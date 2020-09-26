local ft = require"freetype"
local ffi = require"ffi"

local M = {ft=ft}

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

local function face_char_outline_to_polyset(face,fosize,ch,polyset,steps)
	steps = steps or 10
	face:set_char_size( fosize)
	local invsize = 1/(fosize)
	face:load_char(ch, ft.C.FT_LOAD_NO_BITMAP)
	local glyph = face.glyph
	local outline = glyph.outline
	--print("outline: contours",outline.n_contours,",points:", outline.n_points)
	--for i=0,outline.n_points-1 do
		--print(i,outline.points[i].x,outline.points[i].y,bit.band(outline.tags[i],0x03))
	--end
	--print"-------contours-----------"
	local lasti = 0
	for i=0,outline.n_contours-1 do
		polyset[#polyset+1] = {}
		local poly = polyset[#polyset]
		--print(i,outline.contours[i])
		local segment = {}
		local initisoff 
		local virtualini
		if bit.band(outline.tags[lasti],0x03) ~= 0x01 then --init is off point
			local lp = outline.contours[i]
			if (bit.band(outline.tags[lp],0x03) == 0x01) then
				segment = {mat.vec3(outline.points[lp].x*invsize,outline.points[lp].y*invsize,0)}
				initisoff = true --to avoid repeating
			else
				local p1,p2
				p1 = mat.vec3(outline.points[lp].x*invsize,outline.points[lp].y*invsize,0)
				p2 = mat.vec3(outline.points[lasti].x*invsize,outline.points[lasti].y*invsize,0)
				virtualini = 0.5*(p1+p2)
				segment = {virtualini}
			end
		end
		for j=lasti,outline.contours[i] do
			if bit.band(outline.tags[j],0x03) == 0x01 then --on point
				--print"--on"
				if #segment == 0 then --initial
					segment[1] = mat.vec3(outline.points[j].x*invsize,outline.points[j].y*invsize,0)
				else --end on point
					segment[#segment+1] = mat.vec3(outline.points[j].x*invsize,outline.points[j].y*invsize,0)
					assert(#segment<4,#segment)
					add_segment(poly,segment,steps)
					segment = {segment[#segment]}
				end
			else --off point
				--print"--off"
				if bit.band(outline.tags[j],0x03) == 0x00 then --conic
					segment[#segment+1] = mat.vec3(outline.points[j].x*invsize,outline.points[j].y*invsize,0)
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
				segment[#segment+1] = mat.vec3(outline.points[lasti].x*invsize,outline.points[lasti].y*invsize,0)
			end
			add_segment(poly,segment,steps)
		end
		lasti = outline.contours[i] + 1
	end
	return mat.vec3(glyph.advance.x, glyph.advance.y,0)*invsize
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
			chars[i-1].advance = chars[i-1].advance + mat.vec3(delta.x,delta.y,0)/fosize
		end
		previndex = glyph_index
		chars[i] = {polyset=polyset,advance=advance}
	end
	return chars
end

function M.GetCodePoint(face,cp,fosize,steps)
	local glyph_index = face:char_index(cp )
	local polyset ={}
	local advance = face_char_outline_to_polyset(face, fosize,cp,polyset,steps)
	return {polyset=polyset,advance=advance,glyph_index=glyph_index,cp=cp}
end

local CG3 = require"anima.CG3"
local floor = math.floor
local function reverse(t)
	local s = #t+1
	for i=1,floor(#t/2) do
		t[i],t[s-i] = t[s-i],t[i]
	end
	return t
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
function M.repair_char(ch)
	local polyset2 = {}
	local polyset = ch.polyset
	local holes = {}
	for i=1,#polyset do
		--print("--doing",i,"from",#polyset)
		local remr,remc = CG3.degenerate_poly_repair(polyset[i],false)
		--print("repairs",remr,remc)
		--local remr,remc = CG3.degenerate_poly_repair(polyset[i],false)
		--assert(remr==0 and remc==0)
		
		local cross = CHK.check_self_crossings(polyset[i])
		if #cross > 0 then
			
			print("--------------repair self crossings:",#cross)
			local polys = CHK.repair_self_crossings(polyset[i],cross)
			print(#polys,"returned")
			polyset[i] = polys[1]
			for j=2,#polys do
				table.insert(polyset, polys[j])
			end
		end
	end
	
	for i=1,#polyset do
		if #polyset[i] > 0 then
			local sA = CG3.signed_area(polyset[i])
			--print("signed area",i,sA)
			--discard 0 area
			if math.abs(sA) > 1e-12 then
			if sA < 0 then
				polyset[i].sA = math.abs(sA)
				polyset2[#polyset2+1] = reverse(polyset[i])
			else --is hole
				if M.mode == "polys" then
					polyset2[#polyset2+1] = polyset[i]
				else
					table.insert(holes,reverse(polyset[i]))
				end
			end
			end
		end
	end
	--insert holes
	if M.mode ~= "polys" then
	algo.quicksort(polyset2,1,#polyset2,function(a,b) return a.sA < b.sA end)
	for i,h in ipairs(holes) do
		local found = false
		for j,p in ipairs(polyset2) do
			if fitsInside(p,h) then
				found = true
				p.holes = p.holes or {}
				table.insert(p.holes,h)
				break
			end
		end
		if not found then print("hole",i,"not found") end
	end
	end
	ch.polyset = polyset2
end
function M.repair_chars(chars)
	for i,ch in ipairs(chars) do
		M.repair_char(ch)
	end
end



function M.char_to_mesh(ch)
	local deltaindex = 0
	local P,Tr = {}, {}
	local Rests = {}
	for i=1,#ch.polyset do

		--local cross = CHK.CHECKPOLY(ch.polyset[i])
		--if #cross > 0 then print("char_to_meshe: poly",i,"has crossings",#cross); end
		
		local ptsr,trs,ok,rest,restind = CG3.EarClipSimple2(ch.polyset[i], true)
		assert(ok,ch.cp)
		if not ok then
			print("--------------------------bad EarClip-----------------------------------------")
			table.insert(Rests,mesh.mesh{points=rest})
		end
		for j,p in ipairs(ptsr) do
			P[j+deltaindex] = p
		end
		for j,tr in ipairs(trs) do
			Tr[#Tr+1] = tr + deltaindex
		end
		deltaindex = deltaindex + #ptsr
	end
	if #P>0 then
		return mesh.mesh{points=P,triangles=Tr},Rests
	else
		return nil,Rests
	end
end

function M.char_to_meshes(ch)
	local meshes = {}
	local P,Tr = {}, {}
	for i=1,#ch.polyset do

		local cross = CHK.CHECKPOLY(ch.polyset[i])
		if #cross > 0 then print("char_to_meshes: poly",i,"has crossings",#cross) end
		
		if #ch.polyset[i] > 0 then
			meshes[#meshes+1] = mesh.mesh{points=ch.polyset[i]}
		end
		
	end
	return meshes
end



local vert_sh = [[

in vec3 position;

uniform mat4 MVP;
uniform mat4 MO;
void main()
{

	gl_Position = MVP*MO*vec4(position,1);
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


function M.new_face(filename,ranges,size,steps)
	--one library for all faces
	M.library = M.library or M.ft()
	local T = {ranges=ranges or {{32,127}},size=size or 4096,steps=steps or 5}
	T.face = M.library:face(filename)
	T.has_kerning = bit.band(T.face.face_flags,ft.C.FT_FACE_FLAG_KERNING)
	function T.GetStrPolys(self,str,fosize) return M.GetStrPolys(self.face,str,fosize) end
	
	T.chars = {}
	for i,range in ipairs(T.ranges) do
		for j=range[1],range[2] do
			--print("--------------getting cp",j,string.char(j))
			local ch = M.GetCodePoint(T.face,j,T.size,T.steps)
			M.repair_char(ch)
			if M.mode == "polys" then
				local meshes = M.char_to_meshes(ch)
				T.chars[j] = {ch=ch,meshes=meshes}
			else
				local mesh,rests = M.char_to_mesh(ch)
				T.chars[j] = {ch=ch,mesh=mesh,rests=rests}
			end
		end
	end
	
	function T:initgl()
		if not M.program then M.initgl() end
		for k,v in pairs(self.chars) do
			if M.mode == "polys" then
				v.vaos = {}
				for i,m in ipairs(v.meshes) do
					v.vaos[i] = m:vao(M.program)
				end
			else
				if v.mesh then v.vao = v.mesh:vao(M.program) end
				v.restsvaos = {}
				for i,r in ipairs(v.rests) do
					v.restsvaos[i] = r:vao(M.program)
				end
			end
		end
	end
	local color = require"anima.graphics.color"
	T.MO = mat.identity4()
	function T:printcp(cp,camera,MO)
		MO = MO or T.MO
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
			M.program.unif.color:set{1,1,1}
			--if cha.vao then cha.vao:draw(glc.GL_LINE_LOOP) end 
			if cha.vao then cha.vao:draw_elm() end
			M.program.unif.color:set{1,0,0}
			for i,r in ipairs(cha.restsvaos) do
				 r:draw(glc.GL_LINE_LOOP)
			end
			
			-- gl.glPointSize(6)
			-- M.program.unif.color:set{1,1,1}
			-- if cha.vao then cha.vao:draw(glc.GL_POINTS) end
			-- gl.glPointSize(1)
			
		end
	end
	function T:printstring(str,camera)
		local advance = mat.vec3(0,0,0)
		local previndex 
		for i=1,#str do
			local ch = str:sub(i,i)
			local cp = string.byte(ch)
			local MO = mat.translate(advance)
			self:printcp(cp,camera,MO)
			if self.has_kerning and previndex then
				local delta = self.face:kerning( previndex, self.chars[cp].ch.glyph_index, ft.C.FT_KERNING_UNSCALED)
				advance = advance + mat.vec3(delta.x,delta.y,0)/T.size
			end
			advance = advance + self.chars[cp].ch.advance
			previndex = self.chars[cp].ch.glyph_index
		end
	end
	return T
end


return M