require"anima"
local vec3 = mat.vec3
local vec2 = mat.vec2
local vec4 = mat.vec4
local CG = require"anima.CG3"

local function Spline3D(GL, camera,updatefunc)
	local SP3D
	local function sp_update(sp, cmd)
		print("SPLINE",sp,cmd)
		if not cmd then return end
			if false then --self.calc_framecenter then
				local ii = SP3D.NM.curr_spline
				print("calframecenter",ii)
				print("center",SP3D.frames[ii].center)
				local Zcent = (camera:MV()*vec3(0,0,0)).z
				local cent = vec3(0,0,0)
				for i,v in ipairs(SP3D.sccoors[ii]) do
					local r = camera:Viewport2Eye(v)
					cent = cent + r
				end
				cent = cent/#SP3D.sccoors[ii]
				--cent = Scr2Eye(nil,self.sccoors[ii][1])
				print(cent)
				local fac = Zcent/cent.z
				cent = cent*fac
				SP3D.frames[ii].center = cent
				print(cent)
			end
	end
	------------Spline modifications for 3D
	local HeightEditor = require"anima.modeling.HeightEditor"
	SP3D = require"anima.modeling.Spline"(GL,sp_update)
	
	local doheightupdate = true
	local function updateheights(ii)
		if doheightupdate then updatefunc(SP3D,ii) end
		--print"updateheights done"
	end
	
	function SP3D:create_height_editor(spnum)
		local updateheightfunc = function(hedit)
			if self.HeightEditors[spnum].mesh then
				local Mtrinv = self.HeightEditors[spnum].Mtrinv
				self.HeightEditors[spnum].mesh:M4(Mtrinv)
				updateheights(spnum)
			end
		end
		self.HeightEditors[spnum] = HeightEditor(GL,updateheightfunc  )
		return self.HeightEditors[spnum]
	end
	
	SP3D.zoffset = {}
	local MVEzoffset = gui.MultiValueEdit("zoffset",1)
	SP3D.HeightEditors = {}
	local oldfunc = SP3D.NM.func
	SP3D.NM.func = function(this)
		oldfunc(this)
		if SP3D.HeightEditors and SP3D.HeightEditors[this.curr_spline] then
			ig.Separator()
			if MVEzoffset:Draw(SP3D.zoffset[this.curr_spline],nil,nil,0.001) then SP3D:process_all() end
			SP3D.HeightEditors[this.curr_spline].NM:draw()
		end
	end
	
	SP3D.frames = {}
	
	local function Scr2Eye(MPinv,sc)
		return camera:Viewport2Eye(sc,MPinv)
	end
	local function Eye2Scr(MP,eyep)
		return camera:Eye2Viewport(eyep,MP)
	end
	
	function SP3D:newmesh(pts)
		local spnum = self:newspline(pts, true) --dont calc until set_frame
		self:create_height_editor(spnum)
		SP3D.zoffset[spnum] = ffi.new("float[1]",0)
		local cent = camera:MV()*vec3(0,0,0)
		print("newmesh",cent)
		self.frames[spnum] = {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=cent}
		return spnum
	end
	
	local olddeletespline = SP3D.deletespline
	function SP3D:deletemesh(ii)
		table.remove(SP3D.frames,ii)
		table.remove(SP3D.HeightEditors,ii)
		olddeletespline(SP3D,ii)
	end
	function SP3D:deleteall()
		for i=#self.sccoors,1,-1 do
			self:deletemesh(i)
		end
	end
	function SP3D:set_frameW(frame, ii)
		local MV = camera:MV()
		return self:set_frame(mesh.move_frame(frame, MV))
	end
	function SP3D:set_frame(frame,ii)
		ii = ii or self.NM.curr_spline
		self.frames[ii] = frame or {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=vec3(0,0,-1)}
		self:calc_spline(ii)
		--updatefunc(self)
	end
	function SP3D:get_frame()
		if self.NM.curr_spline > 0 then
			return self.frames[self.NM.curr_spline]
		end
	end
	function SP3D:get_frameW()
		local MVinv = camera:MV().inv
		if self.NM.curr_spline > 0 then
			return mesh.move_frame(self.frames[self.NM.curr_spline],MVinv)
		end
	end
	function SP3D:calc_spline(ii)
		print("calc_spline1",ii,self.NM.curr_spline)
		--print(debug.traceback())
		ii = ii or self.NM.curr_spline
		--print("calc_spline",ii,self:numpoints(ii))
		if self:numpoints(ii) > 2 then
			--project on plane
			local prsc = {}
			local R = self.frames[ii].Z
			assert(R~=0, "frame Z==0")
			local point = self.frames[ii].center + self.zoffset[ii][0]*R
			local D = -point*R
			if D < 0 then D = -D; R = -R end
			local MP = camera:MP()
			local MPinv = MP.inv

			for i,v in ipairs(self.sccoors[ii]) do
				local r = Scr2Eye(MPinv,v) --vec3(v.x,v.y,1)
				local dotinv = -D/(R*r)
				prsc[i] = dotinv*r
			end

			if self.sccoors[ii].holes then
				prsc.holes = {}
				for i,hole in ipairs(self.sccoors[ii].holes) do
					prsc.holes[i] = {}
					for j,v in ipairs(hole) do
						local r = Scr2Eye(MPinv,v) --vec3(v.x,v.y,1)
						local dotinv = -D/(R*r)
						prsc.holes[i][j] = dotinv*r
					end
				end
			end
			--make planes coord sys
			local Mt = mat.translate(-prsc[1])
			local X = (prsc[2] - prsc[1]):normalize()
			local Mr = mat.rotABCD(R,vec3(0,0,1),X,vec3(1,0,0))--.mat4
			Mr = Mr.mat4
			local Mtr = Mr*Mt
			for i,v in ipairs(prsc) do
				local vv = Mtr*vec4(v,1)
				prsc[i] = (vv/vv.w):xyz()
			end
			--calc minlen for spline
			local minb,maxb = CG.bounds(prsc)
			local diff = maxb - minb
			local minlen = 5*diff:norm()/400
			if prsc.holes then
				for i,hole in ipairs(prsc.holes) do
					for j,v in ipairs(hole) do
						local vv = Mtr*vec4(v,1)
						hole[j] = (vv/vv.w):xyz()
					end
				end
			end

			local pspr = CG.Spline(prsc,self.alpha[ii][0],self.divs[ii][0],true,minlen)

			if prsc.holes then
				pspr.holes = {}
				for i,hole in ipairs(prsc.holes) do
					if #hole > 2 then
						pspr.holes[i] = CG.Spline(hole,self.alpha[ii][0],self.divs[ii][0],true,minlen)
					end
				end
			end

			--self.indexes[ii] = CG.EarClipSimple2(pspr)--,true)
			
			local Mtrinv = Mtr.inv

			self.ps[ii] = {}
			for i,v in ipairs(pspr) do
				local vv = Mtrinv*v
				self.ps[ii][i] = Eye2Scr(MP,vv)
			end
			if pspr.holes then
				self.ps[ii].holes = {}
				for k,hole in ipairs(pspr.holes) do
					self.ps[ii].holes[k] = {}
					for j,v in ipairs(hole) do
						local vv = Mtrinv*v
						self.ps[ii].holes[k][j] = Eye2Scr(MP,vv)
					end
				end
			end
			--doheightupdate = false
			self.HeightEditors[ii].Mtrinv = Mtrinv
			self.HeightEditors[ii].Mtr = Mtr
			self.HeightEditors[ii]:set_spline(pspr)
			doheightupdate = true
		end
	end
	function SP3D:get_mesh(ii)
		return self.HeightEditors[ii].mesh, self.frames[ii]
	end
	function SP3D:get_meshW(ii)
		local MVinv = camera:MV().inv
		local mm,fr = self:get_mesh(ii)
		--print(mm,fr, "is mesh")
		return mm and mm:clone():M4(MVinv) or nil, mesh.move_frame(fr, MVinv)
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
		pars.zoffset = self.zoffset
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
		self.zoffset = pars.zoffset or {}
		for i=1,pars.SP.numsplines do
			self.zoffset[i] = self.zoffset[i] or ffi.new("float[1]")
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

--[=[
local objects = {}
local GL = GLcanvas{H=1000,aspect=1,DEBUG=false}
local DboxO = GL:DialogBox("objects",true)
local camera = Camera(GL,"tps")
local edit
local function update(a,i) 
	print("update spline",a,i) 
	local meshW,frame = edit:get_meshW(i)
	print("meshW",meshW,frame)
	local object = objects[i] 
	if not object then
		object = require"anima.Object3D"(GL,camera,{name="obj_"..i})
		object:init()
		objects[i] = object
		DboxO:add_dialog(object.NM)
	end
	if meshW then
		object:setMesh(meshW,gtex, frame)
	end

end

edit = Spline3D(GL,camera,update)--,doblend=true})
edit:newmesh()
--edit:set_frame(nil,1)
local plugin = require"anima.plugins.plugin"
edit.fb = plugin.serializer(edit)
local DBox = GL:DialogBox("Spline3D demo",true)
function GL.init()
	DBox:add_dialog(edit.NM)
end
function GL:draw(t,w,h)
	--edit.NM:draw()
	ut.Clear()
	for im,o in pairs(objects) do
		--print("draw",im,o)
		o:draw()
	end
end
GL:start()
--]=]

return Spline3D