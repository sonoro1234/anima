local mat = require"anima.matrixffi"
local vec3 = mat.vec3

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
		{"focal_fac",1,guitypes.val,{min=0.01,max=5}},
		{"nearZ",0.1,guitypes.val,{min=0.01,max=1}},
		{"farZ",1000,guitypes.val,{min=1,max=1000}},
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
		{"distfac",1,guitypes.drag,{min=0.01,max=1000,precission=0.1}},
		{"dist",zforh,guitypes.drag,{min=0,max=zforh*5,precission=0.1}},
		{"xcamL",0,guitypes.drag,{min=-5,max=5,precission=0.1}},
		{"ycamL",0,guitypes.drag,{min=-5,max=5,precission=0.1}},
		--{"zcamL",0,guitypes.drag,{min=-5*zforh,max=5*zforh}},
		{"zcamL",0,guitypes.dial,{min=-5*zforh,max=5*zforh}},
		{"focal",35,guitypes.drag,{min=0,max=180,precission=0.1}},
		{"focal_fac",1,guitypes.drag,{min=0.01,max=5,precission=0.1}},
		{"nearZ",0.1,guitypes.drag,{min=0.01,max=1,precission=0.1}},
		{"farZ",1000,guitypes.drag,{min=1,max=1000,precission=0.1}},
		{"ortho",0,guitypes.toggle}}
		,nil,invisible)
		return NMC
end
	
local MA = require"anima.matrixffi"
local mat = MA	   
function newCamera(GL,cam_type, name,initialDist)

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
		local mat = MA
		X,Y = GL:ScreenToViewport(X,Y)
		local ndc = mat.vec2(X,Y)*2/mat.vec2(GL.W,GL.H) - mat.vec2(1,1)
		local near = cam.NMC.nearZ
		local dir = cam:MP().inv * (mat.vec4(ndc.x,ndc.y,-1,1)*near)
		dir = dir/dir.w
		dir = vec3(dir.x,dir.y,dir.z).normalize
		self:set_dir3(dir)
	end
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
			return pos[0],pos[1],pos[2], pos[0] + center[0],pos[1] + center[1],pos[2] + center[2],upX,upY,upZ
		end
		return pos[0],pos[1],pos[2],center[0],center[1],center[2],upX,upY,upZ
	end
	function cam:CalcCameraEuler(dist, azim,elev,twist)
		local NMC = self.NMC
		dist = dist or (NMC.dist*(NMC.distfac or 1))
		dist = dist * NMC.focal_fac
		azim = azim or NMC.azimuth
		elev = elev or NMC.elevation
		twist = twist or NMC.twist
		

		local cosel = math.cos(elev)
		local x = cosel*math.sin(azim)*dist
		local y = math.sin(elev)*dist
		local z = cosel*math.cos(azim)*dist
		
		--cross prod (z,0,-x)
		local upX,upY,upZ
		upX = -x*y
		upY = z*z + x*x
		upZ = -z*y
		if cosel < 0 then upX,upY,upZ = -upX,-upY,-upZ end
		upX, upY, upZ = Twist(upX, upY, upZ, x, y, z, twist)
		local xL,yL,zL = NMC.xcamL,NMC.ycamL,NMC.zcamL
		if self.shooter=="fps" then
			return  xL, yL, zL, xL - x, yL - y, zL - z, upX,upY,upZ
		else
			return xL + x, yL + y, zL + z, xL, yL, zL, upX, upY, upZ
		end
	end
	function cam:MV()
		local pars = {self:CalcCamera()}
		local vec3 = MA.vec3
		return MA.lookAt(vec3(pars[1],pars[2],pars[3]),vec3(pars[4],pars[5],pars[6]),vec3(pars[7],pars[8],pars[9]))
	end
	function cam:setMV(MV)
		local eye,center,up = mat.matToLookAt(MV)
		--only for lookat camera now, twist not done
		self.NM.vars.position:set(eye)
		self.NM.vars.center:set(center)
	end
	function cam:MP()
		local NMC = self.NMC
		local w,h = self.drawsize.w or GL.W, self.drawsize.h or GL.H
		local aspect = self.drawsize.aspect or GL.aspect
		
		if NMC.ortho then
			return MA.ortho(-0.5*aspect, 0.5*aspect,-0.5, 0.5, -10, 100000);
		else
			local focal
			if NMC.focal_fac == 1 then
				focal = NMC.focal
			else
				focal = 360*math.atan(math.tan(NMC.focal*math.pi/360)/NMC.focal_fac)/math.pi
			end
			self.focal = focal
			return MA.perspective(focal,w/h,NMC.nearZ,NMC.farZ)
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
	function cam:LookAt()
		local NMC = self.NMC
		gl.glMatrixMode(glc.GL_MODELVIEW);
		gl.glLoadIdentity();
		glu.gluLookAt(self:CalcCamera())--NMC.dist*(NMC.distfac or 1),NMC.azimuth,NMC.elevation,NMC.twist))
	end
	function cam:GetZforHeight(height)
		return height*0.5/math.tan(0.5*math.pi*self.NMC.focal/180)
	end
	function cam:GetHeightForZ(Z)
		return 2*Z*math.tan(0.5*math.pi*self.NMC.focal/180)
	end
	function cam:SetProjection()
	
		local NMC = self.NMC
		local w,h = self.drawsize.w or GL.W, self.drawsize.h or GL.H
		local aspect = self.drawsize.aspect or GL.aspect	
		
		gl.glMatrixMode(glc.GL_PROJECTION)
		gl.glLoadIdentity() 
		
		if NMC.ortho then
			gl.glOrtho(-0.5*aspect, 0.5*aspect,-0.5, 0.5, -10, 100000);
		else
			--gl.Frustum(0,width,0,height,10,1000)
			--gl.Frustum(-0.5*w,0.5*w,-0.5*h,0.5*h,NMC.nearZ,NMC.farZ)
			local focal
			if NMC.focal_fac == 1 then
				focal = NMC.focal
			else
				focal = 360*math.atan(math.tan(NMC.focal*math.pi/360)/NMC.focal_fac)/math.pi
				--print(focal,NMC.focal_fac)
			end
			self.focal = focal
			glu.gluPerspective(focal,aspect,NMC.nearZ,NMC.farZ)
		end
		gl.glMatrixMode(glc.GL_MODELVIEW)
		if self.PostProjection then self.PostProjection(w, h) end

	end
	function cam:Set(time,args)
		if time and self.KF then
			self.KF:animate(time)
			self.KF.clippos = args and args.clippos or 0
		end
		self:SetProjection()
		self:LookAt()
		gl.glViewport(0, 0, self.drawsize.w or GL.W, self.drawsize.h or GL.H)
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