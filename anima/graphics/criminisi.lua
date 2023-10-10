-- implementation of: "Object Removal by Exemplar-Based Inpainting, A. Criminisi, P.Perez, K. Toyama"
-- -- prio GPU added
--confidence values recalc
--updateCanvasGPU
-- get subimage
----------------------
local vert_sh=[[
in vec3 position;
void main(){
	gl_Position = vec4(position,1); 
}
]]

local frag_edge = [[
uniform sampler2D tex0;
uniform vec3 channelselector = vec3(0.299, 0.587, 0.114);
vec2 texsize = textureSize(tex0,0);

float luma(vec4 color) {
  return dot(color.rgb, channelselector);
}

float L(vec2 pos){
	return luma(texture2D(tex0,pos/texsize));
	//return texture2D(tex0,pos/texsize).r;
}

void main(){
	
	vec2 pos = gl_FragCoord.xy;
	
	float Lx =	(L(pos + vec2(1,0)) - L(pos + vec2(-1,0)));
	float Ly =	(L(pos + vec2(0,1)) - L(pos + vec2(0,-1)));
	
	//float Lx =	0.5*(L(pos + vec2(1,0)) - L(pos + vec2(0,0)));
	//float Ly =	0.5*(L(pos + vec2(0,1)) - L(pos + vec2(0,0)));
	
	float val = length(vec2(Lx,Ly));

	gl_FragColor = vec4(vec3(val,Lx,Ly),1);
}
]]
local frag_sh = [[
	uniform vec3 color = vec3(1);
	void main(){
		gl_FragColor = vec4(color,1);
	}]]
local frag_dist = require"anima.GLSL.GLSL_color"..[[
uniform sampler2D canvas;
uniform sampler2D canvasSample;
uniform sampler2D mask;
uniform int win_halfsize;
uniform int i,j;
ivec2 texsize = textureSize(canvas,0);
ivec2 limits = texsize - ivec2(win_halfsize);


vec3 ToLab(vec3 color)
{
	return XYZ2LAB(RGB2XYZ(sRGB2RGB(color.rgb)),D65);
	//return color;
}

void main(){
	//bool goodSSD = true;
	float SSD = 0.0;
	if (gl_FragCoord.x < win_halfsize || gl_FragCoord.x > limits.x || gl_FragCoord.y < win_halfsize || gl_FragCoord.y > limits.y){
		//gl_FragColor = vec4(0,0,0,0);
		//return;
		discard;
	}

	for(int x=-win_halfsize;x<=win_halfsize;x++){
		for(int y=-win_halfsize;y<=win_halfsize;y++){
			vec3 color = texelFetch(canvasSample,ivec2(gl_FragCoord.xy)+ivec2(x,y),0).rgb;
			vec3 color2 = texelFetch(canvas,ivec2(i,j)+ivec2(x,y),0).rgb;
			vec3 mpix = texelFetch(mask,ivec2(gl_FragCoord.xy)+ivec2(x,y),0).rgb;
			vec3 mpix2 = texelFetch(mask,ivec2(i,j)+ivec2(x,y),0).rgb;
			if(mpix.g > 0.5){
				vec3 difcol = ToLab(color) - ToLab(color2);
				SSD += dot(difcol,difcol)*mpix2.b;
			}else{
				//goodSSD = false;
				//gl_FragColor = vec4(SSD,0,0,0);
				//return;
				discard;
			}
		}
	}
	
	gl_FragColor = vec4(SSD,1,0,0);
}
]]

