
local vert_shad2 = [[

void main()
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = ftransform();
}

]]
local frag_shad2 = [[
uniform sampler2D tex0;

void main()
{
	gl_FragColor = texture2D(tex0,gl_TexCoord[0].st);
}
]]


local frag_shadmix = [[
uniform sampler2D tex0;
uniform float alpha;

void main()
{
	
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	//if(color.a < 0.5)
	//	discard;
	color.a *= alpha;
	gl_FragColor = color;

}
]]

local function ClearFBO(fbo,color)
	color = color or {0,0,0,0}
	glext.glUseProgram(0);
	glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbo.fb[0]);
	gl.glClearColor(unpack(color))
	gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
end

local function clamp()
	local modewrap = glc.GL_CLAMP --glc.GL_MIRRORED_REPEAT --glc.GL_CLAMP --glc.GL_REPEAT --glc.GL_MIRRORED_REPEAT
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
end

local M = {}

function M.layers_mixer(GL, post)
	local ANCHO = GL.W
 	local ALTO = GL.H
	local LM = {}
	local mixfbo = {}
	local fbo, programmix, program2

	--local clips = {}
	local usemsaa = false
	local textype = glc.GL_TEXTURE_2D
	if usemsaa then
		textype = glc.GL_TEXTURE_2D_MULTISAMPLE
	end	
	function LM:init()

		if usemsaa then
			mixfbo = GL:initFBOMultiSample()
			fbo = GL:initFBOMultiSample()
		else
			mixfbo = GL:initFBO()
			fbo = GL:initFBO()
		end
		programmix = GLSL:new():compile(vert_shad2,frag_shadmix)
		program2 = GLSL:new():compile(vert_shad2,frag_shad2)
		LM.inited = true
	end

	local function get_args(t, timev)
		local theclip = t.clip or t[3]
		theclip.clippos = t.pos
		local alpha = ut.get_var(t.alpha,math.max(0,timev - t.pos), 1)
		local alphaM = ut.get_var(t.alphaM,math.max(0,timev - t.pos), 1)
		local cliptime = ut.get_var(t.cliptime,timev - t.pos,timev - t.pos)
		return theclip, alpha, cliptime,alphaM
	end

	function LM:draw(timebegin, w, h, args, fade)
		if not self.inited then self:init() end
		fade = fade or 1
		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)

		--clear
		gl.glDisable(glc.GL_BLEND)
		ClearFBO(mixfbo,args.clearcolor)

		if not args.cliplist then
			args.cliplist = args.animclips:get_clips(timebegin)
		end
		

		for i,theseg in ipairs(args.cliplist) do

			local theclip, alpha, cliptime, alphaM = get_args(theseg, timebegin)
			glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbo.fb[0]);
			gl.glDisable(glc.GL_BLEND)

			if post then
				print("layer_mixer",i,theclip)
			end
			
			theclip[1]:draw(cliptime, w, h,theclip)

			---[[ mix
			glext.glUseProgram(programmix.program);
			glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, mixfbo.fb[0]);
			glext.glActiveTexture(glc.GL_TEXTURE0);

			gl.glBindTexture(textype, fbo.color_tex[0])


			gl.glEnable(glc.GL_BLEND)
			glext.glBlendEquation(glc.GL_FUNC_ADD)
			gl.glBlendFunc (glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA);
			
			
			programmix.unif.tex0:set{0}

			if GL.SRGB then --linear converted
				programmix.unif.alpha:set{alphaM*alpha*fade}
			else
				programmix.unif.alpha:set{alphaM*alpha*fade}
				--programmix.unif.alpha:set{ut.RGB2sRGB(alpha*fade)}
			end

			gl.glClear(glc.GL_DEPTH_BUFFER_BIT)
			
			if theseg.planer then
				theseg.planer:set(cliptime)
				local x,y,z = unpack(theseg.planer.pos)
				local he = theseg.planer.h
				gl.glTranslatef(x[0],y[0],0)
				ut.DoQuadC(he*w/h,he,z[0])
			else
				ut.project(w,h)
				ut.DoQuad(w,h)
			end
			--]]
		end
		args.cliplist = nil
		gl.glDisable(glc.GL_BLEND)
		program2:use()
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
		glext.glActiveTexture(glc.GL_TEXTURE0);

		gl.glBindTexture(textype, mixfbo.color_tex[0])
	
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		ut.Clear()
			
		ut.project(w,h)
		
		ut.DoQuad(w,h)
		gl.glDisable(glc.GL_FRAMEBUFFER_SRGB)
		
		--[[
		if srgb then
			gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
			ut.DoQuad(w,h)
			gl.glDisable(glc.GL_FRAMEBUFFER_SRGB)
		else
			ut.DoQuad(w,h)
		end
		--]]
		
		--gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
		--ut.DoQuad(w,h)
		--gl.glDisable(glc.GL_FRAMEBUFFER_SRGB)
		--[[ alternative bitblit
		--------ms tosingle fbo
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER,  old_framebuffer[0]);   -- Make sure no FBO is set as the draw framebuffer
		mixindex = (mixindex + 1)%2
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER,  mixfbos[mixindex].fb[0]); -- Make sure your multisampled FBO is the read framebuffer
		if old_framebuffer[0] == 0 then
			gl.glDrawBuffer(glc.GL_BACK);                       -- Set the back buffer as the draw buffer
		end
		glext.glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, glc.GL_COLOR_BUFFER_BIT, glc.GL_LINEAR);
		--]]
	end
	GL:add_plugin(LM,"layers_mixer_blend2")
	return LM
