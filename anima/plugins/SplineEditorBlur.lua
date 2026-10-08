--takes care of feather polygon being simple


local function Editor(GL)
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}

	local  splinefbo, blurfbo
	local blur3 = require"anima.plugins.gaussianblur3"(GL)
	blur3.NM.invisible = true
	local function update() blur3.NM.dirty = true end
	--local spline = require"anima.plugins.Spline"(GL,update,{region=true})
	local spline = require"anima.modeling.Spline"(GL,update,{region=true})
	local FF = require"anima.plugins.flood_fill"(GL)
	FF.NM.remove() --remove from GL.imguimodals
	
	M.FF = FF
	M.blur3 = blur3
	M.spline = spline
	local DBox
	local function set_mask_kind(n)
		if n == 1 then
			DBox.dialogs[2] = spline.NM 
		else -- 2
			DBox.dialogs[2] = FF.NM 
		end
	end
	
	DBox = GL:DialogBox("mask_maker")
	local mNM = DBox:Dialog("mask_feather",
		{
			{"feather",0,guitypes.val,{min=0,max=100}},
			{"mask_kind",1,guitypes.slider_enum,{"spline","flood_fill"},function(n) set_mask_kind(n) end}
		})
	mNM.uncollapsible = true
	mNM.indent = 1
	DBox:add_dialog(spline.NM,10)
	M.NM = DBox
	M.NM.plugin = M
	DBox.dialogs[1].plugin = M
	
	
	function M:init()
		splinefbo = GL:initFBO({no_depth=true})
		blurfbo = GL:initFBO({no_depth=true})
	end

	function M:process(textur,w,h)

		w,h = w or self.res[1],h or self.res[2]
		
		if mNM.mask_kind == 1 then --spline
			if spline.NM.dirty then
				splinefbo:Bind()
				gl.glClearColor(0,0,0,0)
				ut.Clear()
				splinefbo:UnBind()
				for i=1,spline:get_numsplines() do
					spline:spline2mask(splinefbo,{1,0,0,0.5},i)
				end
				spline.NM.dirty = false
			end
		else --2 flood_fill
			FF:process(textur)
			splinefbo:Bind()
			gl.glClearColor(0,0,0,0)
			ut.Clear()

			FF.mask:drawcenter(w,h)
			splinefbo:UnBind()
		end

		blur3.NM.vars.stdevs[0] = 3.5
		--local radio = math.min(39*2,math.max(1,mNM.feather*GL.W))
		local radio = mNM.feather
		blur3.NM.vars.radio[0] = radio
		blur3:update()

		if mNM.feather == 0 then
			splinefbo:tex():drawcenter(w,h)
		else
			blur3:process_fbo(blurfbo,splinefbo:tex(),w,h)
			blurfbo:tex():drawcenter(w,h)
		end

		mNM.dirty = false 
	end
	--M.process = M.draw
	function M:save()
		local pars = {}
		pars.spline = spline:save()
		pars.FF = FF:save()
		pars.dial = mNM:GetValues()
		return pars
	end
	function M:load(params)
		if not params then return end
		mNM:SetValues(params.dial or {})
		set_mask_kind(mNM.mask_kind)
		spline:load(params.spline)
		FF:load(params.FF)
	end
	GL:add_plugin(M,"maskblur")
	return M
end

if not ... then
---[=[
require"anima"
local GL = GLcanvas{H=800,aspect=3/2, use_log=true}
local edit

--GL.use_presets = true
fileName = [[C:\luaGL\frames_anima\im_test\Cosmos_original.jpg]]
--fileName = path.this_script_path()..[[\imagenes\unnamed0.jpg]]
--fileName=[[C:\luagl\animacion\resonator6\resonator-038.jpg]]
--fileName = [[C:\LuaGL\frames_anima\flood_fill\dummy.png]]
fileName = [[C:\LuaGL\frames_anima\edges_detection\flowers2.png]]
fileName = [[c:\luagl\media\estanque-001.jpg]]
local fbo,texture
function GL.init()
	texture = GL:Texture():Load(fileName)
	GL:set_WH(texture.width,texture.height)
	
	edit = Editor(GL)
	local plugin = require"anima.plugins.plugin"
	edit.fb = plugin.serializer(edit)
	
	
	fbo = GL:initFBO{no_depth=true} --only needed if DirtyWrap
	GL:DirtyWrap()
end
function GL.imgui()
ig.Begin"dirty tests"
	ig.TextUnformatted("edit IsDirty:"..tostring(edit:IsDirty()))
	ig.TextUnformatted("edit:"..tostring(edit.NM.dirty))
	ig.TextUnformatted("blur3:"..tostring(edit.blur3.NM.dirty))
	ig.TextUnformatted("spline:"..tostring(edit.spline.NM.dirty))
ig.End()
end
function GL.draw(t,w,h)
	--gl.glClearColor(0,0,0,0)
	--ut.Clear()
	fbo:Bind()
	edit:process(texture,w,h)
	fbo:UnBind()
	
	--gl.glClearColor(0,0,0,0)
	ut.Clear()
	texture:drawcenter()
	fbo:tex():draw_blend()
		--ut.ClearDepth()
	--edit.FF.mask:drawcenter()
	-- ut.Clear()
	-- fbo:tex():drawcenter(w,h)
end
function GL.drawNO(t,w,h)
	gl.glClearColor(0,0,0,0)
	ut.Clear()
	--FF:process_fbo(fbo,texture)
	--fbo:tex():drawcenter()
	edit.FF:process(texture)
	--texture:drawcenter()
	--FF:show_mask()
	ut.ClearDepth()
	edit.FF.mask:drawcenter()
	-- mixer.NM.dirty = true
	-- ut.Clear()
	-- mixer:process{texture,FF.tex2}

end
GL:start()
--]=]
end

return Editor