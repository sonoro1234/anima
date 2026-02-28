--require"debug_cdef"
require"anima.utils"
ut = require"anima.common"

ffi = require "ffi"
bit = require "bit"

local gllib = require"gl"
gl, glc, glu, _ = gllib.libraries()

local lfs = require"lfs"

im = require"imffi"
-- lfs.chdir([[C:\luaGL\iupdlls\]])
-- require("imlua")
-- require("imlua_process")
-------------------------------------------------
gui = require"anima.gui"

--hack for old style iup NotModal
--must be used after GL definition
function NotModal(...)
	return GL:Dialog(...)
end
----------------------------------
--assign to print in debug
dprint = function() end
------------------------------
require"anima.GLSL"
require"anima.textures"
secs_now = require"anima.time"

--
local function MakeDefaultTimeProvider(GL)
	local tp = {starttime=0,timeoffset = 0,nowtime=0,time = 0, playing = false,totdur = GL.totdur or 200}
	function tp:get_time()
		if self.playing then
			self.nowtime = secs_now()
		end
		self.time = self.nowtime - self.starttime	+ self.timeoffset
		return self.time
	end
	function tp:set_time(val)
		self.timeoffset = val - (self.nowtime - self.starttime)
		--prtable("set_time",self)
	end
	function tp:stop()
		self.playing = false
	end
	function tp:start()
		self.timeoffset = self.time
		self.starttime = secs_now()
		self.playing = true
	end

	return tp
end

function MakeRtaudioTimeProvider(GL,dac, totdur)
	GL.dac = dac
	local tp = {totdur = totdur }
	function tp:get_time()
		return dac:getStreamTime() 
	end
	function tp:set_time(val)
		dac:setStreamTime(val)
	end
	function tp:stop()
		dac:stopStream()
		self.playing = false
	end
	function tp:start()
		dac:startStream()
		self.playing = true
	end

	return tp
end

function MakeAudioPlayerTimeProvider(GL,dac, totdur)
	GL.dac = dac
	local tp = {totdur = totdur }
	function tp:get_time()
		return dac:get_stream_time() 
	end
	function tp:set_time(val)
		dac:set_stream_time(val)
	end
	function tp:stop()
		dac:stop()
		self.playing = false
	end
	function tp:start()
		dac:start()
		self.playing = true
	end

	return tp
end

local sndfile --anchor for not being freed
function PrepareAudio(GL,soundfile,offset,args)--asio,dev_id)
	args = args or {}
	offset = offset or 0
	local dev_id = args.dev_id or 0
	rt = require("RtAudio")
	
	local dac
	if args.asio then
		dac = rt.RtAudio(rt.RtAudio_WINDOWS_ASIO)
	else
		dac = rt.RtAudio(rt.RtAudio_WINDOWS_DS)
	end

	dac:openStream({dev_id,2},nil,44100,1024)
	
	print("RtAudio device info:")
	prtable(dac:getDeviceInfo(dev_id))
	
	sndfile = rt.soundFile(soundfile)
	local DURAMUSICA = sndfile:info().frames/sndfile:info().samplerate
	
	sndfile:play(dac,1,offset)
	
	GL.timeprovider = MakeRtaudioTimeProvider(GL,dac,DURAMUSICA + offset +5 + (args.extratime or 0) )
end
function PrepareAudioRT(GL,soundfile,offset,args)--asio,dev_id)
	args = args or {}
	offset = offset or 0
	local dev_id = args.dev_id or 0
	local rt = require 'rtaudio_ffi'
	local AudioPlayer = require("rtAudioPlayer")
	local sndf = require"sndfile_ffi"
	
	if args.api then
		api = rt.compiled_api_by_name(args.api)
	else
		local apis = rt.compiled_api()
		api = apis[0]
		print"available RtAudio APIs"
		for i=0,rt.get_num_compiled_apis() do
			print(i,ffi.string(rt.api_name(apis[i])))
		end
	end
	
	local dac = rt.create(api)
	local device = rt.get_default_output_device(dac)
	print("dac using",ffi.string(rt.api_name(api)))
--copy specs from file
	local info = sndf.get_info(soundfile)
	local audioplayer,err = AudioPlayer({
    dac = dac,
    device = device,
    freq = info.samplerate, 
    format = rt.FORMAT_FLOAT32,
    channels = info.channels, 
    samples = 1024})
	
	assert(audioplayer,err)
	
	
	audioplayer:insert(soundfile,1,offset)
	local DURAMUSICA = info.frames/info.samplerate
	
	
	GL.timeprovider = MakeAudioPlayerTimeProvider(GL,audioplayer,DURAMUSICA + offset +5 + (args.extratime or 0) )
end
function PrepareAudioSDL(GL,soundfile,offset,args)--asio,dev_id)
	args = args or {}
	offset = offset or 0
	local dev_id = args.dev_id or 0
	local AudioPlayer = require("sdlAudioPlayer")
	local sndf = require"sndfile_ffi"
	local sdl = require"sdl2_ffi"
	
	if sdl.WasInit(sdl.INIT_AUDIO)==0 then
		sdl.InitSubSystem(sdl.INIT_AUDIO)
	end
	
	local info = sndf.get_info(soundfile)
	local dac,err = AudioPlayer({
    --device = device_name,
    freq = info.samplerate, 
    format = sdl.AUDIO_S16SYS,
    channels = info.channels, 
    samples = 1024})
	
	assert(dac,err)
	
	print("sdlAudioPlayer device info:")
	dac.obtained_spec[0]:print()
	
	dac:insert(soundfile,1,offset)
	local DURAMUSICA = info.frames/info.samplerate
	
	
	GL.timeprovider = MakeAudioPlayerTimeProvider(GL,dac,DURAMUSICA + offset +5 + (args.extratime or 0) )
end
local function newFPScounter(printer,inifps)
	printer = printer or print
	local frames = 0
	local time = 0
	local lasttime = 0
	local counter = {fpsec=inifps or 25}
	function counter:fps(timenow)
		local lapse = timenow - lasttime
		lasttime = timenow
		frames = frames + 1
		time = time + lapse
		if printer == print then
			if time > 1 then
				self.fpsec = frames/time
				printer("FPS",frames/time,time/frames,timenow)
				frames = 0
				time = 0
			end
		else
			--printer(string.format("%5.2f %5.2f",frames/time,timenow))
			--printer(string.format("%5.1f fps ",frames/time))
			if time > 1 then
				self.fpsec = frames/time
				printer(string.format("%5.1f fps ",frames/time))
				frames = 0
				time = 0
			end
		end
	end
	function counter:reset()
		frames = 0
		time = 0
		lasttime = 0
	end
	return counter
end

function ffistr(str)
	if str~=nil then
		return ffi.string(str)
	else
		return nil
	end
