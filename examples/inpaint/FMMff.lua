-- Threaded implementation of inpaint by FMM
-- use flood_fill to select the area to inpaint
-- then click doit on inpaint dialog

----------------------
require"anima"
local GL = GLcanvas{H=700 ,aspect=1,vsync=true}

local FF,FMMm
local tex
local maskfbo

function GL.init()
	tex = GL:Texture():Load([[golf.png]])
	
	GL:set_WH(tex.width,tex.height)
	
	FF = require"anima.plugins.flood_fill"(GL)
	FFMm = require"anima.graphics.FMMmodule"(GL)
	maskfbo = GL:initFBO({no_depth=true})

	GL:DirtyWrap()
end

function GL.draw(t,w,h)
	ut.Clear()
	
	FF:process_fbo(maskfbo,tex)
	maskfbo:tex():drawcenter()
	
	FFMm:draw(tex, FF.mask)
end

GL:start()