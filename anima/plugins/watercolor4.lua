local vert_std = [[
uniform mat4 MVP;
in vec3 position;
in vec2 texcoords;
out vec4 tcoordf;
	void main()
	{
		tcoordf = vec4(texcoords,0,1);
		gl_Position = MVP*vec4(position,1);
	}
	]]

local frag_sh = [[
// created by florian berger (flockaroo) - 2016
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// trying to resemble watercolors
uniform vec2 texres;

#define Res  iResolution.xy
//#define SHADERTOY
#ifdef SHADERTOY
#define Res0 iChannelResolution[0].xy
#define Res1 iChannelResolution[1].xy
#else
vec2 texres0 = textureSize(iChannel0,0).xy;
vec2 texres1 = textureSize(iChannel1,0).xy;
#define Res0 texres0
#define Res1 texres1
#endif

uniform sampler2D texgrad;
uniform bool paper=true;
#define PI 3.14159265358979

vec4 getColor(vec2 pos)
{
	return texture(iChannel0,pos/Res0);
}
float getBW(vec2 pos)
{
	return dot(texture(iChannel0,pos/Res0).xyz, vec3(0.299, 0.587, 0.114));
}
vec4 getCol(vec2 pos)
{
    vec2 uv=pos/Res0;
    vec4 c1 = texture(iChannel0,uv);
    vec4 c2 = vec4(0.4); // gray on greenscreen
	//vec4 c2 = vec4(1.5); // bright white on greenscreen
    float d = clamp(dot(c1.xyz,vec3(-0.5,1.0,-0.5)), 0.0, 1.0);
    return mix(c1,c2,1.8*d);
}

vec4 getCol2(vec2 pos)
{
    vec2 uv=pos/Res0;
    vec4 c1 = texture(iChannel0,uv);
    vec4 c2 = vec4(1.5); // bright white on greenscreen
    float d = clamp(dot(c1.xyz,vec3(-0.5,1.0,-0.5)), 0.0, 1.0);
    return mix(c1,c2,1.8*d);
}

vec3 getGrad(vec2 pos,float delta)
{
	return texture(texgrad, pos/Res).xyz;
}

vec4 getRand(vec2 pos) 
{
    vec2 uv=pos/Res1;
    return texture(iChannel1,uv).xzyw;
}

float htPattern(vec2 pos)
{

	float p;
    float r=getRand(pos*.4/.7).x;
  	p=clamp((pow(r + 0.3, 2.0) - 0.45),0.,1.);
    return p;
}

float getVal(vec2 pos)
{
    return length(getCol(pos).xyz);//+0.0001*length(pos-0.5*Res0);

}
float getVal2(vec2 pos)
{
    return length(getColor(pos).xyz);
}
    
vec4 getBWDist(vec2 pos)
{
    return vec4(smoothstep(.9,1.1,getVal(pos)*0.9 +htPattern(pos*.7)));
	//return vec4(smoothstep(.9,1.1,getBW(pos)*.9+htPattern(pos*.7)));
}
vec4 getBWDist2(vec2 pos)
{
    return vec4(smoothstep(.9,1.1,getVal2(pos)*.9+htPattern(pos*.7)));
	//return vec4(smoothstep(.9,1.1,getBW(pos)*.9+htPattern(pos*.7)));
}

uniform float SampNum =24;
#define OUTLINES
#define N(a) (a.yx*vec2(1,-1))
uniform float FFin = 1.5;
uniform float FFout = 1.5;
uniform float FF1 =1.0;
uniform float Fgr =1.0;
uniform float thresh = 1;
uniform float faccol = 1.0;
uniform bool do_stepl=true;
uniform float stepl = 0.0;
uniform float steph = 1.0;
uniform float faccol2 = 1.0;
uniform float mixfx = 1.0;
uniform float delta = 2.0;
uniform float gammafac = 1.0;
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
   //centered pos
   vec2 pos=((fragCoord-Res.xy*.5)/Res.y*Res0.y)+Res0.xy*.5;
	
	/*
	vec3 grTa =getGrad(pos, delta);
	float grla=clamp(Fgr*grTa.z,0.,1.);
	vec4 sal1 = vec4(mix(vec3(1.2),getBWDist2(pos).xyz*2.,grla),1);//vec4(getBWDist(pos));
	vec4 sal2 = vec4(mix(vec3(1.2),getBWDist(pos).xyz*2.,grla),1);
	fragColor = mix(sal1,sal2,mixfx);
	return;
	*/
	
	/*
		vec4 sal1 = getBWDist(pos);
		vec4 sal2 = (1-getBWDist2(pos))*getColor(pos);
		fragColor = mix(sal1,sal2,mixfx);
		return;
	*/
	
    vec2 pos2=pos;
    vec2 pos3=pos;
    vec2 pos4=pos;
    vec2 pos0=pos;
    vec3 col=vec3(0);
    vec3 col2=vec3(0);
    float cnt=0.0;
    float cnt2=0.;
    for(int i=0;i<SampNum;i++)
    {   
        float fact=1.-float(i)/float(SampNum);
		//float fact=1.-pow(float(i)/float(SampNum),gammafac);
		
		#ifdef OUTLINES
		// gradient for outlines (gray on green screen)
        vec3 grT =getGrad(pos, delta);
        vec3 gr2T=getGrad(pos2,delta);
		vec2 gr = grT.xy;
		vec2 gr2 = gr2T.xy;
		
		float grl=clamp(Fgr*grT.z,0.,1.);
        float gr2l=clamp(Fgr*gr2T.z,0.,1.);

        // outlines:
        // stroke perpendicular to gradient
        pos +=FF1*N(gr);
        pos2-=FF1*N(gr2);
        
        //col+=fact*mix(vec3(1.2),getBWDist(pos).xyz*2.,grl);
		//col+=fact*mix(vec3(1.2),getBWDist(pos2).xyz*2.,gr2l);
		col+=fact*mix(vec3(1.2),getBWDist(pos ).xyz*2.,smoothstep(thresh,1.0,grl));
        col+=fact*mix(vec3(1.2),getBWDist(pos2).xyz*2.,smoothstep(thresh,1.0,gr2l));
        #endif
		
        // gradient for wash effect (white on green screen)
        vec2 gr3=getGrad(pos3,delta).xy;
        vec2 gr4=getGrad(pos4,delta).xy;

        
		
        // colors + wash effect on gradients:
        // color gets lost from dark areas
        pos3+=FFin*gr3;
        // to bright areas
        pos4-=FFout*gr4;
        
		
        float f1=3.*fact;
        float f2=gammafac*(.7-fact);//4.*(.7-fact);

		
		col2+=f1*getColor(pos3).xyz;
        col2+=f2*getColor(pos4).xyz;
		
        cnt2+=f1+f2;
        cnt+=fact;
    }
    // normalize
	#ifdef OUTLINES
    col/=cnt*2.5;
	#else
	col = vec3(1);
	#endif
    col2/=cnt2;//*1.65;
	
	vec4 colororig = texture(iChannel0,pos0/Res0);
	
	if (do_stepl){
		//col = smoothstep(vec3(stepl), vec3(steph), col);
		//col = smoothstep(vec3(stepl), vec3(1.0), col);
		//col = step(vec3(stepl), col);
		float m = 1.0/(1.0-stepl);
		float b = stepl/(stepl-1.0);
		col = clamp(m*col + vec3(b),vec3(0.0),vec3(1.0));
		col = pow(col,vec3(steph));
	}
	
    col = mix(vec3(1),col,faccol);
	col2 = mix(vec3(1),col2,faccol2);
	
    // outline + color
    col = clamp(clamp(col*.9+.1,0.,1.)*col2,0.,1.);
	
    // paper color and grain
	///*
	if(paper){
		//col = col*vec3(.93,0.93,0.85)+.15*getRand(pos0*2.5).x;
        //*mix(texture(iChannel2,fragCoord.xy/iResolution.xy).xyz,vec3(1.2),.7)
        col += .1*getRand(pos0*2.5).x;
	
	
		// vignetting
		float r = length((fragCoord-iResolution.xy*.5)/iResolution.x);
		float vign = 1.-r*r*r*r;
		col *= vign;
	}
	//*/
	
	col = mix(colororig.rgb,col,mixfx);
	
	fragColor = vec4(col,1.0);
	
}


]]

