--most cant be used in core profile
local M = {}
function M.get_arg(var , timev)
	if type(var)=="table" then
		if(var.is_pointer) then
			return var[0]
		elseif var.is_animatable then
			return var:dofunc(timev)
		else
			return var
		end
	elseif type(var)=="function" then
		return var(timev)
	elseif(ffi.istype("float[1]",var) or ffi.istype("double[1]",var) or ffi.istype("int[1]",var) or ffi.istype("bool[1]",var)) then
		return var[0]
	else
		return var
	end
end
function M.get_var(var , timev, default)
	--default = default~=nil and 0
	if var == nil then
		return default
	elseif type(var)=="table" then
		if(var.is_pointer) then
			return var[0]
		elseif var.is_animatable then
			return var:dofunc(timev)
		else
			return var
		end
	elseif type(var)=="function" then
		return var(timev)
	else
		if(ffi.istype("float[1]",var) or ffi.istype("double[1]",var) or ffi.istype("int[1]",var)) then
			return var[0]
		end
		return var
	end
end
function M.DoQuadN(w, h,zplane)
	zplane = zplane or 0
	gl.glBegin(glc.GL_QUADS)
	gl.glColor4f(1,1,1,1)
	gl.glNormal3f(0, 0,1);
	gl.glVertex3f(0,0,zplane)
	gl.glNormal3f(0, 0,1);
	gl.glVertex3f(0, h ,zplane)
	gl.glNormal3f(0, 0,1);
	gl.glVertex3f(w, h, zplane)
	gl.glNormal3f(0, 0,1);
	gl.glVertex3f(w, 0,zplane)
	gl.glEnd()
end
function M.DoQuad(w, h,zplane)
	zplane = zplane or 0
	gl.glBegin(glc.GL_QUADS)
	--gl.glColor4f(1,1,1,1)
	gl.glTexCoord2f(0, 0);
	gl.glVertex3f(0,0,zplane)
	gl.glTexCoord2f(0 , 1 );
	gl.glVertex3f(0, h ,zplane)
	gl.glTexCoord2f(1, 1 );
	gl.glVertex3f(w, h, zplane)
	gl.glTexCoord2f(1, 0);
	gl.glVertex3f(w, 0,zplane)
	gl.glEnd()
end
function M.DoQuadPos(x,y,w, h,zplane)
	zplane = zplane or 0
	gl.glBegin(glc.GL_QUADS)
	--gl.glColor4f(1,1,1,1)
	gl.glTexCoord2f(0, 0);
	gl.glVertex3f(x,y,zplane)
	gl.glTexCoord2f(0 , 1 );
	gl.glVertex3f(x, y+h ,zplane)
	gl.glTexCoord2f(1, 1 );
	gl.glVertex3f(x+w,y + h, zplane)
	gl.glTexCoord2f(1, 0);
	gl.glVertex3f(x + w, y,zplane)
	gl.glEnd()
end
function M.DoQuadC(w, h,zplane)
	zplane = zplane or 0
	gl.glBegin(glc.GL_QUADS)
	--gl.glColor4f(1,1,1,1)
	gl.glTexCoord2f(0, 0);
	gl.glNormal3f(0, 0,1);
	gl.glVertex3f(-w*0.5,-h*0.5,zplane)
	gl.glTexCoord2f(0 , 1 );
	gl.glNormal3f(0, 0,1);
	gl.glVertex3f(-w*0.5, h*0.5 ,zplane)
	gl.glTexCoord2f(1, 1 );
	gl.glNormal3f(0, 0,1);
	gl.glVertex3f(w*0.5, h*0.5, zplane)
	gl.glTexCoord2f(1, 0);
	gl.glNormal3f(0, 0,1);
	gl.glVertex3f(w*0.5, -h*0.5,zplane)
	gl.glEnd()
end
--renders srgb only if screen buffer
function M.SetSRGB(srgb)
	local framebuffer = ffi.new("GLint[1]",0)
	gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, framebuffer)
	if srgb and framebuffer[0]== 0 then
		gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
	end
end
function M.RGB2sRGB(val)
	if val <= 0.04045 then
		return val/12.45
	else
		local a = 0.055
		return (1 + a)*math.pow(val,1/2.4) - a
	end
end

