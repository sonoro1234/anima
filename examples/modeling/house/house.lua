require"anima"


local GL = GLcanvas{W=800,viewH=600,aspect=1,vsync=1,profile="CORE"}--DEBUG=true}
GL.use_presets = true
local NM 

local camera = Camera(GL,"tps")
camera.NM.vars.dist[0] = 1.5
local edit
local tex
local object
local filters = {glc.GL_NEAREST,glc.GL_LINEAR}
local function make_mesh(...)
		local vec2 = mat.vec2
		local SP3D = edit.Makers[2]
		print("makemesh",#SP3D.ps,"splines",...)
		if #SP3D.ps == 0 then return end
		
		--print(debug.traceback())
		--put all spline points in common structure
		local points = {}
		local epoints = {}
		local indexes = {}
		for i=1,#SP3D.ps do
			for j,p in ipairs(SP3D.ps[i]) do
				points[#points+1] = p
				epoints[#points] = SP3D.ps_eye[i][j]
			end
		end
		if #points==0 then return end
		local offsetind = 0
		for i=1,#SP3D.indexes do
			for j,ind in ipairs(SP3D.indexes[i]) do
				indexes[#indexes+1] = ind + offsetind
			end
			offsetind = offsetind + #SP3D.ps[i]
		end
		--get tcoords
		--first bounding box of screen points
		local minx,maxx,miny,maxy = math.huge,-math.huge,math.huge,-math.huge
		for i,p in ipairs(points) do
			minx = p.x < minx and p.x or minx
			maxx = p.x > maxx and p.x or maxx
			miny = p.y < miny and p.y or miny
			maxy = p.y > maxy and p.y or maxy
		end
		local width = maxx - minx
		local height = maxy - miny
		--the map to 0,1
		local tcoords = {}
		for i,p in ipairs(points) do
			local newx = (p.x - minx)/width
			local newy = (p.y - miny)/height
			tcoords[i] = vec2(newx,newy)
		end
		
		local meshE = mesh.mesh({points=epoints, triangles=indexes, tcoords=tcoords})

		local MVinv = camera:MV().inv
		local meshW = meshE:clone()
		meshW:M4(MVinv)
		meshW:calc_centroid()
		
		local frameO = edit.planes[1].frame
		local frame = mesh.move_frame(frameO,MVinv)
		
		MI.clamp_to_border = false
		
		if NM.gentex then 
			local init_r = secs_now()
			MI:MeshRectify(meshE,nil,filters[NM.filter]) 
			print("mesh rectify in ",secs_now()-init_r)
		end
		object:setMesh(meshW,MI.texR,frame)
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
	MI = require"anima.modeling.mesh_image"(GL,camera,tex,2)
	object = require"anima.Object3D"(GL,camera)
	GL:preset_load("casa.preset")
end
function GL.draw(t,w,h)
	ut.Clear()
	if NM.draw_image then
		tex:drawcenter()
		ut.ClearDepth()
	end
	edit:draw(t,w,h)
	object:draw()
end
GL:start()