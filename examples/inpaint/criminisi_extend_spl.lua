-- implementation of: "Object Removal by Exemplar-Based Inpainting, A. Criminisi, P.Perez, K. Toyama"
-- -- prio GPU added
--confidence values recalc
--updateCanvasGPU
-- get subimage
----------------------

local spline
local tex
local crimi
local padNM

local CG = require"anima.CG3"
local GL
--makes maskfbo with spline and padding
local function make_mask1()
	
	--mask as red (to be inpainted) over blue (not to be inpainted)
	crimi.maskfbo:Bind()
	gl.glClearColor(1,0,0,0)
	ut.Clear()
	crimi.maskfbo:UnBind()
	--mask padding: green (source for inpaint) and blue (not to be inpainted)
	spline:spline2mask(crimi.maskfbo,{0,1,1,0},1)
	
	local CBox = {mat.vec2(0,0),mat.vec2(crimi.maskfbo:tex().width, crimi.maskfbo:tex().height)}
	print("CBox",CBox[1], CBox[2])
	
	local SBox = spline:box2d(1)
	SBox[1].x = math.max(0,SBox[1].x)
	SBox[1].y = math.max(0,SBox[1].y)
	print("SBox",SBox[1], SBox[2])
	return CBox, SBox
end
require"anima"
GL = GLcanvas{H=900 ,aspect=1,profile="CORE",vsync=true,fbo_nearest=false,fps=25,DEBUG=true}


local DBox = GL:DialogBox("Criminisi",true)
local fname = [[golf.png]]--[[edificio.png]]--[[golf.png]]
function GL.init()
	tex = GL:Texture():Load(fname):Info()
	GL:set_WH(tex.width,tex.height)
	crimi = require"anima.graphics.criminisi"(GL,tex,make_mask1)

	spline = require"anima.modeling.Spline"(GL)

	DBox:add_dialog(crimi.NM)
	DBox:add_dialog(spline.NM)
	
	local plugin = require"anima.plugins.plugin"
	local seri = plugin.serializer(spline)
	seri.load"golf_ext.spline"
	GL:DirtyWrap()
end

function GL.draw(t,w,h)
	--if crimi.doing then crimi.NM.vars.mostrar[0] = 1 end
	crimi.draw(t,w,h)
end


GL:start()