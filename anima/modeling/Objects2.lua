require"anima"
local vec3 = mat.vec3

local vert_twist = [[
	uniform mat4 MF;
	uniform float ang;
	uniform float benddir;
	uniform int op = 0;
	uniform int axisperm = 0;
	const mat3 Mper = mat3(0,0,1,
					1,0,0,
					0,1,0);
	mat3 Maxis = mat3(1);
	
	mat4 MFinv = inverse(MF);
	in vec3 position;
	out vec3 position_out;
	
	void main(){
		for(int i=1;i<=axisperm;i++){
			Maxis = Mper*Maxis;
		}
		mat3 Maxisinv = inverse(Maxis);
		
		vec4 position4 = MF*vec4(position,1);
		vec3 position3 = (position4/position4.w).xyz;
		position3 = Maxis*position3;
		float nx,ny,nz;
		if (op==0){
			/// twist
			float alfa = position3.x*ang;
			float cos = cos(alfa);
			float sin = sin(alfa);
			ny = cos*position3.y-sin*position3.z;
			nz = sin*position3.y+cos*position3.z;
			nx = position3.x;
		}else{
			
			//rotate bendir
			float cosb = benddir;//cos(benddir);
			float sinb = 1.0-benddir;//sin(benddir);
			float y2 = cosb*position3.y - sinb*position3.z;
			float z2 = sinb*position3.y + cosb*position3.z;
			float alfa = y2*ang;
			float cos = cos(alfa);
			float sin = sin(alfa);
			float y3 = cos*y2-sin*z2;
			float z3 = sin*y2+cos*z2;
			//unrotate (same cos change -sin)
			ny = cosb*y3 + sinb*z3;
			nz = -sinb*y3 + cosb*z3;
			nx = position3.x;
			
		}
		position3 = Maxisinv*vec3(nx,ny,nz);
		position4 = MFinv*vec4(position3,1);
		position_out = (position4/position4.w).xyz;
	}
]]

local vert_sh = [[
in vec3 position;
in vec2 texcoords;

uniform mat4 ModelM;
uniform mat4 MVP;
out  vec2 f_tc;
void main()
{
	f_tc = texcoords;
	gl_Position = MVP *ModelM* vec4(position,1);
}
]]

local frag_sh = [[
uniform sampler2D tex;
in  vec2 f_tc;
void main()
{
	gl_FragColor  = texture2D(tex,f_tc);
}
]]

local frag_shdiscard = [[
uniform sampler2D tex;
in  vec2 f_tc;
void main()
{
	vec4 color = texture2D(tex,f_tc);
	if (color.a < 0.5)
      discard;
	gl_FragColor  = color;
}

]]

local vertmesh = [[
in vec3 position;
uniform mat4 ModelM;
uniform mat4 MVP;

void main()
{
	gl_Position = MVP *ModelM* vec4(position,1);
}
]]

local fragmesh = [[
uniform vec3 color;
void main()
{
	gl_FragColor  = vec4(color,1);
}
]]

local R = require"anima.rotations"
local program, progmesh, program_discard
local prog_twist
local inimesh,initex


