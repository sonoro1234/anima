local path = require"anima.path"

local lev = 0
while(arg[lev]) do lev = lev - 1 end
local base1 = path.splitpath(arg[lev+1])..path.path_sep.."lua"..path.path_sep
local base2 = (...):gsub("%.",path.path_sep)
local base = path.splitpath(base1..base2)..path.path_sep

this_path = path.this_script_path()
print(base,base2)
require"anima.utils"
print("ashima",this_path)
print("ashima",arg[0])
print("ashima",...)
prtable(arg)
prtable{...}
--print(package.path)
--require"glutils.shaders.ashima.webgl-noise.src.noise3D"
--prtable(package)

return function(name)
	local file = io.open (base.."webgl-noise"..path.path_sep.."src"..path.path_sep..name..".glsl","r")
	local str = file:read"*a"
	return str
end