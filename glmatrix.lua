

local function create_ident_mat(n)
	local m = {n=n}
	for i=1,n do
		m[i] = {}
		for j=1,n do
			m[i][j] = (i==j) and 1 or 0
		end
	end
	return m
end

local M4 = {}

function M4:new(o)
	o = o or create_ident_mat(4)
	setmetatable(o, self)
	self.__index = self
	return o
end

function M4:col(j)
	local res = {}
	for i=1,4 do
		res[i] = self[i][j]
	end
	return res
end
local function translate_mat(a,b,c)
	local res = M4:new()
	res[1][4] = a or 0
	res[2][4] = b or 0
	res[3][4] = c or 0
	return res
end

local function scale_mat(a,b,c)
	local res = M4:new()
	assert(a,"a is nil")
	res[1][1] = a
	res[2][2] = b or a
	res[3][3] = c or a
	return res
end
local function dot(a,b)
	local res = 0
	for i,v in ipairs(a) do
		res = res + a[i]*b[i]
	end
	return res
end
local function normalize(v)
	local mod = math.sqrt(dot(v,v))
	local u = {}
	for i,val in ipairs(v) do
		u[i] = val/mod
	end
	return u
end
local function rotate_matBAK(a,x,y,z)
	local res = M4:new()
	local u = normalize{x,y,z}
	
	res[1][1] = a
	res[2][2] = b
	res[3][3] = c
	return res
end

local function M4fromT(t)
	local m = {}
	for i=1,4 do
		m[i] = {}
		for j=1,4 do
			m[i][j] = t[(i-1)*4 + j]
		end
	end
	return M4:new(m)
end
local function rotate_mat(theta, x,y,z)
	local u = normalize{x,y,z}
	local xy = u[1] * u[2]
	local xz = u[1] * u[3]
	local yz = u[2] * u[3]
	local c = math.cos(theta)
	local one_c = 1. - c
	local s = math.sin(theta)
	return M4fromT{u[1] * u[1] * one_c + c, -- row 1
	xy * one_c - u[3] * s,
	xz * one_c + u[2] * s,
	0,
	xy * one_c + u[3] * s, -- row 2
	u[2] * u[2] * one_c + c,
	yz * one_c - u[1] * s,
	0,
	xz * one_c - u[2] * s, -- row 3
	yz * one_c + u[1] * s,
	u[3] * u[3] * one_c + c,
	0,
	0, 0, 0, 1} -- row 4
end




function M4:multiply(b)
	local res = M4:new()
	for j=1,4 do
		for i=1,4 do
			local ar = self[i]
			local bc = b:col(j)
			res[i][j] = dot(ar,bc)
		end
	end
	return res
end

function M4.__mul(a,b)
	return a:multiply(b)
end
function M4:print()
	for i=1,4 do
		print(self[i][1],self[i][2],self[i][3],self[i][4])
	end
	print()
end
function M4.__tostring(m)
	local str = ""
	for i=1,4 do
		str = str .. table.concat(self[i]) .. "\n"
		--print(self[i][1],self[i][2],self[i][3],self[i][4])
	end
	return str
end
function M4:table()
	local res = {}
	for j=1,4 do
		for i=1,4 do
			table.insert(res,self[i][j])
		end
	end
	return res
end
function M4:translate(...)
	return translate_mat(...)*self
end
function M4:scale(...)
	return scale_mat(...)*self
end
function M4:rotate(...)
	return rotate_mat(...)*self
end
local glFloatv = ffi.typeof('GLfloat[?]')
function M4:gl()
	return glFloatv(16,self:table())
end
return {M4=M4,translate_mat=translate_mat,scale_mat=scale_mat,rotate_mat=rotate_mat}
-- rot = rotate_mat(1.4,1,2,3)
-- rot2 = rotate_mat(-1.4,1,2,3)
-- rot3 = rot:multiply(rot2)

-- rot:print()
-- rot2:print()
-- rot3:print()