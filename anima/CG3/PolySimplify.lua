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
		local ab = (b-a).normalize
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
		local ab = (b-a).normalize
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
		poly = InsertHoles(poly,true)
	end
	assert(#poly.holes== 0)
	
	return PolySimplifyNC1(poly,eps)
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
		local ab = (b-a).normalize
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
function CG.PolySimplifyNC(poly,eps)
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
		while i<#list and v==list[i+1] do table.remove(list,i+1) end
	end
	
	if #poly.holes> 0 then 
		for nh,hole in ipairs(poly.holes) do
			local _,removedS = PolySimplifyNC2(hole,list,eps)
			removed = removed + removedS
		end
	end
	
	local _,removedS = PolySimplifyNC2(poly,list,eps)
	removed = removed + removedS
	
	return removed
end


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
		local ab = (b-a).normalize
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
	local pset = Pset2()
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
