-- Threaded inpaint with GIMP resynthesizer library
-- use Spline to select area to inpaint
-- use padding do dilate this area (resynthesizer will use this area as source)
-- click doit on resynth

require"anima"
local GL = GLcanvas{H=700 ,aspect=1,vsync=true,use_log=false}
GL.use_presets = true

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
local CG = require"anima.CG3"
local spline
local tex
local mask1,mask2
local maskprog
local NM
local function updatespline()
	
	local points = spline.ps[1]
	if not points then return end
	local points,indexes = CG.EarClipSimple2(points)
	local ndc = {}
	for i=1,#points do
		ndc[i] =  points[i]*2/mat.vec2(GL.W,GL.H) - mat.vec2(1,1)
	end
	if not maskprog then
		maskprog = GLSL:new():compile(vert_sh,frag_sh)
	end
	
	local vaoT = VAO({position=ndc},maskprog,indexes)
	maskprog:use()
	mask1:Bind()
	gl.glDisable(glc.GL_DEPTH_TEST)
	mask1:viewport()
	gl.glClearColor(0,0,0,0)
	ut.Clear()
	vaoT:draw_elm()
	mask1:UnBind()
	
	if NM.use_padding then
		local pointspad = CG.PolygonPad(points,NM.padding)
		
		local pointsR = {}
		for i=#points,1,-1 do
			pointsR[#pointsR+1] = points[i]
		end
		pointspad.holes = {pointsR}
		pointspad = CG.InsertHoles(pointspad)
		--local points2,indexes2 = CG.EarClipSimple2(pointspad)
		
		spline:deletespline(2)
		spline:newspline(pointspad)
		spline:calc_spline(2)
		spline:set_current(1)
	end
	
	if not spline.ps[2] then return end
	local points2,indexes2 = CG.EarClipSimple2(spline.ps[2])
	local ndc2 = {}
	for i=1,#points2 do
		ndc2[i] =  points2[i]*2/mat.vec2(GL.W,GL.H) - mat.vec2(1,1)
	end
	local vaoT2 = VAO({position=ndc2},maskprog,indexes2)
	maskprog:use()
	mask2:Bind()
	mask2:viewport()
	gl.glClearColor(0,0,0,0)
	ut.Clear()
	vaoT2:draw_elm()
	mask2:UnBind()
end


local DBox = GL:DialogBox("resynthesizer",true)
NM = GL:Dialog("padding",
{{"use_padding",false,guitypes.toggle},
{"padding",30,guitypes.drag,{min=1,max=200},function() updatespline() end}})

local GIMPm
function GL.init()
	tex = GL:Texture():Load([[golf.png]])
	
	GL:set_WH(tex.width,tex.height)
	GIMPm = require"anima.graphics.GIMPmodule"(GL)
	spline = require"anima.modeling.Spline"(GL,updatespline)

	DBox:add_dialog(GIMPm.NM)
	DBox:add_dialog(NM)
	DBox:add_dialog(spline.NM)

	local plugin = require"anima.plugins.plugin"
	plugin.serializer(spline)
	
	mask1 = GL:initFBO({no_depth=true})
	mask2 = GL:initFBO({no_depth=true})
	
	--GL:DirtyWrap()
end



function GL.draw(t,w,h)
	
	ut.Clear()

	tex:drawcenter()
	ut.ClearDepth()
	gl.glEnable(glc.GL_BLEND)
	gl.glBlendFunc(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA)
	glext.glBlendEquation(glc.GL_FUNC_ADD)
	mask2:tex():drawcenter()
	gl.glDisable(glc.GL_BLEND)
	
	GIMPm:draw(tex, mask1:tex(), mask2:tex())
end

GL:start()