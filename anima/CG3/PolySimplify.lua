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
function CG.PolySimplify_holes(poly,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	
	local removed = 0
	
	--print("poly before",CG.signed_area(poly),#poly)
	local _,removedS = CG.PolySimplify(poly,eps)
	removed = removed + removedS
	--print("poly after",CG.signed_area(poly),#poly)
	
	local remove_holes = {}
	if #poly.holes> 0 then 
		for nh,hole in ipairs(poly.holes) do
			
			--local sarea = CG.signed_area(hole)
			--print(nh,"before",sarea,#hole)
			local _,removedS = CG.PolySimplify(hole,eps)
			removed = removed + removedS
			if #hole<3 then table.insert(remove_holes,nh) end
			--print(nh,"after",CG.signed_area(hole),#hole)
		end
	end
	
	for i=#remove_holes,1,-1 do table.remove(poly.holes,remove_holes[i]) end
	
	if #poly<3 then return removed, true end
	
	return removed
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
			--local _,removedS = CG.PolySimplify(hole,eps)
			removed = removed + removedS
		end
	end
	
	-- local _,removedS = PolySimplifyNC2(poly,list,eps)
	local _,removedS = PolySimplifyNCh1(poly,poly,eps)
	--local _,removedS = CG.PolySimplify(poly,eps)
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
-----------------------------------------------------------------------------------------------------
-------polygon padding
local function mod(a,b)
	return ((a-1)%b)+1
end
-- crosss repair: uses check_self_crossings_rep
local function cross_repair1(pol3,str,npol)
	local CHK = require"anima.CG3.check_poly"

	local cross,badcross = CHK.check_self_crossings_rep(pol3)
	
	if #cross>0 then
		print("========cross ",str,#pol3)
		if #badcross>0 then prtable("badcross",badcross) end
		--prtable("cross",cross)
		for i,cr in ipairs(cross) do
			local pt,a,c,lenn,ini,end_ = unpack(cr)
			print(pt,a+npol,c+npol,"  len:",lenn,"ini end",ini+npol,end_+npol)
			--print(pt,a,c,"  len:",lenn,"ini end",ini,end_)
		end
		--recheck
		local cro = CHK.check_self_crossings_rep(pol3,true)
		if #cro>0 then
			print"------------cross again---------"
			for i,cr in ipairs(cro) do
				local pt,a,c,lenn,ini,end_ = unpack(cr)
				print(pt,a+npol,c+npol,"  len:",lenn,"ini end",ini+npol,end_+npol)
				--print(pt,a,c,"  len:",lenn,"ini end",ini,end_)
				for j=ini,end_ do 
					--local j1 = mod(j,#pol3)
					print(j,pol3[j]) 
				end
			end
			--prtable(pol3)
			print"------------cross again end---------"
		end

	end
end

-- crosss repair: uses check_repair_self_crossings_rep
local function cross_repair2(pol3,str,npol,facCW)
	local CHK = require"anima.CG3.check_poly"

	local polys = CHK.check_repair_self_crossings_rep(pol3)
	
	if #polys>1 then
		print("cross_repair2 polys returned", #polys,str)
		local CW 
		local maxi,maxval = -math.huge, -math.huge
		for i=1,#polys do 
			local CW = facCW*CG.signed_area(polys[i])
			print(i,CW)
			if CW > maxval then
				maxval = CW
				maxi = i
			end
		end
		print("maxi",maxi)
		local poly = polys[maxi]
		assert(#poly==#pol3)
		for i=1,#pol3 do pol3[i] = poly[i] end
		return polys
	else
		-- no reparations
		return polys
	end
end
local function cross_repair3(pol3,str,npol,facCW)
	local SR = require"anima.CG3.subramaniam"

	local poly = SR.repair_crossings_split(pol3,facCW)
	for i=1,#pol3 do pol3[i] = poly[i] end
end


local cross_repair = cross_repair3
--return a polygon with positive outward offset dis
--square bool if square instead of round terminations
--minlen defaults 10 for viewport coordinates
-- do_trian to return triangulation
function CG.PolygonPad(pol,dis,square,minlen, do_triang,dontrepair)
	print("\n===== CG.PolygonPad ",dis,"====================================")
	if dis== 0 then return pol end
	local CW = CG.signed_area(pol)
	local facCW = (CW > 0) and 1 or -1
	--print("PolygonPad CW",CW,facCW)
	local CHK = require"anima.CG3.check_poly"
	--if dis <= 0 then return pol end
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
		local nor = facCW*vec2(edge.y,-edge.x) 
		pol2[#pol2+1] = dis*nor+pol[i] --a
		pol2[#pol2+1] = dis*nor+pol[mod(i+1,#pol)] --b
	end
	
	local function getpol2fori(i) return mod(2*i-2,#pol2),2*i-1 end
	---[[ -- crossing on concave //may be done after so remove?
	for i=1,#pol do
		if facCW * signs[i] <= 0 then
			local iprev,ipost = i-1,i+1
			if i==1 then iprev=#pol elseif i==#pol then ipost=1 end
			local a,b = getpol2fori(i)
			local _,bprev = getpol2fori(iprev)
			local apost,_ = getpol2fori(ipost)
			local pt, not_paralel = CG.IntersecPoint2(pol2[bprev], pol2[a], pol2[b], pol2[apost])
			pol2[a] = not_paralel and pt or pol2[a]
			pol2[b] = not_paralel and pt or pol2[b]
		end
	end
	--]]
	local pol2copy = {}
	for i=1,#pol2 do pol2copy[i] = pol2[i] end
	local polyscross2 = cross_repair(pol2,"pol2",#pol,facCW)--,dontrepair)
	-- if square
	local pol3 = pol2
	local pieces = {} -- to keep 
	--make round on convex vertices

	if not square then
		pol3 = {}
		for i=1,#pol do
			local a,b = mod(2*i-2,#pol2),2*i-1
			--local a,b = 2*(i-1)+1,mod(2*(i-1)+2,#pol2)
			if facCW * signs[i] > 0 then 
				local center = pol[i]
				local p1,p2 = pol2[a],pol2[b]
				local dir1 = (p1 - center):normalize()
				local dir2 = (p2 - center):normalize()
				local iniang = atan2(dir1.y, dir1.x)
				local endang = atan2(dir2.y, dir2.x)

				local chgang = (endang - iniang)
				if facCW > 0 then
					chgang = chgang < 0 and pix2+chgang or chgang
				else
					chgang = chgang > 0 and -pix2+chgang or chgang
				end
				local leng = dis*(chgang)*facCW

				local trozos = floor(leng/minlen)
				local incang = chgang/trozos
				
				pol3[#pol3+1] = p1
				for t = 1, trozos-1 do
					local om = iniang + incang*t
					pol3[#pol3+1] = center + dis*vec2(cos(om),sin(om))
					--print("--adding point",#pol3,pol3[#pol3])
				end
				pol3[#pol3+1] = p2
				pieces[i] = trozos>0 and trozos-1 or trozos
			else
				pol3[#pol3+1] = pol2[a]
				pol3[#pol3+1] = pol2[b]
			end
		end
	end
	--[[
	-- rotate to make 1b the first
	local a = remove(pol3,1)
	insert(pol3,a)
	for i=1,pieces[1] do
		local a = remove(pol3,1)
		insert(pol3,a)
	end
	--]]
	cross_repair(pol3,"pol3",#pol,facCW)--,dontrepair) --dont repair
	--cross_repair(pol3,"pol3B",#pol)--dontrepair)
	-- if #cross>0 or #badcross>0 then
		-- print("====not reapired",#cross,#badcross)
	-- end
	local cross = CHK.check2poly_crossings_rep(pol3,pol)
	if #cross>0 then
		print"========2polycross============"
		prtable("cross",cross)
	end
	--------------------------
	if not do_triang then
		return pol3
	else
		local npol = #pol
		local points, tr = {},{}
		local acum_trozos = {}
		for i=1,npol do
			acum_trozos[i] = (acum_trozos[i-1] or 0) + (pieces[i] or 0)
		end
		--if not square then print("-- acumtrozos --",acum_trozos[npol]) end
		
		-- index on pol2
		local npol2 = #pol2
		-- index on pol3
		local npol3 = #pol3
		-- print("====npol2",npol2,npol3)
		-- prtable(pieces,acum_trozos)
		-- prtable("pol2",pol2,pol3)
		local ab
		if square then
			ab = function(i) return mod(2*i-2,npol2),2*i-1 end
		else
			ab = function(i)
				--pol3 position
				local a,b = (i-1)*2+1,(i-1)*2+2
				assert(a<=npol3)
				assert(b<=npol3)
				a,b = a+(acum_trozos[i-1] or 0),b+acum_trozos[i] 
				assert(a<=npol3)
				assert(b<=npol3)
				return a,b
				end
		end
		-- index on points
		local function ab_p(i) local a,b = ab(i); return a+npol,b+npol end
		for i=1,#pol do points[i] = pol[i] end
		for i=1,npol3 do points[#points+1] = pol3[i] end
		
		-- for pol to pad with cross to pol
		local function check_edge(a,b)
			if a>b then a,b = b,a end
			if a<=#pol and b>#pol then
			--if b>#pol then
				return CHK.check_poly_edge_cross(pol,points[a],points[b])
			end
			return false
		end
		local function T(a,b,c,edg)
			if edg then return end
			local area = CG.TArea(points[a],points[b],points[c])*facCW
			if area > 0 then
				print("        T",a,b,c,area)
				insert(tr,a);insert(tr,b);insert(tr,c)
			end
		end
		local function TesselPos(i,a,b,c,ab,bc,ca)
			T(a,i,c,ca)
			T(a,b,i,ab)
			T(b,c,i,bc)
		end
		local function insert_check(a,b,c)
			if dontrepair then
				insert(tr,a);insert(tr,b);insert(tr,c)
			else
				--if not(CHK.check_poly_edge_cross(pol,points[a],points[b]) or CHK.check_poly_edge_cross(pol,points[c],points[a])) then
				--if CG.TArea(points[a],points[b],points[c])*facCW > 0 then
				local ab = check_edge(a,b)
				local bc = check_edge(b,c)
				local ca = check_edge(c,a)
				if not(ab or bc or ca) then
					insert(tr,a);insert(tr,b);insert(tr,c)
				else
					local area = CG.TArea(points[a],points[b],points[c])*facCW
					print("insert check false",a,b,c,"edg",ab,bc,ca,"area",area)
					if false and area >0 then
						--count in pol points
						local in_ = a<=npol and 1 or 0
						in_ = in_ + (b<=npol and 1 or 0)
						in_ = in_ + (c<=npol and 1 or 0)
						print("    points in",in_)
						assert(in_==2)
						--facCW * signs[i] <= 0
						local edges = {a,b,c}
						table.sort(edges)
						
						for i=1,math.ceil((npol-2)/2) do
						 local a1 = mod(edges[1]-i,npol)
						 local a2 = mod(edges[2]+i,npol)
							if CG.IsPointInTri(pol[a1],points[a],points[b],points[c]) then
								print("    inside is",a1)
								return TesselPos(a1,a,b,c,ab,bc,ca)
							elseif CG.IsPointInTri(pol[a2],points[a],points[b],points[c]) then
								print("    inside is",a2)
								return TesselPos(a2,a,b,c,ab,bc,ca)
							end
							end
					--[[
						for i=1,#pol do
							if CG.IsPointInTri(pol[i],points[a],points[b],points[c]) then
							print("    inside is",i)
							return TesselPos(i,a,b,c,ab,bc,ca)
							end
						end
						--]]
						--not point inside
						print("    not inside")
						local a1 = mod(edges[1]-1,npol)
						 local a2 = mod(edges[2]+1,npol)
						 if not CG.IsPointInTri(points[a2],points[a1],points[edges[1]],points[edges[2]]) then
							insert(tr,a1);insert(tr,edges[1]);insert(tr,edges[2])
							print("        ",a1,edges[1],edges[2])
							return
						 elseif not CG.IsPointInTri(points[a1],points[edges[1]],points[edges[2]],points[a2]) then
							insert(tr,edges[1]);insert(tr,edges[2]);insert(tr,a2)
							print("        ",edges[1],edges[2],a2)
							return
						else
							print"FAILED-----------------------------"
						end
						 
					--]]
					end
				end
			end
		end
		
		local function insert_checkNN(a,b,c)
			insert(tr,a);insert(tr,b);insert(tr,c)
		end
		
		for i=1,#pol do
			local a,b = ab_p(i)
			-- i,a,b
			---print("ab",a,b,pieces[i])
			if pieces[i]==nil or pieces[i]==0 then
				--insert(tr,i);insert(tr,a);insert(tr,b)
				insert_check(i,a,b)
			else
				assert(b-a-1==pieces[i])
				for j=1,pieces[i] do
					--insert(tr,i);insert(tr,a+j-1);insert(tr,a+j)
					insert_check(i, a+j-1, a+j)
				end
				--insert(tr,i);insert(tr,b-1);insert(tr,b)
				insert_check(i, b-1, b)
			end
			-- i,b,i+1
			--insert(tr,i);insert(tr,b);insert(tr,mod(i+1,npol))
			insert_check(i, b, mod(i+1,npol))
			-- i,bprev,a
			local _,bprev = ab_p(mod(i-1,npol))
			--insert(tr,i);insert(tr,bprev);insert(tr,a)
			insert_check(i, bprev, a)
		end
		
		for i=1,#tr do tr[i] = tr[i]-1 end
		return points, tr,pol2copy,polyscross2
	end
end

--return a polygon with positive outward offset dis
--square bool if square instead of round terminations
--minlen defaults 10 for viewport coordinates
-- do_trian to return triangulation
function CG.PolygonPad2(pol,dis,square,minlen, do_triang)

	local CW = CG.signed_area(pol)
	local facCW = (CW > 0) and 1 or -1
	--print("PolygonPad CW",CW,facCW)
	local CHK = require"anima.CG3.check_poly"
	--if dis <= 0 then return pol end
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
		local nor = facCW*vec2(edge.y,-edge.x) 
		pol2[#pol2+1] = dis*nor+pol[i]
		pol2[#pol2+1] = dis*nor+pol[mod(i+1,#pol)]
	end
	
	
	local pol3 = pol2
	local pieces = {} -- to keep 
	--make round on convex vertices
	if not square then
		pol3 = {}
		for i=1,#pol do
			local a,b = mod(2*i-2,#pol2),2*i-1
			if facCW * signs[i] > 0 then 
				local center = pol[i]
				local p1,p2 = pol2[a],pol2[b]
				local dir1 = (p1 - center):normalize()
				local dir2 = (p2 - center):normalize()
				local iniang = atan2(dir1.y, dir1.x)
				local endang = atan2(dir2.y, dir2.x)

				local chgang = (endang - iniang)
				if facCW > 0 then
					chgang = chgang < 0 and pix2+chgang or chgang
				else
					chgang = chgang > 0 and -pix2+chgang or chgang
				end
				local leng = dis*(chgang)*facCW

				local trozos = floor(leng/minlen)
				local incang = chgang/trozos
				
				pol3[#pol3+1] = p1
				for t = 1, trozos-1 do
					local om = iniang + incang*t
					pol3[#pol3+1] = center + dis*vec2(cos(om),sin(om))
				end
				pol3[#pol3+1] = p2
				pieces[i] = trozos
			else
				pol3[#pol3+1] = pol2[a]
				pol3[#pol3+1] = pol2[b]
			end
		end
	end
	if do_triang then
		local npol = #pol
		local points, tr = {},{}
		local acum_trozos = {}
		for i=1,npol do
			acum_trozos[i] = (acum_trozos[i-1] or 0) + (pieces[i] or 0)
		end
		-- index on pol2
		local npol2 = #pol2
		local function ab_square(i) return mod(2*i-2,npol2),2*i-1 end
		local function ab(i) return mod(2*i-2,npol2),2*i-1 end
		-- index on points
		local function ab_p(i) local a,b = ab(i); return a+npol,b+npol end
		for i=1,#pol do
			local a,b = ab_p(i)
			-- i,a,b
			insert(tr,i);insert(tr,a);insert(tr,b)
			-- i,b,i+1
			insert(tr,i);insert(tr,b);insert(tr,mod(i+1,npol))
			-- i,bprev,a
			local _,bprev = ab_p(mod(i-1,npol))
			insert(tr,i);insert(tr,bprev);insert(tr,a)
			points[i] = pol[i]
		end
		for i=1,npol2 do
			points[#points+1] = pol2[i]
		end
		for i=1,#tr do tr[i] = tr[i]-1 end
		return points, tr
	end
	--self intersection repair
	--do return pol2 end
	--now repair
	local poly = {} --= pol3
	for i=1,#pol3 do poly[i] = pol3[i] end
	--do return poly,poly end
	local polys = CHK.check_repair_self_crossings(poly)
	if #polys > 1 then
		local CW 
		local maxi,maxval = -math.huge, -math.huge
		for i=1,#polys do 
			local CW = facCW*CG.signed_area(polys[i]) 
			if CW > maxval then
				maxval = CW
				maxi = i
			end
		end
		poly = polys[maxi]
	else
		poly = polys[1]
	end
	
	return poly,pol3
	--return pol3
end

--return a polygon with positive outward offset dis
--square bool if square instead of round terminations
--minlen defaults 10 for viewport coordinates
--poly must be CCW
function CG.PolygonPadBAK(pol,dis,square,minlen)
	
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
