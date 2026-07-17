local lfs = require"lfs_ffi"
require"anima.utils"
local path = "c:\\aaautf8"--"$Recycle.Bin\\S-1-5-21-2509167016-626393425-3356734568-1002"--aaautf8"--"anima64\\"
local sep = "\\"
local count = 0
local function funcdir(path)
	for file, obj in lfs.dir(path) do
		if file~="." and file~=".." then
			local typ = obj:attr("mode")
			typ = lfs.attributes(path..sep..file,nil)--"mode")
			--typ = lfs.symlinkattributes(path..sep..file,nil)
			prtable(typ)
			count = count + 1
			print(file,typ)
			if typ=="directory" then
				local f = path..sep..file
				--funcdir(f)
			end
		end
	end
end

local ini_t = os.time()
funcdir(path)
print("done in",os.time()-ini_t, count)