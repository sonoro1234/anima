local M = {}
--local par_shapes = require"anima.par_shapes"
local ffi = require"ffi"
local mat = require"anima.matrixffi"
local vec3 = mat.vec3
local vec2 = mat.vec2

--not good it is CW
function M.Quad(left,top,right,bottom)
	--left = left or
	local m = {}
	m.points = {
        left, top, 0,
        right, top, 0,
        right, bottom, 0,
        left, bottom, 0,
    }
	m.normals = {
		0,0,1,
		0,0,1,
		0,0,1,
		0,0,1
	}
	m.texcoords = {
        0, 0,
        1, 0,
        1, 1,
        0, 1,
    }
	m.indexes = { 3, 2, 1, 1, 0, 3 }
	
	function m:vao(prog)
		return VAO({position=self.points,normal=self.normals,texcoords=self.texcoords},prog,self.indexes)
	end
	return m
end

function M.quad(left,bottom,right,top)
	left = left or -1
	bottom = bottom or -1
	right = right or 1
	top = top or 1
	
	local m = {}
	m.points = {
        left,bottom, 0,
		left,top, 0,
        right,bottom, 0,
        right,top, 0,
    }
	m.normals = {
		0,0,1,
		0,0,1,
		0,0,1,
		0,0,1
	}
	m.texcoords = {
        0, 0,
        0, 1,
        1, 0,
        1, 1,
    }
	m.indexes = { 2,1,0,2,3,1 }
	
	function m:vao(prog)
		return VAO({position=self.points,normal=self.normals,texcoords=self.texcoords},prog,self.indexes)
	end
	return m
end

function M.quad2(left,bottom,right,top)
	left = left or -1
	bottom = bottom or -1
	right = right or 1
	top = top or 1
	
	local m = {}
	m.points = {
        vec3(left,bottom, 0),
		vec3(left,top, 0),
        vec3(right,bottom, 0),
        vec3(right,top, 0),
    }
	m.normals = {
		vec3(0,0,1),
		vec3(0,0,1),
		vec3(0,0,1),
		vec3(0,0,1)
	}
	m.tcoords = {
        vec2(0, 0),
        vec2(0, 1),
        vec2(1, 0),
        vec2(1, 1),
    }
	m.triangles = { 2,1,0,2,3,1 }
	
	-- function m:vao(prog)
		-- return VAO({position=self.points,normal=self.normals,texcoords=self.texcoords},prog,self.indexes)
	-- end
	return M.mesh(m)
end

function M.plane_vao(divs,aspect,program)
	local w,h
	if aspect > 1 then
		w,h = divs*aspect,divs
	else
		w,h = divs,divs/aspect
	end
	local par_shapes = require"anima.par_shapes"
	local mesh1 = par_shapes.create.plane(h,w) --dont know why it is inverted
	mesh1:translate(-0.5,-0.5,0)
	mesh1:scale(aspect,1,1)
	local vao = VAO({position=mesh1.points,texcoords=mesh1.tcoords,normal=mesh1.normals},program, mesh1.triangles,{position=mesh1.npoints*3,texcoords=mesh1.npoints*2,normal=mesh1.npoints*3},mesh1.ntriangles*3)
	return vao
end

