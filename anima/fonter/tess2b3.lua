--[[/*
** SGI FREE SOFTWARE LICENSE B (Version 2.0, Sept. 18, 2008) 
** Copyright (C) [dates of first publication] Silicon Graphics, Inc.
** All Rights Reserved.
**
** Permission is hereby granted, free of charge, to any person obtaining a copy
** of this software and associated documentation files (the "Software"), to deal
** in the Software without restriction, including without limitation the rights
** to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
** of the Software, and to permit persons to whom the Software is furnished to do so,
** subject to the following conditions:
** 
** The above copyright notice including the dates of first publication and either this
** permission notice or a reference to http://oss.sgi.com/projects/FreeB/ shall be
** included in all copies or substantial portions of the Software. 
**
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
** INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
** PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL SILICON GRAPHICS, INC.
** BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
** TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
** OR OTHER DEALINGS IN THE SOFTWARE.
** 
** Except as contained in this notice, the name of Silicon Graphics, Inc. shall not
** be used in advertising or otherwise to promote the sale, use or other dealings in
** this Software without prior written authorization from Silicon Graphics, Inc.
*/
--/*
** Author: Mikko Mononen, Aug 2013.
** The code is based on GLU libtess by Eric Veach, July 1994
*/--]]

--Lua version trying to use self:method() instead of self.method
-- jit.off()
--local mat =	require"anima.matrixffi"
	--local function assert() end
	local function vec3(a,b,c)
		return {[0]=a,b,c}
	end
	local function vec2(a,b)
		return {[0]=a,b}
	end
	-- vec3 = mat.vec3
	-- vec2 = mat.vec2
	local function prtable1(t,tab)
		for k,v in pairs(t) do
			print(tab,k,v)
		end
	end
	local function prtable2(t)
		for k,v in pairs(t) do
			print(k,v)
			if type(v)=="table" then prtable1(v,"   ") end
		end
	end
	local function prtableN(t, lev,tab)
		if lev==0 then return end
		tab = tab or ""
		for k,v in pairs(t) do
			print(tab,k,v)
			if type(v)=="table" then prtableN(v,lev-1,tab.."\t") end
		end
	end
	--require"anima.utils"
	
	--/* Public API */

	local Tess2 = {};
	local Geom = {};
	local Tesselator

	
	Tess2.WINDING_ODD = 0;
	Tess2.WINDING_NONZERO = 1;
	Tess2.WINDING_POSITIVE = 2;
	Tess2.WINDING_NEGATIVE = 3;
	Tess2.WINDING_ABS_GEQ_TWO = 4;

	Tess2.POLYGONS = 0;
	Tess2.CONNECTED_POLYGONS = 1;
	Tess2.BOUNDARY_CONTOURS = 2;

	Tess2.tesselate = function(opts) 
		local debug =  opts.debug 
		local tess =  Tesselator();
		for i = 1,#opts.contours do
			--print("opts.vertexSize",opts.vertexSize)
			tess:addContour(opts.vertexSize or 2, opts.contours[i]);
		end

		tess:tesselate(opts.windingRule or Tess2.WINDING_ODD,
					   opts.elementType or Tess2.POLYGONS,
					   opts.polySize or 3,
					   opts.vertexSize or 2,
					   opts.normal or vec3(0,0,1));
		return {
			vertices = tess.vertices,
			vertexIndices = tess.vertexIndices,
			vertexCount = tess.vertexCount,
			elements = tess.elements,
			elementCount = tess.elementCount,
			mesh= debug and tess.mesh or nil
		};
	end

	--/* Internal */


	--[[/* The mesh structure is similar in spirit, notation, and operations
	* to the "quad-edge" structure (see L. Guibas and J. Stolfi, Primitives
	* for the manipulation of general subdivisions and the computation of
	* Voronoi diagrams, ACM Transactions on Graphics, 4(2):74-123, April 1985).
	* For a simplified description, see the course notes for CS348a,
	* "Mathematical Foundations of Computer Graphics", available at the
	* Stanford bookstore (and taught during the fall quarter).
	* The implementation also borrows a tiny subset of the graph-based approach
	* use in Mantyla's Geometric Work Bench (see M. Mantyla, An Introduction
	* to Sold Modeling, Computer Science Press, Rockville, Maryland, 1988).
	*
	* The fundamental data structure is the "half-edge".  Two half-edges
	* go together to make an edge, but they point in opposite directions.
	* Each half-edge has a pointer to its mate (the "symmetric" half-edge Sym),
	* its origin vertex (Org), the face on its left side (Lface), and the
	* adjacent half-edges in the CCW direction around the origin vertex
	* (Onext) and around the left face (Lnext).  There is also a "next"
	* pointer for the global edge list (see below).
	*
	* The notation used for mesh navigation:
	*  Sym   = the mate of a half-edge (same edge, but opposite direction)
	*  Onext = edge CCW around origin vertex (keep same origin)
	*  Dnext = edge CCW around destination vertex (keep same dest)
	*  Lnext = edge CCW around left face (dest becomes new origin)
	*  Rnext = edge CCW around right face (origin becomes new dest)
	*
	* "prev" means to substitute CW for CCW in the definitions above.
	*
	* The mesh keeps global lists of all vertices, faces, and edges,
	* stored as doubly-linked circular lists with a dummy header node.
	* The mesh stores pointers to these dummy headers (vHead, fHead, eHead).
	*
	* The circular edge list is special; since half-edges always occur
	* in pairs (e and e->Sym), each half-edge stores a pointer in only
	* one direction.  Starting at eHead and following the e->next pointers
	* will visit each *edge* once (ie. e or e->Sym, but not both).
	* e->Sym stores a pointer in the opposite direction, thus it is
	* always true that e->Sym->next->Sym->next == e.
	*
	* Each vertex has a pointer to next and previous vertices in the
	* circular list, and a pointer to a half-edge with this vertex as
	* the origin (NULL if this is the dummy header).  There is also a
	* field "data" for client data.
	*
	* Each face has a pointer to the next and previous faces in the
	* circular list, and a pointer to a half-edge with this face as
	* the left face (NULL if this is the dummy header).  There is also
	* a field "data" for client data.
	*
	* Note that what we call a "face" is really a loop; faces may consist
	* of more than one loop (ie. not simply connected), but there is no
	* record of this in the data structure.  The mesh may consist of
	* several disconnected regions, so it may not be possible to visit
	* the entire mesh by starting at a half-edge and traversing the edge
	* structure.
	*
	* The mesh does NOT support isolated vertices; a vertex is deleted along
	* with its last edge.  Similarly when two faces are merged, one of the
	* faces is deleted (see tessMeshDelete below).  For mesh operations,
	* all face (loop) and vertex pointers must not be NULL.  However, once
	* mesh manipulation is finished, TESSmeshZapFace can be used to delete
	* faces of the mesh, one at a time.  All external faces can be "zapped"
	* before the mesh is returned to the client; then a NULL face indicates
	* a region which is not part of the output polygon.
	*/--]]

	local function TESSvertex()
		local this = {}
		this.next = nil;	--/* next vertex (never NULL) */
		this.prev = nil;	--/* previous vertex (never NULL) */
		this.anEdge = nil;	--/* a half-edge with this origin */

		--/* Internal data (keep hidden) */
		this.coords = vec3(0,0,0);	--/* vertex location in 3D */
		this.s = 0.0;
		this.t = 0.0;			--/* projection onto the sweep plane */
		this.pqHandle = 0;		--/* to allow deletion from priority queue */
		this.n = 0;				--/* to allow identify unique vertices */
		this.idx = 0;			--/* to allow map result to original verts */
		return this
	end 

	local function TESSface()
		local this = {}
		this.next = nil;		--/* next face (never NULL) */
		this.prev = nil;		--/* previous face (never NULL) */
		this.anEdge = nil;		--/* a half edge with this left face */

		--/* Internal data (keep hidden) */
		this.trail = nil;		--/* "stack" for conversion to strips */
		this.n = 0;				--/* to allow identiy unique faces */
		this.marked = false;	--/* flag for conversion to strips */
		this.inside = false;	--/* this face is in the polygon interior */
		return this
	end

	local TESShalfEdge_meta
	local function TESShalfEdge(side)
		local this = {}
		this.next = nil;		--/* doubly-linked list (prev==Sym->next) */
		this.Sym = nil;		--/* same edge, opposite direction */
		this.Onext = nil;		--/* next edge CCW around origin */
		this.Lnext = nil;		--/* next edge CCW around left face */
		this.Org = nil;		--/* origin vertex (Overtex too long) */
		this.Lface = nil;		--/* left face */

		--/* Internal data (keep hidden) */
		this.activeRegion = nil;	--/* a region with this upper edge (sweep.c) */
		this.winding = 0;			--/* change in winding number when crossing
									--   from the right face to the left face */
		this.side = side;
		function this:Rface()
			return self.Sym.Lface
		end
		function this:Dst()
			return self.Sym.Org
		end
		function this:Oprev()
			return self.Sym.Lnext
		end
		function this:Lprev()
			return self.Onext.Sym
		end
		function this:Dprev()
			return self.Lnext.Sym
		end
		function this:Rprev()
			return self.Sym.Onext
		end
		function this:Dnext()
			return self.Sym.Onext.Sym
		end
		function this:Rnext()
			return self.Sym.Lnext.Sym
		end
		return setmetatable(this, TESShalfEdge_meta)
	end

	TESShalfEdge_meta = {
		--__index = function(this,k) 
			-- if(k == "Rface") then
				-- return this.Sym.Lface
			-- elseif(k == "Dst") then
				-- return this.Sym.Org;
			-- elseif(k == "Oprev") then
				-- return this.Sym.Lnext;
			-- elseif(k == "Lprev") then
				-- return this.Onext.Sym;
			-- elseif(k == "Dprev") then
				-- return this.Lnext.Sym;
			-- elseif(k == "Rprev") then
				-- return this.Sym.Onext;
			-- elseif(k == "Dnext") then
				-- return this.Sym.Onext.Sym;
			-- elseif(k == "Rnext") then
				-- return this.Sym.Lnext.Sym;
			-- end
		-- end,
		__newindex = function(this, k, v)
			if(k == "setRface") then
				this.Sym.Lface = v;
			elseif(k == "setDst") then
				this.Sym.Org = v;
			elseif(k == "setOprev") then
				this.Sym.Lnext = v;
			elseif(k == "setLprev") then
				this.Onext.Sym = v;
			elseif(k == "setDprev") then
				this.Lnext.Sym = v; 
			elseif(k == "setRprev") then
				this.Sym.Onext = v;
			elseif(k == "setDnext") then
				this.Sym.Onext.Sym = v; 
			elseif(k == "setRnext") then
				this.Sym.Lnext.Sym = v; 
			else
				--print("newindex",k,v)
				rawset(this,k, v)
			end
		
		end,
	};


	local TESSmesh_meta
	local function TESSmesh()
		local this = {}
		local v = TESSvertex();
		local f = TESSface();
		local e = TESShalfEdge(0);
		local eSym = TESShalfEdge(1);
		--dumpObj(e,eSym)
		v.prev = v;
		v.next = v
		v.anEdge = nil;

		f.prev = f;
		f.next = f
		f.anEdge = nil;
		f.trail = nil;
		f.marked = false;
		f.inside = false;

		e.next = e;
		e.Sym = eSym;
		e.Onext = nil;
		e.Lnext = nil;
		e.Org = nil;
		e.Lface = nil;
		e.winding = 0;
		e.activeRegion = nil;

		eSym.next = eSym;
		eSym.Sym = e;
		eSym.Onext = nil;
		eSym.Lnext = nil;
		eSym.Org = nil;
		eSym.Lface = nil;
		eSym.winding = 0;
		eSym.activeRegion = nil;
		
		this.name = "TESSMesh"
		this.vHead = v;		--/* dummy header for vertex list */
		this.fHead = f;		--/* dummy header for face list */
		this.eHead = e;		--/* dummy header for edge list */
		this.eHeadSym = eSym;	--/* and its symmetric counterpart */
		--prtable("TESSmesh",this)
		return setmetatable(this, TESSmesh_meta)
		--[[
		local z = setmetatable({this=this}, {__index = _G})
		for k,v in pairs(TESSmesh_meta.meta2) do
			setfenv(v,z)
			--this[k] = (function(this) return v end)()
			this[k] = v --function(...) local this=this;print("this",this);return v(...) end
		end
		return this
		--]]
	end

	--[[/* The mesh operations below have three motivations: completeness,
	* convenience, and efficiency.  The basic mesh operations are MakeEdge,
	* Splice, and Delete.  All the other edge operations can be implemented
	* in terms of these.  The other operations are provided for convenience
	* and/or efficiency.
	*
	* When a face is split or a vertex is added, they are inserted into the
	* global list *before* the existing vertex or face (ie. e->Org or e->Lface).
	* This makes it easier to process all vertices or faces in the global lists
	* without worrying about processing the same data twice.  As a convenience,
	* when a face is split, the "inside" flag is copied from the old face.
	* Other internal data (v->data, v->activeRegion, f->data, f->marked,
	* f->trail, e->winding) is set to zero.
	*
	* ********************** Basic Edge Operations **************************
	*
	* tessMeshMakeEdge( mesh ) creates one edge, two vertices, and a loop.
	* The loop (face) consists of the two new half-edges.
	*
	* tessMeshSplice( eOrg, eDst ) is the basic operation for changing the
	* mesh connectivity and topology.  It changes the mesh so that
	*  eOrg->Onext <- OLD( eDst->Onext )
	*  eDst->Onext <- OLD( eOrg->Onext )
	* where OLD(...) means the value before the meshSplice operation.
	*
	* This can have two effects on the vertex structure:
	*  - if eOrg->Org != eDst->Org, the two vertices are merged together
	*  - if eOrg->Org == eDst->Org, the origin is split into two vertices
	* In both cases, eDst->Org is changed and eOrg->Org is untouched.
	*
	* Similarly (and independently) for the face structure,
	*  - if eOrg->Lface == eDst->Lface, one loop is split into two
	*  - if eOrg->Lface != eDst->Lface, two distinct loops are joined into one
	* In both cases, eDst->Lface is changed and eOrg->Lface is unaffected.
	*
	* tessMeshDelete( eDel ) removes the edge eDel.  There are several cases:
	* if (eDel->Lface != eDel->Rface), we join two loops into one; the loop
	* eDel->Lface is deleted.  Otherwise, we are splitting one loop into two;
	* the newly created loop will contain eDel->Dst.  If the deletion of eDel
	* would create isolated vertices, those are deleted as well.
	*
	* ********************** Other Edge Operations **************************
	*
	* tessMeshAddEdgeVertex( eOrg ) creates a new edge eNew such that
	* eNew == eOrg->Lnext, and eNew->Dst is a newly created vertex.
	* eOrg and eNew will have the same left face.
	*
	* tessMeshSplitEdge( eOrg ) splits eOrg into two edges eOrg and eNew,
	* such that eNew == eOrg->Lnext.  The new vertex is eOrg->Dst == eNew->Org.
	* eOrg and eNew will have the same left face.
	*
	* tessMeshConnect( eOrg, eDst ) creates a new edge from eOrg->Dst
	* to eDst->Org, and returns the corresponding half-edge eNew.
	* If eOrg->Lface == eDst->Lface, this splits one loop into two,
	* and the newly created loop is eNew->Lface.  Otherwise, two disjoint
	* loops are merged into one, and the loop eDst->Lface is destroyed.
	*
	* ************************ Other Operations *****************************
	*
	* tessMeshNewMesh() creates a new mesh with no edges, no vertices,
	* and no loops (what we usually call a "face").
	*
	* tessMeshUnion( mesh1, mesh2 ) forms the union of all structures in
	* both meshes, and returns the new mesh (the old meshes are destroyed).
	*
	* tessMeshDeleteMesh( mesh ) will free all storage for any valid mesh.
	*
	* tessMeshZapFace( fZap ) destroys a face and removes it from the
	* global face list.  All edges of fZap will have a NULL pointer as their
	* left face.  Any edges which also have a NULL pointer as their right face
	* are deleted entirely (along with any isolated vertices this produces).
	* An entire mesh can be deleted by zapping its faces, one at a time,
	* in any order.  Zapped faces cannot be used in further mesh operations!
	*
	* tessMeshCheckMesh( mesh ) checks a mesh for self-consistency.
	*/--]]

	TESSmesh_meta = {
		--__index = function(this, k)
		--meta2 = {
		__index = {
		--[[/* MakeEdge creates a new pair of half-edges which form their own loop.
		* No vertex or face structures are allocated, but these must be assigned
		* before the current edge operation is completed.
		*/--]]
		--//static TESShalfEdge *MakeEdge( TESSmesh* mesh, TESShalfEdge *eNext )
		makeEdge_= function(eNext)
		--prtable("makeEdge_",eNext)
			local e = TESShalfEdge(0);
			local eSym = TESShalfEdge(1);

			--/* Make sure eNext points to the first edge of the edge pair */
			if( eNext.Sym.side < eNext.side ) then eNext = eNext.Sym; end

			--[[/* Insert in circular doubly-linked list before eNext.
			* Note that the prev pointer is stored in Sym->next.
			*/--]]
			local ePrev = eNext.Sym.next;
			eSym.next = ePrev;
			ePrev.Sym.next = e;
			e.next = eNext;
			eNext.Sym.next = eSym;

			e.Sym = eSym;
			e.Onext = e;
			e.Lnext = eSym;
			e.Org = nil;
			e.Lface = nil;
			e.winding = 0;
			e.activeRegion = nil;

			eSym.Sym = e;
			eSym.Onext = eSym;
			eSym.Lnext = e;
			eSym.Org = nil;
			eSym.Lface = nil;
			eSym.winding = 0;
			eSym.activeRegion = nil;

			return e;
		end,

		--[[/* Splice( a, b ) is best described by the Guibas/Stolfi paper or the
		* CS348a notes (see mesh.h).  Basically it modifies the mesh so that
		* a->Onext and b->Onext are exchanged.  This can have various effects
		* depending on whether a and b belong to different face or vertex rings.
		* For more explanation see tessMeshSplice() below.
		*/--]]
		--// static void Splice( TESShalfEdge *a, TESShalfEdge *b )
		splice_= function(a, b) 
			local aOnext = a.Onext;
			local bOnext = b.Onext;
			aOnext.Sym.Lnext = b;
			bOnext.Sym.Lnext = a;
			a.Onext = bOnext;
			b.Onext = aOnext;
		end,

		--[[/* MakeVertex( newVertex, eOrig, vNext ) attaches a new vertex and makes it the
		* origin of all edges in the vertex loop to which eOrig belongs. "vNext" gives
		* a place to insert the new vertex in the global vertex list.  We insert
		* the new vertex *before* vNext so that algorithms which walk the vertex
		* list will not see the newly created vertices.
		*/--]]
		--//static void MakeVertex( TESSvertex *newVertex, TESShalfEdge *eOrig, TESSvertex *vNext )
		makeVertex_= function(newVertex, eOrig, vNext) 
			local vNew = newVertex;
			assert(vNew ~= nil);

			--/* insert in circular doubly-linked list before vNext */
			local vPrev = vNext.prev;
			vNew.prev = vPrev;
			vPrev.next = vNew;
			vNew.next = vNext;
			vNext.prev = vNew;

			vNew.anEdge = eOrig;
			--/* leave coords, s, t undefined */

			--/* fix other edges on this vertex loop */
			local e = eOrig;
			repeat
				e.Org = vNew;
				e = e.Onext;
			until (not(e ~= eOrig));
		end,

		--[[/* MakeFace( newFace, eOrig, fNext ) attaches a new face and makes it the left
		* face of all edges in the face loop to which eOrig belongs.  "fNext" gives
		* a place to insert the new face in the global face list.  We insert
		* the new face *before* fNext so that algorithms which walk the face
		* list will not see the newly created faces.
		*/--]]
		--// static void MakeFace( TESSface *newFace, TESShalfEdge *eOrig, TESSface *fNext )
		--makeFace_= function(newFace, eOrig, fNext) 
		makeFace_= function(fNew, eOrig, fNext) 
			--local fNew = newFace;
			assert(fNew ~= nil); 

			--/* insert in circular doubly-linked list before fNext */
			local fPrev = fNext.prev;
			fNew.prev = fPrev;
			fPrev.next = fNew;
			fNew.next = fNext;
			fNext.prev = fNew;

			fNew.anEdge = eOrig;
			fNew.trail = nil;
			fNew.marked = false;

			--[[/* The new face is marked "inside" if the old one was.  This is a
			* convenience for the common case where a face has been split in two.
			*/--]]
			fNew.inside = fNext.inside;

			--/* fix other edges on this face loop */
			local e = eOrig;
			repeat
				e.Lface = fNew;
				e = e.Lnext;
			--until not(e ~= eOrig);
			until(e==eOrig)
		end,

		--[[/* KillEdge( eDel ) destroys an edge (the half-edges eDel and eDel->Sym),
		* and removes from the global edge list.
		*/--]]
		--//static void KillEdge( TESSmesh *mesh, TESShalfEdge *eDel )
		killEdge_= function(eDel) 
			--/* Half-edges are allocated in pairs, see EdgePair above */
			if( eDel.Sym.side < eDel.side ) then  eDel = eDel.Sym; end

			--/* delete from circular doubly-linked list */
			local eNext = eDel.next;
			local ePrev = eDel.Sym.next;
			eNext.Sym.next = ePrev;
			ePrev.Sym.next = eNext;
		end,


		--[[/* KillVertex( vDel ) destroys a vertex and removes it from the global
		* vertex list.  It updates the vertex loop to point to a given new vertex.
		*/--]]
		--//static void KillVertex( TESSmesh *mesh, TESSvertex *vDel, TESSvertex *newOrg )
		killVertex_= function(vDel, newOrg)
			local eStart = vDel.anEdge;
			--/* change the origin of all affected edges */
			local e = eStart;
			repeat
				e.Org = newOrg;
				e = e.Onext;
			until not(e ~= eStart);

			--/* delete from circular doubly-linked list */
			local vPrev = vDel.prev;
			local vNext = vDel.next;
			vNext.prev = vPrev;
			vPrev.next = vNext;
		end,

		--[[/* KillFace( fDel ) destroys a face and removes it from the global face
		* list.  It updates the face loop to point to a given new face.
		*/--]]
		--//static void KillFace( TESSmesh *mesh, TESSface *fDel, TESSface *newLface )
		killFace_= function(fDel, newLface) 
			local eStart = fDel.anEdge;

			--/* change the left face of all affected edges */
			local e = eStart;
			repeat
				e.Lface = newLface;
				e = e.Lnext;
			until not(e ~= eStart);

			--/* delete from circular doubly-linked list */
			local fPrev = fDel.prev;
			local fNext = fDel.next;
			fNext.prev = fPrev;
			fPrev.next = fNext;
		end,

		--/****************** Basic Edge Operations **********************/

		--[[/* tessMeshMakeEdge creates one edge, two vertices, and a loop (face).
		* The loop consists of the two new half-edges.
		*/--]]
		--//TESShalfEdge *tessMeshMakeEdge( TESSmesh *mesh )
		makeEdge = function(this) 
			local newVertex1 = TESSvertex();
			local newVertex2 = TESSvertex();
			local newFace = TESSface();
			--prtable("makeEdge",this)
			local e = this.makeEdge_( this.eHead);
			this.makeVertex_( newVertex1, e, this.vHead );
			this.makeVertex_( newVertex2, e.Sym, this.vHead );
			this.makeFace_( newFace, e, this.fHead );
			return e;
		end,

		--[[/* tessMeshSplice( eOrg, eDst ) is the basic operation for changing the
		* mesh connectivity and topology.  It changes the mesh so that
		*	eOrg->Onext <- OLD( eDst->Onext )
		*	eDst->Onext <- OLD( eOrg->Onext )
		* where OLD(...) means the value before the meshSplice operation.
		*
		* This can have two effects on the vertex structure:
		*  - if eOrg->Org != eDst->Org, the two vertices are merged together
		*  - if eOrg->Org == eDst->Org, the origin is split into two vertices
		* In both cases, eDst->Org is changed and eOrg->Org is untouched.
		*
		* Similarly (and independently) for the face structure,
		*  - if eOrg->Lface == eDst->Lface, one loop is split into two
		*  - if eOrg->Lface != eDst->Lface, two distinct loops are joined into one
		* In both cases, eDst->Lface is changed and eOrg->Lface is unaffected.
		*
		* Some special cases:
		* If eDst == eOrg, the operation has no effect.
		* If eDst == eOrg->Lnext, the new face will have a single edge.
		* If eDst == eOrg->Lprev, the old face will have a single edge.
		* If eDst == eOrg->Onext, the new vertex will have a single edge.
		* If eDst == eOrg->Oprev, the old vertex will have a single edge.
		*/--]]
		--//int tessMeshSplice( TESSmesh* mesh, TESShalfEdge *eOrg, TESShalfEdge *eDst )
		splice = function(this,eOrg, eDst) 
			local joiningLoops = false;
			local joiningVertices = false;

			if( eOrg == eDst ) then return end

			if( eDst.Org ~= eOrg.Org ) then
				--/* We are merging two disjoint vertices -- destroy eDst->Org */
				joiningVertices = true;
				this.killVertex_( eDst.Org, eOrg.Org );
			end
			if( eDst.Lface ~= eOrg.Lface ) then
				--/* We are connecting two disjoint loops -- destroy eDst->Lface */
				joiningLoops = true;
				this.killFace_( eDst.Lface, eOrg.Lface );
			end

			--/* Change the edge structure */
			this.splice_( eDst, eOrg );

			if( not joiningVertices ) then
				local newVertex = TESSvertex();

				--[[/* We split one vertex into two -- the new vertex is eDst->Org.
				* Make sure the old vertex points to a valid half-edge.
				*/--]]
				this.makeVertex_( newVertex, eDst, eOrg.Org );
				eOrg.Org.anEdge = eOrg;
			end
			if( not joiningLoops ) then
				local newFace = TESSface();  

				--[[/* We split one loop into two -- the new loop is eDst->Lface.
				* Make sure the old face points to a valid half-edge.
				*/--]]
				this.makeFace_( newFace, eDst, eOrg.Lface );
				eOrg.Lface.anEdge = eOrg;
			end
		end,

		--[[/* tessMeshDelete( eDel ) removes the edge eDel.  There are several cases:
		* if (eDel->Lface != eDel->Rface), we join two loops into one; the loop
		* eDel->Lface is deleted.  Otherwise, we are splitting one loop into two;
		* the newly created loop will contain eDel->Dst.  If the deletion of eDel
		* would create isolated vertices, those are deleted as well.
		*
		* This function could be implemented as two calls to tessMeshSplice
		* plus a few calls to memFree, but this would allocate and delete
		* unnecessary vertices and faces.
		*/--]]
		--//int tessMeshDelete( TESSmesh *mesh, TESShalfEdge *eDel )
		delete = function(this,eDel) 
			local eDelSym = eDel.Sym;
			local joiningLoops = false;

			--[[/* First step: disconnect the origin vertex eDel->Org.  We make all
			* changes to get a consistent mesh in this "intermediate" state.
			*/--]]
			if( eDel.Lface ~= eDel:Rface() ) then
				--/* We are joining two loops into one -- remove the left face */
				joiningLoops = true;
				this.killFace_( eDel.Lface, eDel:Rface() );
			end

			if( eDel.Onext == eDel ) then
				this.killVertex_( eDel.Org, nil );
			else 
				--/* Make sure that eDel->Org and eDel->Rface point to valid half-edges */
				eDel:Rface().anEdge = eDel:Oprev();
				eDel.Org.anEdge = eDel.Onext;

				this.splice_( eDel, eDel:Oprev() );
				if( not joiningLoops ) then
					local newFace = TESSface();

					--/* We are splitting one loop into two -- create a new loop for eDel. */
					this.makeFace_( newFace, eDel, eDel.Lface );
				end
			end

			--[[/* Claim: the mesh is now in a consistent state, except that eDel->Org
			* may have been deleted.  Now we disconnect eDel->Dst.
			*/--]]
			if( eDelSym.Onext == eDelSym ) then
				this.killVertex_( eDelSym.Org, nil );
				this.killFace_( eDelSym.Lface, nil );
			else 
				--/* Make sure that eDel->Dst and eDel->Lface point to valid half-edges */
				eDel.Lface.anEdge = eDelSym:Oprev();
				eDelSym.Org.anEdge = eDelSym.Onext;
				this.splice_( eDelSym, eDelSym:Oprev() );
			end

			--/* Any isolated vertices or faces have already been freed. */
			this.killEdge_( eDel );
		end,

		--/******************** Other Edge Operations **********************/

		--[[/* All these routines can be implemented with the basic edge
		* operations above.  They are provided for convenience and efficiency.
		*/--]]


		--[[/* tessMeshAddEdgeVertex( eOrg ) creates a new edge eNew such that
		* eNew == eOrg->Lnext, and eNew->Dst is a newly created vertex.
		* eOrg and eNew will have the same left face.
		*/--]]
		--// TESShalfEdge *tessMeshAddEdgeVertex( TESSmesh *mesh, TESShalfEdge *eOrg );
		addEdgeVertex = function(this,eOrg) 
			local eNew = this.makeEdge_( eOrg );
			local eNewSym = eNew.Sym;

			--/* Connect the new edge appropriately */
			this.splice_( eNew, eOrg.Lnext );

			--/* Set the vertex and face information */
			eNew.Org = eOrg:Dst();

			local newVertex = TESSvertex();
			this.makeVertex_( newVertex, eNewSym, eNew.Org );

			eNewSym.Lface = eOrg.Lface;
			eNew.Lface = eOrg.Lface

			return eNew;
		end,


		--[[/* tessMeshSplitEdge( eOrg ) splits eOrg into two edges eOrg and eNew,
		* such that eNew == eOrg->Lnext.  The new vertex is eOrg->Dst == eNew->Org.
		* eOrg and eNew will have the same left face.
		*/--]]
		--// TESShalfEdge *tessMeshSplitEdge( TESSmesh *mesh, TESShalfEdge *eOrg );
		splitEdge = function(this,eOrg, eDst) 
			local tempHalfEdge = this:addEdgeVertex( eOrg );
			local eNew = tempHalfEdge.Sym;

			--/* Disconnect eOrg from eOrg->Dst and connect it to eNew->Org */
			this.splice_( eOrg.Sym, eOrg.Sym:Oprev() );
			this.splice_( eOrg.Sym, eNew );

			--/* Set the vertex and face information */
			eOrg.setDst = eNew.Org;
			eNew:Dst().anEdge = eNew.Sym;	--/* may have pointed to eOrg->Sym */
			eNew.setRface = eOrg:Rface();
			eNew.winding = eOrg.winding;	--/* copy old winding information */
			eNew.Sym.winding = eOrg.Sym.winding;

			return eNew;
		end,


		--[[/* tessMeshConnect( eOrg, eDst ) creates a new edge from eOrg->Dst
		* to eDst->Org, and returns the corresponding half-edge eNew.
		* If eOrg->Lface == eDst->Lface, this splits one loop into two,
		* and the newly created loop is eNew->Lface.  Otherwise, two disjoint
		* loops are merged into one, and the loop eDst->Lface is destroyed.
		*
		* If (eOrg == eDst), the new face will have only two edges.
		* If (eOrg->Lnext == eDst), the old face is reduced to a single edge.
		* If (eOrg->Lnext->Lnext == eDst), the old face is reduced to two edges.
		*/--]]

		--// TESShalfEdge *tessMeshConnect( TESSmesh *mesh, TESShalfEdge *eOrg, TESShalfEdge *eDst );
		connect = function(this,eOrg, eDst) 
			local joiningLoops = false;  
			local eNew = this.makeEdge_( eOrg );
			local eNewSym = eNew.Sym;

			if( eDst.Lface ~= eOrg.Lface ) then
				--/* We are connecting two disjoint loops -- destroy eDst->Lface */
				joiningLoops = true;
				this.killFace_( eDst.Lface, eOrg.Lface );
			end

			--/* Connect the new edge appropriately */
			this.splice_( eNew, eOrg.Lnext );
			this.splice_( eNewSym, eDst );

			--/* Set the vertex and face information */
			eNew.Org = eOrg:Dst();
			eNewSym.Org = eDst.Org;
			eNewSym.Lface = eOrg.Lface;
			eNew.Lface = eOrg.Lface;

			--/* Make sure the old face points to a valid half-edge */
			eOrg.Lface.anEdge = eNewSym;

			if( not joiningLoops ) then
				local newFace = TESSface();
				--/* We split one loop into two -- the new loop is eNew->Lface */
				this.makeFace_( newFace, eNew, eOrg.Lface );
			end
			return eNew;
		end,

		--[[/* tessMeshZapFace( fZap ) destroys a face and removes it from the
		* global face list.  All edges of fZap will have a NULL pointer as their
		* left face.  Any edges which also have a NULL pointer as their right face
		* are deleted entirely (along with any isolated vertices this produces).
		* An entire mesh can be deleted by zapping its faces, one at a time,
		* in any order.  Zapped faces cannot be used in further mesh operations!
		*/--]]
		zapFace = function( fZap )
		
			local eStart = fZap.anEdge;
			local e, eNext, eSym;
			local fPrev, fNext;

			--/* walk around face, deleting edges whose right face is also NULL */
			eNext = eStart.Lnext;
			repeat
				e = eNext;
				eNext = e.Lnext;

				e.Lface = nil;
				if( e:Rface() == nil ) then
					--/* delete the edge -- see TESSmeshDelete above */

					if( e.Onext == e ) then
						this.killVertex_( e.Org, nil );
					else 
						--/* Make sure that e->Org points to a valid half-edge */
						e.Org.anEdge = e.Onext;
						this.splice_( e, e:Oprev() );
					end
					eSym = e.Sym;
					if( eSym.Onext == eSym ) then
						this.killVertex_( eSym.Org, nil );
					else 
						--/* Make sure that eSym->Org points to a valid half-edge */
						eSym.Org.anEdge = eSym.Onext;
						this.splice_( eSym, eSym:Oprev() );
					end
					this.killEdge_( e );
				end
			until not( e ~= eStart );

			--/* delete from circular doubly-linked list */
			fPrev = fZap.prev;
			fNext = fZap.next;
			fNext.prev = fPrev;
			fPrev.next = fNext;
		end,

		countFaceVerts_ = function(f) 
			local eCur = f.anEdge;
			local n = 0;
			repeat
				n = n + 1;
				eCur = eCur.Lnext;
			until not (eCur ~= f.anEdge);
			return n;
		end,

		--//int tessMeshMergeConvexFaces( TESSmesh *mesh, int maxVertsPerFace )
		mergeConvexFaces = function(maxVertsPerFace) 
			local f;
			local eCur, eNext, eSym;
			local vStart;
			local curNv, symNv;

			local f = this.fHead.next;
			--for( f = this.fHead.next; f ~= this.fHead; f = f.next )
			--{
			while ( f ~= this.fHead) do
				--// Skip faces which are outside the result.
				if( not f.inside ) then
					goto continue; end

				eCur = f.anEdge;
				vStart = eCur.Org;
					
				while (true) do
					eNext = eCur.Lnext;
					eSym = eCur.Sym;

					--// Try to merge if the neighbour face is valid.
					if( eSym and eSym.Lface and eSym.Lface.inside ) then
						--// Try to merge the neighbour faces if the resulting polygons
						--// does not exceed maximum number of vertices.
						curNv = this.countFaceVerts_( f );
						symNv = this.countFaceVerts_( eSym.Lface );
						if( (curNv+symNv-2) <= maxVertsPerFace ) then
							--// Merge if the resulting poly is convex.
							if( Geom.vertCCW( eCur:Lprev().Org, eCur.Org, eSym.Lnext.Lnext.Org ) and
								Geom.vertCCW( eSym:Lprev().Org, eSym.Org, eCur.Lnext.Lnext.Org ) )
							then
								eNext = eSym.Lnext;
								this:delete( eSym );
								eCur = nil;
								eSym = nil;
							end
						end
					end
					
					if( eCur and eCur.Lnext.Org == vStart ) then
						break;
					end
					--// Continue to next edge.
					eCur = eNext;
				end
				::continue::
				f = f.next
			end
			
			return true;
		end,

		--/* tessMeshCheckMesh( mesh ) checks a mesh for self-consistency.
		--*/
		check = function(this) 
			local fHead = this.fHead;
			local vHead = this.vHead;
			local eHead = this.eHead;
			local f, fPrev, v, vPrev, e, ePrev;

			fPrev = fHead;
			--for( fPrev = fHead ; (f = fPrev.next) ~= fHead; fPrev = f) {
			while(fPrev.next ~= fHead) do
				f = fPrev.next
			--while((function()f = fPrev.next; return true end)() and f~= fHead) do
				assert( f.prev == fPrev );
				e = f.anEdge;
				repeat
					assert( e.Sym ~= e );
					assert( e.Sym.Sym == e );
					assert( e.Lnext.Onext.Sym == e );
					assert( e.Onext.Sym.Lnext == e );
					assert( e.Lface == f );
					e = e.Lnext;
				until not( e ~= f.anEdge );
				fPrev = f
			end
			f = fPrev.next
			assert( f.prev == fPrev and f.anEdge == nil );
			--if not ( f.prev == fPrev and f.anEdge == nil ) then print(f.prev, fPrev,f.anEdge); error"bbbb" end
			vPrev = vHead;
			--for( vPrev = vHead ; (v = vPrev.next) ~= vHead; vPrev = v) {
			while(vPrev.next ~= vHead) do
				v = vPrev.next
				assert( v.prev == vPrev );
				e = v.anEdge;
				repeat
					assert( e.Sym ~= e );
					assert( e.Sym.Sym == e );
					assert( e.Lnext.Onext.Sym == e );
					assert( e.Onext.Sym.Lnext == e );
					assert( e.Org == v );
					e = e.Onext;
				until not( e ~= v.anEdge );
				vPrev = v
			end
			v = vPrev.next
			assert( v.prev == vPrev and v.anEdge == nil );

			ePrev = eHead;
			--for( ePrev = eHead ; (e = ePrev.next) ~= eHead; ePrev = e) {
			while(ePrev.next ~= eHead) do
				e = ePrev.next
				assert( e.Sym.next == ePrev.Sym );
				assert( e.Sym ~= e );
				assert( e.Sym.Sym == e );
				assert( e.Org ~= nil );
				assert( e:Dst() ~= nil );
				assert( e.Lnext.Onext.Sym == e );
				assert( e.Onext.Sym.Lnext == e );
				ePrev = e
			end
			e = ePrev.next
			assert( e.Sym.next == ePrev.Sym
				and e.Sym == this.eHeadSym
				and e.Sym.Sym == e
				and e.Org == nil and e:Dst() == nil
				and e.Lface == nil and e:Rface() == nil );
		end}
		--if meta2[k] then return meta2[k] end
		--return meta2[k]
		--end
	};

	Geom.vertEq = function(u,v) 
		return (u.s == v.s and u.t == v.t);
	end;

	--/* Returns TRUE if u is lexicographically <= v. */
	Geom.vertLeq = function(u,v) 
		return ((u.s < v.s) or (u.s == v.s and u.t <= v.t));
	end;

	--/* Versions of VertLeq, EdgeSign, EdgeEval with s and t transposed. */
	Geom.transLeq = function(u,v) 
		return ((u.t < v.t) or (u.t == v.t and u.s <= v.s));
	end;

	Geom.edgeGoesLeft = function(e) 
		return Geom.vertLeq( e:Dst(), e.Org );
	end;

	Geom.edgeGoesRight = function(e) 
		return Geom.vertLeq( e.Org, e:Dst() );
	end;

	Geom.vertL1dist = function(u,v) 
		return (math.abs(u.s - v.s) + math.abs(u.t - v.t));
	end;

	--//TESSreal tesedgeEval( TESSvertex *u, TESSvertex *v, TESSvertex *w )
	Geom.edgeEval = function( u, v, w ) 
		--[[/* Given three vertices u,v,w such that VertLeq(u,v) and VertLeq(v,w),
		* evaluates the t-coord of the edge uw at the s-coord of the vertex v.
		* Returns v->t - (uw)(v->s), ie. the signed distance from uw to v.
		* If uw is vertical (and thus passes thru v), the result is zero.
		*
		* The calculation is extremely accurate and stable, even when v
		* is very close to u or w.  In particular if we set v->t = 0 and
		* let r be the negated result (this evaluates (uw)(v->s)), then
		* r is guaranteed to satisfy MIN(u->t,w->t) <= r <= MAX(u->t,w->t).
		*/--]]
		assert( Geom.vertLeq( u, v ) and Geom.vertLeq( v, w ));

		local gapL = v.s - u.s;
		local gapR = w.s - v.s;

		if( gapL + gapR > 0.0 ) then
			if( gapL < gapR ) then
				return (v.t - u.t) + (u.t - w.t) * (gapL / (gapL + gapR));
			else 
				return (v.t - w.t) + (w.t - u.t) * (gapR / (gapL + gapR));
			end
		end
		--/* vertical line */
		return 0.0;
	end;

	--//TESSreal tesedgeSign( TESSvertex *u, TESSvertex *v, TESSvertex *w )
	Geom.edgeSign = function( u, v, w ) 
		--[[/* Returns a number whose sign matches EdgeEval(u,v,w) but which
		* is cheaper to evaluate.  Returns > 0, == 0 , or < 0
		* as v is above, on, or below the edge uw.
		*/--]]
		assert( Geom.vertLeq( u, v ) and Geom.vertLeq( v, w ));

		local gapL = v.s - u.s;
		local gapR = w.s - v.s;

		if( gapL + gapR > 0.0 ) then
			return (v.t - w.t) * gapL + (v.t - u.t) * gapR;
		end
		--/* vertical line */
		return 0.0;
	end;


	--[[/***********************************************************************
	* Define versions of EdgeSign, EdgeEval with s and t transposed.
	*/--]]

	--//TESSreal testransEval( TESSvertex *u, TESSvertex *v, TESSvertex *w )
	Geom.transEval = function( u, v, w )
		--[[/* Given three vertices u,v,w such that TransLeq(u,v) and TransLeq(v,w),
		* evaluates the t-coord of the edge uw at the s-coord of the vertex v.
		* Returns v->s - (uw)(v->t), ie. the signed distance from uw to v.
		* If uw is vertical (and thus passes thru v), the result is zero.
		*
		* The calculation is extremely accurate and stable, even when v
		* is very close to u or w.  In particular if we set v->s = 0 and
		* let r be the negated result (this evaluates (uw)(v->t)), then
		* r is guaranteed to satisfy MIN(u->s,w->s) <= r <= MAX(u->s,w->s).
		*/--]]
		assert( Geom.transLeq( u, v ) and Geom.transLeq( v, w ));

		local gapL = v.t - u.t;
		local gapR = w.t - v.t;

		if( gapL + gapR > 0.0 ) then
			if( gapL < gapR ) then
				return (v.s - u.s) + (u.s - w.s) * (gapL / (gapL + gapR));
			else 
				return (v.s - w.s) + (w.s - u.s) * (gapR / (gapL + gapR));
			end
		end
		--/* vertical line */
		return 0.0;
	end;

	--//TESSreal testransSign( TESSvertex *u, TESSvertex *v, TESSvertex *w )
	Geom.transSign = function( u, v, w ) 
		--[[/* Returns a number whose sign matches TransEval(u,v,w) but which
		* is cheaper to evaluate.  Returns > 0, == 0 , or < 0
		* as v is above, on, or below the edge uw.
		*/--]]
		assert( Geom.transLeq( u, v ) and Geom.transLeq( v, w ));

		local gapL = v.t - u.t;
		local gapR = w.t - v.t;

		if( gapL + gapR > 0.0 ) then
			return (v.s - w.s) * gapL + (v.s - u.s) * gapR;
		end
		--/* vertical line */
		return 0.0;
	end;


	--//int tesvertCCW( TESSvertex *u, TESSvertex *v, TESSvertex *w )
	Geom.vertCCW = function( u, v, w )
		--[[/* For almost-degenerate situations, the results are not reliable.
		* Unless the floating-point arithmetic can be performed without
		* rounding errors, *any* implementation will give incorrect results
		* on some degenerate inputs, so the client must have some way to
		* handle this situation.
		*/--]]
		return (u.s*(v.t - w.t) + v.s*(w.t - u.t) + w.s*(u.t - v.t)) >= 0.0;
	end;

	--[[/* Given parameters a,x,b,y returns the value (b*x+a*y)/(a+b),
	* or (x+y)/2 if a==b==0.  It requires that a,b >= 0, and enforces
	* this in the rare case that one argument is slightly negative.
	* The implementation is extremely stable numerically.
	* In particular it guarantees that the result r satisfies
	* MIN(x,y) <= r <= MAX(x,y), and the results are very accurate
	* even when a and b differ greatly in magnitude.
	*/--]]
	Geom.interpolate = function(a,x,b,y)
		--return (a = (a < 0) ? 0 : a, b = (b < 0) ? 0 : b, ((a <= b) ? ((b == 0) ? ((x+y) / 2) : (x + (y-x) * (a/(a+b)))) : (y + (x-y) * (b/(a+b)))));
		a = (a < 0) and 0 or a
		b = (b < 0) and 0 or b
		if a==0 and b==0 then return (x+y) / 2 end
		return (b*x+a*y)/(a+b)
	end;

	--[[/*
	#ifndef FOR_TRITE_TEST_PROGRAM
	#define Interpolate(a,x,b,y)	RealInterpolate(a,x,b,y)
	#else

	// Claim: the ONLY property the sweep algorithm relies on is that
	// MIN(x,y) <= r <= MAX(x,y).  This is a nasty way to test that.
	#include <stdlib.h>
	extern int RandomInterpolate;

	double Interpolate( double a, double x, double b, double y)
	{
		printf("*********************%d\n",RandomInterpolate);
		if( RandomInterpolate ) {
			a = 1.2 * drand48() - 0.1;
			a = (a < 0) ? 0 : ((a > 1) ? 1 : a);
			b = 1.0 - a;
		}
		return RealInterpolate(a,x,b,y);
	}
	#endif*/--]]

	Geom.intersect = function( o1, d1, o2, d2, v )
		--[[/* Given edges (o1,d1) and (o2,d2), compute their point of intersection.
		* The computed point is guaranteed to lie in the intersection of the
		* bounding rectangles defined by each edge.
		*/--]]
		local z1, z2;
		local t;

		--[[/* This is certainly not the most efficient way to find the intersection
		* of two line segments, but it is very numerically stable.
		*
		* Strategy: find the two middle vertices in the VertLeq ordering,
		* and interpolate the intersection s-value from these.  Then repeat
		* using the TransLeq ordering to find the intersection t-value.
		*/--]]

		if( not Geom.vertLeq( o1, d1 )) then t = o1; o1 = d1; d1 = t; end --//swap( o1, d1 ); }
		if( not Geom.vertLeq( o2, d2 )) then t = o2; o2 = d2; d2 = t; end --//swap( o2, d2 ); }
		if( not Geom.vertLeq( o1, o2 )) then t = o1; o1 = o2; o2 = t; t = d1; d1 = d2; d2 = t; end --//swap( o1, o2 ); swap( d1, d2 ); }

		if( not Geom.vertLeq( o2, d1 )) then
			--/* Technically, no intersection -- do our best */
			v.s = (o2.s + d1.s) / 2;
		elseif( Geom.vertLeq( d1, d2 )) then
			--/* Interpolate between o2 and d1 */
			z1 = Geom.edgeEval( o1, o2, d1 );
			z2 = Geom.edgeEval( o2, d1, d2 );
			if( z1+z2 < 0 ) then z1 = -z1; z2 = -z2; end
			v.s = Geom.interpolate( z1, o2.s, z2, d1.s );
		else
			--/* Interpolate between o2 and d2 */
			z1 = Geom.edgeSign( o1, o2, d1 );
			z2 = -Geom.edgeSign( o1, d2, d1 );
			if( z1+z2 < 0 ) then z1 = -z1; z2 = -z2; end
			v.s = Geom.interpolate( z1, o2.s, z2, d2.s );
		end

		--/* Now repeat the process for t */

		if( not Geom.transLeq( o1, d1 )) then t = o1; o1 = d1; d1 = t; end -- //swap( o1, d1 ); }
		if( not Geom.transLeq( o2, d2 )) then t = o2; o2 = d2; d2 = t; end -- //swap( o2, d2 ); }
		if( not Geom.transLeq( o1, o2 )) then t = o1; o1 = o2; o2 = t; t = d1; d1 = d2; d2 = t; end -- //swap( o1, o2 ); swap( d1, d2 ); }

		if( not Geom.transLeq( o2, d1 )) then
			--/* Technically, no intersection -- do our best */
			v.t = (o2.t + d1.t) / 2;
		elseif( Geom.transLeq( d1, d2 )) then
			--/* Interpolate between o2 and d1 */
			z1 = Geom.transEval( o1, o2, d1 );
			z2 = Geom.transEval( o2, d1, d2 );
			if( z1+z2 < 0 ) then z1 = -z1; z2 = -z2; end
			v.t = Geom.interpolate( z1, o2.t, z2, d1.t );
		else 
			--/* Interpolate between o2 and d2 */
			z1 = Geom.transSign( o1, o2, d1 );
			z2 = -Geom.transSign( o1, d2, d1 );
			if( z1+z2 < 0 ) then z1 = -z1; z2 = -z2; end
			v.t = Geom.interpolate( z1, o2.t, z2, d2.t );
		end
	end;



	local function DictNode() 
		local this = {}
		this.key = nil;
		this.next = nil;
		this.prev = nil;
		return this
	end;
	
	local Dict_meta
	local function Dict(frame, leq)
		local this = {}
		this.head = DictNode();
		this.head.next = this.head;
		this.head.prev = this.head;
		this.frame = frame;
		this.leq = leq;
		return setmetatable(this, Dict_meta)
	end;

	Dict_meta = {
		__index = --function(this, k)
		--local meta2 = 
		{
		min= function(this) 
			return this.head.next;
		end,

		max= function() 
			return this.head.prev;
		end,

		insert= function(this,k) 
			return this:insertBefore(this.head, k);
		end,

		search= function(this,key) 
			--[[/* Search returns the node with the smallest key greater than or equal
			* to the given key.  If there is no such key, returns a node whose
			* key is NULL.  Similarly, Succ(Max(d)) has a NULL key, etc.
			*/--]]
			local node = this.head;
			repeat
				node = node.next;
			--until not ( node.key ~= nil and not this.leq(this.frame, key, node.key));
			until( node.key == nil or this.leq(this.frame, key, node.key))

			return node;
		end,

		insertBefore= function(this,node, key) 
			repeat
				node = node.prev;
			until not( node.key ~= nil and not this.leq(this.frame, node.key, key));

			local newNode = DictNode();
			newNode.key = key;
			newNode.next = node.next;
			node.next.prev = newNode;
			newNode.prev = node;
			node.next = newNode;

			return newNode;
		end,

		delete= function(node) 
			node.next.prev = node.prev;
			node.prev.next = node.next;
		end
		}

	};


	local function PQnode() 
		local this = {}
		--this.handle = nil;
		return this
	end

	local function PQhandleElem()
		local this = {}
		-- this.key = nil;
		-- this.node = nil;
		return this
	end

	local PriorityQ_meta
	local function PriorityQ(size, leq)
		local this = {}
		this.size = 0;
		this.max = size;

		this.nodes = {};
		this.nodes.length = size+1;
		local i;
		
		--for (i = 0; i < this.nodes.length; i++)
		for i=0, this.nodes.length-1 do
			this.nodes[i] = PQnode();
		end

		this.handles = {};
		this.handles.length = size+1;
		--for (i = 0; i < this.handles.length; i++)
		for i=0, this.handles.length-1 do
			this.handles[i] = PQhandleElem();
		end

		this.initialized = false;
		this.freeList = 0;
		this.leq = leq;

		this.nodes[1].handle = 1;	--/* so that Minimum() returns NULL */
		this.handles[1].key = nil;
		return setmetatable(this, PriorityQ_meta)
	end;

	PriorityQ_meta = {
		__index = --function(this, k)
		--local meta2 = 
		{
		floatDown_= function(this, curr )
			local n = this.nodes;
			local h = this.handles;
			--local hCurr, hChild;
			--local child;

			local hCurr = n[curr].handle;
			while true do
				local child = bit.lshift(curr , 1);
				if( child < this.size and this.leq( h[n[child+1].handle].key, h[n[child].handle].key )) then
					child = child + 1;
				end

				assert(child <= this.max);

				local hChild = n[child].handle;
				if( child > this.size or this.leq( h[hCurr].key, h[hChild].key )) then
					n[curr].handle = hCurr;
					h[hCurr].node = curr;
					break;
				end
				n[curr].handle = hChild;
				h[hChild].node = curr;
				curr = child;
			end
		end,

		floatUp_= function(this, curr )
			local n = this.nodes;
			local h = this.handles;
			local hCurr, hParent;
			local parent;

			hCurr = n[curr].handle;
			while true do
				parent = bit.rshift(curr, 1);
				hParent = n[parent].handle;
				if( parent == 0 or this.leq( h[hParent].key, h[hCurr].key )) then
					n[curr].handle = hCurr;
					h[hCurr].node = curr;
					break;
				end
				n[curr].handle = hParent;
				h[hParent].node = curr;
				curr = parent;
			end
		end,

		init = function(this) 
			--/* This method of building a heap is O(n), rather than O(n lg n). */
			--for( local i = this.size; i >= 1; --i ) {
			for i= this.size,1,-1 do
				this:floatDown_( i );
			end
			this.initialized = true;
		end,

		min= function(this) 
			return this.handles[this.nodes[1].handle].key;
		end,

		--/* really pqHeapInsert */
		--/* returns INV_HANDLE iff out of memory */
		--//PQhandle pqHeapInsert( TESSalloc* alloc, PriorityQHeap *pq, PQkey keyNew )
		insert= function(this, keyNew)
			local curr;
			local free;
			
			this.size = this.size + 1
			curr = this.size
			if( (curr*2) > this.max ) then
				this.max = this.max * 2;
				local i;
				local s;
				s = this.nodes.length;
				this.nodes.length = this.max+1;
				for i= s, this.nodes.length-1 do
					this.nodes[i] = PQnode();
				end

				s = this.handles.length;
				this.handles.length = this.max+1;

				for i = s, this.handles.length-1 do
					this.handles[i] = PQhandleElem();
				end
			end

			if( this.freeList == 0 ) then
				free = curr;
			else
				free = this.freeList;
				this.freeList = this.handles[free].node;
			end

			this.nodes[curr].handle = free;
			this.handles[free].node = curr;
			this.handles[free].key = keyNew;

			if( this.initialized ) then
				--print"-----------insert initiali"
				this:floatUp_( curr );
			end
			return free;
		end,

		--//PQkey pqHeapExtractMin( PriorityQHeap *pq )
		extractMin= function(this) 
			local n = this.nodes;
			local h = this.handles;
			local hMin = n[1].handle;
			local min = h[hMin].key;
			-- print("in extractMin",hMin, min)
			-- prtableN(min,3)
			if( this.size > 0 ) then
				n[1].handle = n[this.size].handle;
				h[n[1].handle].node = 1;

				h[hMin].key = nil;
				h[hMin].node = this.freeList;
				this.freeList = hMin;

				this.size = this.size - 1
				if( this.size > 0 ) then
					this:floatDown_( 1 );
				end
			end
			return min;
		end,

		delete= function(this, hCurr ) 
			local n = this.nodes;
			local h = this.handles;
			local curr;

			assert( hCurr >= 1 and hCurr <= this.max and h[hCurr].key ~= nil );

			curr = h[hCurr].node;
			n[curr].handle = n[this.size].handle;
			h[n[curr].handle].node = curr;

			this.size = this.size - 1
			if( curr <= this.size ) then
				if( curr <= 1 or this.leq( h[n[bit.rshift(curr,1)].handle].key, h[n[curr].handle].key )) then
					this:floatDown_( curr );
				else 
					this:floatUp_( curr );
				end
			end
			h[hCurr].key = nil;
			h[hCurr].node = this.freeList;
			this.freeList = hCurr;
		end
		}
		--return meta2[k] 
		--end
	};


	--[[/* For each pair of adjacent edges crossing the sweep line, there is
	* an ActiveRegion to represent the region between them.  The active
	* regions are kept in sorted order in a dynamic dictionary.  As the
	* sweep line crosses each vertex, we update the affected regions.
	*/--]]

	local function ActiveRegion() 
		local this = {}
		this.eUp = nil;		--/* upper edge, directed right to left */
		this.nodeUp = nil;	--/* dictionary node corresponding to eUp */
		this.windingNumber = 0;	--/* used to determine which regions are
								--* inside the polygon */
		this.inside = false;		--/* is this region inside the polygon? */
		this.sentinel = false;	--/* marks fake edges at t = +/-infinity */
		this.dirty = false;		--/* marks regions where the upper or lower
						--* edge has changed, but we haven't checked
						--* whether they intersect yet */
		this.fixUpperEdge = false;	--/* marks temporary edges introduced when
							--* we process a "right vertex" (one without
							--* any edges leaving to the right) */
		return this
	end;

	local Sweep = {};

	Sweep.regionBelow = function(r) 
		return r.nodeUp.prev.key;
	end

	Sweep.regionAbove = function(r) 
		return r.nodeUp.next.key;
	end

	Sweep.debugEvent = function( tess )
		--// empty
	end


	--[[/*
	* Invariants for the Edge Dictionary.
	* - each pair of adjacent edges e2=Succ(e1) satisfies EdgeLeq(e1,e2)
	*   at any valid location of the sweep event
	* - if EdgeLeq(e2,e1) as well (at any valid sweep event), then e1 and e2
	*   share a common endpoint
	* - for each e, e->Dst has been processed, but not e->Org
	* - each edge e satisfies VertLeq(e->Dst,event) and VertLeq(event,e->Org)
	*   where "event" is the current sweep line event.
	* - no edge e has zero length
	*
	* Invariants for the Mesh (the processed portion).
	* - the portion of the mesh left of the sweep line is a planar graph,
	*   ie. there is *some* way to embed it in the plane
	* - no processed edge has zero length
	* - no two processed vertices have identical coordinates
	* - each "inside" region is monotone, ie. can be broken into two chains
	*   of monotonically increasing vertices according to VertLeq(v1,v2)
	*   - a non-invariant: these chains may intersect (very slightly)
	*
	* Invariants for the Sweep.
	* - if none of the edges incident to the event vertex have an activeRegion
	*   (ie. none of these edges are in the edge dictionary), then the vertex
	*   has only right-going edges.
	* - if an edge is marked "fixUpperEdge" (it is a temporary edge introduced
	*   by ConnectRightVertex), then it is the only right-going edge from
	*   its associated vertex.  (This says that these edges exist only
	*   when it is necessary.)
	*/--]]

	--[[/* When we merge two edges into one, we need to compute the combined
	* winding of the new edge.
	*/--]]
	Sweep.addWinding = function(eDst,eSrc) 
		eDst.winding = eDst.winding + eSrc.winding;
		eDst.Sym.winding = eDst.Sym.winding + eSrc.Sym.winding;
	end


	--//static int EdgeLeq( TESStesselator *tess, ActiveRegion *reg1, ActiveRegion *reg2 )
	Sweep.edgeLeq = function( tess, reg1, reg2 ) 
		--[[/*
		* Both edges must be directed from right to left (this is the canonical
		* direction for the upper edge of each region).
		*
		* The strategy is to evaluate a "t" value for each edge at the
		* current sweep line position, given by tess->event.  The calculations
		* are designed to be very stable, but of course they are not perfect.
		*
		* Special case: if both edge destinations are at the sweep event,
		* we sort the edges by slope (they would otherwise compare equally).
		*/--]]
		local ev = tess.event;
		local t1, t2;

		local e1 = reg1.eUp;
		local e2 = reg2.eUp;

		if( e1:Dst() == ev ) then
			if( e2:Dst() == ev ) then
				--/* Two edges right of the sweep line which meet at the sweep event.
				--* Sort them by slope.
				--*/
				if( Geom.vertLeq( e1.Org, e2.Org )) then
					return Geom.edgeSign( e2:Dst(), e1.Org, e2.Org ) <= 0;
				end
				return Geom.edgeSign( e1:Dst(), e2.Org, e1.Org ) >= 0;
			end
			return Geom.edgeSign( e2:Dst(), ev, e2.Org ) <= 0;
		end
		if( e2:Dst() == ev ) then
			return Geom.edgeSign( e1:Dst(), ev, e1.Org ) >= 0;
		end

		--/* General case - compute signed distance *from* e1, e2 to event */
		local t1 = Geom.edgeEval( e1:Dst(), ev, e1.Org );
		local t2 = Geom.edgeEval( e2:Dst(), ev, e2.Org );
		return (t1 >= t2);
	end


	--//static void DeleteRegion( TESStesselator *tess, ActiveRegion *reg )
	Sweep.deleteRegion = function( tess, reg ) 
		if( reg.fixUpperEdge ) then
			--/* It was created with zero winding number, so it better be
			--* deleted with zero winding number (ie. it better not get merged
			--* with a real edge).
			--*/
			assert( reg.eUp.winding == 0 );
		end
		reg.eUp.activeRegion = nil;
		tess.dict.delete( reg.nodeUp );
	end

	--//static int FixUpperEdge( TESStesselator *tess, ActiveRegion *reg, TESShalfEdge *newEdge )
	Sweep.fixUpperEdge = function( tess, reg, newEdge ) 
		--/*
		--* Replace an upper edge which needs fixing (see ConnectRightVertex).
		--*/
		assert( reg.fixUpperEdge );
		tess.mesh:delete( reg.eUp );
		reg.fixUpperEdge = false;
		reg.eUp = newEdge;
		newEdge.activeRegion = reg;
	end

	--static ActiveRegion *TopLeftRegion( TESStesselator *tess, ActiveRegion *reg )
	Sweep.topLeftRegion = function( tess, reg ) 
		local org = reg.eUp.Org;
		local e;

		--/* Find the region above the uppermost edge with the same origin */
		repeat
			reg = Sweep.regionAbove( reg );
		until not( reg.eUp.Org == org );

		--/* If the edge above was a temporary edge introduced by ConnectRightVertex,
		--* now is the time to fix it.
		--*/
		if( reg.fixUpperEdge ) then
			e = tess.mesh:connect( Sweep.regionBelow(reg).eUp.Sym, reg.eUp.Lnext );
			if (e == nil) then return nil end
			Sweep.fixUpperEdge( tess, reg, e );
			reg = Sweep.regionAbove( reg );
		end
		return reg;
	end

	--//static ActiveRegion *TopRightRegion( ActiveRegion *reg )
	Sweep.topRightRegion = function( reg )
		local dst = reg.eUp:Dst();
		--/* Find the region above the uppermost edge with the same destination */
		repeat
			reg = Sweep.regionAbove( reg );
		until not( reg.eUp:Dst() == dst );
		return reg;
	end

	--//static ActiveRegion *AddRegionBelow( TESStesselator *tess, ActiveRegion *regAbove, TESShalfEdge *eNewUp )
	Sweep.addRegionBelow = function( tess, regAbove, eNewUp ) 
		--/*
		-- * Add a new active region to the sweep line, *somewhere* below "regAbove"
		-- * (according to where the new edge belongs in the sweep-line dictionary).
		-- * The upper edge of the new region will be "eNewUp".
		-- * Winding number and "inside" flag are not updated.
		-- */
		local regNew = ActiveRegion();
		regNew.eUp = eNewUp;
		regNew.nodeUp = tess.dict:insertBefore( regAbove.nodeUp, regNew );
	--//	if (regNew->nodeUp == NULL) longjmp(tess->env,1);
		regNew.fixUpperEdge = false;
		regNew.sentinel = false;
		regNew.dirty = false;

		eNewUp.activeRegion = regNew;
		return regNew;
	end

	--//static int IsWindingInside( TESStesselator *tess, int n )
	Sweep.isWindingInside = function( tess, n ) 
		--switch( tess.windingRule ) {
			if tess.windingRule == Tess2.WINDING_ODD then
				return bit.band(n , 1) ~= 0;
			elseif tess.windingRule == Tess2.WINDING_NONZERO then
				return (n ~= 0);
			elseif tess.windingRule ==  Tess2.WINDING_POSITIVE then
				return (n > 0);
			elseif tess.windingRule ==  Tess2.WINDING_NEGATIVE then
				return (n < 0);
			elseif tess.windingRule ==  Tess2.WINDING_ABS_GEQ_TWO then
				return (n >= 2) or (n <= -2);
			end
		--}
		assert( false );
		return false;
	end

	--//static void ComputeWinding( TESStesselator *tess, ActiveRegion *reg )
	Sweep.computeWinding = function( tess, reg ) 
		reg.windingNumber = Sweep.regionAbove(reg).windingNumber + reg.eUp.winding;
		reg.inside = Sweep.isWindingInside( tess, reg.windingNumber );
	end


	--//static void FinishRegion( TESStesselator *tess, ActiveRegion *reg )
	Sweep.finishRegion = function( tess, reg ) 
		--/*
		-- * Delete a region from the sweep line.  This happens when the upper
		-- * and lower chains of a region meet (at a vertex on the sweep line).
		-- * The "inside" flag is copied to the appropriate mesh face (we could
		-- * not do this before -- since the structure of the mesh is always
		-- * changing, this face may not have even existed until now).
		-- */
		local e = reg.eUp;
		local f = e.Lface;

		f.inside = reg.inside;
		f.anEdge = e;   --/* optimization for tessMeshTessellateMonoRegion() */
		Sweep.deleteRegion( tess, reg );
	end


	--//static TESShalfEdge *FinishLeftRegions( TESStesselator *tess, ActiveRegion *regFirst, ActiveRegion *regLast )
	Sweep.finishLeftRegions = function( tess, regFirst, regLast ) 
		--/*
		-- * We are given a vertex with one or more left-going edges.  All affected
		-- * edges should be in the edge dictionary.  Starting at regFirst->eUp,
		-- * we walk down deleting all regions where both edges have the same
		-- * origin vOrg.  At the same time we copy the "inside" flag from the
		-- * active region to the face, since at this point each face will belong
		-- * to at most one region (this was not necessarily true until this point
		-- * in the sweep).  The walk stops at the region above regLast; if regLast
		-- * is NULL we walk as far as possible.  At the same time we relink the
		-- * mesh if necessary, so that the ordering of edges around vOrg is the
		-- * same as in the dictionary.
		--*/
		local e, ePrev;
		local reg = nil;
		local regPrev = regFirst;
		local ePrev = regFirst.eUp;
		while( regPrev ~= regLast ) do
			regPrev.fixUpperEdge = false;	--/* placement was OK */
			reg = Sweep.regionBelow( regPrev );
			e = reg.eUp;
			if( e.Org ~= ePrev.Org ) then
				if( not reg.fixUpperEdge ) then
					--/* Remove the last left-going edge.  Even though there are no further
					-- * edges in the dictionary with this origin, there may be further
					-- * such edges in the mesh (if we are adding left edges to a vertex
					-- * that has already been processed).  Thus it is important to call
					-- * FinishRegion rather than just DeleteRegion.
					-- */
					Sweep.finishRegion( tess, regPrev );
					break;
				end
				--/* If the edge below was a temporary edge introduced by
				--* ConnectRightVertex, now is the time to fix it.
				--*/
				e = tess.mesh:connect( ePrev:Lprev(), e.Sym );
	--//			if (e == NULL) longjmp(tess->env,1);
				Sweep.fixUpperEdge( tess, reg, e );
			end

			--/* Relink edges so that ePrev->Onext == e */
			if( ePrev.Onext ~= e ) then
				tess.mesh:splice( e:Oprev(), e );
				tess.mesh:splice( ePrev, e );
			end
			Sweep.finishRegion( tess, regPrev );	--/* may change reg->eUp */
			ePrev = reg.eUp;
			regPrev = reg;
		end
		return ePrev;
	end


	--//static void AddRightEdges( TESStesselator *tess, ActiveRegion *regUp, TESShalfEdge *eFirst, TESShalfEdge *eLast, TESShalfEdge *eTopLeft, int cleanUp )
	Sweep.addRightEdges = function( tess, regUp, eFirst, eLast, eTopLeft, cleanUp ) 
		--/*
		-- * Purpose: insert right-going edges into the edge dictionary, and update
		-- * winding numbers and mesh connectivity appropriately.  All right-going
		-- * edges share a common origin vOrg.  Edges are inserted CCW starting at
		-- * eFirst; the last edge inserted is eLast->Oprev.  If vOrg has any
		-- * left-going edges already processed, then eTopLeft must be the edge
		-- * such that an imaginary upward vertical segment from vOrg would be
		-- * contained between eTopLeft->Oprev and eTopLeft; otherwise eTopLeft
		-- * should be NULL.
		-- */
		local reg, regPrev;
		local e, ePrev;
		local firstTime = true;

		--/* Insert the new right-going edges in the dictionary */
		e = eFirst;
		repeat
			assert( Geom.vertLeq( e.Org, e:Dst() ));
			Sweep.addRegionBelow( tess, regUp, e.Sym );
			e = e.Onext;
		until not ( e ~= eLast );

		--/* Walk *all* right-going edges from e->Org, in the dictionary order,
		-- * updating the winding numbers of each region, and re-linking the mesh
		-- * edges to match the dictionary ordering (if necessary).
		-- */
		if( eTopLeft == nil ) then
			eTopLeft = Sweep.regionBelow( regUp ).eUp:Rprev();
		end
		regPrev = regUp;
		ePrev = eTopLeft;
		while true do
			reg = Sweep.regionBelow( regPrev );
			e = reg.eUp.Sym;
			if( e.Org ~= ePrev.Org ) then break end

			if( e.Onext ~= ePrev ) then
				--/* Unlink e from its current position, and relink below ePrev */
				tess.mesh:splice( e:Oprev(), e );
				tess.mesh:splice( ePrev:Oprev(), e );
			end
			--/* Compute the winding number and "inside" flag for the new regions */
			reg.windingNumber = regPrev.windingNumber - e.winding;
			reg.inside = Sweep.isWindingInside( tess, reg.windingNumber );

			--/* Check for two outgoing edges with same slope -- process these
			--* before any intersection tests (see example in tessComputeInterior).
			--*/
			regPrev.dirty = true;
			if( not firstTime and Sweep.checkForRightSplice( tess, regPrev )) then
				Sweep.addWinding( e, ePrev );
				Sweep.deleteRegion( tess, regPrev );
				tess.mesh:delete( ePrev );
			end
			firstTime = false;
			regPrev = reg;
			ePrev = e;
		end
		regPrev.dirty = true;
		assert( regPrev.windingNumber - e.winding == reg.windingNumber );

		if( cleanUp ) then
			--/* Check for intersections between newly adjacent edges. */
			Sweep.walkDirtyRegions( tess, regPrev );
		end
	end


	--//static void SpliceMergeVertices( TESStesselator *tess, TESShalfEdge *e1, TESShalfEdge *e2 )
	Sweep.spliceMergeVertices = function( tess, e1, e2 ) 
		--/*
		-- * Two vertices with idential coordinates are combined into one.
		-- * e1->Org is kept, while e2->Org is discarded.
		-- */
		tess.mesh:splice( e1, e2 ); 
	end

	--//static void VertexWeights( TESSvertex *isect, TESSvertex *org, TESSvertex *dst, TESSreal *weights )
	Sweep.vertexWeights = function( isect, org, dst ) 
		--/*
		-- * Find some weights which describe how the intersection vertex is
		-- * a linear combination of "org" and "dest".  Each of the two edges
		-- * which generated "isect" is allocated 50% of the weight; each edge
		-- * splits the weight between its org and dst according to the
		-- * relative distance to "isect".
		-- */
		local t1 = Geom.vertL1dist( org, isect );
		local t2 = Geom.vertL1dist( dst, isect );
		local w0 = 0.5 * t2 / (t1 + t2);
		local w1 = 0.5 * t1 / (t1 + t2);
		isect.coords[0] = isect.coords[0] + w0*org.coords[0] + w1*dst.coords[0];
		isect.coords[1] = isect.coords[1] + w0*org.coords[1] + w1*dst.coords[1];
		isect.coords[2] = isect.coords[2] + w0*org.coords[2] + w1*dst.coords[2];
	end


	--//static void GetIntersectData( TESStesselator *tess, TESSvertex *isect, TESSvertex *orgUp, TESSvertex *dstUp, TESSvertex *orgLo, TESSvertex *dstLo )
	Sweep.getIntersectData = function( tess, isect, orgUp, dstUp, orgLo, dstLo ) 
		 --/*
		 -- * We've computed a new intersection point, now we need a "data" pointer
		 -- * from the user so that we can refer to this new vertex in the
		 -- * rendering callbacks.
		 -- */
		isect.coords[0] , isect.coords[1] , isect.coords[2] = 0,0,0;
		isect.idx = -1;
		Sweep.vertexWeights( isect, orgUp, dstUp );
		Sweep.vertexWeights( isect, orgLo, dstLo );
	end

	--//static int CheckForRightSplice( TESStesselator *tess, ActiveRegion *regUp )
	Sweep.checkForRightSplice = function( tess, regUp ) 
		--/*
		-- * Check the upper and lower edge of "regUp", to make sure that the
		-- * eUp->Org is above eLo, or eLo->Org is below eUp (depending on which
		-- * origin is leftmost).
		-- *
		-- * The main purpose is to splice right-going edges with the same
		-- * dest vertex and nearly identical slopes (ie. we can't distinguish
		-- * the slopes numerically).  However the splicing can also help us
		-- * to recover from numerical errors.  For example, suppose at one
		-- * point we checked eUp and eLo, and decided that eUp->Org is barely
		-- * above eLo.  Then later, we split eLo into two edges (eg. from
		-- * a splice operation like this one).  This can change the result of
		-- * our test so that now eUp->Org is incident to eLo, or barely below it.
		-- * We must correct this condition to maintain the dictionary invariants.
		-- *
		-- * One possibility is to check these edges for intersection again
		-- * (ie. CheckForIntersect).  This is what we do if possible.  However
		-- * CheckForIntersect requires that tess->event lies between eUp and eLo,
		-- * so that it has something to fall back on when the intersection
		-- * calculation gives us an unusable answer.  So, for those cases where
		-- * we can't check for intersection, this routine fixes the problem
		-- * by just splicing the offending vertex into the other edge.
		-- * This is a guaranteed solution, no matter how degenerate things get.
		-- * Basically this is a combinatorial solution to a numerical problem.
		-- */
		local regLo = Sweep.regionBelow(regUp);
		local eUp = regUp.eUp;
		local eLo = regLo.eUp;

		if( Geom.vertLeq( eUp.Org, eLo.Org )) then
			if( Geom.edgeSign( eLo:Dst(), eUp.Org, eLo.Org ) > 0 ) then return false end

			--/* eUp->Org appears to be below eLo */
			if( not Geom.vertEq( eUp.Org, eLo.Org )) then
				--/* Splice eUp->Org into eLo */
				tess.mesh:splitEdge( eLo.Sym );
				tess.mesh:splice( eUp, eLo:Oprev() );
				regLo.dirty = true;
				regUp.dirty = true

			elseif( eUp.Org ~= eLo.Org ) then
				--/* merge the two vertices, discarding eUp->Org */
				tess.pq:delete( eUp.Org.pqHandle );
				Sweep.spliceMergeVertices( tess, eLo:Oprev(), eUp );
			end
		else 
			if( Geom.edgeSign( eUp:Dst(), eLo.Org, eUp.Org ) < 0 ) then return false end

			--/* eLo->Org appears to be above eUp, so splice eLo->Org into eUp */
			regUp.dirty = true;
			Sweep.regionAbove(regUp).dirty = true
			tess.mesh:splitEdge( eUp.Sym );
			tess.mesh:splice( eLo:Oprev(), eUp );
		end
		return true;
	end

	--//static int CheckForLeftSplice( TESStesselator *tess, ActiveRegion *regUp )
	Sweep.checkForLeftSplice = function( tess, regUp ) 
		--/*
		-- * Check the upper and lower edge of "regUp", to make sure that the
		-- * eUp->Dst is above eLo, or eLo->Dst is below eUp (depending on which
		-- * destination is rightmost).
		-- *
		-- * Theoretically, this should always be true.  However, splitting an edge
		-- * into two pieces can change the results of previous tests.  For example,
		-- * suppose at one point we checked eUp and eLo, and decided that eUp->Dst
		-- * is barely above eLo.  Then later, we split eLo into two edges (eg. from
		-- * a splice operation like this one).  This can change the result of
		-- * the test so that now eUp->Dst is incident to eLo, or barely below it.
		-- * We must correct this condition to maintain the dictionary invariants
		-- * (otherwise new edges might get inserted in the wrong place in the
		-- * dictionary, and bad stuff will happen).
		-- *
		-- * We fix the problem by just splicing the offending vertex into the
		-- * other edge.
		-- */
		local regLo = Sweep.regionBelow(regUp);
		local eUp = regUp.eUp;
		local eLo = regLo.eUp;
		local e;

		assert( not Geom.vertEq( eUp:Dst(), eLo:Dst() ));

		if( Geom.vertLeq( eUp:Dst(), eLo:Dst() )) then
			if( Geom.edgeSign( eUp:Dst(), eLo:Dst(), eUp.Org ) < 0 ) then return false end

			--/* eLo->Dst is above eUp, so splice eLo->Dst into eUp */
			regUp.dirty = true;
			Sweep.regionAbove(regUp).dirty = true
			e = tess.mesh:splitEdge( eUp );
			tess.mesh:splice( eLo.Sym, e );
			e.Lface.inside = regUp.inside;
		else 
			if( Geom.edgeSign( eLo:Dst(), eUp:Dst(), eLo.Org ) > 0 ) then return false end

			--/* eUp->Dst is below eLo, so splice eUp->Dst into eLo */
			regLo.dirty = true;
			regUp.dirty = true
			e = tess.mesh:splitEdge( eLo );
			tess.mesh:splice( eUp.Lnext, eLo.Sym );
			e:Rface().inside = regUp.inside;
		end
		return true;
	end


	--//static int CheckForIntersect( TESStesselator *tess, ActiveRegion *regUp )
	Sweep.checkForIntersect = function( tess, regUp ) 
		--/*
		-- * Check the upper and lower edges of the given region to see if
		-- * they intersect.  If so, create the intersection and add it
		-- * to the data structures.
		-- *
		-- * Returns TRUE if adding the new intersection resulted in a recursive
		-- * call to AddRightEdges(); in this case all "dirty" regions have been
		-- * checked for intersections, and possibly regUp has been deleted.
		-- */
		local regLo = Sweep.regionBelow(regUp);
		local eUp = regUp.eUp;
		local eLo = regLo.eUp;
		local orgUp = eUp.Org;
		local orgLo = eLo.Org;
		local dstUp = eUp:Dst();
		local dstLo = eLo:Dst();
		local tMinUp, tMaxLo;
		local isect = TESSvertex() --CHECK was TESSvertex
		local orgMin;
		local e;

		assert( not Geom.vertEq( dstLo, dstUp ));
		assert( Geom.edgeSign( dstUp, tess.event, orgUp ) <= 0 );
		assert( Geom.edgeSign( dstLo, tess.event, orgLo ) >= 0 );
		assert( orgUp ~= tess.event and orgLo ~= tess.event );
		assert( not regUp.fixUpperEdge and not regLo.fixUpperEdge );

		if( orgUp == orgLo ) then return false end	--/* right endpoints are the same */

		tMinUp = math.min( orgUp.t, dstUp.t );
		tMaxLo = math.max( orgLo.t, dstLo.t );
		if( tMinUp > tMaxLo ) then return false end	--/* t ranges do not overlap */

		if( Geom.vertLeq( orgUp, orgLo )) then
			if( Geom.edgeSign( dstLo, orgUp, orgLo ) > 0 ) then return false end
		else 
			if( Geom.edgeSign( dstUp, orgLo, orgUp ) < 0 ) then return false end
		end

		--/* At this point the edges intersect, at least marginally */
		Sweep.debugEvent( tess );

		Geom.intersect( dstUp, orgUp, dstLo, orgLo, isect );
		--/* The following properties are guaranteed: */
		assert( math.min( orgUp.t, dstUp.t ) <= isect.t );
		assert( isect.t <= math.max( orgLo.t, dstLo.t ));
		assert( math.min( dstLo.s, dstUp.s ) <= isect.s );
		assert( isect.s <= math.max( orgLo.s, orgUp.s ));

		if( Geom.vertLeq( isect, tess.event )) then
			--/* The intersection point lies slightly to the left of the sweep line,
			-- * so move it until it''s slightly to the right of the sweep line.
			-- * (If we had perfect numerical precision, this would never happen
			-- * in the first place).  The easiest and safest thing to do is
			-- * replace the intersection by tess->event.
			-- */
			isect.s = tess.event.s;
			isect.t = tess.event.t;
		end
		--/* Similarly, if the computed intersection lies to the right of the
		-- * rightmost origin (which should rarely happen), it can cause
		-- * unbelievable inefficiency on sufficiently degenerate inputs.
		-- * (If you have the test program, try running test54.d with the
		-- * "X zoom" option turned on).
		-- */
		orgMin = Geom.vertLeq( orgUp, orgLo ) and orgUp or orgLo;
		if( Geom.vertLeq( orgMin, isect )) then
			isect.s = orgMin.s;
			isect.t = orgMin.t;
		end

		if( Geom.vertEq( isect, orgUp ) or Geom.vertEq( isect, orgLo )) then
			--/* Easy case -- intersection at one of the right endpoints */
			Sweep.checkForRightSplice( tess, regUp );
			return false;
		end

		if(    (not Geom.vertEq( dstUp, tess.event )
			and Geom.edgeSign( dstUp, tess.event, isect ) >= 0)
			or (not Geom.vertEq( dstLo, tess.event )
			and Geom.edgeSign( dstLo, tess.event, isect ) <= 0 ))
		then
			--/* Very unusual -- the new upper or lower edge would pass on the
			-- * wrong side of the sweep event, or through it.  This can happen
			-- * due to very small numerical errors in the intersection calculation.
			-- */
			if( dstLo == tess.event ) then
				--/* Splice dstLo into eUp, and process the new region(s) */
				tess.mesh:splitEdge( eUp.Sym );
				tess.mesh:splice( eLo.Sym, eUp );
				regUp = Sweep.topLeftRegion( tess, regUp );
	--//			if (regUp == NULL) longjmp(tess->env,1);
				eUp = Sweep.regionBelow(regUp).eUp;
				Sweep.finishLeftRegions( tess, Sweep.regionBelow(regUp), regLo );
				Sweep.addRightEdges( tess, regUp, eUp:Oprev(), eUp, eUp, true );
				return true;
			end
			if( dstUp == tess.event ) then
				--/* Splice dstUp into eLo, and process the new region(s) */
				tess.mesh:splitEdge( eLo.Sym );
				tess.mesh:splice( eUp.Lnext, eLo:Oprev() ); 
				regLo = regUp;
				regUp = Sweep.topRightRegion( regUp );
				e = Sweep.regionBelow(regUp).eUp:Rprev();
				regLo.eUp = eLo:Oprev();
				eLo = Sweep.finishLeftRegions( tess, regLo, nil );
				Sweep.addRightEdges( tess, regUp, eLo.Onext, eUp:Rprev(), e, true );
				return true;
			end
			--/* Special case: called from ConnectRightVertex.  If either
			-- * edge passes on the wrong side of tess->event, split it
			-- * (and wait for ConnectRightVertex to splice it appropriately).
			-- */
			if( Geom.edgeSign( dstUp, tess.event, isect ) >= 0 ) then
				regUp.dirty = true;
				Sweep.regionAbove(regUp).dirty = true
				tess.mesh:splitEdge( eUp.Sym );
				eUp.Org.s = tess.event.s;
				eUp.Org.t = tess.event.t;
			end
			if( Geom.edgeSign( dstLo, tess.event, isect ) <= 0 ) then
				regLo.dirty = true;
				regUp.dirty =  true
				tess.mesh:splitEdge( eLo.Sym );
				eLo.Org.s = tess.event.s;
				eLo.Org.t = tess.event.t;
			end
			--/* leave the rest for ConnectRightVertex */
			return false;
		end

		--/* General case -- split both edges, splice into new vertex.
		-- * When we do the splice operation, the order of the arguments is
		-- * arbitrary as far as correctness goes.  However, when the operation
		-- * creates a new face, the work done is proportional to the size of
		-- * the new face.  We expect the faces in the processed part of
		-- * the mesh (ie. eUp->Lface) to be smaller than the faces in the
		-- * unprocessed original contours (which will be eLo->Oprev->Lface).
		-- */
		tess.mesh:splitEdge( eUp.Sym );
		tess.mesh:splitEdge( eLo.Sym );
		tess.mesh:splice( eLo:Oprev(), eUp );
		eUp.Org.s = isect.s;
		eUp.Org.t = isect.t;
		eUp.Org.pqHandle = tess.pq:insert( eUp.Org );
		Sweep.getIntersectData( tess, eUp.Org, orgUp, dstUp, orgLo, dstLo );
		Sweep.regionAbove(regUp).dirty ,regUp.dirty ,regLo.dirty = true,true,true;
		return false;
	end

	--//static void WalkDirtyRegions( TESStesselator *tess, ActiveRegion *regUp )
	Sweep.walkDirtyRegions = function( tess, regUp ) 
		--/*
		-- * When the upper or lower edge of any region changes, the region is
		-- * marked "dirty".  This routine walks through all the dirty regions
		-- * and makes sure that the dictionary invariants are satisfied
		-- * (see the comments at the beginning of this file).  Of course
		-- * new dirty regions can be created as we make changes to restore
		-- * the invariants.
		-- */
		local regLo = Sweep.regionBelow(regUp);
		local eUp, eLo;

		while true do
			--/* Find the lowest dirty region (we walk from the bottom up). */
			while( regLo.dirty ) do
				regUp = regLo;
				regLo = Sweep.regionBelow(regLo);
			end
			if( not regUp.dirty ) then
				regLo = regUp;
				regUp = Sweep.regionAbove( regUp );
				if( regUp == nil or not regUp.dirty ) then
					--/* We've walked all the dirty regions */
					return;
				end
			end
			regUp.dirty = false;
			eUp = regUp.eUp;
			eLo = regLo.eUp;

			if( eUp:Dst() ~= eLo:Dst() ) then
				--/* Check that the edge ordering is obeyed at the Dst vertices. */
				if( Sweep.checkForLeftSplice( tess, regUp )) then

					--/* If the upper or lower edge was marked fixUpperEdge, then
					-- * we no longer need it (since these edges are needed only for
					-- * vertices which otherwise have no right-going edges).
					-- */
					if( regLo.fixUpperEdge ) then
						Sweep.deleteRegion( tess, regLo );
						tess.mesh:delete( eLo );
						regLo = Sweep.regionBelow( regUp );
						eLo = regLo.eUp;
					elseif( regUp.fixUpperEdge ) then
						Sweep.deleteRegion( tess, regUp );
						tess.mesh:delete( eUp );
						regUp = Sweep.regionAbove( regLo );
						eUp = regUp.eUp;
					end
				end
			end
			if( eUp.Org ~= eLo.Org ) then
				if(    eUp:Dst() ~= eLo:Dst()
					and not regUp.fixUpperEdge and not regLo.fixUpperEdge
					and (eUp:Dst() == tess.event or eLo:Dst() == tess.event) )
				then
					--/* When all else fails in CheckForIntersect(), it uses tess->event
					-- * as the intersection location.  To make this possible, it requires
					-- * that tess->event lie between the upper and lower edges, and also
					-- * that neither of these is marked fixUpperEdge (since in the worst
					-- * case it might splice one of these edges into tess->event, and
					-- * violate the invariant that fixable edges are the only right-going
					-- * edge from their associated vertex).
					-- */
					if( Sweep.checkForIntersect( tess, regUp )) then
						--/* WalkDirtyRegions() was called recursively; we're done */
						return;
					end
				else 
					--/* Even though we can't use CheckForIntersect(), the Org vertices
					-- * may violate the dictionary edge ordering.  Check and correct this.
					-- */
					Sweep.checkForRightSplice( tess, regUp );
				end
			end
			if( eUp.Org == eLo.Org and eUp:Dst() == eLo:Dst() ) then
				--/* A degenerate loop consisting of only two edges -- delete it. */
				Sweep.addWinding( eLo, eUp );
				Sweep.deleteRegion( tess, regUp );
				tess.mesh:delete( eUp );
				regUp = Sweep.regionAbove( regLo );
			end
		end
	end


	--//static void ConnectRightVertex( TESStesselator *tess, ActiveRegion *regUp, TESShalfEdge *eBottomLeft )
	Sweep.connectRightVertex = function( tess, regUp, eBottomLeft ) 
		--/*
		-- * Purpose: connect a "right" vertex vEvent (one where all edges go left)
		-- * to the unprocessed portion of the mesh.  Since there are no right-going
		-- * edges, two regions (one above vEvent and one below) are being merged
		-- * into one.  "regUp" is the upper of these two regions.
		-- *
		-- * There are two reasons for doing this (adding a right-going edge):
		-- *  - if the two regions being merged are "inside", we must add an edge
		-- *    to keep them separated (the combined region would not be monotone).
		-- *  - in any case, we must leave some record of vEvent in the dictionary,
		-- *    so that we can merge vEvent with features that we have not seen yet.
		-- *    For example, maybe there is a vertical edge which passes just to
		-- *    the right of vEvent; we would like to splice vEvent into this edge.
		-- *
		-- * However, we don't want to connect vEvent to just any vertex.  We don''t
		-- * want the new edge to cross any other edges; otherwise we will create
		-- * intersection vertices even when the input data had no self-intersections.
		-- * (This is a bad thing; if the user's input data has no intersections,
		-- * we don't want to generate any false intersections ourselves.)
		-- *
		-- * Our eventual goal is to connect vEvent to the leftmost unprocessed
		-- * vertex of the combined region (the union of regUp and regLo).
		-- * But because of unseen vertices with all right-going edges, and also
		-- * new vertices which may be created by edge intersections, we don''t
		-- * know where that leftmost unprocessed vertex is.  In the meantime, we
		-- * connect vEvent to the closest vertex of either chain, and mark the region
		-- * as "fixUpperEdge".  This flag says to delete and reconnect this edge
		-- * to the next processed vertex on the boundary of the combined region.
		-- * Quite possibly the vertex we connected to will turn out to be the
		-- * closest one, in which case we won''t need to make any changes.
		-- */
		local eNew;
		local eTopLeft = eBottomLeft.Onext;
		local regLo = Sweep.regionBelow(regUp);
		local eUp = regUp.eUp;
		local eLo = regLo.eUp;
		local degenerate = false;

		if( eUp:Dst() ~= eLo:Dst() ) then
			Sweep.checkForIntersect( tess, regUp );
		end

		--/* Possible new degeneracies: upper or lower edge of regUp may pass
		-- * through vEvent, or may coincide with new intersection vertex
		-- */
		if( Geom.vertEq( eUp.Org, tess.event )) then
			tess.mesh:splice( eTopLeft:Oprev(), eUp );
			regUp = Sweep.topLeftRegion( tess, regUp );
			eTopLeft = Sweep.regionBelow( regUp ).eUp;
			Sweep.finishLeftRegions( tess, Sweep.regionBelow(regUp), regLo );
			degenerate = true;
		end
		if( Geom.vertEq( eLo.Org, tess.event )) then
			tess.mesh:splice( eBottomLeft, eLo:Oprev() );
			eBottomLeft = Sweep.finishLeftRegions( tess, regLo, nil );
			degenerate = true;
		end
		if( degenerate ) then
			Sweep.addRightEdges( tess, regUp, eBottomLeft.Onext, eTopLeft, eTopLeft, true );
			return;
		end

		--/* Non-degenerate situation -- need to add a temporary, fixable edge.
		-- * Connect to the closer of eLo->Org, eUp->Org.
		-- */
		if( Geom.vertLeq( eLo.Org, eUp.Org )) then
			eNew = eLo:Oprev();
		else 
			eNew = eUp;
		end
		eNew = tess.mesh:connect( eBottomLeft:Lprev(), eNew );

		--/* Prevent cleanup, otherwise eNew might disappear before we've even
		-- * had a chance to mark it as a temporary edge.
		-- */
		Sweep.addRightEdges( tess, regUp, eNew, eNew.Onext, eNew.Onext, false );
		eNew.Sym.activeRegion.fixUpperEdge = true;
		Sweep.walkDirtyRegions( tess, regUp );
	end

	--/* Because vertices at exactly the same location are merged together
	-- * before we process the sweep event, some degenerate cases can't occur.
	-- * However if someone eventually makes the modifications required to
	-- * merge features which are close together, the cases below marked
	-- * TOLERANCE_NONZERO will be useful.  They were debugged before the
	-- * code to merge identical vertices in the main loop was added.
	-- */
	-- //#define TOLERANCE_NONZERO	FALSE

	-- //static void ConnectLeftDegenerate( TESStesselator *tess, ActiveRegion *regUp, TESSvertex *vEvent )
	Sweep.connectLeftDegenerate = function( tess, regUp, vEvent ) 
		--/*
		-- * The event vertex lies exacty on an already-processed edge or vertex.
		-- * Adding the new vertex involves splicing it into the already-processed
		-- * part of the mesh.
		-- */
		local e, eTopLeft, eTopRight, eLast;
		local reg;

		e = regUp.eUp;
		if( Geom.vertEq( e.Org, vEvent )) then
			--/* e->Org is an unprocessed vertex - just combine them, and wait
			-- * for e->Org to be pulled from the queue
			-- */
			assert( false )--/*TOLERANCE_NONZERO*/ );
			Sweep.spliceMergeVertices( tess, e, vEvent.anEdge );
			return;
		end

		if( not Geom.vertEq( e:Dst(), vEvent )) then
			--/* General case -- splice vEvent into edge e which passes through it */
			tess.mesh:splitEdge( e.Sym );
			if( regUp.fixUpperEdge ) then
				--/* This edge was fixable -- delete unused portion of original edge */
				tess.mesh:delete( e.Onext );
				regUp.fixUpperEdge = false;
			end
			tess.mesh:splice( vEvent.anEdge, e );
			Sweep.sweepEvent( tess, vEvent );	--/* recurse */
			return;
		end

		--/* vEvent coincides with e->Dst, which has already been processed.
		-- * Splice in the additional right-going edges.
		-- */
		assert( false) --/*TOLERANCE_NONZERO*/ );
		regUp = Sweep.topRightRegion( regUp );
		reg = Sweep.regionBelow( regUp );
		eTopRight = reg.eUp.Sym;
		eLast = eTopRight.Onext;
		eTopLeft = eLast
		if( reg.fixUpperEdge ) then
			--/* Here e->Dst has only a single fixable edge going right.
			-- * We can delete it since now we have some real right-going edges.
			-- */
			assert( eTopLeft ~= eTopRight );   --/* there are some left edges too */
			Sweep.deleteRegion( tess, reg );
			tess.mesh:delete( eTopRight );
			eTopRight = eTopLeft:Oprev();
		end
		tess.mesh:splice( vEvent.anEdge, eTopRight );
		if( not Geom.edgeGoesLeft( eTopLeft )) then
			--/* e->Dst had no left-going edges -- indicate this to AddRightEdges() */
			eTopLeft = nil;
		end
		Sweep.addRightEdges( tess, regUp, eTopRight.Onext, eLast, eTopLeft, true );
	end


	--//static void ConnectLeftVertex( TESStesselator *tess, TESSvertex *vEvent )
	Sweep.connectLeftVertex = function( tess, vEvent ) 
		--/*
		-- * Purpose: connect a "left" vertex (one where both edges go right)
		-- * to the processed portion of the mesh.  Let R be the active region
		-- * containing vEvent, and let U and L be the upper and lower edge
		-- * chains of R.  There are two possibilities:
		-- *
		-- * - the normal case: split R into two regions, by connecting vEvent to
		-- *   the rightmost vertex of U or L lying to the left of the sweep line
		-- *
		-- * - the degenerate case: if vEvent is close enough to U or L, we
		-- *   merge vEvent into that edge chain.  The subcases are:
		-- *	- merging with the rightmost vertex of U or L
		-- *	- merging with the active edge of U or L
		-- *	- merging with an already-processed portion of U or L
		-- */
		local regUp, regLo, reg;
		local eUp, eLo, eNew;
		local tmp = ActiveRegion();

		--/* assert( vEvent->anEdge->Onext->Onext == vEvent->anEdge ); */

		--/* Get a pointer to the active region containing vEvent */
		tmp.eUp = vEvent.anEdge.Sym;
		--/* __GL_DICTLISTKEY */ --/* tessDictListSearch */
		regUp = tess.dict:search( tmp ).key;
		regLo = Sweep.regionBelow( regUp );
		if( not regLo ) then
			--// This may happen if the input polygon is coplanar.
			return;
		end
		eUp = regUp.eUp;
		eLo = regLo.eUp;

		--/* Try merging with U or L first */
		if( Geom.edgeSign( eUp:Dst(), vEvent, eUp.Org ) == 0.0 ) then
			Sweep.connectLeftDegenerate( tess, regUp, vEvent );
			return;
		end

		--/* Connect vEvent to rightmost processed vertex of either chain.
		-- * e->Dst is the vertex that we will connect to vEvent.
		-- */
		reg = Geom.vertLeq( eLo:Dst(), eUp:Dst() ) and regUp or regLo;

		if( regUp.inside or reg.fixUpperEdge) then
			if( reg == regUp ) then
				eNew = tess.mesh:connect( vEvent.anEdge.Sym, eUp.Lnext );
			else 
				local tempHalfEdge = tess.mesh:connect( eLo:Dnext(), vEvent.anEdge);
				eNew = tempHalfEdge.Sym;
			end
			if( reg.fixUpperEdge ) then
				Sweep.fixUpperEdge( tess, reg, eNew );
			else
				Sweep.computeWinding( tess, Sweep.addRegionBelow( tess, regUp, eNew ));
			end
			Sweep.sweepEvent( tess, vEvent );
		else 
			--/* The new vertex is in a region which does not belong to the polygon.
			-- * We don''t need to connect this vertex to the rest of the mesh.
			-- */
			Sweep.addRightEdges( tess, regUp, vEvent.anEdge, vEvent.anEdge, nil, true );
		end
	end;


	--//static void SweepEvent( TESStesselator *tess, TESSvertex *vEvent )
	Sweep.sweepEvent = function( tess, vEvent ) 
		--/*
		-- * Does everything necessary when the sweep line crosses a vertex.
		-- * Updates the mesh and the edge dictionary.
		-- */

		tess.event = vEvent;		--/* for access in EdgeLeq() */
		Sweep.debugEvent( tess );

		--/* Check if this vertex is the right endpoint of an edge that is
		-- * already in the dictionary.  In this case we don't need to waste
		-- * time searching for the location to insert new edges.
		-- */
		local e = vEvent.anEdge;
		while( e.activeRegion == nil ) do
			e = e.Onext;
			if( e == vEvent.anEdge ) then
				--/* All edges go right -- not incident to any processed edges */
				Sweep.connectLeftVertex( tess, vEvent );
				return;
			end
		end

		--/* Processing consists of two phases: first we "finish" all the
		-- * active regions where both the upper and lower edges terminate
		-- * at vEvent (ie. vEvent is closing off these regions).
		-- * We mark these faces "inside" or "outside" the polygon according
		-- * to their winding number, and delete the edges from the dictionary.
		-- * This takes care of all the left-going edges from vEvent.
		-- */
		local regUp = Sweep.topLeftRegion( tess, e.activeRegion );
		assert( regUp ~= nil );
	--//	if (regUp == NULL) longjmp(tess->env,1);
		local reg = Sweep.regionBelow( regUp );
		local eTopLeft = reg.eUp;
		local eBottomLeft = Sweep.finishLeftRegions( tess, reg, nil );

		--/* Next we process all the right-going edges from vEvent.  This
		-- * involves adding the edges to the dictionary, and creating the
		-- * associated "active regions" which record information about the
		-- * regions between adjacent dictionary edges.
		-- */
		if( eBottomLeft.Onext == eTopLeft ) then
			--/* No right-going edges -- add a temporary "fixable" edge */
			Sweep.connectRightVertex( tess, regUp, eBottomLeft );
		else
			Sweep.addRightEdges( tess, regUp, eBottomLeft.Onext, eTopLeft, eTopLeft, true );
		end
	end;


	--/* Make the sentinel coordinates big enough that they will never be
	-- * merged with real input features.
	-- */

	--//static void AddSentinel( TESStesselator *tess, TESSreal smin, TESSreal smax, TESSreal t )
	Sweep.addSentinel = function( tess, smin, smax, t ) 
		--/*
		-- * We add two sentinel edges above and below all other edges,
		-- * to avoid special cases at the top and bottom.
		-- */
		local reg = ActiveRegion();
		local e = tess.mesh:makeEdge();
	--//	if (e == NULL) longjmp(tess->env,1);

		e.Org.s = smax;
		e.Org.t = t;
		e:Dst().s = smin;
		e:Dst().t = t;
		tess.event = e:Dst();		--/* initialize it */

		reg.eUp = e;
		reg.windingNumber = 0;
		reg.inside = false;
		reg.fixUpperEdge = false;
		reg.sentinel = true;
		reg.dirty = false;
		reg.nodeUp = tess.dict:insert( reg );
	--//	if (reg->nodeUp == NULL) longjmp(tess->env,1);
	end


	--//static void InitEdgeDict( TESStesselator *tess )
	Sweep.initEdgeDict = function( tess ) 
		--/*
		-- * We maintain an ordering of edge intersections with the sweep line.
		-- * This order is maintained in a dynamic dictionary.
		-- */
		tess.dict = Dict( tess, Sweep.edgeLeq );
	--//	if (tess->dict == NULL) longjmp(tess->env,1);

		local w = (tess.bmax[0] - tess.bmin[0]);
		local h = (tess.bmax[1] - tess.bmin[1]);

		local smin = tess.bmin[0] - w;
		local smax = tess.bmax[0] + w;
		local tmin = tess.bmin[1] - h;
		local tmax = tess.bmax[1] + h;

		Sweep.addSentinel( tess, smin, smax, tmin );
		Sweep.addSentinel( tess, smin, smax, tmax );
	end


	Sweep.doneEdgeDict = function( tess )
		local reg;
		local fixedEdges = 0;

		while( (tess.dict:min().key) ~= nil ) do
			reg = tess.dict:min().key
			--/*
			-- * At the end of all processing, the dictionary should contain
			-- * only the two sentinel edges, plus at most one "fixable" edge
			-- * created by ConnectRightVertex().
			-- */
			if( not reg.sentinel ) then
				assert( reg.fixUpperEdge );
				assert( fixedEdges == 0)--1 );
			end
			assert( reg.windingNumber == 0 );
			Sweep.deleteRegion( tess, reg );
			--/*    tessMeshDelete( reg->eUp );*/
		end
	--//	dictDeleteDict( &tess->alloc, tess->dict );
	end


	Sweep.removeDegenerateEdges = function( tess ) 
		--/*
		-- * Remove zero-length edges, and contours with fewer than 3 vertices.
		-- */
		local e, eNext, eLnext;
		local eHead = tess.mesh.eHead;

		--/*LINTED*/
		--for( e = eHead.next; e ~= eHead; e = eNext ) {
		e = eHead.next
		while(e ~= eHead) do
			eNext = e.next;
			eLnext = e.Lnext;

			if( Geom.vertEq( e.Org, e:Dst() ) and e.Lnext.Lnext ~= e ) then
				--/* Zero-length edge, contour has at least 3 edges */
				Sweep.spliceMergeVertices( tess, eLnext, e );	--/* deletes e->Org */
				tess.mesh:delete( e ); --/* e is a self-loop */
				e = eLnext;
				eLnext = e.Lnext;
			end
			if( eLnext.Lnext == e ) then
				--/* Degenerate contour (one or two edges) */
				if( eLnext ~= e ) then
					if( eLnext == eNext or eLnext == eNext.Sym ) then eNext = eNext.next; end
					tess.mesh:delete( eLnext );
				end
				if( e == eNext or e == eNext.Sym ) then eNext = eNext.next; end
				tess.mesh:delete( e );
			end
			e = eNext
		end
	end

	Sweep.initPriorityQ = function( tess ) 
		--/*
		-- * Insert all vertices into the priority queue which determines the
		-- * order in which vertices cross the sweep line.
		-- */
		local pq;
		local v, vHead;
		local vertexCount = 0;
		
		vHead = tess.mesh.vHead;
		--for( v = vHead.next; v ~= vHead; v = v.next ) {
		v = vHead.next
		while(v ~= vHead) do
			vertexCount = vertexCount + 1;
			v = v.next
		end
		--print("initPriorityQ vertexCount", vertexCount)
		--/* Make sure there is enough space for sentinels. */
		vertexCount = vertexCount + 8; --//MAX( 8, tess->alloc.extraVertices );
		
		tess.pq = PriorityQ( vertexCount, Geom.vertLeq );
		pq = tess.pq
		--print("after new PriorityQ")
		--prtableN(pq,4)
	--//	if (pq == NULL) return 0;

		vHead = tess.mesh.vHead;
		--for( v = vHead.next; v ~= vHead; v = v.next ) {
		v = vHead.next
		while( v ~= vHead) do
			--print"insert"
			v.pqHandle = pq:insert( v );
	--//		if (v.pqHandle == INV_HANDLE)
	--//			break;
			v = v.next
		end

		if (v ~= vHead) then
			return false;
		end
		--print("before pq.init")
		--prtableN(pq,4)
		
		pq:init();

		return true;
	end


	Sweep.donePriorityQ = function( tess ) 
		tess.pq = nil;
	end


	Sweep.removeDegenerateFaces = function( tess, mesh ) 
		--/*
		-- * Delete any degenerate faces with only two edges.  WalkDirtyRegions()
		-- * will catch almost all of these, but it won't catch degenerate faces
		-- * produced by splice operations on already-processed edges.
		-- * The two places this can happen are in FinishLeftRegions(), when
		-- * we splice in a "temporary" edge produced by ConnectRightVertex(),
		-- * and in CheckForLeftSplice(), where we splice already-processed
		-- * edges to ensure that our dictionary invariants are not violated
		-- * by numerical errors.
		-- *
		-- * In both these cases it is *very* dangerous to delete the offending
		-- * edge at the time, since one of the routines further up the stack
		-- * will sometimes be keeping a pointer to that edge.
		-- */
		local f, fNext;
		local e;

		--/*LINTED*/
		--for( f = mesh.fHead.next; f ~= mesh.fHead; f = fNext ) {
		f = mesh.fHead.next
		while(f ~= mesh.fHead) do
			fNext = f.next;
			e = f.anEdge;
			assert( e.Lnext ~= e );

			if( e.Lnext.Lnext == e ) then
				--/* A face with only two edges */
				Sweep.addWinding( e.Onext, e );
				tess.mesh:delete( e );
			end
			f = fNext
		end
		return true;
	end

	Sweep.computeInterior = function( tess ) 
		--/*
		-- * tessComputeInterior( tess ) computes the planar arrangement specified
		-- * by the given contours, and further subdivides this arrangement
		-- * into regions.  Each region is marked "inside" if it belongs
		-- * to the polygon, according to the rule given by tess->windingRule.
		-- * Each interior region is guaranteed be monotone.
		-- */
		local v, vNext;

		--/* Each vertex defines an event for our sweep line.  Start by inserting
		-- * all the vertices in a priority queue.  Events are processed in
		-- * lexicographic order, ie.
		-- *
		-- *	e1 < e2  iff  e1.x < e2.x or (e1.x == e2.x and e1.y < e2.y)
		-- */
		Sweep.removeDegenerateEdges( tess );
		if ( not Sweep.initPriorityQ( tess ) ) then return false; end --/* if error */
		-- print"after initPriorityQ"
		-- prtableN( tess.pq,4)
		Sweep.initEdgeDict( tess );

		--while( (v = tess.pq.extractMin()) ~= nil ) {
		v = tess.pq:extractMin()
		while(v ~= nil) do
			--print("1extractMin", v.s, v.t, v.n, v.pqHandle)
			--prtableN(v,1)
			while true do
				vNext = tess.pq:min();
				--print("vNext", vNext.s, vNext.t, vNext.n,vNext.pqHandle)
				--prtableN(vNext,2)--.coords)
				if( vNext == nil or not Geom.vertEq( vNext, v )) then break end

				--/* Merge together all vertices at exactly the same location.
				-- * This is more efficient than processing them one at a time,
				-- * simplifies the code (see ConnectLeftDegenerate), and is also
				-- * important for correct handling of certain degenerate cases.
				-- * For example, suppose there are two identical edges A and B
				-- * that belong to different contours (so without this code they would
				-- * be processed by separate sweep events).  Suppose another edge C
				-- * crosses A and B from above.  When A is processed, we split it
				-- * at its intersection point with C.  However this also splits C,
				-- * so when we insert B we may compute a slightly different
				-- * intersection point.  This might leave two edges with a small
				-- * gap between them.  This kind of error is especially obvious
				-- * when using boundary extraction (TESS_BOUNDARY_ONLY).
				-- */
				vNext = tess.pq:extractMin();
				Sweep.spliceMergeVertices( tess, v.anEdge, vNext.anEdge );
			end
			Sweep.sweepEvent( tess, v );
			v = tess.pq:extractMin()
		end

		--/* Set tess->event for debugging purposes */
		tess.event = tess.dict:min().key.eUp.Org;
		Sweep.debugEvent( tess );
		Sweep.doneEdgeDict( tess );
		Sweep.donePriorityQ( tess );

		if ( not Sweep.removeDegenerateFaces( tess, tess.mesh ) ) then return false end
		tess.mesh:check();

		return true;
	end

	local Tesselator_meta
	Tesselator = function() 
		local this = {}
		--/*** state needed for collecting the input data ***/
		this.mesh = nil;		--/* stores the input contours, and eventually
							--the tessellation itself */

		--/*** state needed for projecting onto the sweep plane ***/

		this.normal = vec3(0.0, 0.0, 0.0);	--/* user-specified normal (if provided) */
		this.sUnit = vec3(0.0, 0.0, 0.0);	--/* unit vector in s-direction (debugging) */
		this.tUnit = vec3(0.0, 0.0, 0.0);	--/* unit vector in t-direction (debugging) */

		this.bmin = vec2(0.0, 0.0);
		this.bmax = vec2(0.0, 0.0);

		--/*** state needed for the line sweep ***/
		this.windingRule = Tess2.WINDING_ODD;	--/* rule for determining polygon interior */

		this.dict = nil;		--/* edge dictionary for sweep line */
		this.pq = nil;		--/* priority queue of vertex events */
		this.event = nil;		--/* current sweep event being processed */

		this.vertexIndexCounter = 0;
		
		this.vertices = {};
		this.vertexIndices = {};
		this.vertexCount = 0;
		this.elements = {};
		this.elementCount = 0;
		
		return setmetatable(this, Tesselator_meta)
	end;

	Tesselator_meta = {
		__index = --function(this, k)
		--local meta2 = 
		{

		dot_= function(u, v) 
			return (u[0]*v[0] + u[1]*v[1] + u[2]*v[2]);
		end,

		normalize_= function( v ) 
			local len = v[0]*v[0] + v[1]*v[1] + v[2]*v[2];
			assert( len > 0.0 );
			len = math.sqrt( len );
			v[0] = v[0]/len;
			v[1] = v[1]/len;
			v[2] = v[2]/len;
		end,

		longAxis_= function( v ) 
			local i = 0;
			--prtable("longAxis",v)
			if( math.abs(v[1]) > math.abs(v[0]) ) then i = 1; end
			if( math.abs(v[2]) > math.abs(v[i]) ) then i = 2; end
			return i;
		end,

		computeNormal_= function( norm )

			local v, v1, v2;
			local c, tLen2, maxLen2;
			local maxVal , minVal, d1 , d2, tNorm  = vec3(0,0,0),vec3(0,0,0),vec3(0,0,0),vec3(0,0,0),vec3(0,0,0)
			local maxVert, minVert = vec3(nil,nil,nil), vec3(nil,nil,nil)
			local vHead = this.mesh.vHead;
			local i;

			v = vHead.next;
			--for( i = 0; i < 3; ++i ) {
			for i=0,2 do
				c = v.coords[i];
				minVal[i] = c;
				minVert[i] = v;
				maxVal[i] = c;
				maxVert[i] = v;
			end

			--for( v = vHead.next; v ~= vHead; v = v.next ) {
			v = vHead.next
			while(v ~= vHead) do
				--for( i = 0; i < 3; ++i ) {
				for i=0,2 do
					c = v.coords[i];
					if( c < minVal[i] ) then minVal[i] = c; minVert[i] = v; end
					if( c > maxVal[i] ) then maxVal[i] = c; maxVert[i] = v; end
				end
			end

			--/* Find two vertices separated by at least 1/sqrt(3) of the maximum
			-- * distance between any two vertices
			-- */
			i = 0;
			if( maxVal[1] - minVal[1] > maxVal[0] - minVal[0] ) then i = 1; end
			if( maxVal[2] - minVal[2] > maxVal[i] - minVal[i] ) then i = 2; end
			if( minVal[i] >= maxVal[i] ) then
				--/* All vertices are the same -- normal doesn't matter */
				norm[0] = 0; norm[1] = 0; norm[2] = 1;
				return;
			end

			--/* Look for a third vertex which forms the triangle with maximum area
			-- * (Length of normal == twice the triangle area)
			-- */
			maxLen2 = 0;
			v1 = minVert[i];
			v2 = maxVert[i];
			d1[0] = v1.coords[0] - v2.coords[0];
			d1[1] = v1.coords[1] - v2.coords[1];
			d1[2] = v1.coords[2] - v2.coords[2];
			--for( v = vHead.next; v ~= vHead; v = v.next ) {
			v = vHead.next
			while(v ~= vHead) do
				d2[0] = v.coords[0] - v2.coords[0];
				d2[1] = v.coords[1] - v2.coords[1];
				d2[2] = v.coords[2] - v2.coords[2];
				tNorm[0] = d1[1]*d2[2] - d1[2]*d2[1];
				tNorm[1] = d1[2]*d2[0] - d1[0]*d2[2];
				tNorm[2] = d1[0]*d2[1] - d1[1]*d2[0];
				tLen2 = tNorm[0]*tNorm[0] + tNorm[1]*tNorm[1] + tNorm[2]*tNorm[2];
				if( tLen2 > maxLen2 ) then
					maxLen2 = tLen2;
					norm[0] = tNorm[0];
					norm[1] = tNorm[1];
					norm[2] = tNorm[2];
				end
				v = v.next 
			end

			if( maxLen2 <= 0 ) then
				--/* All points lie on a single line -- any decent normal will do */
				norm[0] , norm[1] , norm[2] = 0,0,0;
				norm[this.longAxis_(d1)] = 1;
			end
		end,

		checkOrientation_= function() 
			local area;
			local f, fHead = this.mesh.fHead;
			local v, vHead = this.mesh.vHead;
			local e;

			--/* When we compute the normal automatically, we choose the orientation
			-- * so that the the sum of the signed areas of all contours is non-negative.
			-- */
			area = 0;
			--for( f = fHead.next; f ~= fHead; f = f.next ) {
			f = fHead.next
			while( f ~= fHead) do
				e = f.anEdge;
				if( e.winding <= 0 ) then goto continue end
				repeat
					area = area + (e.Org.s - e:Dst().s) * (e.Org.t + e:Dst().t);
					e = e.Lnext;
				until not ( e ~= f.anEdge );
				::continue::
				f = f.next
			end
			if( area < 0 ) then
				--/* Reverse the orientation by flipping all the t-coordinates */
				--for( v = vHead.next; v ~= vHead; v = v.next ) {
				v = vHead.next
				while( v ~= vHead) do
					v.t = - v.t;
					v = v.next
				end
				this.tUnit[0] = - this.tUnit[0];
				this.tUnit[1] = - this.tUnit[1];
				this.tUnit[2] = - this.tUnit[2];
			end
		end,

	--/*	#ifdef FOR_TRITE_TEST_PROGRAM
		-- #include <stdlib.h>
		-- extern int RandomSweep;
		-- #define S_UNIT_X	(RandomSweep ? (2*drand48()-1) : 1.0)
		-- #define S_UNIT_Y	(RandomSweep ? (2*drand48()-1) : 0.0)
		-- #else
		-- #if defined(SLANTED_SWEEP) */
		--/* The "feature merging" is not intended to be complete.  There are
		-- * special cases where edges are nearly parallel to the sweep line
		-- * which are not implemented.  The algorithm should still behave
		-- * robustly (ie. produce a reasonable tesselation) in the presence
		-- * of such edges, however it may miss features which could have been
		-- * merged.  We could minimize this effect by choosing the sweep line
		-- * direction to be something unusual (ie. not parallel to one of the
		-- * coordinate axes).
		-- */
	--/*	#define S_UNIT_X	(TESSreal)0.50941539564955385	// Pre-normalized
		-- #define S_UNIT_Y	(TESSreal)0.86052074622010633
		-- #else
		-- #define S_UNIT_X	(TESSreal)1.0
		-- #define S_UNIT_Y	(TESSreal)0.0
		-- #endif
		-- #endif*/

		--/* Determine the polygon normal and project vertices onto the plane
		-- * of the polygon.
		-- */
		projectPolygon_= function(this) 
			local v
			local vHead = this.mesh.vHead;
			local norm = vec3(0,0,0);
			local sUnit, tUnit;
			local i, first, computedNormal = false;

			norm[0] = this.normal[0];
			norm[1] = this.normal[1];
			norm[2] = this.normal[2];
			if( norm[0] == 0.0 and norm[1] == 0.0 and norm[2] == 0.0 ) then
				this.computeNormal_( norm );
				computedNormal = true;
			end
			sUnit = this.sUnit;
			tUnit = this.tUnit;
			i = this.longAxis_( norm );

	--/*	#if defined(FOR_TRITE_TEST_PROGRAM) or defined(TRUE_PROJECT)
			-- // Choose the initial sUnit vector to be approximately perpendicular
			-- // to the normal.
			
			-- Normalize( norm );

			-- sUnit[i] = 0;
			-- sUnit[(i+1)%3] = S_UNIT_X;
			-- sUnit[(i+2)%3] = S_UNIT_Y;

			--// Now make it exactly perpendicular 
			-- w = Dot( sUnit, norm );
			-- sUnit[0] -= w * norm[0];
			-- sUnit[1] -= w * norm[1];
			-- sUnit[2] -= w * norm[2];
			-- Normalize( sUnit );

			-- // Choose tUnit so that (sUnit,tUnit,norm) form a right-handed frame 
			-- tUnit[0] = norm[1]*sUnit[2] - norm[2]*sUnit[1];
			-- tUnit[1] = norm[2]*sUnit[0] - norm[0]*sUnit[2];
			-- tUnit[2] = norm[0]*sUnit[1] - norm[1]*sUnit[0];
			-- Normalize( tUnit );
		-- #else*/
			--/* Project perpendicular to a coordinate axis -- better numerically */
			sUnit[i] = 0;
			sUnit[(i+1)%3] = 1.0;
			sUnit[(i+2)%3] = 0.0;

			tUnit[i] = 0;
			tUnit[(i+1)%3] = 0.0;
			tUnit[(i+2)%3] = (norm[i] > 0) and 1.0 or -1.0;
	--//	#endif

			--/* Project the vertices onto the sweep plane */
			--for( v = vHead.next; v ~= vHead; v = v.next ) {
			v = vHead.next
			while( v ~= vHead) do
				v.s = this.dot_( v.coords, sUnit );
				v.t = this.dot_( v.coords, tUnit );
				v = v.next 
			end
			if( computedNormal ) then
				this.checkOrientation_();
			end

			--/* Compute ST bounds. */
			first = true;
			--for( v = vHead.next; v ~= vHead; v = v.next ) {
			v = vHead.next
			while(v ~= vHead) do
				if (first) then
					this.bmax[0] = v.s;
					this.bmin[0] = v.s
					this.bmax[1] = v.t;
					this.bmin[1] = v.t
					first = false;
				else 
					if (v.s < this.bmin[0]) then this.bmin[0] = v.s; end
					if (v.s > this.bmax[0]) then this.bmax[0] = v.s; end
					if (v.t < this.bmin[1]) then this.bmin[1] = v.t; end
					if (v.t > this.bmax[1]) then this.bmax[1] = v.t; end
				end
				 v = v.next
			end
		end,

		addWinding_= function(eDst,eSrc) 
			eDst.winding = eDst.winding + eSrc.winding;
			eDst.Sym.winding = eDst.Sym.winding +  eSrc.Sym.winding;
		end,
		
		--/* tessMeshTessellateMonoRegion( face ) tessellates a monotone region
		-- * (what else would it do??)  The region must consist of a single
		-- * loop of half-edges (see mesh.h) oriented CCW.  "Monotone" in this
		-- * case means that any vertical line intersects the interior of the
		-- * region in a single interval.  
		-- *
		-- * Tessellation consists of adding interior edges (actually pairs of
		-- * half-edges), to split the region into non-overlapping triangles.
		-- *
		-- * The basic idea is explained in Preparata and Shamos (which I don''t
		-- * have handy right now), although their implementation is more
		-- * complicated than this one.  The are two edge chains, an upper chain
		-- * and a lower chain.  We process all vertices from both chains in order,
		-- * from right to left.
		-- *
		-- * The algorithm ensures that the following invariant holds after each
		-- * vertex is processed: the untessellated region consists of two
		-- * chains, where one chain (say the upper) is a single edge, and
		-- * the other chain is concave.  The left vertex of the single edge
		-- * is always to the left of all vertices in the concave chain.
		-- *
		-- * Each step consists of adding the rightmost unprocessed vertex to one
		-- * of the two chains, and forming a fan of triangles from the rightmost
		-- * of two chain endpoints.  Determining whether we can add each triangle
		-- * to the fan is a simple orientation test.  By making the fan as large
		-- * as possible, we restore the invariant (check it yourself).
		-- */
	-- //	int tessMeshTessellateMonoRegion( TESSmesh *mesh, TESSface *face )
		tessellateMonoRegion_= function( mesh, face ) 
			local up, lo;

			--/* All edges are oriented CCW around the boundary of the region.
			-- * First, find the half-edge whose origin vertex is rightmost.
			-- * Since the sweep goes from left to right, face->anEdge should
			-- * be close to the edge we want.
			-- */
			up = face.anEdge;
			assert( up.Lnext ~= up and up.Lnext.Lnext ~= up );

			--for( ; Geom.vertLeq( up:Dst(), up.Org ); up = up:Lprev() )
				--;
			while(Geom.vertLeq( up:Dst(), up.Org )) do up = up:Lprev() end
			--for( ; Geom.vertLeq( up.Org, up:Dst() ); up = up.Lnext )
				--;
			while (Geom.vertLeq( up.Org, up:Dst() )) do up = up.Lnext end
			lo = up:Lprev();

			while( up.Lnext ~= lo ) do
				if( Geom.vertLeq( up:Dst(), lo.Org )) then
					--/* up->Dst is on the left.  It is safe to form triangles from lo->Org.
					-- * The EdgeGoesLeft test guarantees progress even when some triangles
					-- * are CW, given that the upper and lower chains are truly monotone.
					-- */
					while( lo.Lnext ~= up and (Geom.edgeGoesLeft( lo.Lnext )
						or Geom.edgeSign( lo.Org, lo:Dst(), lo.Lnext:Dst() ) <= 0.0 )) do
							local tempHalfEdge = mesh:connect( lo.Lnext, lo );
							--//if (tempHalfEdge == NULL) return 0;
							lo = tempHalfEdge.Sym;
					end
					lo = lo:Lprev();
				else 
					--/* lo->Org is on the left.  We can make CCW triangles from up->Dst. */
					while( lo.Lnext ~= up and (Geom.edgeGoesRight( up:Lprev() )
						or Geom.edgeSign( up:Dst(), up.Org, up:Lprev().Org ) >= 0.0 )) do
							local tempHalfEdge = mesh:connect( up, up:Lprev() );
							--//if (tempHalfEdge == NULL) return 0;
							up = tempHalfEdge.Sym;
					end
					up = up.Lnext;
				end
			end

			--/* Now lo->Org == up->Dst == the leftmost vertex.  The remaining region
			-- * can be tessellated in a fan from this leftmost vertex.
			-- */
			assert( lo.Lnext ~= up );
			while( lo.Lnext.Lnext ~= up ) do
				local tempHalfEdge = mesh:connect( lo.Lnext, lo );
				--//if (tempHalfEdge == NULL) return 0;
				lo = tempHalfEdge.Sym;
			end

			return true;
		end,


		--/* tessMeshTessellateInterior( mesh ) tessellates each region of
		-- * the mesh which is marked "inside" the polygon.  Each such region
		-- * must be monotone.
		-- */
		-- //int tessMeshTessellateInterior( TESSmesh *mesh )
		tessellateInterior_= function(this, mesh ) 
			local f, next;

			--/*LINTED*/
			--for( f = mesh.fHead.next; f ~= mesh.fHead; f = next ) {
			f = mesh.fHead.next
			while(f ~= mesh.fHead) do
				--/* Make sure we don''t try to tessellate the new triangles. */
				next = f.next;
				if( f.inside ) then
					print"face"
					if ( not this.tessellateMonoRegion_( mesh, f ) ) then return false; end
				end
				f = next
			end

			return true;
		end,


		--/* tessMeshDiscardExterior( mesh ) zaps (ie. sets to NULL) all faces
		-- * which are not marked "inside" the polygon.  Since further mesh operations
		-- * on NULL faces are not allowed, the main purpose is to clean up the
		-- * mesh so that exterior loops are not represented in the data structure.
		-- */
		-- //void tessMeshDiscardExterior( TESSmesh *mesh )
		discardExterior_= function( mesh ) 
			local f, next;

			--/*LINTED*/
			--for( f = mesh.fHead.next; f ~= mesh.fHead; f = next ) {
			f = mesh.fHead.next
			while(f ~= mesh.fHead) do
				--/* Since f will be destroyed, save its next pointer. */
				next = f.next;
				if( not f.inside ) then
					mesh.zapFace( f );
				end
				f = next 
			end
		end,

		--/* tessMeshSetWindingNumber( mesh, value, keepOnlyBoundary ) resets the
		-- * winding numbers on all edges so that regions marked "inside" the
		-- * polygon have a winding number of "value", and regions outside
		-- * have a winding number of 0.
		-- *
		-- * If keepOnlyBoundary is TRUE, it also deletes all edges which do not
		-- * separate an interior region from an exterior one.
		-- */
	-- //	int tessMeshSetWindingNumber( TESSmesh *mesh, int value, int keepOnlyBoundary )
		setWindingNumber_= function( mesh, value, keepOnlyBoundary ) 
			local e, eNext;

			--for( e = mesh.eHead.next; e ~= mesh.eHead; e = eNext ) {
			e = mesh.eHead.next
			while (e ~= mesh.eHead) do
				eNext = e.next;
				if( e:Rface().inside ~= e.Lface.inside ) then

					--/* This is a boundary edge (one side is interior, one is exterior). */
					e.winding = (e.Lface.inside) and value or -value;
				else 

					--/* Both regions are interior, or both are exterior. */
					if( not keepOnlyBoundary ) then
						e.winding = 0;
					else 
						mesh:delete( e );
					end
				end
				e = eNext
			end
		end,

		getNeighbourFace_= function(edge)
			if (not edge:Rface()) then
				return -1; end
			if (not edge:Rface().inside) then
				return -1; end
			return edge:Rface().n;
		end,

		outputPolymesh_= function(this, mesh, elementType, polySize, vertexSize ) 
			local v;
			local f;
			local edge;
			local maxFaceCount = 0;
			local maxVertexCount = 0;
			local faceVerts, i;
			local elements = 0;
			local vert;

			-- // Assume that the input data is triangles now.
			-- // Try to merge as many polygons as possible
			if (polySize > 3)
			then
				mesh.mergeConvexFaces( polySize );
			end

			--// Mark unused
			--for ( v = mesh.vHead.next; v ~= mesh.vHead; v = v.next )
			v = mesh.vHead.next
			while (v ~= mesh.vHead) do
				v.n = -1;
				v = v.next
			end

			--// Create unique IDs for all vertices and faces.
			--for ( f = mesh.fHead.next; f ~= mesh.fHead; f = f.next )
			f = mesh.fHead.next
			while (f ~= mesh.fHead) do
				f.n = -1;
				if( not f.inside ) then goto continue end

				edge = f.anEdge;
				faceVerts = 0;
				repeat
					v = edge.Org;
					if ( v.n == -1 )
					then
						v.n = maxVertexCount;
						maxVertexCount = maxVertexCount + 1;
					end
					faceVerts = faceVerts + 1;
					edge = edge.Lnext;
				until not (edge ~= f.anEdge);
				
				assert( faceVerts <= polySize );

				f.n = maxFaceCount;
				maxFaceCount = maxFaceCount + 1;
				::continue::
				f = f.next
			end

			this.elementCount = maxFaceCount;
			if (elementType == Tess2.CONNECTED_POLYGONS) then
				maxFaceCount = maxFaceCount * 2;
			end
	--/*		tess.elements = (TESSindex*)tess->alloc.memalloc( tess->alloc.userData,
															  -- sizeof(TESSindex) * maxFaceCount * polySize );
			-- if (!tess->elements)
			-- {
				-- tess->outOfMemory = 1;
				-- return;
			-- }*/
			this.elements = {};
			this.elements.length = maxFaceCount * polySize;
			
			this.vertexCount = maxVertexCount;
	--/*		tess->vertices = (TESSreal*)tess->alloc.memalloc( tess->alloc.userData,
															 -- sizeof(TESSreal) * tess->vertexCount * vertexSize );
			-- if (!tess->vertices)
			-- {
				-- tess->outOfMemory = 1;
				-- return;
			-- }*/
			this.vertices = {};
			this.vertices.length = maxVertexCount * vertexSize;

	--/*		tess->vertexIndices = (TESSindex*)tess->alloc.memalloc( tess->alloc.userData,
																    -- sizeof(TESSindex) * tess->vertexCount );
			-- if (!tess->vertexIndices)
			-- {
				-- tess->outOfMemory = 1;
				-- return;
			--}*/
			this.vertexIndices = {};
			this.vertexIndices.length = maxVertexCount;

			
			--// Output vertices.
			--for ( v = mesh.vHead.next; v ~= mesh.vHead; v = v.next )
			v = mesh.vHead.next
			while(v ~= mesh.vHead) do
				if ( v.n ~= -1 )
				then
					--// Store coordinate
					local idx = v.n * vertexSize;
					this.vertices[idx+0] = v.coords[0];
					this.vertices[idx+1] = v.coords[1];
					if ( vertexSize > 2 ) then
						this.vertices[idx+2] = v.coords[2]; end
					--// Store vertex index.
					this.vertexIndices[v.n] = v.idx;
				end
				v = v.next
			end

			--// Output indices.
			local nel = 0;
			--for ( f = mesh.fHead.next; f ~= mesh.fHead; f = f.next )
			f = mesh.fHead.next
			while(f ~= mesh.fHead) do
				if ( not f.inside ) then goto continue end
				
				--// Store polygon
				edge = f.anEdge;
				faceVerts = 0;
				repeat
					v = edge.Org;
					this.elements[nel] = v.n;
					nel = nel + 1
					faceVerts = faceVerts + 1;
					edge = edge.Lnext;
				until not (edge ~= f.anEdge);
				--// Fill unused.
				--for (i = faceVerts; i < polySize; ++i)
				for i = faceVerts, polySize-1 do
					this.elements[nel] = -1;
					nel = nel + 1
				end

				--// Store polygon connectivity
				if ( elementType == Tess2.CONNECTED_POLYGONS )
				then
					edge = f.anEdge;
					repeat
						this.elements[nel] = this.getNeighbourFace_( edge );
						nel = nel + 1
						edge = edge.Lnext;
					until not (edge ~= f.anEdge);
					--// Fill unused.
					for i = faceVerts,polySize-1 do
						this.elements[nel] = -1;
						nel = nel + 1
					end
				end
				::continue::
				f = f.next
			end
		end,

	--//	void OutputContours( TESStesselator *tess, TESSmesh *mesh, int vertexSize )
		outputContours_= function(this, mesh, vertexSize ) 
			local f;
			local edge;
			local start;
			local verts;
			local elements;
			local vertInds;
			local startVert = 0;
			local vertCount = 0;

			this.vertexCount = 0;
			this.elementCount = 0;

			--for ( f = mesh.fHead.next; f ~= mesh.fHead; f = f.next )
			f = mesh.fHead.next
			while (f ~= mesh.fHead) do
				if ( not f.inside ) then goto continue end

				edge = f.anEdge;
				start = edge 
				repeat
					this.vertexCount = this.vertexCount + 1;
					edge = edge.Lnext;
				until not ( edge ~= start );

				this.elementCount = this.elementCount + 1;
				::continue::
				f = f.next
			end

	--/*		tess->elements = (TESSindex*)tess->alloc.memalloc( tess->alloc.userData,
															  -- sizeof(TESSindex) * tess->elementCount * 2 );
			-- if (not tess->elements)
			-- then
				-- tess->outOfMemory = 1;
				-- return;
			-- }*/
			this.elements = {};
			this.elements.length = this.elementCount * 2;
			
	--/*		tess->vertices = (TESSreal*)tess->alloc.memalloc( tess->alloc.userData,
															  -- sizeof(TESSreal) * tess->vertexCount * vertexSize );
			-- if (!tess->vertices)
			-- {
				-- tess->outOfMemory = 1;
				-- return;
			-- }*/
			this.vertices = {};
			this.vertices.length = this.vertexCount * vertexSize;

	--/*		tess->vertexIndices = (TESSindex*)tess->alloc.memalloc( tess->alloc.userData,
																--    sizeof(TESSindex) * tess->vertexCount );
			-- if (!tess->vertexIndices)
			-- {
				-- tess->outOfMemory = 1;
				-- return;
			-- }*/
			this.vertexIndices = {};
			this.vertexIndices.length = this.vertexCount;

			local nv = 0;
			local nvi = 0;
			local nel = 0;
			startVert = 0;

			--for ( f = mesh.fHead.next; f ~= mesh.fHead; f = f.next )
			f = mesh.fHead.next
			while (f ~= mesh.fHead) do
				if ( not f.inside ) then goto continue end

				vertCount = 0;
				edge = f.anEdge;
				start = f.anEdge
				repeat
					this.vertices[nv] = edge.Org.coords[0];
					nv = nv + 1
					this.vertices[nv] = edge.Org.coords[1];
					nv = nv + 1
					if ( vertexSize > 2 ) then
						this.vertices[nv] = edge.Org.coords[2];
						nv = nv + 1
					end
					this.vertexIndices[nvi] = edge.Org.idx;
					nvi = nvi + 1
					vertCount = vertCount + 1;
					edge = edge.Lnext;
				until not ( edge ~= start );

				this.elements[nel] = startVert;
				nel = nel + 1
				this.elements[nel] = vertCount;
				nel = nel + 1

				startVert = startVert + vertCount;
				::continue::
				f = f.next
			end
		end,

		addContour= function(this, size, vertices )
			--print("addContour",size, vertices)
			--prtable(vertices)
			local e;
			local i;

			if ( this.mesh == nil ) then
			  	this.mesh = TESSmesh(); end
	--/*	 	if ( tess->mesh == NULL ) {
				-- tess->outOfMemory = 1;
				-- return;
			-- }*/

			if ( size < 2 ) then size = 2; end
			if ( size > 3 ) then size = 3; end

			e = nil;

			for i = 1,#vertices,size do
				if( e == nil ) then
					--/* Make a self-loop (one vertex, one edge). */
					e = this.mesh:makeEdge();
	--/*				if ( e == NULL ) {
						-- tess->outOfMemory = 1;
						-- return;
					-- }*/
					this.mesh:splice( e, e.Sym );
				else 
					--/* Create a new vertex and edge which immediately follow e
					-- * in the ordering around the left face.
					-- */
					this.mesh:splitEdge( e );
					e = e.Lnext;
				end

				--/* The new vertex is now e->Org. */
				e.Org.coords[0] = vertices[i+0];
				e.Org.coords[1] = vertices[i+1];
				if ( size > 2 ) then
					e.Org.coords[2] = vertices[i+2]; 
				else
					e.Org.coords[2] = 0.0;
				end
				--/* Store the insertion number so that the vertex can be later recognized. */
				e.Org.idx = this.vertexIndexCounter;
				this.vertexIndexCounter = this.vertexIndexCounter + 1

				--/* The winding of an edge says how the winding number changes as we
				-- * cross from the edge''s right face to its left face.  We add the
				-- * vertices in such an order that a CCW contour will add +1 to
				-- * the winding number of the region inside the contour.
				-- */
				e.winding = 1;
				e.Sym.winding = -1;
			end
		end,

	--	int tessTesselate( TESStesselator *tess, int windingRule, int elementType, int polySize, int vertexSize, const TESSreal* normal )
		tesselate= function(this, windingRule, elementType, polySize, vertexSize, normal )
			--prtable("tesselate",normal)
			this.vertices = {};
			this.elements = {};
			this.vertexIndices = {};

			this.vertexIndexCounter = 0;
			
			if (normal)
			then
				this.normal[0] = normal[0];
				this.normal[1] = normal[1];
				this.normal[2] = normal[2];
			end

			this.windingRule = windingRule;

			if (vertexSize < 2)then vertexSize = 2; end
			if (vertexSize > 3) then vertexSize = 3; end

	--/*		if (setjmp(tess->env) != 0) { 
				-- // come back here if out of memory
				-- return 0;
			-- }*/

			if (not this.mesh)
			then
				return false;
			end

			--/* Determine the polygon normal and project vertices onto the plane
			-- * of the polygon.
			-- */
			this:projectPolygon_();
			--print"after project"
			--prtableN(this,4)

			--/* tessComputeInterior( tess ) computes the planar arrangement specified
			-- * by the given contours, and further subdivides this arrangement
			-- * into regions.  Each region is marked "inside" if it belongs
			-- * to the polygon, according to the rule given by tess->windingRule.
			-- * Each interior region is guaranteed be monotone.
			-- */
			Sweep.computeInterior( this );

			local mesh = this.mesh;

			--/* If the user wants only the boundary contours, we throw away all edges
			-- * except those which separate the interior from the exterior.
			-- * Otherwise we tessellate all the regions marked "inside".
			-- */
			if (elementType == Tess2.BOUNDARY_CONTOURS) then
				this.setWindingNumber_( mesh, 1, true );
			else 
				this:tessellateInterior_( mesh ); 
			end
	--//		if (rc == 0) longjmp(tess->env,1);  --/* could've used a label */

			mesh:check();

			if (elementType == Tess2.BOUNDARY_CONTOURS) then
				this:outputContours_( mesh, vertexSize );     --/* output contours */
			else
				this:outputPolymesh_( mesh, elementType, polySize, vertexSize );     --/* output polygons */
			end

--//			tess.mesh = nil;

			return true;
		end
		}
		--return meta2[k] 
		--end
	}
	
return Tess2
