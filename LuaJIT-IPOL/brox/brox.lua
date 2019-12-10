local vicim = require"anima.vicimag"

ffi.cdef[[
void brox_optic_flow(
    const float *I1,         //first image
    const float *I2,         //second image
    float *u, 		      //x component of the optical flow
    float *v, 		      //y component of the optical flow
    const int    nxx,        //image width
    const int    nyy,        //image height
    const float  alpha,      //smoothness parameter
    const float  gamma,      //gradient term parameter
    const int    nscales,    //number of scales
    const float  nu,         //downsampling factor
    const float  TOL,        //stopping criterion threshold
    const int    inner_iter, //number of inner iterations
    const int    outer_iter, //number of outer iterations
    const bool   verbose     //switch on messages
);
]]

local lib = ffi.load[[libbrox]]
local brox = {lib=lib}

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
local function reduce4(I0,I1)
	local I0t = im.ProcessReduceBy4New(I0)
	local I1t = im.ProcessReduceBy4New(I1)
	I0:Destroy()
	I1:Destroy()
	return I0t,I1t
end
function brox.brox(file0,file1,outfile,args)
	--DEFAULTS
	local ALPHA = args.alpha or 18
	local GAMMA = args.gamma or 7
	local NSCALES = 100
	local ZFACTOR = 0.75
	local TOL = 0.0001
	local INNER_ITER = 1
	local OUTER_ITER = 15 --38 --15
	local VERBOSE = false --true

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
	
	if args.reduce then
		for i=1,args.reduce do
			image0,image1 = reduce4(image0,image1)
		end
	end
	
	--make grey scale
	local I0 = vicim.togrey(image0)
	local I1 = vicim.togrey(image1)

	local nx,ny = image0:Width(),image0:Height()
	print(nx,ny)
	image0:Destroy()
	image1:Destroy()

	local N = math.floor(1 + math.log(math.min(nx, ny) / 16) / math.log(1/zfactor))
	if( N < nscales) then nscales = N end
	
	
	--allocate memory for the flow
	local u = ffi.new("float[?]", nx * ny)
	local v = ffi.new("float[?]", nx * ny)

	--compute the optical flow
	lib.brox_optic_flow(
		I0, I1, u, v, nx, ny, ALPHA, GAMMA, 
		nscales, zfactor, TOL, INNER_ITER, OUTER_ITER, VERBOSE);

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
function brox.do_dir(src_dir,dst_dir,args)
	
	args = args or {ini=1}
	path.mkdir(dst_dir)

	local images = {}
	funcdir(src_dir,function(f) table.insert(images,f) end)

	for i = args.ini,#images do
	
		print("doing",i,"of",#images)
		local im0 = images[i]
		local im1 = images[i+1]
		if i == #images then im1 = images[1] end
		
		brox.brox(im0,im1,path.chain(dst_dir,string.format("f%04d.flo",i)),args)
		brox.brox(im1,im0,path.chain(dst_dir,string.format("b%04d.flo",i)),args)
		print("save to",path.chain(dst_dir,string.format("b%04d.flo",i)))
	end

end
--[=[
local destdir = [[G:\VICTOR\pelis\caprichos\flow\entrada\]]
local suc,errstr = lfs.mkdir(destdir)
if not suc then print(errstr) end

local images = {}
funcdir([[G:\VICTOR\pelis\caprichos\master1080\entrada]],function(f) table.insert(images,f) end)

for i = 1,#images-1 do

print("doing",i)
local im0 = images[i]
local im1 = images[i+1]

brox.brox(im0,im1,destdir..string.format("f%04d.flo",i),{reduce=4})
brox.brox(im1,im0,destdir..string.format("b%04d.flo",i),{reduce=4})
end
--]=]

--[=[
local destdir = [[G:\VICTOR\pelis\pelipino\flow\arbolflornubes_hor]]
local srcdir  = [[G:\VICTOR\pelis\pelipino\master1080\arbolflornubes_hor]]
brox.do_dir(srcdir, destdir,{ini=1,reduce=3})--,gamma=1,alpha=44})
--]=]
--[=[
local destdir = [[G:\VICTOR\pelis\can_oliva\flow\casa_lidia_g7a88]]
local srcdir  = [[G:\VICTOR\pelis\can_oliva\master1080\casa_lidia]]
brox.do_dir(srcdir, destdir,{ini=1,reduce=3,gamma=7,alpha=88})
--]=]
--[=[
local destdir = [[G:\VICTOR\pelis\can_oliva\flow\seclydia2_g2a88]]
local srcdir  = [[G:\VICTOR\pelis\can_oliva\master1080\seclydia2]]
brox.do_dir(srcdir, destdir,{ini=1,reduce=3,gamma=2,alpha=88})
--]=]
--[=[
local destdir = [[G:\VICTOR\pelis\can_oliva\flow\dispersa_lydia_g2a88]]
local srcdir  = [[G:\VICTOR\pelis\can_oliva\master1080\dispersa_lydia]]
brox.do_dir(srcdir, destdir,{ini=1,reduce=3,gamma=2,alpha=88})
--]=]
--[=[
local destdir = [[G:\VICTOR\pelis\can_oliva\flow\seq1y2_g2a88]]
local srcdir  = [[G:\VICTOR\pelis\can_oliva\master1080\seq1y2]]
local initime = os.clock()
brox.do_dir(srcdir, destdir,{ini=1,reduce=3,gamma=2,alpha=88})
print(os.clock()-initime)
--]=]
--[=[
local destdir = [[G:\VICTOR\pelis\pelipino\flow\pies_indios2]]
local srcdir  = [[G:\VICTOR\pelis\pelipino\master1080\pies_indios2]]
local initime = os.clock()
brox.do_dir(srcdir, destdir,{ini=1,reduce=3,gamma=7,alpha=88})
print(os.clock()-initime)
--]=]
--[=[
local destdir = [[G:\VICTOR\pelis\can_oliva\flow\sequenciapuertasmarron]]
local srcdir  = [[G:\VICTOR\pelis\can_oliva\master1080\sequenciapuertasmarron]]
local initime = os.clock()
brox.do_dir(srcdir, destdir,{ini=1,reduce=3,gamma=7,alpha=88})
print(os.clock()-initime)
--]=]
--[=[
local destdir = [[G:\VICTOR\pelis\can_oliva\flow\dorada]]
local srcdir  = [[G:\VICTOR\pelis\can_oliva\master1080\dorada]]
local initime = os.clock()
brox.do_dir(srcdir, destdir,{ini=1,reduce=3,gamma=7,alpha=88})
print(os.clock()-initime)
--]=]
--[=[
local destdir = [[G:\VICTOR\pelis\can_oliva\flow\sechorizontal]]
local srcdir  = [[G:\VICTOR\pelis\can_oliva\master1080\sechorizontal]]
local initime = os.clock()
brox.do_dir(srcdir, destdir,{ini=1,reduce=3,gamma=7,alpha=88})
print(os.clock()-initime)
--]=]
--[=[
local destdir = [[G:\VICTOR\pelis\loopmar\flow\loop1g4a88r2]]
local srcdir  = [[G:\VICTOR\pelis\loopmar\master1080\loop1]]
local initime = os.clock()
brox.do_dir(srcdir, destdir,{ini=1,reduce=2,gamma=4,alpha=88})
print(os.clock()-initime)
--]=]
--[=[
local destdir = [[G:\VICTOR\pelis\loopmar\flow\loop2g7a44]]
local srcdir  = [[G:\VICTOR\pelis\loopmar\master1080\loop2]]
local initime = os.clock()
brox.do_dir(srcdir, destdir,{ini=1,reduce=2,gamma=7,alpha=44})
print(os.clock()-initime)
--]=]
--[=[
local destdir = [[C:\Users\Carmen\Documents\rodrigoPascal\flow]]
local srcdir  = [[C:\Users\Carmen\Documents\rodrigoPascal\master1080]]
local initime = os.clock()
brox.do_dir(srcdir, destdir,{ini=1,reduce=2,gamma=4,alpha=88})
print(os.clock()-initime)
--]=]

return brox

