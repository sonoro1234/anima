require"anima"
local vicim = require"anima.vicimag"
local mat = require"anima.matrixffi"
local mesh = require"anima.mesh"

local vert_shad = [[
uniform mat4 MVP;
uniform mat4 TM;
in vec3 position;
in vec2 texcoords;
void main()
{

	gl_TexCoord[0] = TM*vec4(texcoords,0,1);
	gl_Position = MVP*vec4(position,1);
}

]]
local frag_shad = [[
uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler2D flow;
uniform sampler2D bflow;
uniform float pos;
uniform vec2 size;
uniform bool fadeonly=false;
void main()
{
	vec4 delta = texture2D(flow,gl_TexCoord[0].st);
	vec2 delt = delta.rg / size;
	delta = texture2D(bflow,gl_TexCoord[0].st);
	vec2 bdelt = delta.rg / size;

	if(fadeonly){
		delt = vec2(0);
		bdelt = vec2(0.0);
	}
	/*
	vec2 texc = gl_TexCoord[0].st;
	if(texc.x == 0.0 || texc.x == 1.0 || texc.y == 0.0 || texc.y == 1.0){
		delt.x = delt.y = 0.0;
		bdelt.x = bdelt.y = 0.0;
	}
	*/
	vec4 color1 = texture2D(tex0,gl_TexCoord[0].st - pos*delt);
	vec4 color2 = texture2D(tex1,gl_TexCoord[0].st - (1.0-pos)*bdelt);

	//vec2 ll = gl_TexCoord[0].st - pos*delt;
	//if(ll<0 || ll>1){}
	
	//color1 = vec4(color1.a);
	//color2 = vec4(color2.a);
	
	vec4 color = (1.0-pos)*color1 + pos*color2;
	//vec4 color = mix(color1,color2,pow(pos,4));
	
	gl_FragColor = color;
}
]]

local function loadimages(self,folder,folderflow,masterdir)
	folderflow = folderflow or folder
	masterdir = masterdir or self.GL.rootdir
	local path = require"anima.path"
	local images,fflows,bflows = {},{},{}
	local imdir
	if self.GL.DORENDER then
		imdir = path.chain(masterdir,self.GL.render_source,folder)
	else
		imdir = path.chain(masterdir,self.GL.comp_source,folder)
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

	funcdir(path.chain(masterdir,[[flow]],folderflow),getflows,"flo")
	
	for i=#bflows + 2,#images do
		images[i] = nil
	end
	
	return {self,images=images,fflows=fflows,bflows=bflows}
end
local function modul(i,n)
	local r = i%n
	return (r~=0) and r or n
end

