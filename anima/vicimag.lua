--utilitys for image and im (iup)
require"anima"
local M = {}
function M.flip_vertical(data,w,h,p)
	local datasize = w*p*h
	local types = {"float[?]","unsigned short[?]","unsigned char[?]"}
	local type
	for k,v in ipairs(types) do
		if ffi.istype(v,data) then type=v;break end
	end
	local rdata = ffi.new(type,datasize)
	for i=0,w-1 do
		for j=0,h-1 do
			for k=0,p-1 do
				rdata[i*p+ (h-1-j)*w*p+k] = data[i*p+ j*w*p+k]
			end
		end
	end
	return rdata
end

local nplanes = {[glc.GL_RGB] = 3,[glc.GL_RGBA] = 4,[glc.GL_RED]=1,[glc.GL_LUMINANCE]=1}
M.nplanes = nplanes
function M.togrey(image)
	local nx,ny = image:Width(),image:Height()
	local gldata, glformat = image:GetOpenGLData()
	local data = ffi.cast("unsigned char*",gldata)
	local grey = ffi.new("float[?]",nx*ny)
	
	local bitplanes = nplanes[glformat]
	local inv255 = 1/255
	for i=0,nx*ny-1 do
		grey[i] = (0.299*data[i*bitplanes] + 0.587*data[i*bitplanes+1] + 0.114*data[i*bitplanes+2])*inv255;
	end
	return grey,nx,ny,1
end
--im images
function M.tofloat(image,unpacked)
	
	local nx,ny = image:Width(),image:Height()
	local gldata, glformat = image:GetOpenGLData()
	local data = ffi.cast("unsigned char*",gldata)

	local datalen = nx*ny*nplanes[glformat]
	local fdata = ffi.new("float[?]",datalen)
	local inv255 = 1.0/255.0
	local unpdata
	if unpacked then
		unpdata = ffi.new("unsigned char[?]",datalen)
		im.imffi.imConvertPacking(data,unpdata,nx,ny,nplanes[glformat],nplanes[glformat],im.BYTE,true)
		for i=0,datalen-1 do
			fdata[i] = unpdata[i]*inv255;
		end
	else
		for i=0,datalen-1 do
			fdata[i] = data[i]*inv255;
		end
	end

	return fdata,nx,ny,nplanes[glformat]
