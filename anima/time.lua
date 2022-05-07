-- for getting time with more precission than os.time
local ffi = require"ffi"
local secs_now 

if ffi.os == "Windows" then

if pcall(ffi.typeof, "FILETIME") then
	--cdef already defined
else
	ffi.cdef[[
		typedef struct _SYSTEMTIME {
			uint16_t wYear;
			uint16_t wMonth;
			uint16_t wDayOfWeek;
			uint16_t wDay;
			uint16_t wHour;
			uint16_t wMinute;
			uint16_t wSecond;
			uint16_t wMilliseconds;
		} SYSTEMTIME, *PSYSTEMTIME, *LPSYSTEMTIME;
		typedef struct _FILETIME {
			uint32_t dwLowDateTime;
			uint32_t  dwHighDateTime;
		} FILETIME, *PFILETIME, *LPFILETIME;
		typedef union _ULARGE_INTEGER {
			struct {
				uint32_t LowPart;
				uint32_t HighPart;
			} DUMMYSTRUCTNAME;
			struct {
				uint32_t LowPart;
				uint32_t HighPart;
			} u;
			unsigned __int64 QuadPart;
			} ULARGE_INTEGER;
		void GetSystemTime(LPSYSTEMTIME lpSystemTime);
		unsigned char SystemTimeToFileTime(const SYSTEMTIME *lpSystemTime, LPFILETIME lpFileTime);
	]]
end

local system_time = ffi.new("SYSTEMTIME")
local file_time = ffi.new"FILETIME"
--local utime = ffi.new"uint64_t"
local ularge = ffi.new"ULARGE_INTEGER"
local EPOCH = ffi.new("uint64_t",116444736000000000ULL)
secs_now = function()
	ffi.C.GetSystemTime(system_time );
	local ok = ffi.C.SystemTimeToFileTime( system_time, file_time );
	assert(ok>0)
	--utime = file_time.dwLowDateTime + file_time.dwHighDateTime*2^32 --bit.lshift(file_time.dwHighDateTime, 32)
	--return tonumber(utime - EPOCH)*1e-7 --+ tonumber(system_time.wMilliseconds*1e-3)
	ularge.u.LowPart = file_time.dwLowDateTime;
	ularge.u.HighPart = file_time.dwHighDateTime
	return tonumber(ularge.QuadPart - EPOCH)*1e-7 --+ tonumber(system_time.wMilliseconds*1e-3)
end

else -- ffi.os not Windows

if pcall(ffi.typeof, "struct timeval") then
        -- check if already defined.
else
        -- undefined! let's define it!
        ffi.cdef[[
           typedef struct timeval {
                long tv_sec;
                long tv_usec;
           } timeval;

        int gettimeofday(struct timeval* t, void* tzp);
]]
end
local gettimeofday_struct = ffi.new("struct timeval")
local function gettimeofday()
        ffi.C.gettimeofday(gettimeofday_struct, nil)
        return tonumber(gettimeofday_struct.tv_sec)  + tonumber(gettimeofday_struct.tv_usec) * 0.000001
end
secs_now = gettimeofday
end --ffi,os 

return secs_now