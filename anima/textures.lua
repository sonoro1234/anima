local imffi = im.imffi

local function set_table__gc(t, func)
	local prox = newproxy(true)
	getmetatable(prox).__gc = function() func(t) end
	t.gcproxy = prox
	return t --setmetatable(t, mt)
end

--set w,h centered inside width,height
function getAspectViewport(width,height,w,h)
		local GLaspect = w/h
		local aspect = width/height
			
		local newW,newH,xpos,ypos
		if aspect > GLaspect then
			newW,newH = math.floor(height*GLaspect+0.5), height
		elseif aspect < GLaspect then
			newW,newH = width,math.floor(0.5 + width/GLaspect)
		else
			newW,newH = width, height
		end
		xpos = math.floor(0.5*(width - newW)+0.5)
		ypos = math.floor(0.5*(height - newH)+0.5)
		return xpos,ypos,newW,newH
end
--loading several textures
function LoadTextures(fileNames,GLparams,mipmaps)
	GetGLError"preLoadtextures"
	local timebegin = os.clock()
	GLparams.textures = ffi.new("GLuint[?]",#fileNames)
	GLparams.texdata = {}
	gl.glGenTextures(#fileNames,GLparams.textures)  -- Create The Texture
	local aspect_ratio = {}
	local aniso = ffi.new"float[1]"
	gl.glGetFloatv(glc.GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, aniso);
	for i,fileName in ipairs(fileNames) do
		print("\nbind",fileName)
		gl.glBindTexture(glc.GL_TEXTURE_2D, GLparams.textures[i-1])
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_NEAREST)
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR)
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_LINEAR)
		--gl.TexParameter('TEXTURE_2D','TEXTURE_MIN_FILTER','LINEAR_MIPMAP_NEAREST')
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_NEAREST)
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_LINEAR)
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_NEAREST)
		--gl.TexParameter('TEXTURE_2D','TEXTURE_BORDER_COLOR',{1,0,0,1})
		print("loading",fileName)
		local image = im.FileImageLoadBitmap(fileName)
		if (not image) then
			print ("Unnable to open the file: " .. fileName)
			error("23")
		end
		if not mipmaps then
			gl.glTexImage2D(glc.GL_PROXY_TEXTURE_2D,0, glc.GL_RGB, image:Width(), image:Height(), 0,glc.GL_RGB, glc.GL_UNSIGNED_BYTE, nil)
			local width_conv = ffi.new("GLint[1]")
			gl.glGetTexLevelParameteriv(glc.GL_PROXY_TEXTURE_2D,0,glc.GL_TEXTURE_WIDTH,width_conv)
			local height_conv = ffi.new("GLint[1]") 
			gl.glGetTexLevelParameteriv(glc.GL_PROXY_TEXTURE_2D,0,glc.GL_TEXTURE_HEIGHT,height_conv)
			print(image:Width(),image:Height(),"proposed",width_conv[0],height_conv[0])
			if width_conv[0] ~= image:Width() or height_conv[0] ~= image:Height() then
				local width = width_conv[0]~=0 and width_conv[0] or 2^math.ceil(math.log(image:Width())/math.log(2))
				local height = height_conv[0]~=0 and height_conv[0] or 2^math.ceil(math.log(image:Height())/math.log(2))
				while width_conv==0 and width > 2048 do width = width*0.5 end
				while height_conv==0 and height > 2048 do height = height*0.5 end
				print(width,height)
				
				--_,image = imffi.ProcessResizeNew(image, width, height, 3)
				local im2 = im.ImageCreateBased(image,width,height)
				imffi.ProcessResize(image,im2,3)
				image:Destroy()
				image = im2
			end
		end
		print("GetOpenGLData",fileName)
		local gldata, glformat = image:GetOpenGLData()
		gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT, 1)
		aspect_ratio[i] = image:Width()/image:Height()
		print("Build2DMipmaps",mipmaps,fileName)
		
		if mipmaps then
			local err = glu.gluBuild2DMipmaps(glc.GL_TEXTURE_2D,glc.GL_RGB, image:Width(), image:Height(), glformat, glc.GL_UNSIGNED_BYTE, gldata) 
			if err~= glc.GL_NO_ERROR then error("Error on Build2DMipmaps: "..ffi.string(glu.gluErrorString(err))) end
			--anisotropic filtering
			gl.glTexParameterf(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAX_ANISOTROPY_EXT, aniso[0]);
		else
			gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR)
			gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_LINEAR)
			print(glc.GL_TEXTURE_2D,0, glc.GL_RGB, image:Width(), image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata)
			gl.glTexImage2D(glc.GL_TEXTURE_2D,0, glc.GL_RGB, image:Width(), image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata)
			--gl.TexSubImage2D(0,0,0, image:Width(), image:Height(), glformat, gl.UNSIGNED_BYTE, gldata)
			--gl.TexSubImage2D(level, xoffset, yoffset, width, height, format, type, pixelsUserData)
			local err = gl.glGetError()
			if err and err ~= glc.GL_NO_ERROR then error("Error on Build2DMipmaps: ".. ffi.string(glu.gluErrorString(err))) end
		end
		GLparams.texdata[i] = {width=image:Width(),height=image:Height()}
		-- gldata will be destroyed when the image object is destroyed
		image:Destroy()
	end
	local resident_table = ffi.new("GLboolean[?]",#fileNames)
	gl.glAreTexturesResident(#fileNames,GLparams.textures,resident_table)
	for i=0,#fileNames do -- in ipairs(resident_table) do
		print(i,resident_table[i],fileNames[i+1])
	end
	GetGLError("LOADTEXTURES ")
	print("LOADTEXTURES time",os.clock() -timebegin)
	return aspect_ratio
end

function CubeTexture(GL)
	assert(GL)
	local cubesides = { -- faces of cube texture
        glc.GL_TEXTURE_CUBE_MAP_POSITIVE_X,
        glc.GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
        glc.GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
        glc.GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
        glc.GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
        glc.GL_TEXTURE_CUBE_MAP_NEGATIVE_Z
    }
	GetGLError"cubetexture ini"
	local pTex = ffi.new("GLuint[?]",1)
	gl.glGenTextures(1, pTex);
    if not GL.restricted then gl.glEnable(glc.GL_TEXTURE_CUBE_MAP); end
    gl.glBindTexture(glc.GL_TEXTURE_CUBE_MAP, pTex[0]);
    gl.glTexParameteri(glc.GL_TEXTURE_CUBE_MAP, glc.GL_TEXTURE_WRAP_S,glc.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(glc.GL_TEXTURE_CUBE_MAP, glc.GL_TEXTURE_WRAP_T,glc.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(glc.GL_TEXTURE_CUBE_MAP, glc.GL_TEXTURE_WRAP_R,glc.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(glc.GL_TEXTURE_CUBE_MAP, glc.GL_TEXTURE_MIN_FILTER, glc.GL_LINEAR);
    gl.glTexParameteri(glc.GL_TEXTURE_CUBE_MAP, glc.GL_TEXTURE_MAG_FILTER, glc.GL_LINEAR);
    --gl.glTexParameteri(glc.GL_TEXTURE_CUBE_MAP, glc.GL_GENERATE_MIPMAP, glc.GL_TRUE);
	gl.glBindTexture(glc.GL_TEXTURE_CUBE_MAP, 0);
	GetGLError"cubetexture end"
	local ctex = {tex=pTex[0],pTex=pTex}
	
	
	function ctex:ReLoad(fileName)
		if string.match(fileName, "cmp",-3) then
			error("not done")
			LoadCompressedTotexture( fileName, texture,srgb)
			return
		end
		local image = im.FileImageLoadBitmap(fileName)
			if (not image) then
				print ("Unnable to open the file: " .. fileName)
				error("164")
			end
		
		GetGLError"reloadcube2"
		local imw,imh = image:Width(),image:Height()
		---[[
		assert(imw > imh)
		local wc = imw*0.5
		local offh = (imh-wc)*0.5
		assert(offh >=0)
		print"getting faces"

		local imA = im.ImageCreateBased(image,wc,wc)
		im.ProcessCrop(image, imA, 0, offh)
		local imB = im.ImageCreateBased(image,wc,wc)
		im.ProcessCrop(image, imB, wc, offh)
		local flipA = im.ProcessMirrorNew(imA)
		local flipB = im.ProcessMirrorNew(imB)
		
		--flip upsidedown
		im.ProcessFlip(imA,imA)
		im.ProcessFlip(imB,imB)
		im.ProcessFlip(flipA,flipA)
		im.ProcessFlip(flipB,flipB)
		
		print"getting faces gldata"
		--get gldata
		local gldataA, glformat = imA:GetOpenGLData()
		local gldataB, glformat2 = imB:GetOpenGLData()
		local gldataflipA, _ = flipA:GetOpenGLData()
		local gldataflipB, _ = flipB:GetOpenGLData()
		
		--local datas ={gldataB, gldataflipA, gldataA,gldataA, gldataA,gldataflipB}
		local datas ={gldataB, gldataflipA, nil,nil, gldataA,gldataflipB}
		--local datas ={gldataA, gldataA, nil,nil, gldataA,gldataA}
		local formats ={glformat,glformat,glformat,glformat,glformat,glformat}
		
		print"setting cubemap"
		--]]
		gl.glBindTexture(glc.GL_TEXTURE_CUBE_MAP, self.tex)
		gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT, 1)
		for i=1,6 do
			gl.glTexImage2D (cubesides[i], 0, glc.GL_RGBA, wc,wc, 0, formats[i], glc.GL_UNSIGNED_BYTE, datas[i]);
			--print("glTexImage2D",cubesides[i], 0, glc.GL_RGB, image:Width(),image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata);
		end
		
		GetGLError"reloadcube3"
		-- if(srgb) then
			-- gl.glTexImage2D(glc.GL_TEXTURE_2D,0, glc.GL_SRGB, image:Width(), image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata)
		-- else
			-- gl.glTexImage2D(glc.GL_TEXTURE_2D,0, glc.GL_RGB, image:Width(), image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata)
		-- end
		--gl.glTexSubImage2D(glc.GL_TEXTURE_2D,0,0,0,image:Width(),image:Height(), glformat, glc.GL_UNSIGNED_BYTE, gldata)
		print"image destroy"
		image:Destroy()
		imA:Destroy()
		imB:Destroy()
		flipA:Destroy()
		flipB:Destroy()
		--print("ReloadTexture time",os.clock() - timebegin)
		GetGLError"reloadcube"
		--self:inc_signature()
		return self
	end
	function ctex:ReLoadSq(fileName)
		local tp = require"anima.tex_procs"
		local textureV = Texture():Load(fileName)
		
		local texture = tp.flip(textureV,true,false)
		textureV:delete()
		
		local wc = texture.width*0.5
		local offx = (texture.width - wc)*0.5
		local offy = (texture.height - wc)*0.5
		--first four faces
		local texZM = tp.crop(texture,offx,offy,wc,wc)
		local dataZM = texZM:get_pixels()
		
		local texXm = tp.crop(texture,-offx,offy,wc,wc)
		local dataXm = texXm:get_pixels()
		
		local texXM = tp.crop(texture,offx+wc,offy,wc,wc)
		local dataXM = texXM:get_pixels()
		
		local texZm = tp.flip(texZM,false,true)
		local dataZm = texZm:get_pixels()
		
		texZM:delete()
		texXm:delete()
		texXM:delete()
		texZm:delete()
		--bottom face ------------------
		local texC = tp.crop(texture,offx,offy+wc,wc,wc)
		local ss = tp.crop(texture,-offx,offy+wc,wc,wc)
		local texL = tp.rotate(ss,1)
		ss:delete()
		local ss2 = tp.crop(texture,offx+wc,offy+wc,wc,wc)
		local texR = tp.rotate(ss2,3)
		ss2:delete()
		local ss3 = tp.flip(texC,false,true)
		local texCm = tp.rotate(ss3,2)
		ss3:delete()
		local bottex = tp.fusion(texCm,texR,texC,texL)
		local databot = bottex:get_pixels()
		
		texC:delete()
		texR:delete()
		texL:delete()
		texCm:delete()
		bottex:delete()
		
		--top face ------------------
		local texCm = tp.crop(texture,offx,offy-wc,wc,wc)
		local ssC2 = tp.rotate(texCm,2)
		local texC = tp.flip(ssC2,false,true)
		ssC2:delete()
		
		local ss = tp.crop(texture,-offx,offy-wc,wc,wc)
		local texL = tp.rotate(ss,3)
		ss:delete()
		
		local ss2 = tp.crop(texture,offx+wc,offy-wc,wc,wc)
		local texR = tp.rotate(ss2,1)
		ss2:delete()
		
		
		--local tR = tp.color({1,0,0,1},wc,wc)
		--local toptex = tp.fusion(texCm,texR,texC,texL)
		local toptex = tp.fusion(texCm,texR,texC,texL)
		--local toptex = texL
		local datatop = toptex:get_pixels()
		
		texC:delete()
		texR:delete()
		texL:delete()
		texCm:delete()
		toptex:delete()
		-------------------------------------
		texture:delete()
		-----------------------------------
		local datas ={dataXM, dataXm, datatop,databot, dataZM,dataZm}
		--local datas ={dataXM, dataXm, nil,nil, dataZM,dataZm}

		print"setting cubemap"
		
		gl.glBindTexture(glc.GL_TEXTURE_CUBE_MAP, self.tex)
		gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT, 1)
		for i=1,6 do
			gl.glTexImage2D (cubesides[i], 0, glc.GL_RGBA, wc,wc, 0, glc.GL_RGBA, glc.GL_UNSIGNED_BYTE, datas[i]);
		end
		
		GetGLError"reloadcube3"

		--self:inc_signature()
		return self
	end
	function ctex:ReLoadCube(fileName)

		if string.match(fileName, "cmp",-3) then
			error("not done")
			LoadCompressedTotexture( fileName, texture,srgb)
			return
		end
		local image = im.FileImageLoadBitmap(fileName)
			if (not image) then
				print ("Unnable to open the file: " .. fileName)
				error("164")
			end
		
		GetGLError"reloadcube2"
		local imw,imh = image:Width(),image:Height()
		---[[
		assert(imw*6 == imh)
		local wc = imw
		local offh = wc
		assert(offh >=0)
		print"getting faces"
		
		im.ProcessFlip(image,image)
		local faces = {}
		local datas = {}
		local formats = {}
		for i=0,5 do
			faces[i] = im.ImageCreateBased(image,wc,wc)
			im.ProcessCrop(image, faces[i], 0, offh*i)
			local gldataA, glformat = faces[i]:GetOpenGLData()
			datas[i+1] = gldataA
			formats[i+1] = glformat
		end
		
		print"setting cubemap"
		--]]
		gl.glBindTexture(glc.GL_TEXTURE_CUBE_MAP, self.tex)
		gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT, 1)
		for i=1,6 do
			gl.glTexImage2D (cubesides[i], 0, glc.GL_RGBA, wc,wc, 0, formats[i], glc.GL_UNSIGNED_BYTE, datas[i]);
			--print("glTexImage2D",cubesides[i], 0, glc.GL_RGB, image:Width(),image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata);
		end
		
		GetGLError"reloadcube3"
		-- if(srgb) then
			-- gl.glTexImage2D(glc.GL_TEXTURE_2D,0, glc.GL_SRGB, image:Width(), image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata)
		-- else
			-- gl.glTexImage2D(glc.GL_TEXTURE_2D,0, glc.GL_RGB, image:Width(), image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata)
		-- end
		--gl.glTexSubImage2D(glc.GL_TEXTURE_2D,0,0,0,image:Width(),image:Height(), glformat, glc.GL_UNSIGNED_BYTE, gldata)
		print"image destroy"
		image:Destroy()
		for i=0,5 do
			faces[i]:Destroy()
		end
		--print("ReloadTexture time",os.clock() - timebegin)
		GetGLError"reloadcube"
		--self:inc_signature()
		return self
	end
	function ctex:LoadFolder(folder)
		local fileNames = {"posx","negx","posy","negy","posz","negz"}
		gl.glBindTexture(glc.GL_TEXTURE_CUBE_MAP, self.tex)
		gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT, 1)
		for i=1,6 do
			local image = im.FileImageLoadBitmap(folder..fileNames[i]..".jpg")
			 im.ProcessFlip(image,image)
			local gldata, glformat = image:GetOpenGLData()
			gl.glTexImage2D (cubesides[i], 0, glc.GL_RGBA, image:Width(),image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata);
			image:Destroy()
			--print("glTexImage2D",cubesides[i], 0, glc.GL_RGB, image:Width(),image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata);
		end
		gl.glTexParameteri(glc.GL_TEXTURE_CUBE_MAP,glc.GL_TEXTURE_MAG_FILTER,glc.GL_LINEAR)
		gl.glTexParameteri(glc.GL_TEXTURE_CUBE_MAP,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_LINEAR)
		glext.glGenerateMipmap(glc.GL_TEXTURE_CUBE_MAP);
		return self
	end
	function ctex:Bind(i)
		glext.glActiveTexture(glc.GL_TEXTURE0 + (i or 0));
		gl.glBindTexture(glc.GL_TEXTURE_CUBE_MAP, self.tex)
	end
	return ctex
end

--loads RGB 16 bits only
local function LoadGL16(fileName)
	print("LoadGL16",fileName)
	local function checkError(err)
			if (err and err ~= imffi.IM_ERR_NONE) then
				print(filename,err)
				error(im.ErrorStr(err))
			end
		end
	local err = ffi.new("int[1]")
	local image = imffi.imFileImageLoad(fileName, 0, err)
	checkError(err[0])
	assert(image.data_type == imffi.IM_USHORT or image.data_type == imffi.IM_SHORT)
	assert(image.color_space == imffi.IM_RGB)
	local transp_color = imffi.imImageGetAttribute(image, "TransparencyColor", nil, nil);
	local glformat,gldepth
	if (image.has_alpha~=0 or (transp_color~=nil)) then
		glformat = glc.GL_RGBA;
		gldepth = 4
    else
		glformat = glc.GL_RGB;
		gldepth = 3
	end
	
	local srcdepth = image.depth;
	if (image.has_alpha~=0) then srcdepth = srcdepth + 1 end
	
	local gldata = ffi.new("unsigned short[?]",image.count*gldepth)
	if transp_color~=nil then
		error"must implement iImageGLSetTranspColor"
	end
	print("goes to paking",image.count,gldepth,srcdepth,transp_color,image.has_alpha)
	--convert packing
	local dst_data = gldata
	local src_data = ffi.cast("unsigned short*",image.data[0])
	local count = image.count
	--[[
	for i = 0,count-1 do
		for d = 0,srcdepth -1 do
			--*(dst_data + d) = *(src_data + d*count);
			dst_data[d] = src_data[d*count]
		end

		dst_data = dst_data + gldepth;
		src_data = src_data + 1;
	end
	--]]
	for i = 0,count-1 do
		for d = 0,srcdepth -1 do
			dst_data[d + gldepth*i] = src_data[i+d*count]
		end
	end
	print"end paking"
	imffi.imImageDestroy(image)

	return gldata, glformat
end

local function ReLoadTexture(fileName,texture,srgb,tex)
	--print("ReLoadTexture")
	local rgbf  --= srgb and glc.GL_SRGB or glc.GL_RGB

	if string.match(fileName, "cmp",-3) then
		return LoadCompressedTotexture( fileName, texture,srgb)
	end
	local image,err = im.FileImageLoad(fileName) --imffi.FileImageLoadBitmap(fileName)
		if (image==nil) then
			print ("Unnable to open the file:", fileName)
			error(im.ErrorStr(err))
		end
	
	local gldata, glformat
	local w,h = image:Width(), image:Height()
	--print(fileName,w,h)
	local datatype
	if image:DataType() == im.USHORT or image:DataType() == im.SHORT then --16bits
		datatype = glc.GL_UNSIGNED_SHORT
		image:Destroy()
		image = nil
		gldata, glformat = LoadGL16(fileName)
	else
		assert(image:DataType()==im.BYTE,im.DataTypeName(image:DataType()))
		datatype = glc.GL_UNSIGNED_BYTE
		gldata, glformat = image:GetOpenGLData()
	end
	
	if not srgb then
		if glformat == glc.GL_RGB then 
			rgbf = glc.GL_RGBA32F --glc.GL_RGB32F
		elseif glformat == glc.GL_RGBA then
			rgbf = glc.GL_RGBA32F
		elseif glformat == glc.GL_LUMINANCE then
			rgbf = glc.GL_RGBA32F --glc.GL_LUMINANCE --glc.GL_RED --glc.GL_RGBA32F --glformat
			if tex.GL.restricted then
				glformat = glc.GL_RED
				local swizzleMask = ffi.new("GLint[4]",{glc.GL_RED, glc.GL_RED, glc.GL_RED, glc.GL_ONE})
				gl.glTexParameteriv(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_SWIZZLE_RGBA, swizzleMask);
			end
		else
			local datatype = image and image:DataType()
			print("glformat",glformat,gldata,ToStr(swapped_glc[glformat]),im.DataTypeName(datatype))
			rgbf = glformat
			error("unknown file format:"..tostring(fileName))
		end
	else
		if glformat == glc.GL_RGB then 
			rgbf = glc.GL_SRGB_ALPHA --glc.GL_SRGB
		elseif glformat == glc.GL_RGBA then
			rgbf = glc.GL_SRGB_ALPHA
		else
			error("unknown file format")
		end
	end
	--print(fileName,"format",glformat)
	--print("formats",glc.GL_RGB,glc.GL_RGBA,glc.GL_SRGB,glc.GL_SRGB_ALPHA)
	gl.glBindTexture(glc.GL_TEXTURE_2D, texture)
	gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT, 1)
	
	-- if mipmaps then
			-- gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_LINEAR)
			-- gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_LINEAR)
			-- local err = glu.gluBuild2DMipmaps(glc.GL_TEXTURE_2D, rgbf, w, h, glformat, datatype, gldata) 
			-- if err~= glc.GL_NO_ERROR then error("Error on Build2DMipmaps: "..ffi.string(glu.gluErrorString(err))) end
	-- else
		gl.glTexImage2D(glc.GL_TEXTURE_2D,0, rgbf, w, h, 0, glformat, datatype, gldata)
	-- end

	if image then image:Destroy() end
	gldata = nil
	return w,h,rgbf,glformat,datatype