function M.sRGB2RGB(val)
	if val <= 0.0031308 then
		return val*12.45
	else
		local a = 0.055
		return math.pow((val + a)/(1 + a),2.4)
	end
end

function M.Clear()
	gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
end
function M.ClearDepth()
	gl.glClear(glc.GL_DEPTH_BUFFER_BIT)
end
function M.project(w,h)
	gl.glMatrixMode(glc.GL_PROJECTION)
	gl.glLoadIdentity()
	gl.glOrtho(0.0, w, 0.0, h, -1, 1);
	gl.glMatrixMode(glc.GL_MODELVIEW)
	gl.glLoadIdentity();
	gl.glViewport(0, 0, w, h)
end
function M.project_pos(x,y,w,h)
	gl.glMatrixMode(glc.GL_PROJECTION)
	gl.glLoadIdentity()
	gl.glOrtho(x,x + w, y,y + h, -1, 1);
	--print("ortho",x,x + w, y,y + h, -1, 1)
	--GetGLError"otho"
	gl.glMatrixMode(glc.GL_MODELVIEW)
	gl.glLoadIdentity();
	gl.glViewport(x,y, w, h)
	--GetGLError"view"
end
function M.ortho_camera(w,h)
	gl.glMatrixMode(glc.GL_PROJECTION)
	gl.glLoadIdentity()
	gl.glOrtho(-0.5*w, 0.5*w, -0.5*h, 0.5*h, -1, 1000);
	gl.glMatrixMode(glc.GL_MODELVIEW)
	gl.glLoadIdentity();
	gl.glViewport(0, 0, w, h)
end
function M.ShowTex(tex,w,h)

	local modewrap = glc.GL_MIRRORED_REPEAT --glc.GL_CLAMP --glc.GL_REPEAT --glc.GL_MIRRORED_REPEAT
	
	glext.glActiveTexture(glc.GL_TEXTURE0);
	gl.glEnable( glc.GL_TEXTURE_2D );
	gl.glBindTexture(glc.GL_TEXTURE_2D, tex)
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
	
	M.project(w,h)
	M.DoQuad(w,h)
end
function M.ShowTexPos(tex,x,y,w,h)

	local modewrap = glc.GL_MIRRORED_REPEAT --glc.GL_CLAMP --glc.GL_REPEAT --glc.GL_MIRRORED_REPEAT
	
	glext.glActiveTexture(glc.GL_TEXTURE0);
	gl.glEnable( glc.GL_TEXTURE_2D );
	gl.glBindTexture(glc.GL_TEXTURE_2D, tex)
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
	
	M.project_pos(x,y,w,h)
	M.DoQuadPos(x,y,w,h)

end

function M.FBOReplicator()
	local repl = {}
	local program
	local vert_std = [[
	void main()
	{
		gl_TexCoord[0] = gl_MultiTexCoord0;
		gl_FrontColor = gl_Color;
		gl_Position = ftransform();
	}
	]]
	local frag_shad = [[
	uniform sampler2D tex0;

	void main()
	{
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	gl_FragColor = color;
	}
]]
	function repl:init()
		program = GLSL:new():compile(vert_std,frag_shad);
	end
	function repl:replicate(GL,srctex,dstfbo)
		if not program then self:init() end
		glext.glUseProgram(program.program)
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, dstfbo);
		glext.glActiveTexture(glc.GL_TEXTURE0);
		gl.glBindTexture(glc.GL_TEXTURE_2D, srctex)
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
			
		gl.glMatrixMode(glc.GL_PROJECTION)
		gl.glLoadIdentity()
		gl.glOrtho(0.0, GL.W, 0.0, GL.H, -1, 1);
		gl.glMatrixMode(glc.GL_MODELVIEW)
		gl.glLoadIdentity();
		gl.glViewport(0, 0, GL.W, GL.H)
		M.DoQuad(GL.W, GL.H)
	end
	return repl
end




