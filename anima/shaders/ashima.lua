local path = require"anima.path"
--print("package.path",package.path)
--get lua dir, only works if it is in lua.exe dir
local lev = 0
while(arg[lev]) do lev = lev - 1 end
local luadir = path.chain(path.splitpath(arg[lev+1]),"lua")
--substitution of . in require arguments for /
local base2 = (...):gsub("%.",path.path_sep)
local base = path.splitpath(path.chain(luadir,base2))
--print("loader",arg[lev+1],luadir,base2,base)

return function(name)
	local file = io.open (path.chain(base,"webgl-noise","src",name..".glsl"),"r")
	local str = file:read"*a"
	file:close()
	return str
end