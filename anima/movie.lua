local function funcdir(path,func,...)
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path..'/'..file
            --print ("\t "..f)
            local attr = lfs.attributes (f)
            assert (type(attr) == "table")
            if attr.mode == "directory" then
                --attrdir (f)
            else
                --for name, value in pairs(attr) do
                --    print (name, value)
                --end
				func(f,...)
            end
        end
    end
end
local movie = {current_frame=0,dur_fr=math.huge}
function movie:new(o)
	--o = o or {}
	assert(o.directory)
	assert(o.format)
	assert(o.ext)
	assert(o.GL)
	setmetatable(o, self)
	self.__index = self
	return o
end

function movie:init()
	if self.format == "AVI" then
		if not self.avifile then
			local fsavename = self.directory .. [[\avimoviee]] .. self.ext
			local err = ffi.new("int[1]")
			self.avifile = imffi.imFileNew(fsavename, "AVI",err)
			if (err[0] ~= im.ERR_NONE) then
				print(fsavename)
				error(im.ErrorStr(err[0]))
			end 
			--self.avifile:SetAttribute("FPS", im.FLOAT, {GL.fps})
			local data = ffi.new("float[1]",GL.fps)
			imffi.imFileSetAttribute(self.avifile,"FPS", im.FLOAT,1,data) ;
			local data2 = ffi.new("int[1]",GL.fps)
			imffi.imFileSetAttribute(self.avifile,"KeyFrameRate", im.INT,1,data2) ;
			--imffi.imImageSetAttribReal(self.avifile,"FPS", im.FLOAT,GL.fps)			
		end
	else
		local framesdir = self.directory .. [[\frames]]
		local path = require"anima.path"
		path.mkdir(framesdir)
		--pbo stuff for async read
		--[[
		local w,h =  GL.W, GL.H
		local nbytes = w*h*4*ffi.sizeof"char"
		self.pixelsUserData = ffi.new("char[?]",w*h*4)
		self.pbo = ffi.new("GLuint[3]")
		glext.glGenBuffers(3,self.pbo)
		for i=0,2 do
			glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, self.pbo[i]);
			glext.glBufferData(glc.GL_PIXEL_PACK_BUFFER, nbytes, nil, glc.GL_STREAM_READ);
			gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		end
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, 0);
		--]]
	end
	self.inited = true
end
local readsdone = 0
function movie:SaveImagePBO(GL,filename,formato,frame)
	--GetGLError"pbosave"
		formato = formato or "TIFF"
		
		GL.fbo:BindRead()

		local w,h =  GL.W, GL.H
		local nbytes = w*h*4*ffi.sizeof"char"
		
		local index = (frame) % 3;
		
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, self.pbo[index]);
		
		
		if readsdone>= 3 then

		local ptr = glext.glMapBuffer(glc.GL_PIXEL_PACK_BUFFER, glc.GL_READ_ONLY);
		--assert(ptr ~= nil,"glMapBuffer error")
		print(ptr)

		if ptr ~= nil then
			local pixelsUserData = self.pixelsUserData
			ffi.copy(pixelsUserData, ptr, nbytes)
			glext.glUnmapBuffer(glc.GL_PIXEL_PACK_BUFFER);
			
			---[[
			local image = imffi.imImageCreateFromOpenGLData(w, h, glc.GL_RGBA, pixelsUserData); 
			local err = imffi.imFileImageSave(filename,formato,image)
			if (err and err ~= im.ERR_NONE) then
				print("saved",filename)
				error(im.ErrorStr(err))
			end
			imffi.imImageDestroy(image)
			--]]
		end
		end
		gl.glReadPixels(0,0, w, h, glc.GL_BGRA, glc.GL_UNSIGNED_BYTE, ffi.cast("void *",0))
		readsdone = readsdone + 1
		

		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, 0);
		GetGLError"pbosave end"
	end
function movie:SaveFrame(GL,tim)
	if not self.inited then self:init() end
	self.current_frame = GL.animation.current_frame
	if self.current_frame > self.dur_fr then return end
	
	print("Frame",self.current_frame,tim)
	
	if self.format == "AVI" then
		GL:SaveAVIImage(self.avifile)
	else
		local fsavename = self.directory .. [[\frames\frame]] .. string.format("%.4d",self.current_frame) .. self.ext
		if self.bits == 16 then
			GL:SaveImage16(fsavename,self.format)
		else
			GL:SaveImage(fsavename,self.format)
			--self:SaveImagePBO(GL,fsavename,self.format,self.current_frame)
		end
	end

end
function movie:ClearFrames()
	funcdir(self.directory .. "\\frames",function(f) os.remove(f) end)
	self.current_frame = 0
end
function movie:MakeMovie(movie_name,fps)
	local dir = self.directory .. "\\frames"
	local counter = 0
	local function ProcessFrame(file_name, ifile)
		counter = (counter + 1)%10
		if counter == 0 then
			print("Loading frame: "..file_name)
		end
		local image, err = im.FileImageLoad(file_name);
		if (err and err ~= im.ERR_NONE) then
			error(im.ErrorStr(err))
		end
		--print("saving frame: "..file_name)
		err = ifile:SaveImage(image)
		if (err and err ~= im.ERR_NONE) then
			error(im.ErrorStr(err))
		end
		
		image:Destroy()
	end
	local ifile = im.FileNew(movie_name, "AVI")
	--ifile:SetInfo("CUSTOM")
	--ifile:SetInfo("XVID")
	--ifile:SetInfo("dv25")
	ifile:SetAttribute("FPS", im.FLOAT, {fps}) -- Frames per second
	
	funcdir(dir,ProcessFrame,ifile)
	
	ifile:Close()
end
return movie