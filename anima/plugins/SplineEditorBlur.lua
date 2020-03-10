--takes care of feather polygon being simple


local function Editor(GL)
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}

	local  blurfbo
	local blur3 = require"anima.plugins.gaussianblur3"(GL)
	blur3.NM.invisible = true
	local function update() blur3.NM.dirty = true end
	local spline = require"anima.plugins.Spline"(GL,update,{region=true})
	
	local DBox = GL:DialogBox("blurmask")
	DBox:add_dialog(spline.NM)
	DBox:Dialog("maskblur",
		{{"feather",0,guitypes.val,{min=0,max=0.1}}})
	
	M.NM = DBox
	M.NM.plugin = M
	DBox.dialogs[2].plugin = M
	
	function M:init()
		blurfbo = GL:initFBO({no_depth=true})
	end

	function M:draw(_,w,h)

		w,h = w or self.res[1],h or self.res[2]

		blurfbo:Bind()
		ut.Clear()
		spline:draw()
		blurfbo:UnBind()


		blur3.NM.vars.stdevs[0] = 3.5
		blur3.NM.vars.radio[0] = math.min(39*2,math.max(1,DBox.dialogs[2].feather*GL.W))
		blur3:update()

		if DBox.dialogs[2].feather == 0 then
			blurfbo:tex():drawcenter(w,h)
		else
			blur3:process(blurfbo:tex(),w,h)
		end

		--DBox.dialogs[2].dirty = false 
	end
	function M:save()
		local pars = {}
		pars.spline = spline:save()
		pars.dial = NM:GetValues()
		return pars
	end
	function M:load(params)
		if not params then return end
		NM:SetValues(params.dial or {})
		spline:load(params.spline)
	end
	GL:add_plugin(M,"maskblur")
	return M
end

--[=[
require"anima"
local GL = GLcanvas{H=800,aspect=3/2}
local edit = Editor(GL)
local plugin = require"anima.plugins.plugin"
edit.fb = plugin.serializer(edit)
--GL.use_presets = true
local fbo
function GL.init()
	fbo = GL:initFBO{no_depth=true} --only needed if DirtyWrap
	GL:DirtyWrap()
end
function GL.draw(t,w,h)
	ut.Clear()
	fbo:Bind()

	edit:draw(_,w,h)
	fbo:UnBind()
	fbo:tex():drawcenter()
end
GL:start()
--]=]

--[=[
require"anima"
local GL = GLcanvas{H=800,aspect=3/2}
--local camara = newCamera(GL,"fps")--"ident")
local edit = Editor(GL)--,camara)
local plugin = require"anima.plugins.plugin"
edit.ps = plugin.serializer(edit)
--GL.use_presets = true
--local blur = require"anima.plugins.gaussianblur3"(GL)
--local blur = require"anima.plugins.liquid".make(GL)
--local blur = require"anima.plugins.photofx".make(GL)
local blur = require"anima.plugins.LCHfx".make(GL)
local fboblur,fbomask,tex
local tproc
local NM = GL:Dialog("proc",
{{"showmask",true,guitypes.toggle},
{"invert",false,guitypes.toggle},
{"minmask",0,guitypes.val,{min=0,max=1}},
{"maxmask",1,guitypes.val,{min=0,max=1}},
})

local DBox = GL:DialogBox("photomask")
DBox:add_dialog(edit.NM)
DBox:add_dialog(blur.NM)
DBox:add_dialog(NM)

local fboproc
function GL.init()
	fboblur = GL:initFBO({no_depth=true})
	fbomask = GL:initFBO({no_depth=true})
	fboproc = GL:initFBO({no_depth=true}) --only needed if DirtyWrap
	tex = GL:Texture():Load[[c:\luagl\media\estanque3.jpg]]
	tproc = require"anima.plugins.texture_processor"(GL,3,NM)
	tproc:set_textures{tex,fboblur:GetTexture(),fbomask:GetTexture()}
	tproc:set_process[[vec4 process(vec2 pos){
	
		if (invert)
			c3 = vec4(1) - c3;
		c3 = min(max(c3,vec4(minmask)),vec4(maxmask));
		if (showmask)
			return c3 + c1*(vec4(1)-c3);
		else
			return mix(c1,c2,c3.r);
	}
	]]
	GL:DirtyWrap()
end

function GL.draw(t,w,h)

	blur:process_fbo(fboblur,tex,w,h)
	
	fbomask:Bind()
	--ut.Clear()
	edit:draw(t,w,h)
	-- edit:process_fbo(fbomask) --draw(t,w,h)
	fbomask:UnBind()
	fbomask:tex():inc_signature()
	--edit.NM.dirty = false

	fboproc:Bind() --only needed if DirtyWrap is used
	--ut.Clear()
	tproc:process({tex,fboblur:GetTexture(),fbomask:GetTexture()})
	fboproc:UnBind()
	fboproc:tex():drawcenter()
end
GL:start()
--]=]
return Editor