----------font utilities windows only
if ffi.os == "Windows" then
ffi.cdef([[
typedef int BOOL;
typedef void* HDC;
typedef void* HFONT;
typedef unsigned long DWORD;
typedef float FLOAT;
typedef unsigned char BYTE;
typedef long LONG;
typedef struct _POINTFLOAT {
  FLOAT x;
  FLOAT y;
} POINTFLOAT, *PPOINTFLOAT;
typedef struct tagLOGFONTA {
    LONG lfHeight;
    LONG lfWidth;
    LONG lfEscapement;
    LONG lfOrientation;
    LONG lfWeight;
    BYTE lfItalic;
    BYTE lfUnderline;
    BYTE lfStrikeOut;
    BYTE lfCharSet;
    BYTE lfOutPrecision;
    BYTE lfClipPrecision;
    BYTE lfQuality;
    BYTE lfPitchAndFamily;
    char lfFaceName[32];
} LOGFONTA,*PLOGFONTA,*NPLOGFONTA,*LPLOGFONTA;
typedef struct _GLYPHMETRICSFLOAT {
  FLOAT      gmfBlackBoxX;
  FLOAT      gmfBlackBoxY;
  POINTFLOAT gmfptGlyphOrigin;
  FLOAT      gmfCellIncX;
  FLOAT      gmfCellIncY;
} GLYPHMETRICSFLOAT;//, *PGLYPHMETRICSFLOAT;
BOOL __stdcall wglUseFontOutlinesA(
  HDC hdc,
  DWORD first,
  DWORD count,
  DWORD listBase,
  FLOAT deviation,
  FLOAT extrusion,
  int format,
  GLYPHMETRICSFLOAT* lpgmf
);
HDC __stdcall wglGetCurrentDC(void);
HFONT __stdcall CreateFontIndirectA(const LOGFONTA *lplf);
DWORD __stdcall GetLastError(void);]])
ffi.cdef([[
//static const int FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000;
//static const int FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200;
uint32_t FormatMessageA(
            uint32_t dwFlags,
            const void* lpSource,
            uint32_t dwMessageId,
            uint32_t dwLanguageId,
            char* lpBuffer,
            uint32_t nSize,
            va_list *Arguments
        );
void* GetDC(void *);
void* SelectObject(void*,void*);
BOOL DeleteObject( void*);
]])

--if not pcall(function() return ffi.C.HGDI_ERROR end) then
	ffi.cdef[[static const int HGDI_ERROR = 65535;]]
--end

