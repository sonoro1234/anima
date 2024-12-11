require"anima"
local vec3 = mat.vec3
local vec2 = mat.vec2
local vec4 = mat.vec4
local par_shapes = require"anima.par_shapes"
local R = require"anima.rotations"

local zmoOP = ffi.new("int[?]",1)
local zmoMODE = ffi.new("int[?]",1)
local md = 0.5
local zmobounds = ffi.new("float[?]",6,{ -0.25*md, -0.25*md, -0.25*md, 0.25*md, 0.25*md, 0.25*md })
local snap = ffi.new("float[3]",{ 1, 1, 1 })
local useSnap = ffi.new("bool[1]",false)
local function ShZMO(Shapes, GL, camera)
	ig.RadioButton("trans", zmoOP, imgui.TRANSLATE); ig.SameLine();
	ig.RadioButton("rot", zmoOP, imgui.ROTATE); ig.SameLine();
	ig.RadioButton("scale", zmoOP, imgui.SCALE); --ig.SameLine();
	--ig.RadioButton("bounds", zmoOP, imgui.BOUNDS);
	ig.RadioButton("local", zmoMODE, imgui.LOCAL); ig.SameLine();
	ig.RadioButton("world", zmoMODE, imgui.WORLD);
	ig.Checkbox("snap", useSnap);
	--ig.SameLine()
	if useSnap[0] then
		ig.SameLine()
		if zmoOP[0] == imgui.TRANSLATE then
			ig.InputFloat3("Snap", snap)
		elseif zmoOP[0] == imgui.ROTATE then
			ig.InputFloat("Angle Snap", snap)
		elseif zmoOP[0] == imgui.SCALE then
			ig.InputFloat("Scale Snap", snap);
		end
	end
	ig.ImGuizmo_BeginFrame() 
	ig.ImGuizmo_AllowAxisFlip(false)
	local MVmo = camera:MV().gl
	local MPmo = camera:MP().gl
	ig.ImGuizmo_SetRect(unpack(GL.stencil_sizes))
	
	local frame = Shapes:get_frame()
	--frame to MOmo
	local Mt = mat.translate(frame.center)
	local Mr = mat.rotABCD(mat.vec3(0,0,1),frame.Z,mat.vec3(1,0,0),frame.X).mat4
	local scale = Shapes.ModelMpars.scale[Shapes.NM.curr_shape]
	local Msc = mat.scale(scale[0],scale[1],scale[2])
	local MOmo = (Mt*Mr*Msc).gl
	----------------------
	ig.ImGuizmo_PushID("zmo_sh")
	if ig.ImGuizmo_Manipulate(MVmo,MPmo,zmoOP[0],zmoMODE[0],MOmo,nil,useSnap[0] and snap or nil, nil,nil) then
		--print("Manipulate shape")
		--editor.object:setModelM(mat.gl2mat4(MOmo))
		--Momo to frame
		local MM = mat.gl2mat4(MOmo)
		local scale = mat.get_scale(MM)
		local sc = Shapes.ModelMpars.scale[Shapes.NM.curr_shape]
		sc[0] = scale.x; sc[1] = scale.y; sc[2] = scale.z
		MM = mat.ortho_normalize(MM)
		local center = mat.get_translate(MM)
		local X = MM.mat3*mat.vec3(1,0,0)
		local Y = MM.mat3*mat.vec3(0,1,0)
		local Z = MM.mat3*mat.vec3(0,0,1)
		Shapes:set_frame{X=X,Y=Y,Z=Z,center=center}
	end
	ig.ImGuizmo_PopID()
end

