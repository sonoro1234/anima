local plugin = require"anima.plugins.plugin"
local vert_shad = [[
in vec3 position;
in vec2 texcoords;
out vec2 f_tc;

void main()
{
	f_tc = texcoords;
	gl_Position = vec4(position,1);
}

]]
local frag_shad = [[
uniform sampler2D tex0,tex1;
uniform float alpha;
uniform int mode;
in vec2 f_tc;
void main()
{
	
	vec4 color = texture2D(tex0,f_tc);
	vec4 colorold = texture2D(tex1,f_tc);
	//gl_FragColor = max(colorold *alpha,color);

	
	gl_FragColor = colorold * alpha + color*(1.0 - abs(alpha)); 
	//vec4 colores = (colorold-0.5)*2.0 * alpha + (color-0.5)*2.0*(1.0 - abs(alpha)); 
	//gl_FragColor = colores*0.5+0.5;
}
]]
local frag_shad3 = [[
uniform sampler2D tex0,tex1;
uniform float alpha,alpha2;
uniform int mode;
in vec2 f_tc;
void main()
{
	
	vec4 color = texture2D(tex0,f_tc);
	vec4 colorold = texture2D(tex1,f_tc);
	vec4 colormax = max(colorold *alpha,color);
	vec4 color1 = colorold * alpha + color*(1.0 - abs(alpha));
	gl_FragColor = mix(color1,colormax,alpha2);

}
]]
local frag_shad2 = [[
uniform sampler2D tex0,tex1;
uniform float alpha;
uniform int mode;
in vec2 f_tc;
void main()
{
	
	vec4 color = texture2D(tex0,f_tc);
	vec4 colorold = texture2D(tex1,f_tc);
	
	//gl_FragColor = mix(colorold * alpha,color,color.a);
	
	vec4 mix = colorold * alpha;// + color;
	vec4 colormax = max(mix,color);
	gl_FragColor = colormax;
}
]]

local M = {}
function M.make(GL)
	
	local Clip = {}
	local NM = GL:Dialog("mblur",
{
{"alpha",0.0,guitypes.val,{min=0.0,max=1}},
{"alpha2",0,guitypes.val,{min=0,max=1}},
{"mode",1,guitypes.valint,{min=1,max=3}},
{"reset",false,guitypes.toggle},
}
)
	Clip.NM = NM
	local program
	local fbo
	local mixfbos = {}
	local mixindex = 0
	local quads = {}
	function Clip:init()
		fbo = GL:initFBO()
		mixfbos[0] = GL:initFBO()
		mixfbos[1] = GL:initFBO()
		program = {}
		program[1] = GLSL:new():compile(vert_shad,frag_shad);
		program[2] = GLSL:new():compile(vert_shad,frag_shad2);
		program[3] = GLSL:new():compile(vert_shad,frag_shad3);
		for i=1,3 do
			quads[i] = mesh.quad():vao(program[i])
		end
		Clip.inited = true
	end



	function Clip:draw(timebegin,w,h,args)

		if not self.inited then self:init() end
		
		--alpha = math.pow(alpha,GL.fps/GL.FPS.fpsec)
		plugin.get_args(NM, args, timebegin)
		local theclip = args.clip

		local old_framebuffer = fbo:Bind()
		theclip[1]:draw(timebegin, w, h, theclip)
		
		local program = program[NM.mode]

		program:use()
		mixindex = (mixindex + 1)%2
		mixfbos[mixindex]:Bind()
		
		fbo:UseTexture()
		mixindex = (mixindex + 1)%2
		mixfbos[mixindex]:UseTexture(1,0)
		
		local alpha = NM.alpha
		if NM.reset then
			alpha = 0
			NM.vars.reset[0] = false
		end
		program.unif.tex0:set{0}
		program.unif.tex1:set{1}
		program.unif.alpha:set{alpha}
		program.unif.alpha2:set{NM.alpha2}

		gl.glClearColor(0.0, 0.0, 0.0, 0)
		ut.Clear()

		quads[NM.mode]:draw_elm()

		mixindex = (mixindex + 1)%2
		
		fbo:UnBind()
		ut.Clear()
		mixfbos[mixindex]:tex():drawcenter(w,h)
		

	end
	GL:add_plugin(Clip)
	return Clip
end
return M