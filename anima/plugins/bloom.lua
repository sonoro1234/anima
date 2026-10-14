require"anima"


vert_shad = [[
#version 330 core
layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 texCoords;

out VS_OUT {
    vec3 FragPos;
    vec3 Normal;
    vec2 TexCoords;
} vs_out;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

void main()
{
    gl_Position = projection * view * model * vec4(position, 1.0f);
    vs_out.FragPos = vec3(model * vec4(position, 1.0));   
    vs_out.TexCoords = texCoords;
        
    mat3 normalMatrix = transpose(inverse(mat3(model)));
    vs_out.Normal = normalize(normalMatrix * normal);
}
]]

frag_shad = [[
#version 330 core
layout (location = 0) out vec4 FragColor;
layout (location = 1) out vec4 BrightColor;

in VS_OUT {
    vec3 FragPos;
    vec3 Normal;
    vec2 TexCoords;
} fs_in;

struct Light {
    vec3 Position;
    vec3 Color;
};

uniform Light lights[4];
uniform sampler2D diffuseTexture;
uniform vec3 viewPos;

void main()
{           
    vec3 color = texture(diffuseTexture, fs_in.TexCoords).rgb;
    vec3 normal = normalize(fs_in.Normal);
    // Ambient
    vec3 ambient = 0.0 * color;
    // Lighting
    vec3 lighting = vec3(0.0f);
    vec3 viewDir = normalize(viewPos - fs_in.FragPos);
    for(int i = 0; i < 4; i++)
    {
        // Diffuse
        vec3 lightDir = normalize(lights[i].Position - fs_in.FragPos);
        float diff = max(dot(lightDir, normal), 0.0);
        vec3 result = lights[i].Color * diff * color;      
        // Attenuation (use quadratic as we have gamma correction)
        float distance = length(fs_in.FragPos - lights[i].Position);
        result *= 1.0 / (distance * distance);
        lighting += result;
                
    }
    vec3 result = ambient + lighting;
    // Check whether result is higher than some threshold, if so, output as bloom threshold color
    float brightness = dot(result, vec3(0.2126, 0.7152, 0.0722));
    if(brightness > 1.0)
        BrightColor = vec4(result, 1.0);
    // else
        // BloomColor = vec4(0.0, 0.0, 0.0, 1.0);
    FragColor = vec4(result, 1.0f);
}
]]

local vert_std = [[

//uniform mat4 MVP;
in vec3 position;
in vec2 texcoords;
out vec4 tcoordf;
void main()
{
	tcoordf = vec4(texcoords,0,1);
	//gl_Position = MVP*vec4(position,1);//gl_Vertex;//ftransform();
	gl_Position = vec4(position,1);
}

]]

local frag_mix = [[
//#version 330 core
uniform sampler2D tex0,tex1;
uniform float bloomfac;
in vec4 tcoordf;
out vec4 fcolor;
void main()
{

	fcolor = texture2D(tex1,tcoordf.st) + texture2D(tex0,tcoordf.st)*bloomfac;
	//gl_FragColor =  texture2D(tex0,gl_TexCoord[0].st);
}
]]
local frag_lights = [[

uniform sampler2D tex0;
uniform float bloomlevel;
in vec4 tcoordf;
out vec4 fcolor;
void main()
{
	vec4 color = texture2D(tex0,tcoordf.st);
	float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	
    if(brightness > bloomlevel){
		brightness = smoothstep(bloomlevel,1.0,brightness);
		color.rgb = mix(vec3(0.0),color.rgb,brightness);
        fcolor = color;
	}else
		discard;
	
}
]]

local show_tex = {}
function show_tex:draw(t,w,h,args)
	--ut.ShowTex(args.texture,w,h)
	ut.Clear()
	ut.tex_program:draw(args.texture,w,h)
end