local frag_grad = [[
#define Res  iResolution.xy
vec2 texres0 = textureSize(iChannel0,0).xy;
#define Res0 texres0
uniform float delta = 2.0;
float getBW(vec2 pos)
{
	return dot(texture(iChannel0,pos/Res0).xyz, vec3(0.299, 0.587, 0.114));
}
vec2 getGrad(vec2 pos,float delta)
{
    vec2 d=vec2(delta,0);

	return vec2(getBW(pos+d.xy)-getBW(pos-d.xy),
		getBW(pos+d.yx)-getBW(pos-d.yx)
	)/delta;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
   //centered pos
	vec2 pos=((fragCoord - Res.xy*.5)/Res.y*Res0.y)+Res0.xy*.5;
	vec2 gr = getGrad(pos, delta);
	float grl = length(gr);
	if (grl==0.0)
	fragColor = vec4(vec2(0.0),grl,1);
	else
	fragColor = vec4(normalize(gr),grl,1);
}
]]

local frag_unif =[[
uniform vec3      iResolution;           // viewport resolution (in pixels)
uniform float     iTime;           // shader playback time (in seconds)
uniform float     iTimeDelta;            // render time (in seconds)
uniform int       iFrame;                // shader playback frame
uniform float     iChannelTime[4];       // channel playback time (in seconds)
uniform vec3      iChannelResolution[4]; // channel resolution (in pixels)
uniform vec4      iMouse;                // mouse pixel coords. xy: current (if MLB down), zw: click
uniform sampler2D iChannel0;          // input channel. XX = 2D/Cube
uniform sampler2D iChannel1;          // input channel. XX = 2D/Cube
uniform vec4      iDate;                 // (year, month, day, time in seconds)
uniform float     iSampleRate;           // sound sample rate (i.e., 44100)

]]
local frag_main = [[
out vec4 fragColor;
vec2 fragCoord = gl_FragCoord.xy;
void main()
{
	mainImage(fragColor,fragCoord);
}
]]

