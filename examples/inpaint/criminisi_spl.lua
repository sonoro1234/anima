-- implementation of: "Object Removal by Exemplar-Based Inpainting, A. Criminisi, P.Perez, K. Toyama"
-- -- prio GPU added
--confidence values recalc
--updateCanvasGPU
-- get subimage
----------------------
local vert_sh = [[
	in vec2 position;
	void main(){
		gl_Position = vec4(position,-1,1);
	}]]

local frag_sh = [[
	uniform vec3 color = vec3(1);
	void main(){
		gl_FragColor = vec4(color,1);
	}]]
	
local spline
local tex
local crimi
local padNM

local CG = require"anima.CG3"
local vec2 = mat.vec2
local floor = math.floor
local function box2d(points)
	local function round(x)
		return floor(x+0.5)
	end
	local minx,maxx,miny,maxy = math.huge,-math.huge,math.huge,-math.huge
	for i,p in ipairs(points) do
		minx = p.x < minx and p.x or minx
		maxx = p.x > maxx and p.x or maxx
		miny = p.y < miny and p.y or miny
		maxy = p.y > maxy and p.y or maxy
	end
	return {vec2(round(minx),round(miny)),vec2(round(maxx),round(maxy))}
end

local GL
--makes maskfbo with spline and padding
local function make_mask1()
	

	local points = spline.ps[1]
	if not points then print"No Spline:select spline" return end
	local points,indexes = CG.EarClipSimple2(points)
	local ndc = {}
	for i=1,#points do
		ndc[i] =  points[i]*2/mat.vec2(GL.W,GL.H) - mat.vec2(1,1)
	end
	
	local CBox = box2d(points)
	CBox[1].x = math.max(0,CBox[1].x)
	CBox[1].y = math.max(0,CBox[1].y)
	print("CBox",CBox[1], CBox[2])
	
	
	--mask as red over blue
	local vaoT = VAO({position=ndc},maskprog,indexes)
	maskprog:use()
	maskprog.unif.color:set{1,0,0}
	crimi.maskfbo:Bind()
	gl.glDisable(glc.GL_DEPTH_TEST)
	crimi.maskfbo:viewport()
	gl.glClearColor(0,0,1,0)
	ut.Clear()
	vaoT:draw_elm()
	crimi.maskfbo:UnBind()

	gl.glClearColor(0,0,0,0)
	if padNM.use_padding then
		local pointspad = CG.PolygonPad(points, padNM.padding)
		
		local pointsR = {}
		for i=#points,1,-1 do
			pointsR[#pointsR+1] = points[i]
		end
		pointspad.holes = {pointsR}
		pointspad = CG.InsertHoles(pointspad)
		
		spline:deletespline(2)
		spline:newspline(pointspad)
		spline:calc_spline(2)
		spline:set_current(1)
	end
	
	if not spline.ps[2] then print"No Spline pad"; return end
	local points2,indexes2 = CG.EarClipSimple2(spline.ps[2])
	local ndc2 = {}
	for i=1,#points2 do
		ndc2[i] =  points2[i]*2/mat.vec2(GL.W,GL.H) - mat.vec2(1,1)
	end
	local vaoT2 = VAO({position=ndc2},maskprog,indexes2)
	
	--mask padding: green and blue
	maskprog:use()
	maskprog.unif.color:set{0,1,1}
	crimi.maskfbo:Bind()
	crimi.maskfbo:viewport()
	vaoT2:draw_elm()
	crimi.maskfbo:UnBind()
	
	local SBox = box2d(points2)
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
	tex = GL:Texture():Load(fname)
	
	GL:set_WH(tex.width,tex.height)
	crimi = require"anima.graphics.criminisi"(GL,tex,make_mask1)
	crimi:init()
	maskprog = GLSL:new():compile(vert_sh,frag_sh)
	spline = require"anima.modeling.Spline"(GL,dummy)

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