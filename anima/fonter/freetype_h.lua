local ffi = require"ffi"

--uncomment to debug cdef calls
---[[
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
--]]
ffi_cdef[[
 typedef signed short FT_Int16;
  typedef unsigned short FT_UInt16;
  typedef signed int FT_Int32;
  typedef unsigned int FT_UInt32;
  typedef int FT_Fast;
  typedef unsigned int FT_UFast;
  typedef struct FT_MemoryRec_* FT_Memory;
  typedef void*
  (*FT_Alloc_Func)( FT_Memory memory,
                    long size );
  typedef void
  (*FT_Free_Func)( FT_Memory memory,
                   void* block );
  typedef void*
  (*FT_Realloc_Func)( FT_Memory memory,
                      long cur_size,
                      long new_size,
                      void* block );
  struct FT_MemoryRec_
  {
    void* user;
    FT_Alloc_Func alloc;
    FT_Free_Func free;
    FT_Realloc_Func realloc;
  };
  typedef struct FT_StreamRec_* FT_Stream;
  typedef union FT_StreamDesc_
  {
    long value;
    void* pointer;
  } FT_StreamDesc;
  typedef unsigned long
  (*FT_Stream_IoFunc)( FT_Stream stream,
                       unsigned long offset,
                       unsigned char* buffer,
                       unsigned long count );
  typedef void
  (*FT_Stream_CloseFunc)( FT_Stream stream );
  typedef struct FT_StreamRec_
  {
    unsigned char* base;
    unsigned long size;
    unsigned long pos;
    FT_StreamDesc descriptor;
    FT_StreamDesc pathname;
    FT_Stream_IoFunc read;
    FT_Stream_CloseFunc close;
    FT_Memory memory;
    unsigned char* cursor;
    unsigned char* limit;
  } FT_StreamRec;
  typedef signed long FT_Pos;
  typedef struct FT_Vector_
  {
    FT_Pos x;
    FT_Pos y;
  } FT_Vector;
  typedef struct FT_BBox_
  {
    FT_Pos xMin, yMin;
    FT_Pos xMax, yMax;
  } FT_BBox;
  typedef enum FT_Pixel_Mode_
  {
    FT_PIXEL_MODE_NONE = 0,
    FT_PIXEL_MODE_MONO,
    FT_PIXEL_MODE_GRAY,
    FT_PIXEL_MODE_GRAY2,
    FT_PIXEL_MODE_GRAY4,
    FT_PIXEL_MODE_LCD,
    FT_PIXEL_MODE_LCD_V,
    FT_PIXEL_MODE_BGRA,
    FT_PIXEL_MODE_MAX
  } FT_Pixel_Mode;
  typedef struct FT_Bitmap_
  {
    unsigned int rows;
    unsigned int width;
    int pitch;
    unsigned char* buffer;
    unsigned short num_grays;
    unsigned char pixel_mode;
    unsigned char palette_mode;
    void* palette;
  } FT_Bitmap;
  typedef struct FT_Outline_
  {
    short n_contours;
    short n_points;
    FT_Vector* points;
    char* tags;
    short* contours;
    int flags;
  } FT_Outline;
  typedef int
  (*FT_Outline_MoveToFunc)( const FT_Vector* to,
                            void* user );
  typedef int
  (*FT_Outline_LineToFunc)( const FT_Vector* to,
                            void* user );
  typedef int
  (*FT_Outline_ConicToFunc)( const FT_Vector* control,
                             const FT_Vector* to,
                             void* user );
  typedef int
  (*FT_Outline_CubicToFunc)( const FT_Vector* control1,
                             const FT_Vector* control2,
                             const FT_Vector* to,
                             void* user );
  typedef struct FT_Outline_Funcs_
  {
    FT_Outline_MoveToFunc move_to;
    FT_Outline_LineToFunc line_to;
    FT_Outline_ConicToFunc conic_to;
    FT_Outline_CubicToFunc cubic_to;
    int shift;
    FT_Pos delta;
  } FT_Outline_Funcs;
  typedef enum FT_Glyph_Format_
  {
    FT_GLYPH_FORMAT_NONE = ( ( (unsigned long)0 << 24 ) | ( (unsigned long)0 << 16 ) | ( (unsigned long)0 << 8 ) | (unsigned long)0 ),
    FT_GLYPH_FORMAT_COMPOSITE = ( ( (unsigned long)'c' << 24 ) | ( (unsigned long)'o' << 16 ) | ( (unsigned long)'m' << 8 ) | (unsigned long)'p' ),
    FT_GLYPH_FORMAT_BITMAP = ( ( (unsigned long)'b' << 24 ) | ( (unsigned long)'i' << 16 ) | ( (unsigned long)'t' << 8 ) | (unsigned long)'s' ),
    FT_GLYPH_FORMAT_OUTLINE = ( ( (unsigned long)'o' << 24 ) | ( (unsigned long)'u' << 16 ) | ( (unsigned long)'t' << 8 ) | (unsigned long)'l' ),
    FT_GLYPH_FORMAT_PLOTTER = ( ( (unsigned long)'p' << 24 ) | ( (unsigned long)'l' << 16 ) | ( (unsigned long)'o' << 8 ) | (unsigned long)'t' )
  } FT_Glyph_Format;
  typedef struct FT_RasterRec_* FT_Raster;
  typedef struct FT_Span_
  {
    short x;
    unsigned short len;
    unsigned char coverage;
  } FT_Span;
  typedef void
  (*FT_SpanFunc)( int y,
                  int count,
                  const FT_Span* spans,
                  void* user );
  typedef int
  (*FT_Raster_BitTest_Func)( int y,
                             int x,
                             void* user );
  typedef void
  (*FT_Raster_BitSet_Func)( int y,
                            int x,
                            void* user );
  typedef struct FT_Raster_Params_
  {
    const FT_Bitmap* target;
    const void* source;
    int flags;
    FT_SpanFunc gray_spans;
    FT_SpanFunc black_spans;
    FT_Raster_BitTest_Func bit_test;
    FT_Raster_BitSet_Func bit_set;
    void* user;
    FT_BBox clip_box;
  } FT_Raster_Params;
  typedef int
  (*FT_Raster_NewFunc)( void* memory,
                        FT_Raster* raster );
  typedef void
  (*FT_Raster_DoneFunc)( FT_Raster raster );
  typedef void
  (*FT_Raster_ResetFunc)( FT_Raster raster,
                          unsigned char* pool_base,
                          unsigned long pool_size );
  typedef int
  (*FT_Raster_SetModeFunc)( FT_Raster raster,
                            unsigned long mode,
                            void* args );
  typedef int
  (*FT_Raster_RenderFunc)( FT_Raster raster,
                           const FT_Raster_Params* params );
  typedef struct FT_Raster_Funcs_
  {
    FT_Glyph_Format glyph_format;
    FT_Raster_NewFunc raster_new;
    FT_Raster_ResetFunc raster_reset;
    FT_Raster_SetModeFunc raster_set_mode;
    FT_Raster_RenderFunc raster_render;
    FT_Raster_DoneFunc raster_done;
  } FT_Raster_Funcs;
  typedef unsigned char FT_Bool;
  typedef signed short FT_FWord;
  typedef unsigned short FT_UFWord;
  typedef signed char FT_Char;
  typedef unsigned char FT_Byte;
  typedef const FT_Byte* FT_Bytes;
  typedef FT_UInt32 FT_Tag;
  typedef char FT_String;
  typedef signed short FT_Short;
  typedef unsigned short FT_UShort;
  typedef signed int FT_Int;
  typedef unsigned int FT_UInt;
  typedef signed long FT_Long;
  typedef unsigned long FT_ULong;
  typedef signed short FT_F2Dot14;
  typedef signed long FT_F26Dot6;
  typedef signed long FT_Fixed;
  typedef int FT_Error;
  typedef void* FT_Pointer;
  typedef size_t FT_Offset;
  typedef ptrdiff_t FT_PtrDist;
  typedef struct FT_UnitVector_
  {
    FT_F2Dot14 x;
    FT_F2Dot14 y;
  } FT_UnitVector;
  typedef struct FT_Matrix_
  {
    FT_Fixed xx, xy;
    FT_Fixed yx, yy;
  } FT_Matrix;
  typedef struct FT_Data_
  {
    const FT_Byte* pointer;
    FT_Int length;
  } FT_Data;
  typedef void (*FT_Generic_Finalizer)( void* object );
  typedef struct FT_Generic_
  {
    void* data;
    FT_Generic_Finalizer finalizer;
  } FT_Generic;
  typedef struct FT_ListNodeRec_* FT_ListNode;
  typedef struct FT_ListRec_* FT_List;
  typedef struct FT_ListNodeRec_
  {
    FT_ListNode prev;
    FT_ListNode next;
    void* data;
  } FT_ListNodeRec;
  typedef struct FT_ListRec_
  {
    FT_ListNode head;
    FT_ListNode tail;
  } FT_ListRec;
  enum {
  FT_Mod_Err_Base = 0,
  FT_Mod_Err_Autofit = 0,
  FT_Mod_Err_BDF = 0,
  FT_Mod_Err_Bzip2 = 0,
  FT_Mod_Err_Cache = 0,
  FT_Mod_Err_CFF = 0,
  FT_Mod_Err_CID = 0,
  FT_Mod_Err_Gzip = 0,
  FT_Mod_Err_LZW = 0,
  FT_Mod_Err_OTvalid = 0,
  FT_Mod_Err_PCF = 0,
  FT_Mod_Err_PFR = 0,
  FT_Mod_Err_PSaux = 0,
  FT_Mod_Err_PShinter = 0,
  FT_Mod_Err_PSnames = 0,
  FT_Mod_Err_Raster = 0,
  FT_Mod_Err_SFNT = 0,
  FT_Mod_Err_Smooth = 0,
  FT_Mod_Err_TrueType = 0,
  FT_Mod_Err_Type1 = 0,
  FT_Mod_Err_Type42 = 0,
  FT_Mod_Err_Winfonts = 0,
  FT_Mod_Err_GXvalid = 0,
  FT_Mod_Err_Max };
  enum {
  FT_Err_Ok = 0x00,
  FT_Err_Cannot_Open_Resource = 0x01 + 0,
  FT_Err_Unknown_File_Format = 0x02 + 0,
  FT_Err_Invalid_File_Format = 0x03 + 0,
  FT_Err_Invalid_Version = 0x04 + 0,
  FT_Err_Lower_Module_Version = 0x05 + 0,
  FT_Err_Invalid_Argument = 0x06 + 0,
  FT_Err_Unimplemented_Feature = 0x07 + 0,
  FT_Err_Invalid_Table = 0x08 + 0,
  FT_Err_Invalid_Offset = 0x09 + 0,
  FT_Err_Array_Too_Large = 0x0A + 0,
  FT_Err_Missing_Module = 0x0B + 0,
  FT_Err_Missing_Property = 0x0C + 0,
  FT_Err_Invalid_Glyph_Index = 0x10 + 0,
  FT_Err_Invalid_Character_Code = 0x11 + 0,
  FT_Err_Invalid_Glyph_Format = 0x12 + 0,
  FT_Err_Cannot_Render_Glyph = 0x13 + 0,
  FT_Err_Invalid_Outline = 0x14 + 0,
  FT_Err_Invalid_Composite = 0x15 + 0,
  FT_Err_Too_Many_Hints = 0x16 + 0,
  FT_Err_Invalid_Pixel_Size = 0x17 + 0,
  FT_Err_Invalid_Handle = 0x20 + 0,
  FT_Err_Invalid_Library_Handle = 0x21 + 0,
  FT_Err_Invalid_Driver_Handle = 0x22 + 0,
  FT_Err_Invalid_Face_Handle = 0x23 + 0,
  FT_Err_Invalid_Size_Handle = 0x24 + 0,
  FT_Err_Invalid_Slot_Handle = 0x25 + 0,
  FT_Err_Invalid_CharMap_Handle = 0x26 + 0,
  FT_Err_Invalid_Cache_Handle = 0x27 + 0,
  FT_Err_Invalid_Stream_Handle = 0x28 + 0,
  FT_Err_Too_Many_Drivers = 0x30 + 0,
  FT_Err_Too_Many_Extensions = 0x31 + 0,
  FT_Err_Out_Of_Memory = 0x40 + 0,
  FT_Err_Unlisted_Object = 0x41 + 0,
  FT_Err_Cannot_Open_Stream = 0x51 + 0,
  FT_Err_Invalid_Stream_Seek = 0x52 + 0,
  FT_Err_Invalid_Stream_Skip = 0x53 + 0,
  FT_Err_Invalid_Stream_Read = 0x54 + 0,
  FT_Err_Invalid_Stream_Operation = 0x55 + 0,
  FT_Err_Invalid_Frame_Operation = 0x56 + 0,
  FT_Err_Nested_Frame_Access = 0x57 + 0,
  FT_Err_Invalid_Frame_Read = 0x58 + 0,
  FT_Err_Raster_Uninitialized = 0x60 + 0,
  FT_Err_Raster_Corrupted = 0x61 + 0,
  FT_Err_Raster_Overflow = 0x62 + 0,
  FT_Err_Raster_Negative_Height = 0x63 + 0,
  FT_Err_Too_Many_Caches = 0x70 + 0,
  FT_Err_Invalid_Opcode = 0x80 + 0,
  FT_Err_Too_Few_Arguments = 0x81 + 0,
  FT_Err_Stack_Overflow = 0x82 + 0,
  FT_Err_Code_Overflow = 0x83 + 0,
  FT_Err_Bad_Argument = 0x84 + 0,
  FT_Err_Divide_By_Zero = 0x85 + 0,
  FT_Err_Invalid_Reference = 0x86 + 0,
  FT_Err_Debug_OpCode = 0x87 + 0,
  FT_Err_ENDF_In_Exec_Stream = 0x88 + 0,
  FT_Err_Nested_DEFS = 0x89 + 0,
  FT_Err_Invalid_CodeRange = 0x8A + 0,
  FT_Err_Execution_Too_Long = 0x8B + 0,
  FT_Err_Too_Many_Function_Defs = 0x8C + 0,
  FT_Err_Too_Many_Instruction_Defs = 0x8D + 0,
  FT_Err_Table_Missing = 0x8E + 0,
  FT_Err_Horiz_Header_Missing = 0x8F + 0,
  FT_Err_Locations_Missing = 0x90 + 0,
  FT_Err_Name_Table_Missing = 0x91 + 0,
  FT_Err_CMap_Table_Missing = 0x92 + 0,
  FT_Err_Hmtx_Table_Missing = 0x93 + 0,
  FT_Err_Post_Table_Missing = 0x94 + 0,
  FT_Err_Invalid_Horiz_Metrics = 0x95 + 0,
  FT_Err_Invalid_CharMap_Format = 0x96 + 0,
  FT_Err_Invalid_PPem = 0x97 + 0,
  FT_Err_Invalid_Vert_Metrics = 0x98 + 0,
  FT_Err_Could_Not_Find_Context = 0x99 + 0,
  FT_Err_Invalid_Post_Table_Format = 0x9A + 0,
  FT_Err_Invalid_Post_Table = 0x9B + 0,
  FT_Err_DEF_In_Glyf_Bytecode = 0x9C + 0,
  FT_Err_Missing_Bitmap = 0x9D + 0,
  FT_Err_Syntax_Error = 0xA0 + 0,
  FT_Err_Stack_Underflow = 0xA1 + 0,
  FT_Err_Ignore = 0xA2 + 0,
  FT_Err_No_Unicode_Glyph_Name = 0xA3 + 0,
  FT_Err_Glyph_Too_Big = 0xA4 + 0,
  FT_Err_Missing_Startfont_Field = 0xB0 + 0,
  FT_Err_Missing_Font_Field = 0xB1 + 0,
  FT_Err_Missing_Size_Field = 0xB2 + 0,
  FT_Err_Missing_Fontboundingbox_Field = 0xB3 + 0,
  FT_Err_Missing_Chars_Field = 0xB4 + 0,
  FT_Err_Missing_Startchar_Field = 0xB5 + 0,
  FT_Err_Missing_Encoding_Field = 0xB6 + 0,
  FT_Err_Missing_Bbx_Field = 0xB7 + 0,
  FT_Err_Bbx_Too_Big = 0xB8 + 0,
  FT_Err_Corrupted_Font_Header = 0xB9 + 0,
  FT_Err_Corrupted_Font_Glyphs = 0xBA + 0,
  FT_Err_Max };
  extern const char*
  FT_Error_String( FT_Error error_code );
  typedef struct FT_Glyph_Metrics_
  {
    FT_Pos width;
    FT_Pos height;
    FT_Pos horiBearingX;
    FT_Pos horiBearingY;
    FT_Pos horiAdvance;
    FT_Pos vertBearingX;
    FT_Pos vertBearingY;
    FT_Pos vertAdvance;
  } FT_Glyph_Metrics;
  typedef struct FT_Bitmap_Size_
  {
    FT_Short height;
    FT_Short width;
    FT_Pos size;
    FT_Pos x_ppem;
    FT_Pos y_ppem;
  } FT_Bitmap_Size;
  typedef struct FT_LibraryRec_ *FT_Library;
  typedef struct FT_ModuleRec_* FT_Module;
  typedef struct FT_DriverRec_* FT_Driver;
  typedef struct FT_RendererRec_* FT_Renderer;
  typedef struct FT_FaceRec_* FT_Face;
  typedef struct FT_SizeRec_* FT_Size;
  typedef struct FT_GlyphSlotRec_* FT_GlyphSlot;
  typedef struct FT_CharMapRec_* FT_CharMap;
  typedef enum FT_Encoding_
  {
    FT_ENCODING_NONE = ( ( (FT_UInt32)(0) << 24 ) | ( (FT_UInt32)(0) << 16 ) | ( (FT_UInt32)(0) << 8 ) | (FT_UInt32)(0) ),
    FT_ENCODING_MS_SYMBOL = ( ( (FT_UInt32)('s') << 24 ) | ( (FT_UInt32)('y') << 16 ) | ( (FT_UInt32)('m') << 8 ) | (FT_UInt32)('b') ),
    FT_ENCODING_UNICODE = ( ( (FT_UInt32)('u') << 24 ) | ( (FT_UInt32)('n') << 16 ) | ( (FT_UInt32)('i') << 8 ) | (FT_UInt32)('c') ),
    FT_ENCODING_SJIS = ( ( (FT_UInt32)('s') << 24 ) | ( (FT_UInt32)('j') << 16 ) | ( (FT_UInt32)('i') << 8 ) | (FT_UInt32)('s') ),
    FT_ENCODING_PRC = ( ( (FT_UInt32)('g') << 24 ) | ( (FT_UInt32)('b') << 16 ) | ( (FT_UInt32)(' ') << 8 ) | (FT_UInt32)(' ') ),
    FT_ENCODING_BIG5 = ( ( (FT_UInt32)('b') << 24 ) | ( (FT_UInt32)('i') << 16 ) | ( (FT_UInt32)('g') << 8 ) | (FT_UInt32)('5') ),
    FT_ENCODING_WANSUNG = ( ( (FT_UInt32)('w') << 24 ) | ( (FT_UInt32)('a') << 16 ) | ( (FT_UInt32)('n') << 8 ) | (FT_UInt32)('s') ),
    FT_ENCODING_JOHAB = ( ( (FT_UInt32)('j') << 24 ) | ( (FT_UInt32)('o') << 16 ) | ( (FT_UInt32)('h') << 8 ) | (FT_UInt32)('a') ),
    FT_ENCODING_GB2312 = FT_ENCODING_PRC,
    FT_ENCODING_MS_SJIS = FT_ENCODING_SJIS,
    FT_ENCODING_MS_GB2312 = FT_ENCODING_PRC,
    FT_ENCODING_MS_BIG5 = FT_ENCODING_BIG5,
    FT_ENCODING_MS_WANSUNG = FT_ENCODING_WANSUNG,
    FT_ENCODING_MS_JOHAB = FT_ENCODING_JOHAB,
    FT_ENCODING_ADOBE_STANDARD = ( ( (FT_UInt32)('A') << 24 ) | ( (FT_UInt32)('D') << 16 ) | ( (FT_UInt32)('O') << 8 ) | (FT_UInt32)('B') ),
    FT_ENCODING_ADOBE_EXPERT = ( ( (FT_UInt32)('A') << 24 ) | ( (FT_UInt32)('D') << 16 ) | ( (FT_UInt32)('B') << 8 ) | (FT_UInt32)('E') ),
    FT_ENCODING_ADOBE_CUSTOM = ( ( (FT_UInt32)('A') << 24 ) | ( (FT_UInt32)('D') << 16 ) | ( (FT_UInt32)('B') << 8 ) | (FT_UInt32)('C') ),
    FT_ENCODING_ADOBE_LATIN_1 = ( ( (FT_UInt32)('l') << 24 ) | ( (FT_UInt32)('a') << 16 ) | ( (FT_UInt32)('t') << 8 ) | (FT_UInt32)('1') ),
    FT_ENCODING_OLD_LATIN_2 = ( ( (FT_UInt32)('l') << 24 ) | ( (FT_UInt32)('a') << 16 ) | ( (FT_UInt32)('t') << 8 ) | (FT_UInt32)('2') ),
    FT_ENCODING_APPLE_ROMAN = ( ( (FT_UInt32)('a') << 24 ) | ( (FT_UInt32)('r') << 16 ) | ( (FT_UInt32)('m') << 8 ) | (FT_UInt32)('n') )
  } FT_Encoding;
  typedef struct FT_CharMapRec_
  {
    FT_Face face;
    FT_Encoding encoding;
    FT_UShort platform_id;
    FT_UShort encoding_id;
  } FT_CharMapRec;
  typedef struct FT_Face_InternalRec_* FT_Face_Internal;
  typedef struct FT_FaceRec_
  {
    FT_Long num_faces;
    FT_Long face_index;
    FT_Long face_flags;
    FT_Long style_flags;
    FT_Long num_glyphs;
    FT_String* family_name;
    FT_String* style_name;
    FT_Int num_fixed_sizes;
    FT_Bitmap_Size* available_sizes;
    FT_Int num_charmaps;
    FT_CharMap* charmaps;
    FT_Generic generic;
    FT_BBox bbox;
    FT_UShort units_per_EM;
    FT_Short ascender;
    FT_Short descender;
    FT_Short height;
    FT_Short max_advance_width;
    FT_Short max_advance_height;
    FT_Short underline_position;
    FT_Short underline_thickness;
    FT_GlyphSlot glyph;
    FT_Size size;
    FT_CharMap charmap;
    FT_Driver driver;
    FT_Memory memory;
    FT_Stream stream;
    FT_ListRec sizes_list;
    FT_Generic autohint;
    void* extensions;
    FT_Face_Internal internal;
  } FT_FaceRec;
  typedef struct FT_Size_InternalRec_* FT_Size_Internal;
  typedef struct FT_Size_Metrics_
  {
    FT_UShort x_ppem;
    FT_UShort y_ppem;
    FT_Fixed x_scale;
    FT_Fixed y_scale;
    FT_Pos ascender;
    FT_Pos descender;
    FT_Pos height;
    FT_Pos max_advance;
  } FT_Size_Metrics;
  typedef struct FT_SizeRec_
  {
    FT_Face face;
    FT_Generic generic;
    FT_Size_Metrics metrics;
    FT_Size_Internal internal;
  } FT_SizeRec;
  typedef struct FT_SubGlyphRec_* FT_SubGlyph;
  typedef struct FT_Slot_InternalRec_* FT_Slot_Internal;
  typedef struct FT_GlyphSlotRec_
  {
    FT_Library library;
    FT_Face face;
    FT_GlyphSlot next;
    FT_UInt glyph_index;
    FT_Generic generic;
    FT_Glyph_Metrics metrics;
    FT_Fixed linearHoriAdvance;
    FT_Fixed linearVertAdvance;
    FT_Vector advance;
    FT_Glyph_Format format;
    FT_Bitmap bitmap;
    FT_Int bitmap_left;
    FT_Int bitmap_top;
    FT_Outline outline;
    FT_UInt num_subglyphs;
    FT_SubGlyph subglyphs;
    void* control_data;
    long control_len;
    FT_Pos lsb_delta;
    FT_Pos rsb_delta;
    void* other;
    FT_Slot_Internal internal;
  } FT_GlyphSlotRec;
  extern FT_Error
  FT_Init_FreeType( FT_Library *alibrary );
  extern FT_Error
  FT_Done_FreeType( FT_Library library );
  typedef struct FT_Parameter_
  {
    FT_ULong tag;
    FT_Pointer data;
  } FT_Parameter;
  typedef struct FT_Open_Args_
  {
    FT_UInt flags;
    const FT_Byte* memory_base;
    FT_Long memory_size;
    FT_String* pathname;
    FT_Stream stream;
    FT_Module driver;
    FT_Int num_params;
    FT_Parameter* params;
  } FT_Open_Args;
  extern FT_Error
  FT_New_Face( FT_Library library,
               const char* filepathname,
               FT_Long face_index,
               FT_Face *aface );
  extern FT_Error
  FT_New_Memory_Face( FT_Library library,
                      const FT_Byte* file_base,
                      FT_Long file_size,
                      FT_Long face_index,
                      FT_Face *aface );
  extern FT_Error
  FT_Open_Face( FT_Library library,
                const FT_Open_Args* args,
                FT_Long face_index,
                FT_Face *aface );
  extern FT_Error
  FT_Attach_File( FT_Face face,
                  const char* filepathname );
  extern FT_Error
  FT_Attach_Stream( FT_Face face,
                    FT_Open_Args* parameters );
  extern FT_Error
  FT_Reference_Face( FT_Face face );
  extern FT_Error
  FT_Done_Face( FT_Face face );
  extern FT_Error
  FT_Select_Size( FT_Face face,
                  FT_Int strike_index );
  typedef enum FT_Size_Request_Type_
  {
    FT_SIZE_REQUEST_TYPE_NOMINAL,
    FT_SIZE_REQUEST_TYPE_REAL_DIM,
    FT_SIZE_REQUEST_TYPE_BBOX,
    FT_SIZE_REQUEST_TYPE_CELL,
    FT_SIZE_REQUEST_TYPE_SCALES,
    FT_SIZE_REQUEST_TYPE_MAX
  } FT_Size_Request_Type;
  typedef struct FT_Size_RequestRec_
  {
    FT_Size_Request_Type type;
    FT_Long width;
    FT_Long height;
    FT_UInt horiResolution;
    FT_UInt vertResolution;
  } FT_Size_RequestRec;
  typedef struct FT_Size_RequestRec_ *FT_Size_Request;
  extern FT_Error
  FT_Request_Size( FT_Face face,
                   FT_Size_Request req );
  extern FT_Error
  FT_Set_Char_Size( FT_Face face,
                    FT_F26Dot6 char_width,
                    FT_F26Dot6 char_height,
                    FT_UInt horz_resolution,
                    FT_UInt vert_resolution );
  extern FT_Error
  FT_Set_Pixel_Sizes( FT_Face face,
                      FT_UInt pixel_width,
                      FT_UInt pixel_height );
  extern FT_Error
  FT_Load_Glyph( FT_Face face,
                 FT_UInt glyph_index,
                 FT_Int32 load_flags );
  extern FT_Error
  FT_Load_Char( FT_Face face,
                FT_ULong char_code,
                FT_Int32 load_flags );
  extern void
  FT_Set_Transform( FT_Face face,
                    FT_Matrix* matrix,
                    FT_Vector* delta );
  typedef enum FT_Render_Mode_
  {
    FT_RENDER_MODE_NORMAL = 0,
    FT_RENDER_MODE_LIGHT,
    FT_RENDER_MODE_MONO,
    FT_RENDER_MODE_LCD,
    FT_RENDER_MODE_LCD_V,
    FT_RENDER_MODE_MAX
  } FT_Render_Mode;
  extern FT_Error
  FT_Render_Glyph( FT_GlyphSlot slot,
                   FT_Render_Mode render_mode );
  typedef enum FT_Kerning_Mode_
  {
    FT_KERNING_DEFAULT = 0,
    FT_KERNING_UNFITTED,
    FT_KERNING_UNSCALED
  } FT_Kerning_Mode;
  extern FT_Error
  FT_Get_Kerning( FT_Face face,
                  FT_UInt left_glyph,
                  FT_UInt right_glyph,
                  FT_UInt kern_mode,
                  FT_Vector *akerning );
  extern FT_Error
  FT_Get_Track_Kerning( FT_Face face,
                        FT_Fixed point_size,
                        FT_Int degree,
                        FT_Fixed* akerning );
  extern FT_Error
  FT_Get_Glyph_Name( FT_Face face,
                     FT_UInt glyph_index,
                     FT_Pointer buffer,
                     FT_UInt buffer_max );
  extern const char*
  FT_Get_Postscript_Name( FT_Face face );
  extern FT_Error
  FT_Select_Charmap( FT_Face face,
                     FT_Encoding encoding );
  extern FT_Error
  FT_Set_Charmap( FT_Face face,
                  FT_CharMap charmap );
  extern FT_Int
  FT_Get_Charmap_Index( FT_CharMap charmap );
  extern FT_UInt
  FT_Get_Char_Index( FT_Face face,
                     FT_ULong charcode );
  extern FT_ULong
  FT_Get_First_Char( FT_Face face,
                     FT_UInt *agindex );
  extern FT_ULong
  FT_Get_Next_Char( FT_Face face,
                    FT_ULong char_code,
                    FT_UInt *agindex );
  extern FT_Error
  FT_Face_Properties( FT_Face face,
                      FT_UInt num_properties,
                      FT_Parameter* properties );
  extern FT_UInt
  FT_Get_Name_Index( FT_Face face,
                     const FT_String* glyph_name );
  extern FT_Error
  FT_Get_SubGlyph_Info( FT_GlyphSlot glyph,
                        FT_UInt sub_index,
                        FT_Int *p_index,
                        FT_UInt *p_flags,
                        FT_Int *p_arg1,
                        FT_Int *p_arg2,
                        FT_Matrix *p_transform );
  typedef struct FT_LayerIterator_
  {
    FT_UInt num_layers;
    FT_UInt layer;
    FT_Byte* p;
  } FT_LayerIterator;
  extern FT_Bool
  FT_Get_Color_Glyph_Layer( FT_Face face,
                            FT_UInt base_glyph,
                            FT_UInt *aglyph_index,
                            FT_UInt *acolor_index,
                            FT_LayerIterator* iterator );
  extern FT_UShort
  FT_Get_FSType_Flags( FT_Face face );
  extern FT_UInt
  FT_Face_GetCharVariantIndex( FT_Face face,
                               FT_ULong charcode,
                               FT_ULong variantSelector );
  extern FT_Int
  FT_Face_GetCharVariantIsDefault( FT_Face face,
                                   FT_ULong charcode,
                                   FT_ULong variantSelector );
  extern FT_UInt32*
  FT_Face_GetVariantSelectors( FT_Face face );
  extern FT_UInt32*
  FT_Face_GetVariantsOfChar( FT_Face face,
                             FT_ULong charcode );
  extern FT_UInt32*
  FT_Face_GetCharsOfVariant( FT_Face face,
                             FT_ULong variantSelector );
  extern FT_Long
  FT_MulDiv( FT_Long a,
             FT_Long b,
             FT_Long c );
  extern FT_Long
  FT_MulFix( FT_Long a,
             FT_Long b );
  extern FT_Long
  FT_DivFix( FT_Long a,
             FT_Long b );
  extern FT_Fixed
  FT_RoundFix( FT_Fixed a );
  extern FT_Fixed
  FT_CeilFix( FT_Fixed a );
  extern FT_Fixed
  FT_FloorFix( FT_Fixed a );
  extern void
  FT_Vector_Transform( FT_Vector* vector,
                       const FT_Matrix* matrix );
  extern void
  FT_Library_Version( FT_Library library,
                      FT_Int *amajor,
                      FT_Int *aminor,
                      FT_Int *apatch );
  extern FT_Bool
  FT_Face_CheckTrueTypePatents( FT_Face face );
  extern FT_Bool
  FT_Face_SetUnpatentedHinting( FT_Face face,
                                FT_Bool value );
  typedef FT_Pointer FT_Module_Interface;
  typedef FT_Error
  (*FT_Module_Constructor)( FT_Module module );
  typedef void
  (*FT_Module_Destructor)( FT_Module module );
  typedef FT_Module_Interface
  (*FT_Module_Requester)( FT_Module module,
                          const char* name );
  typedef struct FT_Module_Class_
  {
    FT_ULong module_flags;
    FT_Long module_size;
    const FT_String* module_name;
    FT_Fixed module_version;
    FT_Fixed module_requires;
    const void* module_interface;
    FT_Module_Constructor module_init;
    FT_Module_Destructor module_done;
    FT_Module_Requester get_interface;
  } FT_Module_Class;
  extern FT_Error
  FT_Add_Module( FT_Library library,
                 const FT_Module_Class* clazz );
  extern FT_Module
  FT_Get_Module( FT_Library library,
                 const char* module_name );
  extern FT_Error
  FT_Remove_Module( FT_Library library,
                    FT_Module module );
  extern FT_Error
  FT_Property_Set( FT_Library library,
                   const FT_String* module_name,
                   const FT_String* property_name,
                   const void* value );
  extern FT_Error
  FT_Property_Get( FT_Library library,
                   const FT_String* module_name,
                   const FT_String* property_name,
                   void* value );
  extern void
  FT_Set_Default_Properties( FT_Library library );
  extern FT_Error
  FT_Reference_Library( FT_Library library );
  extern FT_Error
  FT_New_Library( FT_Memory memory,
                  FT_Library *alibrary );
  extern FT_Error
  FT_Done_Library( FT_Library library );
  typedef FT_Error
  (*FT_DebugHook_Func)( void* arg );
  extern void
  FT_Set_Debug_Hook( FT_Library library,
                     FT_UInt hook_index,
                     FT_DebugHook_Func debug_hook );
  extern void
  FT_Add_Default_Modules( FT_Library library );
  typedef enum FT_TrueTypeEngineType_
  {
    FT_TRUETYPE_ENGINE_TYPE_NONE = 0,
    FT_TRUETYPE_ENGINE_TYPE_UNPATENTED,
    FT_TRUETYPE_ENGINE_TYPE_PATENTED
  } FT_TrueTypeEngineType;
  extern FT_TrueTypeEngineType
  FT_Get_TrueType_Engine_Type( FT_Library library );
  typedef struct FT_Glyph_Class_ FT_Glyph_Class;
  typedef struct FT_GlyphRec_* FT_Glyph;
  typedef struct FT_GlyphRec_
  {
    FT_Library library;
    const FT_Glyph_Class* clazz;
    FT_Glyph_Format format;
    FT_Vector advance;
  } FT_GlyphRec;
  typedef struct FT_BitmapGlyphRec_* FT_BitmapGlyph;
  typedef struct FT_BitmapGlyphRec_
  {
    FT_GlyphRec root;
    FT_Int left;
    FT_Int top;
    FT_Bitmap bitmap;
  } FT_BitmapGlyphRec;
  typedef struct FT_OutlineGlyphRec_* FT_OutlineGlyph;
  typedef struct FT_OutlineGlyphRec_
  {
    FT_GlyphRec root;
    FT_Outline outline;
  } FT_OutlineGlyphRec;
  extern FT_Error
  FT_New_Glyph( FT_Library library,
                FT_Glyph_Format format,
                FT_Glyph *aglyph );
  extern FT_Error
  FT_Get_Glyph( FT_GlyphSlot slot,
                FT_Glyph *aglyph );
  extern FT_Error
  FT_Glyph_Copy( FT_Glyph source,
                 FT_Glyph *target );
  extern FT_Error
  FT_Glyph_Transform( FT_Glyph glyph,
                      FT_Matrix* matrix,
                      FT_Vector* delta );
  typedef enum FT_Glyph_BBox_Mode_
  {
    FT_GLYPH_BBOX_UNSCALED = 0,
    FT_GLYPH_BBOX_SUBPIXELS = 0,
    FT_GLYPH_BBOX_GRIDFIT = 1,
    FT_GLYPH_BBOX_TRUNCATE = 2,
    FT_GLYPH_BBOX_PIXELS = 3
  } FT_Glyph_BBox_Mode;
  extern void
  FT_Glyph_Get_CBox( FT_Glyph glyph,
                     FT_UInt bbox_mode,
                     FT_BBox *acbox );
  extern FT_Error
  FT_Glyph_To_Bitmap( FT_Glyph* the_glyph,
                      FT_Render_Mode render_mode,
                      FT_Vector* origin,
                      FT_Bool destroy );
  extern void
  FT_Done_Glyph( FT_Glyph glyph );
  extern void
  FT_Matrix_Multiply( const FT_Matrix* a,
                      FT_Matrix* b );
  extern FT_Error
  FT_Matrix_Invert( FT_Matrix* matrix );
  extern void
  FT_GlyphSlot_Embolden( FT_GlyphSlot slot );
  extern void
  FT_GlyphSlot_Oblique( FT_GlyphSlot slot );
  extern FT_Error
  FT_Outline_Decompose( FT_Outline* outline,
                        const FT_Outline_Funcs* func_interface,
                        void* user );
  extern FT_Error
  FT_Outline_New( FT_Library library,
                  FT_UInt numPoints,
                  FT_Int numContours,
                  FT_Outline *anoutline );
  extern FT_Error
  FT_Outline_Done( FT_Library library,
                   FT_Outline* outline );
  extern FT_Error
  FT_Outline_Check( FT_Outline* outline );
  extern void
  FT_Outline_Get_CBox( const FT_Outline* outline,
                       FT_BBox *acbox );
  extern void
  FT_Outline_Translate( const FT_Outline* outline,
                        FT_Pos xOffset,
                        FT_Pos yOffset );
  extern FT_Error
  FT_Outline_Copy( const FT_Outline* source,
                   FT_Outline *target );
  extern void
  FT_Outline_Transform( const FT_Outline* outline,
                        const FT_Matrix* matrix );
  extern FT_Error
  FT_Outline_Embolden( FT_Outline* outline,
                       FT_Pos strength );
  extern FT_Error
  FT_Outline_EmboldenXY( FT_Outline* outline,
                         FT_Pos xstrength,
                         FT_Pos ystrength );
  extern void
  FT_Outline_Reverse( FT_Outline* outline );
  extern FT_Error
  FT_Outline_Get_Bitmap( FT_Library library,
                         FT_Outline* outline,
                         const FT_Bitmap *abitmap );
  extern FT_Error
  FT_Outline_Render( FT_Library library,
                     FT_Outline* outline,
                     FT_Raster_Params* params );
  typedef enum FT_Orientation_
  {
    FT_ORIENTATION_TRUETYPE = 0,
    FT_ORIENTATION_POSTSCRIPT = 1,
    FT_ORIENTATION_FILL_RIGHT = FT_ORIENTATION_TRUETYPE,
    FT_ORIENTATION_FILL_LEFT = FT_ORIENTATION_POSTSCRIPT,
    FT_ORIENTATION_NONE
  } FT_Orientation;
  extern FT_Orientation
  FT_Outline_Get_Orientation( FT_Outline* outline );]]
