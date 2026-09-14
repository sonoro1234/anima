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
out vec4 fcolor;
void main()
{
	
	vec4 color = texture2D(tex0,f_tc);
	vec4 colorold = texture2D(tex1,f_tc);
	fcolor = colorold * alpha + color*(1.0 - abs(alpha)); 
}
]]
local frag_shad3 = [[
uniform sampler2D tex0,tex1;
uniform float alpha,mixfac;
uniform int mode;
in vec2 f_tc;
out vec4 fcolor;
void main()
{
	
	vec4 color = texture2D(tex0,f_tc);
	vec4 colorold = texture2D(tex1,f_tc);
	vec4 colormax = max(colorold *alpha,color);
	vec4 color1 = colorold * alpha + color*(1.0 - abs(alpha));
	fcolor = mix(color1,colormax,mixfac);
}
]]
local frag_shad2 = [[
uniform sampler2D tex0,tex1;
uniform float alpha;
uniform int mode;
in vec2 f_tc;
out vec4 fcolor;
void main()
{
	
	vec4 color = texture2D(tex0,f_tc);
	vec4 colorold = texture2D(tex1,f_tc);
	vec4 mix1 = colorold * alpha;
	vec4 colormax = max(mix1,color);
	fcolor = colormax;
}
]]

local M = {}
function M.make(GL,args)
	args = args or {}
	local plugin = require"anima.plugins.plugin"
	local Clip = plugin.new{res={args.W or GL.W,args.H or GL.H}}
	local NM = GL:Dialog("mblur",
{
{"time",0.0,guitypes.drag,{min=0.0,max=100}},
{"mixfac",0,guitypes.val,{min=0,max=1}},
{"mode",1,guitypes.valint,{min=1,max=3}},
{"reset",false,guitypes.toggle},
},
function(this)
	ig.TextUnformatted(tostring(math.pow(1/256,1/(GL.fps*this.time))))
end)
	Clip.NM = NM
	local program
	local fbo
	local mixfbos = {}
	local mixindex = 0
	local quads = {}
	function Clip:init()
		fbo = GL:initFBO()
		mixfbos[0] = GL:initFBO({no_depth=true},args.W,args.H)
		mixfbos[1] = GL:initFBO({no_depth=true},args.W,args.H)
		program = {}
		program[1] = GLSL:new():compile(vert_shad,frag_shad);
		program[2] = GLSL:new():compile(vert_shad,frag_shad2);
		program[3] = GLSL:new():compile(vert_shad,frag_shad3);
		for i=1,3 do
			quads[i] = mesh.quad():vao(program[i])
		end
		Clip.inited = true
	end
	function Clip:process(texture,w,h)
		--print(w , self.res[1], h , self.res[2])
		w,h = w or self.res[1], h or self.res[2]
		gl.glViewport(0,0,w, h)
		local program = program[NM.mode]
		program:use()
		mixindex = (mixindex + 1)%2
		mixfbos[mixindex]:Bind()
		
		--fbo:UseTexture()
		texture:Bind()
		mixindex = (mixindex + 1)%2
		mixfbos[mixindex]:UseTexture(1,0)
		
		local alpha = math.pow(1/256,1/(GL.fps*NM.time))
		if NM.reset then
			alpha = 0
			NM.vars.reset[0] = false
		end
		program.unif.tex0:set{0}
		program.unif.tex1:set{1}
		program.unif.alpha:set{alpha}
		program.unif.mixfac:set{NM.mixfac}

		gl.glClearColor(0.0, 0.0, 0.0, 0)
		ut.Clear()

		quads[NM.mode]:draw_elm()

		mixindex = (mixindex + 1)%2
		mixfbos[mixindex]:UnBind()
		--fbo:UnBind()
		ut.Clear()
		mixfbos[mixindex]:tex():drawcenter(w,h)

	end
	function Clip:draw(timebegin,w,h,args)

		if not self.inited then self:init() end
		
		--alpha = math.pow(alpha,GL.fps/GL.FPS.fpsec)
		plugin.get_args(NM, args, timebegin)
		local theclip = args.clip

		local old_framebuffer = fbo:Bind()
		--print("mblurrrr",old_framebuffer, fbo.old_framebuffer)
		theclip[1]:draw(timebegin, w, h, theclip)
		fbo:UnBind()

		local program = program[NM.mode]

		program:use()
		mixindex = (mixindex + 1)%2
		mixfbos[mixindex]:Bind()
		
		fbo:UseTexture()
		mixindex = (mixindex + 1)%2
		mixfbos[mixindex]:UseTexture(1,0)
		

		local alpha = math.pow(1/256,1/(GL.fps*NM.time))
		if NM.reset then
			alpha = 0
			NM.vars.reset[0] = false
		end
		program.unif.tex0:set{0}
		program.unif.tex1:set{1}
		program.unif.alpha:set{alpha}
		program.unif.mixfac:set{NM.mixfac}

		gl.glClearColor(0.0, 0.0, 0.0, 0)
		gl.glViewport(0,0,w, h)
		ut.Clear()

		quads[NM.mode]:draw_elm()

		mixindex = (mixindex + 1)%2
		
		--fbo:UnBind()
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER,old_framebuffer);
		ut.Clear()
		mixfbos[mixindex]:tex():drawcenter(w,h)
		
	end
	GL:add_plugin(Clip)
	return Clip
end

if not ... then
local vert_sh = [[

in vec3 position;
uniform mat4 MVP;
uniform mat4 MO;
void main()
{

	gl_Position = MVP*MO*vec4(position,1);
}
]]
local frag_sh=[[

uniform vec4 color;
out vec4 fcolor;
void main()
{
	fcolor = vec4(color);
}
]]
require"anima"
local GL = GLcanvas{H=800,aspect = 3/2,fps=25}

local program,vao
local mblur,fbo
function GL.init()
	mblur = M.make(GL)
	mblur.NM.vars.time[0] = 2
	program = GLSL:new():compile(vert_sh, frag_sh)
	local quad = mesh.quad() -- -0.5,-0.5,0.5,0.5)
	vao = quad:vao(program)
	fbo = GL:initFBO()
end

function GL.draw(t,w,h)
	fbo:Bind()
	gl.glViewport(0,0,w,h)
	ut.Clear()
	program:use()
	local U = program.unif
	local MVP = mat.ortho(-0.5*GL.aspect, 0.5*GL.aspect,-0.5, 0.5, -10, 100000);
	U.MVP:set(MVP.gl)
	local MO = mat.translate(0,0.3,0)*mat.scale(0.1)
	-- two giros per second
	MO = mat.rotate_axis(t*math.pi,mat.vec3(0,0,1)) * MO
	U.MO:set(MO.gl)
	U.color:set{0.6,0.4,0,1}
	vao:draw_elm()
	fbo:UnBind()
	mblur:process(fbo:tex(),w,h)
end
GL:start()
end


return M