--local lfs = require"luapower.lfs_fs"
--require"luapower.setluapower"
local lfs = require"lfs_fs"
-- local lfs = require"lfs_ffi"
local path = "c:\\anima64"--aaautf8"--"anima64\\"
local sep = "\\"
require"anima.utils"
for file, obj in lfs.dir(path) do
	local f = path..sep..file
	local atname = nil --"atime"
	print(file, obj)--,#file)--,obj)--,attr.mode)
	-- local attr = obj and obj:attr("type",false)-- or 
	-- print("     ",attr.type)
	---[[
	local typef = obj and obj:attr(atname)-- or 
	print("     ",typef)
	if type(typef)=="table" then prtable(typef) end
	
	-- local typef2 = obj and obj:attr("atime")-- or 
	-- print("     ",typef2,typef2==typef.atime)
	
	local attr = lfs.attributes (f,atname)
	print("     ",attr)
	if type(attr)=="table" then prtable(attr) end
	--]]
	-- local attr,err = lfs.attr(f,"type")
	-- print("     ",attr,err)
end