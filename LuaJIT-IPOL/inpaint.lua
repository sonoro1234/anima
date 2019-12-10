local vicim = require"anima.vicimag"
local ffi = require"ffi"
local anima = require"anima"
--require"imlua"
ffi.cdef[[
void inpaint(float *im,float *m,float* res,int swidth,int sheight);
]]

local lfs = require"lfs_ffi"
local currdir = lfs.currentdir()
lfs.chdir[[C:/inpaint/gti_1.2/buildvic/]]
local lib = ffi.load[[C:/inpaint/gti_1.2/buildvic/libinpaint_omp]]
lfs.chdir(currdir)

function do_inpaint(filen,filen_mask, filen_out)
	local function check_err(err)
		if (err and err ~= im.ERR_NONE) then
			error(im.ErrorStr(err))
		end
	end
	local function checkError(err)
			if (err and err ~= im.ERR_NONE) then
				print(filename,err)
				error(im.ErrorStr(err))
			end
		end
	local file = vicim.load_im(filen,true)
	local filem = vicim.load_im(filen_mask,true)
	local res = ffi.new("float[?]", file.w * file.h * file.p)
	lib.inpaint(file.data,filem.data, res,file.w,file.h)
	print"inpaint done"
	local width,height = file.w, file.h
	local leng = width*height*3
	
	local resch = ffi.new("unsigned char[?]",leng)
	for i=0,leng-1 do
		resch[i] = res[i]*255.0;
		--resch[i] = file.data[i]*255;
	end
	local err = ffi.new("int[1]")
		local ifile = imffi.imFileNew(filen_out, "PNG",err);
		checkError(err[0])
		local err2 = imffi.imFileWriteImageInfo(ifile,width, height, im.RGB , im.BYTE);
		checkError(err2)
		err2 = imffi.imFileWriteImageData(ifile, resch);
		checkError(err2)
		imffi.imFileClose(ifile); 
	
	--[[
	local ifile,err = im.FileNew(filen_out, "PNG");
	check_err(err)
	print(ifile,err)
	-- err = ifile:FileWriteImageInfo( width, height, im.IM_RGB, im.IM_FLOAT) --im.IM_BYTE);
	-- check_err(err)
	-- err = ifile:FileWriteImageData( res);
	-- check_err(err)
	ifile:FileClose(); 
	--]]
--[[
	local image = imffi.imImageCreateFromOpenGLData(file.w, file.h, glc.GL_RGB, res); 
	local err = imffi.imFileImageSave(filen_out,"PNG",image)
	check_err(err)
	imffi.imImageDestroy(image)
	--]]
end

--do_inpaint([[C:\inpaint\gti_1.2\data\in.png]], [[C:\inpaint\gti_1.2\data\mask.png]],[[C:\inpaint\gti_1.2\data\output.png]])
do_inpaint([[C:\inpaint\gti_1.2\data\fandema1peqroto.png]], [[C:\inpaint\gti_1.2\data\fandema1peqmask.png]],[[C:\inpaint\gti_1.2\data\fandema1peqclean.png]])
--do_inpaint([[C:\inpaint\gti_1.2\data\fandema1roto.png]], [[C:\inpaint\gti_1.2\data\fandema1mask.png]],[[C:\inpaint\gti_1.2\data\fandema1clean.png]])