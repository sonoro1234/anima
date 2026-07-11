require"anima"

local function Editor(GL,camera,updatefunc)
	updatefunc = updatefunc or function() end
	local M = {}
	local vec3 = mat.vec3
	
	local function updateheight()
		M.mesh = M.HE.mesh
		updatefunc()
	end
	
	M.HE = require"anima.modeling.HeightEditor"(GL,updateheight)
	M.HE.NM.vars.zplane[0] = -1
	
	local function updatesp()
		local ps = {}
		local MPinv = camera:MP().inv
		for i,pt in ipairs(M.SE.ps[1]) do
			ps[i] = camera:Viewport2Eye(pt,MPinv)
		end
		M.HE:set_spline(ps)
	end
	
	M.SE = require"anima.modeling.Spline"(GL,updatesp)
	
	local Dbox = gui.DialogBox("SpHeight",true) --autosaved
	Dbox:add_dialog(M.SE.NM)
	Dbox:add_dialog(M.HE.NM)
	Dbox.plugin = M
	
	M.NM = Dbox
	
	function M:save()
		local pars = {}
		pars.SE = M.SE:save()
		pars.HE = M.HE:save()
		return pars
	end
	function M:load(params)
		if not params then return end
		M.HE:load(params.HE)
		M.SE:load(params.SE)
	end

	return M
end

if not ... then
---[=[
local GL = GLcanvas{H=800,aspect=1,DEBUG=true,use_imgui_viewport=false}
local object, edit, camera
local function make_mesh()
		print"makemesh"
		---[[
		local vec3 = mat.vec3
		local vec2 = mat.vec2
		local meshE = edit.mesh or mesh.mesh{triangles={0,2,1}, points={vec3(-1,-1,0), vec3(0,1,0), vec3(1,-1,0)}, tcoords={vec2(0,0.5),vec2(0.5,1),vec2(1,1)}}
		--]]
		local meshW = meshE:clone()
		meshW:M4(camera:MV().inv)
		meshW:calc_centroid()
		local minb,maxb = meshW:bounds()
		local center = vec3(meshW.centroid.x,meshW.centroid.y,minb.z)

		--if NM.gentex then MI:MeshRectify(meshE,nil,glc.GL_NEAREST) end
		local frame = {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=center}
		object:setMesh(meshW,nil, frame)
	end
--local function update(n) print("update spline",n) end
camera = Camera(GL, "tps")
edit = Editor(GL,camera,make_mesh)--,{region=true})--,doblend=true})
local plugin = require"anima.plugins.plugin"
edit.SE.fb = plugin.serializer(edit.SE)
local DBox = GL:DialogBox("Spline demo",true)
function GL.init()
	object = require"anima.Object3D"(GL,camera)
	DBox:add_dialog(edit.NM)
end
function GL.imgui()
	--ig.ShowDemoWindow()
	--edit.NM:draw()
end
function GL:draw()
	ut.Clear()
	object:draw()
end
GL:start()
--]=]
end

return Editor