local frag_upd_canvas = [[
uniform sampler2D canvas;
uniform sampler2D mask;
uniform int ior,jor;
uniform ivec2 center;
uniform float win_halfsize;
uniform bool doblend;
void main()
{
	vec3 mpix = texelFetch(mask,ivec2(gl_FragCoord.xy),0).rgb;
	vec3 cpix = texelFetch(canvas,ivec2(gl_FragCoord.xy)+ivec2(ior,jor),0).rgb;
	if (mpix.b == 1.0){
		if(doblend){
			float fac = clamp(length(gl_FragCoord.xy - center)/win_halfsize,0,1);
			gl_FragColor = vec4(cpix,1-fac);
		}else{
			discard;
		}
	}else{
		gl_FragColor = vec4(cpix,1);
	}
}
]]

local frag_upd_confi = [[
uniform sampler2D mask;
uniform float confi;

void main()
{
	vec3 mpix = texelFetch(mask,ivec2(gl_FragCoord.xy),0).rgb;
	if (mpix.b == 1.0)
		discard;
	
	gl_FragColor = vec4(confi,0,0,1);
}
]]

local frag_prio = [[
uniform sampler2D contour;
uniform sampler2D isophote;
uniform sampler2D mask;
uniform sampler2D confidence;
uniform int win_halfsize;

float winsize = 2.0*win_halfsize + 1.0;
float winarea = winsize*winsize;

vec2 isophoteSize = textureSize(isophote,0);

void main()
{
	vec3 cpix = texelFetch(contour,ivec2(gl_FragCoord.xy),0).rgb;
	if(cpix.r > 0.0){
		vec2 normal = normalize(vec2(cpix.g, cpix.b));
		
		vec3 isopix = texelFetch(isophote,ivec2(gl_FragCoord.xy),0).rgb;
		//vec3 isopix = texture2D(isophote,(vec2(gl_FragCoord.xy)+normal)/isophoteSize).rgb;
		//vec3 isopix = texture2D(isophote,(gl_FragCoord.xy)/isophoteSize).rgb;
		
		vec2 isograd = vec2(-isopix.b,isopix.g);
		float dataterm = abs(dot(normal, isograd));
		float sumwindow = 0;
		for(int x=-win_halfsize;x<=win_halfsize;x++){
			for(int y=-win_halfsize;y<=win_halfsize;y++){
				vec3 mpix = texelFetch(mask,ivec2(gl_FragCoord.xy)+ivec2(x,y),0).rgb;
				vec3 confi_pix = texelFetch(confidence,ivec2(gl_FragCoord.xy)+ivec2(x,y),0).rgb;
				if(mpix.b > 0)
					sumwindow += confi_pix.r;
			}
		}
		sumwindow /= winarea;
		float prio = sumwindow*dataterm;
		gl_FragColor = vec4(prio,sumwindow,1,0);
	}else{
		gl_FragColor = vec4(0);
	}
}
]]
-------------------------------------------------------------
require"anima"

local function Criminisi(GL,tex,make_mask1)
	local M = {}

	local NM
	local spline
	local canvas,canvas_fbo
	local maskfbo, conf_fbo
	local SBox , CBox


local contour_prog, quad
local contour_fbo, isophote_fbo
local function init_contour()
	contour_prog = GLSL:new():compile(vert_sh, frag_edge)
	quad = mesh.quad():vao(contour_prog)
	contour_fbo = GL:initFBO({no_depth=true})
	M.contour_fbo = contour_fbo
	isophote_fbo = GL:initFBO({no_depth=true})
	M.isophote_fbo = isophote_fbo
end
local function find_contour()
	contour_prog:use()
	contour_prog.unif.tex0:set{0}
	contour_prog.unif.channelselector:set{0,0,1}
	maskfbo:tex():Bind()
	contour_fbo:Bind()
	contour_fbo:viewport()
	ut.Clear()
	quad:draw_elm()
	contour_fbo:UnBind()
end
local function find_isophotes()
	contour_prog:use()
	contour_prog.unif.tex0:set{0}
	contour_prog.unif.channelselector:set{0.299, 0.587, 0.114}
	canvas_fbo:tex():Bind()
	isophote_fbo:Bind()
	isophote_fbo:viewport()
	ut.Clear()
	quad:draw_elm()
	isophote_fbo:UnBind()
