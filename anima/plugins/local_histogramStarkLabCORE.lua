
local vert_shad = [[
#version 130
]]..require"anima.GLSL.GLSL_color"..[[
in vec3 position;
uniform sampler2D tex0;
uniform float nposbinsX;
uniform float nposbinsY;
uniform float posbins;
uniform int color_mode = 0;

float measure(float col,float sz){
	return floor((col + 1.0)*sz) - floor(col*sz);
}
vec3 labscale = vec3(1.0/100.0,1.0/115.0,1.0/115.0);
//a* is -79 to 94, and the range of b* is -112 to 93
vec3 laboffset = vec3(0.0,0.5,0.5);
vec3 lumin = vec3( 0.30, 0.59, 0.11);
void main()
{

	vec4 col = texelFetch(tex0, ivec2(position.xy), 0);
	
	float lum;
	if (color_mode == 0)
		lum = dot(col.rgb,lumin);
	else if(color_mode == 1){
		lum = RGB2HSV(col.rgb).y;
		//vec3 collab = LAB2LCH(XYZ2LAB(RGB2XYZ(sRGB2RGB(col.rgb)),D65));
		//lum = collab.r*0.01;
	}else if(color_mode == 2){
		vec3 collab = XYZ2LAB(RGB2XYZ(sRGB2RGB(col.rgb)),D65);
		lum = collab.r*0.01;
	}
	
	ivec2 sz = textureSize(tex0, 0);
	float squareszX = sz.s/nposbinsX;
	float colsquare = clamp(floor(position.x/squareszX),0.0,nposbinsX - 1.0);
	//float xwidth = min(floor(squareszX), sz.s - colsquare * squareszX);
	float xwidth = measure(colsquare,squareszX);
	float squareszY = sz.t/nposbinsY;
	float rowsquare = clamp(floor(position.y/squareszY),0.0,nposbinsY - 1.0);
	//float ywidth = min(squareszY, sz.t - rowsquare * squareszY);
	float ywidth = measure(rowsquare,squareszY);
	float posbin = rowsquare*nposbinsX + colsquare;
	//posbin /=(posbins - 1.0);
	posbin = (posbin + 0.5)/(posbins);
	gl_Position = vec4((lum -0.5)*2.0,(posbin - 0.5)*2.0,0.0,1.0);
	gl_FrontColor = vec4(1.0/(xwidth*ywidth),0.0,0.0,1.0);
}

]]
local frag_shad = [[
#version 130

void main()
{
	gl_FragColor = gl_Color;
}
]]

local frag_finish = [[
uniform sampler2D hist;

void main()
{
	ivec2 sz = textureSize(hist, 0);
	float tot = 0.0;
	for(int i=0;i<sz.s;i++)
		tot += texelFetch(hist,ivec2(i,gl_FragCoord.t),0).r;

	gl_FragColor = texelFetch(hist,ivec2(gl_FragCoord.s,gl_FragCoord.t),0)/tot;
}

]]
local vert_histoshow = [[
#version 130
void main(){
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = ftransform();
}
]]
local frag_histoshow = [[
#version 130
uniform sampler2D tex0,hist;
uniform float nposbins;
uniform float nbins;
uniform float scale =100.0;
void main(){
	float hh;
	vec2 pos = gl_TexCoord[0].st;
	//ivec2 sz = textureSize(tex0, 0);
	
	//vec4 colh = texture2D(tex0,vec2(pos.s,0));
	//vec4 colh = texelFetch(tex0, ivec2(floor(pos.s*nbins),floor(0.96*sz.t)),0);//floor(pos.t*sz.t)), 0);
	//vec4 colh = texelFetch(tex0, ivec2(floor(pos.s*(nbins-1)),floor(pos.t*(nposbins-1))), 0);
	vec4 colh = texelFetch(tex0, ivec2(floor(pos.s*(nbins)),floor(pos.t*(nposbins))), 0);
	//vec4 colh = texelFetch(tex0, ivec2(floor(gl_FragCoord.x/WW*nbins),floor(glFragCoord.y/WH*nposbins)), 0);
	gl_FragColor = colh*scale;//vec4(hh,0,0,1);//col;
}
]]


