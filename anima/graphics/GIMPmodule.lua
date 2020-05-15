-- Threaded inpaint with GIMP resynthesizer library
-----------------------------------------------------------------------------
local function GIMPmodule(GL)
	local M = {}
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
	param.matchContextType                     = NM.matchContextType - 1
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

local DORESYNTH
local progrData = ffi.new("float[1]")
local NMres = GL:Dialog("resynth",{
{"doit",0,guitypes.button,function() DORESYNTH=true end},
{"flipV",false,guitypes.toggle},
{"showres",false,guitypes.toggle},
{"matchContextType",2,guitypes.slider_enum,{"none","random","concentric inward","horizontal inward","vertical inward","concentric outward","horizontal outward","vertical outward","concentric donut"}},
{"mapWeight",0,guitypes.drag,{min=0,max=1}},
{"sensitivityToOutliers",0.117,guitypes.drag,{min=0,max=1}},
{"patchSize",16,guitypes.valint,{min=1,max=64}},
{"maxProbeCount",500,guitypes.valint,{min=1,max=500}},
},function() 
	ig.ProgressBar(progrData[0])
end)

M.NM = NMres
local tt,datatex
local tex2  = GL:Texture()
function M:draw(tex,mask1,mask2)
	if NMres.showres then
		ut.Clear()
		tex2:drawcenter()
	end
	
	if DORESYNTH then
		tt,datatex = resynth(tex,mask1,mask2,NMres,progrData)
		DORESYNTH = false
	end
	if tt then
		if tt:join(0.01) then
			if NMres.flipV then datatex = vicim.flip_vertical(datatex,tex.width,tex.height,3) end
			tex2:set_data(datatex,3,3)
			tt:free()
			tt = nil
			NMres.vars.showres[0] = true
		end
	end
end

	return M
end

return GIMPmodule