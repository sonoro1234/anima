local ut = require"glutils.common"

local vert_shad = [[
void main()
{
	gl_FrontColor = gl_Color;
	gl_Position = ftransform();
}

]]
local frag_shad = [[
uniform float bright;
vec4 color = vec4(1.0, 0.0, 0.0, 1.0);
void main()
{
  gl_FragColor = vec4(gl_Color.rgb, bright); 
  //gl_FragColor = vec4(gl_Color.rgb*bright,1);
}
]]

local function TextClipMaker(GL, fontname,args)

	fontname = fontname or "Courier New"
	local Clip = {}
	local font,fontO

	function Clip:init()
		print"titulos init"
		font = GLFontOutline(fontname,args) --GLFont(GL.cnv,"Papyrus, Bold  48")
		font:init()
		self.font = font
		--for i=0,255 do 
			--local aa = font.agmf[i]
			--if aa.gmfBlackBoxY == font.maxY then print(string.char(i),font.maxY) end
			-- print(i,string.char(i),aa.gmfBlackBoxX,aa.gmfBlackBoxY,aa.gmfCellIncX,aa.gmfCellIncY)
		--end
		--fontO = GLFontOutline(GL.cnv,fontname,true)
		--fontO:init()
		Clip.program = GLSL:new()
		Clip.program:compile(vert_shad,frag_shad);
		Clip.camera = newCamera(GL,true,"titulos")
		Clip.camera.NMC.vars.ortho[0] = 1
		--Clip.camera.PostProjection = PostProjection
		--Clip.camera.NMC.vars.zcam:setval(157)
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
		
		--gl.glEnable(glc.GL_LINE_SMOOTH)

		--local oldgldephfunc = ffi.new("GLint[1]")
		--gl.glGetIntegerv(glc.GL_DEPTH_FUNC,oldgldephfunc)
		
		local Clip = self
		--glext.glUseProgram(0);
		Clip.program:use()
		
		Clip.camera:Set()
		
		if not args.dontclear then
			--gl.glClearColor(color[1], color[2], color[3], 0)
			gl.glClearColor(0,0,0, 0)
			gl.glClear(glc.GL_COLOR_BUFFER_BIT)
			--gl.glClear(glc.GL_DEPTH_BUFFER_BIT)
		end
		gl.glClear(glc.GL_DEPTH_BUFFER_BIT)
		Clip.program.unif.bright:set{bright}
		
		gl.glRotatef(timebegin*rot_speed,0,0,1)
		
		local sc = size * 1/font.maxY --font.agmf[string.byte"H"].gmfBlackBoxY --
		gl.glScalef(sc,sc,sc)
		
		if type(text)=="string" then text = {text} end
		
		if centered then
			local lenx,leny = font:dims(text[1])
			posX,posY = -lenx/2,-leny
			--print(posX,posY)
		else
			posX,posY = posX/sc,posY/sc
		end
		
		for i,line in ipairs(text) do
			if centered then
				local lenx,leny = font:dims(line)
				posX = -lenx/2
			end
			if shadow then
				local shadowdist = args.shadowdist or 0.04
				gl.glColor4d(0, 0, 0,1) --, br)
				font:printXY(line, posX + font.maxY*shadowdist, posY - font.maxY*shadowdist,-1)
			end
	
			gl.glColor4d(color[1], color[2], color[3],1) --, br)
			font:printXY(line,posX,posY )
			--next prepare
			posY = posY - font.maxY
		end
		--gl.glDepthFunc(oldgldephfunc[0])
		glext.glUseProgram(0);

		gl.glDisable(glc.GL_CULL_FACE);
	end
	GL:add_plugin(Clip)
	return Clip
end

--[=[
require"anima"
TA = require"anima.TA"
chartable = TA():range(211,255)
chartable = chartable:Do(function(v) return string.char(v) end)
alltext = table.concat(chartable)
--local lfs = require"lfs_ffi"
texto = [[Música]] --lfs.win_utf8_to_acp("MÃºsica")
for i=1,#texto do
	print(i,texto:sub(i,i))
end

GL = GLcanvas{H=800,aspect=3/2}
	texter = TextClipMaker(GL,"Silk RemingtonSBold",{italic=false})
	texini = {texter,
	--size=AN({0.05,0.2,15}),
	size = 0.05,
	--text={[[Palmeras]],"Huecas"},
	--text = alltext,
	text = texto,
	color={1,0,0},rot_speed = 30,centered=true,dontclear=true,shadow=false,shadowdist=0.01, posX = AN{-0.75,-0.55,15},posY = AN{-0.5,0,15},bright = AN({0,1,10},{1,1,20},{1,0,5})}
function GL.init()

end
function GL.draw(t,w,h)
					gl.glEnable(glc.GL_BLEND)
				glext.glBlendEquation(glc.GL_FUNC_ADD)
				gl.glBlendFunc (glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA);
	gl.glClearColor(0,0,0, 1)
	ut.Clear()
	texter:draw(t,w,h,texini)--{text="Pepito"})
end
GL:start()

--]=]

return TextClipMaker