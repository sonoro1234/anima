local sep = package.config:sub(1,1)
--local currpath = debug.getinfo(1,'S').source:match("@(.+)"..sep.."([^"..sep.."]+)")
print("pack",package.path)
--print(package.path:match("[^;]+%?%.lua"))
local addpath = ""
for w in package.path:gmatch("[^;]+%?%.lua") do
	addpath = addpath..w:gsub("%?","luapower"..sep.."?")..";"
       print(w, addpath)
end
--package.path = currpath..sep.."luapower"..sep.."?.lua;"..package.path
--package.path = currpath..sep.."?.lua;"..package.path
package.path = addpath..package.path
--print("lfs_fs",currpath,...)
print("pack",package.path)
return true