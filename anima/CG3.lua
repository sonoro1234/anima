require"anima"

local mat = require"anima.matrixffi"
local M = {}

local function mod(a,b)
	return ((a-1)%b)+1
end
--CCW 1 CW -1
local function rightturn_2det(a,b,c)
	return (b.x*c.y-b.y*c.x - (a.x*c.y-a.y*c.x) + a.x*b.y-a.y*b.x) --< 0
end
local function rightturn_2( p1,  p2,p3)
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
end

local function Sign( p1,  p2,  p3)
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
end
M.Sign = Sign
local function SegmentIntersect(a,b,c,d)
	local sc,sd = Sign(c,b,a),Sign(d,b,a)
	local sgabcd = Sign(a,d,c)*Sign(b,d,c)
	return (sc*sd < 0) and (sgabcd < 0),sc,sd
end
M.SegmentIntersect = SegmentIntersect

local function IntersecPoint(a,b,c,d)
	local den = (a.x - b.x)*(c.y - d.y) - (a.y - b.y)*(c.x - d.x)
	if den==0 then return 0,false end
	local cab = (a.x*b.y - a.y*b.x)
	local ccd = (c.x*d.y - c.y*d.x)
	local X = cab*(c.x - d.x)-(a.x - b.x)*ccd
	local Y = cab*(c.y - d.y)-(a.y - b.y)*ccd
	return mat.vec2(X/den,Y/den), true
end
M.IntersecPoint = IntersecPoint

local function Sign2V(a,b)
	return a.x * b.y - b.x * a.y;
end
local function IsPointInTri( pt,  v1,  v2,  v3)
	
	local b1, b2, b3;

	b1 = Sign(pt, v1, v2) < 0.0;
	b2 = Sign(pt, v2, v3) < 0.0;
	b3 = Sign(pt, v3, v1) < 0.0;
	
	return ((b1 == b2) and (b2 == b3));
end
local function IsPointInTri2NN( pt,  v1,  v2,  v3)
	local eps = 0 --1e-18

	local b1 = Sign(pt, v1, v2) < eps;
	local b2 = Sign(pt, v2, v3) < eps;
	if not (b1 == b2) then return false end
	local b3 = Sign(pt, v3, v1) < eps;
	return (b3 == b2) 
	--return ((b1 == b2) and (b2 == b3));
end

local function TArea(a,b,c)
	return 0.5*((a.x-c.x)*(b.y-a.y)-(a.x-b.x)*(c.y-a.y))
end
M.TArea = TArea

local function IsPointInTri2( pt, v1, v2, v3 ) 
	local l2 = (pt.x-v1.x)*(v3.y-v1.y) - (v3.x-v1.x)*(pt.y-v1.y) 
    local l3 = (pt.x-v2.x)*(v1.y-v2.y) - (v1.x-v2.x)*(pt.y-v2.y) 
    local l1 = (pt.x-v3.x)*(v2.y-v3.y) - (v2.x-v3.x)*(pt.y-v3.y)
	return (l1>0 and l2>0  and l3>0) or (l1<0 and l2<0 and l3<0),l1,l2,l3
end
M.IsPointInTri = IsPointInTri2

local function IsCosPos(a,b,c)
	return (a.x - c.x)*(b.x - c.x) + (a.y - c.y)*(b.y - c.y)
end

local function IsPointInTri2BAD( s,  a,  b,  c)
    local as_x = s.x-a.x;
    local as_y = s.y-a.y;

    local s_ab = (b.x-a.x)*as_y-(b.y-a.y)*as_x > 0;

    if((c.x-a.x)*as_y-(c.y-a.y)*as_x > 0 == s_ab) then return false end

    if((c.x-b.x)*(s.y-b.y)-(c.y-b.y)*(s.x-b.x) > 0 ~= s_ab) then return false end

    return true;
end