ffi_cdef[[static const int FT_RENDER_POOL_SIZE = 16384L;
static const int FT_MAX_MODULES = 32;
static const int FT_OUTLINE_NONE = 0x0;
static const int FT_OUTLINE_OWNER = 0x1;
static const int FT_OUTLINE_EVEN_ODD_FILL = 0x2;
static const int FT_OUTLINE_REVERSE_FILL = 0x4;
static const int FT_OUTLINE_IGNORE_DROPOUTS = 0x8;
static const int FT_OUTLINE_SMART_DROPOUTS = 0x10;
static const int FT_OUTLINE_INCLUDE_STUBS = 0x20;
static const int FT_OUTLINE_OVERLAP = 0x40;
static const int FT_OUTLINE_HIGH_PRECISION = 0x100;
static const int FT_OUTLINE_SINGLE_PASS = 0x200;
static const int FT_CURVE_TAG_ON = 0x01;
static const int FT_CURVE_TAG_CONIC = 0x00;
static const int FT_CURVE_TAG_CUBIC = 0x02;
static const int FT_CURVE_TAG_HAS_SCANMODE = 0x04;
static const int FT_CURVE_TAG_TOUCH_X = 0x08;
static const int FT_CURVE_TAG_TOUCH_Y = 0x10;
static const int FT_CURVE_TAG_TOUCH_BOTH = ( FT_CURVE_TAG_TOUCH_X | FT_CURVE_TAG_TOUCH_Y );
static const int FT_Curve_Tag_On = FT_CURVE_TAG_ON;
static const int FT_Curve_Tag_Conic = FT_CURVE_TAG_CONIC;
static const int FT_Curve_Tag_Cubic = FT_CURVE_TAG_CUBIC;
static const int FT_Curve_Tag_Touch_X = FT_CURVE_TAG_TOUCH_X;
static const int FT_Curve_Tag_Touch_Y = FT_CURVE_TAG_TOUCH_Y;
static const int FT_RASTER_FLAG_DEFAULT = 0x0;
static const int FT_RASTER_FLAG_AA = 0x1;
static const int FT_RASTER_FLAG_DIRECT = 0x2;
static const int FT_RASTER_FLAG_CLIP = 0x4;
static const int FT_ERR_BASE = 0;
static const int FT_FACE_FLAG_SCALABLE = ( 1L << 0 );
static const int FT_FACE_FLAG_FIXED_SIZES = ( 1L << 1 );
static const int FT_FACE_FLAG_FIXED_WIDTH = ( 1L << 2 );
static const int FT_FACE_FLAG_SFNT = ( 1L << 3 );
static const int FT_FACE_FLAG_HORIZONTAL = ( 1L << 4 );
static const int FT_FACE_FLAG_VERTICAL = ( 1L << 5 );
static const int FT_FACE_FLAG_KERNING = ( 1L << 6 );
static const int FT_FACE_FLAG_FAST_GLYPHS = ( 1L << 7 );
static const int FT_FACE_FLAG_MULTIPLE_MASTERS = ( 1L << 8 );
static const int FT_FACE_FLAG_GLYPH_NAMES = ( 1L << 9 );
static const int FT_FACE_FLAG_EXTERNAL_STREAM = ( 1L << 10 );
static const int FT_FACE_FLAG_HINTER = ( 1L << 11 );
static const int FT_FACE_FLAG_CID_KEYED = ( 1L << 12 );
static const int FT_FACE_FLAG_TRICKY = ( 1L << 13 );
static const int FT_FACE_FLAG_COLOR = ( 1L << 14 );
static const int FT_FACE_FLAG_VARIATION = ( 1L << 15 );
static const int FT_STYLE_FLAG_ITALIC = ( 1 << 0 );
static const int FT_STYLE_FLAG_BOLD = ( 1 << 1 );
static const int FT_OPEN_MEMORY = 0x1;
static const int FT_OPEN_STREAM = 0x2;
static const int FT_OPEN_PATHNAME = 0x4;
static const int FT_OPEN_DRIVER = 0x8;
static const int FT_OPEN_PARAMS = 0x10;
static const int FT_LOAD_DEFAULT = 0x0;
static const int FT_LOAD_NO_SCALE = ( 1L << 0 );
static const int FT_LOAD_NO_HINTING = ( 1L << 1 );
static const int FT_LOAD_RENDER = ( 1L << 2 );
static const int FT_LOAD_NO_BITMAP = ( 1L << 3 );
static const int FT_LOAD_VERTICAL_LAYOUT = ( 1L << 4 );
static const int FT_LOAD_FORCE_AUTOHINT = ( 1L << 5 );
static const int FT_LOAD_CROP_BITMAP = ( 1L << 6 );
static const int FT_LOAD_PEDANTIC = ( 1L << 7 );
static const int FT_LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH = ( 1L << 9 );
static const int FT_LOAD_NO_RECURSE = ( 1L << 10 );
static const int FT_LOAD_IGNORE_TRANSFORM = ( 1L << 11 );
static const int FT_LOAD_MONOCHROME = ( 1L << 12 );
static const int FT_LOAD_LINEAR_DESIGN = ( 1L << 13 );
static const int FT_LOAD_NO_AUTOHINT = ( 1L << 15 );
static const int FT_LOAD_COLOR = ( 1L << 20 );
static const int FT_LOAD_COMPUTE_METRICS = ( 1L << 21 );
static const int FT_LOAD_BITMAP_METRICS_ONLY = ( 1L << 22 );
static const int FT_LOAD_ADVANCE_ONLY = ( 1L << 8 );
static const int FT_LOAD_SBITS_ONLY = ( 1L << 14 );
static const int FT_SUBGLYPH_FLAG_ARGS_ARE_WORDS = 1;
static const int FT_SUBGLYPH_FLAG_ARGS_ARE_XY_VALUES = 2;
static const int FT_SUBGLYPH_FLAG_ROUND_XY_TO_GRID = 4;
static const int FT_SUBGLYPH_FLAG_SCALE = 8;
static const int FT_SUBGLYPH_FLAG_XY_SCALE = 0x40;
static const int FT_SUBGLYPH_FLAG_2X2 = 0x80;
static const int FT_SUBGLYPH_FLAG_USE_MY_METRICS = 0x200;
static const int FT_FSTYPE_INSTALLABLE_EMBEDDING = 0x0000;
static const int FT_FSTYPE_RESTRICTED_LICENSE_EMBEDDING = 0x0002;
static const int FT_FSTYPE_PREVIEW_AND_PRINT_EMBEDDING = 0x0004;
static const int FT_FSTYPE_EDITABLE_EMBEDDING = 0x0008;
static const int FT_FSTYPE_NO_SUBSETTING = 0x0100;
static const int FT_FSTYPE_BITMAP_EMBEDDING_ONLY = 0x0200;
static const int FT_MODULE_FONT_DRIVER = 1;
static const int FT_MODULE_RENDERER = 2;
static const int FT_MODULE_HINTER = 4;
static const int FT_MODULE_STYLER = 8;
static const int FT_MODULE_DRIVER_SCALABLE = 0x100;
static const int FT_MODULE_DRIVER_NO_OUTLINES = 0x200;
static const int FT_MODULE_DRIVER_HAS_HINTER = 0x400;
static const int FT_MODULE_DRIVER_HINTS_LIGHTLY = 0x800;
static const int FT_DEBUG_HOOK_TRUETYPE = 0;]]