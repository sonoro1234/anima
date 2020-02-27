require"anima"

local function mixer(GL,numtex,codestr)
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}
	
	local toggles = {}
	for i=1,numtex do
		toggles[i] = {"t"..i,true,guitypes.toggle}
	end
	local NM = GL:Dialog("mixer",toggles)
	M.NM = NM
	NM.plugin = M
	local tproc = require"anima.plugins.texture_processor"(GL,numtex,NM)
	
	function M:init()
		local code = [[vec4 process(vec2 pos){
				vec4 color = vec4(0);
				if(t1)
					color += c1;
				]]
		for i=2,numtex do
			--code = code .. "if(t"..i..")\ncolor += c"..i..";\n"
			--local code1 =  "if(t@)\ncolor += c@;\n"
			local code1 =  codestr or "if(t@)\ncolor = color*(1.0-c@)+c@;\n"
			code = code .. string.gsub(code1,"@",tostring(i))
		end
		code = code .. "return color;}"
		tproc:set_process(code)
	end
	function M:process(t)
		return tproc:process(t)
	end
	GL:add_plugin(M,"mixer")
	return M
end

----------------------
--[=[
local GL = GLcanvas{H=700,aspect=1}

local mmm = mixer(GL,3)
local t1,t2,t3

local t3n = [[C:\luaGL\frames_anima\im_test\Cosmos_original.jpg]]
local t1n = [[C:\luaGL\frames_anima\flood_fill\dummy.png]]
local t2n = [[C:\luaGL\frames_anima\flood_fill\labyrinth.png]]
function GL.init()
	t1 = GL:Texture():Load(t1n)
	t2 = GL:Texture():Load(t2n)
	t3 = GL:Texture():Load(t3n)
	GL:DirtyWrap()
end

function GL.draw(t,w,h)
	--ut.Clear()
	mmm:process{t1,t2,t3}
end

GL:start()
--]=]
return mixer