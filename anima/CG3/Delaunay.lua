local CG = require"anima.CG3.base"
local M = CG

--Edges structure
--E[a] = {b=c} key=vertex sharing edge value=vertex opposite to edge
local function setEdge(E,a,b,c)
	E[a] = E[a] or {}
	E[a][b] = c
end

local function InCircle2(e,points)
	local a = points[e.edge[1]]
	local b = points[e.edge[2]]
	local c = points[e[1]]
	local d = points[e[2]]
	local M4 =mat.mat4(1,a.x,a.y,a.x^2+a.y^2,
			1,b.x,b.y,b.x^2+b.y^2,
			1,c.x,c.y,c.x^2+c.y^2,
			1,d.x,d.y,d.x^2+d.y^2)
	local M3 = M4.mat3
	return M4.det*M3.det 
end

local function InCircle(e,points)
	local a1 = points[e.edge[1]].xy --TODO xy is just in case points are xyz
	local b1 = points[e.edge[2]].xy
	local c1 = points[e[1]].xy
	local d = points[e[2]].xy
	local sign = rightturn_2(a1,b1,c1)
	--sign = ((sign > 0) and 1) or ((sign < 0) and -1) or 0
	local a,b,c = a1-d, b1-d, c1-d

	local M3 =mat.mat3(	a.x,a.y,a.x*a.x+a.y*a.y,
						b.x,b.y,b.x*b.x+b.y*b.y,
						c.x,c.y,c.x*c.x+c.y*c.y)
	return M3.det*sign  --> 0
end

function M.Circumcircle(a,b,c,d,points)
	local a1 = points[a].xy --TODO xy is just in case points are xyz
	local b1 = points[b].xy
	local c1 = points[c].xy
	local d = points[d].xy
	local sign = rightturn_2(a1,b1,c1)
	--sign = ((sign > 0) and 1) or ((sign < 0) and -1) or 0
	local a,b,c = a1-d, b1-d, c1-d

	local M3 =mat.mat3(	a.x,a.y,a.x*a.x+a.y*a.y,
						b.x,b.y,b.x*b.x+b.y*b.y,
						c.x,c.y,c.x*c.x+c.y*c.y)
	return M3.det*sign > 1e-11
end
function M.Circumcircle2(a1,b1,c1,d1,points)
	local a = points[a1]--.xy --TODO xy is just in case points are xyz
	local b = points[b1]--.xy
	local c = points[c1]--.xy
	local d = points[d1]--.xy
	local M4 =mat.mat4(1,a.x,a.y,a.x^2+a.y^2,
			1,b.x,b.y,b.x^2+b.y^2,
			1,c.x,c.y,c.x^2+c.y^2,
			1,d.x,d.y,d.x^2+d.y^2)
	local M3 = M4.mat3
	return M4.det*M3.det < 0
end
--a,c debe existir y cambiara b por d
local function ChangeEdge(E,a,c,b,d)
	local key = M.EdgeHash(a,c)
	local chanE = E[a][c]
	for i,v in ipairs(chanE) do
		if v == b then chanE[i] = d; break end
	end
	return chanE,key
end
local function AddToTest(Es,E,a,c)
	
	local op = E[a][c]
	local op2 = E[c][a]
	--if (not Es[hash]) and op2 and op then
	if  op2 and op then
		local hash = M.EdgeHash(a,c)
		Es[hash] = {op,op2,edge={a,c}}
	end
end
--Flip del Quad en E añadiendo a Es los que hay que comprobar
local function Flip(k,e,E,Es)
	--print"flip"
	
	local a,b,c,d = e.edge[1],e.edge[2],e[1],e[2]
	Es[k] = nil
	
	-- M.DeleteEdge(E,a,b)
	M.deleteTriangle(E,a,b,c)
	M.deleteTriangle(E,b,a,d)
	
	--addtriangles
	M.setTriangle(E,d,c,a)
	M.setTriangle(E,c,d,b)
	
	--add edges to test
	--AddToTest(Es,E,d,c)
	AddToTest(Es,E,c,a)
	AddToTest(Es,E,a,d)
	
	--AddToTest(Es,E,c,d)
	AddToTest(Es,E,d,b)
	AddToTest(Es,E,b,c)

end

--elimina del Quad el triangulo con vertice i
local function removeEdgeEnd(e,i)
		if e[1] == i then 
			table.remove(e,1)
		elseif e[2] == i then
			table.remove(e,2)
		end
