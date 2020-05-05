require"anima"
local vec3 = mat.vec3
local vec2 = mat.vec2
local vec4 = mat.vec4
local CG = require"anima.CG3"

local function Spline3D(GL, camera,updatefunc)
	------------Spline modifications for 3D
	local HeightEditor = require"anima.modeling.HeightEditor"
	local SP3D = require"anima.modeling.Spline"(GL,updatefunc)
	
	local doheightupdate = true
	local function updateheights()
		if doheightupdate then updatefunc() end
		--print"updateheights done"
	end
	
	function SP3D:create_height_editor(spnum)
		local updateheightfunc = function(hedit)
			local Mtrinv = self.HeightEditors[spnum].Mtrinv
			self.HeightEditors[spnum].mesh:M4(Mtrinv)
			updateheights()
		end
		self.HeightEditors[spnum] = HeightEditor(GL,updateheightfunc  )
		return self.HeightEditors[spnum]
	end
	
	SP3D.HeightEditors = {}
	local oldfunc = SP3D.NM.func
	SP3D.NM.func = function(this)
		oldfunc(this)
		if SP3D.HeightEditors and SP3D.HeightEditors[this.curr_spline] then
			ig.Separator()
			SP3D.HeightEditors[this.curr_spline].NM:draw()
		end
	end
	
	SP3D.ps_eye = {}
	SP3D.frames = {}
	SP3D.indexes = {}
	
	local function Scr2Eye(MPinv,sc)
		local ndc = sc*2/vec2(GL.W,GL.H) - vec2(1,1)
		local eyepoint = MPinv * vec4(ndc.x,ndc.y,1,1)
		eyepoint = eyepoint/eyepoint.w
		eyepoint = - eyepoint/eyepoint.z
		return eyepoint.xyz
	end
	function Eye2Scr(MP,eyep)
		local ndc = MP*vec4(eyep,1)
		ndc = (ndc/ndc.w).xyz
		ndc = (ndc.xy + vec2(1,1))
		ndc = vec2(ndc.x*GL.W*0.5,ndc.y*GL.H*0.5)
		return ndc
	end
	
	function SP3D:newmesh(pts)
		local spnum = self:newspline(pts)
		self:create_height_editor(spnum)
		return spnum
	end
	
	local olddeletespline = SP3D.deletespline
	function SP3D:deletemesh(ii)
		table.remove(SP3D.indexes,ii)
		table.remove(SP3D.ps_eye,ii)
		table.remove(SP3D.frames,ii)
		olddeletespline(SP3D,ii)
	end
	function SP3D:deleteall()
		for i=#self.sccoors,1,-1 do
			self:deletemesh(i)
		end
	end
	function SP3D:set_frame(frame,ii)
		self.frames[ii] = frame or {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=vec3(0,0,-1)}
		self:calc_spline(ii)
		--updatefunc(self)
	end
	function SP3D:calc_spline(ii)
		--print("calc_spline1",ii,self.NM.curr_spline)
		--print(debug.traceback())
		ii = ii or self.NM.curr_spline
		--print("calc_spline",ii,self:numpoints(ii))
		if self:numpoints(ii)>2 then
			--project on plane
			local prsc = {}
			local R = self.frames[ii].Z
			local D = -self.frames[ii].center*R
			if D < 0 then D = -D; R = -R end
			local MP = camera:MP()
			local MPinv = MP.inv
			for i,v in ipairs(self.sccoors[ii]) do
				local r = Scr2Eye(MPinv,v) --vec3(v.x,v.y,1)
				local dotinv = -D/(R*r)
				prsc[i] = dotinv*r
			end
			--make planes coord sys
			local Mt = mat.translate(-prsc[1])
			local X = (prsc[2] - prsc[1]).normalize
			local Mr = mat.rotABCD(R,vec3(0,0,1),X,vec3(1,0,0))--.mat4
			Mr = Mr.mat4
			local Mtr = Mr*Mt
			for i,v in ipairs(prsc) do
				local vv = Mtr*vec4(v,1)
				prsc[i] = (vv/vv.w).xyz

			end

			local pspr = CG.Spline(prsc,self.alpha[ii][0],self.divs[ii][0],true)
			self.indexes[ii] = CG.EarClipSimple2(pspr)--,true)
			
			local Mtrinv = Mtr.inv

			self.ps_eye[ii] = {}
			self.ps[ii] = {}
			for i,v in ipairs(pspr) do
				local vv = Mtrinv*vec4(v,1)
				vv =  (vv/vv.w).xyz
				self.ps_eye[ii][i] = vv
				self.ps[ii][i] = Eye2Scr(MP,vv)
			end
			
			self.HeightEditors[ii].Mtrinv = Mtrinv
			self.HeightEditors[ii]:set_spline(pspr)
			self.HeightEditors[ii]:process()
		end
	end
	function SP3D:get_mesh(ii)
		return self.HeightEditors[ii].mesh, self.frames[ii]
	end
	function SP3D:resetmesh(ii,frame,pts)
		self.NM.vars.curr_spline[0]=ii
		self:clearshape()
		self.frames[ii] = frame
		for i,p in ipairs(pts) do
			self.sccoors[ii][i] = p
		end
		self:process_all()
	end
	
	local old_save = SP3D.save
	function SP3D:save()
		local pars = {}
		pars.SP = old_save(self)
		pars.HE = {}
		for i, he in ipairs(SP3D.HeightEditors) do
			pars.HE[i] = he:save()
		end
		return pars
	end
	
	local old_load = SP3D.load
	function SP3D:load(pars)
		doheightupdate = false
		local casp = self.calc_all_splines
		self.calc_all_splines = function() end --avoid calc_all_splines
		old_load(SP3D,pars.SP)
		self.calc_all_splines = casp
		
		for i=1,pars.SP.numsplines do
			local HE = self:create_height_editor(i) --skip update
			self:set_frame(nil,i)
			HE:load(pars.HE[i])
		end
		--self:calc_all_splines()
		doheightupdate = true
		-- for iplane,spl in ipairs(self.splines) do
			-- for i,spnum in ipairs(spl) do
				-- local he = create_height_editor(iplane,spnum)
				-- he:load(par.HE[spnum])
			-- end
		-- end
	end
	
	return SP3D
end

return Spline3D