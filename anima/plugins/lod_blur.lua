require"anima"

local vert_std = [[

void main()
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = ftransform();
}

]]
local frag_std = [[
uniform sampler2D tex0;
uniform float bias;
void main()
{
	//ivec2 size = textureSize (tex0, int(bias));
	//gl_FragColor = texelFetch(tex0,ivec2(gl_TexCoord[0].st*size),int(bias));
	
	gl_FragColor = texture(tex0,gl_TexCoord[0].st,bias);
	
	//gl_FragColor = textureLod(tex0,gl_TexCoord[0].st,bias);
}
]]

local function BlurClipMaker(GL)
	local ANCHO,ALTO = GL.W,GL.H
	local Clip = {}
	local programstd
	local fbo 
	function Clip.init()
		programstd = GLSL:new():compile(vert_std,frag_std);
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

		
		glext.glUseProgram(programstd.program);
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
			
		gl.glMatrixMode(glc.GL_PROJECTION)
		gl.glLoadIdentity()
		gl.glOrtho(0.0, ANCHO, 0.0, ALTO, -1, 1);
		gl.glMatrixMode(glc.GL_MODELVIEW)
		gl.glLoadIdentity();
		gl.glViewport(0, 0, ANCHO, ALTO)
		
		ut.DoQuad(w,h)
		--]]

	end
	GL:add_plugin(Clip)
	return Clip
end
return BlurClipMaker