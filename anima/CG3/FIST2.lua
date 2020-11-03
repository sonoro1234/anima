--Robust EarClip with holes
--with lexicografic ordered set for SignI consistency
--much slower than FIST1 more robust
local CG = require"anima.CG3"--.base"


local function mod(a,b)
	return ((a-1)%b)+1
end

local function leftmostvertexInd(poly)
	local minx = math.huge
	local mini
	for i,p in ipairs(poly) do
		if p < minx then
			minx = p
			mini = i
		end
	end
	return minx,mini
end

-----------------------------------------------------------------------
local algo = require"anima.algorithm.algorithm"

--with holes
local function lexicografic_sort_ind(P)
	local P2 = {}
	for i=1,#P do
		P2[i] = P[i]
	end
	if P.holes then
		for ih,hole in ipairs(P.holes) do
			for i=1,#hole do
				P2[#P2+1] = hole[i]
			end
		end
	end
	algo.quicksort(P2,1,#P2,CG.lexicografic_compare)
	
	--delete repeated
	for i,v in ipairs(P2) do
		while i<#P2 and v==P2[i+1] do table.remove(P2,i+1) end
	end
	--generate indices of P in P2
	local Ind = {P=P2}
	for i,v in ipairs(P) do
		Ind[i] = CG.lexicografic_find(P2,v)
	end
	if P.holes then
		Ind.holes = {}
		for ih,hole in ipairs(P.holes) do
			Ind.holes[ih] = {}
			local Indhole = Ind.holes[ih]
			for i,v in ipairs(hole) do
				Indhole[i] = CG.lexicografic_find(P2,v)
			end
		end
	end
	return Ind
end

CG.lexicografic_sort_ind = lexicografic_sort_ind
CG.poly2Ind = lexicografic_sort_ind

CG.Ind2poly = function(Ind)
	local poly = {}
	for i,ii in ipairs(Ind) do
		poly[i] = Ind.P[ii]
	end
	poly.holes = {}
	for nh,hole in ipairs(Ind.holes) do
		poly.holes[nh] = {}
		for i,ii in ipairs(hole) do
			poly.holes[nh][i] = Ind.P[ii]
		end
	end
	return poly
end

local function SignI(Ind, i1,  i2,  i3)
	if i1==i2 or i1==i3 or i2==i3 then return 0 end
	--order
	local si = 1
	if i1 > i2 then i1,i2 = i2,i1; si = -si end
	if i2 > i3 then i2,i3 = i3,i2; si = -si end
	if i1 > i2 then i1,i2 = i2,i1; si = -si end
	local p1, p2, p3 = Ind.P[i1], Ind.P[i2], Ind.P[i3]
	return si*((p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y));
end

--say if interiors of segments a-b c-d overlap
local function SegmentIntersectInd(Ind,a,b,c,d)
	local sc,sd = SignI(Ind,c,b,a),SignI(Ind,d,b,a)
	local sgabcd = SignI(Ind,a,d,c)*SignI(Ind,b,d,c)
	return (sc*sd < 0) and (sgabcd < 0),sc,sd
end

local function check_crossingsInd(Ind,verbose)
	local has_cros = false
	for i=1,#Ind do
		local ai,bi = i,mod(i+1,#Ind)
		local a,b = Ind[ai],Ind[bi]
		for j=i+2,#Ind do
			local ci,di = j,mod(j+1,#Ind)
			local c,d = Ind[ci],Ind[di]
			if SegmentIntersectInd(Ind,a,b,c,d) then
				if verbose then print("self crossing",ai,bi,ci,di) end
				has_cros = true
			end
		end
	end
	return has_cros
end

local check_point_repetitionInd = CG.check_point_repetition

local function check_simpleI(poly,verbose,verb2)
	if verb2==nil then verb2 = verbose end
	return check_crossingsInd(poly,verbose),check_point_repetitionInd(poly,verb2) 
end

local function IsPointInTriCInd(Ind, ip,  i1,  i2,  i3)
	
	local b1, b2, b3;

	b1 = SignI(Ind, ip, i1, i2) ;
	b2 = SignI(Ind, ip, i2, i3) ;
	b3 = SignI(Ind, ip, i3, i1) ;
	
	return (b1<=0 and b2<=0 and b3<=0) or (b1>=0 and b2>=0 and b3>=0)
end

local acos = math.acos
local function AngleI(Ind,i1,i2,i3)
	i1,i3 = i3,i1 --CCW
	--assert(p1~=p2 and p2~=p3) --would give nan as angle
	if i1==i2 or i2==i3 then
		error("Angle called with p1==p2 or p2==p3")
		return math.pi*0.5,true,0,0
	end
	
	local p1, p2, p3 = Ind.P[i1], Ind.P[i2], Ind.P[i3]
	
	local a = p1-p2
	local b = p3-p2
	local cose = a*b/(a:norm()*b:norm())
	--if cose > 1 or cose < -1 then print(p1,p2,p3);print(a,b); error"bad cose" end
	--happening when a = l*b
	cose = (cose > 1 and 1) or (cose < -1 and -1) or cose
	--assert(not cose==1) --0 or 360
	local ang = acos(cose)
	local s = SignI(Ind,i1,i2,i3)
	if s==0 then
		if cose < 0 then return ang,false,s,cose
		else return 0,true,s,cose end
	elseif s <0 then return ang,true,s,cose 
	else return 2*math.pi-ang,false ,s,cose
	end
end

--avoid crossings with list lexicografic sorted
local function PolySimplifyNC_Ind1(poly,Ind,list,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	
	
	local toremove = {}
	--find maxx minx
	local minx,maxx = math.huge, -math.huge
	local im,iM
	for i=1,#poly do
		local p = poly[i]
		if minx > p then minx = p; im = i end
		if maxx < p then maxx = p; iM = i end
		toremove[i] = false
	end
	
	local function mod(a,b)
		return ((a-1)%b)+1
	end
	
	local function FF(i,j)
		if i==j then return end
		local k = mod(i+1,#poly)
		if j == k then return end
		
		local a,b = Ind.P[poly[i]],Ind.P[poly[j]]
		local ab = (b-a):normalize()
		local N = vec2(ab.y,-ab.x)
		local maxd,kmax = -math.huge
		
		
		while k~=j do
			--assert(not toremove[k])
			if toremove[k] then
				print("simp error: #poly",#poly,i,j,mod(i+1,#poly),k)
				error"polysimp"
			end
			local dis = math.abs((Ind.P[poly[k]]-a)*N)
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
					if IsPointInTriCInd(Ind,pt,a,b,c) then
						--assert(CG.IsPointInTriC(Ind.P[pt],Ind.P[a],Ind.P[b],Ind.P[c]))
						empty = false
						break
					else
						--assert(not CG.IsPointInTriC(Ind.P[pt],Ind.P[a],Ind.P[b],Ind.P[c]))
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
					local li = CG.binary_search(list,poly[k],function(a,b) return a<b end)
					--local li = CG.lexicografic_find(list, poly[k])
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
local function PolySimplifyNC_Ind(Ind,eps)
	local mat = require"anima.matrixffi"
	local vec2 = mat.vec2
	
	eps = eps or math.sqrt(2)*0.5 --half diagonal pixel length, good after image vectorization
	
	local removed = 0
	
	local list = {}
	--local list2 = {}
	--for i=1,#Ind.P do list2[i] = i end --not good if poly was repaired
	for i,pt in ipairs(Ind) do
		list[#list+1] = pt
	end
	if #Ind.holes> 0 then 
		--make list
		for nh,hole in ipairs(Ind.holes) do
			for i,pt in ipairs(hole) do
				list[#list+1] = pt
			end
		end
	end
	
	algo.quicksort(list,1,#list,function(a,b) return a<b end)
	--prtable(list)
	--delete repeated
	for i,v in ipairs(list) do
		while i<#list and v==list[i+1] do table.remove(list,i+1) end
	end
	--if not (#list==#list2) then print("#list==#Ind.P",#list,#Ind.P);prtable(list,list2); error"dddd" end
	
	if #Ind.holes> 0 then 
		for nh,hole in ipairs(Ind.holes) do
			local _,removedS = PolySimplifyNC_Ind1(hole,Ind,list,eps)
			removed = removed + removedS
		end
	end
	
	local _,removedS = PolySimplifyNC_Ind1(Ind,Ind,list,eps)
	removed = removed + removedS
	
	return removed
end

CG.PolySimplifyNC_Ind = PolySimplifyNC_Ind

local function InsertHoles(Ind,skip_check)

	local algo = require"anima.algorithm.algorithm"
	local holes = Ind.holes
	
	---[=[
	--check hole dont intersect poly or other holes
	--first poly with holes
	if not skip_check then
	for i,p in ipairs(Ind) do
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
	local holes_order = {}
	for i,hole in ipairs(holes) do
		
		local minx,mini = leftmostvertexInd(hole)
		holes_order[i] = {i=i,minx=minx,mini=mini}
		--assert(not CG.IsPointInPoly(poly,hole[mini]))
	end

	-- table.sort(holes_order,function(a,b) return a.minx < b.minx end)
	algo.quicksort(holes_order, 1, #holes_order, function(a,b) return a.minx < b.minx end)
	for i,horder in ipairs(holes_order) do
		--prtable(horder)
		local hole = holes[horder.i]
		local minx = horder.minx
		local minv = hole[horder.mini]
		--print("minv",minv)
		--sort outer vertex to the left according to distance
		local sortedp = {}
		for j,p in ipairs(Ind) do
			if p < minx then
				sortedp[#sortedp+1] = {j=j,dist=(Ind.P[minv]-Ind.P[p]):norm()}
			end
		end
		-- table.sort(sortedp,function(a,b) return a.dist < b.dist end)
		algo.quicksort(sortedp, 1, #sortedp, function(a,b) return a.dist < b.dist end)
		--test then to find bridge
		local bridgedone = false
		for j,dd in ipairs(sortedp) do
			local found = true
			for k,p in ipairs(Ind) do
				if SegmentIntersectInd(Ind,minv,Ind[dd.j],p,Ind[mod(k+1,#Ind)]) then
					found = false
					break
				end
			end
			if found then
				--create bridge minv to poly(dd.j)
				local newpoly = {}
				for ii=1,dd.j do
					newpoly[ii] = Ind[ii]
				end
				for ii=0,#hole-1 do
					newpoly[#newpoly+1] = hole[mod(ii+horder.mini,#hole)]
				end
				newpoly[#newpoly+1] = hole[horder.mini]
				local indmini = #newpoly
				for ii=dd.j,#Ind do
					newpoly[#newpoly+1] = Ind[ii]
				end
				--poly = newpoly
				for i,ii in ipairs(newpoly) do
					Ind[i] = ii
				end
				--print("bridge added",i,"was",horder.i,horder.mini,"inds",dd.j,dd.j+1,indmini,indmini+1)
				if check_crossingsInd(Ind,true) then
					print("bad bridge insertion of hole",i,"was",hole)
					error"bad bridge"
				end
				bridgedone = true
				break
			end
		end
		if not bridgedone then error"not bridge" end
	end
	--poly.holes = {}
	--return poly
end

local function remove_colinearInd(Ind,pt,verbose)

	local colin = {}
	local numpt = #pt
	for i=1,numpt do
		local ang,conv,s,cose = AngleI(Ind,pt[mod(i-1,numpt)],pt[i],pt[mod(i+1,numpt)])
		if s==0 then  
			if cose<0 then
				colin[#colin+1] = i
			elseif pt[mod(i-1,numpt)]==pt[mod(i+1,numpt)] then --cose>0 and repeated
				print("remove_colinearInd finds consec repeat",mod(i-1,numpt),mod(i+1,numpt),pt[mod(i-1,numpt)],pt[mod(i+1,numpt)])
				colin[#colin+1] = i
			end
		end
	end
	for i=#colin,1,-1 do
		if verbose then print("collinear removes",colin[i]) end
		table.remove(pt,colin[i]) end
	return #colin
end

local function remove_consec_repeatedInd(Ind,verbose)
	local toremove = {}
	for i=1,#Ind-1 do
		if Ind[i]==Ind[i+1] then toremove[#toremove+1] = i end
	end
	if Ind[#Ind]==Ind[1] then toremove[#toremove+1] = #Ind end
	for i=#toremove,1,-1 do 
		if verbose then print("check_repeated deletes",toremove[i]); end
		table.remove(Ind,toremove[i]) end
	return #toremove
end

function degenerate_poly_repairInd(Ind,verbose)
	local rem = 0
	local rem2 = 0
	local round = 1
	while true do
	
	rem = rem + remove_consec_repeatedInd(Ind,verbose)
	for j=1,#Ind.holes do
		rem = rem + remove_consec_repeatedInd(Ind.holes[j],verbose)
		if #Ind.holes[j] == 0 then table.remove(Ind.holes,j) end
	end

	local rem3 = 0
	rem3 = rem3 + remove_colinearInd(Ind,Ind,verbose)
	for j=1,#Ind.holes do
		rem3 = rem3 + remove_colinearInd(Ind,Ind.holes[j],verbose,true)
		if #Ind.holes[j] == 0 then table.remove(Ind.holes,j) end
	end
	print("round",round,rem,rem3)
	if rem3==0 then break end
	round = round + 1
	rem2 = rem2 + rem3
	end
	return rem + rem2
end

CG.degenerate_poly_repairInd = degenerate_poly_repairInd

function CG.EarClipFIST2(Ind)

	
	--check it is simple
	local hasC,hasR = check_simpleI(Ind,false,false)
	if hasC  then 
		--do return Ind.P,{},false end
		error"crossing in not simple polygon"		
	end

	if Ind.holes and #Ind.holes > 0 then
		InsertHoles(Ind,true)
		
		--check it is simple again
		--print"checking outer poly-holes"
		local hasC,hasR = check_simpleI(Ind,false,false)
		if hasC then error"crossings in polygon with holes" end
	end
	
	local use_urgent = true
	local IsPointInTriInd = IsPointInTriCInd --CG.IsPointInTriInd
	
	local ind = {} --indices over Ind
	local tr = {}
	local angles = {}
	local convex = {}
	local eartips = {}
	local urgent_eartips = {}
	local urgent_queue = {}
	
	local function update_all_ears()
		--compute interior angles
		for i=1,#ind do
			angles[ind[i]],convex[ind[i]] = AngleI(Ind,Ind[ind[mod(i-1,#ind)]],Ind[ind[i]],Ind[ind[mod(i+1,#ind)]])
			--angles[ind[i]],convex[ind[i]] = AngleI(poly[ind[mod(i-1,#ind)]],poly[ind[i]],poly[ind[mod(i+1,#ind)]])
		end
		for i=1,#ind do
			if not convex[ind[i]] then goto continue end
			local make_urgent
			local empty = true
			local a,b,c = Ind[ind[mod(i-1,#ind)]],Ind[ind[i]],Ind[ind[mod(i+1,#ind)]]
			
			local j
			if use_urgent and a == Ind[ind[mod(i+2,#ind)]] then
				make_urgent = true
				j = mod(i+3,#ind)
			else
				j = mod(i+2,#ind)
			end
			
			local jlimit
			if use_urgent and c == Ind[ind[mod(i-2,#ind)]] then
				make_urgent = true
				jlimit = mod(i-2,#ind)
			else
				jlimit = mod(i-1,#ind)
			end
			
			while j~=jlimit do
				if not convex[ind[j]] and 
				IsPointInTriInd(Ind,Ind[ind[j]],a,b,c) then
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
			local a,b,c = Ind[ind[mod(i-1,#ind)]],Ind[ind[i]],Ind[ind[mod(i+1,#ind)]]
			
			local j
			if use_urgent and a == Ind[ind[mod(i+2,#ind)]] then
				make_urgent = true
				j = mod(i+3,#ind)
			else
				j = mod(i+2,#ind)
			end
			
			local jlimit
			if use_urgent and c == Ind[ind[mod(i-2,#ind)]] then
				make_urgent = true
				jlimit = mod(i-2,#ind)
			else
				jlimit = mod(i-1,#ind)
			end
			-- assert(not (a == poly[ind[j]]))
			-- assert(not (c== poly[ind[mod(jlimit-1,#ind)]]))
			while j~=jlimit do
				if not convex[ind[j]] and 
				IsPointInTriInd(Ind,Ind[ind[j]],a,b,c) then
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
		
		local zeroarea
		local b = ind[i]
		table.remove(ind,i)
		---[=[
		--remove if consecutive repeat of point
		if not dontremove then
		while Ind[ind[mod(i-1,#ind)]] == Ind[ind[mod(i,#ind)]] do
		--if poly[ind[mod(i-1,#ind)]] == poly[ind[mod(i,#ind)]] then
			i = mod(i,#ind)
			table.remove(ind,i)
			zeroarea = true
			if #ind == 2 then return end
		end
		end
		--]=]
		i = mod(i,#ind)
		local a,c = ind[mod(i-1,#ind)],ind[mod(i,#ind)]
		local am1,cM1 = ind[mod(i-2,#ind)],ind[mod(i+1,#ind)]
		
		--print("----------create tr",a,b,c,poly[a]*4,poly[b]*4,poly[c]*4,#ind)
		
		--update infos
		--remove eartip not necessary because ind is gone
		--update a and c
		angles[a],convex[a] = AngleI(Ind,Ind[am1],Ind[a],Ind[c])
		angles[c],convex[c] = AngleI(Ind,Ind[a],Ind[c],Ind[cM1])
		update_ear(mod(i-1,#ind)) --for a
		update_ear(mod(i,#ind)) --for c
		if create then
			table.insert(tr,Ind[a]-1)
			table.insert(tr,Ind[b]-1)
			table.insert(tr,Ind[c]-1)
		end
	end
	
	---- main
	for i,v in ipairs(Ind) do ind[i] = i end
	update_all_ears()
	local last_uae
	while #ind > 2 do
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
			print("\ntrying to repair",#ind)
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
					if SegmentIntersectInd(Ind,Ind[a],Ind[b],Ind[c],Ind[d]) then 
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
				if Ind[ind[i]]==Ind[ind[j]] then 
					create_tr_update(i,false)
					repaired = true
					print("consecutive repeat repaired",ind[i])
					break
				end
			end
			end
			
			if not repaired then
			for i=1,#ind do
				local a,b,c = Ind[ind[mod(i-1,#ind)]],Ind[ind[i]],Ind[ind[mod(i+1,#ind)]]
				local ang,conv,s,cose = SignI(Ind,a,b,c)
				if (s==0) then
					local angle,conv,s,cose = AngleI(Ind,a,b,c)
					if not angle==0 then
						print("collinear repaired",ind[i],angle,conv,s,cose)
						create_tr_update(i,false)
						repaired = true
						break
					end
				end
			end
			end
			if not repaired then break end
		end
	end	
	if #ind > 2 then
		print("\n--------restpoly",#ind)
		for i,v in ipairs(ind) do print(i,ind[i],convex[ind[i]], angles[ind[i]]) end
		print"-------endrestpoly"
		local restpoly = {}
		for i,v in ipairs(ind) do restpoly[#restpoly+1] = Ind.P[Ind[ind[i]]] end
		return Ind.P,tr,false,restpoly
	end	
	return Ind.P,tr,true
end

return CG

--[[
local mat = require"anima.matrixffi"
local vec2 = mat.vec2
local poly = {vec2(0,0),vec2(0,2),vec2(2,0)}
poly.holes = {{vec2(0.5,1),vec2(1,0.5),vec2(1.5,1.5)}}
prtable(poly)

prtable(EarClipFIST(poly))
--]]
--return EarClipFIST