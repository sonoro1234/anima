
local vector ={}
vector.__index = vector
setmetatable(vector, vector)
function vector:new(o) 
	setmetatable(o, vector)
	return o
end
function vector.is_vector(x)
	return getmetatable(x)==vector
end
function vector.dot(a,b)
	local res = 0
	for i,v in ipairs(a) do
		res = res + a[i]*b[i]
	end
	return res
end
function vector:normalize()
	local mod = math.sqrt(self:dot(self))
	local u = {}
	for i,val in ipairs(self) do
		u[i] = val/mod
	end
	return vector:new(u)
end
function vector:norm()
	return math.sqrt(self:dot(self))
end
function vector:ang(v)
	local norm1 = self:normalize()
	local norm2 = v:normalize()
	local dot = norm1:dot(norm2)
	return math.acos(dot)
end
function vector:cross(v)
	local res = {}
	res[1] = self[2]*v[3] - self[3]*v[2]
	res[2] = self[3]*v[1] - self[1]*v[3]
	res[3] = self[1]*v[2] - self[2]*v[1]
	return vector:new(res)
end
function vector:mul(b)
	local res = {}
	for i,v in ipairs(self) do
		res[i] = v*b
	end
	return vector:new(res)
end
function vector.__mul(a,b)
	if type(a)=="number" then
		return b:mul(a)
	elseif type(b)=="number" then
		return a:mul(b)
	elseif vector.is_vector(a) and vector.is_vector(b) then
		return a:dot(b)
	end
	error("vector.__mul bad operands")
end
function vector.__add(a,b)
	local res = {}
	for i,v in ipairs(a) do
		res[i] = a[i] + b[i]
	end
	return vector:new(res)
end
function vector.__unm(a)
	local res = {}
	for i,v in ipairs(a) do
		res[i] = -a[i]
	end
	return vector:new(res)
end
function vector.__sub(a,b)
	local res = {}
	for i,v in ipairs(a) do
		res[i] = a[i] - b[i]
	end
	return vector:new(res)
end
function vector.__tostring(t)
	return table.concat(t,",")
end
function vector.__call(t,...)
	return t:new{...}
end
function vector:print()
	print(unpack(self))
end

--aa = vector(1,1,1)

--[[
aa = vector:new{1,1,1}
bb = aa:new{2,2,2}
print(vector.__call)
cc = vector(23,24)
print(bb*2)
print(cc)
--]]
return vector