end
function print_glinfo(self)
	print("print_glinfo")
	--not glu in this:
	if not self.restricted then
		--GetGLError("in EXTENSIONS 0",true)
		print("glu.VERSION ",ffistr(glu.gluGetString(glc.GLU_VERSION)))
		print("glu.EXTENSIONS ",ffistr(glu.gluGetString(glc.GLU_EXTENSIONS)))
	else
		print("GLU not usable in CORE and >=3.2")
	end
	--GetGLError("in EXTENSIONS 1",true)
	print("gl.VENDOR ",ffistr(gl.glGetString(glc.GL_VENDOR)))
	print("gl.RENDERER ",ffistr(gl.glGetString(glc.GL_RENDERER)))
	print("gl.VERSION ",ffistr(gl.glGetString(glc.GL_VERSION))) 
	--print("gl.EXTENSIONS ",ffistr(gl.glGetString(glc.GL_EXTENSIONS)))

	local n = ffi.new"GLint[1]"
	gl.glGetIntegerv(glc.GL_NUM_EXTENSIONS, n);
	for i = 0,n[0]-1 do
		print(ffistr(glext.glGetStringi(glc.GL_EXTENSIONS, i)));
	end

	--GetGLError"in infooooooo"
	-- local nunits = ffi.new("int[1]")
	-- gl.glGetIntegerv(glc.GL_MAX_TEXTURE_UNITS,nunits)
	-- print("GL_MAX_TEXTURE_UNITS",string.format("%d",nunits[0]))
	
	local nunits = ffi.new("int[1]")
	gl.glGetIntegerv(glc.GL_MAX_TEXTURE_IMAGE_UNITS,nunits)
	print("GL_MAX_TEXTURE_IMAGE_UNITS",string.format("%d",nunits[0]))
	

	local colenc = ffi.new("GLint[1]")
	gl.glGetIntegerv(glc.GL_MAX_RENDERBUFFER_SIZE,colenc)
	print("GL_MAX_RENDERBUFFER_SIZE",colenc[0])
	

	gl.glGetIntegerv(glc.GL_MAX_TEXTURE_SIZE,colenc)
	print("GL_MAX_TEXTURE_SIZE",colenc[0])
	local colenc = ffi.new("GLint[2]")
	gl.glGetIntegerv(glc.GL_MAX_VIEWPORT_DIMS,colenc)
	print("GL_MAX_VIEWPORT_DIMS",colenc[0],colenc[1])
	print("GL_SHADING_LANGUAGE_VERSION",ffistr(gl.glGetString(glc.GL_SHADING_LANGUAGE_VERSION)));
	--GetGLError("print glinfo end",true)
	
	local NumOfSamples = ffi.new("GLuint[1]")
	gl.glGetIntegerv(glc.GL_MAX_SAMPLES, NumOfSamples);
	print("GL_MAX_SAMPLES",NumOfSamples[0])
end

function GetGLError(str, donterror)
	local iserror = false
	while true do
		local err = gl.glGetError()
		if err ~= glc.GL_NO_ERROR then
			print(str,"GetGLError opengl error:",err)
			--print((glu.gluErrorString(err)==nil) and "unknown error" or ffi.string(glu.gluErrorString(err)))
			iserror = true 
			if not donterror then error("opengl error",2) end
		else
			break;
		end
	end
	return iserror
end


require"anima.camera"
require"anima.camera2"
require"anima.animation"
local function GuiInitSDL(GL)
	GL.Impl = ig.Imgui_Impl_SDL_opengl3()
	
	
	ig.GetIO().ConfigFlags = ig.GetIO().ConfigFlags + imgui.ImGuiConfigFlags_NavEnableKeyboard
	local ok = pcall(function() return imgui.ImGuiConfigFlags_ViewportsEnable end)
	if ok then
		GL.has_imgui_viewport = true
		ig.GetIO().ConfigFlags = ig.GetIO().ConfigFlags + imgui.ImGuiConfigFlags_DockingEnable
		if GL.use_imgui_viewport then
			ig.GetIO().ConfigFlags = ig.GetIO().ConfigFlags + imgui.ImGuiConfigFlags_ViewportsEnable
		end
	end
	GL.Impl:Init(GL.window, GL.gl_context)
	
	GL.Ficons = gui.FontIcons(GL)
	GL.set_imgui_fonts()
	ig.lib.ImGui_ImplOpenGL3_CreateDeviceObjects()
	GL.cursors = GL.Ficons:GetCursors()
	
	GL.transport = gui.ImGui_Transport(GL)
	function GL.key_callback(window, key,  scancode,  action,  mods)
		if scancode == sdl.SCANCODE_F1 and action == sdl.PRESSED then
			local IsFullscreen = bit.band(sdl.getWindowFlags(GL.window), sdl.WINDOW_FULLSCREEN)~=0;
			sdl.setWindowFullscreen(GL.window,IsFullscreen and 0 or sdl.WINDOW_FULLSCREEN_DESKTOP)
		elseif (scancode == sdl.SCANCODE_F2 and action == sdl.PRESSED) then
			GL.show_imgui = not GL.show_imgui
		elseif (scancode == sdl.SCANCODE_SPACE and action == sdl.PRESSED) then
			GL.transport.play()
		elseif GL.tool == "glass" then
			if scancode == sdl.SCANCODE_LALT  then
				if  action == sdl.PRESSED then
					GL:SetCursor(GL.cursors.glass_m);
				elseif action == sdl.RELEASED then
					GL:SetCursor( GL.cursors.glass_p);
				end 
			elseif scancode == sdl.SCANCODE_LCTRL then
				if action == sdl.PRESSED then
					GL:SetCursor( GL.cursors.glass);
				elseif action == sdl.RELEASED then
					GL:SetCursor( GL.cursors.glass_p);
				end
			end
		end
	end
	local function toGLcoords(x,y)
		local wsx,wsy = GL:getWindowSize()
		return x,wsy - y - 1
	end
	
	GL.mxpos = ffi.new"double[1]"
	GL.mypos = ffi.new"double[1]"
	GL.mouse_but = {0,0,0}
	function GL.mouse_button_callbak(win, button, action,mods,x,y)

		if button == sdl.BUTTON_LEFT then
			GL.mouse_but[1] = (action == sdl.PRESSED) and 1 or 0
		end

		--GL.Impl.MouseButtonCallback(win, button, action, mods)
		--dont process mouse if used by imgui
		if ig.GetIO().WantCaptureMouse then return end
		
		if button == sdl.BUTTON_RIGHT then
			GL.mouse_but[2] = (action == sdl.PRESSED) and 1 or 0
			if GL.mouse_but[2]==1 then
				GL.opentoolbox = true
				return
			end
		end
		
		--glfw.glfwGetCursorPos(win, GL.mxpos,GL.mypos)
		GL.mxpos[0],GL.mypos[0] = x,y
		local X,Y = toGLcoords(GL.mxpos[0],GL.mypos[0])
		
		if GL.mouse_pick and button == sdl.BUTTON_LEFT and action == sdl.PRESSED then
			GL.pick_mouse_coords = {X,Y}
		elseif GL.mouse_pick and button == sdl.BUTTON_LEFT and GL.mouse_pick.action_rel and action == sdl.RELEASED then
			local mouse_pick = GL.mouse_pick
			--GL.mouse_pick = nil
			mouse_pick.action_rel(X,Y)
		elseif GL.tool == "hand" then
			if button == sdl.BUTTON_LEFT and action == sdl.PRESSED then
				GL.get_off_XY = {x=X,y=Y}
			elseif button == sdl.BUTTON_LEFT and action == sdl.RELEASED then
				GL.get_off_XY = nil
			end
		elseif GL.tool == "glass" then
			if button == sdl.BUTTON_LEFT and action == sdl.PRESSED then
				local modst = sdl.getModState()
				if bit.band(modst ,sdl.KMOD_ALT)~=0 then
					GL:GlassOffsets(X,Y,0.5)
				elseif bit.band(modst ,sdl.KMOD_CTRL)~=0 then				
					GL:GlassInit()
				else
					GL:SetCursor( GL.cursors.glass_p);
					GL:GlassOffsets(X,Y,2)
				end
			end
		end
	end
	GL.mouse_pos = {0,0}
	function GL.cursor_pos_callback(win, xpos, ypos)
		GL.mouse_pos = {xpos,ypos}
		if GL.get_off_XY then
			xpos,ypos = toGLcoords(xpos, ypos)
			GL.offX = GL.offX + xpos - GL.get_off_XY.x
			GL.offY = GL.offY + ypos - GL.get_off_XY.y
			GL.get_off_XY.x = xpos
			GL.get_off_XY.y = ypos
		end
		if GL.mouse_pos_cb then
			GL.mouse_pos_cb(toGLcoords(xpos, ypos))
		end
	end
