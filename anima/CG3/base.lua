require"anima"

local mat = require"anima.matrixffi"
local M = {}

local function mod(a,b)
	return ((a-1)%b)+1
end
--CCW 1 CW -1
local function rightturn_2det(a,b,c)
	return (b.x*c.y - b.y*c.x - (a.x*c.y - a.y*c.x) + a.x*b.y - a.y*b.x) --< 0
end
M.SignDet = rightturn_2det

local function Sign( p1,  p2,  p3)
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
end
M.Sign = Sign

local acos = math.acos
local function Angle(p1,p2,p3,CW)
	if not CW then p1,p3 = p3,p1 end
	assert(p1~=p2 and p2~=p3) --would give nan as angle
	if p1==p2 or p2==p3 then
		print("Angle called with p1==p2 or p2==p3")
		return math.pi*0.5,true,0,0
	end
	
	local a = p1-p2
	local b = p3-p2
	local cose = a*b/(a.norm*b.norm)
	--if cose > 1 or cose < -1 then print(p1,p2,p3);print(a,b); error"bad cose" end
	--happening when a = l*b
	cose = (cose > 1 and 1) or (cose < -1 and -1) or cose
	--assert(not cose==1) --0 or 360
	local ang = acos(cose)
	local s = Sign(p1,p2,p3)
	if s==0 then
		if cose < 0 then return ang,false,s,cose
		else return 0,true,s,cose end
	elseif s <0 then return ang,true,s,cose 
	else return 2*math.pi-ang,false ,s,cose
	end
end

M.Angle = Angle

--say if interiors of segments a-b c-d overlap
local function SegmentIntersect(a,b,c,d)
	local sc,sd = Sign(c,b,a),Sign(d,b,a)
	local sgabcd = Sign(a,d,c)*Sign(b,d,c)
	return (sc*sd < 0) and (sgabcd < 0),sc,sd
end
M.SegmentIntersect = SegmentIntersect

local function QuadSigns(a,b,c,d)
	local sc,sd = Sign(a,b,c),Sign(a,b,d)
	local sa,sb = Sign(c,d,a),Sign(c,d,b)
	return sa,sb,sc,sd 
end
M.QuadSigns =QuadSigns

local function SegmentBeginIntersect(a,b,c,d)
	local sc,sd = Sign(a,b,c),Sign(a,b,d)
	local sa,sb = Sign(c,d,a),Sign(c,d,b)
	return (sc*sd < 0) and (sa*sb < 0 or sa==0),sa,sb,sc,sd
end
M.SegmentBeginIntersect = SegmentBeginIntersect


-- returns the point where a SegmentIntersect happens
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

function M.IntersecPoint2(a,b,c,d)
	local den = (a.x - b.x)*(c.y - d.y) - (a.y - b.y)*(c.x - d.x)
	if den==0 then return 0,false end
	local num = (a.x - c.x)*(c.y - d.y) - (a.y - c.y)*(c.x - d.x)
	local t = num/den
	
	return a + t*(b - a), t, true
end

-- as IsPointInTri but including closure
local function IsPointInTriC( pt,  v1,  v2,  v3)
	
	local b1, b2, b3;

	b1 = Sign(pt, v1, v2) ;
	b2 = Sign(pt, v2, v3) ;
	b3 = Sign(pt, v3, v1) ;
	
	return (b1<=0 and b2<=0 and b3<=0) or (b1>=0 and b2>=0 and b3>=0),b1,b2,b3
end
M.IsPointInTriC = IsPointInTriC
--dont needs to be oriented
local function IsPointInTri( pt,  v1,  v2,  v3)
	
	local b1, b2, b3;

	b1 = Sign(pt, v1, v2) < 0.0;
	b2 = Sign(pt, v2, v3) < 0.0;
	b3 = Sign(pt, v3, v1) < 0.0;
	
	return ((b1 == b2) and (b2 == b3));
end

local function IsPointInTri2( pt, v1, v2, v3 ) 
	local l2 = (pt.x-v1.x)*(v3.y-v1.y) - (v3.x-v1.x)*(pt.y-v1.y) 
    local l3 = (pt.x-v2.x)*(v1.y-v2.y) - (v1.x-v2.x)*(pt.y-v2.y) 
    local l1 = (pt.x-v3.x)*(v2.y-v3.y) - (v2.x-v3.x)*(pt.y-v3.y)
	return (l1>0 and l2>0  and l3>0) or (l1<0 and l2<0 and l3<0),l1,l2,l3
end
M.IsPointInTri = IsPointInTri2

