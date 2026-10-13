


local vert_shad = [[
//version 130
uniform sampler2D tex0;
uniform float nbins;
float binwidth = 1.0/nbins;
float halfbw = binwidth*0.5;
uniform vec3 lumin = vec3( 0.30, 0.59, 0.11);
in vec3 position;
out vec4 color;
//float minpos = -1+2.0/nbins;
void main()
{

	vec4 col = texelFetch(tex0, ivec2(position.xy), 0);
	float lum = dot(col.rgb,lumin);
	//lum = lum*(nbins-1.0)/nbins; //from [0,1] to [0,1)
	//lum = lum - (lum/nbins); //from [0,1] to [0,1)
	lum = clamp(lum, halfbw, 1.0-halfbw); //clamp to center of first and last bins
	gl_Position = vec4((lum - 0.5)*2.0, 0, 0.0, 1.0); //from [0.1] to [-1.1] 
	//float pos = max(minpos,lum*2.0-1.0);//,-1) ;
	//gl_Position = vec4(pos, 0, 0.5, 1.0);
	//gl_Position = vec4(0, 0, 0.0, 1.0); //from [0.1) to [-1.1) ndc
	color = vec4(1.0,0.0,0.0,1.0);
}

]]


local frag_shad = [[
//version 130
uniform sampler2D tex0;
// Get the size of the texture :
ivec2 sz = textureSize(tex0, 0);
// Prepare normalization constant :
float nrm = 1.0/float(sz.s*sz.t);
out vec4 fcolor;
in vec4 color;
void main()
{
	fcolor = color * nrm;  
}
]]

local vert_histoshow = [[
uniform mat4 MVP;
in vec3 position;
in vec2 texcoords;
out vec4 tcoordf;
void main(){
	tcoordf = vec4(texcoords,0,1);
	gl_Position = MVP*vec4(position,1);
}

]]
local frag_histoshow = [[
uniform sampler2D tex0,hist;
uniform float scale ;
out vec4 fcolor;
in vec4 tcoordf;
void main(){
	float hh;
	vec2 pos = tcoordf.st;
	ivec2 sz = textureSize(tex0, 0);
	
	//vec4 colh = texture2D(tex0,vec2(pos.s,0));
	vec4 colh = texelFetch(tex0, ivec2(floor(pos.s * sz.s + 0.5),0), 0);
	if(pos.t < colh.r*scale) //(1.0-colh.r*scale) )
		hh = 1.0;
	else
		hh = 0.0;
	fcolor = vec4(vec3(hh),1);//col;
}
]]

local vert_texshow = [[
uniform sampler2D hist;
uniform float fac;
out float mini;
out float maxi;
out vec4 tcoordf;
uniform mat4 MVP;
in vec3 position;
in vec2 texcoords;
void main()
{
	int nbins = textureSize(hist,0).s;
	vec4 scol = vec4(0.0);
	for(int i=0;i<nbins; i++){
		scol += texelFetch(hist, ivec2(i,0), 0);
		if (scol.r >= fac){
			mini = float(i)/float(nbins-1);
			break;
		}
	}
	scol = vec4(0.0);
	for(int i=nbins-1;i>=0; i--){
		scol += texelFetch(hist, ivec2(i,0), 0);
		if (scol.r >= fac){
			maxi = float(i)/float(nbins-1);
			break;
		}
	}
	tcoordf = vec4(texcoords,0,1);
	gl_Position = MVP*vec4(position,1);
}

]]

local frag_texshow = [[
in float mini;
in float maxi;	
uniform sampler2D tex0;
out vec4 fcolor;
in vec4 tcoordf;
void main(){
	
	vec2 pos = tcoordf.st;
	vec3 col = texture2D(tex0,pos).rgb;
	
	fcolor = vec4((col - mini)/(maxi - mini),1.0);
}

]]

local vert_cum = [[
//out vec4 tcoordf;
in vec3 position;
uniform mat4 MVP;
void main()
{
	//tcoordf = gl_MultiTexCoord0;
	gl_Position = MVP*vec4(position,1);
}
]]

local frag_cum = [[
uniform sampler2D hist;
out vec4 fcolor;
void main()
{
	vec4 acum = vec4(0.0);
	for(int i=0;i<=gl_FragCoord.s;i++)
		acum += texelFetch(hist,ivec2(i,0),0);
	fcolor = acum;
	//fcolor = vec4(1.0); //texelFetch(hist,ivec2(gl_FragCoord.s,0),0);
}

]]

local vert_he = vert_histoshow


