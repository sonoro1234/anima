
local vicim = require"anima.vicimag"

local vert_mix = [[
void main()
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = ftransform();
}

]]

local frag_mix = [[
uniform sampler2D tex1;
uniform sampler2D tex2;
uniform float alpha;
void main()
{
	vec4 color1 = texture2D(tex1,gl_TexCoord[0].st);
	vec4 color2 = texture2D(tex2,gl_TexCoord[0].st);
	gl_FragColor = mix(color1,color2,alpha);
}

]]

local vert_shad = [[
in vec2 texc;
uniform sampler2D flow;
uniform vec2 size;
uniform float pos;

void main()
{

	vec4 delta = texture2D(flow,texc);
	vec2 delt = delta.rg / size;
	gl_TexCoord[0] = vec4(texc,0,1);
	
	/*
	if(texc.x == 0.0 || texc.x == 1.0)
		delt.x = 0.0;
		
	if(texc.y == 0.0 || texc.y == 1.0)
		delt.y = 0.0;
	*/
	
	if(texc.x == 0.0 || texc.x == 1.0 || texc.y == 0.0 || texc.y == 1.0)
		delt.x = delt.y = 0.0;
		
	vec4 position = vec4(texc,0,1) + pos*vec4(delt,0,0);
	gl_Position = gl_ModelViewProjectionMatrix * position;

}

]]
local frag_shad = [[
uniform sampler2D tex0;
uniform float alpha;
uniform bool dogrey;
vec3 togrey = vec3(0.299, 0.587, 0.114);
void main()
{
	
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	if(dogrey)
		color = vec4(dot(color.rgb,togrey));
	gl_FragColor = vec4(color.rgb,alpha);
}
]]

