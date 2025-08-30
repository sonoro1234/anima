
local ffi = require"ffi"
local libgl = require"gl"
local glu = libgl.glu
local glc = libgl.glc
local gl = libgl.gl


local meshes = {}
local printD = function() end --print
local function beginCallback(which)
	printD("beginCallback",which,glc.GL_TRIANGLES,glc.GL_TRIANGLE_STRIP)
   meshes[#meshes + 1] = {mode=which}
end
local cb_beginCallback = ffi.cast("void (*)()", ffi.cast("void (*)(GLenum)", beginCallback))

function errorCallback(errorCode)
	printD("errorCallback",errorCode)
   local estring = glu.gluErrorString(errorCode);
   print( "Tessellation Error: %s\n",ffi.string(estring));
   --exit(0);
   error"glu teseel error"
end
local cb_errorCallback = ffi.cast("void (*)()", ffi.cast("void (*)(GLenum)", errorCallback))

function vertexCallback(pointer)
	printD("vertexCallback",pointer[0],pointer[1],pointer[2],pointer[3],pointer[4],pointer[5])
   --const GLdouble *pointer;

   --pointer = (GLdouble *) vertex;
   -- gl.glColor3dv(pointer+3);
   -- gl.glVertex3dv(pointer);
   table.insert(meshes[#meshes],mat.vec2(pointer[0],pointer[1]))--,pointer[2]))
end
local cb_vertexCallback = ffi.cast("void (*)()", ffi.cast("void (*)(GLdouble*)", vertexCallback))
function vertexCallback1(pointer)
	printD("vertexCallback1",pointer[0],pointer[1],pointer[2])
   --gl.glVertex3dv(pointer);
   table.insert(meshes[#meshes],mat.vec2(pointer[0],pointer[1]))--,pointer[2]))
end
local cb_vertexCallback1 = ffi.cast("void (*)()", ffi.cast("void (*)(GLdouble*)", vertexCallback1))
function endCallback(void)
	printD("endCallback")
   --gl.glEnd();
end
local cb_endCallback = ffi.cast("void (*)()", endCallback)
-- /*  combineCallback is used to create a new vertex when edges
 -- *  intersect.  coordinate location is trivial to calculate,
 -- *  but weight[4] may be used to average color, normal, or texture
 -- *  coordinate data.  In this program, color is weighted.
 -- */
 local anchor = {}
local function combineCallback(coords,vertex_data,weight,dataOut )
	printD("combineCallback")--,coords,vertex_data,weight,dataOut)
	printD("coords",coords[0],coords[1],coords[2])
	printD("weight",weight[0],weight[1],weight[2],weight[3])
   local vertex = ffi.new("GLdouble[6]")
	table.insert(anchor, vertex)
   vertex[0] = coords[0];
   vertex[1] = coords[1];
   vertex[2] = coords[2];
   -- for i=3,5 do
      -- vertex[i] = weight[0] * vertex_data[0][i]
                  -- + weight[1] * vertex_data[1][i]
                  -- + weight[2] * vertex_data[2][i]
                  -- + weight[3] * vertex_data[3][i];
    -- end
   printD(vertex[0],vertex[1],vertex[2],vertex[3],vertex[4],vertex[5])
   dataOut[0] = vertex
end

local cb_combineCallback = ffi.cast("void (*)()", ffi.cast("void (*)(GLdouble[3], GLdouble*[4], GLfloat[4], GLdouble ** )", combineCallback))

local M = {}

local function get_Meshes(meshes, get_indexes)
   local Meshes = {}
   local tr = {}
   for i=1,#meshes do
		if get_indexes then
			tr[i] = {}
			if meshes[i].mode == glc.GL_TRIANGLE_STRIP then
				--print("GL_TRIANGLE_STRIP",#meshes[i])
				for j=3,#meshes[i] do
					table.insert(tr[i],j-2-1)
					table.insert(tr[i],j-1-1)
					table.insert(tr[i],j-1)
				end
			elseif meshes[i].mode == glc.GL_TRIANGLE_FAN then
				--print("GL_TRIANGLE_FAN",#meshes[i])
				for j=3,#meshes[i] do
					table.insert(tr[i],0)
					table.insert(tr[i],j-1-1)
					table.insert(tr[i],j-1)
				end
			elseif meshes[i].mode == glc.GL_TRIANGLES then
				--print("GL_TRIANGLES")
				for j=1,#meshes[i]-2,3 do
					table.insert(tr[i],j-1)
					table.insert(tr[i],j+1-1)
					table.insert(tr[i],j+2-1)
				end
			else
				error"not done"
			end
			--local m = mesh.mesh{points=meshes[i],triangles=tr}
			--table.insert(Meshes, m)
		else
			local m = mesh.mesh{points=meshes[i]}
			m.modedraw = meshes[i].mode
			table.insert(Meshes, m)
		end
   end
   local Points, trs = {},{}
   local last_tr = 0
   if get_indexes then
		for i=1,#meshes do
			for j=1,#meshes[i] do table.insert(Points, meshes[i][j]) end
			for j=1,#tr[i] do table.insert(trs, tr[i][j] + last_tr) end
			last_tr = last_tr + #meshes[i]
		end
		local m = mesh.mesh{points=Points, triangles=trs}
		table.insert(Meshes, m)
   end
   return Meshes
end
--polygon with poly.holes
local anchor = {}
local insert = table.insert
function M.tesselate(poly, winding, get_indexes)
	meshes = {}
   local tobj = glu.gluNewTess();

   glu.gluTessCallback(tobj, glc.GLU_TESS_VERTEX,cb_vertexCallback1);
   glu.gluTessCallback(tobj, glc.GLU_TESS_BEGIN,cb_beginCallback);
   glu.gluTessCallback(tobj, glc.GLU_TESS_END, cb_endCallback);
   glu.gluTessCallback(tobj, glc.GLU_TESS_ERROR, cb_errorCallback);
   glu.gluTessCallback(tobj, glc.GLU_TESS_COMBINE, cb_combineCallback);

   glu.gluTessProperty(tobj, glc.GLU_TESS_WINDING_RULE,winding or glc.GLU_TESS_WINDING_ODD);
   glu.gluTessNormal(tobj, 0,0,1)
  -- for ii,poly in ipairs(polyset) do
   glu.gluTessBeginPolygon(tobj, NULL);
        glu.gluTessBeginContour(tobj);
		for i,v in ipairs(poly) do
			local vertex = ffi.new("GLdouble[3]",v.x,v.y,0)
			insert(anchor, vertex)
            glu.gluTessVertex(tobj, vertex, vertex);
		end
		glu.gluTessEndContour(tobj);
		if poly.holes then
		for j,hole in ipairs(poly.holes) do
			glu.gluTessBeginContour(tobj);
			for ih,vh in ipairs(hole) do
				local vertex = ffi.new("GLdouble[3]",vh.x,vh.y,0)
				insert(anchor, vertex)
				glu.gluTessVertex(tobj, vertex, vertex);
			end
			glu.gluTessEndContour(tobj);
		end
		end
      
		glu.gluTessEndPolygon(tobj);
  -- end
   glu.gluDeleteTess(tobj);
   
   -- local Meshes = {}
   -- for i=1,#meshes do
		-- local m = mesh.mesh{points=meshes[i]}
		-- m.modedraw = meshes[i].mode
		-- table.insert(Meshes, m)
   -- end
    anchor = {}
   --return Meshes
      return get_Meshes(meshes, get_indexes)
end
--polyset no poly.holes
function M.tesselate_set(polyset,winding,get_indexes)
	--print("tesselate_set winding", winding)
	meshes = {}
   local tobj = glu.gluNewTess();

   glu.gluTessCallback(tobj, glc.GLU_TESS_VERTEX,cb_vertexCallback1);
   glu.gluTessCallback(tobj, glc.GLU_TESS_BEGIN,cb_beginCallback);
   glu.gluTessCallback(tobj, glc.GLU_TESS_END, cb_endCallback);
   glu.gluTessCallback(tobj, glc.GLU_TESS_ERROR, cb_errorCallback);
   glu.gluTessCallback(tobj, glc.GLU_TESS_COMBINE, cb_combineCallback);

   glu.gluTessProperty(tobj, glc.GLU_TESS_WINDING_RULE, winding or glc.GLU_TESS_WINDING_ODD);
   glu.gluTessNormal(tobj, 0,0,1)

   glu.gluTessBeginPolygon(tobj, nil);
   for ii,poly in ipairs(polyset) do
        glu.gluTessBeginContour(tobj);
		for i,v in ipairs(poly) do
			local vertex = ffi.new("GLdouble[3]",v.x,v.y,0)
			insert(anchor, vertex)
            glu.gluTessVertex(tobj, vertex, vertex);
		end
		glu.gluTessEndContour(tobj);
    end
		glu.gluTessEndPolygon(tobj);
  -- end
   glu.gluDeleteTess(tobj);

	anchor = {}
   return get_Meshes(meshes, get_indexes)
end
return M