local frag_he = [[
uniform sampler2D cumhist,tex0;
uniform bool doit;
vec3 lumin = vec3( 0.30, 0.59, 0.11);
out vec4 fcolor;
in vec4 tcoordf;
void main()
{
	
	ivec2 sz = textureSize(cumhist,0);
	vec3 col = texture2D(tex0, tcoordf.st).rgb;
	float lum = dot(col, lumin);
	//float targ_lum  = texelFetch(cumhist, ivec2(floor(lum*(sz.s-1)),0),0).r;
	
	float targ_lum1  = texelFetch(cumhist, ivec2(floor(lum*(sz.s-1)),0),0).r;
	float targ_lum2  = texelFetch(cumhist, ivec2(min(floor(lum*(sz.s-1))+1,sz.s-1),0),0).r;
	//float targ_lum2  = texelFetch(cumhist, ivec2(floor(lum*(sz.s-1))+1,0),0).r;
	float targ_lum = mix(targ_lum1,targ_lum2,fract(lum*(sz.s-1)));
	
	if(doit)
		fcolor = vec4(col*targ_lum/lum,1.0);
	else	
		fcolor = vec4(col,1.0);
}

]]
local function OtsuThreshold(prob,nbins)

	local omega = ffi.new("float[?]",nbins)
	local mu = ffi.new("float[?]",nbins)
	omega[0] = prob[0]
	mu[0] = 0
	for i=1,nbins-1 do
		omega[i] = omega[i-1] + prob[i]
		mu[i] = mu[i-1] + i * prob[i]
	end
	local sigma = ffi.new("float[?]",nbins)
	local max_sigma = 0
	local threshold = 0
	for i=1,nbins-1 do
		if (omega[i] ~= 0.0 and omega[i] ~= 1.0 and i<nbins-2) then
			--sigma[i] = ((mu[nbins-1] * omega[i] - mu[i])^2)/ (omega[i] * (1.0 - omega[i]));
			--value = ((mi_max*w_k - mi_k)*(mi_max*w_k - mi_k))/(w_k*(1-w_k));
			sigma[i] = ((mu[nbins-1]*omega[i] - mu[i])*(mu[nbins-1]*omega[i] - mu[i]))/(omega[i]*(1-omega[i]));
		else
			sigma[i] = 0.0;
		end
		if sigma[i] > max_sigma then
			max_sigma = sigma[i];
			threshold = i;
		end
	end
	return threshold/nbins, sigma
end

local function DoMESH(w, h,prog)
print("DoMESH",w, h,prog)
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
local function ShowTex(tex,w,h)
	
	local modewrap = glc.GL_MIRRORED_REPEAT --glc.GL_CLAMP --glc.GL_REPEAT --glc.GL_MIRRORED_REPEAT
	
	glext.glActiveTexture(glc.GL_TEXTURE0);
	gl.glEnable( glc.GL_TEXTURE_2D );
	gl.glBindTexture(glc.GL_TEXTURE_2D, tex)
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
	
	gl.glMatrixMode(glc.GL_PROJECTION)
	gl.glLoadIdentity()
	gl.glOrtho(0.0, w, 0.0, h, -1, 1);
	gl.glMatrixMode(glc.GL_MODELVIEW)
	gl.glLoadIdentity();
	gl.glViewport(0, 0, w, h)
	ut.DoQuad(w,h)
end


local function SetSRGB(srgb)
	local framebuffer = ffi.new("GLint[1]",0)
	gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, framebuffer)
	if srgb and framebuffer[0]== 0 then
		gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
	end
