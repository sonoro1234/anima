-- ported from https://github.com/BrutPitt/imGuIZMO.quat qJset example
require"anima"

local GL = GLcanvas{H=600,aspect=1,profile="CORE"}

local Ldir =  {3,3,3}
local Quat = ffi.new("quat",{0,0,0,1})
local matOrientation = mat.identity3()
local position = ffi.new("G3Dvec3")

local NM = GL:Dialog("juliaS",{
{"quatPt",{-0.65, 0.4, 0.25, 0.05},guitypes.drag,{min=-1,max=1}},
{"epsilon",1,guitypes.val,{min=0.001,max=1,format="%0.6f",power=5}},
{"specularExponent",15,guitypes.drag,{min=1,max=250,precission=1}},
{"specularComponent",0.5,guitypes.drag,{min=0,max=1}},
{"normalComponent",0.25,guitypes.drag,{min=0,max=1}},
{"phongMethod",1,guitypes.drag,{min=0,max=1}},
{"diffuseColor",{0.3,0.9,0.65},guitypes.color},
{"isFullRender",false,guitypes.toggle},
{"useShadow",true,guitypes.toggle},
{"useAO",true,guitypes.toggle},
},function() 
	local vL = ffi.new("G3Dvec3",{-Ldir[1],-Ldir[2],-Ldir[3]})
	if ig.gizmo3D("###guizmoL",vL,150,imgui.modeDirection) then
		Ldir = {-vL.x,-vL.y,-vL.z}
	end
	if ig.gizmo3D("###guizmo0",position,Quat,150,imgui.mode3Axes + imgui.cubeAtOrigin) then
		local m4f = ig.mat4_cast(Quat)
		local m4 = mat.gl2mat4(m4f.f)
		matOrientation = m4.mat3.t
	end
end)

local file,err  = io.open([[Shaders/qjVert.glsl]])
assert(file,err)
local vertsh = file:read"*a"
file:close()

local file,err  = io.open([[Shaders/qjFragES2.glsl]])
assert(file,err)
local fragsh = file:read"*a"
file:close()

local prog, vao
function GL:init()
	GLSL.default_version = "#version 330\n"
	prog = GLSL:new():compile(vertsh, fragsh)
	vao = VAO({vPos={-1.0,-1.0,1.0,-1.0,1.0, 1.0,-1.0, 1.0 }},prog)
end

function GL.draw(t,w,h)
	ut.Clear()
	prog:use()
	local U = prog.unif
	U.quatPt:set(NM.quatPt)
	U.diffuseColor:set(NM.diffuseColor)
	U.Light:set(Ldir)
	U.phongMethod:set{NM.phongMethod}
	U.specularExponent:set{NM.specularExponent}
	U.specularComponent:set{NM.specularComponent}
	U.normalComponent:set{NM.normalComponent}
	U.epsilon:set{NM.epsilon/1000}
	U.isFullRender:set{NM.isFullRender}
	U.useShadow:set{NM.useShadow}
	U.useAO:set{NM.useAO}
	U.matOrientation:set(matOrientation.gl)
	U.position:set{-position.x,-position.y,-position.z}
	U.resolution:set{w,h,w/h}
	gl.glViewport(0,0,w,h)
	vao:draw(glc.GL_TRIANGLE_FAN)

end

GL:start()
