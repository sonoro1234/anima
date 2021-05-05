--------------------------------GLSL


local t = 
{	GL_FLOAT = {1,'glUniform1fv'},
	GL_FLOAT_VEC2 = {2,'glUniform2fv'},
	GL_FLOAT_VEC3 = {3,'glUniform3fv'},
	GL_FLOAT_VEC4 = {4,'glUniform4fv'},
	GL_INT = {1,'glUniform1iv'},
	GL_INT_VEC2 = {2,'glUniform2iv'},
	GL_INT_VEC3 = {3,'glUniform3iv'},
	GL_INT_VEC4 = {4,'glUniform4iv'},
	GL_UNSIGNED_INT = {1,'glUniform1uiv'},
	GL_UNSIGNED_INT_VEC2 = {2,'glUniform2uiv'},
	GL_UNSIGNED_INT_VEC3 = {3,'glUniform3uiv'},
	GL_UNSIGNED_INT_VEC4 = {4,'glUniform4uiv'},
	GL_BOOL = {1,'glUniform1iv'},
	GL_BOOL_VEC2 = {2,'glUniform2iv'},
	GL_BOOL_VEC3 = {3,'glUniform3iv'},
	GL_BOOL_VEC4 = {4,'glUniform4iv'},
	GL_FLOAT_MAT2 = {4,'glUniformMatrix2fv'},
	GL_FLOAT_MAT3 = {9,'glUniformMatrix3fv'},
	GL_FLOAT_MAT4 = {16,'glUniformMatrix4fv'},
	GL_FLOAT_MAT2x3 = {6,'glUniformMatrix2x3fv'},
	GL_FLOAT_MAT2x4 = {8,'glUniformMatrix2x4fv'},
	GL_FLOAT_MAT3x2 = {6,'glUniformMatrix3x2fv'},
	GL_FLOAT_MAT3x4 = {12,'glUniformMatrix3x4fv'},
	GL_FLOAT_MAT4x2 = {8,'glUniformMatrix4x2fv'},
	GL_FLOAT_MAT4x3 = {12,'glUniformMatrix4x3fv'},
	GL_SAMPLER_1D = {1,'glUniform1iv'},
	GL_SAMPLER_2D = {1,'glUniform1iv'},
	GL_SAMPLER_3D = {1,'glUniform1iv'},
	GL_SAMPLER_CUBE = {1,'glUniform1iv'},
	GL_SAMPLER_1D_SHADOW = {1,'glUniform1iv'},
	GL_SAMPLER_2D_SHADOW = {1,'glUniform1iv'},
	GL_SAMPLER_2D_RECT = {1,'glUniform1iv'},
	GL_SAMPLER_BUFFER = {1,'glUniform1iv'},
	GL_IMAGE_2D = {1,'glUniform1iv'},
	GL_IMAGE_BUFFER = {1,'glUniform1iv'},
}


print"making uniform_types -------------------------------"
local uniform_types = {}
for k,v in pairs(t) do
	uniform_types[glc[k]] = {name = k, nvalues = v[1], fname = v[2], matrix = k:match"MAT" and true}
	local a = uniform_types[glc[k]]
	a.isint = k:match"INT" or k:match"BOOL" or k:match"SAMPLER" or k:match"IMAGE"
	print(a.name,a.nvalues,a.fname,a.matrix,a.isint)
end


UniformT = {}
function UniformT:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end
function Uniform(size, tipo, loc, name)
	return UniformT:new{size = size, type = tipo, loc = loc, name = name}
end
function UniformT:strtype()
	return uniform_types[self.type].name