end
-----------------------------
local vicim = require"anima.vicimag"
local vec2 = mat.vec2

local progdist,fbodist,quadist
local function initProgDist()
	progdist = GLSL:new():compile(vert_sh, frag_dist)
	quadist = mesh.quad():vao(progdist)
	fbodist = GL:initFBO({no_depth=true})
	M.fbodist = fbodist
end
local function searchDistancesGPU(i,j)
	if not progdist then initProgDist() end
	
	local offX, offY, W, H = SBox[1].x, SBox[1].y, SBox[2].x - SBox[1].x, SBox[2].y - SBox[1].y
	--local offX, offY, W, H = 0,0, fbodist:tex().width, fbodist:tex().height
	
	progdist:use()
	progdist.unif.canvas:set{0}
	canvas_fbo:tex():Bind()
	progdist.unif.canvasSample:set{2}
	tex:Bind(2)
	progdist.unif.mask:set{1}
	maskfbo:tex():Bind(1)
	progdist.unif.i:set{i}
	progdist.unif.j:set{j}
	progdist.unif.win_halfsize:set{math.floor(NM.win_halfsize)}
	fbodist:Bind()
	--fbodist:viewport()
	gl.glViewport(offX, offY, W, H)
	gl.glClearColor(0,0,0,0)
	ut.Clear()
	quadist:draw_elm()
	fbodist:UnBind()
	
	
	local dists = {}
	local mindist = math.huge
	local minind = -1
	
	--local distpd = vicim.tex2pd(fbodist:tex())
	local subdata = fbodist:get_pixels(glc.GL_RGB,glc.GL_FLOAT,0,nil, offX, offY, W, H)
	local distpd = vicim.pixel_data(subdata, W, H, 3)

	for np=0,distpd.npix-1 do
		local pix = distpd:lpix(np)
		if pix[1] > 0.5 then
			local i,j = distpd:lpixTOij(np)
			dists[#dists+1] = {i+offX,j+offY,pix[0]}
			if pix[0] < mindist then
				mindist = pix[0]
				minind = #dists
			end
		end
	end

	return dists[minind]
end

--------------PRIO

local prio_prog, prio_vao,prio_fbo
local function initPrio()
	prio_prog = GLSL:new():compile(vert_sh, frag_prio)
	prio_vao = mesh.quad():vao(prio_prog)
	prio_fbo = GL:initFBO({no_depth=true})
	M.prio_fbo = prio_fbo
end
local function calcPriorityGPU()
	if not prio_prog then initPrio() end
	local win_halfsize = math.floor(NM.win_halfsize)
	
	local offX, offY, W, H = CBox[1].x, CBox[1].y, CBox[2].x - CBox[1].x, CBox[2].y - CBox[1].y
	 --local offX, offY, W, H = 0,0, prio_fbo:tex().width, prio_fbo:tex().height
	
	prio_prog:use()
	local U = prio_prog.unif
	U.contour:set{0}
	contour_fbo:tex():Bind(0)
	U.isophote:set{1}
	isophote_fbo:tex():Bind(1)
	U.mask:set{2}
	maskfbo:tex():Bind(2)
	U.confidence:set{3}
	conf_fbo:tex():Bind(3)
	U.win_halfsize:set{win_halfsize}
	prio_fbo:Bind()
	--prio_fbo:viewport()
	gl.glViewport(offX, offY, W, H)
	ut.Clear()
	prio_vao:draw_elm()
	prio_fbo:UnBind()
	
	
	local maxprio = -math.huge
	local maxind = -1
	
	local prios = {}
	
	-- local priopd = vicim.tex2pd(prio_fbo:tex())
	local subdata = prio_fbo:get_pixels(glc.GL_RGB,glc.GL_FLOAT,0,nil, offX, offY, W, H)
	local priopd = vicim.pixel_data(subdata, W, H, 3)

	for np=0,priopd.npix-1 do
		local pix = priopd:lpix(np)
		if pix[2] > 0 then
			if pix[0] > maxprio then
				maxprio = pix[0]
				local i,j = priopd:lpixTOij(np)
				prios[#prios+1] = {i=i+offX,j=j+offY,prio=maxprio,confi=pix[1]}
				maxind = #prios
			end
		end
	end
	return prios, maxind
end


---------------------------UpdateCanvasGPU

local prupdcanvas, vaoupdcanvas 
local prupdconfi, vaoupdconfi
local prupdmask , maskquad
local function initUpdate()
	prupdcanvas = GLSL:new():compile(vert_sh, frag_upd_canvas)
	vaoupdcanvas = mesh.quad():vao(prupdcanvas)
	
	prupdconfi = GLSL:new():compile(vert_sh, frag_upd_confi)
	vaoupdconfi = mesh.quad():vao(prupdconfi)
	
	canvas_fbo = GL:initFBO({no_depth=true})
	M.canvas_fbo = canvas_fbo
	prupdmask = GLSL:new():compile(vert_sh, frag_sh)
	maskquad = mesh.quad():vao(prupdmask)
end

local function UpdateCanvasGPU(P1,P2)
	local id,jd,confi = P1.i, P1.j, P1.confi
	local ior,jor = P2[1],P2[2]
	local win_halfsize = math.floor(NM.win_halfsize)
	local winsize = 2*win_halfsize +1
	
	gl.glEnable(glc.GL_BLEND)
	glext.glBlendEquation(glc.GL_FUNC_ADD)
	gl.glBlendFunc(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA)
	prupdcanvas:use()
	prupdcanvas.unif.canvas:set{0}
	tex:Bind()
	prupdcanvas.unif.mask:set{1}
	maskfbo:tex():Bind(1)
	prupdcanvas.unif.ior:set{-id+ior} --ior-id}
	prupdcanvas.unif.jor:set{-jd+jor}--320-jor} --jor-jd}
	prupdcanvas.unif.center:set{id,jd}
	prupdcanvas.unif.win_halfsize:set{win_halfsize}
	prupdcanvas.unif.doblend:set{NM.doblend}
	canvas_fbo:Bind()
	--ut.ClearDepth()
	gl.glViewport(id-win_halfsize,jd-win_halfsize,winsize,winsize)
	vaoupdcanvas:draw_elm()
	canvas_fbo:UnBind()
	gl.glDisable(glc.GL_BLEND)
	
	prupdconfi:use()
	prupdconfi.unif.mask:set{0}
	maskfbo:tex():Bind(0)
	prupdconfi.unif.confi:set{confi}
	conf_fbo:Bind()
	gl.glViewport(id-win_halfsize,jd-win_halfsize,winsize,winsize)
	vaoupdconfi:draw_elm()
	conf_fbo:UnBind()
	
	gl.glEnable(glc.GL_BLEND)
	glext.glBlendEquation(glc.GL_MAX)
	prupdmask:use()
	prupdmask.unif.color:set{0,0,1}
	maskfbo:Bind()
	gl.glViewport(id-win_halfsize,jd-win_halfsize,winsize,winsize)
	gl.glDisable(glc.GL_DEPTH_TEST)
	--gl.glClearColor(1,1,1,1)
	--ut.Clear()
	maskquad:draw_elm()
	maskfbo:UnBind()
	gl.glDisable(glc.GL_BLEND)
