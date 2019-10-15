local ffi = require"ffi"

ffi.cdef[[
typedef uint32_t PAR_SHAPES_T ;

typedef struct par_shapes_mesh_s {
    float* points;           // Flat list of 3-tuples (X Y Z X Y Z...)
    int npoints;             // Number of points
    PAR_SHAPES_T* triangles; // Flat list of 3-tuples (I J K I J K...)
    int ntriangles;          // Number of triangles
    float* normals;          // Optional list of 3-tuples (X Y Z X Y Z...)
    float* tcoords;          // Optional list of 2-tuples (U V U V U V...)
} par_shapes_mesh;

typedef void (*par_shapes_fn)(float const*, float*, void*);

void par_shapes_free_mesh(par_shapes_mesh* mesh);

par_shapes_mesh* par_shapes_create_octohedron();
par_shapes_mesh* par_shapes_create_tetrahedron();
par_shapes_mesh* par_shapes_create_cube();

par_shapes_mesh* par_shapes_create_parametric_sphere(int slices, int stacks);
par_shapes_mesh* par_shapes_create_subdivided_sphere(int nsubdivisions);
par_shapes_mesh* par_shapes_create_cylinder(int slices, int stacks);
par_shapes_mesh* par_shapes_create_plane(int slices, int stacks);
par_shapes_mesh* par_shapes_create_empty();
par_shapes_mesh* par_shapes_create_lsystem(char const* text, int slices,int maxdepth);
par_shapes_mesh* par_shapes_create_parametric(par_shapes_fn fn, int slices, int stacks, void* userdata);
par_shapes_mesh* par_shapes_create_disk(float radius, int slices,float const* center, float const* normal);
par_shapes_mesh* par_shapes_create_torus(int slices, int stacks, float radius);
par_shapes_mesh* par_shapes_create_hemisphere(int slices, int stacks);

void par_shapes_compute_normals(par_shapes_mesh* m);
void par_shapes__compute_welded_normals(par_shapes_mesh* m);
void par_shapes_unweld(par_shapes_mesh* mesh, bool create_indices);
par_shapes_mesh* par_shapes_weld(par_shapes_mesh const* mesh, float epsilon,PAR_SHAPES_T* weldmap);
par_shapes_mesh* par_shapes_clone(par_shapes_mesh const* mesh,par_shapes_mesh* target);

void par_shapes__connect(par_shapes_mesh* scene,par_shapes_mesh* cylinder, int slices);
void par_shapes_merge(par_shapes_mesh* dst, par_shapes_mesh const* src);
void par_shapes_translate(par_shapes_mesh*, float x, float y, float z);
void par_shapes_rotate(par_shapes_mesh*, float radians, float const* axis);
void par_shapes_scale(par_shapes_mesh*, float x, float y, float z);
void par_shapes_merge_and_free(par_shapes_mesh* dst, par_shapes_mesh* src);
void par_shapes_remove_degenerate(par_shapes_mesh*, float minarea);
]]

local lib = ffi.load[[shapes]]

local par_shapes = {lib=lib}

local mesh_mt = {
	translate = function(...) return lib.par_shapes_translate(...) end,
	rotate = function(...) return lib.par_shapes_rotate(...) end,
	scale = function(...) return lib.par_shapes_scale(...) end,
	merge = function(...) return lib.par_shapes_merge(...) end,
	merge_and_free = function(...) return lib.par_shapes_merge_and_free(...) end,
	connect = function(...) return lib.par_shapes__connect(...) end,
	compute_normals = function(...) return lib.par_shapes_compute_normals(...) end,
	compute_welded_normals = function(...) return lib.par_shapes__compute_welded_normals(...) end,
	weld = function(...) return lib.par_shapes_weld(...) end,
	unweld = function(m) return lib.par_shapes_unweld(m,true) end,
	clone = function(...) return lib.par_shapes_clone(...) end,
	remove_degenerate = function(...) return lib.par_shapes_remove_degenerate(...) end,
	free = function(m) ffi.gc(m,nil);return lib.par_shapes_free_mesh(m) end,
	__gc = function(m) print("__gc called"); 
		--return lib.par_shapes_free_mesh(m) 
	end
}
mesh_mt.__index = mesh_mt
local meshtype = ffi.metatype("par_shapes_mesh",mesh_mt)

local create_mt = {
	__index = function(t,k)
		local fname = string.format("par_shapes_create_%s", k)
		local ok,ret = pcall(function() return lib[fname] end)
		if not ok then error("Couldn't find pointer type for "..fname.." (are you accessing the right function?)",2) end
		local ret2 = function(...) 
			local rr = ret(...);
			assert(rr~=nil,"par_shapes returning nil");
			return ffi.gc(rr, lib.par_shapes_free_mesh) 
		end
		rawset(par_shapes.create, k,ret2 )
		return ret2
	end
}
par_shapes.create = setmetatable({},create_mt)

--custom creations
local conefunc = ffi.cast("par_shapes_fn",function(inp,out,us) 
		local u = math.pi * 2 * inp[1]
		local v = 1 - inp[0]
		out[0] = v * math.sin(u)
		out[1] = v * math.cos(u)
		out[2] = inp[0]
	end)
function par_shapes.create.cone(a,b)
	return lib.par_shapes_create_parametric(conefunc,a,b,nil)
end
function par_shapes.create.circle(a)
	return lib.par_shapes_create_parametric(function(inp,out,us) 
		local u = math.pi * 2 * inp[1]
		--local v = 1 - inp[0]
		out[0] = math.sin(u)
		out[1] = math.cos(u)
		out[2] = 0
	end,a,0,nil)
end
--local cone_tronco_func = ffi.cast("par_shapes_fn",
function par_shapes.create.cone_tronco(a,b,r2,inv)
	return lib.par_shapes_create_parametric(function(inp,out,us) 
		local u = math.pi * 2 * inp[1]
		local v
		if inv then
			v = inp[0]
		else
			v = 1 - inp[0]
		end
		v = r2 + v*(1-r2)
		out[0] = v * math.sin(u)
		out[1] = v * math.cos(u)
		out[2] = inp[0]
	end,a,b,nil)
end
--[[
aa = par_shapes.create.circle(32)

print(collectgarbage("count"),"created")
aa = par_shapes.create.cylinder(32,32)
bb = ffi.new"par_shapes_mesh"
print(collectgarbage("count"),"created",aa,bb)
io.read"*l"
print(collectgarbage("count"),"created")
io.read"*l"
collectgarbage()
print(collectgarbage("count"),"created")
lib.par_shapes_free_mesh(aa)
aa = nil
bb=nil
io.read"*l"
collectgarbage()
print(collectgarbage("count"),"created")

io.read"*l"
collectgarbage()
print(collectgarbage("count"),"created")
print"done"
--]]
return par_shapes