end
local function GuiInitGLFW(GL)
	
	GL.Impl = ig.Imgui_Impl_glfw_opengl3() 
	--GL.Impl = ig.ImplGlfwGL3()

	print"imgui init"
	ig.GetIO().ConfigFlags = ig.GetIO().ConfigFlags + imgui.ImGuiConfigFlags_NavEnableKeyboard
	local ok = pcall(function() return imgui.ImGuiConfigFlags_ViewportsEnable end)
	if ok then
		GL.has_imgui_viewport = true
		ig.GetIO().ConfigFlags = ig.GetIO().ConfigFlags + imgui.ImGuiConfigFlags_DockingEnable
		if GL.use_imgui_viewport then
			ig.GetIO().ConfigFlags = ig.GetIO().ConfigFlags + imgui.ImGuiConfigFlags_ViewportsEnable
		end
	end
	GL.Impl:Init(GL.window, false,GL.glsl_version or "#version 130")
	print"imgui init done"
	
	GL:makeContextCurrent()
	
	GL.Ficons = gui.FontIcons(GL)
	GL.set_imgui_fonts()
	ig.lib.ImGui_ImplOpenGL3_CreateDeviceObjects()
	GL.cursors = GL.Ficons:GetCursors()
	
	GL.transport = gui.ImGui_Transport(GL)

	local saved_w_sett = { xpos = ffi.new"int[1]", ypos = ffi.new"int[1]",width = ffi.new"int[1]",height = ffi.new"int[1]"}
	local function key_callback(window, key,  scancode,  action,  mods)
		if (key == glfwc.GLFW_KEY_F1 and action == glfwc.GLFW_PRESS) then
			local monitor = glfw.glfwGetWindowMonitor(window) 
			print("F1",monitor,monitor==nil)

			if monitor ~= nil then --we are in fullscreen
				print"seting windowscreen"
				--local mode = glfw.glfwGetVideoMode(monitor);
				glfw.glfwSetWindowMonitor(window, nil, 
				saved_w_sett.xpos[0], saved_w_sett.ypos[0], saved_w_sett.width[0],saved_w_sett.height[0], 0);
			else
				--save position and size
				glfw.glfwGetWindowPos(window, saved_w_sett.xpos, saved_w_sett.ypos)
				glfw.glfwGetWindowSize(window, saved_w_sett.width, saved_w_sett.height)
				print"setting fullscreen"
				monitor = glfw.glfwGetPrimaryMonitor() 
				local mode = glfw.glfwGetVideoMode(monitor);			
				glfw.glfwSetWindowMonitor(window, monitor, 0, 0, mode.width, mode.height, mode.refreshRate);
			end
		elseif (key == glfwc.GLFW_KEY_F2 and action == glfwc.GLFW_PRESS) then
			GL.show_imgui = not GL.show_imgui
		elseif (key == glfwc.GLFW_KEY_SPACE and action == glfwc.GLFW_PRESS) then
			GL.transport.play()
		elseif GL.tool == "glass" then
			if key == glfwc.GLFW_KEY_LEFT_ALT  then
				if  action == glfwc.GLFW_PRESS then
					GL:SetCursor( GL.cursors.glass_m);
				elseif action == glfwc.GLFW_RELEASE then
					GL:SetCursor( GL.cursors.glass_p);
				end 
			elseif key == glfwc.GLFW_KEY_LEFT_CONTROL then
				if action == glfwc.GLFW_PRESS then
					GL:SetCursor(GL.cursors.glass);
				elseif action == glfwc.GLFW_RELEASE then
					GL:SetCursor(GL.cursors.glass_p);
				end
			end
		end
			
		GL.Impl.KeyCallback(window, key,scancode, action, mods);
	end
	
	local function toGLcoords(x,y)
		local wsx,wsy = GL:getWindowSize()
		return x,wsy - y - 1
	end
	
	GL.mxpos = ffi.new"double[1]"
	GL.mypos = ffi.new"double[1]"
	GL.mouse_but = {0,0,0}
	local function mouse_button_callbak(win, button, action,mods)

		if button == glfwc.GLFW_MOUSE_BUTTON_1 then
			GL.mouse_but[1] = (action == glfwc.GLFW_PRESS) and 1 or 0
		end
		
		GL.Impl.MouseButtonCallback(win, button, action, mods)
		--dont process mouse if used by imgui
		if ig.GetIO().WantCaptureMouse then return end
		
		if button == glfwc.GLFW_MOUSE_BUTTON_2 then
			GL.mouse_but[2] = (action == glfwc.GLFW_PRESS) and 1 or 0
			if GL.mouse_but[2]==1 then
				GL.opentoolbox = true
				return
			end
		end
		
		glfw.glfwGetCursorPos(win, GL.mxpos,GL.mypos)
		local X,Y = toGLcoords(GL.mxpos[0],GL.mypos[0])
		
		if GL.mouse_pick and button == glfwc.GLFW_MOUSE_BUTTON_1 and action == glfwc.GLFW_PRESS then
			GL.pick_mouse_coords = {X,Y}
		elseif GL.mouse_pick and button == glfwc.GLFW_MOUSE_BUTTON_1 and GL.mouse_pick.action_rel and action == glfwc.GLFW_RELEASE then
			local mouse_pick = GL.mouse_pick
			--GL.mouse_pick = nil
			mouse_pick.action_rel(X,Y)
		elseif GL.tool == "hand" then
			if button == glfwc.GLFW_MOUSE_BUTTON_1 and action == glfwc.GLFW_PRESS then
				GL.get_off_XY = {x=X,y=Y}
			elseif button == glfwc.GLFW_MOUSE_BUTTON_1 and action == glfwc.GLFW_RELEASE then
				GL.get_off_XY = nil
			end
		elseif GL.tool == "glass" then
			if button == glfwc.GLFW_MOUSE_BUTTON_1 and action == glfwc.GLFW_PRESS then
				if mods == glfwc.GLFW_MOD_ALT then
					GL:GlassOffsets(X,Y,0.5)
				elseif mods == glfwc.GLFW_MOD_CONTROL then
					GL:GlassInit()
				else
					GL:SetCursor(GL.cursors.glass_p);
					GL:GlassOffsets(X,Y,2)
				end
			end
		end

	end
	GL.mouse_pos = {0,0}
	local function cursor_pos_callback(win, xpos, ypos)
		GL.mouse_pos = {xpos,ypos}
		if GL.get_off_XY then
			xpos,ypos = toGLcoords(xpos, ypos)
			GL.offX = GL.offX + xpos - GL.get_off_XY.x
			GL.offY = GL.offY + ypos - GL.get_off_XY.y
			GL.get_off_XY.x = xpos
			GL.get_off_XY.y = ypos
		end
		if GL.mouse_pos_cb then
			GL.mouse_pos_cb(toGLcoords(xpos, ypos))
		end
	end
	local window = GL.window
	window:setCursorPosCallback(cursor_pos_callback)
	window:setMouseButtonCallback( mouse_button_callbak);
    window:setScrollCallback(GL.Impl.ScrollCallback) -- imgui.ImGui_ImplGlfwGL3_ScrollCallback);
	window:setSizeCallback(GL.OnResize2);
	window:setPosCallback(function() GL:action() end) --avoid draw blocking on move
	--window:setFocusCallback(function() print"focus-----------------------";GL:action() end)
	--window:setRefreshCallback(function() print"refresh-----------------------------------------";GL:action() end)
	window:setCharCallback(GL.Impl.CharCallback) --imgui.ImGui_ImplGlfwGL3_CharCallback);
	window:setKeyCallback(key_callback);
	print"Imgui inited"
	GetGLError"GuiInit"
