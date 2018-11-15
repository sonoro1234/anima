require"anima"

local function getctx()
	local ctx
	if glfw then
		ctx = tostring(glfw.glfwGetCurrentContext())
	else
		ctx = tostring(sdl.gL_GetCurrentContext())
	end
	return ctx
end
local texcrops = {}
local function make_texcrop_prog()
	local ctx = getctx()
	local prog = texcrops[ctx]
	if prog then return prog end
	
	local P3 = {}
	function P3:init()
		local vert_shad = [[
	in vec3 pos;
	void main()
	{
		gl_Position = vec4(pos,1);
	}
	
	]]
	local frag_shad = [[
	uniform sampler2D tex0;
	ivec2 tsize = textureSize(tex0,0);
	uniform ivec2 offset;
	void main()
	{
		vec2 uv = (gl_FragCoord.xy+offset)/tsize;
		gl_FragColor = texture2D(tex0,uv);
	}
	]]
	
		self.program = GLSL:new():compile(vert_shad,frag_shad)
		local m = mesh.Quad(-1,-1,1,1)
		self.vao = VAO({pos=m.points},self.program,m.indexes)
		self.inited = true
	end
	function P3:process(w,h,offx,offy)
		if not self.inited then self:init() end
		self.program:use()
		self.program.unif.tex0:set{0}
		self.program.unif.offset:set{offx or 0,offy or 0}
		gl.glViewport(0,0,w,h)
		self.vao:draw_elm()
		glext.glUseProgram(0)
	end
	texcrops[ctx] = P3
	return P3
end

local texflips = {}
local function make_texflip_prog()
	local ctx = getctx()
	local prog = texflips[ctx]
	if prog then return prog end
	
	local P3 = {}
	function P3:init()
		local vert_shad = [[
	in vec3 pos;
	void main()
	{
		gl_Position = vec4(pos,1);
	}
	
	]]
	local frag_shad = [[
	uniform sampler2D tex0;
	ivec2 tsize = textureSize(tex0,0);
	uniform bool flip;
	uniform bool mirror;
	void main()
	{
		vec2 uv = (gl_FragCoord.xy)/tsize;
		if(flip)
			uv.y = 1.0 -uv.y;
		if(mirror)
			uv.x = 1.0 -uv.x;
		gl_FragColor = texture2D(tex0,uv);
	}
	]]
	
		self.program = GLSL:new():compile(vert_shad,frag_shad)
		local m = mesh.Quad(-1,-1,1,1)
		self.vao = VAO({pos=m.points},self.program,m.indexes)
		self.inited = true
	end
	function P3:process(w,h,flip,mirror)
		if not self.inited then self:init() end
		self.program:use()
		self.program.unif.tex0:set{0}
		self.program.unif.flip:set{flip or false}
		self.program.unif.mirror:set{mirror or false}
		gl.glViewport(0,0,w,h)
		self.vao:draw_elm()
		glext.glUseProgram(0)
	end
	texflips[ctx] = P3
	return P3
end

local texrotate = {}
local function make_texrotate_prog()
	local ctx = getctx()
	local prog = texrotate[ctx]
	if prog then return prog end
	
	local P3 = {}
	function P3:init()
		local vert_shad = [[
	in vec3 pos;
	void main()
	{
		gl_Position = vec4(pos,1);
	}
	
	]]
	local frag_shad = [[
	uniform sampler2D tex0;
	ivec2 tsize = textureSize(tex0,0);
	uniform int numquarters = 1;
	void main()
	{
		vec2 uv = (gl_FragCoord.xy)/tsize;
		vec2 uvc = uv - 0.5;
		switch(numquarters){
			case 1:
				uvc = vec2(-uvc.y,uvc.x);
				break;
			case 2:
				uvc = vec2(-uvc.x,-uvc.y);
				break;
			case 3:
				uvc = vec2(uvc.y,-uvc.x);
				break;
		}
		uv = uvc + 0.5;
		gl_FragColor = texture2D(tex0,uv);
	}
	]]
	
		self.program = GLSL:new():compile(vert_shad,frag_shad)
		local m = mesh.Quad(-1,-1,1,1)
		self.vao = VAO({pos=m.points},self.program,m.indexes)
		self.inited = true
	end
	function P3:process(w,h,quarters)
		if not self.inited then self:init() end
		self.program:use()
		self.program.unif.tex0:set{0}
		self.program.unif.numquarters:set{quarters}
		gl.glViewport(0,0,w,h)
		self.vao:draw_elm()
		glext.glUseProgram(0)
	end
	texrotate[ctx] = P3
	return P3
