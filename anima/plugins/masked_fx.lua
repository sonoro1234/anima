
require"anima"
local plugin = require"anima.plugins.plugin"

local function Masked_fx(GL,fx)

	local MM = plugin.new{res={GL.W,GL.H}}
	local mask = require"anima.plugins.masks"(GL)
	mask.NM.name = "masked_"..fx.NM.name
	MM.maskpl = mask
	local fbofx,fbomask

	-- local DBox = GL:DialogBox("maskfx",true) --autosaved
	-- DBox:add_dialog(mask.NM)
	-- DBox:add_dialog(fx.NM)
	local DBox = mask.NM
	DBox:add_dialog(fx.NM,10)
	
	MM.NM = DBox
	MM.ps = plugin.serializer(MM)
	
	function MM:init()
		fbofx = GL:initFBO({no_depth=true})
	end

	function MM:process(tex,w,h)
		fx:process_fbo(fbofx,tex)
		mask:process({tex,fbofx:tex()})
	end
	
	function MM:save()
		local pars = {}
		pars.mask = mask:save()
		pars.fx = fx:save()
		return pars
	end
	
	function MM:load(params)
		if not params then return end
		mask:load(params.mask)
		fx:load(params.fx)
	end
	
	GL:add_plugin(MM,"masked_fx")
	return MM
end

if not ... then

---[=[

local GL = GLcanvas{H=600,aspect=3/2,use_log=true}

--GL.use_presets = true
--local fxx = require"anima.plugins.gaussianblur3"(GL)
--local fxx = require"anima.plugins.liquid".make(GL)
--local fxx = require"anima.plugins.photofx".make(GL)
--local fxx = require"anima.plugins.LABfx".make(GL)
local fxx 
--local fxx = require"anima.plugins.local_histogramStarkLab"(GL)

local masked_ed,tex, fbo1
function GL.init()
	--tex = GL:Texture():Load[[c:\luagl\media\estanque3.jpg]]
	tex = GL:Texture():Load[[c:\luagl\media\estanque-001.jpg]]
	GL:set_WH(tex.width, tex.height)
	fxx = require"anima.plugins.LCHfx".make(GL)
	--fxx = require"anima.plugins.gaussianblur3"(GL)
	masked_ed = Masked_fx(GL,fxx)
	GL:DirtyWrap()
end
function GL.imgui()
-- ig.Begin"dirty tests"
	-- ig.TextUnformatted("masked_ed:Is"..tostring(masked_ed:IsDirty()))
	-- ig.TextUnformatted("masked_ed:"..tostring(masked_ed.NM.dirty))
	-- ig.TextUnformatted("fxx:"..tostring(fxx.NM.dirty))
	-- ig.TextUnformatted("maskpl:"..tostring(masked_ed.maskpl:IsDirty()).." dirty:"..tostring(masked_ed.maskpl.NM.dirty))
-- ig.End()
end
function GL.draw(t,w,h)
	masked_ed:process(tex)
end
GL:start()
--]=]
end

return Masked_fx