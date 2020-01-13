
local sphere_point_to_texcoords = [[
const float PI = 3.141592653589793;
//from world position skybox to texture
vec2 sphere_point_to_texcoords(vec3 pos)
{
	//radius is 0.5
	vec3 npos = normalize(pos);
	float phi = asin(npos.y);
	float theta = atan(npos.x,-npos.z);
	vec2 coor = vec2(0.5*theta/PI,phi/PI);
	coor = coor + vec2(0.5);
	vec4 tcoor = gl_TextureMatrix[0] * vec4(coor.x*2,coor.y*2,0,1);
	return tcoor.xy/tcoor.w;
}

]]
local vert_sh = [[
#version 330
const float PI = 3.141592653589793;
//from (-0.5 to 0.5)
vec3 sphere(vec2 coor)
{
	float phi = coor.y * PI;
    float theta = coor.x * 2 * PI;
	vec3 xyz;
    xyz.z = -cos(theta) * cos(phi);
    xyz.x = sin(theta) * cos(phi);
    xyz.y = sin(phi);
	return xyz*0.5;

}
uniform float morph_fac;
in vec2 texc;

uniform mat4 MM = mat4(1);

void main()
{
	
	vec2 texc_pos = texc - vec2(0.5);

	vec3 position1 = vec3(texc_pos,0);
	vec3 position2 = sphere(texc_pos);
	vec3 position = mix(position1,position2,morph_fac);

	vec4 point = MM * vec4(position,1.0);	

	gl_TexCoord[0] = gl_TextureMatrix[0] * vec4(texc.x*2,texc.y*2,0,1);
	gl_Position = gl_ModelViewProjectionMatrix * point;

}

]]



local frag_sh = [[
#version 330
uniform sampler2D tex;
void main()
{ 
	gl_FragColor = texture2D(tex,gl_TexCoord[0].st);
}
]]
local function make(GL,name)
	name = name or "skybox"
local SK = {sphere_point_to_texcoords=sphere_point_to_texcoords}
local glmatrix = require"anima.glmatrix"
local par_shapes = require"par_shapes"

local NM = GL:Dialog(name,{
	{"morph_fac",1,guitypes.val,{min=0,max=1}},
	{"scale",3.1,guitypes.val,{min=0.5,max=20}},
	{"texscale",0.666,guitypes.val,{min=0.5,max=2}},
	{"texscale2",0.8,guitypes.val,{min=0.5,max=2}},
	})
SK.NM = NM
function SK:init(args)
	args = args or {}
	local slices = 30
	self.fbo = GL:initFBO()
	self.camera = args.camera or newCamera(GL,true)
	local mesh1 = par_shapes.create.plane(slices,slices)
	self.program = GLSL:new():compile(vert_sh,frag_sh)
	self.vao1 = VAO({texc=mesh1.tcoords},self.program, mesh1.triangles,{texc=mesh1.npoints*2},mesh1.ntriangles*3)
	self.vao1:UnBind()
	print(ffi.typeof(mesh1),ffi.typeof(mesh1.tcoords),ffi.sizeof(mesh1.tcoords))
	print("camara:GetHeightForZ(3)",self.camera:GetHeightForZ(self.camera.NMC.dist))
	self.NM.vars.scale[0] = (self.camera:GetHeightForZ(self.camera.NMC.dist)*2.05)
	self.inited = true
end
local function mix(a,b,fac)
	return a * (1-fac) + b * fac
end
function SK:draw(t,w,h,args)

	if not self.inited then self:init() end
	
	if not args.textura then
	local theclip = args.clip
	if theclip[1].isTex2D then
		--theclip[1]:set_wrap(glc.GL_CLAMP)
		theclip[1]:Bind()
	else
		local old_framebuffer = self.fbo:Bind()
		
		ut.Clear()
		theclip[1]:draw(t, w, h,theclip)
		
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer);
		self.fbo:UseTexture()
	end
	end
	--gl.glFrontFace(glc.GL_CW);
	--gl.glCullFace(glc.GL_BACK); --GL_FRONT_AND_BACK
	--gl.glEnable(glc.GL_CULL_FACE); 
	--gl.glCullFace(glc.GL_BACK); 
	--gl.glEnable(glc.GL_CULL_FACE); 

	args.camera = args.camera or self.camera

	local MM = glmatrix.scale_mat(NM.scale)

	self.program:use()
	self.program.unif.tex:set{0}
	self.program.unif.MM:set(MM:table())
	
	if args.textura then
	--args.textura:set_wrap(glc.GL_CLAMP)
	args.textura:Bind()
	end
	
	self.program.unif.morph_fac:set{NM.morph_fac}

	args.camera:Set()

	gl.glMatrixMode(glc.GL_TEXTURE);
	gl.glLoadIdentity();
	gl.glTranslated(-0.5,-0.5, 0);
	gl.glTranslated(1,1, 0);
	--gl.glScaled(mix(NM.texscale,1,NM.morph_fac),1,1)
	--gl.glScaled(mix(NM.texscale,NM.texscale2,NM.morph_fac),1,1)
	gl.glScaled(mix(NM.texscale,1,NM.morph_fac),mix(NM.texscale2,1,1-NM.morph_fac),1)
	gl.glTranslated(-1,-1, 0);

	ut.Clear()
	self.vao1:draw_elm()
	
	--gl.glDisable(glc.GL_CULL_FACE); 
	--self.vao1:draw(glc.GL_POINTS,32*32)
	--self.vao1:draw_mesh()
end
	return SK
end
--[=[
require"anima"
GL = GLcanvas{fps=60,aspect=1.5,H=700}
local SK = make(GL)
local textura
function GL.init()

	camara = newCamera(GL,"tps")
	camara.NMC.vars.distfac[0] = 1
	camara.NMC.vars.focal[0] = 50
	
	--textura = Texture():Load[[C:\Users\Carmen\Desktop\humanoides f\ajetreo\ajetreo-001.jpg]]
	--textura = Texture():Load[[C:\luaGL\media\juncos.tif]]
	--textura = Texture():Load[[C:\luaGL\media\estanque-001.jpg]]
	--textura = Texture():Load[[C:\luaGL\media\estanque-002.jpg]]
	textura = GL:Texture():Load[[C:\luaGL\media\estanque7.jpg]]
	SK:init({camera=camara})
end
function GL.draw(t,w,h)
	SK:draw(t,w,h,{textura=textura,camera=camara})
end

GL:start()
--]=]

return make