end
function UniformT:set(t,pad)
	if not (type(t) == "table") then
		--must be cdata
		return self:set_ffi(t)
	end
	local thistype = uniform_types[self.type]
	-- if pad then
		-- for i=#t+1,self.size * thistype.nvalues do
			-- table.insert(t,0)
		-- end
	-- end
	local buf
	if pad then
		buf = ffi.new(thistype.isint and "GLint[?]" or "GLfloat[?]",self.size * thistype.nvalues,t)
	else
		if not(#t == self.size * thistype.nvalues) then
			print(#t,self.size * thistype.nvalues,"are different",self.size)
			error(self.name.." uniform different sizes")
		end
		buf = ffi.new(thistype.isint and "GLint[?]" or "GLfloat[?]",#t,t)
	end
	
	if thistype.matrix then
		glext[thistype.fname](self.loc, self.size, false, buf)
	else
		glext[thistype.fname](self.loc, self.size, buf)
		--glext[thistype.fname](self.loc, #t, buf)
	end
	--print("uniform_set")
	--prtable(thistype,self)
end
function UniformT:set_ffi(buf)
	local thistype = uniform_types[self.type]
	if thistype.matrix then
		glext[thistype.fname](self.loc, self.size, false, buf)
	else
		glext[thistype.fname](self.loc, self.size, buf)
	end
end
----------just warns one time
local dummyUniformT = {}
function dummyUniformT:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end
function dummyUniformT:set()
	if not self.warned then
		local source = debug.getinfo(2,'Sl')
		print(source.source,source.linedefined,source.currentline)
		print(self.name,"uniform is not in program xxxxxxxxxxx")
		if GLSL.uniform_error then error[[uniform not present]] end
		self.warned = true
	else
		return
	end
end

local unif_mt = {}
unif_mt.__index = function(t,k)
			local du = dummyUniformT:new{name = k}
			rawset(t,k,du)
			return du
			end
-------------------
AttribT = {}
function AttribT:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end
function Attrib(size, tipo, loc)
	return AttribT:new{size = size, type = tipo, loc = loc, nvalues = uniform_types[tipo].nvalues}
end
function AttribT:strtype()
	return uniform_types[self.type].name
end
function AttribT:set(t)
	--local thistype = uniform_types[self.type]
	assert(#t == self.size * self.nvalues)
	--local buf = ffi.new(thistype.isint and "GLint[?]" or "GLfloat[?]",#t,t)
	local buf = ffi.new("GLfloat[?]",#t,t)
	glext['glVertexAttrib'..self.nvalues.."fv"](self.loc, buf)
end
local function printSource(src)
	local tsrc = stsplit(src,"\n")
	for i,line in ipairs(tsrc) do
		print(i,line)
	end
end
local function printShaderInfoLog(obj)
	print"shader info log"
	local status = ffi.new("GLint[1]", 0)
	glext.glGetShaderiv(obj, glc.GL_COMPILE_STATUS,status)
	
	local infologLength = ffi.new("int[1]", 0)
	glext.glGetShaderiv(obj, glc.GL_INFO_LOG_LENGTH,infologLength);
	
	if (infologLength[0] > 0) then
		local charsWritten  = ffi.new("int[1]", 0)
		local infoLog = ffi.new("char[?]",infologLength[0])
		glext.glGetShaderInfoLog(obj, infologLength[0], charsWritten, infoLog);
		print(string.format("%s\n",ffi.string(infoLog)));
	end
	return status[0] == glc.GL_FALSE

end


GLSL = {}
function GLSL:new(o)
	o = o or {}
	o.program = glext.glCreateProgram();
	setmetatable(o, self)
	self.__index = self
	return o
end

function GLSL:use(val)
	glext.glUseProgram(val or self.program)
end
function GLSL:printProgramInfoLog()
	local obj = self.program
	print"program info log"
    local infologLength = ffi.new("int[1]", 0)
    local charsWritten  = ffi.new("int[1]", 0)
	local lstatus  = ffi.new("int[1]", 0)
    --char *infoLog;
	glext.glGetProgramiv(obj, glc.GL_LINK_STATUS,lstatus);
	
	glext.glGetProgramiv(obj, glc.GL_INFO_LOG_LENGTH,infologLength);
    if (infologLength[0] > 0) then
		print"program info link failure:"
        --infoLog = (char *)malloc(infologLength);
		local infoLog = ffi.new("char[?]",infologLength[0])
        glext.glGetProgramInfoLog(obj, infologLength[0], charsWritten, infoLog);
		print(string.format("%s\n",ffi.string(infoLog)));
       -- return true
    end
	assert(lstatus[0] == glc.GL_TRUE,"GLSL program link failure")
end

function GLSL:validate()	
	local obj = self.program
	local lstatus  = ffi.new("int[1]", 0)
	local infologLength = ffi.new("int[1]", 0)
	local charsWritten  = ffi.new("int[1]", 0)	
	
	glext.glValidateProgram(obj);
	glext.glGetProgramiv(obj, glc.GL_VALIDATE_STATUS,lstatus);
	if lstatus[0] == glc.GL_FALSE then
		glext.glGetProgramiv(obj, glc.GL_INFO_LOG_LENGTH,infologLength);
		if (infologLength[0] > 0) then
			print"program info validate failure:"
			local infoLog = ffi.new("char[?]",infologLength[0])
			glext.glGetProgramInfoLog(obj, infologLength[0], charsWritten, infoLog);
			print(string.format("%s\n",ffi.string(infoLog)));
		-- return true
		end
		error()
	end
end
local function str2char(str)
	return ffi.new("char[?]",#str + 1,str)
end  
local function char2str(charp)
	if charp then
		return ffi.string(charp)
	else
		return nil
	end
end
local function HasVersion(code)
	return code:match("^%s*#version")
end
local function CheckVersion(code)
	if GLSL.default_version and not HasVersion(code) then
		code = GLSL.default_version .. code
	end
	return code
end
function GLSL:setShaders(vert,frag,geom,tfvar) 
	local p = self.program
	local v,f,g
	if vert then
		vert = CheckVersion(vert)
		v = glext.glCreateShader(glc.GL_VERTEX_SHADER);
		local vertp = ffi.new("const char*[1]",{vert})
		glext.glShaderSource(v, 1, vertp,NULL);
		glext.glCompileShader(v);
		if printShaderInfoLog(v) then printSource(vert) end
	end
	if frag then
		frag = CheckVersion(frag)
		f = glext.glCreateShader(glc.GL_FRAGMENT_SHADER);
		local fragp = ffi.new("const char*[1]",{frag})
		glext.glShaderSource(f, 1, fragp,NULL);
		glext.glCompileShader(f);
		if printShaderInfoLog(f) then printSource(frag) end
	end
	if geom then
		geom = CheckVersion(geom)
		g = glext.glCreateShader(glc.GL_GEOMETRY_SHADER);
		local geomp = ffi.new("const char*[1]",{geom})
		glext.glShaderSource(g, 1, geomp,NULL);
		glext.glCompileShader(g);
		if printShaderInfoLog(g) then printSource(geom) end
	end
	
	
	--local p = glext.glCreateProgram();
	if vert then glext.glAttachShader(p,v); end
	if frag then glext.glAttachShader(p,f); end
	if geom then glext.glAttachShader(p,g); end
	
	--tfvar is table of transform feedback varyings names
	if tfvar then
		self:set_TFV(tfvar)
	--[[
		local Varyings = ffi.new("const char*[".. #tfvar .."]")
		for i=0,#tfvar-1 do
			 Varyings[i] = str2char(tfvar[i + 1])
		end
		glext.glTransformFeedbackVaryings(p, #tfvar, Varyings, glc.GL_INTERLEAVED_ATTRIBS);
		--]]
	end

	glext.glLinkProgram(p);
	self:printProgramInfoLog();
	
	if vert then glext.glDeleteShader(v) end
	if frag then glext.glDeleteShader(f) end
	if geom then glext.glDeleteShader(g) end
	
	glext.glUseProgram(p);
	return p
end
function GLSL:set_TFV(tfvar,separate)
	print"set_TFV______________________________________________________________________"
	separate = (separate==nil) and true or separate
	local mode = separate and glc.GL_SEPARATE_ATTRIBS or glc.GL_INTERLEAVED_ATTRIBS
	local Varyings = ffi.new("const char*[".. #tfvar .."]")
	for i=0,#tfvar-1 do
		 Varyings[i] = str2char(tfvar[i + 1])
	end
	glext.glTransformFeedbackVaryings(self.program, #tfvar, Varyings, mode);
	glext.glLinkProgram(self.program);
	self:printProgramInfoLog();
	--self:TFVinfo()
	self:getunif()
end
function GLSL:TFVinfo()
	print"TFVinfo______________________________________________________________________"
	local natt = ffi.new("GLint[1]")
	local bufsize = ffi.new("GLint[1]")
	--get transform feedback varyings
	glext.glGetProgramiv(self.program, glc.GL_TRANSFORM_FEEDBACK_VARYINGS, natt)
	glext.glGetProgramiv(self.program, glc.GL_TRANSFORM_FEEDBACK_VARYING_MAX_LENGTH, bufsize)
	local size = ffi.new("GLsizei[1]")
	local tipo = ffi.new("GLenum[1]")
	local name = ffi.new("GLchar[?]",bufsize[0])
	local length = ffi.new("GLsizei[1]")
	if natt[0] > 0 then
		self.tfv = {}
		print("transform feedback varyings",natt[0])
		for i=0,natt[0]-1 do
			glext.glGetTransformFeedbackVarying(self.program, i, bufsize[0], length, size, tipo, name);
			local namel = char2str(name) 
			self.tfv[namel] = i
			print(i,string.format("%".. bufsize[0] .."s",namel),size[0],uniform_types[tipo[0]].name)
		end
	end
	return self
end
function GLSL:compile(vert,frag,geom,tfvar)
	print"---------------Compile------------------"
	local source = debug.getinfo(2,'Sl')
	print(source.source,source.linedefined,source.currentline)
	self.source = source
	--self.program = setShaders(vert, frag)
	self:setShaders(vert, frag,geom,tfvar)
	self:getunif()
	return self
end
function GLSL:getunif()
	print("---------------GetUnif------------------",self)
	--get uniforms
	local natt = ffi.new("GLint[1]")
	glext.glGetProgramiv(self.program, glc.GL_ACTIVE_UNIFORMS, natt)
	local bufsize = ffi.new("GLint[1]")
	glext.glGetProgramiv(self.program, glc.GL_ACTIVE_UNIFORM_MAX_LENGTH, bufsize)
	local size = ffi.new("GLint[1]")
	local tipo = ffi.new("GLenum[1]")
	local name = ffi.new("GLchar[?]",bufsize[0])
	self.unif = setmetatable({}, unif_mt)
	print("Uniforms",natt[0])
	for i=0,natt[0]-1 do
		glext.glGetActiveUniform(self.program, i, bufsize[0], nil, size, tipo, name);
		local namel = ffi.string(name) 
		local loc = glext.glGetUniformLocation(self.program,namel)
		self.unif[namel] = Uniform(size[0],tipo[0],loc,namel)
		--print(i,ffi.string(name),size[0],uniform_types[tipo[0]].name)
		local typename = uniform_types[tipo[0]] and uniform_types[tipo[0]].name or "UNKNOWN_TYPE"
		print(i,loc,string.format("%".. bufsize[0] .."s",namel),size[0],tipo[0],typename)
		assert(uniform_types[tipo[0]],"tipo desconocido")
	end
	--get attribs
	glext.glGetProgramiv(self.program, glc.GL_ACTIVE_ATTRIBUTES, natt)
	glext.glGetProgramiv(self.program, glc.GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, bufsize)
	local name = ffi.new("GLchar[?]",bufsize[0])
	self.attr = {}
	print("Attributes",natt[0])
	for i=0,natt[0]-1 do
		glext.glGetActiveAttrib(self.program, i, bufsize[0], nil, size, tipo, name);
		local namel = ffi.string(name) 
		local loc = glext.glGetAttribLocation(self.program,namel)
		self.attr[namel] = Attrib(size[0],tipo[0],loc)
		--print(i,ffi.string(name),size[0],uniform_types[tipo[0]].name)
		print(i,loc,string.format("%".. bufsize[0] .."s",namel),size[0],uniform_types[tipo[0]].name)
	end
	self:TFVinfo()
	return self
end


function pingpongFBO(w,h,num,GL)
	num = num or 2
	assert(w)
	assert(h)
	local PP = {}
	for i=0,num-1 do
		PP[i] = GL:initFBO(nil,w,h)
	end
	local curr_rend = 0
	function PP:getDRAW()
		local fbo = PP[curr_rend]
		curr_rend = (curr_rend + 1)%num
		return fbo
	end
	return PP
end
local object_types = {[[GL_NONE]],[[GL_FRAMEBUFFER_DEFAULT]],[[GL_TEXTURE]],[[GL_RENDERBUFFER]]}
function printFramebufferInfo(target, fbo)
 
    local  i = 0
    --GLint buffer;
	local buffer = ffi.new("GLint[1]")
	local res = ffi.new("int[1]")
    glext.glBindFramebuffer(target,fbo);
 
    repeat
        gl.glGetIntegerv(glc.GL_DRAW_BUFFER0+i, buffer);
        if (buffer[0] ~= glc.GL_NONE) then
            print(string.format("Shader Output Location %d - color attachment %d", i, buffer[0] - glc.GL_COLOR_ATTACHMENT0));
            glext.glGetFramebufferAttachmentParameteriv(target, buffer[0],glc.GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, res);
			local tipo
			for i,v in ipairs(object_types) do
				if res[0] == glc[v] then
					tipo = v
				end
			end
            print(string.format("\tAttachment Type: %s", tipo));
            glext.glGetFramebufferAttachmentParameteriv(target, buffer[0],glc.GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, res);
            print(string.format("\tAttachment object name: %d",res[0]));
        end
        i = i + 1
    until (buffer[0] ~= glc.GL_NONE);
end

function initFBO(wFBO,hFBO,args)
	if type(wFBO)=="table" then hFBO = wFBO.H; wFBO=wFBO.W end
	print("initFBO",wFBO,hFBO)
	wFBO = math.max(1,wFBO)
	hFBO = math.max(1,hFBO)
	GetGLError"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxinitFBO ini"
	args = args or {}
	args.num_tex = args.num_tex or 1
	args.wrap = args.wrap or glc.GL_MIRRORED_REPEAT
	args.filter = args.filter or glc.GL_LINEAR
	args.data = args.data or {}
	--get old fbo
	local old_framebuffer = ffi.new("GLint[1]",0)
	gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
	--the fbo
	local thefbo = {w = wFBO, h = hFBO}
	thefbo.fb = ffi.new("GLuint[1]")
	glext.glGenFramebuffers(1, thefbo.fb);
	glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, thefbo.fb[0]);
	--the color textures
	if not args.color_tex then
		thefbo.color_tex = ffi.new("GLuint[?]",args.num_tex)
		gl.glGenTextures(args.num_tex, thefbo.color_tex);
		local intformat = args.SRGB and glc.GL_SRGB_ALPHA or glc.GL_RGBA32F
		thefbo.SRGB = args.SRGB
		for i=0,args.num_tex-1 do
			gl.glBindTexture(glc.GL_TEXTURE_2D, thefbo.color_tex[i]);
			gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT,1);
	
			gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, args.wrap);
			gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, args.wrap);
			gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,args.filter)
			gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,args.filter)
		
			--gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAX_LEVEL, 0);
			gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, intformat, wFBO, hFBO, 0, glc.GL_RGBA, glc.GL_FLOAT, args.data[i]);
			
			--if GL.mipmaps then
			--gl.glEnable(glc.GL_TEXTURE_2D) --ati bug
			--glext.glGenerateMipmap(glc.GL_TEXTURE_2D)
			--end
			
			glext.glFramebufferTexture(glc.GL_DRAW_FRAMEBUFFER, glc.GL_COLOR_ATTACHMENT0 + i, thefbo.color_tex[i], 0);
		end
		gl.glBindTexture(glc.GL_TEXTURE_2D, 0)								 
	else --suplied textures
		thefbo.suplied_textures = true
		thefbo.color_tex = args.color_tex
		for i=0,args.num_tex-1 do
			glext.glFramebufferTexture(glc.GL_DRAW_FRAMEBUFFER, glc.GL_COLOR_ATTACHMENT0 + i, thefbo.color_tex[i], 0);
		end
	end
  -- Set the list of draw buffers.
	--GLenum DrawBuffers[1] = {GL_COLOR_ATTACHMENT0};
	--thefbo.drawbuffers = ffi.new("GLenum[1]")
	--thefbo.drawbuffers[0] = glc.GL_COLOR_ATTACHMENT0
	--glext.glDrawBuffers(1, thefbo.drawbuffers); -- "1" is the size of DrawBuffers

   GetGLError"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxinitFBO2"
   --------------------------- has deph buffer
	if not args.no_depth then
		thefbo.depth_rb = ffi.new("GLuint[1]")
		--[[ --not texture only renderbuffer
		glext.glGenRenderbuffers(1, thefbo.depth_rb);
		glext.glBindRenderbuffer(glc.GL_RENDERBUFFER, thefbo.depth_rb[0]);
		glext.glRenderbufferStorage(glc.GL_RENDERBUFFER, glc.GL_DEPTH_COMPONENT, wFBO, hFBO);
		glext.glFramebufferRenderbuffer(glc.GL_DRAW_FRAMEBUFFER, glc.GL_DEPTH_ATTACHMENT, glc.GL_RENDERBUFFER, thefbo.depth_rb[0]);
		--]]
		local internalformat = args.depth_format or glc.GL_DEPTH_COMPONENT
		-- with texture
		gl.glGenTextures(1, thefbo.depth_rb);
		gl.glBindTexture(glc.GL_TEXTURE_2D, thefbo.depth_rb[0]);
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, glc.GL_CLAMP_TO_EDGE);
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, glc.GL_CLAMP_TO_EDGE);
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MIN_FILTER, glc.GL_NEAREST);
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAG_FILTER, glc.GL_NEAREST);
		gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, glc.GL_DEPTH_COMPONENT, wFBO, hFBO, 0, glc.GL_DEPTH_COMPONENT, glc.GL_FLOAT, nil);
		glext.glFramebufferTexture2D(glc.GL_DRAW_FRAMEBUFFER, glc.GL_DEPTH_ATTACHMENT, glc.GL_TEXTURE_2D, thefbo.depth_rb[0], 0);
		GetGLError"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxinitFBO3"
	end
   ---------------------------
   --Does the GPU support current FBO configuration?
   --GLenum status;
   if (glc.GL_FRAMEBUFFER_COMPLETE ~= glext.glCheckFramebufferStatus(glc.GL_DRAW_FRAMEBUFFER)) then
		print("initFBO error",wFBO,hFBO)
		error()
   end
   GetGLError"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxinitFBO"
   glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
   function thefbo:UseTexture(i,j)
		i = i or 0
		j = j or i
		glext.glActiveTexture(glc.GL_TEXTURE0 + i);
		gl.glEnable( glc.GL_TEXTURE_2D );
		gl.glBindTexture(glc.GL_TEXTURE_2D, self.color_tex[j])
		--local modewrap = glc.GL_MIRRORED_REPEAT --glc.GL_CLAMP --glc.GL_REPEAT --glc.GL_MIRRORED_REPEAT
		--gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
		--gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
   end
   function thefbo:UseDepthTexture(i)
		assert(not args.no_depth,"no depth texture in fbo")
		i = i or 0
		glext.glActiveTexture(glc.GL_TEXTURE0 + i);
		gl.glBindTexture(glc.GL_TEXTURE_2D, thefbo.depth_rb[0]);
   end
   local depth_tex 
   function thefbo:GetDepthTexture()
		if depth_tex then return depth_tex end
		depth_tex = Texture(wFBO,hFBO,glc.GL_RGBA,self.depth_rb )
		return depth_tex
   end
   local textures = {}
   function thefbo:GetTexture(i)
		i = i or 0
		if textures[i] then return textures[i] end
		textures[i] = Texture(wFBO,hFBO,glc.GL_RGBA,self.color_tex + i )
		return textures[i]
   end
	thefbo.tex = thefbo.GetTexture --alias									 
   function thefbo:Bind(val)
		local old_framebuffer = ffi.new("GLuint[1]",0)
		gl.glGetIntegerv(glc.GL_DRAW_FRAMEBUFFER_BINDING, old_framebuffer)
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, val or self.fb[0]);
		self.old_framebuffer = old_framebuffer[0]
		return old_framebuffer[0]
   end
	function thefbo:UnBind(fbo)
		--assert(self.old_framebuffer,"there is not oldframebuffer")
		fbo = fbo or self.old_framebuffer
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbo);
		self.old_framebuffer = nil
	end
   function thefbo:BindRead(i)
		i = i or 0
		local old_framebuffer = ffi.new("GLuint[1]",0)
		gl.glGetIntegerv(glc.GL_READ_FRAMEBUFFER_BINDING, old_framebuffer)
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER, self.fb[0]);
		gl.glReadBuffer(glc.GL_COLOR_ATTACHMENT0 + i); 
		return old_framebuffer[0]
   end
   --read to CPU memory
   function thefbo:get_pixels(format,type,whichbuf,buffer, offX,offY, W, H)
		whichbuf = whichbuf or 0
		local types = {[glc.GL_FLOAT] = "float[?]", [glc.GL_UNSIGNED_SHORT]="short[?]"}
		local formats = {[glc.GL_RED]=1,[glc.GL_RGB]=3,[glc.GL_RGBA]=4}
		local ncomponents = formats[format]		
		local allocstr = types[type]

		local oldfbo = self:BindRead()
		--
		gl.glReadBuffer(glc.GL_COLOR_ATTACHMENT0 + whichbuf); 
		
		local bufferWidth = ffi.new("GLint[1]")
		local bufferHeight = ffi.new("GLint[1]")
		--glext.glGetRenderbufferParameteriv(glc.GL_RENDERBUFFER, glc.GL_RENDERBUFFER_WIDTH, bufferWidth);
		--glext.glGetRenderbufferParameteriv(glc.GL_RENDERBUFFER, glc.GL_RENDERBUFFER_HEIGHT, bufferHeight);
		local iniX,iniY,w,h
		if offX then
			iniX,iniY,w,h = offX,offY,W,H
		else
			iniX,iniY,w,h = 0,0,wFBO,hFBO --bufferWidth[0],bufferHeight[0]
		end
	
		local pixelsUserData = buffer or ffi.new(allocstr,w*h*ncomponents)
		--assert(ffi.sizeof(pixelsUserData)==
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(iniX,iniY, w, h, format, type, pixelsUserData)

		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER, oldfbo);
		return pixelsUserData,w,h
   end
	function thefbo:Dump(framebuffer)
		framebuffer = framebuffer or self.old_framebuffer
		local w,h = wFBO,hFBO
		local old_read_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_READ_FRAMEBUFFER_BINDING, old_read_framebuffer)
		
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER,  framebuffer);   -- Make sure no FBO is set as the draw framebuffer
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER,  self.fb[0]); -- Make sure your multisampled FBO is the read framebuffer
		if framebuffer == 0 then
			gl.glDrawBuffer(glc.GL_BACK);                       -- Set the back buffer as the draw buffer
		else
			gl.glDrawBuffer(glc.GL_COLOR_ATTACHMENT0); 
		end

		glext.glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, glc.GL_COLOR_BUFFER_BIT, glc.GL_LINEAR);
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER,  old_read_framebuffer[0]);
		self:UnBind(framebuffer)
	end
	function thefbo:delete()
		glext.glDeleteFramebuffers(1, self.fb);
		if not thefbo.suplied_textures then
			gl.glDeleteTextures(args.num_tex, self.color_tex);
		end
		if self.depth_rb then gl.glDeleteTextures(1, thefbo.depth_rb) end
	end
	function thefbo:viewport()
		gl.glViewport(0,0,self.w,self.h)
	end
	return thefbo
