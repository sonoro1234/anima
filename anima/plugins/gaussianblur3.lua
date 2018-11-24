--local ut = require"glutils.common"
local plugin = require"anima.plugins.plugin"
local vert_std = [[

void main()
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = ftransform();
}

]]
local frag_std = [[
uniform sampler2D tex0;

void main()
{

	gl_FragColor = texture2D(tex0,gl_TexCoord[0].st);
}
]]


--http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/


--linear versions
local fragH2 = [[
#version 330 core
#define MAXSIZE 40
uniform sampler2D image;
uniform float w;
uniform float h;

out vec4 FragmentColor;

uniform int size = 3;
uniform float offset[MAXSIZE]; //= float[]( 0.0, 1.3846153846, 3.2307692308 );
uniform float weight[MAXSIZE]; //= float[]( 0.2270270270, 0.3162162162, 0.0702702703 );

void main(void)
{
	vec4 orig_color = texture2D( image, vec2(gl_FragCoord)/vec2(w,h) );
	vec4 blured_color = orig_color * weight[0];
	for (int i=1; i<size; i++) {
		vec4 temp = texture2D( image, ( vec2(gl_FragCoord)+vec2(offset[i], 0.0) )/vec2(w,h)) + texture2D( image, ( vec2(gl_FragCoord)-vec2(offset[i], 0.0) )/vec2(w,h) );
		blured_color += temp * weight[i];
	}
	FragmentColor = blured_color;
}

]]

local fragV2 = [[
#version 330 core
#define MAXSIZE 40
uniform sampler2D image;
uniform float w;
uniform float h;
out vec4 FragmentColor;

uniform int size = 3;
uniform float offset[MAXSIZE];// = float[]( 0.0, 1.3846153846, 3.2307692308 );
uniform float weight[MAXSIZE];// = float[]( 0.2270270270, 0.3162162162, 0.0702702703 );

void main(void)
{
	vec4 orig_color = texture2D( image, vec2(gl_FragCoord)/vec2(w,h) );
	vec4 blured_color = orig_color * weight[0];
	for (int i=1; i<size; i++) {
		vec4 temp = texture2D( image, ( vec2(gl_FragCoord)+vec2(0.0, offset[i]) )/vec2(w,h) ) + texture2D( image, ( vec2(gl_FragCoord)-vec2(0.0, offset[i]) )/vec2(w,h) );
		blured_color += temp * weight[i];
	}
	FragmentColor = blured_color;
}

]]

