

local vert_shad = [[
in vec3 Position;
in vec2 texcoords;
void main()
{
	gl_TexCoord[0] = vec4(texcoords,0,1);
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



void main()
{

	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	float norm = distance(color.rgb,tcolor);
	float a = smoothstep(maxdist-stepd,maxdist,norm);
	if(mode == 1)
		a = clamp(0.0,1.0,norm/maxdist);
	if(invert)
		a = 1.0 - a;
	//gl_FragColor = color*a; //vec4(color.rgb*a,a);
	gl_FragColor = vec4(color.rgb,color.a*a);	
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
//a* is -79 to 94, and the range of b* is -112 to 93
vec3 laboffset = vec3(0.0,0.5,0.5);
float LabDistance(vec3 col1,vec3 col2){
	vec3 collab1 = XYZ2LAB(RGB2XYZ(sRGB2RGB(col1)),D65);
	vec3 collab2 = XYZ2LAB(RGB2XYZ(sRGB2RGB(col2)),D65);
	
	collab1 = collab1*labscale + laboffset;
	collab2 = collab2*labscale + laboffset;
	
	//return distance(collab1,collab2);
	return distance(collab1.yz,collab2.yz);
	//collab = collab*labscale + laboffset;
	//collab = (collab - laboffset)/labscale;
	//color = XYZ2RGB(LAB2XYZ(collab,D65));
}


void main()
{

	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	float norm = LabDistance(color.rgb,tcolor);
	float a = smoothstep(maxdist-stepd,maxdist,norm);
	if(mode == 1)
		a = clamp(0.0,1.0,norm/maxdist);
	if(invert)
		a = 1.0 - a;
	gl_FragColor = color*a; //vec4(color.rgb*a,a); 
}
]]


local function make(GL)--,args)
	args = args or {}
	local NM = GL:Dialog("color_trans",
{
{"maxdist",1,guitypes.val,{min=0,max=1}},
{"stepd",0,guitypes.val,{min=0,max=1}},
{"mode",1,guitypes.valint,{min=0,max=1}},
{"Lab",false,guitypes.toggle},
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
							this.vars.r[0] = pUD[0]
							this.vars.g[0] = pUD[1]
							this.vars.b[0] = pUD[2]
							this.vars.maxdist[0] = oldmaxdist
							GL.mouse_pick = nil
						end}

end},
{"r",1,guitypes.val,{min=0,max=1}},
{"g",1,guitypes.val,{min=0,max=1}},
{"b",1,guitypes.val,{min=0,max=1}},

})
	
	local plugin = require"anima.plugins.plugin"
	local LM = plugin.new{res={GL.W,GL.H}}
	LM.NM = NM
	local fbo, programfx, progrgb,proglab
	local lapse,oldtime,lapsesum = 0,0,0
	function LM:init()
		fbo = GL:initFBO()
		proglab = GLSL:new():compile(vert_shad,frag_shad_Lab)

		progrgb = GLSL:new():compile(vert_shad,frag_shad)

		local m = mesh.Quad(-1,-1,1,1)
		LM.vao = VAO({Position=m.points,texcoords = m.texcoords},progrgb,m.indexes)
		self.inited = true
	end
	
	local function get_args(t, timev)
		local clip = t.clip
		local tcolor = ut.get_var(t.tcolor,timev,{NM.r,NM.g,NM.b})
		local maxdist = ut.get_var(t.maxdist,timev,NM.maxdist)
		return clip,tcolor,maxdist
	end
	
	
	function LM:process(srctex,w,h)
		srctex:Bind()
		programfx = NM.Lab and proglab or progrgb
		
		programfx:use()
		programfx.unif.tex0:set{0}
		programfx.unif.maxdist:set{NM.maxdist}
		programfx.unif.stepd:set{NM.stepd}
		programfx.unif.mode:set{NM.mode}
		programfx.unif.invert:set{NM.invert}
		programfx.unif.tcolor:set{NM.r,NM.g,NM.b}

		gl.glViewport(0,0,w or self.res[1], h or self.res[2])
		ut.Clear()
		self.vao:draw_elm()

	end
	

	
	function LM:draw(timebegin, w, h, args)
		if not self.inited then self:init() end
		
		local theclip,tcolor,maxdist = get_args(args, timebegin)
		
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
		
		programfx = NM.Lab and proglab or progrgb
		
		programfx:use()
		
		
		programfx.unif.tex0:set{0}
		programfx.unif.maxdist:set{maxdist}
		programfx.unif.stepd:set{NM.stepd}
		programfx.unif.mode:set{NM.mode}
		programfx.unif.invert:set{NM.invert}
		programfx.unif.tcolor:set{unpack(tcolor)}

		gl.glViewport(0,0,w,h)
		ut.Clear()
		self.vao:draw_elm()
		
	end
	GL:add_plugin(LM)
	return LM
end

--[=[
require"anima"
GL = GLcanvas{H=1080,viewH=700,aspect=1.5}
trans = make(GL)
local textura
function GL.init()
	textura = GL:Texture()
	print(textura)
	textura = textura:Load[[C:\luagl\animacion\resonator6\resonator-038.jpg]]
end

function GL.draw(t,w,h)

	trans:draw(t,w,h,{clip={textura}})

end

GL:start()
--]=]

return make