end
fbostatus = {[[GL_FRAMEBUFFER_UNDEFINED]],
[[GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT]],
[[GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT]],
[[GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER]],
[[GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER]],
[[GL_FRAMEBUFFER_UNSUPPORTED]],
[[GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE]],
[[GL_FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS]]}


function MakeSlab(w,h,args,GL)
	args = args or {no_depth=true}

	local slab = {isSlab=true}
	slab.ping = GL:initFBO(args,w,h)
	slab.pong = GL:initFBO(args,w,h)
	function slab:swapt()
		self.ping,self.pong = self.pong,self.ping
	end
	function slab:Bind()
		self.pong:Bind()
	end
	function slab:UnBind()
		self.pong:UnBind()
		self.swapt()
	end
	function slab:tex()
		return slab.ping:tex()
	end
end
						   


function initFBOMultiSample(GL,wFBO,hFBO)
	assert(GL)
	hFBO = hFBO or GL.H; wFBO=wFBO or GL.W
	local old_framebuffer = ffi.new("GLint[1]",0)
	gl.glGetIntegerv(glc.GL_DRAW_FRAMEBUFFER_BINDING, old_framebuffer)
	
	local NumOfSamples = ffi.new("GLuint[1]")
	local g_MultiSampleTexture_ID = ffi.new("GLuint[1]")
	local g_MultiSampleFrameBufferObject_ID = ffi.new("GLuint[1]")
	local g_MultiSampleColorRenderBufferObject_ID = ffi.new("GLuint[1]")
	local g_MultiSampleDepthBufferObject_ID = ffi.new("GLuint[1]")
	
	gl.glGetIntegerv(glc.GL_MAX_SAMPLES, NumOfSamples);
	
	gl.glGenTextures(1, g_MultiSampleTexture_ID );
	gl.glBindTexture(glc.GL_TEXTURE_2D_MULTISAMPLE, g_MultiSampleTexture_ID[0]);
	glext.glTexImage2DMultisample(glc.GL_TEXTURE_2D_MULTISAMPLE, NumOfSamples[0], glc.GL_RGBA, wFBO, hFBO, false);
	glext.glGenFramebuffers(1, g_MultiSampleFrameBufferObject_ID);
	glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, g_MultiSampleFrameBufferObject_ID[0]);
	glext.glFramebufferTexture2D(glc.GL_DRAW_FRAMEBUFFER, glc.GL_COLOR_ATTACHMENT0, glc.GL_TEXTURE_2D_MULTISAMPLE, g_MultiSampleTexture_ID[0], 0);
	glext.glGenRenderbuffers(1, g_MultiSampleColorRenderBufferObject_ID);
	glext.glBindRenderbuffer(glc.GL_RENDERBUFFER, g_MultiSampleColorRenderBufferObject_ID[0]);
	glext.glRenderbufferStorageMultisample(glc.GL_RENDERBUFFER, NumOfSamples[0], glc.GL_RGBA, wFBO, hFBO);
	glext.glFramebufferRenderbuffer(glc.GL_DRAW_FRAMEBUFFER, glc.GL_COLOR_ATTACHMENT0, glc.GL_RENDERBUFFER, g_MultiSampleColorRenderBufferObject_ID[0]);
	glext.glGenRenderbuffers(1, g_MultiSampleDepthBufferObject_ID);
	glext.glBindRenderbuffer(glc.GL_RENDERBUFFER, g_MultiSampleDepthBufferObject_ID[0]);
	glext.glRenderbufferStorageMultisample(glc.GL_RENDERBUFFER, NumOfSamples[0], glc.GL_DEPTH24_STENCIL8, wFBO, hFBO);
	glext.glFramebufferRenderbuffer(glc.GL_DRAW_FRAMEBUFFER, glc.GL_DEPTH_ATTACHMENT, glc.GL_RENDERBUFFER, g_MultiSampleDepthBufferObject_ID[0]);
	glext.glFramebufferRenderbuffer(glc.GL_DRAW_FRAMEBUFFER, glc.GL_STENCIL_ATTACHMENT, glc.GL_RENDERBUFFER, g_MultiSampleDepthBufferObject_ID[0]);

	 local fbo_status = glext.glCheckFramebufferStatus(glc.GL_DRAW_FRAMEBUFFER)
  -- if (glc.GL_FRAMEBUFFER_COMPLETE_EXT ~= fbo_status) then
	if (glc.GL_FRAMEBUFFER_COMPLETE ~= fbo_status) then
		print("initFBOMultiSample error",fbo_status)
		--print(glu.gluErrorString(fbo_status)==nil and "unknown error" or ffi.string(glu.gluErrorString(fbo_status)))
		for i,v in ipairs(fbostatus) do
			if fbo_status == glc[v] then
				print("fbo error",v)
			end
		end
		error()
	end
	glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]); 
	print("MultiSample fbo",NumOfSamples[0],g_MultiSampleFrameBufferObject_ID[0],g_MultiSampleTexture_ID[0])
	local ret = {color_tex = g_MultiSampleTexture_ID ,fb = g_MultiSampleFrameBufferObject_ID,GL=GL}
	
	function ret:Bind(val)
		gl.glEnable(glc.GL_MULTISAMPLE);
		local old_framebuffer = ffi.new("GLuint[1]",0)
		gl.glGetIntegerv(glc.GL_DRAW_FRAMEBUFFER_BINDING, old_framebuffer)
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, val or self.fb[0]);
		self.old_framebuffer = old_framebuffer[0]
		return old_framebuffer[0]
	end
	function ret:UnBind(fbo)
		--assert(self.old_framebuffer)
		fbo = fbo or self.old_framebuffer
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbo);
		self.old_framebuffer = nil
	end
	--------ms tosingle fbo
	function ret:Dump(framebuffer)
		framebuffer = framebuffer or self.old_framebuffer
		local w,h = wFBO,hFBO
		local old_read_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_READ_FRAMEBUFFER_BINDING, old_read_framebuffer)
		
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER,  framebuffer);   -- Make sure no FBO is set as the draw framebuffer
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER,  self.fb[0]); -- Make sure your multisampled FBO is the read framebuffer
		if framebuffer == 0 then
			gl.glDrawBuffer(glc.GL_BACK);                       -- Set the back buffer as the draw buffer
		else
			gl.glDrawBuffer(glc.GL_COLOR_ATTACHMENT0); 
		end

		glext.glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, glc.GL_COLOR_BUFFER_BIT, glc.GL_LINEAR);
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER,  old_read_framebuffer[0]);
		self:UnBind(framebuffer)
	end
		------------------------
	GetGLError"initMSSA"
	return ret