end

local tex_progs = {}
local mesh = require"anima.mesh"
--makes a context dependent prog for show textures
local function make_tex_prog()
	local P3 = {}
	function P3:init()
		local vert_shad = [[
	in vec3 Position;
	in vec2 texcoord;
	out vec2 texcoordf;
	void main()
	{
		texcoordf = texcoord;
		gl_Position = vec4(Position,1);
	}
	
	]]
	local frag_shad = [[
	uniform sampler2D tex0;
	in vec2 texcoordf;
	void main()
	{

		gl_FragColor = texture(tex0,texcoordf);
	}
	]]
	
		self.program = GLSL:new():compile(vert_shad,frag_shad)
		--prtable(mesh)
		local m = mesh.quad(-1,-1,1,1)
		self.vao = VAO({Position=m.points,texcoord=m.texcoords},self.program,m.indexes)
		print"tex_prog compiled"
		self.inited = true
	end
	function P3:draw(w,h)
		--print("P3:draw",w,h)
		if not self.inited then self:init() end
		self.program:use()
		self.program.unif.tex0:set{0}
		gl.glViewport(0,0,w,h)
		self.vao:draw_elm()
		glext.glUseProgram(0)
	end
	function P3:drawpos(x,y,w,h)
		--print("P3:drawpos",x,y,w,h)
		if not self.inited then self:init() end
		self.program:use()
		self.program.unif.tex0:set{0}
		gl.glViewport(x,y,w,h)
		self.vao:draw_elm()
		glext.glUseProgram(0)
	end
	return P3
