local CG = require"anima.CG3.base"
local M = CG

local mod = CG.mod
local Sign = CG.Sign
--standard triangulation by sweep , ugly triangles
function CG.triang_sweept(P)


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

--helper for triang_sweept_monotone
local function getChains(P,polind)
    local lowerchain,upperchain = {},{}
	local is_lower = {}
	local doinglow
	for i,v in ipairs(polind) do
		if v==1 then --init lower chain
			doinglow = true
			for j=0,#polind-1 do
				local w = polind[mod(i+j,#polind)]
				if w==#P then doinglow = false end
				if doinglow then
					table.insert(lowerchain,w)
					is_lower[w] = true
				else
					table.insert(upperchain,w)
					is_lower[w] = false
				end
			end
			break
		end
	end
	--test monotone
	local monotone = true
	for i=2,#lowerchain do
		--assert(lowerchain[i]>lowerchain[i-1],"not monotone")
		if not (lowerchain[i]>lowerchain[i-1]) then monotone=false end
	end	
	for i=2,#upperchain do
		--assert(upperchain[i]<upperchain[i-1],"not monotone")
		if not (upperchain[i]<upperchain[i-1]) then monotone = false end
	end	
	return is_lower, monotone
end
--Dave Mount book
-- and also 
--Computational Geometry Algorithms and Applications
--by Mark de Berg and others
function CG.triang_sweept_monotone(P,polind)
	--prtable("triang_sweept_monotone",P,polind)

	assert(P.sorted,"points must be sorted")
	local insert,remove = table.insert, table.remove
	local tr = {}
	
	--for j=1,#polind do assert(polind[j],"nil innnnnn") end
	
	local is_lower, OK = getChains(P, polind)
	assert(OK, "not monotone")
	------
	local function same_chain(a,b)
		--local test1 = a==1 or a==#P or b==1 or b==#P
		return test1 or is_lower[a]==is_lower[b]
	end
	-- prtable("P",P)
	-- prtable("polind",polind)
	-- prtable("lowerchain",lowerchain)
	-- prtable("upperchain",upperchain)
	local stack = {1,2}
	local tr = {}
	for i=3,#P do
		--print("-----check p",i)
		--if is_lower[i]~=is_lower[stack[#stack]] then
		if not same_chain(i,stack[#stack]) then
			--make triangle with reflex chain
			--print"different chains"
			local stack2 = {stack[#stack],i}
			while #stack > 1 do
				local s = remove(stack)
				--TODO check orientation
				insert(tr,i-1)
				insert(tr,s-1)
				insert(tr,stack[#stack]-1)
				local sign = Sign(P[i],P[s],P[stack[#stack]])
				if sign < 0 then
					tr[#tr-1],tr[#tr] = tr[#tr],tr[#tr-1]
				end
				--print("triangle",i,s,stack[#stack])
				--print("sign",CG.Sign(P[tr[#tr-2]+1],P[tr[#tr-1]+1],P[tr[#tr]+1]))
				--prtable("stack",stack)
			end
			stack = stack2
			--prtable("stack2",stack)
		else
			--print"same chains"
			local test_sign = is_lower[i] and 1 or -1
			while #stack > 1 do 
				local sign = Sign(P[i],P[stack[#stack]],P[stack[#stack-1]])
				local sign2 = sign*test_sign
				if sign2<0 then
					insert(tr,i-1)
					insert(tr,stack[#stack]-1)
					insert(tr,stack[#stack-1]-1)
					if sign < 0 then
						tr[#tr-1],tr[#tr] = tr[#tr],tr[#tr-1]
					end
					--print("triangle",i,stack[#stack],stack[#stack-1])
					--print("sign",CG.Sign(P[tr[#tr-2]+1],P[tr[#tr-1]+1],P[tr[#tr]+1]))
					remove(stack)
				else
					break
				end
			end
			insert(stack,i)
			--prtable("stack2",stack)
		end
	end
	return tr
end
----------------------------- make_monotones
--partition some given contours into monotone contours
local function setEdge(E,a,b,c)
	E[a] = E[a] or {}
	E[a][b] = c
end
local function mod_pol(pol,i)
	return pol[mod(i,#pol)]
end

local PointInCone = CG.PointInCone
local function IsPointInCone(P,pi,a,b,c)
	local scone = Sign(P[a],P[b],P[c])
	local sab = Sign(P[a],P[b],P[pi])
	local sbc = Sign(P[b],P[c],P[pi])
	if scone < 0 then --right
		return not(sab<0 and sbc<0)
	else --left
		return sab > 0 and sbc > 0
	end

	--return PointInCone(P[pi],P[a],P[b],P[c])
end

local vec2 = mat.vec2
local function IntersecSweepLine(a,b,c)
	local den = (a.x - b.x)
	if den==0 then return 0,false end
	local t = (a.x - c.x)/den
	--return a + t*(b - a), true, t
	--return mat.vec2(a.x + t*(b.x - a.x),a.y + t*(b.y - a.y)),true,t
	return mat.vec2(a.x - t*den,a.y + t*(b.y - a.y)),true,t
end

local insert,remove = table.insert, table.remove
local function SplitPolygon(polinds,ip,a,b,invPolind,newindex)
	--printD("Splitpol",polinds,ip,a,b,invPolind,newindex)
	--printD("edge",polinds[ip][a],polinds[ip][b])
	--prtable("polind",polinds[ip])
	local bridges = invPolind.bridges
	--prtable("bridges pa",bridges[ip])
	
	local remove = table.remove
	local polind = polinds[ip]
	local PolA,PolB = {},{}
	--a,b = (a > b) and b,a or a,b
	if a>b then a,b = b,a end
	--print("a,b",a,b)
	--
	local PolB_len = 0
	for i=a,b do
		--insert(PolB,polind[i])
		local pi = polind[i]
		PolB_len = PolB_len +1
		PolB[PolB_len] = pi
		local dd = invPolind[pi]
		dd[ip] = nil
		dd[newindex] = PolB_len
	end
	--[[
	for i=1,a do
		--insert(PolA,polind[i])
		--PolA[i] = polind[i]
		local pi = polind[i]
		PolA[i] = pi
		invPolind[pi][ip] = i
	end
	local PolA_len = #PolA 
	for i=b,#polind do
		--insert(PolA,polind[i])
		local pi = polind[i]
		PolA_len = PolA_len + 1
		PolA[PolA_len] = pi
		invPolind[pi][ip]=PolA_len
	end
	--]]
	---[[
	--better performace keeping polind
	--for i=b-1,a+1,-1 do remove(polind,i) end
	--remove faster alternative
	local polind_len = #polind
	local aab = a+1-b
	for i=b,polind_len do 
		polind[aab+i] = polind[i]
	end
	for j=a+2+polind_len-b,polind_len do
		polind[j] = nil
	end
	------update invPolind
	--for i=a+1,#polind do 
	for i=1,#polind do
		local pi = polind[i]
		assert(pi)
		invPolind[pi][ip]=i
	end
	PolA = polind
	--]]
	--update bridges
	if bridges[ip] then
	bridges[ip] = {}
	local vertextoind = {}
	for i=1,#PolA do
		local vi = PolA[i]
		if vertextoind[vi] then 
			insert(vertextoind[vi],i)
		else
			vertextoind[vi] = {i}
		end
	end
	for kk,ss in pairs(vertextoind) do
		if #ss > 1 then bridges[ip][kk] = ss end
	end
	bridges[newindex] = {}
	vertextoind = {}
	for i=1,#PolB do
		local vi = PolB[i]
		if vertextoind[vi] then 
			insert(vertextoind[vi],i)
		else
			vertextoind[vi] = {i}
		end
	end
	for kk,ss in pairs(vertextoind) do
		if #ss > 1 then bridges[newindex][kk] = ss end
	end
	end
	--prtable("result split",PolA,PolB,bridges[ip],bridges[newindex])
	return PolA,PolB
	
	
end
local function MergePolygons(P,polinds,pa,ia,pb,ib,invPolind)
	print("MergePolygons",polinds,pa,ia,pb,ib,invPolind)
	print("edge",polinds[pa][ia],polinds[pb][ib])
	--prtable("polinds",polinds[pa],polinds[pb])
	
	local PolA,PolB = polinds[pa],polinds[pb]
	local va,vb = PolA[ia],PolB[ib]
	local bridges = invPolind.bridges
	
	--prtable("bridges pa and pb",bridges[pa],bridges[pb])
	---------keep exsitent bridges
	-- local otherbrid = {}
	-- local bridupdate = {}
	-- if bridges[pa] then
	-- for k,v in pairs(bridges[pa]) do
		if k~=va then 
			-- otherbrid[k] = true;
			-- bridupdate[k]={} 
		end
	-- end
	-- end
	-- if bridges[pb] then
	-- for k,v in pairs(bridges[pb]) do
		if k~=vb then 
			-- otherbrid[k] = true;
			-- bridupdate[k]={} 
		end
	-- end
	-- end
	-- otherbrid[va] = true
	-- bridupdate[va]={}
	-- otherbrid[vb] = true
	-- bridupdate[vb]={}
	-- prtable("otherbrid",otherbrid)
	--------------
	local ia_array = bridges[pa] and bridges[pa][va] or {ia}
	local ib_array = bridges[pb] and bridges[pb][vb] or {ib}
	--de todos los bridges de a cogemos el que tiene en cone a vb
	local found_bri = false
	for _,iaa in ipairs(ia_array) do
		if IsPointInCone(P,vb,mod_pol(PolA,iaa-1),PolA[iaa],mod_pol(PolA,iaa+1)) then
			for _,ibb in ipairs(ib_array) do
				if IsPointInCone(P,va,mod_pol(PolB,ibb-1),PolB[ibb],mod_pol(PolB,ibb+1)) then
					ia,ib = iaa,ibb
					found_bri =  true
					goto FOUND_BRIDGES
				end
			end
		end
	end
	
	::FOUND_BRIDGES::
	assert(found_bri,"not found bridges")
	--local bridges_a = {}
	local Pol = {}
	for i=1,ia do
		--insert(Pol,PolA[i])
		Pol[i] = PolA[i]
		invPolind[PolA[i]][pa] = i
	end
	--bridges_a[va] = {ia}
	local Pol_len = #Pol
	--bridges_a[vb] = {Pol_len + 1}
	for i=ib,#PolB do
		Pol_len = Pol_len +1
		--insert(Pol,PolB[i])
		local PolBi = PolB[i]
		Pol[Pol_len] = PolBi
		invPolind[PolBi][pb] = nil
		invPolind[PolBi][pa] = Pol_len
	end
	assert(Pol_len==#Pol) --if never assert could delete line below
	Pol_len = #Pol
	for i=1,ib do
		Pol_len = Pol_len +1
		--insert(Pol,PolB[i])
		local PolBi = PolB[i]
		Pol[Pol_len] = PolBi
		invPolind[PolBi][pb] = nil
		invPolind[PolBi][pa] = Pol_len
	end
	--bridges_a[vb][2] = Pol_len
	assert(Pol_len==#Pol) --if never assert could delete line below
	Pol_len = #Pol
	--bridges_a[va][2] = Pol_len+1
	for i=ia,#PolA do
		Pol_len = Pol_len +1
		--insert(Pol,PolA[i])
		local PolAi = PolA[i]
		Pol[Pol_len] = PolAi
		invPolind[PolAi][pa] = Pol_len
	end
	-----bridges delete pb and add to pa
	bridges[pb] = nil
	bridges[pa] = {}--bridges[pa] or {}
	--local bridges_ao = bridges[pa]
	-- bridges_ao[va] = bridges_ao[va] or {}
	-- local lenb = #bridges_ao[va]
	-- bridges_ao[va][lenb+1] = bridges_a[va][1]
	-- bridges_ao[va][lenb+2] = bridges_a[va][2]
	-- bridges_ao[vb] = bridges_ao[vb] or {}
	-- local lenb = #bridges_ao[vb]
	-- bridges_ao[vb][lenb+1] = bridges_a[vb][1]
	-- bridges_ao[vb][lenb+2] = bridges_a[vb][2]
	--otherbrid
	--if next(otherbrid) then
	--prtable("bridupdate",bridupdate,"otherbrid",otherbrid)
		-- for i=1,#Pol do
			-- local vc = Pol[i]
			-- if otherbrid[vc] then insert(bridupdate[vc],i) end
		-- end
		-- for k,v in pairs(bridupdate) do
			-- bridges_ao[k] = {}
			-- for i,ii in ipairs(v) do
				-- insert(bridges_ao[k],ii)
			-- end
		-- end
	--end
	--update bridges
	--bridges[ip] = {}
	local vertextoind = {}
	for i=1,#Pol do
		local vi = Pol[i]
		if vertextoind[vi] then 
			insert(vertextoind[vi],i)
		else
			vertextoind[vi] = {i}
		end
	end
	for kk,ss in pairs(vertextoind) do
		if #ss > 1 then bridges[pa][kk] = ss end
	end
	--prtable("result merge",Pol,bridges_ao)
	
	return Pol
end
local function CheckInside(P,polinds,pa,ia,pb,ib,vai,vbi)
	local PolA,PolB = polinds[pa],polinds[pb]
	local va,vb = P[vai],P[vbi]
	local PolyA = {}
	for i=1,#PolA do PolyA[i]=P[PolA[i]] end
	if CG.IsPointInPoly(PolyA,vb) then return true end
	local PolyB = {}
	for i=1,#PolB do PolyB[i]=P[PolB[i]] end
	if CG.IsPointInPoly(PolyB,va) then return true end
	return false
end

-- local a = mat.vec2(3,3)
-- local b = mat.vec2(6,4)
-- local c = mat.vec2(5,28)
-- print(IntersecSweepLine(a,b,c))
--dave mout
local printD = function()  end
local function CHECKpol(polinds)
	for k,polind in pairs(polinds) do
		for j=1,#polind do assert(polind[j],"nil index in polind") end
	end
end
function CG.make_monotones(P,polinds)
	--CHECKpol(polinds)
	local EdgeHash = CG.EdgeHash
	assert(P.sorted,"points must be sorted")
	--prtable("points",P)
	local insert,remove = table.insert, table.remove
	local E = {}
	local invPolind 
	--local sigareas = {}
	local function calc_invPolind()
		invPolind = {bridges={}}
		for i,polind in ipairs(polinds) do
			--local poly = {}
			for j=1,#polind do
				if invPolind[polind[j]] then
					invPolind[polind[j]][i] = j
				else
					invPolind[polind[j]]= {[i]=j}
				end
				--poly[j] = P[polind[j]]
			end
			--sigareas[i] =1-- CG.signed_area(poly) > 0 and 1 or -1
		end
	end
	local polindsOrig = {}
	for i,polind in ipairs(polinds) do
		polindsOrig[i] = {}
		for j=1,#polind do
			polindsOrig[i][j] = polind[j]
		end
	end
	polinds, polindsOrig = polindsOrig, polinds
	--CHECKpol(polinds)
	calc_invPolind()
	--prtable(E)
	local algo = require"anima.algorithm.algorithm"
	local Status = {}
	local function UpdateStatus(i)
		do return end
		--prtable("st1",Status)
		local sorted = {}
		Status.sorted = nil
		for k,v in pairs(Status) do
			--print("pairs Status",k,v[1],v[2],i)
			--local pt, ok = IntersecSweepLine(P[v[1]],P[v[2]],P[i])
			--assert(ok)
			--insert(sorted,{k=k,y=pt.y})
			insert(sorted,{k=k})
		end
		--algo.quicksort(sorted,1,#sorted,function(a,b) return a.y < b.y end)
		Status.sorted = sorted
		-- for i=1,#sorted do
			-- local a = Status[sorted[i].k]
			-- for j=i+1,#sorted do
				-- local b= Status[sorted[j].k]
				-- if CG.SegmentIntersect(P[a[1]],P[a[2]],P[b[1]],P[b[2]]) then
					-- print("SegmentIntersec",P[a[1]],P[a[2]],P[b[1]],P[b[2]])
				-- end
			-- end
		-- end
		--print(#Status.sorted)
		--prtable("st2",Status)
	end
	-- local function SearchAbove(ii)
		-- local y = P[ii].y
		-- for k,e in pairs(Status) do
		-- end
	-- end
	local function SearchAbove(ii)
		local y = P[ii].y
		local efound,yfound = nil,math.huge
		local kfound
		for k,e in pairs(Status) do
			printD("SearchAbove",ii,k,e[1],e[2],"helper",e.helper)
			local pt, ok = IntersecSweepLine(P[e[1]],P[e[2]],P[ii])
			--assert(ok,"intersec fail")
			if ok then
			local pty = pt.y
			printD("SearchAbove",ii,k,pty,y,yfound)
			if pty > y then
				--if yfound then
					if yfound > pty then
						printD"Searchline found"
						yfound = pty
						efound = e
						kfound = k
					elseif yfound == pty then 
					--repeated points get the lower edge
						printD("e",e[1],e[2],"efound",efound[1],efound[2])
						local mine = e[1] > e[2] and 2 or 1
						local minefound = efound[1] > efound[2] and 2 or 1
						assert(efound[minefound==1 and 2 or 1]==e[mine==1 and 2 or 1])
						if P[e[mine]].y < P[efound[minefound]].y then
							efound = e
							kfound = k
						end
					end
				-- else
					-- yfound = pty
					-- efound = e
				-- end
			end
			end
		end
		--prtable("SearchAbove returns",efound)
		--if not efound then prtable(y,Status) end
		return efound,kfound --Status[Status.sorted[efound].k]
	end
	--binary_search would be better or binary tree
	local function SearchAboveBAK(ii) --for quicksorted
		local y = P[ii].y
		local found
		for i,v in ipairs(Status.sorted) do
			found = i
			if v.y > y then break end
		end
		return Status[Status.sorted[found].k]
	end
	local MergeVerts = {}
	local AddedLines = {}
	local function fixup(i,e)
		if e.helper and MergeVerts[e.helper] then
			--printD("--add line" ,i,e.helper)
			insert(AddedLines,{i,e.helper})
			--MergeVerts[e.helper] = false
		end
	end
	local function printStatus()
		print"===Status=========="
		for k,v in pairs(Status) do
			print(k,v[1],v[2],"helper",v.helper)
		end
		local  st = {"MergeVerts"}
		for k,v in pairs(MergeVerts) do
			insert(st,k)
		end
		print(table.concat(st," "))
		print"=================="
	end
	for i=1,#P do
		--E[i]
		local vi = P[i]
		--input polinds dont share vertex so take 1
		local ivp = invPolind[i]
		local ip = {}
		ip[1],ip[2] = next(ivp)
		--print(ip[1],ip[2])
		local pol,j = polinds[ip[1]],ip[2]
		local prev,succ = mod_pol(pol,j-1),mod_pol(pol,j+1)
		Pprev,Psucc = P[prev], P[succ]
		--if Pprev.x > vi.x and Psucc.x > vi.x then
		--if CG.lexicografic_compare(vi,Pprev) and CG.lexicografic_compare(vi,Psucc) then
		--printStatus()
		--prtable("AddedLines",AddedLines)
		if i < prev and i < succ then
			if CG.Sign(Pprev,vi,Psucc) > 0 then
				printD(i,ip[1],"---start",prev,i,succ)
				--printStatus()
				--print(E[i][succ],E[prev][i])
				Status[EdgeHash(i,succ)] = {i,succ}
				Status[EdgeHash(prev,i)] = {prev,i,helper=i}
			else
				printD(i,ip[1],"---split")
				UpdateStatus(i)
				--printStatus()
				local e,k = SearchAbove(i)
				---add line
				printD("----add line",i,e.helper,k)
				
				assert(e.helper)
				insert(AddedLines,{i,e.helper})
				e.helper = i
				
				-- local succy = P[succ].y
				-- local prevy = P[prev].y
				-- if succy < prevy then
					-- Status[EdgeHash(i,succ)] = {i,succ,helper=i}
					-- Status[EdgeHash(prev,i)] = {prev,i}--,helper=nil}
				-- else
					-- Status[EdgeHash(i,succ)] = {i,succ}
					-- Status[EdgeHash(prev,i)] = {prev,i,helper=i}
				-- end
				
				Status[EdgeHash(i,succ)] = {i,succ,helper=i}
				Status[EdgeHash(prev,i)] = {prev,i,helper=i}
			end
		--elseif  Pprev.x < vi.x and Psucc.x < vi.x then
		--elseif  CG.lexicografic_compare(Pprev,vi) and CG.lexicografic_compare(Psucc,vi) then
		elseif  prev < i and succ < i then
			if CG.Sign(Pprev,vi,Psucc)  > 0 then
				printD(i,ip[1],"--end")
				--printStatus()
				--prtable("end status",Status)
				local eUp = Status[EdgeHash(i,succ)]
				--prtable("endd",eUp)
				fixup(i, eUp)
				-- if eUp.helper and MergeVerts[eUp.helper] then
					-- print("--add line" ,i,eUp.helper,"if it is merge vertex")
					-- insert(AddedLines,{i,eUp.helper})
				-- end
				Status[EdgeHash(prev,i)] = nil
				Status[EdgeHash(i,succ)] = nil
			else
				printD(i,ip[1],"--merge")
				--prtable("merge status",Status)
				--printStatus()
				local e1 = Status[EdgeHash(prev,i)]
				local e2 = Status[EdgeHash(i,succ)]
				Status[EdgeHash(prev,i)] = nil
				Status[EdgeHash(i,succ)] = nil
				UpdateStatus(i)
				local e = SearchAbove(i)
				fixup(i, e)
				--prtable("e above",e)
				-- if e.helper and MergeVerts[e.helper] then
					-- print("--add line" ,i,e.helper)
					-- insert(AddedLines,{i,e.helper})
				-- end
				--buscar el bajo de e1 y e2 y fixup
				-----TODO?
				local succy = P[succ].y
				local prevy = P[prev].y
				if succy<prevy then
					fixup(i, e2)
					--prtable("incident below",e2)
				else
					fixup(i, e1)
					--prtable("incident below",e1)
				end
				-- if e1.helper and MergeVerts[e1.helper] then
					-- print("--add line" ,i,e1.helper)
					-- insert(AddedLines,{i,e1.helper})
				-- end
				MergeVerts[i] = true
				e.helper = i
			end 
			
		else
			printD(i,ip[1],"--regular")
			--if Pprev.x > vi.x then
			--if CG.lexicografic_compare(vi,Pprev) then
			if i < prev then
				printD"--upper regular"
				--printStatus()
				local e = Status[EdgeHash(i,succ)]
				fixup(i, e)
				-- if e.helper and MergeVerts[e.helper] then
					-- print("--add line" ,i,e.helper)
					-- insert(AddedLines,{i,e.helper})
				-- end
				Status[EdgeHash(i,succ)] = nil
				Status[EdgeHash(prev,i)] = {prev,i,helper=i}
			else
				printD"--lower regular"
				UpdateStatus(i)
				--printStatus()
				--prtable(MergeVerts)
				local e = SearchAbove(i)
				fixup(i, e)
				-- if e.helper and MergeVerts[e.helper] then
					-- print("--add line" ,i,e.helper)
					-- insert(AddedLines,{i,e.helper})
				-- end
				e.helper = i --this is taken from Computational ......
				--prtable("modification",e)
				Status[EdgeHash(prev,i)] = nil
				Status[EdgeHash(i,succ)] = {i,succ,helper=i}
			end
		end
	end
	printD"done AddLines"
	--printStatus()
	--prtable("AddedLines",AddedLines)
	--do return end
	------AddLines
	--now only polind[1]
	printD("#AddedLines",#AddedLines)
	--do return end
	local newindex = #polinds
	--check polinds 
	-- for k,polind in pairs(polinds) do
		-- for j=1,#polind do assert(polind[j],"nil index in polind") end
	-- end
	
	for il,v in ipairs(AddedLines) do
		printD("addding",v[1],v[2],"#polinds",#polinds)
		--prtable("polinds",polinds)
		--local repes=0
		::REPEAT::
		--repes = repes+1
		--if repes>10 then return end
		local ipi1,ipi2 = invPolind[v[1]],invPolind[v[2]]
		--prtable("invPolind",invPolind)
		--prtable("ipi1,ipi2",ipi1,ipi2)

		
		--prtable("ipi1,ipi2",ipi1,ipi2)
		local checkn = 62
		for p1,ipi1a in pairs(ipi1) do
			--first same poli
			--for  p2,ipi2a in pairs(ipi2) do
				--if p1==p2 then
			local ipi2a = ipi2[p1]
				if ipi2a then
					--if math.abs(ipi1a[2]-ipi2a[2])>1 then
						--print("split poligon",p1,"indexes",ipi1a,ipi2a)
						newindex = newindex + 1
						local PolA,PolB = SplitPolygon(polinds,p1,ipi1a,ipi2a,invPolind,newindex)
						--remove(polinds,ipi1a[1])
						-- if p1==checkn then print("-split---------------------11----------------------------",#PolA,#PolB) 
							-- local Ppol = {}
							-- for g=1,#PolA do Ppol[g] = P[PolA[g]] end
							-- cvb = require"anima.CG3.check_poly"
							-- cvb.CHECKPOLY(Ppol)
						-- end
						-- if newindex==checkn then print("new----------------------11----------------------------",#PolA,#PolB) end
						polinds[p1] = nil
						if #PolA >2 then polinds[p1]=PolA end
						if #PolB >2 then polinds[newindex]=PolB end
						--calc_invPolind()
						--for j=1,#PolA do assert(PolA[j],"nil index in polind") end
						--for j=1,#PolB do assert(PolB[j],"nil index in polind") end
						goto NEWLINE 
						--goto REPEAT
					--end
				--end
				end
		end
		for p1,ipi1a in pairs(ipi1) do
			--now different polis
			for  p2,ipi2a in pairs(ipi2) do
				if p1~=p2 then
					--print("merge poligons", p1,p2)
					--if ipi1a inside ipi2a or viceversa
					if CheckInside(P,polinds,p1,ipi1a,p2,ipi2a,v[1],v[2]) then
						--print"MERGE::::::::::::::::::::::::::::::::::::::::"
						local Pol = MergePolygons(P,polinds,p1,ipi1a,p2,ipi2a,invPolind)
						--local a,b = ipi1a[1],ipi2a[1]
						--if a<b then a,b=b,a end
						--remove(polinds,a)
						--for j=1,#Pol do assert(Pol[j],"nil index in polind") end
						--if p1==checkn then print"-merge---------------------11----------------------------" end
						polinds[p1] = Pol
						polinds[p2] = nil
						--remove(polinds,b)
						--insert(polinds, Pol)
						--calc_invPolind()
						goto NEWLINE 
						--goto REPEAT
					else
						--print("not inside--")
					end
				end
			end
		end
		--break
		::NEWLINE::
	end
	--print("#polinds",#polinds)
	--prtable("all polinds",polinds)
	--do return polinds,{} end
	local trs = {}
	for k,polind in pairs(polinds) do
		--for j=1,#polind do assert(polind[j],"nil index in polind") end
		local P1 = {}
		--which P points used in polind
		for j=1,#polind do
			P1[polind[j]] = j --P[j]
		end

		--save them to P2 in order and polind2
		local polind2 = {}
		local P2 = {sorted=true}
		local P2toP,PtoP2 = {},{}
		for j=1,#P do
			if P1[j] then
				insert(P2,P[j])
				P2toP[#P2] = j
				PtoP2[j] = #P2
				--polind2[P1[j]] = #P2
			end
		end
		for j=1,#polind do polind2[j] = PtoP2[polind[j]] end
		--prtable("polind2",polind2,"P2",P2,"P1",P1)
		--prtable(k,"polind",polind,"polind2",polind2,"P2",P2)
		--print(k,"polind",#polind,"points")
		
		-- local _,OK = getChains(P2,polind2)
		-- if not OK then print"not monotone" end
		
		---[[
		local tr = CG.triang_sweept_monotone(P2,polind2)

		--tranlate P2 to P
		for j=1,#tr do
			tr[j] = P2toP[tr[j]+1]-1
		end
		--prtable("tranlate to P",tr)
		trs[#trs+1] = tr
		--]]
	end
	return polindsOrig, trs
end

function CG.monotone_tesselator(pts,contours)
	local inds = CG.lexicografic_sort(pts, true)
	local inds2 = {}
	for i,v in ipairs(inds) do inds2[v]=i end
	for i,cont in ipairs(contours) do
		local cont2 = {}
		for j,v in ipairs(cont) do cont2[j] = inds2[v] end
		contours[i] = cont2
	end
	local polis, trs = CG.make_monotones(pts,contours)
	local trmerged = {}
	for i,tr in ipairs(trs) do
		for j,ind in ipairs(tr) do
			table.insert(trmerged,ind)
		end
	end
	return pts, trmerged
end

return CG