end
-----------------------------
function Query()
	local Query = {}
	
	function Query:Begin(type_query)
		if not Query.one_query then
			Query.one_query = ffi.new("GLuint[1]")
			glext.glGenQueries(1, Query.one_query);
		end
		type_query = type_query or glc.GL_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN
		self.type = type_query
		glext.glBeginQuery(type_query, Query.one_query[0]);
	end
	function Query:End()
		glext.glEndQuery(Query.type);
		local res = ffi.new("GLuint[1]")
		--glext.glGetQueryObjectuiv(Query.one_query[0], glc.GL_QUERY_RESULT_AVAILABLE, res);
		--if res[0]==glc.GL_FALSE then return false end
		glext.glGetQueryObjectuiv(Query.one_query[0], glc.GL_QUERY_RESULT, res);
		return res[0]
	end
	return Query
end
--------------
function VBO()
	local tVbo = {isVBO=true}
	tVbo.vbo = ffi.new("GLuint[1]",1)
	glext.glGenBuffers(1, tVbo.vbo);
	tVbo.handle = tVbo.vbo[0]
	function tVbo:Bind(type)
		glext.glBindBuffer(type, self.vbo[0]);
	end
	function tVbo:BufferData(values,kind)
		kind = kind or glc.GL_ARRAY_BUFFER
		self:Bind(kind)
		glext.glBufferData(kind,ffi.sizeof(values),values, glc.GL_DYNAMIC_DRAW);
	end
	local btex
	local tbo_unit
	local tbo_type
	local tbo = {Bind= function(self,unit,mode)
					unit = unit or 0
					tbo_unit = unit
					glext.glActiveTexture(glc.GL_TEXTURE0 + unit);
					gl.glBindTexture(glc.GL_TEXTURE_BUFFER, btex[0]);
					--mode = mode or glc.GL_READ_WRITE
					--glext.glBindImageTexture(unit, btex[0], 0, glc.GL_FALSE, 0, mode, tbo_type)				
				end,
				UnBind = function(self) 
					glext.glActiveTexture(glc.GL_TEXTURE0 + tbo_unit);
					gl.glBindTexture(glc.GL_TEXTURE_BUFFER, 0);
				end}
	function tVbo:buffer_texture(type)
		type = type or glc.GL_RGB32F
		tbo_type = type
		if not btex then --initialize
			btex = ffi.new("GLuint[1]")
			gl.glGenTextures(1, btex);
			gl.glBindTexture(glc.GL_TEXTURE_BUFFER, btex[0]);
			glext.glTexBuffer(glc.GL_TEXTURE_BUFFER, type, self.vbo[0])
			gl.glBindTexture(glc.GL_TEXTURE_BUFFER, 0);
		end
		return tbo
	end
	return tVbo