end
--borra los triangulos que se solapan en Quads adjacentes a e con vertice a
local function DeleteAdj(E,a1,a2,a)
	--print("DeleteAdj",a1,a2,a)
	local adj = E[a1][a]
	if adj then 
		removeEdgeEnd(adj,a2)
		--if #adj == 0 then E[a1][a] = nil end
	end
	local adj = E[a2][a]
	if adj then 
		removeEdgeEnd(adj,a1)
		--if #adj == 0 then E[a2][a] = nil end
	end
end
--borra el Quad de clave a,b y los triangulos solapados en Quads adjacentes
local function DeleteEdge1(E,a,b)
	--print("DeleteEdge1",a,b)
	local e = E[a][b]
	if not e then return end
	DeleteAdj(E,a,b,e[1])
	if e[2] then
		DeleteAdj(E,a,b,e[2])
	end
	E[a][b] = nil
	E[b][a] = nil
end
local function DeleteEdgeO(E,a,b)
	--print("DeleteEdge",a,b)
	DeleteEdge1(E,a,b)
	--DeleteEdge1(E,b,a)
end


local function deleteTriangle(E,a,b,c)
	--if not c then return end
	E[a][b] = nil
	E[b][c] = nil
	E[c][a] = nil

end
M.deleteTriangle = deleteTriangle
local function DeleteEdgeS(E,a,b)
	local c = E[a][b]
	local d = E[b][a]
	deleteTriangle(E,a,b,c)
	if d then
		deleteTriangle(E,b,a,d)
	end
end
M.DeleteEdge = DeleteEdgeS

local function setTriangle(E,a,b,c)
	setEdge(E,a,b,c)
	setEdge(E,b,c,a)
	setEdge(E,c,a,b)
end
M.setTriangle = setTriangle

M.MAXVERT = 1000000
local function EdgeHash(a,b)
	if b < a then a,b = b,a end
	return a*M.MAXVERT+b
	-- return a .."_"..b
end
M.EdgeHash = EdgeHash

function M.Ed2TRBAK(E)
	local doneT = {}
	local Ed2 = deepcopy(E)
	local tr2 = {}
	for ka,v in pairs(Ed2) do
	for kb,op in pairs(v) do
		local hash = EdgeHash(ka,kb)
		if not doneT[hash] then
			table.insert(tr2,ka-1)
			table.insert(tr2,kb-1)
			table.insert(tr2,op-1)
			doneT[hash] = true
		end
	end
	end
	return tr2
end
--generate tr indexes for openGL rendering 
-- from Edges 
function M.Ed2TR(E)
	local doneT = {}
	local tr = {}
	for ka,v in pairs(E) do
		for kb,op in pairs(v) do
			local hash = M.TriangleKey(ka,kb,op)
			if not doneT[hash] then
				table.insert(tr,ka-1)
				table.insert(tr,kb-1)
				table.insert(tr,op-1)
				doneT[hash] = true
			end
		end
	end
	return tr
