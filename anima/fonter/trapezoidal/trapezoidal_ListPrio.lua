--trapezoid version
--with winding
local CG = require"anima.CG3.base"
--CG = require"anima.CG3.TriangSweep"
local Sign = CG.Sign
local M = {edges = {}}
local use_added_lines --= true
local use_common_point = true
local use_collapse_faces = true --true
local use_prioL = false --true
local use_test_rev = false
--correct status vs ListPrio
local use_correct_status = true
local search_cross = true
local use2pointcross = true

function prtableDDr(...)
	for i=1, select('#', ...) do
		local t = select(i, ...)
		print(tb2st_serialize(t))
		print("\n")
	end
end

local DOprint = function() end
local printD = function() end
local prtableD = function() end
local prtableDD = function() end
if not ... then
--DOprint = print
-- printD = print --function() end
-- prtableD = prtableDDr --function() end
-- prtableDD = prtableDDr
end

function M:new()
	local o = {edges={},faces={},newface=1,vertex = {},Alias={},invAlias={},collapsed_faces={}}
	self.__index = self
	return setmetatable(o,self)
end 
local maxvertex = 20000
function M:add_edge(a,b,info)
	--assert(not self.edges[a])
	if self.edges[a] then
		printD("goind new a",a)
		a = self:getP(a)
		self.invAlias[a] = self.invAlias[a] or {}
		local inv = self.invAlias[a]
		local Alias = self.Alias
		Alias[#Alias + 1] = a
		a = maxvertex + #Alias
		inv[#inv+1] = a
		printD("new a",a,self:getP(a))
	end
	info.a = a
	info.b = b
	self.edges[a] = info
	return a
end
function M:_add_edge(a,b,info)
	assert(not self.edges[a])
	self:add_edge(a,b,info)
end

function M:getP(a)
	if a > maxvertex then return self.Alias[a-maxvertex] end
	return a
end
local function ESign(P,a,b,c)
	return Sign(P[a],P[b],P[c])
end
function M:Sign(P,a,b,c)
	--return Sign(P[self:getP(a)],P[self:getP(b)],P[self:getP(c)])
	return Sign(P[a] or P[self:getP(a)],P[b] or P[self:getP(b)],P[c] or P[self:getP(c)])
end
function M:getPstr(a)
	if a > maxvertex then return tostring(a).."("..self.Alias[a-maxvertex]..")" end
	return a
end
local function str_inf(inf)
	return table.concat{"a:",inf.a," b:",inf.b," face:",inf.face," prev:",inf.prev}
end
function M:printEdge(inf)
	print(self:getPstr(inf.a),self:getPstr(inf.b),str_inf(inf))
end
function M:strEdge(i)
	local inf = self.edges[i]
	return self:getPstr(inf.a),self:getPstr(inf.b),str_inf(inf)
end
function M:walk(a1,f)
	--printD("walk",a1)
	local counter = 0
	local visited = {}
	local edges = self.edges
	local a = a1
	repeat
		local inf = edges[a]
		f(self,inf)
		visited[a] = true
		a = inf.b
		counter = counter + 1
		--printD(a)
	until a==a1 or visited[a]--or counter==100
	if a~=a1 then
		printD("walk aborted on",a,a1)
		--error"walk aborted"
		return false,visited
	end
	return true
	--printD("end walk",a1)
end


local function mod(a,b)
	return (a-1)%b+1
end
function M:add_face(t)
	self.faces[self.newface] = t[1]
	local n = self.newface
	self.newface = self.newface + 1
	self:_add_edge(t[1],t[2],{face=n,prev=t[#t]})
	for i=2,#t-2 do
		self:_add_edge(t[i],t[i+1],{face=n,prev=t[i-1]})
	end
	self:_add_edge(t[#t-1],t[#t],{face=n,prev=t[#t-2]})
	self:_add_edge(t[#t],t[1],{face=n,prev=t[#t-1]})
end
function M:split_face(a,b,commonpoint)
	local edges = self.edges
	local infa = edges[a]
	local infb = edges[b]
	local preva = infa.prev
	local prevb = infb.prev
	local face = infa.face
	assert(face == infb.face,"split_face with two faces")
	printD("facea",face,infb.face,"a,b",a,b)
	local anew
	if commonpoint then
		-- anew = self:add_edge(a,infb.b,{face=face,prev=preva})
		-- edges[preva].b = anew
		-- edges[infb.b].prev = anew
		-- edges[b] = nil
		anew = a
		edges[b].prev,edges[a].prev = edges[a].prev,edges[b].prev
		edges[edges[b].prev].b = b
		edges[edges[a].prev].b = a
	else
		anew = self:add_edge(a,b,{face=face,prev=preva})
		edges[preva].b = anew
		edges[b].prev = anew
	end
	printD("assign face",face,anew)
	self.faces[face] = anew
	
	--self.faces[self.newface] = b
	local face = self.newface
	--self.newface = self.newface + 1
	
	local bnew
	if commonpoint then
		-- bnew = self:add_edge(b,infa.b,{face=face,prev=prevb})
		-- edges[prevb].b = bnew
		-- edges[infa.b].prev = bnew
		-- edges[a] = nil
		bnew = b
	else
		bnew = self:add_edge(b,a,{face=face,prev=prevb})
		edges[prevb].b = bnew
		edges[a].prev = bnew
	end
	
	printD("create face",self.newface)
	self.faces[self.newface] = bnew
	self.newface = self.newface + 1
	
	self:walk(bnew,function(self,inf) inf.face=face end)
	return anew,bnew,"split"
end
function M:merge_faces(a,b,commonpoint)
	--assert(not commonpoint,"not done commonpoint")
	local edges = self.edges
	local infa = edges[a]
	local infb = edges[b]
	local preva = infa.prev
	local prevb = infb.prev
	local face = infa.face
	--change B face to A
	self.faces[infb.face] = nil
	self:walk(b,function(self,inf) inf.face = face end)
	local anew
	if commonpoint then
		-- anew = self:add_edge(a,infb.b,{face=face,prev=preva})
		-- edges[preva].b = anew
		-- edges[infb.b].prev = anew
		-- edges[b] = nil
		anew = a
		edges[b].prev,edges[a].prev = edges[a].prev,edges[b].prev
		edges[edges[a].prev].b = a
		edges[edges[b].prev].b = b
	else
		anew = self:add_edge(a,b,{face=face,prev=preva})
		edges[preva].b = anew
		edges[b].prev = anew
	end
	local bnew
	if commonpoint then
		-- bnew = self:add_edge(b,infa.b,{face=face,prev=prevb})
		-- edges[prevb].b = bnew
		-- edges[infa.b].prev = bnew
		-- edges[a] = nil
		bnew = b
	else
		bnew = self:add_edge(b,a,{face=face,prev=prevb})
		edges[prevb].b = bnew
		edges[a].prev = bnew
	end
	self.faces[infa.face] = anew
	return anew,bnew,"merge"
end
function M:add_line(a,b,commonpoint)
	--do return end
	local edges = self.edges
	local infa = edges[a]
	local infb = edges[b]
	if infb.face == infa.face then
		printD("add_line split",commonpoint)
		return self:split_face(a,b,commonpoint)
	else
		printD("add_line merge",commonpoint)
		return self:merge_faces(a,b,commonpoint)
	end
end
--a-b and c-d are crossing in i==i2
--not rev makes a-i-d and c-i2-b
--rev makes a-i-c and b-i2-d
function M:add_point_rev(a,c,i,i2)
	--i,i2 = i2,i
	local edges = self.edges
	local infa = edges[a]
	local infc = edges[c]
	local preva = infa.prev
	local b = infa.b
	local facea = infa.face
	local prevc = infc.prev
	local d = infc.b
	local facec = infc.face
	local sameface = facea==facec
	--add a-i-c
	if sameface then
		self:reverseB(c,b)
		local infb = edges[b]
		infb.prev,infb.b = infb.b,infb.prev
	else
		local infd = edges[d]
		local db = infd.b
		self:reverseB(c,d)
		--local infd = edges[d]
		infd.prev = db
	end
	self:add_edge(i,c,{face=facea,prev=a})
	edges[a].b = i
	edges[c].prev = i
	--walk b to c reversing
	-- self:walk(b,function(self,inf) 
		-- inf.face=face 
		-- inf.b,inf.prev = inf.prev,inf.b
	-- end)
	
	--do return end
	--revert b-c
	-- local infb = edges[b]
	-- assert(infb.b==c)
	-- infb.b,infb.prev = infb.prev,infb.b
	
	local face
	--if same face make new
	if sameface then
		-- self.faces[self.newface] = b
		-- face = self.newface
		-- self.newface = self.newface + 1
		-- self.faces[facea] = a
		face = facea
	else
		self.faces[facec] = nil
		face = facea
	end
	if sameface then
	--add b-i2-d
		local newi = self:add_edge(i2,d,{face=face,prev=b})
		edges[b].b = newi
		edges[d].prev = newi
		--self:walk(b,function(self,inf) inf.face=face end)
	else
	--add d-i2-b
		local newi = self:add_edge(i2,b,{face=face,prev=d})
		edges[d].b = newi
		edges[b].prev = newi
		self:walk(a,function(self,inf) inf.face=face end)
	end
end
function M:add_point(a,c,i,i2,rev)
	if rev then return self:add_point_rev(a,c,i,i2) end
	local edges = self.edges
	local infa = edges[a]
	local infc = edges[c]
	local preva = infa.prev
	local b = infa.b
	local facea = infa.face
	local prevc = infc.prev
	local d = infc.b
	local facec = infc.face
	--add a-i-d
	self:add_edge(i,d,{face=facea,prev=a})
	edges[a].b = i
	edges[d].prev = i

	local face
	--if same face make new
	if facea == facec then
		self.faces[self.newface] = b
		face = self.newface
		self.newface = self.newface + 1
		self.faces[facea] = a
	else
		self.faces[facec] = nil
		face = facea
	end
	--add c-i2-b
	local newi = self:add_edge(i2,b,{face=face,prev=c})
	edges[c].b = newi
	edges[b].prev = newi
	self:walk(b,function(self,inf) inf.face=face end)
end
function M:reverse(ii,ii2)
	ii2 = ii2 or ii
	--local counter = 0
	local edges = self.edges
	local a = ii
	repeat
		--counter = counter+1
		--printD("reverse",a)
		local inf = edges[a]
		inf.b,inf.prev = inf.prev,inf.b
		a = inf.prev
	until a==ii2 --or counter>15
end
function M:reverseB(ii,ii2)
	ii2 = ii2 or ii
	--local counter = 0
	local edges = self.edges
	local a = ii
	repeat
		--counter = counter+1
		--printD("reverse",a)
		local inf = edges[a]
		inf.b,inf.prev = inf.prev,inf.b
		a = inf.b
	until a==ii2 --or counter>15
end
local printF = printD
function M:faces_print(txt)
	if printF==print then
	printF("----------faces print----------------------------",txt)
	for i,v in pairs(self.faces) do
		printF("----face",i,"-------------------------------------collapsed:",self.collapsed_faces[i])
		self:walk(v,self.printEdge)
	end
	printF"---------------------------------------------------"
	end
end
function M:faces_walk(f)
	for i,v in pairs(self.faces) do
		self:walk(v,f)
	end
end
function M:get_polinds(all)
	local polind
	local polinds = {}
	local function getPolind(self,inf)
		polind[#polind+1] = self:getP(inf.a)
	end
	for i,v in pairs(self.faces) do
		if all or not self.collapsed_faces[i] then
			polind = {}
			self:walk(v,getPolind)
			polinds[#polinds+1] = polind
		end
	end
	return polinds
end
function M:get_polind(a)
	local polind
	local polinds = {}
	local function getPolind(self,inf)
		polind[#polind+1] = self:getP(inf.a)
	end
	polind = {}
	self:walk(a,getPolind)
	return polind
end
function M:delete_face(a)
	printD("----------------------- delete_face",self:getPstr(a))
	prtableD(self)
	self.faces[self.edges[a].face] = nil
	self:walk(a,function(self,inf)
		assert(inf.a> maxvertex,"deleting not virtual")
		self.edges[inf.a]=nil 
	end)
	assert(a > maxvertex)
	local inv = self.invAlias[self:getP(a)]
	for i=1,#inv do if inv[i]==a then table.remove(inv,i); break end end
	self.Alias[a-maxvertex] = 0
	prtableD(self)
	--error"delete face"
end
function M:mark_collapsed(a)
	printD("mark_collapsed",a)
	self.collapsed_faces[self.edges[a].face] = true
end
function M:not_collapsed(a)
	--printD("not_collapsed",a)
	if not self.edges[a] then return false end
	-- printD(self.edges[a])
	-- printD(self.edges[a].face)
	-- prtable(self.collapsed_faces)
	return not self.collapsed_faces[self.edges[a].face]
end
function M:check()
	if printD~=print then return end
	local visited = {}
	-- for k,v in pairs(self.edges) do
		-- local ok = self:walk(v,function(self,inf) visited[inf.a]=true end)
		-- assert(ok)
	-- end
	--self:faces_walk(function(self,inf) visited[inf.a]=true end)
	for i,v in pairs(self.faces) do
		local ok,visited = self:walk(v,function(self,inf) visited[inf.a]=true;if inf.face~=i then printD"bad face";error"bad face" end end)
		if not ok then 
			self:printEdge(self.edges[v])
			prtableD("visited",visited)
			for k,w in pairs(visited) do
				self:printEdge(self.edges[k])
			end
		end
		assert(ok,"bad walk")
	end
	for k,v in pairs(self.edges) do
		
		if not visited[v.a] then
			printD("not visited",k,v)
			self:printEdge(self.edges[k])
			error"not visited"
		end
		if k~=self.edges[v.b].prev then print(k,"error");error"bad b prev" end
		if k~=self.edges[v.prev].b then print(k,"error");error"bad b prev" end
	end
	--invAlias check
	for k,v in pairs(self.invAlias) do
		assert(self.edges[k])
		for i,w in ipairs(v) do
			if not self.edges[w] then
				print("no edges",w,"alias",k)
			end
		end
	end
end


-----------------------------
local insert,remove = table.insert, table.remove

local algo = require"anima.algorithm.algorithm"
--helper for triang_sweept_monotone
--polind must be CCW
local function getChainsBAK(P,polind,sinds,Ptoind)
    local lowerchain,upperchain = {},{}
	local is_lower = {}
	local doinglow
	for i,v in ipairs(polind) do
		if Ptoind[v]==sinds[1] then --init lower chain
			printD(i,v,"low")
			doinglow = true
			for j=0,#polind-1 do
				local w = polind[mod(i+j,#polind)]
				if Ptoind[w]==sinds[#sinds] then printD(mod(i+j,#polind),w,"high");doinglow = false end
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
	prtableD("chains",lowerchain,upperchain)
	local monotone = true
	for i=2,#lowerchain do
		--assert(lowerchain[i]>lowerchain[i-1],"not monotone")
		if not (Ptoind[lowerchain[i]]>Ptoind[lowerchain[i-1]]) then monotone=false end
	end	
	for i=2,#upperchain do
		--assert(upperchain[i]<upperchain[i-1],"not monotone")
		if not (Ptoind[upperchain[i]]<Ptoind[upperchain[i-1]]) then monotone = false end
	end	
	return is_lower, monotone
end
local floor = math.floor
local function reverse(t)
	local s = #t+1
	for i=1,floor(#t/2) do
		t[i],t[s-i] = t[s-i],t[i]
	end
	return t
end
local function signed_area(P,poly)
	if #poly < 3 then return 0 end
	local sum = 0
	for i=1,#poly-1 do
		local a,b = P[poly[i]], P[poly[i+1]]
		sum = sum + a.x*b.y - b.x*a.y
	end
	local a,b = P[poly[#poly]], P[poly[1]]
	sum = sum + a.x*b.y - b.x*a.y
	return sum
end
--for monotone mountains low and high are contiguous
--check firs low then high
local function getChains(P,polind,sinds,Ptoind)
	prtableD("--------polind",polind)
	local sigA = signed_area(P,polind)
	printD(sigA,"sifAS")
	if sigA<0 then reverse(polind) end
    local lowerchain,upperchain = {},{}
	local is_lower = {}
	local doinglow
	
	-- local low
	-- for i,v in ipairs(polind) do
		-- if Ptoind[v]==sinds[1] then low = i;break end
	-- end
	-- printD("low",low)
	-- if sinds[#sinds]==Ptoind[polind[mod(low-1,#polind)]] then
		-- printD("REVERSE",#polind-low+1)
		-- low = #polind-low+1
		-- reverse(polind)
	-- else
		-- assert(sinds[#sinds]==Ptoind[polind[mod(low+1,#polind)]])
	-- end

	for i,v in ipairs(polind) do
		if Ptoind[v]==sinds[1] then --init lower chain
			printD(i,v,"low")
			doinglow = true
			for j=0,#polind-1 do
				local w = polind[mod(i+j,#polind)]
				if Ptoind[w]==sinds[#sinds] then printD(mod(i+j,#polind),w,"high");doinglow = false end
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
	-- doinglow = true
	-- for j=0,#polind-1 do
		-- local w = polind[mod(low+j,#polind)]
		-- if Ptoind[w]==sinds[#sinds] then printD(mod(low+j,#polind),w,"high");doinglow = false end
		-- if doinglow then
			-- table.insert(lowerchain,w)
			-- is_lower[w] = true
		-- else
			-- table.insert(upperchain,w)
			-- is_lower[w] = false
		-- end
	-- end

	--test monotone
	prtableD("chains",lowerchain,upperchain)
	local monotone = true
	for i=2,#lowerchain do
		--assert(lowerchain[i]>lowerchain[i-1],"not monotone")
		if not (Ptoind[lowerchain[i]]>Ptoind[lowerchain[i-1]]) then monotone=false end
	end	
	for i=2,#upperchain do
		--assert(upperchain[i]<upperchain[i-1],"not monotone")
		if not (Ptoind[upperchain[i]]<Ptoind[upperchain[i-1]]) then monotone = false end
	end	
	return is_lower, monotone
end

--Dave Mount book
-- and also 
--Computational Geometry Algorithms and Applications
--by Mark de Berg and others
--work with unsorted P and polind points to only some P
local function triang_sweept_monotone(P,polind,sinds,Ptoind)
	-- local sigA = signed_area(P,polind)
	-- printD(sigA,"sifAS")
	-- if sigA<0 then reverse(polind) end
	local polsinds,sinds2 = {},{}
	for i=1,#polind do
		polsinds[i] = Ptoind[polind[i]]
		sinds2[i] = polsinds[i]
	end
	
	--prtable("Ptoind",Ptoind,"polind",polind,"polsinds",polsinds)

	algo.quicksort(sinds2,1,#sinds2,function(a,b) return a<b end)
	--prtable("sinds2",sinds2)
	
	-- for i=1,#polsinds do
		-- print(i,polind[i],polsinds[i],sinds[sinds2[i]],sinds[polsinds[i]])--,Ai[i],sinds2[A[i]],Ai[sinds2[i]])
	-- end
	
	local insert,remove = table.insert, table.remove
	local tr = {}
	
	local is_lower, OK = getChains(P, polind,sinds2,Ptoind)
	assert(OK, "not monotone")
	if not OK then print"not monotone" ;return {} end
	------
	local function same_chain(a,b)
		return is_lower[a]==is_lower[b]
	end
	-- prtable("P",P)
	-- prtable("polind",polind)
	-- prtable("lowerchain",lowerchain)
	-- prtable("upperchain",upperchain)
	--prtable("sinds2",sinds2,polind)
	-- prtable(polind,sinds2,sinds)
	local stack = {sinds[sinds2[1]],sinds[sinds2[2]]}
	local tr = {}
	for h=3,#sinds2 do
		local i = sinds[sinds2[h]]
		printD("-----check p",i)
		--if is_lower[i]~=is_lower[stack[#stack]] then
		if not same_chain(i,stack[#stack]) then
			--make triangle with reflex chain
			printD"different chains"
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
			printD"same chains"
			local test_sign = is_lower[i] and 1 or -1 --(1 or -1)
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

local format = string.format
local function IsPointInCone(P,pi,a,b,c,preva,succc)
	
	local scone = Sign(P[a],P[b],P[c])
	local sab = Sign(P[a],P[b],P[pi])
	local sbc = Sign(P[b],P[c],P[pi])
	printD("IsPointInCone",pi,a,b,c,"signs",format("%.17f,%.17f,%.17f",scone,sab,sbc))
	--assert(scone~=0 and sab~=0 and sbc~=0)
	--if scone== 0 or sab==0 or sbc==0 then print("IsPointInCone",scone,sab,sbc); return true end --error"collinear" end
	if scone==0 then
		--colinear
		if P[a]==P[b] then
			if P[c]==P[a] then error"3 coincident points" end
			return sbc > 0
		elseif P[b]==P[c] then
			return sab > 0
		elseif P[a]==P[c] then
			--error"IsPointInCone spike1"
			printD"IsPointInCone spike1"
			return IsPointInCone(P,succc,preva,a,b)
			--return true
		else
			local ang = CG.Angle(P[a],P[b],P[c])
			if ang==0 then
				error"IsPointInCone spike2"
			else
				return sab >0 and sbc > 0
			end
		end
	end
	--assert(not(scone==0),"colinear a,b,c")
	if scone < 0 then --right
		return not(sab<0 and sbc<0)
	else --left > 0
		return sab > 0 and sbc > 0
	end
	-- return CG.PointInCone(P[pi],P[a],P[b],P[c])
end

-- local P1={
-- mat.vec2(0,0),
-- mat.vec2(2,0),
-- mat.vec2(3,1)
-- }
-- print("InCone",IsPointInCone(P1,2,1,2,3))
-- print("InCone",IsPointInCone(P1,2,3,2,1))
-- os.exit()

local function IsPointInside(pi,a,b,c)
	printD("IsPointInside",pi,a,b,c)
	local scone = Sign(a,b,c)
	local sab = Sign(a,b,pi)
	local sbc = Sign(b,c,pi)
	if scone < 0 then --right
		return (sab<=0 and sbc<=0)
	else --left > 0
		return sab >= 0 and sbc >= 0
	end
end
---------------------------------
local Snaps = {}
local SnapsP = {}
local function TakeSnapP(item,prio,ii)
	printD("TakeSnapP",item,prio,ii)
	local itc = copyTable(item)
	--local itc = deepcopy(item)
	Snaps[prio] = Snaps[prio] or {}
	Snaps[prio][ii] = itc
	SnapsP[prio] = itc
end
local function CompareSnapsP(item,prio,ii)
	--print("CompareSnapsP",item,prio,ii)
	--prtable(Snaps)
	-- if not Snaps[prio] then return false end
	-- if not Snaps[prio][ii] then return false end
	return tbl_compare(Snaps[prio][ii],item)
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

local insert = table.insert
--local windingRules = {"ODD","NONZERO","POSITIVE","NEGATIVE","ABS_GEQ_TWO"}
local windingRules = {[0]=function(w) return (w%2)==1 end,
function(w) return w~=0 end,
function(w) return w>0 end,
function(w) return w<0 end,
function(w) return (w >= 2) or (w <= -2) end}

function CG.edges_monotone_tesselator(P, contours,wrule,alg1)
	use_added_lines = alg1
	local windingrule = windingRules[wrule]
	------sort
	local inds = {}
	for i=1,#P do inds[i]=i end
	algo.quicksort(inds,1,#P,function(a,b) return CG.lexicografic_compare(P[a],P[b]) end)
	----------merge commonpoints
	-- local map = {}
	-- for i=1,#inds do
		-- local ind = inds[i]
		-- print(i,ind,map[i-1],P[ind],P[map[i-1]])
		-- if i> 1 and P[ind]==P[map[i-1]] then 
			-- print("iguales",i,i-1) 
			-- map[i]  = map[i-1]
		-- else
			-- map[i] = ind
		-- end
	-- end

	-- local Ptoind = {}
	-- for i=1,#P do Ptoind[inds[i]]=i end
	-- local map2 = {}
	-- for i=1,#P do map2[inds[i]]=map[i] end
	-- prtable(inds,map,Ptoind,map2,P)
	--error"DEBUG"
	-------------------
	local Ptoind = {}
	for i=1,#P do Ptoind[inds[i]]=i end
	prtableD("inds",inds)
		--create edges_mesh
	local E = M:new()
	for i,cont in ipairs(contours) do
		E:add_face(cont)
	end
	-------------Status
	local AddedLines = {}
	local AddedLines2 = {} --with Alias
	local function EdgeHash(a,b)
		return table.concat{tostring(a),">",tostring(b)}
	end
	local Bridges = {}
	local Status = {edges={},sorted={}}
	local function StatusWindCalc()
		--prtable(Status)
		local windL = 0
		for i=1,#Status.sorted do
			local e = Status.edges[Status.sorted[i]]
			e.windU = windL
			local wind = e.first == 1 and -1 or 1
			e.windL = wind + windL
			windL = e.windL
			--print(e[1],e[2],wind,e.windL)
		end
	end
	local function getPrio(ii)
		local prio = Ptoind[ii]
		if not prio then
			return Ptoind[E:getP(ii)]
		else
			return prio
		end
	end
	local function getTipo(ii)
		local inf = E.edges[ii]
		local succ = inf.b
		local prev = inf.prev
		--local Pprev,Psucc = P[prev], P[succ]
		
		local prio,iprev,isucc = getPrio(ii),getPrio(prev),getPrio(succ)
		if prio < iprev and prio < isucc then
				return"start"
		elseif  iprev < prio and isucc < prio then
			return"end"
		else
			if prio < iprev then
				return"upper"
			else
				return"lower"
			end
		end
	end
	local function DOprintStatus(...)
		local printD --=print
		if DOprint == print then printD=print end
		if printD==print then

		printD("----Status sorted----------",...)
		for i,k in ipairs(Status.sorted) do
			local v = Status.edges[k]
			if not v then 
				printD(i,k,"not edges")
			else
				--printD(i,k,E:getPstr(v[1]),E:getPstr(v[2]),"prios",Ptoind[v[1]],Ptoind[v[2]],"lastprio",v.lastprioL,v.lastprioU,"wind",v.windL,v.windU)
				--printD(string.format("%d %-8s %-8s last %-5d %-5d wind %3d %3d",i,E:getPstr(v[1]),E:getPstr(v[2]),v.lastprioL,v.lastprioU,v.windL or 999,v.windU or 999))
				printD(string.format("%d %-8s %-8s last %-5d %-5d wind %3d %3d first %3d %s", i, E:getPstr(v[1]), E:getPstr(v[2]), v.lastprioL, v.lastprioU, v.windL or 999, v.windU or 999, v.first, getTipo(v[v.first])))
			end
		end
		prtableD(Status.sorted)
		prtableDD(Status.edges)
		printD"--------------------"
		--E:faces_print()
		end
	end
	local function printStatus(...)

		if printD==print then

		printD("----Status sorted----------",...)
		for i,k in ipairs(Status.sorted) do
			local v = Status.edges[k]
			if not v then 
				printD(i,k,"not edges")
			else
				--printD(i,k,E:getPstr(v[1]),E:getPstr(v[2]),"prios",Ptoind[v[1]],Ptoind[v[2]],"lastprio",v.lastprioL,v.lastprioU,"wind",v.windL,v.windU)
				printD(string.format("%d %-8s %-8s last %-5d %-5d wind %3d %3d first %3d %s", i, E:getPstr(v[1]), E:getPstr(v[2]), v.lastprioL, v.lastprioU, v.windL or 999, v.windU or 999, v.first,getTipo(v[v.first])))
			end
		end
		prtableD(Status.sorted)
		prtableDD(Status.edges)
		for k,e in pairs(Status.edges) do printD("ed key",k) end
		printD"--------------------"
		--E:faces_print()
		end
	end
	local function StatusPrint(_Status,...)
		
		print("----Status sorted----------",...)
		for i,k in ipairs(_Status.sorted) do
			local v = _Status.edges[k]
			if not v then 
				print(i,k,"not edges")
			else
				print(i,k,E:getPstr(v[1]),E:getPstr(v[2]),"prios",Ptoind[v[1]],Ptoind[v[2]],"lastprio",v.lastprioL,v.lastprioU,"wind",v.windL,v.windU)
			end
		end
		--prtable(_Status.sorted)
		--prtable(_Status.edges)
		print"--------------------"
		--E:faces_print()
	end

	
	local function StatusFirstCalc()
		for k,e in pairs(Status.edges) do
			if getPrio(e[1]) < getPrio(e[2]) then
				e.first = 1;e.second = 2
			else
				e.first = 2;e.second = 1
			end
		end
	end
	
	local function StatusCheck(ii,...)
		local prio = getPrio(ii)
		local function lastpriocheck(l,e)
			if not (getPrio(l)>=getPrio(e[e.first]) and getPrio(l)<=getPrio(e[e.second])) then
				print("bad last prio", e[e.first],e[e.second],l,"prios",getPrio(e[e.first]),getPrio(e[e.second]),getPrio(l))
				error"bad last prio"
			end
		end
		printD("----Status check----------prio",prio,...)
		for i=1,#Status.sorted-1 do --k in ipairs(Status.sorted) do
			local vu = Status.edges[Status.sorted[i]]
			printD("StatusCheck",vu[1],vu[2])

			assert(vu ,"not edge")
			assert(E.edges[vu[1]].b==vu[2],"bad status edge")
			lastpriocheck(vu.lastprioL,vu)
			lastpriocheck(vu.lastprioU,vu)
			
			local vl = Status.edges[Status.sorted[i+1]]
			if vl then assert(vu.lastprioL==vl.lastprioU,"last dont match") end

			if vu.first == 1 then
				assert(getPrio(vu[1])<getPrio(vu[2]),"bad first1")
			else
				assert(getPrio(vu[1])>getPrio(vu[2]),"bad first1")
			end
			
			if getPrio(vu[vu.second])<prio then 
				printD(vu[1],vu[2],"bad second prio",getPrio(vu[vu.second]),prio )
				error"bad second prio"
			end

		end
		--count edges
		local count = 0
		for k,e in pairs(Status.edges) do count = count + 1 end
		assert(count==#Status.sorted,"mismatch sorted edges")
		--prtable(_Status.sorted)
		--prtable(_Status.edges)
		printD"--------------------"
	end
	--used in StatusCross when doing rev
	--could be e[1], e[2] changed order
	local function StatusCorrectRev(doassert)
		local oldk = {}
		local badedges = {}
		for k,e in pairs(Status.edges) do
			if E.edges[e[1]].b~=e[2] then
				if E.edges[e[2]].b == e[1] then
				--print("correcting",e[1],e[2])
					e[1],e[2] = e[2],e[1]
					e.first, e.second = e.second,e.first
					oldk[k] = e
					Status.sorted[e.order] = e[1]
				else
					if doassert then error"bad edge in StatusCorrectRev" end
					insert(badedges,e)
				end
			end
		end
		for ok,nk in pairs(oldk) do
			if ok~=nk[1] then --whe using commonpoint anew and bnew are a and b
			--Status.edges[nk]= Status.edges[ok]
			--print("deleting",ok)
			Status.edges[ok]=nil
			end
		end
		for ok,nk in pairs(oldk) do
			if ok~=nk[1] then --whe using commonpoint anew and bnew are a and b
			--print("adding",nk[1])
			Status.edges[nk[1]]= nk
			--Status.edges[ok]=nil
			end
		end
		return badedges
	end
	local function StatusCross(e,e1,pt)

		DOprint("StatusCross",e[1],e[2],e1[1],e1[2],pt)

		printStatus("in statuscross1")
		local k = e1[1] 
		prtableD(e,e1)
		insert(P,pt)
		Bridges[#P] = true
		
		if use2pointcross then
			insert(P,pt)
			Bridges[#P] = true
		end

		local x = pt + vec2(1,0)
		local a , b = e[1], e[2]
		local signa = Sign(P[a] or P[E:getP(a)],P[b] or P[E:getP(b)], x) > 0
		local a , b = e1[1], e1[2]
		local signc = Sign(P[a] or P[E:getP(a)],P[b] or P[E:getP(b)], x) > 0
		local testrev = use_test_rev and signa == signc
		local sameface = E.edges[e[1]].face==E.edges[e1[1]].face
		--print("testrev",testrev,"sameface",sameface)
		
		
		if e1.first==1 then
			E:add_point(e[1],e1[1],#P,use2pointcross and #P-1 or #P,testrev)
		else
			E:add_point(e[1],e1[1],use2pointcross and #P-1 or #P,#P,testrev)
		end

		local e1ind = Ptoind[E:getP(e1[e1.first])]
		local eind = Ptoind[E:getP(e[e.first])]
		local maxeind = e1ind>eind and e1ind or eind
		--Ptoind[#P] = maxeind+0.5
		--search priority for pt
		local toinsert 
		for i=maxeind,#inds do
			if CG.lexicografic_compare(pt,P[inds[i]]) then
				toinsert = i
				break
			end
		end
		insert(inds,toinsert,#P)
		if use2pointcross then
			insert(inds,toinsert,#P-1)
		end
		for j=1,#P do Ptoind[inds[j]]=j end
		-----------
		local e1second = e1.first==1 and 2 or 1
		assert(e1.second==e1second)
		local esecond = e.first==1 and 2 or 1
		assert(esecond==e.second)
		
		--[=[
		--check
		if not testrev then
			--a-d
			assert(E.edges[e[1]].b == E.edges[e1[2]].prev)
			--c-b
			assert(E.edges[e1[1]].b == E.edges[e[2]].prev)
		else
			--a-c
			assert(E.edges[e[1]].b == E.edges[e1[1]].prev)
			--b-d
			assert(E.edges[e[2]].b == E.edges[e1[2]].prev)
		end
		--]=]
		
		--c-d
		if e1.first == 1 then
			printD("e1f1",e1.first,e1[1],e1[2],E.edges[e1[1]].b)
			if testrev then
				e1[e1second] = E.edges[e1[1]].prev
				-- e1[1],e1[2]=e1[2],e1[1]
				-- e1.first,e1.second = e1.second,e1.first
			else
				e1[e1second] = E.edges[e1[1]].b 
			end
		else --e1.first == 2
			printD("e1f2",e1.first,e1[1],e1[2],E.edges[e1[2]].b,E.edges[e1[2]].prev)
			if testrev then
				if not sameface then
					e1[1] = E.edges[e1[2]].b 
					-- e1[1],e1[2]= e1[2],e1[1]
					-- e1.first,e1.second = e1.second,e1.first
				else
					e1[1] = E.edges[e1[2]].prev
				end
			else
				e1[1] = E.edges[e1[2]].prev
			end
		end
		--a-b
		if e.first == 1 then
			printD("ef1",e.first,e[1],e[2],E.edges[e[1]].b)
			if testrev then
				e[esecond] = E.edges[e[1]].b
			else
				e[esecond] = E.edges[e[1]].b
			end
			
		else --e1.first == 2
			printD("ef2",e.first,e[1],e[2],E.edges[e[2]].prev)
			if testrev then
				if not sameface then
					e[1] = E.edges[e[2]].prev 
				else
					e[1] = E.edges[e[2]].b 
					e[1],e[2]= e[2],e[1]
					e.first,e.second = e.second,e.first
				end
			else
				e[1] = E.edges[e[2]].prev  --
			end
		end
		prtableD("-----NEW EDGE e1",e1)
		prtableD("-----NEW EDGE e",e)
		--correct old status

		Status.edges[k] = nil
		Status.edges[e1[1]] = e1
		Status.sorted[e1.order] = e1[1]
		--correct old status
		printStatus("before correctrev 2")
		if testrev then StatusCorrectRev(true) end
		printStatus("after correctrev 2")
		
		Status.sorted[e.order] = e[1]
		--------------------
		Status.edges[e[1]] = e --done after but do now for StatusCorrectRev
		--------------------
		--after new
		--printStatus("before correctrev 3")
		printStatus("in statuscross")
		--prtable(Status)
		E:faces_print("in statuscross")
		E:check()
		
		
		--StatusCheck("after statuscross")
		--error"DEBUG"
		 --#P
		--e[e.first] = #P
		--printD("intersec inds","inds",e[1],e[2],e1[1],e1[2])
		--printD("intersec",pt,"points",P[e[1]],P[e[2]],P[e1[1]],P[e1[2]])
		return testrev
	end

	local function StatusAdd(e)
		printD("---StatusAdd",e[1],e[2])
		--test intersection
		--if Ptoind[e[1]] < Ptoind[e[2]] then
		--printD("yyyy",getPrio(e[1]) , getPrio(e[2]))
		if getPrio(e[1]) < getPrio(e[2]) then
			--e.first = 1;e.second = 2
			assert(e.first==1 and e.second==2)
		else
			--e.first = 2;e.second = 1
			assert(e.first==2 and e.second==1)
		end
		local crossing 
		local tmin = math.huge
		if search_cross then
			for k,e1 in pairs(Status.edges) do
				--printStatus()
				--local va,vb = P[E:getP(e[1])],P[E:getP(e[2])]
				local va,vb = P[E:getP(e[e.first])],P[E:getP(e[e.second])]
				--local inter = CG.SegmentIntersect(va,vb,P[e1[1]],P[e1[2]])
				--printD(va,vb,P[E:getP(e1[1])],P[E:getP(e1[2])],true)
				local inter,pt,t,u = CG.SegmentIntersecPoint(va,vb,P[E:getP(e1[1])],P[E:getP(e1[2])],true)
				if inter and not (vb==P[E:getP(e1[2])]) then
					
					printD("intersection",E:getPstr(e[1]),E:getPstr(e[2]),E:getPstr(e1[1]),E:getPstr(e1[2]),va,vb,P[E:getP(e1[1])],P[E:getP(e1[2])],"t,u",t,u,t>0,t<1,u>0,u<1,vb==P[E:getP(e1[2])])
					--error"intersection"
					--StatusCross(e,e1,pt)
					if t<tmin then
						tmin = t
						crossing = {e1=e1,pt=pt,t}
					end
				--end
				end
			end
			if crossing then
				local rev = StatusCross(e,crossing.e1,crossing.pt)
				return rev
			end
		end
		Status.edges[e[1]] = e
		printStatus("end StatusAdd",e[1],e[2])
		return false
		--prtable(Status)
	end
	
	local function Pequal(P,a,b)
		--return P[E:getP(a)] == P[E:getP(b)]
		return (P[a] or P[E:getP(a)]) == (P[b] or P[E:getP(b)])
	end
	local function NoCollapsedWalk(i,j,dir)
		local visited = {}
		while Pequal(P,i,j) do
			visited[j] = true
			j = E.edges[j][dir]
			assert(not visited[j])
		end
		return j
	end
	--no collapsed prev and succ
	local function getStartPoints(i)
		local inf = E.edges[i]
		local prev = inf.prev
		local succ = inf.b
		prev = NoCollapsedWalk(i,prev,"prev")
		succ = NoCollapsedWalk(i,succ,"b")
		--printD("getStartPoints",E:getPstr(i),E:getPstr(prev),E:getPstr(succ))
		local canspike = false
		if Pequal(P,prev,succ) then 
			printD"can be spike-------------------" 
			canspike = true
			-- prev = NoCollapsedWalk(prev,prev,"prev")
			-- succ = NoCollapsedWalk(succ,succ,"b")
			-- printD("spike getStartPoints",E:getPstr(i),E:getPstr(prev),E:getPstr(succ))
		end
		
		return prev, succ, canspike
	end
	--searchs right from a collapsed edge
	local function NoCollapsedEdge(e1)
		local e1first, e1second = e1[e1.first],e1[e1.second]
		local visited ={}
		local ea
		if e1.first == 1 then
			local e2 = e1second
			repeat
				local inf = E.edges[e2]
				ea = e2
				visited[e2] = true
				e2 = inf.b
			until not Pequal(P,e1second,e2) or visited[e2]
			assert(not visited[e2],"loop NoCollapsedEdge")
			return e2, {ea,e2,first=1,second=2}
		else --e1.first == 2
			local e2 = e1second
			repeat
				local inf = E.edges[e2]
				ea = e2
				visited[e2] = true
				e2 = inf.prev
			until not Pequal(P,e1second,e2)  or visited[e2]
			assert(not visited[e2],"loop NoCollapsedEdge")
			return e2, {e2,ea,first=2,second=1}
		end
	end
	local function checkStartSigns(s1,s2)
		printD("checkStartSigns",s1,s2,(s1>0),(s2>0))
		--round to zero
		if math.abs(s1)< 1e-10 then s1=0 end
		if math.abs(s2)< 1e-10 then s2=0 end
		-----------------------------------
		if s1==0 and s2==0 then --two zeros
			error"spike"
		elseif s1==0 or s2==0 then --one zero
			return s1>0 or s2>0
		elseif (s1>0)==(s2>0) then --same signs
			return s1>0
		else --different signs
			print(s1,s2)
			error"crossing"
		end
		-- if (s1>0)==(s2>0) then
			-- if s1 == 0 then
				-- error"spike"
			-- elseif s1 > 0 then
				-- return true
			-- else --s1 <0
				-- return false
			-- end
		-- else
			-- if s1==0 or s2==0 then
				-- return s1>=0 and s2>=0
			-- else -- + and -
				-- error"crossing"
			-- end
		-- end
	end
	local function SpikeResolve(a,b)
		printD("SpikeResolve",a,b)
		
		a = NoCollapsedWalk(a,a,"prev")
		b = NoCollapsedWalk(b,b,"b")
		if a==b then
			printD("found",a,b)
			--E:faces_print()
			local polind = E:get_polind(a)
			local sigA = signed_area(P,polind)
			print(#polind,sigA)
			error"SpikeResolve bad checking"
		end
		return a,b,Pequal(P,a,b)
	end
	--After and Before Lexicographycally from e[1] and e[2]
	local function AfterBeforeEdge(e)
		local es1,es2
		if e.second==1 then
			es1 = E.edges[e[e.second]].prev
			es2 = E.edges[e[e.first]].b
			es1 = NoCollapsedWalk(e[e.second],es1,"prev")
			es2 = NoCollapsedWalk(e[e.first],es2,"b")
		else --second==2
			es1 = E.edges[e[e.second]].b
			es2 = E.edges[e[e.first]].prev
			es1 = NoCollapsedWalk(e[e.second],es1,"b")
			es2 = NoCollapsedWalk(e[e.first],es2,"prev")
		end
		--if Pequal(P,es[1],es[2]) then return NoCollapsedEdge(es) end
		return es2,es1
	end
	--for E:Sign(P,e1[e1.first],e1[e1.second],ir)==0
	-- i is a start point
	--answers if e1 is below i
	local function IsBelowZ(e1,i)
		assert(getTipo(i)=="start")-- or getTipo(i)=="end")
		local e1first, e1second = e1[e1.first],e1[e1.second]
		printD("IsBelowZ",e1first, e1second,i)
		--E:faces_print()
		--collapsed edge
		if Pequal(P,e1first,e1second) then
			local e2, ea = NoCollapsedEdge(e1)
			printD("NoCollapsed",e2)
			local sign = E:Sign(P,e1second,e2,i)
			if sign > 0 then
				return true
			elseif sign < 0 then
				return false
			else --sign==0
				return IsBelowZ(ea,i)
			end
		elseif Pequal(P,e1first,i) then
			local a,b,cs = getStartPoints(i)
			::REDO::
			local s1 = E:Sign(P,e1first,e1second,a)
			if cs and s1==0 then a,b,cs = SpikeResolve(a,b);goto REDO end
			--printD(E:getPstr(e1first),E:getPstr(e1second),a,"sign",s1)
			local s2 = E:Sign(P,e1first,e1second,b)
			printD(e1first,e1second,b,"sign",s2)
			return checkStartSigns(s1,s2)
		elseif Pequal(P,e1second,i) then
				local e2ff, ea = NoCollapsedEdge(e1)
				local e2a,e2b = AfterBeforeEdge(e1)
				assert(e2b==e2ff,"AfterBeforeEdge")
				local e2 = e2b
				
				--if goes leftward
				if getPrio(e1[e1.second]) > getPrio(e2) then
					local sign = E:Sign(P,e1first,e1second,e2)
					assert(sign~=0)
					return sign < 0
				else --goes right
					local a,b,cs = getStartPoints(i)
					::REDO::
					local s1 = E:Sign(P,e1second,e2,a)
					if cs and s1==0 then a,b,cs = SpikeResolve(a,b);goto REDO end
					local s2 = E:Sign(P,e1second,e2,b)
					return checkStartSigns(s1,s2)
				end
		else --i between e1first and e1second
			local a,b,cs = getStartPoints(i)
			::REDO::
			local s1 = E:Sign(P,e1first,e1second,a)
			if cs and s1==0 then a,b,cs = SpikeResolve(a,b);goto REDO end
			local s2 = E:Sign(P,e1first,e1second,b)
			return checkStartSigns(s1,s2)
		end
	end
	local function IsBelow(e1,i)
		local e1first, e1second = e1[e1.first],e1[e1.second]
		local sign = E:Sign(P,e1first,e1second,i)
		--printD("IsBelow",E:getPstr(e1first), E:getPstr(e1second),"point:",E:getPstr(i))
		if sign > 0 then
			return true
		elseif sign < 0 then
			return false
		end
		do return IsBelowZ(e1,i) end
		--E:faces_print()
		--sign==0 collinear
		local inf = E.edges[i]
		--printD("checking",E:getPstr(inf.b) , E:getPstr(inf.prev))
		local ss = E:Sign(P,i,inf.prev,inf.b)
		if ss==0 then
			printD(E:getP(i),E:getP(inf.prev),E:getP(inf.b),getTipo(i))
			printD(P[E:getP(i)],P[E:getP(inf.prev)],P[E:getP(inf.b)])
			local ir,prevr,succr = P[E:getP(i)],P[E:getP(inf.prev)],P[E:getP(inf.b)]
			if ir==prevr then
				local inf_prev = E.edges[inf.prev]
				ss = E:Sign(P,i,inf_prev.prev,inf.b)
				printD("ir==prevr",ss1,i,inf_prev.prev,inf.b)
			elseif ir==succr then
				local inf_succ = E.edges[inf.b]
				ss = E:Sign(P,i,inf.prev,inf_succ.b)
				printD("ir==succr",ss1,i,inf.prev,inf_succ.b)
			else
				assert(prevr==succr)
			end
			
		end
		assert(ss~=0,"IsBelow zero")
		-- local eabove = ss > 0 and i or inf.prev
		-- local ebelow = eabove == inf.prev and i or inf.prev
		local pabove = (ss > 0) and inf.b or inf.prev
		local pbelow = (pabove == inf.prev) and inf.b or inf.prev
		printD("edge",e1first,e1second,"pabove,pbelow",pabove,pbelow)
		local s1 = E:Sign(P,e1first,e1second,pabove)
		local s2 = E:Sign(P,e1first,e1second,pbelow)
		printD(pabove,pbelow,"s1,s2",s1,s2)
		--assert(s1==0 or s2==0)
		if s1==0 then
			assert(s2<0)
			return false
		elseif s2==0 then
			assert(s1>0)
			return true
		else
			assert((s1>0)==(s2>0))
			local nextp
			if e1.first == 1 then
				nextp = E.edges[e1second].b
			else
				nextp = E.edges[e1second].prev
			end
			local s1 = E:Sign(P,e1second,nextp,pabove)
			local s2 = E:Sign(P,e1second,nextp,pbelow)
			printD("e1second,nextp",e1second,nextp,"s1,s2",s1,s2)
			assert((s1>0)==(s2>0))
			return s1>0
		end
	end
	
	local function StatusPointAdd(i)--,tipo)
		--tipo = tipo or getTipo(i)
		local tipo = getTipo(i)
		printD("StatusPointAdd",i,tipo)
		local sorted = Status.sorted
		local edges = Status.edges
		-- if edges[i] then
			-- error"readition"
		-- end
		if tipo=="start" then
			local e
			for j=1,#sorted do
				local e1 = edges[sorted[j]]
				if IsBelow(e1,i) then
					e = e1
					break
				end
			end
			local eorder = e and e.order or #sorted + 1
			local inf = E.edges[i]
			--local above = P[inf.prev].y > P[inf.b].y and inf.prev or i
			local above = E:Sign(P,i,inf.prev,inf.b) > 0 and i or inf.prev
			local below = above == inf.prev and i or inf.prev
			table.insert(sorted,eorder,below)
			table.insert(sorted,eorder,above)
			for j=eorder,#sorted do
				local s = sorted[j]
				local edgs = edges[s]
				if edgs then edgs.order = j end
			end
			local e1 = {above,above==i and inf.b or i,order=eorder,lastprioU=i,lastprioL=i,first=above==i and 1 or 2 ,second=above==i and 2 or 1}
			local e2 = {below,below==i and inf.b or i,order=eorder+1,lastprioU=i,lastprioL=i,first=below==i and 1 or 2 ,second=below==i and 2 or 1}
			local cross = StatusAdd(e1)
			if cross then
				if E.edges[e2[1]].b~=e2[2] then
					e2[1],e2[2] = e2[2],e2[1]
					e2.first, e2.second = e2.second,e2.first
					assert(E.edges[e2[1]].b==e2[2],"bad StatusCorrectRevPointAdd")
					sorted[eorder + 1] = e2[1]
				end
			end
			StatusAdd(e2)
			--printStatus("after statuspointadd in start")
			for j=eorder,#sorted do
				local s = sorted[j]
				local edgs = edges[s]
				local sup = sorted[j-1]
				local edgsup = edges[sup] or {windL=0}
				--print(edgs,edgsup,j,j-1)
				edgs.order = j
				edgs.windU = edgsup.windL
				local wind = edgs.first == 1 and -1 or 1
				edgs.windL = wind + edgs.windU
			end
		elseif tipo=="end" then
			local inf = E.edges[i]
			--printD("StatusPointAdd end search edges",E:getPstr(inf.prev),E:getPstr(i),E:getPstr(inf.b))
			local e1 = edges[inf.prev]
			local e2 = edges[i]
			edges[inf.prev] = nil
			edges[i] = nil
			--assert(math.abs(e1.order-e2.order)==1,"not contigous")
			local loworder = e1.order < e2.order and e1.order or e2.order
			local hiorder = (loworder == e1.order) and e2.order or e1.order
			local sorted = Status.sorted
			remove(sorted,hiorder)--loworder)
			remove(sorted,loworder)
			for j=loworder,#sorted do
				local sup = sorted[j-1]
				local edgsup = edges[sup] or {windL=0}
				local s = sorted[j]
				local edgs = edges[s]
				edgs.order = j
				edgs.windU = edgsup.windL
				local wind = edgs.first == 1 and -1 or 1
				edgs.windL = wind + edgs.windU
			end
		elseif tipo=="upper" then
			local inf = E.edges[i]
			local e = edges[i]
			--StatusAdd{inf.prev,i,order=e.order,lastprioU=i,lastprioL=i,first=2,second=1,windU=e.windU,windL=e.windL}
			edges[i] = nil
			Status.sorted[e.order] = inf.prev
			StatusAdd{inf.prev,i,order=e.order,lastprioU=i,lastprioL=i,first=2,second=1,windU=e.windU,windL=e.windL}
		elseif tipo=="lower" then
			local inf = E.edges[i]
			local e = edges[inf.prev]
			--StatusAdd{i,inf.b,order=e.order,lastprioU=i,lastprioL=i,first=1,second=2,windU=e.windU,windL=e.windL}
			edges[inf.prev] = nil
			Status.sorted[e.order] = i
			StatusAdd{i,inf.b,order=e.order,lastprioU=i,lastprioL=i,first=1,second=2,windU=e.windU,windL=e.windL}
		end
	end
	local function StatusPointRemove(i)
		local tipo = getTipo(i)
		printD("StatusPointRemove",E:getPstr(i),tipo)
		local sorted = Status.sorted
		local edges = Status.edges
		-- if edges[i] then
			-- error"readition"
		-- end
		if tipo=="end" then
			local e
			for j=1,#sorted do
				local e1 = edges[sorted[j]]
				if IsBelow(e1,i) then
					e = e1
					break
				end
			end
			local eorder = e and e.order or #sorted + 1
			local inf = E.edges[i]
			--local above = P[inf.prev].y > P[inf.b].y and inf.prev or i
			local above = E:Sign(P,i,inf.prev,inf.b) > 0 and i or inf.prev
			local below = above == inf.prev and i or inf.prev
			table.insert(sorted,eorder,below)
			table.insert(sorted,eorder,above)
			for j=eorder,#sorted do
				local s = sorted[j]
				local edgs = edges[s]
				if edgs then edgs.order = j end
			end
			StatusAdd{above,above==i and inf.b or i,order=eorder,lastprioU=i,lastprioL=i,second=above==i and 1 or 2 ,first=above==i and 2 or 1}
			StatusAdd{below,below==i and inf.b or i,order=eorder+1,lastprioU=i,lastprioL=i,second=below==i and 1 or 2 ,first=below==i and 2 or 1}
			--printStatus("after statusadd in start")
			for j=eorder,#sorted do
				local s = sorted[j]
				local edgs = edges[s]
				local sup = sorted[j-1]
				local edgsup = edges[sup] or {windL=0}
				--print(edgs,edgsup,j,j-1)
				edgs.order = j
				edgs.windU = edgsup.windL
				local wind = edgs.first == 1 and -1 or 1
				edgs.windL = wind + edgs.windU
			end
		elseif tipo=="start" then
			local inf = E.edges[i]
			--printD("StatusPointAdd end search edges",E:getPstr(inf.prev),E:getPstr(i),E:getPstr(inf.b))
			local e1 = edges[inf.prev]
			local e2 = edges[i]
			edges[inf.prev] = nil
			edges[i] = nil
			--assert(math.abs(e1.order-e2.order)==1,"not contigous")
			local loworder = e1.order < e2.order and e1.order or e2.order
			local hiorder = (loworder == e1.order) and e2.order or e1.order
			local sorted = Status.sorted
			remove(sorted,hiorder)--loworder)
			remove(sorted,loworder)
			for j=loworder,#sorted do
				local sup = sorted[j-1]
				local edgsup = edges[sup] or {windL=0}
				local s = sorted[j]
				local edgs = edges[s]
				edgs.order = j
				edgs.windU = edgsup.windL
				local wind = edgs.first == 1 and -1 or 1
				edgs.windL = wind + edgs.windU
			end
		elseif tipo=="lower" then
			local inf = E.edges[i]
			local e = edges[i]
			StatusAdd{inf.prev,i,order=e.order,lastprioU=i,lastprioL=i,first=1,second=2,windU=e.windU,windL=e.windL}
			edges[i] = nil
			Status.sorted[e.order] = inf.prev
		elseif tipo=="upper" then
			local inf = E.edges[i]
			local e = edges[inf.prev]
			StatusAdd{i,inf.b,order=e.order,lastprioU=i,lastprioL=i,first=2,second=1,windU=e.windU,windL=e.windL}
			edges[inf.prev] = nil
			Status.sorted[e.order] = i
		end
	end
	local function SearchAbove(ii,tipo)
		printD("SearchAbove",ii)
		local skippoint = not (tipo=="start") --tipo=="end" or tipo=="upper" 
		local Regions = {}
		local y = P[ii].y
		local efound,yfound = nil,math.huge
		local efoundL,yfoundL = nil,-math.huge
		local kfound,kfoundL
		for k,e in pairs(Status.edges) do
			printD("SearchAbove1",ii,k,e[1],e[2],"lastprio",e.lastprioL,e.lastprioU)
			if skippoint and e[e.second] == ii then 
				e.pty = y
				--prtable(Regions[1],e)
				if Regions[1] and (P[Regions[1][Regions[1].first]].y < P[e[e.first]].y) then
					insert(Regions,1,e)
				else
					insert(Regions,e)
				end
				goto SKIP 
			end
			local pt, ok = IntersecSweepLine(P[e[1]],P[e[2]],P[ii])
			--assert(ok,"intersec fail")
			if not ok then
				printD"----intersec fail"
				printD(e[1],e[2],ii,P[e[1]],P[e[2]],P[ii])
				error"----intersec fail"
			end
			if ok then
			    local pty = pt.y
				e.pty = pty
				printD("SearchAbove2",ii,k,pty,y,yfound)
				if pty > y then
				--if yfound then
					if yfound > pty then
						printD"Searchline found"
						yfound = pty
						efound = e
						kfound = k
					end
				elseif pty<y then
					if yfoundL < pty then
						yfoundL = pty
						efoundL = e
						kfoundL = k
					end
				end
			end
			::SKIP::
		end
		--prtable("SearchAbove returns",efound)
		--if not efound then prtable(y,Status) end
		--return efound,kfound,efoundL,kfoundL --Status[Status.sorted[efound].k]
		if efound then insert(Regions,1,efound) end
		if efoundL then insert(Regions,efoundL) end
		return Regions
	end
	local function SignRegions(ii)
		--printD("SignRegions",E:getPstr(ii),"edges",E.edges[ii].prev,E.edges[ii].b)
		local iir = E:getP(ii)
		local edges = Status.edges
		local sorted = Status.sorted
		for j=1,#sorted do
			local e1 = edges[sorted[j]]
			local sign = E:Sign(P,e1[e1.first],e1[e1.second],iir)
			if sign==0 then
				local s1 = E:Sign(P,e1[e1.first],e1[e1.second],E.edges[ii].b)
				local s2 = E:Sign(P,e1[e1.first],e1[e1.second],E.edges[ii].prev)
				printD("SignRegions",j,"edge",e1[e1.first],e1[e1.second],"ss",sign,s1,s2)
			else
				printD("SignRegions",j,"edge",e1[e1.first],e1[e1.second],"ss",sign)
			end
		end
	end
	local function SearchRegions(ii,tipo)
		printD("SearchRegions",E:getPstr(ii),tipo)
		local iir = E:getP(ii)
		local Regions = {}
		local iregion
		local edges = Status.edges
		local sorted = Status.sorted
		if tipo == "start" then
			local e
			--SignRegions(ii)
			for j=1,#sorted do
				local e1 = edges[sorted[j]]
				--search first below i
				if IsBelow(e1,ii) then
					e = e1
					break
				end
			end
			if e then
				insert(Regions,edges[sorted[e.order-1]])
				iregion = {#Regions+0.5,#Regions+ 0.5}
				insert(Regions,edges[sorted[e.order]])
				--assert(#Regions==2,#Regions)
				
			elseif #sorted>0 then --must be lowest
				insert(Regions,edges[sorted[#sorted]])
				iregion = {1.5,1.5}
			else
				--no Region no iregion
				--assert(false)
			end
		elseif tipo == "end" then
			local inf = E.edges[ii]
			local e1 = edges[inf.prev]
			local e2 = edges[ii]
			printD("end edges",inf.prev,ii)
			local above = e1.order < e2.order and e1 or e2
			local below = above==e1 and e2 or e1
			if above.order > 1 then
				insert(Regions,edges[sorted[above.order-1]])
			end
			printD("SearchRegions end",#Regions,"orders",above.order,below.order)
			if #Regions > 0 then iregion = {2,3} else iregion = {1,2} end
			insert(Regions,above)
			insert(Regions,below)
			if below.order < #sorted then
				insert(Regions,edges[sorted[below.order+1]])
			end
			-- print"end edges"
			-- print(edges[sorted[above.order-1]][1])
			-- print(above[1])
			-- print(below[1])
			-- print(edges[sorted[below.order+1]][1])
		elseif tipo == "upper" then
			local e = edges[ii]
			insert(Regions,edges[sorted[e.order-1]])
			insert(Regions,e)
			iregion = {#Regions,#Regions}
			insert(Regions,edges[sorted[e.order+1]])
			--iregion = {2,2}
		else
			assert(tipo=="lower")
			local inf = E.edges[ii]
			--prtable(ii,inf)
			local e = edges[inf.prev]
			insert(Regions,edges[sorted[e.order-1]])
			insert(Regions,e)
			iregion = {#Regions,#Regions}
			insert(Regions,edges[sorted[e.order+1]])
			--iregion = {2,2}
		end
		return Regions,iregion
	end

	
	local pointTipos = {}
	local check_pair1
	local function StatusSortedRepair()
		for i,v in ipairs(Status.sorted) do
			Status.edges[v].order = i
		end
	end
	local function DeleteStatus(a)
		printD("DeleteStatus",a,getTipo(a))
		local infa = E.edges[a]
		if Status.edges[a] then
			local e = Status.edges[a]
			Status.edges[a] = nil
			printD("Delete",a,"edge",e[1],e[2])
			remove(Status.sorted,e.order)
			StatusSortedRepair()
		end
		if Status.edges[infa.prev] then
			local e = Status.edges[infa.prev]
			Status.edges[infa.prev] = nil
			printD("Delete",infa.prev,"edge",e[1],e[2])
			remove(Status.sorted,e.order)
			StatusSortedRepair()
		end
	end
	------------for correct status
	local function ChangeLastPrio(e,a,anew)
		--prtable(e)
		if a==anew then return end
		printD("ChangeLastPrio",a,anew)
		if e.lastprioL == a then e.lastprioL = anew end
		if e.lastprioU == a then e.lastprioU = anew end
	end
	local function reverseSedge(k,e,oldk)
		e[1],e[2] = e[2],e[1]
		Status.sorted[e.order] = e[1]
		oldk[k] = e
	end
	local function deleteSedge(k,e)
		remove(Status.sorted,e.order)
		Status.edges[k] = nil
	end
	local function CScopoint2(a,b)
		local oldk = {}
		for k,e in pairs(Status.edges) do
			if e[1]==a or e[2]==a or e[1]==b or e[2]==b then
				local acollap = not E:not_collapsed(a)
				local bcollap = not E:not_collapsed(b)
			--print("edge",e[1],e[2])
				if e[1] == b then
					if bcollap then
						deleteSedge(k,e)
					else
						local infb = E.edges[b]
						if e[2] == infb.b then
						elseif e[2] == infb.prev then
							reverseSedge(k,e,oldk)
						else
							e[2] = inf.b --TODO rev
						end
					end
				elseif e[2] == b then
					if bcollap then
						deleteSedge(k,e)
					else
						local infb =  E.edges[b]
						if e[1] == infb.prev then
						elseif e[1] == infb.b then
							reverseSedge(k,e,oldk)
						else
							--TODO rev
							e[1] = infb.prev
							Status.sorted[e.order] = e[1]
							oldk[k] = e
						end
					end
				elseif e[1] == a then
					if acollap then
						deleteSedge(k,e)
					else
						local inf = E.edges[e[1]]
						--if inf.b==e[2] --bien
						if inf.prev == e[2] then
							reverseSedge(k,e,oldk)
						elseif not inf.b == e[2] then
							--TODO reverse?
							e[2] = inf.b
						end
					end
				else --e[2]==a
					if acollap then
						deleteSedge(k,e)
					else
						local inf = E.edges[a]
						if inf.prev==e[1] then
						elseif inf.b == e[1] then
							reverseSedge(k,e,oldk)
						else --TODO reverse
							e[1] = inf.prev
							Status.sorted[e.order] = e[1]
							oldk[k] = e
						end
					end
				end
			else --not a or b but could be reversed
				local inf = E.edges[e[1]]
				if inf.prev == e[2] then
					reverseSedge(k,e,oldk)
					--error"reverse in CScopoint"
				end
			end
		end
		--prtable(Status)
		for ok,nk in pairs(oldk) do
			if ok~=nk then --whe using commonpoint anew and bnew are a and b
			--Status.edges[nk]= Status.edges[ok]
			Status.edges[ok]=nil
			end
		end
		for ok,nk in pairs(oldk) do
			if ok~=nk then --whe using commonpoint anew and bnew are a and b
			Status.edges[nk[1]]= nk
			--Status.edges[ok]=nil
			end
		end
		StatusSortedRepair()
		--check b new edges

		if false and not bcollap then
			local inf = E.edges[b]
			--if Status.edges[b] and Status.edges[inf.prev] then
			--else
			if Status.edges[b] then
				deleteSedge(b,Status.edges[b])
			end
			if Status.edges[inf.prev] then
				deleteSedge(inf.prev,Status.edges[inf.prev])
			end
			StatusSortedRepair()
			
				-- local reg,ireg = SearchRegions(b,getTipo(b))
				-- SetRegionsLastprio(ireg,reg,b)
				StatusPointAdd(b)
		end
		
		if false and not acollap then
			local inf = E.edges[a]
			if getPrio(inf.prev)<getPrio(a) then
				local infpr = E.edges[inf.prev]
				if Status.edges[infpr.prev] then
					deleteSedge(infpr.prev,Status.edges[infpr.prev])
				end
				if Status.edges[infpr.b] then
					deleteSedge(infpr.b,Status.edges[infpr.b])
				end
				StatusSortedRepair()
				StatusPointAdd(inf.prev)
				-- error"mnmgggggggnfgh"
			end
		end
		

		--prtable(Status)
	end
	-------------------------------------
	local function IsBelow2(e1,i)
		local e1first, e1second = e1[e1.first],e1[e1.second]
		local sign = E:Sign(P,e1first,e1second,i)
		--printD("IsBelow",E:getPstr(e1first), E:getPstr(e1second),"point:",E:getPstr(i))
		if sign > 0 then
			return true
		elseif sign <= 0 then
			return false
		end
		--do return IsBelowZ(e1,i) end
	end
	local function CSsearch(ii)
		local edges = Status.edges
		local sorted = Status.sorted
		local e
		--SignRegions(ii)
		for j=1,#sorted do
			local e1 = edges[sorted[j]]
			--search first below i
			if IsBelow2(e1,ii) then
				e = e1
				break
			end
		end
		local eorder = e and e.order or #sorted + 1
		do return eorder,e end
		if e then
			-- insert(Regions,edges[sorted[e.order-1]])
			-- iregion = {#Regions+0.5,#Regions+ 0.5}
			-- insert(Regions,edges[sorted[e.order]])
			--assert(#Regions==2,#Regions)
		elseif #sorted>0 then --must be lowest
			-- insert(Regions,edges[sorted[#sorted]])
			-- iregion = {1.5,1.5}
		else
			--no Region no iregion
			--assert(false)
		end
	end
	local function CorrectLastPrio(ii)
		printD("CorrectLastPrio",ii,getTipo(ii))
			--[==[
			for i=1,#Status.sorted do
				local ee = Status.edges[Status.sorted[i]]
				local el = Status.edges[Status.sorted[i+1]]
				local eu = Status.edges[Status.sorted[i-1]]
				printD("corect last",ee[1],ee[2],"pr",getPrio(ee[1]) ,getPrio(ee[2]),"f",ee[ee.first],ee[ee.second])
				if el then
					printD("priosL",getPrio(ee[ee.first]), getPrio(el[el.first]),getPrio(ee.lastprioL),"bb",ee[ee.first], el[el.first],ee.lastprioL)
					if getPrio(ee[ee.first]) < getPrio(el[el.first]) then
						-- ee.lastprioL = el[el.first] 
						ee.lastprioL = getPrio(ee.lastprioL) <= getPrio(el[el.first]) and el[el.first] or ee.lastprioL
					elseif getPrio(ee[ee.first]) > getPrio(el[el.first]) then
						-- ee.lastprioL = ee[ee.first]
						ee.lastprioL = getPrio(ee.lastprioL) <= getPrio(ee[ee.first]) and ee[ee.first] or ee.lastprioL
					elseif getPrio(ee[ee.first]) == getPrio(el[el.first]) then
						-- ee.lastprioL = ee[ee.first]
						ee.lastprioL = getPrio(ee.lastprioL) <= getPrio(ee[ee.first]) and ee[ee.first] or ee.lastprioL
					end
				end
				if eu then 
					printD("priosU",getPrio(ee[ee.first]) ,getPrio(eu[eu.first]),"bb",ee[ee.first], eu[eu.first]  )
					if getPrio(ee[ee.first]) < getPrio(eu[eu.first]) then
						-- ee.lastprioU = eu[eu.first]
						ee.lastprioU = getPrio(ee.lastprioU) <= getPrio(eu[eu.first]) and eu[eu.first] or ee.lastprioU
					elseif getPrio(ee[ee.first]) > getPrio(eu[eu.first]) then
						-- ee.lastprioU = ee[ee.first]
						ee.lastprioU = getPrio(ee.lastprioU) <= getPrio(ee[ee.first]) and ee[ee.first] or ee.lastprioU
					elseif getPrio(ee[ee.first]) == getPrio(eu[eu.first]) then
						-- ee.lastprioU = eu[eu.first]
						ee.lastprioU = getPrio(ee.lastprioU) <= getPrio(eu[eu.first]) and eu[eu.first] or ee.lastprioU
					end
				end
			end
			--]==]
			---[==[
			
			local function checkll(a,e,ee,kind)
				if E:not_collapsed(a) and getTipo(a)=="end" then
				if getPrio(a) > getPrio(e[e.first]) then
					--print(getPrio(a),getTipo(a),E:not_collapsed(a),getPrio(e[e.first]),getPrio(e[e.second]),getPrio(ii))
					--print"lastprio bigger"
					local ord,eb = CSsearch(a)
					--print( "CSsearch",ord,eb,ee.order,kind)
					--print("from",#Status.sorted)
					--do return true end --false to leave lastprio
					if kind=="L" then
						if ee.order+1 == ord then
							return false
						else
							return true
						end
					else --"U"
						if ee.order == ord then
							return false
						else
							return true
						end
					end
				end
				end
				return true
			end
			for i=1,#Status.sorted do
				local ee = Status.edges[Status.sorted[i]]
				local el = Status.edges[Status.sorted[i+1]]
				local eu = Status.edges[Status.sorted[i-1]]
				printD("corect last",ee[1],ee[2],"pr",getPrio(ee[1]) ,getPrio(ee[2]),"f",ee[ee.first],ee[ee.second])
				if el then
					printD("priosL",getPrio(ee[ee.first]), getPrio(el[el.first]),getPrio(ee.lastprioL),"bb",ee[ee.first], el[el.first],ee.lastprioL)
					if getPrio(ee[ee.first]) < getPrio(el[el.first]) then
						if checkll(ee.lastprioL,el,ee,"L") then
						ee.lastprioL = el[el.first] 
						end
						-- ee.lastprioL = getPrio(ee.lastprioL) <= getPrio(el[el.first]) and el[el.first] or ee.lastprioL
					elseif getPrio(ee[ee.first]) > getPrio(el[el.first]) then
						if checkll(ee.lastprioL,ee,ee,"L") then
						ee.lastprioL = ee[ee.first]
						end
						-- ee.lastprioL = getPrio(ee.lastprioL) <= getPrio(ee[ee.first]) and ee[ee.first] or ee.lastprioL
					elseif getPrio(ee[ee.first]) == getPrio(el[el.first]) then
						if checkll(ee.lastprioL,ee,ee,"L") then
						ee.lastprioL = ee[ee.first]
						end
						-- ee.lastprioL = getPrio(ee.lastprioL) <= getPrio(ee[ee.first]) and ee[ee.first] or ee.lastprioL
					end
				end
				if eu then 
					printD("priosU",getPrio(ee[ee.first]) ,getPrio(eu[eu.first]),getPrio(ee.lastprioU),"bb",ee[ee.first], eu[eu.first],ee.lastprioU  )
					if getPrio(ee[ee.first]) < getPrio(eu[eu.first]) then
						if checkll(ee.lastprioU,eu,ee,"U") then
						ee.lastprioU = eu[eu.first]
						end
						-- ee.lastprioU = getPrio(ee.lastprioU) <= getPrio(eu[eu.first]) and eu[eu.first] or ee.lastprioU
					elseif getPrio(ee[ee.first]) > getPrio(eu[eu.first]) then
						if checkll(ee.lastprioU,ee,ee,"U") then
						ee.lastprioU = ee[ee.first]
						end
						-- ee.lastprioU = getPrio(ee.lastprioU) <= getPrio(ee[ee.first]) and ee[ee.first] or ee.lastprioU
					elseif getPrio(ee[ee.first]) == getPrio(eu[eu.first]) then
						if checkll(ee.lastprioU,eu,ee,"U") then
						ee.lastprioU = eu[eu.first]
						end
						-- ee.lastprioU = getPrio(ee.lastprioU) <= getPrio(eu[eu.first]) and eu[eu.first] or ee.lastprioU
					end
				end
			end
			--]==]
	end
	local function Searche2(v)
		for k,e in pairs(Status.edges) do
			if e[2]==v then return e end
		end
	end

	local function repairEdge(e,p,i,inf)
		assert(e[1]==i or e[2]==i)
		if inf.b == p then
			if e[1]==i then
				e[2] = p
			else --e[2]==i
				Status.edges[e[1]] = nil
				e[1] = i
				e[2] = p
				Status.sorted[e.order] = e[1]
				Status.edges[e[1]] = e
			end
		elseif inf.prev == p then
			if e[2] == i then
				Status.edges[e[1]] = nil
				e[1] = p
				Status.sorted[e.order] = e[1]
				Status.edges[e[1]] = e
			else --e[1] == i
				Status.edges[e[1]] = nil
				e[1] = p
				e[2] = i
				Status.sorted[e.order] = e[1]
				Status.edges[e[1]] = e
			end
		else
			error"reapairEdge"
		end
	end
	
	local function CScopointBAK(a,b,l,Regions)
		local ta,tb = l[3],l[4]
		local tanw,tbnw = getTipo(a),getTipo(b)
		local infa = E.edges[a]
		local infb = E.edges[b]
		local acollap = not E:not_collapsed(a)
		local bcollap = not E:not_collapsed(b)
		if acollap or bcollap then print("collaps",acollap,bcollap) end
		if ta=="start" and tb=="start" then
			--go to start start
			local e = Status.edges[b]
			local e2 = Searche2(b)
			--corregir
			local eabove = e.order < e2.order and e or e2
			local ebelow = eabove == e and e2 or e
			local pabove = P[E:getP(infb.b)].y > P[E:getP(infb.prev)].y and infb.b or infb.prev
			local pbelow = pabove == infb.b and infb.prev or infb.b
			repairEdge(eabove,pabove,b,infb)
			repairEdge(ebelow,pbelow,b,infb)
			return
		elseif tb=="end" and ta=="start" then
			assert(tbnw=="upper" and tanw=="lower")
			local eorder = Regions[l.region].order + 1
			
			local eb = {infb.prev,b,order=eorder,lastprioL=b,lastprioU=b,first=2,second=1}
			local ea = {infa.prev,a,order=eorder+1,lastprioL=infa.prev,lastprioU=infa.prev,first=1,second=2}
			--prtable(eb,ea)
			StatusCorrectRev(true)
			insert(Status.sorted,eorder,eb[1])
			insert(Status.sorted,eorder,ea[1])
			Status.edges[ea[1]] = ea
			Status.edges[eb[1]] = eb
			--CorrectLastPrio()
			return
		elseif tb=="lower" and ta=="upper" then
			assert(tbnw=="start" and tanw=="end","lower uppwer not start end")
			printD("------------add",a,"adding",b)

			if acollap then --remove
				local oa = Status.edges[a]
				remove(Status.sorted,oa.order)
				Status.edges[a] = nil
				StatusSortedRepair()
			else --add anew
				local e = Status.edges[a]
				local na = {infa.prev,a,lastprioL=infa.prev,lastprioU=infa.prev,first=2,second=1}
				if P[E:getP(na[1])].y > P[E:getP(e[2])].y then
					--nb arriba
					insert(Status.sorted,e.order,na[1])
				else
					insert(Status.sorted,e.order+1,na[1])
				end
				Status.edges[na[1]] = na
			end
			
			local e = Status.edges[b]
			local nb = {infb.prev,b,lastprioL=infb.prev,lastprioU=infb.prev,first=2,second=1}
			if P[E:getP(nb[1])].y > P[E:getP(e[2])].y then
				--nb arriba
				insert(Status.sorted,e.order,nb[1])
			else
				insert(Status.sorted,e.order+1,nb[1])
			end
			Status.edges[nb[1]] = nb
			
			return
		elseif tb=="upper" and ta=="lower" then
			assert(tbnw=="end" and tanw=="start","lower uppwer not start end")
			--"DELETING---------",a,b)
			local ob = Status.edges[b] or Searche2(b)
			remove(Status.sorted,ob.order)
			Status.edges[ob[1]] = nil
			StatusSortedRepair()
			
			local ob = Status.edges[a] or Searche2(a)
			remove(Status.sorted,ob.order)
			Status.edges[ob[1]] = nil
			StatusSortedRepair()
			
			-- local e = Status.edges[a]
			-- local na = {infa.prev,a,lastprioL=infa.prev,lastprioU=infa.prev,first=2,second=1}
			-- if P[E:getP(na[1])].y > P[E:getP(e[2])].y then
				-- insert(Status.sorted,e.order,na[1])
			-- else
				-- insert(Status.sorted,e.order+1,na[1])
			-- end
			-- Status.edges[na[1]] = na
			
			return
		elseif false and tb=="lower" and ta=="start" then
			assert(tbnw=="start" and tanw=="lower","lower uppwer not start end")
			print("addd",b,"add",a,"acollap",acollap)
			local infa = E.edges[a] 
			--print("CSsearch",a,CSsearch(a))--,e.order)
			print("replace",infa.prev,a,infa.b)
			
			local e = Status.edges[b]
			local nb = {infb.prev,b,lastprioL=infb.prev,lastprioU=infb.prev,first=2,second=1}
			print("CSsearch",nb[1],CSsearch(nb[1]),e.order)
			if P[E:getP(nb[1])].y > P[E:getP(e[2])].y then
				insert(Status.sorted,e.order,nb[1])
			else
				insert(Status.sorted,e.order+1,nb[1])
			end
			Status.edges[nb[1]] = nb

			return 
		end
		return CScopoint2(a,b)
		--elseif ta=="start" and tb=="end" then
		
	end
local function Sedges(a)
	edgs = {}
	if Status.edges[a] then
		insert(edgs,Status.edges[a])
	end
	local inva = Searche2(a)
	if inva then insert(edgs,inva) end
	return edgs
end
local function Right(a)
	local redges = {}
	local inf = E.edges[a]
	if E:not_collapsed(a) then
	if getPrio(a)<getPrio(inf.b) then
		insert(redges,{a,inf.b})
	end
	if getPrio(a)<getPrio(inf.prev) then
		insert(redges,{inf.prev,a})
	end
	end
	return redges
end
local function Left(a)
	local redges = {}
	local inf = E.edges[a]
	if E:not_collapsed(a) then
	if getPrio(a)>getPrio(inf.b) then
		insert(redges,{a,inf.b})
	end
	if getPrio(a)>getPrio(inf.prev) then
		insert(redges,{inf.prev,a})
	end
	end
	return redges
end
local function todelete(add,present)
	local dels = {}
	for i,v in ipairs(present) do
		local delete = true
		for j,vv in ipairs(add) do
			if v[1]==vv[1] then delete=false;break end
		end
		if delete then insert(dels,v) end
	end
	return dels
end
local function toadd(add,present)
	local adds = {}
	for i,v in ipairs(add) do
		local add = true
		for j,vv in ipairs(present) do
			if v[1]==vv[1] then add=false;break end
		end
		if add then insert(adds,v) end
	end
	return adds
end
local function set_edge_vals(v)
	v.first = getPrio(v[1])<getPrio(v[2]) and 1 or 2
	v.second = v.first==1 and 2 or 1
	v.lastprioL = v[v.first]
	v.lastprioU = v[v.first]
end
local function CScopoint(a,b,l,Regions)
	print("CScopint",a,b,"order",Regions[l.region].order)
	print(b,a,"copoint tipes",l[4],l[3],"to",getTipo(b),getTipo(a))
	local eorder = Regions[l.region].order + 1
	--reverse Status edges if needed
	local badedges = StatusCorrectRev()
	--get b edges going right
	local redges = Right(b)
	--get b edges in Status
	local bSedges = Sedges(b)
	local btodelete = todelete(redges,bSedges)
	local btoadd = toadd(redges,bSedges)
	--get a Left edges
	local ledges = Left(a)
	--bet a edges in status
	local aSedges = Sedges(a)
	local atodelete = todelete(ledges,aSedges)
	local atoadd = toadd(ledges,aSedges)
	local xtoadd = {}
	for i,v in ipairs(atoadd) do insert(xtoadd,v) end
	for i,v in ipairs(btoadd) do insert(xtoadd,v) end
	local xtodelete = {}
	for i,v in ipairs(atodelete) do insert(xtodelete,v) end
	for i,v in ipairs(btodelete) do insert(xtodelete,v) end
	-- prtable(redges,bSedges,ledges,aSedges)
	-- prtable("btodelete",btodelete,btoadd,atodelete,atoadd)
	-- prtable("badedges",badedges)
	--if #btodelete > 0 and #btoadd>0 then prtable(btodelete,btoadd)print"b delete and add--------------------------------------------------------------------------------" end
	--if #atodelete > 0 and #atoadd>0 then print"a delete and add-------------------------------------------------------------------------" end
	if #xtodelete >0 and #xtoadd == 0 then
		--only delete
		--print("CScopoint only delete")
		--borrar de abajo a arriba
		if #xtodelete > 1 then
			algo.quicksort(xtodelete,1,#xtodelete,function(a,b) return a.order > b.order end)
		end
		for i,v in ipairs(xtodelete) do
			deleteSedge(v[1],v)
		end
		StatusSortedRepair()
	elseif #xtodelete ==0 and #xtoadd > 0 then
		--print("CScopoint only add-----------------------------------------------------------------------")
		assert(#xtoadd==2,"only add not 2")
		--only add
		----order abajo-arriba
		E:faces_print()
		local spa = false
		if #btoadd>0 and getTipo(b)=="start" then
			--delete other b
			local otherb = Status.edges[b] or Searche2(b)
			--prtable("otherb-------------------------------------",otherb)
			deleteSedge(otherb[1],otherb)
			StatusSortedRepair()
			--StatusPointAdd(b)
			spa = true
			xtoadd = atoadd
			--DOprintStatus("repair b")
		else
			local b1 = btoadd[1]
			local a1 = atoadd[1]
			set_edge_vals(b1)
			set_edge_vals(a1)
			local aother = ((a1[1]== a) or (a1[1]==b)) and a1[2] or a1[1]
			local bother = ((b1[1]== a) or (b1[1]==b)) and b1[2] or b1[1]
			local infa = E.edges[a]
			local anext = infa.b == aother and infa.prev or infa.b
			local infb = E.edges[b]
			local bnext = infb.b == bother and infb.prev or infb.b
			local sigan = E:Sign(P,a1[a1.first],a1[a1.second],bnext)
			local sigbn = E:Sign(P,b1[b1.first],b1[b1.second],anext)
			local siga = E:Sign(P,a1[1],a1[2],bother)
			local sigb = E:Sign(P,b1[1],b1[2],aother)
			assert((sigan>=0)==(sigbn<=0))
			if sigan < 0 then
				xtoadd = {b1,a1}
			else
				xtoadd = {a1,b1}
			end
			print("sigan",sigan,sigbn)
			print("add",#btoadd,#atoadd,siga,sigb)
		end
		-- if #xtoadd > 1 then
			-- algo.quicksort(xtoadd,1,#xtoadd,function(a1,b1) 
				-- local aother = ((a1[1]== a) or (a1[1]==b)) and a1[2] or a1[1]
				-- local bother = ((b1[1]== a) or (b1[1]==b)) and b1[2] or b1[1]
				-- return P[E:getP(aother)].y < P[E:getP(bother)].y
			-- end)
		-- end
		for i,v in ipairs(xtoadd) do
			set_edge_vals(v)
			insert(Status.sorted,eorder,v[1])
			Status.edges[v[1]] = v
		end
		StatusSortedRepair()
		StatusWindCalc()
		if spa then
					--error"DEBUG"
			print("spa--------------------------------------------------------------------------")
			--DOprintStatus("repair b")
			StatusPointAdd(b)
		end
	else
		--print("CScopoint  delete and add")
		--add and delete
		assert(#xtoadd>0 and #xtodelete>0)
		assert(#xtoadd==#xtodelete)
		assert(#xtoadd==1)
		--print(#xtoadd, #xtodelete,"a",#atoadd,#atodelete,"b",#btoadd,#btodelete,"CScopoint not processed------------------------------------------------------------------")
		local v = xtoadd[1]
		set_edge_vals(v)

		Status.sorted[xtodelete[1].order] = v[1]
		Status.edges[v[1]] = v
		Status.edges[xtodelete[1][1]] = nil
	end
	if  false  then
		-- DOprint = print
		-- E:faces_print()
		-- DOprintStatus();
		prtable("b",btoadd,btodelete); 
		prtable("a",atoadd,atodelete); 
		prtable("bad edges",badedges)
		print"---------------------------------------------------------------------------------------------" 
		-- DOprint = function() end
		-- error"DEBUG"
	end
	if #badedges ~= #atodelete + #btodelete then 
		--print("bad edges",#badedges , #atodelete , #btodelete)
		--error"todelete missmatch-------------------------------------------------------------------------------------------" 
	end

end
local function CorrectStatus(a,b,anew,bnew, copoint,l,Regions)
		--assert((a==anew)==(b==bnew))
		--local commonpoint = (a==anew)
		printD("CorrectStatus",a,b,anew,bnew)
		if copoint then 
			assert((a==anew) and (b==bnew))
			return CScopoint(a,b,l,Regions)
		end
		local oldk = {}
		local sort_del = {}
		for k,e in pairs(Status.edges) do
			if e[1]==a or e[2]==a or e[1]==b or e[2]==b then
				if e[1]==a then
					printD("found e[1]==a",a,e[2])
					prtableD(E.edges[e[2]])
					local inf = E.edges[e[2]]
					local infa = E.edges[a]
					if infa.b == e[2] then
						--bien
					elseif infa.prev == e[2] then
						--rev
						e[1],e[2] = e[2],e[1]
						Status.sorted[e.order] = e[1]
						oldk[k] = e
						--ChangeLastPrio(e,a,inf.b)
						
					elseif inf.prev == anew then
						e[1] = anew
						Status.sorted[e.order] = e[1]
						oldk[a] = e
						ChangeLastPrio(e,a,anew)
					elseif inf.b == anew or inf.b == a then
						--rev
						e[1],e[2] = e[2],inf.b
						Status.sorted[e.order] = e[1]
						oldk[a] = e
						ChangeLastPrio(e,a,inf.b)
					else
						error"ccccccccccccc"
					end
					printD("to",e[1],e[2])
				elseif e[2] ==a then
					printD("found e[2]==a",a,"edge",e[1],e[2])
					prtableD(E.edges[e[1]])
					local inf = E.edges[e[1]]
					if inf.prev == anew or inf.prev == a then
						--rev
						oldk[k] = e
						e[1],e[2] = e[2],inf.prev
						Status.sorted[e.order] = e[1]
						ChangeLastPrio(e,a,inf.prev)
					elseif inf.b == anew then
						e[2] = anew
						ChangeLastPrio(e,a,anew)
					else
						error"cccccccccccccc"
						assert(copoint)
						printD"copoint"
						Status.edges[k] = nil
						--remove(Status.sorted,e.order)
						sort_del[e.order] = true
						-- if inf.b == b then
							-- e[2] = b
						-- elseif inf.prev == b then 
							-- e[1],e[2] = inf.prev,e[1]
							-- oldk[k] = e
							-- Status.sorted[e.order] = e[1]
							-- ChangeLastPrio(e,a,inf.prev)--??
						-- else
							-- error"ccccccccccccc"
						-- end
					end
					printD("to",e[1],e[2])
				elseif e[1] == b then
					printD("found e[1]==b",b,e[2])
					prtableD(E.edges[e[2]])
					local inf = E.edges[e[2]]
					local infb = E.edges[b]
					if e[2] == infb.b then
						--bien
					elseif e[2] == infb.prev then
						--rev
						oldk[k] = e
						e[1],e[2] = e[2],e[1]
						Status.sorted[e.order] = e[1]
						ChangeLastPrio(e,b,e[1])
					elseif inf.prev == bnew then
						e[1] = bnew
						Status.sorted[e.order] = e[1]
						oldk[b] = e
						ChangeLastPrio(e,b,bnew)
					elseif inf.b == bnew or inf.b == b then
						--rev
						oldk[b] = e
						e[1],e[2] = e[2],inf.b
						Status.sorted[e.order] = e[1]
						ChangeLastPrio(e,b,inf.b)
					else
						error"ccccccccccccc"
					end
					printD("to",e[1],e[2])
				elseif e[2] ==b then
					printD("found e[2]==b",b,"edge",e[1],e[2])
					prtableD(E.edges[e[1]])
					local inf = E.edges[e[1]]
					if inf.prev == bnew or inf.prev == b then
						--rev
						--print"--rev"
						--e[1],e[2] = e[2],inf.prev
						e[1],e[2] = inf.prev,e[1]
						oldk[k] = e
						Status.sorted[e.order] = e[1]
						ChangeLastPrio(e,b,inf.prev)
					elseif inf.b == bnew then
						--print"no rev"
						e[2] = bnew
						ChangeLastPrio(e,b,bnew)
					else					
						error"cccccccccccccc"
						assert(copoint)
						printD"copoint"
						Status.edges[k] = nil
						--remove(Status.sorted,e.order)
						sort_del[e.order] = true
						-- if inf.b == a then
							-- e[2] = a
						-- elseif inf.prev == a then
							-- e[1],e[2] = inf.prev,e[1]
							-- oldk[k] = e
							-- Status.sorted[e.order] = e[1]
							-- ChangeLastPrio(e,b,inf.prev)--??
						-- else
							-- error"ccccccccccccc"
						-- end
					end
					printD("to",e[1],e[2])
				end
			else--not a or b but could be reversed
				local inf = E.edges[e[1]]
				if inf.prev == e[2] then
					reverseSedge(k,e,oldk)
					--error"reverse in CorrectStatus"
				end
			end
		end
		for ok,nk in pairs(oldk) do
			if ok~=nk then --whe using commonpoint anew and bnew are a and b
			--Status.edges[nk]= Status.edges[ok]
			Status.edges[ok]=nil
			end
		end
		for ok,nk in pairs(oldk) do
			if ok~=nk then --whe using commonpoint anew and bnew are a and b
			Status.edges[nk[1]]= nk
			--Status.edges[ok]=nil
			end
		end
		for i=#Status.sorted,1,-1 do
			if sort_del[i] then
				remove(Status.sorted,i)
			end
		end
		-- prtable(oldk)
		--StatusSortedRepair()
		--prtable(Status)
		printStatus("in correct")
		for i=1,#Status.sorted do --k in ipairs(Status.sorted) do
			local vu = Status.edges[Status.sorted[i]]
			--local vl = Status.edges[Status.sorted[i+1]]
			--assert(vu.lastprioL==vl.lastprioU)
			if vu.lastprioL==b or vu.lastprioU==b then
				DOprint(i,vu[1],"----have last b",vu.lastprioL, vu.lastprioU)
			end
		end
	end

	local printL = printD
	local function getCandidates(prio)
		local candidates = {}
		local v = inds[prio]
		if E:not_collapsed(v) then
			insert(candidates,v)
		else
			--print("collap",v)
		end
		if E.invAlias[v] then
			for k,w in ipairs(E.invAlias[v]) do
				if E:not_collapsed(w) then
					insert(candidates,w)
				else
					--print("collap",w)
				end
			end
		end
		if #candidates > 1 then
			--assert(#candidates<4,"tomany"..tostring(#candidates))
			printL("-----candidates:")
			local  ends = {}
			for i=1,#candidates do
				local v = candidates[i]
				local tipo = getTipo(v)
				--printL(i,E:getPstr(v),tipo)
				--print(i,v,tipo)
				if tipo=="end" then
					local inf = E.edges[v]
					--prtable(inf)
					local e1 = Status.edges[inf.prev]
					local e2 = Status.edges[v]
					local dist = math.abs(e1.order-e2.order)
					ends[v] = dist
				else
					ends[v] = math.huge
				end
			end
			prtableD(candidates,ends)
			algo.quicksort(candidates,1,#candidates,function(a,b) return ends[a]<ends[b] end)
		end
		--prtable("candidates",candidates)
		return candidates
	end
	
	local ListPrio
	
	local INADDLINES = false
	local function getPrioL(a,b,reva,revb)
		local infa,infb = E.edges[a],E.edges[b]
		local preva,prevb = infa.prev,infb.prev
		local suca,sucb = infa.b,infb.b --for reversing
		--local ap = reva and suca or preva
		--local bp = revb and 
		local priomin = math.huge
		local pointmin
		for i,v in ipairs{a,b,preva,prevb,suca,sucb} do
			local pri = getPrio(v)
			--priomin = priomin > pri and pri or priomin
			if priomin > pri then
				priomin = pri
				pointmin = v
			end
		end
		return priomin,pointmin
	end
	local function getPrioL1(a,b)
		local infa,infb = E.edges[a],E.edges[b]
		local preva,prevb = infa.prev,infb.prev
		local suca,sucb = infa.b,infb.b --for reversing
		--local ap = reva and suca or preva
		--local bp = revb and 
		return {a,b,preva,prevb,suca,sucb}
	end
	local function getPrioL2(t,reva,revb)
		printD("getPrioL2",reva,revb)
		--local ap = reva and suca or preva
		--local bp = revb and 
		--return {a,b,preva,prevb,suca,sucb}
		local t2 = {t[1],t[2],reva and t[5] or t[3],revb and t[6] or t[4]}
		--local t2 = {t[1],t[2],t[3],t[4]}
		local priomin = math.huge
		local pointmin
		for i,v in ipairs(t) do
			local pri = getPrio(v)
			--priomin = priomin > pri and pri or priomin
			if priomin > pri then
				priomin = pri
				pointmin = v
			end
		end
		return priomin,pointmin
	end
	--local prioL
	local function SetRegionsLastprio(iregion,Regions,ii)
		--set lastprio
		if iregion then printD("----iregion",iregion[1],iregion[2],"ii",ii) end
		for i=1,#Regions do
			local v = Regions[i]
			printD("Region",i,v[1],v[2],"prios",Ptoind[v[1]],Ptoind[v[2]],"lastprio",v.lastprioL,v.lastprioU,"pty",v.pty)
			
			if i<iregion[1] then
				v.lastprioL = ii
			elseif i>iregion[2] then
				v.lastprioU = ii
			else
				v.lastprioL = ii
				v.lastprioU = ii
			end
		end
	end
	local usedLines = {}
	local SearchStatus
	local function AddLineCorrect(added_lines, iregion, Regions,ii)
		INADDLINES = true
		local commonpoint
		--for i=1,#added_lines do
		for i=1,math.min(#added_lines,1) do
			local anew,bnew
			local l = added_lines[i]
			commonpoint = use_common_point and Pequal(P,l[1],l[2])
			local sameface = E.edges[l[1]].face == E.edges[l[2]].face
			DOprint("----do_added_lines",i,"from",#added_lines)
			DOprint(l[1],l[2],"sameface",sameface,"commonpoint",commonpoint,"prios",getPrio(l[1]),getPrio(l[2]),"tipo",l[3],l[4])
			--if commonpoint then assert((getPrio(l[1])-getPrio(l[2]))==1) end
			local Reva,Revb = false,false
			local prioL
			if sameface then
				local ok,tests = check_pair1(l[1],l[2])
				--assert(tests.t1==tests.t2,"sameface opposite tests")
				if tests.t1~=tests.t2 then 
						print("sameface opposite tests");
						--do as if not added line
						SetRegionsLastprio(iregion, Regions, ii)
						StatusPointAdd(ii)
						StatusWindCalc()
						StatusCheck(ii,"after StatusPointAdd",ii)
						DOprintStatus("after StatusPointAdd",ii,getTipo(ii),"prio",getPrio(ii))
						return 
				end
				prtableD("tests",ok,tests)
				
				anew,bnew = E:add_line(l[1],l[2],commonpoint)
				E:check()
				--if commonpoint then E:faces_print();error"commonpoint" end
				-------------check zero are
				if use_collapse_faces then
					local polinda = E:get_polind(anew)
					local polindb = E:get_polind(bnew)
					local sigAa = signed_area(P,polinda)
					local sigAb = signed_area(P,polindb)
					printD("check zero area",#polinda,sigAa,#polindb,sigAb)
					if sigAa==0 then
						E:mark_collapsed(anew)
					end
					if sigAb==0 then
						E:mark_collapsed(bnew)
					end
				end
			else
				local ok,tests = check_pair1(l[1],l[2])
				if not ok then
					prtableD(tests)
					if not tests.t1 then
						printD("reverse1",l[1])
						E:reverse(l[1])
						Reva = true
					end
					if not tests.t2 then
						printD("reverse2",l[2])
						E:reverse(l[2])
						Revb = true
					end
				end
				anew,bnew = E:add_line(l[1],l[2],commonpoint)
				E:check()
				printD"postcheck"

			end

			printD("---- end_do_added_lines",i,l[1],l[2],"sameface",sameface)
			printD("tipos",l[3],l[4],getTipo(anew),getTipo(bnew))
			E:faces_print("after do added lines")
			DOprintStatus("after do added lines")
			CorrectStatus(l[1],l[2],anew,bnew,commonpoint,l,Regions)
			--print("line",l[1],l[2],anew,bnew)
			DOprintStatus("after correct1")
			------------------------
			--anew-b
			--bnew-a
			local function makeLineEdge(anew,b)
				printD("makeLineEdge",anew,b)
				local eanew
				local infanew = E.edges[anew]
				if infanew.b==b then
					eanew = {anew,b}
				elseif infanew.prev==b then
					eanew = {b,anew}
				else
					prtableD(infanew)
					error"???????"
				end
				eanew.first = getPrio(eanew[1])<getPrio(eanew[2]) and 1 or 2
				eanew.second = eanew.first == 1 and 2 or 1
				eanew.lastprioL = eanew[eanew.first]
				eanew.lastprioU = eanew.lastprioL
				return eanew
			end
			local function AfterBeforeEdge(e)
				local es1,es2
				if e.second==1 then
					es1 = E.edges[e[e.second]].prev
					es1 = NoCollapsedWalk(e[e.second],es1,"prev")
					es2 = E.edges[e[e.first]].b
					es2 = NoCollapsedWalk(e[e.first],es2,"b")
				else --second==2
					es1 = E.edges[e[e.second]].b
					es1 = NoCollapsedWalk(e[e.second],es1,"b")
					es2 = E.edges[e[e.first]].prev
					es2 = NoCollapsedWalk(e[e.first],es2,"prev")
				end
				--if Pequal(P,es[1],es[2]) then return NoCollapsedEdge(es) end
				return es1,es2
			end
			local function Angle(a,b,c)
				local ang = CG.Angle(P[E:getP(a)],P[E:getP(b)],P[E:getP(c)])*180/math.pi
				return ang --==0 and 360 or ang
			end
			local function IsBelowLE(e1,e2)
				E:faces_print()
				printD("IsBelowLE",e1[1],e1[2],e2[1],e2[2])
				assert(Pequal(P,e1[e1.second],e2[e2.second]))
				assert(Pequal(P,e1[e1.first],e2[e2.first]))
				local e1e1,e1e2 = AfterBeforeEdge(e1)
				local e2e1,e2e2 = AfterBeforeEdge(e2)
				printD("start",e1e1,e1e2,e2e1,e2e2)
				printD("e1",e1[1],e1[2])
				assert(not Pequal(P,e1[e1.first],e1[e1.second]),"collapsed edge")
				local ang1 = Angle(e1[e1.first],e1[e1.second],e1e1)
				local ang2 = Angle(e1[e1.second],e1[e1.first],e1e2)
				local ang3 = Angle(e1[e1.first],e1[e1.second],e2e1)
				local ang4 = Angle(e1[e1.second],e1[e1.first],e2e2)
				printD(ang1,ang2,ang3,ang4)
				--assert((ang1>ang3)==(ang2<ang4),"angles cross")
				if not (ang1>ang3)==(ang2<ang4) then 
					ang1 = ang1==0 and 360 or ang1
					ang2 = ang2==0 and 360 or ang2
					ang3 = ang3==0 and 360 or ang3
					ang4 = ang4==0 and 360 or ang4
					assert((ang1>ang3)==(ang2<ang4),"angles cross")
				end

				return ang1>ang3
			end
			E:faces_print("before IsBelow")
			if not commonpoint then
			--if true then
				local eanew = makeLineEdge(anew,l[2])
				local ebnew = makeLineEdge(bnew,l[1])
				local below = IsBelowLE(eanew,ebnew) and eanew or ebnew
				local above = below == eanew and ebnew or eanew
				local eorder = Regions[l.region].order + 1
				insert(Status.sorted,eorder,below[1])
				insert(Status.sorted,eorder,above[1])
				Status.edges[below[1]] = below
				Status.edges[above[1]] = above
				for j=eorder,#Status.sorted do
					local s = Status.sorted[j]
					local edgs = Status.edges[s]
					local sup = Status.sorted[j-1]
					local edgsup = Status.edges[sup] or {windL=0}
					--prtable(edgs,edgsup,j,j-1)
					edgs.order = j
					edgs.windU = edgsup.windL
					local wind = edgs.first == 1 and -1 or 1
					edgs.windL = wind + edgs.windU
				end
				StatusFirstCalc()
				DOprintStatus("after add bridges")
			end --commonpoint
			----------------------
			DOprintStatus("after correct last1111")
			StatusSortedRepair()
			CorrectLastPrio(ii)
			StatusFirstCalc()
			StatusWindCalc()
			DOprintStatus("after correct last",ii)
			--StatusCheck(ii)
		end --end for added_lines
			
		local candidates = getCandidates(getPrio(ii))
		for i=1,#candidates do
			local v = candidates[i]
			--print("cand",v)
			-- SearchStatus(v)
			if false and v==ii then
				local reg,ireg = SearchRegions(v,getTipo(v))
				SetRegionsLastprio(ireg,reg,v)
				StatusPointAdd(v)
				StatusSortedRepair()
				StatusWindCalc()
				DOprintStatus("after cand",ii)
				StatusCheck(v,"in Add line correct")
			else
				SearchStatus(v)
				StatusSortedRepair()
				StatusWindCalc()
			end
		end
		StatusCheck(ii,"after Add line correct")
		INADDLINES = false
	end
	
	local function AddLine(added_lines,iregion, Regions, ii)
		INADDLINES = true
			printStatus("before added_lines")
			for i=1,math.min(#added_lines,1) do
				local l = added_lines[i]
				--using 1 does not fail but it is much slower TODO
				--prioL,pointmin = use_prioL and getPrioL(l[1],l[2]) or 1
				local tprioL = getPrioL1(l[1],l[2])
				local sameface = E.edges[l[1]].face == E.edges[l[2]].face
				local commonpoint = use_common_point and Pequal(P,l[1],l[2])
				DOprint("----do_added_lines",i,"from",#added_lines)
				DOprint(E:getPstr(l[1]),E:getPstr(l[2]),"sameface",sameface,"commonpoint",commonpoint,"prios",getPrio(l[1]),getPrio(l[2]),"tipo",getTipo(l[1]),getTipo(l[2]))
				-- print("preva,prevb",E.edges[l[1]].prev,E.edges[l[2]].prev,"prios",getPrio(E.edges[l[1]].prev),getPrio(E.edges[l[2]].prev))
				printD("prioL",prioL,pointmin)
				printD("--todelete")
				local Reva,Revb = false,false
				local prioL
				if sameface then
					local ok,tests = check_pair1(l[1],l[2])
					--assert(tests.t1==tests.t2,"sameface opposite tests")
					if tests.t1~=tests.t2 then 
						print("sameface opposite tests");
						--do as if not added line
						SetRegionsLastprio(iregion, Regions, ii)
						StatusPointAdd(ii)
						StatusWindCalc()
						StatusCheck(ii,"after StatusPointAdd",ii)
						DOprintStatus("after StatusPointAdd",ii,getTipo(ii),"prio",getPrio(ii))
						goto SKIP 
					end
					prtableD("tests",ok,tests)
					
					local anew,bnew,kind = E:add_line(l[1],l[2],commonpoint)
					E:check()
					--if commonpoint then E:faces_print();error"commonpoint" end
					-------------check zero are
					if use_collapse_faces then
					local polinda = E:get_polind(anew)
					local polindb = E:get_polind(bnew)
					local sigAa = signed_area(P,polinda)
					local sigAb = signed_area(P,polindb)
					printD("check zero area",#polinda,sigAa,#polindb,sigAb)
					if sigAa==0 then
						E:mark_collapsed(anew)
					end
					if sigAb==0 then
						E:mark_collapsed(bnew)
					end
					end
					------------------------------
				else
					local ok,tests = check_pair1(l[1],l[2])
					if not ok then
						prtableD(tests)
						if not tests.t1 then
							printD("reverse1",l[1])
							E:reverse(l[1])
							Reva = true
						end
						if not tests.t2 then
							printD("reverse2",l[2])
							E:reverse(l[2])
							Revb = true
						end
					end
					local anew,bnew,kind = E:add_line(l[1],l[2],commonpoint)
					E:check()
					printD"postcheck"
					--ListPrio(prioL,getPrio(l[1]))
					--CorrectStatus(l[2],bnew)
				end
				insert(usedLines,l)
				E:faces_print("after add_line")
				prioL = use_prioL and getPrioL2(tprioL,Reva,Revb) or 1
				printD("prioL",prioL)
				Status = copyTable(SnapsP[prioL-1] or {edges={},sorted={}})
				printStatus("after snap restore")
				ListPrio(prioL,l[1])
				--tipo = getTipo(ii)
				DOprint("---- end_do_added_lines",i,l[1],l[2],"sameface",sameface)

			end
			::SKIP::
			INADDLINES = false
	end
	SearchStatus = function(ii,dotakesnap)
		assert(E:not_collapsed(ii),"collapsed in SearchStatus")
		--dotakesnap = true
		local added_lines = {}
		local tipo = getTipo(ii)
		pointTipos[ii] = tipo
		local vec2 = mat.vec2
		--local prioi = Ptoind[ii]
		--local y = P[ii].y
		local inf = E.edges[ii]
		local succ = inf.b
		local prev = inf.prev
		DOprint("----SearchStatus",E:getPstr(ii),"-------prio",getPrio(ii))
		--local Regions2 = SearchAbove(ii,tipo)
		local Regions,iregion = SearchRegions(ii,tipo)
		-- print("compare Regions",#Regions,#Regions2)
		-- local maxReg = #Regions>#Regions2 and #Regions or #Regions2
		-- for j=1,maxReg do
			-- prtable(Regions[j],Regions2[j])
		-- end
		--assert(#Regions==#Regions2)
		--prtable("Regions",Regions)
		for i=1,#Regions-1 do
			local eH = Regions[i]
			local eL = Regions[i+1]
			--prtable("Region eH",eH)
			--prtable("Region eL",eL)
			local eHf = eH[eH.first]
			local eLf = eL[eL.first]
			local eHs = eH[eH.second]
			local eLs = eL[eL.second]
			--Is interior?
			-- local inA = IsPointInside(vec2(P[ii].x,eH.pty),P[prev],P[ii],P[succ])
			-- local inB = IsPointInside(vec2(P[ii].x,eL.pty),P[prev],P[ii],P[succ]) 
			-- print(inA,inB)
			-- if inA and inB then
			assert(eH.windL==eL.windU,"bad windL in:"..i)
			--if eH.windL~=0 then --fill non-zero rule
			--if eH.windL%2==1 then --fill odd rule
			if windingrule(eH.windL) and (not search_cross or not use_added_lines) then
			if eH.lastprioL or eL.lastprioU then
				local lpri = eH.lastprioL or eL.lastprioU
				printD("preadd line",ii,eH.lastprioL, eL.lastprioU,"b and prev",E.edges[ii].b, E.edges[ii].prev,"wind",eH.windL)
				--if E.edges[ii].b~=lpri and E.edges[ii].prev~=lpri then --and not INADDLINES then
				if E:getP(E.edges[ii].b)~=E:getP(lpri) and E:getP(E.edges[ii].prev)~=E:getP(lpri) then --and not Pequal(P,ii,lpri) then --and not INADDLINES then
					printD(i,"Add line",E:getPstr(ii),E:getPstr(lpri),"options",eH.lastprioL, eL.lastprioU,"b and prev",E.edges[ii].b, E.edges[ii].prev)
					insert(AddedLines,{E:getP(ii),E:getP(lpri),tipo,pointTipos[lpri]})
					insert(AddedLines2,{ii,lpri,tipo,pointTipos[lpri]})
					--insert(added_lines,{ii,lpri,tipo,pointTipos[lpri]})
					insert(added_lines,{ii,lpri,tipo,getTipo(lpri),region=i})
					-- printD("Tipos",ii,getTipo(ii),lpri,getTipo(lpri))
					-- local anew,bnew,kind = E:add_line(ii,lpri,commonpoint)
					-- printD("Tipos",ii,getTipo(ii),lpri,getTipo(lpri),anew,getTipo(anew),bnew,getTipo(bnew))
				end
			end
			end
			--end
		end
		
		
		--printStatus("before StatusPointAdd added_lines")
		--StatusPointAdd(ii,tipo)
		if use_added_lines and not search_cross and #added_lines > 0 then
			if use_correct_status then
				--local itc1 = copyTable(Status)
				AddLineCorrect(added_lines,iregion, Regions, ii)
				--local itc2 = copyTable(Status)
				--Status = copyTable(itc1)
				--assert(tbl_compare(Status,itc1),"---bad status compare")
				--local iregion,Regions = SearchRegions(ii,tipo)
				--AddLine(added_lines,iregion, Regions, ii)
				--assert(tbl_compare(Status,itec2),"differetn Status")
			else
				AddLine(added_lines,iregion, Regions, ii)
			end
			return true
		else --not added lines
			--prtable(iregion,Regions)
			--local reg,ireg = SearchRegions(ii,getTipo(ii))
			--prtable(ireg,reg)
			SetRegionsLastprio(iregion, Regions, ii)
			
			StatusPointAdd(ii)
			StatusWindCalc()
			--StatusCheck(ii,"after StatusPointAdd",ii)
			DOprintStatus("after StatusPointAdd",ii,getTipo(ii),"prio",getPrio(ii))
			StatusCheck(ii,"after StatusPointAdd",ii)
			-- local candidates = getCandidates(getPrio(ii))
			-- for i=1,#candidates do
				-- local v = candidates[i]
				-- printD("cand",v)
				-- if true and v==ii then
					-- SetRegionsLastprio(iregion, Regions, ii)
					-- StatusPointAdd(v)
					-- StatusSortedRepair()
					-- StatusWindCalc()
					-- DOprintStatus("after cand",ii)
					-- StatusCheck(v,"in Add line correct")
				-- else
					-- SearchStatus(v)
					-- StatusSortedRepair()
					-- StatusWindCalc()
				-- end
			-- end
			-- StatusCheck(ii,"after cands")
		end
	end
	
	ListPrio = function(p1,ii)
		local p2 = getPrio(ii)
		printL("ListPrio",p1,p2)
		for j=p1,p2 do
			printL("--ListPrio",j)
			local candidates = getCandidates(j)
			--if #candidates==0 then TakeSnapP(Status,j,0) end
			for i=1,#candidates do
				local v = candidates[i]
				printL("ListPrio doing",v)
				printStatus("before ListPrio",j,v)
				SearchStatus(v,i==#candidates)
			end
		end
	end
	-----------

	-----------------

	--E:faces_walk()
	--for prio=1,#inds do
	local function Sweep(takesnap)
	local prio = 1
	while prio <= #inds do
		local i = inds[prio]
		local vi = P[i]
		local inf = E.edges[i]
		local succ = inf.b
		local prev = inf.prev
		local Pprev,Psucc = P[prev], P[succ]
		local iprev,isucc = Ptoind[prev],Ptoind[succ]
		DOprint("\n===================== prio",prio,"=============================================")
		DOprint(i,"prev,succ",prev,succ,getTipo(i))
		printD(prio,"iprev,isucc",iprev,isucc)
		printD(vi,"Pprev,Psucc",Pprev,Psucc)
		DOprintStatus("normal",i)
		assert(E:not_collapsed(i))
		--assert(not E.invAlias[i],"invAlias in Sweep")
		if E.invAlias[i] then
			local candidates = getCandidates(prio)
			for i=1,#candidates do
				local v = candidates[i]
				printL("Sweep doing",v)
				local addl = SearchStatus(v,i==#candidates)
				--if line added in ListPrio all candidates are already done
				--if addl and not use_correct_status then break end
				if addl then break end
			end
		else
		   SearchStatus(i,takesnap)
		end
		prio = prio + 1
	end
	printD"done AddLines"
	printD("#AddedLines",#AddedLines)
	for i,l in ipairs(AddedLines) do
		printD("line",i,"points",l[1],l[2],l[3],l[4],"prios",Ptoind[l[1]],Ptoind[l[2]])
	end
	-- local polindsr = E:get_polinds()
	--do return AddedLines end
	prtableD("Bridges",Bridges)
	for k,v in pairs(Bridges) do
		printD(k,P[k])
	end
	end
	
	local function check_pair0(v1,v2,rev1,rev2)
		local infv1 = E.edges[v1]
		local succv1 = E:getP(infv1.b)
		local prevv1 = E:getP(infv1.prev)
		if rev1 then succv1,prevv1 = prevv1,succv1 end
		local infv2 = E.edges[v2]
		local succv2 = E:getP(infv2.b)
		local prevv2 = E:getP(infv2.prev)
		if rev2 then succv2,prevv2 = prevv2,succv2 end
		printD("check_pair0",prevv1,v1,succv1,"and",prevv2,v2,succv2)
		-----points
		local p_v1 = P[E:getP(v1)]
		local p_succv1 = P[succv1]
		local p_prevv1 = P[prevv1]
		local p_v2 = P[E:getP(v2)]
		local p_succv2 = P[succv2]
		local p_prevv2 = P[prevv2]
		--sarch angles order
		local a = CG.Angle(p_prevv1,p_v1,p_succv2,true)
		--a = (a==0) and 2*math.pi or a
		--assert(not (a==0),"check0 spike a")
		if a==0 then --disambiguate
			printD"disambiguate a"
			local succsuccv2,prevprevv1
			if not rev2 then
				succsuccv2 = E:getP(E.edges[infv2.b].b)
			else
				succsuccv2 = E:getP(E.edges[infv2.prev].prev)
			end
			if not rev1 then
				prevprevv1 = E:getP(E.edges[infv1.prev].prev)
			else
				prevprevv1 = E:getP(E.edges[infv1.b].b)
			end
			if IsPointInCone(P,succsuccv2,prevprevv1,prevv1,E:getP(v1)) then a=2*math.pi else a=0 end
		end
		local maxa,mina = a,a
		local b = CG.Angle(p_prevv1,p_v1,p_prevv2,true)
		--b = (b==0) and 2*math.pi or b
		--assert(not (b==0),"check0 spike b")
		if b==0 then --disambiguate
			printD"disambiguate b"
			local prevprevv2,prevprevv1
			if not rev2 then
				prevprevv2 = E:getP(E.edges[infv2.prev].prev)
			else
				prevprevv2 = E:getP(E.edges[infv2.b].b)
			end
			if not rev1 then
				prevprevv1 = E:getP(E.edges[infv1.prev].prev)
			else
				prevprevv1 = E:getP(E.edges[infv1.b].b)
			end
			if IsPointInCone(P,prevprevv2,prevprevv1,prevv1,E:getP(v1)) then b=0 else b=2*math.pi end
		end
		maxa = maxa > b and maxa or b
		mina = mina < b and mina or b
		local c = CG.Angle(p_prevv1,p_v1,p_succv1,true)
		--assert(not (c==0),"check0 spike c")
		--c = (c==0) and 2*math.pi or c
		if c==0 then --disambiguate
			printD"disambiguate c"
			local succsuccv1,prevprevv1
			if not rev1 then
				succsuccv1 = E:getP(E.edges[infv1.b].b)
				prevprevv1 = E:getP(E.edges[infv1.prev].prev)
			else
				succsuccv1 = E:getP(E.edges[infv1.prev].prev)
				prevprevv1 = E:getP(E.edges[infv1.b].b)
			end
			if IsPointInCone(P,succsuccv1,prevprevv1,prevv1,E:getP(v1)) then c=2*math.pi else c=0 end
		end
		maxa = maxa > c and maxa or c
		mina = mina < c and mina or c
		if a==0 or b==0 or c==0 then
			printD("check0 spike",a,b,c)
			--error"check0 spike"
		end
		--crossing?
		
		if not (c==mina or c==maxa) then printD("check0 Angles",a,b,c,"min,max",mina,maxa) end
		assert(c==mina or c==maxa)
		local i
		if c==mina then
			--choose larger
			i = maxa == b and prevv2 or succv2
		elseif c==maxa then --c==maxa
			--choose shorter
			i = mina == b and prevv2 or succv2
		else --try with 0 angles
			if b==0 then
				i = prevv2
			elseif a==0 then
				i = succv2
			else
				assert(false,"check0 bad")
			end
		end
		if i==succv2 then
			return true
		else
			return false
		end
	end
	local function Signs(pi,a,b,c)
		local scone = Sign(P[a],P[b],P[c])
		local sab = Sign(P[a],P[b],P[pi])
		local sbc = Sign(P[b],P[c],P[pi])
		return scone,sab,sbc
	end
	local function InConeBasic(v1,v2,rev)
		local v1r = E:getP(v1)
		local v2r = E:getP(v2)
		local infv1 = E.edges[v1]
		local succv1,prevv1
		if rev then
			prevv1 = infv1.b
			succv1 = infv1.prev
		else
			succv1 = infv1.b
			prevv1 = infv1.prev
		end
		local prevv1r = E:getP(prevv1)
		local succv1r = E:getP(succv1)
		local scone,sab,sbc = Signs(v2r,prevv1r,v1r,succv1r)
		printD("Signs",v2r,prevv1r,v1r,succv1r)
		printD(scone,sab,sbc)
		if sab==0 or sbc==0 then return 0 end
		if scone < 0 then --right
			return not(sab<0 and sbc<0)
		elseif scone > 0 then --left > 0
			return sab > 0 and sbc > 0
		else
			error"scone==0 in InConeBasic"
		end
	end
	local printDC = printD --function() end --printD
	local function InCone(v1,v2,rev)
		--------------------------------
		-- local polind = E:get_polind(v1)
		-- local polindP = {}
		-- for i=1,#polind do polindP[i]=P[polind[i]] end
		-- if CG.signed_area(polindP) == 0 then
			-- return false, true
		-- end
		-------------------------------
		local v1r = E:getP(v1)
		local v2r = E:getP(v2)
		local infv1 = E.edges[v1]
		local succv1,prevv1
		if rev then
			prevv1 = infv1.b
			succv1 = infv1.prev
		else
			succv1 = infv1.b
			prevv1 = infv1.prev
		end
		local prevv1r = E:getP(prevv1)
		local succv1r = E:getP(succv1)
		local scone,sab,sbc = Signs(v2r,prevv1r,v1r,succv1r)
		printDC("Signs",v2r,prevv1r,v1r,succv1r)
		printDC(scone,sab,sbc)
		--assert(not (sab==0 and sbc==0))
		if scone~=0 and sab==0 and sbc==0 then
			assert(P[v2r]==P[v1r])
			--local succv2 = E.edges[v2].b
			--return InCone(v1,succv2,rev)
			local infv2 = E.edges[v2]
			local tt1 = InConeBasic(v1,infv2.b,rev)
			local tt2 = InConeBasic(v1,infv2.prev,rev)
			printDC("sab==0,sbc==0",tt1,tt2,infv2.b,infv2.prev)
			if tt1==tt2 then
				--assert(tt1~=0)
				if tt1==0 then return true,true end
				return tt1 --true,true --tt1
			elseif tt1==0 then
				return tt2
			elseif tt2==0 then
				return tt1
			else
				error"crossing"
			end
			-- local inftt1 = infv2
			-- while tt1==0 do
				-- inftt1 = E.edges[inftt1.b]
				-- tt1 = InConeBasic(v1,inftt1.b,rev)
			-- end
			-- local inftt2 = infv2
			-- while tt2==0 do
				-- inftt2 = E.edges[inftt2.prev]
				-- tt2 = InConeBasic(v1,inftt2.prev,rev)
			-- end
			-- printD("sab==0,sbc==0",tt1,tt2,inftt1.b,inftt2.prev)
			-- if tt1==tt2 then
				-- return tt1
			-- else
				-- error"InCone crossing"
			-- end
		end
		if scone < 0 then --right
			if sbc == 0 then
				printDC"sbc 0"
				-- local succv2 = E.edges[v2].b
				-- local prevv2 = E.edges[v2].prev
				-- return InCone(succv1,prevv2,rev)
				return not (sab<0 and sab<=0)
			end
			
			if sab==0 then
				printDC("sab 0, rev:",rev)
				-- local prevv2 = E.edges[v2].prev
				-- return InCone(prevv1,prevv2,rev)
				return not(sab<=0 and sbc<0)
			end
			return not(sab<0 and sbc<0)
		elseif scone > 0 then --left > 0
			--assert(not (sab==0 and sbc==0))
			-- if sab==0 and sbc==0 then
				-- assert(P[v2r]==P[v1r])
				-- local succv2 = E.edges[v2].b
				-- return InCone(v1,succv2,rev)
			-- end
			if sab==0 then
				printDC("sab 0, rev:",rev)
				--local prevv2 = E.edges[v2].prev
				--return InCone(prevv1,prevv2,rev)
				return sab >= 0 and sbc > 0
			end
			if sbc == 0 then
				printDC"sbc 0"
				-- local succv2 = E.edges[v2].b
				-- local prevv2 = E.edges[v2].prev
				-- return InCone(v1,succv2,rev)
				return sab > 0 and sbc >=0
			end
			return sab > 0 and sbc > 0
		else -- scone==0
			--colinear
			--do return true,true end --solves aedgecommon
			if P[prevv1r]==P[v1r] then
				printDC("P[prevv1r]==P[v1r]")
				if P[succv1r]==P[prevv1r] then error"3 coincident points" end
				if sbc == 0 then
					-- local infv2 = E.edges[v2]
					-- local succv2 = E:getP(infv2.b)
					-- local prevv2 = E:getP(infv2.prev)
					-- local s1 = Sign(P[v1r],P[succv1r],P[succv2])
					-- local s2 = Sign(P[v1r],P[succv1r],P[prevv2])
					---------------
					--E:faces_print()
					local a,b,cs = getStartPoints(v1)
					local infprev = E.edges[prevv1]
					local prevprevv1r 
					if rev then
						prevprevv1r = E:getP(infprev.b)
					else
						prevprevv1r = E:getP(infprev.prev)
					end
					local s3 = Sign(P[prevprevv1r],P[v1r],P[v2r])
					printD("s3",s3,"prevprevv1r",prevprevv1r,a,b,cs)
					do return s3 > 0 end
					--------------------------
					printD("s1,s2",s1,s2,"succv2,prevv2",succv2,prevv2)
					if s1==0 then
						if s2~=0 then
							return s2 > 0
						else
							-- local polind = E:get_polind(v1)
							-- local polindP = {}
							-- for i=1,#polind do polindP[i]=P[polind[i]] end
							-- if CG.signed_area(polindP) == 0 then
								-- return false, true
							-- end
							return true,true
							--error"doble zero"
						end
					elseif s2==0 then
						if s1~=0 then
							return s1 >= 0
						else
							return true,true
							--error"doble zero"
						end
					else
						if (s1>0)==(s2>0) then
							return s1 >= 0
						else
							error"crossing"
						end
					end
				end
				return sbc > 0
				
			elseif P[v1r]==P[succv1r] then
				printDC"P[v1r]==P[succv1r]"
				if sab == 0 then
					-- local infv2 = E.edges[v2]
					-- local succv2 = E:getP(infv2.b)
					-- local prevv2 = E:getP(infv2.prev)
					-- local s1 = Sign(P[prevv1r],P[v1r],P[succv2])
					-- local s2 = Sign(P[prevv1r],P[v1r],P[prevv2])
					-- printDC("s1",s1,prevv1r,v1r,succv2)
					-- printDC("s2",s2,prevv1r,v1r,prevv2)
					-----------------------------
					local a,b,cs = getStartPoints(v1)
					local infsucc = E.edges[succv1]
					local succsuccv1r = E:getP(infsucc.b)
					local s3 = Sign(P[v1r],P[succsuccv1r],P[v2r])
					printD("s3",s3,"succsuccv1r",succsuccv1r,a,b,cs)
					do return s3 > 0 end
					-------------------------------
					if s1==0 then
						if s2~=0 then
							return s2 >= 0
						else
							-- local polind = E:get_polind(v1)
							-- local polindP = {}
							-- for i=1,#polind do polindP[i]=P[polind[i]] end
							-- if CG.signed_area(polindP) == 0 then
								-- return false,true
							-- end
							return true,true
							--error"doble zero"
						end
					elseif s2==0 then
						if s1~=0 then
							return s1 >= 0
						else
							return true,true
							--error"doble zero"
						end
					else
						if (s1>0)==(s2>0) then
							return s1 >= 0
						else
							error"crossing"
						end
					end
				end
				return sab >= 0
			elseif P[prevv1r]==P[succv1r] then
				--error"IsPointInCone spike1"
				printDC"InCone spike1"
				local succsuccv1
				if rev then
					succsuccv1 = E.edges[succv1].prev
				else
					succsuccv1 = E.edges[succv1].b
				end
				return InCone(prevv1,succsuccv1,rev)
				--return true
			else
				printDC"angle 000"
				local ang = CG.Angle(P[prevv1r],P[v1r],P[succv1r])
				if ang==0 then
					error"InCone spike2"
				else
					if sab==0 and sbc==0 then
						local a,b,cs = getStartPoints(v2)
						local s1 = E:Sign(P,v1,succv1,a)
						local s2 = E:Sign(P,v1,succv1,b)
						return checkStartSigns(s1,s2)
					elseif sab==0 then
						error"not done"
					elseif sbc==0 then
						error"not done"
					end
					return sab >0 and sbc > 0
				end
			end
		end 
	end
	local function InCone2(v1,v2,rev)
		printDC("InCone2",v1,v2,rev)
		local prev,succ,cs = getStartPoints(v1)
		if rev then
			prev,succ = succ,prev
		end
		local scone,sab,sbc
		--if use_added_lines then
			scone = E:Sign(P,prev,v1,succ)
			sab = E:Sign(P,prev,v1,v2)
			sbc = E:Sign(P,v1,succ,v2)
		-- else
			-- scone = ESign(P,prev,v1,succ)
			-- sab = ESign(P,prev,v1,v2)
			-- sbc = ESign(P,v1,succ,v2)
		-- end
		printDC("InCone2 signs",scone,sab,sbc)
		if scone==0 then
			if Pequal(P,prev,succ) then
				printDC("InCone2 spike1",sab,sbc)
				-- local a,b,cs = getStartPoints(succ)
				-- local susu = rev and a or b
				-- printDC("succsuccv1",susu)
				-- return InCone2(prev,susu,rev)
				----------------------------
				E:faces_print()
				local a,b,cs = getStartPoints(succ)
				local sucsuc = rev and a or b
				local a,b,cs = getStartPoints(prev)
				local prepre = rev and b or a
				printD("prepre,sucsuc",prepre,sucsuc)
				local scone2 = E:Sign(P,prepre,prev,sucsuc)
				local sab2 = E:Sign(P,prepre,prev,v2)
				local sbc2 = E:Sign(P,prev,sucsuc,v2)
				local sab3 = E:Sign(P,prepre,prev,v1)
				local sbc3 = E:Sign(P,prev,sucsuc,v1)
				printD(scone2,sab2,sbc2,sab3,sbc3)
				--return sab3 >0 and sbc3 > 0
				error"InCone2 spike1"
			else
				printDC"angle 000"
				local ang = CG.Angle(P[E:getP(prev)],P[E:getP(v1)],P[E:getP(succ)])
				if ang==0 then
					error"InCone2 spike2"
				else
					if sab==0 and sbc==0 then
						--error"InCone2 collinear"
						local a,b,cs = getStartPoints(v2)
						local s1 = E:Sign(P,v1,succ,a)
						local s2 = E:Sign(P,v1,succ,b)
						return checkStartSigns(s1,s2)
					elseif sab==0 then
						error"not done"
					elseif sbc==0 then
						error"not done"
					end
					return sab >0 and sbc > 0
				end
			end
			error"scone==0"
		elseif scone < 0 then
			if sab==0 and sbc==0 then
				assert(Pequal(P,v1,v2))
				local prev2,succ2,cs = getStartPoints(v2)
				local a = E:Sign(P,prev,v1,prev2)
				local b = E:Sign(P,v1,succ,prev2)
				local c = E:Sign(P,prev,v1,succ2)
				local d = E:Sign(P,v1,succ,succ2)
				local s1 = not (a<0 and b<0)
				local s2 = not (c<0 and d<0)
				local s10 = not (a<=0 and b<=0)
				local s20 = not (c<=0 and d<=0)
				printDC(a,b,c,d,s1,s2,s10,s20)
				if s1==s2 then return s1 end
				if s10==s20 then return s10 end
				error"sab and sbc==0" 
			elseif sab==0 then
				-- local prev2,succ2,cs = getStartPoints(v2)
				-- local a = E:Sign(P,prev,v1,prev2)
				-- local c = E:Sign(P,prev,v1,succ2)
				-- local s1 = not (a<0 and sbc<0)
				-- local s2 = not (c<0 and sbc<0)
				-- local s10 = not (a<=0 and sbc<=0)
				-- local s20 = not (c<=0 and sbc<=0)
				-- printDC(a,b,c,d,s1,s2,s10,s20)
				-- if s1==s2 then return s1 end
				-- if s10==s20 then return s10 end
				-- error"sab and sbc==0" 
				return not (sbc<0)
			elseif sbc==0 then
				-- local prev2,succ2,cs = getStartPoints(v2)
				-- local b = E:Sign(P,v1,succ,prev2)
				-- local d = E:Sign(P,v1,succ,succ2)
				-- local s1 = not (sab<0 and b<0)
				-- local s2 = not (sab<0 and d<0)
				-- local s10 = not (sab<=0 and b<=0)
				-- local s20 = not (sab<=0 and d<=0)
				-- printDC(a,b,c,d,s1,s2,s10,s20)
				-- if s1==s2 then return s1 end
				-- if s10==s20 then return s10 end
				-- error"sab and sbc==0" 
				return not (sab<0)
			end
			return not(sab<0 and sbc<0)
		else
			assert(scone>0)
			if sab==0 and sbc==0 then
				assert(Pequal(P,v1,v2))
				local prev2,succ2,cs = getStartPoints(v2)
				local a = E:Sign(P,prev,v1,prev2)
				local b = E:Sign(P,v1,succ,prev2)
				local c = E:Sign(P,prev,v1,succ2)
				local d = E:Sign(P,v1,succ,succ2)
				local s1 = a>0 and b>0
				local s2 = c>0 and d>0
				local s10 = a>=0 and b>=0
				local s20 = c>=0 and d>=0
				printDC(a,b,c,d,s1,s2,s10,s20)
				if s1==s2 then return s1 end
				if s10==s20 then return s10 end
				-- if (a>=0)==(b>=0) then
					-- return a>=0 and b>=0
				-- end
				-- if (c>=0)==(d>=0) then
					-- return c>=0 and d>=0
				-- end
				error"sab and sbc==0" 
			elseif sab==0 then
				-- local prev2,succ2,cs = getStartPoints(v2)
				-- local a = E:Sign(P,prev,v1,prev2)
				-- local c = E:Sign(P,prev,v1,succ2)
				-- local s1 = a>0 and sbc>0
				-- local s2 = c>0 and sbc>0
				-- local s10 = a>=0 and sbc>=0
				-- local s20 = c>=0 and sbc>=0
				-- printDC(a,b,c,d,s1,s2,s10,s20)
				-- if s1==s2 then return s1 end
				-- if s10==s20 then return s10 end
				-- error"sab and sbc==0" 
				return sbc > 0
			elseif sbc==0 then
				-- local prev2,succ2,cs = getStartPoints(v2)
				-- local b = E:Sign(P,v1,succ,prev2)
				-- local d = E:Sign(P,v1,succ,succ2)
				-- local s1 = sab>0 and b>0
				-- local s2 = sab>0 and d>0
				-- local s10 = sab>=0 and b>=0
				-- local s20 = sab>=0 and d>=0
				-- printDC(a,b,c,d,s1,s2,s10,s20)
				-- if s1==s2 then return s1 end
				-- if s10==s20 then return s10 end
				-- error"sab and sbc==0" 
				return sab > 0
			end
			
			return sab > 0 and sbc > 0
		end
		
	end
	--local function check_pair1(v1,v2)
	check_pair1 = function(v1,v2)
		printDC"t1----------"
		local t1,A1 = InCone2(v1,v2)
		printDC"----------"
		--assert(t1==InCone(v1,v2),"InCone2 not InCone")
		printDC"t2----------"
		local t2,A2 = InCone2(v2,v1)
		printDC"----------"
		--assert(t2==InCone(v2,v1),"InCone2 not InCone")
		printDC"t1r----------"
		--local t1r,A1r = InCone2(v1,v2,true)
		printDC"----------"
		--assert(t1r==InCone(v1,v2,true),"InCone2 not InCone")
		printDC"t2r----------"
		--local t2r,A2r = InCone2(v2,v1,true)
		printDC"----------"
		--assert(t2r==InCone(v2,v1,true),"InCone2 not InCone")
		prtableD{t1=t1,t2=t2,t1r=t1r,t2r=t2r}
		prtableD{A1=A1,A1r=A1r,A2=A2,A2r=A2r}
		--assert(((A1 or A1r) or (t1==(not t1r))) and ((A2 or A2r) or (t2==(not t2r))),"tests")
		--assert( (t1==(not t1r)) and  (t2==(not t2r)),"tests")
		return t1 and t2,{t1=t1,t2=t2,t1r=t1r,t2r=t2r,A0=A1 or A1r or A2 or A2r}
	end
	
	local function CreatePairs(aa,bb)
		local pairss = {}
		for i,v1 in ipairs(aa) do
			if E:not_collapsed(v1) then
				for j,v2 in ipairs(bb) do
					if E:not_collapsed(v2) then
						if E.edges[v1].face == E.edges[v2].face then
							insert(pairss,1,{v1,v2,true})
						else
							insert(pairss,{v1,v2,false})
						end
					end
				end
			end
		end
		return pairss
	end
	local function preCreatePairs(l)
		local aa = {l[1]}
		if E.invAlias[l[1]] then
			for j,v in ipairs(E.invAlias[l[1]]) do
				insert(aa,v)
			end
		end
		local bb = {l[2]}
		if E.invAlias[l[2]] then
			for j,v in ipairs(E.invAlias[l[2]]) do
				insert(bb,v)
			end
		end
		return CreatePairs(aa,bb)
	end
	local printDO = printD
	local prtableDO = prtableDD
	local function CreateGoodPairs(pairss)
		printD"----------------tests------------------------"
		local good = {}
		for j,dd in ipairs(pairss) do 
			printD("tests",dd[1],dd[2],dd[3])
			local v1,v2,sameface = dd[1],dd[2],dd[3]
			local ok,tests,ptest = check_pair1(v1,v2)
			dd[4] = tests
			if sameface then
				if tests.t1==tests.t2 then
					local infv1 = E.edges[v1]
					local infv2 = E.edges[v2]
					if (infv1.b == v2 or infv1.prev == v2) then
						printDO("SKIP addline: already edge",v1,v2)
					else
						insert(good,dd)
					end
				end
			else
				insert(good,dd)
			end
		end
		
		printD"---------------- end tests------------------------"
		return good
	end
	local function num_good_test(t)
		if t.t1 and t.t2 then
			return 2
		elseif t.t1 or t.t2 then
			return 1
		else
			return 0
		end
	end

	local function doAddLines3(Lines, recall)
		printDO("doAddLines3",recall)
		Lines = Lines or AddedLines
		local dorev --= true
		local not_found = {}
		for i,l in ipairs(Lines) do
			printDO("===========add line",i,"from",#Lines,l[1],l[2],E:getPstr(l[1]),E:getPstr(l[2]),Bridges[E:getP(l[1])],Bridges[E:getP(l[2])])
			--printD("==faces",E.edges[l[1]].face,E.edges[l[2]].face)
			
			local pairss = preCreatePairs(l)
			prtableDO("--------pairss",pairss)
			pairss = CreateGoodPairs(pairss)
			if #pairss > 1 and not pairss[1][3] then
				prtableDD(pairss)
				--heuristic ????????????
				algo.quicksort(pairss,1,#pairss,function(a,b) return num_good_test(a[4])> num_good_test(b[4]) end)
				--prtable(pairss)
				-- print"ambiguous mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm"
				-- error"goddmmmmmmmmmmmm"
			end
			prtableDO("good",pairss)
			::REPEAT::
			local ia,ib,facesame
			for j,dd in ipairs(pairss) do 
				local v1,v2,sameface = dd[1],dd[2],dd[3] 
				--if sameface then ia,ib = v1,v2; goto FOUND end
					printD("search",v1,v2,E.edges[v1],E.edges[v2])
					if not(E.edges[v1] and E.edges[v2]) then printDO("deleted point SKIP"); goto SKIP end
					local sameface = E.edges[v1].face==E.edges[v2].face
					printD("search",v1,v2,"sameface",sameface)
					--local ok,tests,ptest = check_pair1(v1,v2)
					local tests = dd[4]
					local ok = tests.t1 and tests.t2
					prtableD(tests)
					if ok then
						ia,ib,facesame = v1,v2,sameface
						goto FOUND
					elseif dorev then
						if not ptest then
							if not sameface then
								if tests.t1==false then
									printD"--REVERSINGA"
									E:reverse(v1)
								end
								if tests.t2==false then
									printD"--REVERSINGB"
									E:reverse(v2)
								end
							else
								if tests.t1==false and tests.t2==false then
									printD"sameline good"
									printD"--REVERSING common"
									E:reverse(v1)
								else
									printD"sameface SKIP"
									goto SKIP
								end
							end
							local ok2,tests2 = check_pair1(v1,v2)
							prtableD(tests2)
							assert(ok2,"not working")
							if ok2 then
							ia,ib,facesame = v1,v2,sameface
							goto FOUND
							end
						else
						end
					end
					::SKIP::
			end
			::FOUND::
			--assert(ia,"not found")
			if not ia then
				printD("line not found",l[1],l[2],dorev)
				--insert(not_found,l)
				--assert(not dorev)
				if dorev then
					insert(not_found,l)
					dorev = false
				else
					dorev = true
					goto REPEAT
				end
			else
				dorev = false
				local commonpoint = use_common_point and Pequal(P,ia,ib)
				printDO("==== using",E:getPstr(ia),E:getPstr(ib),"commonpoint",commonpoint,"sameface",facesame)
				insert(usedLines, {ia,ib,commonpoint})
				--E:check()
				--E:faces_print()
				-- printD("walk----",ia)
				-- E:walk(ia,E.printEdge)
				-- printD("walk----",ib)
				-- E:walk(ib,E.printEdge)
				local anew,bnew,kind = E:add_line(ia,ib,commonpoint)
				-------------check zero area
				if facesame then
					local polinda = E:get_polind(anew)
					local polindb = E:get_polind(bnew)
					local sigAa = signed_area(P,polinda)
					local sigAb = signed_area(P,polindb)
					printD("check zero area",#polinda,sigAa,#polindb,sigAb)
					if sigAa==0 and use_collapse_faces then
						E:mark_collapsed(anew)
					end
					if sigAb==0 and use_collapse_faces then
						E:mark_collapsed(bnew)
					end
				end
				------------------------------
				printD("done using",anew,bnew)
				-- printD("walk----",anew)
				-- E:walk(anew,E.printEdge)
				-- printD("walk----",bnew)
				-- E:walk(bnew,E.printEdge)
				E:faces_print("after line add")
				printD"check----"
				E:check()
				local anew2,bnew2 = E:getP(anew),E:getP(bnew)
				if Bridges[anew2] and Bridges[bnew2] then
					if false and kind=="merge" and P[anew2]==P[bnew2] then
						printD("repair bridge",anew,bnew,anew2,bnew2)
						prtableD(E.edges[anew],E.edges[bnew])
						local infa = E.edges[anew]
						E.edges[infa.prev].b = infa.b
						E.edges[infa.b].prev = infa.prev
						local infb = E.edges[bnew]
						E.edges[infb.prev].b = infb.b
						E.edges[infb.b].prev = infb.prev
						
						printD"end repair bridge"
						--E:faces_print()
					end
				end
			end
		end
		if #not_found > 0 then
			
			if recall then
				--assert((#Lines > #not_found),"not_found lines")
				if (#Lines == #not_found) then 
					--E:faces_print()
					-- for ii,ll in ipairs(not_found) do
						-- local v1,v2 = ll[1],ll[2]
						-- local infv1 = E.edges[ll[1]]
						-- if (infv1.b == v2 or infv1.prev == v2) then
							-- print("SKIP addline: already edge",v1,v2)
						-- elseif not (E:not_collapsed(v1) and E:not_collapsed(v2)) then
							-- print("SKIP addline: collapsed",v1,v2)
						-- else
							-- error"not_found2"
						-- end
					-- end
					--error"not_found lines"
					return 
				end
			end
			printD"----REPEAT doAddLines"
			prtableD("not_found",not_found)
			--doAddLines3(not_found,true)
		end
	end
	printT = printD
	if use_added_lines then
		search_cross= true
		local t1 = os.clock()
		Sweep()
		printT("search_cross done in",os.clock()-t1)
		search_cross= false
		local t1 = os.clock()
		--print"go Sweep2"
		Sweep(true)
		printT("addlines",os.clock()-t1)
	else
		search_cross= true
		local t1 = os.clock()
		Sweep()
		printT("search_cross and lines",os.clock()-t1)
		-- AddedLines = {}
		-- search_cross= false
		-- Sweep(true)
	end
	printD"---------beforr add lines--------------------"
	local plin = E:get_polinds()
	prtableD(plin)
	--doAddLines()--AddedLines,P,E)
	if not use_added_lines then 
		--E:faces_print("before doAddLines3");
		local t1 = os.clock()
		doAddLines3()
		printT("doaddlines3",os.clock()-t1)		
	end
	--local polindsr = E:get_polinds()
	--do return {},{},AddedLines,polindsr end
	local function mono_triangulate()--P,E,inds)
		local polind
		local function getPolind(self,inf)
			polind[#polind+1] = self:getP(inf.a)
		end
		local trs = {}
		local polinds = {}
		for i,v in pairs(E.faces) do
			printD("doing face",i,"------------------------------")
			polind = {}
			E:walk(v,getPolind)
			polinds[#polinds+1]=polind
			local P1 = {}
			--which P points used in polind
			for j=1,#polind do
				P1[polind[j]] = j --P[j]
			end
			--save them to P2 in order and polind2
			local polind2 = {}
			local P2 = {sorted=true}
			local P2toP,PtoP2 = {},{}
			for prio=1,#inds do
			local j = inds[prio]
				--for j=1,#P do
				if P1[j] then
					insert(P2,P[j])
					P2toP[#P2] = j
					PtoP2[j] = #P2
				end
			end
			for j=1,#polind do polind2[j] = PtoP2[polind[j]] end
			
			-- for j=2,#P2 do
				-- assert(CG.lexicografic_compare(P2[j-1],P2[j]))
			-- end
			
			-- local _,OK = CG.getChains(P2,polind2)
			-- if not OK then print"not monotone" end
			
			local tr = CG.triang_sweept_monotone(P2,polind2)
			prtableD("tr",tr)
			for j=1,#tr do
				insert(trs,P2toP[tr[j]+1]-1)
			end
		end
		return trs
	end
	local function Spikeremove(polind)
		--remove line 0 length
		for i=#polind,2,-1 do
			if P[polind[i]]==P[polind[i-1]] then printD(i,i-1,"spike remove repeated",polind[i],polind[i-1]);remove(polind,i) end
		end
		if #polind> 1 and P[polind[1]]==P[polind[#polind]] then printD(1,#polind,"spike remove repeated",polind[1],polind[#polind]);remove(polind) end
		prtableD("before remove spike",polind)
		-- for i=#polind,3,-1 do
			-- if P[polind[i]]==P[polind[i-2]] then printD(i,i-2,"spike remove",polind[i],polind[i-2]);remove(polind,i-2);remove(polind,i-2);prtableD(polind) end
		-- end
		-- if #polind > 2 and P[polind[2]]==P[polind[#polind]] then printD(2,#polind,"spike remove",polind[2],polind[#polind]);remove(polind,1);remove(polind,1);prtableD(polind) end
		-- if #polind > 3 and P[polind[1]]==P[polind[#polind-1]] then printD(1,#polind-1,"spike remove",polind[1],polind[#polind-1]);remove(polind);remove(polind);prtableD(polind) end
		local i = #polind
		while i>2 do
			if P[polind[i]]==P[polind[i-2]] then 
				printD(i,i-2,"spike remove",polind[i],polind[i-2])
				remove(polind,i);remove(polind,i-1);
				prtableD(polind)
				i = i - 2
			else
				i = i - 1
			end
		end
		if #polind > 2 and P[polind[2]]==P[polind[#polind]] then printD(2,#polind,"spike remove",polind[2],polind[#polind]);remove(polind,1);remove(polind,1);prtableD(polind) end
		if #polind > 3 and P[polind[1]]==P[polind[#polind-1]] then printD(1,#polind-1,"spike remove",polind[1],polind[#polind-1]);remove(polind);remove(polind);prtableD(polind) end
		return polind
	end
	local function mono_triangulate2()
		local polind
		local function getPolind(self,inf)
			--polind[#polind+1] = self:getP(inf.a)
			local p = self:getP(inf.a)
			-- if Bridges[p] then
				-- print("bridges",p,#polind)
				-- if P[p]==P[polind[#polind]] then print"eñlajds ñadf" end
			-- end
			polind[#polind+1] = p
			
				--spikes out
				-- if #polind > 2 then
					-- if P[polind[#polind]]~=P[p] then polind[#polind]=nil end
					-- if P[polind[#polind]]==P[polind[#polind-2]] then
						-- printD("spike remove",#polind-1,#polind)
						-- polind[#polind] = nil
						-- polind[#polind] = nil
					-- end
				-- end
			
		end
		local trs = {}
		local polinds = {}
		for i,v in pairs(E.faces) do
			printD("doing face",i,"------------------------------")
			if E.collapsed_faces[i] then printD"collapsed" goto SKIP end
			polind = {}
			E:walk(v,getPolind)
			-- if #polind > 2 and P[polind[2]]==P[polind[#polind]] then printD("spike remove2",1,2);remove(polind,1);remove(polind,1) end
			-- if #polind > 3 and P[polind[1]]==P[polind[#polind-1]] then printD("spike remove2",#polind-1,#polind);remove(polind);remove(polind) end
			
			-- local toremove = {}
			-- for j=1,#polind-1 do
				-- if Bridges[polind[j]] and P[polind[j]]==P[polind[j+1]] then insert(toremove,j) end
			-- end
			-- if Bridges[polind[#polind]] and P[polind[#polind]]==P[polind[1]] then insert(toremove,#polind) end
			-- for j=#toremove,1,-1 do
				-- remove(polind,toremove[j])
			-- end
			
			-- if #polind > 1 and P[polind[#polind]]==P[polind[1]] then remove(polind) end
			-- local _,OK = getChains(P2,polind2)
			-- if not OK then print"not monotone" end
			local olen = #polind
			prtableD(polind)
			Spikeremove(polind)
			if olen~=#polind then prtableD("spikesout",polind) end
			--printD(tb2st_serialize{P,polind,inds,Ptoind})
			local tr = triang_sweept_monotone(P,polind,inds,Ptoind)
			prtableD("tr",tr)
			for j=1,#tr do
				insert(trs,tr[j])
			end
			::SKIP::
		end
		return trs
	end
	--local trs = mono_triangulate()--P,E,inds)
	local t1 = os.clock()
	local trs = mono_triangulate2()
	printT("mono_triangulate2",os.clock()-t1)
	prtableD("trs",trs)
	prtableD("AddedLines",AddedLines)
	prtableD("AddedLines2",AddedLines2)
	prtableD("usedLines",usedLines)
	prtableD("collapsed_faces",E.collapsed_faces)
	prtableD("inds",inds)
	return P,trs,AddedLines,E:get_polinds()
	--return polinds,trs
end


---[[
if not ... then
local function clone_ps(ps)
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
local params = loadfile("../spline_files/monotonize.spline")()
--local params = loadfile("../spline_files/tomonotone.spline")()
--local params = loadfile("../spline_files/atest_rev.spline")()
--local params = loadfile("../spline_files/calc_1a5.spline")()
--local params = loadfile("../spline_files/calculator1e.spline")()
--local params = loadfile("../spline_files/example2.spline")()
--local params = loadfile("../spline_files/example2-2holes.spline")()
--local params = loadfile("../spline_files/example3.spline")()
--local params = loadfile("../spline_files/aacrossed4_tri.spline")()
--local params = loadfile("../spline_files/concentric.spline")()
--local params = loadfile("../spline_files/aaex.spline")()
--local params = loadfile("../spline_files/corona4b.spline")()
--local params = loadfile("../spline_files/aaedgecommonf.spline")()
--local params = loadfile("../spline_files/aatouchedpoint.spline")()
--local params = loadfile("../spline_files/start_crossed3c.spline")()
--local params = loadfile("../spline_files/yunke_co.spline")()
--local params = loadfile("../spline_files/aaa1_co.spline")()
--prtable(params)
local bad_count = 0
local count = 0
local function test(f)
	print("---------------",f)
	count = count + 1
	local params = loadfile(f)()
	local pts,icontours = clone_ps(params.sccoors[1])
	local ok,P,trs = pcall(CG.edges_monotone_tesselator,pts,icontours,0,true)
	if not ok then 
		bad_count = bad_count + 1
		--print("---------------",f)
		print(P)
		--print(debug.traceback(3));
		--error"vvvvv" 
	end
end

funcdir("../spline_files",test,"spline")
print("bad_count",bad_count,"from ",count)
-- local lpt = require"luapower.time"
-- local pts,icontours = clone_ps(params.sccoors[1])

-- ProfileStart()
-- for i=1,1 do
-- local t1 = lpt.clock()
-- local P,trs = CG.edges_monotone_tesselator(pts,icontours,0,true)
-- print("done in",lpt.clock()-t1)
-- end
-- ProfileStop()




end
--]]
return CG