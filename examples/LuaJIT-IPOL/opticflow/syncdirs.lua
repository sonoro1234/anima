
local im = require"imffi"
local path = require"anima.path"
local script_path = path.this_script_path()


local function FitFrame(image, w, h)
	local ratioor = w/h
	local ratioim = image:Width()/image:Height()
	local imw,imh = image:Width(),image:Height()
	local xmin, xmax, ymin, ymax, dofit
	if ratioor > ratioim then
		print"fit 1"
		ymin = 0
		ymax = imh
		xmax = math.floor(0.5 + ymax * ratioor)
		xmin = math.floor(0.5 + (xmax - imw)/2)
		dofit = 1
	elseif ratioor < ratioim then
		print"fit2"
		xmin = 0
		xmax = imw
		ymax = math.floor(0.5 + xmax / ratioor)
		ymin =  math.floor(0.5 + (ymax - imh)/2)
		dofit = 2
	else
		print"no fit"
	end
	if dofit then
		print("image",ratioim,imw,imh)
		print("immargins", image:Width()/image:Height(),image:Width(),image:Height())
		print("parms", xmin, xmax, ymin, ymax)
		--local imfit = im.ProcessAddMarginsNew(image, xmin, xmax, ymin, ymax)
		local imfit = im.ImageCreateBased(image,xmax,ymax)
		if dofit == 2 then
			im.ProcessAddMargins(image,imfit,xmin,ymin)
		else
			im.ProcessInsert(imfit, image, imfit, xmin, ymin) 
			im.ProcessMirror(image, image)
			--image:Gamma(5)
			im.ProcessInsert(imfit, image, imfit, math.min(xmin + imw, xmax-1), ymin)
			--local imcrop = im.ProcessCropNew(image, imw - xmin, imw, ymin, imh)
			local imcrop = im.ImageCreateBased(image,xmin,ymax)
			im.ProcessCrop(image, imcrop, imw - xmin, ymin)
			
			im.ProcessInsert(imfit, imcrop, imfit, 0, ymin)
			imcrop:Destroy()
		end
		image:Destroy()
		image = imfit
	
	end
	--resize
	if (image:Width() ~= w ) or (image:Height() ~= h) then
		local im2 = im.ImageCreateBased(image,w,h)
		im.ProcessResize(image,im2,3)
		image:Destroy()
		image = im2
	end
	return image
end

local function copyprocess(src, name, dstdir, w,h)
	print("copyprocess", src,name)
	local image,err = im.FileImageLoad(src)
	if (err and err ~= im.ERR_NONE) then
			print("error while reading",src)
			print(im.ErrorStr(err))
			return
	end
	--print"loadedxxxxxxxxxxxxxx"
	-- fit in w h resize
	image = FitFrame(image, w, h)
	--several frames
	name2 = string.gsub(name , "jpg" .. "$", "tif")
	local dst = dstdir.."/"..name2
	--err = im.FileImageSave(dst, "TIFF", image)
	err = image:FileSave(dst, "TIFF")
	if (err and err ~= im.ERR_NONE) then
			print("error while writing",dst)
			print(im.ErrorStr(err))
			return
	end
	image:Destroy()
end 

local Sync = require"anima.syncdirs"

print(script_path)
rootdir = script_path
local srcdir = rootdir..[[/exports]]
local dstdir = rootdir..[[/master]]

local HEIGHT = 1080
local ASPECT = 2661/3671
Sync.Synchronize1(srcdir, dstdir..tostring(HEIGHT), "jpg", "tif", copyprocess, HEIGHT*ASPECT, HEIGHT)
print"done sync"

