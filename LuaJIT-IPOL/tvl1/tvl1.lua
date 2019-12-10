local vicim = require"anima.vicimag"

ffi.cdef[[
void Dual_TVL1_optic_flow_multiscale(
		float *I0,           // source image
		float *I1,           // target image
		float *u1,           // x component of the optical flow
		float *u2,           // y component of the optical flow
		const int   nxx,     // image width
		const int   nyy,     // image height
		const float tau,     // time step
		const float lambda,  // weight parameter for the data term
		const float theta,   // weight parameter for (u - v)²
		const int   nscales, // number of scales
		const float zfactor, // factor for building the image piramid
		const int   warps,   // number of warpings per scale
		const float epsilon, // tolerance for numerical convergence
		const bool  verbose  // enable/disable the verbose mode
);
]]

local lib = ffi.load[[libtvl1]]
local tvl1 = {lib=lib}

ffi.cdef[[
typedef void FILE;
FILE * fopen(const char *path, const char *mode);
size_t fread ( const void * ptr, size_t size, size_t count, FILE * stream );
size_t fwrite ( const void * ptr, size_t size, size_t count, FILE * stream );
int fclose ( FILE * stream );
]]


local function save_optical_flow(filename,data,w,h)
	--reorder data
	local rdata = ffi.new("float[?]",w*h*2)
	--FORL(pd) FORI(n)
	--	clear[pd*i + l] = broken[n*l + i];
	local n = w*h
	for l=0,1 do
		for i=0,n-1 do
			rdata[2*i + l] = data[n*l + i]
		end
	end
	vicim.save(filename,rdata,w,h,2)
end

function tvl1.tvl1(file0,file1,outfile,args)
	args = args or {}
	--defaults
	local TAU     = 0.25
	local LAMBDA  =  0.15 --0.05 --0.09 --0.15 --0.03 --1 --0.15
	local THETA   = 0.3
	local NSCALES = 100
	local ZFACTOR = 0.5
	local NWARPS  = 5
	local EPSILON = 0.01
	local VERBOSE = true

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

	--save_raw([[C:\slowmoVideo\test\move0.raw]],I0,nx,ny,1)
	--if true then return end
	
	local N = 1 + math.log(math.sqrt(nx*nx + ny*ny)/16.0) / math.log(1/zfactor);
	if (N < nscales) then
		nscales = N;
	end
	
	--allocate memory for the flow
	local u = ffi.new("float[?]",2 * nx * ny)--xmalloc(2 * nx * ny * sizeof*u);
	local v = u + nx*ny

	--compute the optical flow
	lib.Dual_TVL1_optic_flow_multiscale(
				I0, I1, u, v, nx, ny, TAU, LAMBDA, THETA,
				nscales, zfactor, NWARPS, EPSILON, VERBOSE
		);

	--save the optical flow
	save_optical_flow(outfile, u, nx, ny);
end

local path = require"anima.path"
function tvl1.do_dir(src_dir,dst_dir,args)
	
	args = args or {ini=1}
	path.mkdir(dst_dir)

	local images = {}
	funcdir(src_dir,function(f) table.insert(images,f) end)
	
	for i = args.ini,#images do
	
		print("doing",i)
		local im0 = images[i]
		local im1 = images[i+1]
		if i == #images then im1 = images[1] end
		
		tvl1.tvl1(im0,im1,path.chain(dst_dir,string.format("f%04d.flo",i)),args)
		tvl1.tvl1(im1,im0,path.chain(dst_dir,string.format("b%04d.flo",i)),args)
		print("save to",path.chain(dst_dir,string.format("b%04d.flo",i)))
	end

end

--local destdir = [[G:\VICTOR\pelis\caprichos\flow\lotomask_tvl1]]
--local srcdir = [[G:\VICTOR\pelis\caprichos\master1080\lotomask]]
-- local destdir = [[G:\VICTOR\pelis\loopmar\flow\loop1tvl1]]
-- local srcdir = [[G:\VICTOR\pelis\loopmar\master1080\loop1]]
-- tvl1.do_dir(srcdir, destdir,{ini=1,reduce=3})

return tvl1

