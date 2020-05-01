----camera.lua will be legacy
----camera2.lua will have many changes and dont manages opengl2

local mat = require"anima.matrixffi"
local vec2 = mat.vec2
local vec3 = mat.vec3
local vec4 = mat.vec4
local R = require"anima.rotations"

--http://inside.mines.edu/fs_home/gmurray/ArbitraryAxisRotation/
--rotates point(x,y,z) om radians around (u,v,w)
local function Twist(x,y,z,u,v,w,om)
	local norm = math.sqrt(u*u+v*v+w*w)
	u = u/norm
	v = v/norm
	w = w/norm
	local sinom,cosom = math.sin(om),math.cos(om)
	local ux = (u*x + v*y + w*z)*(1-cosom)
	local X = u*ux+x*cosom+(-w*y+v*z)*sinom
	local Y = v*ux+y*cosom+(w*x-u*z)*sinom
	local Z = w*ux+z*cosom+(-v*x+u*y)*sinom
	return X, Y, Z
end

local function imgui_lookat_cameraDialog(name,zforh,GL, invisible,cam)
		local NMC =GL:Dialog(name .."_cam",
		{
		{"printMV",0,guitypes.button,function() print(cam:MV());print(cam:MP()) end},
		{"twist",0,guitypes.dial},
		{"set_dir",0,guitypes.button,function() 
			GL.mouse_pick = {action=function(X,Y)
							cam:set_dir2(X,Y)
							GL.mouse_pick = nil
						end}
		end},
		{"use_dir",true,guitypes.toggle},
		{"center",{0,0,-1},guitypes.drag,{min=-5,max=5}},
		{"position",{0,0,0},guitypes.drag,{minv=-5,maxv=5}},
		{"focal",35,guitypes.val,{min=0,max=180}},
		{"focal_fac",1,guitypes.val,{min=0.01,max=5,sameline=true}},
		{"nearZ",0.1,guitypes.val,{min=0.01,max=1}},
		{"farZ",1000,guitypes.val,{min=1,max=1000,sameline=true}},
		{"ortho",0,guitypes.toggle}}
		,nil,invisible)
		return NMC
end


local function imgui_cameraDialog(name,zforh,GL, invisible,cam)
		local NMC =GL:Dialog(name .."_cam",
		{
		{"printMV",0,guitypes.button,function() print(cam:MV());print();print(cam:MP()) end},
		{"azimuth",0,guitypes.dial},
		{"elevation",0,guitypes.dial},
		{"twist",0,guitypes.dial},
		{"set_dir",0,guitypes.button,function() 
			GL.mouse_pick = {action=function(X,Y)
							cam:set_dir2(X,Y)
							GL.mouse_pick = nil
						end}
		end},
		{"dist",zforh,guitypes.drag,{precission=0.1}},
		{"pos",{0,0,0},guitypes.drag,{precission=0.1}},
		-- {"xcamL",0,guitypes.drag,{min=-5,max=5,precission=0.1}},
		-- {"ycamL",0,guitypes.drag,{min=-5,max=5,precission=0.1}},
		-- {"zcamL",0,guitypes.dial,{min=-5*zforh,max=5*zforh}},
		{"focal",35,guitypes.drag,{min=0,max=180,precission=0.1,separator=true}},
		{"focal_fac",1,guitypes.drag,{min=0.01,max=5,precission=0.1,sameline=true}},
		{"nearZ",0.1,guitypes.drag,{min=0.01,max=1,precission=0.1}},
		{"farZ",1000,guitypes.drag,{min=1,max=1000,precission=0.1,sameline=true}},
		{"ortho",0,guitypes.toggle}}
		,nil,invisible)
		return NMC
