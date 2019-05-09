local frag_sh = [[
// Using a sobel filter to create a normal map and then applying simple lighting.

// This makes the darker areas less bumpy but I like it
#define USE_LINEAR_FOR_BUMPMAP

//#define SHOW_NORMAL_MAP
//#define SHOW_ALBEDO

struct C_Sample
{
	vec3 vAlbedo;
	vec3 vNormal;
	vec3 color;
};
	
C_Sample SampleMaterial(const in vec2 vUV, sampler2D sampler,  const in vec2 vTextureSize, const in float fNormalScale)
{
	C_Sample result;
	
	vec2 vInvTextureSize = vec2(1.0) / vTextureSize;
	
	vec3 cSampleNegXNegY = texture(sampler, vUV + (vec2(-1.0, -1.0)) * vInvTextureSize.xy).rgb;
	vec3 cSampleZerXNegY = texture(sampler, vUV + (vec2( 0.0, -1.0)) * vInvTextureSize.xy).rgb;
	vec3 cSamplePosXNegY = texture(sampler, vUV + (vec2( 1.0, -1.0)) * vInvTextureSize.xy).rgb;
	
	vec3 cSampleNegXZerY = texture(sampler, vUV + (vec2(-1.0, 0.0)) * vInvTextureSize.xy).rgb;
	vec3 cSampleZerXZerY = texture(sampler, vUV + (vec2( 0.0, 0.0)) * vInvTextureSize.xy).rgb;
	vec3 cSamplePosXZerY = texture(sampler, vUV + (vec2( 1.0, 0.0)) * vInvTextureSize.xy).rgb;
	
	vec3 cSampleNegXPosY = texture(sampler, vUV + (vec2(-1.0,  1.0)) * vInvTextureSize.xy).rgb;
	vec3 cSampleZerXPosY = texture(sampler, vUV + (vec2( 0.0,  1.0)) * vInvTextureSize.xy).rgb;
	vec3 cSamplePosXPosY = texture(sampler, vUV + (vec2( 1.0,  1.0)) * vInvTextureSize.xy).rgb;

	// convert to linear	
	vec3 cLSampleNegXNegY = cSampleNegXNegY * cSampleNegXNegY;
	vec3 cLSampleZerXNegY = cSampleZerXNegY * cSampleZerXNegY;
	vec3 cLSamplePosXNegY = cSamplePosXNegY * cSamplePosXNegY;
                                           
	vec3 cLSampleNegXZerY = cSampleNegXZerY * cSampleNegXZerY;
	vec3 cLSampleZerXZerY = cSampleZerXZerY * cSampleZerXZerY;
	vec3 cLSamplePosXZerY = cSamplePosXZerY * cSamplePosXZerY;
                                           
	vec3 cLSampleNegXPosY = cSampleNegXPosY * cSampleNegXPosY;
	vec3 cLSampleZerXPosY = cSampleZerXPosY * cSampleZerXPosY;
	vec3 cLSamplePosXPosY = cSamplePosXPosY * cSamplePosXPosY;

	// Average samples to get albdeo colour
	result.vAlbedo = ( cLSampleNegXNegY + cLSampleZerXNegY + cLSamplePosXNegY 
		    	     + cLSampleNegXZerY + cLSampleZerXZerY + cLSamplePosXZerY
		    	     + cLSampleNegXPosY + cLSampleZerXPosY + cLSamplePosXPosY ) / 9.0;	
	
	vec3 vScale = vec3(0.3333);
	result.color = cLSampleZerXZerY;
	#ifdef USE_LINEAR_FOR_BUMPMAP
		
		float fSampleNegXNegY = dot(cLSampleNegXNegY, vScale);
		float fSampleZerXNegY = dot(cLSampleZerXNegY, vScale);
		float fSamplePosXNegY = dot(cLSamplePosXNegY, vScale);
		
		float fSampleNegXZerY = dot(cLSampleNegXZerY, vScale);
		float fSampleZerXZerY = dot(cLSampleZerXZerY, vScale);
		float fSamplePosXZerY = dot(cLSamplePosXZerY, vScale);
		
		float fSampleNegXPosY = dot(cLSampleNegXPosY, vScale);
		float fSampleZerXPosY = dot(cLSampleZerXPosY, vScale);
		float fSamplePosXPosY = dot(cLSamplePosXPosY, vScale);
	
	#else
	
		float fSampleNegXNegY = dot(cSampleNegXNegY, vScale);
		float fSampleZerXNegY = dot(cSampleZerXNegY, vScale);
		float fSamplePosXNegY = dot(cSamplePosXNegY, vScale);
		
		float fSampleNegXZerY = dot(cSampleNegXZerY, vScale);
		float fSampleZerXZerY = dot(cSampleZerXZerY, vScale);
		float fSamplePosXZerY = dot(cSamplePosXZerY, vScale);
		
		float fSampleNegXPosY = dot(cSampleNegXPosY, vScale);
		float fSampleZerXPosY = dot(cSampleZerXPosY, vScale);
		float fSamplePosXPosY = dot(cSamplePosXPosY, vScale);	
	
	#endif
	
	// Sobel operator - http://en.wikipedia.org/wiki/Sobel_operator
	
	vec2 vEdge;
	vEdge.x = (fSampleNegXNegY - fSamplePosXNegY) * 0.25 
			+ (fSampleNegXZerY - fSamplePosXZerY) * 0.5
			+ (fSampleNegXPosY - fSamplePosXPosY) * 0.25;

	vEdge.y = (fSampleNegXNegY - fSampleNegXPosY) * 0.25 
			+ (fSampleZerXNegY - fSampleZerXPosY) * 0.5
			+ (fSamplePosXNegY - fSamplePosXPosY) * 0.25;

	result.vNormal = normalize(vec3(vEdge * fNormalScale, 1.0));	
	
	return result;
}

uniform float fNormalScale = 10.0;
uniform float fViewHeight = 2.0;
uniform float fLightHeight = 0.2;
uniform float mixf = 1.0;
uniform vec2 LightPos = vec2(0);
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{	
	vec2 vUV = fragCoord.xy / iResolution.xy;
	
	C_Sample materialSample;
		
	//float fNormalScale = 10.0;
	materialSample = SampleMaterial( vUV, iChannel0, iChannelResolution[0].xy, fNormalScale );
	
	// Random Lighting...
	
	//float fLightHeight = 0.2;
	//float fViewHeight = 2.0;
	
	vec3 vSurfacePos = vec3(vUV, 0.0);
	
	vec3 vViewPos = vec3(0.5, 0.5, fViewHeight);
	
	vec3 vLightPos = vec3(LightPos,fLightHeight);
/*	
	//vec3 vLightPos = vec3( vec2(sin(iTime),cos(iTime)) * 0.25 + 0.5 , fLightHeight);
	vec3 vLightPos = vec3( vec2(snoise(vec2(iTime,0)),snoise(vec2(iTime+17))) * 0.5 + 0.5 , fLightHeight);
		
	if( iMouse.z > 0.0 )
	{
		vLightPos = vec3(iMouse.xy / iResolution.xy, fLightHeight);
	}
	*/
	vec3 vDirToView = normalize( vViewPos - vSurfacePos );
	vec3 vDirToLight = normalize( vLightPos - vSurfacePos );
		
	float fNDotL = clamp( dot(materialSample.vNormal, vDirToLight), 0.0, 1.0);
	float fDiffuse = fNDotL;
	
	vec3 vHalf = normalize( vDirToView + vDirToLight );
	float fNDotH = clamp( dot(materialSample.vNormal, vHalf), 0.0, 1.0);
	float fSpec = pow(fNDotH, 10.0) * fNDotL * 0.5;
	
	//vec3 vResult = materialSample.vAlbedo * fDiffuse + fSpec;
	vec3 vResult = materialSample.vAlbedo * (fDiffuse + fSpec);
	
	vResult = sqrt(mix(materialSample.color,vResult,mixf));
	
	#ifdef SHOW_NORMAL_MAP
	vResult = materialSample.vNormal * 0.5 + 0.5;
	#endif
	
	#ifdef SHOW_ALBEDO
	vResult = sqrt(materialSample.vAlbedo);
	#endif
	
	fragColor = vec4(vResult,1.0);
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

local program
local function make(GL)
	local M = {}
	M.NM = GL:Dialog("emboss",{
{"fNormalScale",10,guitypes.val,{min=0,max=25}},
{"fViewHeight",2,guitypes.val,{min=0,max=10}},
{"fLightHeight",0.2,guitypes.val,{min=0,max=2}},
{"mixf",1,guitypes.val,{min=0,max=1}},
{"LightPos",{0.5,0.5},guitypes.drag,{min=0,max=1}},
{"bypass",false,guitypes.toggle},

})
	local NM = M.NM
	local fbo
	function M:init()
		if not program then
			program = GLSL:new():compile(ut.vert_std,frag_unif..frag_sh..frag_main)
		end
		fbo = GL:initFBO()
	end
	function M:draw(t,w,h,args)
		local theclip = args.clip
		fbo:Bind()
		theclip[1]:draw(t,w,h,theclip)
		fbo:UnBind()
		local textura = fbo:GetTexture()
		if NM.bypass then textura:draw(t,w,h);return end
		program:use()
		program.unif.iChannel0:set{0}
		program.unif.iResolution:set{w,h,10}
		program.unif["iChannelResolution[0]"]:set{textura.width,textura.height,1}
		program.unif.fNormalScale:set{NM.fNormalScale}
		program.unif.fViewHeight:set{NM.fViewHeight}
		program.unif.fLightHeight:set{NM.fLightHeight}
		program.unif.mixf:set{NM.mixf}
		program.unif.LightPos:set(NM.LightPos)
	
		ut.Clear()
		ut.project(w,h)
		textura:Bind(0)
		ut.DoQuad(w,h)
	end
	GL:add_plugin(M)
	return M
end

--[=[
require"anima"

GL = GLcanvas{H=800,aspect=1.5}
local textura
local emboss
function GL.init()
	textura = Texture():Load([[G:\VICTOR\pelis\pelipino\master1080\muro\frame-0001.tif]],false,true)
	emboss = make(GL)
end
function GL.draw(t,w,h)
	emboss:draw(t,w,h,{clip={textura}})
end
GL:start()
--]=]

return make