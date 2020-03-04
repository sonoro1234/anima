
local CG = require"anima.CG3"

local function check_self_repetition(poly)
	for i=1,#poly-1 do
		local pt = poly[i]
		for j=i+1,#poly do
		local pt2 = poly[j]
			if pt==pt2 then 
				print("repeated point",i,j,"#poly",#poly)
				error"self repetition"
			end
		end
	end
end

local function check2poly_repetition(poly1,poly2)
	for i=1,#poly1 do
		local pt = poly1[i]
		for j=1,#poly2 do
		local pt2 = poly2[j]
			if pt==pt2 then 
				print("repeated point",i,j)
				error"2poly repetition"
			end
		end
	end
end

local function check_point_repetition(poly)
	local has_repeat = false
	check_self_repetition(poly)
	for nh,hole in ipairs(poly.holes) do
		check2poly_repetition(poly,hole)
		for nh2=nh+1,#poly.holes do
			check2poly_repetition(hole,poly.holes[nh2])
		end
	end
	return has_repeat
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
	local isIn = (t >=0) and (t<=1)
	return isIn,t
end

local function SegmentIntersectC(a,b,c,d,deqa)
	local A,B,C,D,E = CG.SegmentIntersect(a,b,c,d), IsPointInSegment(c,a,b), IsPointInSegment(d,a,b),
			IsPointInSegment(a,c,d),IsPointInSegment(b,c,d)
	
	if deqa then
		if A then 
			print("SIC A",A)
			return true
		else
			return false
		end
	end
	if A or B or C or D or E then 
		print("SIC",A,B,C,D,E);
		return true 
	else 
		return false 
	end
end

local function mod(a,b)
	return ((a-1)%b)+1
end

local function check2poly_crossings(poly1,poly2)
	for i=1,#poly1 do
		local ai,bi = i,mod(i+1,#poly1)
		local a,b = poly1[ai],poly1[bi]
		for j=1,#poly2 do
			local ci,di = j,mod(j+1,#poly2)
			local c,d = poly2[ci],poly2[di]
			if SegmentIntersectC(a,b,c,d) 
			then
				print("poly1-poly2 crossing",ai,bi,ci,di)
				error"self crossing"
			end
		end
	end

end

local function check_self_crossings(poly,donterror)
	for i=1,#poly do
		local ai,bi = i,mod(i+1,#poly)
		local a,b = poly[ai],poly[bi]
		local lim = #poly --math.min(mod(i-2,#poly),#poly)
		for j=i+2,lim do
			local ci,di = j,mod(j+1,#poly)
			local c,d = poly[ci],poly[di]
			if SegmentIntersectC(a,b,c,d,d==a)
			then
				print(a,b,c,d,d==a)
				--print((a-b).normalize,(c-d).normalize)
				print("self crossing",ai,bi,ci,di,"#poly",#poly)
				if not donterror then error"self crossing" end
				--has_cros = true
			end
		end
	end
end

local function check_crossings(poly)
	local has_cros = false
	check_self_crossings(poly)
	for nh,hole in ipairs(poly.holes) do
		check_self_crossings(hole)
		check2poly_crossings(poly,hole)
		for nh2=nh+1,#poly.holes do
			check2poly_crossings(hole,poly.holes[nh2])
		end
	end
	return has_cros
end

local function CHECKPOLY(poly)
	check_point_repetition(poly)
	check_crossings(poly)
end

local function check_collinear(poly)

	local colin = {}
	local numpt = #poly
	for i=1,numpt do
		local ang,conv,s,cose = CG.Angle(poly[mod(i-1,numpt)],poly[i],poly[mod(i+1,numpt)])
		if s==0 then  
			if cose<0 then
				print("collinear on",i)
				error"collinear"
			elseif poly[mod(i-1,numpt)]==poly[mod(i+1,numpt)] then --cose>0 and repeated
				print("collinear on",i)
				error"collinear"
			end
		end
	end

end
local M = {CHECKPOLY=CHECKPOLY,CHECKCOLIN=check_collinear,check_self_crossings=check_self_crossings}
return M