local function genlinearkernel(radio,nstdevs)
	nstdevs = nstdevs or 3
	local kernel = {}
	local sigma = radio/nstdevs
	local size = math.ceil(radio)

	for  x = 0, size do 
		kernel[x+1] =  math.exp( -0.5 * (math.pow((x)/sigma, 2.0) ) )/ (math.sqrt(2 * math.pi) * sigma ) ;
	end
	local sum = kernel[1]
	for i=2,#kernel do
		sum = sum + kernel[i]*2
	end
	for i=1,#kernel do
		kernel[i] = kernel[i]/sum
	end
	local kk = {}
	kk[1] = kernel[1]
	local off2 = {}
	off2[1] = 0
	for i=2,#kernel-1,2 do
		kk[#kk+1] = kernel[i] + kernel[i+1]
		off2[#off2 +1] = ((i-1)*kernel[i] + i*kernel[i+1])/kk[#kk]
	end
	return kk,off2
end
local function BlurClipMaker(GL)
	local ANCHO,ALTO = GL.W,GL.H
	local plugin = require"anima.plugins.plugin"
	local Clip = plugin.new{res={GL.W,GL.H}}
	local programH, programV,programstd
	local kernel,offs
	local mixfbos = {}
	local NM = GL:Dialog("blur",{
	{"stdevs",2.5,guitypes.val,{min=1,max=4},function(val,this) 
			--kernel,offs = genlinearkernel(this.radio,val) 
			Clip:update()
		end},
	{"radio",10,guitypes.val,{min=1,max=39*2},function(val,this) 
			--kernel,offs = genlinearkernel(val,this.stdevs) 
			Clip:update()
		end},
	}
	)
	Clip.NM = NM
	NM.plugin = Clip
	local old_radio,old_stdevs
	function Clip.init()
		print"gaussianblur init"
		programH = GLSL:new():compile(nil,fragH2);
		programV = GLSL:new():compile(nil,fragV2);
		programstd = GLSL:new():compile(vert_std,frag_std);
		mixfbos[0] = initFBO(ANCHO,ALTO)
		mixfbos[1] = initFBO(ANCHO,ALTO)
		--kernel,offs = genlinearkernel(NM.radio,NM.stdevs)
		Clip:update()
		-- old_radio = NM.radio
		-- old_stdevs = NM.stdevs
		Clip.inited = true
	end
	function Clip:update()
		if old_radio~=NM.radio or old_stdevs~=NM.stdevs then
			--print"doing update"
			kernel,offs = genlinearkernel(NM.radio,NM.stdevs)
			old_radio = NM.radio
			old_stdevs = NM.stdevs
			NM.dirty = true
		end
	end
	
	function Clip:process(srctex,w,h)
		local w,h = w or self.res[1],h or self.res[2] --srctex.width,srctex.height
		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
			
			mixfbos[0]:Bind()
			srctex:draw(0,w,h)
			
			programH:use()
			mixfbos[1]:Bind()
			mixfbos[0]:UseTexture(0)
			--srctex:Bind(0)
			programH.unif.image:set{0}
			programH.unif.w:set{w}
			programH.unif.h:set{h}
			programH.unif.size:set{#kernel}
			programH.unif.offset:set(offs,true)
			programH.unif.weight:set(kernel,true)
			
			gl.glClearColor(0.0, 0.0, 0.0, 0)
			ut.Clear()
			
			ut.project(w,h)
			ut.DoQuad(w,h)
			
			programV:use()
			--mixfbos[0]:Bind()
			glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
			mixfbos[1]:UseTexture(0)
			programV.unif.image:set{0}
			programV.unif.w:set{w}
			programV.unif.h:set{h}
			programV.unif.size:set{#kernel}
			programV.unif.offset:set(offs,true)
			programV.unif.weight:set(kernel,true)
			
			gl.glClearColor(0.0, 0.0, 0.0, 0)
			ut.Clear()
			
			ut.project(w,h)
			ut.DoQuad(w,h)

		
		-- programstd:use()
		-- glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
		-- mixfbos[0]:UseTexture(0)
		
		-- gl.glClearColor(0.0, 0.0, 0.0, 0)
		-- ut.Clear()
			
		-- ut.project(w,h)
		-- ut.DoQuad(w,h)

	end
	function Clip:draw(timebegin,w,h,args)
		if not self.inited then self.init() end
		plugin.get_args(NM, args, timebegin)
		local theclip = args.clip

		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		mixfbos[0]:Bind()

		theclip[1]:draw(timebegin, w, h,theclip)
		--prtable(kernel,offs)
		--for i=1,NM.iters do
			programH:use()
			mixfbos[1]:Bind()
			mixfbos[0]:UseTexture(0)
			programH.unif.image:set{0}
			programH.unif.w:set{w}
			programH.unif.h:set{h}
			programH.unif.size:set{#kernel}
			programH.unif.offset:set(offs,true)
			programH.unif.weight:set(kernel,true)
			
			gl.glClearColor(0.0, 0.0, 0.0, 0)
			ut.Clear()
			
			ut.project(w,h)
			ut.DoQuad(w,h)
			
			programV:use()
			mixfbos[0]:Bind()
			mixfbos[1]:UseTexture(0)
			programV.unif.image:set{0}
			programV.unif.w:set{w}
			programV.unif.h:set{h}
			programV.unif.size:set{#kernel}
			programV.unif.offset:set(offs,true)
			programV.unif.weight:set(kernel,true)
			
			gl.glClearColor(0.0, 0.0, 0.0, 0)
			ut.Clear()
			
			ut.project(w,h)
			ut.DoQuad(w,h)
		--end
		
		programstd:use()
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
		mixfbos[0]:UseTexture(0)
		
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		ut.Clear()
			
		ut.project(w,h)
		ut.DoQuad(w,h)

	end
	GL:add_plugin(Clip)
	return Clip
end


--[=[
require"anima"
local GL = GLcanvas{H=800,aspect=2/3}
local blur = BlurClipMaker(GL,{size=2})
-- local blur = require"anima.plugins.gaussianblur"(GL)
--local LM = require"anima.plugins.layermixer_blend"
--local themixer = LM.layers_mixer(GL,true)
local tex
function GL.init()
	tex = GL:Texture():Load[[C:\luaGL\frames_anima\7thDoor\puertas\_MG_4250.tif]]
	--cliplist = LM.layers_seq:new({{0,200,clip={blur,clip={tex}}}} )
	GL:DirtyWrap()
end
function GL.draw(t,w,h)
	blur:process(tex)
	-- blur:draw(t,w,h,{clip={tex}})
	-- themixer:draw(t,w,h,{animclips=cliplist})
end
GL:start()
--]=]

return BlurClipMaker