
local plugin = require"anima.plugins.plugin"

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
uniform float w,h;
uniform float time;
uniform float perlinfac = 0.01;
uniform float spacefac = 0.01;
void main()
{
	
	vec2 pos = vec2(gl_FragCoord.x/w,gl_FragCoord.y/h);
	float delta = snoise(vec3(pos*spacefac,time));

	vec4 color = texture2D(tex0,pos + delta*perlinfac);
	gl_FragColor = color; 
}
]]

local frag_shad = [[

uniform sampler2D tex0;
uniform float w,h;
uniform float time;
uniform float perlinfac = 0.01;
uniform float spacefac = 0.01;
uniform float spacefacX = 0.01;
uniform float offdelta = 4.0;
void main()
{

	vec2 pos = vec2(gl_FragCoord.x/w,gl_FragCoord.y/h);
	//vec2 perlinpos = ((pos - 0.5)*spacefac) + 0.5;
	vec2 perlinpos = ((pos - 0.5)*vec2(spacefac,spacefac*spacefacX)) + 0.5;
	float delta = snoise(vec3(perlinpos,time));
	float delta2 = snoise(vec3(perlinpos,time + offdelta));
	//vec4 color = texture2D(tex0,pos + vec2(delta,delta2*0.0)*perlinfac);
	vec4 color = texture2D(tex0,pos + vec2(delta,delta2)*perlinfac);
	gl_FragColor = color; 
}
]]
GLSL_perlin = require"anima.GLSL.GLSL_perlin"
frag_shad = "#version 120\n" .. GLSL_perlin..frag_shad

local M = {}

function M.make(GL)
	local NM = GL:Dialog("liquid",
{
{"perlinfac",0.004,guitypes.drag,{min=0,max=1}},
{"timefac",0.4,guitypes.val,{min=0,max=2}},
{"spacefac",3,guitypes.val,{min=0,max=10}},
{"spacefacX",1,guitypes.val,{min=0,max=10}},
{"offdelta",3,guitypes.val,{min=0,max=10}},
})
	local plugin = require"anima.plugins.plugin"
	local LM = plugin.new{res={GL.W,GL.H},NM=NM}
	local fbo, programfx
	local lapse,oldtime,lapsesum = 0,0,0
	function LM.init()
		--if not GL.PPFBO then GL:init_PPFBO() end
		fbo = initFBO(GL.W,GL.H)
		programfx = GLSL:new():compile(vert_shad,frag_shad)
		local m = mesh.Quad(-1,-1,1,1)
		LM.vao = VAO({Position=m.points,texcoords = m.texcoords},programfx,m.indexes)
		LM.inited = true
	end
	
	local function get_args(t, timev)
		local clip = t.clip
		local perlinfac = ut.get_var(t.perlinfac,timev,NM.perlinfac)
		local timefac = ut.get_var(t.timefac,timev,NM.timefac)
		return clip,perlinfac,timefac
	end
	function LM:process(srctex,w,h)
		w,h = w or self.res[1], h or self.res[2]
		
		srctex:Bind()
		
		programfx:use()
		programfx.unif.tex0:set{0}
		programfx.unif.w:set{w}
		programfx.unif.h:set{h}
		programfx.unif.time:set{GL:get_time()*NM.timefac} --uses global time for effect
		programfx.unif.perlinfac:set{NM.perlinfac}
		programfx.unif.spacefac:set{NM.spacefac}
		programfx.unif.spacefacX:set{NM.spacefacX}
		programfx.unif.offdelta:set{NM.offdelta}
		
		gl.glViewport(0,0,w,h)
		ut.Clear()
		self.vao:draw_elm()
		
	end
	function LM:draw(timebegin, w, h, args)
		if not self.inited then self.init() end
		--local theclip,perlinfac,timefac = get_args(args, timebegin)
		plugin.get_args(NM, args, timebegin)
		local theclip = args.clip
		
		--local fbo = GL.PPFBO:getDRAW()
		fbo:Bind()

		theclip[1]:draw(timebegin, w, h,theclip)
		
		fbo:UnBind()
		fbo:GetTexture():Bind()

		
		programfx:use()
		programfx.unif.tex0:set{0}
		programfx.unif.w:set{w}
		programfx.unif.h:set{h}
		programfx.unif.time:set{GL:get_time()*NM.timefac} --uses global time for effect
		
		for k,v in pairs(NM.vars) do
			if programfx.unif[k] then
				programfx.unif[k]:set{NM[k]}
			end
		end	
		
		-- programfx.unif.perlinfac:set{NM.perlinfac}
		-- programfx.unif.spacefac:set{NM.spacefac}
		-- programfx.unif.spacefacX:set{NM.spacefacX}
		-- programfx.unif.offdelta:set{NM.offdelta}
		
		gl.glViewport(0,0,w,h)
		ut.Clear()
		self.vao:draw_elm()

	end
	GL:add_plugin(LM)
	return LM
end
--alias
M.liquid = M.make
--test
--[=[
require"anima"
GL = GLcanvas{fps=25,H=700,aspect=3/2}
liquid = M.make(GL)
function GL.init()
	textura = Texture():Load([[C:\luagl\animacion\resonator6\resonator-001.jpg]])
end
function GL.draw(t,w,h)
	ut.Clear()
	liquid:draw(t,w,h,{clip={textura}})
end
GL:start()
--]=]

return M


