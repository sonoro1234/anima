local CG = require"anima.CG3.base"

--standard Ramer–Douglas–Peucker algorithm
function CG.PolySimplify(poly,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	local toremove = {}
	--find maxx minx
	local minx,maxx = math.huge, -math.huge
	local im,iM
	for i=1,#poly do
		local p = poly[i]
		if minx > p.x then minx = p.x; im = i end
		if maxx < p.x then maxx = p.x; iM = i end
		toremove[i] = false
	end
	
	local function mod(a,b)
		return ((a-1)%b)+1
	end
	
	local function FF(i,j)
		if i==j then return end
		local k = mod(i+1,#poly)
		if j == k then return end
		
		local a,b = poly[i],poly[j]
		local ab = (b-a):normalize()
		local N = vec2(ab.y,-ab.x)
		local maxd,kmax = -math.huge
		
		
		while k~=j do
			--assert(not toremove[k])
			if toremove[k] then
				print("simp error: #poly",#poly,i,j,mod(i+1,#poly),k)
				error"polysimp"
			end
			local dis = math.abs((poly[k]-a)*N)
			if dis > maxd then
				maxd = dis
				kmax = k
			end
			k = mod(k+1,#poly)
		end
		
		if maxd >= eps then
			--recursion
			FF(i,kmax)
			FF(kmax,j)
		else
			local k = mod(i+1,#poly)
			while k~=j do
				toremove[k] = true
				k = mod(k+1,#poly)
			end
			
		end
	end
	
	FF(im,iM)
	FF(iM,im)
	
	local before = #poly
	for ii=#toremove,1,-1 do
		if toremove[ii] then table.remove(poly,ii) end
	end
	--number of removed vertices
	return poly,before - #poly
end





--avoid self crossings
local function PolySimplifyNC1(poly,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	
	
	local toremove = {}
	--find maxx minx
	local minx,maxx = math.huge, -math.huge
	local im,iM
	for i=1,#poly do
		local p = poly[i]
		if minx > p.x then minx = p.x; im = i end
		if maxx < p.x then maxx = p.x; iM = i end
		toremove[i] = false
	end
	
	local function mod(a,b)
		return ((a-1)%b)+1
	end
	
	local function FF(i,j)
		if i==j then return end
		local k = mod(i+1,#poly)
		if j == k then return end
		
		local a,b = poly[i],poly[j]
		local ab = (b-a):normalize()
		local N = vec2(ab.y,-ab.x)
		local maxd,kmax = -math.huge
		
		
		while k~=j do
			--assert(not toremove[k])
			if toremove[k] then
				print("simp error: #poly",#poly,i,j,mod(i+1,#poly),k)
				error"polysimp"
			end
			local dis = math.abs((poly[k]-a)*N)
			if dis > maxd then
				maxd = dis
				kmax = k
			end
			k = mod(k+1,#poly)
		end
		
		if maxd >= eps then
			--recursion
			FF(i,kmax)
			FF(kmax,j)
		else
			---[[
			--check crossings
			local a,b,c = poly[i],poly[kmax],poly[j]
			--could be faster with sorted list
			local empty = true
			local j1 = mod(j+1,#poly)
			local jlimit = i
			while j1~=jlimit do
				if CG.IsPointInTriC(poly[j1],a,b,c) then
					empty = false
					break
				end
				j1 = mod(j1+1,#poly)
			end
			--]]
			--[[
			--check crossings
			local a,b,c = poly[i],poly[kmax],poly[j]
			--could be faster with sorted list
			local empty = true
			local j1 = j
			local jlimit = mod(i-1,#poly)
			while j1~=jlimit do
				--if CG.IsPointInTriC(poly[j1],a,b,c) then
				if CG.SegmentIntersect(a,c,poly[j1],poly[mod(j1+1,#poly)]) then
					empty = false
					break
				end
				j1 = mod(j1+1,#poly)
			end
			--]]
			if not empty then
				--recursion
				FF(i,kmax)
				FF(kmax,j)
			else
				local k = mod(i+1,#poly)
				while k~=j do
					toremove[k] = true
					k = mod(k+1,#poly)
				end
			end
		end
	end
	
	FF(im,iM)
	FF(iM,im)
	
	local before = #poly
	for ii=#toremove,1,-1 do
		if toremove[ii] then table.remove(poly,ii) end
	end
	--number of removed vertices
	return poly,before - #poly
end

--insert before simplify
--which perhaps creates overcomplicated bridges
function CG.PolySimplifyNC3(poly,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	
	
	if #poly.holes> 0 then 
		poly = CG.InsertHoles(poly,true)
	end
	assert(#poly.holes== 0)
	
	local _,removedS = PolySimplifyNC1(poly,eps)
	return removedS
end



--avoid crossings with list lexicografic sorted
local function PolySimplifyNC2(poly,list,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	
	
	local toremove = {}
	--find maxx minx
	local minx,maxx = math.huge, -math.huge
	local im,iM
	for i=1,#poly do
		local p = poly[i]
		if minx > p.x then minx = p.x; im = i end
		if maxx < p.x then maxx = p.x; iM = i end
		toremove[i] = false
	end
	
	local function mod(a,b)
		return ((a-1)%b)+1
	end
	
	local function FF(i,j)
		if i==j then return end
		local k = mod(i+1,#poly)
		if j == k then return end
		
		local a,b = poly[i],poly[j]
		local ab = (b-a):normalize()
		local N = vec2(ab.y,-ab.x)
		local maxd,kmax = -math.huge
		
		
		while k~=j do
			--assert(not toremove[k])
			if toremove[k] then
				print("simp error: #poly",#poly,i,j,mod(i+1,#poly),k)
				error"polysimp"
			end
			local dis = math.abs((poly[k]-a)*N)
			if dis > maxd then
				maxd = dis
				kmax = k
			end
			k = mod(k+1,#poly)
		end
		
		if maxd >= eps then
			--recursion
			FF(i,kmax)
			FF(kmax,j)
		else
			--check crossings
			local a,b,c = poly[i],poly[kmax],poly[j]
			--[[
			--prepare pset2
			local pset2 = CG.Pset2()	
			local j1 = mod(i,#poly)
			local jlimit = mod(j+1,#poly)
			while j1~=jlimit do
				pset2:add(poly[j1])
				j1 = mod(j1+1,#poly)
			end
			--]]
			local empty = true
			--then with list

			for jl=1,#list do
				local pt = list[jl]
				---[[
				local docheck = true
				--dont check if between a and c
				local j1 = mod(i,#poly)
				local jlimit = mod(j+1,#poly)
				while j1~=jlimit do
					if pt==poly[j1] then
						docheck = false
						break
					end
					j1 = mod(j1+1,#poly)
				end

				if docheck then
				--]]
				--if not pset2:has(pt) then
					if CG.IsPointInTriC(pt,a,b,c) then
						empty = false
						break
					end
				end
			end

			if not empty then
				--recursion
				FF(i,kmax)
				FF(kmax,j)
			else
				local k = mod(i+1,#poly)
				while k~=j do
					--delete from list
					-- for li,pt in ipairs(list) do
						-- if pt == poly[k] then 
							-- table.remove(list,li);
							-- break 
						-- end
					-- end
					--local li = binary_search(list,poly[k],CG.lexicografic_compare)
					local li = CG.lexicografic_find(list, poly[k])
					if li then table.remove(list,li) end
					toremove[k] = true
					k = mod(k+1,#poly)
				end
			end
		end
	end
	
	FF(im,iM)
	FF(iM,im)
	
	local before = #poly
	for ii=#toremove,1,-1 do
		if toremove[ii] then table.remove(poly,ii) end
	end
	--number of removed vertices
	return poly,before - #poly
end

--use list of all points and simplifies poly and holes with it
--not only slow but also PolySimplifyNC1 point in tri test is not enough to avoid crossings
function CG.PolySimplifyNCList(poly,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	
	local removed = 0
	local list = {}
	for i,pt in ipairs(poly) do
		list[#list+1] = pt
	end
	if #poly.holes> 0 then 
		--make list
		for nh,hole in ipairs(poly.holes) do
			for i,pt in ipairs(hole) do
				list[#list+1] = pt
			end
		end
	end
	
	CG.lexicografic_sort(list)
	--delete repeated
	for i,v in ipairs(list) do
		while i<#list and v==list[i+1] do table.remove(list,i+1);print("remo",i+1) end
	end
	
	if #poly.holes> 0 then 
		for nh,hole in ipairs(poly.holes) do
			-- local _,removedS = PolySimplifyNC2(hole,list,eps)
			local _,removedS = PolySimplifyNC1(hole,eps)
			removed = removed + removedS
		end
	end
	
	-- local _,removedS = PolySimplifyNC2(poly,list,eps)
	local _,removedS = PolySimplifyNC1(poly,eps)
	removed = removed + removedS
	
	return removed
end

--------------------------------------begin PolySimplifyNC-------------------
--checks segment intersec (point in tri is not enough)
local function mod(a,b)
	return ((a-1)%b)+1
end
local function check_other_cross(a,b,other)
	for i=1,#other-1 do
		if CG.SegmentIntersect(a,b,other[i],other[i+1]) then
			return true
		end
	end
	if CG.SegmentIntersect(a,b,other[#other],other[1]) then
		return true
	end
	return false
end
local function check_self_cross(poly,i,j)
	local a,b = poly[i],poly[j]
	local j1 = j
	local jlimit = mod(i-1,#poly)
	while j1~=jlimit do
		if CG.SegmentIntersect(a,b,poly[j1],poly[mod(j1+1,#poly)]) then
			return true
		end
		j1 = mod(j1+1,#poly)
	end
	return false
end
local function check_simp_cross(poly,i,j,mainpoly)
	local a, b = poly[i],poly[j]
	if mainpoly==poly then
		if check_self_cross(poly,i,j) then
			return true
		end
		for ih,h in ipairs(mainpoly.holes) do
			if check_other_cross(a,b,h) then
				return true
			end
		end
	else --is hole
		if check_other_cross(a,b,mainpoly) then
			return true
		end
		for ih,h in ipairs(mainpoly.holes) do
			if h==poly then
				if check_self_cross(poly,i,j) then
					return true
				end
			else
				if check_other_cross(a,b,h) then
					return true
				end
			end
		end
	end
	return false
end
local function PolySimplifyNCh1(poly,mainpoly,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	
	
	local toremove = {}
	--find maxx minx
	local minx,maxx = math.huge, -math.huge
	local im,iM
	for i=1,#poly do
		local p = poly[i]
		if minx > p.x then minx = p.x; im = i end
		if maxx < p.x then maxx = p.x; iM = i end
		toremove[i] = false
	end
	
	local function mod(a,b)
		return ((a-1)%b)+1
	end
	
	local function FF(i,j)
		if i==j then return end
		local k = mod(i+1,#poly)
		if j == k then return end
		
		local a,b = poly[i],poly[j]
		local ab = (b-a):normalize()
		local N = vec2(ab.y,-ab.x)
		local maxd,kmax = -math.huge
		
		
		while k~=j do
			--assert(not toremove[k])
			if toremove[k] then
				print("simp error: #poly",#poly,i,j,mod(i+1,#poly),k)
				error"polysimp"
			end
			local dis = math.abs((poly[k]-a)*N)
			if dis > maxd then
				maxd = dis
				kmax = k
			end
			k = mod(k+1,#poly)
		end
		
		if maxd >= eps then
			--recursion
			FF(i,kmax)
			FF(kmax,j)
		else
			local empty = not check_simp_cross(poly,i,j,mainpoly)
			if not empty then
				--recursion
				FF(i,kmax)
				FF(kmax,j)
			else
				local k = mod(i+1,#poly)
				while k~=j do
					toremove[k] = true
					k = mod(k+1,#poly)
				end
			end
		end
	end
	
	FF(im,iM)
	FF(iM,im)
	
	local before = #poly
	for ii=#toremove,1,-1 do
		if toremove[ii] then table.remove(poly,ii) end
	end
	--number of removed vertices
	return poly,before - #poly
end

function CG.PolySimplifyNC(poly,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	
	local removed = 0
	
	if #poly.holes> 0 then 
		for nh,hole in ipairs(poly.holes) do
			-- local _,removedS = PolySimplifyNC2(hole,list,eps)
			local _,removedS = PolySimplifyNCh1(hole,poly,eps)
			removed = removed + removedS
		end
	end
	
	-- local _,removedS = PolySimplifyNC2(poly,list,eps)
	local _,removedS = PolySimplifyNCh1(poly,poly,eps)
	removed = removed + removedS
	
	return removed
end
---------------------------------end PolySimplifyNC----------------------

--avoid crossings with Pset of points
local function PolySimplifyNC3(poly,pset,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	
	
	local toremove = {}
	--find maxx minx
	local minx,maxx = math.huge, -math.huge
	local im,iM
	for i=1,#poly do
		local p = poly[i]
		if minx > p.x then minx = p.x; im = i end
		if maxx < p.x then maxx = p.x; iM = i end
		toremove[i] = false
	end
	
	local function mod(a,b)
		return ((a-1)%b)+1
	end
	
	local function FF(i,j)
		if i==j then return end
		local k = mod(i+1,#poly)
		if j == k then return end
		
		local a,b = poly[i],poly[j]
		local ab = (b-a):normalize()
		local N = vec2(ab.y,-ab.x)
		local maxd,kmax = -math.huge
		

		while k~=j do
			--assert(not toremove[k])
			if toremove[k] then
				print("simp error: #poly",#poly,i,j,mod(i+1,#poly),k)
				error"polysimp"
			end
			
			local dis = math.abs((poly[k]-a)*N)
			if dis > maxd then
				maxd = dis
				kmax = k
			end
			k = mod(k+1,#poly)
		end
		
		if maxd >= eps then
			--recursion
			FF(i,kmax)
			FF(kmax,j)
		else
			--check crossings
			local a,b,c = poly[i],poly[kmax],poly[j]
			--[[
			--prepare pset2
			local pset2 = CG.Pset2()	
			local j1 = mod(i,#poly)
			local jlimit = mod(j+1,#poly)
			while j1~=jlimit do
				pset2:add(poly[j1])
				j1 = mod(j1+1,#poly)
			end
			--]]
			
			local empty = true
			for pt in pset:allpoints() do
				---[[
				local docheck = true
				--dont check if between a and c
				local j1 = mod(i,#poly)
				local jlimit = mod(j+1,#poly)
				while j1~=jlimit do
					if pt==poly[j1] then
						docheck = false
						break
					end
					j1 = mod(j1+1,#poly)
				end

				if docheck then
				--]]
				--if not pset2:has(pt) then
					if CG.IsPointInTriC(pt,a,b,c) then
						empty = false
						break
					end
				end
			end

			if not empty then
				--recursion
				FF(i,kmax)
				FF(kmax,j)
			else
				local k = mod(i+1,#poly)
				while k~=j do
					pset:remove(poly[k])
					toremove[k] = true
					k = mod(k+1,#poly)
				end
			end
		end
	end
	
	FF(im,iM)
	FF(iM,im)
	
	local before = #poly
	for ii=#toremove,1,-1 do
		if toremove[ii] then table.remove(poly,ii) end
	end
	--number of removed vertices
	return poly,before - #poly
end

--uses a Pset and simplifies poly and holes with it
function CG.PolySimplifyNC2(poly,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	
	local removed = 0
	local pset = CG.Pset2()
	for i,pt in ipairs(poly) do
		pset:add(pt)
	end
	if #poly.holes> 0 then 
		--make list
		for nh,hole in ipairs(poly.holes) do
			for i,pt in ipairs(hole) do
				pset:add(pt)
			end
		end
	end
	
	if #poly.holes> 0 then 
		for nh,hole in ipairs(poly.holes) do
			local _,removedS = PolySimplifyNC3(hole,pset,eps)
			removed = removed + removedS
		end
	end
	
	local _,removedS = PolySimplifyNC3(poly,pset,eps)
	removed = removed + removedS
	
	return poly,removed
end

-------polygon padding
local function mod(a,b)
	return ((a-1)%b)+1
end
--return a polygon with positive outward offset dis
--square bool if square instead of round terminations
--minlen defaults 10 for viewport coordinates
function CG.PolygonPad(pol,dis,square,minlen)
	
	if dis <= 0 then return pol end
	if square==nil then square=false end
	minlen = minlen or 10
	
	local floor,atan2,cos,sin = math.floor, math.atan2, math.cos, math.sin
	local insert, remove = table.insert, table.remove
	local pix2 = math.pi*2
	local vec2 = mat.vec2
	
	--first displace edges outwards
	local pol2 = {}
	local signs = {}
	for i=1,#pol do
		signs[i] = CG.Sign(pol[mod(i-1,#pol)],pol[i],pol[mod(i+1,#pol)])
		local edge = (pol[mod(i+1,#pol)]-pol[i]):normalize()
		local nor = vec2(edge.y,-edge.x) 
		pol2[#pol2+1] = dis*nor+pol[i]
		pol2[#pol2+1] = dis*nor+pol[mod(i+1,#pol)]
	end
	
	local pol3 = pol2
	--make round on convex vertices
	if not square then
		pol3 = {}
		for i=1,#pol do
			local a,b = mod(2*i-2,#pol2),2*i-1
			if signs[i] > 0 then 
				local center = pol[i]
				local p1,p2 = pol2[a],pol2[b]
				local dir1 = (p1 - center):normalize()
				local dir2 = (p2 - center):normalize()
				local iniang = atan2(dir1.y, dir1.x)
				local endang = atan2(dir2.y, dir2.x)
				--print("convex",i,iniang, endang, dir1, dir2)
				local chgang = endang - iniang
				chgang = chgang < 0 and pix2+chgang or chgang
				local leng = dis*(chgang)
				--leng = math.abs(leng)
				--assert(leng>0)
				--trozos
				local trozos = floor(leng/minlen)
				local incang = chgang/trozos
				
				pol3[#pol3+1] = p1
				for t = 1, trozos-1 do
					local om = iniang + incang*t
					pol3[#pol3+1] = center + dis*vec2(cos(om),sin(om))
				end
				pol3[#pol3+1] = p2
			else
				pol3[#pol3+1] = pol2[a]
				pol3[#pol3+1] = pol2[b]
			end
		end
	end
	--self intersection repair
	--start from minimum x and y vertex
	local minx = math.huge
	local mini
	for i=1,#pol3 do
		if pol3[i].x <= minx then
			if pol3[i].x == minx then
				if pol3[i].y < miny then
					miny = pol3[i].y
					mini = i
				end
			else
				miny = pol3[i].y
				minx = pol3[i].x
				mini = i
			end
		end
	end
	for i=1,mini-1 do
		insert(pol3,remove(pol3,1))
	end
	--now repair
	local poly = pol3
	local i = 1
	while i < #poly do
		--print("repair",i,#poly)
		local ai,bi = i,mod(i+1,#poly)
		local a,b = poly[ai],poly[bi]
		local found = false
		for j=i+2,#poly do
			local ci,di = j,mod(j+1,#poly)
			local c,d = poly[ci],poly[di]
			if CG.SegmentIntersect(a,b,c,d) then
				--print("intersec",ai,bi,ci,di)
				local pc = CG.IntersecPoint2(a,b,c,d)
				--delete from bi to ci
				for k=ci,bi,-1 do 
					remove(poly,k) 
				end
				insert(poly,ai+1,pc)
				found = true
				break
			end
		end
		if not found then
			i = i + 1
		end
	end
	return pol3
end
