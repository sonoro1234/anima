local lfs=require"lfs"
local path = require"anima.path"
local script_path = path.this_script_path()
--first resize photos
print"resizing originals-------------"
dofile(path.chain(script_path,"syncdirs.lua"))

--make compressed images
print"saving compressed images -------------"
dofile(path.chain(script_path,"savecompresseddir.lua"))

--calculate flows if flow dir is not present
if not lfs.attributes(path.chain(script_path,"flow")) then
	print"calculating flows ------------------------------------------"
	local brox = require"IPOL.brox"
	local destdir = path.chain(script_path,"flow","peli1")
	local srcdir  = path.chain(script_path,"master1080","peli1")
	brox.do_dir(srcdir, destdir,{ini=1,reduce=2,gamma=4,alpha=88})
end

----------- use flows ----------------------------
require"anima"
local GL = GLcanvas{H=800,aspect=2661/3671,profile="CORE",DORENDER=false,RENDERINI=0,RENDEREND=20}
GL.rootdir = path.file_path()
GL:setMovie(GL.rootdir.."/frames")

local fpl = require"anima.plugins.flow_player"(GL)

local args = fpl:loadimages("peli1","peli1")
args.frame = AN({1,#args.images*10,#args.images*10*0.2 },{1,#args.images*10,#args.images*10*2 })

function GL.init()
	--start playing (press space)
	GL.transport.play()
end
function GL.draw(t,w,h)
	fpl:draw(t,w,h,args)
end

GL:start()
