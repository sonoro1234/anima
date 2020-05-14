-- Threaded inpaint with GIMP resynthesizer library
-- use flood_fill to select area to inpaint
-- use mophol do dilate this area (resynthesizer will use this area as source)
-- click doit on resynth
-----------------------------------------------------------------------------
require"anima"


local GL = GLcanvas{H=700 ,aspect=1,vsync=true}
GL.use_presets = true

local medit1
local morpho 
local tex
local mask1,mask2,morfbo
local mixer,subsproc
local GIMPm
local DBox = GL:DialogBox("resynthesizer",true)
function GL.init()
	tex = GL:Texture():Load([[golf.png]])
	GL:set_WH(tex.width,tex.height)
	
	medit1 = require"anima.plugins.flood_fill"(GL)
	morpho = require"anima.plugins.morphology"(GL)
	morpho.NM:SetValues{op="dilate"}

	GIMPm = require"anima.graphics.GIMPmodule"(GL)
	subsproc = require"anima.plugins.texture_processor"(GL,2)
	DBox:add_dialog(GIMPm.NM)
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
	
	GIMPm:draw(tex,medit1.mask,mask2:tex())
end

GL:start()