end
local tex_progsSRGB = {}
local function make_tex_progSRGB()
	local P3 = {}
	function P3:init()
		local vert_shad = [[
	in vec3 Position;
	in vec2 texcoord;
	out vec2 texcoordf;
	void main()
	{
		texcoordf = texcoord;
		gl_Position = vec4(Position,1);
	}
	
	]]
	local frag_shad = require"anima.GLSL.GLSL_color"..[[
	in vec2 texcoordf;
	uniform sampler2D tex0;
	void main()
	{
		vec4 color = texture2D(tex0,texcoordf);
		gl_FragColor = vec4(RGB2sRGB(color.rgb),color.a);
	}
	]]
	
		self.program = GLSL:new():compile(vert_shad,frag_shad)
		local m = mesh.quad(-1,-1,1,1)
		self.vao = VAO({Position=m.points,texcoord=m.texcoords},self.program,m.indexes)
		print"tex_progSRGB compiled"
		self.inited = true
	end
	function P3:draw(w,h)
		if not self.inited then self:init() end
		self.program:use()
		self.program.unif.tex0:set{0}
		gl.glViewport(0,0,w,h)
		self.vao:draw_elm()
		glext.glUseProgram(0)
	end
	function P3:drawpos(x,y,w,h)
		if not self.inited then self:init() end
		self.program:use()
		self.program.unif.tex0:set{0}
		gl.glViewport(x,y,w,h)
		self.vao:draw_elm()
		glext.glUseProgram(0)
	end
	return P3
