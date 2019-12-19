local ffi = require"ffi"

ffi.cdef[[
typedef uint32_t PAR_MSQUARES_T;
typedef uint8_t par_byte;
typedef struct par_msquares_meshlist_s par_msquares_meshlist;

// Results of a marching squares operation.  Triangles are counter-clockwise.
typedef struct {
    float* points;        // pointer to XY (or XYZ) vertex coordinates
    int npoints;          // number of vertex coordinates
    PAR_MSQUARES_T* triangles;  // pointer to 3-tuples of vertex indices
    int ntriangles;       // number of 3-tuples
    int dim;              // number of floats per point (either 2 or 3)
    uint32_t color;       // used only with par_msquares_color_multi
} par_msquares_mesh;

typedef struct {
    PAR_MSQUARES_T* values;
    size_t count;
    size_t capacity;
} par__uint16list;

typedef struct {
    float* points;
    int npoints;
    PAR_MSQUARES_T* triangles;
    int ntriangles;
    int dim;
    uint32_t color;
    int nconntriangles;
    PAR_MSQUARES_T* conntri;
    par__uint16list* tjunctions;
} par_msquares__mesh;

struct par_msquares_meshlist_s {
    int nmeshes;
    par_msquares__mesh** meshes;
};

// Polyline boundary extracted from a mesh, composed of one or more chains.
// Counterclockwise chains are solid, clockwise chains are holes.  So, when
// serializing to SVG, all chains can be aggregated in a single <path>,
// provided they each terminate with a "Z" and use the default fill rule.
typedef struct {
    float* points;        // list of XY vertex coordinates
    int npoints;          // number of vertex coordinates
    float** chains;       // list of pointers to the start of each chain
    PAR_MSQUARES_T* lengths;    // list of chain lengths
    int nchains;          // number of chains
} par_msquares_boundary;

par_msquares_meshlist* par_msquares_grayscale(float const* data, int width,
    int height, int cellsize, float threshold, int flags);
par_msquares_meshlist* par_msquares_grayscale_multi(float const* data,
    int width, int height, int cellsize, float const* thresholds,
    int nthresholds, int flags);
par_msquares_meshlist* par_msquares_color(par_byte const* data, int width,
    int height, int cellsize, uint32_t color, int bpp, int flags);
par_msquares_meshlist* par_msquares_color_multi(par_byte const* data, int width,
    int height, int cellsize, int bpp, int flags);
par_msquares_mesh const* par_msquares_get_mesh(par_msquares_meshlist*, int n);
int par_msquares_get_count(par_msquares_meshlist*);
void par_msquares_free(par_msquares_meshlist*);
par_msquares_boundary* par_msquares_extract_boundary(par_msquares_mesh const* );
]]

local lib = ffi.load[[msquares]]
---[[
local par_msquares = {lib=lib}
-- Reverses the "insideness" test.
par_msquares.INVERT = 1

-- Returns a meshlist with two meshes: one for the inside, one for the outside.
par_msquares.DUAL = 2

-- Requests that returned meshes have 3-tuple coordinates instead of 2-tuples.
-- When using a color-based function, the Z coordinate represents the alpha
-- value of the nearest pixel.
par_msquares.HEIGHTS = 4

-- Applies a step function to the Z coordinates.  Requires HEIGHTS and DUAL.
par_msquares.SNAP = 8

-- Adds extrusion triangles to each mesh other than the lowest mesh.  Requires
-- the PAR_MSQUARES_HEIGHTS flag to be present.
par_msquares.CONNECT = 16

-- Enables quick & dirty (not best) simpification of the returned mesh.
par_msquares.SIMPLIFY = 32

-- Indicates that the "color" argument is ABGR instead of ARGB.
par_msquares.SWIZZLE = 64

-- Ensures there are no T-junction vertices. (par_msquares_color_multi only)
-- Requires the PAR_MSQUARES_SIMPLIFY flag to be disabled.
par_msquares.CLEAN = 128

--]]

local par_msquares_mt = {
	__index = function(t,k)
		local fname = string.format("par_msquares_%s", k)
		local ok,ret = pcall(function() return lib[fname] end)
		if not ok then error("Couldn't find pointer type for "..fname.." (are you accessing the right function?)",2) end
	
		rawset(par_msquares, k,ret )
		return ret
	end,
	-- __gc = function(m) print("__gc called"); 
		-- return lib.par_msquares_free(m) 
	-- end
}
par_msquares = setmetatable(par_msquares,par_msquares_mt)
return par_msquares