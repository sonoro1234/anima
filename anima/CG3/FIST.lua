--Robust EarClip with holes
local CG = require"anima.CG3.base"
local Angle = CG.Angle

local function mod(a,b)
	return ((a-1)%b)+1
end

local function leftmostvertex(poly)
	local minx = math.huge
	local mini
	for i,p in ipairs(poly) do
		if p.x < minx then
			minx = p.x
			mini = i
		end
	end
	return minx,mini
end

local function IsPointInSegment(pt,a,b)
	assert(not (a==b)) 
	local A = a - b
	local B = pt - b
	if not (A.x*B.y==A.y*B.x) then return false end
	local t
	if A.x == 0 then
		t = B.y/A.y
	else
		t = B.x/A.x
	end
	return t >=0,t and t<=1,t
end


local function IsPointInPolyBorder(poly,p)
	for i,p1 in ipairs(poly) do
		if IsPointInSegment(p,p1,poly[mod(i+1,#poly)]) then
			return true --on border
		end
	end
	return false
end


local function equal(p1,p2)
	--return (p1 - p2):norm() < 1e-15
	return p1==p2
end
local function remove_colinear(pt,verbose)
	local abs = math.abs
	local colin = 0
	local numpt = #pt
	local i = 1
	while i <= numpt and numpt > 2 do
		
		local ang,conv,s,cose,sine = Angle(pt[mod(i-1,numpt)],pt[mod(i,numpt)],pt[mod(i+1,numpt)])
		--print(numpt, "Angle of:",mod(i-1,numpt),i,mod(i+1,numpt),"vals",ang,conv,s,cose,sine)
		if s==0 then
		--if abs(s) < 1e-12 then
		--if abs(sine) < 1e-12 then
			colin = colin + 1
			table.remove(pt,i)
			--print("remove_colinear",i,numpt)
			numpt = #pt
			i = mod(i,numpt)
			--if pt[mod(i-1,numpt)]==pt[mod(i,numpt)] then 
			local repe = false
			--while pt[mod(i-1,numpt)]==pt[mod(i,numpt)] do
			while equal(pt[mod(i-1,numpt)],pt[mod(i,numpt)]) do
				assert(cose >= 0)
				--print(i,"pt[mod(i-1,numpt)]==pt[mod(i,numpt)]",mod(i-1,numpt),mod(i,numpt),numpt)
				colin = colin + 1
				table.remove(pt,i)
				numpt = #pt
				repe = true
			end
			if repe then i = mod(i-1,numpt) end
		else
			i = i + 1 
		end
	end
	--if #pt < 3 then pt[2]=nil;pt[1]=nil;print"zero poly--------------" end
	if verbose then print("collinear removes",colin) end

	return colin
end

local function remove_consec_repeated(poly,verbose)
	if #poly < 2 then return 0 end
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
	for i=#toremove,1,-1 do 
		if verbose then print("check_repeated deletes",toremove[i]); end
		table.remove(poly,toremove[i]) end
	return #toremove
end

function CG.degenerate_poly_repair(poly,verbose)
	local remr = 0

	remr = remr + remove_consec_repeated(poly,verbose)
	if poly.holes then
	for j=1,#poly.holes do
		remr = remr + remove_consec_repeated(poly.holes[j],verbose)
		if #poly.holes[j] == 0 then table.remove(poly.holes,j) end
	end
	end

	local remc = 0
	remc = remc + remove_colinear(poly,verbose)
	if poly.holes then
	for j=1,#poly.holes do
		remc = remc + remove_colinear(poly.holes[j],verbose,true)
		if #poly.holes[j] == 0 then table.remove(poly.holes,j) end
	end
	end

	return remr,remc
end


local function IsPointInsidePoly(poly,p)
	if not CG.IsPointInPoly(poly,p) then return false end
	return not IsPointInPolyBorder(poly,p)
end


local IntersecPoint2 = CG.IntersecPoint2
local function CorrectHole(poly,hole,bridgei)
	print"correctHole"
	local hasC = false
	for ih,ph in ipairs(hole) do
		local ph1 = hole[mod(ih+1,#hole)]
		
		if not CG.IsPointInPoly(poly,ph) then
			print("CorrectHole point",ih,ph,"out of poly")
		end
		for i,p in ipairs(poly) do
			local p1 = poly[mod(i+1,#poly)]
			local inter,sc,sd = CG.SegmentIntersect(p,p1,ph,ph1)
			-- if IsPointInSegment(p,ph,ph1) then print(p," of poly in...",ih,mod(ih+1,#hole)) end
			-- if IsPointInSegment(ph,p,p1) then print(ph,"of hole",p,p1) end
			-- if ph == p then print("point",ih,"equals poly",i) end
			-- if CG.SegmentIntersectC(p,p1,ph,ph1) then print(ih,ih+1,"of hole interC with",i,i+1) end
			if inter then
				print("intersection of",ih,"sc,sd",sc,sd)
				hasC = true
				--local pt,ok = CG.IntersecPoint(p,p1,ph,ph1)
				local pt,ok,t = IntersecPoint2(ph,ph1,p,p1)
				assert(ok)
				print("signs of pt:",CG.Sign(pt,p,p1),CG.Sign(pt,ph,ph1))
				if sc<0 then --ph is out
					print("CorrectHole 1",ih)
					assert(CG.IsPointInPoly(poly,ph1))
					--pt = ph + t*(ph1-ph)*1.0001
					hole[ih] = pt
					--assert(ih~=bridgei)
				else
					print("CorrectHole 2",mod(ih+1,#hole))
					assert(CG.IsPointInPoly(poly,ph))
					--pt = ph + t*(ph1-ph)*0.9999
					hole[mod(ih+1,#hole)] = pt
					--assert(mod(ih+1,#hole)~=bridgei)
				end
				break
			end
		end
	end
	return hasC
end

local function Equiv()
	local E = {data={}}
	function E:equal(a,b)
		return (self.data[a] and self.data[b] and self.data[a]==self.data[b]) or false
	end
	function E:has(a)
		return self.data[a]
	end
	function E:get_equals(a)
		local equals = {}
		if not self.data[a] then return nil end
		for k,v in pairs(self.data) do
			if self.data[a] == v then
				equals[#equals+1] = k
			end
		end
		return equals
	end
	function E:inc(lim, inc)
		local newdata = {}
		for k,v in pairs(self.data) do
			if k >= lim then 
				newdata[k+inc]=v
			else
				newdata[k]=v
			end
		end
		self.data = newdata
	end
	function E:add(a,b)
		local A = self.data[a]
		local B = self.data[b]
		if A==nil then
			if B==nil then
				self.data[a] = {}
				self.data[b] = self.data[a]
			else
				self.data[a] = B
			end
		else
			if B==nil then
				self.data[b] = A
			else --A and B not nil
				if not A==B then --do union
					for k,v in pairs(self.data) do
						if v == B then self.data[k]=A end
					end
				end
			end
		end
	end
	return E
end

local function InsertHoles(poly,skip_check)
	local EQ = Equiv()
	local algo = require"anima.algorithm.algorithm"
	local holes = poly.holes
	poly.EQ = EQ
	if not holes then
		poly.holes = {}
		poly.bridges = {}
		return poly
	end
	--[[
	print"removing bad points in holes---------------------"
	for nhole,hole in ipairs(holes) do
		remove_colinear(hole)
		remove_repeated(hole)
		--assert(signed_area(hole)>=0)
		if #hole==0 then table.remove(holes,nhole) end
	end
	--]]
	--[=[
	print"checking holes againgst poly---------------------"
	for nhole,hole in ipairs(holes) do
		local inpoly = true
		for i,p in ipairs(hole) do
			if not CG.IsPointInPoly(poly,p) then
				print("point",i,p,"of hole",nhole,hole,"is out of poly")
				inpoly = false
			end
		end
		if not inpoly then
			table.remove(holes, nhole)
			-- CorrectHole(poly,hole) 
			-- for i,p in ipairs(hole) do
				-- if not CG.IsPointInPoly(poly,p) then
					-- print("recheck point",i,p,"out of poly")
				-- end
			-- end
		end
	end
	print"end checking holes----------------"
	--]=]
	---[=[
	--check hole dont intersect poly or other holes
	--first poly with holes
	if not skip_check then
	for i,p in ipairs(poly) do
		for nh,hole in ipairs(holes) do
			local crossi = {}
			for ih,ph in ipairs(hole) do
				local inter = CG.SegmentBeginIntersect(p,poly[mod(i+1,#poly)],ph,hole[mod(ih+1,#hole)])
				if inter then
					local pc,ok = IntersecPoint2(p,poly[mod(i+1,#poly)],ph,hole[mod(ih+1,#hole)])
						
					crossi[#crossi+1] = {pc=pc,i1=ih,i2=mod(ih+1,#hole)}
					print("hole to insert",nh,"intersects poly on index",i,ih)
						--assert(ok)
					if not ok then
						--print(ph,hole[mod(ih+1,#hole)]);print(ph2,hole2[mod(ih2+1,#hole2)])
						error"paralelos"
					end
				end
			end
			if #crossi>0 then 
				print("#crossi",#crossi) 
				assert(#crossi%2==0)
				local todel = {}
				local toins = {}
				--repair hole deleting points outside
				for ii=1,#crossi,2 do
					local ibegin = crossi[ii].i2
					local iend = crossi[ii+1].i2
					toins[ibegin] = (crossi[ii].pc + hole[crossi[ii].i1])*0.5
					toins[iend] = (crossi[ii+1].pc + hole[crossi[ii+1].i2])*0.5
					local j=ibegin
					while j~=iend do
						todel[j] = true
						j = mod(j+1,#hole)
					end
				end
				--apply actions
				for ii=#hole,1,-1 do
					if todel[ii] then table.remove(hole,ii) end
					if toins[ii] then table.insert(hole,ii,toins[ii]) end
				end
				if #hole==0 then table.remove(holes,nh) end
			end
		end
	end
	--then holes between them merging them
	for nh,hole in ipairs(holes) do
		::compare_again::
		for nh2=nh+1,#holes do
			local hole2 = holes[nh2]
			local crossi = {}
			for ih2,ph2 in ipairs(hole2) do
				for ih,ph in ipairs(hole) do
					local inter = CG.SegmentBeginIntersect(ph,hole[mod(ih+1,#hole)],ph2,hole2[mod(ih2+1,#hole2)])
					if inter then
						local pc,ok = IntersecPoint2(ph,hole[mod(ih+1,#hole)],ph2,hole2[mod(ih2+1,#hole2)])
						
						crossi[#crossi+1] = {pc=pc,ih=ih,ih2=ih2}
						print("holes to insert",nh,nh2,"intersects on index",ih,ih2)
						--assert(ok)
						if not ok then
							print(ph,hole[mod(ih+1,#hole)]);print(ph2,hole2[mod(ih2+1,#hole2)])
							error"paralelos"
						end
					end
				end
			end
			if #crossi>0 then 
				print("#crossi",#crossi) 
				assert(#crossi%2==0)
				--merge hole2 into hole
				local merged = {}
				merged[1] = hole[crossi[1].ih]
				--merged[2] = crossi[1].pc
				local j = mod(crossi[1].ih2 + 1,#hole2)
				local jlimit = mod(crossi[#crossi].ih2 + 1,#hole2)
				while j ~= jlimit do
					merged[#merged+1] = hole2[j]
					j = mod(j+1,#hole2)
				end
				--merged[#merged+1] = crossi[#crossi].pc
				j = mod(crossi[#crossi].ih + 1,#hole)
				jlimit = crossi[1].ih
				while j ~= jlimit do
					merged[#merged+1] = hole[j]
					j = mod(j+1,#hole)
				end
				holes[nh] = merged
				table.remove(holes,nh2)
				goto compare_again
			end
		end
		::continue::
	end
	end --skip check
	--do return poly end
	--]=]
	--classify holes according to leftmost vertex
	local bridges = {}
	local br_equal = {} --same point because of bridge
	local holes_order = {}
	for i,hole in ipairs(holes) do
		
		local minx,mini = leftmostvertex(hole)
		holes_order[i] = {i=i,minx=minx,mini=mini}
		--assert(not CG.IsPointInPoly(poly,hole[mini]))
		--print("hole",i,minx,mini)
	end

	-- table.sort(holes_order,function(a,b) return a.minx < b.minx end)
	algo.quicksort(holes_order, 1, #holes_order, function(a,b) return a.minx < b.minx end)

	for i,horder in ipairs(holes_order) do
		--prtable(horder)
		--print("horder",i)
		local hole = holes[horder.i]
		local minx = horder.minx
		local minv = hole[horder.mini]
		--print("minv",minv)
		--sort outer vertex to the left according to distance
		local sortedp = {}
		for j,p in ipairs(poly) do
			if p.x < minx 
			--and not bridges[j]
			-- and not EQ:has(j)
			then
				--when p is in bridge we have equal p and p1, choose the one having minv to the left
				if not EQ:has(j) then
					sortedp[#sortedp+1] = {j=j,dist=(minv-p):norm()}
				else
					local a,b
					if bridges[j] then a=j;b=j+1 else a=j-1;b=j end
					--print("check",j,b,CG.Sign(poly[mod(a,#poly)],poly[mod(b,#poly)],minv))
					if CG.Sign(poly[mod(a,#poly)],poly[mod(b,#poly)],minv) > 0 then
						sortedp[#sortedp+1] = {j=j,dist=(minv-p):norm()}
					end
				end
			end
		end
		-- table.sort(sortedp,function(a,b) return a.dist < b.dist end)
		algo.quicksort(sortedp, 1, #sortedp, function(a,b) return a.dist < b.dist end)
		--test then to find bridge
		local bridgedone = false
		for j,dd in ipairs(sortedp) do
			--print("hole sorted",j)
			local found = true
			for k,p in ipairs(poly) do
				if CG.SegmentIntersect(minv,poly[dd.j],p,poly[mod(k+1,#poly)]) then
					found = false
					break
				end
			end
			if found then
				-- print("create bridge",dd.j,#hole)
				-- prtable(EQ)
				-- prtable(bridges)
				-- prtable(br_equal)
				--create bridge minv to poly(dd.j)

				local newpoly = {}
				for ii=1,dd.j do
					newpoly[ii] = poly[ii]
				end

				for ii=0,#hole-1 do
					newpoly[#newpoly+1] = hole[mod(ii+horder.mini,#hole)]
				end
				newpoly[#newpoly+1] = hole[horder.mini]
				local indmini = #newpoly
				for ii=dd.j,#poly do
					newpoly[#newpoly+1] = poly[ii]
				end
				poly = newpoly
				
				--update EQ structure
				local hasEQ = EQ:has(dd.j)
				EQ:inc(dd.j,#hole + 2)
				if hasEQ then EQ:add(dd.j,dd.j+#hole + 2) end --make new dd.j equal class that old dd.j
				EQ:add(dd.j,indmini+1)
				EQ:add(dd.j + 1,indmini)
				
				--update old bridges indexes
				local newbridges = {}
				local newbr_equal = {}
				local inc = #hole + 2
				for k,v in pairs(bridges) do
					if k > dd.j then
						--bridges[k] = nil
						newbridges[k+inc] = true
						newbr_equal[k+inc] = br_equal[k] > dd.j and (br_equal[k] + inc) or br_equal[k]
						--newbr_equal[br_equal[k] + inc] = k + inc
					else
						newbridges[k] = true
						newbr_equal[k] = br_equal[k] > dd.j and (br_equal[k] + inc) or br_equal[k]
						--newbr_equal[br_equal[k]] = k
					end
				end
				bridges = newbridges
				br_equal = newbr_equal
				-----------------------
				
				bridges[dd.j]= true
				br_equal[dd.j] = indmini+1

				bridges[indmini]= true
				br_equal[indmini] = dd.j + 1
				
				--print"------------"
				--prtable(bridges,br_equal)
				--prtable(EQ)

				--print("bridge added",i,"was",horder.i,horder.mini,"inds",dd.j,dd.j+1,indmini,indmini+1)
				
				-- if CG.check_crossings(poly,true) then
					-- print("bad bridge insertion of hole",i,"was",hole)
				-- end
				
				bridgedone = true
				break
			end
		end
		if not bridgedone then error"not bridge" end
	end
	poly.holes = {}
	--add reversed br_equal
	local br_equal_r = {}
	for k,v in pairs(br_equal) do
		br_equal_r[v] = k
	end
	for k,v in pairs(br_equal_r) do
		br_equal[k] = v
	end
	poly.br_equal = br_equal
	poly.bridges = bridges
	poly.EQ = EQ
	-- prtable(EQ)
	-- prtable(bridges)
	-- prtable(br_equal)
	return poly
end
CG.InsertHoles = InsertHoles

local function check_collinear(poly,ind,msg)

	local colin = {}
	local numpt = #ind
	for i=1,numpt do
		local ang,conv,s,cose = CG.Angle(poly[ind[mod(i-1,numpt)]],poly[ind[i]],poly[ind[mod(i+1,numpt)]])
		if s==0 then  
			if cose<0 then
				print("collinear on",i,msg)
				error"collinear"
			elseif poly[ind[mod(i-1,numpt)]]==poly[ind[mod(i+1,numpt)]] then --cose>0 and repeated
				print("collinear on",i,msg)
				error"collinear"
			end
		end
	end

end

local function repair1collinear(poly,ind,i)
	local numpt = #ind
	if numpt <3 then return false end
	local ang,conv,s,cose = CG.Angle(poly[ind[mod(i-1,numpt)]],poly[ind[i]],poly[ind[mod(i+1,numpt)]])
		if s==0 then  
			if cose<0 then
				print("repair1collinear on",i,#ind)
				table.remove(ind,i)
				return true
			elseif poly[ind[mod(i-1,numpt)]]==poly[ind[mod(i+1,numpt)]] then --cose>0 and repeated
				print("repair1collinear on",i,#ind)
				table.remove(ind,i)
				return true
			end
		end
		return false
end

function CG.EarClipFIST(poly)


	local use_urgent = true
	local IsPointInTri = CG.IsPointInTriC --CG.IsPointInTriC

	--check it is simple
	local hasC,hasR = CG.check_simple(poly,true,false)
	if hasC  then 
		--do return poly,{},false end
		error"crossing in not simple polygon"		
	end
	--signed area
	-- local sA = signed_area(poly)
	-- print("sA",sA)
	-- assert(sA<=0)
	if poly.holes and #poly.holes > 0 then
		poly = InsertHoles(poly,true)
		
		--check it is simple again
		--print"checking outer poly-holes"
		local hasC,hasR = CG.check_simple(poly,true,false)
		if hasC then error"crossings in polygon with holes" end
	end
	
	remove_colinear(poly,true)
	-- local sA = signed_area(poly)
	-- print("sA",sA)
	-- assert(sA<=0)
	-- print("647",Angle(poly[646],poly[647],poly[648]))
	
	local ind = {}
	local tr = {}
	local angles = {}
	local convex = {}
	local eartips = {}
	local urgent_eartips = {}
	local urgent_queue = {}
	
	local function update_all_ears()
		--compute interior angles
		for i=1,#ind do
			angles[ind[i]],convex[ind[i]] = Angle(poly[ind[mod(i-1,#ind)]],poly[ind[i]],poly[ind[mod(i+1,#ind)]])
		end
		for i=1,#ind do
			if not convex[ind[i]] then goto continue end
			local make_urgent
			local empty = true
			local a,b,c = poly[ind[mod(i-1,#ind)]],poly[ind[i]],poly[ind[mod(i+1,#ind)]]
			
			local j
			if use_urgent and a == poly[ind[mod(i+2,#ind)]] then
				make_urgent = true
				j = mod(i+3,#ind)
			else
				j = mod(i+2,#ind)
			end
			
			local jlimit
			if use_urgent and c == poly[ind[mod(i-2,#ind)]] then
				make_urgent = true
				jlimit = mod(i-2,#ind)
			else
				jlimit = mod(i-1,#ind)
			end
			
			while j~=jlimit do
				if not convex[ind[j]] and --not poly.bridges[ind[j]] and
				IsPointInTri(poly[ind[j]],a,b,c) then
					empty = false
					break
				end
				j = mod(j+1,#ind)
			end
			eartips[ind[i]] = empty
			
			if make_urgent and eartips[ind[i]] then
				table.insert(urgent_queue,i)
				urgent_eartips[ind[i]] = true
			end
			::continue::
		end
		-- if eartips[647] then
			-- print("update all eartips 647",angles[647],convex[647])
		-- end
	end
	
	local function update_ear(i)
		if not convex[ind[i]] then 
			eartips[ind[i]] = false
		else
			local make_urgent
			local empty = true
			local a,b,c = poly[ind[mod(i-1,#ind)]],poly[ind[i]],poly[ind[mod(i+1,#ind)]]
			
			local j
			if use_urgent and a == poly[ind[mod(i+2,#ind)]] then
				make_urgent = true
				j = mod(i+3,#ind)
			else
				j = mod(i+2,#ind)
			end
			
			local jlimit
			if use_urgent and c == poly[ind[mod(i-2,#ind)]] then
				make_urgent = true
				jlimit = mod(i-2,#ind)
			else
				jlimit = mod(i-1,#ind)
			end
			-- assert(not (a == poly[ind[j]]))
			-- assert(not (c== poly[ind[mod(jlimit-1,#ind)]]))
			while j~=jlimit do
				if not convex[ind[j]] and 
				IsPointInTri(poly[ind[j]],a,b,c) then
					empty = false
					break
				end
				-- if CG.SegmentIntersect(a,c,poly[ind[j]],poly[ind[mod(j+1,#ind)]]) then
					-- empty = false
					-- break
				-- end
				j = mod(j+1,#ind)
			end
			eartips[ind[i]] = empty
			
			if make_urgent and eartips[ind[i]] then
				table.insert(urgent_queue,i)
				urgent_eartips[ind[i]] = true
			end
		end
	end
	
	local function create_tr_update(i,create,dontremove)
		--print("create_tr_update",i,create,#ind)
		--check_collinear(poly,ind,"before trupdate "..i)
		local zeroarea
		local b = ind[i]
		table.remove(ind,i)
		---[=[
		--remove if consecutive repeat of point
		if not dontremove then
		while poly[ind[mod(i-1,#ind)]] == poly[ind[mod(i,#ind)]] do
		--if poly[ind[mod(i-1,#ind)]] == poly[ind[mod(i,#ind)]] then
			i = mod(i,#ind)
			table.remove(ind,i)
			zeroarea = true
			if #ind == 2 then return end
		end
		end
		--]=]
		i = mod(i,#ind)
		
		while repair1collinear(poly,ind,mod(i-1,#ind)) do end
		while repair1collinear(poly,ind,mod(i,#ind)) do end
		--check_collinear(poly,ind,"after trupdate "..i)
		
		i = mod(i,#ind)
		local a,c = ind[mod(i-1,#ind)],ind[mod(i,#ind)]
		local am1,cM1 = ind[mod(i-2,#ind)],ind[mod(i+1,#ind)]
		
		--print("----------create tr",a,b,c,poly[a]*4,poly[b]*4,poly[c]*4,#ind)
		
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
		--check_collinear(poly,ind,"end trupdate "..i)
	end
	
	---- main
	
	for i,v in ipairs(poly) do ind[i] = i end
	
	--check_collinear(poly,ind,"initial")
	update_all_ears()
	local last_uae
	local last_uae2
	while #ind > 2 do
		--check_collinear(poly,ind,"main loop")
		local initind = #ind
		--find smallest angle eartips
		local has_eartip = false
		local minang = math.huge
		local mineartipI 
		
		while #urgent_queue > 0 do
			mineartipI = table.remove(urgent_queue)
			if urgent_eartips[ind[mineartipI]] then
				urgent_eartips[ind[mineartipI]] = false
				has_eartip = true
				break
			end
		end
		
		if not has_eartip then
		for i=1,#ind do
			if eartips[ind[i]] then
				has_eartip = true
				if angles[ind[i]] < minang then
					minang = angles[ind[i]]
					mineartipI = i
					--break --sequential
				end
			end
		end
		end
		
		assert(minang>=0)
		if has_eartip then
			-- if ind[mineartipI] == 647 then
				-- print("647 B",Angle(poly[646],poly[647],poly[648]))
				-- print(angles[647],convex[647])
			-- end
			create_tr_update(mineartipI,true)
		else
			-- try to repair
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
					local a,b,c,d = i,mod(i+1,#ind),mod(i+2,#ind),mod(i+3,#ind)
					if CG.SegmentIntersect(poly[a],poly[b],poly[c],poly[d]) then 
						print("self intersecting triangle")
						print("deleting vi+1")
						create_tr_update(c,true)--,true)
						print("deleting vi")
						create_tr_update(mod(c-1,#ind),true)--,true)
						repaired = true
						
						break
					end
				end
			end
			
			if not repaired then
			for i=1,#ind do
				local j = mod(i+1,#ind)
				if poly[ind[i]]==poly[ind[j]] then
					print("consecutive repeat repaired",ind[i])
					create_tr_update(i,false)
					repaired = true
					break
				end
			end
			end
			
			if not repaired then
				print"trying repiair1collinear"
				for i=1,#ind do
				--[=[
					local a,b,c = poly[ind[mod(i-1,#ind)]],poly[ind[i]],poly[ind[mod(i+1,#ind)]]
					local ang,conv,s,cose = CG.Sign(a,b,c)
					if (s==0) then
						local angle,conv,s,cose = Angle(a,b,c)
						if not angle==0 then
							print("collinear repaired",ind[i],angle,conv,s,cose)
							create_tr_update(i,false)
							repaired = true
							break
						end
					end
				--]=]
					if repair1collinear(poly,ind,i) then repaired = true end
				end
			end
			-- if not repaired and last_uae2 ~= #ind then
				-- print"update_all_ears with IsPointInTri"
				-- IsPointInTri = CG.IsPointInTri
				-- update_all_ears()
				-- repaired = true
				-- last_uae2 = #ind
			-- end
			if not repaired then break end
		end
	end	
	if #ind > 2 then
		print("\n--------restpoly",#ind)
		for i,v in ipairs(ind) do print(i,ind[i],convex[ind[i]], angles[ind[i]]) end
		print"-------endrestpoly"
		local restpoly = {}
		for i,v in ipairs(ind) do restpoly[#restpoly+1] = poly[ind[i]] end
		print("rest poly check simple------")
		CG.check_simple(restpoly,true)
		print("rest poly check self crossings------")
		local cc = require"anima.CG3.check_poly"
		local ret = cc.check_self_crossings(restpoly)
		if #ret>0 then print(#ret,"self crossings found") end
		return poly,tr,false,restpoly
	end	
	return poly,tr,true
end



--[[
local mat = require"anima.matrixffi"
local vec2 = mat.vec2
local poly = {vec2(0,0),vec2(0,2),vec2(2,0)}
poly.holes = {{vec2(0.5,1),vec2(1,0.5),vec2(1.5,1.5)}}
prtable(poly)

prtable(EarClipFIST(poly))
--]]
--return EarClipFIST