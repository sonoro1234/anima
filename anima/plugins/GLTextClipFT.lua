local path = require"anima.path"
print(path.animapath())
local fonter = require"anima.fonter.fonter"
fonter.triangulator = "glu" --"monotone" --"glu" --ear
fonter.min_area = 1e-4 --1e-12

local vert_sh = [[

in vec2 position;
uniform mat4 MVP;
uniform mat4 MO;
void main()
{

	gl_Position = MVP*MO*vec4(position,0,1);
}
]]
local frag_sh=[[

uniform vec4 color;
out vec4 fcolor;
void main()
{
	fcolor = vec4(color);
}
]]

local function TextClipMaker(GL, fontname,args)
	args = args or {}
	assert(fontname,"GLTextClipFT with no fontname")
	if #path.path2table(fontname) == 1 then
			fontname = path.chain(path.animapath(),"fonts",fontname)
	end
	local Clip = {}
	-- local NM = GL:Dialog("fonter",{
-- {"show",0,guitypes.valint,{min=0,max=20}},
-- {"mesh",false,guitypes.toggle},
-- {"lines",false,guitypes.toggle},
-- {"ini",1,guitypes.drag},
-- })
	-- Clip.NM = NM
	local font,fontO

	function Clip:init()
	---[[
		print("titulos init",GL.W,GL.H,fontname)
		local program = GLSL:new():compile(vert_sh, frag_sh)
		local t1 = secs_now()

		font = fonter.new_face(fontname,args)
		print("GLTextClipFT loaded in ", secs_now() - t1)
		--set custom_program
		font:initgl(program, true)
		self.font = font
		font.NM = NM
		Clip.camera = newCamera(GL,true,"titulos")
		Clip.camera.NMC.vars.ortho[0] = 1
		--font.camera = Clip.camera
		--Clip.camera.PostProjection = PostProjection
		--Clip.camera.NMC.vars.zcam:setval(157)
		--]]
		Clip.inited = true
	end

	local function get_args(t, timev)
		local size = ut.get_var(t.size,timev,0.1)
		local rot_speed = ut.get_var(t.rot_speed,timev,0)
		local bright = ut.get_var(t.bright,timev,1)
		local color = ut.get_var(t.color, timev, {1,1,1})
		local text = ut.get_var(t.text,timev,1)
		local shadow = ut.get_var(t.shadow,timev,false)
		local posX = ut.get_var(t.posX,timev,0)
		local posY = ut.get_var(t.posY,timev,0)
		local centered = ut.get_var(t.centered,timev,false)
		return size, rot_speed,bright,text,color,shadow,posX,posY,centered
	end

	function Clip:draw(timebegin,w,h,args)
		if not self.inited then self.init() end
		local size, rot_speed,bright,text,color,shadow,posX,posY,centered = get_args(args, timebegin)
		local MO = mat.identity()
				
		--gl.glEnable(glc.GL_LINE_SMOOTH)

		--local oldgldephfunc = ffi.new("GLint[1]")
		--gl.glGetIntegerv(glc.GL_DEPTH_FUNC,oldgldephfunc)
		
		local Clip = self
		--glext.glUseProgram(0);
		--font.program:use()

		
		if not args.dontclear then
			--gl.glClearColor(color[1], color[2], color[3], 0)
			gl.glClearColor(0,0,0, 0)
			gl.glClear(glc.GL_COLOR_BUFFER_BIT)
			--gl.glClear(glc.GL_DEPTH_BUFFER_BIT)
		end
		gl.glClear(glc.GL_DEPTH_BUFFER_BIT)
		--
		
		--gl.glRotatef(timebegin*rot_speed,0,0,1)
		MO = MO * mat.rotate_axis(timebegin*rot_speed,mat.vec3(0,0,1))

		local sc = size* 1/font.maxY --font.agmf[string.byte"H"].gmfBlackBoxY --
		--gl.glScalef(sc,sc,sc)
		MO = MO * mat.scale(sc,sc,sc)

		if type(text)=="string" then text = {text} end
		
		if centered then
			local lenx,leny = font:dims(text[1])
			posX,posY = -lenx/2,-leny
			--print(posX,posY)
		else
			posX,posY = posX/sc,posY/sc
		end
		
		font.cust_program:use()
		font.cust_program.unif.MVP:set(Clip.camera:MVP().gl)
		gl.glViewport(0,0,w,h)
		for i,line in ipairs(text) do
			if centered then
				local lenx,leny = font:dims(line)
				posX = -lenx/2
			end
			if shadow then
				local shadowdist = args.shadowdist or 0.04
				--gl.glColor4d(0, 0, 0,1) --, br)
				font:printXY(line, posX + font.maxY*shadowdist, posY - font.maxY*shadowdist,-1,nil,MO,{0,0,0,1})
			end
			
			--print("posX",posX,posY,size,sc)
			font:printXY(line,posX,posY, nil,nil,MO, {color[1], color[2], color[3],bright} )
			--font:printXY("D",0,0, nil,nil,nil, {color[1], color[2], color[3],bright} )
			--next prepare
			posY = posY - font.maxY
		end
		--gl.glDepthFunc(oldgldephfunc[0])
		glext.glUseProgram(0);

		--gl.glDisable(glc.GL_CULL_FACE);
	end
	GL:add_plugin(Clip)
	return Clip
