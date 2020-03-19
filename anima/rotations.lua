local mat = require"anima.matrixffi"
local mat3 = mat.mat3
local sin, cos = math.sin, math.cos
local atan2,asin = math.atan2, math.asin
local sqrt = math.sqrt

local M = {}
--useful for getting matrix distances between matixes with M3norm(A-B)
function M.M3norm(A)
	local B = A*(A.t)
	return sqrt(B.m11+B.m22+B.m33)
end

function M.Rx(a)
	local c,s = cos(a),sin(a)
	return mat3( 1 , 0, 0,
				 0 , c, -s,
				 0 , s, c)
end
function M.Ry(a)
	local c,s = cos(a),sin(a)
	return mat3( c , 0, s,
				 0 , 1, 0,
				 -s , 0, c)
end
function M.Rz(a)
	local c,s = cos(a),sin(a)
	return mat3( c , -s, 0,
				 s , c, 0,
				 0 , 0, 1)
end
--matrix from Tait-Euler angles
--names axis order E extrinsic I intrinsic
--but I will just be the E version in reverse order
function M.YXZE(a,b,c)
	local c1,s1 = cos(a),sin(a)
	local c2,s2 = cos(b),sin(b)
	local c3,s3 = cos(c),sin(c)
	return mat3(c1*c3+s1*s2*s3	, c3*s1*s2-c1*s3	, c2*s1	,
				c2*s3			, c2*c3				, -s2	,
				c1*s2*s3-c3*s1	, c1*c3*s2+s1*s3	, c1*c2)

end
--equals XYZI
function M.ZYXE(a,b,c)
	local c1,s1 = cos(a),sin(a)
	local c2,s2 = cos(b),sin(b)
	local c3,s3 = cos(c),sin(c)
	return mat3(c1*c2		, c1*s2*s3-c3*s1	, s1*s3+c1*c3*s2	,
				c2*s1			, c1*c3+s1*s2*s3	, c3*s1*s2-c1*s3	,
				-s2				, c2*s3				, c2*c3)

end
function M.ZYXE2angles(m)
	local a = atan2(m.m12,m.m11)
	local b = asin(-m.m13)
	local c = atan2(m.m23,m.m33)
	return a,b,c
end

--equals YXZI
function M.ZXYE(a,b,c)
	local c1,s1 = cos(a),sin(a)
	local c2,s2 = cos(b),sin(b)
	local c3,s3 = cos(c),sin(c)
	return mat3(c1*c3-s1*s2*s3	, -c2*s1			, c1*s3+c3*s1*s2,
				c3*s1+c1*s2*s3	, c1*c2				, s1*s3-c1*c3*s2,
				-c2*s3			, s2				, c2*c3)

end
function M.ZXYE2angles(m)
	--local tan1neg = m.m21/m.m22
	local a = atan2(-m.m21,m.m22)
	local b = asin(m.m23)
	local c = atan2(-m.m13,m.m33)
	return a,b,c
end
return M