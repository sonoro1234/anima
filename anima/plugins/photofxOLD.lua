require"anima"

local vert_shad = [[

void main()
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = ftransform();
}

]]
local frag_shad = require"anima.GLSL.GLSL_color"..[[
uniform sampler2D tex0;
uniform float ampL;
uniform float ampR;
uniform float black;
uniform float white;
uniform float saturation;
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
	vec3 color = tcolor.rgb;
	vec3 colhsv = RGB2HSV(color);
	float lum = colhsv.z ;//dot(color.rgb,vec3(1.0/3.0));
	float lum2 = clamp((lum - black)/(white - black),0.0, 1.0);
	/*
	float fac = lum2/lum;
	if (lum == 0.0)
		fac = 0;
		*/
	lum2 = sigmoidal(lum2,ampL,ampR);
	color = HSV2RGB(vec3(colhsv.x,clamp(saturation*colhsv.y,0,1),lum2));
	gl_FragColor = vec4(color,tcolor.a);
}
]]


local function Zoom(zoom,cx,cy,x,y)
	local x1 = zoom*(x-cx)+cx
	local y1 = zoom*(y-cy)+cy
	return x1,y1
end

local M = {}

function M.photofx(GL)
	local NM = GL:Dialog("photofx",
{
{"girarX",0,guitypes.toggle},
{"ampL",-0.01,guitypes.val,{min=-10,max=10}},
{"ampR",0.01,guitypes.val,{min=-10,max=10}},
{"black",0,guitypes.val,{min=0,max=1}},
{"white",1,guitypes.val,{min=0,max=2}},
{"saturation",1,guitypes.val,{min=0,max=1}},
{"zoom",1,guitypes.val,{min=0.1,max=10}},
{"centerX",0.5,guitypes.val,{min=0,max=1}},
{"centerY",0.5,guitypes.val,{min=0,max=1}},

},function(n,v)  end)

	local LM = {}
	local  program,fbo

	function LM.init()
		--if not GL.PPFBO then GL:init_PPFBO() end
		fbo = GL:initFBO()
		programfx = GLSL:new():compile(vert_shad,frag_shad)
		--program2 = GLSL:new():compile(nil,frag_shad2)
		LM.inited = true
	end
	
	local function get_args(t, timev)
		local clip = t.clip
		local girarX = ut.get_var(t.girarX, timev, NM.girarX==1)
		local ampL = ut.get_var(t.ampL, timev, NM.ampL)
		local ampR = ut.get_var(t.ampR, timev, NM.ampR)
		local black = ut.get_var(t.black, timev, NM.black)
		local white = ut.get_var(t.white, timev, NM.white)
		local saturation = ut.get_var(t.saturation, timev, NM.saturation)
		local zoom = ut.get_var(t.zoom, timev, NM.zoom)
		return clip,girarX, ampL,ampR, black, white,saturation,zoom
	end

	function LM:draw(timebegin, w, h, args)
		if not self.inited then self.init() end
		local theclip, girarX, ampL,ampR, black, white,saturation,zoom = get_args(args, timebegin)
		--print(ampL, ampR)
		local old_framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, old_framebuffer)
		--local fbo = GL.PPFBO:getDRAW()
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbo.fb[0]) --fbo.fb[0]);

		--glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, fbo.fb[0]);
		theclip[1]:draw(timebegin, w, h,theclip)
		---[[
		glext.glUseProgram(programfx.program);
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
		glext.glActiveTexture(glc.GL_TEXTURE0);
		gl.glBindTexture(glc.GL_TEXTURE_2D, fbo.color_tex[0])
		local modewrap = glc.GL_MIRRORED_REPEAT --glc.GL_REPEAT --glc.GL_MIRRORED_REPEAT
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
		GL:CheckSRGB()
			programfx.unif.tex0:set{0}
			programfx.unif.ampL:set{ampL}
			programfx.unif.ampR:set{ampR}
			programfx.unif.black:set{black}
			programfx.unif.white:set{white}
			programfx.unif.saturation:set{saturation}
			-- programmix.unif.tex1:set{1}
			-- programmix.unif.alpha:set{alpha}
			
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
	
		gl.glMatrixMode(glc.GL_PROJECTION)
		gl.glLoadIdentity()
		gl.glOrtho(0.0, w, 0.0, h, -1, 1);
			--gl.glOrtho(0.0, w, 0.0, h, -1, 1);
			--GL.camera:SetProjection()
		gl.glMatrixMode(glc.GL_MODELVIEW)
		gl.glLoadIdentity();
		gl.glViewport(0, 0, w, h)
	
		local zplane = 0
		local MESHH = h
		local MESHW = w
		-- GL.camera:SetProjection()
		-- gl.glLoadIdentity();
		-- GL.LookAt()
		-- gl.glTranslatef(-MESHW*0.5,-MESHH*0.5,0)
		
		local LP,RP
		if girarX  then
			LP = 1
			RP = 0
		else
			LP = 0
			RP = 1
		end
		local centerX = NM.centerX
		local centerY = NM.centerY

		gl.glBegin(glc.GL_QUADS)
		gl.glColor4f(1,1,1,1)
		gl.glTexCoord2f(Zoom(zoom,centerX,centerY,LP,0));
		gl.glVertex3f(0,0,zplane)
		gl.glTexCoord2f(Zoom(zoom,centerX,centerY,LP,1));
		gl.glVertex3f(0,MESHH,zplane)
		gl.glTexCoord2f(Zoom(zoom,centerX,centerY,RP,1));
		gl.glVertex3f(MESHW,MESHH,zplane)
		gl.glTexCoord2f(Zoom(zoom,centerX,centerY,RP,0));
		gl.glVertex3f(MESHW,0,zplane)
		gl.glEnd()
		--]]
	end
	GL:add_plugin(LM)
	return LM
end
--alias
M.make = M.photofx

---[=[
if not ... then
require"anima"
local GL = GLcanvas{H=800,aspect=3/2}
local tex,slab,lch
function GL.init()
	tex = GL:Texture():Load[[c:\luagl\media\estanque3.jpg]]
	--tex = GL:Texture():Load[[c:\luagl\media\piscina.tif]]
	slab = tex:make_slab()
	--GL:set_WH(tex.width,tex.height)
	lch = M.photofx(GL)
end
local enadt = ffi.new("GLboolean[1]")
function GL.draw(t,w,h)
	-- lch:process(slab,tex)
	-- slab.ping:GetTexture():draw(t,w,h)
	gl.glGetBooleanv(glc.GL_DEPTH_TEST,enadt)
	--print("DT",enadt[0])
	lch:draw(t,w,h,{clip={tex}})
end
GL:start()
end
--]=]
return M