local function TArea(a,b,c)
	return 0.5*((a.x-c.x)*(b.y-a.y)-(a.x-b.x)*(c.y-a.y))
end
M.TArea = TArea

local function signed_area(poly)
	local sum = 0
	for i=2,#poly-1 do
		sum = sum + Sign(poly[1],poly[i],poly[i+1])
	end
	return sum
end
M.signed_area = signed_area




--answers without taking orientation
--includes the border
local function IsPointInPoly(P, p)

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
		--((p.x - P[i].x) < (P[j].x - P[i].x) * (p.y - P[i].y) / (P[j].y - P[i].y) )) then
		
		 -- ((P[j].y - P[i].y)*(p.x - P[i].x) < (P[j].x - P[i].x) * (p.y - P[i].y)  )) then
          c = not c;
		end
	end
	P[#P] = nil
    return c;
end

--crossing number algo
--http://geomalgorithms.com/a03-_inclusion.html
local function IsPointInPolyCn(V,P)
	local i, c = 0,false 
	local lenV = #V
	V[lenV + 1] = V[1]
	for i=1,lenV do
		if (((V[i].y <= P.y) and (V[i+1].y > P.y))     -- an upward crossing
        or ((V[i].y > P.y) and (V[i+1].y <=  P.y)))  -- a downward crossing
		then
			local vt = (P.y  - V[i].y) / (V[i+1].y - V[i].y);
			if (P.x <  V[i].x + vt * (V[i+1].x - V[i].x)) then -- P.x < intersect
                 c = not c   -- a valid crossing of y=P.y right of P.x
			end
		end
	end
	V[#V] = nil
    return c;
end

local function IsPointInPolyWn(V,P)
	local i, wn = 0,0 
	local lenV = #V
	V[lenV + 1] = V[1]
	for i=1,lenV do
		if (V[i].y <= P.y) then          -- start y <= P.y
            if (V[i+1].y  > P.y) then     -- an upward crossing
                if (Sign( V[i], V[i+1], P) > 0) then --- P left of  edge
                    wn = wn + 1            -- have  a valid up intersect
				end
			end
                                -- start y > P.y (no test needed
		elseif (V[i+1].y  <= P.y) then    -- a downward crossing
                if (Sign( V[i], V[i+1], P) < 0) then -- P right of  edge
                    wn = wn - 1            -- have  a valid down intersect
				end
        end
	end
	V[#V] = nil
    return wn~=0;
end

M.IsPointInPoly = IsPointInPolyCn
M.IsPointInPolyWn = IsPointInPolyWn

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


local function check_point_repetition(poly,verbose)
	local has_repeat = false
	for i=1,#poly-1 do
		local pt = poly[i]
		for j=i+1,#poly do
		local pt2 = poly[j]
			if pt==pt2 then 
				if verbose then print("repeated point",i,j) end
				has_repeat=true 
			end
		end
	end
	return has_repeat
end
M.check_point_repetition = check_point_repetition

local function check_crossings(poly,verbose)
	local has_cros = false
	for i=1,#poly do
		local ai,bi = i,mod(i+1,#poly)
		local a,b = poly[ai],poly[bi]
		for j=i+2,#poly do
			local ci,di = j,mod(j+1,#poly)
			local c,d = poly[ci],poly[di]
			if M.SegmentIntersect(a,b,c,d) then
				if verbose then print("self crossing",ai,bi,ci,di,"#poly",#poly) end
				has_cros = true
			end
		end
	end
	return has_cros
end
M.check_crossings = check_crossings

function M.check_simple(poly,verbose,verb2)
	if verb2==nil then verb2 = verbose end
	return check_crossings(poly,verbose),check_point_repetition(poly,verb2)
end


--lexicografic sort
function M.lexicografic_compare(a,b) 
		return (a.x < b.x) or ((a.x == b.x) and (a.y < b.y))
	end
	
local algo = require"anima.algorithm.algorithm"
function M.lexicografic_sort(P)
	algo.quicksort(P,1,#P,M.lexicografic_compare)
	P.sorted = true
end

--helper binary search
local function binary_search(A, T, fcomp)
	local floor = math.floor
	local n = #A
    local L = 1
    local R = n
	local m
    while L <= R do
        m = floor((L + R) / 2)
        --if A[m] < T then
		if fcomp(A[m],T) then
            L = m + 1
        --elseif A[m] > T then
		elseif fcomp(T, A[m]) then
            R = m - 1
        else
            return m
		end
	end
    return false
end
M.binary_search = binary_search

function M.lexicografic_find(P,v)
	return binary_search(P,v,M.lexicografic_compare)
end

-- returns bounds given polygon
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


return M