end
local function Histogram(GL,nbins)
	nbins = nbins or 400
	--local plugin = require"anima.plugins.plugin"
	local hist = {} --plugin.new(nil,GL)

	local fbohist, programfx,programhistoshow,programtexshow,pr_cum,pr_he
	local pr_cum_vao,programhistoshow_vao
	local fbocumhist
	local quad_list, textura
	local inited = false
	function hist:init()
		if inited then return end
		programfx = GLSL:new():compile(vert_shad,frag_shad)
		programhistoshow = GLSL:new():compile(vert_histoshow,frag_histoshow)
		programhistoshow_vao = mesh.quad(0,0,GL.W,GL.H):vao(programhistoshow)
		programtexshow = GLSL:new():compile(vert_texshow,frag_texshow)
		pr_cum = GLSL:new():compile(vert_cum,frag_cum)
		pr_cum_vao = mesh.quad(0,0,nbins,1):vao(pr_cum)
		pr_he = GLSL:new():compile(vert_he,frag_he)
		fbohist = GL:initFBO({no_depth=true},nbins,1)
		self.fbohist = fbohist
		inited = true
		
	end
	function hist:newhist()
		return GL:initFBO({no_depth=true},nbins,1)
	end
	function hist:Getcumhist()
		return fbocumhist
	end
	function hist:get_histo()
		local histovalues = ffi.new("float[?]",nbins)
		fbohist:get_pixels(glc.GL_RED,glc.GL_FLOAT,0,histovalues)
		return histovalues
	end
	function hist:OtsuThreshold()
		if not textura then return 0.5 end
		return OtsuThreshold(hist:get_histo(),nbins)
	end
	function hist:set_texture(text)
		if not inited then self:init() end
		if not textura or textura.width~=text.width or textura.height~=text.height then
			-- creates a gl list for a basic quad GPGPU 
			--print("do qual list")
			if quad_list then quad_list:delete() end
			--quad_list = gl.glGenLists(1);
			--gl.glNewList(quad_list, glc.GL_COMPILE);
			quad_list = DoMESH(text.width, text.height,programfx);
			--gl.glEndList();  
		end
		textura = text
	end
	function hist:cum_calc(fb,fbcum)
		if not fbocumhist then
			fbocumhist = GL:initFBO({no_depth=true},nbins,1)
		end
		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		fb = fb or fbohist
		fbcum = fbcum or fbocumhist
		glext.glUseProgram(pr_cum.program);
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbcum.fb[0]);
		glext.glActiveTexture(glc.GL_TEXTURE0);
		gl.glBindTexture(glc.GL_TEXTURE_2D, fb.color_tex[0])
		
		-- gl.glMatrixMode(glc.GL_PROJECTION)
		-- gl.glLoadIdentity()
		-- gl.glOrtho(0.0, nbins, 0.0, 1, -1, 1);
		-- gl.glMatrixMode(glc.GL_MODELVIEW)
		-- gl.glLoadIdentity();
		local MVP = mat.ortho(0.0, nbins, 0.0, 1, -1, 1)
		pr_cum.unif.MVP:set(MVP.gl)
		gl.glViewport(0, 0, nbins, 1)
		
		gl.glDisable(glc.GL_DEPTH_TEST);
		
		pr_cum.unif.hist:set{0}
		
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
		
		pr_cum_vao:draw_elm()
		--ut.DoQuad(nbins,1)

		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
	end
	local histr,histg,histb
	function hist:calc_rgb()
		if not histr then
			histr = GL:initFBO({no_depth=true},nbins,1)
			histg = GL:initFBO({no_depth=true},nbins,1)
			histb = GL:initFBO({no_depth=true},nbins,1)
		end
		-- self:calc(histr, mat.vec3(0.3,0,0))
		-- self:calc(histg, mat.vec3(0,0.59,0))
		-- self:calc(histb, mat.vec3(0,0,0.11))
		self:calc(histr, mat.vec3(1,0,0))
		self:calc(histg, mat.vec3(0,1,0))
		self:calc(histb, mat.vec3(0,0,1))
	end
	function hist:get_rgb()
		return histr,histg,histb
	end
	function hist:calc(fbo, lumin)
		if not inited then self:init() end
		fbo = fbo or fbohist
		
		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		glext.glUseProgram(programfx.program);
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbo.fb[0]);
		glext.glActiveTexture(glc.GL_TEXTURE0);
		gl.glBindTexture(glc.GL_TEXTURE_2D, textura.tex) --fbo.color_tex[0])
		local modewrap = glc.GL_CLAMP_TO_EDGE --glc.GL_REPEAT --glc.GL_MIRRORED_REPEAT
	
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
	
		programfx.unif.tex0:set{0}
		programfx.unif.nbins:set{nbins}
		if lumin then 
			programfx.unif.lumin:set(lumin:gl())
		else
			programfx.unif.lumin:set(mat.vec3(0.30, 0.59, 0.11):gl())
		end
		-- programfx.unif.h:set{h}
	
		--gl.glMatrixMode(glc.GL_PROJECTION)
		--gl.glLoadIdentity()
		--gl.glOrtho(0.0, w, 0.0, h, -1, 1);
		--gl.glMatrixMode(glc.GL_MODELVIEW)
		--gl.glLoadIdentity();
		gl.glViewport(0, 0, nbins, 1)
	
		gl.glEnable(glc.GL_BLEND)
		gl.glBlendFunc(glc.GL_ONE,glc.GL_ONE)
		glext.glBlendEquation(glc.GL_FUNC_ADD)
		gl.glDisable(glc.GL_DEPTH_TEST);
	
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
		gl.glPointSize(1)
		quad_list:draw(glc.GL_POINTS)

		gl.glDisable(glc.GL_BLEND)
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
		gl.glPointSize(1)
	end
	function hist:Show(w,h,scale,fbo)
		scale = scale or 1
		fbo = fbo or fbohist
		programhistoshow:use()
		programhistoshow.unif.scale:set{scale}
		gl.glEnable(glc.GL_BLEND)
		gl.glBlendFunc(glc.GL_ONE,glc.GL_ONE)
		--glext.glBlendEquation(glc.GL_MAX) --(glc.GL_FUNC_ADD)
		glext.glBlendEquation(glc.GL_FUNC_REVERSE_SUBTRACT)
		gl.glDisable(glc.GL_DEPTH_TEST);
		
		--fbo:UseTexture(0)
		local tex = fbo:tex()
		tex:Bind(0):set_wrap()
		local MVP = mat.ortho(0.0, w, 0.0, h, -1, 1);
		programhistoshow.unif.MVP:set(MVP.gl)
		gl.glViewport(0,0,w,h)
		programhistoshow_vao:draw_elm()

		gl.glDisable(glc.GL_BLEND)
	end
	function hist:ShowPos(x,y,w,h,scale,fbo)
		scale = scale or 1
		fbo = fbo or fbohist
		glext.glUseProgram(programhistoshow.program);
		programhistoshow.unif.scale:set{scale}
		gl.glEnable(glc.GL_BLEND)
		gl.glBlendFunc(glc.GL_ONE,glc.GL_ONE)
		--glext.glBlendEquation(glc.GL_MAX) --(glc.GL_FUNC_ADD)
		glext.glBlendEquation(glc.GL_FUNC_REVERSE_SUBTRACT)
		gl.glDisable(glc.GL_DEPTH_TEST);
		
		ut.ShowTexPos(fbo.color_tex[0],x,y,w,h)
		
		gl.glDisable(glc.GL_BLEND)
	end
	--equalizes histogram searching min and max thresholds according to fac value
	function hist:ShowTex(w,h,fac,srgb)
		programtexshow:use()
		fbohist:UseTexture(1,0)
		programtexshow.unif.tex0:set{0}
		programtexshow.unif.hist:set{1}
		programtexshow.unif.fac:set{fac}
		
		
		textura:Bind(0)
		textura:set_wrap()
		local MVP = mat.ortho(0.0, w, 0.0, h, -1, 1);
		programtexshow.unif.MVP:set(MVP.gl)
		gl.glViewport(0,0,w,h)
		programhistoshow_vao:draw_elm()
		
	end
	
	function hist:HEq(w,h,doit,srgb)
		pr_he:use()
		fbocumhist:UseTexture(1,0)
		pr_he.unif.tex0:set{0}
		pr_he.unif.cumhist:set{1}
		pr_he.unif.doit:set{doit >0}
		
		textura:Bind(0)
		textura:set_wrap()
		local MVP = mat.ortho(0.0, w, 0.0, h, -1, 1);
		programtexshow.unif.MVP:set(MVP.gl)
		gl.glViewport(0,0,w,h)
		programhistoshow_vao:draw_elm()
		
	end
	
	--GL:add_plugin(hist,"hist") --dont has NM so 
	return hist
