require"anima"
local vec3 = mat.vec3
local program,programE
local function PlanePicker(GL,camera,updatefunc)
	
	local updatefunc = updatefunc or function() end
	local mat = require"anima.matrixffi"
	
	local PR = {camera=camera}

	local vert_sh = [[
	in vec3 position;
	uniform mat4 MVP;
	void main()
	{
		gl_Position = MVP * vec4(position,1);
	
	}
	]]
	local vertEYE_sh = [[
	in vec3 position;
	uniform mat4 P;
	void main()
	{
		gl_Position = P * vec4(position,1);
	
	}
	]]
	local frag_sh = [[
	uniform vec3 color = vec3(1);
	void main()
	{
		gl_FragColor = vec4(color,1);
	}
	]]
	
	
	
	local NM = GL:Dialog("pick points",
	{
	{"focal_track",false,gui.types.toggle,nil},
	{"get_camera",0,guitypes.button,function() PR:Rectify() end,{sameline=true}},
	{"zval",1,guitypes.val,{min=1e-5,max=30},function(val,this) 
		if PR:numpoints()==4 then PR:set_pointsR();PR:make_shape();PR:set_points_vao()  end end},
	{"set_dir3",0,guitypes.button,function() camera:set_dir3(PR.frame.X) end},
	{"drawpoints",true,guitypes.toggle},
	{"drawlines",true,guitypes.toggle,nil,{sameline=true}},
	{"rotate points",0,guitypes.button,function() PR:RotatePoints();PR:Rectify() end},
	{"reverse points",0,guitypes.button,function() PR:ReversePoints();PR:Rectify() end,{sameline=true}},
	{"edit",false,guitypes.toggle,function(val,this)
		
		local mousepick 
		mousepick = {action=function(X,Y)
							X,Y = GL:ScreenToViewport(X,Y)
							--print(X,Y)
							local touched = -1
							for i,v in ipairs(PR.sccoors) do
								local vec = mat.vec2(v[1] - X, v[2] - Y)
								if (vec:norm()) < 3 then touched = i; break end
							end
							--print(touched)
							if touched > 0 then
								GL.mouse_pos_cb = function(x,y)
									x,y = GL:ScreenToViewport(x,y)
									PR.sccoors[touched] = {x,y}
									PR:Rectify()
								end
							else
								GL.mouse_pos_cb = nil
							end
	
						end,
						action_rel = function(X,Y)
							GL.mouse_pos_cb = nil
						end}
		if val then
			GL.mouse_pick = mousepick
		else
			GL.mouse_pick = nil
		end
	
	end},
	{"set points",0,guitypes.button,function(this)
		this.vars.edit[0] = false
		PR:newplane()
		local mousepick 
		mousepick = {action=function(X,Y)
							local Xv,Yv = GL:ScreenToViewport(X,Y)
							--print(Xv,Yv)
							PR:process1(Xv,Yv)
							PR:set_eyepoints_vao()
							if PR:numpoints() >=4 then
								PR:Rectify()
								GL.mouse_pick = nil
							end
						end}
		GL.mouse_pick = mousepick
	end,{sameline=true}}
	})

	PR.NM = NM
	local TA = require"anima.TA"
	PR.sccoors = {}
	local eyepoints = {}
	local eyepointsR = {}
	PR.eyepointsR = eyepointsR
	PR.eyepoints = eyepoints
	local camMVinv , camMPinv,camMP, camNear
	
	camMVinv = camera:MV().inv
	camMPinv = camera:MP().inv
	camMP = camera:MP()
	camNear = camera.NMC.nearZ
		
	local vaopoints,vaopointsE,vao_lines


	local function eye2world(p)
		local pR = camMVinv * mat.vec4(p.x,p.y,p.z,1)
		return vec3(pR.x,pR.y,pR.z)/pR.w
	end
	local  vec2vao = mat.vec2vao
		

	function PR:init()
		if not program then
			program = GLSL:new():compile(vert_sh,frag_sh)
		end
		if not programE then
			programE = GLSL:new():compile(vertEYE_sh,frag_sh)
		end
		
		vaopointsE = VAO({position=TA():Fill(0,12)},programE)
		vaopoints = VAO({position=TA():Fill(0,12)},program)
		vao_lines = VAO({position=TA():Fill(0,12)},program)
	end
	function PR:newplane()
		self.sccoors = {}
		eyepoints = {}
		self.eyepoints = eyepoints
	end
	
	function PR:process1(X,Y)
		local ndc = mat.vec2(X,Y)*2/mat.vec2(GL.W,GL.H) - mat.vec2(1,1)
		local near = 1 --camera.NMC.nearZ
		local eyepoint = camera:MP().inv * (mat.vec4(ndc.x,ndc.y,-1,1)*near)
		eyepoint = eyepoint/eyepoint.w

		table.insert(self.sccoors,{X,Y})
		table.insert(eyepoints,eyepoint:xyz())
		return X,Y
	end

	function PR:numpoints()
		return #eyepoints
	end
	function PR:draw_points()
		program:use()
		program.unif.MVP:set(camera:MVP().gl)
		program.unif.color:set{1,0,0}
		vaopoints:draw(glc.GL_LINE_LOOP,4)
		gl.glPointSize(6)
		program.unif.color:set{0,1,0}
		vaopoints:draw(glc.GL_POINTS,4)
		program.unif.color:set{1,1,0}
		vaopoints:draw(glc.GL_POINTS,1)
		gl.glPointSize(1)
	end
	function PR:draw_pointsE()
		programE:use()
		programE.unif.color:set{1,0,0}
		programE.unif.P:set(camera:MP().gl)
		vaopointsE:draw(glc.GL_LINE_LOOP,4)
		gl.glPointSize(6)
		programE.unif.color:set{0,1,0}
		vaopointsE:draw(glc.GL_POINTS,4)
		programE.unif.color:set{1,1,0}
		vaopointsE:draw(glc.GL_POINTS,1)
		gl.glPointSize(1)
	end
	function PR:draw_lines()
		program:use()
		program.unif.MVP:set(camera:MVP().gl)
		program.unif.color:set{0,1,1}
		vao_lines:draw(glc.GL_LINES,4,6)
		program.unif.color:set{0,0,1}
		vao_lines:draw(glc.GL_LINES,2,4)
		program.unif.color:set{0,1,0}
		vao_lines:draw(glc.GL_LINES,2,2)
		program.unif.color:set{1,0,0}
		vao_lines:draw(glc.GL_LINES,2,0)
	end
	function PR:save()
		local pars = {sccoors=self.sccoors,VP={GL.W,GL.H}}
		pars.dial = NM:GetValues()
		return pars
	end
	function PR:load(params)

		self:newplane()
		local VP = params.VP or {GL.W,GL.H}
		for i,v in ipairs(params.sccoors) do
			v[1] = v[1]*GL.W/VP[1]
			v[2] = v[2]*GL.H/VP[2]
			self:process1(unpack(v))
		end
		NM:SetValues(params.dial or {})
		NM.vars.edit[0] = false
		--old format saved
		if params.zval then NM.vars.zval[0] = params.zval end
		
		self:Rectify()
	end
	
	function PR:set_eyepoints_vao()
		local lp = vec2vao(eyepoints)
		vaopointsE:set_buffer("position",lp,(#eyepoints)*3)
	end
	function PR:set_points_vao()
	
		self:set_eyepoints_vao()
		
		local wp = {}
		for i,p in ipairs(eyepointsR) do
			wp[i] = eye2world(p)
		end
		self.wp = wp
		lp = vec2vao(wp)
		vaopoints:set_buffer("position",lp,(#wp)*3)
		
		---lines
		local eye = eyepointsR[1]
		local eyenorm = self.height --(eyepointsR[4]-eyepointsR[1]).norm --eye.norm
		local eyeW = eye2world(eye)

		local p1 = eye2world(eye - self.vpointX:normalize()*eyenorm*0.5)
		local p2 = eye2world(eye - self.vpointY:normalize()*eyenorm*0.5)
		local p3 = eye2world(eye + self.vpointY:normalize()*eyenorm*0.5)
		
		local fx = eye2world(eye + self.frame.X * eyenorm)
		local fy = eye2world(eye + self.frame.Y * eyenorm)
		local fz = eye2world(eye + self.frame.Z * eyenorm)
	
		local lp = vec2vao{eyeW,fx,eyeW,fy,eyeW,fz,eyeW,p1,p2,p3}
		vao_lines:set_buffer("position",lp,10*3)
	end

	function PR:RotatePoints()
		local sccoors = self.sccoors
		local temp = sccoors[1]
		for i=1,#sccoors-1 do
			sccoors[i] = sccoors[i+1]
		end
		sccoors[4] = temp
	end
	
	function PR:ReversePoints()
		local sccoors = self.sccoors
		sccoors[2],sccoors[4] = sccoors[4],sccoors[2]
	end
	
	local lastfocal = camera.focal
	function PR:draw()
		if NM.collapsed then return end
		
		--if focal changes and NM.focal_track==true redo Rectify
		--good for getting focal of a photo: when with points representing a rectangle
		--frame line Y (green) align with that rectangle
		if lastfocal ~= camera.focal and NM.focal_track then
			self:Rectify()
			lastfocal = camera.focal
		end
		
		gl.glViewport(0, 0,GL.W,GL.H)
		if #eyepoints == 4 then
			gl.glDisable(glc.GL_DEPTH_TEST)
			if NM.drawpoints then
				self:draw_pointsE()
				self:draw_points()
			end
			if NM.drawlines then
				self:draw_lines()
			end
			gl.glEnable(glc.GL_DEPTH_TEST)
		elseif #eyepoints > 0 then --we are setting the points
			self:draw_pointsE()
		end
	end
	function PR:set_pointsR()
		local vlineN = self.vline:normalize() --/self.vline.z --:normalize() 
		local centroid = vec3(0,0,0)
		--get plane on point1 at distance zval
		local D = vlineN * eyepoints[1]:normalize()*NM.zval 
		-- move all points to be in same plane -> eyepointsR[i]*vlineN == D
		-- but make the plane distance to origin == zval instead of D
		for i,pO in ipairs(eyepoints) do
			local ray = pO:normalize()
			eyepointsR[i] = ray * (D/(vlineN*ray))
			centroid = centroid + eyepointsR[i]
		end
		
		self.centroid = centroid*0.25
		self.frame.center = self.centroid
		self.width = (eyepointsR[2]-eyepointsR[1]):norm()
		self.height = (eyepointsR[2]-eyepointsR[3]):norm()
		
	end
	
	function PR:set_camera(camera)
		--camera:set_dir3(self.frame.X)
	end
	function PR:Rectify()

		if PR:numpoints()~=4 then return end
		local scoorsO = self.sccoors 
		self:newplane()
		for i,v in ipairs(scoorsO) do
			self:process1(unpack(v))
		end

		--get vanishing points
		local l1 = eyepoints[1]:cross(eyepoints[2])
		local l2 = eyepoints[4]:cross(eyepoints[3])
		local vpointX = l1:cross(l2)
		self.vpointX = vpointX


		l1 = eyepoints[1]:cross(eyepoints[4])
		l2 = eyepoints[2]:cross(eyepoints[3])
		local vpointY = l1:cross(l2)
		self.vpointY = vpointY
	

		-- vanishing line
		self.vline = vpointX:cross(vpointY)
		
		self.frame = {}
		self.frame.X = vpointX:normalize()
		self.frame.Z = self.vline:normalize()
		self.frame.Y = self.frame.Z:cross(self.frame.X)
		
		self:set_pointsR()

		self:set_camera(camera)
		
		self.camMV = camera:MV()
		camMVinv = camera:MV().inv
		self.camMVinv = camMVinv
		camMPinv = camera:MP().inv
		camMP = camera:MP()
		camNear = camera.NMC.nearZ
		
		
		self:set_points_vao()
		
		self:make_shape()

	end
	
	function PR:make_shape()
		updatefunc(self)
	end
	
	GL:add_plugin(PR,"plane_picker")
	return PR
end

--[=[
local GL = GLcanvas{H=800,aspect=2/2}
local camara = newCamera(GL,"tps")--"lookat")
local edit = PlanePicker(GL,camara)
-- local plugin = require"anima.plugins.plugin"
-- edit.ps = plugin.serializer(edit)
-- GL.use_presets = true
function GL.draw(t,w,h)
	ut.Clear()
	edit:draw(t,w,h)
end
GL:start()
--]=]

return PlanePicker
