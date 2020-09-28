--local ut = require"glutils.common"
local vert_shad = [[
#version 120
void main()
{
	//gl_TexCoord[0] = gl_MultiTexCoord0;

	gl_TexCoord[0] = gl_TextureMatrix[0]*gl_MultiTexCoord0;
	gl_TexCoord[1] = gl_TextureMatrix[1]*gl_MultiTexCoord0;
	//gl_Position = ftransform();
	gl_Position = gl_ModelViewProjectionMatrix *gl_Vertex;
}

]]
local frag_shad = [[
#version 120
uniform sampler2D tex0,tex1;
uniform float alpha;

void main()
{
/*
  bool test0 = (any(greaterThan(gl_TexCoord[0].st,vec2(1.0,1.0))) ||  any(lessThan(gl_TexCoord[0].st,vec2(0.0,0.0))));
  bool test1 = (any(greaterThan(gl_TexCoord[1].st,vec2(1.0,1.0))) ||  any(lessThan(gl_TexCoord[1].st,vec2(0.0,0.0))));
  float fac0 = 1.0;
  float fac1 = 1.0;
  if(test0) fac0 = 0;//5.0;
  if(test1) fac1 = 0;//5.0;
  //vec4 color1 = pow(texture2D(tex0,gl_TexCoord[0].st),vec4(fac0));
 // vec4 color2 = pow(texture2D(tex1,gl_TexCoord[1].st),vec4(fac1));
  vec4 color1 = texture2D(tex0,gl_TexCoord[0].st)*fac0;
  vec4 color2 = texture2D(tex1,gl_TexCoord[1].st)*fac1;
*/
  vec4 color1 = texture2D(tex0,gl_TexCoord[0].st);
  vec4 color2 = texture2D(tex1,gl_TexCoord[1].st);
	gl_FragColor = mix(color1,color2,alpha); 

}
]]
local frag_shad2 = [[
uniform sampler2D tex0,tex1;
uniform float alpha;
uniform float time;
uniform float w,h;
uniform float perlinfac = 0.1;
uniform float spacefac = 3;
uniform float offdelta = 4.0;
void main()
{
	vec2 pos = vec2(gl_FragCoord.x/w,gl_FragCoord.y/h);
	vec2 perlinpos = ((pos - 0.5)*vec2(spacefac,spacefac)) + 0.5;
	float delta = snoise(vec3(perlinpos,time));
	float delta2 = snoise(vec3(perlinpos,time + offdelta));
	vec2 pos2 = pos + vec2(delta,delta2)*perlinfac;
  
	vec4 color1 = texture2D(tex0,mix(pos,pos2,alpha));
	vec4 color2 = texture2D(tex1,mix(pos2,pos,alpha));
	vec4 color = color1*(1.0-alpha) + color2*alpha;
	gl_FragColor = color;
}
]]
local GLSL_perlin = require"anima.GLSL.GLSL_perlin"
frag_shad2 = "#version 120\n" .. GLSL_perlin..frag_shad2

local function DoQuad2(w, h)
	--gl.glTranslatef(-w*0.5,-h*0.5,0)
	local zplane = 0
	gl.glBegin(glc.GL_QUADS)
	gl.glColor4f(1,1,1,1)
	gl.glTexCoord2f(0, 0);
	gl.glVertex3f(0,0,zplane)
	gl.glTexCoord2f(0 , 1 );
	gl.glVertex3f(0, h ,zplane)
	gl.glTexCoord2f(1, 1 );
	gl.glVertex3f(w, h, zplane)
	gl.glTexCoord2f(1, 0);
	gl.glVertex3f(w, 0,zplane)
	gl.glEnd()
end
local function biasBAK(b, x)
	b = linearmap(b,0,1,0,0.5)
	if b == 0 then return 0 end
	return math.pow(x, math.log(b)/math.log(0.5));
end
local function biasFC(b, x)
	return math.max(0,math.min(1,linearmap(x,1-b,1,0,1)))
end
local function gain(g,x)
	g = linearmap(g,0,1,1,0.5)
	if (x < 0.5) then
		return bias(1-g, 2*x)/2;
	else
		return 1 - bias(1-g, 2 - 2*x)/2;
	end
end
local function getframes(timebegin , frdur ,nimages,args)

	local dur = args.dur
	--timebegin = math.max(0,timebegin)
	if dur then 
		timebegin = math.min(dur ,timebegin) 
		--timebegin = math.min(dur - frdur,timebegin) 
		--if timebegin >= (dur - frdur) then print("last",timebegin,dur-frdur,frdur,dur) end
	end
	local T1,T2,alfa
	local fr
	if args.last then
		fr = args.last.fr + (timebegin - args.last.ti)/frdur
	else
		fr = ((timebegin/frdur))
	end
	--args.last = {fr=fr,ti=timebegin} --rounding error are bad, dont use arg.last
	if not args.rloop then
		T1 = math.floor(fr)
		alfa = fr - T1
		T2 = T1 + 1
		T1 = (T1 % nimages) --+ 1
		T2 = (T2 % nimages) --+ 1
	else --rloop
		local N2 = (nimages*2 - 2)
		local revers = false
		local t1 = math.floor(fr)
		alfa = fr - t1
		t1 = (t1 % N2)
		if t1 >= (nimages-1) then revers = true end
		if not revers then
			--alfa = fr - t1
			T1 = t1 --+ 1
			T2 = T1 + 1 --+1
		else
			--alfa = fr - t1
			T1 = N2 - t1
			T2 = T1 - 1
		end
	end
	--print(T1+1,T2+1,alfa,timebegin,1/frdur,timebegin/frdur)
	return T1 + 1, T2 + 1, alfa