end

---[=[
if not ... then
require"anima"
local GL = GLcanvas{H=2^10,aspect=1,profile="CORE",use_log=true}
local Histogram1 --= Histogram(GL,400)
local archivo = [[C:\LuaGL\frames_anima\pelis\humanoides_peli\compressed1080\ninos\ninos-001.cmp]]
--archivo = [[C:\LuaGL\media\BWramp.png]]
local NM = GL:Dialog("hist",{
{"fac",0,guitypes.val,{min=0,max=0.9}},
{"scale",10,guitypes.val,{min=0,max=10}},
{"val",0,guitypes.val,{min=0,max=1}}
})

-- local Hist,Hi=gui.Histogram(GL,2^5)
-- function GL.imgui()
  -- Hist()
-- end
local TP = require"anima.plugins.texture_processor"(GL,0)
local fbo
function GL.init()
	local textura1 = GL:Texture():Load(archivo)--,srgb)
	GL:set_WH(textura1.width,textura1.height)
	Histogram1 = Histogram(GL,400)
	Histogram1:set_texture(textura1)
	Histogram1:calc()
	--Histogram1:cum_calc()
	fbo = GL:initFBO({no_depth=true})
	TP:set_process[[vec4 process(vec2 pos){
		return vec4(vec3(pos.x),1.0);
	}
	]]
end

function GL.draw(t,w,h)
	gl.glClearColor(NM.val,NM.val,NM.val,1)
	ut.Clear()
	TP:process{}
end
function GL.drawNN(t,w,h)
	gl.glClearColor(NM.val,NM.val,NM.val,1)
	fbo:Bind()
	ut.Clear()
	fbo:UnBind()
	gl.glClearColor(1,1,1,1)
	ut.Clear()
	--Histogram1:HEq(w,h,1)
	Histogram1:set_texture(fbo:tex())
	Histogram1:calc()
	--Histogram1:ShowTex(w,h,NM.fac)
	Histogram1:Show(w,h,NM.scale)
end
GL:start()
end
--]=]
 
return Histogram