end
--generates Edges from tr indexes
function M.TR2Ed(tr)
	assert(#tr%3==0)
	local E = {}
	for i=1,#tr,3 do
		setTriangle(E,tr[i]+1,tr[i+1]+1,tr[i+2]+1)
	end
	return E
end

local function LenEt(Et)
	local count = 0
	for ka,v in pairs(Et) do
		for kb,e in pairs(v) do
			count = count + 1
		end
	end
	return count
end
function M.Delaunay(P,tr)
	--maxflips
	local maxflips = #P*(#P-1) --/2
	--get edges
	local Et = {}
	for i=1,#tr,3 do
		setTriangle(Et,tr[i]+1,tr[i+1]+1,tr[i+2]+1)
	end

	local Ets = {} --copiamos los que pueden ser ilegales
	local lenEts = 0
	for ka,v in pairs(Et) do
	for kb,op in pairs(v) do
		if Et[kb][ka] then 
			local hash = EdgeHash(ka,kb)
			if not Ets[hash] then
				Ets[hash] = {edge={ka,kb},op,Et[kb][ka]} 
				lenEts = lenEts + 1
			end
		end 
	end
	end
	
	--print("LenEt1",LenEt(Et))
	--testTODO
	-- for k,e in pairs(Ets) do
		-- assert(#e==2 and #e.edge==2)
	-- end
	-- do
	-- local tr2 = M.Ed2TR(Et)
	-- print(#tr,#tr2,#tr2/#tr)
	-- return tr2,Et
	-- end
	
	--print("delaunay",lenEts)
	local nflips = 0
	local goodEt = true
	repeat
		goodEt = true
		for k,e in pairs(Ets) do
			--print(k)
			--if InCircle(e,P) > 1e-15 then
			if InCircle2(e,P) < -1e-15 then
				nflips = nflips + 1
				Flip(k,e,Et,Ets)
				goodEt = false
				break
			else
				Ets[k] = nil
			end
		end
	until goodEt or (nflips > maxflips)
	
	if ( not goodEt) then --demasiados flips
		local incirc = {}
		for k,e in pairs(Ets) do
			if #e > 1 then
			incirc[#incirc + 1] = InCircle(e,P)
			end
			--print(k,InCircle(e,P))
		end
		table.sort(incirc)
		print("incirc",incirc[1],incirc[#incirc])
		error("not goodEt")
	end
	--recreate triangulation
	--print("LenEt2",LenEt(Et))
	local tr2 = M.Ed2TR(Et)
	--print(#tr,#tr2,#tr2/#tr)
	return tr2,Et
end



----------------DelaunayInc

local abs = math.abs
local function TestColinear(a,b,c,d,P)
	local eps = 1e-18
	if (abs(Sign(P[a],P[b],P[c])) < eps) then
		print(P[a],P[b],P[c])
		error"colinear points a,b,c"
	elseif(abs(Sign(P[a],P[c],P[d])) < eps) then
		print(P[a],P[c],P[d])
		error"colinear points a,c,d"
	elseif (abs(Sign(P[a],P[b],P[d])) < eps) then
		print(P[a],P[b],P[d])
		error"colinear points a,b,d"
	end
end
local function setQuadInc(E,a,b,c,d)
	assert(c and d)
	E[a] = E[a] or {}
	E[a][b] =  {c,d}

	E[b] = E[b] or {}
	E[b][a] = E[a][b]

end
local function setEdgeInc(E,a,b,c)
	if b < a then a,b = b,a end
	local key = tostring(a).."_"..tostring(b)
	E[key] = E[key] or {edge={a,b}}
	table.insert(E[key],c)
end
local function setTriangleInc(E,T)
	setTriangle(E,T.p[1],T.p[2],T.p[3])
end

--generates unique hash for a triangle a,b,c
--without inverting order
local min = math.min
local function TriangleKey(a,b,c)
	
	local mina = min(a,min(b,c))
	local t = {[0]=a,b,c}
	local t2 
	for i=0,2 do
		if t[i] == mina then
			t2 = {t[i],t[(i+1)%3],t[(i+2)%3]}
			break
		end
	end
	return table.concat(t2,"_")
	-- other way but can do inversion, could be faster
	-- local ori = 1
	-- if a > b then a,b = b,a; ori=-ori end
	-- if b > c then b,c = c,b; ori=-ori end
	-- if a > b then a,b = b,a; ori=-ori end
	-- return ori .. "_" .. a .. "_" .. b .. "_" .. c
end
M.TriangleKey = TriangleKey
local function newT(Tlist,a,b,c)
	local key = TriangleKey(a,b,c)
	assert(Tlist[key]==nil,"newT already exist")
	local T = {p={a,b,c} }
	Tlist[key] = T
	return T
end
local function getT(Tlist,a,b,c)
	local key = TriangleKey(a,b,c)
	assert(Tlist[key])
	return Tlist[key]
end
local function getornewT(Tlist,a,b,c)
	return newT(Tlist,a,b,c)
	-- local key = TriangleKey(a,b,c)
	-- if Tlist[key] then
		-- return Tlist[key]
	-- else
		-- return newT(Tlist,a,b,c)
	-- end
end
local function printT(T)
	for i,v in ipairs(T) do
		print("\tsons:",i,TriangleKey(v.p[1],v.p[2],v.p[3]))
		
	end
end
local function printTlist(Tl)
	for k,v in pairs(Tl) do
		print(k,#v)
		printT(v)
	end
end


local function SearchT(i,T,P,Tlist)
	local abs = math.abs
	local pit,l1,l2,l3 = IsPointInTri2(P[i],P[T.p[1]],P[T.p[2]],P[T.p[3]])
	local coll = false
	--if l1==0 or l2==0 or l3==0 then coll=true end
	local eps = 1e-16
	--if abs(l1*l2*l3) <= eps then
		if abs(l1)<=eps and l3*l2>=0 then
			coll = {T.p[2],T.p[3],T.p[1]}
		elseif abs(l2)<=eps and l3*l1>=0 then
			coll = {T.p[1],T.p[3],T.p[2]}
		elseif abs(l3)<=eps and l1*l2>=0 then
			coll = {T.p[1],T.p[2],T.p[3]}
		end
	--end
	if pit or coll then
		for j=1,#T do
				local t,c = SearchT(i,T[j],P,Tlist)
				if t then return t,c end
		end
		--assert(#T==0)
		if #T>0 then 
			print("search fail on ",unpack(T.p)); 
			print(IsPointInTri2(P[i],P[T.p[1]],P[T.p[2]],P[T.p[3]]))
			for j=1,#T do
				local ts = T[j]
				local pit,l1,l2,l3 = IsPointInTri2(P[i],P[ts.p[1]],P[ts.p[2]],P[ts.p[3]])
				print(j,pit,l1,l2,l3,l1*l2*l3)
			end
			error"search fail" 
		end
		return T,coll
	else
		return false
	end
end

local function SearchTroot(i,root,P,Tlist)
	for j=1,#root do
		local t,coll = SearchT(i,root[j],P,Tlist)
		if t then return t,coll end
	end
	return root
end
--a,c debe existir y cambiara b por d
local function ChangeEdgeInc(E,a,c,b,d)
	local key = EdgeKey(a,c)
	local chanE = E[key]
	for i,v in ipairs(chanE) do
		if v == b then chanE[i] = d; break end
	end
	return chanE,key
end
--inserta i en el Quad a-b donde se haye c y devuelve el key de a-b
local function InsertPointInQuad(E,i,a,b,c)
	--print("InsertPointInQuad",i,a,b,c)
	--dentro
	local e = E[a][b]
	if e[1] == c then
		e[1] = i
	elseif e[2] == c then
		e[2] = i
	else
		--print"Bad InsertPointInQuad"
		error("Bad InsertPointInQuad: not point "..c)
	end	 
	--return key,e
end


local function FlipInc(a,b,e,E,Tlist)

	--make c-d
	local c,d = e[1],e[2]
	M.DeleteEdge(E,a,b)
	--addtriangles
	M.setTriangle(E,c,d,a)
	M.setTriangle(E,c,d,b)
	--history graph
	local T1 = getT(Tlist,a,b,c)
	local T2 = getT(Tlist,a,b,d)
	--local enew = E[key]
	local nT1 = getornewT(Tlist,c,d,a)
	local nT2 = getornewT(Tlist,c,d,b)
	table.insert(T1,nT1)
	table.insert(T1,nT2)
	table.insert(T2,nT1)
	table.insert(T2,nT2)

end

local function NotLegalEdge(e,P)
	-- return #e == 2 and InCircle(e,P) > 1e-15
	return #e == 2 and InCircle2(e,P) < -1e-15
	-- return false
end

local function Eopposite(e,i)
	if e[1] == i then
		return e[2]
	elseif e[2] == i then
		return e[1]
	else --TODO remove check
		prtable(e)
		error("bad opposite "..i)
	end
end
M.Eopposite = Eopposite
local function Legalize(E,P,Tlist,a,b,i)
	local e = E[a][b]
	if NotLegalEdge({edge={a,b},e[1],e[2]},P) then
		local k = Eopposite(e,i)
		FlipInc(a,b,e,E,Tlist)
		Legalize(E,P,Tlist,k,a,i)
		Legalize(E,P,Tlist,k,b,i)
	end
end

--Flip debe comprobar los adjacentes
local function InsertPoint(E,i,T,P,Tlist)

	--inserta i en los tres Quads del triangulo
	local key1 = InsertPointInQuad(E,i,T.p[1],T.p[2],T.p[3]) --1,2
	local key2 = InsertPointInQuad(E,i,T.p[1],T.p[3],T.p[2]) --1,3
	local key3 = InsertPointInQuad(E,i,T.p[2],T.p[3],T.p[1]) --2,3
	--añade los triangulos creados como hijos
	table.insert(T,newT(Tlist,T.p[1],T.p[2],i))
	table.insert(T,newT(Tlist,T.p[1],T.p[3],i))
	table.insert(T,newT(Tlist,T.p[2],T.p[3],i))
	
	setQuadInc(E,i,T.p[1],T.p[2],T.p[3])
	setQuadInc(E,i,T.p[2],T.p[1],T.p[3])
	setQuadInc(E,i,T.p[3],T.p[1],T.p[2])

	Legalize(E,P,Tlist,T.p[1],T.p[2],i)
	Legalize(E,P,Tlist,T.p[1],T.p[3],i)
	Legalize(E,P,Tlist,T.p[2],T.p[3],i)
end

--Flip debe comprobar los adjacentes
local function InsertPointColl(E,i,T,P,Tlist,coll)
	local a,b,c = unpack(coll)
	local op = Eopposite(E[a][b],c)
	local Top = getT(Tlist,a,b,op)
	
	--deleteTriangle(E,T.p[1],T.p[2],T.p[3])
	--deleteTriangle(E,coll[1],coll[2],op)
	DeleteEdge(E,a,b)
	setTriangle(E,i,a,c)
	setTriangle(E,i,b,c)
	setTriangle(E,i,a,op)
	setTriangle(E,i,b,op)

	--añade los triangulos creados como hijos
	table.insert(T,newT(Tlist,a,c,i))
	table.insert(T,newT(Tlist,b,c,i))
	table.insert(Top,newT(Tlist,a,op,i))
	table.insert(Top,newT(Tlist,b,op,i))
	

	Legalize(E,P,Tlist,a,c,i)
	Legalize(E,P,Tlist,b,c,i)
	Legalize(E,P,Tlist,a,op,i)
	Legalize(E,P,Tlist,b,op,i)
end

--lexicografic sortyx for DealunayInc
local function lexicografic_sortyx(P)
	table.sort(P,function(a,b) 
		return (a.y > b.y) or ((a.y == b.y) and (a.x > b.x))
	end)
	--P.sorted = true
end

local function permutation(t)

	local tt=t
	local res={}
	for i=1,#t do
		j=math.floor(math.random()*#tt + 1)
		table.insert(res,tt[j])
		table.remove(tt,j)
	end
	return res
end
----------------------------------
local TA = require"anima.TA"
function M.DelaunayInc(P,limit)
	limit = limit or #P

	local Tlist = {}
	--lexicografic_sortyx(P)
	--M.lexicografic_sort(P)
	local big = 1e5
	P[-2] = mat.vec2(-big,-big)
	P[-1] = mat.vec2(big,-big)
	P[0] = mat.vec2(0,big)
	local root = newT(Tlist,-1,-2,0) --{p={-1,-2,0}}
	local E = {}
	setTriangleInc(E,root)
	--prtable(E)
	--add points
	local perm = permutation(TA():range(1,#P))
	for _,i in ipairs(perm) do
	--for i=1,limit do --#P do
		local t,coll = SearchTroot(i,root,P,Tlist)
		if coll then 
			InsertPointColl(E,i,t,P,Tlist,coll)
		else
			InsertPoint(E,i,t,P,Tlist)
		end
	end
	--delete virtual points
	P[-2] = nil
	P[-1] = nil
	P[0] = nil
	for i=-2,0 do
	for k,e in pairs(E[i]) do
		--if e.edge[1] < 1 or e.edge[2] < 1 then
			DeleteEdge(E,i,k)
		--end
	end
	end
	--recreate triangulation
	local Et = E --deepcopy(E)
	local tr2 = {}
	--[[
	
	for k,e in pairs(Et) do
		table.insert(tr2,e.edge[1]-1)
		table.insert(tr2,e.edge[2]-1)
		table.insert(tr2,e[1]-1)
		if e[2] then
			table.insert(tr2,e.edge[1]-1)
			table.insert(tr2,e.edge[2]-1)
			table.insert(tr2,e[2]-1)
		end
		DeleteEdge(Et,k)
	end
	--]]
	local min = math.min
	for _,T in pairs(Tlist) do
		if #T == 0 then
			local a,b,c = unpack(T.p)
			local mini = min(min(a,b),c)
			if mini > 0 then
				table.insert(tr2,T.p[1]-1)
				table.insert(tr2,T.p[2]-1)
				table.insert(tr2,T.p[3]-1)
			end
		end
	end
	return tr2,Et
end