end

local vert_shad = [[
	in vec3 pos;
	void main()
	{
		gl_Position = vec4(pos,1);
	}
	
	]]
local frag_fus = [[
			uniform sampler2D texA;
			uniform sampler2D texB;
			uniform sampler2D texC;
			uniform sampler2D texD;
			uniform float del = 0.4;
			ivec2 size = textureSize(texA,0);
			float a,b,c,d;
			void main(){
				vec2 uv = gl_FragCoord.xy/size;
				vec2 uvc = uv*2 - 1;
				
				float da1 = uvc.y - uvc.x;
				float da2 = uvc.y + uvc.x;
				float a1 = smoothstep(-del,0,da1);
				float a2 = smoothstep(-del,0,da2);
				a = a1*a2;
				float b1 = smoothstep(-del,0,-da1);
				float b2 = smoothstep(-del,0,da2);
				b = b1*b2;
				float c1 = smoothstep(-del,0,-da1);
				float c2 = smoothstep(-del,0,-da2);
				c = c1*c2;
				float d1 = smoothstep(-del,0,da1);
				float d2 = smoothstep(-del,0,-da2);
				d = d1*d2;
				//a=b=0;
				float sum = a+b+c+d;
				gl_FragColor = (a*texture(texA,uv)+b*texture(texB,uv)+c*texture(texC,uv)+d*texture(texD,uv))/sum;
			}
		]]
local M = {}
function M.rotate(tex,quarts)
	local fbo = tex:make_fbo()
	local pp = make_texrotate_prog()
	fbo:Bind()
	tex:Bind()
	pp:process(tex.width,tex.height,quarts)
	fbo:UnBind()
	local ret = fbo:tex()
	fbo:delete(true)
	return ret
end
function M.flip(tex,flip,mirror)
	local fbo = tex:make_fbo()
	local pp = make_texflip_prog()
	fbo:Bind()
	tex:Bind()
	pp:process(tex.width,tex.height,flip,mirror)
	fbo:UnBind()
	local ret = fbo:tex()
	fbo:delete(true)
	return ret
end
function M.crop(tex,x,y,w,h)
	local fbo = initFBO(w,h,{no_depth=true})
	local pp = make_texcrop_prog()
	fbo:Bind()
	tex:Bind()
	pp:process(w,h,x,y)
	fbo:UnBind()
	local ret = fbo:tex()
	fbo:delete(true)
	return ret
end

function M.fusion(A,B,C,D)
	local pp = GLSL:new():compile(vert_shad,frag_fus)
	local m = mesh.Quad(-1,-1,1,1)
	local vao = VAO({pos=m.points},pp,m.indexes)
	local fbo = A:make_fbo()
	fbo:Bind()
	pp:use()
	local U = pp.unif
	U.del:set{0.2}
	U.texA:set{0}
	U.texB:set{1}
	U.texC:set{2}
	U.texD:set{3}
	C:Bind(2)
	D:Bind(3)
	B:Bind(1)
	A:Bind(0)
	vao:draw_elm()
	fbo:UnBind()
	local ret = fbo:tex()
	fbo:delete(true)
	return ret
end
function M.color(t,w,h)
	local fbo = initFBO(w,h,{no_depth=true})
	fbo:Bind()
	gl.glClearColor(unpack(t))
	ut.Clear()
	local ret = fbo:tex()
	fbo:delete(true)
	return ret
end

return M