end
---------------------------
local floor = math.floor
local function box2d(fbo,ch,doprint)
	ch = ch or 0
	local offX, offY, W, H = 0,0, fbo:tex().width, fbo:tex().height
	local subdata = fbo:get_pixels(glc.GL_RGB,glc.GL_FLOAT,0,nil, offX, offY, W, H)
	local distpd = vicim.pixel_data(subdata, W, H, 3)
	local minx,maxx,miny,maxy = math.huge,-math.huge,math.huge,-math.huge
	for np=0,distpd.npix-1 do
		local pix = distpd:lpix(np)
		if pix[ch] > 0.5 then
			local i,j = distpd:lpixTOij(np)
			minx = i < minx and i or minx
			maxx = i > maxx and i or maxx
			miny = j < miny and j or miny
			maxy = j > maxy and j or maxy
		end
	end

	return {mat.vec2(minx,miny),mat.vec2(maxx,maxy)}
end

local function make_mask_default()
	local SBox = box2d(maskfbo,1) 
	local CBox = box2d(maskfbo,0) 
	print("CBox",CBox[1], CBox[2])
	print("SBox",SBox[1], SBox[2])
	return CBox, SBox
end

-----------------------------
local initconfprog	
local function do_criminisi()
	M.doing = true
	local init_t = secs_now()
	local iterscount = 0
	--ProfileStart("3vfsm1")
	local make_mask = make_mask1 and make_mask1 or make_mask_default
	CBox, SBox = make_mask()
	initconfprog:process_fbo(conf_fbo,{maskfbo:tex()})
	canvas_fbo:Bind()
	tex:drawcenter()
	canvas_fbo:UnBind()
	coroutine.yield()
	while true do
		find_contour()
		find_isophotes()
		
		local P,i = calcPriorityGPU() --Dummy()
		if i < 0 then break end
		local P2 = searchDistancesGPU(P[i].i,P[i].j)
		if not P2 then print"No sample found: reduce win_halfsize" end
		UpdateCanvasGPU(P[i],P2)
		
		iterscount = iterscount + 1
		coroutine.yield()
	end
	M.doing = false
	tex:inc_signature()
	--ProfileStop()
	print("done in -----------------",secs_now()-init_t)
	print("iters",iterscount)
