

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

uniform sampler2D tex0;
uniform vec2 ini;
uniform vec2 endp;
uniform bool bypass;
uniform bool oval;
uniform bool invert;
uniform bool AA;
void main()
{
	
	vec2 texsize = textureSize(tex0,0);
	//vec2 pos = vec2(gl_FragCoord.x/w,gl_FragCoord.y/h);
	vec2 pos = gl_FragCoord.xy/texsize;
	vec4 color = texture2D(tex0,pos);
	float alpha = 1.0;
	if(!bypass){
		if(oval){
			vec2 itopos = pos - ini;
			float radio = endp.y;
			float dst = length(itopos);
			if(!AA){
				alpha = 1.0 - smoothstep(radio, radio + endp.x, dst);
			}else{
				//float delta = fwidth(dst);
				float delta = length(vec2(dFdx(dst),dFdy(dst)));
				alpha = 1.0 - smoothstep(radio - delta, radio + delta + endp.x, dst);
			}
		}else{
			vec2 itopos = pos - ini;
			vec2 itoend = endp - ini;
			float proj = dot(itopos,itoend)/dot(itoend,itoend);
			alpha = clamp(proj,0.0,1.0);
		}
		if(invert)
			alpha = 1.0 - alpha;
	}
	
	gl_FragColor = vec4(color.xyz,color.a*alpha); 
}
]]


local M = {}

function M.make(GL,name)
	local NM = GL:Dialog(name or "gradient",
{
{"iniX",0,guitypes.dial},
{"iniY",0.2,guitypes.dial},
{"endX",0,guitypes.dial},
{"endY",0.5,guitypes.dial},
{"oval",false,guitypes.toggle},
{"invert",false,guitypes.toggle},
{"bypass",false,guitypes.toggle},
{"AA",false,guitypes.toggle},
})
	local plugin = require"anima.plugins.plugin"
	local LM = plugin.new{res={GL.W,GL.H},NM=NM}
	local programfx

	function LM.init()
		programfx = GLSL:new():compile(vert_shad,frag_shad)
		local m = mesh.Quad(-1,-1,1,1)
		LM.vao = VAO({Position=m.points,texcoords = m.texcoords},programfx,m.indexes)
		LM.inited = true
	end
	
	function LM:process(srctex,w,h)

		srctex:Bind()
		
		programfx:use()
		programfx.unif.tex0:set{0}
		programfx.unif.ini:set{NM.iniX,NM.iniY}
		programfx.unif.endp:set{NM.endX,NM.endY}
		programfx.unif.bypass:set{NM.bypass}
		programfx.unif.oval:set{NM.oval}
		programfx.unif.invert:set{NM.invert}
		programfx.unif.AA:set{NM.AA}
		
		gl.glViewport(0,0,w or self.res[1], h or self.res[2])
		self.vao:draw_elm()

	end
	
	GL:add_plugin(LM)
	return LM
end


return M


