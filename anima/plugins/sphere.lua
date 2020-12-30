require"anima"
local glmatrix = require"anima.glmatrix"

--refract
local vert_shadrefr = [[
#version 120
varying float lfac;
uniform float distpl = 0;
void main()
{
	vec4 point = gl_Vertex;
	vec3 lightdir = normalize(vec3(1,0,-1));

	vec4 normal = vec4(gl_Normal,1);

	normal = gl_ModelViewMatrixInverseTranspose * normal;
	
	vec3 normal3 = normal.xyz/normal.w;
	
	lfac = dot(normal3,-lightdir);
	vec4 v_dir_w = (gl_ModelViewMatrix * point);
	vec3 v_dir = v_dir_w.xyz/v_dir_w.w;
	vec3 ref_dir = refract(normalize(v_dir),normal3,0.98);
	
	vec4 ref_dir_i = gl_ModelViewMatrixInverse * vec4(ref_dir,1.0);
	vec3 npl = vec3(0.0, 0.0, 1.0);
	vec3 a = point.xyz/point.w;
	vec3 r = ref_dir_i.xyz/ref_dir_i.w;
	float lambda = (distpl - dot(npl,a))/dot(npl,r);
	
	gl_TexCoord[0] = gl_TextureMatrix[0]*vec4(a + lambda*r,1.0);
	
	gl_FrontColor = gl_Color*lfac;
	gl_Position = gl_ModelViewProjectionMatrix * point;
}

]]

local vert_shadrefr = [[
#version 120

uniform float distpl = 0;
uniform float refrac;
uniform mat4 MM;
void main()
{
	vec4 point = MM*gl_Vertex;

	vec3 normal3 = normalize(gl_NormalMatrix * gl_Normal);
	
	vec4 v_dir_w = (gl_ModelViewMatrix * point);
	vec3 v_dir = v_dir_w.xyz/v_dir_w.w;
	vec3 ref_dir = refract(normalize(v_dir),normal3,refrac);
	ref_dir = normalize(ref_dir);
	
	//move plane vector to eye position
	vec4 npl4 = gl_ModelViewMatrixInverseTranspose * vec4(0.0, 0.0, 1.0,-distpl);

	vec3 a = v_dir;
	vec3 r = ref_dir; 
	//float lambda = (-distpl - dot(npl,a))/dot(npl,r);
	float lambda =  - dot(npl4,vec4(a,1))/dot(npl4.xyz,r);
	
	//move intesection point to world position
	gl_TexCoord[0] = gl_TextureMatrix[0]*gl_ModelViewMatrixInverse*vec4(a + lambda*r,1.0);


	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * point;
}

]]

local vert_shadrefr2 = [[
#version 120

uniform float distpl = 0;
uniform float refrac;
uniform mat4 MM;
in vec3 position;
void main()
{
	vec4 point = MM*vec4(position,1);

	vec3 normal3 = normalize(position);
	normal3 = normalize(gl_NormalMatrix * normal3);
	
	vec4 v_dir_w = (gl_ModelViewMatrix * point);
	vec3 v_dir = v_dir_w.xyz/v_dir_w.w;
	vec3 ref_dir = refract(normalize(v_dir),normal3,refrac);
	ref_dir = normalize(ref_dir);
	
	//move plane vector to eye position
	vec4 npl4 = gl_ModelViewMatrixInverseTranspose * vec4(0.0, 0.0, 1.0,-distpl);

	vec3 a = v_dir;
	vec3 r = ref_dir; 
	//float lambda = (-distpl - dot(npl,a))/dot(npl,r);
	float lambda =  - dot(npl4,vec4(a,1))/dot(npl4.xyz,r);
	
	//move intesection point to world position
	gl_TexCoord[0] = gl_TextureMatrix[0]*gl_ModelViewMatrixInverse*vec4(a + lambda*r,1.0);


	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * point;
}

]]

local frag_shadrefr = [[
#version 120
uniform sampler2D tex0;
void main()
{
  gl_FragColor = texture2D(tex0,gl_TexCoord[0].st);
}
]]

local vert_std = [[
#version 120
uniform mat4 MM = mat4(1.0) ;//identity
void main()
{
	vec4 point = MM * gl_Vertex;
	gl_TexCoord[0] = gl_TextureMatrix[0] * point;
	gl_Position = gl_ModelViewProjectionMatrix * point;
}

]]
local frag_std = [[
#version 120
uniform sampler2D tex0;

void main()
{
  vec4 color = texture2D(tex0,gl_TexCoord[0].st);
  gl_FragColor = color ;
}
]]


