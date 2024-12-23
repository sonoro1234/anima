local ffi = require "ffi"
local reflect = require "reflect"

local function tb2st(t)
    if type(t)~= "table" then
        return tostring(t)
    else
        local str = {"{"}
        for i,v in ipairs(t) do
            table.insert(str,tb2st(v))
            table.insert(str, ",")
        end
        if #str > 1 then table.remove(str) end
        table.insert(str, "}")
        return table.concat(str)
    end
end

local function valor(base,ind,name)
    --print("valor",tb2st(ind),name)
    local field = base
    for i,vv in ipairs(ind) do field = field[vv] end
    field = field[name]
    return field
end
local function valorarray(base,ind,name,nels)
    local field = valor(base,ind,name)
    local t = {}
    for i=0,nels-1 do t[i+1] = field[i] end
    return t
end
local function mergetab(t,t2,ti,ti2)
    if ti2.what == "union" then
        t2 = ti.transparent and t2[1] or {t2[1]}
        table.insert(t,t2)
    else --struct
        if ti.transparent then
            for i,v in ipairs(t2) do table.insert(t,v) end
        else
            table.insert(t,t2)
        end
    end
end
local function cd2tab(cd,ct,ind,nelems)
  local t = {}
  ind = ind or {}
  for ti in ct:members() do
    if ti.what == "struct" or ti.what == "union" then
        if not ti.transparent then table.insert(ind,ti.name) end
        local t2 = cd2tab(cd,ti,ind,nelems)
        if not ti.transparent then table.remove(ind) end
        mergetab(t,t2,ti,ti)
    else
        assert(ti.what == "field")
        if ti.type.what == "struct" or ti.type.what == "union" then
            if not ti.transparent then table.insert(ind,ti.name) end
            local t2 = cd2tab(cd,ti.type,ind,nelems)
            if not ti.transparent then table.remove(ind) end
            mergetab(t,t2,ti,ti.type)
        elseif ti.type.what == "array" then
            local nels = ti.type.vla and nelems or (ti.type.size/ti.type.element_type.size)
            local t2 = valorarray(cd,ind,ti.name,nels)
            table.insert(t,t2)
        else
            table.insert(t,valor(cd,ind,ti.name))
        end
    end
  end
  return ct.what=="union" and {t[1]} or t
end

local function valorarray1(cd,nels,ti)
    local tk = ti.element_type.what
    local t = {}
    for i=0,nels-1 do
        local val = cd[i]
        if tk == "struct" or tk == "union" then 
            val = cd2tab(cd[i],ti.element_type,{})
        end
        t[i+1] = val 
    end
    return t
end
local function genstr(tystr,vals,nelem)
    if nelem then
        return table.concat{"ffi.new(\"",tystr,"\",",nelem,",",tb2st(vals),")"}
    else
        return table.concat{"ffi.new(\"",tystr,"\",",tb2st(vals),")"}
    end
end
local function cdataser(cd)
    local ty = ffi.typeof(cd)
    local len = ffi.sizeof(cd)
    local s0 = ffi.sizeof(ty,0)
    local s1 = ffi.sizeof(ty,1)
    local tystr = tostring(ty):sub(7, -2)
    local is_vla, nelem
    if s0 ~= s1 then
        is_vla = true
        local el_size = s1 - s0
        nelem = (len - s0)/el_size
    end
    local ti = reflect.typeof(ty)
    if ti.what == "struct" or ti.what == "union" then
        local t = cd2tab(cd,ti,{},nelem)
        return genstr(tystr,t,nelem)
    elseif ti.what == "array" then
        assert(ti.vla == is_vla)
        local nels = is_vla and nelem or ti.size/ti.element_type.size
        local vals = valorarray1(cd,nels,ti)
        return genstr(tystr,vals,nelem)
    else
        return genstr(tystr,tonumber(cd))
    end
end

return cdataser