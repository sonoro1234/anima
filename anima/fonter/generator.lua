package.path = package.path.."../../LuaJIT-ImGui/cimgui/generator/?.lua"
local cp2c = require"cpp2ffi"
local parser = cp2c.Parser()


cp2c.save_data("./outheader.h",[[#include <ft2build.h>
#include FT_FREETYPE_H          // <freetype/freetype.h>
#include FT_MODULE_H            // <freetype/ftmodapi.h>
#include FT_GLYPH_H             // <freetype/ftglyph.h>
#include FT_SYNTHESIS_H         // <freetype/ftsynth.h>
#include FT_OUTLINE_H  //<freetype/ftoutln.h>
]])


local defines = parser:take_lines([[gcc -E -dD -I ../../../freetype2/ -I ../../../freetype2/include/ ./outheader.h]],{[[freetype.-]]},"gcc")
os.remove"./outheader.h"
---------------------------
parser:do_parse()


--parseItems
--local itemarr,items = cp2c.parseItems(txt)
local cdefs = {}
for i,it in ipairs(parser.itemsarr) do
	table.insert(cdefs,it.item)
end


local deftab = {}
---[[
local ffi = require"ffi"
ffi.cdef(table.concat(cdefs,""))
local wanted_strings = {"FT.-"}
for i,v in ipairs(defines) do
	print("#defines",v[1],v[2])
	local wanted = false
	for _,wan in ipairs(wanted_strings) do
		if (v[1]):match(wan) then wanted=true; break end
	end
	if wanted then
		local lin = "static const int "..v[1].." = " .. v[2] .. ";"
		local ok,msg = pcall(function() return ffi.cdef(lin) end)
		if not ok then
			print("skipping def",lin)
			print(msg)
		else
			table.insert(deftab,lin)
		end
	end
end
--]]


local sdlstr = [[
local ffi = require"ffi"

--uncomment to debug cdef calls]]..
"\n---[["..[[

local ffi_cdef = function(code)
    local ret,err = pcall(ffi.cdef,code)
    if not ret then
        local lineN = 1
        for line in code:gmatch("([^\n\r]*)\r?\n") do
            print(lineN, line)
            lineN = lineN + 1
        end
        print(err)
        error"bad cdef"
    end
end
]].."--]]"..[[

ffi_cdef]].."[["..table.concat(cdefs,"").."]]"..[[

ffi_cdef]].."[["..table.concat(deftab,"\n").."]]" 

cp2c.save_data("./freetype_h.lua",sdlstr)