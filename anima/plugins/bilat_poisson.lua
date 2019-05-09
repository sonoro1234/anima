local frag_sh = [[

uniform float BSIGMA = 0.1;
uniform bool bypass = false;
uniform sampler2D   sTextureSamples;  
ivec2 texsampdims = textureSize(sTextureSamples,0);
uniform float scale=1;
uniform int scaleY2=1;
uniform int nsamples = 25;

uniform vec3      iResolution;           // viewport resolution (in pixels)
uniform sampler2D iChannel0;          // input channel. XX = 2D/Cube

float normpdf(in float x, in float sigma)
{
	float xs = x/sigma;
	return 0.39894*exp(-0.5*xs*xs)/sigma;
}

const float face = 0.159154;
float normpdf3(in vec3 v, in float sigma)
{
	float sigmasq = sigma*sigma;
	return face*exp(-0.5*dot(v,v)/sigmasq)/sigmasq;
	//return exp(-dot(v,v)/sigma);
}

float rand(vec2 n) { 
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

vec3 lumin = vec3( 0.30, 0.59, 0.11);

out vec4 fragColor;
vec2 fragCoord = gl_FragCoord.xy;
void main()
{
	
	vec2 vTexcoord = fragCoord.xy / iResolution.xy;
	
	vec3 c = texture(iChannel0, vTexcoord ).rgb;
	if (bypass)
	{
		fragColor = vec4(c, 1.0);
		
	} else {
		
		//float yFetch = vTexcoord.y * scaleY2;
		
		
		vec3 final_colour = vec3(0.0);
		float Z = 0.0;
		
		//int yslice = 0;
		//int yslice = (int(fragCoord.y)+scaleY2)%texsampdims.y;
		//int yslice = mod(fragCoord.y+scaleY2,texsampdims.y);
		//int yslice = int(rand(fragCoord.xy+scaleY2)*texsampdims.y);
		//int yslice = int(fragCoord.x+fragCoord.y+scaleY2)%texsampdims.y;
		int yslice = scaleY2%texsampdims.y;

		
		for(int i=0; i<nsamples; i++){
			//int i = nsamples;
			//vec2 coords = texture2D(sTextureSamples, vec2(float(i) / 30.0, yFetch)).xy;
			vec2 coords = texelFetch(sTextureSamples, ivec2(i,yslice ),0).xy;
			coords = (coords - 0.5) * scale;
			vec3 colorFetch = texture2D(iChannel0, coords + vTexcoord).xyz;
			vec3 colorDist = colorFetch - c;
			float tmpWeight = normpdf3(colorDist,BSIGMA);//exp(-dot(colorDist, colorDist) / BSIGMA);
			//float lumdist = dot(colorFetch - c,lumin);
			//float tmpWeight = normpdf(lumdist, BSIGMA);
			final_colour += colorFetch * tmpWeight;
			Z += tmpWeight;
		}
		
		fragColor = vec4(final_colour/Z, 1.0);
	}
}

]]

local program
local texsamp
local function make(GL)
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new(nil,GL)
	
	local NM = GL:Dialog("bilat_poisson",{
	{"BSIGMA",0.1,guitypes.val,{min=0,max=0.25}},
	{"nsamples",25,guitypes.valint,{min=1,max=50}},
	{"Niter",1,guitypes.valint,{min=1,max=6}},
	{"scale",0.3,guitypes.val,{min=0,max=0.3}},
	{"scalesc",1,guitypes.val,{min=0,max=4}},
	{"scaleY2",1,guitypes.valint,{min=0,max=64}},
	{"bypass",false,guitypes.toggle},
	})
	
	M.NM = NM
	NM.plugin = M
	
	local path = require"anima.path"
	local vicim = require"anima.vicimag"
	local fbos = {}
	function M:init()
		if not program then
			program = GLSL:new():compile(ut.vert_std,frag_sh)
			
			local here = path.file_path()
			here = path.path2table(here)
			here[#here] = "media"
			here = path.table2path(here)
			
			-- texsamp = Texture():Load(here..[[/samples64_quad.png]])
			texsamp = vicim.vicimag2tex(here..[[/poisson.dat]],GL)
		end

	end
	
	function M:process(tex,w,h)
		w,h = w or self.res[1], h or self.res[2]
		program:use()
		local U = program.unif
		U.iChannel0:set{0}
		U.iResolution:set{w,h,10}

		U.BSIGMA:set{NM.BSIGMA}
		U.nsamples:set{NM.nsamples}
		U.bypass:set{NM.bypass}
		U.sTextureSamples:set{1}

		U.scale:set{NM.scale*NM.scalesc}
		U.scaleY2:set{NM.scaleY2}
	
		ut.Clear()
		ut.project(w,h)
		
		fbos[0] = GL:get_fbo()
		fbos[1] = GL:get_fbo()
		
		texsamp:Bind(1) --
		
		local oldfbo = fbos[0]:Bind()
		--print("oldfbo",oldfbo)
		
		for i=1,NM.Niter do
			if i<NM.Niter then
				fbos[i%2]:Bind()
			else
				--GL.fbo:Bind()
				glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, oldfbo);
			end
			if i==1 then
				tex:Bind(0)
			else
				fbos[(i-1)%2]:tex():Bind()
			end
			U.scaleY2:set{NM.scaleY2*i}
			ut.DoQuad(w,h)
		end
		
		
		fbos[0]:release()
		fbos[1]:release()
	end
	
	function M:draw(t,w,h,args)
		local fbo = GL:get_fbo()
		local theclip = args.clip
		fbo:Bind()
		theclip[1]:draw(t,w,h,theclip)
		fbo:UnBind()
		local textura = fbo:tex()
		self:process(textura)
		fbo:release()
	end
	GL:add_plugin(M,"bilat_poisson")
	return M
end


--[=[
require"anima"
path = require"anima.path"
vicim = require"anima.vicimag"
print(path.this_script_path())
GL = GLcanvas{H=1080,aspect=3/2}

local textura,bilat
local argspeli
function GL.init()
	
	--textura = Texture():Load(path.this_script_path().."/canvas.png",false,true)
	--textura = Texture():Load([[c:\luaGL\media\estanque-001.jpg]],false,true)
	--textura = Texture():Load(path.this_script_path()..[[\tex03.jpg]])
	--textura = Texture():Load(path.this_script_path()..[[\_MG_5819.png]],false,true)
	--textura = Texture():Load([[c:\luagl\frames_anima\photofx\5909tn.tif]],false,true)
	--textura = Texture():Load([[c:\luagl\media\noise.tif]])
	--textura = Texture():Load("c:/luagl/media/piscina.tif",false,true)
	--textura = Texture():Load([[G:\VICTOR\pelis\7thDoor\frames3\frames/frame1500.tif]])
	textura = Texture():Load([[G:\VICTOR\pelis\pelipino\master1080\arbolenflordos\frame-0001.tif]])
	--textura = Texture():Load[[c:/luagl/media\frame-0001.tif]]
	--textura = Texture():Load[[G:\VICTOR\pelis\hadas\master1080\leslie_giro1\frame-0001.tif]]
	--textura = Texture():Load[[c:/luagl/media\amsterdam.jpg]]
	--textura = textura:resample_fac(0.25)
	
	
	
	--texsamp:gen_mipmap(1)
	GL:set_WH(textura.width,textura.height)
	
	-- GL.rootdir = [[G:\VICTOR\pelis\pelipino]]
	-- fpl2 = require"anima.plugins.flow_player"(GL)
	-- argspeli = fpl2:loadimages("arbolenflordos")
	-- argspeli.frame = AN({1,#argspeli.images*20,#argspeli.images*20*16})
	
	bilat = make(GL)
	require"anima.plugins.plugin".serializer(bilat)
	--fbos[0] = GL:initFBO({no_depth=true})
	--fbos[1] = GL:initFBO({no_depth=true})
	GL:DirtyWrap()
end

function GL.draw(t,w,h)
	
	--bilat:process(textura)
	bilat:draw(t,w,h,{clip={textura}})
	--bilat:draw(t,w,h,{clip=argspeli})
end

GL:start()
--]=]
--print(path.this_script_path(),path.script_path())
return make