end
--saves float data for p bitplanes
--order r0,g0,b0,r1,g1,b1
function M.save(filename,data,w,h,p)
	print("vicimag save",filename)
	local pFile = ffi.C.fopen(filename, "wb");
	if (pFile == nil) then error("could not save "..tostring(filename)) end
	local magicNumber = "VICIMAG"
	ffi.C.fwrite(magicNumber, ffi.sizeof"char", #magicNumber, pFile);
	ffi.C.fwrite(ffi.new("int[1]",w), ffi.sizeof"int", 1, pFile);
	ffi.C.fwrite(ffi.new("int[1]",h), ffi.sizeof"int", 1, pFile);
	ffi.C.fwrite(ffi.new("int[1]",p), ffi.sizeof"int", 1, pFile);
	ffi.C.fwrite(data, ffi.sizeof"float", w*h*p, pFile);
	ffi.C.fclose(pFile);
end

local lpData 
local lpDataSize = 0
function M.load(filename)
	local magicNumber = "VICIMAG"
	
	local pFile = ffi.C.fopen(filename, "rb");
	if (pFile == nil) then error("could not load "..tostring(filename)) end

	local magic = ffi.new("char[?]",#magicNumber)
	ffi.C.fread(magic, ffi.sizeof"char", #magicNumber, pFile);
	assert(ffi.string(magic,#magicNumber) == magicNumber)
	
	local width = ffi.new"int[1]"
	ffi.C.fread(width, ffi.sizeof"int", 1, pFile);
	local height = ffi.new"int[1]"
	ffi.C.fread(height, ffi.sizeof"int", 1, pFile);
	local bitplanes = ffi.new"int[1]"
	ffi.C.fread(bitplanes, ffi.sizeof"int", 1, pFile);
	
	local datasize = width[0]*height[0]*bitplanes[0]
	
	--increment buffer lpData is necessary
	if datasize > lpDataSize then
		lpData = ffi.new("float[?]",datasize)
		lpDataSize = datasize
	end
	
	local pData = lpData
	local retsize = ffi.C.fread(pData, ffi.sizeof"float", datasize, pFile);
	assert(retsize == datasize,"problem loading VICIMAG file")
	ffi.C.fclose(pFile);
	return pData,width[0],height[0],bitplanes[0]
end

function M.tex2pd(tex, planes)
	planes = planes or glc.GL_RGB
	local formats = {[glc.GL_RED]=1,[glc.GL_RGB]=3,[glc.GL_RGBA]=4}
	local data = tex:get_pixels(glc.GL_FLOAT,planes)
	return M.pixel_data(data, tex.width, tex.height,formats[planes])
end


function M.pixel_data(data,w,h,p)
	data = data or ffi.new("float[?]",w*h*p)
	local pdat = {data=data,w=w,h=h,p=p,npix=w*h}
	--returns i,j indexes and pix
	function pdat:iterator()
		local i,j = -1, 0
		return function()
			if i == w-1 then
				i = 0
				j = j + 1
				if j == h then return nil end
			else
				i = i + 1
			end
			return i,j,data + (i+ j*w)*p --self:pixR(i,j)
		end
	end
	--returns i1,j1 indexes as relative increments respect i,j and pix with max increment==r
	--respects image borders
	local min, max = math.min, math.max
	function pdat:square_it(i,j,r)
		local mindx = max(-i,-r)
		local maxdx = min(self.w - i - 1,r)
		local mindy = max(-j,-r)
		local maxdy = min(self.h - j - 1,r)
		local dx,dy = mindx - 1, mindy
		return function()
			if dx == maxdx then
				dx = mindx
				dy = dy + 1
				if dy > maxdy then return nil end
			else
				dx = dx + 1
			end
			return dx, dy, self:pixR(i+dx,j+dy)
			--return dx, dy, self.data + (i + dx + (j+dy)*w)*p
		end
	end
	--returns i1,j1 indexes as relative increments respect i,j and pix with max increment==r
	--respects image borders, 
	local function it2(state)
		--print(state,self)
			if state.dx == state.maxdx then
				state.dx = state.mindx
				state.dy = state.dy + 1
				if state.dy > state.maxdy then return nil end
			else
				state.dx = state.dx + 1
			end
			return state.dx, state.dy, state.self:pixR(state.i+state.dx,state.j+state.dy)
			--return state.dx, state.dy, state.self.data + (state.i + state.dx + (state.j+state.dy)*w)*p
		end
	--From (i-r,j-r) to (i+r,j+r)
	function pdat:square_it2(i,j,r)
		local state = {
			i = i,
			j = j,
			mindx = max(-i,-r),
			maxdx = min(self.w - i - 1, r),
			mindy = max(-j,-r),
			maxdy = min(self.h - j - 1, r),
		}
		state.dx = state.mindx - 1
		state.dy = state.mindy
		state.self = self
		return it2,state,self
	end
	--From (i,j) to (i+r-1,j+r-1)
	function pdat:square_itUL(i,j,r)
		local state = {
			i = i,
			j = j,
			mindx = 0,
			maxdx = min(self.w - i - 1, r-1),
			mindy = 0,
			maxdy = min(self.h - j - 1, r-1),
		}
		state.dx = state.mindx - 1
		state.dy = state.mindy
		state.self = self
		return it2,state,self
	end
	--From (i,j) to (i+r1-1,j+r2-1)
	function pdat:rectangle_itUL(i,j,r1,r2)
		local state = {
			i = i,
			j = j,
			mindx = 0,
			maxdx = min(self.w - i - 1, r1-1),
			mindy = 0,
			maxdy = min(self.h - j - 1, r2-1),
		}
		state.dx = state.mindx - 1
		state.dy = state.mindy
		state.self = self
		return it2,state,self
	end
	function pdat:copy()
		local data2 = ffi.new("float[?]",w*h*p)
		ffi.copy(data2, data, w*h*p*ffi.sizeof"float")
		return M.pixel_data(data2,w,h,p)
	end
	function pdat:mult(f)
		local size = w*h*p
		local data2 = ffi.new("float[?]",size)
		for i=0,size-1 do
			data2[i] = data[i]*f
		end
		self.data = data2
		data = data2
	end
	--returns float array deinterlaced (cant be used as data for indexing i,j)
	function pdat:deinterlace()
		local sizeor = w*h*p
		local deint = ffi.new("float[?]",sizeor)
		local ideint = 0
		for plane = 0,p-1 do
			for np=0,self.npix-1 do
				deint[ideint] = self:lpix(np)[plane]
				ideint = ideint + 1
			end
		end
		return deint
	end
	--sets data from deinterlaced version
	function pdat:interlace(deint)
		local size = w*h*p
		local ideint = 0
		for plane = 0,p-1 do
			for np=0,self.npix-1 do
				self:lpix(np)[plane] = deint[ideint]
				ideint = ideint + 1
			end
		end
	end
	function pdat:get_pixel(x,y)
		assert(x<w and y<h)
		local pixel = {}
		for i=0,p-1 do
			--pixel[i+1] = data[y*w*p + x + i]
			pixel[i+1] = data[(x+ y*w)*p +i]
		end
		return pixel
	end
	local zero = ffi.new("float[?]",p)
	pdat.zero = zero
	function pdat:pixCheck(x,y)
		if x<0 or x>=w or y<0 or y>=h then error"bad index" end
		return data + (x+ y*w)*p 
	end
	function pdat:pix(x,y)
		if x<0 or x>=w or y<0 or y>=h then return zero end
		return data + (x+ y*w)*p 
	end
	pdat.get_pix = pdat.pix --alias
	function pdat:pixR(x,y)
		return data + (x+ y*w)*p 
	end
	function pdat:lpix(n)
		return data + n*p
	end
	local floor = math.floor
	function pdat:lpixTOij(np)
		local row = floor(np/w)
		local col = np - row * w
		return col, row
	end
	--pdat.pix = pdat.get_pix
	function pdat:set_pixel(pixel,x,y)
		assert(x<w and y<h)
		assert(#pixel == p)
		for i=0,p-1 do
			--data[y*w*p + x + i] = pixel[i+1]
			data[(y*w + x)*p + i] = pixel[i+1]
		end
	end
	function pdat:set_pix(pixel,x,y)
		assert(x<w and y<h)
		for i=0,p-1 do
			data[(y*w + x)*p + i] = pixel[i]
		end
	end
	function pdat:save(filename)
		M.save(filename,self.data,w,h,p)
	end
	function pdat:same_dims()
		local pData = ffi.new("float[?]",w*h*p)
		return M.pixel_data(pData,w,h,p)
	end
	function pdat:flipV()
		local pdf = self:same_dims()
		print("flipV",w,h,p)
		for y = 0,h-1 do
			for x = 0,w-1 do
				local pix = self:get_pixel(x,h-1-y)
				pdf:set_pixel(pix,x,y)
			end
		end
		return pdf
	end
	function pdat:flipV_inplace()
		local dat = M.flip_vertical(self.data,w,h,p)
		self.data = dat
		data = dat
	end
	function pdat:totex(GL)
		local pData,width,height,bitplanes = self.data,w,h,p
		local formats = { glc.GL_RED, glc.GL_RG, glc.GL_RGB, glc.GL_RGBA}
		local int_formats = { glc.GL_R32F, glc.GL_RG32F, glc.GL_RGB32F, glc.GL_RGBA32F}
		local tex = GL:Texture(width,height)
	
		gl.glBindTexture(glc.GL_TEXTURE_2D, tex.tex)
		gl.glTexImage2D(glc.GL_TEXTURE_2D,0, int_formats[bitplanes], width,height, 0, formats[bitplanes], glc.GL_FLOAT, pData)
		return tex
	end
	return pdat
end

function M.load_im(fname,unpacked)
	local imag = im.FileImageLoadBitmap(fname)
	if (imag==nil) then
		print ("Unnable to open the file: " .. fname)
		error("23")
	end
	return M.pixel_data(M.tofloat(imag,unpacked))
end

function M.vicimag2tex(filename,GL,tex)

	local pData,width,height,bitplanes = M.load(filename)
	local formats = { glc.GL_RED, glc.GL_RG, glc.GL_RGB, glc.GL_RGBA}
	local int_formats = { glc.GL_R32F, glc.GL_RG32F, glc.GL_RGB32F, glc.GL_RGBA32F}
	local tex = tex or GL:Texture(width,height)

	gl.glBindTexture(glc.GL_TEXTURE_2D, tex.tex)
	gl.glTexImage2D(glc.GL_TEXTURE_2D,0, int_formats[bitplanes], width,height, 0, formats[bitplanes], glc.GL_FLOAT, pData)
	return tex
end
--loading flow data from slowmoVideo
function M.optflow2tex(flowfile,tex)
	local magicNumber = "flow_sV"
	
	local pFile = ffi.C.fopen(flowfile, "rb");
	if (pFile == nil) then error("could not load "..tostring(flowfile)) end

	local magic = ffi.new("char[?]",#magicNumber)
	ffi.C.fread(magic, ffi.sizeof"char", #magicNumber, pFile);
	assert(ffi.string(magic,#magicNumber) == magicNumber)
	
	local version = ffi.new"char[1]"
	ffi.C.fread(version, ffi.sizeof"char", 1, pFile);
	assert(version[0] == 1)
	
	local width = ffi.new"int[1]"
	ffi.C.fread(width, ffi.sizeof"int", 1, pFile);
	local height = ffi.new"int[1]"
	ffi.C.fread(height, ffi.sizeof"int", 1, pFile);
	
	local datasize = width[0]*height[0]*2
	
	local pData = ffi.new("float[?]",datasize)
	local retsize = ffi.C.fread(pData, ffi.sizeof"float", datasize, pFile);
	assert(retsize == datasize,"problem loading compressed file")
	ffi.C.fclose(pFile);
	
	local rpData = M.flip_vertical(pData,width[0],height[0],2)
	--get values
	--[[
	local maxv,minv = -math.huge,math.huge
	for i=0,datasize-1 do
		maxv = (pData[i] > maxv) and pData[i] or maxv
		minv = (pData[i] < minv) and pData[i] or minv
	end
	print("max-min",minv,maxv)
	--]]
	local tex = tex or Texture(width[0],height[0])

	gl.glBindTexture(glc.GL_TEXTURE_2D, tex.tex)
	gl.glTexImage2D(glc.GL_TEXTURE_2D,0, glc.GL_RGBA32F, width[0],height[0], 0, glc.GL_RG, glc.GL_FLOAT, rpData)
	return tex
end

--[=[
local GL = GLcanvas{H=600,aspect=1}
local tex
function GL.init()
	--tex = Texture():Load[[c:/luagl/media/fandema1_cara.png]]
	local pd = M.load_im[[c:/luagl/media/fandema1_cara.png]]
	prtable(pd)
	local pdf = pd:flipV()
	prtable(pdf)
	tex = pdf:totex(GL)
end
function GL.draw(t,w,h)
	ut.Clear()
	tex:drawcenter(w,h)
end
GL:start()
--]=]

return M