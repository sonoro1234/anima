
local lfs = require"lfs"
local function funcdir(path, func, pat, recur, funcd, tree)
	--pat = pat or "" -- ".-"
	--if #pat > 0 then pat = "%." .. pat end
	tree = tree or ""
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path..'/'..file
            local attr = lfs.attributes (f)
            assert (type(attr) == "table")
            if attr.mode == "directory" and recur then
				if funcd then funcd(f,file,attr,tree) end
                funcdir(f, func,pat,recur,funcd,tree.."/"..file)
            elseif (not pat) or file:match(".+%."..pat.."$") then
				func(f, file, attr, tree)
            end
        end
    end
end

local function copyfile(src,dst)
	local srcf = io.open(src,"rb")
	local dstf = io.open(dst,"wb")
	local data = srcf:read"*a"
	dstf:write(data)
	srcf:close()
	dstf:close()
end


local function printdate(attr)
	print(attr.access, attr.modification, attr.change)
	print(os.date("%c",attr.access), os.date("%c",attr.modification), os.date("%c",attr.change))
end
--------------------------
local M = {}

function M.Synchronize(srcdir, dstdir , ext , ext2, copyprocess, ...)
	--ext = ext or ""
	--ext2 = ext2 or ext
	local varargs = {...}
	lfs.mkdir(dstdir)
	--get export to master 
	--print"getting export frames..."
	funcdir(srcdir, function(f, name,attr, tree) 
							--print(f, name, tree)
							--table.insert(exports, f)
							--printdate(attr)
							local name2
							if ext and ext2 then 
								name2 = string.gsub(name , ext .. "$", ext2)
							else
								name2 = name
							end
							local attr2 = lfs.attributes(dstdir..tree.."/"..name2)
							--printdate(attr2)
							if attr2==nil or attr.modification > attr2.modification then
								copyprocess( f, name, dstdir..tree, unpack(varargs))
							end
						end,
						ext, true, function(f, dir,at,tree) lfs.mkdir(dstdir..tree.."/"..dir) end)
	local deletedirs = {}
	--delete from dstdir not in srcdir
	funcdir(dstdir, function(f, name, attr, tree)
							if ext and ext2 then name = string.gsub(name , ext2 .. "$", ext) end
							local attr2 = lfs.attributes(srcdir..tree.."/"..name)
							if attr2 == nil then
								print("deleting:",f)
								os.remove (f)
							end
						end,
						ext2, true, 
						function(f, dir,at,tree)
							local attr2 = lfs.attributes(srcdir..tree.."/"..dir)
							if attr2 == nil then
								deletedirs[#deletedirs + 1] = f
							end 
						end)
	for i,f in ipairs(deletedirs) do
		print("deleting:",f)
		local res,err = lfs.rmdir (f)
		if not res then print("error deleting dir:",err) end
	end
end
--dont delete sync in this version
function M.Synchronize1(srcdir, dstdir , ext , ext2, copyprocess, ...)
	--ext = ext or ""
	--ext2 = ext2 or ext
	local varargs = {...}
	lfs.mkdir(dstdir)
	--get export to master 
	--print"getting export frames..."
	funcdir(srcdir, function(f, name,attr, tree) 
							--print(f, name, tree)
							--table.insert(exports, f)
							--printdate(attr)
							local name2
							if ext and ext2 then 
								name2 = string.gsub(name , ext .. "$", ext2)
							elseif ext2 then
								name2 = string.gsub(name , "%..-$", "."..ext2)
							else
								name2 = name
							end
							local attr2 = lfs.attributes(dstdir..tree.."/"..name2)
							print("looking for:",dstdir..tree.."/"..name2)
							--printdate(attr2)
							if attr2==nil or attr.modification > attr2.modification then
								copyprocess( f, name, dstdir..tree, unpack(varargs))
							end
						end,
						ext, true, function(f, dir,at,tree) lfs.mkdir(dstdir..tree.."/"..dir) end)
	
end

M.funcdir = funcdir
--funcdir([[F:\palmeras\compressed1080]],function(f, name,attr, tree) local f2 = string.gsub(f, "tif$", "cmp"); os.rename(f,f2) end,"tif",true)
--print(string.gsub(".ti.f","%.","%%."))
return 	M				
