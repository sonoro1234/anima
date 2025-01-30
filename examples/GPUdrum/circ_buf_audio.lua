
local function audio_init(frames,SR)
	local lp_time = require"luapower.time"
	local secs_now =lp_time.clock
	local rt = require"rtaudio_ffi"
	local ffi = require"ffi"
	local fulltime = frames/(SR)
	local ring_buf = require"ring_scsp"
	return function(out, inp, nFrames,stream_time,status,userdata)
		local begintime = secs_now()
		local udc = ffi.cast("circ_buf*",userdata)
		out = ffi.cast("float*", out)
		udc:read(out)
		ffi.copy(out + nFrames, out, nFrames*ffi.sizeof"float")
		local endtime = secs_now()
		udc.cpuload[0] = (endtime-begintime)/fulltime
		--does not work with ASIO
		--if status~=0 then print(rt.STATUS_INPUT_OVERFLOW == status and "overflow" or "underflow") end
		return 0
	end
end

return audio_init