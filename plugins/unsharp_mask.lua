require"anima"

local function make(GL)
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}
	
	local NM = GL:Dialog("um",{
	{"clarity",0,guitypes.val,{min=-1,max=1}}
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
		fbo = initFBO(GL.W,GL.H,{no_depth=true})
		texproc:set_process[[
		vec4 process(vec2 pos){
			//return c1*alpha1 + (vec4(1)-c2)*alpha2;
			//return c1*alpha1 - c2*alpha2;
			return c1 + (c1- c2)*clarity;
		}
		]]
	end
	function M:process(tex,w,h)
		blur:process_fbo(fbo,tex)
		--texproc:set_textures{tex,fbo:tex()}
		texproc:process({tex,fbo:tex()})
	end
	GL:add_plugin(M,"um")
	return M
end

--[=[
GL = GLcanvas{H=600,aspect=1.5}
local tex,um
function GL:init()
	tex = GL:Texture():Load[[c:\luagl/media/estanque-001.jpg]]
	tex = tex:resample(GL.W,GL.H)
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