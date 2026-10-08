--takes care of feather polygon being simple


local function Editor(GL)
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}

	local  maskfbo, blurfbo
	local tproc
	local blur3 = require"anima.plugins.gaussianblur3"(GL)
	blur3.NM.invisible = true
	local function update() blur3.NM.dirty = true end
	--local spline = require"anima.plugins.Spline"(GL,update,{region=true})
	local spline = require"anima.modeling.Spline"(GL,update,{region=true})
	local FF = require"anima.plugins.flood_fill"(GL)
	FF.NM.remove() --remove from GL.imguimodals
		local NMproc = GL:Dialog("proc",
	{{"showmask",false,guitypes.toggle},
	{"invert",false,guitypes.toggle,nil,{sameline=true}},
	{"minmask",0,guitypes.val,{min=0,max=1}},
	{"maxmask",1,guitypes.val,{min=0,max=1}},
	},function() ig.Separator() end)
	local tproc = require"anima.plugins.texture_processor"(GL,3,NMproc)
	
	M.FF = FF
	M.blur3 = blur3
	M.spline = spline
	M.tproc = tproc

	
	local DBox
	local function set_mask_kind(n)
		if n == 1 then
			DBox.dialogs[3] = spline.NM 
		else -- 2
			DBox.dialogs[3] = FF.NM 
		end
		DBox.dialogs[3].dirty = true
		NMproc.dirty = true
		blur3.NM.dirty = true
	end
	
	DBox = GL:DialogBox("masks")
	NMproc.uncollapsible = true
	DBox:add_dialog(NMproc,1)
	local mNM = DBox:Dialog("mask_feather",
		{
			{"feather",0,guitypes.val,{min=0,max=100}},
			{"mask_kind",1,guitypes.slider_enum,{"spline","flood_fill"},function(n) set_mask_kind(n) end}
		})
	mNM.uncollapsible = true
	mNM.indent = 1
	FF.NM.indent = 10
	DBox:add_dialog(spline.NM,10)

	M.NM = DBox
	M.NM.plugin = M
	DBox.dialogs[1].plugin = M
	DBox.dialogs[2].plugin = M
	
	--M.ps = plugin.serializer(M)
	function M:Set_WH()
		maskfbo = GL:initFBO({no_depth=true})
		blurfbo = GL:initFBO({no_depth=true})
	end
	function M:init()
		maskfbo = GL:initFBO({no_depth=true})
		blurfbo = GL:initFBO({no_depth=true})
		
		tproc:set_process[[vec4 process(vec2 pos){
		
			if (invert){
				c3.r = 1.0 - c3.r;
				c3.a = 1.0 - c3.a;
			}
			c3.r = min(max(c3.r,minmask),maxmask);
			if (showmask)
				return c3 + c1*(1.0-c3.r);
			else
				return mix(c1,c2,c3.r);
		}
		]]
	end

	function M:process(texts,w,h)
		--print("masks:process")
		local textur = texts[1]
		local texturfx = texts[2]
		w,h = w or self.res[1],h or self.res[2]
		
		if mNM.mask_kind == 1 then --spline
			--if spline.NM.dirty then
				maskfbo:Bind()
				gl.glClearColor(0,0,0,0)
				ut.Clear()
				maskfbo:UnBind()
				for i=1,spline:get_numsplines() do
					spline:spline2mask(maskfbo,{1,0,0,0.5},i)
				end
				maskfbo:tex():inc_signature()
				spline.NM.dirty = false
			--end
		else --2 flood_fill
			FF:process(textur)
			maskfbo:Bind()
			gl.glClearColor(0,0,0,0)
			ut.Clear()

			FF.mask:drawcenter(w,h)
			maskfbo:UnBind()
			maskfbo:tex():inc_signature()
		end

		blur3.NM.vars.stdevs[0] = 3.5
		--local radio = math.min(39*2,math.max(1,mNM.feather*GL.W))
		local radio = mNM.feather
		blur3.NM.vars.radio[0] = radio
		blur3:update()
--[[
		if mNM.feather == 0 then
			blurfbo:Bind()
			maskfbo:tex():drawcenter(w,h)
			blurfbo:UnBind()
			blur3.NM.dirty = false
		else
			blur3:process_fbo(blurfbo,maskfbo:tex(),w,h)
			--blurfbo:tex():drawcenter(w,h)
		end
--]]
		if mNM.feather == 0 then
			blur3.NM.vars.bypass[0] = true
		else
			blur3.NM.vars.bypass[0] = false
		end
		blur3:process_fbo(blurfbo,maskfbo:tex(),w,h)
		tproc:process({textur,texturfx,blurfbo:tex()})
		
		DBox.dirty = false
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
local fbo,texture,fxx
function GL.init()
	texture = GL:Texture():Load(fileName)
	GL:set_WH(texture.width,texture.height)
	fxx = require"anima.plugins.LCHfx".make(GL)
	edit = Editor(GL)
	--local plugin = require"anima.plugins.plugin"
	--edit.fb = plugin.serializer(edit)
	
	
	fbo = GL:initFBO{no_depth=true} --only needed if DirtyWrap
	GL:DirtyWrap()
end
function GL.imgui()
ig.Begin"dirty tests"
	ig.TextUnformatted("edit IsDirty:"..tostring(edit:IsDirty()))
	ig.TextUnformatted("edit:"..tostring(edit.NM.dirty))
	ig.TextUnformatted("tproc:"..tostring(edit.tproc.NM.dirty))
	ig.TextUnformatted("blur3:"..tostring(edit.blur3.NM.dirty))
	ig.TextUnformatted("spline:"..tostring(edit.spline.NM.dirty))
	ig.TextUnformatted("FF:"..tostring(edit.FF.NM.dirty))
	ig.TextUnformatted("fxx:"..tostring(fxx.NM.dirty))
ig.End()
end
function GL.draw(t,w,h)
	--gl.glClearColor(0,0,0,0)
	--ut.Clear()

	fxx:process_fbo(fbo,texture,w,h)
	edit:process({texture,fbo:tex()})
	

end

GL:start()
--]=]
end

return Editor