require"anima"
local path = require"anima.path"
local vicim = require"anima.vicimag"
local plugin = require"anima.plugins.plugin"

function make(GL)
	
	local M = plugin.new(nil,GL)
local NM = GL:Dialog("watercolor",{
{"SampNum",2,guitypes.valint,{min=1,max=50}},
{"FFin",2,guitypes.val,{min=0,max=15}},
{"FFout",4,guitypes.val,{min=0,max=15}},
{"FF1",1,guitypes.val,{min=0,max=15}},
{"Fgr",5,guitypes.val,{min=0,max=15}},
{"thresh",0,guitypes.val,{min=0,max=1}},
{"do_stepl",false,guitypes.toggle},
{"stepl",0,guitypes.val,{min=0,max=1}},
{"steph",1,guitypes.val,{min=0,max=1}},
{"faccol",0.7,guitypes.val,{min=0,max=1}},
{"faccol2",1,guitypes.val,{min=0,max=1}},
{"mixfx",1,guitypes.val,{min=0,max=1}},
{"delta",1,guitypes.val,{min=0,max=4}},
{"gammafac",4,guitypes.val,{min=0,max=15}},
{"paper",false,guitypes.toggle},
})
	M.NM = NM
	local program,pgrad,textura_noise,fbo,blurfbo,blur,vao
	function M:Set_WH()
		fbo = GL:initFBO()
		fbograd = GL:initFBO()
		vao = mesh.quad(0,0,GL.W,GL.H):vao(program)
	end
