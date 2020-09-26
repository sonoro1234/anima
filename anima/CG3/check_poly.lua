
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
				print("repeated point",i,j)
				error"2poly repetition"
			end
		end
	end
end

local function check_point_repetition(poly)
	local has_repeat = false
	check_self_consec_repetition(poly)
	if poly.holes then
	for nh,hole in ipairs(poly.holes) do
		check2poly_repetition(poly,hole)
		for nh2=nh+1,#poly.holes do
			check2poly_repetition(hole,poly.holes[nh2])
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

function M.repair_self_crossings(poly,cross)

	if #cross == 0 then return {poly} end
	local typ = ffi.typeof(poly[1]) --could be vec3 or vec2
	local polyset = {}
	local crossS = {}
	local nexT = {}
	for j,cr in ipairs(cross) do
		crossS[cr[3]] = {typ(cr[1]),cr[3],cr[5]}
		crossS[cr[5]] = {typ(cr[1]),cr[3],cr[5]}
	end
	
	local function use_cross(k,crS,poly1)
		local nex
		if k == crS[2] then 
			if poly[crS[2]]==crS[1] then --crossing in a segment begin
				poly1[#poly1+1] = poly[crS[2]]
			else
				poly1[#poly1+1] = poly[crS[2]]
				poly1[#poly1+1] = crS[1]
			end
			nex = mod(crS[3]+1,#poly)
		else
			assert(k==crS[3])
			if poly[crS[3]]==crS[1] then
				poly1[#poly1+1] = poly[crS[3]]
			else
				poly1[#poly1+1] = poly[crS[3]]
				poly1[#poly1+1] = crS[1]
			end
			nex = mod(crS[2]+1,#poly)
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


local function check_self_crossings(poly,crossings)
	crossings = crossings or {}
	for i=1,#poly do
		local ai,bi = i,mod(i+1,#poly)
		local a,b = poly[ai],poly[bi]
		local lim = math.min(i + #poly - 2,#poly)
		for j=i+2,lim do
			local ci,di = j,mod(j+1,#poly)
			local c,d = poly[ci],poly[di]
			if CG.SegmentIntersectC(a,b,c,d) --,d==a)
			--CG.SegmentIntersect(a,b,c,d)
			then
				local pt = CG.IntersecPoint(a,b,c,d)
				table.insert(crossings,{pt,poly,ai,poly,ci})
			end
		end
	end
	return crossings
end

local function check_crossings(poly,crossings)
	crossings = crossings or {}
	check_self_crossings(poly,crossings)
	if poly.holes then
	for nh,hole in ipairs(poly.holes) do
		check_self_crossings(hole,crossings)
		check2poly_crossings(poly,hole,crossings)
		for nh2=nh+1,#poly.holes do
			check2poly_crossings(hole,poly.holes[nh2],crossings)
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
	if has then print"point repetition" end
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
			if cose<0 then
				print("collinear on",i)
				error"collinear"
			elseif poly[mod(i-1,numpt)]==poly[mod(i+1,numpt)] then --cose>0 and repeated
				print("collinear on",i)
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