end
local tex_greyprogs = {}
local function make_tex_greyprog()
	local P3 = {}
	function P3:init()
		local vert_shad = [[
	in vec3 Position;
	in vec2 texcoord;
	out vec2 texcoordf;
	void main()
	{
		texcoordf = texcoord;
		gl_Position = vec4(Position,1);
	}
	
	]]
	local frag_shad = [[

	uniform sampler2D tex0;
	uniform vec4 mask = vec4( 0.30, 0.59, 0.11,0.0);
	in vec2 texcoordf;
	void main()
	{
		vec4 color = texture2D(tex0,texcoordf);
		float lum = dot(color,mask);
		gl_FragColor = vec4(vec3(lum),color.a);
	}
	]]
	
		self.program = GLSL:new():compile(vert_shad,frag_shad)
		local m = mesh.quad(-1,-1,1,1)
		self.vao = VAO({Position=m.points,texcoord=m.texcoords},self.program,m.indexes)
		print"tex_greyprog compiled"
		self.inited = true
	end
	function P3:draw(w,h,mask)
		mask = mask or {0.30, 0.59, 0.11,0}
		if not self.inited then self:init() end
		self.program:use()
		self.program.unif.tex0:set{0}
		self.program.unif.mask:set(mask)
		gl.glViewport(0,0,w,h)
		self.vao:draw_elm()
		glext.glUseProgram(0)
	end

	return P3
end

