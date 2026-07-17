-- local sep = package.config:sub(1,1)
-- local currpath = debug.getinfo(1,'S').source:match("@(.+)"..sep.."([^"..sep.."]+)")
-- package.path = currpath..sep.."luapower"..sep.."?.lua;"..package.path
-- print("lfs_fs",currpath,...)
require"luapower.setluapower"
local lfs = require"fs"
local function attrtranslate(name,t,...)
	--print("attrtranslate",name,t,...)
	if t==nil then
		return t
	elseif type(t)=="string" then
		t = t=="dir" and "directory" or t
		return t
	elseif type(t)~="table" then
		return t
	end
	t.mode = t.type
	if t.mode == "dir" then t.mode = "directory" end
	t.type = nil
	--permissions
	if t.perms then
		t.permissions = t.perms
		t.perms = nil
	else --windows
		local endname = name:match"%.exe$" or name:match"%.bat$"  or name:match"%.cmd$"  or name:match"%.com$"
		local perms = "r"..(t.readonly and "-" or "w")..(endname and "x" or "-")
		perms = perms:rep(3)
		t.permissions = perms
		t.readonly = nil
		t.archive = nil
	end
	return t
end

lfs.currentdir = lfs.cd
lfs.attributes = function(fname,atname)
	if type(atname)=="string" then
		atname = atname=="mode" and "type" or atname
	end
	local at = lfs.attr(fname,atname,true)
	return attrtranslate(fname, at) 
end
lfs.symlinkattributes = function(fname,atname)
	if type(atname)=="string" then
		atname = atname=="mode" and "type" or atname
	end
	local at = lfs.attr(fname,atname,false)
	return attrtranslate(fname, at) 
end

lfs.link = mksymlink
lfs.rmdir = lfs.remove
local oldfs_dir = lfs.dir
function lfs.dir(path)
	local dnext, dir = oldfs_dir(path, true)
	local dir_wrap = {}
	function dir_wrap.attr(dir_w,atname) 
		if type(atname)=="string" then
			atname = atname=="mode" and "type" or atname
		end
		local rets = dir:attr(atname)
		return attrtranslate(dir_w.file,rets)
	end
	setmetatable(dir_wrap, {
		__index = function(t,k)
			--print("__index",k)
			return dir[k]
		end,
		__newindex = function(t, k, v)
			--print("__newindex",k, v)
			dir[k] = v
		end
	})
	local function wrapped_next(dir1)
		while true do
			local file, err = dnext(dir1)
			rawset(dir1, "file", file)
			if file == nil then
				return nil
			elseif not file then
				--return false, err
				return nil, err
			else--if file ~= '.' and file ~= '..' then
				return file, dir1
			end
		end
	end
	return wrapped_next, dir_wrap
end
return lfs