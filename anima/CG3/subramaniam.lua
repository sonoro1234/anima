local CG = require"anima.CG3"

local function mod(a,b)
	return ((a-1)%b)+1
end
local insert = table.insert
local sort = table.sort

-- spline+holes -> polys
local function spline2polys(ps)
	local polys = {{}}
	for i=1,#ps do polys[1][i] = ps[i] end
	if ps.holes then
		for i,hole in ipairs(ps.holes) do
			polys[#polys+1] = {}
			local poly = polys[#polys]
			for j,v in ipairs(hole) do poly[j]=v end
		end
	end
	return polys
end
-- spline to points+contours
local function spline2contours(ps)
	local pts = {}
	for i=1,#ps do pts[i] = ps[i] end
	if ps.holes then
		for i,hole in ipairs(ps.holes) do
			for j,v in ipairs(hole) do pts[#pts+1]=v end
		end
	end
	local contours = {}
	local Polind = {}
	---------------
	for j=1,#ps do assert(ps[j],"nil index in ps") end
	for i=1,#ps do Polind[i]=i end
	contours[1] = Polind
	local sum = #Polind
	if ps.holes then
		for i,hole in ipairs(ps.holes) do
			local Pi = {}
			for j=1,#hole do
				Pi[j]=j + sum
			end
			contours[#contours+1]=Pi
			sum = sum + #contours[#contours]
		end
	end
	return pts, contours
end

local function polys2contours(polys)
	local pts = {}
	local contours = {}
	local sum = 0
	for i,poly in ipairs(polys) do
		local Pi = {}
		for j,pt in ipairs(poly) do
			Pi[j]=j + sum
			pts[#pts+1] = pt
		end
		contours[#contours+1]=Pi
		sum = sum + #contours[#contours]
	end
	return pts, contours
end

local function contours2polys(pts, contours)
	local polys = {}
	for i,cont in ipairs(contours) do
		local poly = {}
		for j,ind in ipairs(cont) do
			insert(poly,pts[ind])
		end
		insert(polys, poly)
	end
	return polys
end
--- =============== contours intersec ===================
--- brute force
local function find_contour_intersec(pts,contour,n)
	local crossings = {}
	local ncontour = #contour
	for i=1,ncontour do
		local ai,bi = contour[i],contour[mod(i+1,ncontour)]
		local a,b = pts[ai],pts[bi]
		if a==b then goto CONTINUE1 end
		local lim = math.min(i + ncontour - 2,ncontour)
		for j=i+2,lim do
			local ci,di = contour[j],contour[mod(j+1,ncontour)]
			local c,d = pts[ci],pts[di]
			if c==d then goto CONTINUE2 end
			if CG.SegmentIntersectC(a,b,c,d) then
				local pt,good,t1,t2 = CG.IntersecPoint3(a,b,c,d)
				if good then 
					table.insert(crossings,{pt=pt,ct_a=n,a=ai,b=bi,ct_c=n,c=ci,d=di,t1=t1,t2=t2})
				else
					print("bad intersecpoint",ai,ci,a,b,c,d)
					if a == c then
						table.insert(crossings,{pt=a,ct_a=n,a=ai,b=bi,ct_c=n,c=ci,d=di,t1=0,t2=0})
					else
						local t = (c-a)/(b - a)
						print("t1",c-a,b-a)
						if t.x~=t.x then --nan
							t = t.y --both cant be nan
						else
							t = t.x
						end
						local t1 = t
						table.insert(crossings,{pt=c,ct_a=n,a=ai,b=bi,ct_c=n,c=ci,d=di,t1=t1,t2=0})
					end
				end
			end
			::CONTINUE2::
		end
		::CONTINUE1::
	end
	return crossings
end

local function find_2contour_intersec(pts,contour1,contour2,i,j)
	local crossings = {}
	local ncontour1,ncontour2 = #contour1,#contour2
	for i=1,ncontour1 do
		local ai,bi = contour1[i],contour1[mod(i+1,ncontour1)]
		local a,b = pts[ai],pts[bi]
		if a==b then goto CONTINUE1 end
		--local lim = math.min(i + ncontour - 2,ncontour)
		for j=1,ncontour2 do
			local ci,di = contour2[j],contour2[mod(j+1,ncontour2)]
			local c,d = pts[ci],pts[di]
			if c==d then goto CONTINUE2 end
			if CG.SegmentIntersectC(a,b,c,d) then
				local pt,good,t1,t2 = CG.IntersecPoint3(a,b,c,d)
				if good then 
					table.insert(crossings,{pt=pt,ct_a=i,a=ai,b=bi,ct_c=j,c=ci,d=di,t1=t1,t2=t2})
				else
					print("bad intersecpoint",ai,ci,a,b,c,d)
					if a == c then
						table.insert(crossings,{pt=a,ct_a=i,a=ai,b=bi,ct_c=j,c=ci,d=di,t1=0,t2=0})
					else
						local t = (c-a)/(b - a)
						print("t1",c-a,b-a)
						if t.x~=t.x then --nan
							t = t.y --both cant be nan
						else
							t = t.x
						end
						local t1 = t
						table.insert(crossings,{pt=c,ct_a=i,a=ai,b=bi,ct_c=j,c=ci,d=di,t1=t1,t2=0})
					end
				end
			end
			::CONTINUE2::
		end
		::CONTINUE1::
	end
	return crossings
end

local function find_contours_intersec(pts,contours)
	local cross = {}
	for i,contour in ipairs(contours) do
		-- find self intersecpoints
		cross[#cross+1] = find_contour_intersec(pts,contour,i)
		-- find 2 contours intersec
		for j=i+1,#contours do
			cross[#cross+1] = find_2contour_intersec(pts,contour,contours[j],i,j)
		end
	end
	-- flatten cross
	local crossi = {}
	for i,crs in ipairs(cross) do
		for j,cr in ipairs(crs) do
			crossi[#crossi+1] = cr
		end
	end
	return crossi
end
local function repair_contour_crossings(pts, contours)
	local cross = find_contours_intersec(pts,contours)
	local npts = #pts
	-- make nexts array
	local nexts = {}
	for i,cont in ipairs(contours) do
		local ncont = #cont
		for j,ind in ipairs(cont) do
			assert(not nexts[ind],"equal ind in different contours")
			nexts[ind] = cont[mod(j+1,#cont)]
		end
	end
	
	-- make edges array
	local edges = {}
	for i=1,#pts do
		edges[i] = {}
	end

	for i,cr in ipairs(cross) do
		insert(edges[cr.a],{pt=cr.pt,next= cr.b,other=cr.c, t=cr.t1,cr=i,crdone=i*2-1})
		insert(edges[cr.c],{pt=cr.pt,next= cr.d,other=cr.a, t=cr.t2,cr=i,crdone=i*2})
	end
	
	for i=1,#edges do
		sort(edges[i],function(a,b) return a.t<b.t end)
	end
	
	local pols,done,donecross = {},{},{}
	local pol,poli,polcr = {}, 1,0
	local curri  = 1
	local edgei = 1
	print"====first pol"
	print"insert 1"
	insert(pol, curri)
	done[curri] = true
	local count = 0
	while true do
		count = count +1
		if count>30 then return pts,pol end
		print("-- curri",curri,"edgei",edgei)
		if edges[curri][edgei] then
			local cr = edges[curri][edgei]
			
			if polcr==cr.crdone then
				print"closing"
				insert(pols,pol)
				return pts,pols
			end
			insert(pts, cr.pt)
			insert(pol, #pts)
			print("insert",#pts)
			donecross[cr.crdone] = true --(donecross[cr.cr] or 0) + 1
			local edge = cr.other
			--search next
			for i=1,#edges[edge] do
				local cr2 = edges[edge][i]
				if cr2.other==curri then
					curri = edge
					edgei = i+1
					print("found",curri,"edgei",edgei)
					break
				end
			end
			--
		else
			
			curri = nexts[curri] --mod(curri + 1,#poly)
			print("next point------------",curri,"poli",poli,"polcr",polcr)
			if curri == poli and polcr == 0 then --closed
				print"closing"
				insert(pols,pol)
				-- check original pts done
				for i=1,npts do 
					if not done[i] then
						pol = {}
						curri = i
						edgei = 1
						poli = i
						polcr = 0
						print("============new pol",i)
						goto INIT
					end
				end
				-- now check donecross
				print"crosscheck"
				for i=1,#cross*2 do
					print("donecross",i,donecross[i])
					if not (donecross[i]) then
						pol = {}
						polcr = i
						poli = 0
						local ic
						if i%2==1 then 
							ic=(i+1)/2
							curri = cross[ic].c
						else 
							ic = i/2 
							curri = cross[ic].a
						end
						
						print("donecross found",i,donecross[i],curri,ic)
						--prtable(edges[curri])
						--error"debug"
						for j=1,#edges[curri] do
							if edges[curri][j].cr == ic then
								edgei = j+1
								print("==========new pol cross",i)
								insert(pts,cross[ic].pt)
								insert(pol,#pts)
								print("insert",#pts)
								goto INIT2
							end
						end
					end
				end
				-- all done
				return pts,pols
			end
			::INIT::
			print("insert",curri)
			done[curri] = true
			
			insert(pol,curri)
			edgei = 1
			::INIT2::
		end
	end
end
---------------------- only 1 poly
local function find_intersec(poly)
	local crossings = {}
	for i=1,#poly do
		local ai,bi = i,mod(i+1,#poly)
		local a,b = poly[ai],poly[bi]
		if a==b then goto CONTINUE1 end
		local lim = math.min(i + #poly - 2,#poly)
		for j=i+2,lim do
			local ci,di = j,mod(j+1,#poly)
			local c,d = poly[ci],poly[di]
			if c==d then goto CONTINUE2 end
			--local ok,err = pcall(CG.SegmentIntersectC,a,b,c,d)
			--if not ok then prtable(ai,bi,ci,di,poly) end
			if CG.SegmentIntersectC(a,b,c,d) then
				local pt,good,t1,t2 = CG.IntersecPoint3(a,b,c,d)
				if good then 
					table.insert(crossings,{pt=pt,a=ai,c=ci,t1=t1,t2=t2})
				else
					print("bad intersecpoint",ai,ci,a,b,c,d)
					if a == c then
						table.insert(crossings,{pt=a,a=ai,c=ci,t1=0,t2=0})
					else
						--error"badintersec"
						---[[
						local t = (c-a)/(b - a)
						print("t1",c-a,b-a)
						if t.x~=t.x then --nan
							t = t.y --both cant be nan
						else
							t = t.x
						end
						local t1 = t
						table.insert(crossings,{pt=c,a=ai,c=ci,t1=t1,t2=0})
						--]]
						--[[
						local t = (a-c)/(d - c)
						print("t2",a-c,d-c)
						if t.x~=t.x then --nan
							t = t.y --both cant be nan
						else
							t = t.x
						end
						local t2 = t
						table.insert(crossings,{pt=a,a=ai,c=ci,t1=0,t2=t2})
						--]]
						print("t1,t2",t1,t2)
						--error"badintersec"
					end
					--print("bad crossing",pt,ai,bi,ci,di)
					--print(a,b,c,d)
				end
			end
			::CONTINUE2::
		end
		::CONTINUE1::
	end
	return crossings
end

--this is subramaniam algo
-- the same used in https://github.com/mclaeysb/simplepolygon
local function repair_crossings(poly)
	local cross = find_intersec(poly)
	-- make edges array
	local edges = {}
	for i=1,#poly do
		edges[i] = {}
	end
	
	for i,cr in ipairs(cross) do
		insert(edges[cr.a],{pt=cr.pt,other=cr.c, t=cr.t1,cr=i})
		insert(edges[cr.c],{pt=cr.pt,other=cr.a, t=cr.t2,cr=i})
	end
	
	for i=1,#edges do
		-- print("sort",i)
		-- prtable(edges[i])
		sort(edges[i],function(a,b) return a.t<b.t end)
	end
	
	local pols,done,donecross = {},{},{}
	local pol,poli,polcr,polip = {}, 1,0,poly[1]
	local curri = 1
	local edgei = 1
	insert(pol, poly[curri])
	done[curri] = true
	local count = 0
	while true do
		count = count +1
		--if count>20 then return pol end
		print("-- curri",curri,"edgei",edgei)
		if edges[curri][edgei] then
			local cr = edges[curri][edgei]
			print("insert",cr.pt)
			if polcr==cr.cr then
				insert(pols,pol)
				return pols
			end
			insert(pol, cr.pt)
			donecross[cr.cr] = (donecross[cr.cr] or 0) + 1
			local edge = cr.other
			--search next
			for i=1,#edges[edge] do
				local cr2 = edges[edge][i]
				if cr2.other==curri then
					curri = edge
					edgei = i+1
					print("found",curri,"edgei",edgei)
					break
				end
			end
			--
		else
			
			curri = mod(curri + 1,#poly)
			print("next point------------",curri,"poli",poli,"polcr",polcr)
			if curri == poli and polcr == 0 then --closed
				print"closing"
				insert(pols,pol)
				for i=1,#poly do
					if not done[i] then
						pol = {}
						curri = i
						edgei = 1
						poli = i
						polcr = 0
						print("============new pol",i)
						goto INIT
					end
				end
				-- now check donecross
				print"crosscheck"
				for i=1,#cross do
					print("donecross",i,donecross[i])
					if not (donecross[i]==2) then
						
						pol = {}
						polcr = i
						poli = 0
						curri = cross[i].a
						print("donecross found",i,donecross[i],curri)
						for j=1,#edges[curri] do
							if edges[curri][j].cr == i then
								edgei = j+1
								print("==========new pol cross",i)
								insert(pol,cross[i].pt)
								goto INIT2
							end
						end
					end
				end
				-- all done
				return pols
			end
			::INIT::
			print("insert",poly[curri],curri)
			done[curri] = true
			insert(pol, poly[curri])
			edgei = 1
			::INIT2::
		end
	end
end
-- get the max area from subramaniam result
local function subramaniam_max(poly, facCW)
	local polys = repair_crossings(poly)
	--choose max area
	local maxA,maxi = -math.huge
	for i=1,#polys do
		local A = facCW*CG.signed_area(polys[i])
		if A>maxA then
			maxA = A
			maxi = i
		end
	end
	return polys[maxi]
end
----------------------------------------------------
-- repair by split: not consistent, changes with first point
local function  split_on_cross_rep(poly, cr)
	--print("split_on_cross_rep",unpack(cr))
	local printD = function() end
	local typ = ffi.typeof(poly[1]) --could be vec3 or vec2
	local pt, a, c = typ(cr.pt), cr.a, cr.c
	local b, d = mod(a + 1, #poly), mod(c + 1, #poly)
	local P1, P2 = {},{} --{poly[a]}, {poly[c]}
	--- set points to pt from b to c
	local i = b
	while(i~=d) do
		P1[i] = pt
		i = mod(i+1,#poly)
	end
	local i = d
	while(i ~= b) do
		P1[i] = poly[i]
		i = mod(i+1,#poly)
	end
	-- set points to pt from d to a
	local i = d
	while(i~=b) do
		P2[i] = pt
		i = mod(i+1,#poly)
	end
	local i = b
	while(i ~= d) do
		P2[i] = poly[i]
		i = mod(i+1,#poly)
	end
	--prtable("split_on_cross_rep",poly,P1,P2)
	assert(#poly==#P1)
	assert(#poly==#P2)
	return {P1, P2}
end

local max = math.max
local function repair_crossings_split(poly, facCW)
	local cross = find_intersec(poly)
	if #cross>0 then
		local BIS = {}
		local ALL = {}
		local maxi,maxA = 0,-math.huge
		for i=1,#cross do
			local BI = split_on_cross_rep(poly,cross[i])
			local A1 = facCW*CG.signed_area(BI[1])
			local A2 = facCW*CG.signed_area(BI[2])
			print("A1,A2",A1,A2)
			local A = max(A1,A2)
			if A>maxA then
				maxA = A1
				--maxi = i
				if A1>A2 then
					insert(BIS,BI[1])
				else
					insert(BIS,BI[2])
				end
				maxi = #BIS
			end
			-- insert(ALL,BI[1])
			-- insert(ALL,BI[2])
		end
		print("maxi",maxi,#BIS)
		-- return ALL
		return BIS[maxi]
	else
		return poly
	end
end

local function reverse(t)
	local s = #t+1
	for i=1,math.floor(#t/2) do
		t[i],t[s-i] = t[s-i],t[i]
	end
	return t
end
---[[
local poly = {}
poly[1] = ffi.new("struct dvec2",{178,137})
poly[2] = ffi.new("struct dvec2",{482,691})
poly[3] = ffi.new("struct dvec2",{357,691})
poly[4] = ffi.new("struct dvec2",{563,256})
poly[5] = ffi.new("struct dvec2",{154,502})
poly[6] = ffi.new("struct dvec2",{646,498})
poly[7] = ffi.new("struct dvec2",{290,255})
poly[8] = ffi.new("struct dvec2",{350,211})
poly[9] = ffi.new("struct dvec2",{415,437})
poly[10] = ffi.new("struct dvec2",{523,132})

--poly = reverse(poly)
--local pol = repair_crossings(poly)
--local pol = repair_crossings_split(poly)
local pts, contours = polys2contours({poly})
local pts2,pol = repair_contour_crossings(pts, contours)
prtable(pol)
--]]
--[[ --badcorssing a==c
poly = {}
poly[1] = mat.vec2(377,73)
poly[2] = mat.vec2(499,354)
poly[3] = mat.vec2(377,245)
poly[4] = mat.vec2(377,414)
poly[5] = mat.vec2(255,136)
poly[6] = mat.vec2(377,245)
local pol = repair_crossings(poly)
prtable(pol)
--]]
--[[
poly = {}
poly[1] = mat.vec2(377,73)
poly[2] = mat.vec2(499,354)
poly[3] = mat.vec2(377,178)
poly[4] = mat.vec2(377,414)
poly[5] = mat.vec2(255,136)
poly[6] = mat.vec2(377,245)
local pol = repair_crossings(poly)
prtable(pol)
--]]
local M = {repair_crossings= repair_crossings, repair_crossings_split = repair_crossings_split, subramaniam_max=subramaniam_max}
M.repair_contour_crossings = repair_contour_crossings
M.spline2contours = spline2contours
M.contours2polys = contours2polys
return M