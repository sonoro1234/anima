-- Threaded inpaint with GIMP resynthesizer library
-- use flood_fill to select area to inpaint
-- use mophol do dilate this area (resynthesizer will use this area as source)
-- click doit on resynth
-----------------------------------------------------------------------------
require"anima"
--WINUSEPTHREAD = true
local ok,resy = pcall(require,"resynth")
if not ok then print("You need to install from https://github.com/sonoro1234/resynthesizer"); os.exit() end
local Thread = require "lj-async.thread"
local thread_data_t = ffi.typeof("struct { ImageBuffer im;ImageBuffer m1;ImageBuffer m2;float* progdata;}")

local thread_func = function(pars)
	--WINUSEPTHREAD = true
	local ffi = require "ffi"
	local resy = require"resynth"

	local cancel = ffi.new"int[1]"
	local param = ffi.new"TImageSynthParameters"
	
	param.isMakeSeamlesslyTileableHorizontally = false;
	param.isMakeSeamlesslyTileableVertically   = false;
	param.matchContextType                     = pars.matchContextType
	param.mapWeight                            = pars.mapWeight
	param.sensitivityToOutliers                = pars.sensitivityToOutliers
	param.patchSize                            = pars.patchSize
	param.maxProbeCount	                       = pars.maxProbeCount
	
	return function(ud)

		ud = ffi.cast("struct { ImageBuffer im;ImageBuffer m1;ImageBuffer m2;float* progdata;}*", ud)

		local function progress(count,ctx)
			ud.progdata[0] = count/100
		end
		
		ud.progdata[0] = 0
		
		local err = resy.imageSynth2(ud.im, ud.m1, ud.m2, resy.T_RGB, param, progress, nil,cancel)
		
		if err==0 then ud.progdata[0] = 1 end
		print("err is",err)
	end
end

local vicim = require"anima.vicimag"
local imbuf,m1buf,m2buf,datam1,datam2
local function resynth(tex,m1,m2,NM,progrData)

	local cancel = ffi.new"int[1]"
	local param = {}
	
	param.isMakeSeamlesslyTileableHorizontally = false;
	param.isMakeSeamlesslyTileableVertically   = false;
	param.matchContextType                     = NM.matchContextType
	param.mapWeight                            = NM.mapWeight
	param.sensitivityToOutliers                = NM.sensitivityToOutliers
	param.patchSize                            = NM.patchSize
	param.maxProbeCount	                       = NM.maxProbeCount
	
	local datatex = tex:get_pixels(nil,glc.GL_RGB)

	if NM.flipV then datatex = vicim.flip_vertical(datatex,tex.width,tex.height,3) end
	imbuf = ffi.new("ImageBuffer",{datatex, tex.width, tex.height, tex.width*3})
	
	datam1 = m1:get_pixels(nil,glc.GL_RED)
	if NM.flipV then datam1 = vicim.flip_vertical(datam1,m1.width,m1.height,1) end
	m1buf = ffi.new("ImageBuffer",{datam1, m1.width, m1.height, m1.width})
	
	datam2 = m2:get_pixels(nil,glc.GL_RED)
	if NM.flipV then datam2 = vicim.flip_vertical(datam2,m2.width,m2.height,1) end
	m2buf = ffi.new("ImageBuffer",{datam2, m2.width, m2.height, m2.width})
	
	local size = m2.width*m2.height
	local maxval = -math.huge
	local minval = math.huge
	for i=0,size-1 do
		maxval = maxval > datam2[i] and maxval or datam2[i]
		minval = minval < datam2[i] and minval or datam2[i]
		if datam1[i] > 0 then datam1[i] = 255 end
		if datam2[i] > 0 then datam2[i] = 255 end
	end
	print("maxval",minval,maxval)

	local t = Thread(thread_func,thread_data_t(imbuf,m1buf,m2buf,progrData),param)

	return t,datatex

end

local GL = GLcanvas{H=700 ,aspect=1,vsync=true}
GL.use_presets = true

local DORESYNTH
local progrData = ffi.new("float[1]")
local NM = GL:Dialog("resynth",{
{"doit",0,guitypes.button,function() DORESYNTH=true end},
{"flipV",false,guitypes.toggle},
{"showres",false,guitypes.toggle},
{"matchContextType",1,guitypes.valint,{min=0,max=8}},
{"mapWeight",0,guitypes.drag,{min=0,max=1}},
{"sensitivityToOutliers",0.117,guitypes.drag,{min=0,max=1}},
{"patchSize",16,guitypes.valint,{min=1,max=36}},
{"maxProbeCount",500,guitypes.valint,{min=1,max=500}}
},function() 
	ig.ProgressBar(progrData[0])
end)

local medit1
local morpho 
local tex,tex2
local mask1,mask2,morfbo
local mixer,subsproc
local DBox = GL:DialogBox("resynthesizer",true)
function GL.init()
	tex = GL:Texture():Load([[golf.png]])
	tex2 = GL:Texture(tex.width,tex.height)
	GL:set_WH(tex.width,tex.height)
	
	medit1 = require"anima.plugins.flood_fill"(GL)
	morpho = require"anima.plugins.morphology"(GL)
	morpho.NM:SetValues{op="dilate"}
	local codestr = [[if(t@)
						color = color*(1.0-c@.r)+c@;
	]]

	subsproc = require"anima.plugins.texture_processor"(GL,2)
	DBox:add_dialog(NM)
	DBox:add_dialog(medit1.NM)
	DBox:add_dialog(morpho.NM)
	
	
	local plugin = require"anima.plugins.plugin"
	plugin.serializer(medit1)
	plugin.serializer(morpho)
	
	mask1 = GL:initFBO({no_depth=true})
	mask2 = GL:initFBO({no_depth=true})
	morfbo = GL:initFBO({no_depth=true})
	
	subsproc:set_process[[vec4 process(vec2 pos){
		float col = c1.r-c2.r;
		return vec4(vec3(col),col*0.5);
	}]]
	GL:DirtyWrap()
end


local tt,datatex
function GL.draw(t,w,h)
	
	ut.Clear()

	medit1:process_fbo(mask1,tex)
	mask1:tex():drawcenter()
	morpho:process_fbo(morfbo,medit1.mask)
	
	
	subsproc:process_fbo(mask2,{morfbo:tex(),medit1.mask})
	
	ut.ClearDepth()
	gl.glEnable(glc.GL_BLEND)
	gl.glBlendFunc(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA)
	glext.glBlendEquation(glc.GL_FUNC_ADD)
	mask2:tex():drawcenter()
	gl.glDisable(glc.GL_BLEND)
	
	if NM.showres then
		ut.Clear()
		tex2:drawcenter()
	end
	
	if DORESYNTH then
		tt,datatex = resynth(tex,medit1.mask,mask2:tex(),NM,progrData)
		DORESYNTH = false
	end
	if tt then
		if tt:join(0.01) then
			if NM.flipV then datatex = vicim.flip_vertical(datatex,tex.width,tex.height,3) end
			tex2:set_data(datatex,3,3)
			tt:free()
			tt = nil
			NM.vars.showres[0] = true
		end
	end
end

GL:start()