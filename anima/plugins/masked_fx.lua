
require"anima"
local plugin = require"anima.plugins.plugin"

local function Masked_fx(GL,fx)

	local MM = plugin.new{res={GL.W,GL.H}}
	local mask = require"anima.plugins.SplineEditorBlur"(GL)
	MM.maskpl = mask
	print("mask",mask)
	local fbofx,fbomask,tex
	local tproc
	
	local NM = GL:Dialog("proc",
	{{"showmask",false,guitypes.toggle},
	{"invert",false,guitypes.toggle},
	{"minmask",0,guitypes.val,{min=0,max=1}},
	{"maxmask",1,guitypes.val,{min=0,max=1}},
	},function() MM.ps.draw() end)

	local DBox = GL:DialogBox("maskfx",true) --autosaved
	DBox:add_dialog(mask.NM)
	DBox:add_dialog(fx.NM)
	DBox:add_dialog(NM)
	
	MM.NM = DBox
	MM.ps = plugin.serializer(MM)
	
	function MM:init()
		fbofx = GL:initFBO({no_depth=true})
		fbomask = GL:initFBO({no_depth=true})
		--tex = GL:Texture():Load[[c:\luagl\media\estanque3.jpg]]
		tproc = require"anima.plugins.texture_processor"(GL,3,NM)
		
		tproc:set_process[[vec4 process(vec2 pos){
		
			if (invert)
				c3 = vec4(1) - c3;
			c3 = min(max(c3,vec4(minmask)),vec4(maxmask));
			if (showmask)
				return c3 + c1*(vec4(1)-c3);
			else
				return mix(c1,c2,c3.r);
		}
		]]
	end

	function MM:process(tex,w,h)
		
		--fbofx = GL:get_fbo()
		fx:process_fbo(fbofx,tex)
		--fbomask = GL:get_fbo()
		mask:process_fbo(fbomask,tex)
	
		--ut.Clear()
		--tproc:set_textures{tex,fbofx:tex(),fbomask:tex()}
		tproc:process({tex,fbofx:tex(),fbomask:tex()})
		
		--fbomask:release()
		--fbofx:release()
	end
	GL:add_plugin(MM,"masked_fx")
	return MM
end

if not ... then

---[=[

local GL = GLcanvas{H=600,aspect=3/2,use_log=true}

--GL.use_presets = true
--local fxx = require"anima.plugins.gaussianblur3"(GL)
--local fxx = require"anima.plugins.liquid".make(GL)
--local fxx = require"anima.plugins.photofx".make(GL)
--local fxx = require"anima.plugins.LABfx".make(GL)
local fxx 
--local fxx = require"anima.plugins.local_histogramStarkLab"(GL)

local masked_ed,tex, fbo1
function GL.init()
	--tex = GL:Texture():Load[[c:\luagl\media\estanque3.jpg]]
	tex = GL:Texture():Load[[c:\luagl\media\estanque-001.jpg]]
	GL:set_WH(tex.width, tex.height)
	fxx = require"anima.plugins.LCHfx".make(GL)
	masked_ed = Masked_fx(GL,fxx)
	fbo1 = GL:initFBO()
	GL:DirtyWrap()
end
function GL.imgui()
ig.Begin"dirty tests"
	ig.TextUnformatted("masked_ed:Is"..tostring(masked_ed:IsDirty()))
	ig.TextUnformatted("masked_ed:"..tostring(masked_ed.NM.dirty))
	ig.TextUnformatted("fxx:"..tostring(fxx.NM.dirty))
	ig.TextUnformatted("maskpl:"..tostring(masked_ed.maskpl:IsDirty()).." dirty:"..tostring(masked_ed.maskpl.NM.dirty))
ig.End()
end
function GL.draw(t,w,h)
	--masked_ed.NM.dirty = true
	--masked_ed:process(tex)
	masked_ed:process_fbo(fbo1,tex)
	fbo1:tex():drawcenter()
end
GL:start()
--]=]
end

return Masked_fx