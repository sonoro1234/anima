-- several utility functions
function LogFile(str,filename)
	filename = filename or "logsc.txt"
	file = io.open(lua2scpath..filename,"w+")
	if file then
		file:write(str)
		file:close()
	end
end

function clip(val,mini,maxi)
    return math.max(mini,math.min(val,maxi))
end
--values must be unique
function swap_keyvalue(t)
	local res={}
	for k,v in pairs(t) do
		if res[v] then
			if type(res[v])=="table" then
				table.insert(res[v],k)
			else
				res[v] = {res[v],k}
			end
		else
			res[v]=k
		end
	end
	return res
end
function debuglocals(prtables)
	print"debuglocals"
	local prtables = prtables or false
	print"\n"
	for level = 2, math.huge do
		local info = debug.getinfo(level, "Sln")
		if not info then break end
		if info.what == "C" then -- is a C function?
			print(level, "C function")
		else -- a Lua function
			print(string.format("\nfunction %s[%s]:%d",tostring(info.name), info.short_src,info.currentline))
		end
		local a = 1
		while true do
			local name, value = debug.getlocal(level, a)
			if not name then break end
			print("local variable:",name, value)
			if type(value)=="table" and prtables then dumpObj(value) end
			a = a + 1
		end
	end
	print("end debug print")
