--white point control
--malo usar Labfx or LabfxW2

----------------------------------------

local vert_shad = [[
in vec3 Position;
in vec2 texcoords;
void main()
{
	gl_TexCoord[0] = vec4(texcoords,0,1);
	gl_Position = vec4(Position,1);
}
]]

local frag_shad = require"anima.GLSL.GLSL_color"..[[
uniform sampler2D tex0;
uniform sampler1D LUTx;
uniform sampler1D LUTy;
uniform sampler1D LUTz;
uniform vec2 whitepoint;
uniform bool usealpha;
uniform bool invert;
uniform bool bypass;

float lutSize = textureSize(LUTx,0);
float scale = (lutSize - 1.0) / lutSize;
float offset = 1.0 / (2.0 * lutSize);

const vec3 labscale = vec3(1.0/100.0,1.0/115.0,1.0/115.0);
//a* is -79 to 94, and the range of b* is -112 to 93
const vec3 laboffset = vec3(0.0,0.5,0.5);
void main()
{
	vec4 tcolor = texture2D(tex0,gl_TexCoord[0].st);
	
	if (bypass){
		if(usealpha)
			tcolor.a = 1.0;
		gl_FragColor = tcolor;
		return;
	}
	
	
	vec3 color = tcolor.rgb;

	color += vec3(whitepoint.x,whitepoint.y,-whitepoint.x)*0.1;
	
	vec3 collab = XYZ2LAB(RGB2XYZ(color),D65);

	collab = collab*labscale + laboffset;
	
	collab.x = texture1D(LUTx,collab.x*scale + offset).r;
	collab.y = texture1D(LUTy,collab.y*scale + offset).r;
	collab.z = texture1D(LUTz,collab.z*scale + offset).r;
	
	collab = (collab - laboffset)/labscale;
	
	//collab.yz += whitepoint*25.0;
	
	color = XYZ2RGB(LAB2XYZ(collab,D65));
	
	if(invert)
		tcolor.a = 1.0 - tcolor.a;
	if(usealpha)
		gl_FragColor = mix(vec4(tcolor.rgb,1.0),vec4(color,1.0),tcolor.a);
	else
		gl_FragColor = vec4(color,tcolor.a);
}
]]


local M = {}