end

if not ... then
---[=[
require"anima"
TA = require"anima.TA"
chartable = TA():range(211,255)
chartable = chartable:Do(function(v) return string.char(v) end)
alltext = table.concat(chartable)
--local lfs = require"lfs"
texto = [[Música\ndivertida]] --lfs.win_utf8_to_acp("MÃºsica")
texto = {[[Música]],[[divertida]]}
texto = {[[Dia]]}
-- for i=1,#texto do
	-- print(i,texto:sub(i,i))
-- end
local filen = [[C:\anima64\lua\anima\fonts\SilkRemington-SBold.ttf]]
local filen = [[SilkRemington-SBold.ttf]]
local GL = GLcanvas{H=800,fps=60,aspect=3/2,profileNO="CORE",use_log=false}

local texter = TextClipMaker(GL,filen,{ranges = {{0,0x10FFFF}}, italic=true})
--local texter2 = require"anima.plugins.GLTextClip"(GL,"Silk RemingtonSBold",{italic=false,outlineonly=false})
local filen2 = [[C:\anima\lua\anima\fonts\ProggyTiny.ttf]]
--local texter2 = TextClipMaker(GL,filen2)
local texini = {texter,
	size=AN({0.05,0.2,15}),
	--size = 2,
	text={[[Palmeras]],"Huecas"},
	--text = {"D"},
	--text = alltext,
	--text = texto,
	color={1,0,0},rot_speed = math.pi*30/180,centered=false,dontclear=true,shadow=false,shadowdist=0.01, posXN = AN{-0.75,-0.55,15},posYN = AN{-0.5,0,15},bright = AN({0,1,10},{1,1,20},{1,0,5})}
local texini2 = {texter2,
	--size=AN({0.05,0.2,15}),
	size = 2,
	--text={[[Palmeras]],"Huecas"},
	text = {"D"},
	--text = alltext,
	--text = texto,
	color={1,0,0},rot_speed = math.pi*30/180,centered=false,dontclear=true,shadow=false,shadowdist=0.01, posXN = AN{-0.75,-0.55,15},posYN = AN{-0.5,0,15},bright = AN({0,1,10},{1,1,20},{1,0,5})}
local mssafbo
function GL.init()
	msaafbo = GL:initFBOMultiSample()
end
function GL.draw(t,w,h)
					-- gl.glEnable(glc.GL_BLEND)
				-- glext.glBlendEquation(glc.GL_FUNC_ADD)
				-- gl.glBlendFunc (glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA);
	gl.glClearColor(0,0,0, 1)
	
	--msaafbo:Bind()
	
	ut.Clear()
	--texter:draw(t,w,h,{text="Pepito"})
	 texter:draw(t,w,h,texini)
	-- texter2:draw(t,w,h,texini2)

	--msaafbo:Dump()
end
GL:start()

--]=]
end

return TextClipMaker