end
--returns items ordered by key
function pairsByKeys(t, f)
	local a = {}
	for n in pairs(t) do a[#a + 1] = n end
	table.sort(a, f)
	local i = 0 -- iterator variable
	return function () -- iterator function
		i = i + 1
		return a[i], t[a[i]]
	end
end
--values must be unique
function pairsByValues(t, f)
	local a = {}
	local b = {}
	for k,v in pairs(t) do 
		assert(a[v]==nil)
		a[v] = k ; 
		b[#b + 1] = v 
	end
	table.sort(b, f)
	local i = 0 -- iterator variable
	return function () -- iterator function
		i = i + 1
		return a[b[i]],b[i] 
	end
end

function mergeTable(a,b)
	for k,v in pairs(b) do
			a[k]=v
	end
	return a
end
--swaps row and files 2d (transpose matrix)
function flop(t)
	local res={}
	local files=#t
	local rows=#t[1]
	for i=1,rows  do
		res[i]={}
		for j=1,files do
			res[i][j]=t[j][i]
		end
	end
	return res
end
function flatten(t,lev)
	lev = lev or 1
	if type(t)~="table" then return t end
	if lev < 1 then return t end
	lev = lev - 1
	local res = {}
	for i,v in ipairs(t) do
		--res[#res+1]=flatten(v,lev)
		res=concatTables(res,flatten(v,lev))
	end
	return res
end
--returns a table n elements from n evals of func (function or value)
function TableFill(n,func)
	local res={}
	for i=1,n do
		if type(func)=="function" then
			res[i]=func(i)
		else
			res[i]=func
		end
	end
	return res
end
function isSimpleTable(t)
	return (type(t)=="table" and getmetatable(t)==nil)
end

function functabla(t,f)
	if not isSimpleTable(t) then return f(t) end
	local res={}
	for i,v in ipairs(t) do
			res[i]= f(v)
	end 
	return res
end
function seriesFill(n,init,step)
	init = init or 1; step = step or 1
	return TableFill(n,function(i) return init +(i-1)*step end) 
end
function len(t)
	if type(t)=="table" then return #t else return 1 end
end
function WrapAt(t,i)
	if type(t)=="table" then
		i=i%#t
		i= (i~=0) and i or #t
		return t[i]
	else
		return t
	end
end
function WrapAtSimple(t,i)
	if isSimpleTable(t) then
		i=i%#t
		i= (i~=0) and i or #t
		return t[i]
	else
		return t
	end
end

function deepcopy(object)
    local lookup_table = {}
    local function _copy(object)
		--assert(object~=REST)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end
--only valuess are deepcopied not keys
function deepcopy_values(object)
    local lookup_table = {}
    local function _copy(object)
		--assert(object~=REST)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[index] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

-- not recursive working use deepcopy
function copyiTable(a)
	--assert(a~=REST)
	local res ={}
	for k,v in ipairs(a) do
		if type(v) == "table" then
			res[k] = copyiTable(v)
		else
			res[k]=v
		end
	end
	return res
end

--accepts several tables or items
function concatTables(...)
	local res={}
	for i=1, select('#', ...) do
		local t = select(i, ...)
		if type(t)=="table" then
			assert(t~=REST)
			for _,v in ipairs(t) do
				table.insert(res,v)
			end
		else
			table.insert(res,t)
		end
	end
	return res
end
function concat2Tables(a,b)
	assert(b~=REST)
	for i,v in ipairs(b) do
		table.insert(a,v)
	end
	return a
end
-- all items not just numbered sequential
function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function prOSC(t)
	local strT = {}
	local function _prOSC(t)
		if type(t)=="table" then
			strT[#strT+1]="["
			for i=1,#t-1 do
				_prOSC(t[i])
				strT[#strT+1]=","
			end
			_prOSC(t[#t])
			strT[#strT+1]="]"
		else
			strT[#strT+1]=tostring(t)
		end
	end
	_prOSC(t)
	return table.concat(strT)
end
-- not good for cycles
function tb2st(t)
	local function _tb2st(t)
		if type(t)=="table" then
			local str2="["
			local comma = false
			for k,v in pairs(t) do
				if comma then str2=str2.."," else comma = true end
				str2=str2..tostring(k)..":".._tb2st(v)
			end
			str2=str2.."]"
			return str2
		else
			return tostring(t)
		end
	end
	return(_tb2st(t))
end
-- very readable but not suited for cyclic tables
function tb2st_serialize(t)
	local function serialize_key(val)
		if type(val)=="number" then
			return "["..tostring(k).."]="
		else
			return tostring(val) .."="
		end
	end
	local function _tb2st(t)
		if type(t)=="table" then
			local str2="{"
			for k,v in pairs(t) do
				if type(v)=="number" then
					str2=str2 .. serialize_key(k) .. string.format("%0.17g",v) ..","
				else
					str2=str2 .. serialize_key(k) .. _tb2st(v) ..","
				end
			end
			str2=str2.."}"
			return str2
		else
			return tostring(t)
		end
	end
	return(_tb2st(t))
end
function tb2stSerialize(t)
	local function _tb2st(t)
		if type(t)=="table" then
			local str2="{"
			for k,v in pairs(t) do
				local Kstring = basicSerialize(k)
				if type(v)=="number" then
					str2=str2.."["..Kstring.."]="..string.format("%0.17g",v)..","
				else
					str2=str2.."["..Kstring.."]=".._tb2st(v)..","
				end
			end
			str2=str2.."}"
			return str2
		else
			return tostring(t)
		end
	end
	return(_tb2st(t))
end
--ok with cycles
function ToStr(t,dometatables)
	local strTG = {}
	--local basicToStr= basicSerialize --tostring
	if type(t) ~="table" then  return basicToStr(t) end
	local recG = 0
	local nameG="SELF"..recG
	local ancest ={}
	local function _ToStr(t,strT,rec,name)
		if ancest[t] then
			strT[#strT + 1]=ancest[t]
			return
		end
		rec = rec + 1
		ancest[t]=name
		strT[#strT + 1]='{'
		local count=0
		-------------
		--if t.name then strT[#strT + 1]=string.rep("\t",rec).."name:"..tostring(t.name) end
		----------------
		for k,v in pairs(t) do
			count=count+1
			strT[#strT + 1]="\n"
			local kstr
			if type(k) == "table" then
				local name2=string.format("%s.KEY%d",name,count)
				strT[#strT + 1]=string.rep("\t",rec).."["
				local strTK = {}
				_ToStr(k,strTK,rec,name2)
				kstr=table.concat(strTK)
				strT[#strT + 1]=kstr.."]="
			else
				kstr = basicToStr(k)
				strT[#strT + 1]=string.rep("\t",rec).."["..kstr.."]="
			end
			
			if type(v) == "table" then
					local name2=string.format("%s[%s]",name,kstr)
					_ToStr(v,strT,rec,name2)
			else
				strT[#strT + 1]=basicToStr(v)
			end
		end
		if dometatables then
			local mt = getmetatable(t)
			if mt then
				local namemt = string.format("%s.METATABLE",name)
				local strMT = {}
				_ToStr(mt,strMT,rec,namemt)
				local metastr=table.concat(strMT)
				strT[#strT + 1] = "\n"..string.rep("\t",rec).."[METATABLE]="..metastr
			end
		end
		strT[#strT + 1]='}'
		rec = rec - 1
		return
	end
	_ToStr(t,strTG,recG,nameG)
	return table.concat(strTG)
end
function prtable(...)
	for i=1, select('#', ...) do
		local t = select(i, ...)
		print(ToStr(t))
		print("\n")
	end
end

function dumpObj(o)
	local function ToStr(t)
		local strTG = {}
		local basicToStr=tostring
		if type(t) ~="table" then  return basicToStr(t) end
		local recG = -1
		local nameG="SELF"
		local ancest ={}
		local function _ToStr(t,strT,rec,name)
			if ancest[t] then
				strT[#strT + 1]=ancest[t]
				return
			end
			rec = rec + 1
			ancest[t]=name
			strT[#strT + 1]='{'
			local count=0
			for k,v in pairs(t) do
				count=count+1
				strT[#strT + 1]="\n"
				local kstr
				if type(k) == "table" then
					local name2=string.format("%s.KEY%d",name,count)
					strT[#strT + 1]=string.rep("\t",rec).."["
					local strTK = {}
					_ToStr(k,strTK,rec,name2)
					kstr=table.concat(strTK)
					strT[#strT + 1]=kstr.."]:"
				else
					kstr = basicToStr(k)
					strT[#strT + 1]=string.rep("\t",rec).."["..kstr.."]:"
				end
				
				if type(v) == "table" then
						local name2=string.format("%s[%s]",name,kstr)
						_ToStr(v,strT,rec,name2)
				else
					strT[#strT + 1]=basicToStr(v)
				end
			end
			strT[#strT + 1]='}'
			local met = getmetatable(t)
			if met then
				local name2=string.format("%s.META",name)
				strT[#strT + 1]="\n"..string.rep("\t",rec).."METATABLE:"
				local strTM = {}
				_ToStr(met,strTM,rec,name2)
				local metastr=table.concat(strTM)
				strT[#strT + 1]=metastr
			end
			rec = rec - 1
			return
		end
		_ToStr(t,strTG,recG,nameG)
		return table.concat(strTG)
	end
	print(ToStr(o))
	print("\n")
end

function tbl_compare(t1,t2)
    local lookup_table = {}
    local function _comp(t1,t2)
        if type(t1) ~= "table" then
            return t1 == t2
        elseif lookup_table[t1] then
            return lookup_table[t1]
        end
		local eq = true
        for index, value in pairs(t1) do
			if not _comp(t2[index] , value) then
				eq = false
				break
			end
        end
		lookup_table[t1] = eq
        return eq
    end
    if not _comp(t1,t2) then return false end
	lookup_table = {}
	return _comp(t2,t1)
end

local function cdataSerialize(cd)
	if ffi.istype("float[1]", cd) then
		return table.concat{[[ffi.new('float[1]',]],cd[0],[[)]]}
	elseif ffi.istype("int[1]", cd) then
		return table.concat{[[ffi.new('int[1]',]],cd[0],[[)]]}
	elseif ffi.istype("float[]",cd) then
		local size = ffi.sizeof(cd)/ffi.sizeof"float"
		local tab = {[[ffi.new("float[?]",]],size}
		for i=0,size-1 do tab[#tab+1] = ",";tab[#tab+1] = cd[i] end
		tab[#tab+1] = [[)]]
		return table.concat(tab)
	else
		print(cd,"not serialized")
	end
end

function basicSerialize (o)
    if type(o) == "number" then
		return string.format("%.17g", o)
	elseif type(o)=="boolean" then
        return tostring(o)
    elseif type(o) == "string" then
        return string.format("%q", o)
	elseif pcall(function() return o.__serialize end) then
		return o.__serialize(o)
	elseif type(o)=="cdata" then
		return cdataSerialize(o)
	else
		return tostring(o) --"nil"
    end
end

function basicToStr (o)
    if type(o) == "number" then
		return string.format("%.17g", o)
	elseif type(o)=="boolean" then
        return tostring(o)
    elseif type(o) == "string" then
        return string.format("%q", o)
	elseif ffi.istype("float[]",o) then
		local size = ffi.sizeof(o)/ffi.sizeof"float"
		local tab = {[[float[]<]],o[0]}
		for i=1,size-1 do tab[#tab+1] = ",";tab[#tab+1] = o[i] end
		tab[#tab+1] = [[>]]
		return table.concat(tab)
	elseif ffi.istype("float[1]",o) then
		return table.concat{[=[float[1]<]=],o[0],">"}
	elseif ffi.istype("int[1]",o) then
		return table.concat{[=[int[1]<]=],o[0],">"}
	else
		return tostring(o) --"nil"
    end
end


function serializeTable(name, value, saved)
	
	local string_table = {}
	if not saved then 
		table.insert(string_table, "local "..name.." = ") 
	else
		table.insert(string_table, name.." = ") 
	end
	
	saved = saved or {}       -- initial value
	
	--if type(value) == "number" or type(value) == "string" or type(value)=="boolean" then
	if type(value)~= "table" then
		table.insert(string_table,basicSerialize(value).."\n")
	elseif type(value) == "table" then
		if saved[value] then    -- value already saved?
			table.insert(string_table,saved[value].."\n")          
		else
			saved[value] = name   -- save name for next time
			table.insert(string_table, "{}\n")          
			for k,v in pairs(value) do      -- save its fields
				local fieldname = string.format("%s[%s]", name,basicSerialize(k))
				table.insert(string_table, serializeTable(fieldname, v, saved))
			end
		end
	else --cant save value so delete key
		string_table[#string_table] = nil
		--error("cannot save a " .. type(value))
	end
	
	return table.concat(string_table)
end
-- use as serializeTableF(table) to get "return string"
-- could be optimized passing string_table as argument
function serializeTableF(value,name,saved)
	
	local first = not (saved and true or false)
	name = first and "SELFT" or name
	saved = saved or {}       -- initial value
	local string_table = {}

	table.insert(string_table, name.." = ")
	
	--if type(value) == "number" or type(value) == "string" or type(value)=="boolean" then
	if type(value)~= "table" then
		table.insert(string_table,basicSerialize(value).."\n")
	elseif type(value) == "table" then
		if saved[value] then    -- value already saved?
			table.insert(string_table,saved[value].."\n")          
		else
			saved[value] = name   -- save name for next time
			table.insert(string_table, "{}\n")          
			for k,v in pairs(value) do      -- save its fields
				local fieldname = string.format("%s[%s]", name, basicSerialize(k))
				table.insert(string_table, serializeTableF(v,fieldname, saved))
			end
		end
	--else
		--error("cannot save a " .. type(value))
	end
	if first then
		table.insert(string_table, "return " .. name)
	end
	return table.concat(string_table)
end
function stsplit(str, pat)
	local t = {} 
	local fpat = "(.-)" .. pat
	local last_end = 1
	local s, e, cap = str:find(fpat, 1)
	while s do
		table.insert(t,cap)
		last_end = e+1
		s, e, cap = str:find(fpat, last_end)
	end
	if last_end <= #str then
		cap = str:sub(last_end)
		table.insert(t, cap)
	elseif str:sub(-1)==pat then
		table.insert(t, "")
	end
	return t
end
local lfs = require"lfs"
local is_windows = package.config:sub(1,1) == '\\'
local sep = is_windows and '\\' or '/'

function funcdir(path,func,pat,...)
	assert(lfs.attributes(path),path)
    for file in lfs.dir(path) do
		local match = not pat or (pat and file:match(".+%."..pat.."$"))
        if file ~= "." and file ~= ".." and match then
            local f = path..sep..file
            --print ("\t "..f)
            local attr = lfs.attributes (f)
            assert (type(attr) == "table")
            if attr.mode == "directory" then
                --attrdir (f)
            else
				func(f,...)
            end
        end
    end
end
function funcdirr(path, func, pat, recur, funcd, tree)
	--pat = pat or "" -- ".-"
	--if #pat > 0 then pat = "%." .. pat end
	tree = tree or ""
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path..sep..file
           -- print ("\t "..f,pat)
            local attr = lfs.attributes (f)
            assert (type(attr) == "table")
            if attr.mode == "directory" and recur then
				if funcd then funcd(f,file,attr,tree) end
                funcdirr(f, func,pat,recur,funcd,tree..sep..file)
            elseif (not pat) or file:match(".+%."..pat.."$") then
				func(f, file, attr, tree)
            end
        end
    end
end

function GlobalsChecker()
	local Gc = {}
	local Gkeys,Gsize,Gkeys2,Gsize2
	function Gc:Get()
		Gsize = tablelength(_G)
		print("Gsize",Gsize)
		Gkeys = {}
		for k,v in pairs(_G) do Gkeys[k]=true end
		return self
	end
	function Gc:compare()
		Gsize2 = tablelength(_G)
		print("Gsize2",Gsize2)
		if Gsize ~= Gsize2 then 
			print("more globals",Gsize2 - Gsize)
			Gkeys2 = {}
			for k,v in pairs(_G) do Gkeys2[k]=true end
			for k,v in pairs(Gkeys2) do
				if not Gkeys[k] then print(k) end
			end
			print"---------------"
		end
		return self
	end
	return Gc
end

function ProfileStart(prstr,filename)
	require("jit.p").start(prstr or "3vfsi4m1", filename or 'profReport.txt')
end
function ProfileStop()
	require("jit.p").stop()
end

function table_continue(T,...)
	for j=1,select('#',...) do
		local t = select(j,...)
		T[#T+1]=t 
	end
end