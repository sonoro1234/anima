local M = {}
local buffercdef = "typedef struct {bool abort;double cpuload[1];int nFrames;int Rpos;int Wpos; int Size;float buf[?];} circ_buf;"
local ffi = require"ffi"
ffi.cdef(buffercdef)
local wait = 1/44100
local tim = require"luapower.time"
local min = math.min
local circ_buf_mt = {}
circ_buf_mt.__index = circ_buf_mt
function circ_buf_mt:__new(nFrames,N)
    local size = nFrames*N
    local bb = ffi.new("circ_buf",size)
    bb.Size = size
    bb.nFrames = nFrames
    return bb
end

function circ_buf_mt:read(out)
    while (not self.abort) and self.Rpos == self.Wpos do 
        tim.sleep(wait)
    end

    local size1 = min(self.nFrames, self.Size - self.Rpos)
    local size2 = self.nFrames - size1
    ffi.copy(out, self.buf + self.Rpos, size1 * ffi.sizeof"float")
    ffi.copy(out + size1, self.buf, size2 * ffi.sizeof"float")
    self.Rpos = (self.Rpos + self.nFrames)%self.Size
end


function circ_buf_mt:write1(buf)
    local r = self.Rpos
    local w = self.Wpos
    local nextw = (w + self.nFrames)%self.Size;
    
    if r == nextw then
        return false;
    end

    local size1 = min(self.Size - w,self.nFrames)
    local size2 = self.nFrames - size1
    ffi.copy(self.buf + w, buf, size1 * ffi.sizeof"float")
    ffi.copy(self.buf, buf + size1, size2 * ffi.sizeof"float")
    self.Wpos = nextw
    return true
end

function circ_buf_mt:write(buf)
    while (not self.abort) and (not self:write1(buf)) do
        tim.sleep(wait)
    end
end
M.circ_buf = ffi.metatype("circ_buf",circ_buf_mt)

return M