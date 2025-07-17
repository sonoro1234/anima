local function codepoint_to_utf8(c)
    if     c < 128 then
        return                                                          string.char(c)
    elseif c < 2048 then
        return                                     string.char(192 + c/64, 128 + c%64)
    elseif c < 55296 or 57343 < c and c < 65536 then
        return                    string.char(224 + c/4096, 128 + c/64%64, 128 + c%64)
    elseif c < 1114112 then
        return string.char(240 + c/262144, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
    end
end

local fonter = require"fonter"

local filen = [[C:\anima\lua\anima\fonts\ProggyTiny.ttf]]
local filen = [[C:\anima\lua\anima\fonts\SilkRemington-SBold.ttf]]
local filen = [[C:\anima\lua\anima\fonts\fontawesome-webfont.ttf]]
local filen = [[C:\anima\lua\anima\fonts\fa-solid-900.ttf]]
--local filen = [[C:\anima\lua\anima\fonts\verdana.ttf]]
local filen = [[C:\anima\lua\anima\fonts\seguiemj.ttf]]

fonter.triangulator = "glu"
--fonter.mode = "polys"
fonter.min_area = 1e-4 --1e-12
local ch1=string.byte"D"
--ch1=91

ProfileStart()--"3vfsi4m1")
local t1 = secs_now()
 local f1 = fonter.new_face(filen,
	{
	--{129691,129691}
	--{199,199} 
	{9641,9641}, --bad seguiemj
	--{10037,10037}, --bad seguiemj
	--{127959,127959}, --bad seguiemj
	--{126982,126982}, --bad seguiemj
	--{63076,63076} --bad fa-solid
	--{57434,57434}
	--{57447,57447}--virus-lung
	--{8987,8987} --seguiemj reloj arena
	--{62904,62904}
	--{62851,62851}
	--{57433,57433}
	--{9772,9772}
	--{0,255}
	--{61724,62000}
	--{61724,0xFFFF}
	--{61400,0xFFFF}
	--{0,0xFFFF}
	--{0,0xFFFF}
	--{0,0x10FFFF}
	--{0,128120}
	--{128121, 128121}
	--{199,199}
	--{62524,62524}
	--{61726,61726} --flagchecked
	--{61886,61886}
	--{61580,61580} --lined
	--{61442,61442}
	--{62046,62046}
	--{61868,61868} --calculadora (BAD)
	--{61869,61869}
	--{62082,62082}
	--{61821,61821} --drible
	--{61440,61440} --glass
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
	--{61612,61612} --globe
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
ProfileStop()
print("-----------done in",secs_now()-t1)

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
local function save_polyset( filename)
		local ch = f1.chars[ch1[0]]
		local str = {}
		table.insert(str,serializeTable("polyset",ch.layers[1].polyset))
		table.insert(str,"\nreturn polyset")
		local file,err = io.open(filename,"w")
		if not file then print(err); return end
		file:write(table.concat(str))
		file:close()
end

local polysaver = gui.FileBrowser(nil,{check_existence=true,filename="phfx",key="saveps",pattern="polyset",addext=true},save_polyset)
function GL.imgui()
	-- if ig.InputText("choose",ch1,2,ig.lib.ImGuiInputTextFlags_EnterReturnsTrue) then
		-- print("choose",ch1[0])
	-- end
	
	-- if ig.InputInt("cp",ch1) then
		-- print("cp",ch1[0])
	-- end
	if ig.SmallButton("save polyset") then
		polysaver.open()
	end
	polysaver.draw()
	if ig.BeginTable("dirsizes",5, ig.lib.ImGuiTableFlags_Borders + ig.lib.ImGuiTableFlags_RowBg + ig.lib.ImGuiTableFlags_ScrollY + ig.lib.ImGuiTableFlags_Resizable + ig.lib.ImGuiTableFlags_Sortable) then
		ig.TableSetupColumn("cp");
        ig.TableSetupColumn("name");
		ig.TableSetupColumn("cross");
		ig.TableSetupColumn("badhole");
		ig.TableSetupColumn("utf8");
        ig.TableHeadersRow();
		local sort_specs = ig.TableGetSortSpecs();
		if sort_specs and sort_specs.SpecsDirty then 
			local col_specs = sort_specs.Specs[0]
			--print(col_specs.ColumnUserID, col_specs.ColumnIndex, col_specs.SortOrder, col_specs.SortDirection);
			local sortfield = ({"cp","name","cross","badhole"})[col_specs.ColumnIndex + 1]
			local function sortf1(a,field) return a[field] end
			local function sortf_bool(a,field) return a[field] and 1 or 0 end
			local sortff = ({sortf1,sortf1,sortf_bool,sortf_bool})[col_specs.ColumnIndex + 1]
			if sortfield then
				if col_specs.SortDirection == ig.lib.ImGuiSortDirection_Ascending then
					table.sort(f1.allcps,function(a,b) return sortff(a,sortfield) < sortff(b,sortfield) end)
				elseif col_specs.SortDirection == ig.lib.ImGuiSortDirection_Descending then
					table.sort(f1.allcps,function(a,b) return sortff(a,sortfield) > sortff(b,sortfield) end)
				end
			end
			sort_specs.SpecsDirty=false 
		end
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
					ig.TableNextColumn()
					local str = codepoint_to_utf8(f1.allcps[line].cp)
					local bytes = {string.byte(str, 1, #str)}
					local str2 = ""
					for i=1,#str do str2 = str2 .. "\\x" .. string.format("%X",bytes[i]) end
					ig.TextUnformatted(str2)
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