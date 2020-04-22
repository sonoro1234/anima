

local ffi  = require 'ffi'
local math = require 'math'
local bit  = require 'bit'
local sin, cos = math.sin, math.cos
local sqrt = math.sqrt

ffi.cdef [[
typedef struct {
  double m11, m21;
  double m12, m22;
} mat2;
typedef struct {
  double m11, m21, m31;
  double m12, m22, m32;
  double m13, m23, m33;
} mat3;
typedef struct {
  double m11, m21, m31, m41;
  double m12, m22, m32, m42;
  double m13, m23, m33, m43;
  double m14, m24, m34, m44;
} mat4;
]]

ffi.cdef [[
typedef struct vec2 { double x, y;       } vec2;
typedef struct vec3 { double x, y, z;    } vec3;
typedef struct vec4 { double x, y, z, w; } vec4;
]]

local glFloatv = ffi.typeof('float[?]')

local vec2
vec2 = ffi.metatype('vec2', {
	__eq = function(a,b) return a.x == b.x and a.y == b.y end,
  __add = function(a, b) return vec2(a.x + b.x, a.y + b.y) end,
  __sub = function(a, b) return vec2(a.x - b.x, a.y - b.y) end,
  __unm = function(a) return vec2(-a.x,-a.y) end,
  __mul = function(a, b)
	if not ffi.istype(vec2, a) then a,b=b,a end
    if not ffi.istype(vec2, b) then
    return vec2(a.x * b, a.y * b) end
    return a.x * b.x + a.y * b.y
  end,
  __div = function(a, b)
    if not ffi.istype(vec2, b) then
    return vec2(a.x / b, a.y / b) end
    return vec2(a.x / b.x, a.y / b.y)
  end,
  __pow = function(a, b) -- dot product
    if not ffi.istype(vec2, b) then
    return vec2(a.x ^ b, a.y ^ b) end
    return a.x * b.x + a.y * b.y
  end,
  __index = function(v, i)
    if i == 'gl' then return glFloatv(2, v.x, v.y) end
	if i == 'xy' then return v end
	if i == 'norm' then return sqrt(v*v) end
	if i == 'normalize' then return v/sqrt(v*v) end
	if i == 'cross' then
		return function(_,w)
					 return v.x*w.y-v.y*w.x
				end
	end
	if i == '__serialize' then 
		return function(v) 
			return table.concat{"loadstring ('return mat.vec2(",v.x,",",v.y,")' )()"}
		end
	end
    return nil
  end,
  __tostring = function(v) return '<'..v.x..','..v.y..'>' end
})
local vec3
vec3 = ffi.metatype('vec3', {
	__new = function(tp,x,y,z)
		if ffi.istype(vec2,x) then
			return ffi.new(tp,x.x,x.y,y or 0)
		elseif ffi.istype(glFloatv,x) and ffi.sizeof(x)==3*ffi.sizeof"float" then
			return ffi.new(tp,x[0],x[1],x[2])
		end
		return ffi.new(tp,x,y,z)
	end,
	__eq = function(a,b)
		if not ffi.istype(vec3,b) then return false end
		return a.x == b.x and a.y == b.y and a.z == b.z end,
	__add = function(a, b) return vec3(a.x + b.x, a.y + b.y, a.z + b.z) end,
	__sub = function(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end,
	__unm = function(a) return vec3(-a.x,-a.y,-a.z) end,
	__mul = function(a, b)
		if not ffi.istype(vec3, a) then a,b=b,a end
		if not ffi.istype(vec3, b) then 
			return vec3(a.x * b, a.y * b, a.z * b) 
		end
		return a.x * b.x + a.y * b.y + a.z * b.z
	end,
	__div = function(a, b)
		if not ffi.istype(vec3, b) then
		return vec3(a.x / b, a.y / b, a.z / b) end
		return vec3(a.x / b.x, a.y / b.y, a.z / b.z)
	end,
	__pow = function(a, b) -- dot product
		if not ffi.istype(vec3, b) then
		return vec3(a.x ^ b, a.y ^ b, a.z ^ b) end
		return a.x * b.x + a.y * b.y + a.z * b.z
	end,
	__index = function(v, i)
		if i == 'gl' then return glFloatv(3, v.x, v.y, v.z) end
		if i == 'xy' then return vec2(v.x, v.y) end
		if i == 'norm' then return sqrt(v*v) end
		if i == 'normalize' then return v/sqrt(v*v) end
		if i == 'cross' then
			return function(_,w)
						return vec3(v.y*w.z-v.z*w.y, v.z*w.x-v.x*w.z, v.x*w.y-v.y*w.x)
					end
		end
		if i == 'set' then
			return function(_,w)
				v.x,v.y,v.z = w.x,w.y,w.z
			end
		end
		if i == '__serialize' then 
			return function(v) 
				return table.concat{"loadstring ('return mat.vec3(",v.x,",",v.y,",",v.z,")' )()"}
			end
		end
		--if i == '__serialize' then return function(v) return string.dump(function() return vec3(v.x,v.y,v.z) end) end end
		--if i == 0 then return v end
		return nil
	end,
	-- __newindex = function(v, i, val)
		-- if i == 0 then 
			-- v.x = val.x;v.y=val.y;v.z=val.z 
		-- end
	--end,
	__tostring = function(v) return '<'..v.x..','..v.y..','..v.z..'>' end,
	
})
local vec4
vec4 = ffi.metatype('vec4', {
	__new = function(tp,x,y,z,w)
		if ffi.istype(vec3,x) then
			return ffi.new(tp,x.x,x.y,x.z,y)
		end
		return ffi.new(tp,x,y,z,w)
	end,
  __add = function(a, b) return vec4(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w) end,
  __sub = function(a, b) return vec4(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w) end,
  __unm = function(a) return vec4(-a.x,-a.y,-a.z,-a.w) end,
  __mul = function(a, b)
	if not ffi.istype(vec4, a) then a,b=b,a end
    if not ffi.istype(vec4, b) then
    return vec4(a.x * b, a.y * b, a.z * b, a.w * b) end
    return vec4(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w)
  end,
  __div = function(a, b)
    if not ffi.istype(vec4, b) then
    return vec4(a.x / b, a.y / b, a.z / b, a.w / b) end
    return vec4(a.x / b.x, a.y / b.y, a.z / b.z, a.w / b.w)
  end,
  __pow = function(a, b) -- dot product
    if not ffi.istype(vec4, b) then
    return vec4(a.x ^ b, a.y ^ b, a.z ^ b, a.w ^ b) end
    return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
  end,
  __index = function(v, i)
    if i == 'gl' then return glFloatv(4, v.x, v.y, v.z, v.w) end
	if i == 'xyz' then return vec3(v.x, v.y, v.z) end
	if i == 'xy' then return vec2(v.x, v.y) end
	if i == '__serialize' then 
			return function(v) 
				return table.concat{"loadstring ('return mat.vec4(",v.x,",",v.y,",",v.z,",",v.w,")' )()"}
			end
		end
    return nil
  end,
  __tostring = function(v) return '<'..v.x..','..v.y..','..v.z..','..v.w..'>' end
})

local M = {vec2 = vec2, vec3 = vec3, vec4 = vec4, vec = vec4,
        vvec2 = ffi.typeof('vec2[?]'),
        vvec3 = ffi.typeof('vec3[?]'),
        vvec4 = ffi.typeof('vec4[?]'),
        vvec  = ffi.typeof('vec4[?]')}


local mat2
mat2 = ffi.metatype('mat2', {
  __mul = function(a, b)
    if not ffi.istype(mat2, a) then a, b = b, a end
    if ffi.istype(mat2, b) then
      return mat2(a.m11*b.m11 + a.m21*b.m12,  a.m11*b.m21 + a.m21*b.m22,
                  a.m12*b.m11 + a.m22*b.m12,  a.m12*b.m21 + a.m22*b.m22)
    elseif ffi.istype(vec2, b) then
      return vec2(a.m11*b.x + a.m21*b.y,
                  a.m12*b.x + a.m22*b.y)
    end
    return mat2(a.m11 * b, a.m21 * b,
                a.m12 * b, a.m22 * b)
  end,
  __index = function(m, i)
    if i == 't' then
      return mat2(m.m11, m.m12,
                  m.m21, m.m22)
    elseif i == 'det' then
      return m.m11 * m.m22 - m.m21 * m.m12
    elseif i == 'inv' then
      local det = m.m11 * m.m22 - m.m21 * m.m12;
      return mat2( m.m22 / det, -m.m21 / det,
                  -m.m12 / det,  m.m11 / det)
    elseif i == 'gl' then
      return glFloatv(4, m.m11, m.m12,
                         m.m21, m.m22)
    end
    return nil
  end,
  __tostring = function(m) return string.format("[%+4.4f %+4.4f ]\n[%+4.4f %+4.4f ]",
                                                  m.m11, m.m21,   m.m12, m.m22) end
})
local mat3
mat3 = ffi.metatype('mat3', {
  __mul = function(a, b)
    if not ffi.istype(mat3, a) then a, b = b, a end
    if ffi.istype(mat3, b) then
      return mat3(a.m11*b.m11 + a.m21*b.m12 + a.m31*b.m13,  a.m11*b.m21 + a.m21*b.m22 + a.m31*b.m23,  a.m11*b.m31 + a.m21*b.m32 + a.m31*b.m33,
                  a.m12*b.m11 + a.m22*b.m12 + a.m32*b.m13,  a.m12*b.m21 + a.m22*b.m22 + a.m32*b.m23,  a.m12*b.m31 + a.m22*b.m32 + a.m32*b.m33,
                  a.m13*b.m11 + a.m23*b.m12 + a.m33*b.m13,  a.m13*b.m21 + a.m23*b.m22 + a.m33*b.m23,  a.m13*b.m31 + a.m23*b.m32 + a.m33*b.m33)
    elseif ffi.istype(vec3, b) then
      return vec3(a.m11*b.x + a.m21*b.y + a.m31*b.z,
                  a.m12*b.x + a.m22*b.y + a.m32*b.z,
                  a.m13*b.x + a.m23*b.y + a.m33*b.z)
    end
    return mat3(a.m11 * b, a.m21 * b, a.m31 * b,
                a.m12 * b, a.m22 * b, a.m32 * b,
                a.m13 * b, a.m23 * b, a.m33 * b)
  end,
  __unm = function(a) return mat3(-a.m11 , -a.m21 , -a.m31,
                                  -a.m12 , -a.m22 , -a.m32,
                                  -a.m13 , -a.m23 , -a.m33)
			end,
  __add = function(a, b) return mat3(a.m11 + b.m11, a.m12 + b.m12, a.m13 + b.m13,
									a.m21 + b.m21, a.m22 + b.m22, a.m23 + b.m23,
									a.m31 + b.m31, a.m32 + b.m32, a.m33 + b.m33) 
	end,
  __sub = function(a,b) return a + (-b) end,
  __index = function(m, i)
    if i == 'mat2' then
      return mat2(m.m11, m.m21,
                  m.m12, m.m22)
	elseif i == 'mat4' then
		return M.mat4(m.m11, m.m21, m.m31, 0,
					m.m12, m.m22, m.m32, 0,
					m.m13, m.m23, m.m33, 0,
					0    ,     0,     0, 1)
    elseif i == 't' then
      return mat3(m.m11, m.m12, m.m13,
                  m.m21, m.m22, m.m23,
                  m.m31, m.m32, m.m33)
    elseif i == 'det' then
      return m.m11 * (m.m22*m.m33 - m.m32*m.m23) +
             m.m21 * (m.m32*m.m13 - m.m33*m.m12) +
             m.m31 * (m.m12*m.m23 - m.m22*m.m13)
    elseif i == 'inv' then
      local det = m.m11 * (m.m22*m.m33 - m.m32*m.m23) +
                  m.m21 * (m.m32*m.m13 - m.m33*m.m12) +
                  m.m31 * (m.m12*m.m23 - m.m22*m.m13)
      return mat3((m.m22*m.m33 - m.m32*m.m23) / det, (m.m31*m.m23 - m.m21*m.m33) / det, (m.m21*m.m32 - m.m31*m.m22) / det,
                  (m.m32*m.m13 - m.m12*m.m33) / det, (m.m11*m.m33 - m.m31*m.m13) / det, (m.m31*m.m12 - m.m11*m.m32) / det,
                  (m.m12*m.m23 - m.m22*m.m13) / det, (m.m13*m.m21 - m.m11*m.m23) / det, (m.m11*m.m22 - m.m21*m.m12) / det)
    elseif i == 'gl' then
      return glFloatv(9, m.m11, m.m12, m.m13,
                         m.m21, m.m22, m.m23,
                         m.m31, m.m32, m.m33)
    end
    return nil
  end,
  __tostring = function(m)
    --return string.format("[%4.1f %4.1f %4.1f ]\n[%4.1f %4.1f %4.1f ]\n[%4.1f %4.1f %4.1f ]\n",
    --                       m.m11, m.m21, m.m31,  m.m12, m.m22, m.m32,  m.m13, m.m23, m.m33)
	return string.format("[%+4.4f %+4.4f %+4.4f ]\n[%+4.4f %+4.4f %+4.4f ]\n[%+4.4f %+4.4f %+4.4f ]\n",
                           m.m11, m.m21, m.m31,  m.m12, m.m22, m.m32,  m.m13, m.m23, m.m33)
    end
})
local mat4
mat4 = ffi.metatype('mat4', {
  __mul = function(a, b)
    if not ffi.istype(mat4, a) then a, b = b, a end
    if ffi.istype(mat4, b) then
      local ret = mat4(
        a.m11*b.m11 + a.m21*b.m12 + a.m31*b.m13 + a.m41*b.m14,
        a.m11*b.m21 + a.m21*b.m22 + a.m31*b.m23 + a.m41*b.m24,
        a.m11*b.m31 + a.m21*b.m32 + a.m31*b.m33 + a.m41*b.m34,
        a.m11*b.m41 + a.m21*b.m42 + a.m31*b.m43 + a.m41*b.m44,

        a.m12*b.m11 + a.m22*b.m12 + a.m32*b.m13 + a.m42*b.m14,
        a.m12*b.m21 + a.m22*b.m22 + a.m32*b.m23 + a.m42*b.m24,
        a.m12*b.m31 + a.m22*b.m32 + a.m32*b.m33 + a.m42*b.m34,
        a.m12*b.m41 + a.m22*b.m42 + a.m32*b.m43 + a.m42*b.m44,

        a.m13*b.m11 + a.m23*b.m12 + a.m33*b.m13 + a.m43*b.m14,
        a.m13*b.m21 + a.m23*b.m22 + a.m33*b.m23 + a.m43*b.m24,
        a.m13*b.m31 + a.m23*b.m32 + a.m33*b.m33 + a.m43*b.m34,
        a.m13*b.m41 + a.m23*b.m42 + a.m33*b.m43 + a.m43*b.m44,

        a.m14*b.m11 + a.m24*b.m12 + a.m34*b.m13 + a.m44*b.m14,
        a.m14*b.m21 + a.m24*b.m22 + a.m34*b.m23 + a.m44*b.m24,
        a.m14*b.m31 + a.m24*b.m32 + a.m34*b.m33 + a.m44*b.m34,
        a.m14*b.m41 + a.m24*b.m42 + a.m34*b.m43 + a.m44*b.m44)
      return ret
    elseif ffi.istype(vec4, b) then
      return vec4(
        a.m11*b.x + a.m21*b.y + a.m31*b.z + a.m41*b.w,
        a.m12*b.x + a.m22*b.y + a.m32*b.z + a.m42*b.w,
        a.m13*b.x + a.m23*b.y + a.m33*b.z + a.m43*b.w,
        a.m14*b.x + a.m24*b.y + a.m34*b.z + a.m44*b.w)
    elseif ffi.istype(vec3, b) then
        local v4 = vec4(b.x,b.y,b.z,1)
		v4 = a*v4
		v4 = v4/v4.w
		return v4.xyz
    end
    return mat4(
      a.m11*b, a.m21*b, a.m31*b, a.m41*b,
      a.m12*b, a.m22*b, a.m32*b, a.m42*b,
      a.m13*b, a.m23*b, a.m33*b, a.m43*b,
      a.m14*b, a.m24*b, a.m34*b, a.m44*b)
  end,
  __index = function(m, i)
    if i == 'mat3' then
      return mat3(m.m11, m.m21, m.m31,
                  m.m12, m.m22, m.m32,
                  m.m13, m.m23, m.m33)
    elseif i == 'mat2' then
      return mat2(m.m11, m.m21,
                  m.m12, m.m22)
    elseif i == 't' then
      return mat4(m.m11, m.m12, m.m13, m.m14,
                  m.m21, m.m22, m.m23, m.m24,
                  m.m31, m.m32, m.m33, m.m34,
                  m.m41, m.m42, m.m43, m.m44)
    -- http://stackoverflow.com/questions/1148309/inverting-a-4x4-matrix
    elseif i == 'det' then
      local i1 =  m.m22*m.m33*m.m44 - m.m22*m.m43*m.m34 - m.m23*m.m32*m.m44 + m.m23*m.m42*m.m34 + m.m24*m.m32*m.m43 - m.m24*m.m42*m.m33
      local i2 = -m.m12*m.m33*m.m44 + m.m12*m.m43*m.m34 + m.m13*m.m32*m.m44 - m.m13*m.m42*m.m34 - m.m14*m.m32*m.m43 + m.m14*m.m42*m.m33
      local i3 =  m.m12*m.m23*m.m44 - m.m12*m.m43*m.m24 - m.m13*m.m22*m.m44 + m.m13*m.m42*m.m24 + m.m14*m.m22*m.m43 - m.m14*m.m42*m.m23
      local i4 = -m.m12*m.m23*m.m34 + m.m12*m.m33*m.m24 + m.m13*m.m22*m.m34 - m.m13*m.m32*m.m24 - m.m14*m.m22*m.m33 + m.m14*m.m32*m.m23
      return m.m11*i1 + m.m21*i2 + m.m31*i3 + m.m41*i4
    elseif i == 'inv' then
      local inv = mat4(
        m.m22*m.m33*m.m44 - m.m22*m.m43*m.m34 - m.m23*m.m32*m.m44 + m.m23*m.m42*m.m34 + m.m24*m.m32*m.m43 - m.m24*m.m42*m.m33,
       -m.m21*m.m33*m.m44 + m.m21*m.m43*m.m34 + m.m23*m.m31*m.m44 - m.m23*m.m41*m.m34 - m.m24*m.m31*m.m43 + m.m24*m.m41*m.m33,
        m.m21*m.m32*m.m44 - m.m21*m.m42*m.m34 - m.m22*m.m31*m.m44 + m.m22*m.m41*m.m34 + m.m24*m.m31*m.m42 - m.m24*m.m41*m.m32,
       -m.m21*m.m32*m.m43 + m.m21*m.m42*m.m33 + m.m22*m.m31*m.m43 - m.m22*m.m41*m.m33 - m.m23*m.m31*m.m42 + m.m23*m.m41*m.m32,
       -m.m12*m.m33*m.m44 + m.m12*m.m43*m.m34 + m.m13*m.m32*m.m44 - m.m13*m.m42*m.m34 - m.m14*m.m32*m.m43 + m.m14*m.m42*m.m33,
        m.m11*m.m33*m.m44 - m.m11*m.m43*m.m34 - m.m13*m.m31*m.m44 + m.m13*m.m41*m.m34 + m.m14*m.m31*m.m43 - m.m14*m.m41*m.m33,
       -m.m11*m.m32*m.m44 + m.m11*m.m42*m.m34 + m.m12*m.m31*m.m44 - m.m12*m.m41*m.m34 - m.m14*m.m31*m.m42 + m.m14*m.m41*m.m32,
        m.m11*m.m32*m.m43 - m.m11*m.m42*m.m33 - m.m12*m.m31*m.m43 + m.m12*m.m41*m.m33 + m.m13*m.m31*m.m42 - m.m13*m.m41*m.m32,
        m.m12*m.m23*m.m44 - m.m12*m.m43*m.m24 - m.m13*m.m22*m.m44 + m.m13*m.m42*m.m24 + m.m14*m.m22*m.m43 - m.m14*m.m42*m.m23,
       -m.m11*m.m23*m.m44 + m.m11*m.m43*m.m24 + m.m13*m.m21*m.m44 - m.m13*m.m41*m.m24 - m.m14*m.m21*m.m43 + m.m14*m.m41*m.m23,
        m.m11*m.m22*m.m44 - m.m11*m.m42*m.m24 - m.m12*m.m21*m.m44 + m.m12*m.m41*m.m24 + m.m14*m.m21*m.m42 - m.m14*m.m41*m.m22,
       -m.m11*m.m22*m.m43 + m.m11*m.m42*m.m23 + m.m12*m.m21*m.m43 - m.m12*m.m41*m.m23 - m.m13*m.m21*m.m42 + m.m13*m.m41*m.m22,
       -m.m12*m.m23*m.m34 + m.m12*m.m33*m.m24 + m.m13*m.m22*m.m34 - m.m13*m.m32*m.m24 - m.m14*m.m22*m.m33 + m.m14*m.m32*m.m23,
        m.m11*m.m23*m.m34 - m.m11*m.m33*m.m24 - m.m13*m.m21*m.m34 + m.m13*m.m31*m.m24 + m.m14*m.m21*m.m33 - m.m14*m.m31*m.m23,
       -m.m11*m.m22*m.m34 + m.m11*m.m32*m.m24 + m.m12*m.m21*m.m34 - m.m12*m.m31*m.m24 - m.m14*m.m21*m.m32 + m.m14*m.m31*m.m22,
        m.m11*m.m22*m.m33 - m.m11*m.m32*m.m23 - m.m12*m.m21*m.m33 + m.m12*m.m31*m.m23 + m.m13*m.m21*m.m32 - m.m13*m.m31*m.m22)
       local det = m.m11*inv.m11 + m.m21*inv.m12 + m.m31*inv.m13 + m.m41*inv.m14
       inv.m11 = inv.m11 / det; inv.m21 = inv.m21 / det; inv.m31 = inv.m31 / det; inv.m41 = inv.m41 / det
       inv.m12 = inv.m12 / det; inv.m22 = inv.m22 / det; inv.m32 = inv.m32 / det; inv.m42 = inv.m42 / det
       inv.m13 = inv.m13 / det; inv.m23 = inv.m23 / det; inv.m33 = inv.m33 / det; inv.m43 = inv.m43 / det
       inv.m14 = inv.m14 / det; inv.m24 = inv.m24 / det; inv.m34 = inv.m34 / det; inv.m44 = inv.m44 / det
       return inv
    elseif i == 'gl' then
      return glFloatv(16, m.m11, m.m12, m.m13, m.m14,
                          m.m21, m.m22, m.m23, m.m24,
                          m.m31, m.m32, m.m33, m.m34,
                          m.m41, m.m42, m.m43, m.m44)
    end
    return nil
  end,
  __tostring = function(m)
    return string.format("[%+4.4f %+4.4f %+4.4f %+4.4f ]\n[%+4.4f %+4.4f %+4.4f %+4.4f ]\n[%+4.4f %+4.4f %+4.4f %+4.4f ]\n[%+4.4f %+4.4f %+4.4f %+4.4f ]",
                           m.m11, m.m21, m.m31, m.m41, m.m12, m.m22, m.m32, m.m42, m.m13, m.m23, m.m33, m.m43, m.m14, m.m24, m.m34, m.m44)
    end
})

local function rotate2(r)
  return mat2(cos(r), -sin(r),
              sin(r),  cos(r))
end
local function rotate3x(r)
  return mat3(1,     0,       0,
              0, cos(r), -sin(r),
              0, sin(r),  cos(r))
end
local function rotate3y(r)
  return mat3(cos(r), 0, sin(r),
                   0, 1,      0,
             -sin(r), 0, cos(r))
end
local function rotate3z(r)
  return mat3(cos(r), -sin(r), 0,
              sin(r),  cos(r), 0,
                   0,       0, 1)
end
local function rotate3(rx, ry, rz)
  return rotate3x(rx) * rotate3y(ry) * rotate3z(rz)
end
local function rotate4x(r)
  return mat4(1,     0,        0, 0,
              0, cos(r), -sin(r), 0,
              0, sin(r),  cos(r), 0,
              0,      0,       0, 1)
end
local function rotate4y(r)
  return mat4(cos(r), 0, sin(r), 0,
                   0, 1,      0, 0,
             -sin(r), 0, cos(r), 0,
                   0, 0,      0, 1)
end
local function rotate4z(r)
  return mat4(cos(r), -sin(r), 0, 0,
              sin(r),  cos(r), 0, 0,
                   0,       0, 1, 0,
                   0,       0, 0, 1)
end
local function rotate4(rx, ry, rz)
  return rotate4x(rx) * rotate4y(ry) * rotate4z(rz)
end

function M.rotate_axis(theta, axis)
	local u = axis.normalize
	local xy = u.x * u.y
	local xz = u.x * u.z
	local yz = u.y * u.z
	local c = math.cos(theta)
	local one_c = 1.0 - c
	local s = math.sin(theta)
	
	return mat4(u.x * u.x * one_c + c,
	xy * one_c - u.z * s,
	xz * one_c + u.y * s,
	0,
	xy * one_c + u.z * s, -- row 2
	u.y * u.y * one_c + c,
	yz * one_c - u.x * s,
	0,
	xz * one_c - u.y * s, -- row 3
	yz * one_c + u.x * s,
	u.z * u.z * one_c + c,
	0,
	0, 0, 0, 1) -- row 4
end
M.mat2 = mat2
M.mat3 = mat3
M.mat4 = mat4
M.mat  = mat4
M.rotate2  = rotate2
M.rotate3x = rotate3x
M.rotate3y = rotate3y
M.rotate3z = rotate3z
M.rotate3  = rotate3
M.rotate4x = rotate4x
M.rotate4y = rotate4y
M.rotate4z = rotate4z
M.rotate4  = rotate4
M.rotatex  = rotate4x
M.rotatey  = rotate4y
M.rotatez  = rotate4z
M.rotate   = rotate4
M.identity2 = mat2(1, 0,
                   0, 1)
function M.identity3() return mat3(1, 0, 0,
                   0, 1, 0,
                   0, 0, 1)
end
M.identity4 = mat4(1, 0, 0, 0,
                   0, 1, 0, 0,
                   0, 0, 1, 0,
                   0, 0, 0, 1)
M.identity = M.identity4

function M.translate(x, y, z)
  if ffi.istype(vec2, x) then
    y = x.y
    x = x.x
  elseif ffi.istype(vec3, x) then
    z = x.z
    y = x.y
    x = x.x
  end
  y = y or 0
  z = z or 0
  return mat4(1, 0, 0, x,
              0, 1, 0, y,
              0, 0, 1, z,
              0, 0, 0, 1)
end
function M.scale(x, y, z)
  if ffi.istype(vec2, x) then
    y = x.y
    x = x.x
  elseif ffi.istype(vec3, x) then
    z = x.z
    y = x.y
    x = x.x
  end
  y = y or x
  z = z or x
  return mat4(x, 0, 0, 0,
              0, y, 0, 0,
              0, 0, z, 0,
              0, 0, 0, 1)
end
function M.frustum(l, r, b, t, n, f)
	return mat4(2*n/(r-l),  0,  		(r+l)/(r-l),  0,
                0, 			2*n/(t-b),  (t+b)/(t-b),  0,
                0,         	0, 			-(f+n)/(f-n), -2*n*f/(f-n),
                0,         	0,           -1,           0)
end
function M.ortho(l, r, b, t, n, f)
  return mat4(2/(r-l),       0,        0, -(r+l)/(r-l),
                    0, 2/(t-b),        0, -(t+b)/(t-b),
                    0,       0, -2/(f-n), -(f+n)/(f-n),
                    0,       0,        0,            1)
end
function M.lookAt(eye,center,up)
	local Z = eye - center;
    Z = Z.normalize
    Y = up;
    X = Y:cross( Z );
	Y = Z:cross( X )
	X = X.normalize
	Y = Y.normalize
	return mat4(X.x,X.y,X.z,-(X*eye),
				Y.x,Y.y,Y.z,-(Y*eye),
				Z.x,Z.y,Z.z,-(Z*eye),
				0,0,0,1.0)
end
function M.matToLookAt(MV)
	--frame.X = vec3(MV.m11,MV.m21,MV.m31)
	local Y = vec3(MV.m12,MV.m22,MV.m32)
	local Z = vec3(MV.m13,MV.m23,MV.m33)
	--eye in LookAt
	local eye = MV.mat3.inv * (-vec3(MV.m41, MV.m42, MV.m43))
	return eye,eye-Z,Y
end
function M.gl2mat4(f)
	return mat4(f[0], f[4], f[8],  f[12],
                f[1], f[5], f[9],  f[13],
                f[2], f[6], f[10], f[14],
                f[3], f[7], f[11], f[15])
end
function M.perspective(fovy, aspect, n, f)
   local t = n * math.tan(fovy * math.pi / 360.0)
   local r = t * aspect
   return M.frustum(-r, r, -t, t, n, f)
end

----------------------------------
--Rodriges rotation 3d
--gives matrix rotating A to B
--about axis AxB
function M.rotAB(A,B)
	local a,b = A.normalize, B.normalize
	local v = a:cross(b)
	local sine = v.norm
	local cose = a*b
	if sine == 0 then
		if cose == 1 then
			return M.identity3()
		elseif cose == -1 then
			return M.identity3()*(-1)
		else
			print("cos",cose,"sin",sine)
			error("bad cos")
		end
	end
	--skew-symmetric cross-product matrix of v
	local V = mat3(0, -v.z, v.y,
					v.z, 0, -v.x,
					-v.y,v.x,0)
	local V2 = V*V
	
	return M.identity3() + V + (1/(1+cose))*V2
end

--useful for aligning two reference frames A,C -> B,D
function M.rotABCD(A,B,C,D)
	local r1 = M.rotAB(A,B)
	local r2 = M.rotAB(r1*C,D)
	return r2*r1
end

function M.sin2d(a,b)
	a = a.normalize
	b = b.normalize
	return a.x*b.y-a.y*b.x
end
function M.vec2vao(t,n)
	--print("vec2vao",t,n,t[1])
	n = n or (ffi.istype(vec3,t[1]) and 3) or (ffi.istype(vec2,t[1]) and 2) 
	or error("vec2vao wants vec2 or vec3 but is receiving "..tostring(ffi.typeof(t[1])))

	local lp = ffi.new("float[?]",#t*n)
	if n == 3 then
		for i=0,#t-1 do
			local v = t[i+1]
			lp[i*3],lp[i*3+1],lp[i*3+2] = v.x,v.y,v.z
		end
	elseif n==2 then
		for i=0,#t-1 do
			local v = t[i+1]
			assert(v,"i+1:"..tostring(i+1))
			lp[i*2],lp[i*2+1] = v.x,v.y
		end
	end
	return lp
end

function M.vao2vec(arr,size,n)
	assert(size%n==0)
	local vecs = {}
	if n==3 then
		for i=0,size-1,3 do
			vecs[#vecs+1] = vec3(arr[i],arr[i+1],arr[i+2])
		end
	elseif n==2 then
		for i=0,size-1,2 do
			vecs[#vecs+1] = vec2(arr[i],arr[i+1])
		end
	elseif n==1 then
		for i=0,size-1 do
			vecs[#vecs+1] = arr[i]
		end
	else
		error("n should be 1 or 2 or 3")
	end
	return vecs
end
--aa = mat4()
--print(aa.t.gl, type(aa.t.gl))
--[[
eye = vec3(1,2,3)
MV = M.lookAt(eye,vec3(0,0,0),vec3(0,1,0))
MVinv =MV.inv
print(MVinv*vec4(0,0,0,1))
--]]
--[[
aa = vec2(1,2)
bb = vec2(3,4)
cc = aa*aa
aa = vec3(2,2,2)
print(aa,aa.norm)
aa1 = vec2(3,2)
print(aa1,aa1.norm)
bb = aa.normalize
cc = aa + math.sqrt(12)*bb
print(aa,bb,cc)
--]]

--mmgl = mat4(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16).gl
--print(mmgl,ffi.istype("float[16]",mmgl))

--print(vec3(vec2(1,2)),vec3(1,2,3))
--print(vec4(1,2,3,4),vec4(vec3(1,2,3),4))
			
return M