local tex_negprogs = {}
local function make_tex_negprog()
	local P3 = {}
	function P3:init()
		local vert_shad = [[
	in vec3 Position;
	in vec2 texcoord;
	out vec2 texcoordf;
	void main()
	{
		texcoordf = texcoord;
		gl_Position = vec4(Position,1);
	}
	
	]]
	local frag_shad = [[
	uniform sampler2D tex0;
	in vec2 texcoordf;
	void main()
	{
		vec4 color = texture2D(tex0,texcoordf);
		gl_FragColor = vec4(vec3(1.0-color.r,1.0-color.g,1.0-color.b),color.a);
	}
	]]
		self.program = GLSL:new():compile(vert_shad,frag_shad)
		local m = mesh.quad(-1,-1,1,1)
		self.vao = VAO({Position=m.points,texcoord=m.texcoords},self.program,m.indexes)
		print"tex_negprog compiled"
		self.inited = true
	end
	function P3:process(w,h)
		if not self.inited then self:init() end
		self.program:use()
		self.program.unif.tex0:set{0}
		gl.glViewport(0,0,w,h)
		self.vao:draw_elm()
		glext.glUseProgram(0)
	end

	return P3
end

function Texture1D(w,formato,data,format,type,args)
	assert(args.GL)
	formato = formato or glc.GL_RGB
	format = format or formato
	type = type or glc.GL_FLOAT
	
	local tex = {width=w,internal_format= formato,GL=args.GL}
	tex.pTex = ffi.new("GLuint[?]",1)
	gl.glGenTextures(1,tex.pTex) 
	gl.glBindTexture(glc.GL_TEXTURE_1D, tex.pTex[0])
	gl.glTexParameteri(glc.GL_TEXTURE_1D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR)
	gl.glTexParameteri(glc.GL_TEXTURE_1D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_LINEAR)
	gl.glTexParameteri(glc.GL_TEXTURE_1D, glc.GL_TEXTURE_WRAP_S, glc.GL_CLAMP_TO_EDGE);
	gl.glTexImage1D(glc.GL_TEXTURE_1D,0, formato, w, 0, format, type, data)
	tex.tex = tex.pTex[0]
	function tex:Bind(n)
		n = n or 0
		glext.glActiveTexture(glc.GL_TEXTURE0 + n);
		if not self.GL.restricted then gl.glEnable( glc.GL_TEXTURE_1D ); end
		gl.glBindTexture(glc.GL_TEXTURE_1D, self.tex)
	end
	function tex:set_data(data, format,type)
		type = type or glc.GL_FLOAT
		format = format or self.internal_format
		gl.glBindTexture(glc.GL_TEXTURE_1D, self.tex)
		gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT, 1)
		gl.glTexImage1D(glc.GL_TEXTURE_1D,0, self.internal_format, w, 0, format, type, data)
	end
	return tex