local function drawtri(a, b, c,  div, r) 
	local function normalize(a)
		local  d = math.sqrt(a[0]*a[0]+a[1]*a[1]+a[2]*a[2]);
		a[0] = a[0]/d; a[1] = a[1]/d;a[2] = a[2]/d;
	end
    if (div<=0) then
        gl.glNormal3fv(a); gl.glVertex3f(a[0]*r, a[1]*r, a[2]*r);
        gl.glNormal3fv(b); gl.glVertex3f(b[0]*r, b[1]*r, b[2]*r);
        gl.glNormal3fv(c); gl.glVertex3f(c[0]*r, c[1]*r, c[2]*r);
    else 
        local ab, ac, bc = ffi.new("GLfloat[3]"),ffi.new("GLfloat[3]"),ffi.new("GLfloat[3]")
        for  i=0,2 do
            ab[i]=(a[i]+b[i])/2;
            ac[i]=(a[i]+c[i])/2;
            bc[i]=(b[i]+c[i])/2;
        end
        normalize(ab); normalize(ac); normalize(bc);
        drawtri(a, ab, ac, div-1, r);
        drawtri(b, bc, ab, div-1, r);
        drawtri(c, ac, bc, div-1, r);
		drawtri(ab, bc, ac, div-1, r);  --//<--Comment this line and sphere looks really cool!
    end  
end

function M.drawsphere(ndiv,radius) 
	ndiv = ndiv or 3
	radius = radius or 1
	local X = 0.525731112119133606 
	local Z = 0.850650808352039932
	local vdata = ffi.new("GLfloat[12][3]",{    
		{-X, 0.0, Z}, {X, 0.0, Z}, {-X, 0.0, -Z}, {X, 0.0, -Z},    
		{0.0, Z, X}, {0.0, Z, -X}, {0.0, -Z, X}, {0.0, -Z, -X},    
		{Z, X, 0.0}, {-Z, X, 0.0}, {Z, -X, 0.0}, {-Z, -X, 0.0} 
	})
	local tindices = ffi.new("GLfloat[20][3]",{ 
    {0,4,1}, {0,9,4}, {9,5,4}, {4,5,8}, {4,8,1},    
    {8,10,1}, {8,3,10}, {5,3,8}, {5,2,3}, {2,7,3},    
    {7,10,3}, {7,6,10}, {7,11,6}, {11,0,6}, {0,1,6}, 
    {6,1,10}, {9,0,11}, {9,11,2}, {9,2,5}, {7,2,11} })
	
    gl.glBegin(glc.GL_TRIANGLES);
    for i=0,20-1 do
        drawtri(vdata[tindices[i][0]], vdata[tindices[i][1]], vdata[tindices[i][2]], ndiv, radius);
	end
    gl.glEnd();
end
-- standart glsl program
local P = {}
function P:init()
	local vert_std = [[
	void main()
	{
		gl_TexCoord[0] = gl_MultiTexCoord0;
		gl_FrontColor = gl_Color;
		gl_Position = ftransform();
	}
	]]
	local frag_std = [[
	void main()
	{
		gl_FragColor = gl_Color;
	}
	]]
	P.prog = GLSL:new():compile(vert_std,frag_std)
	P.inited = true
end
function P:use(val)
	if not self.inited then self:init() end
	self.prog:use(val)
end
M.std_program = P

local P2 = {}
function P2:init()
	local vert_std = [[
    void main()
    {
      gl_Position = ftransform();
    }
	]]
	local frag_std = [[                                 
    uniform sampler2DRect tex;                              
    void main()                                             
    {                                                       
       gl_FragColor = texture2DRect(tex, gl_FragCoord.xy);          
             
    }
	]]
	self.prog = GLSL:new():compile(vert_std,frag_std)
	self.inited = true
end
function P2:draw(tex,w,h)
	if not self.inited then self:init() end
	glext.glUseProgram(self.prog.program)
	self.prog.unif.tex:set{0}
	gl.glEnable(glc.GL_TEXTURE_RECTANGLE);
	gl.glBindTexture(glc.GL_TEXTURE_RECTANGLE, tex);
	M.project(w,h)
	M.DoQuad(w,h)
	gl.glDisable(glc.GL_TEXTURE_RECTANGLE);
	glext.glUseProgram(0)
end
M.rect_program = P2

local P3 = {}
function P3:init()
	local vert_shad = [[

void main()
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = ftransform();
}

]]
local frag_shad = [[
uniform sampler2D tex0;
void main()
{
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	gl_FragColor = color; //vec4(color.r,0,0,1);
}
]]

	self.program = GLSL:new():compile(vert_shad,frag_shad)
	print"P3 compiled"
	self.inited = true