local ES = {}
function ES.make(GL)
	local Clip = {}
	local NM = GL:Dialog("sphere",
{
{"radio",0.5,guitypes.val,{min=0,max=2}},
{"centerX",0,guitypes.val,{min=-2,max=2}},
{"centerZ",0,guitypes.dial,{min=-5,max=5}},
{"refrac",0.87,guitypes.val,{min=0,max=2}},
{"distpl",-4.1,guitypes.dial,{min=-5,max=5}},
})
	function Clip:init()
		--textura = Texture():Load[[C:\luajitbin2.0.2-copia\animacion\resonator6\resonator-038.jpg]]
		self.fbo = GL:initFBO()
		self.camera = newCamera(GL,true,"sphere ")
		-- program = GLSL:new():compile(vert_shadrefr,frag_shadrefr);
		program = GLSL:new():compile(vert_shadrefr2,frag_shadrefr);
		programstd = GLSL:new():compile(vert_std,frag_std);
		
		local par_shapes = require"par_shapes"
		local mesh1 = par_shapes.create.subdivided_sphere(3)
		self.sphere_vao = VAO({position=mesh1.points},program, mesh1.triangles,{position=mesh1.npoints*3},mesh1.ntriangles*3)
		
		self.inited = true
	end

	local function get_args(t, timev)
		local clip = t.clip
		local distpl = ut.get_var(t.distpl,timev,NM.distpl)
		local refrac = ut.get_var(t.refrac,timev,NM.refrac)
		local centerX = ut.get_var(t.centerX,timev,NM.centerX)
		local centerZ = ut.get_var(t.centerZ,timev,NM.centerZ)
		local radio = ut.get_var(t.radio,timev,NM.radio)
		local camara = ut.get_var(t.camara,timev,Clip.camera)
		return clip,distpl,refrac,centerX,centerZ,radio,camara
	end


	function Clip:draw(tim,w,h,args)
		if not self.inited then self:init() end
		local theclip,distpl,refrac,centerX,centerZ,radio,camara = get_args(args,tim)
		
		if theclip[1].isTex2D then
			theclip[1]:set_wrap(glc.GL_CLAMP)
			theclip[1]:Bind()
		else
			local old_framebuffer = self.fbo:Bind()
			
			ut.Clear()
			theclip[1]:draw(tim, w, h,theclip)
			
			glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer);
			self.fbo:UseTexture()
		end
		-----------
		--gl.glEnable(glc.GL_CULL_FACE)
		--gl.glCullFace(glc.GL_FRONT)
		camara:Set()
		
		gl.glMatrixMode(glc.GL_TEXTURE);
		gl.glLoadIdentity();
		gl.glTranslated(0.5, 0.5, 0);
		gl.glScaled(1/GL.aspect,1,1)
		
		if true then
			programstd:use()
			programstd.unif.tex0:set{0}
			
			gl.glClearColor(0.0, 0, 0, 0)
			ut.Clear()
			
			local modmat = glmatrix.translate_mat(-1.5/2,-1/2,distpl)
			programstd.unif.MM:set(modmat:table())

			ut.DoQuad(1.5,1)
		end
		
		program:use()
		program.unif.tex0:set{0}
		program.unif.distpl:set{distpl}
		program.unif.refrac:set{refrac}
	
		
		local modmat2 = glmatrix.scale_mat(NM.radio)
		modmat2 = modmat2:translate(centerX,0,centerZ)
		program.unif.MM:set(modmat2:table())

		-- ut.drawsphere(3,1)
		self.sphere_vao:draw_elm()
		
		gl.glMatrixMode(glc.GL_TEXTURE);
		gl.glLoadIdentity();
	end
	return Clip
end

--[=[
--test

GL = GLcanvas{fps=250,RENDERINI=0,RENDEREND=208,H=700,aspect = 1.5}
function GL.init()
	textura2 = GL:Texture():Load([[C:\luaGL\media\fandema1.tif]])
	theplug = ES.make(GL)
end
function GL.draw(t,w,h)
	ut.Clear()
	theplug:draw(t,w,h,{clip={textura2}})
	--show_tex:draw(t,w,h,{texture=textura2.tex})
	--textura2:draw(t,w,h)
end
GL:start()
--]=]
return ES