function M:init()
	program = GLSL:new():compile(vert_std, frag_unif..frag_sh..frag_main)
	pgrad = GLSL:new():compile(vert_std, frag_unif..frag_grad..frag_main)
	vao = mesh.quad(0,0,GL.W,GL.H):vao(program)
	--textura = Texture():Load(path.this_script_path().."/canvas.png",false,true)
	--textura = Texture():Load([[c:\luaGL\media\estanque-001.jpg]],false,true)
	--textura = Texture():Load(path.this_script_path()..[[\_MG_5819.png]],false,true)
	--textura = Texture():Load([[G:\VICTOR\pelis\pelipino\master1080\muro\frame-0001.tif]],false,true)
	--textura = Texture():Load("c:/luagl/media/piscina.tif",false,true)
	textura_noise = vicim.vicimag2tex(path.file_path().."/noise2256.dat",GL)
	textura_noise:set_wrap(glc.GL_REPEAT)
	textura_noise:gen_mipmap()
	textura_noise:mag_filter(glc.GL_LINEAR)
	textura_noise:min_filter(glc.GL_LINEAR)
	fbo = GL:initFBO()
	fbograd = GL:initFBO()
end
function M:process(textura,w,h)
	w,h = w or M.res[1],h or M.res[2]

	fbograd:Bind()
	pgrad:use()
	local U = pgrad.unif
	U.iChannel0:set{0}
	textura:Bind(0)
	--blurtex:Bind(0)
	U.iResolution:set{w,h,10}
	U.delta:set{NM.delta}
	ut.Clear()
	local MVP = mat.ortho(0.0, w, 0.0, h, -1, 1);
	U.MVP:set(MVP.gl)
	gl.glViewport(0, 0, w, h)
	--ut.project(w,h)
	--ut.DoQuad(w,h)
	vao:draw_elm()
	fbograd:UnBind()
	local texgrad = fbograd:tex()
	
	--texgrad:drawcenter(0,w,h)
	--texgrad:togrey(w,h,{1,1,1,0})
	-- do return end
	---[[
	program:use()
	program.unif.iChannel0:set{0}
	program.unif.iChannel1:set{1}
	program.unif.texgrad:set{2}
	program.unif.iTime:set{t}
	program.unif.iResolution:set{w,h,10}
	program.unif.SampNum:set{NM.SampNum}
	program.unif.FFin:set{NM.FFin}
	program.unif.FFout:set{NM.FFout}
	program.unif.FF1:set{NM.FF1}
	program.unif.Fgr:set{NM.Fgr}
	program.unif.thresh:set{NM.thresh}
	program.unif.do_stepl:set{NM.do_stepl}
	program.unif.stepl:set{NM.stepl}
	program.unif.steph:set{NM.steph}
	program.unif.faccol:set{NM.faccol}
	program.unif.faccol2:set{NM.faccol2}
	program.unif.mixfx:set{NM.mixfx}
	program.unif.delta:set{NM.delta}
	program.unif.gammafac:set{NM.gammafac}
	program.unif.paper:set{NM.paper}
	--program.unif.texres:set{textura.width,textura.height}
	local xm,ym = unpack(GL.mouse_pos)
	program.unif.iMouse:set{xm,ym,GL.mouse_but[1],0}
	ut.Clear()
	--ut.project(w,h)
	program.unif.MVP:set(MVP.gl)
	gl.glViewport(0,0,w,h)
	textura:Bind(0)
	textura_noise:Bind(1)
	texgrad:Bind(2)
	--ut.DoQuad(w,h)
	vao:draw_elm()
	--]]
