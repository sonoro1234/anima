


local function MM_Maker(GL, fac)
	fac = fac or 2
	local Clip = {}

	local msfbo
	local old_framebuffer = ffi.new("GLint[1]",0)
	
	function Clip.init()
		msfbo = GL:initFBO(nil,GL.W*fac, GL.H*fac)
	end

	local function get_args(t, timev)
		local clip = t.clip
		return clip
	end

	function Clip:draw(timebegin,w,h,args)

		local theclip = get_args(args, timebegin)
		
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, msfbo.fb[0]) 
		gl.glViewport(0,0,w*fac,h*fac)
		theclip[1]:draw(timebegin, w*fac, h*fac, theclip)
		gl.glViewport(0,0,w,h)
		--------ms tosingle fbo
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER,  old_framebuffer[0]);   -- Make sure no FBO is set as the draw framebuffer
		local tt = msfbo:GetTexture()
		tt:gen_mipmap()
		tt:draw(timebegin,w,h)
		--[[
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER,  msfbo.fb[0]); -- Make sure your multisampled FBO is the read framebuffer
		if old_framebuffer[0] == 0 then
			gl.glDrawBuffer(glc.GL_BACK);                       -- Set the back buffer as the draw buffer
		end
		local tt = msfbo:GetTexture()
		tt:Bind()
		--gl.glEnable(glc.GL_TEXTURE_2D) --ati bug
		---glext.glGenerateMipmap(glc.GL_TEXTURE_2D)
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_LINEAR)
		--glext.glTextureParameteri(tt.tex,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_NEAREST)
		--tt:gen_mipmap()
		glext.glGenerateMipmap(glc.GL_TEXTURE_2D);
		--gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
		glext.glBlitFramebuffer(0, 0, w*fac, h*fac, 0, 0, w, h, glc.GL_COLOR_BUFFER_BIT, glc.GL_LINEAR)--glc.GL_NEAREST) --glc.GL_LINEAR);
		--glext.glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, glc.GL_COLOR_BUFFER_BIT, glc.GL_LINEAR);
		------------------------
	--]]
	end
	function Clip:drawX(timebegin,w,h,args)

		local theclip = get_args(args, timebegin)
		
		theclip[1]:draw(timebegin, w*fac, h*fac, theclip)

	end
	GL:add_plugin(Clip)
	return Clip
end
return MM_Maker