end

function M:init()
	maskfbo = GL:initFBO({no_depth=true})
	M.maskfbo = maskfbo
	conf_fbo = GL:initFBO({no_depth=true})
	M.conf_fbo = conf_fbo
	initconfprog = require"anima.plugins.texture_processor"(GL,1)
	initconfprog:set_process[[vec4 process(vec2 pos){
			return vec4(1-c1.r,0,0,0);
		}]]
	init_contour()
	initProgDist()
	initPrio()
	initUpdate()
end

M.make_mask_co = nil

NM = GL:Dialog("inpaint",{
{"mostrar",0, guitypes.combo,{"orig","canvas","mask","contour","isophote","confidence","prio"}},
{"doblend",true,guitypes.toggle},
{"win_halfsize",10,guitypes.drag,{min=3,max=30}},
{"do_it",false, guitypes.button, function(this) 
	--this.vars.mostrar[0] = 1
	M.make_mask_co = coroutine.create(do_criminisi)
	local ok,err = coroutine.resume(M.make_mask_co) 
	if not ok then print(err) end
end}
})
M.NM = NM

function M.draw(t,w,h)
	ut.Clear()
	if NM.mostrar == 0 then
		tex:drawcenter()
	elseif NM.mostrar == 1 then
		canvas_fbo:tex():drawcenter()
	elseif NM.mostrar == 2 then
		maskfbo:tex():drawcenter()
	elseif NM.mostrar == 3 then
		contour_fbo:tex():drawcenter()
	elseif NM.mostrar == 4 then
		isophote_fbo:tex():drawcenter()
	elseif NM.mostrar == 5 then
		conf_fbo:tex():drawcenter()
	elseif NM.mostrar == 6 then
		prio_fbo:tex():drawcenter()
	end
	if M.make_mask_co and coroutine.status(M.make_mask_co)~="dead" then
		local ok,err = coroutine.resume(M.make_mask_co) 
		if not ok then print(err); print(debug.traceback(M.make_mask_co)) end
	end
end

	return M
end --Criminisi

return Criminisi