end
function M:draw(t,w,h,args)
	local theclip = args.clip
		fbo:Bind()
		theclip[1]:draw(t,w,h,theclip)
		fbo:UnBind()
		local textura = fbo:GetTexture()
	
	-- blur:process_fbo(blurfbo,textura)
	-- local blurtex = blurfbo:tex()
	
	fbograd:Bind()
	pgrad:use()
	local U = pgrad.unif
	U.iChannel0:set{0}
	textura:Bind(0)
	--blurtex:Bind(0)
	U.iResolution:set{w,h,10}
	U.delta:set{NM.delta}
	ut.Clear()
	local MVP = mat.ortho(0.0, w, 0.0, h, -1, 1);
	U.MVP:set(MVP.gl)
	gl.glViewport(0, 0, w, h)
	--ut.project(w,h)
	--ut.DoQuad(w,h)
	vao:draw_elm()
	fbograd:UnBind()
	local texgrad = fbograd:tex()
	
	--texgrad:togrey(w,h,{0,0,1})
	--return
	---[[
	program:use()
	program.unif.iChannel0:set{0}
	program.unif.iChannel1:set{1}
	program.unif.texgrad:set{2}
	program.unif.iTime:set{t}
	program.unif.iResolution:set{w,h,10}
	program.unif.SampNum:set{NM.SampNum}
	program.unif.FFin:set{NM.FFin}
	program.unif.FFout:set{NM.FFout}
	program.unif.FF1:set{NM.FF1}
	program.unif.Fgr:set{NM.Fgr}
	program.unif.thresh:set{NM.thresh}
	program.unif.faccol:set{NM.faccol}
	program.unif.faccol2:set{NM.faccol2}
	program.unif.mixfx:set{NM.mixfx}
	program.unif.delta:set{NM.delta}
	program.unif.gammafac:set{NM.gammafac}
	program.unif.paper:set{NM.paper}
	--program.unif.texres:set{textura.width,textura.height}
	local xm,ym = unpack(GL.mouse_pos)
	program.unif.iMouse:set{xm,ym,GL.mouse_but[1],0}
	ut.Clear()
	--ut.project(w,h)
	program.unif.MVP:set(MVP.gl)
	gl.glViewport(0,0,w,h)
	textura:Bind(0)
	textura_noise:Bind(1)
	texgrad:Bind(2)
	--ut.DoQuad(w,h)
	vao:draw_elm()
	--]]
end
	GL:add_plugin(M)
	return M
end

if not ... then
---[=[
print(path.this_script_path())
GL = GLcanvas{H=800,aspect=1.5,profileNO="CORE",DEBUG=true}
local tex,wcol

function GL.init()
	--tex = GL:Texture():Load([[c:\luagl\pelis\pelipino\master1080\muro\frame-0001.tif]],false,true)
	tex = GL:Texture():Load("c:/luagl/media/piscina.tif",false,true)
	GL:set_WH(tex.width, tex.height)
	wcol = make(GL)
	
	--GL:DirtyWrap()
end
function GL.draw(t,w,h)
	--wcol:draw(t,w,h,{clip={tex}})
	wcol:process(tex)

end
GL:start()
--]=]
end
--[=[
print(path.this_script_path())
GL = GLcanvas{H=1080,aspect=1.5}
local tex,wcol
local fbos = {}
local curr = 0
function GL.init()
	tex = GL:Texture():Load([[F:\VICTOR\pelis\pelipino\master1080\muro\frame-0001.tif]],false,true)
	wcol = make(GL)
	fbos[0] = GL:initFBO()
	fbos[1] = GL:initFBO()
	fbos[curr]:Bind()
	tex:draw(t,w,h)
	fbos[curr]:UnBind()
	curr = (curr+1)%2
	--GL:DirtyWrap()
end
function GL.draw(t,w,h)
	fbos[curr]:Bind()
	wcol:draw(t,w,h,{clip={fbos[(curr+1)%2]:tex()}})
	fbos[curr]:UnBind()
	fbos[curr]:tex():draw(t,w,h)
	curr = (curr+1)%2
end
GL:start()
--]=]
return make