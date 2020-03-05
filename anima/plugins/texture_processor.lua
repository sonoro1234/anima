require"anima"

local vert_shad = [[
in vec3 Position;
in vec2 texcoords;
void main()
{
	gl_TexCoord[0] = vec4(texcoords,0,1);
	gl_Position = vec4(Position,1);
}
]]

local frag_shad = [[

void main(){
	loadtextures(gl_TexCoord[0].st);
	gl_FragColor = process(gl_TexCoord[0].st);
}

]]

function mixer(GL,ntex,NM)
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new({res={GL.W,GL.H}},GL)
	M.NM = NM or {}
	local frag = ""
	if NM then
		local typev = " float "
		for k,v in pairs(NM.vars) do
			--prtable(v,v[1],NM.defs[k])
			if NM.defs[k].type == guitypes.toggle then
				typev = " bool "
			else
				typev = " float "
			end
			frag = frag .. "uniform"..typev..k..";\n"
		end
	end
	for i=1,ntex do
		frag = frag .. "uniform sampler2D tex"..tostring(i)..";\n"
		frag = frag .. "vec4 c"..tostring(i)..";\n"
	end
	frag = frag .. "void loadtextures(vec2 pos){\n"
	for i=1,ntex do
		frag = frag .. "c"..tostring(i).." = texture2D(tex"..tostring(i)..",pos);\n"
	end
	frag = frag .. "}\n"
	
	function M:set_process(st)
		self.program = GLSL:new():compile(vert_shad,frag..st..frag_shad)
		local m = mesh.Quad(-1,-1,1,1)
		M.vao = VAO({Position=m.points,texcoords = m.texcoords},self.program,m.indexes)
	end
	
	local texsignatures = {}
	function M:set_textures(t)
		assert(#t == ntex)
		self.tex = t
		-- for i,t in ipairs(self.tex) do
			-- if not texsignatures[i] or texsignatures[i]~=tex[i]:get_signature() then
				-- self.NM.dirty = true
				-- break
			-- end
		-- end
	end

	function M:process(texs,w,h)
		gl.glDisable(glc.GL_DEPTH_TEST)
		assert(#texs == ntex,"number of textures failing!!")
		self.tex = texs
		self.program:use()
		local U = self.program.unif
		for i,t in ipairs(self.tex) do
			t:Bind(i-1)
			U["tex"..tostring(i)]:set{i-1}
		end
		
		if NM then
		for k,v in pairs(NM.vars) do
			U[k]:set{NM[k]}
		end
		end
		
		gl.glViewport(0,0,w or self.res[1], h or self.res[2])
		ut.Clear()
		self.vao:draw_elm()
		--gl.glEnable(glc.GL_DEPTH_TEST)
	end
	GL:add_plugin(M,"texproc")
	return M
end

--[=[
GL = GLcanvas{H=1080,aspect=1.5}
NM = GL:Dialog("pp",{
{"alpha",0,guitypes.val,{min=0,max=1}},
})
pp = mixer(GL,2,NM)

function GL.init()
	tex = GL:Texture():Load[[c:\luagl/media/estanque-001.jpg]]
	tex2 = GL:Texture():Load[[c:\luagl/media/estanque-002.jpg]]
	--pp:set_textures{tex,tex2}
	pp:set_process[[vec4 process(vec2 pos){
		return mix(c1,c2,alpha);
	}
	]]
end
function GL.draw(t,w,h)
	ut.Clear()
	pp:process({tex,tex2})
end

GL:start()
--]=]


return mixer