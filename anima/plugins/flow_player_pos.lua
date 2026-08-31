require"anima"
local vicim = require"anima.vicimag"

local vert_std = [[
in vec3 position;
in vec2 texcoords;
out vec4 t_coor_f;
uniform mat4 MVP;
	void main()
	{
		//t_coor_f = gl_MultiTexCoord0;
		//t_coor_f = vec4(position.xy,0,1);
		t_coor_f = vec4(texcoords,0,1);
		//gl_FrontColor = gl_Color;
		//gl_Position = ftransform();
		//gl_Position = gl_ModelViewProjectionMatrix*gl_Vertex;
		//gl_Position = MVP*gl_Vertex;
		gl_Position = MVP*vec4(position.xy,0,1);
	}
	]]

local frag_inp = [[
uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float alpha;
in vec4 t_coor_f;
out vec4 fcolor;
void main()
{
	fcolor = mix(texture2D(tex0,t_coor_f.st),texture2D(tex1,t_coor_f.st),alpha);
}
]]

local vert_shad = [[
in vec2 position;
uniform sampler2D flow;
uniform vec2 size;
uniform float pos;
uniform bool fadeonly=false;
out vec4 t_coor_f;
uniform mat4 MVP;
void main()
{
	vec4 delta = texture2D(flow,position);
	vec2 delt = delta.rg / size;
	
	if(fadeonly){
		delt = vec2(0);
	}
	
	t_coor_f = vec4(position,0,1);
	gl_Position = MVP*vec4(position + pos*delt, 0, 1);
	
}

]]
local frag_shad = [[
uniform sampler2D tex0;
uniform float alpha;
in vec4 t_coor_f;
out vec4 fcolor;
void main()
{
	
	vec4 color = texture2D(tex0,t_coor_f.st);
	fcolor = vec4(color.rgb,alpha);
}
]]
local function make_points(w,h)
	w = w -1
	h = h -1
	local texc = {};
	for j = 0, h do
        local Y = j / h;
		for i = 0, w do
			local X = i / w;
            texc[#texc + 1] = X
            texc[#texc + 1] = Y
        end
    end
	return texc
end
local function modul(i,n)
	local r = i%n
	return (r~=0) and r or n
end

local function flow_player(GL)
	local fplay = {}
	
	local NM = GL:Dialog("fpp",{
	{"inpaint",true,guitypes.toggle},{"dopos",true,guitypes.toggle}})
	fplay.NM = NM
	
	function fplay:init()
		self.program = GLSL:new():compile(vert_shad,frag_shad)
		self.prinp = GLSL:new():compile(vert_std,frag_inp)
		self.tex1 = GL:Texture()
		self.tex2 = GL:Texture()
		local texc = make_points(GL.W,GL.H)
		self.vao = VAO({position=texc},self.program)
		self.vao2 = mesh.quad(0,0,GL.W,GL.H):vao(self.prinp)
	end
	
	local function get_args(t,timev)
		local images = t.images
		local frame = ut.get_var(t.frame,timev,1)
		local fadeonly = ut.get_var(t.fadeonly,timev,false)
		return t.images, t.fflows, t.bflows, frame, fadeonly
	end
	
	function fplay:draw(t,w,h,args)
		local images, fflows, bflows ,frame, fadeonly = get_args(args,t)
		local fr1 = math.floor(frame)
		local pos = frame - fr1
		local T1 = modul(fr1 , #images)
		local T2 = modul((T1 + 1) , #images )
		
		--print(#images,T1,T2,pos)
		if images[T1] ~= self.oldT1 then
			--print(#images,T1,T2,pos)
			if args.verbose then print("reload 1", images[T1],pos) end
			--glext.glActiveTexture(glc.GL_TEXTURE0);
			self.tex1:Load(images[T1])
			self.oldT1 = images[T1]
			--glext.glActiveTexture(glc.GL_TEXTURE1);
			self.tex2:Load(images[T2])
			self.flow = vicim.vicimag2tex(fflows[T1],GL,self.flow)
			self.bflow = vicim.vicimag2tex(bflows[T1],GL,self.bflow)
		end
		
		gl.glPointSize(args.pointsize or 1)
		gl.glDisable(glc.GL_DEPTH_TEST)	

		gl.glClearColor(0,0,0,0)
		ut.Clear()
		
		if NM.inpaint then
			self.prinp:use()
			local U = self.prinp.unif
			U.alpha:set{pos}
			U.tex0:set{0}
			U.tex1:set{1}
			self.tex1:Bind(0)
			self.tex2:Bind(1)
			--ut.project(w,h)
			local MP = mat.ortho(0, w, 0, h, -1, 1);
			U.MVP:set(MP.gl)
			gl.glViewport(0,0,w,h)
			--ut.DoQuad(w,h)
			self.vao2:draw_elm()--glc.GL_POINTS)
		end
		
		if NM.dopos then
		
		gl.glDisable(glc.GL_BLEND)
		
		self.program:use()
		local U = self.program.unif
		U.tex0:set{0}
		U.flow:set{1}
		U.pos:set{pos}
		U.alpha:set{1} -- -pos}
		U.size:set{self.flow.width,self.flow.height}
		U.fadeonly:set{fadeonly}
		self.tex1:Bind(0)
		self.tex1:set_wrap()--glc.GL_CLAMP_TO_EDGE)
		self.flow:Bind(1)
		--gl.glClearColor(0,0,0,0)
		--ut.Clear()
		--ut.project(1,1)
		local MP = mat.ortho(0, 1, 0, 1, -1, 1);
		U.MVP:set(MP.gl)
		gl.glViewport(0,0,w,h)
		self.vao:draw(glc.GL_POINTS)
		---[[
		gl.glEnable(glc.GL_BLEND)
		gl.glBlendFunc(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA)
		--gl.glBlendColor(1,1,1,1)
		--glext.glBlendFuncSeparate(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA,glc.GL_ONE,glc.GL_ONE)
		
		self.tex2:Bind(0)
		self.tex2:set_wrap()--glc.GL_CLAMP_TO_EDGE)
		self.bflow:Bind(1)
		U.pos:set{1 - pos}
		U.alpha:set{pos}
		self.vao:draw(glc.GL_POINTS)
		
		gl.glDisable(glc.GL_BLEND)
		--]]
		end
		
		gl.glEnable(glc.GL_DEPTH_TEST)
	end
	
	GL:add_plugin(fplay,"flow_player_pos")
	return fplay
end

if not ... then
---[=[
GL = GLcanvas{fps=25,H=1080,viewH=700,aspect=3/2,profile="CORE"}

local fpl --= flow_player(GL)
--args = {images=images,fflows=fflows,bflows=bflows,frame= AN({1,80,80*1})}
local fpl2 = require"anima.plugins.flow_player"(GL)
local args = fpl2:loadimages("lotomask","lotomask_tvl1",[[C:\LuaGL\pelis\caprichos]])
--args.frame = AN({8,9,4},{9,20+16,4*25})
args.frame = AN({9,20+16,4*25})
args.doclamp = true
local tex 
function GL.init()
	tex = GL:Texture():Load([[C:\LuaGL\pelis\caprichos\master1080\lotomask\frame-0001.tif]])
	GL:set_WH(tex.width, tex.height)
	--init here to have GL.W and H
	fpl = flow_player(GL)
end
function GL.draw(t,w,h)
	fpl:draw(t,w,h,args)
end

GL:start()
--]=]
end

return flow_player