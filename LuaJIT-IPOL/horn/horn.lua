local vicim = require"anima.vicimag"

ffi.cdef[[
void horn_schunck_pyramidal(
	const float *I1,              // source image
	const float *I2,              // target image
	float       *u,               // x component of optical flow
	float       *v,               // y component of optical flow
	const int    nx,              // image width
	const int    ny,              // image height
	const float  alpha,           // smoothing weight
	const int    nscales,         // number of scales
	const float  zfactor,         // zoom factor
	const int    warps,           // number of warpings per scale
	const float  TOL,             // stopping criterion threshold
	const int    maxiter,         // maximum number of iterations
	const bool   verbose          // switch on messages
);
]]

local lib = ffi.load[[libhorn]]
local horn = {lib=lib}


function horn.horn(file0,file1,outfile,args)
	--DEFAULTS

	local ALPHA = 7
	local NSCALES = 10
	local ZFACTOR = 0.5
	local NWARPS = 10
	local TOL = 0.0001
	local MAXITER = 150
	local VERBOSE = false
	
--define PAR_MAX_ZFACTOR 0.99

	local zfactor = ZFACTOR
	local nscales = NSCALES
	
	local image0 = im.FileImageLoadBitmap(file0)
	if (not image0) then
			print ("Unnable to open the file: " .. file0)
			error()
	end
	
	local image1 = im.FileImageLoadBitmap(file1)
	if (not image1) then
			print ("Unnable to open the file: " .. file1)
			error()
	end
	
	assert(image0:Width() == image1:Width())
	assert(image0:Height() == image1:Height())
	
	local image0r
	local image1r
	if args.reduce then
		--reduce
		local image0rt = im.ProcessReduceBy4New(image0)
		local image1rt = im.ProcessReduceBy4New(image1)
		image0r = im.ProcessReduceBy4New(image0rt)
		image1r = im.ProcessReduceBy4New(image1rt)
		image0rt:Destroy()
		image1rt:Destroy()
	else
		image0r = image0
		image1r = image1
	end
	
	--make grey scale
	local I0 = vicim.togrey(image0r)
	local I1 = vicim.togrey(image1r)

	local nx,ny = image0r:Width(),image0r:Height()
	
	image0:Destroy()
	image1:Destroy()
	if args.reduce then
		image0r:Destroy()
		image1r:Destroy()
	end


	local N = 1 + math.log(math.sqrt(nx*nx + ny*ny)/16.0) / math.log(1/zfactor);
	if (N < nscales) then
		nscales = N;
	end
	
	
	--allocate memory for the flow
	local u = ffi.new("float[?]", nx * ny)
	local v = ffi.new("float[?]", nx * ny)

	--compute the optical flow
	lib.horn_schunck_pyramidal(
				I0, I1, u, v, nx, ny,
				ALPHA, nscales, zfactor, NWARPS, TOL, MAXITER,VERBOSE);
	
	--save
	local f = ffi.new("float[?]", nx * ny * 2)
	for i = 0,nx * ny -1 do
		f[2*i] = u[i];
		f[2*i+1] = v[i];
	end
	--save the optical flow
	vicim.save(outfile,f,nx,ny,2)
end

local path = require"anima.path"
function horn.do_dir(src_dir,dst_dir,args)
	
	args = args or {ini=1}
	path.mkdir(dst_dir)

	local images = {}
	funcdir(src_dir,function(f) table.insert(images,f) end)
	
	for i = args.ini,#images do
	
		print("doing",i)
		local im0 = images[i]
		local im1 = images[i+1]
		if i == #images then im1 = images[1] end
		
		horn.horn(im0,im1,path.chain(dst_dir,string.format("f%04d.flo",i)),args)
		horn.horn(im1,im0,path.chain(dst_dir,string.format("b%04d.flo",i)),args)
		print("save to",path.chain(dst_dir,string.format("b%04d.flo",i)))
	end

end

--[=[
local destdir = [[G:\VICTOR\pelis\loopmar\flow\loop1horn]]
local srcdir = [[G:\VICTOR\pelis\loopmar\master1080\loop1]]
horn.do_dir(srcdir, destdir,{ini=1,reduce=3})
--]=]
--[=[
local destdir = [[H:\pelis\ninfas\flow\fati3horn\]]
local suc,errstr = lfs.mkdir(destdir)
if not suc then print(errstr) end

local images = {}
funcdir([[H:\pelis\ninfas\master1080\fati3]],function(f) table.insert(images,f) end)

for i = 1,#images-1 do

print("doing",i)
local im0 = images[i]
local im1 = images[i+1]

horn.horn(im0,im1,destdir..string.format("f%04d.flo",i),{reduce=4})
horn.horn(im1,im0,destdir..string.format("b%04d.flo",i),{reduce=4})
end
--]=]


return horn

