local CG = require"anima.CG3.base"

--this version allows identical points
local function CatmulRom(p0,p1,p2,p3,ps,alpha,amountOfPoints,last)

	local function GetT( t,  p0,  p1,alpha)
	    local a = math.pow((p1.x-p0.x), 2.0) + math.pow((p1.y-p0.y), 2.0);
	    local b = math.pow(a, 0.5);
	    local c = math.pow(b, alpha);
	   
	    return (c + t);
	end
	
	local t0 = 0.0;
	local t1 = GetT(t0, p0, p1, alpha);
	local t2 = GetT(t1, p1, p2, alpha);
	local t3 = GetT(t2, p2, p3, alpha);
	
	--print(t0,t1,t2,t3)
	local range = last and amountOfPoints or (amountOfPoints - 1)
	
	--special cases
	local A1s,A3s
	if p1==p2 then
		for i=0,range do ps[#ps + 1] = p1 end
		return
	end
	if p0==p1 then A1s = p0 end
	if p2==p3 then A3s = p2 end
	
	local inc = (t2-t1)/amountOfPoints
	for i=0,range do
		local t = t1 + inc*i
	--for t=t1; t<t2; t+=((t2-t1)/amountOfPoints))
	    local A1 = A1s or (t1-t)/(t1-t0)*p0 + (t-t0)/(t1-t0)*p1;
	    local A2 = (t2-t)/(t2-t1)*p1 + (t-t1)/(t2-t1)*p2;
	    local A3 = A3s or (t3-t)/(t3-t2)*p2 + (t-t2)/(t3-t2)*p3;

	    local B1 = (t2-t)/(t2-t0)*A1 + (t-t0)/(t2-t0)*A2;
	    local B2 = (t3-t)/(t3-t1)*A2 + (t-t1)/(t3-t1)*A3;

	    local C = (t2-t)/(t2-t1)*B1 + (t-t1)/(t2-t1)*B2;
	   -- print(C)
	    ps[#ps + 1] = C
	end
end
CG.CatmulRom = CatmulRom

local floor, min, max = math.floor, math.min, math.max
local function Spline(points,alpha,amountOfPoints,closed,minlen)
	minlen = minlen or 5
	--print("Spline alpha",alpha)
	local ps = {}
	local i0,i1,i2,i3
	if closed then
		if #points < 3 then return ps end
		local divs = floor((points[2]-points[1]):norm()/minlen)
		divs = max(1,min(divs, amountOfPoints))
		CatmulRom(points[#points],points[1],points[2],points[3],ps,alpha,divs)
		for i=1,#points-3 do
			divs = floor((points[i+2]-points[i+1]):norm()/minlen)
			divs = max(1,min(divs, amountOfPoints))
			CatmulRom(points[i],points[i+1],points[i+2],points[i+3],ps,alpha,divs)
		end
		divs = floor((points[#points]-points[#points-1]):norm()/minlen)
		divs = max(1,min(divs, amountOfPoints))
		CatmulRom(points[#points-2],points[#points-1],points[#points],points[1],ps,alpha,amountOfPoints)
		divs = floor((points[#points]-points[1]):norm()/minlen)
		divs = max(1,min(divs, amountOfPoints))
		CatmulRom(points[#points-1],points[#points],points[1],points[2],ps,alpha,amountOfPoints,true)
		
		ps[#ps] = nil --delete repeated
	else
		if #points < 4 then return ps end
		for i=1,#points-4 do
			CatmulRom(points[i],points[i+1],points[i+2],points[i+3],ps,alpha,amountOfPoints)
		end
		local i = #points-3
		CatmulRom(points[i],points[i+1],points[i+2],points[i+3],ps,alpha,amountOfPoints,true)
	end
	return ps
end

CG.Spline = Spline