require"anima"

local glmatrix = require"anima.glmatrix"
local vert_shada = [[
uniform mat4 MM;
uniform sampler2D texblured;
uniform float extfac;
in vec3 pos;
void main()
{
	

	gl_TexCoord[0] = gl_TextureMatrix[0]* vec4(pos,1);
	vec4 color = texture2D(texblured,gl_TexCoord[0].st);
	float lum = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722))*extfac;
	pos += vec3(0,0,1)*lum;

	vec4 point = MM * vec4(pos,1);
	gl_Position = gl_ModelViewProjectionMatrix * point;
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
	
	local wfac = MESHW/(piecesX-1)
	local yfac = MESHH/(piecesY-1)
	print("making meshList clip1")	
	local points = {}
	local ind = 1
	for j=0,piecesY-1 do
        for i=0,piecesX-1 do
			points[ind] = i*wfac-MESHW*0.5
			points[ind+1] = j*yfac -MESHH*0.5
			points[ind+2] = 0
			ind = ind + 3
		end
	end
	print"triangs"
	local indexes = mesh.triangs(piecesX,piecesY)
	print"done"
	return points,indexes
end
function make(GL)
	local M = require"anima.plugins.plugin".new(nil,GL)
	local NM = GL:Dialog("extrudecolor",
{
{"centerX",0,guitypes.val,{min=-2,max=2}},
{"centerY",0,guitypes.val,{min=-2,max=2}},
{"centerZ",0,guitypes.val,{min=-5,max=5}},
{"extfac",0,guitypes.val,{min=-2,max=2}},
{"use_blur",false,guitypes.toggle},
},function(n,v)  end)
	
	M.NM = NM
	NM.plugin = M
	
	local camera,program,meshvao,blurfbo,bilat

	function M:init()
		camera = newCamera(GL,true)
		program = GLSL:new()
		program:compile(vert_shada,frag_shada);
		--meshlist = CreateMesh(1.5,1,1500,1000)
		--local pos,ind = CreateMesh2(1.5,1,1500,1000)
		local pos,ind = CreateMesh(GL.aspect,1,GL.W,GL.H)
		meshvao = VAO({pos=pos},program,ind)
		blurfbo = GL:initFBO({no_depth=true})
		self.fbo = GL:initFBO({no_depth=true})
		bilat = require"anima.plugins.bilat_poisson"(GL)
	end
	function M:draw(t,w,h,args)
		local theclip = args.clip
		
		local old_framebuffer = self.fbo:Bind()
		theclip[1]:draw(t, w, h,theclip)
		
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer);
		local textura = self.fbo:tex()
		
		if NM.use_blur then
			bilat:process_fbo(blurfbo,textura)
		end
		
		program:use()
		program.unif.tex0:set{0}
		program.unif.texblured:set{1}
		program.unif.extfac:set{NM.extfac}
		gl.glMatrixMode(glc.GL_TEXTURE);
		gl.glLoadIdentity();
		gl.glTranslated(0.5, 0.5, 0);
		gl.glScaled(textura.height/textura.width,1,1)
		--gl.glScaled(2/3,1,1)
	
		textura:Bind()
		if NM.use_blur then
			blurfbo:tex():Bind(1)
		else
			textura:Bind(1)
		end
		gl.glClearColor(0.0, 0, 0, 0)
		ut.Clear()
		camera:Set()
		
		local modmat2 = glmatrix.translate_mat(NM.centerX,NM.centerY,NM.centerZ)
		program.unif.MM:set(modmat2:table())
		--gl.glPointSize(2)
		meshvao:draw_elm()
		--meshvao:draw(glc.GL_POINTS)
		gl.glPointSize(1)
	end
	GL:add_plugin(M)
	return M
end


--[=[

GL = GLcanvas{H=700,aspect = 1.5}

extr = make(GL)
function GL.init()

	--textura = Texture():Load[[C:\luajitbin2.0.2-copia\animacion\resonator6\resonator-038.jpg]]
	
	--textura = Texture():Load[[c:/luagl/media\frame-0001.tif]]
	-- textura2 = Texture():Load[[c:/luagl/media\frame-0001Bilat.tif]]
	
	--textura = Texture():Load[[c:/luagl/media\leslie.tif]]
	--textura2 = Texture():Load[[c:/luagl/media\leslie_blur.tif]]
	textura = Texture():Load[[G:\VICTOR\pelis\pelipino\master1080\arbolenflordos\frame-0001.tif]]
	
	GL:set_WH(textura.width,textura.height)
	
	
	GL:DirtyWrap()
end

function GL.draw(tim,w,h)

	extr:draw(t,w,h,{clip={textura}})
end

GL:start()
--]=]

return make