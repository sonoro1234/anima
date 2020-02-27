require"anima"
local CG = require"anima.CG3"

local vert_sh = [[
	in vec2 position;
	uniform mat4 MVP;
	void main()
	{
		gl_Position = MVP * vec4(position,0,1);
	
	}
	]]

local frag_sh = [[
	uniform vec3 color = vec3(1);
	void main()
	{
		gl_FragColor = vec4(color,1);
	}
	]]


GL = GLcanvas{H=800,aspect=1}

local N = 500
local prog,vaop,vaoCH,vaoT,vaoTD
local points = {}

function set_vaos()
	CG.lexicografic_sort(points)
	local CH,tr = CG.triang_sweept(points)
	local tr2 = CG.Delaunay(points,tr)

	vaop:set_buffer("position",mat.vec2vao(points))
	vaoCH:set_buffer("position",mat.vec2vao(CH))
	vaoT:set_buffer("position",mat.vec2vao(points))
	vaoT:set_indexes(tr)
	vaoTD:set_buffer("position",mat.vec2vao(points))
	vaoTD:set_indexes(tr2)
end

function make_points()
	for i=1,N do
		points[i] = mat.vec2(math.random()-0.5,math.random()-0.5)*0.25
	end
	set_vaos()
end

function move_points()
	for i=1,N do
		points[i] = points[i] + mat.vec2(math.random()-0.5,math.random()-0.5)*0.01
	end
	set_vaos()
end


local NM = GL:Dialog("dealun",
{{"other",0,guitypes.button,function() make_points() end},
{"drawhull",true,guitypes.toggle},
{"drawtriang",true,guitypes.toggle},
{"dealunay",true,guitypes.toggle},
})

function GL.init()
	prog = GLSL:new():compile(vert_sh,frag_sh)
	vaop = VAO({position={}},prog)
	vaoCH = VAO({position={}},prog)
	vaoT = VAO({position={}},prog,{0})
	vaoTD = VAO({position={}},prog,{0})
	make_points()
end

function GL.draw(t,w,h)
	move_points()
	ut.Clear()
	gl.glDisable(glc.GL_DEPTH_TEST)
	gl.glViewport(0,0,w,h)
	prog:use()
	prog.unif.MVP:set(mat.identity.gl)
	
	gl.glPointSize(5)
	prog.unif.color:set{1,0,0}
	vaop:draw(glc.GL_POINTS)
	
	if NM.drawhull then
		prog.unif.color:set{0,1,0}
		vaoCH:draw(glc.GL_POINTS)
		prog.unif.color:set{1,1,1}
		vaoCH:draw(glc.GL_LINE_LOOP)
	end
	if NM.drawtriang then
		prog.unif.color:set{1,1,1}
		if NM.dealunay then
			vaoTD:draw_mesh()
		else
			vaoT:draw_mesh()
		end
	end
	gl.glPointSize(1)
	gl.glEnable(glc.GL_DEPTH_TEST)
end
GL:start()