local function IsPointInTri2BAD2(p,  p0,  p1,  p2)

    local s = p0.y * p2.x - p0.x * p2.y + (p2.y - p0.y) * p.x + (p0.x - p2.x) * p.y;
    local t = p0.x * p1.y - p0.y * p1.x + (p0.y - p1.y) * p.x + (p1.x - p0.x) * p.y;

    if ((s < 0) ~= (t < 0)) then return false end

    local A = -p1.y * p2.x + p0.y * (p2.x - p1.x) + p0.x * (p1.y - p2.y) + p1.x * p2.y;
    if (A < 0.0) then
        s = -s;
        t = -t;
        A = -A;
    end
    return s > 0 and t > 0 and (s + t) <= A;
end

function M.IsPointInPoly(P, p)

    local i, j, c = 0,0,false --true
	local lenP = #P
	P[lenP + 1] = P[1]
	for i=1,lenP do
		--j = mod(i + 1,#P)
		j = i + 1
		-- if j>#P then j=1 end
        if ((((P[i].y <= p.y) and (p.y < P[j].y)) or
             ((P[j].y <= p.y) and (p.y < P[i].y))) and
			 --((P[j].y < p.y) and (p.y <= P[i].y))) and
            (p.x < (P[j].x - P[i].x) * (p.y - P[i].y) / (P[j].y - P[i].y) + P[i].x)) then
		   --((P[j].y - P[i].y)*(p.x - P[i].x) > (P[j].x - P[i].x) * (p.y - P[i].y)  )) then
          c = not c;
		end
	end
	P[#P] = nil
    return c;
end
local function IsConvex(a,b,c)
	return Sign(a,b,c) <=0
end
--triangulation of polygon as a table of vertices
--EarClip helpers
--find intersection of c+(1,0) with a-b
local function intersectSegmentX(p0, p1, c)
	local y = c.y
    if p0.y == p1.y then return mat.vec2(p0.x,y) end 
    if p0.y < p1.y then
      local t = (y - p0.y) / (p1.y - p0.y)
      return mat.vec2(p0.x + t * (p1.x - p0.x),y)
    else
      local t = (y - p1.y) / (p0.y - p1.y)
      return mat.vec2(p1.x + t * (p0.x - p1.x),y)
	end
end
local function EarClipH(poly, holes)
	holes = holes or {}
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
			local Ite = intersectSegmentX(a,b,Mp)
			if Ite.x < I.x then
				edge = i
				I = Ite
			end
		end
		::CONTINUE::
	end

	assert(edge)
	if edge then
	--if I is edge or edge+1 this is visible point
	local VV
	local a,b = poly[edge],poly[mod(edge+1,#poly)]
	if I==a then
		VV = edge
	elseif I==b then
		VV = mod(edge+1,#poly)
	elseif a.x < b.x then
		VV = mod(edge+1,#poly)
	else
		VV = edge
	end
	local P = poly[VV]
	--print("Rayintersec",a,b,Mp,P)
	--check all reflex (not convex) poly vertex are outside triangle MIP
	local mintan = math.huge
	local Ri
	for i=1,#poly do
		local a,b,c = poly[mod(i-1,#poly)],poly[i],poly[mod(i+1,#poly)]
		if IsConvex(a,b,c) then
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
	if Ri then VV=Ri end
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
	end --no edge
	table.remove(holes,maxhole)
	end --holes
	
	
	--prtable(poly)
	local ind = {}
	local tr = {}
	for i,v in ipairs(poly) do ind[i] = i end
	--ind[#ind] = nil --delete repeated
	--finc ear_tip
	while #ind > 2 do
	--print("EarClip",#ind)
	local initind = #ind
	for i,v in ipairs(ind) do
		--is convex?
		local a,b,c = ind[mod(i-1,#ind)],ind[i],ind[mod(i+1,#ind)]
		if IsConvex(poly[a],poly[b],poly[c]) then
			--test empty
			local empty = true
			local jlimit = mod(i-1,#ind)
			local j = mod(i+2,#ind)
			while j~=jlimit do
				if M.IsPointInTri(poly[ind[j]],poly[a],poly[b],poly[c]) then
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
	local function isreflexangle(a,b,c)
		local ab = b-a
		local ac = c-a
		return ac:cross(ab).z -->= 0
	end
	if (initind == #ind) then
		print("no convex----------",#ind)
		for i,v in ipairs(ind) do
			local a,b,c = ind[mod(i-1,#ind)],ind[i],ind[mod(i+1,#ind)]
			print(poly[a],poly[b],poly[c],IsConvex(poly[a],poly[b],poly[c]),isreflexangle(poly[a],poly[b],poly[c]))
		end
		print("end no convex --------")
		return poly,tr,false
	end
	end
	return poly,tr,true
end
M.EarClipH = EarClipH
local function EarClip(poly, holes)
	--prtable(poly)
	local ind = {}
	local tr = {}
	for i,v in ipairs(poly) do ind[i] = i end
	--ind[#ind] = nil --delete repeated
	--finc ear_tip
	while #ind > 2 do
	--print("EarClip",#ind)
	local initind = #ind
	for i,v in ipairs(ind) do
		--is convex?
		local a,b,c = ind[mod(i-1,#ind)],ind[i],ind[mod(i+1,#ind)]
		if IsConvex(poly[a],poly[b],poly[c]) then
			--test empty
			local empty = true
			local jlimit = mod(i-1,#ind)
			local j = mod(i+2,#ind)
			while j~=jlimit do
				if IsPointInTri(poly[ind[j]],poly[a],poly[b],poly[c]) then
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
		print("no convex",#ind)
		return tr,false
	end
	end
	return tr,true
end
M.EarClip = EarClip
local function Jarvis_Conv(P)
	--find leftmost
	local minx = 1
	for i=1,#P do
		if P[i].x < P[minx].x then 
			minx = i
		elseif (P[i].x == P[minx].x) and (P[i].y < P[minx].y) then
			minx = i
		end
	end
	local p_start = minx
	local q_next = (minx == 1) and 2 or 1

	local q = {}
	local h = 1;
	local q_now = p_start;
	repeat 
		q[h] = q_now;
		h = h + 1;
		for i = 1,#P do
			if i~=q_next and i~= q_now then
			local det = rightturn_2(P[q_now], P[q_next], P[i])
			if (det > 0) then 
				q_next = i
			elseif det == 0 then
				local a = (P[q_next] - P[q_now]).xy.norm
				local b = (P[q_now] - P[i]).xy.norm
				if(a==b) then
					print(a,b,P[q_now], P[q_next], P[i])
					error("bad jarvis")
				end
				if b > a then q_next = i end
			end
			end
		end
		q_now = q_next;
		q_next = p_start;
	until(q_now == p_start)
	
	local Q = {}
	for i,v in ipairs(q) do
		Q[i] = P[v]
	end
	return Q,q
end

local function SLR(P)
	--lexicografic sort
	-- table.sort(P,function(a,b) 
		-- return (a.x < b.x) or ((a.x == b.x) and (a.y < b.y))
	-- end)
	assert(P.sorted)
	local Q = {}
	Q[1] = P[1];
	local h = 1;
	-- Lower convex hull (left to right):
	for i = 2,#P do
		while (h > 1 and rightturn_2(Q[h-1], Q[h], P[i]) <  0) do
			h = h - 1;
		end
		h = h + 1;
		Q[h] = P[i];
	end
	-- Upper convex hull (right to left):

	for i = #P-1,1,-1 do
		while (h > 1 and rightturn_2(Q[h-1], Q[h], P[i]) <  0) do
			h = h - 1;
		end
		h = h + 1;
		Q[h] = P[i];
	end
	--clear holes in Q
	for i= h+1,#Q do Q[i] = nil end
	return Q
end


local function conv_sweept(P)

	assert(P.sorted)
	local Q = {}
	local tr = {}
	local last
	--first triangle
	local sign = rightturn_2(P[1],P[2],P[3])
	if sign > 0 then
		Q[1],Q[2],Q[3] = 1,2,3
		tr = {0,1,2}
		last = 3
		--print"right"
	elseif sign < 0 then
		Q[1],Q[2],Q[3] = 1,3,2
		tr = {0,2,1}
		last = 2
		--print"left"
	else
		error("collinear points")
	end

	for i=4,#P do
		local u,d = last,last
		--prtable(Q)
		while (rightturn_2(P[i],P[Q[u]],P[Q[mod(u+1,#Q)]]) < 0) do
			--local usig = mod(u+1,#Q)
			--print("u",u,usig,mod(usig+1,#Q))
			u = mod(u+1,#Q)
		end
		while (rightturn_2(P[i],P[Q[d]],P[Q[mod(d-1,#Q)]]) > 0) do
			d = mod(d-1,#Q)
		end
		if(d >u and u~=1) then
			print(d,u)--,rightturn_2(Q[1],Q[2],Q[3]),rightturn_2(P[1],P[2],P[3]))
			--prtable(Q)
			error("bad sdfjlksdf")
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
	return CH
end


function M.triang_sweept(P)


	assert(P.sorted,"points must be sorted")
	local Q = {}
	local tr = {}
	local last
	--first triangle
	local sign = rightturn_2(P[1],P[2],P[3])
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
		while (rightturn_2(P[i],P[Q[u]],P[Q[mod(u+1,#Q)]]) < 0) do
			table.insert(tr,i-1)
			table.insert(tr,Q[mod(u+1,#Q)]-1)
			table.insert(tr,Q[u]-1)
			u = mod(u+1,#Q)
		end
		while (rightturn_2(P[i],P[Q[d]],P[Q[mod(d-1,#Q)]]) > 0) do
			table.insert(tr,i-1)
			table.insert(tr,Q[d]-1)
			table.insert(tr,Q[mod(d-1,#Q)]-1)
			d = mod(d-1,#Q)
		end
		if(d >u and u~=1) then
			print(d,u)--,rightturn_2(Q[1],Q[2],Q[3]),rightturn_2(P[1],P[2],P[3]))
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
		--assert(rightturn_2(P[tr[i]+1],P[tr[i+1]+1],P[tr[i+2]+1]) > 0)
		-- if rightturn_2(P[tr[i]+1],P[tr[i+1]+1],P[tr[i+2]+1]) < 0 then
			-- tr[i+1],tr[i+2] = tr[i+2],tr[i+1]
		-- end
	-- end
	return CH,tr
end

--Edges structure

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

local function deleteTriangleEdgeMal(E,a,b,c)
	if not c then return end
	local e = E[a][b]
	removeEdgeEnd(e,c)
	if #e==0 then
		E[a][b] = nil
		E[b][a] = nil
	end
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

function M.Ed2TR(E)
	local doneT = {}
	local Ed2 = E --deepcopy(E)
	local tr2 = {}
	for ka,v in pairs(Ed2) do
	for kb,op in pairs(v) do
		local hash = M.TriangleKey(ka,kb,op)
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



--lexicografic sort
function M.lexicografic_sort(P)
	table.sort(P,function(a,b) 
		return (a.x < b.x) or ((a.x == b.x) and (a.y < b.y))
	end)
	P.sorted = true
end

function M.bounds(P)
	local minx,maxx,miny,maxy = math.huge,-math.huge,math.huge,-math.huge
	for i=1,#P do
		minx = (P[i].x<minx) and P[i].x or minx
		maxx = (P[i].x>maxx) and P[i].x or maxx
		miny = (P[i].y<miny) and P[i].y or miny
		maxy = (P[i].y>maxy) and P[i].y or maxy
	end
	return mat.vec2(minx,miny),mat.vec2(maxx,maxy)
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
local min = math.min
local function TriangleKey(a,b,c)
	-- local t = {a,b,c}
	-- table.sort(t)
	-- return table.concat(t,"_")
	
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
	-- if a > b then a,b = b,a end
	-- if b > c then b,c = c,b end
	-- if a > b then a,b = b,a end
	-- return a .. "_" .. b .. "_" .. c
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



return M