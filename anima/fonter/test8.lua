

local fonter = require"fonter"

local filen = [[C:\anima\lua\anima\fonts\ProggyTiny.ttf]]
local filen = [[C:\anima\lua\anima\fonts\SilkRemington-SBold.ttf]]
local filen = [[C:\anima\lua\anima\fonts\fontawesome-webfont.ttf]]
--local filen = [[C:\anima\lua\anima\fonts\verdana.ttf]]

--fonter.mode = "polys"
local ch1=string.byte"D"
--ch1=91
--ProfileStart()--"3vfsi4m1")
 local f1 = fonter.new_face(filen,
	{
	--{0,255}
	--{61724,62000}
	--{61724,0xFFFF}
	--{61400,0xFFFF}
	--{0,0xFFFF}
	--{61726,61726}
	
	--{61886,61886}
	--{61580,61580} --lined
	--{61442,61442}
	--{62046,62046}
	--{61868,61868} --calculadora
	--{61869,61869}
	--{62082,62082}
	--{61821,61821} --drible
	{61440,61440} --glass
	--{61572,61572} --key primero mal se ve bien
	--{61733,61733} --crop mal Earclip 1 y 2 sin holes
	--{61798,61798} --youtube insert1 mejor
	--{61819,61819} --android ok
	 --{61852,61852} --ok
	--{61890,61890} --W
	--{61891,61891} --W
	--{61892,61892} --W
	--{61894,61894} --W
	--{61895,61895} --W
	--{61926,61926} --W
	--{61937,61937} --W
	--{61940,61940} --paypal
	--{61970,61970} --W
	--{62012,62012} --W
	--{62042,62042} --W
	--{62046,62046} --cc
	--{62138,62138} --W
	--{62140,62140} --W
	--{62142,62142} --W
	--{61580, 61580} --linkedin
	}
	,1024*4,5,false)--,{{35,35}})
--local f1 = fonter.new_face(filen,{{ch1,ch1}},1024*4,5)
--ProfileStop()

-------------

local GL = GLcanvas{H=800,aspect=1}

local NM = GL:Dialog("fonter",{
{"show",0,guitypes.valint,{min=0,max=20}},
{"mesh",false,guitypes.toggle},
{"lines",false,guitypes.toggle},
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
	camera.NM.vars.dist[0]=2.7
end

local texto = ""
local ch1 = ffi.new("int[?]",1,string.byte"D")
function GL.imgui()
	-- if ig.InputText("choose",ch1,2,ig.lib.ImGuiInputTextFlags_EnterReturnsTrue) then
		-- print("choose",ch1[0])
	-- end
	
	-- if ig.InputInt("cp",ch1) then
		-- print("cp",ch1[0])
	-- end
	if ig.BeginTable("dirsizes",4, ig.lib.ImGuiTableFlags_Borders + ig.lib.ImGuiTableFlags_RowBg + ig.lib.ImGuiTableFlags_ScrollY + ig.lib.ImGuiTableFlags_Resizable) then
		local clipper = ig.ImGuiListClipper()
			clipper:Begin(#f1.allcps)
			while (clipper:Step()) do
				for line = clipper.DisplayStart+1,clipper.DisplayEnd-1+1 do
					if line <= #f1.allcps then
					ig.TableNextRow()
					ig.TableNextColumn()
					if ig.Button(tostring(f1.allcps[line].cp)) then
						ch1[0] = f1.allcps[line].cp
						break
					end
					ig.TableNextColumn()
					ig.TextUnformatted(f1.allcps[line].name)
					ig.TableNextColumn()
					ig.TextUnformatted(f1.allcps[line].cross and "cross" or "")
					ig.TableNextColumn()
					ig.TextUnformatted(f1.allcps[line].badhole and "badhole" or "")
					end
				end
			end
			clipper:End()
		ig.EndTable()
	end
end
---[[
	--T.MO = mat.identity4()
	function f1:printcp2(cp,camera,MO,numpoly)
		--print"vvvvvvvvv"
		local M = fonter
		MO = MO or self.MO
		M.program:use()
		M.program.unif.MVP:set(camera:MVP().gl)
		M.program.unif.MO:set(MO.gl)
		local cha = self.chars[cp]
		if not cha then
			local k,v = next(self.chars)
			cha  = v
		end
		if M.mode == "polys" then
			for i,v in ipairs(cha.vaos) do
				if numpoly == i or numpoly == 0 then
				M.program.unif.color:set{color.HSV2RGB((i-1)/#cha.vaos,1,1)}
				v:draw(glc.GL_LINE_LOOP)
				gl.glPointSize(6)
				M.program.unif.color:set{1,1,1}
				v:draw(glc.GL_POINTS, 1, math.min(math.max(0,math.floor(NM.ini)),v.count))
				gl.glPointSize(1)
				end
			end
		else
			local tr = cha.mesh:triangle(math.floor(NM.count))
			--print(cha.vao.num_indices/3,tr[1],tr[2],tr[3])
			texto = (cha.vao.num_indices/3)..","..tr[1]..","..tr[2]..","..tr[3]
			
			M.program.unif.color:set{0,1,0}
			if cha.vao then 
				--cha.vao:draw(glc.GL_LINE_LOOP)
				--cha.vao:draw_mesh()
				--cha.vao:draw_mesh(NM.count,math.floor(NM.count)) 
			end
			
			M.program.unif.color:set{0.25,0.25,0.25}
			if cha.vao then cha.vao:draw(glc.GL_LINE_LOOP) end 
			
			--if cha.vao then cha.vao:draw_mesh() end
			M.program.unif.color:set{1,0,0}
			for i,r in ipairs(cha.restsvaos) do
				 r:draw(glc.GL_LINE_LOOP)
			end
			
			gl.glPointSize(6)
			M.program.unif.color:set{1,1,1}
			if cha.vao then cha.vao:draw(glc.GL_POINTS,1,math.floor(NM.ini)) end
			gl.glPointSize(1)
			
		end
	end
--]]
function GL.draw(t,w,h)
	
	mssa:Bind()
	ut.Clear()
	gl.glViewport(0,0,w,h)
	if fonter.mode == "polys" then
		f1:printcp(ch1[0],camera,nil,NM)
	else
		f1:printcp(ch1[0],camera,nil,NM)
	end
	--f1:printstring("Te estoy",camera)
	mssa:Dump()
end

GL:start()