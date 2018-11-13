--- class for table arithmetic and indexing
--by Victor Bombi
local function len(t)
	return type(t)=="table" and #t or 1 
end
local function WrapAt(t,i)
	if isSimpleTable(t) then -- type(t)=="table" then
		i=i%#t
		i= (i~=0) and i or #t
		return t[i]
	else
		return t
	end
end
--counts from 1 to tlen insted of %
--which counts from 0 to tlen-1
local function mod1(i,tlen)
	i = i % tlen
	return (i~=0) and i or tlen
end
local function mulTables(a,b)
	local res={}
	local maxlen=math.max(len(a),len(b))
	for i=1,maxlen do
		res[i]=WrapAt(a,i)*WrapAt(b,i)
	end
	return res
end
local function divTables(a,b)
	local res={}
	local maxlen=math.max(len(a),len(b))
	for i=1,maxlen do
		res[i]=WrapAt(a,i)/WrapAt(b,i)
	end
	return res
end
local function powTables(a,b)
	local res={}
	local maxlen=math.max(len(a),len(b))
	for i=1,maxlen do
		res[i]=WrapAt(a,i)^WrapAt(b,i)
	end
	return res
end
local function addTables(a,b)
	local res={}
	local maxlen=math.max(len(a),len(b))
	for i=1,maxlen do
		--if not pcall(function() 
			res[i]=WrapAt(a,i)+WrapAt(b,i) 
		--	end) then debuglocals(true);error() end
	end
	return res
end
--accepts several tables or items
local function concatTables(...)
	local res={}
	for i=1, select('#', ...) do
		local t = select(i, ...)
		if type(t)=="table" then
			for _,v in ipairs(t) do
				table.insert(res,v)
			end
		else
			table.insert(res,t)
		end
	end
	return res
end

local _TAmt = {}
--- Takes a integer indexed table and gives it metatable _TAmt
local function TA(t)
	t = t or {}
	assert(getmetatable(t)==nil or getmetatable(t)==_TAmt,"TA table already has metatable.")
	setmetatable(t,_TAmt)
	return t
end
function _TAmt:new(o)
	o = o or {}
	setmetatable(o, _TAmt)
	return o
end
function _TAmt.__add(a,b)
	return TA(addTables(a,b))
end
function _TAmt.__sub(a,b)
	return a + (-b)
end
function _TAmt.__unm(a)
	return -1 * a
end
function _TAmt.__mul(a,b)
	return TA(mulTables(a,b))
end
function _TAmt.__div(a,b)
	return TA(divTables(a,b))
end
function _TAmt.__pow(a,b)
	return TA(powTables(a,b))
end
_TAmt.__index = _TAmt

--- Fills n slots with func
-- @tparam int number of slots
-- @tparam ?function|any func receives index and returns value or if it is other type is asigned to every slot
-- @treturn TA
function _TAmt:Fill(n,func)
	func = func or 1
	for i=1,n do
		if type(func)=="function" then
			self[i]=func(i)
		else
			self[i]=func
		end
	end
	-- delete possible old values
	self[n+1]=nil
	return self
end
function _TAmt:series(n,init,step)
	init = init or 1;step = step or 1
	return self:Fill(n,function(i) return init +(i-1)*step end) 
end
function _TAmt:range(ini,endp)
	return self:series(endp-ini+1,ini,1)
end
function _TAmt:gseries(n,init,step)
	init = init or 1;step = step or 1
	return self:Fill(n,function(i) return init * step^(i-1) end) 
end
function _TAmt:sort(f)
	local res = {}
	for i,v in ipairs(self) do
		res[i]= v
	end
	table.sort(res,f)
	return self:new(res)