local vert_cum = [[
uniform mat4 MVP;
in vec3 position;
void main()
{
	//gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = MVP*vec4(position,1); //ftransform();
}
]]


--with alfa an beta from Starks
local frag_cum2 = [[
uniform sampler2D hist;
uniform float alfa;
uniform float beta;

float Q(float d,float alfa){
	return 0.5*sign(d)*pow(abs(2*d),alfa);
}
float FC(float a,float b){
	//return 0.5*sign(a-b);
	return beta*(a-0.5) -beta*Q(a-b,1.0) + Q(a-b,alfa);
}
void main()
{
	ivec2 sz = textureSize(hist, 0);
	vec4 tot = vec4(0.0);
	//for(int i=0;i<sz.s;i++)
	//	tot += texelFetch(hist,ivec2(i,gl_FragCoord.t),0);
	vec4 acum = vec4(0.0);
	float g = float(gl_FragCoord.s)/float(sz.s);
	for(int i=0;i<sz.s;i++)
		acum += texelFetch(hist,ivec2(i,gl_FragCoord.t),0)*FC(g,float(i)/float(sz.s));
	acum += vec4(0.5,0,0,0);
	//acum /= tot;
	if(acum.r > 1.0){
		acum = vec4(1.0,acum.r - 1.0,1.0,1);
	}
	gl_FragColor = acum;
	//gl_FragColor = vec4(1.0); //texelFetch(hist,ivec2(gl_FragCoord.s,0),0);
}

]]

local frag_stdev = [[
uniform sampler2D hist;
uniform float nbins;
void main()
{
	vec4 mean = vec4(0.0);
	for(int i=0;i<nbins;i++)
		mean += texelFetch(hist,ivec2(i,gl_FragCoord.t),0)*float(i)/nbins;
	vec4 stdev = vec4(0.0);
	for(int i=0;i<nbins;i++)
		stdev += abs((float(i)/nbins) - mean)*texelFetch(hist,ivec2(i,gl_FragCoord.t),0);
		//stdev += abs(texelFetch(hist,ivec2(i,gl_FragCoord.t),0) - mean)*float(i)/nbins;
	//if(acum.r > 1.0){
	//	acum = vec4(1.0,acum.r - 1.0,1.0,1);
	//}
	gl_FragColor = vec4(stdev.r,mean.r,0,1);
	//gl_FragColor = vec4(1.0); //texelFetch(hist,ivec2(gl_FragCoord.s,0),0);
}

]]

local vert_he = [[
in vec3 position;
in vec2 texcoords;
out vec2 texcoord_f;
uniform mat4 MVP;
void main()
{
	texcoord_f = texcoords;
	gl_Position = MVP*vec4(position,1);//ftransform();
}
]]