end

local function getframes2(fr ,nimages,args)


	local T1,T2,alfa
	fr = fr - 1
	if not args.rloop then
		T1 = math.floor(fr)
		alfa = fr - T1
		T2 = T1 + 1
		T1 = (T1 % nimages) --+ 1
		T2 = (T2 % nimages) --+ 1
	else --rloop
		local N2 = (nimages*2 - 2)
		local revers = false
		local t1 = math.floor(fr)
		alfa = fr - t1
		t1 = (t1 % N2)
		if t1 >= (nimages-1) then revers = true end
		if not revers then
			--alfa = fr - t1
			T1 = t1 --+ 1
			T2 = T1 + 1 --+1
		else
			--alfa = fr - t1
			T1 = N2 - t1
			T2 = T1 - 1
		end
	end
	return T1 + 1, T2 + 1, alfa
end


--------------------------------------------------------------------
local sequencer = {is_sequencer = true}

function sequencer:new(WIDTH, HEIGHT,srgb)
	local o =  {WIDTH = WIDTH, HEIGHT = HEIGHT,textures = {},oldT1="",oldT2="",srgb=srgb} 
	setmetatable(o, self)
	self.__index = self
	return o
end

function sequencer:get_args(t,timev)
	local images = t.images
	local frdur = ut.get_var(t.frdur,timev,1) --t.frdur or 1

	local ga = ut.get_var(t.ga,timev,self.NM.ga)
	local mode = ut.get_var(t.mode,timev,"")
	local frame = ut.get_var(t.frame,timev,nil)
	
	return images, frdur, ga, mode, frame
end
function sequencer:init()
	if self.inited then return end

	glext.glActiveTexture(glc.GL_TEXTURE0);
	self.textures[1] = self.GL:Texture()
	glext.glActiveTexture(glc.GL_TEXTURE1);
	self.textures[2] = self.GL:Texture()


	self.program = GLSL:new()
	self.program:compile(vert_shad,frag_shad);
	self.program2 = GLSL:new():compile(vert_shad,frag_shad2);
	self.inited = true
	--debugprint = require"glutils.GLTextClip"(GL)
	--self.debugfont = GLFontOutline(GL.cnv,"Courier New, Italic  12") --GLFont(GL.cnv,"Papyrus, Bold  48")
end

function sequencer:SetTextureMatrixes(w,h)
	local aspect = w/h
	for i=1,2 do
		glext.glActiveTexture(glc.GL_TEXTURE0 + i -1);
		gl.glMatrixMode(glc.GL_TEXTURE);
		gl.glPushMatrix()
		gl.glLoadIdentity();
	
		if aspect >= self.textures[i].aspect then
			local rat = aspect/self.textures[i].aspect
			gl.glScaled(rat,1,1)
			gl.glTranslated(-0.5*(rat-1)/rat,0, 0);
		else
			local rat = self.textures[i].aspect/aspect
			gl.glScaled(1,rat,1)
			gl.glTranslated(0,-0.5*(rat-1)/rat, 0);
		end
	end
end
function sequencer:UnsetTextureMatrixes()
	for i=0,1 do
		glext.glActiveTexture(glc.GL_TEXTURE0 + i);
		gl.glMatrixMode(glc.GL_TEXTURE);
		gl.glPopMatrix();
	end
