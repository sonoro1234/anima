local ffi = require"ffi"
local mat = require"anima.matrixffi"
--local mesh = require"anima.mesh"

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

par_shapes_mesh* par_shapes_create_octahedron();
par_shapes_mesh* par_shapes_create_tetrahedron();
par_shapes_mesh* par_shapes_create_cube();

par_shapes_mesh* par_shapes_create_klein_bottle(int slices, int stacks);
par_shapes_mesh* par_shapes_create_parametric_sphere(int slices, int stacks);
par_shapes_mesh* par_shapes_create_subdivided_sphere(int nsubdivisions);
par_shapes_mesh* par_shapes_create_cylinder(int slices, int stacks);
par_shapes_mesh* par_shapes_create_cone(int slices, int stacks);
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
void par_shapes_set_epsilon_welded_normals(float epsilon);
void par_shapes_set_epsilon_degenerate_sphere(float epsilon);
]]

local lib = ffi.load[[shapes]]


local par_shapes = {lib=lib}

local function par_shapes_vao(mesh,program)
	local vao =  VAO({position=mesh.points,normal=mesh.normals,texcoords=mesh.tcoords},program, mesh.triangles,{position=mesh.npoints*3,normal=mesh.npoints*3,texcoords=mesh.npoints*2},mesh.ntriangles*3)
	vao:check_counts()
	--prtable(vao)
	function vao:reset_mesh(mesh1)
		self:set_buffer("position",mesh1.points,mesh1.npoints*3)
		self:set_buffer("normal",mesh1.normals,mesh1.npoints*3)
		self:set_buffer("texcoords",mesh1.tcoords,mesh1.npoints*2)
		self:set_indexes(mesh1.triangles,mesh1.ntriangles*3)
		--prtable(vao)
		vao:check_counts()
	end
	return vao
end

--faltan las normales con inversa transpuesta
local function par_shapesM4(m,MM)
	for i=0,m.npoints-1 do
		local vec = mat.vec4(m.points[i*3],m.points[i*3+1],m.points[i*3+2],1)
		local pR = MM * vec
		pR = pR/pR.w
		m.points[i*3],m.points[i*3+1],m.points[i*3+2] = pR.x,pR.y,pR.z
	end
	return m
end

