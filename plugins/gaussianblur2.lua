
local generator = require"anima.plugins.generate_gaussian_kernel"
local plugin = require"anima.plugins.plugin"
local vert_std = [[
void main()
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = ftransform();
}
]]
local frag_std = [[
uniform sampler2D tex0;
void main()
{
	gl_FragColor = texture2D(tex0,gl_TexCoord[0].st);
}
]]


local function BlurClipMaker(GL,args)
	local Clip = {}
	Clip.size = type(args)=="table" and args.size or args or 2
	Clip.size = math.floor(Clip.size)
	local eps = type(args)=="table" and args.eps or 0.02
	local ANCHO,ALTO = GL.W,GL.H
	local NM = GL:Dialog("blur",
	{{"iters",type(args)=="table" and args.iters or 1,guitypes.valint,{min=0,max=10}},
	{"mixfac",1,guitypes.val,{min=0,max=1}},
	{"size",Clip.size,guitypes.valint,{min=2,max=25}},
	{"eps",eps,guitypes.drag,{min=0.001,max=0.8},function() Clip:compile() end}
	})
	Clip.NM = NM
	local programH, programV,programstd
	local mixfbos = {}
	local fbo
	function Clip:compile()
		print("Clip:compile",Clip.size)
		local fragH, fragV = generator(Clip.size*4-1,NM.eps)
		programH = GLSL:new():compile(vert_std,fragH);
		programV = GLSL:new():compile(vert_std,fragV);
	end
	function Clip.init()
		print"gaussianblur2 init"
		Clip:compile()
		programstd = GLSL:new():compile(vert_std,frag_std);
		mixfbos[0] = initFBO(ANCHO,ALTO)
		mixfbos[1] = initFBO(ANCHO,ALTO)
		Clip.inited = true
	end
	function Clip:Setsize(n)
		n = math.floor(n)
		if n~=Clip.size then
			Clip.size = n
			NM.vars.size[0] = n
			self:compile()
		end
	end

	function Clip:draw(timebegin,w,h,args)
		if not self.inited then self.init() end
		
		plugin.get_args(NM, args, timebegin)
		local theclip = args.clip
		Clip:Setsize(NM.size)

		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		mixfbos[0]:Bind()
		
		theclip[1]:draw(timebegin, w, h,theclip)

		for i=1,NM.iters do
			programH:use()
			mixfbos[1]:Bind()
			mixfbos[0]:UseTexture(0)
			
			programH.unif.uTex0:set{0}
			programH.unif.w:set{w}
			programH.unif.mixfac:set{NM.mixfac}
			
			gl.glClearColor(0.0, 0.0, 0.0, 0)
			ut.Clear()
			ut.project(ANCHO,ALTO)
			ut.DoQuad(w,h)
			
			programV:use();
			mixfbos[0]:Bind()
			mixfbos[1]:UseTexture(0)
			
			programV.unif.uTex0:set{0}
			programV.unif.h:set{h}
			programV.unif.mixfac:set{NM.mixfac}
			
			gl.glClearColor(0.0, 0.0, 0.0, 0)
			ut.Clear()
			ut.project(ANCHO,ALTO)
			ut.DoQuad(w,h)
		end
		
		programstd:use()
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
		
		mixfbos[0]:UseTexture(0)
		
		programstd.unif.tex0:set{0}
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		ut.Clear()
		ut.project(ANCHO, ALTO)
		ut.DoQuad(w,h)
	end
	
	GL:add_plugin(Clip)
	return Clip
end

--[=[
require"anima"
local GL = GLcanvas{H=1080,aspect=2/3}
local blur = BlurClipMaker(GL,{size=2})
-- local blur = require"anima.plugins.gaussianblur"(GL)
local LM = require"anima.plugins.layermixer_blend"
local themixer = LM.layers_mixer(GL,true)
local tex
function GL.init()
	tex = GL:Texture():Load[[C:\luaGL\frames_anima\7thDoor\puertas\_MG_4250.tif]]
	--cliplist = LM.layers_seq:new({{0,200,clip={blur,clip={tex}}}} )
end
function GL.draw(t,w,h)
	blur:draw(t,w,h,{clip={tex}})
	-- themixer:draw(t,w,h,{animclips=cliplist})
end
GL:start()
--]=]
return BlurClipMaker