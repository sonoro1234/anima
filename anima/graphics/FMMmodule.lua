-- Threaded implementation of inpaint by FMM
-- use flood_fill to select the area to inpaint
-- then click doit on inpaint dialog

local function FMMmodule(GL)
	local M = {}
require"anima"

local ImageF = [[
typedef struct _ImageF 
{
  float * data;
  unsigned int width;
  unsigned int height;
  unsigned int bitplanes;
}
ImageF;
]]

ffi.cdef(ImageF)

--WINUSEPTHREAD = true
local Thread = require "lj-async.thread"
local thread_data_t = ffi.typeof("struct { ImageF im;ImageF m;float* eik;float* progdata;}")

local thread_func = function(pars)
	--WINUSEPTHREAD = true
	local ffi = require "ffi"
	ffi.cdef(ImageF)
	local vicim = require"anima.vicimag"
	local cancel = ffi.new"int[1]"
	local inpaintFMM3 = require"anima.graphics.inpaintFMM"
	
	return function(ud)

		ud = ffi.cast("struct { ImageF im;ImageF m;float* eik;float* progdata;}*", ud)

		local function progress(count)
			ud.progdata[0] = count
		end
		
		ud.progdata[0] = 0
		
		local image = vicim.pixel_data(ud.im.data, ud.im.width, ud.im.height, ud.im.bitplanes)
		local mask = vicim.pixel_data(ud.m.data, ud.m.width, ud.m.height, ud.m.bitplanes)
		
		inpaintFMM3(ud.im.width, ud.im.height, image, mask, ud.eik, pars.radio, progress)
		
	end
end

-- this locals act as anchors avoiding the data being gc
-- on function end, as they are needed in other thread
local imbuf,m1buf,datam1,eik
local function inpaint(tex,m1,NM,progrData)

	local datatex = tex:get_pixels(glc.GL_FLOAT,glc.GL_RGB) 
	imbuf = ffi.new("ImageF",{datatex, tex.width, tex.height, 3})
	
	datam1 = m1:get_pixels(glc.GL_FLOAT,glc.GL_RED)
	m1buf = ffi.new("ImageF",{datam1, m1.width, m1.height, 1})
	
	local size = m1.width*m1.height
	eik = ffi.new("float[?]",size)

	local t = Thread(thread_func,thread_data_t(imbuf,m1buf,eik,progrData),{radio=NM.radio})

	return t,datatex

end
	
	local DOINPAINT
	local progrData = ffi.new("float[1]")
	local NM = GL:Dialog("inpaint",{
	{"doit",0,guitypes.button,function() DOINPAINT=true end},
	{"showres",false,guitypes.toggle},
	{"radio",5,guitypes.valint,{min=1,max=30}},
	},function() 
		ig.ProgressBar(progrData[0])
	end)
	
	M.NM = NM
	
	local tt,datatex
	local inpainted = GL:Texture()
	function M:draw(tex,mask)
		if NM.showres then
			ut.Clear()
			inpainted:drawcenter()
		end
		
		if DOINPAINT then
			tt,datatex = inpaint(tex, mask, NM, progrData)
			DOINPAINT = false
		end
		if tt then
			if tt:join(0.01) then
				inpainted:set_data(datatex,3,3)
				tt:free()
				tt = nil
				NM.vars.showres[0] = true
			end
		end
	end

	return M
end

return FMMmodule
