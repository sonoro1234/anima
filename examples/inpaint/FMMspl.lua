-- Threaded implementation of inpaint by FMM
-- use Spline to select area to inpaint
-- then click doit on inpaint dialog

----------------------
require"anima"
local GL = GLcanvas{H=700 ,aspect=1,vsync=true}

local spline,FMMm
local tex
local maskfbo

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
local function make_mask()
	
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
	maskfbo:Bind()
	gl.glDisable(glc.GL_DEPTH_TEST)
	maskfbo:viewport()
	gl.glClearColor(0,0,0,0)
	ut.Clear()
	vaoT:draw_elm()
	maskfbo:UnBind()
	
end


local DBox = GL:DialogBox("FMM",true)
function GL.init()
	tex = GL:Texture():Load([[golf.png]])
	
	GL:set_WH(tex.width,tex.height)
	
	spline = require"anima.modeling.Spline"(GL,make_mask)
	FFMm = require"anima.graphics.FMMmodule"(GL)
	maskfbo = GL:initFBO({no_depth=true})
	
	DBox:add_dialog(FFMm.NM)
	DBox:add_dialog(spline.NM)
	
	local plugin = require"anima.plugins.plugin"
	plugin.serializer(spline)

	GL:DirtyWrap()
end

function GL.draw(t,w,h)
	ut.Clear()
	tex:drawcenter()
	FFMm:draw(tex, maskfbo:tex())
end

GL:start()