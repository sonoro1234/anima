local plugin = require"anima.plugins.plugin"
local vert_shad = [[

void main()
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = ftransform();
}

]]
local frag_shad = [[
uniform sampler2D tex0,tex1;
uniform float alpha;
uniform int mode;

void main()
{
	
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	vec4 colorold = texture2D(tex1,gl_TexCoord[0].st);
	//gl_FragColor = max(colorold *alpha,color);

	
	gl_FragColor = colorold * alpha + color*(1.0 - abs(alpha)); 
	//vec4 colores = (colorold-0.5)*2.0 * alpha + (color-0.5)*2.0*(1.0 - abs(alpha)); 
	//gl_FragColor = colores*0.5+0.5;
}
]]
local frag_shad3 = [[
uniform sampler2D tex0,tex1;
uniform float alpha,alpha2;
uniform int mode;

void main()
{
	
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	vec4 colorold = texture2D(tex1,gl_TexCoord[0].st);
	vec4 colormax = max(colorold *alpha,color);
	vec4 color1 = colorold * alpha + color*(1.0 - abs(alpha));
	gl_FragColor = mix(color1,colormax,alpha2);

}
]]
local frag_shad2 = [[
uniform sampler2D tex0,tex1;
uniform float alpha;
uniform int mode;
void main()
{
	
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	vec4 colorold = texture2D(tex1,gl_TexCoord[0].st);
	
	//gl_FragColor = mix(colorold * alpha,color,color.a);
	
	vec4 mix = colorold * alpha;// + color;
	vec4 colormax = max(mix,color);
	gl_FragColor = colormax;
}
]]

local M = {}
function M.make(GL)
	
	local Clip = {}
	local NM = GL:Dialog("mblur",
{
{"alpha",0.0,guitypes.val,{min=0.0,max=1}},
{"alpha2",0,guitypes.val,{min=0,max=1}},
{"mode",1,guitypes.valint,{min=1,max=3}},
{"reset",false,guitypes.toggle},
}
)
	Clip.NM = NM
	local program
	local fbo
	local mixfbos = {}
	local mixindex = 0
	local FBOrep
	function Clip:init()

		fbo = initFBO(GL.W, GL.H)
		mixfbos[0] = initFBO(GL.W, GL.H)
		mixfbos[1] = initFBO(GL.W, GL.H)
		program = {}
		program[1] = GLSL:new():compile(vert_shad,frag_shad);
		program[2] = GLSL:new():compile(vert_shad,frag_shad2);
		program[3] = GLSL:new():compile(vert_shad,frag_shad3);
		FBOrep = ut.FBOReplicator()
		FBOrep:init()
		Clip.inited = true
	end



	function Clip:draw(timebegin,w,h,args)
		--prtable(args)
		--print"mblur"
		if not self.inited then self:init() end
		
		--alpha = math.pow(alpha,GL.fps/GL.FPS.fpsec)
		plugin.get_args(NM, args, timebegin)
		local theclip = args.clip

		local old_framebuffer = fbo:Bind()
		theclip[1]:draw(timebegin, w, h, theclip)
		
		local program = program[NM.mode]

		---[[
		program:use()
		mixindex = (mixindex + 1)%2
		mixfbos[mixindex]:Bind()
		
		fbo:UseTexture()
		mixindex = (mixindex + 1)%2
		mixfbos[mixindex]:UseTexture(1,0)
		
		local alpha = NM.alpha
		if NM.reset then
			alpha = 0
			NM.vars.reset[0] = false
		end
		program.unif.tex0:set{0}
		program.unif.tex1:set{1}
		program.unif.alpha:set{alpha}
		program.unif.alpha2:set{NM.alpha2}

		gl.glClearColor(0.0, 0.0, 0.0, 0)
		ut.Clear()

		ut.project(w,h)
		ut.DoQuad(w,h)
		--]]
		mixindex = (mixindex + 1)%2
		FBOrep:replicate(GL,mixfbos[mixindex].color_tex[0],old_framebuffer)
		--FBOrep:replicate(GL,fbo.color_tex[0],old_framebuffer)
		--[[
		--------ms tosingle fbo
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER,  old_framebuffer);   -- Make sure no FBO is set as the draw framebuffer
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER,  mixfbos[mixindex].fb[0]); -- Make sure your multisampled FBO is the read framebuffer
		if old_framebuffer == 0 then
			gl.glDrawBuffer(glc.GL_BACK);                       -- Set the back buffer as the draw buffer
		else
			gl.glDrawBuffer(glc.GL_COLOR_ATTACHMENT0); 
		end
		glext.glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, glc.GL_COLOR_BUFFER_BIT, glc.GL_LINEAR);
		--]]
	end
	GL:add_plugin(Clip)
	return Clip
end
return M