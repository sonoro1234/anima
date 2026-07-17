local lfs = require"lfs_fs"

local path = "c:\\aaautf8"--"anima64\\"
local sep = "\\"
local count = 0
local function funcdir(path)
	for file, obj in lfs.dir(path) do
		if file~="." and file~=".." then
			if type(file)=="boolean" then 
				print(file,obj,path)
				break
			else
				local typ = obj:attr("mode")
				count = count + 1
				print(file,typ)
				--print(obj:path())
				if typ=="directory" then
					-- local f = obj:path() 
					local f = path..sep..file
					--funcdir(f)
				end
			end
		end
	end
end

local ini_t = os.time()
funcdir(path)
print("done in",os.time()-ini_t, count)