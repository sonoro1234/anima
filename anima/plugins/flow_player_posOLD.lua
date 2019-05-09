require"anima"
local vicim = require"anima.vicimag"

local vert_shad = [[
in vec2 position;
uniform sampler2D flow;
uniform vec2 size;
uniform float pos;
uniform bool fadeonly=false;
void main()
{
	vec4 delta = texture2D(flow,position);
	vec2 delt = delta.rg / size;
	
	if(fadeonly){
		delt = vec2(0);
	}
	
	gl_TexCoord[0] = vec4(position,0,1);
	gl_Position = gl_ModelViewProjectionMatrix*vec4(position + pos*delt, 0, 1);
	
}

]]
local frag_shad = [[
uniform sampler2D tex0;
uniform float alpha;
void main()
{
	
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	gl_FragColor = vec4(color.rgb,alpha);
}
]]
local function make_points(w,h)
	w = w -1
	h = h -1
	local texc = {};
	local texc2 = {};
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
	
	
	function fplay:init()
		self.program = GLSL:new():compile(vert_shad,frag_shad)
		self.tex1 = GL:Texture()
		self.tex2 = GL:Texture()
		local texc = make_points(GL.W,GL.H)
		self.vao = VAO({position=texc},self.program)
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
			print(#images,T1,T2,pos)
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
		self.program:use()
		local U = self.program.unif
		U.tex0:set{0}
		U.flow:set{1}
		U.pos:set{pos}
		U.alpha:set{1}
		U.size:set{self.flow.width,self.flow.height}
		U.fadeonly:set{fadeonly}
		self.tex1:Bind(0)
		self.tex1:set_wrap(glc.GL_CLAMP_TO_EDGE)
		self.flow:Bind(1)
		gl.glClearColor(0,0,0,0)
		ut.Clear()
		ut.project(1,1)
		gl.glViewport(0,0,w,h)
		self.vao:draw(glc.GL_POINTS)
		
		gl.glEnable(glc.GL_BLEND)
		gl.glBlendFunc(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA)
		
		self.tex2:Bind(0)
		self.tex2:set_wrap(glc.GL_CLAMP_TO_EDGE)
		self.bflow:Bind(1)
		U.pos:set{1 - pos}
		U.alpha:set{pos}
		self.vao:draw(glc.GL_POINTS)
		
		gl.glDisable(glc.GL_BLEND)
		
		gl.glEnable(glc.GL_DEPTH_TEST)
	end
	
	GL:add_plugin(fplay)
	return fplay
end
--[=[
local path = require"anima.path"
local images,fflows,bflows = {},{},{}

--local imdir =[[H:\pelis\palmeras\compressed1080\dosserierecortada_tn]]
local imdir = [[H:\pelis\ninfas\compressed1080\infrarojodos]]
funcdir(imdir,function(f) table.insert(images,f) end)
local function getflows(f)
	--print(f)
	local _,fnam = path.splitpath(f)
	if fnam:sub(1,1) == "b" then
		table.insert(bflows,f)
	else
		table.insert(fflows,f)
	end
end
-- 

--funcdir([[H:\pelis\palmeras\flow\dosserierecortada_tn]],getflows,"flo")
funcdir([[H:\pelis\ninfas\flow\infrarojodos]],getflows,"flo")

for i=#fflows + 2,#images do
	images[i] = nil
end
print(#images)
prtable(images,fflows,bflows)

GL = GLcanvas{fps=25,H=1080,viewH=700,aspect=3/2}

fpl = flow_player(GL)
args = {images=images,fflows=fflows,bflows=bflows,frame= AN({1,80,80*1})}
function GL.init()
end
function GL.draw(t,w,h)
	fpl:draw(t,w,h,args)
end

GL:start()
--]=]


return flow_player