local frag_he = require"anima.GLSL.GLSL_color"..[[
in vec2 texcoord_f;
uniform sampler2D cumhist,tex0,stdev;
uniform bool doit;
uniform bool do_postprocess;
uniform float fac;
uniform float facdev;
uniform float facadddev;
uniform float nposbinsX;
uniform float nposbinsY;
uniform float ampL;
uniform float ampR;
uniform float black;
uniform float white;
uniform float saturation;

vec3 lumin = vec3( 0.30, 0.59, 0.11);

vec4 sigmoidal(vec4 val,float ampL,float ampR){

	vec3 i = vec3(mix(ampL,ampR,val.r),mix(ampL,ampR,val.g),mix(ampL,ampR,val.b));
	float minV2 = 1.0/(1.0 + exp(-ampL));
	float maxV2 = 1.0/(1.0 + exp(-ampR));
	float escale = 1.0/(maxV2 - minV2);
	float offset = 1.0 - maxV2 * escale;

	return vec4(offset + escale/(1.0 + exp(-i)),val.a);
}

float stdev_func(float lum,float fQ1,float facdev,float facadddev,vec4 stdevcol){

	float stdefac = stdevcol.r/stdevcol.g;
	
	float mixfac;
	if(facadddev == 0.0)
		mixfac = step(facdev,stdefac);
	else
		mixfac = smoothstep(facdev,facdev+facadddev ,stdefac);
		
	float ret = mix(lum,fQ1,mixfac);
	//if(isinf(stdefac))
	//	ret = 0.5;
	return ret;
}

float get_targ(float lum,float posbin,sampler2D cumhist){
	ivec2 sz = textureSize(cumhist,0);
	//return texelFetch(cumhist, ivec2(floor(lum*(sz.s-1)),floor(posbin)),0).r;
	float tar1 = texelFetch(cumhist, ivec2(floor(lum*(sz.s-1)),floor(posbin)),0).r;
	float tar2 = texelFetch(cumhist, ivec2(min(floor(lum*(sz.s-1))+1,sz.s-1),floor(posbin)),0).r;
	return mix(tar1,tar2,fract(lum*(sz.s-1)));
}

vec3 labscale = vec3(1.0/100.0,1.0/115.0,1.0/115.0);
//a* is -79 to 94, and the range of b* is -112 to 93
vec3 laboffset = vec3(0.0,0.5,0.5);
uniform int  color_mode = 0;
void main()
{
	vec2 pos = texcoord_f;
	
	ivec2 sz = textureSize(cumhist,0);
	vec3 col = texture2D(tex0, pos).rgb;
	
	float lum;
	vec3 colspace;
	if (color_mode == 0){
		lum = dot(col.rgb,lumin);
		colspace = col.rgb;
	}else if(color_mode == 1){
		colspace = RGB2HSV(col.rgb);
		lum = colspace.y;
		//colspace = LAB2LCH(XYZ2LAB(RGB2XYZ(sRGB2RGB(col.rgb)),D65));
		//lum = colspace.r*0.01;
	}else if(color_mode == 2){
		colspace = XYZ2LAB(RGB2XYZ(sRGB2RGB(col.rgb)),D65);
		lum = colspace.r*0.01;
	}
	
	/*
	//float lum = dot(col, lumin);
	//vec3 colhsv = RGB2HSV(col);
	//float lum = colhsv.z;
	
	vec3 collab = XYZ2LAB(RGB2XYZ(sRGB2RGB(col)),D65);
	//collab = collab*labscale + laboffset;
	float lum = collab.r*0.01;
	*/
	
	vec2 a = fract(pos*vec2(nposbinsX,nposbinsY));
	vec2 Porig = floor(pos*vec2(nposbinsX,nposbinsY));
	vec2 P = Porig;
	vec2 b = a - vec2(0.5);
	if( b.x < 0.0){
		b.x = 1.0 + b.x;
		P.x = P.x - 1.0;
		//col = col + vec3(1,0,0);
	}
	if( b.y < 0.0){
		b.y = 1.0 + b.y;
		P.y = P.y - 1.0;
		//col = col + vec3(0,1,0);
	}
	
	vec2 limpos = vec2(nposbinsX-1.0,nposbinsY-1.0);
	vec2 Q1 = clamp(P, vec2(0.0), limpos);
	vec2 Q2 = clamp(P + vec2(0.0, 1.0), vec2(0.0), limpos);
	vec2 Q3 = clamp(P + vec2(1.0, 1.0), vec2(0.0), limpos);
	vec2 Q4 = clamp(P + vec2(1.0, 0.0), vec2(0.0), limpos);
	
	//if( P==limpos) 
	//	col = col + vec3(0,0,1);
	
	float posbin;
	vec4 stdevcol;
	posbin = dot(Q1,vec2(1.0,nposbinsX));
	//float fQ1 = texelFetch(cumhist, ivec2(floor(lum*(sz.s-1)),floor(posbin)),0).r;
	float fQ1 = get_targ(lum,posbin,cumhist);
	stdevcol  = texelFetch(stdev, ivec2(0,floor(posbin)),0);
	//fQ1 = mix(lum,fQ1,clamp(stdevcol*facdev,0.0,1.0));
	//fQ1 = mix(lum,fQ1,step(facdev, stdevcol));
	fQ1 = stdev_func(lum,fQ1,facdev,facadddev,stdevcol);
	
	posbin = dot(Q2,vec2(1.0,nposbinsX));
	//float fQ2 = texelFetch(cumhist, ivec2(floor(lum*(sz.s-1)),floor(posbin)),0).r;
	float fQ2 = get_targ(lum,posbin,cumhist);
	stdevcol  = texelFetch(stdev, ivec2(0,floor(posbin)),0);
	fQ2 = stdev_func(lum,fQ2,facdev,facadddev,stdevcol);
	
	posbin = dot(Q3,vec2(1.0,nposbinsX));
	//float fQ3 = texelFetch(cumhist, ivec2(floor(lum*(sz.s-1)),floor(posbin)),0).r;
	float fQ3 = get_targ(lum,posbin,cumhist);
	stdevcol  = texelFetch(stdev, ivec2(0,floor(posbin)),0);
	fQ3 = stdev_func(lum,fQ3,facdev,facadddev,stdevcol);
	
	posbin = dot(Q4,vec2(1.0,nposbinsX));
	//float fQ4 = texelFetch(cumhist, ivec2(floor(lum*(sz.s-1)),floor(posbin)),0).r;
	float fQ4 = get_targ(lum,posbin,cumhist);
	stdevcol  = texelFetch(stdev, ivec2(0,floor(posbin)),0);
	fQ4 = stdev_func(lum,fQ4,facdev,facadddev,stdevcol);
	
	float targ_lum = mix(mix(fQ1,fQ4,b.x),mix(fQ2,fQ3,b.x),b.y);
	
	//posbin = dot(Porig,vec2(1.0,nposbinsX));
	//targ_lum = get_targ(lum,posbin,cumhist);
	
/*
	float colsquare = floor(pos.s*nposbinsX);
	float rowsquare = floor(pos.t*nposbinsY);
	posbin = rowsquare*nposbinsX + colsquare;
	
	posbin = dot(Q1,vec2(1.0,nposbinsX));
	vec4 stdevcol  = texelFetch(stdev, ivec2(0,floor(posbin)),0);
*/	
	//targ_lum = clamp(targ_lum,0.0,1.0);
	if(isnan(targ_lum))
		targ_lum = 0.0;
	targ_lum = mix(lum,targ_lum,fac);
	
	vec4 color;
	if(doit){
		if(do_postprocess)
			targ_lum = (targ_lum - black)/(white - black);//targ_lum = clamp((targ_lum - black)/(white - black),0.0,1.0);
			
		if (color_mode == 0){
			col = col*targ_lum/lum;
		}else if(color_mode == 1){
			col = HSV2RGB(vec3(colspace.x,targ_lum,colspace.z));
			//col = HSV2RGB(vec3(colspace.x,clamp(saturation*colspace.y,0.0,1.0),targ_lum));
			//col = RGB2sRGB(XYZ2RGB(LAB2XYZ(LCH2LAB(vec3(targ_lum*100.0,saturation*colspace.g,colspace.b)),D65)));
		}else if(color_mode == 2){
			col = RGB2sRGB(XYZ2RGB(LAB2XYZ(vec3(targ_lum*100.0,colspace.g,colspace.b),D65)));
		}	
		//col = HSV2RGB(vec3(colhsv.x,clamp(saturation*colhsv.y,0.0,1.0),targ_lum));
		//collab = (collab - laboffset)/labscale;
		//col = RGB2sRGB(XYZ2RGB(LAB2XYZ(vec3(targ_lum*100.0,collab.g,collab.b),D65)));
		
		color = vec4(col,1.0);
		
		//test range
		//if(any(greaterThan(col,vec3(1,1,1))))
		//	color = vec4(1,0,0,1);
		
		if(do_postprocess)
			color = sigmoidal(color,ampL,ampR);
	}else{

		color = vec4(col,1.0);
	}
		
	gl_FragColor =color ;//+ vec4( stdevcol.r*2);// color;//vec4(stdevcol.r,0,0,1); //color + stdevcol;
}

]]

