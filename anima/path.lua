-----------------extracted from penligth (Steve Donovan)
local M = {}
local lfs = require"lfs"
local is_windows = package.config:sub(1,1) == '\\'
local function isabs(P)
	if is_windows then
		return P:sub(1,1) == '/' or P:sub(1,1)=='\\' or P:sub(2,2)==':'
	else
		return P:sub(1,1) == '/'
	end
end
local sep = is_windows and '\\' or '/'
M.path_sep = sep
M.sep = sep
local np_gen1, np_gen2 = '[^SEP]+SEP%.%.SEP?', 'SEP+%.?SEP'
local np_pat1, np_pat2 = np_gen1:gsub('SEP',sep) , np_gen2:gsub('SEP',sep)

local function normpath(P)
    if is_windows then
        if P:match '^\\\\' then -- UNC
            return '\\\\'..normpath(P:sub(3))
        end
        P = P:gsub('/','\\')
    end
    local k
    repeat -- /./ -> /
        P,k = P:gsub(np_pat2,sep)
    until k == 0
    repeat -- A/../ -> (empty)
        P,k = P:gsub(np_pat1,'')
    until k == 0
    if P == '' then P = '.' end
    return P
end

local function abspath(P)
	local pwd = lfs.currentdir()
	if not isabs(P) then
		P = pwd..sep..P
	elseif is_windows  and P:sub(2,2) ~= ':' and P:sub(2,2) ~= '\\' then
		P = pwd:sub(1,2)..P -- attach current drive to path like '\\fred.txt'
	end
	return normpath(P)
end
-----------------------------end penlight
local function splitpath(P)
	return P:match("(.+)"..sep.."([^"..sep.."]+)")
end

-- creates a dir and its parents
local function mkdir(P)
	local dirs = {}
	local rr = normpath(P)
	for w in rr:gmatch("([^"..sep.."]+)") do
		dirs[#dirs + 1] = w
	end
	local current = dirs[1]
	for i=2,#dirs do
		current = current .. sep .. dirs[i]
		if nil == lfs.attributes(current) then
			local suc,err = lfs.mkdir(current)
			if not suc then error("mkdir:"..current .. " " ..err) end
		end
	end
end

local function copyfile(src,dst,blocksize)
	blocksize = blocksize or 1024*4
	print( "copyfile", src, dst)
	local srcf, err = io.open(src,"rb")
	if not srcf then error(err) end
	local dstf, err = io.open(dst,"wb")
	if not dstf then error(err) end
	while true do
		local data = srcf:read(blocksize)
		if not data then break end
		dstf:write(data)
	end
	srcf:close()
	dstf:close()
end

local function ext(path)
	return path:match(".+%.([^%.]-)$")    ----("(.+)%.(.-)$")
end
function M.chain(...)
	local res={}
	for i=1, select('#', ...) do
		local t = select(i, ...)
		table.insert(res,t)
	end
	return table.concat(res,sep)
end
function M.change_ext(path,ext)
	local noext,oldext = path:match("(.+%.)([^%.]-)$")
	return noext..ext
end
function M.path2table(P)
	local t = {}
	while true do
		local a,b = M.splitpath(P)
		if not a then
			table.insert(t,1,P)
			break 
		end
		table.insert(t,1,b)
		P = a
	end
	return t
end
function M.table2path(t)
	return table.concat(t,sep)
end
local function matchpath(file,patt)
	for i,v in ipairs(patt) do
		if file:match(v) then return true end
	end
	return false
end
local function preparepath(patt)
	if not patt then return end
	for i,v in ipairs(patt) do
		v:gsub("%.","%.")
	end
end
function M.funcdir(path, func, patt, recur, funcd, tree)
	if type(patt)=="string" then patt = {patt} end
	if not tree then preparepath(patt) end --if first time
	tree = tree or ""
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path..sep..file
            local attr = lfs.attributes (f)
            assert (type(attr) == "table")
            if attr.mode == "directory" then
				if funcd then funcd(f,file,attr,tree) end
				if recur then
					local newtree = (tree == "") and file or tree..sep..file
					M.funcdir(f, func, patt, recur, funcd, newtree)
				end
            elseif (not patt) or matchpath(file,patt) then
				func(f, file, attr, tree)
            end
        end
    end
end


M.splitpath = splitpath
M.mkdir = mkdir
M.ext = ext
M.copyfile = copyfile
M.abspath = abspath
--path of main script
function M.this_script_path()
	return splitpath(abspath(arg[0])) --.. sep
end
M.main_scrip_path = M.this_script_path
--path of file calling file_path
function M.file_path()
	local scpath = debug.getinfo(2,'S').source:match("@(.*)$") 
	return splitpath(abspath(scpath)) --.. sep
end
function M.testcurdir()
	local info = debug.getinfo(1,'S');
	print("anima path in",info.source);
	local info = debug.getinfo(2,'S');
	print("anima path in",info.source);
end
function M.animapath()
	local scpath = debug.getinfo(1,'S').source:match("@(.*)$") 
	return splitpath(abspath(scpath)) --.. sep
end
function M.require_here()
	local script_path = M.this_script_path()
	local addp = script_path ..sep.."?.lua"
	--if package.path:match(
	package.path = package.path..";"..script_path ..sep.."?.lua"
end
function M.require_in(pat)
	package.path = package.path..";"..pat ..sep.."?.lua"
end
--[=[
--print(ext("nest.eerd.exe"))
require"anima.utils"
local pp = M.change_ext([[c:\p1\p2\p3.pep]],"pri")
local tt = M.path2table(pp)
prtable(tt)
tt[#tt-1] = "p2nuevo"
print(M.table2path(tt))
--]=]
return M