require"anima"

local glmatrix = require"anima.glmatrix"


local vert_shada = [[

uniform sampler2D tex0;
uniform float extfac;
void main()
{
	
	gl_TexCoord[0] = gl_TextureMatrix[0]* gl_Vertex;
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);
	//vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
	vec3 normal = gl_Normal;
	
	float lum = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722)) - 0.5;
	vec4 Vertex = gl_Vertex;
	Vertex.xyz += normal*lum*extfac;
	/*
	if(extfac > 0.0){
		gl_Vertex.xyz += normal*lum*extfac;
	}else{
		gl_Vertex.xyz += normal*(lum-1.0)*extfac;
	}	
	*/
	gl_Position = gl_ModelViewProjectionMatrix * Vertex;
}

]]
local frag_shada = [[

uniform sampler2D tex0;
void main()
{
  vec4 color = texture2D(tex0,gl_TexCoord[0].st);
  gl_FragColor = color; 
}
]]


local function CreateMesh(MESHW,MESHH,piecesX,piecesY)
	
	local wfac,yfac

	wfac = MESHW/(piecesX)
	yfac = MESHH/(piecesY)
		
	local meshList = gl.glGenLists(1);
	print("making meshList clip1",meshList)
	gl.glNewList(meshList, glc.GL_COMPILE);
	for j=0,piecesY-1 do
		gl.glBegin(glc.GL_TRIANGLE_STRIP)
        for i=0,piecesX do
			--[j][i] = {}
			for k=0,1 do
				local x = i*wfac
				local y = (j+k)*yfac 
				local yt = (j+k)/piecesY
				local xt = i/piecesX
				local xu,yu,zu = x-MESHW*0.5,y-MESHH*0.5,0 
				--gl.glTexCoord2f(xt, yt);
				gl.glNormal3f(0, 0,1);
				gl.glVertex3f( xu, yu,zu) 
			end
		end
		gl.glEnd()
	end
	gl.glEndList();
	return meshList
end

local M ={}
function M.make(GL)
	local plugin = require"anima.plugins.plugin"
	local NM = GL:Dialog("extrude",
{
{"extfac",0,guitypes.val,{min=-2,max=2}},
})

	local P = {}
	P.camera = newCamera(GL,true,"extrude")
	P.NM = NM 
	function P:init()
		self.fbo = GL:initFBO()
		
		self.program = GLSL:new()
		self.program:compile(vert_shada,frag_shada);
		self.meshlist = CreateMesh(GL.aspect,1,GL.W,GL.H)
		self.inited = true
	end
	local function get_args(t, timev)
		local clip = t.clip
		--local extfac = ut.get_var(t.extfac,timev,NM.extfac)
		local camara = ut.get_var(t.camara,timev,P.camera)
		return clip,camara
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
		
		gl.glMatrixMode(glc.GL_TEXTURE);
		gl.glPushMatrix()
		gl.glLoadIdentity();
		gl.glTranslated(0.5, 0.5, 0);
		gl.glScaled(h/w,1,1)
		
		gl.glClearColor(0.0, 0, 0, 0)
		ut.Clear()

		camara:Set()
	
		gl.glCallList(self.meshlist);
		
		gl.glMatrixMode(glc.GL_TEXTURE);
		gl.glPopMatrix()
	end
	GL:add_plugin(P)
	return P
end

--[=[

GL = GLcanvas{H=1080,viewH=700,aspect=1.5}
ext = M.make(GL)
function GL.init()
	textura = GL:Texture():Load[[c:\luagl\pelis\hadas\master1080\leslie_giro1\frame-0001.tif]]
end

function GL.draw(t,w,h)
	--textura:draw(t,w,h)
	ext:draw(t,w,h,{clip={textura}})
end

GL:start()
--]=]
return M