local function Object(name,objtree)
	local O = {objtree=objtree}
	O.name = name or tostring(O)
	O.childs = {}
	
	O.scale = vec3(1,1,1)
	O.rot = vec3(0,0,0)
	O.pos = vec3(0,0,0)
	O.twisters = {}
	O.MF = mat.identity()
	O.MFinv = O.MF.inv
	O.ModelM = mat.identity()
	O.tex = initex
	local md = 0.5
	O.zmobounds = ffi.new("float[?]",6,{ -0.25*md, -0.25*md, -0.25*md, 0.25*md, 0.25*md, 0.25*md })
	
	function O:add_twister()
		local prevvao,destvao
		if #self.twisters > 0 then --modify last tfv1
			local prevtw = self.twisters[#self.twisters]
			destvao = prevtw.vaomeshtfb
			prevtw.vaomeshtfb = self.mesh:vao(prog_twist, true)
			prevtw.tfv1:set_vaos(prevtw.orig_vao,prevtw.vaomeshtfb)
			prevvao = prevtw.vaomeshtfb
		else
			destvao = self.vaomesh:clone(prog_twist)
			prevvao = self.mesh:vao(prog_twist, true)
		end

		local tw = {}
		tw.deformang = ffi.new("float[1]")
		tw.benddir = ffi.new("int[1]")
		tw.axisperm = ffi.new("int[1]")
		tw.deformop = ffi.new("int[1]")
		
		tw.orig_vao = prevvao
		tw.vaomeshtfb = destvao
		tw.tfv1 = TFV1({position="position_out"},prog_twist,tw.orig_vao,tw.vaomeshtfb)
		table.insert(self.twisters,tw)
	end
	function O:del_twister(i)
	
	end
	function O:set_frame(frame,center)
		O.frame = frame or {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1)}--,center=center or self.mesh:calc_centroid()}
		O.frame.center = O.frame.center or center or self.mesh:calc_centroid()
		
		local MF = mat.translate(-self.frame.center)
		--print(self.frame.Y, vec3(0,1,0), self.frame.X , vec3(1,0,0))
		MF = mat.rotABCD(self.frame.Y, vec3(0,1,0), self.frame.X , vec3(1,0,0)).mat4 * MF
		--print(MF)
		O.MF = MF
		O.MFinv = MF.inv
		
		-- vaoframe
		local maxdim = self.maxdim or 1
		
		local fc = self.frame.center
		local fx = fc + self.frame.X * maxdim
		local fy = fc + self.frame.Y * maxdim
		local fz = fc + self.frame.Z * maxdim
		
		self.vaoframe = VAO({position=mat.vec2vao{fc,fx,fc,fy,fc,fz}},progmesh)
		self:make_model_mat()
	end
	
	function O:setMesh(mesh,tex,frame)
		print("setmesh",mesh,tex,frame)
		O.bounds = {mesh:bounds()}
		O.mesh = mesh
		O.tex = tex or O.tex or initex
		O.tex:Bind()
		O.tex:gen_mipmap()
		
		local dims = self.bounds[2] - self.bounds[1]
		self.maxdim = math.max(dims.x, math.max(dims.y, dims.z))
		local md = self.maxdim
		self.zmobounds = ffi.new("float[?]",6,{ -0.25*md, -0.25*md, -0.25*md, 0.25*md, 0.25*md, 0.25*md })
		
		self:set_frame(frame)
		
		if self.vao then 
			self.vao:delete()
			self.vaomesh:delete()
		end
		self.vao = mesh:vao(program)
		self.vaomesh = self.vao:clone(progmesh) 
		--TFV
		for i,tw in ipairs(self.twisters) do
			if tw.orig_vao then tw.orig_vao:delete() end
			if tw.vaomeshtfb then tw.vaomeshtfb:delete() end
			tw.orig_vao = mesh:vao(prog_twist, true)
			tw.vaomeshtfb = self.vaomesh:clone(prog_twist)
			if not tw.tfv1 then
				tw.tfv1 = TFV1({position="position_out"},prog_twist,tw.orig_vao,tw.vaomeshtfb)
			else
				tw.tfv1:set_vaos(tw.orig_vao,tw.vaomeshtfb)
			end
		end
	end
	
	function O:make_localM()
		local M = 1
		M = mat.scale(O.scale.x,O.scale.y,O.scale.z) * M
		M = R.ZYXE(O.rot.z,O.rot.y,O.rot.x).mat4 * M
		M = mat.translate(O.pos.x,O.pos.y,O.pos.z) * M
		return M
	end
	
	O.parentM = mat.identity()
	function O:make_model_mat(parentM)
		O.parentM = parentM or O.parentM
		
		local M = self.make_localM()
		
		self.ModelM =  O.parentM * self.MFinv * M * self.MF
		for ich,child in ipairs(self.childs) do
			child:make_model_mat(self.ModelM)
		end
	end
	
	--set local M
	function O:set_localM(M)
		self.ModelM =  O.parentM * self.MFinv * M * self.MF
		
		self:calcfromM(M)
		
		for ich,child in ipairs(self.childs) do
			child:make_model_mat(self.ModelM)
		end
	end
	
	function O:get_localM()
		return O.parentM.inv*self.MF*self.ModelM*self.MFinv
	end
	
	--useful for zmo
	function O:getModelM()
		return  self.ModelM * self.MFinv
	end
	
	local fmod,abs,pi = math.fmod,math.abs,math.pi
	local pix2,hpi,hpix3 = pi*2,pi*0.5, pi*1.5
	--useful for zmo
	function O:setModelM(MM)
		self.ModelM = MM * self.MF

		local M = self.MF * O.parentM.inv * MM
		
		self:calcfromM(M,true)
		
		for ich,child in ipairs(self.childs) do
			child:make_model_mat(self.ModelM)
		end
	end
	
	function O:calcfromM(M,use_roty)
		
		local roty
		if use_roty then roty = self.rot.y end
		
		self.pos = vec3(M.m41,M.m42,M.m43)
		
		local scale = {}
		scale[1] = vec3(M.m11, M.m12, M.m13):norm()
		scale[2] = vec3(M.m21, M.m22, M.m23):norm()
		scale[3] = vec3(M.m31, M.m32, M.m33):norm()
		self.scale = vec3(scale[1],scale[2],scale[3])
		
		M = M*mat.scale(1/scale[1],1/scale[2],1/scale[3])
		
		local z,y,x = R.ZYXE2angles(M.mat3)
		--try to achive continuity in roty
		if roty then --near roty value
			local yA = fmod(roty,pix2)
			while yA < 0 do yA = yA + pix2 end
			local yB = y
			while yB < 0 do yB = yB + pix2 end
			if (abs(yA-yB)>1e-6) then
			--print(yA,yB)
			if (hpi < yA and yA < hpix3) and
				not (hpi < yB and yB < hpix3) then
				--print("correct",x,y,z,roty)
				 y = pi - y
				 z = z + pi
				 x = x + pi
				 --print(x,y,z)
			end
			end
		end
		self.rot = vec3(x,y,z)
	end
	
	function O:add_child(name)
		local child = Object(name,self.objtree)
		O.childs[#O.childs + 1] = child
		return child, #O.childs
	end
	function O:drawmesh(U, editor)
		local color = editor.object==self and {1,1,1} or {0.5,0.5,0.5}
		U.ModelM:set(self.ModelM.gl)
		if self.vaomesh then
			U.color:set(color)
			self.vaomesh:draw_mesh()
		end
		if self.vaoframe and editor.object==self then
			U.color:set{1,0,0}
			self.vaoframe:draw(glc.GL_LINES,2,0)
			U.color:set{0,1,0}
			self.vaoframe:draw(glc.GL_LINES,2,2)
			U.color:set{0,0,1}
			self.vaoframe:draw(glc.GL_LINES,2,4)
			gl.glPointSize(5)
			U.color:set{1,1,0}
			self.vaoframe:draw(glc.GL_POINTS,1,0)
			gl.glPointSize(1)
		end
		for i,child in ipairs(O.childs) do
			child:drawmesh(U, editor)
		end
	end
	
	function O:drawpoints(U, editor)
		if editor.object==self then
			if self.vaomesh  then
				U.ModelM:set(self.ModelM.gl)
				U.color:set{1,0,0}
				self.vaomesh:draw(glc.GL_POINTS)
			end
		else
			for i,child in ipairs(O.childs) do
				child:drawpoints(U,editor)
			end
		end
	end

	function O:draw(U,NM)
		
		if self.vao then
			U.ModelM:set(self.ModelM.gl)
			O.tex:Bind()
			
			---[[
				local tex = O.tex
				if NM.aniso then
					tex:set_aniso()
				else
					tex:set_aniso(1)
				end
				if NM.mipmaps then
					tex:min_filter(glc.GL_LINEAR_MIPMAP_LINEAR)
				else
					tex:min_filter(glc.GL_LINEAR)
				end
			--]]
			self.vao:draw_elm()
		end
		for i,child in ipairs(O.childs) do
			child:draw(U,NM)
		end
	end
	
	function O:do_twist()
		if self.twisters[1] and self.twisters[1].orig_vao then
			for i,tw in ipairs(self.twisters) do
				prog_twist:use()
				prog_twist.unif.ang:set{tw.deformang[0]}
				prog_twist.unif.benddir:set{tw.benddir[0]}
				prog_twist.unif.axisperm:set{tw.axisperm[0]}
				prog_twist.unif.op:set{tw.deformop[0]}
				prog_twist.unif.MF:set(self.MF.gl)
				tw.tfv1:Update()
			end
		end
		for i,child in ipairs(O.childs) do
			child:do_twist()
		end
	end
	
	function O:dump(lev)
		lev = lev or 0
		print(string.rep("  ",lev)..O.name)
		prtable(O.frame)
		for ich,child in ipairs(self.childs) do
			child:dump(lev+1)
		end
	end

	function O:tree(editor)
		if #self.childs > 0 then
			ig.SetNextItemOpen(true, ig.lib.ImGuiCond_Once)
			if ig.TreeNode(O.name) then
				ig.SameLine();
				if ig.RadioButton("edit##"..tostring(O),editor.object and editor.object==O or false) then
					editor.object = O
				end
				if O.name == "root" then
					ig.SameLine();
					if ig.RadioButton("noedit##"..tostring(O),not editor.object) then
						editor.object = nil
					end
				end
				for ich,child in ipairs(self.childs) do
					child:tree(editor)
				end
				ig.TreePop()
			end
		else
			ig.BulletText(O.name)
			ig.SameLine()
			if ig.RadioButton("edit##"..tostring(O),editor.object and editor.object==O or false) then
				editor.object = O
			end
			if O.name == "root" then
				ig.SameLine();
				if ig.RadioButton("noedit##"..tostring(O),not editor.object) then
					editor.object = nil
				end
			end						   
		end
	end
	
	function O:find_child(name)
		for ich,child in ipairs(self.childs) do
			if child.name == name then
				return child
			end
		end 
		for ich,child in ipairs(self.childs) do
			local ret = child:find_child(name)
			if ret then return ret end
		end 
	end
	
	function O:clear_childs()
		for ich,child in ipairs(self.childs) do
			child:clear_childs()
			self.childs[ich] = nil
		end 
	end
	
	--given names table: {name1=true, name2=true}
	--deletes recursively childs with name not in names
	function O:clear_childs_notin(names)
		for ich,child in ipairs(self.childs) do
			child:clear_childs_notin(names)
			if not names[child.name] then
				--self.childs[ich] = nil
				table.remove(self.childs,ich)
			end
		end 
	end
	
	O:set_frame({X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=vec3(0,0,0)})
	
	return O
end


local function Objects(GL,camera,args)
	args = args or {}
	
	local Os = {}
	--------zmo
	local MVmo,MPmo,MOmo
	local zmoOP = ffi.new("int[?]",1)
	local zmoMODE = ffi.new("int[?]",1)
	--local zmobounds = ffi.new("float[?]",6,{ -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 })
	local NMzmo = gui.Dialog("zmo",
	{--{"zmoO",false,guitypes.toggle},
	--{"zmoC",false,guitypes.toggle,nil,{sameline=true}},
	--{"grid",false,guitypes.toggle,nil,{sameline=true}}
	},
	function()
		ig.RadioButton("trans", zmoOP, imgui.TRANSLATE); ig.SameLine();
		ig.RadioButton("rot", zmoOP, imgui.ROTATE); ig.SameLine();
		ig.RadioButton("scale", zmoOP, imgui.SCALE); ig.SameLine();
		ig.RadioButton("bounds", zmoOP, imgui.BOUNDS);
		ig.RadioButton("local", zmoMODE, imgui.LOCAL); ig.SameLine();
		ig.RadioButton("world", zmoMODE, imgui.WORLD);
	end)
	
	
	---------------
	local editor = {}
	local MVEpos = gui.MultiValueEdit("pos",3)
	local MVErot = gui.MultiValueEdit("rot",3)
	local MVEscale = gui.MultiValueEdit("scale",3)
	local MVEdeformang = gui.MultiValueEdit("deformang",1)
	local twn = ffi.new("int[1]",1) --current twister
	local NM = GL:Dialog(args.name or "objects",{
		{"dodraw",true,guitypes.toggle},
		{"mesh",true,guitypes.toggle,nil,{sameline=true}},
		{"points",false,guitypes.toggle,nil,{sameline=true}},
		{"cull",false,guitypes.toggle},
		{"mipmaps",false,guitypes.toggle,nil,{sameline=true}},
		{"aniso",false,guitypes.toggle,nil,{sameline=true}},
		{"showtex",false,guitypes.toggle},
		{"transparency",1,guitypes.slider_enum,{"none","alpha","mult","add","discard"}},
		--{"dump",0,guitypes.button,function() Os.root:dump() end}
	},function() 
		ig.Separator()
		Os.root:tree(editor)
		ig.Separator()
		if editor.object then
			local object = editor.object
			local scale = object.scale:gl()
			if MVEscale:Draw(scale,nil,nil,0.1) then
				object.scale = vec3(scale)
				object:make_model_mat()
			end
			local rot = object.rot
			local frot = ffi.new("float[?]",3,rot.x,rot.y,rot.z)
			if MVErot:Draw(frot,nil,nil,0.1) then
				rot.x,rot.y,rot.z = frot[0],frot[1],frot[2]
				object:make_model_mat()
			end
			local pos = object.pos
			local fpos = ffi.new("float[?]",3,pos.x,pos.y,pos.z)
			if MVEpos:Draw(fpos,nil,nil,0.1) then
				pos.x,pos.y,pos.z = fpos[0],fpos[1],fpos[2]
				object:make_model_mat()
			end
			ig.SetNextItemWidth(80.0)
			ig.SliderInt("twister",twn,0,#object.twisters)
			ig.SameLine()
			if ig.SmallButton("add") then object:add_twister() end
			ig.SameLine()
			ig.SmallButton("del")
			local twister = object.twisters[twn[0]]
			if twister then
				MVEdeformang:Draw(twister.deformang,nil,nil,0.1)
				ig.SameLine()
				local bdt = ffi.new("bool[1]",twister.benddir[0]==1)
				if gui.ToggleButton("benddir", bdt) then
					twister.benddir[0] = bdt[0] and 1 or 0
				end
				local axistr = {[0]="X","Y","Z"}
				ig.SliderInt("axis",twister.axisperm,0,2,axistr[twister.axisperm[0]])
				local opstr = {[0]="twist","bend"}
				ig.SliderInt("deformop",twister.deformop,0,1,opstr[twister.deformop[0]])
			end
		end
		---zmo
		ig.Separator()
		NMzmo:draw()
		if NMzmo.zmoC or NMzmo.zmoO then
			ig.ImGuizmo_BeginFrame() 
			MVmo = camera:MV().gl
			MPmo = camera:MP().gl
			ig.ImGuizmo_SetRect(unpack(GL.stencil_sizes))
			--if NMzmo.zmoC then
				--ig.ImGuizmo_SetOrthographic(camera.NM.ortho);
				--ig.ImGuizmo_ViewManipulate(MVmo,camera.NM.dist or 1,ig.ImVec2(0,0),ig.ImVec2(128,128),0x01010101)
				--if NMzmo.grid then ig.ImGuizmo_DrawGrid(MVmo,MPmo,mat.identity().gl,10) end
				--camera:setMV(mat.gl2mat4(MVmo))
			--end
			--if NMzmo.zmoO and editor.object then
				MOmo = editor.object:getModelM().gl
				--ig.ImGuizmo_DrawCube(MVmo,MPmo,MOmo)
				ig.ImGuizmo_PushID("zmo_obj")
				ig.ImGuizmo_Manipulate(MVmo,MPmo,zmoOP[0],zmoMODE[0],MOmo,nil,nil,zmoOP[0]==imgui.BOUNDS and editor.object.zmobounds or nil,nil)
				editor.object:setModelM(mat.gl2mat4(MOmo))
				ig.ImGuizmo_PopID()  
			--end
		end
	end)
	
	Os.NM = NM
	NM.plugin = Os
	
	function Os:init()
		if not program then
			program = GLSL:new():compile(vert_sh,frag_sh)
			program_discard = GLSL:new():compile(vert_sh,frag_shdiscard)
			progmesh = GLSL:new():compile(vertmesh,fragmesh)
			
			prog_twist = GLSL:new():compile(vert_twist)--,fragmesh)
			prog_twist:set_TFV({"position_out"},true)
			
			--initial object
			local tproc = require"anima.plugins.texture_processor"(GL,0)
			tproc:set_process[[
				#define M_PI 3.1415926535897932384626433832795
				vec4 process(vec2 pos){
					float angle = M_PI*0.25;
					float N = 5.0;
					float freq = 2*N/sin(0.5*M_PI-angle);
					vec2 dir = vec2(cos(angle),sin(angle));
					float dis = dot(dir,pos);
					return vec4(vec3(sin(dis*2*M_PI*freq)*0.5+0.5),1);
				}]]
			local fbo = GL:initFBO({no_depth=true},300,300)
			fbo:Bind()
			ut.Clear()
			tproc:process({},300,300)
			fbo:UnBind()
			initex = fbo:tex()
			
			local par_shapes = require"anima.par_shapes"
			local pmesh = par_shapes.create.cube()
			inimesh = mesh.par_shapes2mesh(pmesh)
			local cent = inimesh:calc_centroid()
			inimesh:M4(mat.translate(-cent))
			local vec2 = mat.vec2
			inimesh.tcoords = {vec2(0,0),vec2(0,1),vec2(1/3,1),vec2(1/3,0),vec2(1,0),vec2(1,1),vec2(2/3,1),vec2(2/3,0)}
		end
		Os.root = Object("root",self)
		initex = args.initex or initex
		if args.doinit then self.root:setMesh(inimesh,initex) end
	end
	
	function Os:clear()
		self.root:clear_childs()
		self.root.ModelM = mat.identity()
	end
	
	function Os:find_node(name)
		return Os.root:find_child(name)
	end
	
	function Os:draw()
		
		if not NM.dodraw then return end

		if NM.cull then 
			gl.glEnable(glc.GL_CULL_FACE) 
		else
			gl.glDisable(glc.GL_CULL_FACE)
		end
		--gl.glEnable(glc.GL_DEPTH_TEST)

		if NM.showtex then
			local obj = editor.object or Os.root
			obj.tex:drawcenter()
		else
			gl.glViewport(0,0,GL.W,GL.H)
			Os.root:do_twist()
			
			if NM.points then
				progmesh:use()
				local U = progmesh.unif
				U.MVP:set(camera:MVP().gl)
				U.color:set{1,0,0}
				gl.glPointSize(5)
				Os.root:drawpoints(U, editor)
				gl.glPointSize(1)
			end
			if NM.mesh then
				progmesh:use()
				local U = progmesh.unif
				U.MVP:set(camera:MVP().gl)
				Os.root:drawmesh(U, editor)
			else
				if NM.transparency == 1 then --none
					gl.glEnable(glc.GL_DEPTH_TEST)
				elseif NM.transparency == 2 then --alpha blend
					gl.glDisable(glc.GL_DEPTH_TEST)
					gl.glEnable(glc.GL_BLEND)
					gl.glBlendFunc(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA)
					glext.glBlendEquation(glc.GL_FUNC_ADD)
				elseif NM.transparency ==3 then --multiply
					gl.glDisable(glc.GL_DEPTH_TEST)
					gl.glEnable(glc.GL_BLEND)
					gl.glBlendFunc(glc.GL_ZERO, glc.GL_SRC_COLOR);
					glext.glBlendEquation(glc.GL_FUNC_ADD)
				elseif NM.transparency == 4 then --add
					gl.glDisable(glc.GL_DEPTH_TEST)
					gl.glEnable(glc.GL_BLEND)
					gl.glBlendFunc(glc.GL_ONE, glc.GL_ONE);
					glext.glBlendEquation(glc.GL_FUNC_ADD)
				end
				
				local U
				if NM.transparency == 5 then
					gl.glEnable(glc.GL_DEPTH_TEST)
					program_discard:use()
					U = program_discard.unif
				else
					program:use()
					U = program.unif
				end
				U.MVP:set(camera:MVP().gl)
				
				U.tex:set{0}
				
				Os.root:draw(program.unif, NM)
				
				gl.glDisable(glc.GL_BLEND)
				gl.glDisable(glc.GL_DEPTH_TEST)
			end
		end
	end
	
	function Os:save()
		local pars = {}
		pars.dial = NM:GetValues()
		return pars
	end
	
	function Os:load(params)
		Os:clear()
		if not params then return end
		NM:SetValues(params.dial or {})
	end
	
	GL:add_plugin(Os,"Objects")
	return Os
end

--[=[ test 
local function make_cyl(pos, scl,eje)
	scl = scl or 1
	local par_shapes = require"anima.par_shapes"
	local pmesh = par_shapes.create.cylinder(32,32)
	local inimesh = mesh.par_shapes2mesh(pmesh)
	local cent = inimesh:calc_centroid()
	local rot = mat.rotAB(vec3(0,0,1),eje).mat4
	inimesh:M4(mat.translate(pos)*mat.translate(-cent)*rot*mat.scale(scl*vec3(1,1,5)))
	return inimesh
end

local function scene1(objects)
	objects.root:set_frame(nil,vec3(0,0,-12*0))
	local child,ich = objects.root:add_child("Xcyl")
	child:setMesh(make_cyl(vec3(-3,0,-12*0),1,vec3(1,0,0)))
	local child, ich = objects.root:add_child("Ycyl")
	child:setMesh(make_cyl(vec3(3,0,-12*0),1,vec3(0,1,0)))
	child:add_twister()
	child = child:add_child("Zcyl")
	child:setMesh(make_cyl(vec3(0,0,-12*0),1,vec3(0,0,1)))
end

local function scene2(objects)
	local d = 6
	objects.root:setMesh(make_cyl(vec3(0,0,0),3,vec3(0,1,0)))
	for i=0,9 do
		print("------------add_child",i)
		local child = objects.root:add_child("child"..i)
		local ang = i*2*math.pi/10
		local pos = vec3(d*math.sin(ang),0,d*math.cos(ang))
		local frame = mesh.make_frame{Z=pos,Y=vec3(0,1,0)}
		prtable(frame)
		child:setMesh(make_cyl(pos,1,vec3(0,1,0)),nil, frame)
	end
end

local GL = GLcanvas{H=800,aspect=1,use_log=false}
GLSL.default_version = "#version 140\n"
local camera = Camera(GL,{gizmo=true,type="tps"})
--camera.NM.vars.pos:set{0,0,19}
local objects,msaa
function GL:init()
	objects = Objects(GL,camera)--,{doinit=true})
	scene1(objects)
	msaa = GL:initFBOMultiSample()
end
function GL.draw(t,w,h)
	msaa:Bind()
	ut.Clear()
	objects:draw()
	msaa:Dump()
end
GL:start()
--]=]

return Objects