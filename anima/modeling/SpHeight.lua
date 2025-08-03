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

--[=[
local GL = GLcanvas{H=800,aspect=1,DEBUG=true,use_imgui_viewport=false}
local function update(n) end --print("update spline",n) end
local camera = Camera(GL, "tps")
local edit = Editor(GL,camera,update,{region=true})--,doblend=true})
local plugin = require"anima.plugins.plugin"
edit.fb = plugin.serializer(edit)
local DBox = GL:DialogBox("Spline demo",true)
function GL.init()
	DBox:add_dialog(edit.NM)
end
function GL.imgui()
	--ig.ShowDemoWindow()
	--edit.NM:draw()
end
GL:start()
--]=]

return Editor