ffi.cdef[[
HFONT CreateFontA(
 int     nHeight,
 int     nWidth,
 int     nEscapement,
 int     nOrientation,
 int     fnWeight,
 DWORD   fdwItalic,
 DWORD   fdwUnderline,
 DWORD   fdwStrikeOut,
 DWORD   fdwCharSet,
 DWORD   fdwOutputPrecision,
 DWORD   fdwClipPrecision,
 DWORD   fdwQuality,
 DWORD   fdwPitchAndFamily,
 const char* lpszFace
);
enum FontWindowsConstants
{
OUT_DEFAULT_PRECIS =0,
OUT_STRING_PRECIS =1,
OUT_CHARACTER_PRECIS =2,
OUT_STROKE_PRECIS =3,
OUT_TT_PRECIS =4,
OUT_DEVICE_PRECIS =5,
OUT_RASTER_PRECIS =6,
OUT_TT_ONLY_PRECIS =7,
OUT_OUTLINE_PRECIS =8,
OUT_SCREEN_OUTLINE_PRECIS =9,
OUT_PS_ONLY_PRECIS =10,

CLIP_DEFAULT_PRECIS =0,
CLIP_CHARACTER_PRECIS =1,
CLIP_STROKE_PRECIS =2,
CLIP_MASK =0xf,
CLIP_LH_ANGLES =(1<<4),
CLIP_TT_ALWAYS =(2<<4),
//#if _WIN32_WINNT >= 0x0600
CLIP_DFA_DISABLE =(4<<4),
//#endif
CLIP_EMBEDDED =(8<<4),

DEFAULT_QUALITY =0,
DRAFT_QUALITY =1,
PROOF_QUALITY =2,
NONANTIALIASED_QUALITY =3,
ANTIALIASED_QUALITY =4,

CLEARTYPE_QUALITY =5,
CLEARTYPE_NATURAL_QUALITY =6,

DEFAULT_PITCH =0,
FIXED_PITCH =1,
VARIABLE_PITCH =2,
MONO_FONT =8,

ANSI_CHARSET =0,
DEFAULT_CHARSET =1,
SYMBOL_CHARSET =2,
SHIFTJIS_CHARSET =128,
HANGEUL_CHARSET =129,
HANGUL_CHARSET =129,
GB2312_CHARSET =134,
CHINESEBIG5_CHARSET =136,
OEM_CHARSET =255,
JOHAB_CHARSET =130,
HEBREW_CHARSET =177,
ARABIC_CHARSET =178,
GREEK_CHARSET =161,
TURKISH_CHARSET =162,
VIETNAMESE_CHARSET =163,
THAI_CHARSET =222,
EASTEUROPE_CHARSET =238,
RUSSIAN_CHARSET =204,

MAC_CHARSET =77,
BALTIC_CHARSET =186,
/*
#define FS_LATIN1 __MSABI_LONG(0x00000001)
#define FS_LATIN2 __MSABI_LONG(0x00000002)
#define FS_CYRILLIC __MSABI_LONG(0x00000004)
#define FS_GREEK __MSABI_LONG(0x00000008)
#define FS_TURKISH __MSABI_LONG(0x00000010)
#define FS_HEBREW __MSABI_LONG(0x00000020)
#define FS_ARABIC __MSABI_LONG(0x00000040)
#define FS_BALTIC __MSABI_LONG(0x00000080)
#define FS_VIETNAMESE __MSABI_LONG(0x00000100)
#define FS_THAI __MSABI_LONG(0x00010000)
#define FS_JISJAPAN __MSABI_LONG(0x00020000)
#define FS_CHINESESIMP __MSABI_LONG(0x00040000)
#define FS_WANSUNG __MSABI_LONG(0x00080000)
#define FS_CHINESETRAD __MSABI_LONG(0x00100000)
#define FS_JOHAB __MSABI_LONG(0x00200000)
#define FS_SYMBOL __MSABI_LONG(0x80000000)
*/
FF_DONTCARE =(0<<4),
FF_ROMAN =(1<<4),

FF_SWISS =(2<<4),

FF_MODERN =(3<<4),

FF_SCRIPT =(4<<4),
FF_DECORATIVE =(5<<4),

FW_DONTCARE =0,
FW_THIN =100,
FW_EXTRALIGHT =200,
FW_LIGHT =300,
FW_NORMAL =400,
FW_MEDIUM =500,
FW_SEMIBOLD =600,
FW_BOLD =700,
FW_EXTRABOLD =800,
FW_HEAVY =900
/*
#define FW_ULTRALIGHT FW_EXTRALIGHT
#define FW_REGULAR FW_NORMAL
#define FW_DEMIBOLD FW_SEMIBOLD
#define FW_ULTRABOLD FW_EXTRABOLD
#define FW_BLACK FW_HEAVY

#define PANOSE_COUNT 10
#define PAN_FAMILYTYPE_INDEX 0
#define PAN_SERIFSTYLE_INDEX 1
#define PAN_WEIGHT_INDEX 2
#define PAN_PROPORTION_INDEX 3
#define PAN_CONTRAST_INDEX 4
#define PAN_STROKEVARIATION_INDEX 5
#define PAN_ARMSTYLE_INDEX 6
#define PAN_LETTERFORM_INDEX 7
#define PAN_MIDLINE_INDEX 8
#define PAN_XHEIGHT_INDEX 9

#define PAN_CULTURE_LATIN 0
*/
};
]]

local function error_win(lvl)
        local errcode = ffi.C.GetLastError()
        local str = ffi.new("char[?]",1024)
		local FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000;
        local FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200;
        local numout = ffi.C.FormatMessageA(bit.bor(FORMAT_MESSAGE_FROM_SYSTEM,
            FORMAT_MESSAGE_IGNORE_INSERTS), nil, errcode, 0, str, 1023, nil)
        if numout == 0 then
            error("Windows Error: (Error calling FormatMessage)", lvl)
        else
            error("Windows Error: "..errcode..","..ffi.string(str, numout), lvl)
        end
    end