end
function Texture(w,h,formato,pTexor,args)
	assert(args)
	if not args then print("texture witout context") end
	--args = args or {GL={}}
	w = w or 1
	h = h or 1
	formato = formato or glc.GL_RGBA
	local tex = {aspect= w/h,width=w,height=h,isTex2D=true,instance=0,formato=formato,GL=args.GL}
	
	if not pTexor then
		tex.pTex = ffi.new("GLuint[?]",1)
		gl.glBindTexture(glc.GL_TEXTURE_2D,0); --https://stackoverflow.com/questions/18641988/broken-texture-number-opengl-after-glgentextures-glbindtexture/18652534
		gl.glGenTextures(1,tex.pTex) 
		gl.glBindTexture(glc.GL_TEXTURE_2D, tex.pTex[0])
		tex.GL:addTexture(tex.pTex[0],"Texture "..tostring(tex))
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR)
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_LINEAR)
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, glc.GL_MIRRORED_REPEAT);
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, glc.GL_MIRRORED_REPEAT);
		gl.glTexImage2D(glc.GL_TEXTURE_2D,0, formato, w, h, 0, glc.GL_RGB, glc.GL_UNSIGNED_BYTE, nil)
		tex.tex = tex.pTex[0]
		--print("new tex2d",tex.tex,tex)
	else
		tex.pTex = pTexor
		tex.tex = pTexor[0]
		--print("new tex2d from pTexor",tex.tex,tex)
	end
	--assert(tex.tex == tex.pTex[0])
	function tex:is_texture()
		return gl.glIsTexture(self.tex)==glc.GL_TRUE
	end
	
	function tex:delete()
		--assert(GL.window==glfw.glfwGetCurrentContext())
		--assert(not self.isdeleted)
		--print("tex:delete isdeleted", self.isdeleted,"contex good",GL:checkcontext(),"tex:",self.tex,self)
		--prtable("tex:delete from", debug.getinfo(4,"Sl"))
		gl.glDeleteTextures(1,tex.pTex) 
		self.GL:removeTexture(tex.pTex[0])
		--avoid _gc after manual delete
		getmetatable(self.gcproxy).__gc = nil
		self.isdeleted = true
	end
	
	function tex:set_data(pData,bitplanes, intbitplanes)
		bitplanes = bitplanes or 3
		intbitplanes = intbitplanes or bitplanes
		local formats = { glc.GL_RED, glc.GL_RG, glc.GL_RGB, glc.GL_RGBA}
		local int_formats = { glc.GL_R32F, glc.GL_RG32F, glc.GL_RGB32F, glc.GL_RGBA32F}
		local types = {[glc.GL_FLOAT] = "float[?]", [glc.GL_UNSIGNED_SHORT]="unsigned short[?]",[glc.GL_UNSIGNED_BYTE]="unsigned char[?]"}
		local type
		for k,v in pairs(types) do
			if ffi.istype(v,pData) then type=k;break end
		end
		--print("set_data type",swapped_glc[type])
		assert(type)
		self:Bind()
		gl.glTexImage2D(glc.GL_TEXTURE_2D,0, int_formats[intbitplanes], self.width,self.height, 0, formats[bitplanes], type, pData)
		return tex
	end
	function tex:Load(filename,srgb,mipmaps)
		srgb = srgb or (self.GL and self.GL.SRGB)
		mipmaps = mipmaps or (self.GL and self.GL.mipmaps)
		if self.GL and self.GL.loaded_files then
			self.GL.loaded_files[filename] = true
		end
		--assert(mipmaps)
		self.width,self.height,self.internal_format,self.formato,self.datatype = ReLoadTexture(filename,self.tex,srgb,self) --,mipmaps)
		self.aspect = self.width/self.height
		self.filename = filename
		--
		if mipmaps then
			self:Bind()
			self:gen_mipmap()
		end
		self:inc_signature()
		return self
	end
	function tex:mag_filter(mode)
		--self:Bind()
		 --ati bug
		if not self.GL.restricted then gl.glEnable( glc.GL_TEXTURE_2D ); end
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,mode)
	end
	function tex:min_filter(mode)
		--self:Bind()
		 --ati bug
		if not self.GL.restricted then gl.glEnable( glc.GL_TEXTURE_2D ); end
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,mode)
	end
	function tex:gen_mipmap()
		--self:Bind(n)
		
		 --ati bug
		if not self.GL.restricted then gl.glEnable( glc.GL_TEXTURE_2D ); end
		glext.glGenerateMipmap(glc.GL_TEXTURE_2D)
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_LINEAR)
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_NEAREST_MIPMAP_LINEAR)
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_NEAREST_MIPMAP_NEAREST)
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_NEAREST)
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_LINEAR)
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_LINEAR)
	end
	function tex:Bind(n)
		n = n or 0
		--local modewrap = glc.GL_MIRRORED_REPEAT --glc.GL_CLAMP --glc.GL_REPEAT --glc.GL_MIRRORED_REPEAT
		glext.glActiveTexture(glc.GL_TEXTURE0 + n);
		if not self.GL.restricted then gl.glEnable( glc.GL_TEXTURE_2D ); end
		gl.glBindTexture(glc.GL_TEXTURE_2D, self.tex)
		--gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
		--gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
	end

	function tex:set_aniso(val)
		local aniso = ffi.new"float[1]"
		gl.glBindTexture(glc.GL_TEXTURE_2D, self.tex);
		if not val then
			gl.glGetFloatv(glc.GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, aniso);
		else
			aniso[0] = val
		end
		gl.glTexParameterf(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAX_ANISOTROPY_EXT, aniso[0]);
	end
	function tex:set_border(t)
		--self:Bind()
		gl.glTexParameterfv(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_BORDER_COLOR,ffi.new("float[4]",t))
	end
	function tex:set_wrap(modewrap)
		modewrap = modewrap or glc.GL_MIRRORED_REPEAT
		--gl.glBindTexture(glc.GL_TEXTURE_2D, self.tex)
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, modewrap); 
		gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, modewrap);
	end
	function tex:make_slab()
		local slab = {isSlab=true}
		slab.ping = self.GL:initFBO({no_depth=true},self.width, self.height)--,color_tex = self.pTex})
		slab.pong = self.GL:initFBO({no_depth=true},self.width, self.height)
		function slab:init() --copy tex to ping
			self.ping:Bind()
			tex:blit()
			self.ping:UnBind()
		end
		function slab:process(proc, srctex)
			srctex = srctex or slab.ping:tex()	
			local w,h = srctex.width,srctex.height
			slab.pong:Bind()
			proc(srctex)
			slab.pong:UnBind()
			slab:swapt()
		end
		function slab:swapt()
			 self.ping,self.pong = self.pong,self.ping
		end
		function slab:tex()
			return self.ping:tex()
		end
		return slab
	end
	function tex:make_slabMS()
		local slab = {isSlab=true}
		slab.pong = GL:initFBOMultiSample(nil,self.width, self.height)--,color_tex = self.pTex})
		slab.ping = self.GL:initFBO({no_depth=true},self.width, self.height)
		function slab:swapt()
			slab.pong:Dump(slab.ping.fb[0])
			--self.ping,self.pong = self.pong,self.ping
		end
		return slab
	end
	function tex:make_chain(t)
		local N = #t
		local function mod(a,b)
			return ((a-1)%b)+1
		end
		local chain = {}
		local curr = 1
		for i=1,N do
			chain[i] = self.GL:initFBO{no_depth=true}
		end
		function chain:current()
			return chain[curr]
		end
		function chain:inc()
			curr = mod(curr + 1,N)
		end
		function chain:process( srctex)
			for i=1,N do
			t[i]:process_fbo(chain[i],i == 1 and srctex or chain[i-1]:tex())
			curr = i
			end
		end
		function chain:tex()
			--print("chain tex",curr)
			return self[curr]:tex()
		end
		return chain
	end
	function tex:make_fbo()
		return self.GL:initFBO({no_depth=true},self.width, self.height)
	end
	-- tostring for using cdata as key
	local ctx
	if glfw then
		ctx = tostring(glfw.glfwGetCurrentContext())
	else
		ctx = tostring(sdl.gL_GetCurrentContext())
	end
	local prog = tex_progs[ctx] or make_tex_prog()
	tex_progs[ctx] = prog
	local progSRGB = tex_progsSRGB[ctx] or make_tex_progSRGB()
	tex_progsSRGB[ctx] = progSRGB
	local greyprog = tex_greyprogs[ctx] or make_tex_greyprog()
	tex_greyprogs[ctx] = greyprog
	local negprog = tex_negprogs[ctx] or make_tex_negprog()
	tex_negprogs[ctx] = negprog
	
	function tex:get_pixels(type,format)
		type = type or glc.GL_UNSIGNED_BYTE
		format = format or glc.GL_RGBA
		local types = {[glc.GL_FLOAT] = "float[?]", [glc.GL_UNSIGNED_SHORT]="unsigned short[?]",[glc.GL_UNSIGNED_BYTE]="unsigned char[?]"}
		local formats = {[glc.GL_RED]=1,[glc.GL_RGB]=3,[glc.GL_RGBA]=4}
		local ncomponents = formats[format]		
		local allocstr = types[type]
		
		self:Bind()
		local w,h = self.width, self.height
		local pixelsUserData = ffi.new(allocstr,w*h*ncomponents) 
		
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER,0)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glGetTexImage(glc.GL_TEXTURE_2D, 0, format, type, pixelsUserData)
		return pixelsUserData
	end
	function tex:save(filename,formato)
		formato = formato or "PNG"
		local pixelsUserData = self:get_pixels()
		local image = im.ImageCreateFromOpenGLData(w, h, glc.GL_RGBA, pixelsUserData); 
		local err = image:FileSave(filename,formato)
		if (err and err ~= im.ERR_NONE) then
			print("saved",filename)
			error(im.ErrorStr(err))
		end
		image:Destroy()
	end
	function tex:blit(w,h)
		w = w or self.width
		h = h or self.height
		self:Bind(0)
		prog:draw(w,h)
	end
	function tex:drawcenter(W,H)
		self:Bind(0)
		prog:drawpos(getAspectViewport(W or self.GL.W,H or self.GL.H,self.width, self.height))
	end
	function tex:drawpos(x,y,w,h)
		self:Bind(0)
		prog:drawpos(x,y,w,h)
	end
	function tex:drawposSRGB(x,y,w,h)
		self:Bind(0)
		progSRGB:drawpos(x,y,w,h)
	end
	function tex:draw(t,w,h)
		ut.Clear()
		self:blit(w,h)
	end
	function tex:togrey(w,h,mask)
		ut.Clear()
		self:Bind(0)
		greyprog:draw(w or self.width,h or self.height,mask)
	end
	--as plugin:process_tex
	function tex:make_grey(mask)
		local fbo = self.GL:get_fbo()
		fbo:Bind()
		self:togrey(nil,nil,mask)
		fbo:UnBind()
		return fbo
		--fbo:release()
		--return fbo:texcopy()
	end
	function tex:neg()
		self:Bind()
		negprog:process(self.width,self.height)
	end

	function tex:make_neg()
		local fbo = self.GL:get_fbo()
		fbo:Bind()
		self:neg()
		fbo:UnBind()
		return fbo:tex()
		-- fbo:release()
		-- return fbo:texcopy()
	end
	function tex:resample(w,h)
		local resfbo = self.GL:initFBO({no_depth=true},w,h)
		resfbo:Bind()
		self:Bind()
		self:gen_mipmap()
		self:drawcenter(resfbo.w,resfbo.h)
		resfbo:UnBind()
		local tex = resfbo:tex()
		resfbo:delete(true) --keep texture
		return tex
	end
	function tex:resize(w,h)
		local resfbo = self.GL:initFBO({no_depth=true},w,h)
		resfbo:Bind()
		self:Bind()
		self:gen_mipmap()
		self:drawpos(0,0,resfbo.w,resfbo.h)
		resfbo:UnBind()
		local tex = resfbo:tex()
		resfbo:delete(true) --keep texture
		return tex
	end
	function tex:resample_fac(f)
		return self:resample(math.floor(self.width*f+0.5),math.floor(self.height*f+0.5))
	end
	function tex:inc_signature()
		self.instance = self.instance + 1
	end
	function tex:get_signature()
		return tostring(self)..self.instance
	end
	set_table__gc(tex,function(t) t:delete() end)
	return tex
