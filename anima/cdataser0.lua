local ffi = require "ffi"

local CTs = {[0] =
"int","struct","ptr","array","void","enum","func","typedef","attrib","field","bitfield","constant","extern","kw"}
local cidstop = {int=true,struct=true,void=true,bitfield=true}
local function typeinfo_ex(cd, dontprint)
    --print("cd",cd)
    local ti = ffi.typeinfo(cd)
    if not ti then return end
    ti.typeid = type(cd)=="number" and cd or tonumber(ffi.typeof(cd))
    ti.what = CTs[bit.rshift(ti.info, 28)]
    ti.transparent = (bit.band(bit.rshift(ti.info, 16), 0xff) == 3) or nil
    
    if not cidstop[ti.what] then
    local cid = bit.band(ti.info, 0xffff)
    ti.cidti = (cid~=0) and typeinfo_ex(cid,true) or nil
    end

    if not dontprint then
        --print("--",ti.what, ti.name,ti.transparent,ti.cidti, ti.cidti and ti.cidti.what,ti.cidti and ti.cidti.name,ti.cidti and ti.cidti.transparent)
        --prtable(ti)
    end
    return ti
end
---------------------------
local function walkatt(ti)
    assert(ti.what=="attrib")
    if ti.cidti then
        if ti.cidti.what=="attrib" then
            return walkatt(ti.cidti)
        else
            assert(ti.cidti.what=="struct")
            return ti.cidti
        end
    else
        error"not cidti in attrib"
    end
end
local nilval = {}
local function basicSerialize (o)
    if type(o) == "number" then
        return string.format("%.17g", o)
    elseif type(o)=="boolean" then
        return tostring(o)
    elseif type(o) == "string" then
        return string.format("%q", o)
    else
        return tostring(o) --"nil"
    end
end
local function tb2st(t)
    if type(t)~= "table" then
        return basicSerialize(t)
    else
        if t==nilval then
            return "nil"
        end
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

local function mergetab(t,t2,ti,ti2)
    local is_union = (bit.band(ti2.info, 0x00800000) ~= 0)
    if is_union then --ti2.what == "union" then
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
local function save_ptr(cd, ti)
    local is_ref = (bit.band(ti.info, 0x00800000) ~= 0)
    if is_ref then
        return cd
    end
    ti = ti.cidti
    local el_size = ti.size
    local const = (bit.band(ti.info, 0x02000000) ~= 0) and true or nil
    if cd~=nil and el_size == 1 and const then
        local s = ffi.string(cd)
        return s
    else
        print("cdataser WARNING: saving nil ptr!!")
        return nilval
    end
end
local walk
local function valorarray1(cd,nels,ti)
    local tk = ti.cidti.what
    local t = {}
    for i=0,nels-1 do
        local val = cd[i]
        if tk == "struct" then 
            val = walk(cd[i],ti.cidti)
        elseif tk == "array" then
            local nels2 = ti.cidti.size/ti.cidti.cidti.size
            val = valorarray1(val,nels2,ti.cidti)
        elseif tk == "ptr" then
            val = save_ptr(val,ti.cidti)
        end
        t[i+1] = val 
    end
    return t
end

walk = function(cd,ti,base,level)
    level = level or 1
    local t = {}
    --print("walk------------------------",level,base,ti.what,cd)
    while ti.sib do
        ti = typeinfo_ex(ti.sib)
        if ti.what=="attrib" then
            -- ti = walkatt(ti)
            local ti2 = walkatt(ti)
            local t2 = walk(cd,ti2,base,level+1)
            mergetab(t,t2,ti,ti2)
        --end
        elseif ti.what=="field" then 
            local ticidti = ti.cidti
            if ticidti then 
                if ticidti.what=="struct" then 
                    local t2 = walk(cd[ti.name],ticidti,base,level+1)
                    mergetab(t,t2,ti,ticidti)
                elseif ticidti.what=="attrib" then
                    local ti2 = walkatt(ticidti)
                    local t2 = walk(cd[ti.name],ti2,base,level+1)
                    mergetab(t,t2,ti,ti2)
                elseif ticidti.what=="array" then
                    local nelems
                    local is_vla = (bit.band(ticidti.info, 0x00100000) ~= 0) and true
                    local nels = is_vla and base or ticidti.size/ticidti.cidti.size
                    local t2 = valorarray1(cd[ti.name],nels,ticidti)
                    table.insert(t,t2)
                elseif ticidti.what == "int" then
                    table.insert(t,cd[ti.name])
                elseif ticidti.what=="ptr" then
                    local t2 = save_ptr(cd[ti.name],ticidti)
                    table.insert(t,t2)
                elseif ticidti.what == "enum" then
                    table.insert(t,tonumber(cd[ti.name]))
                else
                    print(ticidti.what, ticidti.name,ti.name)
                    error"unmanaged field"
                    table.insert(t,cd[ti.name])
                end
            end
        else 
            assert(ti.what=="bitfield",ti.what)
            table.insert(t,cd[ti.name])
        end
    end
    --print("end walk------------------------",level,t)
    return t
end

local function genstr(tystr,vals,nelem)
    if nelem then
        return table.concat{"ffi.new(\"",tystr,"\",",nelem,",",tb2st(vals),")"}
    else
        return table.concat{"ffi.new(\"",tystr,"\",",tb2st(vals),")"}
    end
end
local function find_typedef(ti,tystr)
    print("searching typedef for anonymous",tystr)
    local name
    for i = 1, math.huge do
        local t = typeinfo_ex(i,true)
        if t == nil then
            break
        end
        if t.what == "typedef" and ti.typeid == bit.band(t.info, 0xffff) then
            name = t.name
            break
        end
    end
    assert(name,"could not find typedef of anonymous struct!!")
    return name
end
local function cdataser(cd)
    local len = ffi.sizeof(cd)
    local ty = ffi.typeof(cd)
    local s0 = ffi.sizeof(ty,0)
    local s1 = ffi.sizeof(ty,1)
    local tystr = tostring(ty):sub(7, -2)
    local is_vla, nelem
    if s0~=s1 then
        is_vla = true
        local el_size = s1 - s0
        nelem = (len - s0)/el_size
    end
    local ti = typeinfo_ex(ty)
    if ti.what == "ptr" then
        local is_ref = (bit.band(ti.info, 0x00800000) ~= 0)
        if is_ref then
            ti = ti.cidti
            tystr = tystr:gsub("%(*&%)*","")
        else --ptr
            local t = save_ptr(cd,ti)
            return genstr(tystr,t)
        end
    end
    if ti.what=="attrib" then
        ti = walkatt(ti)
    end
    if ti.what == "struct" then
        if not ti.name then
            tystr = find_typedef(ti,tystr)
        end
        local t = walk(cd, ti, nelem)
        return genstr(tystr,t,nelem)
    elseif ti.what == "array" then
        local nels = is_vla and nelem or ti.size/ti.cidti.size
        local vals = valorarray1(cd,nels,ti)
        return genstr(tystr,vals,nelem)
    else
        return genstr(tystr,tonumber(cd))
    end
end

return cdataser