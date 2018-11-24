

local vert_shad = [[

void main()
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}

]]
local frag_shad = [[

uniform sampler2D tex0;

void main()
{
	
	gl_FragColor = texture2D(tex0,gl_TexCoord[0].st); 
}
]]


local M = {}

function M.make(GL)

	local NM = GL:Dialog("photopos",
	{
	{"xpos",0,guitypes.dial},
	{"ypos",0,guitypes.dial},
	{"zpos",0,guitypes.dial},
	{"scale",1,guitypes.val,{min=0,max=10}},
	{"twist",0,guitypes.dial,{fac=180/math.pi}},
	})
	local plugin = require"anima.plugins.plugin"
	local LM = plugin.new{res={GL.W,GL.H},NM=NM}
	local programfx

	function LM.init()
		programfx = GLSL:new():compile(vert_shad,frag_shad)
		--local m = mesh.Quad(-1,-1,1,1)
		--LM.vao = VAO({Position=m.points,texcoords = m.texcoords},programfx,m.indexes)
		LM.inited = true
	end
	
	function LM:process(srctex,w,h)
		w, h = w or self.res[1], h or self.res[2]
		srctex:Bind()
		
		ut.Clear()
		programfx:use()
		programfx.unif.tex0:set{0}
		ut.ortho_camera(w/h,1)
		gl.glViewport(0, 0, w, h)
		gl.glTranslatef(NM.xpos,NM.ypos,NM.zpos)
		gl.glRotatef(NM.twist,0,0,1)
		gl.glScalef(NM.scale,NM.scale,NM.scale)

		ut.DoQuadC(w/h,1)

	end
	
	GL:add_plugin(LM)
	return LM
end


return M


