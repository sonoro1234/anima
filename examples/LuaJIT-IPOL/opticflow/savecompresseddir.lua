require"anima"
local im = require"imffi"
local path = require"anima.path"
local script_path = path.this_script_path()
local rootdir = script_path


local GL = GLcanvas{fps=25,ortho=1,fog=false,H=500,aspect = 1.5,profile="CORE",invisible=true}


function copyprocess(src, name, dstdir, w,h)
	print("copyprocess", src)
	local name2 = string.gsub(name , "%..+$", ".cmp")
	ConvertToCompressed(src,dstdir.."/"..name2)
end 

function swapkeyvalue(t)
	local res={}
	for k,v in pairs(t) do
		res[v]=k
	end
	return res
end
swappedglc = swapkeyvalue(glc)

local Sync = require"anima.syncdirs"
function GL.init()
	--get formats
	local formatCount = ffi.new("GLint[1]",0)
	gl.glGetIntegerv(glc.GL_NUM_COMPRESSED_TEXTURE_FORMATS, formatCount);
	local formatArray = ffi.new("GLint[?]",formatCount[0])
	gl.glGetIntegerv(glc.GL_COMPRESSED_TEXTURE_FORMATS, formatArray);
	
	print("There are formats:", formatCount[0])
	for i=0,formatCount[0]-1 do
		print(i, formatArray[i],swappedglc[formatArray[i]])
	end

	Sync.Synchronize1(rootdir..[[/master1080]],rootdir..[[/compressed1080]], "tif", "cmp", copyprocess, 1080*1.5, 1080)

	print"done sync"
	GL:quit()
end

function GL.draw(w, h)

end

GL:start()