local blurmaker = require"anima.plugins.gaussianblur3"
local M = {}
function M.make(GL)
	local plugin = require"anima.plugins.plugin"
	local bloomer = plugin.new{res={GL.W,GL.H}}
	local NM = GL:Dialog("bloom",
	{
	{"bloomlevel",1.0,guitypes.val,{min=0,max=1}},
	{"bloomfac",1.0,guitypes.val,{min=0,max=2}},
	{"bloom_size",3.0,guitypes.val,{min=2,max=8}},
	{"iters",3.0,guitypes.val,{min=0,max=10}},
	{"bypass",false,guitypes.toggle},
	},function(n,v)  end)
	
	bloomer.NM = NM

	local blurer --= blurmaker(GL)--,{size=NM.bloom_size})--,0.5)
	
	function bloomer:init()
		print"bloomer:init======================================================================="
		self.clipfbo = GL:initFBO()
		self.light_fbo = GL:initFBO({no_depth=true})
		self.bloom_fbo = GL:initFBO({no_depth=true})
		blurer = blurmaker(GL)--,{size=NM.bloom_size})--,0.5)
		self.program = GLSL:new()
		self.program:compile(vert_std,frag_lights);
		self.programmix = GLSL:new()
		self.programmix:compile(vert_std,frag_mix);
		self.vao = mesh.quad():vao(self.program)
		self.inited = true
	end
	function bloomer:process(texture,w,h)
		local w,h = w or self.res[1],h or self.res[2] --srctex.width,srctex.height
		if NM.bypass then
			texture:drawcenter()
		else
		local old_framebuffer = self.light_fbo:Bind()

		gl.glViewport(0,0,w,h)
		texture:Bind()
		self.program:use()
		self.program.unif.tex0:set{0}
		self.program.unif.bloomlevel:set{NM.bloomlevel}
		ut.Clear()
		self.vao:draw_elm()

		self.light_fbo:UnBind()
		ut.Clear()
		--self.light_fbo:tex():drawcenter()--(0,w,h)
		--blurer:update()
		--blurer:process(self.light_fbo:tex())
		--blurer:process(texture)
		blurer:process_fbo(self.bloom_fbo, self.light_fbo:tex())
		-- ut.Clear()
		-- self.bloom_fbo:tex():drawcenter()
				--final mix
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer);
		--self.bloom_fbo:tex():drawcenter()
		--do return end
		self.programmix:use()
		self.programmix.unif.tex0:set{0}
		self.programmix.unif.tex1:set{1}
		self.programmix.unif.bloomfac:set{NM.bloomfac}
		texture:Bind(1)
		--self.clipfbo:UseTexture(1,0)
		self.bloom_fbo:UseTexture()
		ut.Clear()
		--ut.project(w,h)
		--ut.DoQuad(w,h)
		self.vao:draw_elm()
		end
	end
	local function get_args(t, timev)
		local clip = t.clip
		local bloomlevel = ut.get_var(t.bloomlevel,timev,NM.bloomlevel)
		local bloomfac = ut.get_var(t.bloomfac,timev,NM.bloomfac)
		return clip,bloomlevel,bloomfac
	end
	function bloomer:draw(t,w,h,args)
		if not self.inited then self:init() end
		local theclip,bloomlevel,bloomfac = get_args(args,t)
		--print(bloomfac)
		if not NM.bypass then
		
		local old_framebuffer = self.clipfbo:Bind()
		ut.Clear()
		theclip[1]:draw(t, w, h,theclip)
		
		self.clipfbo:UnBind()
		-- ut.Clear()
		-- self.clipfbo:tex():drawcenter()
		-- do return end

		---------get lights
		self.light_fbo:Bind()
		self.clipfbo:UseTexture()
		self.program:use()
		self.program.unif.tex0:set{0}
		self.program.unif.bloomlevel:set{bloomlevel}
		ut.Clear()
		ut.project(w,h)
		-- local MP = mat.ortho(0.0, w, 0.0, h, -1, 1);
		-- self.program.unif.MVP:set(MP.gl)
		ut.DoQuad(w,h)
		-- local qq = mesh.quad(0,0,w,h):vao(self.program)
		-- qq:draw_elm()
		
		self.light_fbo:UnBind()
		-- ut.Clear()
		-- self.light_fbo:tex():drawcenter()
		-- do return end
		--blur lights
		--self.bloom_fbo:Bind()
		
		--blurer:Setsize(NM.bloom_size)
		-- blurer.NM.vars.radio[0] = NM.bloom_size
		-- blurer:update()
		ut.Clear()
		--self.clipfbo:tex():drawcenter()
		--blurer:process(self.clipfbo:tex())--self.light_fbo:tex())
		blurer:process(self.light_fbo:tex())
		--blurer:draw(t,w,h,{clip={show_tex,texture=self.light_fbo:GetTexture().tex},iters=NM.iters})
		--blurer:draw(t,w,h,{clip={self.light_fbo:GetTexture()},iters=NM.iters})
		do return end
		--final mix
		self.programmix:use()
		self.programmix.unif.tex0:set{0}
		self.programmix.unif.tex1:set{1}
		self.programmix.unif.bloomfac:set{bloomfac}
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer);
		self.clipfbo:UseTexture(1,0)
		self.bloom_fbo:UseTexture()
		ut.Clear()
		ut.project(w,h)
		ut.DoQuad(w,h)
		else --bypass
			ut.Clear()
			theclip[1]:draw(t, w, h,theclip)
		
		end --bypass
	end
	GL:add_plugin(bloomer)
	return bloomer
end

if not ... then
---[=[
--test

local GL = GLcanvas{fps=250,RENDERINI=0,RENDEREND=208,H=700,aspect = 1.5,profile="COMPAT"}
--texter = require"anima.plugins.GLTextClip"(GL)
--texini = {texter,size=AN({0.05,0.2,15}),text={[[Palmeras]],"Huecas"},color={1,1,1},rot_speed = 30,centered=true,dontclear=true,shadow=true,shadowdist=0.01, posX = AN{-0.75,-0.55,15},posY = AN{-0.5,0,15},bright = AN({0,1,1},{1,1,20},{1,0,3})}
local textur
function GL.init()
	print("GL example init =======================================================================",GL)
	textur = GL:Texture():Load([[c:\luaGL\media\estanque-001.jpg]])
	--textur = textur:resample_fac(0.25)
	GL:set_WH(textur.width, textur.height)
	theblommer = M.make(GL)
	--GL.animation:add_animatable(AN1(theblommer.NM.vars.bloomlevel,{1,0.85,40,unit_maps.sinemapf(40*2)}))
end

function GL.draw(t,w,h)
	ut.Clear()
	theblommer:process(textur)
	--theblommer:draw(t,w,h,{clip={textur},bloomfacNO = AN({1,0.85,40,unit_maps.sinemapf(40*2)})})
	--theblommer:draw(t,w,h,{clip=texini,bloomlevel= 0.8,bloomfac = AN({1,0,40,unit_maps.sinemapf(40*2)})})
	--texini[1]:draw(t,w,h,texini)
end
GL:start()
--]=]
end


return M