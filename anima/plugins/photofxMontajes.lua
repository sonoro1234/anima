
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
uniform float ampL;
uniform float ampR;
uniform float black;
uniform float white;
uniform float saturation;

uniform bool usealpha;
uniform bool invert;
uniform bool bypass;

/*
vec4 sigmoidal(vec4 val,float ampL,float ampR){

	vec3 i = vec3(mix(ampL,ampR,val.r),mix(ampL,ampR,val.g),mix(ampL,ampR,val.b));
	float minV2 = 1.0/(1.0 + exp(-ampL));
	float maxV2 = 1.0/(1.0 + exp(-ampR));
	float escale = 1.0/(maxV2 - minV2);
	float offset = 1.0 - maxV2 * escale;

	return vec4(offset + escale/(1.0 + exp(-i)),val.a);
}
*/

float sigmoidal(float val,float ampL,float ampR){

	float i = mix(ampL,ampR,val);
	float minV2 = 1.0/(1.0 + exp(-ampL));
	float maxV2 = 1.0/(1.0 + exp(-ampR));
	float escale = 1.0/(maxV2 - minV2);
	float offset = 1.0 - maxV2 * escale;

	return offset + escale/(1.0 + exp(-i));
}
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
	vec3 colhsv = RGB2HSV(color);
	float lum = colhsv.z ;//dot(color.rgb,vec3(1.0/3.0));
	float lum2 = clamp((lum - black)/(white - black),0.0, 1.0);
	//float lum2 = (lum - black)/(white - black);
	/*
	float fac = lum2/lum;
	if (lum == 0.0)
		fac = 0;
		*/
	lum2 = sigmoidal(lum2,ampL,ampR);
	color = HSV2RGB(vec3(colhsv.x,clamp(saturation*colhsv.y,0,1),lum2));
	
	if(invert)
		tcolor.a = 1.0 - tcolor.a;
	if(usealpha)
		gl_FragColor = mix(vec4(tcolor.rgb,1.0),vec4(color,1.0),tcolor.a);
	else
		gl_FragColor = vec4(color,tcolor.a);
}
]]


local M = {}

function M.photofx(GL)
	local NM = GL:Dialog("photofx",
	{
	{"ampL",-0.01,guitypes.val,{min=-10,max=10}},
	{"ampR",0.01,guitypes.val,{min=-10,max=10}},
	{"black",0,guitypes.val,{min=-1,max=1}},
	{"white",1,guitypes.val,{min=0,max=2}},
	{"saturation",1,guitypes.val,{min=0,max=1}},
	{"usealpha",false,guitypes.toggle},
	{"invert",false,guitypes.toggle},
	{"bypass",false,guitypes.toggle}
	})

	local plugin = require"anima.plugins.plugin"
	local LM = plugin.new{res={GL.W,GL.H}}
	local  programfx,fbo

	function LM.init()
		--if not GL.PPFBO then GL:init_PPFBO() end
		fbo = GL:initFBO()
		programfx = GLSL:new():compile(vert_shad,frag_shad)
		
		local mesh = require"anima.mesh"
		--local m = mesh.Quad(-1,1,1,-1)
		local m = mesh.Quad(-1,-1,1,1)
		LM.vao = VAO({Position=m.points,texcoords = m.texcoords},programfx,m.indexes)

		LM.inited = true
	end
	
	local function get_args(t, timev)
		for k,v in pairs(NM.vars) do
			if t.k then v[0] = ut.get_arg(t.k, timev) end
		end
	end
	
	function LM:process(srctex,w,h)

		srctex:Bind()
		
		programfx:use()
		programfx.unif.tex0:set{0}

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
			theclip[1]:set_wrap(glc.GL_CLAMP)
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
		ut.Clear()
		programfx:use()
		programfx.unif.tex0:set{0}
		
		for k,v in pairs(NM.vars) do
			--print(k,NM[k])
			programfx.unif[k]:set{NM[k]}
		end
		
		gl.glViewport(0,0,w,h)
		self.vao:draw_elm()
		
		if theclip[1].isSlab then
			theclip[1].pong:UnBind()
			theclip[1]:swapt()
		end
	end
	GL:add_plugin(LM)
	return LM
end
--alias
M.make = M.photofx
return M