end
function sequencer:draw(timebegin, w , h, args)
	--args.verbose = true
	--print(ga,ga.is_setable_var, ga.value)
	if not self.inited then self:init() end
	local images, frdur, ga ,mode, frame = self:get_args(args,timebegin)
	--print(frdur)
	local T1, T2, alfa 
	local count = args.reorder and #args.reorder or #images
	if frame then
		T1, T2, alfa = getframes2(frame , count,args)
	else
		T1, T2, alfa = getframes(timebegin , frdur , count,args)
	end
	if args.reorder then
		T1 = args.reorder[T1]
		T2 = args.reorder[T2]
	end
	local Clip = self
	
	if not (mode=="perlin") then
		glext.glUseProgram(Clip.program.program);
		Clip.program.unif.tex0:set{0}
		Clip.program.unif.tex1:set{1}
		Clip.program.unif.alpha:set{biasFC(ga,alfa)}
		if self.srgb then --linear converted
			--Clip.program.unif.alpha:set{biasFC(ga,alfa)}
		else
			--Clip.program.unif.alpha:set{ut.RGB2sRGB(biasFC(ga,alfa))}
		end
	else
		glext.glUseProgram(Clip.program2.program);
		Clip.program2.unif.tex0:set{0}
		Clip.program2.unif.tex1:set{1}
		Clip.program2.unif.alpha:set{biasFC(ga,alfa)}
		Clip.program2.unif.w:set{w}
		Clip.program2.unif.h:set{h}
		--constant for each T1
		Clip.program2.unif.time:set{T1}
	end
	
	if images[T1] ~= self.oldT1 then
		
		if args.verbose then print("reload 1", images[T1],biasFC(ga,alfa),alfa,self.oldT1) end
		--ReLoadTexture(images[T1],self.textures[1].tex,self.srgb)
		glext.glActiveTexture(glc.GL_TEXTURE0);
		self.textures[1]:Load(images[T1],self.srgb,self.mipmaps)
		self.oldT1 = images[T1]
	end
	
	if ga~=0 then
	if images[T2] ~= self.oldT2 then
		if args.verbose then print("reload 2", images[T2],biasFC(ga,alfa),alfa,self.oldT2) end
		--ReLoadTexture(images[T2],self.textures[2].tex,self.srgb)
		glext.glActiveTexture(glc.GL_TEXTURE1);
		self.textures[2]:Load(images[T2],self.srgb,self.mipmaps)
		self.oldT2 = images[T2]
	end
	end
	
	gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))

	local modewrap = glc.GL_MIRRORED_REPEAT --glc.GL_CLAMP --glc.GL_REPEAT --glc.GL_MIRRORED_REPEAT
	
	--[[
	glext.glActiveTexture(glc.GL_TEXTURE0);
	gl.glEnable( glc.GL_TEXTURE_2D );
	gl.glBindTexture(glc.GL_TEXTURE_2D, self.textures[1].tex)
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
	
	
	glext.glActiveTexture(glc.GL_TEXTURE1);
	gl.glEnable( glc.GL_TEXTURE_2D );
	gl.glBindTexture(glc.GL_TEXTURE_2D, self.textures[2].tex)
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
	--]]
	
	self.textures[1]:Bind(0)
	self.textures[2]:Bind(1)
	
	
	ut.project(w,h)
	
	self:SetTextureMatrixes(w,h)

	ut.DoQuad(w,h)

	self:UnsetTextureMatrixes()

	--debugprint:draw(timebegin, w , h,{text=images[T1],size=0.03,posX=-1,posY=-0.45,dontclear=true})
	--debugprint:draw(timebegin, w , h,{text=images[T2],size=0.03,posX=-1,posY=-0.5,dontclear=true})
	--[[
	glext.glUseProgram(0);
	gl.glDisable(glc.GL_DEPTH_TEST)
	gl.glMatrixMode(glc.GL_PROJECTION)
	gl.glLoadIdentity()
	gl.glOrtho(0.0, w, 0.0, h, -1, 1);
	gl.glMatrixMode(glc.GL_MODELVIEW)
	gl.glLoadIdentity();
	--gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
	gl.glColor4d(1,1, 1,1)
	self.debugfont:printXY("Hola",0,0,-1)
	--DrawAxis()
	--]]
end
local path = require"anima.path"
function sequencer:loadimages(dir,frdur,inifr,endfr,dur,ga,args)
	local sourcedir = (self.GL.DORENDER and self.GL.render_source) or self.GL.comp_source
	local ldir = path.chain(self.GL.rootdir,sourcedir,dir)
	return self:make_clip(ldir,frdur,inifr,endfr,dur,ga,args)
end
function sequencer:make_clip(dir,frdur,inifr,endfr,dur,ga,args)
	args = args or {}
	local imagsrc = {}
	funcdir(dir,function(f) table.insert(imagsrc,f) end)
	inifr,endfr = (inifr or 1),(endfr or #imagsrc)
	table.sort(imagsrc)
	dur =  dur or ((endfr - inifr + 0)*frdur)
	local imags = {}
	for i =  inifr,endfr do
		table.insert(imags,imagsrc[i])
	end
	
	assert(#imags > 0,"no images in "..dir)
	return {self, images = imags,frdur = frdur,dur = dur, ga = ga,rloop=args.rloop }
end
function sequencer:make_clip2(dirs,frdur,dur,ga,args)
	args = args or {}
	local imagsrc = {}
	for i,dir in ipairs(dirs) do
		funcdir(dir,function(f) table.insert(imagsrc,f) end)
	end
	table.sort(imagsrc)
	assert(#imagsrc > 0,"no images in "..dir)
	return {self, images = imagsrc,frdur = frdur,dur = dur or 200, ga = ga,rloop=args.rloop }
end
local function FolderClipMaker(GL)
	local seq = sequencer:new(GL.W, GL.H,GL.SRGB)
	seq.GL = GL
	seq.NM = GL:Dialog("framer",
		{
		{"ga",0,guitypes.val,{min=0,max=1}},
		})
	GL:add_plugin(seq)
	return seq
end
return FolderClipMaker