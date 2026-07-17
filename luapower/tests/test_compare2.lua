local lfs = require"fs"

local path = "c:\\aaautf8"--"$Recycle.Bin"--"anima64\\"
local sep = "\\"
local count = 0
local function funcdir(path)
	for file, obj in lfs.dir(path, true) do
		if file~="." and file~=".." then
			if type(file)=="boolean" then 
				print(file,obj,path)
				break
			else
				-- local atime = obj:attr("ctime",false)
				-- local tat = obj:attr(nil,false)
				-- print("atime",atime,tat.ctime,atime==tat.ctime)
				local typ = obj:attr("type",false)
				--if lfs.attr(path..sep..file,"type",false) == "symlink" then print("symlink",file) end
				--print(lfs.attr(path..sep..file,"type",true))
				count = count + 1
				print(file,typ)
				--print(obj:path())
				if typ=="dir" then
					-- local f = obj:path() 
					local f = path..sep..file
					funcdir(f)
				elseif typ~="file" then
					print(typ,file)
				end
			end
		end
	end
end

local ini_t = os.time()
funcdir(path)
print("done in",os.time()-ini_t, count)