local function make_mesh(stacks, slices)

    local mesh = {}

    -- Generate verts.
    mesh.npoints = (slices + 1) * (stacks + 1);
    mesh.points = {} --ffi.new("float[?]", 3 * mesh.npoints);

    local points = mesh.points;
	local istacks = 1.0/stacks
	local islices = 1.0/slices
    for stack = 0, stacks do
        local X = stack * istacks;
        for slice = 0, slices do
            local Y = slice * islices;
            points[#points + 1] = X
            points[#points + 1] = Y
        end
    end

    -- Generate faces.
    mesh.ntriangles = 2 * slices * stacks;
    mesh.triangles = {} --PAR_CALLOC(PAR_SHAPES_T, 3 * mesh->ntriangles);
    local v = 0;
    local face = mesh.triangles;
    for stack = 0, stacks - 1 do
        for slice = 0,slices -1 do
            local next = slice + 1;
            face[#face + 1] = v + slice + slices + 1;
            face[#face + 1] = v + next;
            face[#face + 1] = v + slice;
            face[#face + 1] = v + slice + slices + 1;
            face[#face + 1] = v + next + slices + 1;
            face[#face + 1] = v + next;
        end
        v = v + slices + 1;
    end

    return mesh;
end
local function modul(i,n)
	local r = i%n
	return (r~=0) and r or n
end

local function flow_player(GL)
	local fplay = {}
	
	function fplay:init()
		self.program = GLSL:new():compile(vert_shad,frag_shad)
		self.program_mix = GLSL:new():compile(vert_mix,frag_mix)
		self.tex1 = GL:Texture()
		self.tex2 = GL:Texture()
	end
	function fplay:make_mesh(w,h)
		local mesh1 = make_mesh(w -1,h-1)
		self.meshsizes = {w,h}
		self.vao1 = VAO({texc=mesh1.points},self.program, mesh1.triangles)
	end
	local function get_args(t,timev)
		local images = t.images
		local frame = ut.get_var(t.frame,timev,1)
		return t.images, t.fflows, t.bflows, frame
	end
	
	function fplay:draw(t,w,h,args)
		local images, fflows, bflows ,frame = get_args(args,t)
		local fr1 = math.floor(frame)
		local pos = frame - fr1
		local T1 = modul(fr1 , #images)
		local T2 = modul((T1 + 1) , #images )
		
		--print(#images,T1,T2,pos)
		if images[T1] ~= self.oldT1 then
			--print(#images,T1,T2,pos)
			if args.verbose then print("reload 1", images[T1],pos) end
			glext.glActiveTexture(glc.GL_TEXTURE0);
			self.tex1:Load(images[T1])
			self.oldT1 = images[T1]
			glext.glActiveTexture(glc.GL_TEXTURE1);
			self.tex2:Load(images[T2])
			-- self.flow = vicim.optflow2tex(fflows[T1],self.flow)
			-- self.bflow = vicim.optflow2tex(bflows[T1],self.bflow)
			self.flow = vicim.vicimag2tex(fflows[T1],GL,self.flow)
			self.bflow = vicim.vicimag2tex(bflows[T1],GL,self.bflow)
			if not self.meshsizes then
				self:make_mesh(self.flow.width,self.flow.height)
				--self:make_mesh(self.tex1.width,self.tex1.height)
				--self:make_mesh(GL.viewW,GL.viewH)
				--self:make_mesh(18*2,12*2)
				gl.glPointSize(GL.H/self.meshsizes[2])
			end
		end
		
	-- gl.glFrontFace(glc.GL_CCW);
	-- gl.glCullFace(glc.GL_BACK); 
	-- gl.glEnable(glc.GL_CULL_FACE); 
		
		gl.glDisable(glc.GL_DEPTH_TEST)	
		ut.Clear()
		--[[
		self.program_mix:use()
		local U = self.program_mix.unif
		U.tex1:set{0}
		U.tex2:set{1}
		U.alpha:set{pos}
		self.tex1:Bind(0)
		self.tex2:Bind(1)
		ut.project(w,h)
		ut.DoQuad(w,h)
		--]]
		---[[
		ut.project(1,1)
		gl.glViewport(0, 0, w, h)
		

		self.program:use()
		local U = self.program.unif
		

		U.tex0:set{0}
		U.flow:set{1}
		U.pos:set{pos}
		U.alpha:set{1-pos}
		U.size:set{self.flow.width,self.flow.height}
		self.tex1:Bind(0)
		self.flow:Bind(1)


		
		
		self.vao1:draw_elm()
		--self.vao1:draw(glc.GL_POINTS)
		--self.vao1:draw_mesh()--,glc.GL_TRIANGLES)

		gl.glEnable(glc.GL_BLEND)
		--gl.glBlendFunc(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA)
		glext.glBlendFuncSeparate(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA, glc.GL_ONE, glc.GL_ONE)
		glext.glBlendEquation(glc.GL_FUNC_ADD)
		U.pos:set{1-pos}
		U.alpha:set{pos}
		self.tex2:Bind(0)
		self.bflow:Bind(1)
		self.vao1:draw_elm()
		--self.vao1:draw(glc.GL_POINTS)
		gl.glDisable(glc.GL_BLEND)
	--]]
		gl.glEnable(glc.GL_DEPTH_TEST)
	end
	
	GL:add_plugin(fplay)
	return fplay
end
--[[
mesh = make_mesh(10,10)

for i,v in ipairs(mesh.triangles) do
print(i,v)
end
--]]
--[=[
DORENDER = false
local path = require"anima.path"
local images,fflows,bflows = {},{},{}
--local imdir = [[H:\pelis\palmeras\compressed1080\dosserierecortada_tn]]
local imdir
local carp = "fati3" --"bolasluz" --"fati3" --"olas_azul"
local carpflow = "fati3brox"--"bolasluz" --"fati3brox" --"olas_azul_brox"
if DORENDER then
	imdir = [[H:\pelis\ninfas\master1080\]]..carp
else
	imdir = [[H:\pelis\ninfas\compressed1080\]]..carp
end
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
funcdir([[H:\pelis\ninfas\flow\]]..carpflow,getflows,"flo")
--funcdir([[H:\pelis\palmeras\flow\dosserierecortada_tnbrox]],getflows,"flo")
--funcdir([[H:\pelis\palmeras\flow\dosserierecortada_tn005rr]],getflows,"flo")
--funcdir([[H:\pelis\palmeras\flow\dosserierecortada_tn]],getflows,"flo")

for i=#bflows + 2,#images do
	images[i] = nil
end
print(#images)
prtable(images,fflows,bflows)

GL = GLcanvas{fps=25,H=1080,viewH=700,aspect=3/2,DORENDER=DORENDER,RENDERINI=0,RENDEREND=30,use_fbo=true}
GL:setMovie[[H:\pelis\test]]

function GL.init()
	
end
fpl = flow_player(GL)
args = {images=images,fflows=fflows,bflows=bflows,frame= AN({1,80,80*3})}

function GL.draw(t,w,h)
	fpl:draw(t,w,h,args)
	--glext.glUseProgram(0)
	--ut.Clear()
	--textura:Show(w,h)

end

GL:start()
--]=]
--[=[
local path = require"anima.path"
local images,fflows,bflows = {},{},{}

funcdir([[H:\pelis\palmeras\compressed1080\dosserierecortada_tn]],function(f) table.insert(images,f) end)
local function getflows(f)
	--print(f)
	local _,fnam = path.splitpath(f)
	if fnam:match("backward") then
		table.insert(bflows,f)
	else
		table.insert(fflows,f)
	end
end
funcdir([[C:\slowmoVideo\palmerasdosrecortadas\cache\oFlowOrig]],getflows)

for i=#fflows + 2,#images do
	images[i] = nil
end
print(#images)
prtable(images,fflows,bflows)

GL = GLcanvas{fps=25,H=1080,viewH=700,aspect=3/2}

fpl = flow_player(GL)
args = {images=images,fflows=fflows,bflows=bflows,frame= AN({1,20,40})}
function GL.init()
end
function GL.draw(t,w,h)
	fpl:draw(t,w,h,args)
end

GL:start()
--]=]
--[=[
GL = GLcanvas{fps=25,H=1080,viewH=700,aspect=3/2}
folderpl = require"glutils.GLFolderClip"(GL)
clip = folderpl:make_clip([[H:\pelis\palmeras\compressed1080\dosserierecortada_tn_sl]],0.1,nil,nil,40,0)

function GL.draw(t,w,h)
	folderpl:draw(t,w,h,clip)
end
GL:start()
--]=]

return flow_player