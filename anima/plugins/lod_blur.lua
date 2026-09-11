require"anima"

local vert_std = [[
in vec3 position;
in vec2 texcoords;
uniform mat4 MVP;
out vec4 tcoordf;
void main()
{
	tcoordf = vec4(texcoords,0,1);
	gl_Position = MVP * vec4(position,1);
}

]]
local frag_std = [[
uniform sampler2D tex0;
uniform float bias;
in vec4 tcoordf;
out vec4 fcolor;
void main()
{
	//ivec2 size = textureSize (tex0, int(bias));
	//gl_FragColor = texelFetch(tex0,ivec2(gl_TexCoord[0].st*size),int(bias));
	
	fcolor = texture(tex0,tcoordf.st,bias);
	
	//gl_FragColor = textureLod(tex0,gl_TexCoord[0].st,bias);
}
]]

local function BlurClipMaker(GL)
	local ANCHO,ALTO = GL.W,GL.H
	local Clip = {}
	local programstd, vao
	local fbo 
	function Clip.init()
		programstd = GLSL:new():compile(vert_std,frag_std);
		vao = mesh.quad(0,0,GL.W,GL.H):vao(programstd)
		fbo = GL:initFBO()
		Clip.inited = true
	end

	local function get_args(t, timev)
		local clip = t.clip
		local lod = ut.get_var(t.lod,timev,0)
		local mixfac = ut.get_var(t.mixfac,timev,0)
		return clip, lod,mixfac
	end

	function Clip:draw(timebegin,w,h,args)
		if not self.inited then self.init() end
		
		local theclip, lod,mixfac = get_args(args, timebegin)

		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbo.fb[0]);

		theclip[1]:draw(timebegin, w, h,theclip)

		
		programstd:use()
		programstd.unif.bias:set{lod*mixfac}
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
		
		--ut.Clear()
		--ut.ShowTex(fbo.color_tex[0],w,h)
		
		---[[
		glext.glActiveTexture(glc.GL_TEXTURE0);
		gl.glBindTexture(glc.GL_TEXTURE_2D, fbo.color_tex[0])
		
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_LINEAR)
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_LINEAR)
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAX_LEVEL, 1000);
		glext.glGenerateMipmap(glc.GL_TEXTURE_2D)
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
			
		-- gl.glMatrixMode(glc.GL_PROJECTION)
		-- gl.glLoadIdentity()
		-- gl.glOrtho(0.0, ANCHO, 0.0, ALTO, -1, 1);
		-- gl.glMatrixMode(glc.GL_MODELVIEW)
		-- gl.glLoadIdentity();
		local MVP = mat.ortho(0.0, ANCHO, 0.0, ALTO, -1, 1);
		programstd.unif.MVP:set(MVP.gl)
		gl.glViewport(0, 0, ANCHO, ALTO)
		
		--ut.DoQuad(w,h)
		vao:draw_elm()
		--]]

	end
	GL:add_plugin(Clip)
	return Clip
end

if not ... then
---[=[
require"anima"
local GL = GLcanvas{H=1080,aspect=2/3,profile="CORE"}
local blur = BlurClipMaker(GL,{size=2})
-- local blur = require"anima.plugins.gaussianblur"(GL)
local tex
function GL.init()
	tex = GL:Texture():Load[[C:\LuaGL\frames_anima\pelis\7thDoor\puertas\_MG_4250.tif]]
end
function GL.draw(t,w,h)
	blur:draw(t,w,h,{clip={tex},lod=2,mixfac=1})
end
GL:start()
--]=]
end


return BlurClipMaker