local function Shapes(GL,camera,updatefunc)

	local shapes = {"parametric_sphere","cylinder","cone"}
	local M = {}
	M.shapes_table = {}
	M.frames = {}
	M.ModelM = {}
	M.shape_pars = {}
	M.ModelMpars = {scale = {},rot={},pos={}}
	
	local scaleMVE = gui.MultiValueEdit("scale",3)
	local rotMVE = gui.MultiValueEdit("rot",3)
	local posMVE = gui.MultiValueEdit("pos",3)
	
	local numshapes = 0
	local NM = gui.Dialog("shapes",
	{{"curr_shape",0,guitypes.valint,{min=1,max=numshapes}},
	{"newshape",0,guitypes.button,function(this) local i = M:newmesh();M:update(i,"creation") end},
	{"cloneshape",0,guitypes.button,function(this) local i = M:clonemesh();M:update(i,"creation") end,{sameline=true}},
	{"shape",1,guitypes.slider_enum, shapes,function() M:recreate_mesh() end},
	{"slices",8,guitypes.valint,{min=4,max=64},function() M:recreate_mesh() end},
	{"stacks",8,guitypes.valint,{min=4,max=64},function() M:recreate_mesh() end},
	},function(this,  varname)
		if this.curr_shape < 1 then return end
		if varname == "curr_shape" then
			this.vars.shape[0] = M.shape_pars[this.curr_shape][1]
			this.vars.slices[0] = M.shape_pars[this.curr_shape][2]
			this.vars.stacks[0] = M.shape_pars[this.curr_shape][3]
		end
		
		local scale = M.ModelMpars.scale[this.curr_shape]
		local rot   = M.ModelMpars.rot[this.curr_shape] 
		local pos   = M.ModelMpars.pos[this.curr_shape] 
		if scaleMVE:Draw(scale) then M:update() end
		if rotMVE:Draw(rot) then M:update() end
		if posMVE:Draw(pos) then M:update() end
		ShZMO(M, GL, camera)
	end)
	M.NM = NM
	NM.plugin = M
	function M:recreate_mesh()
		if not M.shapes_table[NM.curr_shape] then return end
		local mesh1 = par_shapes.create[shapes[NM.shape]](NM.slices,NM.stacks)
		mesh1 = mesh.par_shapes2mesh(mesh1)
		M.shapes_table[NM.curr_shape].mesh = mesh1
		M.shape_pars[NM.curr_shape] = {NM.shape,NM.slices,NM.stacks}
		M:update()
	end
	function M:create_mesh(shape,slices,stacks)
		local mesh1 = par_shapes.create[shapes[shape]](slices,stacks)
		mesh1 = mesh.par_shapes2mesh(mesh1)
		table.insert(M.shapes_table,{mesh=mesh1})
	end
	function M:newmesh()
		numshapes = numshapes + 1
		NM.vars.curr_shape[0]=numshapes 
		NM.defs.curr_shape.args.max=numshapes 
		
		self:create_mesh(NM.shape,NM.slices,NM.stacks)
		self.frames[numshapes] = {X=vec3(1,0,0),Y=vec3(0,0,-1),Z=vec3(0,1,0),center=vec3(0,0,0)}
		--self.frames[numshapes] = {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=vec3(0,0,0)}
		
		M.shape_pars[numshapes] = {NM.shape,NM.slices,NM.stacks}
		M.ModelMpars.scale[numshapes] = ffi.new("float[3]",{1,1,1})
		M.ModelMpars.rot[numshapes]   = ffi.new("float[3]")
		M.ModelMpars.pos[numshapes]   = ffi.new("float[3]")
		
		return #M.shapes_table
	end
	
	function M:clonemesh()
		local ii = NM.curr_shape
		if ii < 1 then return end
		numshapes = numshapes + 1
		NM.vars.curr_shape[0]=numshapes 
		NM.defs.curr_shape.args.max=numshapes
		self:create_mesh(unpack(M.shape_pars[ii]))
		local ofra = self.frames[ii]
		self.frames[numshapes] = {X=ofra.X,Y=ofra.Y,Z=ofra.Z,center=ofra.center}
		--self.frames[numshapes] = {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=vec3(0,0,0)}
		
		M.shape_pars[numshapes] = {unpack(M.shape_pars[ii])}
		M.ModelMpars.scale[numshapes] = ffi.new("float[3]",M.ModelMpars.scale[ii])
		M.ModelMpars.rot[numshapes]   = ffi.new("float[3]",M.ModelMpars.rot[ii])
		M.ModelMpars.pos[numshapes]   = ffi.new("float[3]",M.ModelMpars.pos[ii])
		
		return #M.shapes_table
	end
	
	function M:external_control(yes)
		NM.defs.curr_shape.invisible = yes
		NM.defs.newmesh.invisible = yes
	end
	
	function M:set_current(i)
		self.NM.vars.curr_shape[0] = i
	end
	
	function M:deletemesh(ii)
		table.remove(M.shapes_table,ii)
		table.remove(M.frames,ii)
		table.remove(M.ModelM,ii)
		table.remove(M.ModelMpars.scale,ii)
		table.remove(M.ModelMpars.rot,ii)
		table.remove(M.ModelMpars.pos,ii)
		numshapes = numshapes - 1
		NM.vars.curr_shape[0]=numshapes 
		NM.defs.curr_shape.args.max=numshapes 
	end
	function M:deleteall()
		for i=#M.shapes_table,1,-1 do
			self:deletemesh(i)
		end
	end
	local use_update = true
	function M:update(ii,...)
		ii = ii or NM.curr_shape
		if ii == 0 then return end
		if use_update then updatefunc(self,ii,...) end
	end
	function M:make_model_mat(ii)
		ii = ii or NM.curr_shape
		if ii==0 then return end
		local M = 1
		local scale = self.ModelMpars.scale[ii]
		local rot = self.ModelMpars.rot[ii]  
		local pos = self.ModelMpars.pos[ii]  
		
		M = mat.scale(scale[0],scale[1],scale[2]) * M
		M = R.ZYXE(rot[2],rot[1],rot[0]).mat4 * M
		M = mat.translate(pos[0],pos[1],pos[2]) * M
		self.ModelM[ii] =  M --self.MFinv * M * self.MF 
	end
	function M:set_frame(frame,ii)
		ii = ii or NM.curr_shape
		self.frames[ii] = frame or {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=vec3(0,0,0)}
		M:update(ii)
	end
	M.set_frameW = M.set_frame --works in world coordinates
	function M:resetmesh(ii,frame,pts)
		self:set_frame(frame,ii)
	end
	function M:get_frame()
		if NM.curr_shape > 0 then
			return self.frames[NM.curr_shape]
		end
	end
	M.get_frameW = M.get_frame
	function M:get_mesh(ii)
		local mesh1 = self.shapes_table[ii].mesh
		local frame = self.frames[ii]
		local meshC = mesh1:clone()
		--make planes coord sys
		local Mt = mat.translate(frame.center)
		local Mr = mat.rotABCD(vec3(0,0,1),frame.Z,vec3(1,0,0),frame.X).mat4
		self:make_model_mat(ii)
		meshC:M4(Mt*Mr*self.ModelM[ii])
		return meshC,frame
	end
	M.get_meshW = M.get_mesh
	M.load = function(self,pars) 
				use_update = false
				M:deleteall()
				M.NM:SetValues(pars.dial)
				M.shape_pars = pars.shape_pars
				M.ModelMpars = pars.ModelMpars
				M.frames = pars.frames
				numshapes = pars.numshapes or 0
				for i=1,numshapes do
					M:create_mesh(unpack(M.shape_pars[i]))
					M:set_frame(M.frames[i],i)
				end
				use_update = true
				NM.defs.curr_shape.args.max=numshapes
				for i=1,numshapes do M:update(i,"creation") end
				--if M.update then M:update() end
			end
	M.save = function()
			local pars = {}
			pars.dial = M.NM:GetValues()
			pars.shape_pars = M.shape_pars
			pars.ModelMpars = M.ModelMpars
			pars.numshapes = numshapes
			pars.frames = M.frames
			return pars
		end
	return M
end
return Shapes