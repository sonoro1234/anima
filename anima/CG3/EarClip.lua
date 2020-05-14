local CG = require"anima.CG3.base"
local M = CG

local function mod(a,b)
	return ((a-1)%b)+1
end

local Sign = CG.Sign
local IsPointInTri = CG.IsPointInTri
local Angle = CG.Angle

local function InsertHoles2(poly)
	holes = poly.holes
	--first fusion holes with poly
	--find hole with max X point
	while #holes>0 do
		--print("#holes",#holes)
		local maxx = -math.huge
		local maxhole, maxholevert
		for i=1,#holes do
			local hole = holes[i]
			for j=1,#hole do
				if hole[j].x > maxx then
					maxx = hole[j].x
					maxhole = i
					maxholevert = j
				end
			end
		end
		--find segment maxholevert-outer not intersecting outer
		local Mp = holes[maxhole][maxholevert]
		local I = Mp + mat.vec3(math.huge, 0,0)
		local edge
		for i=1,#poly do
			local a,b = poly[i],poly[mod(i+1,#poly)]
			if (a.x < Mp.x and b.x < Mp.x) then goto CONTINUE end
			if a.x > I.x and b.x > I.x then goto CONTINUE end
			if (a.y <= Mp.y and Mp.y <= b.y) or (b.y <= Mp.y and Mp.y <= a.y) then
				local Ite = CG.intersectSegmentX(a,b,Mp)
				if Ite.x < I.x then
					edge = i
					I = Ite
				end
			end
			::CONTINUE::
		end

		assert(edge)

		--if I is edge or edge+1 this is visible point
		local VV,isendpoint
		local a,b = poly[edge],poly[mod(edge+1,#poly)]
		if I==a then
			VV = edge
			isendpoint = true
		elseif I==b then
			VV = mod(edge+1,#poly)
			isendpoint = true
		elseif a.x < b.x then
			VV = mod(edge+1,#poly)
		else
			VV = edge
		end
		
		if not isendpoint then
			local P = poly[VV]
			--print("Rayintersec",a,b,Mp,P)
			--check all reflex (not convex) poly vertex are outside triangle MIP
			local mintan = math.huge
			local Ri
			for i=1,#poly do
				local a,b,c = poly[mod(i-1,#poly)],poly[i],poly[mod(i+1,#poly)]
				--if IsConvex(a,b,c) then
				if CG.Sign(a,b,c) > 0 then
					if M.IsPointInTri(b,Mp,I,P) then
						--keep angle
						local MR = b-Mp
						local tan = math.abs(math.atan2(MR.y,MR.x))
						if tan < mintan then
							Ri = i
							mintan = tan
						end
					end
				end
			end
			-- if not Ri then M-P are visible so VV remains equal
			if Ri then VV=Ri end
		end
		--create segment Mp-VV merging hole in poly
		local newpoly = {}
		for i=1,VV do
			newpoly[i] = poly[i]
		end
		local hole = holes[maxhole]
		for i=0,#hole-1 do
			newpoly[#newpoly+1] = hole[mod(i+maxholevert,#hole)]
		end
		newpoly[#newpoly+1] = hole[maxholevert]
		--newpoly[#newpoly+1] = poly[VV]
		for i=VV,#poly do
			newpoly[#newpoly+1] = poly[i]
		end
		poly = newpoly
		--delete hole
		table.remove(holes,maxhole)
	end --holes
	
	--local tr,ok,rest = M.EarClip(poly)
	--return poly,tr,ok,rest
	return poly
end
CG.InsertHoles2 = InsertHoles2

local function check_crossings_ind(poly,ind,verbose)
	local has_cros = false
	for i=1,#ind do
		local a,b = poly[ind[i]],poly[ind[mod(i+1,#ind)]]
		local jlimit = mod(i-2,#ind)
		local j = mod(i+2,#ind)
		while j~=jlimit do
			local ijp1 = mod(j+1,#ind)
			local c,d = poly[ind[j]],poly[ind[ijp1]]
			local inters,sc,sd = M.SegmentIntersect(a,b,c,d)
			--print("find crossin",i,j,"vals",inters,sc,sd)
			if inters then
				if verbose then print("self crossing",i,j,a,b,c,d) end
				has_cros = true
			end
			j = mod(j+1,#ind)
		end
	end
	return has_cros
end

local function EarClipSimple(poly,CW)
	
	local CWfac = CW and -1 or 1
	--local hasC,hasR = M.check_simple(poly)--,true)
	--if hasC then error"not simple polygon" end
	
	local ind = {}
	local tr = {}
	for i,v in ipairs(poly) do ind[i] = i end
	--ind[#ind] = nil --delete repeated
	--finc ear_tip
	local badcross = false
	while #ind > 2 do
		local initind = #ind
		
		local hasC = check_crossings_ind(poly,ind)
		if hasC then badcross=true;break; end
		
		for i,v in ipairs(ind) do
			--is convex?
			local a,b,c = ind[mod(i-1,#ind)],ind[i],ind[mod(i+1,#ind)]
			local s = Sign(poly[a],poly[b],poly[c])*CWfac
			if s > 0 then --convex
				local empty = true
				--test empty
				local jlimit = mod(i-1,#ind)
				local j = mod(i+2,#ind)
				while j~=jlimit do
					local intri = IsPointInTri(poly[ind[j]],poly[a],poly[b],poly[c])
					if intri 
					--and Sign(poly[ind[mod(j-1,#ind)]],poly[ind[j]],poly[ind[mod(j+1,#ind)]])>0 
					then
						empty = false
						break
					end
					j = mod(j+1,#ind)
				end
				
				if empty then
					table.remove(ind,i)
					table.insert(tr,a-1)
					table.insert(tr,b-1)
					table.insert(tr,c-1)
					break
				end
			end
		end
		if (initind == #ind) then
			--print("failed to find ear, no convex is",not_convex,#ind) 
			local repaired = false
			--find consecutive repeated
			for i=1,#ind do
				local j = mod(i+1,#ind)
				if poly[ind[i]]==poly[ind[j]] then 
					table.remove(ind,i)
					repaired = true
					--print("consecutive repeat repaired",ind[i])
					break
				end
			end
			--find collinear
			if not repaired then
			for i=1,#ind do
				local a,b,c = poly[ind[mod(i-1,#ind)]],poly[ind[i]],poly[ind[mod(i+1,#ind)]]
				local ang,conv,s,cose = CG.Sign(a,b,c)
				if (s==0) then
					local angle,conv,s,cose = Angle(a,b,c)
					if not angle==0 then
						print("collinear repaired",ind[i],angle,conv,s,cose)
						table.remove(ind,i)
						repaired = true
						break
					end
				end
			end
			end
			--------------
			if not repaired then
				local restpoly = {}
				for i,v in ipairs(ind) do restpoly[#restpoly+1] = poly[ind[i]] end
				return tr,false,restpoly
			end
		end
	end
	if badcross then
		local restpoly = {}
		for i,v in ipairs(ind) do restpoly[#restpoly+1] = poly[ind[i]] end
		return tr,false,restpoly
	end
	return tr,true
end
CG.EarClipSimple = EarClipSimple


local function EarClipSimple2(poly)
	
	if poly.holes then
		poly = CG.InsertHoles(poly)
	end
	
	local ind = {}
	local tr = {}
	local angles = {}
	local convex = {}
	local eartips = {}
	for i,v in ipairs(poly) do ind[i] = i end
	--compute interior angles
	
	local function update_all_ears()
		for i=2,#ind-1 do
			angles[i],convex[i] = Angle(poly[i-1],poly[i],poly[i+1])
		end
		angles[1],convex[1] = Angle(poly[#ind],poly[1],poly[2])
		angles[#ind],convex[#ind] = Angle(poly[#ind-1],poly[#ind],poly[1])
		
		
		--find eartips
		for i=1,#ind do
			if convex[i] then
				local empty = true
				local a,b,c = poly[mod(i-1,#ind)],poly[i],poly[mod(i+1,#ind)]
				local jlimit = mod(i-1,#ind)
				local j = mod(i+2,#ind)
				while j~=jlimit do
					--if not convex[j] and 
					if IsPointInTri(poly[j],a,b,c) then
						empty = false
						break
					end
					j = mod(j+1,#ind)
				end
				eartips[i] = empty
			end
		end
	end
	
	update_all_ears()
	
	local function update_ear(i)
		if not convex[ind[i]] then 
			eartips[ind[i]] = false
		else
			local empty = true
			local a,b,c = poly[ind[mod(i-1,#ind)]],poly[ind[i]],poly[ind[mod(i+1,#ind)]]
			local jlimit = mod(i-1,#ind)
			local j = mod(i+2,#ind)
			while j~=jlimit do
				--if not convex[ind[j]] and 
				if IsPointInTri(poly[ind[j]],a,b,c) then
					empty = false
					break
				end
				j = mod(j+1,#ind)
			end
			eartips[ind[i]] = empty
		end
	end
	
	local function create_tr_update(i,create)
		local b = ind[i]
		table.remove(ind,i)
		--remove if consecutive repeat of point
		while poly[ind[mod(i-1,#ind)]] == poly[ind[mod(i,#ind)]] do
			i = mod(i,#ind)
			table.remove(ind,i)
		end
		i = mod(i,#ind)
		local a,c = ind[mod(i-1,#ind)],ind[mod(i,#ind)]
		local am1,cM1 = ind[mod(i-2,#ind)],ind[mod(i+1,#ind)]
		
		--update infos
		--remove eartip not necessary because ind is gone
		--update a and c
		angles[a],convex[a] = Angle(poly[am1],poly[a],poly[c])
		angles[c],convex[c] = Angle(poly[a],poly[c],poly[cM1])
		update_ear(mod(i-1,#ind)) --for a
		update_ear(mod(i,#ind)) --for c
		if create then
			table.insert(tr,a-1)
			table.insert(tr,b-1)
			table.insert(tr,c-1)
		end
	end
	local last_uae
	while #ind > 2 do
		local initind = #ind
		--find smallest angle eartips
		local not_eartips = true
		local minang = math.huge
		local mineartipI 
		for i=1,#ind do
			if eartips[ind[i]] then
				not_eartips = false
				if angles[ind[i]] < minang then
					minang = angles[ind[i]]
					mineartipI = i
					--break
				end
			end
		end
		assert(minang>=0)
		if not_eartips then
			-- try to repair
			--find consecutive repeated
			print("\n-----------trying to repair",#ind)
			local repaired = false
			if last_uae ~= #ind then
				update_all_ears()
				print"updated_all_ears"
				last_uae = #ind
				repaired = true
			end
			if not repaired then
			for i=1,#ind do
				local j = mod(i+1,#ind)
				if poly[ind[i]]==poly[ind[j]] then 
					create_tr_update(i,false)
					repaired = true
					print("consecutive repeat repaired",ind[i])
					break
				end
			end
			end
			if not repaired then
			for i=1,#ind do
				local ang,conv,s,cose = Angle(poly[ind[mod(i-1,#ind)]],poly[ind[i]],poly[ind[mod(i+1,#ind)]])
				if (s==0 and not ang==0) then
					create_tr_update(i,false)
					print("collinear repaired",ind[i])
					repaired = true
					break
				end
			end
			end
			if not repaired then break end
		else
			if not mineartipI then 
				for i=1,#ind do
					if eartips[ind[i]] then
						print("angle",i,angles[ind[i]])
						print(poly[ind[mod(i-1,#ind)]],poly[ind[i]],poly[ind[mod(i+1,#ind)]])
					end
				end
			end
			create_tr_update(mineartipI,true)
		end
	end	
	if #ind > 2 then
		local restpoly = {}
		for i,v in ipairs(ind) do restpoly[#restpoly+1] = poly[ind[i]] end
		return poly,tr,false,restpoly
	end	
	return poly,tr,true
end
CG.EarClipSimple2 = EarClipSimple2

--standard triangulation by sweep , ugly triangles
function CG.triang_sweept(P)

	local Sign = CG.Sign
	assert(P.sorted,"points must be sorted")
	local Q = {}
	local tr = {}
	local last
	--first triangle
	local sign = Sign(P[1],P[2],P[3])
	--if sign >= 0 then 
	if sign > 0 then
		Q[1],Q[2],Q[3] = 1,2,3
		tr = {0,1,2}
		last = 3
	elseif sign < 0 then
		Q[1],Q[2],Q[3] = 1,3,2
		tr = {0,2,1}
		last = 2
	else
		error("collinear points")
	end

	for i=4,#P do
		local u,d = last,last
		while (Sign(P[i],P[Q[u]],P[Q[mod(u+1,#Q)]]) < 0) do
			table.insert(tr,i-1)
			table.insert(tr,Q[mod(u+1,#Q)]-1)
			table.insert(tr,Q[u]-1)
			u = mod(u+1,#Q)
		end
		while (Sign(P[i],P[Q[d]],P[Q[mod(d-1,#Q)]]) > 0) do
			table.insert(tr,i-1)
			table.insert(tr,Q[d]-1)
			table.insert(tr,Q[mod(d-1,#Q)]-1)
			d = mod(d-1,#Q)
		end
		if(d >u and u~=1) then
			print(d,u)--,Sign(Q[1],Q[2],Q[3]),Sign(P[1],P[2],P[3]))
			--prtable(Q)
			error("asdfasdf")
		end
		
		if u > d then
			for h=1,u-d-1 do table.remove(Q,d+1) end
		else
			for j=d+1,#Q do Q[j]=nil end
		end
		table.insert(Q,d+1,i)
		last = d+1

		--]]
	end
	local CH = {}
	for i,v in ipairs(Q) do
		CH[i] = P[Q[i]]
	end
	--testTODO
	-- for i=1,#tr,3 do
		--assert(Sign(P[tr[i]+1],P[tr[i+1]+1],P[tr[i+2]+1]) > 0)
		-- if Sign(P[tr[i]+1],P[tr[i+1]+1],P[tr[i+2]+1]) < 0 then
			-- tr[i+1],tr[i+2] = tr[i+2],tr[i+1]
		-- end
	-- end
	return CH,tr
end
