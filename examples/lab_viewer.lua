
local vert_shad = [[

in vec3 position;
void main()
{

	gl_Position = vec4(position,1);
}
]]

local colors = require"anima.GLSL.GLSL_color"

local frag_shad = "#version 420\n"..colors..[[
uniform float L;
uniform vec2 size;
uniform bool out_color;
out vec4 FragColor;
void main()
{
	vec2 pos = gl_FragCoord.xy/size;
	pos -= vec2(0.5);
	
	//one or the other
	//pos *=vec2(115.0*2);
	pos *=vec2(127.0*2);
	
	vec3 color = RGB2sRGB(XYZ2RGB(LAB2XYZ(vec3(L*100,pos),D65)));
	if (out_color){
		if (any(greaterThan(color,vec3(1.0))) || any(lessThan(color,vec3(0.0))))
			color = vec3(0.0);
	}		
	FragColor = vec4(color,1);
}

]]

require"anima"

GL = GLcanvas{H=800,aspect=1,profile="CORE",SDL=false} --SDL=true to change GLFW for SDL

NM = GL:Dialog("lab_viewer",
{
	{"L",0.75,guitypes.val,{min=0,max=1}},
	{"out_color",true,guitypes.toggle}
})

local programfx,vao
function GL.init()
	programfx = GLSL:new():compile(vert_shad,frag_shad)
	local mesh = require"anima.mesh"
	local m = mesh.quad()
	vao = m:vao(programfx)
end

function GL.draw(t,w,h)
	programfx:use()
	local U = programfx.unif
	ut.Clear()
	U.L:set{NM.L}
	U.out_color:set{NM.out_color}
	U.size:set{GL.W,GL.H}
	vao:draw_elm()
end

GL:start()