function GLFontOutline(font,args)
	args = args or {}
	args.italic = args.italic and true or false
	if args.bold then args.weight = 700 end
	print("italic",italic)
	local fonter = {font=font}
	function fonter:init()
		local C = ffi.C
		self.agmf = ffi.new("GLYPHMETRICSFLOAT[256]")
		fonter.list_base = gl.glGenLists(256);

		local hdc = gl.wglGetCurrentDC();

		local hfont = ffi.C.CreateFontA(0,0,0,0, args.weight or C.FW_DONTCARE, args.italic,true,false,
		--C.ANSI_CHARSET,
		C.DEFAULT_CHARSET,
		C.OUT_OUTLINE_PRECIS,C.CLIP_DEFAULT_PRECIS,C.CLEARTYPE_QUALITY, C.VARIABLE_PITCH, font);
		assert(hfont~=nil,"Could not create font")
		print("hfont",hfont)
		local oldfont = ffi.C.SelectObject(hdc,hfont)
		if oldfont == ffi.C.HGDI_ERROR or oldfont == nil then error_win(2) end
		
		local WGL_FONT_POLYGONS= 1
		local WGL_FONT_LINES = 0
		local typef = WGL_FONT_POLYGONS
		if args.outlineonly then typef = WGL_FONT_LINES end
		local res = gl.wglUseFontOutlinesA(hdc, 0, 255, fonter.list_base, 0.0, 0.2, typef, self.agmf);
		
		if res ==0 then
			--print("GetLastError",ffi.C.GetLastError())
			--error("Font creation failed")
			error_win(2)
		end
		ffi.C.SelectObject(hdc,oldfont)
		ffi.C.DeleteObject(hFont)
		
		local maxX, maxY = 0, 0
		for i=0,255 do
			local aa = self.agmf[i]
			maxX = math.max(maxX,aa.gmfBlackBoxX)
			maxY = math.max(maxY,aa.gmfBlackBoxY)			
		end
		self.maxX = maxX
		self.maxY = maxY
		--for i=0,255 do
			--local aa = self.agmf[i]
			--print(aa.gmfBlackBoxX,aa.gmfBlackBoxY,aa.gmfCellIncX,aa.gmfCellIncY)
		--end
	end
	function fonter:dims(...)
		if not self.list_base then self:init() end
		local x,y = 0,0
		for i,v in ipairs{...} do
			local text = tostring(v)
			for j=1,#text do
				x = x + self.agmf[text:byte(j)].gmfCellIncX;
				y = math.max(y,self.agmf[text:byte(j)].gmfBlackBoxY)
			end
			--x = x + self.agmf[32].gmfCellIncX;
			--y = math.max(y,self.agmf[32].gmfBlackBoxY)
		end
		return x, y
	end
	function fonter:print(...)
	--if true then return end
		if not self.list_base then self:init() end
		gl.glPushAttrib(glc.GL_LIST_BIT);
		gl.glListBase(self.list_base);
		for i,v in ipairs{...} do
			local text = tostring(v)
			gl.glCallLists(#text, glc.GL_UNSIGNED_BYTE, text);
			gl.glCallList(self.list_base + 32); --space
		end
		gl.glPopAttrib();
	end
	function fonter:printXY(tex,x,y,z,size)
	
		if not self.list_base then self:init() end
	--if true then return end
		gl.glPushMatrix()
		if size then
			local sc = size * 1/self.maxY --font.agmf[string.byte"H"].gmfBlackBoxY --
			gl.glScalef(sc,sc,sc)
		end
		gl.glTranslatef(x,y,z or 0)
		gl.glPushAttrib(glc.GL_LIST_BIT);
		gl.glListBase(self.list_base);
		local text = tostring(tex)
		gl.glCallLists(#text, glc.GL_UNSIGNED_BYTE, text);
		gl.glPopAttrib();
		gl.glPopMatrix()
		GetGLError"fontprintxy"
	end
	return fonter
end  

-- bitmap fonts from iup framework
function GLFont(cnv,font)
	local fonter = {}
	cnv.FONT = font
	fonter.list_base = gl.glGenLists(256);
	iup.GLUseFont(cnv, 0, 255, fonter.list_base)
	function fonter:print(...)
		gl.glPushAttrib(glc.GL_LIST_BIT);
		gl.glListBase(self.list_base);
		for i,v in ipairs{...} do
			local text = tostring(v)
			--print("pirnting",text)
			gl.glCallLists(#text, glc.GL_UNSIGNED_BYTE, text);
			--gl.glCallList(self.list_base + 32); --space
		end
		gl.glPopAttrib();
		GetGLError"fonterxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
	end

	function fonter.printer(x,y)
		x = x or 0
		y = y or 30
		return function(...) 
			--gl.glColor3d(1.0, 1.0, 1.0); 
			glext.glWindowPos2d(x, y);
			fonter:print(...) end
	end
	return fonter
end

end -- os= win