local function flow_player(GL)
	local fplay = {GL=GL}
	fplay.loadimages = loadimages
	function fplay:init()
		self.program = GLSL:new():compile(vert_shad,frag_shad)
		self.tex1 = GL:Texture()
		self.tex2 = GL:Texture()
		self.vao = mesh.quad():vao(self.program)
	end
	
	local function get_args(t,timev)
		local images = t.images
		local frame = ut.get_var(t.frame,timev,1)
		local fadeonly = ut.get_var(t.fadeonly,timev,false)
		local doclamp = ut.get_var(t.doclamp,timev,false)
		return t.images, t.fflows, t.bflows, frame,fadeonly,doclamp
	end
	
	function fplay:draw(t,w,h,args)

		local images, fflows, bflows ,frame,fadeonly,doclamp = get_args(args,t)
		local fr1 = math.floor(frame)
		local pos = frame - fr1
		local T1 = modul(fr1 , #images)
		local T2 = modul((T1 + 1) , #images )
		
		--print(#images,T1,T2,pos)
		--if images[T1] ~= self.oldT1 then
		if fflows[T1] ~= self.oldT1 then
			--print(#images,T1,T2,pos)
			if args.verbose then print("reload 1", images[T1],#images,T1,T2,pos) end
			--glext.glActiveTexture(glc.GL_TEXTURE0);
			self.tex1:Load(images[T1])
			self.tex1:set_wrap(glc.GL_CLAMP_TO_BORDER)
			--self.tex1:set_border{0,0,0,0}
			self.oldT1 = fflows[T1]
			--self.oldT1 = images[T1]
			self.tex2:Load(images[T2])
			self.tex2:set_wrap(glc.GL_CLAMP_TO_BORDER)
			--self.tex2:set_border{0,0,0,0}
			self.flow = vicim.vicimag2tex(fflows[T1],GL,self.flow)
			self.bflow = vicim.vicimag2tex(bflows[T1],GL,self.bflow)
		end
			
		self.program:use()
		local U = self.program.unif
		U.tex0:set{0}
		U.tex1:set{1}
		U.flow:set{2}
		U.bflow:set{3}
		U.pos:set{pos}
		U.size:set{self.flow.width,self.flow.height}
		U.fadeonly:set{fadeonly}
		
		if doclamp then
			self.tex1:set_wrap(glc.GL_CLAMP_TO_BORDER)
			self.tex2:set_wrap(glc.GL_CLAMP_TO_BORDER)
		else
			self.tex1:set_wrap()
			self.tex2:set_wrap()
		end
		self.tex1:Bind(0)
		
		self.tex2:Bind(1)

		self.flow:Bind(2)
		self.bflow:Bind(3)
		--gl.glClearColor(0.0, 0.0, 0.0, 0)
		ut.Clear()

		---[[
		local MP = mat.ortho(-1, 1, -1, 1, -1, 1);
		U.MVP:set(MP.gl)
		gl.glViewport(0, 0, w, h)
		
		local TM = self:SetTM(w,h)
		U.TM:set(TM.gl)
		self.vao:draw_elm()
		--]]
		--[[
		ut.project(w,h)
		self:SetTextureMatrixes(w,h)
		ut.DoQuad(w,h)
		self:UnsetTextureMatrixes()
		--]]
	end
	function fplay:SetTM(w,h)
		local aspect = w/h
		if aspect >= self.tex1.aspect then
			local rat = aspect/self.tex1.aspect
			return mat.scale(rat,1,1)*mat.translate(-0.5*(rat-1)/rat,0, 0)
		else
			local rat = self.tex1.aspect/aspect
			return mat.scale(1,rat,1)*mat.translate(0,-0.5*(rat-1)/rat, 0)
		end
	
	end
	function fplay:SetTextureMatrixes(w,h)
		local aspect = w/h
		glext.glActiveTexture(glc.GL_TEXTURE0);
		gl.glMatrixMode(glc.GL_TEXTURE);
		gl.glPushMatrix()
		gl.glLoadIdentity();
		
		if aspect >= self.tex1.aspect then
			local rat = aspect/self.tex1.aspect
			gl.glScaled(rat,1,1)
			gl.glTranslated(-0.5*(rat-1)/rat,0, 0);
		else
			local rat = self.tex1.aspect/aspect
			gl.glScaled(1,rat,1)
			gl.glTranslated(0,-0.5*(rat-1)/rat, 0);
		end
	end
	function fplay:UnsetTextureMatrixes()
		glext.glActiveTexture(glc.GL_TEXTURE0);
		gl.glMatrixMode(glc.GL_TEXTURE);
		gl.glPopMatrix();
	end
	GL:add_plugin(fplay)
	return fplay
end

--[=[
GL = GLcanvas{fps=25,H=1080,viewH=700,aspect=3/2}

fpl = flow_player(GL)
--args = {images=images,fflows=fflows,bflows=bflows,frame= AN({1,80,80*1})}

local args = fpl:loadimages("lotomask","lotomask_tvl1",[[D:\VICTOR\pelis\caprichos]])
args.frame = AN({8,8,18},{8,9,4},{9,20+16,40*2})
args.doclamp = true
function GL.init()
end
function GL.draw(t,w,h)
	fpl:draw(t,w,h,args)
end

GL:start()
--]=]


return flow_player