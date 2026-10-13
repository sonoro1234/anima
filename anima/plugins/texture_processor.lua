require"anima"

local vert_shad = [[
in vec3 Position;
in vec2 texcoords;
 noperspective out vec2 texCoord;
void main()
{
	texCoord = texcoords;
	gl_Position = vec4(Position,1);
}
]]

local frag_shad = [[

noperspective in vec2 texCoord;
out vec4 fcolor;

void main(){
	loadtextures(texCoord);
	fcolor = process(texCoord);
}

]]

function mixer(GL,ntex,NM)
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new({res={GL.W,GL.H}},GL)
	M.NM = NM or {}
	local frag = "uniform vec2 viewport_dims;"
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
		local m = mesh.quad()
		M.vao = VAO({Position=m.points,texcoords = m.texcoords},self.program,m.indexes)
	end
	--[[
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
	--]]
	function M:process(texs,w,h)
		--print"doing"
		w = w or self.res[1];h = h or self.res[2]
		gl.glDisable(glc.GL_DEPTH_TEST)
		assert(#texs == ntex,"number of textures failing!!")
		self.tex = texs
		self.program:use()
		local U = self.program.unif
		for i,t in ipairs(self.tex) do
			t:Bind(i-1)
			U["tex"..tostring(i)]:set{i-1}
		end
		U.viewport_dims:set{w,h}
		if NM then
		for k,v in pairs(NM.vars) do
			U[k]:set{NM[k]}
		end
		end
		
		gl.glViewport(0,0,w, h)
		ut.Clear()
		self.vao:draw_elm()
		--gl.glEnable(glc.GL_DEPTH_TEST)
	end
	GL:add_plugin(M,"texproc")
	return M
end

--[=[
if not ... then
local GL = GLcanvas{H=900,aspect=1.5,SDL=false, use_log=true}
local NM = GL:Dialog("pp",{
{"alpha",0,guitypes.val,{min=0,max=1}},
})
local pp = mixer(GL,2,NM)
local NM2 = GL:Dialog("pp2",{
{"col",0,guitypes.val,{min=0,max=1}},
})
local fbo,fbo2
function GL.init()
	print_glinfo(GL)
	tex = GL:Texture():Load[[c:\luagl/media/estanque-001.jpg]]
	tex2 = GL:Texture():Load[[c:\luagl/media/estanque-002.jpg]]
	pp:set_process[[vec4 process(vec2 pos){
		return mix(c1,c2,alpha);
	}
	]]
	fbo = GL:initFBO()
	fbo2 = GL:initFBO()
	GL:DirtyWrap()
end
function GL.draw(t,w,h)
	---[==[
	--dirty wrap test
	fbo2:Bind()
	gl.glClearColor(NM2.col,1,0,1)
	ut.Clear()
	fbo2:UnBind()
	if NM2.dirty then
	fbo2:tex():inc_signature()
	NM2.dirty = false
	end
	pp:process_fbo(fbo,{fbo2:tex(),tex2})
	fbo:tex():draw(0,w,h)
	do return end
	--]==]
	
	pp:process_fbo(fbo,{tex,tex2})
	fbo:tex():draw(0,w,h)
end

GL:start()
end
--]=]

---[=[
if not ... then
local GL = GLcanvas{H=900,aspect=1.5,SDL=false, use_log=false}
local pp = mixer(GL,0)
function GL.init()
	pp:set_process[[vec4 process(vec2 pos){
		return vec4(1.0-length(pos));
	}
	]]
end
function GL.draw(t,w,h)
	pp:process{}
end

GL:start()
end
--]=]


return mixer