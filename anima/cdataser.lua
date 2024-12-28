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

local cd2tab
local function valorarray1(cd,nels,ti)
    local tk = ti.element_type.what
    local t = {}
    for i=0,nels-1 do
        local val = cd[i]
        if tk == "struct" or tk == "union" then 
            val = cd2tab(cd[i],ti.element_type,{})
        elseif tk == "array" then
            local nels2 = ti.element_type.size/ti.element_type.element_type.size
            val = valorarray1(val,nels2,ti.element_type)
        end
        t[i+1] = val 
    end
    return t
end
local function valorarray(base,ind,name,nels,ti) 
    local field = valor(base,ind,name)
    return valorarray1(field,nels,ti)
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
cd2tab = function(cd,ct,ind,nelems)
  local t = {}
  ind = ind or {}
  for ti in ct:members() do
    if ti.what == "struct" or ti.what == "union" then
        if not ti.transparent then table.insert(ind,ti.name) end
        local t2 = cd2tab(cd,ti,ind,nelems)
        if not ti.transparent then table.remove(ind) end
        mergetab(t,t2,ti,ti)
    else
       --assert(ti.what == "field" or bitfield)
        if ti.type.what == "struct" or ti.type.what == "union" then
            if not ti.transparent then table.insert(ind,ti.name) end
            local t2 = cd2tab(cd,ti.type,ind,nelems)
            if not ti.transparent then table.remove(ind) end
            mergetab(t,t2,ti,ti.type)
        elseif ti.type.what == "array" then
            local nels = ti.type.vla and nelems or (ti.type.size/ti.type.element_type.size)
            local t2 = valorarray(cd,ind,ti.name,nels,ti.type)
            table.insert(t,t2)
        else
            table.insert(t,valor(cd,ind,ti.name))
        end
    end
  end
  return ct.what=="union" and {t[1]} or t
end


local function genstr(tystr,vals,nelem)
    if nelem then
        return table.concat{"ffi.new(\"",tystr,"\",",nelem,",",tb2st(vals),")"}
    else
        return table.concat{"ffi.new(\"",tystr,"\",",tb2st(vals),")"}
    end
end

local CTs = {[0] =
"int","struct","ptr","array","void","enum","func","typedef","attrib","field","bitfield","constant","extern","kw"}
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
    if ti.what == "ref" then
        ti = ti.element_type
        tystr = tystr:gsub("%(*&%)*","")
    elseif ti.what == "ptr" then
        ti = ti.element_type
        cd = cd[0]
        return cdataser(cd)
    end
    if ti.what == "struct" or ti.what == "union" then
        --anonymous struct find typedef
        if not ti.name then
            print("searching typedef for",tystr)
            local name
            for i = 1, math.huge do
                local t = ffi.typeinfo(i)
                if t == nil then
                    break
                end
                --local rti = reflect.refct_from_id(i)
                --if rti.what == "typedef" and rti.element_type.typeid == ti.typeid then
                t.what = CTs[bit.rshift(t.info, 28)]
                if t.what == "typedef" and ti.typeid == bit.band(t.info, 0xffff) then
                    name = t.name
                    break
                end
            end
            assert(name,"could not find typedef of anonymous struct!!")
            tystr = name
        end
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