function M.photofx(GL,args)
	args = args or {}
	local plugin = require"anima.plugins.plugin"
	local LM = plugin.new{res={GL.W,GL.H}}
	local  program,fbo
	local LUTx,LUTy,LUTz
	local LUTsize = args.LUTsize or 256
	local cuus = {}
	local numpoints = args.numpoints or 10
	
	local whitepoint = ffi.new("float[2]")
	
	
	LM.save = function()
		local vals = LM.NM:GetValues()
		local ptsx = cuus[1]:getpoints()
		local ptsy = cuus[2]:getpoints()
		local ptsz = cuus[3]:getpoints()
		return {vals=vals,ptsx=ptsx,ptsy=ptsy,ptsz=ptsz}
	end
	LM.load = function(self,params)
		--print("LAVload",self.NM.dirty)
		LM.NM:SetValues(params.vals)
		cuus[1]:setpoints(params.ptsx)
		cuus[2]:setpoints(params.ptsy)
		cuus[3]:setpoints(params.ptsz)
		cuus[1]:get_data()
		cuus[2]:get_data()
		cuus[3]:get_data()
		LUTx:set_data(cuus[1].LUT, glc.GL_RED)
		LUTy:set_data(cuus[2].LUT, glc.GL_RED)
		LUTz:set_data(cuus[3].LUT, glc.GL_RED)
		self.NM.dirty=true
	end
	
	local fB = plugin.serializer(LM)
	local presets = plugin.presets(LM)
	
	local sz = 300
	local curr_curve = 1
	local curve_labels = {"L","a","b"}
	local Luts = {LUTx,LUTy,LUTz}
	local cux = ig.LuaCurve(curve_labels[1],LUTsize)
	local cuy = ig.LuaCurve(curve_labels[2],LUTsize)
	local cuz = ig.LuaCurve(curve_labels[3],LUTsize)
	cuus = {cux,cuy,cuz}

	local NM
	NM = GL:Dialog("photofx",
	{

	{"usealpha",false,guitypes.toggle},
	{"invert",false,guitypes.toggle},
	{"bypass",false,guitypes.toggle}
	}, function(this) 
		for i=1,3 do
			local dopop = false
			if i == curr_curve then
				ig.PushStyleColor(imgui.ImGuiCol_Button, ig.ImVec4(1,0,0,1)); dopop = true
			end
			if ig.SmallButton(curve_labels[i].."##tab") then curr_curve = i end
			if dopop then imgui.igPopStyleColor(1); end
			ig.SameLine()
		end
		ig.NewLine()
		local scpos = ig.GetCursorScreenPos()
		
		ig.SetCursorScreenPos(scpos)
		ig.PushID(curr_curve)
		cuus[curr_curve]:draw(ig.ImVec2(sz,sz),curr_curve)
		ig.PopID()
		ig.BeginDisabled()
		for i=1,3 do
			if i~=curr_curve then
				ig.SetCursorScreenPos(scpos)
				ig.PushStyleColor(imgui.ImGuiCol_PlotLinesHovered, ig.ImVec4(0,0,1,1));
				ig.PushID(i)
				cuus[i]:draw(ig.ImVec2(sz,sz),curr_curve) 
				ig.PopID()
				ig.PopStyleColor(1)
			end
		end
		ig.EndDisabled()
		ig.SetCursorScreenPos(scpos)
		if cuus[curr_curve]:draw(ig.ImVec2(sz,sz),"repe") then
			cuus[curr_curve]:get_data()
			Luts[curr_curve]:set_data(cuus[curr_curve].LUT, glc.GL_RED)
			NM.dirty = true
		end

		if gui.pad("colorp",whitepoint) then NM.dirty = true end

		fB.draw()
		presets.draw()
	end)
	LM.NM = NM
	NM.plugin = LM
	function LM.init()
	
		programfx = GLSL:new():compile(vert_shad,frag_shad)
		
		cuus[1]:get_data()
		cuus[2]:get_data()
		cuus[3]:get_data()
		
		LUTx = GL:Texture1D(LUTsize,glc.GL_R32F,cuus[1].LUT,glc.GL_RED)
		LUTy = GL:Texture1D(LUTsize,glc.GL_R32F,cuus[2].LUT,glc.GL_RED)
		LUTz = GL:Texture1D(LUTsize,glc.GL_R32F,cuus[3].LUT,glc.GL_RED)
		Luts = {LUTx,LUTy,LUTz}
		
		local mesh = require"anima.mesh"
		local m = mesh.quad(-1,-1,1,1)
		LM.vao = VAO({Position=m.points,texcoords = m.texcoords},programfx,m.indexes)

		LM.inited = true
	end
	
	local function get_args(t, timev)
		for k,v in pairs(NM.vars) do
			if t.k then v[0] = ut.get_arg(t.k, timev) end
		end
	end
	
	function LM:process(srctex,w,h)
		gl.glDisable(glc.GL_DEPTH_TEST);
		srctex:Bind()
		LUTx:Bind(1)
		LUTy:Bind(2)
		LUTz:Bind(3)
		
		programfx:use()
		programfx.unif.tex0:set{0}
		programfx.unif.LUTx:set{1}
		programfx.unif.LUTy:set{2}
		programfx.unif.LUTz:set{3}
		
		programfx.unif.whitepoint:set(whitepoint)
		
		for k,v in pairs(NM.vars) do
			programfx.unif[k]:set{NM[k]}
		end
		
		gl.glViewport(0,0,w or self.res[1], h or self.res[2])
		self.vao:draw_elm()
		
		gl.glEnable(glc.GL_DEPTH_TEST);
	end
	
	function LM:draw(timebegin, w, h, args)
		if not self.inited then self.init() end
		
		get_args(args, timebegin)
		local theclip = args.clip
		
		if theclip[1].isTex2D then
			theclip[1]:set_wrap(glc.GL_CLAMP)
			theclip[1]:Bind()
		elseif theclip[1].isSlab then
			theclip[1].ping:GetTexture():Bind()
			theclip[1].pong:Bind()
		else
			fbo:Bind()
			theclip[1]:draw(timebegin, w, h,theclip)
			fbo:UnBind()
			fbo:UseTexture(0)
		end

		programfx:use()
		programfx.unif.tex0:set{0}
		
		for k,v in pairs(NM.vars) do
			programfx.unif[k]:set{NM[k]}
		end
		
		gl.glViewport(0,0,w,h)
		self.vao:draw_elm()
		
		if theclip[1].isSlab then
			theclip[1].pong:UnBind()
			theclip[1]:swapt()
		end
	end
	GL:add_plugin(LM)
	return LM
end
--alias
M.make = M.photofx

if not ... then
---[=[
require"anima"
local GL = GLcanvas{H=800,aspect=3/2}
local tex,slab,lch
function GL.init()
	tex = GL:Texture():Load[[c:\luagl\media\estanque3.jpg]]
	slab = tex:make_slab()
	--GL:set_WH(tex.width,tex.height)
	lch = M.photofx(GL)
end
function GL.draw(t,w,h)
	-- lch:process(slab,tex)
	-- slab.ping:GetTexture():draw(t,w,h)
	--lch:draw(t,w,h,{clip={tex}})
	--ut.ClearDepth()
	lch:process(tex)
end
GL:start()
--]=]
end
return M


