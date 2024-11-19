


local plugin = require"anima.plugins.plugin"

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
uniform float saturation;
uniform float hue;
uniform bool usealpha;
uniform bool invert;
uniform bool bypass;

float lutSize = textureSize(LUTx,0);
float scale = (lutSize - 1.0) / lutSize;
float offset = 1.0 / (2.0 * lutSize);

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
	//color = sRGB2RGB(color);
	
	
	vec3 colhsv = RGB2HSV(color);
	//vec3 colhsv = color;
	
	colhsv.x = texture1D(LUTx,colhsv.x*scale + offset).r;
	colhsv.y = texture1D(LUTy,colhsv.y*scale + offset).r;
	colhsv.z = texture1D(LUTz,colhsv.z*scale + offset).r;
	
	color = HSV2RGB(colhsv);
	//color = colhsv;
	
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

	local LM = plugin.new{res={GL.W,GL.H}}
	local  programfx,fbo
	local LUTx,LUTy,LUTz
	local LUTsize = args.LUTsize or 256
	local LUTdatax = ffi.new("float[?]",LUTsize)
	local LUTdatay = ffi.new("float[?]",LUTsize)
	local LUTdataz = ffi.new("float[?]",LUTsize)

	LUTdatax[0] = -1
	LUTdatay[0] = -1
	LUTdataz[0] = -1
	local numpoints = args.numpoints or 10
	local pointsx = ffi.new("ImVec2[?]",numpoints)
	pointsx[0].x = -1
	local pointsy = ffi.new("ImVec2[?]",numpoints)
	pointsy[0].x = -1
	local pointsz = ffi.new("ImVec2[?]",numpoints)
	pointsz[0].x = -1
	
	--serializer and presets 
	local function getpoints(points)
		local pts = {}
		for i=0,numpoints-1 do
			pts[i] = {x=points[i].x,y=points[i].y}
		end
		return pts
	end
	local function setpoints(pts,points)
		for i=0,#pts do
			points[i].x = pts[i].x
			points[i].y = pts[i].y
		end
	end
	
	LM.save = function()
		local vals = LM.NM:GetValues()
		vals.ptsx = getpoints(pointsx)
		vals.ptsy = getpoints(pointsy)
		vals.ptsz = getpoints(pointsz)
		return vals 
	end
	LM.load = function(self,params)
		LM.NM:SetValues(params) 
		setpoints(params.ptsx,pointsx)
		setpoints(params.ptsy,pointsy)
		setpoints(params.ptsz,pointsz)
		LUTdatax[0] = -1
		LUTdatay[0] = -1
		LUTdataz[0] = -1
		imgui.CurveGetData(pointsx, numpoints,LUTdatax, LUTsize )
		imgui.CurveGetData(pointsy, numpoints,LUTdatay, LUTsize )
		imgui.CurveGetData(pointsz, numpoints,LUTdataz, LUTsize )
		LUTx:set_data(LUTdatax, glc.GL_RED)
		LUTy:set_data(LUTdatay, glc.GL_RED)
		LUTz:set_data(LUTdataz, glc.GL_RED)
	end
	
	local fB = plugin.serializer(LM)
	local presets = plugin.presets(LM)
	
	local sz = 200
	local curr_curve = 1
	local curve_pars = {
	{ ig.ImVec2(sz,sz),pointsx, numpoints,LUTdatax, LUTsize,true},
	{ ig.ImVec2(sz,sz),pointsy, numpoints,LUTdatay, LUTsize,true},
	{ ig.ImVec2(sz,sz),pointsz, numpoints,LUTdataz, LUTsize,true}
	}
	local curve_labels = {"H","S","V"}

	local Luts = {LUTx,LUTy,LUTz}
	local NM 
	NM = GL:Dialog(args.name or "photofx",
	{
	{"usealpha",false,guitypes.toggle},
	{"invert",false,guitypes.toggle},
	{"bypass",false,guitypes.toggle}
	}, function()
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
		if imgui.Curve(curve_labels[curr_curve],unpack(curve_pars[curr_curve]))  then
			Luts[curr_curve]:set_data(curve_pars[curr_curve][4], glc.GL_RED)
			NM.dirty = true
		end
		for i=1,3 do
			if i~=curr_curve then
				ig.SetCursorScreenPos(scpos)
				ig.PushStyleColor(imgui.ImGuiCol_PlotLinesHovered, ig.ImVec4(0,0,1,1));
				if imgui.Curve("##"..curve_labels[i],unpack(curve_pars[i]))  then
					--Luts[i]:set_data(curve_pars[i][5], glc.GL_RED)
				end
				ig.PopStyleColor(1)
			end
		end
		
		ig.SetCursorScreenPos(scpos)
		imgui.Curve(curve_labels[curr_curve].."##s",unpack(curve_pars[curr_curve]))
		--[[
		if imgui.Curve("c_x", ig.ImVec2(sz,sz),pointsx, numpoints,LUTdatax, LUTsize )  then
			LUTx:set_data(LUTdatax, glc.GL_RED)
			--for i=0,2 do print(LUTdatax[i]) end
		end
		ig.SetCursorScreenPos(scpos)
		if imgui.Curve("c_y", ig.ImVec2(sz,sz),pointsy, numpoints,LUTdatay, LUTsize )  then
			LUTy:set_data(LUTdatay, glc.GL_RED)
		end
		ig.SetCursorScreenPos(scpos)
		if imgui.Curve("c_z", ig.ImVec2(sz,sz),pointsz, numpoints,LUTdataz, LUTsize )  then
			LUTz:set_data(LUTdataz, glc.GL_RED)
		end
		--]]
		fB.draw()
		presets.draw()
	end)
	LM.NM = NM
	NM.plugin = LM
	
	function LM.init()
	

		programfx = GLSL:new():compile(vert_shad,frag_shad)
		
		imgui.CurveGetData(pointsx, numpoints,LUTdatax, LUTsize )
		imgui.CurveGetData(pointsy, numpoints,LUTdatay, LUTsize )
		imgui.CurveGetData(pointsz, numpoints,LUTdataz, LUTsize )
			
		LUTx = GL:Texture1D(LUTsize,glc.GL_R32F,LUTdatax,glc.GL_RED,nil,{GL=GL})
		LUTy = GL:Texture1D(LUTsize,glc.GL_R32F,LUTdatay,glc.GL_RED,nil,{GL=GL})
		LUTz = GL:Texture1D(LUTsize,glc.GL_R32F,LUTdataz,glc.GL_RED,nil,{GL=GL})
		Luts = {LUTx,LUTy,LUTz}
		
		local mesh = require"anima.mesh"
		local m = mesh.quad(-1,-1,1,1)
		LM.vao = VAO({Position=m.points,texcoords = m.texcoords},programfx,m.indexes)

		LM.inited = true
	end
	
	local function get_args(t, timev)
		if not t then return end
		for k,v in pairs(NM.vars) do
			if t.k then v[0] = ut.get_arg(t.k, timev) end
		end
	end
	
	function LM:process(srctex,w,h)
	
		srctex:Bind()
		LUTx:Bind(1)
		LUTy:Bind(2)
		LUTz:Bind(3)
		
		programfx:use()
		programfx.unif.tex0:set{0}
		programfx.unif.LUTx:set{1}
		programfx.unif.LUTy:set{2}
		programfx.unif.LUTz:set{3}
		
		for k,v in pairs(NM.vars) do
			programfx.unif[k]:set{NM[k]}
		end
		
		gl.glViewport(0,0,w or self.res[1], h or self.res[2])
		self.vao:draw_elm()
	end
	
	
	function LM:draw(timebegin, w, h, args)
		if not self.inited then self.init() end
		
		get_args(args, timebegin)
		local theclip = args.clip
		
		if theclip[1].isTex2D then
			theclip[1]:set_wrap(glc.GL_CLAMP_TO_EDGE)
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
		
		LUTx:Bind(1)
		LUTy:Bind(2)
		LUTz:Bind(3)
		
		ut.Clear()
		
		programfx:use()
		programfx.unif.tex0:set{0}
		programfx.unif.LUTx:set{1}
		programfx.unif.LUTy:set{2}
		programfx.unif.LUTz:set{3}
		
		for k,v in pairs(NM.vars) do
			programfx.unif[k]:set{NM[k]}
		end
					
		gl.glViewport(0,0,w,h);GetGLError"photofx2"
		self.vao:draw_elm()

		if theclip[1].isSlab then
			theclip[1].pong:UnBind()
			theclip[1]:swapt()
		end
	end
	GL:add_plugin(LM,args.name)
	return LM
end
--alias
M.make = M.photofx

--[=[
require"anima"
local GL = GLcanvas{H=800,aspect=3/2}
local tex,slab,lch
function GL.init()
	tex = GL:Texture():Load[[c:\luagl\media\estanque3.jpg]]
	--tex = GL:Texture():Load[[c:\luagl\media\piscina.tif]]
	slab = tex:make_slab()
	--GL:set_WH(tex.width,tex.height)
	lch = M.photofx(GL)
end
local enadt = ffi.new("GLboolean[1]")
function GL.draw(t,w,h)
	-- lch:process(slab,tex)
	-- slab.ping:GetTexture():draw(t,w,h)
	gl.glGetBooleanv(glc.GL_DEPTH_TEST,enadt)
	--print("DT",enadt[0])
	lch:draw(t,w,h,{clip={tex}})
end
GL:start()
--]=]

return M