end
function P3:draw(tex,w,h)
--print("p3 draw") ;error()
	if not self.inited then self:init() end
	self.program:use()
	self.program.unif.tex0:set{0}
	M.ShowTex(tex,w,h)
	glext.glUseProgram(0)
end
function P3:use(val)
	if not self.inited then self:init() end
	self.program:use(val)
end
M.tex_program = P3

local P3a = {}
function P3a:init()
	local vert_shad = [[

void main()
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = ftransform();
}

]]
local frag_shad = [[
uniform sampler2D tex0;
void main()
{
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	gl_FragColor = color; //vec4(color.r,0,0,1);
}
]]

	self.program = GLSL:new():compile(vert_shad,frag_shad)
	print"P3 compiled"
	self.inited = true
end
function P3a:draw(tex,x,y,w,h)

	if not self.inited then self:init() end
	self.program:use()
	self.program.unif.tex0:set{0}
	M.ShowTexPos(tex,x,y,w,h)
	glext.glUseProgram(0)
end
function P3a:use(val)
	if not self.inited then self:init() end
	self.program:use(val)
end
M.tex_program_pos = P3a

local P4 = {}
function P4:init()
	local vert_shad = [[

void main()
{
	gl_TexCoord[0] = gl_TextureMatrix[0]*gl_ModelViewProjectionMatrix*gl_Vertex;
	gl_TexCoord[0] /= gl_TexCoord[0].w;
	gl_Position = gl_ModelViewProjectionMatrix*gl_Vertex;
}

]]
local frag_shad = [[
uniform sampler2D tex0;
uniform float alpha = 0.5;
void main()
{
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	gl_FragColor = vec4(color.xyz,alpha);
}
]]
	print"P4 compiled"
	self.program = GLSL:new():compile(vert_shad,frag_shad)
	print"P4 compiled"
	self.inited = true
end
function P4:draw(tex,w,h,alpha)
	if not self.inited then self:init() end
	glext.glUseProgram(self.program.program)
	self.program.unif.tex0:set{0}
	self.program.unif.alpha:set{alpha}
	--M.Clear()
	M.ShowTex(tex,w,h)

	glext.glUseProgram(0)
end
M.tex_alpha_program = P4
-- standart glsl program
local P5 = {}
function P5:init()
	local vert_std = [[
uniform vec3 LightPosition = vec3(0.3);
uniform float SpecularContribution = 0.3;
uniform float brightness = 1.0;
float DiffuseContribution = 1.0 - SpecularContribution;
uniform float ambient = 0.0;

float compute_light(vec4 point,vec3 normal)
{
	
	vec3 ecPosition = vec3(gl_ModelViewMatrix * point);
	
	vec3 normalvec = gl_NormalMatrix * normal;
	vec3 tnorm = normalize( normalvec);
	
	vec3 lightVec = LightPosition - ecPosition;
	//float light_dist = length(lightVec);
	float distfac = 1.0;///(1.0 + light_dist*light_dist);
	lightVec = normalize(lightVec);
	
	vec3 reflectVec = reflect(-lightVec, tnorm);
	vec3 viewVec = normalize(-ecPosition);
	//float diffuse = max(dot(lightVec, tnorm), 0.0);
	float diffuse = abs(dot(lightVec, tnorm));
	float spec = 0.0;
	//if (diffuse > 0.0){
		spec = abs(dot(reflectVec, viewVec));//, 0.0);
		spec = pow(spec, 16.0);
	//}
	float linearColor = (DiffuseContribution * diffuse + SpecularContribution * spec)*distfac + ambient;
	linearColor *= brightness;
	return pow(linearColor, 1.0/2.2);
}
	void main()
	{
		gl_TexCoord[0] = gl_MultiTexCoord0;
		gl_FrontColor = gl_Color*compute_light(gl_Vertex,gl_Normal);
		gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
	}
	]]
	local frag_std = [[
	void main()
	{
		gl_FragColor = gl_Color;
	}
	]]
	P5.prog = GLSL:new():compile(vert_std,frag_std)
	P5.inited = true
end
function P5:use(val)
	if not self.inited then self:init() end
	self.prog:use(val)
end
M.std_program_light = P5
M.vert_std = [[
	void main()
	{
		gl_TexCoord[0] = gl_MultiTexCoord0;
		gl_FrontColor = gl_Color;
		gl_Position = ftransform();
	}
	]]
return M