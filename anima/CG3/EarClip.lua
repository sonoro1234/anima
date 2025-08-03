local CG = require"anima.CG3.base"
local M = CG

local function mod(a,b)
	if a<1 or a>b then return ((a-1)%b)+1 end
	--return ((a-1)%b)+1
	return a
end

local Sign = CG.Sign
local IsPointInTri = CG.IsPointInTri
local Angle = CG.Angle

--Triangulation by Ear Clipping
--David Eberly
local function InsertHoles2(poly)
	if not poly.holes then
		return poly
	end
	holes = poly.holes
	--first fusion holes with poly
	--find hole with max X point
	local nproc = 0
	while #holes>0 do
		--if nproc == 2 then return poly end
		nproc = nproc + 1
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
		local I = Mp + mat.vec2(math.huge,0) --mat.vec3(math.huge, 0,0)
		local edge
		for i=1,#poly do
			local a,b = poly[i],poly[mod(i+1,#poly)]
			if (a.x < Mp.x and b.x < Mp.x) then goto CONTINUE end
			if a.x > I.x and b.x > I.x then goto CONTINUE end
			if (a.y <= Mp.y and Mp.y <= b.y) or (b.y <= Mp.y and Mp.y <= a.y) then
				local Ite = CG.intersectSegmentX(a,b,Mp)
				--local Ite2 = CG.IntersecPoint2(a,b,Mp,Mp+mat.vec2(1,0))
				--if Ite ~= Ite2 then print("bad Ite",Ite,Ite2); error"bad Ite" end
				if Ite.x < I.x then
					edge = i
					I = Ite
					--print(nproc,"Ite",Ite,"edge",i,"Mp",Mp)
				end
			end
			::CONTINUE::
		end

		assert(edge)

		--if I is a or a+1 this is visible point
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
		--print("VV",VV,"isendpoint",isendpoint)
		if not isendpoint then
			local P = poly[VV]
			--print("Rayintersec",a,b,Mp,P)
			--check all reflex (not convex) poly vertex are outside triangle MpIP
			local mintan = math.huge
			local Ri
			for i=1,#poly do
				local a,b,c = poly[mod(i-1,#poly)],poly[i],poly[mod(i+1,#poly)]
				if CG.Sign(a,b,c) < 0 then --is reflex
					if M.IsPointInTri(b,Mp,I,P) then
						--keep angle
						local MR = b-Mp
						local tan = math.abs(math.atan2(MR.y,MR.x))
						--print("Reflex point",i,b,tan)
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
		if hasC then badcross=true;print("badcross",#ind);break; end
		
		for i,v in ipairs(ind) do
			--is convex?
			local a,b,c = ind[mod(i-1,#ind)],ind[i],ind[mod(i+1,#ind)]
			local s = Sign(poly[a],poly[b],poly[c])*CWfac
			if s > 0 then --convex
				--print("test",a,b,c,s,CG.TArea(poly[a],poly[b],poly[c]))
				local empty = true
				--test empty
				local jlimit = mod(i-1,#ind)
				local j = mod(i+2,#ind)
				--local jlimit = mod(a-1,#poly)
				--local j = mod(a+2,#poly)
				while j~=jlimit do
					local intri = CG.IsPointInTri(poly[ind[j]],poly[a],poly[b],poly[c])
					--local intri = CG.IsPointInTri(poly[j],poly[a],poly[b],poly[c])
					if intri 
					--and Sign(poly[ind[mod(j-1,#ind)]],poly[ind[j]],poly[ind[mod(j+1,#ind)]])>0 
					then
						empty = false
						break
					end
					j = mod(j+1,#ind)
					--j = mod(j+1,#poly)
				end
				--[=[
				-- test cut line
				if empty then
				local jlimit = mod(i-1,#ind)
				local j = mod(i+2,#ind)
				while j~=jlimit do 
					local j2 = mod(j+1,#ind)
					local d = poly[ind[j]]
					local e = poly[ind[j2]]
					local inter = CG.SegmentIntersect(d,e,poly[a],poly[b])
					if inter then empty = false; break end
					inter = CG.SegmentIntersect(d,e,poly[b],poly[c])
					if inter then empty = false; break end
					inter = CG.SegmentIntersect(d,e,poly[c],poly[a])
					if inter then empty = false; break end
					j = j2
				end
				end
				--]=]
				
				
				if empty then
					table.remove(ind,i)
					table.insert(tr,a-1)
					table.insert(tr,b-1)
					table.insert(tr,c-1)
					--local co,bb = coroutine.running()
					--if not bb then coroutine.yield(tr, true) end
					break
				end
			end
		end
		if (initind == #ind) then
			print("EarClipSimple failed to find ear, no convex is",not_convex,#ind) 
			local repaired = false
			--find consecutive repeated
			for i=1,#ind do
				local j = mod(i+1,#ind)
				if poly[ind[i]]==poly[ind[j]] then 
					table.remove(ind,i)
					repaired = true
					print("consecutive repeat repaired",ind[i])
					break
				end
			end
			--find collinear
			if not repaired then
			for i=1,#ind do
				local a,b,c = poly[ind[mod(i-1,#ind)]],poly[ind[i]],poly[ind[mod(i+1,#ind)]]
				--local ang,conv,s,cose = CG.Sign(a,b,c)
				local s = CG.Sign(a,b,c)
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
		print"EarClipSimple badcross"
		local restpoly = {}
		for i,v in ipairs(ind) do restpoly[#restpoly+1] = poly[ind[i]] end
		return tr,false,restpoly
	end
	return tr,true
end
CG.EarClipSimple = EarClipSimple



--local CHK = require"anima.CG3.check_poly"

function check_self_repetition(poly)
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
local function EarClipSimple2(poly, use_closed)

	--if poly.holes then
	poly = CG.InsertHoles(poly,false)
		--assert(poly.EQ)
		--print("poly is",poly)
		--prtable(poly.br_equal)
	--end
	--[=[
	prtable(poly.bridges,poly.br_equal)
	
	local reps = {}
	local repseq = {}
	if poly.br_equal then
		reps = check_self_repetition(poly)
	--prtable(reps)
	for i=1,#reps do
		local r = reps[i]
		repseq[r[1]]=r[2]
		repseq[r[2]]=r[1]
		print(r[1],r[2])
		--assert(poly.br_equal[r[1]]==r[2])
		--assert(poly.br_equal[r[2]]==r[1])
	end
	local count = 0
	for k,v in pairs(poly.br_equal) do count = count + 1 end
	--assert(count == 2*#reps)
	for k,v in pairs(poly.br_equal) do
		print("--",k,v,repseq[k])
		assert(repseq[k]==v)
	end
	end
	--]=]
	--do return poly,{},true end
	
	
	--local EQ = poly.EQ
	--prtable(EQ)
	--local br_equal = poly.br_equal or {}
	poly.EQ = nil
	poly.br_equal = nil
	poly.bridges = nil
	
	local IsPointInTriI
	if use_closed then
		IsPointInTriI = function(pti,ai,bi,ci)
			local p,a,b,c = poly[pti],poly[ai],poly[bi],poly[ci]
		--[[
			if EQ:equal(ai,pti) or EQ:equal(bi,pti) or EQ:equal(ci,pti) then
				--assert(CG.IsPointInTriC(poly[pti],poly[ai],poly[bi],poly[ci]))
				return CG.IsPointInTri(poly[pti],poly[ai],poly[bi],poly[ci])
			end
			return CG.IsPointInTriC(poly[pti],poly[ai],poly[bi],poly[ci])
			--]]
			
			local isintri = CG.IsPointInTriC(p, a, b, c)
			--[=[
			if isintri and (EQ:equal(ai,pti) or EQ:equal(bi,pti) or EQ:equal(ci,pti)) then
				return CG.IsPointInTri(p,a,b,c)
			end
			--]=]
			---[=[
			if isintri then
				if p==a or p==b or p==c then 
					return false 
				end
			end
			--]=]
			return isintri
		end
	else
		IsPointInTriI = function(pti,ai,bi,ci)
			local p,a,b,c = poly[pti],poly[ai],poly[bi],poly[ci]
			--if p==a or p==b or p==c then return false end
			local isintri = CG.IsPointInTri(p,a,b,c)
			return isintri
		end
	end
	
	local CE1differs = false
	local ind = {}
	local tr = {}
	local angles = {}
	local convex = {}
	local eartips = {}
	for i,v in ipairs(poly) do ind[i] = i end
	
	local function InConeConvex(pt,a,b,c)
		--print("InConeConvex",CG.Sign(a,b,pt), CG.Sign(b,c,pt))
		return CG.Sign(a,b,pt)>0 and CG.Sign(b,c,pt)>0
	end
	local function InConeReflex(pt,a,b,c)
		--print("InConeReflex",CG.Sign(a,b,pt), CG.Sign(b,c,pt))
		return not (CG.Sign(a,b,pt)<=0 and CG.Sign(b,c,pt)<=0)
	end
	
	local function areEQequal(a,b,c,d)
		return EQ:equal(a,b) or EQ:equal(a,c) or EQ:equal(a,d) or EQ:equal(b,c) or EQ:equal(b,d) or EQ:equal(c,d)
	end
	
	local function checkCE1_3(i)
		local vm2,ai,bi,ci,vM2 = ind[mod(i-2,#ind)],ind[mod(i-1,#ind)],ind[i],ind[mod(i+1,#ind)],ind[mod(i+2,#ind)]
		if convex[ci] then
			if vM2~=ai 
			--and not EQ:equal(vM2,ai) and not EQ:equal(vM2,bi) and not EQ:equal(vM2,ci)
			and not areEQequal(ai,bi,ci,vM2)
			and not InConeConvex(poly[ai],poly[bi],poly[ci],poly[vM2]) then return false end
		else
			if vM2~=ai 
			--and not EQ:equal(vM2,ai) and not EQ:equal(vM2,bi) and not EQ:equal(vM2,ci) 
			and not areEQequal(ai,bi,ci,vM2)
			and not InConeReflex(poly[ai],poly[bi],poly[ci],poly[vM2]) then return false end
		end
		if convex[ai] then
			if vm2~=ci 
			--and not EQ:equal(vm2,ci) 
			and not areEQequal(ai,bi,ci,vm2)
			and not InConeConvex(poly[ci],poly[vm2],poly[ai],poly[bi]) then return false end
		else
			if vm2~=ci 
			--and not EQ:equal(vm2,ci) 
			and not areEQequal(ai,bi,ci,vm2)
			and not InConeReflex(poly[ci],poly[vm2],poly[ai],poly[bi]) then return false end
		end
		return true
	end
	
	local function checkCE1(i)
		--check CE1
		local vm2,ai,bi,ci,vM2 = ind[mod(i-2,#ind)],ind[mod(i-1,#ind)],ind[i],ind[mod(i+1,#ind)],ind[mod(i+2,#ind)]
		-- if bi==169 or bi==209 or bi == 216 then
			-- print("indexes:",vm2,ai,bi,ci,vM2,areEQequal(vm2,ai,bi,ci),areEQequal(vM2,ai,bi,ci))
		-- end
		--not intersecting polygon edges 
		---[[
		local aai,bbi = ind[#ind],ind[1]
		if ai~=aai and ai~=bbi and ci~=aai and ci~=bbi
		and not EQ:equal(ai,aai) and not EQ:equal(ai,bbi) and not EQ:equal(ci,aai) and not EQ:equal(ci,bbi)
		then
			if CG.SegmentIntersectC(poly[ai],poly[ci],poly[aai],poly[bbi]) then
				return false
			end
		end
		for i=1,#ind-1 do
			local aai,bbi = ind[i],ind[i+1]
			if ai~=aai and ai~=bbi and ci~=aai and ci~=bbi 
			and not EQ:equal(ai,aai) and not EQ:equal(ai,bbi) and not EQ:equal(ci,aai) and not EQ:equal(ci,bbi) 
			then
			if CG.SegmentIntersectC(poly[ai],poly[ci],poly[aai],poly[bbi]) then
				return false
			end
			end
		end
		--]]
		--------
		return checkCE1_3(i)
	end

	local function update_all_ears_init()
		for i=2,#ind-1 do
			angles[i],convex[i] = Angle(poly[i-1],poly[i],poly[i+1])
		end
		angles[1],convex[1] = Angle(poly[#ind],poly[1],poly[2])
		angles[#ind],convex[#ind] = Angle(poly[#ind-1],poly[#ind],poly[1])
		
		
		--find eartips
		for i=1,#ind do
			if convex[i] then
				local empty = true
				local ai,bi,ci = ind[mod(i-1,#ind)],ind[i],ind[mod(i+1,#ind)]
				local a,b,c = poly[mod(i-1,#ind)],poly[i],poly[mod(i+1,#ind)]
				local jlimit = mod(i-1,#ind)
				local j = mod(i+2,#ind)
				while j~=jlimit do
					if not convex[j] and 
					--if 
					--CG.IsPointInTriC(poly[j],a,b,c) then
					IsPointInTriI(j,ai,bi,ci) then
						empty = false
						break
					end
					j = mod(j+1,#ind)
					-- j = j + 1
					-- if j > #ind then j = 1 end
				end
				eartips[i] = empty
			end
		end
	end
	
	local function update_all_ears()
		for i=2,#ind-1 do
			angles[ind[i]],convex[ind[i]] = Angle(poly[ind[i-1]],poly[ind[i]],poly[ind[i+1]])
		end
		angles[ind[1]],convex[ind[1]] = Angle(poly[ind[#ind]],poly[ind[1]],poly[ind[2]])
		angles[ind[#ind]],convex[ind[#ind]] = Angle(poly[ind[#ind-1]],poly[ind[#ind]],poly[ind[1]])
		
		
		--find eartips
		for i=1,#ind do
			if convex[ind[i]] then
				local empty = true
				local ai,bi,ci = ind[mod(i-1,#ind)],ind[i],ind[mod(i+1,#ind)]
				--local a,b,c = poly[ai],poly[bi],poly[ci]
				local jlimit = mod(i-1,#ind)
				local j = mod(i+2,#ind)
				while j~=jlimit do
					if not convex[ind[j]] and 
					--if --IsPointInTri(poly[j],a,b,c)
						IsPointInTriI(ind[j],ai,bi,ci)
					then
						empty = false
						break
					end
					j = mod(j+1,#ind)
					-- j = j + 1
					-- if j > #ind then j = 1 end
				end
				--local emptyCE1 = checkCE1(i) 
				--empty = empty and checkCE1_3(i)
				--[[
				if emptyCE1~=empty then 
					print("---------CE1 differs1",bi,empty,emptyCE1,EQ:has(ai),EQ:has(bi),EQ:has(ci));
					CE1differs = true
					error"CE1 differs" 
				end
				--]]
				eartips[ind[i]] = empty --and emptyCE1
			end
		end
	end
	
	update_all_ears_init()
	--[=[
	for kk=1,#ind do
		print(kk,ind[kk],convex[ind[kk]],eartips[ind[kk]],angles[ind[kk]])
	end
	do return poly,{},false,poly end
	--]=]
	local function update_ear(i)
		if not convex[ind[i]] then 
			eartips[ind[i]] = false
		else
			local empty = true
			local ai,bi,ci = ind[mod(i-1,#ind)],ind[i],ind[mod(i+1,#ind)]
			--local a,b,c = poly[ai],poly[bi],poly[ci]
			local jlimit = mod(i-1,#ind)
			local j = mod(i+2,#ind)
			while j~=jlimit do
				if not convex[ind[j]] and 
				--if --IsPointInTri(poly[ind[j]],a,b,c) 
					IsPointInTriI(ind[j],ai,bi,ci)
				then
					empty = false
					break
				end
				--j = mod(j+1,#ind)
				j = j + 1
				if j > #ind then j = 1 end
			end
			--local emptyCE1 = checkCE1(i)
			--empty = empty and checkCE1_3(i)
			--[[
			if emptyCE1~=empty then 
				print("-----------CE1 differs2",bi,empty,emptyCE1,EQ:has(ai),EQ:has(bi),EQ:has(ci));
				CE1differs = true
				error"CE1 differs" 
			end
			--]]
			eartips[ind[i]] = empty --and emptyCE1
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
		if #ind > 2 then
			angles[a],convex[a] = Angle(poly[am1],poly[a],poly[c])
			angles[c],convex[c] = Angle(poly[a],poly[c],poly[cM1])
			update_ear(mod(i-1,#ind)) --for a
			update_ear(mod(i,#ind)) --for c
		end
		if create then
			--print("create",a,b,c)
			table.insert(tr,a-1)
			table.insert(tr,b-1)
			table.insert(tr,c-1)
			--local co,bb = coroutine.running()
			--if not bb then coroutine.yield(poly,tr,true,nil,nil,eartips, convex,angles,ind) end
		end
	end
	--first bridges
	--[=[
	local function checkusebridge(indi)
		if not indi then return false end
		local ai,bi,ci = ind[mod(indi-1,#ind)],indi,ind[mod(indi+1,#ind)]
		for i=1,#ind do
			local aai,bbi = ind[i],ind[mod(i+1,#ind)]
			if ai~=aai and ai~=bbi and ci~=aai and ci~=bbi 
			--and not EQ:equal(ai,aai) and not EQ:equal(ai,bbi) and not EQ:equal(ci,aai) and not EQ:equal(ci,bbi) 
			then
			if CG.SegmentIntersectC(poly[ai],poly[ci],poly[aai],poly[bbi]) then
				return false
			end
			end
		end
		return true
	end
	if poly.bridges then
	for k,v in pairs(poly.bridges) do
		print("first bridges",k ,#ind)
		local indi 
		for i=1,#ind do if ind[i]==k then indi=i;break end end
		--check if possible
		if checkusebridge(indi) then
			print("isPosible true",k)
			create_tr_update(indi, true)
		end
		
		indi = nil
		for i=1,#ind do if ind[i]==k+1 then indi=i;break end end
		if checkusebridge(indi) then
			print("isPosible true",k+1)
			create_tr_update(indi, true)
		end
		--[[
		if not isposible then
			print("isPosible false",k)
			indi = nil
			for i=1,#ind do if ind[i]==k then indi=i;break end end
			create_tr_update(indi, true)
		end
		--]]
	end
	end
	--]=]
	
	local last_uae
	while --false do
	--#ind > 7 do
	#ind  > 2 do --and not CE1differs do 
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
				end
			end
		end
		assert(minang>=0)
		if not_eartips then
		
		--[=[
		do
			local restpoly = {}
			for i,v in ipairs(ind) do restpoly[#restpoly+1] = poly[ind[i]] end
			return poly,tr,false,restpoly
		end
		--]=]
		--[=[
		print"before repair"
		for kk=1,#ind do
			print(kk,ind[kk],convex[ind[kk]],eartips[ind[kk]],angles[ind[kk]])
		end
		--]=]
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
				print"not mineartipI"
				for i=1,#ind do
					if eartips[ind[i]] then
						print("angle",i,angles[ind[i]])
						print(poly[ind[mod(i-1,#ind)]],poly[ind[i]],poly[ind[mod(i+1,#ind)]])
					end
				end
			end
			--if (#poly-#ind) < 14 then
			--print("mineartipI",(#poly-#ind),ind[mineartipI],angles[ind[mineartipI]])
			-- for kk=1,#ind do
				-- if eartips[ind[kk]] then
				-- print(kk,ind[kk],convex[ind[kk]],eartips[ind[kk]],angles[ind[kk]])
				-- end
			-- end
			--end
			create_tr_update(mineartipI,true)
		end
	end	
	if #ind > 2 then
		local restpoly = {}
		for i,v in ipairs(ind) do restpoly[#restpoly+1] = poly[ind[i]] end
		print("return restpoly",#restpoly)
		return poly,tr,false,restpoly,ind
	end	
	--print("poly2 is",poly)
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
		print(P[1],P[2],P[3])
		error("collinear points")
	end

	for i=4,#P do
		--up and down
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
		--update Q for convex hull: add i between d and u
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
		-- assert(Sign(P[tr[i]+1],P[tr[i+1]+1],P[tr[i+2]+1]) > 0)
		-- if Sign(P[tr[i]+1],P[tr[i+1]+1],P[tr[i+2]+1]) < 0 then
			-- tr[i+1],tr[i+2] = tr[i+2],tr[i+1]
		-- end
	-- end
	return CH,tr
end
