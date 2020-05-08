require"anima"
local vec3 = mat.vec3
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
local program, progmesh
local inimesh,initex


local function Object(name)
	local O = {}
	O.name = name or tostring(O)
	O.childs = {}
	
	O.scale = vec3(1,1,1)
	O.rot = vec3(0,0,0)
	O.pos = vec3(0,0,0)
	O.MF = mat.identity()
	O.MFinv = O.MF.inv
	O.ModelM = mat.identity()
	O.tex = initex
	local md = 0.5
	O.zmobounds = ffi.new("float[?]",6,{ -0.25*md, -0.25*md, -0.25*md, 0.25*md, 0.25*md, 0.25*md })
	
	function O:set_frame(frame)
		O.frame = frame or {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=self.mesh:calc_centroid()}

		local MF = mat.translate(-self.frame.center)
		MF = mat.rotABCD(self.frame.Y, vec3(0,1,0), self.frame.X , vec3(1,0,0)).mat4 * MF

		O.MF = MF
		O.MFinv = MF.inv
		
		-- vaoframe
		maxdim = self.maxdim or 1
		
		local fc = self.frame.center
		local fx = fc + self.frame.X * maxdim
		local fy = fc + self.frame.Y * maxdim
		local fz = fc + self.frame.Z * maxdim
		
		self.vaoframe = VAO({position=mat.vec2vao{fc,fx,fc,fy,fc,fz}},progmesh)
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
		
		self:make_model_mat()
		if self.vao then self.vao:delete() end
		self.vao = mesh:vao(program)
		if self.vaomesh then self.vaomesh:delete() end
		self.vaomesh = mesh:vao(progmesh, true)
		
		self:set_frame(frame)
	end
	
	O.parentM = mat.identity()
	function O:make_model_mat(parentM)
		O.parentM = parentM or O.parentM
		local M = 1
		M = mat.scale(O.scale.x,O.scale.y,O.scale.z) * M
		M = R.ZYXE(O.rot.z,O.rot.y,O.rot.x).mat4 * M
		M = mat.translate(O.pos.x,O.pos.y,O.pos.z) * M
		self.ModelM =  O.parentM * self.MFinv * M * self.MF
		for ich,child in ipairs(self.childs) do
			child:make_model_mat(self.ModelM)
		end
	end
	
	function O:getModelM()
		return  self.ModelM * self.MFinv
	end
	
	local fmod,abs,pi = math.fmod,math.abs,math.pi
	local pix2,hpi,hpix3 = pi*2,pi*0.5, pi*1.5
	function O:setModelM(MM,roty)
		self.ModelM = MM * self.MF

		local M = self.MF * O.parentM.inv * MM
		
		self.pos = vec3(M.m41,M.m42,M.m43)
		
		local scale = {}
		scale[1] = vec3(M.m11, M.m12, M.m13).norm
		scale[2] = vec3(M.m21, M.m22, M.m23).norm
		scale[3] = vec3(M.m31, M.m32, M.m33).norm
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
		
		for ich,child in ipairs(self.childs) do
			child:make_model_mat(self.ModelM)
		end
	end
	function O:add_child(name)
		local child = Object(name)
		O.childs[#O.childs + 1] = child
		return child, #O.childs
	end
	function O:drawmesh(U)
		
		U.ModelM:set(self.ModelM.gl)
		if self.vaomesh then
			U.color:set{1,1,1}
			self.vaomesh:draw_mesh()
		end
		if self.vaoframe then
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
			child:drawmesh(U)
		end
	end
	
	function O:drawpoints(U)
		if self.vaomesh then
		U.ModelM:set(self.ModelM.gl)
		U.color:set{1,0,0}
		self.vaomesh:draw(glc.GL_POINTS)
		end
		for i,child in ipairs(O.childs) do
			child:drawpoints(U)
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
	
	local O = {}
	--------zmo
	local MVmo,MPmo,MOmo
	local zmoOP = ffi.new("int[?]",1)
	local zmoMODE = ffi.new("int[?]",1)
	--local zmobounds = ffi.new("float[?]",6,{ -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 })
	local NMzmo = gui.Dialog("zmo",
	{{"zmoO",false,guitypes.toggle},
	{"zmoC",false,guitypes.toggle,nil,{sameline=true}},
	{"grid",false,guitypes.toggle,nil,{sameline=true}}},
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
	local NM = GL:Dialog(args.name or "objects",{
		{"dodraw",true,guitypes.toggle},
		{"mesh",true,guitypes.toggle,nil,{sameline=true}},
		{"points",false,guitypes.toggle,nil,{sameline=true}},
		{"cull",false,guitypes.toggle},
		{"mipmaps",false,guitypes.toggle,nil,{sameline=true}},
		{"aniso",false,guitypes.toggle,nil,{sameline=true}},
		{"showtex",false,guitypes.toggle},
		--{"dump",0,guitypes.button,function() O.root:dump() end}
	},function() 
		ig.Separator()
		O.root:tree(editor)
		ig.Separator()
		if editor.object then
			local scale = editor.object.scale.gl
			if MVEscale:Draw(scale,nil,nil,0.1) then
				editor.object.scale = vec3(scale)
				editor.object:make_model_mat()
			end
			local rot = editor.object.rot
			local frot = ffi.new("float[?]",3,rot.x,rot.y,rot.z)
			if MVErot:Draw(frot,nil,nil,0.1) then
				rot.x,rot.y,rot.z = frot[0],frot[1],frot[2]
				editor.object:make_model_mat()
			end
			local pos = editor.object.pos
			local fpos = ffi.new("float[?]",3,pos.x,pos.y,pos.z)
			if MVEpos:Draw(fpos,nil,nil,0.1) then
				pos.x,pos.y,pos.z = fpos[0],fpos[1],fpos[2]
				editor.object:make_model_mat()
			end
		end
		---zmo
		ig.Separator()
		NMzmo:draw()
		if NMzmo.zmoC or NMzmo.zmoO then
			ig.zmoBeginFrame() 
			MVmo = camera:MV().gl
			MPmo = camera:MP().gl
			ig.zmoSetRect(unpack(GL.stencil_sizes))
			if NMzmo.zmoC then
				ig.zmoSetOrthographic(camera.NM.ortho);
				ig.zmoViewManipulate(MVmo,camera.NM.dist or 1,ig.ImVec2(0,0),ig.ImVec2(128,128),0x01010101)
				if NMzmo.grid then ig.zmoDrawGrid(MVmo,MPmo,mat.identity().gl,10) end
				camera:setMV(mat.gl2mat4(MVmo))
			end
			if NMzmo.zmoO and editor.object then
				MOmo = editor.object:getModelM().gl
				local ry = editor.object.rot.y
				--ig.zmoDrawCube(MVmo,MPmo,MOmo)
				ig.zmoManipulate(MVmo,MPmo,zmoOP[0],zmoMODE[0],MOmo,nil,nil,zmoOP[0]==imgui.BOUNDS and editor.object.zmobounds or nil,nil)
				editor.object:setModelM(mat.gl2mat4(MOmo),ry)
			end
		end
	end)
	
	-- local Dbox = GL:DialogBox("Objects")
	-- Dbox:add_dialog(NM)
	-- Dbox:add_dialog(NMzmo)
	-- O.NM = Dbox
	O.NM = NM
	NM.plugin = O
	
	function O:init()
		if not program then
			program = GLSL:new():compile(vert_sh,frag_sh)
			progmesh = GLSL:new():compile(vertmesh,fragmesh)
			
			--initial object
			local tproc = require"anima.plugins.texture_processor"(GL,0)
			tproc:set_process[[
				#define M_PI 3.1415926535897932384626433832795
				vec4 process(vec2 pos){
					float angle = M_PI*0.3*2;
					float freq = 100;
					vec2 dir = vec2(cos(angle),sin(angle));
					float dis = dot(dir,pos);
					return vec4(vec3(sin(dis*2*M_PI*freq)*0.5+0.5),1);
				}]]
			local fbo = GL:initFBO({no_depth=true},300,300)
			fbo:Bind()
			ut.Clear()
			tproc:process{}
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
		O.root = Object("root")
		if args.doinit then self.root:setMesh(inimesh,initex) end
	end
	
	function O:clear()
		self.root:clear_childs()
		self.root.ModelM = mat.identity()
	end
	
	function O:find_node(name)
		return O.root:find_child(name)
	end
	
	function O:draw()
		
		if not NM.dodraw then return end

		if NM.cull then 
			gl.glEnable(glc.GL_CULL_FACE) 
		else
			gl.glDisable(glc.GL_CULL_FACE)
		end
		gl.glEnable(glc.GL_DEPTH_TEST)

		if NM.showtex then
			local obj = editor.object or O.root
			obj.tex:drawcenter()
		else
			gl.glViewport(0,0,GL.W,GL.H)
			if NM.points then
				progmesh:use()
				local U = progmesh.unif
				U.MVP:set(camera:MVP().gl)
				U.color:set{1,0,0}
				gl.glPointSize(5)
				O.root:drawpoints(U)
				gl.glPointSize(1)
			end
			if NM.mesh then
				progmesh:use()
				local U = progmesh.unif
				U.MVP:set(camera:MVP().gl)
				O.root:drawmesh(U)
			else
				gl.glEnable(glc.GL_BLEND)
				gl.glBlendFunc(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA)
				glext.glBlendEquation(glc.GL_FUNC_ADD)
				
				program:use()
				local U = program.unif
				U.MVP:set(camera:MVP().gl)
				
				U.tex:set{0}
				
				O.root:draw(program.unif, NM)
				gl.glDisable(glc.GL_BLEND)

			end
		end
	end
	
	function O:save()
		local pars = {}
		pars.dial = NM:GetValues()
		return pars
	end
	
	function O:load(params)
		O:clear()
		if not params then return end
		NM:SetValues(params.dial or {})
	end
	
	GL:add_plugin(O,"Objects")
	return O
end

--[=[ test
local function make_cyl(pos, scl)
	scl = scl or 1
	local par_shapes = require"anima.par_shapes"
	local pmesh = par_shapes.create.cylinder(32,32)
	local inimesh = mesh.par_shapes2mesh(pmesh)
	local cent = inimesh:calc_centroid()
	inimesh:M4(mat.translate(pos)*mat.translate(-cent)*mat.scale(scl))
	return inimesh
end


local GL = GLcanvas{H=800,aspect=1,use_log=true}

local camera = Camera(GL,"tps")
local objects
function GL:init()
	--local tex = GL:Texture():Load[[../5847tnmtpe.tif]]
	objects = Objects(GL,camera)--,{doinit=true})
	--objects:init()
	local child,ich = objects.root:add_child()
	child:setMesh(make_cyl(vec3(-1,0,0)),tex)
	local child, ich = objects.root:add_child()
	child:setMesh(make_cyl(vec3(1,0,0)),tex)
	child = child:add_child()
	child:setMesh(make_cyl(vec3(1.5,0,0.5),0.5),tex)
end
function GL.draw(t,w,h)
	ut.Clear()
	objects:draw()
end
GL:start()
--]=]

return Objects