local mat = require"anima.matrixffi"
local mesh = require"anima.mesh"
local function DoQuad(w,h,prog)
	if not prog.vao then
		local m = mesh.quad(0,0,w,h)
		prog.vao = m:vao(prog)
	end
	--assert(vao.count)
	prog.vao:draw_elm()
end
--for computing histo
local function DoMESH(w, h,prog)
	local zplane = 0
	local Pos = ffi.new("float[?]",w*h*3)
	local ind = 0
		for i=0,w-1,1 do
		for j=0,h-1,1 do
		Pos[ind] = i
		Pos[ind+1] = j
		Pos[ind+2] = zplane
		ind = ind + 3
	end
	end
	return VAO({position=Pos},prog)
end

local function Clear()
	gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
end
local function ShowTex(tex,w,h,prog)


	local modewrap = glc.GL_CLAMP_TO_EDGE --glc.GL_CLAMP --glc.GL_REPEAT --glc.GL_MIRRORED_REPEAT
	
	glext.glActiveTexture(glc.GL_TEXTURE0);
	--gl.glEnable( glc.GL_TEXTURE_2D );
	gl.glBindTexture(glc.GL_TEXTURE_2D, tex)
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
	
	-- gl.glMatrixMode(glc.GL_PROJECTION)
	-- gl.glLoadIdentity()
	-- gl.glOrtho(0.0, w, 0.0, h, -1, 1);
	-- gl.glMatrixMode(glc.GL_MODELVIEW)
	-- gl.glLoadIdentity();
	gl.glViewport(0, 0, w, h)
	
	prog.unif.MVP:set(mat.ortho(0.0, w, 0.0, h, -1, 1).gl)
	DoQuad(w,h,prog)