end
function LoadTextures2(fileNames,GLparams,mipmaps)
	GetGLError"preLoadtextures"
	local timebegin = os.clock()
	local textures = ffi.new("GLuint[?]",#fileNames)
	local texdata = {}
	gl.glGenTextures(#fileNames,textures)  -- Create The Texture
	local aspect_ratio = {}
	for i,fileName in ipairs(fileNames) do
		print("\nbind",fileName)
		gl.glBindTexture(glc.GL_TEXTURE_2D, textures[i-1])
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_NEAREST)
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR)
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR_MIPMAP_LINEAR)
		--gl.TexParameter('TEXTURE_2D','TEXTURE_MIN_FILTER','LINEAR_MIPMAP_NEAREST')
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_NEAREST)
		gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_LINEAR)
		--gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_NEAREST)
		--gl.TexParameter('TEXTURE_2D','TEXTURE_BORDER_COLOR',{1,0,0,1})
		print("loading",fileName)
		local image = im.FileImageLoadBitmap(fileName)
		if (not image) then
			print ("Unnable to open the file: " .. fileName)
			error("364")
		end
		if not mipmaps then
			gl.glTexImage2D(glc.GL_PROXY_TEXTURE_2D,0, glc.GL_RGB, image:Width(), image:Height(), 0,glc.GL_RGB, glc.GL_UNSIGNED_BYTE, nil)
			local width_conv = ffi.new("GLint[1]")
			gl.glGetTexLevelParameteriv(glc.GL_PROXY_TEXTURE_2D,0,glc.GL_TEXTURE_WIDTH,width_conv)
			local height_conv = ffi.new("GLint[1]") 
			gl.glGetTexLevelParameteriv(glc.GL_PROXY_TEXTURE_2D,0,glc.GL_TEXTURE_HEIGHT,height_conv)
			print(image:Width(),image:Height(),"proposed",width_conv[0],height_conv[0])
			if width_conv[0] ~= image:Width() or height_conv[0] ~= image:Height() then
				local width = width_conv[0]~=0 and width_conv[0] or 2^math.ceil(math.log(image:Width())/math.log(2))
				local height = height_conv[0]~=0 and height_conv[0] or 2^math.ceil(math.log(image:Height())/math.log(2))
				while width_conv==0 and width > 2048 do width = width*0.5 end
				while height_conv==0 and height > 2048 do height = height*0.5 end
				print("Resizing",width,height)
				
				--_,image = imffi.ProcessResizeNew(image, width, height, 3)
				local im2 = im.ImageCreateBased(image,width,height)
				imffi.ProcessResize(image,im2,3)
				image:Destroy()
				image = im2
			end
		end
		print("GetOpenGLData",fileName)
		local gldata, glformat = image:GetOpenGLData()
		gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT, 1)
		aspect_ratio[i] = image:Width()/image:Height()
		print("Build2DMipmaps",mipmaps,fileName)
		
		if mipmaps then
			local err = glu.gluBuild2DMipmaps(glc.GL_TEXTURE_2D,glc.GL_RGB, image:Width(), image:Height(), glformat, glc.GL_UNSIGNED_BYTE, gldata) 
			if err~= glc.GL_NO_ERROR then error("Error on Build2DMipmaps: "..ffi.string(glu.gluErrorString(err))) end
		else
			gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR)
			gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_LINEAR)
			print(glc.GL_TEXTURE_2D,0, glc.GL_RGB, image:Width(), image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata)
			gl.glTexImage2D(glc.GL_TEXTURE_2D,0, glc.GL_RGB, image:Width(), image:Height(), 0, glformat, glc.GL_UNSIGNED_BYTE, gldata)
			--gl.TexSubImage2D(0,0,0, image:Width(), image:Height(), glformat, gl.UNSIGNED_BYTE, gldata)
			--gl.TexSubImage2D(level, xoffset, yoffset, width, height, format, type, pixelsUserData)
			local err = gl.glGetError()
			if err and err ~= glc.GL_NO_ERROR then error("Error on glTexImage2D: ".. ffi.string(glu.gluErrorString(err))) end
		end
		texdata[i] = {width=image:Width(),height=image:Height()}
		-- gldata will be destroyed when the image object is destroyed
		image:Destroy()
	end
	local resident_table = ffi.new("GLboolean[?]",#fileNames)
	gl.glAreTexturesResident(#fileNames,textures,resident_table)
	for i=0,#fileNames do -- in ipairs(resident_table) do
		print(i,resident_table[i],fileNames[i+1])
	end
	GetGLError("LOADTEXTURES ")
	print("LOADTEXTURES time",os.clock() -timebegin)
	return textures,texdata,aspect_ratio
end
function ListCompressedFormats()
	local num = ffi.new("GLuint[1]")
	gl.glGetIntegerv(glc.GL_NUM_COMPRESSED_TEXTURE_FORMATS, num)
	local formats = ffi.new("GLuint[?]",num*4)
	gl.glGetIntegerv(glc.GL_COMPRESSED_TEXTURE_FORMATS, num)
end
function ImageConvertToCompressed(image,pathSave)

   -- Again, more error checking.  Here we aren't using
   -- MIPMAPs, so make sure your dimensions are a power of 2.
GetGLError"ImageConvertToCompressed 1"

	local gldata, glformat = image:GetOpenGLData()
	local textureNumber = ffi.new("GLuint[1]")
	gl.glGenTextures(1,textureNumber)
	
   -- Bind to the texture number.
   gl.glBindTexture(glc.GL_TEXTURE_2D, textureNumber[0]);
   gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT, 1);

   -- Define how to scale the texture.
   gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MIN_FILTER, glc.GL_LINEAR);
   gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAG_FILTER, glc.GL_LINEAR);
