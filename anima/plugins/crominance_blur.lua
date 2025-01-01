require"anima"

local function make(GL)
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}
	
	local NM = GL:Dialog("cr",{
	{"mixv",0,guitypes.val,{min=0,max=1}}
	})
	
	local texproc = require"anima.plugins.texture_processor"(GL,2,NM)
	local blur = require"anima.plugins.gaussianblur3"(GL)
	--blur3.NM.invisible = true
	
	local DBox = GL:DialogBox("um",true) --autosaved
	DBox:add_dialog(blur.NM)
	DBox:add_dialog(texproc.NM)

	M.NM = DBox
	
	local fbo
	function M:init()
		fbo = GL:initFBO({no_depth=true})

		texproc:set_process(require"anima.GLSL.GLSL_color"..[[
		vec4 process(vec2 pos){
			vec3 c1lab = sRGB2LAB(c1.rgb);
			vec3 c2lab = sRGB2LAB(c2.rgb);
			vec3 res = LAB2sRGB(vec3(c1lab.r,c2lab.g,c2lab.b));
			return mix(c1,vec4(res,1),mixv);
			//return c1 + (c1- c2)*mixv;
		}
		]])
	end
	function M:process(tex,w,h)
		blur:process_fbo(fbo,tex)
		texproc:process({tex,fbo:tex()})
	end
	GL:add_plugin(M,"cr")
	return M
end

--[=[
GL = GLcanvas{H=800,aspect=1.5}
local tex,um
function GL:init()
	tex = GL:Texture():Load[[c:\luagl/frames_anima/photofx/5909tn.tif]]
	tex = tex:resample(GL.W,GL.H)
	GL:set_WH(tex.width,tex.height)
	um = make(GL)
	GL:DirtyWrap()
end
local Hist = gui.Histogram(GL,256)
function GL:imgui()
	Hist()
end
function GL.draw(t,w,h)
	--tex:inc_signature()
	um:process(tex)
end
GL:start()
--]=]
return make