function M.grid(divs,aspect)
	local w,h
	if aspect > 1 then
		w,h = math.ceil(divs*aspect),divs
	else
		w,h = divs,math.ceil(divs/aspect)
	end
	
	local points = {}
	local tcoords = {}
	local stepx,stepy = 1/w,1/h
	for i=0,w do
		local x = (i*stepx - 0.5)*aspect
		local xc = i/w
		for j=0,h do
			local y =  j*stepy - 0.5
			local p = vec3(x,y,0)
			points[#points+1] = p
			tcoords[#tcoords+1] = vec2(xc,j/h)
		end
	end
	-- tr indexes for grid
	local indexes = mesh.triangs(h+1,w+1)
	local bounds = {vec2(-0.5*aspect,-0.5),vec2(0.5*aspect,0.5)}
	local mesh1 = mesh.mesh({points=points,tcoords=tcoords,triangles=indexes}) 
	return mesh1, bounds
end

function M.gridB(divs,bounds,zval)
	local minb,maxb = bounds[1],bounds[2]
	local diff = maxb-minb
	local aspect = diff.x/diff.y
	local w,h
	if aspect > 1 then
		w,h = math.ceil(divs*aspect),divs
	else
		w,h = divs,math.ceil(divs/aspect)
	end
	
	local points = {}
	local tcoords = {}
	local stepx,stepy = diff.x/w,diff.y/h
	for i=0,w do
		local x = i==w and maxb.x or (minb.x + i*stepx)
		local xc = i/w
		for j=0,h do
			local y =  j==h and maxb.y or (minb.y + j*stepy)
			local p = vec3(x,y,zval)
			points[#points+1] = p
			tcoords[#tcoords+1] = vec2(xc,j/h)
		end
	end
	-- tr indexes for grid
	local indexes = mesh.triangs(h+1,w+1)
	local mesh1 = mesh.mesh({points=points,tcoords=tcoords,triangles=indexes}) 
	return mesh1
end

--takes points and indexes (0-based opengl)
--deletes unused points, remap indexes
--returns map to reindex other things
function M.clean_points(points, indexes)
local used, map = {}, {}
	for i,p in ipairs(points) do used[i] = 0; map[i] = i end
	for i,ind in ipairs(indexes) do
		used[ind+1] = used[ind+1] + 1
	end
	for i=#used,1,-1 do
		if used[i]==0 then table.remove(points,i); table.remove(map,i) end
	end
	local map2 = {}
	for i,v in ipairs(map) do map2[v] = i end
	--apply map2
	for i,ind in ipairs(indexes) do
		indexes[i] = map2[ind+1]-1
	end
	return map2
end

ffi.cdef[[void* malloc (size_t size); void* realloc (void* ptr, size_t size); void free (void* ptr);]]
function M.par_shapes_tube(section,stacks)

	local slices = #section - 1
	
	--local mesh = ffi.new"par_shapes_mesh"
	local mesh = ffi.cast("par_shapes_mesh*",ffi.C.malloc(ffi.sizeof"par_shapes_mesh"))
	mesh.npoints = (stacks + 1)*#section
	--mesh.points = ffi.new("float[?]",mesh.npoints * 3)
	mesh.points = ffi.C.malloc(ffi.sizeof"float" * mesh.npoints * 3)
	
	local points = mesh.points
	
	for i=0,stacks do
		local u =  i / stacks;
		for j=0,slices do
			--local v = section[j].v
			points[0] = section[j + 1].point.x
			points = points + 1
			points[0] = section[j + 1].point.y
			points = points + 1
			points[0] = u
			points = points + 1
		end
	end
	
	--mesh.tcoords = ffi.new("float[?]",mesh.npoints * 2)
	mesh.tcoords = ffi.C.malloc(ffi.sizeof"float" * mesh.npoints * 2)
	local tcoords = mesh.tcoords
	
	for i=0,stacks do
		local u =  i / stacks;
		for j=0,slices do
			local v = section[j + 1].v
			tcoords[0] = u
			tcoords = tcoords + 1
			tcoords[0] = v
			tcoords = tcoords + 1
		end
	end
	
	-- Generate faces.
    mesh.ntriangles = 2 * slices * stacks;
   -- mesh.triangles = ffi.new("PAR_SHAPES_T[?]",mesh.ntriangles * 3)
	mesh.triangles = ffi.C.malloc(ffi.sizeof"PAR_SHAPES_T" * mesh.ntriangles * 3)
    local v = 0;
    local face = mesh.triangles;
    for i=0,stacks - 1 do
        for slice = 0,slices - 1 do
            local next = slice + 1;
            face[0] = v + slice + slices + 1;
			face = face + 1
            face[0] = v + next;
			face = face + 1
            face[0] = v + slice;
			face = face + 1
            face[0] = v + slice + slices + 1;
			face = face + 1
            face[0] = v + next + slices + 1;
			face = face + 1
            face[0] = v + next;
			face = face + 1
        end
        v = v + slices + 1;
    end

    mesh:compute_welded_normals();
	--mesh:compute_normals();
    return mesh;

end

function M.tube(section,stacks)

	local slices = #section - 1
	
	local mesh = M.mesh()
	local npoints = (stacks + 1)*#section
	
	local points = {}
	for i=0,stacks do
		local u =  i / stacks;
		for j=0,slices do
			points[#points +1] = vec3(section[j + 1].point.x, section[j + 1].point.y, u)
		end
	end
	
	assert(npoints==#points)
	
	local tcoords = {}
	for i=0,stacks do
		local u =  i / stacks;
		for j=0,slices do
			local v = section[j + 1].v
			tcoords[#tcoords+1] = vec2(u, v)
		end
	end

    --mesh:compute_welded_normals();
    return M.mesh({points=points,tcoords=tcoords,triangles=M.triangs(slices+1, stacks+1)});

end

--section for using with par_shapes_tube
function M.roundedQuad(r1,steps,radio)

	local function arc(center,iniang,endang,radio,steps,Q)
		for i=0,steps do
			local ang = iniang + (endang-iniang)*i/(steps)
			local point = center + vec2(math.cos(ang),math.sin(ang))*radio
			Q[#Q+1] = {point=point}
		end
	end

	radio = radio or 0.5
	r1 = radio*r1
	local lat = radio - r1
	
	local Q = {}
	arc(vec2(-lat,lat),math.pi/2,math.pi,r1,steps,Q)
	arc(vec2(-lat,-lat),math.pi,3*math.pi/2,r1,steps,Q)
	arc(vec2(lat,-lat),3*math.pi/2,2*math.pi,r1,steps,Q)
	arc(vec2(lat,lat),0,math.pi/2,r1,steps,Q)
	Q[#Q+1] = {point=vec2(-lat,radio)}
	
	local angfirst = math.atan2(Q[1].point.y,Q[1].point.x)
	for i,v in ipairs(Q) do
		local ang = math.atan2(v.point.y,v.point.x) - angfirst
		if ang < 0 then ang = ang + 2*math.pi end
		v.v = ang/(2*math.pi)
	end
	Q[#Q].v = 1
	return Q
end
--CCW
function M.tb2section(tb)
	local centroid = vec2(0,0)
	local Q = {}
	for i,v in ipairs(tb) do
		local point = vec2(v.x,v.y)
		Q[#Q+1] = {point=point}
		centroid = centroid + point
	end
	centroid = centroid/#tb
	--CCW----------------------------
	local angfirst = math.atan2(Q[1].point.y - centroid.y,Q[1].point.x - centroid.x)
	while angfirst < 0 do angfirst = angfirst + 2*math.pi end
	for i,v in ipairs(Q) do
		local ang = math.atan2(v.point.y - centroid.y, v.point.x - centroid.x) - angfirst
		while ang < 0 do ang = ang + 2*math.pi end
		v.v = ang/(2*math.pi)
	end
	Q[#Q].v = 1
	return Q
end
function M.tb2sectionCW(tb)
	local centroid = vec2(0,0)
	local Q = {}
	for i,v in ipairs(tb) do
		local point = vec2(v.x,v.y)
		Q[#Q+1] = {point=point}
		centroid = centroid + point
	end
	centroid = centroid/#tb
	--CW----------------------------
	local angfirst = math.atan2(Q[1].point.y - centroid.y,Q[1].point.x - centroid.x)
	while angfirst < 0 do angfirst = angfirst + 2*math.pi end
	for i,v in ipairs(Q) do
		local ang = math.atan2(v.point.y - centroid.y, v.point.x - centroid.x) - angfirst
		while ang < 0 do ang = ang + 2*math.pi end
		v.v = 1 - ang/(2*math.pi)
	end
	Q[1].v = 0
	Q[#Q].v = 1
	return Q
end

function M.par_shapes_program()
	local vert = [[
		in vec3 position;
		in vec2 texcoords;
		in vec3 normal;
		out vec2 texc_f;
		void main(){
			texc_f = texcoords;
			gl_Position = gl_ModelViewProjectionMatrix * vec4(position,1);
		}
	]]
	
	local frag = [[
		in vec2 texc_f;
		uniform sampler2D tex;
		void main(){
			vec4 color = texture(tex,texc_f);
			gl_FragColor = color;//vec4(1);
		}
	
	]]
	return GLSL:new():compile(vert,frag)
end

--expects two ortogonal directions
function M.make_frame(t)
	if not t.X then
		t.Y = t.Y:normalize()
		t.Z = t.Z:normalize()
		assert(t.Y*t.Z==0)
		t.X = t.Y:cross(t.Z)
	elseif not t.Y then
		t.X = t.X:normalize()
		t.Z = t.Z:normalize()
		assert(t.X*t.Z==0)
		t.Y = t.Z:cross(t.X)
	elseif not t.Z then
		t.Y = t.Y:normalize()
		t.X = t.X:normalize()
		assert(t.Y*t.X==0)
		t.Z = t.X:cross(t.Y)
	else
		error"make frame called with more than two axis"
	end
	return t
end

function M.move_frame(frame,MM)
	local MMnor = MM.inv.t
	return {X = MMnor*frame.X, Y = MMnor*frame.Y, Z=MMnor*frame.Z, center=MM*frame.center}
end

function M.mesh(t)
	t = t or {}
	local mesh = {}
	mesh.points = t.points or {vec3(0,0,0)}
	mesh.triangles = t.triangles or {}
	mesh.indexes = mesh.triangles -- alias for quad compability
	mesh.ntriangles = #mesh.triangles/3
	mesh.normals = t.normals --or {}
	mesh.tcoords = t.tcoords --or {mat.vec2(0,0)}
	function mesh:point(i)
		return self.points[i]
	end
	function mesh:tcoord(i)
		return self.tcoords[i]
	end
	function mesh:normal(i)
		return self.normals[i]
	end
	function mesh:triangle(i)
		i = i - 1
		return {self.triangles[3*i + 1] + 1,self.triangles[3*i + 2] + 1,self.triangles[3*i + 3] + 1}
	end
	function mesh:dump()
		print"points"
		for i=1,#self.points do
			print(i,self:point(i),self:tcoord(i),self:normal(i))
		end
		print"triangles"
		for i=1,self.ntriangles do
			print(i,unpack(self:triangle(i)))
		end
	end
	function mesh:compute_normals()
		local normals = {}
		local zerovec = vec3(0,0,0)
		--local alltris = {}
		for i=1,self.ntriangles do
			local tri = self:triangle(i)
			local pa = self:point(tri[1])
			local pb = self:point(tri[2])
			local pc = self:point(tri[3])
			if not(pa and pb and pc) then print(i,pa,pb,pc,tri[1],tri[2],tri[3]); error"  " end
			local nor = (pb - pa):cross(pc - pa)
			normals[tri[1]] = nor + (normals[tri[1]] or zerovec)
			local nor = (pc - pb):cross(pa - pb)
			normals[tri[2]] = nor + (normals[tri[2]] or zerovec)
			local nor = (pa - pc):cross(pb - pc)
			normals[tri[3]] = nor + (normals[tri[3]] or zerovec)
			--alltris[tri[1]]=true;alltris[tri[2]]=true;alltris[tri[3]]=true
		end
		for i=1,#self.points do
			-- if not normals[i] then 
				-- print(normals[i],#normals,i) 
				-- assert(not alltris[i])
			-- end
			normals[i] = normals[i] and normals[i]:normalize() or zerovec
		end
		--assert(#normals == #self.points)
		self.normals = normals
	end
	function mesh:clone()
		local points = {}
		for i,v in ipairs(self.points) do
			points[i] = vec3(v.x,v.y,v.z)
		end
		local tcoords = {}
		for i,v in ipairs(self.tcoords) do
			tcoords[i] = vec2(v.x,v.y)
		end
		if self.normals then
		local normals = {}
		for i,v in ipairs(self.normals) do
			normals[i] = vec3(v.x,v.y,v.z)
		end
		end
		local triangles = {}
		for i,v in ipairs(self.triangles) do
			triangles[i] = v
		end
		return M.mesh{points=points,normals=normals,tcoords=tcoords,triangles=triangles}
	end
	--normals not done
	function mesh:merge(m2)
		local npoints = #self.points
		for i,v in ipairs(m2.points) do
			self.points[i+npoints] = v --vec3(v.x,v.y,v.z)
		end
		local ntr = #self.triangles
		for i,v in ipairs(m2.triangles) do
			self.triangles[i+ntr] = v + npoints 
		end
		--make tcoords based on 2d coordinates
		local CG = require"anima.CG3"
		local minb,maxb = CG.bounds(self.points)
		local diff = maxb-minb
		for i,v in ipairs(self.points) do
			local vv = v:xy() - minb
			self.tcoords[i] = vec2(vv.x/diff.x,vv.y/diff.y)
		end
		return self
	end
	
	function mesh:M4(MM)
		local M3,tt
		if ffi.istype(mat.mat4, MM) then
			M3 = MM.mat3
			tt = MM*mat.vec4(0,0,0,1)
			tt = tt:xyz()/tt.w
		else
			M3 = MM
			tt = vec3(0,0,0)
		end
		local points = self.points
		for i=1,#points do
			-- local vec = mat.vec4(self.points[i],1)
			-- local pR = MM * vec
			-- pR = pR/pR.w
			-- self.points[i] = pR:xyz()
			points[i] = M3 * points[i] + tt
		end
		return self
	end
	function mesh:scale(f)
		for i=1,#self.points do
			self.points[i] = self.points[i]*f
		end
	end
	function mesh:calc_centroid()
		local centroid = vec3(0,0,0)
		for i=1,#self.points do
			centroid = centroid + self.points[i]
		end
		self.centroid = centroid/#self.points
		return self.centroid
	end
	function mesh:bounds()
		local minx,maxx,miny,maxy,minz,maxz = math.huge,-math.huge,math.huge,-math.huge,math.huge,-math.huge
		for i,p in ipairs(self.points) do
			minx = p.x < minx and p.x or minx
			maxx = p.x > maxx and p.x or maxx
			miny = p.y < miny and p.y or miny
			maxy = p.y > maxy and p.y or maxy
			minz = p.z < minz and p.z or minz
			maxz = p.z > maxz and p.z or maxz
		end
		return vec3(minx,miny,minz),vec3(maxx,maxy,maxz)
	end
	function mesh:vao(program,notcoords)
		local tt = {}
		tt.position = mat.vec2vao(mesh.points)
		tt.normal = self.normals and mat.vec2vao(self.normals) or nil
		if not notcoords then tt.texcoords = self.tcoords and mat.vec2vao(self.tcoords) or nil end
		local vao =  VAO(tt,program, mesh.triangles)
		function vao:reset_mesh(mesh1)
			self:set_buffer("position",mat.vec2vao(mesh1.points))
			if self.normals then
				self:set_buffer("normal",mat.vec2vao(mesh1.normals))
			end
			if not notcoords then self:set_buffer("texcoords",mat.vec2vao(mesh1.tcoords)) end
			self:set_indexes(mesh1.triangles)
			vao:check_counts()
		end
		vao:check_counts()
		return vao
	end
	return mesh
end
function M.par_shapes2mesh(pm)
	local mesh = M.mesh()
	for i=0,pm.npoints-1 do
		mesh.points[i+1] = pm:point(i)
	end
	if pm.tcoords ~=nil then
	mesh.tcoords = {}
	for i=0,pm.npoints-1 do
		mesh.tcoords[i+1] = pm:tcoord(i)
	end
	end
	if pm.normals ~=nil then
		mesh.normals = {}
		for i=0,pm.npoints-1 do
			mesh.normals[i+1] = pm:normal(i)
		end
	end
	for i=0,pm.ntriangles- 1 do
		mesh.triangles[i*3 +1],mesh.triangles[i*3+2],mesh.triangles[i*3+3] = unpack(pm:triangle(i))
	end
	mesh.ntriangles = #mesh.triangles/3
	--print("ntriangles",pm.ntriangles,mesh.ntriangles , #mesh.triangles/3)
	return mesh
end

-- function M.triangs(stacks,slices)--,stacks)
function M.triangs(slices,stacks)
	slices = slices - 1
	stacks = stacks - 1
	local v = 0;
    local face = {}
	local ind = 1
    for i=0,stacks - 1 do
        for slice = 0,slices - 1 do
			--local ind = #face + 1
            local next = slice + 1;
            face[ind] = v + slice + slices + 1;
            face[ind + 1] = v + next;
            face[ind + 2] = v + slice;
            face[ind + 3] = v + slice + slices + 1;
            face[ind + 4] = v + next + slices + 1;
            face[ind + 5] = v + next;
			ind = ind + 6
        end
        v = v + slices + 1;
    end
	return face
end

local function drawtri(a, b, c,  div, r, pos, nor) 
	local function normalize(a)
		local  d = math.sqrt(a[0]*a[0]+a[1]*a[1]+a[2]*a[2]);
		a[0] = a[0]/d; a[1] = a[1]/d;a[2] = a[2]/d;
	end
    if (div<=0) then
		local i=#pos
		pos[i+1] = a[0]*r; pos[i+2] = a[1]*r; pos[i+3] = a[2]*r
		pos[i+4] = b[0]*r; pos[i+5] = b[1]*r; pos[i+6] = b[2]*r
		pos[i+7] = c[0]*r; pos[i+8] = c[1]*r; pos[i+9] = c[2]*r
		nor[i+1] = a[0]; nor[i+2] = a[1]; nor[i+3] = a[2]
		nor[i+4] = b[0]; nor[i+5] = b[1]; nor[i+6] = b[2]
		nor[i+7] = c[0]; nor[i+8] = c[1]; nor[i+9] = c[2]
        -- gl.glNormal3fv(a); gl.glVertex3f(a[0]*r, a[1]*r, a[2]*r);
        -- gl.glNormal3fv(b); gl.glVertex3f(b[0]*r, b[1]*r, b[2]*r);
        -- gl.glNormal3fv(c); gl.glVertex3f(c[0]*r, c[1]*r, c[2]*r);
    else 
        local ab, ac, bc = ffi.new("GLfloat[3]"),ffi.new("GLfloat[3]"),ffi.new("GLfloat[3]")
        for  i=0,2 do
            ab[i]=(a[i]+b[i])/2;
            ac[i]=(a[i]+c[i])/2;
            bc[i]=(b[i]+c[i])/2;
        end
        normalize(ab); normalize(ac); normalize(bc);
        drawtri(a, ab, ac, div-1, r, pos, nor);
        drawtri(b, bc, ab, div-1, r, pos, nor);
        drawtri(c, ac, bc, div-1, r, pos, nor);
		drawtri(ab, bc, ac, div-1, r, pos, nor);  --//<--Comment this line and sphere looks really cool!
    end  
end

function M.gen_sphere(ndiv,radius) 
	ndiv = ndiv or 3
	radius = radius or 1
	local X = 0.525731112119133606 
	local Z = 0.850650808352039932
	local vdata = ffi.new("GLfloat[12][3]",{    
		{-X, 0.0, Z}, {X, 0.0, Z}, {-X, 0.0, -Z}, {X, 0.0, -Z},    
		{0.0, Z, X}, {0.0, Z, -X}, {0.0, -Z, X}, {0.0, -Z, -X},    
		{Z, X, 0.0}, {-Z, X, 0.0}, {Z, -X, 0.0}, {-Z, -X, 0.0} 
	})
	local tindices = ffi.new("GLfloat[20][3]",{ 
    {0,4,1}, {0,9,4}, {9,5,4}, {4,5,8}, {4,8,1},    
    {8,10,1}, {8,3,10}, {5,3,8}, {5,2,3}, {2,7,3},    
    {7,10,3}, {7,6,10}, {7,11,6}, {11,0,6}, {0,1,6}, 
    {6,1,10}, {9,0,11}, {9,11,2}, {9,2,5}, {7,2,11} })
	
	local points = {}
	local normals = {}
    for i=0,20-1 do
        drawtri(vdata[tindices[i][0]], vdata[tindices[i][1]], vdata[tindices[i][2]], ndiv, radius, points,normals);
	end
	return points, normals
end
return M