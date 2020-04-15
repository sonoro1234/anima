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
local function Object(GL,camera,args)
	args = args or {}
	
	local O = {}
	O.frame = {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=vec3(0,0,0)}
	
	local NM = GL:Dialog("object",{
		{"mat2",false,gui.types.toggle,function(val,this) O:switchmat(val) end},

		{"scale",{1,1,1},guitypes.drag,{min=0.01,max=4},function() O:make_model_mat() end},
		{"rot",{0,0,0},guitypes.drag,{},function() O:make_model_mat() end},
		{"pos",{0,0,0},guitypes.drag,{},function() O:make_model_mat() end},
		{"dodraw",true,guitypes.toggle},
		{"showtex",false,guitypes.toggle,nil,{sameline=true}},
		{"mesh",false,guitypes.toggle,nil,{sameline=true}},
		{"cull",false,guitypes.toggle},
		{"mipmaps",false,guitypes.toggle,nil,{sameline=true}},
		{"aniso",false,guitypes.toggle,nil,{sameline=true}},
	})
	
	O.NM = NM
	
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
					return vec4(sin(dis*2*M_PI*freq)*0.5+0.5);
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
			self.MF = mat.identity4
			self.MFinv = mat.identity4
		end

		if args.doinit then self:setMesh(inimesh,initex) end
	end
	
	local vao,vaomesh,vaoframe,ModelM
	function O:make_mat2()
		local camframe = camera:frame()
		
		local M = mat.rotABCD(self.frame.Y, camframe.Y, self.frame.X , camframe.X).mat4 
	
		--get position
		local mbounds = {M*self.bounds[1],M*self.bounds[2]}
		--prtable(self.bounds,self.bounds[2]-self.bounds[1],(self.bounds[2]-self.bounds[1]).norm)
		--prtable(mbounds,mbounds[2]-mbounds[1],(mbounds[2]-mbounds[1]).norm)
		--local height = mbounds[2].y*2 -- - self.frame.center.y) --self.bounds[1].y
		local height = math.abs(mbounds[2].y - mbounds[1].y)
		--print("height",height)
		--local height = (self.bounds[2].y - self.bounds[1].y)
		local dist = camera:GetZforHeight(height)
		local newcenter = camframe.center - camframe.Z * dist
		M = mat.translate(newcenter) * M
		
		return M
	end
	local oldmat
	function O:switchmat(mat2)
		if mat2 then
			oldmat = ModelM
			ModelM = self:make_mat2()
		else
			ModelM = oldmat
		end
	end
	
	function O:make_model_mat()
		
		local M = 1
		
		M = mat.scale(NM.scale[0],NM.scale[1],NM.scale[2]) * M


		-- M = mat.rotate4y(NM.rot[1]) * M
		-- M = mat.rotate4x(NM.rot[0]) * M
		-- M = mat.rotate4z(NM.rot[2]) * M
		
		--M = R.ZXYE(NM.rot[2],NM.rot[0],NM.rot[1]).mat4 * M
		M = R.ZYXE(NM.rot[2],NM.rot[1],NM.rot[0]).mat4 * M
		
		M = mat.translate(NM.pos[0],NM.pos[1],NM.pos[2]) * M
		--M = mat.translate(-self.frame.center)*M
		
		ModelM =  self.MFinv * M * self.MF 
	end
	function O:getModelM()
		return  ModelM * self.MFinv
	end
	function O:setModelM(MM)
		
		ModelM = MM * self.MF
		--local M = self.MF * ModelM *self.MFinv
		--or equivalent
		local M = self.MF * MM
		
		NM.vars.pos:set{M.m41,M.m42,M.m43}
		
		local scale = {}
		-- scale[1] = vec3(M.m11, M.m21, M.m31).norm
		-- scale[2] = vec3(M.m12, M.m22, M.m32).norm
		-- scale[3] = vec3(M.m13, M.m23, M.m33).norm
		scale[1] = vec3(M.m11, M.m12, M.m13).norm
		scale[2] = vec3(M.m21, M.m22, M.m23).norm
		scale[3] = vec3(M.m31, M.m32, M.m33).norm
		NM.vars.scale:set(scale)
		
		M = M*mat.scale(1/scale[1],1/scale[2],1/scale[3])
		
		--local z,x,y = R.ZXYE2angles(M.mat3)
		local z,y,x = R.ZYXE2angles(M.mat3)
		NM.vars.rot:set{x,y,z}
		
	end
	function O:setMesh(mesh,tex,frame)
		O.bounds = {mesh:bounds()}
		O.mesh = mesh
		O.tex = tex or O.tex or initex
		O.tex:Bind()
		O.tex:gen_mipmap()
		O.frame = frame or {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=mesh:calc_centroid()}
		

		local MF = mat.translate(-self.frame.center)
		MF = mat.rotABCD(self.frame.Y, vec3(0,1,0), self.frame.X , vec3(1,0,0)).mat4 * MF

		O.MF = MF
		O.MFinv = MF.inv
		
		self:make_model_mat()
		vao = mesh:vao(program)
		vaomesh = mesh:vao(progmesh)
		
		-- vaoframe
		local dims = self.bounds[2] - self.bounds[1]
		local maxdim = math.max(dims.x, math.max(dims.y, dims.z))
		
		local fc = self.frame.center
		local fx = fc + self.frame.X * maxdim
		local fy = fc + self.frame.Y * maxdim
		local fz = fc + self.frame.Z * maxdim
		
		vaoframe = VAO({position=mat.vec2vao{fc,fx,fc,fy,fc,fz}},progmesh)
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
			self.tex:drawcenter()
		else
			if vao then
				gl.glViewport(0,0,GL.W,GL.H)
				if NM.mesh then
					progmesh:use()
					local U = progmesh.unif
					U.MVP:set(camera:MVP().gl)
					U.ModelM:set(ModelM.gl)
					U.color:set{1,1,1}
					vaomesh:draw_mesh()
					U.color:set{1,0,0}
					vaoframe:draw(glc.GL_LINES,2,0)
					U.color:set{0,1,0}
					vaoframe:draw(glc.GL_LINES,2,2)
					U.color:set{0,0,1}
					vaoframe:draw(glc.GL_LINES,2,4)
					gl.glPointSize(5)
					U.color:set{1,1,0}
					vaoframe:draw(glc.GL_POINTS,1,0)
					gl.glPointSize(1)
				else
					program:use()
					program.unif.MVP:set(camera:MVP().gl)
					program.unif.ModelM:set(ModelM.gl)
					program.unif.tex:set{0}
					self.tex:Bind()
					if NM.aniso then
						self.tex:set_aniso()
					else
						self.tex:set_aniso(1)
					end
					if NM.mipmaps then
						self.tex:min_filter(glc.GL_LINEAR_MIPMAP_LINEAR)
					else
						self.tex:min_filter(glc.GL_LINEAR)
					end
					vao:draw_elm()
				end
			end
		end
	end
	
	GL:add_plugin(O,"Object3D")
	return O
end

--[[
local GL = GLcanvas{H=800,aspect=1}
require"anima.camera2"
local camera = newCamera(GL,"tps")
local object1,object2
function GL:init()
	object1 = Object(GL,camera)
	object1.NM.vars.pos:set{-1,0,-4}
	object1:make_model_mat()
	object2 = Object(GL,camera)
	object2.NM.vars.pos:set{1,1,-4}
	object2:make_model_mat()
end
function GL.draw(t,w,h)
	ut.Clear()
	object1:draw()
	object2:draw()
end
GL:start()
--]]

return Object