end
	
   
function Camera(GL,cam_type, name,initialDist)

	name = name or "cam"
	local cam = {}
	function cam:set_dir3Euler(dir)
		dir = dir.normalize
		print("dir",dir)
		local elev = math.asin(dir.y)
		self.NMC.vars.elevation[0] = elev
		local cosel = math.cos(elev)
		local azim = math.atan2(dir.x,-dir.z)
		self.NMC.vars.azimuth[0] = azim
	end
	function cam:set_dir3lookat(dir)
		dir = dir.normalize
		print("dir",dir)
		local center = self.NMC.center
		local pos = self.NMC.position
		if self.NMC.use_dir then
			center[0],center[1],center[2] = -dir.x,-dir.y, dir.z
		else
			center[0],center[1],center[2] = pos[0]+dir.x,pos[1]+dir.y, pos[2]+dir.z
		end
	end
	function cam:set_dir2(X,Y)
		X,Y = GL:ScreenToViewport(X,Y)
		local ndc = mat.vec2(X,Y)*2/mat.vec2(GL.W,GL.H) - mat.vec2(1,1)
		local near = cam.NMC.nearZ
		local dir = cam:MP().inv * (mat.vec4(ndc.x,ndc.y,-1,1)*near)
		dir = dir/dir.w
		dir = vec3(dir.x,dir.y,dir.z).normalize
		self:set_dir3(dir)
	end
	------------------coordinate transforms
	function cam:Viewport2Eye(v2,MPinv)
		MPinv = MPinv or self:MP().inv
		local v2 = v2*2/vec2(GL.W,GL.H) - vec2(1,1)
		local eyepoint = MPinv * vec4(v2.x,v2.y,-1,1)
		eyepoint = eyepoint/eyepoint.w
		eyepoint = (-1*(eyepoint/eyepoint.z)).xyz
		return eyepoint
	end
	----------------------------------
	function cam:CalcCameraLookat()
		local NMC = self.NMC
		local pos = NMC.position
		local center = NMC.center
		local dir
		if NMC.use_dir then
			dir = vec3(center[0],center[1],center[2])
		else
			dir = vec3(center[0]-pos[0],center[1]-pos[1],center[2]-pos[2])
		end
		local side = -dir:cross(vec3(0,1,0))
		local upv = dir:cross(side)
		local upX,upY,upZ = Twist(upv.x,upv.y,upv.z,dir.x,dir.y,dir.z,NMC.twist)
		if NMC.use_dir then
			return mat.lookAt(vec3(pos[0],pos[1],pos[2]), 
							vec3(pos[0] + center[0],pos[1] + center[1],pos[2] + center[2]), 
							vec3(upX,upY,upZ))
		end
		return mat.lookAt(vec3(pos[0],pos[1],pos[2]), 
							vec3(center[0],center[1],center[2]), 
							vec3(upX,upY,upZ))
	end
	function cam:CalcCameraEuler(dist, azim,elev,twist)
		local NMC = self.NMC
		dist = dist or NMC.dist
		dist = dist * NMC.focal_fac
		azim = azim or NMC.azimuth
		elev = elev or NMC.elevation
		twist = twist or NMC.twist
		
		local Rot = R.ZXYE( -twist, elev,-azim)
		
		local xL,yL,zL = NMC.pos[0],NMC.pos[1],NMC.pos[2]
		if self.shooter=="fps" then
			return  Rot.mat4*mat.translate(-xL,-yL,-zL)
		else
			return  mat.translate(-xL, -yL, -zL-dist)*Rot.mat4 
		end
	end
	function cam:MV()
		return self:CalcCamera()
	end
	function cam:setMV(MV)
		if self.type == "lookat" then
			local eye,center,up = mat.matToLookAt(MV)
			--only for lookat camera now, twist not done
			self.NM.vars.position:set(eye)
			self.NM.vars.center:set(center)
		else --tps,fps
			local tw,el,az = R.ZXYE2angles(MV.mat3)
			tw = -tw; az = -az
			self.NM.vars.azimuth[0] = az
			self.NM.vars.elevation[0] = el
			self.NM.vars.twist[0] = tw
			
			if self.type == "fps" then
				local Ri = MV.mat3.t.mat4 --inverse of rotation part
				local tt = Ri*MV
				local tran = vec3(tt.m41,tt.m42,tt.m43)
				-- self.NM.vars.xcamL[0] = -tran.x
				-- self.NM.vars.ycamL[0] = -tran.y
				-- self.NM.vars.zcamL[0] = -tran.z
				self.NM.vars.pos:set{-tran.x,-tran.y,-tran.z}
			else --tps
				local Ri = MV.mat3.t.mat4 --inverse of rotation part
				local tt = MV*Ri
				local tran = vec3(tt.m41,tt.m42,tt.m43)
				-- self.NM.vars.xcamL[0] = -tran.x
				-- self.NM.vars.ycamL[0] = -tran.y
				-- self.NM.vars.zcamL[0] = -tran.z - self.NM.dist
				self.NM.vars.pos:set{-tran.x,-tran.y,-tran.z - self.NM.dist}
			end
		end
	end
	function cam:setRot(MV)
		if self.type == "lookat" then
			error"setRot not done for lookat"
		else --tps,fps
			local tw,el,az = R.ZXYE2angles(MV.mat3)
			tw = -tw; az = -az
			self.NM.vars.azimuth[0] = az
			self.NM.vars.elevation[0] = el
			self.NM.vars.twist[0] = tw
			
		end
	end
	function cam:MP()
		local NMC = self.NMC
		local w,h = self.drawsize.w or GL.W, self.drawsize.h or GL.H
		local aspect = self.drawsize.aspect or GL.aspect
		
		if NMC.ortho then
			return mat.ortho(-0.5*aspect, 0.5*aspect,-0.5, 0.5, -10, 100000);
		else
			local focal
			if NMC.focal_fac == 1 then
				focal = NMC.focal
			else
				focal = 360*math.atan(math.tan(NMC.focal*math.pi/360)/NMC.focal_fac)/math.pi
			end
			self.focal = focal
			return mat.perspective(focal,w/h,NMC.nearZ,NMC.farZ)
		end
	end
	function cam:frame()
		local MV = cam:MV()
		local frame = {}
		frame.X = vec3(MV.m11,MV.m21,MV.m31)
		frame.Y = vec3(MV.m12,MV.m22,MV.m32)
		frame.Z = vec3(MV.m13,MV.m23,MV.m33)
		--eye in LookAt
		frame.center = MV.mat3.inv * (-vec3(MV.m41, MV.m42, MV.m43))
		return frame
	end
	function cam:MVP()
		return self:MP()*self:MV()
	end
	
	function cam:GetZforHeight(height)
		return height*0.5/math.tan(0.5*math.pi*self.NMC.focal/180)
	end
	function cam:GetHeightForZ(Z)
		return 2*Z*math.tan(0.5*math.pi*self.NMC.focal/180)
	end
	

	function cam:setsize(w,h)
		--self.drawsize = self.drawsize or {}
		self.drawsize.w ,self.drawsize.h = w,h
		self.drawsize.aspect = w/h
	end
	
	--cam:setsize(GL.W,GL.H)
	cam.drawsize = {}
	cam.type = cam_type
	local zforh = initialDist or 0.5/math.tan(0.5*math.pi*35/180)
	if cam_type=="tps" or cam_type=="fps" or (type(cam_type)=="boolean" and cam_type==true) then
		cam.CalcCamera = cam.CalcCameraEuler
		cam.set_dir3 = cam.set_dir3Euler
		cam.shooter = cam_type
		cam.NMC = imgui_cameraDialog(name,zforh,GL,false,cam)
		
	elseif cam_type == "lookat" then
		cam.CalcCamera = cam.CalcCameraLookat
		cam.set_dir3 = cam.set_dir3lookat
		cam.NMC = imgui_lookat_cameraDialog(name,zforh,GL,false,cam)
	elseif cam_type == "ident" then
		cam.CalcCamera = cam.CalcCameraLookat
		cam.set_dir3 = function() end
		cam.NMC = nil --imgui_lookat_cameraDialog(name,zforh,GL,true,cam)
		cam.MV = function() return mat.identity end
		cam.MP = function() return mat.identity end
	elseif not cam_type then
		cam.CalcCamera = cam.CalcCameraEuler
		cam.NMC = imgui_cameraDialog(name,zforh,GL,true,cam)
	end
	cam.NM = cam.NMC
	-----------
	--cam.KF = gui.KeyFramer(cam.NMC)

	return cam
end