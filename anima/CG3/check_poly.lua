
local CG = require"anima.CG3"
local M = {}
function M.check_self_repetition(poly)
	local reps = {}
	for i=1,#poly-1 do
		local pt = poly[i]
		for j=i+1,#poly do
		local pt2 = poly[j]
			if pt==pt2 then 
				print("repeated point",i,j,"#poly",#poly)
				table.insert(reps,{i,j})
				--error"self repetition"
			end
		end
	end
	return reps
end

local function check_self_consec_repetition(poly)
	if #poly==0 then return end
	local toremove = {}
	for i=1,#poly-1 do
		local j = i + 1
		while poly[i]==poly[j] do
			toremove[#toremove+1] = j 
			j = j + 1
			if j == #poly then j = 1 end
			if j == i then break end
		end
	end
	if poly[#poly]==poly[1] then toremove[#toremove+1] = #poly end
	if #toremove > 0 then error"consec_repeated" end
	-- for i=#toremove,1,-1 do 
		-- if verbose then print("check_repeated deletes",toremove[i]); end
		-- table.remove(poly,toremove[i]) end
	-- return #toremove
end

local function check2poly_repetition(poly1,poly2)
	for i=1,#poly1 do
		local pt = poly1[i]
		for j=1,#poly2 do
		local pt2 = poly2[j]
			if pt==pt2 then 
				print("check2poly_repetition repeated point",i,j)
				--error"2poly repetition"
				return true
			end
		end
	end
	return false
end

local function check_point_repetition(poly)
	local has_repeat = false
	check_self_consec_repetition(poly)
	if poly.holes then
	for nh,hole in ipairs(poly.holes) do
		local repe = check2poly_repetition(poly,hole)
		if repe then return true end
		for nh2=nh+1,#poly.holes do
			local repe = check2poly_repetition(hole,poly.holes[nh2])
			if repe then return true end
		end
	end
	end
	return has_repeat
end





local function mod(a,b)
	return ((a-1)%b)+1
end

local function check2poly_crossings(poly1,poly2,crossings)
	crossings = crossings or {}
	for i=1,#poly1 do
		local ai,bi = i,mod(i+1,#poly1)
		local a,b = poly1[ai],poly1[bi]
		for j=1,#poly2 do
			local ci,di = j,mod(j+1,#poly2)
			local c,d = poly2[ci],poly2[di]
			if CG.SegmentIntersectC(a,b,c,d) 
			then
				--print("poly1-poly2 crossing",ai,bi,ci,di)
				--error"self crossing"
				local pt = CG.IntersecPoint(a,b,c,d)
				table.insert(crossings,{pt,poly1,ai,poly2,ci})
			end
		end
	end
	return crossings
end

function M.repair_self_crossingsBAK(poly,cross)

	if #cross == 0 then return {poly} end
	local typ = ffi.typeof(poly[1]) --could be vec3 or vec2
	local polyset = {}
	local crossS = {}
	local nexT = {}
	for j,cr in ipairs(cross) do
						-- pt , a , c
		crossS[cr[3]] = {typ(cr[1]),cr[3],cr[5]}
		crossS[cr[5]] = {typ(cr[1]),cr[3],cr[5]}
	end
	
	local function use_cross(k,crS,poly1)
		local nex
		if k == crS[2] then 
			if poly[crS[2]]==crS[1] then --crossing in a segment begin
				poly1[#poly1+1] = poly[crS[2]] --a==pt
			else
				poly1[#poly1+1] = poly[crS[2]] --a
				poly1[#poly1+1] = crS[1] --pt
			end
			nex = mod(crS[3]+1,#poly) --d
		else
			assert(k==crS[3])
			if poly[crS[3]]==crS[1] then
				poly1[#poly1+1] = poly[crS[3]] --c==pt
			else
				poly1[#poly1+1] = poly[crS[3]] --c
				poly1[#poly1+1] = crS[1] --pt
			end
			nex = mod(crS[2]+1,#poly) --b
		end
		return nex
	end
	
	for k,crS in pairs(crossS) do
		if not crS.visited then
			crS.visited = true
			local poly1 = {}
			local nex = use_cross(k,crS,poly1)
			while true do
				while not crossS[nex] do
					assert(not nexT[nex])
					nexT[nex] = true
					poly1[#poly1+1] = poly[nex]
					nex = mod(nex+1,#poly)
				end
				if nex == k then --closed cicle
					table.insert(polyset,poly1)
					assert(crossS[nex].visited)
					break
				else
					crossS[nex].visited = true
					nex = use_cross(nex,crossS[nex],poly1)
				end
			end
		end
	end
	return polyset
end

--receives poly and 1 cross and returns 2 polys in a polyset
--and a map from old indices to new indices
local function  SIC(poly, cr)
	local typ = ffi.typeof(poly[1]) --could be vec3 or vec2
	local pt, a, c = typ(cr[1]), cr[3], cr[5]
	local b, d = mod(a + 1, #poly), mod(c + 1, #poly)
	local P1, P2 = {poly[a], pt}, {poly[c], pt}

	local Map = {}; Map[a] = {P1, 1}; Map[c] = {P2, 1}
	local i, n = d, 3
	if P1[1] == P1[2] then print("out1 pt",P1[2]);P1[2] = nil; n = 2; end
	while(i ~= a) do
		table.insert(P1, poly[i])
		Map[i] = {P1, n}
		i = mod(i+1,#poly)
		n = n + 1
	end
	
	local i, n = b, 3
	if P2[1] == P2[2] then print("out2 pt",P2[2]);P2[2] = nil; n = 2 end
	while(i ~= c) do
		table.insert(P2, poly[i])
		Map[i] = {P2, n}
		i = mod(i+1,#poly)
		n = n + 1
	end
	return {P1, P2}, Map
end
-- repair_self_crossings
--fails on double crossings depending on first point
local function RC(poly,cross)

	if #cross == 0 then return {poly} end
	local typ = ffi.typeof(poly[1]) --could be vec3 or vec2
	--use first cross
	local Bi, Map = SIC(poly, cross[1])
	--map all other crosses
	local cross1, cross2 = {}, {}
	for i=2, #cross do
		local cr = cross[i]
		cr[2], cr[3] = unpack(Map[cr[3]])
		cr[4], cr[5] = unpack(Map[cr[5]])
		assert(cr[2] == cr[4])
		if cr[2] == Bi[1] then 
			table.insert(cross1, cr)
		else
			assert(cr[2] == Bi[2])
			table.insert(cross2, cr)
		end
	end
	local res1 = RC(Bi[1], cross1)
	local res2 = RC(Bi[2], cross2)
	for i,v in ipairs(res2) do
		table.insert(res1, v)
	end
	return res1
end
M.repair_self_crossings = RC

local function check_self_crossings(poly,crossings)
	crossings = crossings or {}
	for i=1,#poly do
		local ai,bi = i,mod(i+1,#poly)
		local a,b = poly[ai],poly[bi]
		local lim = math.min(i + #poly - 2,#poly)
		for j=i+2,lim do
		-- local lim = math.min(i + #poly - 1,#poly)
		-- for j=i+1,lim do
			local ci,di = j,mod(j+1,#poly)
			local c,d = poly[ci],poly[di]
			if CG.SegmentIntersectC(a,b,c,d) 
			--CG.SegmentIntersect(a,b,c,d)
			then
				local pt,good,t = CG.IntersecPoint2(a,b,c,d)
				if good then 
					table.insert(crossings,{pt,poly,ai,poly,ci})
				else
					if a == c then
						table.insert(crossings,{a,poly,ai,poly,ci})
					else
						table.insert(crossings,{a,poly,ai,poly,ci})
						--table.insert(crossings,{c,poly,ai,poly,ci})
					end
					--print("bad crossing",pt,ai,bi,ci,di)
					--print(a,b,c,d)
				end
			end
		end
	end
	return crossings
end
----------------------------------
--receives poly and 1 cross and returns 2 polys in a polyset
local function  split_on_cross(poly, cr)
	local printD = function() end
	local typ = ffi.typeof(poly[1]) --could be vec3 or vec2
	local pt, a, c = typ(cr[1]), cr[3], cr[5]
	local b, d = mod(a + 1, #poly), mod(c + 1, #poly)
	local P1, P2 = {poly[a], pt}, {poly[c], pt}
	--print("split_on_cross------------",#poly, a,b,c,d,pt)
	--print("split_on_cross------------",#poly, poly[a], poly[b], poly[c], poly[d])
	--if #poly == 417 then prtable(poly) end
	

	local i = d
	if P1[1] == P1[2] then printD("split on cross out1 pt",P1[2]);table.remove(P1) end--P1[2] = nil; end
	while(i ~= a) do
		table.insert(P1, poly[i])
		i = mod(i+1,#poly)
	end
	if #P1> 2 and P1[2] == P1[3] then printD("split on cross out1 d==pt",P1[2]);table.remove(P1,2); end

	local i = b
	if P2[1] == P2[2] then printD("split on cross out2 pt",P2[2]);table.remove(P2) end --P2[2] = nil; end
	while(i ~= c) do
		table.insert(P2, poly[i])
		i = mod(i+1,#poly)
	end
	if #P2>2 and P2[2] == P2[3] then printD("split on cross out2 b=pt",P2[2]);table.remove(P2,2) ; end
	--print("returns",#P1,#P2)
	return {P1, P2}
end
--in poly with crossings
--out polyset
local function check_repair_self_crossings(poly)
	--print("check_repair_self_crossings",#poly)
	-- local remr,remc = CG.degenerate_poly_repair(poly,false)
	-- print("degenerate repairs in check_repair_self_crossings",remr,remc)
	local crossings = {}
	for i=1,#poly do
		local ai,bi = i,mod(i+1,#poly)
		local a,b = poly[ai],poly[bi]
		local lim = math.min(i + #poly - 2,#poly)
		for j=i+2,lim do
			local ci,di = j,mod(j+1,#poly)
			local c,d = poly[ci],poly[di]
			local ok,err = pcall(CG.SegmentIntersectC,a,b,c,d)
			if not ok then prtable(ai,bi,ci,di,poly) end
			if CG.SegmentIntersectC(a,b,c,d) then
				local pt,good,t = CG.IntersecPoint2(a,b,c,d)
				if good then 
					table.insert(crossings,{pt,poly,ai,poly,ci})
				else
					print("bad intersecpoint",a,b,c,d)
					if a == c then
						table.insert(crossings,{a,poly,ai,poly,ci})
					else
						table.insert(crossings,{a,poly,ai,poly,ci})
						--table.insert(crossings,{c,poly,ai,poly,ci})
					end
					--print("bad crossing",pt,ai,bi,ci,di)
					--print(a,b,c,d)
				end
				goto REPAIR
			end
		end
	end
	::REPAIR::
	if #crossings > 0 then
		local BI = split_on_cross(poly,crossings[1])
		local res1, res2 = {}, {}
		if #BI[1] > 2 then res1 = check_repair_self_crossings(BI[1]) end
		if #BI[2] > 2 then res2 = check_repair_self_crossings(BI[2]) end
		for i,v in ipairs(res2) do
			table.insert(res1, v)
		end
		return res1
	end
	return {poly}
end
M.check_repair_self_crossings = check_repair_self_crossings

local function check_crossings(poly,crossings)
	crossings = crossings or {}
	local cross = check_self_crossings(poly)
	if #cross > 0 then print("poly self crossings",#cross) end
	if poly.holes then
	for nh,hole in ipairs(poly.holes) do
		local  cross = check_self_crossings(hole)
		if #cross > 0 then print(nh,"hole self crossings",#cross) end
		local cross = check2poly_crossings(poly,hole)
		if #cross > 0 then print(nh,"poly-hole crossings",#cross) end
		for nh2=nh+1,#poly.holes do
			local cross = check2poly_crossings(hole,poly.holes[nh2])
			if #cross > 0 then print(nh,nh2,"hole-hole crossings",#cross) end
		end
	end
	end
	return crossings
end

local function check_polyset_crossings(polyset,crossings)
	crossings = crossings or {}
	for i=1,#polyset-1 do
		check_crossings(polyset[i],crossings)
		for j=i+1,#polyset do
			check2poly_crossings(polyset[i],polyset[j],crossings)
		end
	end
	check_crossings(polyset[#polyset],crossings)
	return crossings
end

local function CHECKPOLY(poly)
	local has = check_point_repetition(poly)
	if has then print"CHECKPOLY point repetition" end
	local cross = check_crossings(poly)
	if #cross > 0 then print("CHECKPOLY self crossings",#cross) end
	return cross
end

local function check_collinear(poly)

	local colin = {}
	local numpt = #poly
	for i=1,numpt do
		local ang,conv,s,cose = CG.Angle(poly[mod(i-1,numpt)],poly[i],poly[mod(i+1,numpt)])
		if s==0 then  
			-- local ang2,conv2,s2,cose2 = CG.Angle(poly[mod(i+1,numpt)],poly[i],poly[mod(i-1,numpt)])
			-- if s2~=0 then
				-- print("rev colin",s,s2,poly[mod(i-1,numpt)],poly[i],poly[mod(i+1,numpt)])
				-- print(ang,conv,s,cose)
				-- print(ang2,conv2,s2,cose2)
			-- end
			if cose<0 then
				print("collinear1 on",i)
				error"collinear"
			elseif poly[mod(i-1,numpt)]==poly[mod(i+1,numpt)] then --cose>0 and repeated
				print("collinear2 on",i)
				error"collinear"
			end
		end
	end

end
M.CHECKPOLY=CHECKPOLY
M.CHECKCOLIN=check_collinear
M.check_self_crossings=check_self_crossings
M.check2poly_crossings=check2poly_crossings
M.check_polyset_crossings=check_polyset_crossings
return M