require"anima"


local GL = GLcanvas{W=800,aspect=1,vsync=1,use_log=true,profile="CORE"}--DEBUG=true}
GL.use_presets = true
local NM 

local camera = Camera(GL,"tps")
camera.NM.vars.dist[0] = 1.5
local edit
local tex
local objects
local filters = {glc.GL_NEAREST,glc.GL_LINEAR}

local function makeObj(sp,MVinv,iplane)
	local i,maker = sp[1],sp[2]
	local objname = "obj_"..maker.."_"..i
	print("makeObj",maker,i)
	
	local meshE,frame = edit.Makers[maker]:get_mesh(i)
	if not meshE then return end
	
	local meshW = meshE:clone()
	meshW:M4(MVinv)
	
	local gtex
	if NM.gentex then 
		gtex = MI:MeshRectify(meshE,true,filters[NM.filter]) 
	end

	local frame = mesh.move_frame(frame,MVinv)
	
	local child = objects:find_node(objname) or objects.root:add_child(objname)
	child:setMesh(meshW, gtex, frame)
end

local function make_mesh()
	print"----------------------------set_objects"

	local MVinv = camera:MV().inv
	
	local frame = mesh.move_frame({X=mat.vec3(1,0,0),Y=mat.vec3(0,1,0),Z=mat.vec3(0,0,1),center=edit.centroid},MVinv)
	objects.root:set_frame(frame)
	
	for iplane,qm in ipairs(edit.quad_meshes) do
		for i,sp in ipairs(qm) do
			makeObj(sp,MVinv,iplane)
		end
	end
end



NM = GL:Dialog("test",{
{"make_mesh",0,gui.types.button,function() make_mesh() end},
{"draw_image",false,gui.types.toggle},
{"gentex",false,gui.types.toggle},
{"filter",1,guitypes.slider_enum,{"nearest","linear","none"}}
})


edit = require"anima.modeling.rhomboidsM"(GL,camera,make_mesh)


function GL.init()
	tex = GL:Texture():Load[[casa.png]]
	GL:set_WH(tex.width, tex.height)
	MI = require"anima.modeling.mesh_image"(GL,camera,tex,1)
	objects = require"anima.modeling.Objects"(GL,camera)
	GL:preset_load("casa.preset")
end
function GL.draw(t,w,h)
	ut.Clear()
	if NM.draw_image then
		tex:drawcenter()
		ut.ClearDepth()
	end
	edit:draw(t,w,h)
	objects:draw()
end
GL:start()