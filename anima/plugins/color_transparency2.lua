

local vert_shad = [[
in vec3 Position;
in vec2 texcoords;
out vec2 texcoordsf;
void main()
{
	texcoordsf = texcoords;
	//gl_TexCoord[0] = vec4(texcoords,0,1);
	gl_Position = vec4(Position,1);
}

]]


local frag_shad = [[

uniform sampler2D tex0;
uniform vec3 tcolor;
uniform float maxdist;
uniform float stepd = 0.0;
uniform int mode;
uniform bool invert;
in vec2 texcoordsf;


void main()
{
	vec4 color = texture2D(tex0,texcoordsf);
	float norm = distance(color.rgb,tcolor);
	float a = smoothstep(maxdist-stepd,maxdist,norm);
	if(mode == 1)
		a = clamp(norm/maxdist,0.0,1.0);
	if(invert)
		a = 1.0 - a;
	gl_FragColor = color*a; //vec4(color.rgb*a,a);
	//gl_FragColor = vec4(vec3(norm),1.0);
	//gl_FragColor = vec4(vec3(a),1);
	//gl_FragColor = vec4(color.rgb,color.a*a);	
}
]]

local colorFuncs = require"anima.GLSL.GLSL_color"

local frag_shad_Lab = colorFuncs..[[

uniform sampler2D tex0;
uniform vec3 tcolor;
uniform float maxdist;
uniform float stepd = 0.0;
uniform int mode;
uniform bool invert;

vec3 labscale = vec3(1.0/100.0,1.0/115.0,1.0/115.0);
//vec3 labscale = vec3(1.0/100.0,1.0/30.0,1.0/30.0);
//a* is -79 to 94, and the range of b* is -112 to 93
vec3 laboffset = vec3(0.0,0.5,0.5);
float LabDistance(vec3 col1,vec3 col2){
	vec3 collab1 = XYZ2LAB(RGB2XYZ(sRGB2RGB(col1)),D65);
	vec3 collab2 = XYZ2LAB(RGB2XYZ(sRGB2RGB(col2)),D65);
	
	collab1 = collab1*labscale + laboffset;
	collab2 = collab2*labscale + laboffset;
	
	return distance(collab1,collab2);
	//return distance(collab1.yz,collab2.yz);

}
in vec2 texcoordsf;

void main()
{
	vec4 color = texture2D(tex0,texcoordsf);
	float norm = LabDistance(color.rgb,tcolor);
	float a = smoothstep(maxdist-stepd,maxdist,norm);
	if(mode == 1)
		a = clamp(norm/maxdist,0.0,1.0);
	if(invert)
		a = 1.0 - a;
	gl_FragColor = color*a; //vec4(color.rgb*a,a);
	//gl_FragColor = vec4(vec3(norm),1.0);	
}
]]

local frag_shad_hsv = colorFuncs..[[

uniform sampler2D tex0;
uniform vec3 tcolor;
uniform float maxdist;
uniform float stepd = 0.0;
uniform int mode;
uniform bool invert;

float Hdist(float a,float b){
	float d = abs(a-b);
	float d2 = 1.0-d;
	return min(d,d2);
}

float HSVDistance(vec3 col1,vec3 col2){
	vec3 collab1 = RGB2HSV(sRGB2RGB(col1));
	vec3 collab2 = RGB2HSV(sRGB2RGB(col2));
	//vec3 collab1 = RGB2HSV(col1);
	//vec3 collab2 = RGB2HSV(col2);
	//vec3 collab1 = sRGB2RGB(col1);
	//vec3 collab2 = sRGB2RGB(col2);
	float hdis = Hdist(collab1.x, collab2.x);
	vec3 v = (collab1 - collab2);
	return length(vec3(hdis,v.y,v.z));
	//return distance(collab1.y,collab2.y);
	//return distance(col1,col2);
	//return clamp(distance(collab1.x,collab2.x),0.0,1.0);
	//return distance(collab1.x,collab2.x);
}
in vec2 texcoordsf;
void main()
{
	vec4 color = texture2D(tex0,texcoordsf);
	//vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	float norm = HSVDistance(color.rgb,tcolor);
	float a = smoothstep(maxdist-stepd,maxdist,norm);
	if(mode == 1)
		a = clamp(norm/maxdist,0.0,1.0);
	if(invert)
		a = 1.0 - a;
	//gl_FragColor = vec4(vec3(a),1);
	gl_FragColor = color*a; //vec4(color.rgb*a,a); 
	//gl_FragColor = vec4(vec3(norm),1.0);
	//gl_FragColor = vec4(RGB2sRGB(HSV2RGB(RGB2HSV(sRGB2RGB(color.rgb)))),1);
	//gl_FragColor = vec4(HSV2RGB(RGB2HSV(color.rgb)),1);
}
]]



