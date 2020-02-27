local CG = require"anima.CG3.base"


local function Pset(t)
	local pset = {}
	local data = {}
	local typ
	local vec2 = mat.vec2
	local vec3 = mat.vec3
	local typevec2 = ffi.typeof(vec2)
	local typevec3 = ffi.typeof(vec3)
	
	function pset:add_one(pt)
		if not typ then typ = ffi.typeof(pt) end
		--assert(typ == ffi.typeof(pt),typ)
		if typ == typevec2 then
			data[pt.x] = data[pt.x] or {}
			data[pt.x][pt.y] = pt
		elseif typ == typevec3 then
			data[pt.x] = data[pt.x] or {}
			data[pt.x][pt.y] = data[pt.x][pt.y] or {}
			data[pt.x][pt.y][pt.z] = pt
		else
			error("added element to point set is not point")
		end
	end
	
	function pset:add(pt)
		if type(pt)=="table" then
			for i,v in ipairs(pt) do
				self:add_one(v)
			end
		else
			self:add_one(pt)
		end
	end
	function pset:remove_one(pt)
		if typ == typevec2 then
			if not data[pt.x] then return end
			data[pt.x][pt.y] = nil
			if not next(data[pt.x]) then data[pt.x] = nil end
		elseif typ == typevec3 then
			if not data[pt.x] then return end
			if not data[pt.x][pt.y] then return end
			data[pt.x][pt.y][pt.z] = nil
			if not next(data[pt.x][pt.y]) then data[pt.x][pt.y] = nil end
			if not next(data[pt.x]) then data[pt.x] = nil end
		end
	end
	function pset:remove(pt)
		if type(pt)=="table" then
			for i,v in ipairs(pt) do
				self:remove_one(v)
			end
		else
			self:remove_one(pt)
		end
	end
	function pset:has(pt)
		if not data[pt.x] then return false end
		if not data[pt.x][pt.y] then return false end
		if typ == typevec3 and not data[pt.x][pt.y][pt.z] then return false end
		return true
	end
	
	--not finished for vec3
	function pset:allpoints()
		local i1,i2,v1,v2
		return function()
			if i1 and not i2 then error"bad data" end
			if not i1 and i2 then error"bad data" end
			if i1 and i2 then
				--we have i1 and i2
				i2,v2 = next(v1,i2)
				if i2 then return v2 end --vec2(i1,i2) end
			end
	
			i1,v1 = next(data,i1)
			if not i1 then return nil end
			i2,v2 = next(v1,i2)
			if i2 then return v2 else error"bad data" end

		end
	end
	
	if t then pset:add(t) end
	return pset
end

CG.Pset = Pset

--better than Pset for iteration, worse for add, remove
local function Pset2(t)
	local pset = {}
	local data = {}
	local typ
	local vec2 = mat.vec2
	local vec3 = mat.vec3
	local typevec2 = ffi.typeof(vec2)
	local typevec3 = ffi.typeof(vec3)
	
	function pset:add_one(pt)
		if not typ then typ = ffi.typeof(pt) end
		--assert(typ == ffi.typeof(pt),typ)
		data[tostring(pt)] = pt
	end
	
	function pset:add(pt)
		if type(pt)=="table" then
			for i,v in ipairs(pt) do
				self:add_one(v)
			end
		else
			self:add_one(pt)
		end
	end
	function pset:remove_one(pt)
		data[tostring(pt)] = nil
	end
	function pset:remove(pt)
		if type(pt)=="table" then
			for i,v in ipairs(pt) do
				self:remove_one(v)
			end
		else
			self:remove_one(pt)
		end
	end
	function pset:has(pt)
		if not data[tostring(pt)] then return false end
		return true
	end
	
	function pset:allpoints()
		local k,v
		return function()
			k,v = next(data,k)
			return v
		end
		-- return next,data,nil
	end
	
	if t then pset:add(t) end
	return pset
end

CG.Pset2 = Pset2