local function connectA(scene, cyl, slices)
    local stacks = 1;
    local npoints = (slices + 1) * (stacks + 1);
    assert(scene.npoints >= npoints , "Cannot connect to empty scene.");

    -- Create the new point list.
    npoints = scene.npoints + (slices + 1);
    local points = ffi.cast("float*",ffi.C.malloc(ffi.sizeof"float"*npoints*3)) --PAR_MALLOC(float, npoints * 3);
    --memcpy(points, scene->points, sizeof(float) * scene->npoints * 3);
	ffi.copy(points, scene.points, ffi.sizeof"float"*npoints*3)
    local newpts = points + scene.npoints * 3
    --memcpy(newpts, cylinder->points + (slices + 1) * 3,sizeof(float) * (slices + 1) * 3);
	--ffi.copy(newpts,cyl.points + (slices + 1) * 3, ffi.sizeof("float") * (slices + 1) * 3)
	ffi.copy(newpts,cyl.points, ffi.sizeof("float") * (slices + 1) * 3)
    --PAR_FREE(scene->points);
	ffi.C.free(scene.points)
    scene.points = points;

    -- Create the new triangle list.
    local ntriangles = scene.ntriangles + 2 * slices * stacks;
    local triangles = ffi.cast("PAR_SHAPES_T*",ffi.C.malloc(ffi.sizeof"PAR_SHAPES_T"*ntriangles * 3) )--PAR_MALLOC(PAR_SHAPES_T, ntriangles * 3);
    --memcpy(triangles, scene->triangles,sizeof(PAR_SHAPES_T) * scene->ntriangles * 3);
	ffi.copy(triangles, scene.triangles,ffi.sizeof("PAR_SHAPES_T") * scene.ntriangles * 3);
    local v = scene.npoints - (slices + 1);
    local face = triangles + scene.ntriangles * 3;
    --for (int stack = 0; stack < stacks; stack++) {
        --for (int slice = 0; slice < slices; slice++) {
	for stack=0, stacks-1 do
		for slice =0, slices-1 do
            local next = slice + 1;
            face[0] = v + slice + slices + 1;
            face[1] = v + next;
            face[2] = v + slice;
            face[3] = v + slice + slices + 1;
            face[4] = v + next + slices + 1;
            face[5] = v + next;
			face = face + 6
        end
        v = v + slices + 1;
    end
    ffi.C.free(scene.triangles);
    scene.triangles = triangles;

    scene.npoints = npoints;
    scene.ntriangles = ntriangles;
end

local mesh_mt = {
	point = function(m,i)  return mat.vec3(m.points[i*3],m.points[i*3+1],m.points[i*3+2]) end,
	tcoord = function(m,i)  
				if m.tcoords~=nil then 
					return mat.vec2(m.tcoords[i*2],m.tcoords[i*2+1])
				else
					return nil
				end
			end,
	triangle = function(m,i) return {m.triangles[i*3],m.triangles[i*3+1],m.triangles[i*3+2]} end,
	normal = function(m,i)  
				if m.normals~=nil then 
					return mat.vec3(m.normals[i*3],m.normals[i*3+1],m.normals[i*3+2])
				else
					return nil
				end
			end,
	dump = function(m)
		print"points"
		for i=0,m.npoints - 1 do
			print(i,m:point(i),m:tcoord(i),m:normal(i))
		end
		print"triangles"
		for i=0,m.ntriangles- 1 do
			print(i,unpack(m:triangle(i)))
		end
	end,
	vao = function(m,prog) return par_shapes_vao(m,prog) end,
	M4 = function(m,MM) return par_shapesM4(m,MM) end,
	translate = function(...) return lib.par_shapes_translate(...) end,
	rotate = function(...) return lib.par_shapes_rotate(...) end,
	scale = function(...) return lib.par_shapes_scale(...) end,
	merge = function(...) return lib.par_shapes_merge(...) end,
	merge_and_free = function(...) return lib.par_shapes_merge_and_free(...) end,
	--connect = function(...) return lib.par_shapes__connect(...) end,
	connect = function(...) return connectA(...) end,
	compute_normals = function(...) return lib.par_shapes_compute_normals(...) end,
	compute_welded_normals = function(...) return lib.par_shapes__compute_welded_normals(...) end,
	weld = function(...) return lib.par_shapes_weld(...) end,
	unweld = function(m) return lib.par_shapes_unweld(m,true) end,
	clone = function(...) return lib.par_shapes_clone(...) end,
	remove_degenerate = function(...) return lib.par_shapes_remove_degenerate(...) end,
	free = function(m) ffi.gc(m,nil);return lib.par_shapes_free_mesh(m) end,
	__gc = function(m) print("__gc called"); return lib.par_shapes_free_mesh(m) end
}
mesh_mt.__index = mesh_mt
par_shapes.meshtype = ffi.metatype("par_shapes_mesh",mesh_mt)

local create_mt = {
	__index = function(t,k)
		local fname = string.format("par_shapes_create_%s", k)
		local ok,ret = pcall(function() return lib[fname] end)
		if not ok then error("Couldn't find pointer type for "..fname.." (are you accessing the right function?)",2) end
		local ret2 = function(...) local rr = ret(...);assert(rr~=nil,"par_shapes returning nil");return ffi.gc(rr,lib.par_shapes_free_mesh) end
		rawset(par_shapes.create, k,ret2 )
		return ret2
	end
}
par_shapes.create = setmetatable({},create_mt)
local sin,cos = math.sin,math.cos
--custom creations
function par_shapes.create.quad_prism(b)
	local radio = math.sqrt(2)/2 -- for quad width==1
	return lib.par_shapes_create_parametric(function(inp,out,us) 
		local u = math.pi * 2 * inp[1] - math.pi/4
		out[0] = math.sin(u)*radio
		out[1] = math.cos(u)*radio
		out[2] = inp[0]
	end,4,b,nil)
end
function par_shapes.create.quad_rprism(b)
	local radio = math.sqrt(2)/2 -- for quad width==1
	local width = 0.5 * 1.1
	return lib.par_shapes_create_parametric(function(inp,out,us) 
		local u = math.pi * 2 * inp[1] - math.pi/4
		out[0] = math.sin(u)*radio
		out[1] = math.cos(u)*radio
		local maxi = math.max(math.abs(out[0]),math.abs(out[1]))
		if maxi > width then
			out[0] = out[0]*width/maxi
			out[1] = out[1]*width/maxi
		end
		out[2] = inp[0]
	end,4*30,b,nil)
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
--without par_shapes_remove_degenerate 
function par_shapes.create.parametric_sphere2(a,b)
	return lib.par_shapes_create_parametric(function(inp,out,us) 
		local phi = inp[0] * math.pi;
		local theta = inp[1] * 2 * math.pi;
		out[0] = cos(theta) * sin(phi);
		out[1] = sin(theta) * sin(phi);
		out[2] = cos(phi);
	end,a,b,nil)
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
		--local mesh = require"anima.mesh"
		local meshesfere = par_shapes.create.cube()
		print(meshesfere.npoints, meshesfere.ntriangles)
		meshesfere:dump()
		--local mesh1 = mesh.par_shapes2mesh(meshesfere)
		meshesfere:free()
--]]
return par_shapes