end

local function SetSRGB(srgb)
	local framebuffer = ffi.new("GLint[1]",0)
	gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, framebuffer)
	if srgb and framebuffer[0]== 0 then
		gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
	end
end

local function Histogram(GL,nbins,maxposbins)

	local plugin = require"anima.plugins.plugin"
	local hist = plugin.new{res={GL.W,GL.H}}
	local plugin = require"anima.plugins.plugin"
	local fB = plugin.serializer(hist)
	local presets = plugin.presets(hist)
	
local alfabetadirty = true
local NMamp = GL:Dialog("stark local hist",
{
{"ampL",0.001,guitypes.val,{min=-6,max=6}},
{"ampR",0.00,guitypes.val,{min=-6,max=6}},
{"fac2",0,guitypes.val,{min=0,max=0.5}},
{"facadd2",0,guitypes.val,{min=0,max=0.5}},
{"black",0,guitypes.val,{min=0,max=1}},
{"white",1,guitypes.val,{min=0,max=1}},
{"saturation",1,guitypes.val,{min=0,max=2}},
{"do_postprocess",1,guitypes.toggle},
{"fac",1,guitypes.val,{min=0,max=1}},
{"posbins",maxposbins-1000,guitypes.drag,{min=1,max=maxposbins}},
{"doit",1,guitypes.toggle},
{"color_mode",2,guitypes.combo,{"rgb","hsv","Lab"},function(val) 
	hist:calc()
	hist:cum_calc()
	hist:stdev_calc()
	print("color_mode",val)
end},
{"alfa",0.5,guitypes.val,{min=0,max=1},function() alfabetadirty= true end },
{"beta",1,guitypes.val,{min=0,max=1},function() alfabetadirty= true end },
},function() fB:draw();presets:draw() end)
	
	hist.NM = NMamp
	hist.save = function() return NMamp:GetValues() end
	hist.load = function(self,vv) alfabetadirty= true;return NMamp:SetValues(vv) end
	
	local fbohist,fbohist0,fbocumhist,fbostdev, programfx,programhistoshow
	local pr_cum,pr_stdev,pr_he
	local quad_list
	local textura = false
	local inited = false
	local posbins,nposbinsX,nposbinsY
	local squaresz
	local squareszdirty = false
	function hist:init()
		if inited then return end
		programfx = GLSL:new():compile(vert_shad,frag_shad)
		programhistoshow = GLSL:new():compile(vert_histoshow,frag_histoshow)
		pr_cum = GLSL:new():compile(vert_cum,frag_cum2)
		pr_finish = GLSL:new():compile(vert_cum,frag_finish)
		pr_stdev = GLSL:new():compile(vert_cum,frag_stdev)
		pr_he = GLSL:new():compile(vert_he,frag_he)
		fbohist = GL:initFBO({no_depth=true},nbins,maxposbins)
		fbohist0 = GL:initFBO({no_depth=true},nbins,maxposbins)
		inited = true
	end
	function hist:Getcumhist()
		return fbocumhist
	end
	function hist:setposbins(pbins)
		pbins = pbins or NMamp.posbins
		pbins = math.floor(pbins)
		local sqsz = math.sqrt(textura.width*textura.height/pbins)
		if sqsz == squaresz then return end
		print("posbins",sqsz,squaresz)
		squaresz = sqsz
		nposbinsX = math.ceil(textura.width/squaresz)
		nposbinsY = math.ceil(textura.height/squaresz)
		posbins = nposbinsX*nposbinsY
		--assert(pbins == posbins,"posbins "..posbins.." pbins "..pbins)
		print("posbins",posbins,pbins,"XxY", nposbinsX,nposbinsY,"squaresz",squaresz)
		--squareszdirty = true
		self:calc()
		self:cum_calc()
		self:stdev_calc()
	end
	function hist:set_texture(text,newmesh)
		squaresz = nil --setposbins will trigger calc
		if not textura or newmesh or text.width ~= textura.width or text.height ~= textura.height then
			-- creates a gl list for a basic quad GPGPU 
			print"create new mesh"
			if quad_list then quad_list:delete() end
			quad_list = DoMESH(text.width, text.height,programfx);
		end
		textura = text
	end
	function hist:stdev_calc(fb,fbcum)
		if not fbostdev then
			fbostdev = GL:initFBO({no_depth=true},1,maxposbins)
		end
		fb = fb or fbohist
		fbcum = fbcum or fbostdev
		
		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		glext.glUseProgram(pr_stdev.program);
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbcum.fb[0]);
		glext.glActiveTexture(glc.GL_TEXTURE0);
		gl.glBindTexture(glc.GL_TEXTURE_2D, fb.color_tex[0])
		
		gl.glViewport(0, 0, 1, posbins)
		
		gl.glDisable(glc.GL_DEPTH_TEST);
		
		pr_stdev.unif.MVP:set(mat.ortho(0.0, 1, 0.0, posbins, -1, 1).gl)
		pr_stdev.unif.hist:set{0}
		pr_stdev.unif.nbins:set{nbins}
		
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
		
		DoQuad(1,posbins,pr_stdev)

		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
	end
	function hist:cum_calc(args)
		args = args or NMamp
		if not fbocumhist then
			fbocumhist = GL:initFBO({no_depth=true},nbins,maxposbins)
		end
		local fb = fbohist
		local fbcum = fbocumhist
		
		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		glext.glUseProgram(pr_cum.program);
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbcum.fb[0]);
		glext.glActiveTexture(glc.GL_TEXTURE0);
		gl.glBindTexture(glc.GL_TEXTURE_2D, fb.color_tex[0])
		
		gl.glViewport(0, 0, nbins, posbins)
		
		gl.glDisable(glc.GL_DEPTH_TEST);
		
		pr_cum.unif.MVP:set(mat.ortho(0.0, nbins, 0.0, posbins, -1, 1).gl)
		pr_cum.unif.hist:set{0}
		pr_cum.unif.alfa:set{args.alfa}
		pr_cum.unif.beta:set{args.beta}
		
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
		
		DoQuad(nbins,posbins,pr_cum)

		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
		alfabetadirty = false
	end
	function hist:calc_finish()
		
		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		glext.glUseProgram(pr_finish.program);
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbohist.fb[0]);
		glext.glActiveTexture(glc.GL_TEXTURE0);
		gl.glBindTexture(glc.GL_TEXTURE_2D, fbohist0.color_tex[0])
		
		gl.glViewport(0, 0, nbins, posbins)
		
		gl.glDisable(glc.GL_DEPTH_TEST);
		
		pr_finish.unif.MVP:set(mat.ortho(0.0, nbins, 0.0, posbins, -1, 1).gl)
		pr_finish.unif.hist:set{0}
		
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
		
		DoQuad(nbins,posbins,pr_finish)

		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
	end
	function hist:calc()
		if not inited then self:init() end
		
		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		glext.glUseProgram(programfx.program);
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbohist0.fb[0]);
		glext.glActiveTexture(glc.GL_TEXTURE0);
		gl.glBindTexture(glc.GL_TEXTURE_2D, textura.tex) --fbo.color_tex[0])
		local modewrap = glc.GL_MIRRORED_REPEAT --glc.GL_REPEAT --glc.GL_MIRRORED_REPEAT
		
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
		
		programfx.unif.tex0:set{0}
		--programfx.unif.squaresz:set{squaresz}
		programfx.unif.nposbinsX:set{nposbinsX}
		programfx.unif.nposbinsY:set{nposbinsY}
		programfx.unif.posbins:set{posbins}
		programfx.unif.color_mode:set{NMamp.color_mode}
		
		gl.glViewport(0, 0, nbins, posbins)
		
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
		
		gl.glEnable(glc.GL_BLEND)
		gl.glBlendFunc(glc.GL_ONE,glc.GL_ONE)
		glext.glBlendEquation(glc.GL_FUNC_ADD)
		gl.glDisable(glc.GL_DEPTH_TEST);
		
		quad_list:draw(glc.GL_POINTS)

		gl.glDisable(glc.GL_BLEND)
		
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
		
		self:calc_finish()
		squareszdirty = false
	end

	function hist:Show(w,h,scale,fbo)
		if squareszdirty then self:calc();self:cum_calc();squareszdirty=false end
		scale = scale or 100
		fbo = fbo or fbohist
		glext.glUseProgram(programhistoshow.program);
		programhistoshow.unif.scale:set{scale}
		programhistoshow.unif.tex0:set{0}
		programhistoshow.unif.nbins:set{nbins}
		programhistoshow.unif.nposbins:set{posbins}
		gl.glEnable(glc.GL_BLEND)
		gl.glBlendFunc(glc.GL_ONE,glc.GL_ONE)
		glext.glBlendEquation(glc.GL_FUNC_ADD)
		gl.glDisable(glc.GL_DEPTH_TEST);
		ShowTex(fbo.color_tex[0],w,h,programhistoshow)
		gl.glDisable(glc.GL_BLEND)
	end

	function hist:HEq(srgb,args)
		args = args or NMamp
		if alfabetadirty then self:cum_calc(); end
		glext.glUseProgram(pr_he.program);
		glext.glActiveTexture(glc.GL_TEXTURE1);
		gl.glBindTexture(glc.GL_TEXTURE_2D, fbocumhist.color_tex[0]) --fbo.color_tex[0])
		
		glext.glActiveTexture(glc.GL_TEXTURE2);
		gl.glBindTexture(glc.GL_TEXTURE_2D, fbostdev.color_tex[0])
		
		pr_he.unif.tex0:set{0}
		pr_he.unif.cumhist:set{1}
		pr_he.unif.stdev:set{2}
		pr_he.unif.fac:set{args.fac}
		pr_he.unif.facdev:set{args.fac2}
		pr_he.unif.facadddev:set{args.facadd2}
		pr_he.unif.doit:set{args.doit}
		pr_he.unif.do_postprocess:set{args.do_postprocess}
		pr_he.unif.nposbinsX:set{nposbinsX}
		pr_he.unif.nposbinsY:set{nposbinsY}
		pr_he.unif.ampL:set{args.ampL}
		pr_he.unif.ampR:set{args.ampR}
		pr_he.unif.black:set{args.black}
		pr_he.unif.white:set{args.white}
		pr_he.unif.saturation:set{args.saturation}
		pr_he.unif.color_mode:set{NMamp.color_mode}
		--SetSRGB(srgb)
		pr_he.unif.MVP:set(mat.ortho(0.0, 1, 0.0, posbins, -1, 1).gl)
		ShowTex(textura.tex,textura.width,textura.height,pr_he)
		
		gl.glDisable(glc.GL_FRAMEBUFFER_SRGB)
	end
	local texsign
	function hist:process(srctex)
		gl.glDisable(glc.GL_DEPTH_TEST);
		if not texsign or texsign~=srctex:get_signature() then
			self:set_texture(srctex)
			texsign = srctex:get_signature()
		end
		hist:setposbins()
		hist:HEq(argos)
		--gl.glEnable(glc.GL_DEPTH_TEST);
	end
	GL:add_plugin(hist,"lhistStarkLab")
	return hist
end

return Histogram


