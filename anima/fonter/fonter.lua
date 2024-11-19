local ft = require"freetype"
local ffi = require"ffi"
local CG3 = require"anima.CG3"
local vec2 = mat.vec2
local printD = print --function() end
local function Vec(a, b)
	return vec2(a, b)
end 

local M = {ft=ft}
local floor = math.floor
local function reverse(t)
	local s = #t+1
	for i=1,floor(#t/2) do
		t[i],t[s-i] = t[s-i],t[i]
	end
	return t
end
local function Bezier2(t,P0,P1,P2)
	local tm1 = 1 - t
	return tm1*(tm1*P0+t*P1)+t*(tm1*P1+t*P2)
end
local function Bezier3(t,P0,P1,P2,P3)
	local tm1 = 1 - t
	return tm1*Bezier2(t,P0,P1,P2)+t*Bezier2(t,P1,P2,P3)
end
local function add_segment(poly,segment,steps)
	--steps = steps or 10 --10
	if #segment == 2 then --line
		poly[#poly+1] = segment[1]
	elseif #segment == 3 then -- conic Bezier2
		for i=0,steps-1 do
			poly[#poly+1] = Bezier2(i/steps,segment[1],segment[2],segment[3])
		end
	elseif #segment == 4 then -- cubic Bezier2
		for i=0,steps-1 do
			poly[#poly+1] = Bezier3(i/steps,segment[1],segment[2],segment[3],segment[4])
		end
	else
		error"add_segment with more than 4 point"
	end
end

	
local function face_show_glyph_index_outlines(face,glyph_index)
	face:set_char_size(64*64)
	face:load_glyph(glyph_index, ft.C.FT_LOAD_NO_BITMAP)
	local glyph = face.glyph
	local outline = glyph.outline
	print("outline",outline.n_contours, outline.n_points)
end
------------
local poldec = {}
local function movetof(to,user)
	printD("---init",#poldec +1)
	printD("movetof",to.x,to.y)
	poldec[#poldec + 1] = {}
	table.insert(poldec[#poldec],Vec(to.x,to.y))
	return 0
end
local function linetof(to,user)
	printD("linetof",to.x,to.y,"point#",#poldec[#poldec])
	table.insert(poldec[#poldec],Vec(to.x,to.y))
	return 0
end
local function conictof(ctrl,to,user)
	printD("conictof",ctrl.x,ctrl.y,to.x,to.y)
	local poly = poldec[#poldec]
	local ini = poly[#poly]
	local steps = 5
	for i=0,steps do
			poly[#poly+1] = Bezier2(i/steps,ini,Vec(ctrl.x,ctrl.y),Vec(to.x,to.y))
	end
	return 0
end
local function cubictof(ctrl,ctrl2,to,user)
	printD("cubictof",ctrl.x,ctrl.y,ctrl2.x,ctrl2.y,to.x,to.y)
	local poly = poldec[#poldec]
	local ini = poly[#poly]
	local steps = 5
	for i=0,steps do
			poly[#poly+1] = Bezier3(i/steps,ini,Vec(ctrl.x,ctrl.y),Vec(ctrl2.x,ctrl2.y),Vec(to.x,to.y))
	end
	return 0
end
local funcs = ffi.new("FT_Outline_Funcs[1]")
funcs[0].move_to = movetof
funcs[0].line_to = linetof
funcs[0].conic_to = conictof
funcs[0].cubic_to = cubictof
local function decompose(outline,polyset)
	
	poldec = polyset
	outline:decompose(funcs)
end
local function face_char_outline_to_polyset(face,fosize,ch,polyset,steps,outlinef)
	steps = steps or 10
	face:set_char_size( fosize)
	local invsize = 1/(fosize)
	face:load_char(ch, ft.C.FT_LOAD_NO_BITMAP)
	local glyph = face.glyph
	local glyph_index = face:char_index(ch )--glyph.glyph_index
	print(ch,glyph_index,face:glyph_name(glyph_index,nil,64))
	local outline = glyph.outline
	
	if outlinef then
		decompose(outline, polyset)
		for i,pol in ipairs(polyset) do
			for j,v in ipairs(pol) do
				pol[j] = v*invsize
			end
		end
		return Vec(glyph.advance.x, glyph.advance.y,0)*invsize
	end
	
	--outline:check()
	--print("outline: contours",outline.n_contours,",points:", outline.n_points)
	--for i=0,outline.n_points-1 do
		--print(i,outline.points[i].x,outline.points[i].y,bit.band(outline.tags[i],0x03))
	--end
	--print"-------contours-----------"
	local lasti = 0
	for i=0,outline.n_contours-1 do
		polyset[#polyset+1] = {}
		local poly = polyset[#polyset]
		--print("#outline",i,outline.contours[i])
		local segment = {}
		local initisoff 
		local virtualini
		if bit.band(outline.tags[lasti],0x01) == 0x00 then --init is off point
			--print"--------iit is off"
			--error"init off"
			local lp = outline.contours[i]
			if (bit.band(outline.tags[lp],0x01) == 0x01) then --last on
				segment = {Vec(outline.points[lp].x*invsize,outline.points[lp].y*invsize,0)}
				initisoff = true --to avoid repeating
			else --last off
				local p1,p2
				p1 = Vec(outline.points[lp].x*invsize,outline.points[lp].y*invsize,0)
				p2 = Vec(outline.points[lasti].x*invsize,outline.points[lasti].y*invsize,0)
				virtualini = 0.5*(p1+p2)
				segment = {virtualini}
			end
		end
		for j=lasti,outline.contours[i] do
			if bit.band(outline.tags[j],0x01) == 0x01 then --on point
				--print"--on"
				if #segment == 0 then --initial
					segment[1] = Vec(outline.points[j].x*invsize,outline.points[j].y*invsize,0)
				else --end on point
					segment[#segment+1] = Vec(outline.points[j].x*invsize,outline.points[j].y*invsize,0)
					assert(#segment<4,#segment)
					add_segment(poly,segment,steps)
					segment = {segment[#segment]}
				end
			else --off point
				--print"--off"
				if bit.band(outline.tags[j],0x03) == 0x00 then --conic
					segment[#segment+1] = Vec(outline.points[j].x*invsize,outline.points[j].y*invsize,0)
					if #segment == 3 then
						assert(bit.band(outline.tags[j-1],0x03) == 0x00)
						local virtual = 0.5*(segment[2] + segment[3])
						add_segment(poly,{segment[1],segment[2],virtual},steps)
						segment = {virtual,segment[3]}
					end
					assert(#segment<3)
				else
					assert(bit.band(outline.tags[j],0x03) == 0x02) --cubic
					error"not cubic "
				end
			end
		end
		--end line
		if not initisoff then
			if virtualini then
				segment[#segment+1] = virtualini
			else
				segment[#segment+1] = Vec(outline.points[lasti].x*invsize,outline.points[lasti].y*invsize,0)
			end
			add_segment(poly,segment,steps)
		end
		lasti = outline.contours[i] + 1
	end
	--tweak
	-- local ppoly = reverse(polyset[3])
	-- polyset[1] = ppoly --;polyset[2] = nil; polyset[3] = nil
	-- for i=2,#polyset do polyset[i] = nil end
	-- print("num polyset",#polyset)
	--prtable(polyset)
	--[[
	local str = {}
		table.insert(str,serializeTable("params",polyset))
		table.insert(str,"\nreturn params")
		local file,err = io.open("datapoly.lua","w")
		if not file then print(err); return end
		file:write(table.concat(str))
		file:close()
	--]]
	
	return Vec(glyph.advance.x, glyph.advance.y,0)*invsize
end

function M.GetStrPolys(face,str,fosize)
	local chars = {}
	local previndex
	local has_kerning = bit.band(face.face_flags,ft.C.FT_FACE_FLAG_KERNING)
	print("Has kerning", has_kerning)
	for i=1,#str do
		local ch = str:sub(i,i)
		print("ch",i,ch)
		local glyph_index = face:char_index(  string.byte(ch) )
		local polyset ={}
		local advance = face_char_outline_to_polyset(face, fosize, string.byte(ch),polyset)
		if previndex and has_kerning then
			local delta = face:kerning( previndex, glyph_index, ft.C.FT_KERNING_UNSCALED)--, delta)
			print("delta----------------",delta.x,delta.y)
			chars[i-1].advance = chars[i-1].advance + Vec(delta.x,delta.y,0)/fosize
		end
		previndex = glyph_index
		chars[i] = {polyset=polyset,advance=advance}
	end
	return chars
end
--glyph must exist
function M.GetCodePoint(face,cp,fosize,steps, outlinef)
	local glyph_index = face:char_index(cp )
	assert(glyph_index ~= 0)
	local polyset ={}
	local advance = face_char_outline_to_polyset(face, fosize,cp,polyset,steps,outlinef)
	local empty = #polyset == 0 and true
	return {polyset=polyset,advance=advance,glyph_index=glyph_index,cp=cp,name=face:glyph_name(glyph_index),empty=empty}
end


local function fitsInside(p,h)
	for i,pt in ipairs(h) do
		if not CG3.IsPointInPoly(p,pt) then return false end
	end
	return true
end
local algo = require"anima.algorithm.algorithm"
local CHK = require"anima.CG3.check_poly"
--repair , reverse and set as holes when inverse direction
function M.repair_char1(ch)
	local polyset2 = {}
	local polyset = ch.polyset
	local holes = {}
	for i=1,#polyset do
		printD("--doing repair",i,"from",#polyset,#polyset[i],"points")
		if #polyset[i] < 3 then goto continue end
		local remr,remc = CG3.degenerate_poly_repair(polyset[i],false)
		printD("repairs",remr,remc)
		if #polyset[i] < 3 then goto continue end
		local polys = CHK.check_repair_self_crossings(polyset[i])
		if #polys > 1 then
			--prtable(polyset[i])
			--prtable(cross)
			print("--------------repair self crossings:")
			--local polys = CHK.repair_self_crossings(polyset[i],cross)
			print(#polys,"polys returned")
			--
			--prtable(polys)
			for j=1,#polys do
				CG3.degenerate_poly_repair(polys[j],true)
				local cross = CHK.check_self_crossings(polys[j])
				if #cross > 0  then print("bad repairing",j) end
				table.insert(polyset2, polys[j])	
			end
		else
			table.insert(polyset2, polyset[i])
		end
		::continue::
	end
	ch.polyset = polyset2
end
function M.repair_char2(ch)	
	local polyset2 = {}
	local polyset = ch.polyset
	local holes = {}
	for i=1,#polyset do
		if #polyset[i] > 0 then
			local sA = CG3.signed_area(polyset[i])
			printD("signed area",i,sA,"npoints",#polyset[i])
			--discard 0 area
			if math.abs(sA) > 1e-12 then
			--if math.abs(sA) > 1e-5 then
			if sA < 0 then
				polyset[i].sA = math.abs(sA)
				polyset2[#polyset2+1] = reverse(polyset[i])
			else --is hole
				if M.mode == "polys" then
					polyset2[#polyset2+1] = reverse(polyset[i])
				else
					polyset[i].sA = sA
					table.insert(holes,reverse(polyset[i]))
				end
			end
			end
		end
	end
	--prtable(polyset2)
	--insert holes
	if M.mode ~= "polys" then
	algo.quicksort(polyset2,1,#polyset2,function(a,b) return a.sA < b.sA end)
	algo.quicksort(holes,1,#holes,function(a,b) return a.sA > b.sA end)
	--prtable(holes)
	---discard bad holes inside other holes
--[[
	local badholes = {}
	for i=1,#holes do
		for j=i+1,#holes do
			if fitsInside(holes[i],holes[j]) then
				print("---  bad hole",i,j)
				ch.badhole = true
				table.insert(badholes,j)
			end
		end
	end
	table.sort(badholes,function(a,b) return a > b end)
	for i,j in ipairs(badholes) do
		local hole = table.remove(holes,j)
		table.insert(polyset2,reverse(hole))
	end
--]]
	local maxbox = CG3.box2d(polyset2[#polyset2])
	local maxsize = maxbox[2].x > maxbox[2].y and maxbox[2].x or maxbox[2].y
	local facPad = maxsize/1000
	for i,h in ipairs(holes) do
		local found = false
		for j,p in ipairs(polyset2) do
			if fitsInside(p,h) then
				p.holes = p.holes or {}
				local holecross = false
				for i2,h2 in ipairs(p.holes) do
					local cross = CHK.check2poly_crossings(h2,h)
					if #cross > 0 then 
						printD("holes cross",i,i2)
						--local hpad = CG3.PolygonPad(h,-facPad,true)
						--for l,lv in ipairs(hpad) do h[l] = lv end
						holecross = true; --for inserting afted padding
						break 
					end
				end
				--check dont overlap other holes
				if not holecross then
					found = true
					table.insert(p.holes,h)
					break
				end
			end
		end
		if not found then 
			print("hole",i,"not found"); 
			table.insert(polyset2,reverse(holes[i])) 
			ch.badhole = true
		end
	end
	
		--check bad holes
		for i,p in ipairs(polyset2) do
			--prtable(p.holes)
			if p.holes and #p.holes > 0 then
				
				algo.quicksort(p.holes,1,#p.holes,function(a,b) return a.sA > b.sA end)
				local badholes = {}
				for j,h in ipairs(p.holes) do
					for k=j+1,#p.holes do
						local h2 = p.holes[k]
						if fitsInside(h,h2) then
							print("---  bad hole",j,k)
							ch.badhole = true
							table.insert(badholes,k)
							--badholes[k] = true
						end
					end
				end
				table.sort(badholes,function(a,b) return a > b end)
				--for k,_ in pairs(badholes) do
				for _,k in pairs(badholes) do
					printD("remove badhole",k)
					table.insert(polyset2,reverse(p.holes[k]))
					table.remove(p.holes,k)
				end
			end
		end
	end
	--ch.polyset = {polyset2[5]}
	ch.polyset = polyset2
	--prtable(polyset2)
end
-- function M.repair_chars(chars)
	-- for i,ch in ipairs(chars) do
		-- M.repair_char(ch)
	-- end
-- end



function M.char_to_trmeshes(ch)
	local ff = require"anima.CG3.FIST2"
	local Rests = {}
	local meshes = {}
	for i=1,#ch.polyset do
		printD("----------char_to_tr_mesh",i)
		--if i==2 then prtable(ch.polyset[i]) end
		for k=1,0 do
			table.remove(ch.polyset[i].holes,1)
		end

		local cross = CHK.CHECKPOLY(ch.polyset[i])
		if #cross > 0 then print("char_to_mesh: poly",i,"has crossings",#cross); end
		CHK.CHECKCOLIN(ch.polyset[i])
		
		ch.polyset[i] = CG3.InsertHoles2(ch.polyset[i],false)
		ch.polyset[i].holes = {}
		
		-- local trs,ok,rest,restind = CG3.EarClipSimple(ch.polyset[i], false)
		-- local ptsr = ch.polyset[i]
		local ptsr,trs,ok,rest,restind = CG3.EarClipSimple2(ch.polyset[i], true)
		--local ptsr,trs,ok,rest,restind = CG3.EarClipFIST(ch.polyset[i])
		--local ptsr,trs,ok,rest,restind = ff.EarClipFIST2(ch.polyset[i])
		--assert(ok,ch.cp)
		if not ok then
			print("--------------------------bad EarClip-----------------------------------------")
			--table.insert(Rests,mesh.mesh{points=rest})
			ch.cross = true
		end
		table.insert(Rests,mesh.mesh{points=rest})
		meshes[#meshes+1] = mesh.mesh{points=ptsr,triangles=trs}
	end

	return meshes,Rests

end

function M.char_to_meshes(ch)
	local meshes = {}
	local P,Tr = {}, {}
	for i=1,#ch.polyset do
		printD("char_to_meshes CHK.CHECKPOLY",i)
		--local cross = CHK.CHECKPOLY(ch.polyset[i])
		local cross = CHK.check_self_crossings(ch.polyset[i])
		if #cross > 0 then 
			print("char_to_meshes: poly",i,"has crossings",#cross) 
			ch.cross = true
		end
		
		if #ch.polyset[i] > 0 then
			meshes[#meshes+1] = mesh.mesh{points=ch.polyset[i]}
		end
		
	end
	return meshes
end



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
#version 330
uniform sampler2D tex0;
uniform vec3 color;
void main()
{
	gl_FragColor = vec4(color,1);
}
]]

M.initgl = function()
	M.program = GLSL:new():compile(vert_sh, frag_sh)
end

local function GetVisibleRanges(face)

	local gindex = ffi.new("FT_UInt[1]")
	local charcode = face:first_char(gindex)

	local cp_glyphs = {}
	while gindex[0] ~= 0 do
		--print(charcode, gindex[0] )
		cp_glyphs[charcode] = gindex[0]
		--print(charcode, cp_glyphs[charcode])
		charcode = face:next_char(charcode,gindex )
	end
	return cp_glyphs
end

function M.new_face(filename,ranges,size,steps,outlinef)
	--one library for all faces
	M.library = M.library or M.ft()
	local T = {ranges=ranges or {{32,127}},size=size or 4096,steps=steps or 5}
	T.face = M.library:face(filename)
	T.has_kerning = bit.band(T.face.face_flags,ft.C.FT_FACE_FLAG_KERNING)
	T.has_glyph_names = bit.band(T.face.face_flags,ft.C.FT_FACE_FLAG_GLYPH_NAMES)
	print("T.has_glyph_names",T.has_glyph_names)
	
	T.face:select_charmap(ft.C.FT_ENCODING_UNICODE)
	
	function T.GetStrPolys(self,str,fosize) return M.GetStrPolys(self.face,str,fosize) end
	
	T.visrng = GetVisibleRanges(T.face);
	
	T.chars = {}
	T.allcps = {}
	for i,range in ipairs(T.ranges) do
		for j=range[1],range[2] do
			--print("--------------getting cp",j,string.char(j))
			if T.visrng[j] then
			local ch = M.GetCodePoint(T.face, j, T.size , T.steps, outlinef)
			if not ch.empty then
				M.repair_char1(ch)
				--print(#ch.polyset, "polys after repair")
				--M.repair_char(ch)
				--print(#ch.polyset, "polys after repair")
				M.repair_char2(ch)
				--print(#ch.polyset, "polys after repair")
				table.insert(T.allcps,ch)
				if M.mode == "polys" then
					local meshes = M.char_to_meshes(ch)
					ch.meshes = meshes
					T.chars[j] = ch --{ch=ch,meshes=meshes}
				else
					local meshes,rests = M.char_to_trmeshes(ch)
					ch.meshes, ch.rests = meshes, rests
					T.chars[j] = ch --{ch=ch,mesh=mesh,rests=rests}
				end
				--else print("bad cp",j)
				end
			end
		end
	end
	--prtable(T.chars)
	table.sort(T.allcps, function(a,b) return a.cp < b.cp end)
	
	function T:initgl()
		if not M.program then M.initgl() end
		for k,v in pairs(self.chars) do
			if M.mode == "polys" then
				v.vaos = {}
				for i,m in ipairs(v.meshes) do
					v.vaos[i] = m:vao(M.program)
				end
			else
				--if v.mesh then v.vao = v.mesh:vao(M.program) end
				v.restsvaos = {}
				v.vaos = {}
				for i,m in ipairs(v.meshes) do
					v.vaos[i] = m:vao(M.program)
					v.restsvaos[i] = v.rests[i]:vao(M.program)
				end
			end
		end
	end
	local color = require"anima.graphics.color"
	T.MO = mat.identity4()
	function T:printcp(cp,camera,MO,NM)
		gl.glDisable(glc.GL_DEPTH_TEST)
		local numpoly = NM.show
		MO = MO or T.MO
		M.program:use()
		M.program.unif.MVP:set(camera:MVP().gl)
		M.program.unif.MO:set(MO.gl)
		local cha = self.chars[cp] --or self.chars[63]
		--assert(cha)
		if not cha then
			local k,v = next(self.chars)
			cha  = v
		end
		if M.mode == "polys" then
			for i,v in ipairs(cha.vaos) do
				if numpoly == 0 or numpoly == i then
				M.program.unif.color:set{color.HSV2RGB((i-1)/#cha.vaos,1,1)}
				v:draw(glc.GL_LINE_LOOP)
				gl.glPointSize(3)
				M.program.unif.color:set{1,1,1}
				v:draw(glc.GL_POINTS,1,math.min(math.max(0,math.floor(NM.ini)),v.count))
				gl.glPointSize(1)
				end
			end
		else
			for i,vao in ipairs(cha.vaos) do
				if numpoly == 0 or numpoly == i then
				M.program.unif.color:set{1,1,1}
				--if cha.vao then cha.vao:draw(glc.GL_LINE_LOOP) end 
				if NM.mesh then
					if NM.lines then
						vao:draw(glc.GL_LINE_LOOP)
						gl.glPointSize(6)
						M.program.unif.color:set{1,1,1}
						vao:draw(glc.GL_POINTS,1,math.min(math.max(0,math.floor(NM.ini)),vao.count))
						gl.glPointSize(1)
					else
						if vao then vao:draw_mesh() end
					end
				else
					if vao then vao:draw_elm() end
				end
				M.program.unif.color:set{1,0,0}
				local r = cha.restsvaos[i]
				r:draw(glc.GL_LINE_LOOP)
				
				-- gl.glPointSize(6)
				-- M.program.unif.color:set{1,1,1}
				-- if cha.vao then cha.vao:draw(glc.GL_POINTS) end
				-- gl.glPointSize(1)
				end
			end
		end
	end
	function T:printstring(str,camera)
		local advance = Vec(0,0,0)
		local previndex 
		for i=1,#str do
			local ch = str:sub(i,i)
			local cp = string.byte(ch)
			local MO = mat.translate(advance)
			self:printcp(cp,camera,MO)
			if self.has_kerning and previndex then
				local delta = self.face:kerning( previndex, self.chars[cp].ch.glyph_index, ft.C.FT_KERNING_UNSCALED)
				advance = advance + Vec(delta.x,delta.y,0)/T.size
			end
			advance = advance + self.chars[cp].ch.advance
			previndex = self.chars[cp].ch.glyph_index
		end
	end
	return T
end


return M