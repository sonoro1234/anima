require"anima"
local GL = GLcanvas{H=900,aspect=1,use_log=true,use_imgui_viewport=false}
local function update(n) end --print("update spline",n) end
local edit = require"anima.modeling.Spline"(GL,update,{region=true})--,doblend=true})
local plugin = require"anima.plugins.plugin"
edit.fb = plugin.serializer(edit)
local DBox = GL:DialogBox("Spline demo",true)
local NMpad
local maskfbo
function GL.init()
	DBox:add_dialog(edit.NM)
	NMpad = DBox:Dialog("padd",{{"pad",0,guitypes.drag,{min=-50,max=150},function() edit.NM.dirty = true end},
	{"square",false,guitypes.toggle,function() edit.NM.dirty = true end},
	{"tol",10,guitypes.val,{min=0.1,max=30},function() edit.NM.dirty = true end},
	{"dontrepair",false,guitypes.toggle,function() edit.NM.dirty = true end},})
	maskfbo = GL:initFBO({no_depth=true})
	GL:DirtyWrap()
end
function GL.imgui()
	--ig.ShowDemoWindow()
	--edit.NM:draw()
	ig.TextUnformatted("edit:"..tostring(edit.NM.dirty))
	ig.TextUnformatted("edit:"..tostring(edit:IsDirty()))
end
function GL.draw()
	-- maskfbo:Bind()
	-- gl.glClearColor(0,0,1,0)
	-- ut.Clear()
	-- maskfbo:UnBind()
	if edit.NM.dirty then
		maskfbo:Bind()
	gl.glClearColor(0,0,1,0)
	ut.Clear()
	maskfbo:UnBind()
	for i=1,1 do --edit:get_numsplines() do
		edit:spline2mask_pad(maskfbo,{1,0,0,0},NMpad.pad, NMpad.square, NMpad.tol, NMpad.dontrepair,i)
	end
	edit.NM.dirty = false
	end
	--ut.Clear()
	maskfbo:tex():drawcenter()
end
GL:start()