end
function _TAmt.__call(t,ini,ends,step)
	step = step or 1;ends = ((ends and ends < 0) and (#t+ends+1)) or ends or ini
	local res = {}
	for i=ini,ends,step do
		res[#res + 1]= t[i] or 0
	end 
	return t:new(res) --self:new(res)
end
function _TAmt:Do(f,...)
	local res={}
	for i,v in ipairs(self) do
		res[i]= f(v,...)
	end 
	return self:new(res)
end
function _TAmt:Doi(f,...)
	local res={}
	for i,v in ipairs(self) do
		res[i]= f(v,i,...)
	end 
	return self:new(res)
end
function _TAmt:reduce(f,memo,...)
	for i,v in ipairs(self) do
		memo= f(memo,v,i,...)
	end 
	return memo
end
function _TAmt:sum()
	return self:reduce(function(ac,v) return ac + v end,0)
end
function _TAmt:multiply()
	return self:reduce(function(ac,v) return ac * v end,1)
end
function _TAmt.__concat(a,b)
	return TA(concatTables(a,b))
end
function _TAmt.__tostring(a)
	local str = "{"..tostring(a[1])
	for i=2,#a do
		str = str..", "..tostring(a[i])
	end
	return str.."}"
end
function _TAmt:squared()
	local res={}
	for i,v in ipairs(self) do
		res[i]= v * v
	end 
	return self:new(res)
end
function _TAmt:reverse()
	local res={}
	for i,v in ipairs(self) do
		res[#self - i + 1]= v
	end 
	return self:new(res)
end
function _TAmt:mirror()
	return self..self(1,#self - 1):reverse()
end
function _TAmt:mirror2()
	return self..self:reverse()
end
function _TAmt:clump2(n)
	local res = {}
	for i,v in ipairs(self) do
		local i2 = 1 + math.floor((i-1)/n)
		res[i2] = res[i2] or self:new{}
		res[i2][#res[i2] + 1] = v
	end
	return self:new(res)
end
function _TAmt:clump(size)
	local n = n or 1
	local res = {}
	res[#res + 1] = self:new{}
	for i,v in ipairs(self) do
		if #res[#res] >= size then
			res[#res + 1] = self:new{}
		end
		res[#res][#res[#res] + 1] = v
	end
	return self:new(res)
end
function _TAmt:asSimpleTable()
	local res = {}
	for i,v in ipairs(self) do
		res[i] = v
	end
	return res
end
function _TAmt:rotate(delta)
	local res = {}
	for i,v in ipairs(self) do
		res[mod1(i + delta,#self)] = v
	end
	return self:new(res)
end
function _TAmt:grow(t)
	local lastpos = #self
	for i=1,#t do
		self[lastpos + i] = t[i]
	end
	return self
end
--[[
print(TA():range(10,15)..TA():range(26,30))
--]]


return TA
--[[
for k,v in pairs(_G) do print(k,v) end
--]]
--[[
ss=TA():series(12)
print(ss)
ss = ss:clump(4)
ss = ss:clump(4)
print(ss)
aa=ss:Doi(function(v,i) return #v end)
print(aa)
bb=TA{1}
print(bb:sum())
print(TA{nil,1,2})
--]]
--[[
ss=TA():series(15)
print(ss)
ss = ss:clump(4)
print(ss)
ss=TA():series(8)
ss:Do(print)
suma=ss:reduce(function(ac,v) return v + ac end,0)
print(suma)
local ac = 0
suma2=ss:Do(function(v,ac) ac=ac or 0;ac = v + ac; print("ac",ac);return ac end,ac)
suma2:Do(print)

mat = TA():Fill(5,function(i) return TA():series(5,i,i) end)
mat:Do(print)
print(tostring(mat))
print(mat)
suma=mat:reduce(function(ac,v) return v + ac end,0)
print(suma)
mat2 = mat * 10
print(mat2)
print(mat2 * mat)
--]]
--[[
aa = TA():series(7,1,1)
bb = aa:rotate(2)
cc=(bb(1,2) - 7 .. bb(3,#bb))
print("zzz",cc,"zzz")
--]]