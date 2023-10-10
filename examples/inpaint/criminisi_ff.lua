-- implementation of: "Object Removal by Exemplar-Based Inpainting, A. Criminisi, P.Perez, K. Toyama"
-- -- prio GPU added
--confidence values recalc
--updateCanvasGPU
-- get subimage
----------------------
require"anima"
local GL = GLcanvas{H=700 ,aspect=1,profile="CORE",vsync=false,fbo_nearest=false,fps=300}

local tex
local crimi
local FF,morfbo1,morpho,morpho1,morfbo,subsproc

local DBox = GL:DialogBox("Criminisi",true)
local fname = [[golf.png]]--[[edificio.png]]

function GL.init()
	tex = GL:Texture():Load(fname)
	
	GL:set_WH(tex.width,tex.height)
	
	crimi = require"anima.graphics.criminisi"(GL, tex)
	crimi:init()

	FF = require"anima.plugins.flood_fill"(GL)
	FF.NM.vars.show_image[0] = false
	morpho = require"anima.plugins.morphology"(GL)
	morpho.NM:SetValues{op="dilate",kernelsize=4,iters=10}
	morpho1 = require"anima.plugins.morphology"(GL)
	morpho1.NM:SetValues{op="dilate",kernelsize=2,iters=1}
	morpho1.NM.invisible = true
	subsproc = require"anima.plugins.texture_processor"(GL,2)
	subsproc:set_process[[vec4 process(vec2 pos){
		float col = max(0.0,c1.r-c2.r);
		return vec4(c2.r,col,1.0-c2.r,0.3);
	}]]

	morfbo1 = GL:initFBO({no_depth=true})
	morfbo = GL:initFBO({no_depth=true})
	
	DBox:add_dialog(crimi.NM)
	DBox:add_dialog(FF.NM)
	DBox:add_dialog(morpho.NM)

	GL:DirtyWrap()
end


function GL.draw(t,w,h)
	ut.Clear()
	
	--flod fill
	FF:process(tex)
	--dilate 2 pixels
	morpho1:process_fbo(morfbo1,FF.mask)
	--dilate to get padding area
	morpho:process_fbo(morfbo,morfbo1:tex())
	--make maskfbo: red is to be inpaint, blue not to be inpainted, green is padding area
	subsproc:process_fbo(crimi.maskfbo,{morfbo:tex(),morfbo1:tex()})
	
	-- if doing criminisi show canvas
	if crimi.doing then crimi.NM.vars.mostrar[0] = 1 end
	-- show tex and mask blended
	if crimi.NM.mostrar == 0 then
		tex:drawcenter()
			ut.ClearDepth()
			gl.glEnable(glc.GL_BLEND)
			gl.glBlendFunc(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA)
			glext.glBlendEquation(glc.GL_FUNC_ADD)
			crimi.maskfbo:tex():drawcenter()
			gl.glDisable(glc.GL_BLEND)
	else
		crimi.draw(t,w,h)
	end

end


GL:start()