end
---------------------------------
local layers_seq = {is_layers_seq = true}
-- object must have setval for updtating values
-- segments = {{pos, dur ,ini,end,func},{ini,end,dur,func},...}
function layers_seq:new(segments)
	local o =  {} 
	o.segments = segments or {}
	setmetatable(o, self)
	self.__index = self
	return o
end
--sort by pos
function layers_seq:init()
	
	for i,segment in ipairs(self.segments) do
		local fade1 = segment.fade1 or 0
		local fade2 = segment.fade2 or 0
		local dur = segment[2]
		segment.pos_or = segment[1]
		segment.pos = segment[1] - fade1
		--segment.cliptime = animatable:new(nil,{{0,0,fade1},{0, dur, dur}, {dur - 1e-10, dur -1e-10,fade2}})
		--segment.lastpos = segment[1] + dur + fade2
		--segment.alpha = animatable:new(nil,{{0, 1, fade1*2},{1 ,1, dur - fade1 - fade2},{1, 0, fade2*2}})
		
		--segment.cliptime = segment.cliptime or animatable:new(nil,{{0,0,fade1},{0, dur, dur}, {dur - 1e-10, dur -1e-10,fade2}})
		segment.cliptime = segment.cliptime or animatable:new(nil,{{0,0,fade1},{0, dur, dur}, {dur , dur ,fade2}})
		segment.lastpos = segment[1] + dur 
		segment.alpha = animatable:new(nil,{{0, 1, fade1},{1 ,1, dur - fade2},{1, 0, fade2}})
	end
	table.sort(self.segments, function(a, b) return a[1] < b[1] end)
	self.inited = true
end

local MA = require"anima.matrixffi"
function layers_seq:get_clips(time)

	if not self.inited then self:init() end
	-- find segments
	local _segms =  {}
	for i,segment in ipairs(self.segments) do
		if (time >= segment.pos) then
			if (time < segment.lastpos) then table.insert(_segms, segment) end
		else
			break
		end
	end
	for i,seg in ipairs(_segms) do
		if seg.planer then 
			seg.zcalc = (seg.planer.camera:MV() * MA.vec4(0,0,seg.planer.pos[3][0],1)).z
		else
			seg.zcalc = seg.zpos or seg.zorder
		end
	end
	--table.sort(_segms, function(a,b) return ((a.zorder or 0) < (b.zorder or 0)) end)
	table.sort(_segms, function(a,b) return (a.zcalc < b.zcalc) end)
	return _segms
end
function layers_seq:add_segment(s)
	table.insert(self.segments, s)
	self:init()
end
function layers_seq:folder_seq(carpetas,imagefiles,offset)
	local function set_actions_dur(act,dur)
		for k,v in pairs(act) do
			if type(v)=="table" and v.is_animatable then
				local segs = v.segments
				for j, seg in ipairs(segs) do
					seg[3] = seg[3] or dur/#segs
				end
			end
		end
	end
	local seqc = {}
	local pos = offset or 0
	local fade1 = 0
	for i_car,car in ipairs(carpetas) do
	
		local frdur = car[2]
		local dur = car[5] 
		
		--if car.ga then car.ga = car.ga * 2 end -- for changed bias function
		local fade2 = car.fade or 0 --frdur*(car.ga or 0.1)
		--local imags = TA(imagefiles["\\"..car[1]])(car[3],car[4] or #imagefiles["\\"..car[1]])
		local imags = {}
		local imagsrc = imagefiles[path.sep..car[1]]
		if not imagsrc then error("cant find folder:"..car[1]) end
		local inifr,endfr = (car[3] or 1),(car[4] or #imagsrc)
		dur =  dur or ((endfr - inifr + 1)*frdur)
		for i =  inifr,endfr do
			table.insert(imags,imagsrc[i])
		end
	
		local frclip = {Framer, images = imags,frdur = frdur,dur = dur, ga = car.ga ,rloop=car.rloop,verbose=car.verbose}
		if car.actions then
			for i_a, action in ipairs(car.actions) do
				local frclipin = frclip
				set_actions_dur(action,dur)
				frclip = action
				assert(frclipin)
				frclip.clip = frclipin
			end
		end
		--frclip = {liquid, timefac=0.082,clip = frclip}
		seqc[#seqc +1] = {pos,dur ,alphaM = car.alphaM,cliptime=car.cliptime, fade1 =  fade1, fade2 = fade2,frclip}
		fade1 = fade2
		--seqc[#seqc +1] = {pos,dur , fade1 =  fade, fade2 = fade, frclip}
		pos = pos + dur
		seqc[#seqc ].clave = car[1] 
	
	end
	return seqc
end
local function newPlanner(GL,planez,show,cameraplaner)
	planez = planez or 0
	local planner = {pos={pointer(0),pointer(0),pointer(planez)}}
	local cameraplaner = cameraplaner or newCamera(GL,show)
	local cam_to_plane = cameraplaner.NMC.dist - planez + cameraplaner.NMC.zcamL
	planner.camera = cameraplaner
	planner.h = planner.camera:GetHeightForZ(cam_to_plane )
	function planner:set(time)
		if self.autom then
			for i,v in ipairs(self.autom) do
				v:dofunc(time)
			end
		end
		self.camera:Set(time)
	end
	return planner
end
M.newPlanner = newPlanner
M.layers_seq = layers_seq
return M


