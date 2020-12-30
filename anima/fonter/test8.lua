

local fonter = require"fonter"

local filen = [[C:\anima\lua\anima\fonts\ProggyTiny.ttf]]
local filen = [[C:\anima\lua\anima\fonts\SilkRemington-SBold.ttf]]
--local filen = [[C:\anima\lua\anima\fonts\fontawesome-webfont.ttf]]
--local filen = [[C:\anima\lua\anima\fonts\verdana.ttf]]

--fonter.mode = "polys"
local ch1=string.byte"P"

--ProfileStart()--"3vfsi4m1")
 local f1 = fonter.new_face(filen,{{1,255}},1024*4,5)--,{{35,35}})
--local f1 = fonter.new_face(filen,{{ch1,ch1}},1024*4,5)
--ProfileStop()

-------------

local GL = GLcanvas{H=800,aspect=1}

local NM = GL:Dialog("test",{
{"count",1,guitypes.drag,{min=1}},
{"ini",1,guitypes.drag},
})

local program,meshvaos,camera
local color = require"anima.graphics.color"

local mssa
function GL.init()
	f1:initgl()
	mssa = GL:initFBOMultiSample()
	camera = Camera(GL,"tps")
	camera.NM.vars.pos:set{0.4,0.3,-0.3}
end

local texto = ""
function GL.imgui()
	ig.Text(texto)
end
--[[
	--T.MO = mat.identity4()
	function f1:printcp(cp,camera,MO)
		--print"vvvvvvvvv"
		local M = fonter
		MO = MO or self.MO
		M.program:use()
		M.program.unif.MVP:set(camera:MVP().gl)
		M.program.unif.MO:set(MO.gl)
		local cha = self.chars[cp]
		if M.mode == "polys" then
			for i,v in ipairs(self.chars[cp].vaos) do
				M.program.unif.color:set{color.HSV2RGB((i-1)/#cha.vaos,1,1)}
				v:draw(glc.GL_LINE_LOOP)
				gl.glPointSize(3)
				M.program.unif.color:set{1,1,1}
				v:draw(glc.GL_POINTS)
				gl.glPointSize(1)
			end
		else
			local tr = cha.mesh:triangle(math.floor(NM.count))
			--print(cha.vao.num_indices/3,tr[1],tr[2],tr[3])
			texto = (cha.vao.num_indices/3)..","..tr[1]..","..tr[2]..","..tr[3]
			
			M.program.unif.color:set{0,1,0}
			if cha.vao then cha.vao:draw_mesh(NM.count,math.floor(NM.count)) end
			
			M.program.unif.color:set{0.25,0.25,0.25}
			if cha.vao then cha.vao:draw(glc.GL_LINE_LOOP) end 
			
			--if cha.vao then cha.vao:draw_mesh() end
			M.program.unif.color:set{1,0,0}
			for i,r in ipairs(cha.restsvaos) do
				 r:draw(glc.GL_LINE_LOOP)
			end
			
			gl.glPointSize(6)
			M.program.unif.color:set{1,1,1}
			if cha.vao then cha.vao:draw(glc.GL_POINTS) end --,1,NM.ini) end
			gl.glPointSize(1)
			
		end
	end
--]]
function GL.draw(t,w,h)
	
	mssa:Bind()
	ut.Clear()
	gl.glViewport(0,0,w,h)
	--f1:printcp(ch1,camera)
	f1:printstring("Te estoy",camera)
	mssa:Dump()
end

GL:start()