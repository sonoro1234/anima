require"anima"


local vert_shad = [[
uniform mat4 TM;
in vec3 position;
in vec2 texcoords;
out vec2 ftcoor;
void main()
{

	ftcoor = (TM*vec4(texcoords,0,1)).st;
	gl_Position = vec4(position,1);
}

]]

local frag_shad = [[
uniform sampler2D tex0;
in vec2 ftcoor;
void main()
{
	vec4 color = texture2D(tex0,ftcoor);
	gl_FragColor = color;
}
]]

local program, vao
local function mirror(GL)
	local M = {GL=GL}
	function M:init()
		if not program then 
			program = GLSL:new():compile(vert_shad,frag_shad)
			vao = mesh.quad():vao(program)
		end
	end
	function M:SetTM(texture,w,h)
		local aspect = w/h
		if aspect >= texture.aspect then
			local rat = aspect/texture.aspect
			return mat.scale(rat,1,1)*mat.translate(-0.5*(rat-1)/rat,0, 0)
		else
			local rat = texture.aspect/aspect
			return mat.scale(1,rat,1)*mat.translate(0,-0.5*(rat-1)/rat, 0)
		end
	end
	function M:process(texture)
		program:use()
		local U = program.unif
		U.tex0:set{0}
		texture:Bind(0)
		texture:set_wrap()
		gl.glViewport(0, 0, GL.W, GL.H)
		
		local TM = self:SetTM(texture,GL.W, GL.H)
		U.TM:set(TM.gl)
		vao:draw_elm()
	end
	GL:add_plugin(M)
	return M
end

--[=[

local GL = GLcanvas{H=800,aspect=16/9}
local mirr = mirror(GL)
local textur
function GL.init()
	textur = GL:Texture():Load[[C:\luaGL\media\_MG_2305.jpg]]
end

function GL.draw(t,w,h)
	ut.Clear()
	--textur:drawcenter()
	mirr:process(textur)
end
GL:start()
--]=]

return mirror