local function make(GL)--,args)
	args = args or {}
	local NM = GL:Dialog("color_trans",
{
{"maxdist",1,guitypes.val,{min=0,max=1}},
{"stepd",0,guitypes.val,{min=0,max=1}},
{"mode",1,guitypes.valint,{min=0,max=1}},
--{"Lab",false,guitypes.toggle},
{"color_mode",0,guitypes.combo,{"rgb","lab","hsv"}},
{"invert",false,guitypes.toggle},
{"pick",0,guitypes.button,function(this) 
	local oldmaxdist = this.maxdist
	this.vars.maxdist[0] = 0
	GL.mouse_pick = {action=function(X,Y)
							local pUD = ffi.new("float[?]",3)
							glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER, 0);
							gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
							gl.glReadPixels(X,Y, 1, 1, glc.GL_RGB, glc.GL_FLOAT, pUD)
							print(X,Y,"RGB:",pUD[0],pUD[1],pUD[2])
							this.vars.color:set{pUD[0],pUD[1],pUD[2]} --= pUD[0]
							this.vars.maxdist[0] = oldmaxdist
							GL.mouse_pick = nil
						end}

end},
{"color",{1,1,1},guitypes.color},
})
	
	
	local plugin = require"anima.plugins.plugin"
	local LM = plugin.new{res={GL.W,GL.H}}
	LM.NM = NM
	local fbo, programfx, progrgb,proglab,proghsv
	local lapse,oldtime,lapsesum = 0,0,0
	function LM:init()
		fbo = GL:initFBO()
		proglab = GLSL:new():compile(vert_shad,frag_shad_Lab)
		proghsv = GLSL:new():compile(vert_shad,frag_shad_hsv)

		progrgb = GLSL:new():compile(vert_shad,frag_shad)

		local m = mesh.quad(-1,-1,1,1)
		LM.vao = VAO({Position=m.points,texcoords = m.texcoords},progrgb,m.indexes)
		self.inited = true
	end
	
	local function get_args(t, timev)
		local clip = t.clip
		local tcolor = ut.get_var(t.tcolor,timev,NM.color)
		local maxdist = ut.get_var(t.maxdist,timev,NM.maxdist)
		return clip,tcolor,maxdist
	end

	function LM:process(srctex,w,h)

		srctex:Bind()
		
		if NM.color_mode == 0 then
			programfx =  progrgb
		elseif NM.color_mode == 1 then
			programfx = proglab
		else
			programfx = proghsv
		end
		
		programfx:use()
		programfx.unif.tex0:set{0}
		programfx.unif.maxdist:set{NM.maxdist}
		programfx.unif.stepd:set{NM.stepd}
		programfx.unif.mode:set{NM.mode}
		programfx.unif.invert:set{NM.invert}
		programfx.unif.tcolor:set(NM.color)

		gl.glViewport(0,0,w or self.res[1], h or self.res[2])
		ut.Clear()
		self.vao:draw_elm()

	end
	local plugin = require"anima.plugins.plugin"
	function LM:draw(timebegin, w, h, args)
		if not self.inited then self:init() end
		
		--local theclip,tcolor,maxdist = get_args(args, timebegin)
		theclip = args.clip
		plugin.get_args(NM,args,timebegin)
		
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
		
		-- fbo:Bind()
		-- theclip[1]:draw(timebegin, w, h,theclip)
		-- fbo:UnBind()
		-- fbo:UseTexture()
		
		if NM.color_mode == 0 then
			programfx =  progrgb
		elseif NM.color_mode == 1 then
			programfx = proglab
		else
			programfx = proghsv
		end
		
		programfx:use()
		
		
		programfx.unif.tex0:set{0}
		programfx.unif.maxdist:set{NM.maxdist}
		programfx.unif.stepd:set{NM.stepd}
		programfx.unif.mode:set{NM.mode}
		programfx.unif.invert:set{NM.invert}
		programfx.unif.tcolor:set(NM.color)
--print(tcolor)
		gl.glViewport(0,0,w,h)
		ut.Clear()
		self.vao:draw_elm()
		
	end
	GL:add_plugin(LM)
	return LM
end

--[=[
require"anima"
local GL = GLcanvas{H=1080,viewH=700,aspect=1.5,SDL=false}
GLSL.default_version = "#version 400\n"
local trans
local textura
function GL.init()
	textura = GL:Texture():Load[[C:\luagl\media\cara2.png]]
	GL:set_WH(textura.width,textura.height)
	trans = make(GL)
end

function GL.draw(t,w,h)
	trans:draw(t,w,h,{clip={textura}})
end

GL:start()
--]=]

return make