end
--vao for sending GL_FLOAT
function VAO(t,program,indices,tsize,isize)
	local tVao = {}
	local attribs = {}
	local att_names = {}
	
	for k,v in pairs(t) do
		if type(v)=="table" then
			if v.isVBO then
				attribs[#attribs + 1]  = {name = k,vbo=v}
			else
				local ffivalues = ffi.new("GLfloat[?]",#v,v)
				local b_size = ffi.sizeof(ffivalues)
				attribs[#attribs + 1]  = {name = k, ffivalues=ffivalues, b_size = b_size}
			end
		elseif ffi.sizeof(v) > ffi.sizeof("float *") then --ffi.istype("float[?]",v) then
			attribs[#attribs + 1] = {name = k, ffivalues=v, b_size = ffi.sizeof(v)}
		else
			if not tsize then error"cant get sizes" end
			attribs[#attribs + 1] = {name = k, ffivalues=v, b_size = tsize[k]*ffi.sizeof"float"}
		end
		att_names[k] = #attribs
	end
	
	--make vao
	local vao = ffi.new("GLuint[1]")
	glext.glGenVertexArrays(1, vao);
	glext.glBindVertexArray(vao[0]);
	
	--make vbos
	local vbos = {}
	for i,v in ipairs(attribs) do
		if not attribs[i].vbo then
			attribs[i].vbo = VBO()
		end
		 vbos[i] = attribs[i].vbo
	end
	
	--set vbos data
	for i,v in ipairs(attribs) do
		if v.ffivalues then
			vbos[i]:Bind(glc.GL_ARRAY_BUFFER)
			vbos[i].b_size = v.b_size
			glext.glBufferData(glc.GL_ARRAY_BUFFER,v.b_size,v.ffivalues, glc.GL_DYNAMIC_DRAW);
		end
	end
	
	--check program info
	local allcount
	for i,v in ipairs(attribs) do
		local attr = program.attr[v.name]
		--assert(attr,v.name.." attribute not found in program")
		if attr then 
			v.present = true
			v.loc = attr.loc
			v.typesize = attr.nvalues
			local b_size = v.vbo.b_size
			v.vbo.count = b_size/(ffi.sizeof"float"*attr.nvalues)
			if allcount then assert(v.vbo.count == allcount) else allcount = v.vbo.count end
		else
			v.present = false
			print("xxxxxxxxxxx",v.name," attribute not found in program")
			if GLSL.uniform_error then error[[attribute not found]] end
		end
	end
	tVao.count = allcount
	
	--bind vaos that are in program
	for i,v in ipairs(attribs) do
		if v.present then
		vbos[i]:Bind(glc.GL_ARRAY_BUFFER)
		glext.glEnableVertexAttribArray(v.loc)
		glext.glVertexAttribPointer(v.loc, v.typesize, glc.GL_FLOAT, glc.GL_FALSE,0,ffi.cast("GLvoid*", 0));
		end
	end

	if indices then
		local ffiindices
		local i_b_sizes
		local ebocount
		if type(indices)=="table" then
			ffiindices = ffi.new("GLuint[?]",#indices,indices)
			i_b_sizes = #indices * ffi.sizeof("GLuint")
			ebocount = #indices
		elseif ffi.istype("GLuint[?]",indices) then
			ffiindices = indices
			ebocount = ffi.sizeof(ffiindices)/ffi.sizeof("GLuint")
			i_b_sizes = ffi.sizeof(ffiindices)
		else 
			if not isize then error"cant get indices sizes" end
			ebocount = isize
			i_b_sizes = isize * ffi.sizeof("GLuint")
			ffiindices = ffi.new("GLuint[?]",isize)
			ffi.copy(ffiindices, indices, i_b_sizes)
		end
		-- local ebo = ffi.new("GLuint[1]")
		-- glext.glGenBuffers(1, ebo);
		-- glext.glBindBuffer(glc.GL_ELEMENT_ARRAY_BUFFER, ebo[0]);
		-- glext.glBufferData(glc.GL_ELEMENT_ARRAY_BUFFER,i_b_sizes,ffiindices, glc.GL_STATIC_DRAW);
		-- tVao.ebo = ebo
		local ebo = VBO()
		--glext.glBindBuffer(glc.GL_ELEMENT_ARRAY_BUFFER, ebo[0]);
		--ebo:Bind(glc.GL_ELEMENT_ARRAY_BUFFER)
		--glext.glBufferData(glc.GL_ELEMENT_ARRAY_BUFFER,i_b_sizes,ffiindices, glc.GL_STATIC_DRAW);
		--glext.glBufferData(kind,ffi.sizeof(values),values, glc.GL_DYNAMIC_DRAW);
		ebo:BufferData(ffiindices,glc.GL_ELEMENT_ARRAY_BUFFER);
		ebo.count = ebocount
		tVao.ebo = ebo
		
	end
	
	--same vbos with other program
	function tVao:clone(prog)
		local tt = {}
		for i,at in ipairs(attribs) do
			tt[at.name] = at.vbo
		end
		--prtable(tt,indices)
		--return VAO(tt,prog,indices,tsize,isize)
		local retv = VAO(tt,prog)
		if self.ebo then
			retv.ebo = self.ebo
			retv:Bind()
			retv.ebo:Bind(glc.GL_ELEMENT_ARRAY_BUFFER)
			--glext.glBindBuffer(glc.GL_ELEMENT_ARRAY_BUFFER, retv.ebo[0]);
			retv:UnBind()
		end
		return retv
	end
	
	function tVao:vbo(name)
		return vbos[att_names[name]]
	end
	function tVao:set_indexes(data,size)
		assert(self.ebo)
		--indices = data
		if type(data)=="table" then
			size = #data
			data = ffi.new("GLuint[?]",#data,data)
		end
		self:Bind()
		tVao.ebo.count = size
		--glext.glBindBuffer(glc.GL_ELEMENT_ARRAY_BUFFER, self.ebo[0]);
		self.ebo:Bind(glc.GL_ELEMENT_ARRAY_BUFFER)
		--to orphan buffer
		glext.glBufferData(glc.GL_ELEMENT_ARRAY_BUFFER,size*ffi.sizeof("GLuint"),nil, glc.GL_DYNAMIC_DRAW);
		glext.glBufferData(glc.GL_ELEMENT_ARRAY_BUFFER,size*ffi.sizeof("GLuint"),data, glc.GL_DYNAMIC_DRAW);
		self:UnBind()
	end
	--check all vbo have same count
	function tVao:check_counts()
		-- for i,v in pairs(vbos) do 
			-- assert(v.count == self.count)
		-- end
		for i,at in ipairs(attribs) do
			if at.present then
				if(at.vbo.count ~= self.count) then
					print(self.count,at.vbo.count,at.name)
					error"check_counts"
				end
			end
		end
	end
	--only set floats
	function tVao:set_buffer(name,data,size)
		local b_size
		if type(data)=="table" then
			size = #data
			data = ffi.new("GLfloat[?]",#data,data)
			b_size = size*ffi.sizeof"float"
		else -- float[?]
			if size then --for pointers
				b_size = ffi.sizeof"float"*size
			else
				b_size = ffi.sizeof(data)
				size = b_size/ffi.sizeof"float"
			end
		end
		
		local att = attribs[att_names[name]]
		if not att.present then print(name,"not present in vao:set_buffer"); return end
		local thisvbo = vbos[att_names[name]]
		thisvbo.count = size/att.typesize
		
		--cuidado TODO controlar diferentes medidas
		self.count = thisvbo.count
		--self:check_counts() -- aqui controlamos
		
		thisvbo:Bind(glc.GL_ARRAY_BUFFER);
		--to orphan buffer
		glext.glBufferData(glc.GL_ARRAY_BUFFER,b_size,nil, glc.GL_DYNAMIC_DRAW);
		glext.glBufferData(glc.GL_ARRAY_BUFFER,b_size,data, glc.GL_DYNAMIC_DRAW);
		thisvbo.b_size = b_size
	end
	function tVao:Bind()
		glext.glBindVertexArray(vao[0]);
	end
	function tVao:UnBind()
		glext.glBindVertexArray(0);
	end
	function tVao:draw(type,count,ini,primcount)
		type = type or glc.GL_TRIANGLES
		self:check_counts()
		count = count or self.count
		ini = ini or 0
		primcount = primcount or 0
		glext.glBindVertexArray(vao[0]);
		if primcount > 0 then
			glext.glDrawArraysInstanced(type, ini, count,primcount)
		else
			gl.glDrawArrays(type, ini, count);
		end
	end
	function tVao:draw_elm(type,count,ini)
		ini = ini or 0
		local inip = ffi.cast("void*",(ini)*3*ffi.sizeof"int")
		type = type or glc.GL_TRIANGLES
		count = count or self.ebo.count
		glext.glBindVertexArray(vao[0]);
		--gl.glDrawElements(type, count, glc.GL_UNSIGNED_INT, nil);
		gl.glDrawElements(type, count, glc.GL_UNSIGNED_INT, inip);
	end
	function tVao:draw_mesh(count,type)
		--count = count or self.num_indices/3
		count = count or self.ebo.count/3
		type = type or glc.GL_LINE_LOOP
		glext.glBindVertexArray(vao[0]);
		for i=1,count do
			gl.glDrawElements(type, 3, glc.GL_UNSIGNED_INT, ffi.cast("void*",(i-1)*3*ffi.sizeof"int"));
		end
	end

	
	tVao.attribs = attribs
	tVao.vao = vao[0]
	glext.glBindVertexArray(0);
	return tVao
end
function image2D(w,h,type,data)
	type = type or "GL_RGBA"
	local type32f = type.."32F"
	local tex = ffi.new("GLuint[1]")
	gl.glGenTextures(1, tex);
	assert(tex[0]>0)
	gl.glBindTexture(glc.GL_TEXTURE_2D, tex[0]);
	--needed for amd to work
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MIN_FILTER, glc.GL_NEAREST); 
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAG_FILTER, glc.GL_NEAREST);
	if data then
		gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, glc[type32f], w, h, 0, glc[type], glc.GL_FLOAT, data);
	else
		glext.glTexStorage2D(glc.GL_TEXTURE_2D, 1, glc[type32f], w, h);
	end
	--Unbind it from the 2D texture target
	gl.glBindTexture(glc.GL_TEXTURE_2D, 0);
	local im = {tex=tex[0]}
	function im:Bind(unit,mode)
		mode = mode or glc.GL_READ_WRITE
		unit = unit or 0
		glext.glBindImageTexture(unit, self.tex, 0, glc.GL_FALSE, 0, mode,glc[type32f]);
	end
	return im
end

function TFV(t,prog_update,update_vao)
	local tfb = {}
	local varyings = {}
	local vars = {}
	for k,v in pairs(t) do
		varyings[#varyings + 1] = v
		vars[#vars + 1] = k
	end
	prog_update:set_TFV(varyings,true)
	local m_transformFeedback = ffi.new("GLuint[2]") 
    glext.glGenTransformFeedbacks(2, m_transformFeedback);
	for i=0,1 do
		local other = (i+1)%2
        glext.glBindTransformFeedback(glc.GL_TRANSFORM_FEEDBACK, m_transformFeedback[i]);
		for j,v in ipairs(vars) do
        glext.glBindBufferBase(glc.GL_TRANSFORM_FEEDBACK_BUFFER, prog_update.tfv[varyings[j]], update_vao[other]:vbo(vars[j]).vbo[0]);
		end
    end
	function tfb:Bind(n)
		glext.glBindTransformFeedback(glc.GL_TRANSFORM_FEEDBACK, m_transformFeedback[n]);
	end
	function tfb:Update(type)
		--print("tfb:Update",self.currenttfb)
		type = type or glc.GL_POINTS

		gl.glEnable(glc.GL_RASTERIZER_DISCARD);
		ut.Clear() --needed for consecutive TF to work
		tfb:Bind(self.currenttfb)
		glext.glBeginTransformFeedback(type);
		--self.currenttfb = (self.currenttfb + 1)%2
		update_vao[self.currenttfb]:draw(type)
		glext.glEndTransformFeedback();
		gl.glDisable(glc.GL_RASTERIZER_DISCARD);
		self.currenttfb = (self.currenttfb + 1)%2
		return self.currenttfb
	end
	tfb.currenttfb = 0
	tfb.m_transformFeedback = m_transformFeedback
	return tfb
end

function MakeGLGlobal()
	local glmeta = {}
	glmeta.__index = function(t,k)
		for i,ta in ipairs{gl,glc,glu,glext} do
			local ok,ret = pcall(function() return ta[k] end)
			if ok and ret then
				return ret 
			end
		end
	end
	setmetatable(_G,glmeta)
end