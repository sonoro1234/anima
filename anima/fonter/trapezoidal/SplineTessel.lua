
require"anima"
local vec2 = mat.vec2
local CG = require"anima.CG3"



local function mod(a,b)
	return ((a-1)%b)+1
end

local maskprog 

local function Editor(GL,updatefunc1)
	local sp_update = function(E,...)
			if E.NM.curr_spline > 0 then
				E:triangulate(E.NM.curr_spline);
			end
			if updatefunc1 then updatefunc1(E, ...) end
	end
	local SPT = require"anima.modeling.Spline"(GL,sp_update)
	SPT.triangulation = {}
	local NM
	local vars = {
	{"tesselator",4,guitypes.combo,{"EarClip2","glu","CDT1","CDT3","monotones","Tess2"},function()
		if NM.tesselator==5 or NM.tesselator==1 or NM.tesselator==4 then 
			NM.defs.Tess2_winding.invisible = false 
		else
			NM.defs.Tess2_winding.invisible = true
		end
		NM.defs.alg.invisible = (NM.tesselator~=4) and true or false
		SPT:triangulate(1) end},
	{"Tess2_winding",0,guitypes.combo,{"ODD","NONZERO","POSITIVE","NEGATIVE","ABS_GEQ_TWO"},function() SPT:triangulate(1) end},
	{"alg",0,guitypes.combo,{"AA","BB"},function() SPT:triangulate(1) end},
	{"drawregion",false,guitypes.toggle,function() sp_update(SPT) end},
	{"add_lines",false,guitypes.toggle,function()  print("add_lines",NM.add_lines) end}
	}
	
	--for converting from window coordinates to GL.fbo coordinates
	--from imgui inverted Y
	local function ScreenToViewport(X,Y)
		local mvp = ig.GetMainViewport()
		local sw,sh = GL:getWindowSize()
		--local x,y,w,h = unpack(GL.stencil_sizes)
		return GL:ScreenToViewport(X- mvp.Pos.x,sh-(Y-mvp.Pos.y))
	end
	local function ViewportToScreen(X,Y)
		local mvp = ig.GetMainViewport()
		local sw,sh = GL:getWindowSize()
		--local x,y,w,h = unpack(GL.stencil_sizes)
		local X1,Y1 = GL:ViewportToScreen(X,Y)
		return ig.ImVec2(X1,sh-Y1) + mvp.Pos
	end
	local function DrawTriangulation(dl, trian,color,i)
		if i~=1 then return end
		--print"DrawTriangulation"
		if #trian.points == 0 then return end
		local pointsI = {}
		for i=1,#trian.points do local p = trian.points[i];pointsI[i-1] = ViewportToScreen(p.x, p.y) end
		local tr = trian.tr
		--for i=1,math.min(#tr,3*NM.triangs),3 do
		if #trian.tr > 0 then
		for i=1,#tr,3 do 
			dl:AddTriangleFilled(pointsI[tr[i]], pointsI[tr[i+1]], pointsI[tr[i+2]],color) 
		end
		end
		--for i=1,#tr do dl:AddText(pointsI[tr[i]]+ig.ImVec2(0,-16),ig.U32(1,1,1,1),tostring(tr[i]+1)) end
		--for i=1,#tr,3 do dl:AddTriangle(pointsI[tr[i]], pointsI[tr[i+1]], pointsI[tr[i+2]],color) end
		for i=0,#pointsI do dl:AddText(pointsI[i]+ig.ImVec2(0,-16),ig.U32(1,1,1,1),tostring(i+1)) end
	end
	local function ShowSplines(NM)
		--if numsplines==0 then return end
		--if NM.curr_spline == 0 then return end
		local igio = ig.GetIO()
		local mpos = igio.MousePos
		local dl = ig.GetBackgroundDrawList(ig.GetMainViewport())
		local keepflags = dl.Flags
		dl.Flags = bit.band(dl.Flags,bit.bnot(ig.lib.ImDrawListFlags_AntiAliasedLines))
		--AddedLines
		if NM.add_lines and SPT.AddedLines then
		for i,line in ipairs(SPT.AddedLines) do
			local a = line[1]
			local b = line[2]
			local pointA = ViewportToScreen(a.x,a.y)
			local pointB = ViewportToScreen(b.x,b.y)
			dl:AddLine(pointA,pointB,ig.U32(0,1,0,1))
		end
		end
		if NM.drawregion then
			for i=1,SPT:get_numsplines() do
				--print"drawregion"
				if not SPT.triangulation[i] then SPT:triangulate(i) end
				if not SPT.triangulation[i].error then
					local color2 = i == SPT.NM.curr_spline and ig.U32(0.75,1,0,0.1) or ig.U32(0.75,1,0,0.05)
					DrawTriangulation(dl,SPT.triangulation[i],color2,i)
				end
				--dl:AddConcavePolyFilled(pointsI,#M.ps[i],color2)
			end
		end
		dl.Flags = keepflags
	end

	-----------------
	local tess_time = 0

	NM = gui.Dialog("spline tessel",vars,function(this)
		local NM = this
		--if numsplines==0 then return end
		local igio = ig.GetIO()
		local mpos = igio.MousePos
		local mposvp = vec2(ScreenToViewport(mpos.x, mpos.y))
		if NM.curr_spline == 0 then goto SHOW end
		::SHOW::
		ig.TextUnformatted(string.format("%f",tess_time*1000))
		ShowSplines(NM)
	end)
	
	local DBox = GL:DialogBox("Spline tesselat",true)
	DBox:add_dialog(SPT.NM)
	DBox:add_dialog(NM)
	SPT.NM.plugin = SPT
	
	local floor = math.floor
	
	local function clone_ps(ps)
		local pts = {}
		for i=1,#ps do pts[i] = ps[i] end
		if ps.holes then
			for i,hole in ipairs(ps.holes) do
				for j,v in ipairs(hole) do pts[#pts+1]=v end
			end
		end
		local contours = {}
		local Polind = {}
		---------------
		for j=1,#ps do assert(ps[j],"nil index in ps") end
		for i=1,#ps do Polind[i]=i end
		contours[1] = Polind
		local sum = #Polind
		if ps.holes then
			for i,hole in ipairs(ps.holes) do
				local Pi = {}
				for j=1,#hole do
					Pi[j]=j + sum
				end
				contours[#contours+1]=Pi
				sum = sum + #contours[#contours]
			end
		end
		return pts, contours
	end
	function SPT:triangulate(ii)
		print("triangulate",ii)
		--prtable(self)
		self.triangulation[ii] = {}
		if not NM.drawregion then return end
		if #self.ps[ii] < 3 then return end
		
		if ii~=1 then return end
		local lpt = require"luapower.time"
		local t1 = lpt.clock()
		if NM.tesselator == 0 then
			--- EarClip2
			local good, OK
			OK, self.triangulation[ii].points, self.triangulation[ii].tr, good = pcall(CG.EarClipSimple2, self.ps[ii], true)
			if not OK then
				print("EarClip error:", self.triangulation[ii].points)
				print(debug.traceback())
				self.triangulation[ii].error = true
				action = 1
				doingedit = false
			end
			if not good then print"bad EarClip" end
		elseif NM.tesselator == 1 then
			--winding positive and get tr
			--- glu_tesselator
			local glu_tesselator = require"anima.Fonter.glu_tesselator"
			local meshes = glu_tesselator.tesselate(self.ps[ii],glc.GLU_TESS_WINDING_ODD+NM.Tess2_winding,true)
			--meshes[1].triangles = CG.Delaunay( meshes[1].points,meshes[1].triangles)
			self.triangulation[ii].points, self.triangulation[ii].tr = meshes[1].points, meshes[1].triangles
		elseif NM.tesselator == 5 then --Tess2
			local insert = table.insert
			local Tess2 = require"anima.Fonter.tess2b3" 
			local contours = {}
			local contour = {}
			for i,v in ipairs(self.ps[ii]) do
				insert(contour,v.x)
				insert(contour,v.y)
			end
			contours[#contours+1] = contour
			if self.ps[ii].holes then
			for i,hole in ipairs(self.ps[ii].holes) do
				local contour = {}
				for j,v in ipairs(hole) do
					insert(contour,v.x)
					insert(contour,v.y)
				end
				contours[#contours+1] = contour
			end
			end
			local polisiz = 3
			local tess = Tess2.tesselate({
				contours= contours,
				windingRule=NM.Tess2_winding,--Tess2.WINDING_ODD,
				elementType=Tess2.POLYGONS,
				polySize=polisiz,
				vertexSize= 2
			});
			local points = {}
			local tr = {}
			for i = 0,tess.elements.length-1,polisiz do
				--print" begin path"
				for j = 0, polisiz-1 do
					local idx = tess.elements[i+j];
					if (idx == -1) then goto continue end
					if (j == 0) then
						--ctx.moveTo(tess.vertices[idx*2+0], tess.vertices[idx*2+1]);
						--print(tess.vertices[idx*2+0], tess.vertices[idx*2+1]);
						points[#points+1] = mat.vec2(tess.vertices[idx*2+0], tess.vertices[idx*2+1])
						insert(tr,#points-1)
					else
						--ctx.lineTo(tess.vertices[idx*2+0], tess.vertices[idx*2+1]);
						--print(tess.vertices[idx*2+0], tess.vertices[idx*2+1]);
						points[#points+1] = mat.vec2(tess.vertices[idx*2+0], tess.vertices[idx*2+1])
						insert(tr,#points-1)
					end
					::continue::
				end
				--print"end path"
			end
			prtable("result",points,tr)
			self.triangulation[ii].points, self.triangulation[ii].tr = points, tr
		elseif NM.tesselator == 2 then
			---[[ CDTins whith grid
			--clone ps
			local ps = self.ps[ii]
			local pts = {holes={}}
			for i=1,#ps do pts[i] = ps[i] end
			if ps.holes then
			for i,hole in ipairs(ps.holes) do
				pts.holes[i]= {}
				for j,v in ipairs(hole) do pts.holes[i][j]=v end
			end
			end
			local polyh = CG.InsertHoles(pts)
			--local Polind = {}
			--for i=1,#polyh do Polind[i]=i end
			--local polyh2 = {}
			--for i,v in ipairs(polyh) do polyh2[i]=v end
			--prtable(polyh.bridges)
			-- local inds = CG.lexicografic_sort(polyh2, true)
			-- local CH,tr = CG.triang_sweept(polyh2)
			-- local tr2 = {}
			-- for i=1,#tr do tr2[i] = inds[tr[i]+1]-1 end
			local epsv = mat.vec3(10,10,10)*3
			local minb,maxb = CG.bounds(polyh)
			local grid = mesh.gridB(1,{minb-epsv,maxb+epsv})
			local points_add = grid.points
			local indexes = grid.triangles
			local Polind = CG.AddPoints2Mesh(polyh,points_add,indexes)
			local ok,indexes2 = pcall(CG.CDTinsertion,points_add,indexes,Polind,polyh.bridges, true)
			self.triangulation[ii].points, self.triangulation[ii].tr = points_add, ok and indexes2 or indexes
			--]]
		--[[ CDTins 2
		--clone ps
		local ps = self.ps[ii]
		local pts = {holes={}}
		for i=1,#ps do pts[i] = ps[i] end
		if ps.holes then
		for i,hole in ipairs(ps.holes) do
			pts.holes[i]= {}
			for j,v in ipairs(hole) do pts.holes[i][j]=v end
		end
		end

		local inds = CG.lexicografic_sort(pts, true)
		local CH,tr = CG.triang_sweept(pts)
		local tr2 = {}
		for i=1,#tr do tr2[i] = inds[tr[i]+1]-1 end
		local Polind = {}
		for i=1,#ps do Polind[i]=i end

		local ok,indexes2 = pcall(CG.CDTinsertion,ps,tr2,Polind,{}, true)
		self.triangulation[ii].points, self.triangulation[ii].tr = ps, ok and indexes2 or tr2
		print("ok",ok,indexes2)
		--]]
		elseif NM.tesselator == 3 then
			---[=[ CDTins 3
			--clone ps
			local pts, contours = clone_ps(self.ps[ii])
			local ptsOr = {}
			for i=1,#pts do ptsOr[i]=pts[i] end
			local inds = CG.lexicografic_sort(pts, true)
			local CH,tr = CG.triang_sweept(pts)
			local tr2 = {}
			for i=1,#tr do tr2[i] = inds[tr[i]+1]-1 end
	
			local indexes2 = CG.CDTinsertion(ptsOr,tr2,contours,{}, true)
			self.triangulation[ii].points, self.triangulation[ii].tr = ptsOr, indexes2 
			--]==]
		
		elseif NM.tesselator ==  4 then
			
			CG = require"anima.fonter.trapezoidal.trapezoidal_ListPrio"
			---[=[ Dave mount for trapezoidal as seidel
			local pts, contours = clone_ps(self.sccoors[ii])--self.ps[ii])
			prtable(pts,contours)
			--local OK,points, tr = pcall(CG.monotone_tesselator,pts, contours)
			local OK,points, tr,AddedLines,pols = pcall(CG.edges_monotone_tesselator,pts, contours,NM.Tess2_winding,NM.alg==0)
			--prtable(points,tr)
			--print(OK,points,debug.traceback())
			if OK then
			--NM.vars.drawregion[0] = false
			for i=SPT:get_numsplines(),2,-1 do
				SPT:deletespline(i)
			end
			for i,pol in ipairs(pols) do
				print("newspline",i)
				local poly = {}
				for j=1,#pol do poly[j] = pts[pol[j]] end
				local a = self:newspline(poly)
				self.triangulation[a] = {}
				self.triangulation[a].points, self.triangulation[a].tr = poly, {}
			end
			SPT.NM.vars.curr_spline[0] = 1
			end
			if OK then
				self.AddedLines = {}
				for i,line in ipairs(AddedLines) do
					table.insert(self.AddedLines,{pts[line[1]],pts[line[2]]})
				end
				prtable(AddedLines)
				prtable(self.AddedLines)
			end
			if OK then
				self.triangulation[ii].points, self.triangulation[ii].tr = points, tr
			else
				print("error:",points,debug.traceback())
				self.triangulation[ii].points, self.triangulation[ii].tr = pts,{}
			end
			--]=]
		end
		tess_time = lpt.clock() - t1
	end
	
	SPT.draw = function() end --dummy value for plugin
	--M:clearshape()
	GL:add_plugin(SPT,"spline tessel")
	return SPT
end

---[=[
if not ... then
local GL = GLcanvas{H=900,aspect=1,DEBUG=true,use_imgui_viewport=false}
local function update(n) end --print("update spline",n) end
local edit = Editor(GL,update,{region=true})--,doblend=true})
local plugin = require"anima.plugins.plugin"
edit.fb = plugin.serializer(edit)
---local DBox = GL:DialogBox("Spline Tessel demo",true)
function GL.init()
	--DBox:add_dialog(edit.NM)
end
function GL.imgui()
	--ig.ShowDemoWindow()
	--edit.NM:draw()
end
GL:start()

end

--]=]

return Editor