end
local function GuiInit(GL)
	if GL.SDL then GuiInitSDL(GL)
	else GuiInitGLFW(GL)
	end
	ig.ImPlot_CreateContext()
end
--------------------------------------------------------------------------------------------
local singleton_canvas
function GLcanvas(GL)
	if singleton_canvas then error"another GLcanvas is opened" end
	singleton_canvas = true
	
	GL.fps = GL.fps or 25
	GL.FPScounter = newFPScounter(print,GL.fps)
	GL.globaltime = ffi.new"float[1]"
	GL.save_image = pointer("")
	GL.draw = function() end
	
	if GL.H and GL.aspect then
		GL.W = GL.H * GL.aspect
	elseif GL.W and GL.aspect then
		GL.H = GL.W / GL.aspect
	elseif GL.W and GL.H then
		GL.aspect = GL.W / GL.H
	else
		error("GL without sizes")
	end
	
	if GL.use_fbo == nil then GL.use_fbo=true end
	
	GL.viewH = GL.viewH or GL.H
	GL.viewW = GL.viewH * GL.aspect
	--Glass
	GL.scale = 1
	GL.offX = 0
	GL.offY = 0
	
	GL.profile = GL.profile or "COMPAT" --"ANY"
	
	--lj_glfw.init()
	
	GL.gl_version = GL.gl_version or {3,3} --{1,0}
	GL.v3_2plus = (GL.gl_version[1]>3 or (GL.gl_version[1]==3 and GL.gl_version[2] >=2))
	GL.v3_0plus = GL.gl_version[1]>=3
	GLSL.default_version = "#version 130\n"
	if (GL.profile == "CORE" and GL.v3_2plus) then
		GL.restricted = true
		GLSL.default_version = "#version 140\n"
	end
	
	GL.postdraw = function() end
	GL.keyframers = {}
	GL.animated_keyframers = {}
	if not GL.not_imgui then gui.SetImGui(GL) end

	function GL:initFBO(args,w,h)
		args = args or {}
		args.GL = self
		return initFBO(w or self.W,h or self.H, args)
	end
	
	function GL:initFBOMultiSample(args,w,h)
		return initFBOMultiSample(GL,w,h,args)
	end
	
	function GL:set_WH(W,H)
		W = W or self.W
		H = H or self.H
		print("set_WH",W,H)
		self.W = W 
		self.H = H 
		self.aspect = W/H
		if self.fbo then self.fbo:delete() end--TODO check _gc
		self.fbo = self:initFBO() --,{SRGB=self.SRGB}) 
		if self.SRGB then
			if self.srgb_fbo then self.srgb_fbo:delete() end--TODO check _gc
			self.srgb_fbo = self:initFBO({SRGB=true}) 
		end
		self.OnResize(self.window,self:getWindowSize()) --calculate viewW etc
		if self.plugins then
		for i,p in ipairs(self.plugins) do
			p.res = {W,H}
		end
		end
	end

	function GL:setMovie(dir,format,ext)
		format = format or "TIFF"
		ext = ext or ".tif"
		self.movie = require"anima.movie":new{directory=dir,ext=ext,format=format,GL=self}
	end

	function GL:SaveImage(filename,formato) --,w,h)
		local oldfboread
		if self.SRGB then
			gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
			--self.fbo:Dump(self.srgb_fbo.fb[0])
			self.srgb_fbo:Bind()
			ut.Clear()
			self.fbo:GetTexture():blit(self.W,self.H)
			self.srgb_fbo:UnBind()
			oldfboread = self.srgb_fbo:BindRead()
			gl.glDisable(glc.GL_FRAMEBUFFER_SRGB)
		else
			oldfboread = self.fbo:BindRead()
		end
		
		GetGLError"SaveImage"
		local formato = formato or "TIFF"
		local w,h = self.W, self.H
		print("GetImage",w,h)
		local pixelsUserData = ffi.new("char[?]",w*h*4) 
		
		local intformat = glc.GL_RGBA --self.SRGB and glc.GL_SRGB8_ALPHA8 or glc.GL_RGBA
		--if self.SRGB then gl.glEnable(glc.GL_FRAMEBUFFER_SRGB) end
		
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER,0)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(0,0, w, h, intformat, glc.GL_UNSIGNED_BYTE, pixelsUserData)
		
		--if self.SRGB then gl.glDisable(glc.GL_FRAMEBUFFER_SRGB) end
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER,oldfboread)

		local image = im.ImageCreateFromOpenGLData(w, h, glc.GL_RGBA, pixelsUserData); 
		--local err = im.FileImageSave(filename,formato,image)
		local err = image:FileSave(filename,formato)
		if (err and err ~= im.ERR_NONE) then
			print("saved",filename)
			error(im.ErrorStr(err))
		end
		--im.ImageDestroy(image)
		image:Destroy()
	end
	
	function GL:SaveImageGet(filename,formato) --,w,h)

		self.fbo:GetTexture():Bind()

		GetGLError"SaveImage"
		local formato = formato or "TIFF"
		local w,h = self.W, self.H
		print("GetImage",w,h)
		local pixelsUserData = ffi.new("char[?]",w*h*4) 
		
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER,0)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glGetTexImage(glc.GL_TEXTURE_2D, 0, glc.GL_RGBA, glc.GL_UNSIGNED_BYTE, pixelsUserData)

		local image = im.ImageCreateFromOpenGLData(w, h, glc.GL_RGBA, pixelsUserData); 
		local err = image:FileSave(filename,formato)
		if (err and err ~= im.ERR_NONE) then
			print("saved",filename)
			error(im.ErrorStr(err))
		end
		--im.ImageDestroy(image)
		image:Destroy()
	end
	
	function GL:SaveImagePBO(filename,formato)
		formato = formato or "TIFF"
		
		GL.fbo:BindRead()

		local w,h =  self.W, self.H
		local nbytes = w*h*3*ffi.sizeof"char"
		
		local pbo = ffi.new("GLuint[1]")
		glext.glGenBuffers(1,pbo)
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, pbo[0]);
		glext.glBufferData(glc.GL_PIXEL_PACK_BUFFER, nbytes, nil, glc.GL_STREAM_READ);
		
		local pixelsUserData = ffi.new("char[?]",w*h*3)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(0,0, w, h, glc.GL_RGB, glc.GL_UNSIGNED_BYTE, ffi.cast("void *",0))
		
		local ptr = glext.glMapBuffer(glc.GL_PIXEL_PACK_BUFFER, glc.GL_READ_ONLY);
		assert(ptr ~= nil,"glMapBuffer error")
		ffi.copy(pixelsUserData, ptr, nbytes)
		glext.glUnmapBuffer(glc.GL_PIXEL_PACK_BUFFER);
		
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, 0);
		glext.glDeleteBuffers(1,pbo)
		GetGLError"SaveImagePBO"
		
		local image = imffi.imImageCreateFromOpenGLData(w, h, glc.GL_RGB, pixelsUserData); 
		local err = imffi.imFileImageSave(filename,formato,image)
		if (err and err ~= im.ERR_NONE) then
			print("saved",filename)
			error(im.ErrorStr(err))
		end
		imffi.imImageDestroy(image)
	end
	function GL:SaveImage16(filename,formato,w,h)
		--make sure we read from last draw
		-- local drawbuf = ffi.new("GLint[1]",0)
		-- gl.glGetIntegerv(glc.GL_DRAW_FRAMEBUFFER_BINDING, drawbuf)
		-- glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER, drawbuf[0]);
		GL.fbo:BindRead()
		
		local function checkError(err)
			if (err and err ~= im.ERR_NONE) then
				print(filename,err)
				error(im.ErrorStr(err))
			end
		end
		formato = formato or "TIFF"
		w,h = w or self.W, h or self.H
		local pixelsUserData = ffi.new("short[?]",w*h*4)
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER,0)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(0,0, w, h, glc.GL_RGBA, glc.GL_UNSIGNED_SHORT, pixelsUserData)
		
		local err = ffi.new("int[1]")
		local ifile = im.imffi.imFileNew(filename, formato,err);
		checkError(err[0])
		local err2 = im.imffi.imFileWriteImageInfo(ifile,w, h, im.RGB + im.ALPHA + im.PACKED, im.USHORT);
		checkError(err2)
		err2 = im.imffi.imFileWriteImageData(ifile, pixelsUserData);
		checkError(err2)
		--im.imffi.imFileClose(ifile); 
		ifile:Close()
	end
	
	function GL:SaveImageVICIM(filename)
		local vicim = require"anima.vicimag"
		GL.fbo:BindRead()

		local w,h =  self.W, self.H
		local pixelsUserData = ffi.new("float[?]",w*h*4)
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER,0)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(0,0, w, h, glc.GL_RGBA, glc.GL_FLOAT, pixelsUserData)
		
		GetGLError"SaveImageVICIM"
		vicim.save(filename,pixelsUserData,w,h,4)

	end
	
	function GL:SaveImageVICIMPBO(filename)
		local vicim = require"anima.vicimag"
		GL.fbo:BindRead()

		local w,h =  self.W, self.H
		local nbytes = w*h*3*ffi.sizeof"float"
		
		local pbo = ffi.new("GLuint[1]")
		glext.glGenBuffers(1,pbo)
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, pbo[0]);
		glext.glBufferData(glc.GL_PIXEL_PACK_BUFFER, nbytes, nil, glc.GL_STREAM_READ);
		
		local pixelsUserData = ffi.new("float[?]",w*h*3)
		--gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(0,0, w, h, glc.GL_RGB, glc.GL_FLOAT, ffi.cast("void *",0))
		
		local ptr = glext.glMapBuffer(glc.GL_PIXEL_PACK_BUFFER, glc.GL_READ_ONLY);
      if (nil ~= ptr) then
		ffi.copy(pixelsUserData, ptr, nbytes)
        glext.glUnmapBuffer(glc.GL_PIXEL_PACK_BUFFER);
      else
		error()
	  end
		
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, 0);
		GetGLError"SaveImageVICIMPBO"
		vicim.save(filename,pixelsUserData,w,h,3)

	end


	
	function GL:CheckSRGB()
		local framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, framebuffer)
		--only render srgb to screen and if not need to mouse_pick color
		if self.SRGB and framebuffer[0]== 0 and not GL.mouse_pick then
			gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
		end
	end
	
	function GL:predraw(w,h)
		local timebegin
	
		if GL.DORENDER then
			timebegin = GL.animation:animate()
		else
			timebegin = GL.timeprovider:get_time() 
			GL.animation:animate(timebegin)
		end
		
		for i,v in ipairs(self.animated_keyframers) do v:animate(timebegin) end
		
		GL.globaltime[0] = timebegin

		return timebegin
	end
	
	function GL:FBODrawPrivate(alfa_alone)
		local x,y,w,h = unpack(self.stencil_sizes)
		local tex = self.fbo:GetTexture()
		tex:Bind()
		tex:gen_mipmap()
		if GL.fbo_nearest then
			tex:mag_filter(glc.GL_NEAREST)
			tex:min_filter(glc.GL_NEAREST)
		else
			--tex:gen_mipmap()
		end
		if alfa_alone then
			tex:drawpos_alpha(x+self.offX,y+self.offY,w*self.scale,h*self.scale)
		else
			tex:drawpos(x+self.offX,y+self.offY,w*self.scale,h*self.scale)
		end
	end
	function GL:FBODraw()
		local GL = self
		if GL.use_fbo then
			glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, 0);
			gl.glClearColor(0.1,0.1,0.1,1)
			ut.Clear()
			gl.glClearColor(0,0,0,1)
			local colm = GL.colormasks
			local alpha_alone = colm.alpha[0]
			if not alpha_alone then gl.glColorMask(colm.red[0], colm.green[0], colm.blue[0], glc.GL_TRUE) end
			if GL.SRGB then
				gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
				self:FBODrawPrivate(alpha_alone)
				gl.glDisable(glc.GL_FRAMEBUFFER_SRGB)
			else
				self:FBODrawPrivate(alpha_alone)	
			end	
			gl.glColorMask(glc.GL_TRUE, glc.GL_TRUE,glc.GL_TRUE,glc.GL_TRUE)
		end
		GetGLError("fbo_dump")
		--mouse pick
		if GL.mouse_pick and GL.pick_mouse_coords then
			local xm,ym = unpack(GL.pick_mouse_coords)
			local mouse_pick = GL.mouse_pick
			--GL.mouse_pick = nil
			GL.pick_mouse_coords = nil
			mouse_pick.action(xm,ym)
		end
	end
	function GL:get_time()
		return self.globaltime[0] --or 0
	end
	
	local lasttimefps
	local function actionSDL(self)
		if not lasttimefps then lasttimefps = sdl.getTicks() end
		local GL = self
		--print("action",self)
		GetGLError"action ini"
		local tbeg = self:predraw(self.W,self.H)
		
		sdl.gL_MakeCurrent(self.window, self.gl_context);
		
		if self.use_fbo then self.fbo:Bind() end
		
		GetGLError"action ini 2"
		self.draw(tbeg, self.W, self.H)
		GetGLError("Error after canvas.draw")--,true)
