

local function MM_Maker(GL)
	local Clip = {}

	local msfbo
	local old_framebuffer = ffi.new("GLint[1]",0)
	--local FBOrep
	
	function Clip.init()
		msfbo = GL:initFBOMultiSample()
		print("msaa fbo is ",msfbo.fb[0])
		--FBOrep = ut.FBOReplicator()
		Clip.inited = true
	end


	function Clip:draw(timebegin,w,h,args)
		if not self.inited then self.init() end
		local theclip = args.clip
		
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		gl.glEnable(glc.GL_MULTISAMPLE);
		--gl.glEnable(glc.GL_SAMPLE_ALPHA_TO_COVERAGE);
		
		--glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, msfbo.fb[0])
		msfbo:Bind()		
		ut.Clear()
		theclip[1]:draw(timebegin, w, h, theclip)

		--FBOrep:replicate(GL,msfbo.color_tex[0],old_framebuffer[0])
		msfbo:Dump(old_framebuffer[0])
		--[[
		--------ms tosingle fbo
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER,  old_framebuffer[0]);   -- Make sure no FBO is set as the draw framebuffer
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER,  msfbo.fb[0]); -- Make sure your multisampled FBO is the read framebuffer
		if old_framebuffer[0] == 0 then
			--gl.glDrawBuffer(glc.GL_BACK);                       -- Set the back buffer as the draw buffer
		else
			--gl.glDrawBuffer(glc.GL_COLOR_ATTACHMENT0); 
		end

		glext.glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, glc.GL_COLOR_BUFFER_BIT, glc.GL_LINEAR);
		------------------------
		--]]
		gl.glDisable(glc.GL_MULTISAMPLE);
	end

	GL:add_plugin(Clip)
	return Clip
end
return MM_Maker