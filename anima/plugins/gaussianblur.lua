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

local vert = [[
#version 330 core

in vec2 VertexPosition;

void main(void) {
	gl_Position = vec4(VertexPosition, 0.0, 1.0);
}
]]

--discrete versions
--http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
local fragH = [[
#version 330 core

uniform sampler2D image;
uniform float w;
uniform float h;
uniform float mixfac;
out vec4 FragmentColor;

uniform float offset[5] = float[]( 0.0, 1.0, 2.0, 3.0, 4.0 );
uniform float weight[5] = float[]( 0.2270270270, 0.1945945946, 0.1216216216, 0.0540540541, 0.0162162162 );

void main(void)
{
	vec4 orig_color = texture2D( image, vec2(gl_FragCoord)/vec2(w,h) );
	vec4 blured_color = orig_color * weight[0];
	for (int i=1; i<5; i++) {
		blured_color += texture2D( image, ( vec2(gl_FragCoord)+vec2(offset[i], 0.0) )/vec2(w,h) ) * weight[i];
		blured_color += texture2D( image, ( vec2(gl_FragCoord)-vec2(offset[i], 0.0) )/vec2(w,h) ) * weight[i];
	}
	
	FragmentColor = mix(orig_color,blured_color,mixfac);
}
]]

local fragV = [[
#version 330 core

uniform sampler2D image;
uniform float w;
uniform float h;
uniform float mixfac;
out vec4 FragmentColor;

uniform float offset[5] = float[]( 0.0, 1.0, 2.0, 3.0, 4.0 );
uniform float weight[5] = float[]( 0.2270270270, 0.1945945946, 0.1216216216, 0.0540540541, 0.0162162162 );

void main(void)
{
	vec4 orig_color = texture2D( image, vec2(gl_FragCoord)/vec2(w,h) );
	vec4 blured_color = orig_color * weight[0];
	for (int i=1; i<5; i++) {
		vec4 temp = texture2D( image, ( vec2(gl_FragCoord)+vec2(0.0, offset[i]) )/vec2(w,h) ) + texture2D( image, ( vec2(gl_FragCoord)-vec2(0.0, offset[i]) )/vec2(w,h) );
		blured_color += temp * weight[i];
	}
	FragmentColor = mix(orig_color,blured_color,mixfac);
}
]]

--linear versions
local fragH2 = [[
#version 330 core

uniform sampler2D image;
uniform float w;
uniform float h;
uniform float mixfac;
out vec4 FragmentColor;

uniform float offset[3] = float[]( 0.0, 1.3846153846, 3.2307692308 );
uniform float weight[3] = float[]( 0.2270270270, 0.3162162162, 0.0702702703 );

void main(void)
{
	vec4 orig_color = texture2D( image, vec2(gl_FragCoord)/vec2(w,h) );
	vec4 blured_color = orig_color * weight[0];
	for (int i=1; i<3; i++) {
		vec4 temp = texture2D( image, ( vec2(gl_FragCoord)+vec2(offset[i], 0.0) )/vec2(w,h)) + texture2D( image, ( vec2(gl_FragCoord)-vec2(offset[i], 0.0) )/vec2(w,h) );
		blured_color += temp * weight[i];
	}
	FragmentColor = mix(orig_color,blured_color,mixfac);
}

]]

local fragV2 = [[
#version 330 core

uniform sampler2D image;
uniform float w;
uniform float h;
uniform float mixfac;
out vec4 FragmentColor;

uniform float offset[3] = float[]( 0.0, 1.3846153846, 3.2307692308 );
uniform float weight[3] = float[]( 0.2270270270, 0.3162162162, 0.0702702703 );

void main(void)
{
	vec4 orig_color = texture2D( image, vec2(gl_FragCoord)/vec2(w,h) );
	vec4 blured_color = orig_color * weight[0];
	for (int i=1; i<3; i++) {
		vec4 temp = texture2D( image, ( vec2(gl_FragCoord)+vec2(0.0, offset[i]) )/vec2(w,h) ) + texture2D( image, ( vec2(gl_FragCoord)-vec2(0.0, offset[i]) )/vec2(w,h) );
		blured_color += temp * weight[i];
	}
	FragmentColor = mix(orig_color,blured_color,mixfac);
}

]]

local function BlurClipMaker(GL)

	local Clip = {}
	local programH, programV,programstd
	local mixfbos = {}
	local NM = GL:Dialog("blur",
	{{"iters",1,guitypes.valint,{min=0,max=20}},
	{"mixfac",1,guitypes.val,{min=0,max=1}}
	}
	)
	Clip.NM = NM
	function Clip.init()
		print"gaussianblur init"
		programH = GLSL:new():compile(vert_std,fragH2);
		programV = GLSL:new():compile(vert_std,fragV2);
		programstd = GLSL:new():compile(vert_std,frag_std);
		mixfbos[0] = GL:initFBO()
		mixfbos[1] = GL:initFBO()
		Clip.inited = true
	end


	function Clip:draw(timebegin,w,h,args)
		if not self.inited then self.init() end
		plugin.get_args(NM, args, timebegin)
		local theclip = args.clip

		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		
		mixfbos[0]:Bind()

		theclip[1]:draw(timebegin, w, h,theclip)
		
		for i=1,NM.iters do
			programH:use()
			mixfbos[1]:Bind()
			mixfbos[0]:UseTexture(0)
			programH.unif.image:set{0}
			programH.unif.w:set{w}
			programH.unif.h:set{h}
			programH.unif.mixfac:set{NM.mixfac}
			
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
			programV.unif.mixfac:set{NM.mixfac}
			
			gl.glClearColor(0.0, 0.0, 0.0, 0)
			ut.Clear()
			
			ut.project(w,h)
			ut.DoQuad(w,h)
		end
		
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
local GL = GLcanvas{H=1080,aspect=2/3}
local blur = BlurClipMaker(GL,{size=2})
-- local blur = require"anima.plugins.gaussianblur"(GL)
local tex
function GL.init()
	tex = GL:Texture():Load[[C:\luaGL\frames_anima\7thDoor\puertas\_MG_4250.tif]]
end
function GL.draw(t,w,h)
	blur:draw(t,w,h,{clip={tex}})
end
GL:start()
--]=]

return BlurClipMaker