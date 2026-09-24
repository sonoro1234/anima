require"anima"

local glmatrix = require"anima.glmatrix"

local vert_shada1 = [[

uniform sampler2D tex0;
uniform float extfac;
uniform mat4 TM;
uniform mat4 MVP;
out vec4 tcoordf;
in vec3 normal;
in vec3 position;
void main()
{
	
	tcoordf = TM * vec4(position,1);//gl_Vertex;
	vec4 color = texture2D(tex0,tcoordf.st);
	//vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
	//vec3 normal = gl_Normal;
	
	float lum = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722)) - 0.5;
	vec4 Vertex = vec4(position,1);
	Vertex.xyz += normal*lum*extfac;
	/*
	if(extfac > 0.0){
		gl_Vertex.xyz += normal*lum*extfac;
	}else{
		gl_Vertex.xyz += normal*(lum-1.0)*extfac;
	}	
	*/
	gl_Position = MVP * Vertex;
}

]]

local frag_shada = [[

uniform sampler2D tex0;
in vec4 tcoordf;
out vec4 fcolor;
void main()
{
  vec4 color = texture2D(tex0,tcoordf.st);
  fcolor = color; 
}
]]


local function CreateMesh1(MESHW,MESHH,piecesX,piecesY)
	
	local wfac,yfac

	wfac = MESHW/(piecesX)
	yfac = MESHH/(piecesY)
		
	--local meshList = gl.glGenLists(1);
	print("making meshList clip1",meshList)
	--gl.glNewList(meshList, glc.GL_COMPILE);
	local points = {}
	local normals = {}
	local first = {}
	local count = {}
	for j=0,piecesY-1 do
		--gl.glBegin(glc.GL_TRIANGLE_STRIP)
		table.insert(first,#points)
        for i=0,piecesX do
			--[j][i] = {}
			for k=0,1 do
				local x = i*wfac
				local y = (j+k)*yfac 
				local yt = (j+k)/piecesY
				local xt = i/piecesX
				local xu,yu,zu = x-MESHW*0.5,y-MESHH*0.5,0 
				-- gl.glNormal3f(0, 0,1);
				-- gl.glVertex3f( xu, yu,zu) 
				table.insert(normals, mat.vec3(0,0,1))
				table.insert(points, mat.vec3(xu, yu,zu))
			end
		end
		table.insert(count,#points-first[#first])
		--gl.glEnd()
	end
	--gl.glEndList();
	local primcount = #first
	first = ffi.new("GLint[?]",#first,first)
	count = ffi.new("GLsizei[?]",#count,count)
	local mesh = require"anima.mesh"
	return mesh.mesh({points=points,normals=normals}),first,count,primcount
end



local M ={}
function M.make(GL)
	local plugin = require"anima.plugins.plugin"
	local NM = GL:Dialog("extrude",
{
{"extfac",0,guitypes.val,{min=-2,max=2}},
})

	local P = plugin.new{res={GL.W,GL.H},name="extrudecolor"}--plug.new(nil,GL)
	P.name = "xmajhgdu"
	assert(getmetatable(P))
	P.camera = newCamera(GL,true,"extrude")
	local DBox = GL:DialogBox("extruder")
	DBox:add_dialog(NM)
	DBox:add_dialog(P.camera.NMC)
	P.NM = DBox 
	-- P.NM = NM
	local first, count, primcount
	function P:init()
		--self = P
		self.fbo = GL:initFBO()
		
		self.program = GLSL:new()
		self.program:compile(vert_shada1,frag_shada);
		local mesh 
		mesh, first, count, primcount = CreateMesh1(GL.aspect,1,GL.W,GL.H)
		self.vao = mesh:vao(self.program)
		--self.meshlist = CreateMesh(GL.aspect,1,GL.W,GL.H)
		self.inited = true
	end
	local function get_args(t, timev)
		local clip = t.clip
		--local extfac = ut.get_var(t.extfac,timev,NM.extfac)
		local camara = ut.get_var(t.camara,timev,P.camera)
		return clip,camara
	end
	function P:process(texture,w,h)
		-- self.NM.dirty = self.NM.dirty or self.camera.NMC.dirty
		-- print(self.NM.dirty, self.camera.NMC.dirty)
		w,h = w or self.res[1], h or self.res[2]
		if not self.inited then self:init() end

		
		local old_framebuffer = self.fbo:Bind()
		texture:draw(tim, w, h)
		
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer);
		self.fbo:UseTexture()
		
		self.program:use()
		self.program.unif.tex0:set{0}
		self.program.unif.extfac:set{NM.extfac}
		
		local TM = mat.translate(0.5, 0.5, 0)
		TM = TM * mat.scale(h/w,1,1)
		self.program.unif.TM:set(TM.gl)
		
		gl.glClearColor(0.0, 0, 0, 0)
		ut.Clear()

		self.program.unif.MVP:set(self.camera:MVP().gl)
		gl.glViewport(0,0,w,h)
	
		self.vao:multi_draw(glc.GL_TRIANGLE_STRIP, first, count, primcount)
		
	end
	function P:draw(tim,w,h,args)
		if not self.inited then self:init() end
		local theclip,camara = get_args(args,tim)
		plugin.get_args(NM,args,tim)
		
		local old_framebuffer = self.fbo:Bind()
		theclip[1]:draw(tim, w, h,theclip)
		
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer);
		self.fbo:UseTexture()
		
		self.program:use()
		self.program.unif.tex0:set{0}
		self.program.unif.extfac:set{NM.extfac}
		
		-- gl.glMatrixMode(glc.GL_TEXTURE);
		-- gl.glPushMatrix()
		-- gl.glLoadIdentity();
		-- gl.glTranslated(0.5, 0.5, 0);
		-- gl.glScaled(h/w,1,1)
		local TM = mat.translate(0.5, 0.5, 0)
		TM = TM * mat.scale(h/w,1,1)
		self.program.unif.TM:set(TM.gl)
		
		gl.glClearColor(0.0, 0, 0, 0)
		ut.Clear()

		--camara:Set()
		self.program.unif.MVP:set(camara:MVP().gl)
		gl.glViewport(0,0,w,h)
	
		--gl.glCallList(self.meshlist);
		self.vao:multi_draw(glc.GL_TRIANGLE_STRIP, first, count, primcount)
		
		-- gl.glMatrixMode(glc.GL_TEXTURE);
		-- gl.glPopMatrix()
	end
	GL:add_plugin(P,"extrudecolor")
	assert(getmetatable(P))
	print("extrudecolor returning plugin")
	return P
end

---[=[
if not ... then
GL = GLcanvas{H=1080,viewH=700,aspect=1.5,profile="CORE",DEBUG=false}
local fbo
function GL.init()
	textura = GL:Texture():Load[[c:\luagl\pelis\hadas\master1080\leslie_giro1\frame-0001.tif]]
	GL:set_WH(textura.width, textura.height)
	ext = M.make(GL)
	fbo = GL:initFBO()
	GL:DirtyWrap()
end

function GL.draw(t,w,h)
	--textura:draw(t,w,h)
	--ext:draw(t,w,h,{clip={textura}})
	ext:process_fbo(fbo,textura,w,h)
	ut.Clear()
	fbo:tex():drawcenter()
end

GL:start()
end
--]=]
return M