GetGLError"ImageConvertToCompressed 2"
   -- Figure out what our image format is (alpha?)
   local  internalFormat;
   if (glformat == glc.GL_RGB) then
      internalFormat = glc.GL_COMPRESSED_RGB_S3TC_DXT1_EXT;
   elseif (glformat == glc.GL_RGBA) then
      internalFormat = glc.GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
	else
		print("glformat",gldata,glformat,swapped_glc[glformat])
		print("image",image:Width(),image:Height(),image:DataType(),imffi.IM_USHORT,imffi.IM_BYTE)
		error"unknown format"
   end
	gl.glHint(glc.GL_TEXTURE_COMPRESSION_HINT, glc.GL_NICEST)
GetGLError"pre compress"	
   -- Read in and compress the texture.
   gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, internalFormat,
                image:Width(), image:Height(), 0,
                glformat, glc.GL_UNSIGNED_BYTE, gldata);
	GetGLError"compress texture"
   -- If our compressed size is reasonable, write the compressed image to disk.
   local compressedSize = ffi.new"GLint[1]"
   gl.glGetTexLevelParameteriv(glc.GL_TEXTURE_2D, 0,
                            glc.GL_TEXTURE_COMPRESSED_IMAGE_SIZE,
                            compressedSize);
GetGLError"compress getsize"
   if ((compressedSize[0] > 0) and (compressedSize[0] < 100000000)) then
      -- Allocate a buffer to read back the compressed texture.
      --GLubyte *compressedBytes = ffi.C.malloc(ffi.sizeof("GLubyte") * compressedSize[0]);
		local compressedBytes = ffi.new("GLubyte[?]", compressedSize[0]);
      -- Read back the compressed texture.
      glext.glGetCompressedTexImage(glc.GL_TEXTURE_2D, 0, compressedBytes);

      -- Save the texture to a file.
      SaveCompressedImage(pathSave, image:Width(), image:Height(),
                          internalFormat, compressedSize[0], compressedBytes);

      -- Free our buffer.
      --free(compressedBytes);
	else
		print("too big for saving",compressedSize[0])
   end

   -- Define your texture edge handling, again here I'm clamping.
   --glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP);
  -- glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
   --glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

   -- Release the bitmap image rep.

	gl.glDeleteTextures(1, textureNumber)
	GetGLError"end getsize"
end
function ConvertToCompressed(fileName,pathSave)

   -- Again, more error checking.  Here we aren't using
   -- MIPMAPs, so make sure your dimensions are a power of 2.
	----------------------------
	local image = im.FileImageLoadBitmap(fileName)
		if (not image) then
			print ("Unnable to open the file: " .. fileName)
			error("500")
		end
	if image:DataType() == imffi.IM_USHORT then
		print"convert ushort to byte"
		local err,imag2 = imffi.ConvertDataTypeNew(image,imffi.IM_BYTE, imffi.IM_CPX_REAL, imffi.IM_GAMMA_LINEAR, true, imffi.IM_CAST_FIXED)
		if err ~= im.ERR_NONE then print(err,imag2);error"no conversion" end
		image:Destroy()
		image = imag2
	end
	--multiple of 4
	local w4 = math.floor(image:Width()/4 +0.5)*4
	local h4 = math.floor(image:Height()/4 +0.5)*4
	if image:Width()~=w4 or image:Height()~=h4 then
		print("resize",image:Width(),image:Height(),"to",w4,h4)
		local im2 = im.ImageCreateBased(image,w4,h4)
		im.ProcessResize(image,im2,3)
		image:Destroy()
		image = im2
	end
	ImageConvertToCompressed(image,pathSave)
	image:Destroy()

end

function LoadCompressedTotexture(filename, texture,srgb)
	-- Attempt to load the compressed texture data.
	local pData, width, height,compressedFormat, size = LoadCompressedImage(filename)
	--print(pData,width, height,compressedFormat, size)
  
    gl.glBindTexture(glc.GL_TEXTURE_2D, texture);
	gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT, 1)
	
    gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MIN_FILTER, glc.GL_LINEAR);
    gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAG_FILTER, glc.GL_LINEAR);
      -- Create the texture from the compressed bytes.
	if srgb then
		if (compressedFormat == glc.GL_COMPRESSED_RGB_S3TC_DXT1_EXT) then
			compressedFormat = glc.GL_COMPRESSED_SRGB_S3TC_DXT1_EXT;
		elseif (compressedFormat == glc.GL_COMPRESSED_RGBA_S3TC_DXT5_EXT) then
			compressedFormat = glc.GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT;
		end
	end
    glext.glCompressedTexImage2D(glc.GL_TEXTURE_2D, 0, compressedFormat,width, height, 0, size, pData);

	return width,height,compressedFormat
end
ffi.cdef[[
typedef void FILE;
FILE * fopen(const char *path, const char *mode);
size_t fread ( const void * ptr, size_t size, size_t count, FILE * stream );
size_t fwrite ( const void * ptr, size_t size, size_t count, FILE * stream );
int fclose ( FILE * stream );
]]
function SaveCompressedImage(path,  width,  height,
                          compressedFormat,  size, pData)
	print("saving",path,  width,  height,compressedFormat,  size)
   local pFile = ffi.C.fopen(path, "wb");
   if (pFile == 0) then error("could not save "..tostring(path)) end

   local info = ffi.new"GLuint[4]"

   info[0] = width;
   info[1] = height;
   info[2] = compressedFormat;
   info[3] = size;

   ffi.C.fwrite(info, ffi.sizeof"GLuint", 4, pFile);
   ffi.C.fwrite(pData, size, 1, pFile);
   ffi.C.fclose(pFile);
end

--GLubyte * data ,width, height,compressedFormat, size
local lpData 
local lpDataSize = 0
function LoadCompressedImage(path)
	--print("LoadCompressedImage",path)
	local pFile = ffi.C.fopen(path, "rb");
	if (pFile == nil) then error("could not load "..tostring(path)) end

	local info = ffi.new"GLuint[4]"

	ffi.C.fread(info, ffi.sizeof"GLuint", 4, pFile);
	--increment buffer lpData is necessary
	if info[3] > lpDataSize then
		lpData = ffi.new("GLubyte[?]",info[3])
		lpDataSize = info[3]
	end
   local pData = lpData
   local retsize = ffi.C.fread(pData, 1, info[3], pFile);
   assert(retsize == info[3],"problem loading compressed file:"..path)
   ffi.C.fclose(pFile);
   return pData, info[0],info[1],info[2],info[3];
   -- Free pData when done...
end