---[[		
		
		if GL.DORENDER then
			if GL.RENDERINI <= tbeg and GL.RENDEREND > tbeg then
				GL.movie:SaveFrame(GL,tbeg)
				GetGLError("RENDER")
			else
				GL:quit()
			end
		end
		
		if GL.save_image[0]~="" then
			GL:SaveImageGet(GL.save_image[0],GL.save_image_type or "TIFF")
			--GL:SaveImage(GL.save_image[0]..".jpg","JPEG")
			--GL:SaveImageVICIMPBO(GL.save_image[0]..".vic")
			--GL:SaveImageVICIM(GL.save_image[0]..".vic")
			--GL:SaveImagePBO(GL.save_image[0]..".tif")
			GetGLError("save_image")
			print("save:",GL.save_image[0])
			GL.save_image[0] = ""
		end
		
		if true then --not (self.window:getAttrib( glc.GLFW_ICONIFIED)>0) then --iconif
		--strange error on gl.ortho(0,0,0,0...
			self:FBODraw()
			self:postdraw()
		end --iconif
		
		GetGLError("postdraw")
--]]		
		sdl.gL_SwapWindow(self.window);
		
		if not GL.DORENDER then
		while (sdl.getTicks() < lasttimefps + 1000.0/GL.fps) do
        -- TODO: Put the thread to sleep, yield, or simply do nothing
			sdl.Delay(10)
		end
		lasttimefps = lasttimefps + 1000.0/GL.fps;
		end
	end
	
	
	local function actionGLFW(self)
		if not lasttimefps then lasttimefps = glfw.glfwGetTime() end
		local GL = self
		--print("action",self)
		GetGLError"action ini"
		local tbeg = self:predraw(self.W,self.H)
		
		self.window:makeContextCurrent()
		
		if self.use_fbo then self.fbo:Bind() end
		
		GetGLError"action ini 2"
		self.draw(tbeg, self.W, self.H)
		GetGLError("Error after canvas.draw")--,true)
