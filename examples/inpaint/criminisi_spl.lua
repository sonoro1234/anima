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
	gl.glClearColor(0,0,1,0)
	ut.Clear()
	crimi.maskfbo:UnBind()
	spline:spline2mask(crimi.maskfbo,{1,0,0,0},1)
	
	local CBox = spline:box2d(1)
	CBox[1].x = math.max(0,CBox[1].x)
	CBox[1].y = math.max(0,CBox[1].y)
	print("CBox",CBox[1], CBox[2])
	
	--create source mask from padding spline 1
	--with hole from to be inpainted mask
	if padNM.use_padding then
	
		local points = spline.ps[1]
		local pointspad = CG.PolygonPad(points, padNM.padding)
		
		local pointsR = {}
		for i=#points,1,-1 do
			pointsR[#pointsR+1] = points[i]
		end
		--pointspad.holes = {pointsR}
		--pointspad = CG.InsertHoles(pointspad)
		
		spline:deletespline(2)
		spline:newspline(pointspad)
		spline:newhole(pointsR)
		spline:calc_spline(2)
		spline:set_current(1)
	end
	
	--mask padding: green (source for inpaint) and blue (not to be inpainted)
	spline:spline2mask(crimi.maskfbo,{0,1,1,0}, 2)

	local SBox = spline:box2d(2)
	SBox[1].x = math.max(0,SBox[1].x)
	SBox[1].y = math.max(0,SBox[1].y)
	print("SBox",SBox[1], SBox[2])
	return CBox, SBox
end
require"anima"
GL = GLcanvas{H=700 ,aspect=1,profile="CORE",vsync=false,fbo_nearest=false,fps=300}

padNM = GL:Dialog("padding",
{{"use_padding",true,guitypes.toggle},
{"padding",30,guitypes.drag,{min=1,max=200}}})

local DBox = GL:DialogBox("Criminisi",true)
local fname = [[golf.png]]--[[edificio.png]]--[[golf.png]]
function GL.init()
	tex = GL:Texture():Load(fname):Info()
	GL:set_WH(tex.width,tex.height)
	crimi = require"anima.graphics.criminisi"(GL,tex,make_mask1)

	spline = require"anima.modeling.Spline"(GL)

	DBox:add_dialog(crimi.NM)
	DBox:add_dialog(spline.NM)
	DBox:add_dialog(padNM)
	
	local plugin = require"anima.plugins.plugin"
	local seri = plugin.serializer(spline)
	seri.load"golf.spline"
	GL:DirtyWrap()
end

function GL.draw(t,w,h)
	if crimi.doing then crimi.NM.vars.mostrar[0] = 1 end
	crimi.draw(t,w,h)
end


GL:start()