---[[		
		
		if GL.DORENDER then
			if GL.RENDERINI <= tbeg and GL.RENDEREND > tbeg then
				GL.movie:SaveFrame(GL,tbeg)
				GetGLError("RENDER")
			else
				GL:quit()
			end
		end
		
		if GL.save_image[0]~="" then
			GL:SaveImageGet(GL.save_image[0],GL.save_image_type or "TIFF")
			--GL:SaveImage(GL.save_image[0]..".jpg","JPEG")
			--GL:SaveImageVICIMPBO(GL.save_image[0]..".vic")
			--GL:SaveImageVICIM(GL.save_image[0]..".vic")
			--GL:SaveImagePBO(GL.save_image[0]..".tif")
			GetGLError("save_image")
			print("save:",GL.save_image[0])
			GL.save_image[0] = ""
		end
		
		if not (self.window:getAttrib( glfwc.GLFW_ICONIFIED)>0) then --iconif
		--strange error on gl.ortho(0,0,0,0...
			self:FBODraw()
			self:postdraw()
		end --iconif
		
		GetGLError("postdraw")
--]]		
		self.window:swapBuffers()
		
		if not GL.DORENDER then
		while (glfw.glfwGetTime() < lasttimefps + 1.0/GL.fps) do
        -- TODO: Put the thread to sleep, yield, or simply do nothing
		ig.lib.ImGui_ImplGlfw_Sleep(10);
		end
		lasttimefps = lasttimefps + 1.0/GL.fps;
		end
	end
	local function startSDL(self,postf) 

		self:doinit()
		
		local ev2ig
		if self.not_imgui then
			ev2ig = function() end
		else
			ev2ig = function(event) ig.lib.ImGui_ImplSDL2_ProcessEvent(event); end
		end
		
		local done = false
		while not done do

			local event = ffi.new"SDL_Event"
			while (sdl.pollEvent(event) ~=0) do
				ev2ig(event);
				if (event.type == sdl.QUIT) then
					done = true;
				end
				if (event.type == sdl.WINDOWEVENT) then 
					if (event.window.event == sdl.WINDOWEVENT_CLOSE and event.window.windowID == sdl.getWindowID(window)) then
						done = true;
					elseif event.window.event == sdl.WINDOWEVENT_SIZE_CHANGED then
						self.OnResize(self.window,event.window.data1,event.window.data2)
					end
				elseif event.type == sdl.KEYDOWN or event.type == sdl.KEYUP then 
					self.key_callback(self.window, event.key.keysym.sym, event.key.keysym.scancode, event.key.state, event.key.keysym.mod)
				elseif event.type ==  sdl.MOUSEBUTTONDOWN or event.type == sdl.MOUSEBUTTONUP then
					local button = event.button
					self.mouse_button_callbak(self.window,button.button,button.state,nil,button.x,button.y)
				elseif event.type == sdl.MOUSEMOTION then
					self.cursor_pos_callback(self.window,event.motion.x,event.motion.y)
				end
			end
			
			self:action()
			
		end
		
		if postf then postf() end
		if GL.use_log then print = GL.luaprint end
		if not GL.not_imgui then self.Impl:destroy() end
		
		--self.window:destroy()
		sdl.destroyWindow(self.window)
		sdl.quit()
		--dont destroy in case multiwindow
		--imgui.igShutdown();
		--lj_glfw.terminate()
		singleton_canvas = nil
	end
	local function startGLFW(self, postf) 

		self:doinit()
		
		while not self.window:shouldClose() do
			lj_glfw.pollEvents()
			self:action()

		end
		-- Destroy the window and deinitialize GLFW.
		--free callbacks??
		--[[
		local window = self.window
		window:setCursorPosCallback(nil)
		window:setMouseButtonCallback( nil);
        window:setScrollCallback( nil);
		window:setSizeCallback(nil);
		window:setCharCallback(nil);
		window:setKeyCallback(nil);
		--]]
		if postf then postf() end
		if GL.use_log then print = GL.luaprint end
		if not GL.not_imgui then self.Impl:destroy() end
		
		self.window:destroy()
		
		
		--dont destroy in case multiwindow
		--imgui.igShutdown();
		lj_glfw.terminate()
		singleton_canvas = nil
	end
	
	local function GLgetAspectViewport(width,height)
		local GLaspect = GL.aspect
		local aspect = width/height
			
		local newW,newH,xpos,ypos
		if aspect > GLaspect then
			newW,newH = math.floor(height*GLaspect+0.5), height
		elseif aspect < GLaspect then
			newW,newH = width,math.floor(0.5 + width/GLaspect)
		else
			newW,newH = width, height
		end
		xpos = math.floor(0.5*(width - newW)+0.5)
		ypos = math.floor(0.5*(height - newH)+0.5)
		return xpos,ypos,newW,newH
	end
	GL.getAspectViewport = GLgetAspectViewport
	
	local int_buffer = ffi.new("int[2]")
	
	local function OnResize(win,width, height)
		local sizes = {GLgetAspectViewport(width,height)}
		GL.stencil_sizes = sizes
		GL.viewW, GL.viewH = sizes[3],sizes[4]
		-- gl.glScissor(unpack(sizes))
		-- gl.glEnable(glc.GL_SCISSOR_TEST);
		-- gl.glViewport(unpack(sizes))
 
		print("setSizeCallback",width,height)
		print(unpack(sizes))
		--glfw.glfwGetFramebufferSize(win,int_buffer,int_buffer+1)
		--print(int_buffer[0],int_buffer[1])
	end
	local function OnResize2(win,width, height)
		OnResize(win,width, height)
		GL:action()
	end
	
	GL.OnResize = OnResize
	GL.OnResize2 = OnResize2
	--for converting from window coordinates to GL.fbo coordinates
	function GL:ScreenToViewport(X,Y)
		local x,y,w,h = unpack(self.stencil_sizes)
		x= x + self.offX
		y= y + self.offY
		w = w*self.scale
		h = h*self.scale
		return self.W*(X - x)/w,self.H*(Y - y)/h
	end
	function GL:ViewportToScreen(X,Y)
		local x,y,w,h = unpack(self.stencil_sizes)
		x= x + self.offX
		y= y + self.offY
		w = w*self.scale
		h = h*self.scale
		return X*w/self.W + x, Y*h/self.H + y
	end
	--makes ScreenToViewport return the same values for X and Y after fac in GL.scale
	function GL:GlassOffsets(X,Y,fac)
		local x,y,w,h = unpack(self.stencil_sizes)
		local fac1 = 1- fac
		self.offX, self.offY, self.scale = (X-x)*fac1+fac*self.offX, (Y-y)*fac1+fac*self.offY, self.scale*fac
	end
	function GL:GlassInit()
		self.offX, self.offY, self.scale = 0, 0, 1
	end
	
	GL.chktextures = {}
	function GL:addTexture(n,info)
		if(self.chktextures[n]) then
			print("texture ",n,"already present",info)
			prtable(GL.chktextures)
			error("hhh",2)
		end
		self.chktextures[n] = info
	end
	function GL:removeTexture(n,info)
		if not self.chktextures[n] then
			print("texture",n,"not present",info)
			--print(debug.traceback())
			prtable(GL.chktextures)
			error("iii",2)
		end
		self.chktextures[n] = nil
	end
	
	local function doinitCOMMON(self)
		--require"anima.GLSL"
		-----------------------------------------------------------------------------------
		--print_glinfo(self)
		self.colormasks = {red = ffi.new("bool[1]",true),
							green = ffi.new("bool[1]",true),
							blue = ffi.new("bool[1]",true),
							alpha = ffi.new("bool[1]",false)}
		if self.profile == "COMPAT" then

			GetGLError"doinit 2"
			gl.glEnable(glc.GL_TEXTURE_2D)    
			gl.glEnable(glc.GL_DEPTH_TEST);
			--gl.glEnable(glc.GL_POLYGON_SMOOTH)
			--gl.glEnable(glc.GL_LINE_SMOOTH)
			GetGLError"doinit 3"
			gl.glHint(glc.GL_POINT_SMOOTH_HINT,glc.GL_NICEST)
			gl.glHint(glc.GL_LINE_SMOOTH_HINT,glc.GL_NICEST)
			gl.glHint(glc.GL_POLYGON_SMOOTH_HINT,glc.GL_NICEST)
			gl.glHint(glc.GL_PERSPECTIVE_CORRECTION_HINT,glc.GL_NICEST)
			GetGLError"doinit 4"
			gl.glShadeModel(glc.GL_SMOOTH) --gl.FLAT --gl.SMOOTH
	
			--------fog
			GetGLError"preinit fog"
			if GL.fog then
				gl.glEnable(glc.GL_FOG);
				gl.glFog(glc.GL_FOG_MODE,glc.GL_EXP2);--gl.LINEAR
				gl.glFog(glc.GL_FOG_COLOR,{0, 0, 0, 0});
				gl.glFog(glc.GL_FOG_DENSITY, 0);
				gl.glHint(glc.GL_FOG_HINT,glc.GL_NICEST) --gl.DONT_CARE);
			end
		else
			gl.glEnable(glc.GL_DEPTH_TEST);
		end
		
		GL.animation:animate(GL.RENDERINI or 0)
		GL.timeprovider:set_time(GL.RENDERINI or 0)
		
		if not self.not_imgui then GuiInit(self) end
		
		if GL.plugins then
			for i,v in ipairs(GL.plugins) do
				if not v.inited then
				print("call init on plugin",v.name)
				if not v.init then
					prtable(v.plug)
				else
					v:init()
				end
				--self.window:makeContextCurrent()
				self:makeContextCurrent()
				--self:postdraw()
				io.write(string.format("plug %d\n",i))
				--self.window:swapBuffers()
				self:swapBuffers()
				v.inited = true
				end
			end
		end
		
		if GL.use_fbo then self:set_WH() end
		
		if GL.init then GL.in_init = true;print"GL.init()";GL:init();GL.in_init = false end
		
		if not self.not_imgui then self:set_initial_curr_notmodal() end
		
		function self:LockCursor() ig.GetIO().ConfigFlags =  bit.bor(ig.GetIO().ConfigFlags, ig.lib.ImGuiConfigFlags_NoMouseCursorChange) end
		function self:UnLockCursor() ig.GetIO().ConfigFlags =  bit.band(ig.GetIO().ConfigFlags, bit.bnot(ig.lib.ImGuiConfigFlags_NoMouseCursorChange)) end
		
		GetGLError("INIT")
	
	end
	local function doinitSDL(self)
		sdl = require"sdl2_ffi" 
		--sdl = require"sdl2"
		local gllib = require"gl"
		gllib.set_loader(sdl)
		gl, glc, glu, glext = gllib.libraries()
		
		if self.DEBUG then
			gl = gllib.glErrorWrap(gl)
			glext = gllib.glErrorWrap(glext)
		end
		
		self.FPScounter = newFPScounter(function(str) sdl.setWindowTitle(self.window, str) end,self.fps)
		
		if (sdl.init(sdl.INIT_VIDEO+sdl.INIT_TIMER) ~= 0) then
			print(string.format("Error: %s\n", sdl.getError()));
			error()
		end
		--sdl.gL_SetAttribute(sdl.GL_CONTEXT_FLAGS, sdl.GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
		if self.profile == "COMPAT" then
		sdl.gL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, sdl.GL_CONTEXT_PROFILE_COMPATIBILITY);
		else --CORE
		sdl.gL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, sdl.GL_CONTEXT_PROFILE_CORE);
		end
		sdl.gL_SetAttribute(sdl.GL_DOUBLEBUFFER, 1);
		sdl.gL_SetAttribute(sdl.GL_DEPTH_SIZE, 24);
		sdl.gL_SetAttribute(sdl.GL_STENCIL_SIZE, 8);
		sdl.gL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, self.gl_version[1]);
		sdl.gL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, self.gl_version[2]);
		
		local extraflags = 0
		if self.invisible then extraflags = sdl.SDL_WINDOW_HIDDEN end
		local window = sdl.createWindow(self.name or "", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, self.viewW, self.viewH, sdl.WINDOW_OPENGL+sdl.WINDOW_RESIZABLE+extraflags); 

		self.window = window
		local gl_context = sdl.gL_CreateContext(window);
		self.gl_context = gl_context
		
		function self:makeContextCurrent() sdl.gL_MakeCurrent(self.window, self.gl_context); end
		function self:swapBuffers() sdl.gL_SwapWindow(self.window); end
		function self:getWindowSize()
			local w,h = ffi.new("int[1]"),ffi.new("int[1]")
			sdl.getWindowSize(self.window,w,h)
			return w[0],h[0]
		end
		local nilcursor = sdl.getCursor()
		function self:SetCursor(c) return sdl.setCursor(c or nilcursor) end
		function self:checkcontext() return sdl.gL_GetCurrentContext()==self.gl_context end
		OnResize(self.window,self:getWindowSize()) --it is not called fist time
		sdl.gL_MakeCurrent(window, gl_context);
		if self.vsync then sdl.gL_SetSwapInterval(type(self.vsync)=="number" and self.vsync or 1) end
		doinitCOMMON(self)
	end
	local function doinitGLFW(self)
		lj_glfw  = require "glfw"
		local gllib = require"gl"
		gllib.set_loader(lj_glfw)
		gl, glc, glu, glext = gllib.libraries()
		glfw = lj_glfw.glfw
		glfwc = lj_glfw.glfwc
		
		if self.DEBUG then
			gl = gllib.glErrorWrap(gl)
			glext = gllib.glErrorWrap(glext)
		end

		swapped_glc = swap_keyvalue(glc)
		glfw.glfwSetErrorCallback(function(error,description)
			print("GLFW error:",error,ffi.string(description));
		end)
		self.FPScounter = newFPScounter(function(str) glfw.glfwSetWindowTitle(self.window, str) end,self.fps)
		
		lj_glfw.init()
		--glfw.glfwWindowHint(glc.GLFW_CLIENT_API, glc.GLFW_OPENGL_ES_API)
		
		glfw.glfwWindowHint(glfwc.GLFW_CONTEXT_VERSION_MAJOR, self.gl_version[1]);
		glfw.glfwWindowHint(glfwc.GLFW_CONTEXT_VERSION_MINOR, self.gl_version[2]);
		
		if self.v3_2plus then
		glfw.glfwWindowHint(glfwc.GLFW_OPENGL_PROFILE, glfwc["GLFW_OPENGL_"..self.profile.."_PROFILE"]);
		end
		
		if self.v3_0plus then
		if jit.os == "OSX" then
			glfw.glfwWindowHint(glfwc.GLFW_OPENGL_FORWARD_COMPAT, glc.GL_TRUE);
		else
			glfw.glfwWindowHint(glfwc.GLFW_OPENGL_FORWARD_COMPAT, self.forward and glc.GL_TRUE or glc.GL_FALSE);
		end
		end
		
		if self.invisible then glfw.glfwWindowHint(glfwc.GLFW_VISIBLE, glfwc.GLFW_FALSE) end
		
		--[[ setting screen multisample
		local window = lj_glfw.Window(self.viewW, self.viewH, self.name or "")
		local NumOfSamples = ffi.new("GLuint[1]")
		window:makeContextCurrent()
		gl.glGetIntegerv(glc.GL_MAX_SAMPLES, NumOfSamples);
		print("GLFW_SAMPLES",NumOfSamples[0])
		window:swapBuffers()
		window:destroy()
		glfw.glfwWindowHint(glfwc.GLFW_SAMPLES, NumOfSamples[0])
		--]]
		
		local window = lj_glfw.Window(self.viewW, self.viewH, self.name or "")
		self.window = window
		
		function self:makeContextCurrent() self.window:makeContextCurrent() end
		function self:swapBuffers() self.window:swapBuffers() end
		function self:getWindowSize() return self.window:getSize() end
		function self:SetCursor(c) return glfw.glfwSetCursor(self.window,c) end
		function self:checkcontext() return self.window==glfw.glfwGetCurrentContext() end
		
		OnResize(self.window,self:getWindowSize()) --it is not called fist time
		self.window:makeContextCurrent()
		
		if self.vsync then lj_glfw.swapInterval(type(self.vsync)=="number" and self.vsync or 1) end
		GetGLError"doinit ini"
		

		doinitCOMMON(self)
	end
	
	--GL.plugins will be used for calling init , for DirtyWrap and set_WH (not really done: sets p.res)
	function GL:add_plugin(plugin,name)
		if self.in_init then
			plugin:init()
			plugin.inited = true
		end
		print("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxaddplugin: " .. (name or plugin.name or "unnamed"),"NM",plugin.NM)
		self.plugins = self.plugins or {}
		self.plugins[#self.plugins + 1] = plugin --{plugin=plugin,name=name or ""}

		--Log draw
		if self.window then
		self:makeContextCurrent()
		--self:postdraw()
		io.write(string.format("GL:add_plugin %s\n",name or ""))
		self:swapBuffers()
		end
	end
	GL.render_source = "master1080"
	GL.comp_source = "compressed1080"
	GL.comp_ext = ".cmp"
	GL.render_ext = ".tif"
	function GL:Texture(w,h,form,texor)
		local tex = Texture(w,h,form,texor,{GL=self})
		tex.GL = self
		local path = require"anima.path"
		function tex:GLLoad(filename)
			local sourcedir = (self.GL.DORENDER and self.GL.render_source) or self.GL.comp_source
			local ext = (self.GL.DORENDER and self.GL.render_ext) or self.GL.comp_ext
			local fname = path.chain(self.GL.rootdir,sourcedir,filename..ext)
			return self:Load(fname,self.GL.SRGB,self.GL.mipmaps)
		end
		return tex
	end
	function GL:Texture1D(w,formato,data,format,type)
		return Texture1D(w,formato,data,format,type,{GL=self})
	end
	function GL:CreateVolume(w,h,d,ncomp)
		return CreateVolume(w,h,d,ncomp,GL)
	end
	function GL:make_slab()
		return MakeSlab(self.W,self.H,nil,self)
	end
	---------
	GL.fbo_pool = {}
	function GL:get_fbo()
		--if empty create
		if #self.fbo_pool > 0 then
			local fbo = self.fbo_pool[1]
			table.remove(self.fbo_pool,1)
			return fbo
		else
			local fbo = self:initFBO({no_depth=true})
			fbo.release = function(self)
						GL.fbo_pool[#GL.fbo_pool + 1] = self
					end
			return fbo
		end
	end
	---------
	-- wraps plugins.process and process_fbo functions to be called only if is dirty
	-- because changed NM values or new texture provided
	function GL:DirtyWrap()
		self.dirty_wrapped = true
		self.plugins = self.plugins or {}
		for i,p in ipairs(self.plugins) do
			print("GL:DirtyWrap",i,p,p.name)
		end
		for i,p in ipairs(self.plugins) do
			--if not p.NM.isDBox then
			print("DirtyWrap",p,p.NM,p.NM and p.NM.name or "unman")
			--prtable(p)
			p.oldprocess=p.process
			p.NM.dirty = true
			p.process = function(self,tex,w,h)
				self:set_texsignature(tex)
				if self:IsDirty() then
					--print("call process",self.NM.name)
					self.oldprocess(self,tex,w,h)
					if not p.always_dirty then
						--print("always dirty",self.NM.name)
						self.NM.dirty = false 
					end
				end
			end
			p.oldprocess_fbo = p.process_fbo
			p.process_fbo = function(self,fbo,tex)
				self:set_texsignature(tex)
				if self:IsDirty() then
					--print("call process_fbo",self.NM.name)
					--self.oldprocess_fbo(self,fbo,tex)
					fbo:Bind()
					self.oldprocess(self,tex)
					fbo:UnBind()
					fbo:tex():inc_signature()
					if not p.always_dirty then 
						self.NM.dirty = false 
					end
				end
			end
		end
	end
	GL.timeprovider = MakeDefaultTimeProvider(GL)
	GL.animation = Animation:new({fps = GL.fps})
	
	local function QuitGLFW(GL)
		GL.window:setShouldClose(glfwc.GLFW_TRUE)
	end
	
	local function QuitSDL(GL)
		local event = ffi.new"SDL_Event"
		event.type = sdl.QUIT
		sdl.pushEvent(event)
	end
	----------------------
	if not GL.SDL then 
		GL.doinit = doinitGLFW
		GL.action = actionGLFW
		GL.start = startGLFW
		GL.quit = QuitGLFW
	else
		GL.doinit = doinitSDL
		GL.action = actionSDL
		GL.start = startSDL
		GL.quit = QuitSDL
	end
	---------------------
	return GL
end
require"anima.font_utils"
