require"anima"
local vec3 = mat.vec3
local vec2 = mat.vec2
local vec4 = mat.vec4


local vertEYE_sh = [[
in vec3 position;
uniform mat4 P;
void main()
{
	gl_Position = P * vec4(position,1);

}
]]
local frag_sh = [[
uniform vec3 color = vec3(1);
void main()
{
	gl_FragColor = vec4(color,1);
}
]]

local  programE

local function PlanesPicker(GL,camera,updatefunc,MakersG)
	local updatefunc = updatefunc or function() end
	
	local doupdate = true
	local function updatefunc1()
		if doupdate then 
			updatefunc() 
		end
	end

	local PR = {camera=camera, planes = {}}
	local NM
	
	local points = {}
	local quads = {}
	local components = 1 
	local picking = false
	local curr_plane -- for choose_p and spline drawing in it
	local use_points = ffi.new("bool[1]",true)
	PR.curr_maker = ffi.new("int[1]",1)
	
	--for converting from window coordinates to GL.fbo coordinates
	--from imgui inverted Y
	local function ScreenToViewport(X,Y)
		local sw,sh = GL:getWindowSize()
		local x,y,w,h = unpack(GL.stencil_sizes)
		return GL:ScreenToViewport(X,sh-Y)
	end
	local function ViewportToScreen(V)
		local sw,sh = GL:getWindowSize()
		local x,y,w,h = unpack(GL.stencil_sizes)
		local X1,Y1 = GL:ViewportToScreen(V.x,V.y)
		return ig.ImVec2(X1,sh-Y1)
	end
	
	local CG = require"anima.CG3"
	--we have 3 points and 2 vpoints
	local function complete_quad(quad)
		--find point not in quad from 1st vpoint
		local vpoint1 = quad.vpoints[1].vp
		vpoint1 = PR:Eye2Viewport(vpoint1)
		local from1 = quad.vpoints[1].from
		local who1 = quad.vpoints[1].who
		local notin1 
		for i=1,3 do 
			if i~= who1[1] and i~=who1[2] then
				--print(from1, "not touched by",i)
				notin1 = points[quad[i]]
				notin1 = vec2(notin1.x, notin1.y)
				break
			end
		end
		--find point not in quad from 2nd vpoint
		local vpoint2 = quad.vpoints[2].vp
		vpoint2 = PR:Eye2Viewport(vpoint2)
		local from2 = quad.vpoints[2].from
		local who2 = quad.vpoints[2].who
		local notin2 
		for i=1,3 do 
			if i~= who2[1] and i~=who2[2] then
				--print(from2, "not touched by",i)
				notin2 = points[quad[i]]
				notin2 = vec2(notin2.x, notin2.y)
				break
			end
		end
		--intersect lines notin1-vp1
		--and notin2-vp2
		--print("complete",notin1,vpoint1,notin2,vpoint2)
		local c = CG.IntersecPoint2(notin1,vpoint1,notin2,vpoint2)
		--reuse if already exists
		c = ig.ImVec2(c.x,c.y)
		for i,p in ipairs(points) do
			if (p-c).norm < 0.1 then
				quad[4] = i
				return 
			end
		end
		--create new if not
		points[#points+1] = c
		quad[4] = #points
	end
	--spetial case 1 vpoint 3 touched points
	local function correct_quad3(quad,nottouched)
		--we have a touched point STILL not generating vpoint
		--find the other touchedquad
		print"special-------------------------------"
		local from = quad.vpoints[1].from
		local who = quad.vpoints[1].who
		local otherquad,otherind
		for k,iq in pairs(quad.touchedquads) do
			if k~=from then 
				otherquad=k;
				assert(#iq==1) --only one point touched
				otherind = iq[1][1]
				break 
			end
		end
		print("from",from,"otherquad",otherquad,otherind)
		assert(otherquad)
		--search in otherquad a point aligned with otherind and vpoint[1].vp
		--adjacent to otherind
		local prev = otherind-1
		prev = prev < 1 and prev+4 or prev
		local follow = otherind + 1
		follow = follow > 4 and follow - 4 or follow
		local minsign = math.huge
		local a, b = PR:Eye2Viewport(quad.vpoints[1].vp), points[quads[otherquad][otherind]]
		local searchind
		for i,ind in ipairs{prev,follow} do
			local sign = math.abs(CG.Sign(a,b,points[quads[otherquad][ind]]))
			if sign < minsign then
				minsign = sign
				searchind = ind
			end
		end
		print("searchind",searchind, quads[otherquad][searchind])
		quad[nottouched] = quads[otherquad][searchind]
	end
	--4 point is added to a quad with already 1 vpoint
	--or in repair 1 vpoint present
	local function correct_quad(quad)
		--print"correct_quad"
		local nottouched = {}
		for i=1,#quad do
			if not quad.touched[i] then 
				--print("not touched",i);
				nottouched[#nottouched+1] = i 
			end
		end
		if #nottouched == 1 then
			print"correct_quad3 from correct_quad-------------------------"
			return correct_quad3(quad,nottouched[1])
		end
		assert(#nottouched==2)
		local vpoint = quad.vpoints[1].vp
		vpoint = PR:Eye2Viewport(vpoint)
		local a = points[quad[nottouched[1]]]
		a = vec2(a.x,a.y)
		local ray = (a - vpoint).normalize
		local b = points[quad[nottouched[2]]]
		b = vec2(b.x,b.y)
		local ray2 = b-vpoint
		local proj = ray*ray2
		local c = vpoint + ray*proj
		points[quad[nottouched[2]]] = ig.ImVec2(c.x,c.y)
	end
	
	local function check_touchedquad(quad,k,v)
		local a,b = v[1][1],v[2][1] --unpack(v)
		local c,d = v[1][2],v[2][2]
		if b < a then a,b = b,a end
		quad.vpoints = quad.vpoints or {}

		if a==2 and b==3 then 
			table.insert(quad.vpoints, {vp=PR.planes[k].vpointY, from=k, who={c,d}})
			return true
		elseif a==3 and b==4 then
			table.insert(quad.vpoints, {vp=PR.planes[k].vpointX,from=k, who={c,d}})
			return true
		elseif a==1 then
			if b==2 then
				table.insert(quad.vpoints, {vp=PR.planes[k].vpointX,from=k, who={c,d}})
				return true
			elseif b==4 then
				table.insert(quad.vpoints, {vp=PR.planes[k].vpointY,from=k, who={c,d}})
				return true
			end
		end
		return false
	end
	
	local function Choose_plane()
		local igio = ig.GetIO()
		if igio.MouseClicked[0] and not igio.MouseDownOwned[0] then
			local mpos = igio.MousePos
			local mposvp = ig.ImVec2(ScreenToViewport(mpos.x, mpos.y))
			for i,plane in ipairs(PR.planes) do
				local center = PR:Eye2Viewport(plane.frame.center)
				if (center - mposvp).norm < 6 then
					curr_plane = i 
					NM.vars.choose_p[0] = false
				end
			end
		end
	end
	
	local function PickQuad()
		ig.SetMouseCursor(ig.lib.ImGuiMouseCursor_Hand);
		local quad = quads[#quads]
		local igio = ig.GetIO()
		local mpos = igio.MousePos
		--clicked not over any window
		if igio.MouseClicked[0] and not igio.MouseDownOwned[0] then
			print"pick"
			local touched = -1
			local mposvp = ig.ImVec2(ScreenToViewport(mpos.x, mpos.y))
			for i=1,#points do 
				if (points[i] - mposvp).norm < 6 then touched = i;break end
			end
			if touched < 0 then 
				points[#points+1]= mposvp 
				quad[#quad+1] = #points
				print("qindex",#quad)
				if #quad == 4 and (quad.vpoints and #quad.vpoints == 1) then
					correct_quad(quad)
				end
			else
				print("touched",touched)
				--avoid already in this quad
				local inthis = false
				quad.touchedquads = quad.touchedquads or {}
				for j=1,#quad do
					if quad[j]==touched then print"inthis";inthis=true;break end
				end
				if not inthis then
					--find touched quad in previous quads
					local found = false
					for i=1,#quads-1 do
						for j=1,4 do
							if quads[i][j] == touched then
								--quad.touchedquads = quad.touchedquads or {}
								quad.touchedquads[i] = quad.touchedquads[i] or {}
								--vertex #quad+1 from quad touches vertex j from quad i
								table.insert(quad.touchedquads[i],{j,#quad +1}) 
								found = true
							end
						end
					end
					if found then 
						quad[#quad+1] = touched
						print("qindex found",#quad)
						quad.touched = quad.touched or {}
						quad.touched[#quad] = true
					end
				end
				for k,v in pairs(quad.touchedquads) do
					--if we have two points from other quad then 
					--we have already an vpoint
					if #v == 2 and (not quad.hasvpointfrom or not quad.hasvpointfrom[k])then
						if check_touchedquad(quad,k,v) then
							quad.hasvpointfrom = quad.hasvpointfrom or {}
							quad.hasvpointfrom[k] = true
							print("has vpoint from",k,v)
						end
					end
				end
				if #quad == 3 then
					if (quad.vpoints and #quad.vpoints==2) then
						--prtable("goes to complete",quad)
						print"-------complete"
						complete_quad(quad)
					elseif (quad.vpoints and #quad.vpoints==1) then
						--if 1,2,3 touched points
						if #quad.touched == 3 then
							correct_quad3(quad,4)
						end
					end
				end
				--prtable(quad)
			end
			if #quad == 4 then 
				picking = false 
				curr_plane = #quads
				return true
			end
		end
		return false
	end
	
	--we have 4 points and 2 vpoints
	local function correct_quad2(quad)
		--print"correct_quad2"
		--find point not in quad from 1st vpoint
		local vpoint1 = quad.vpoints[1].vp
		vpoint1 = PR:Eye2Viewport(vpoint1)
		local from1 = quad.vpoints[1].from
		local who1 = quad.vpoints[1].who
		local notin1 
		for i=1,4 do 
			if i~=who1[1] and i~=who1[2]  then
				--print(from1, "not touched by",i)
				notin1 = points[quad[i]]
				notin1 = vec2(notin1.x, notin1.y)
				break
			end
		end
		--find point not in quad from 2nd vpoint
		local vpoint2 = quad.vpoints[2].vp
		vpoint2 = PR:Eye2Viewport(vpoint2)
		local from2 = quad.vpoints[2].from
		local who2 = quad.vpoints[2].who
		local notin2 
		for i=1,4 do 
			if i~=who2[1] and i~=who2[2]  then
				--print(from2, "not touched by",i)
				notin2 = points[quad[i]]
				notin2 = vec2(notin2.x, notin2.y)
				break
			end
		end
		--intersect lines notin1-vp1
		--and notin2-vp2
		--print("complete",notin1,vpoint1,notin2,vpoint2)
		local c = CG.IntersecPoint2(notin1,vpoint1,notin2,vpoint2)
		--intersection goes to point not in who1 or who2 
		--print("whos",who1[1], who1[2], who2[1],who2[2],c)
		local nottouched
		for i=1,4 do if who1[1]~=i and who1[2]~=i and who2[1]~=i and who2[2]~=i then nottouched=i; break end end
		--nottouched is nil if both vpoints are equal: two parallel lines touched
		if nottouched then
		points[quad[nottouched]] = ig.ImVec2(c.x,c.y)
		end
	end
	
	local function repair_quad(quad)
		if not quad.touchedquads then return end
		--find resticting vpoints
		--quad.hasvpointfrom = nil
		quad.vpoints = nil
		for k,v in pairs(quad.touchedquads) do
			--if we have two points from other quad then 
			--we have already an vpoint
			if #v == 2 then ---and (not quad.hasvpointfrom or not quad.hasvpointfrom[k])then
				check_touchedquad(quad,k,v)
			end
		end
		--prtable(quad)
		if not quad.vpoints then return end
		if #quad.vpoints == 1 then 
			correct_quad(quad)
		elseif #quad.vpoints == 2 then
			correct_quad2(quad)
		end
	end
	
	local function DFS(G,v)
		G.V[v].explored = true
		G.L = G.L or {}
		table.insert(G.L,v)
		for eh,_  in pairs(G.V[v].edges) do
			if not G.E[eh].explored then
				local E = G.E[eh]
				local w = E[1]==v and E[2] or E[1]
				if not G.V[w].explored then
					G.E[eh].explored = "discovered"
					DFS(G,w)
				else
					G.E[eh].explored = "backedge"
				end
			end
		end
	end
	local function makegraph()
		local G = {V={},E={}, L={}}
		local function Ehash(i,j)
			if i > j then i,j = j,i end
			return tostring(i).."-"..tostring(j)
		end
		--find conections between quads
		for i,quad in ipairs(quads) do
			for j,quad2 in ipairs(quads) do
				G.V[j] = G.V[j] or {edges={}}
				if i~=j then
					for k=1,4 do 
						for l=1,4 do
							if quad[k]==quad2[l] then
								local eh = Ehash(i,j)
								local e = {i,j}
								G.E[eh] = e
								G.V[i].edges[eh] = true
								G.V[j].edges[eh] = true
							end
						end
					end
				end
			end
		end
		return G
	end
	
	local function reconstruct()
		print("reconstruct","doupdate",doupdate)
		doupdate = false
		--order quads and planes according to dependences
		local G = makegraph()
		local components = 0
		for i,V in ipairs(G.V) do
			if not V.explored then 
				components = components + 1
				DFS(G,i) 
			end
		end
		--prtable(PR.quad_meshes)
		--prtable(G.L)
		local newquads = {}
		local newsplines = {}
		for _,i in ipairs(G.L) do 
			table.insert(newsplines,PR.quad_meshes[i])
			table.insert(newquads,quads[i])
		end
		quads = newquads
		PR.quads = quads
		PR.quad_meshes = newsplines
		--
		--delete planes
		PR.planes = {}
		--delete points not in quad
		--and reindex
		local used, map = {}, {}
		for i,p in ipairs(points) do used[i] = 0; map[i] = i end
		for i,quad in ipairs(quads) do
			for j=1,4 do used[quad[j]] = used[quad[j]] + 1 end
		end
		--for i,v in ipairs(used) do
		for i=#used,1,-1 do
			local v = used[i]
			if v==0 then table.remove(points,i); table.remove(map,i) end
		end
		local map2 = {}
		for i,v in ipairs(map) do map2[v] = i end
		--apply map2
		for i,quad in ipairs(quads) do
			for j=1,4 do quad[j] = map2[quad[j]] end
			assert(#quad==4)
		end
		
		--delete all excep quad points and points
		for i,quad in ipairs(quads) do
			for k,v in pairs(quad) do
				if type(k)~="number" then
					quad[k] = nil
				end
			end
		end
		--reconstruct
		for nq,quad in ipairs(quads) do
			for ip=1,4 do
				local currpoint = quad[ip]
				--find touched quad in previous quads
				local found = false
				for i=1,nq-1 do
					for j=1,4 do
						if quads[i][j] == currpoint then
							quad.touchedquads = quad.touchedquads or {}
							quad.touchedquads[i] = quad.touchedquads[i] or {}
							table.insert(quad.touchedquads[i],{j,ip})
							found = true
						end
					end
				end
				if found then 
					--quad[#quad+1] = touched
					quad.touched = quad.touched or {}
					quad.touched[ip] = true
				end
			end
		end
		PR:Rectify()
		for nq,quad in ipairs(quads) do
			repair_quad(quad)
		end
		PR:Rectify()
		PR:Rectify2()
		PR:reset_planes()

		doupdate = true
		updatefunc1()
		print("components",components)
		print("reconstruct done")
	end
	
	local editind
	local function EditQuads()
		ig.SetMouseCursor(ig.lib.ImGuiMouseCursor_Hand);
		local igio = ig.GetIO()
		local mpos = igio.MousePos
		if igio.MouseClicked[0] then
			local touched = -1
			local mposvp = ig.ImVec2(ScreenToViewport(mpos.x, mpos.y))
			for i=1,#points do 
				if (points[i] - mposvp).norm < 6 then touched = i end
			end
			if touched > 0 then editind=touched end
		end
		if editind then
			points[editind] = ig.ImVec2(ScreenToViewport(mpos.x, mpos.y))
			for i,quad in ipairs(quads) do
				--print("repair ",i)
				repair_quad(quad)
			end
			if igio.MouseReleased[0] then 
				editind = nil
			end
			return true
		end
		return false
	end
	
	local function ShowQuads()
		--print"Show"
		local igio = ig.GetIO()
		local mpos = igio.MousePos
		local dl = ig.GetBackgroundDrawList()
		local keepflags = dl.Flags
		dl.Flags = bit.band(dl.Flags,bit.bnot(ig.lib.ImDrawListFlags_AntiAliasedLines))
		
		for j,quad in ipairs(quads) do
			local pointsI = ffi.new("ImVec2[?]",#quad)
			for i=1,#quad do
				local point = points[quad[i]]
				local scpoint = ViewportToScreen(point)
				dl:AddCircleFilled(scpoint, 4, ig.U32(1,0,0,1))
				if picking and (scpoint - mpos).norm < 4 then dl:AddCircleFilled(scpoint, 6, ig.U32(1,1,0,1)) end
				pointsI[i-1] = scpoint
			end
			dl:AddPolyline(pointsI,#quad,ig.U32(1,1,0,1),#quad > 2, 1)
			
			--vpointX and Y1
			if PR.planes[j] then
				local vpX,vpY = PR.planes[j].vpointX, PR.planes[j].vpointY
				vpX = PR:Eye2Viewport(vpX)
				vpY = PR:Eye2Viewport(vpY)
				dl:AddCircleFilled(ViewportToScreen(vpX), 4, ig.U32(0,1,0,1))
				dl:AddCircleFilled(ViewportToScreen(vpY), 4, ig.U32(0,1,0,1))
			end
			--show planes center
			if PR.planes[j] then
				local center = PR.planes[j].frame.center
				center = PR:Eye2Viewport(center)
				local color = j==curr_plane and ig.U32(1,0,1,1) or ig.U32(0,0,1,1)
				dl:AddCircleFilled(ViewportToScreen(center), 4, color)
			end
			--if just picking this quad
			if #quad < 4 then
				--line from last point to mouse
				if #quad > 0 then
					local lastp = ViewportToScreen(points[quad[#quad]])
					dl:AddLine(lastp,mpos,ig.U32(1,1,0,1))
				end
				if quad.vpoints and #quad.vpoints > 0 then
					assert(#quad.vpoints==1)
					--find not touched
					local vpoint1 = quad.vpoints[1].vp
					local from1 = quad.vpoints[1].from
					local who1 = quad.vpoints[1].who
					for i=1,#quad do
						--if not quad.touched[i] then
						--draw line for completing this quad with already an vpoint
						if i~=who1[1] and i~=who1[2] then
							local vpoint = quad.vpoints[1].vp
							vpoint = PR:Eye2Viewport(vpoint)
							local a = points[quad[i]]
							local ray = a - vpoint
							local b1 = a - ray*400
							local b2 = a + ray*400
							local as = ViewportToScreen(a)
							local b1s = ViewportToScreen(b1)
							local b2s = ViewportToScreen(b2)
							dl:AddLine(b1s,b2s,ig.U32(1,0,0,1))
							dl:AddCircleFilled(as, 6, ig.U32(1,0,1,1))
							--print"showline"
						end
					end
				end
			end
		end
		
		dl.Flags = keepflags
	end
	
	
	
	local function add_mesh(iplane, usepoints)
		local sppoints 
		if usepoints then
			sppoints = {}
			for i,ind in ipairs(quads[iplane]) do
				local p = points[ind]
				sppoints[i] = vec2(p.x,p.y)
			end
		end
		
		local spnum = PR.Makers[PR.curr_maker[0]]:newmesh(sppoints)
		--PR.quad_meshes[iplane] = PR.quad_meshes[iplane] or {}
		table.insert(PR.quad_meshes[iplane], {spnum,PR.curr_maker[0]})
		local frame = PR:get_planev4(iplane)
		PR.Makers[PR.curr_maker[0]]:set_frame(frame,spnum)
	end
	local curr_mesh_edit
	NM = gui.Dialog("rhomboids",
	{
	{"dump quads",0,guitypes.button,function() prtable(PR.quads,PR.points) end},
	{"dump planes",0,guitypes.button,function() 
			for i,pl in ipairs(PR.planes) do
				prtable(pl.frame)
				print(pl.vpointX,pl.vpointY)
			end
		end,{sameline=true}},
	{"dump quad_meshes",0,guitypes.button,function() prtable(PR.quad_meshes) end,{sameline=true}},
	{"focal_track",false,gui.types.toggle,nil},
	
	{"zval",1,guitypes.val,{min=1e-5,max=30},function(val,this) PR:Rectify();PR:Rectify2();PR:reset_planes() end},
	{"reconstruct",0,guitypes.button,function() reconstruct() end},
	{"pick_plane",0,guitypes.button,function(this,_) 
		if not picking then
			this.vars.edit[0]=false; 
			quads[#quads+1]= {};
			PR.quad_meshes[#PR.quad_meshes+1] = {}
			picking = true 
		end
		end},
	{"edit",false,guitypes.toggle,nil,{sameline=true}},
	
	{"choose_p",false,guitypes.toggle,function(val,this)
			if val then this.vars.edit[0]=false end
		end,{sameline=true}},
	{"set_all_meshes",0,guitypes.button,function() 
			for i,pl in ipairs(PR.planes) do
				if #PR.quad_meshes[i] == 0 then
					add_mesh(i,true)
				end
			end 
		end},
	},function(this,vname)
		
		--ig.Columns(2)
		if picking then
			if PickQuad() then reconstruct() end --PR:Rectify() end
		elseif this.edit then
			if EditQuads()  then 
				reconstruct()
			end
		elseif this.choose_p then
			Choose_plane()
		end
		ShowQuads()
		------------------------
		ig.SameLine()
		gui.ToggleButton("use points",use_points)
		
		if ig.SliderInt("maker",PR.curr_maker, 1,#MakersG, MakersG.names[PR.curr_maker[0]]) then
			
		end
		if curr_plane then
			local cuplane = ffi.new("int[1]",curr_plane)
			if ig.SliderInt("curr_plane",cuplane,1,#PR.quads) then
				curr_plane = cuplane[0]
			end
		end
		ig.Separator()
		for i,plane in ipairs(PR.planes) do
			ig.SetNextItemOpen(true, ig.lib.ImGuiCond_Once)
			if ig.TreeNode("plane "..i) then
				ig.SameLine();
				if ig.SmallButton("delete_plane##"..i) then
					PR:delete_plane(i)
					curr_plane = #PR.quads > 0 and #PR.quads or nil
				end
				ig.SameLine()
				local label = "add_"..MakersG.names[PR.curr_maker[0]].."##"..i
				if ig.SmallButton(label) then
					add_mesh(i,use_points[0])
				end
				for j,sp in ipairs(PR.quad_meshes[i]) do
					local spnum = sp[1]
					local maker = sp[2]
					local idst = maker.."_"..spnum
					ig.BulletText(MakersG.names[maker]..":"..spnum)
					ig.SameLine()
					if ig.SmallButton("reset##"..idst) then
						PR:reset_mesh(i,maker,spnum)
					end
					ig.SameLine()
					if ig.SmallButton("delete##"..idst) then
						PR:deletemesh(i,maker,spnum)
					end
					ig.SameLine()
					if ig.SmallButton("edit##"..idst) then
						curr_mesh_edit = sp
					end
					
				end
				ig.TreePop()
			end
		end
		ig.Separator()
		if curr_mesh_edit then
			local maker = curr_mesh_edit[2]
			local imesh = curr_mesh_edit[1]
			ig.Text(MakersG.names[maker]..": "..imesh.." editor")
			ig.SameLine()
			if ig.SmallButton("close") then
				curr_mesh_edit = nil
			end
			ig.Separator()
			if ig.BeginChild("editor") then
				PR.Makers[maker]:set_current(imesh)
				PR.Makers[maker]:external_control(true)
				PR.Makers[maker].NM:draw()
			end
			ig.End()
		end
		--ig.NextColumn()
		--ig.Columns(1)
	end)
	
	--------------------------------------------------

	PR.Makers = {}
	for i,m in ipairs(MakersG) do
		PR.Makers[i] = m(GL,camera,updatefunc1)
	end
---[[
	local Dbox = gui.DialogBox("plSpline",true)
	Dbox:add_dialog(NM)
	
	Dbox.plugin = PR
	PR.NM = Dbox
	table.insert(GL.presetmanaged, Dbox)
	local oldimguifunc = GL.imgui
	GL.imgui = function()
		if oldimguifunc then oldimguifunc() end
		if ig.Begin("rhomboidsM") then
			Dbox:draw()
			--io.write"."
		end
		ig.End()
	end
--]]
--[[
	NM.plugin = PR
	PR.NM = NM
	table.insert(GL.presetmanaged, NM)
	local oldimguifunc = GL.imgui
	GL.imgui = function()
		if oldimguifunc then oldimguifunc() end
		if ig.Begin("rhomboidsM") then
			NM:draw()
		end
		ig.End()
	end
	
--]]

	PR.quads = quads
	PR.points = points
	PR.quad_meshes = {}
	PR.epoints = {}
	PR.epointsR = {}
	
	
	
	local camMVinv , camMPinv,camMP, camNear
	
	camMVinv = camera:MV().inv
	camMPinv = camera:MP().inv
	camMP = camera:MP()
	camNear = camera.NMC.nearZ
		
	
	local function initVaos()
		local vao_lines = VAO({position={0,0,0, 0,0,0, 0,0,0, 0,0,0}},programE)
		return  vao_lines
	end
	

	function PR:init()
		if not programE then
			programE = GLSL:new():compile(vertEYE_sh,frag_sh)
		end
	end
	
	function PR:Viewport2Eye(scpoint)
		local ndc = scpoint*2/vec2(GL.W,GL.H) - vec2(1,1)
		local eyepoint = camera:MP().inv * (mat.vec4(ndc.x,ndc.y,1,1))
		eyepoint = eyepoint/eyepoint.w
		eyepoint = - eyepoint/eyepoint.z
		return eyepoint.xyz
	end
	
	function PR:Eye2Viewport(eyep)
		local ndc = camera:MP()*mat.vec4(eyep,1)
		ndc = (ndc/ndc.w).xyz
		--ndc = ndc/ndc.z
		ndc = (ndc.xy + vec2(1,1))
		ndc = vec2(ndc.x*GL.W*0.5,ndc.y*GL.H*0.5)
		return ndc
	end
	
	local function draw_lines(vao_lines)
		programE:use()
		programE.unif.P:set(camera:MP().gl)
		programE.unif.color:set{0,1,1}
		vao_lines:draw(glc.GL_LINES,4,6)
		programE.unif.color:set{0,0,1}
		vao_lines:draw(glc.GL_LINES,2,4)
		programE.unif.color:set{0,1,0}
		vao_lines:draw(glc.GL_LINES,2,2)
		programE.unif.color:set{1,0,0}
		vao_lines:draw(glc.GL_LINES,2,0)
	end
	function PR:draw_lines()
		if curr_plane then
			draw_lines(self.planes[curr_plane].vao_lines)
		end
	end
	
	local lastfocal = camera.focal
	function PR:draw()
		if NM.collapsed then return end
		
		--if focal changes and NM.focal_track==true redo Rectify
		--good for getting focal of a photo: when with points representing a rectangle
		--frame line Y (green) align with that rectangle
		if lastfocal ~= camera.focal and NM.focal_track then
			self:Rectify()
			self:Rectify2()
			lastfocal = camera.focal
		end
		
		gl.glViewport(0, 0,GL.W,GL.H)
		
		if #self.planes > 0 then
			gl.glDisable(glc.GL_DEPTH_TEST)
			self:draw_lines()
			gl.glEnable(glc.GL_DEPTH_TEST)
		end
	end
	
	local function eye2world(p)
		local pR = camMVinv * mat.vec4(p.x,p.y,p.z,1)
		return vec3(pR.x,pR.y,pR.z)/pR.w
	end
	
	function PR:set_points_vao()
		local vec2vao = mat.vec2vao
		for i,plane in ipairs(self.planes) do
		
			local eyepointsR = {}
			for j=1,4 do
				eyepointsR[j] = self.epointsR[plane.quad[j]]
			end
			
			---lines
			local eye = eyepointsR[1]
			local eyenorm = (eyepointsR[4]-eyepointsR[1]).norm --eye.norm
	
			local p1 = eye - plane.vpointX.normalize*eyenorm*0.5
			local p2 = eye - plane.vpointY.normalize*eyenorm*0.5
			local p3 = eye + plane.vpointY.normalize*eyenorm*0.5
			
			local fx = eye + plane.frame.X * eyenorm
			local fy = eye + plane.frame.Y * eyenorm
			local fz = eye + plane.frame.Z * eyenorm
		
			local lp = vec2vao{eye,fx,eye,fy,eye,fz,eye,p1,p2,p3}
			plane.vao_lines:set_buffer("position",lp,10*3)
		end
	end
	
	
	function PR:set_pointsR()
		--print"set_pointsR"
		
		local centroid = vec3(0,0,0)
		self.epointsR = {}
		--set first point
		--self.epointsR[1] = self.epoints[1].normalize*NM.zval
		for i,plane in ipairs(self.planes) do
		--for _,i in ipairs(Graph.L) do
			local plane = self.planes[i]
			local vlineN = plane.frame.Z
			--find setted point in this plane
			local spoint
			for j=1,4 do
				local ind = plane.quad[j]
				if self.epointsR[ind] then
					spoint = self.epointsR[ind]
					break
				end
			end
			--if no point was alredy set in this quad
			--set the first one to NM.zval
			if spoint==nil then
				print("new firs point in quad",i)
				self.epointsR[plane.quad[1]] = self.epoints[plane.quad[1]].normalize*NM.zval
				spoint = self.epointsR[plane.quad[1]]
			end
			--get plane on point1 at distance zval
			local D = vlineN * spoint 
			-- move all points to be in same plane -> eyepointsR[i]*vlineN == D
			-- but make the plane distance to origin == zval instead of D
			-- for i,pO in ipairs(eyepoints) do
				-- local ray = pO.normalize
				-- eyepointsR[i] = ray * (D/(vlineN*ray))
				-- centroid = centroid + eyepointsR[i]
			-- end
			local cent = vec3(0,0,0)
			for j=1,4 do
				local ind = plane.quad[j]
				local epoint = self.epoints[ind]
				local ray = epoint.normalize
				local old = self.epointsR[ind]
				self.epointsR[ind] = ray * (D/(vlineN*ray))
				centroid = centroid + self.epointsR[ind]
				cent = cent + self.epointsR[ind]
				if old then
					if (old - self.epointsR[ind]).norm > 1e-5 then
						print("---old-new plane:",i,j,(old - self.epointsR[ind]).norm)
						print(old, self.epointsR[ind] )
					end
				end
			end
			plane.frame.center = cent*0.25
		end
		
		self.centroid = centroid/(4*#self.planes)
		--self.frame.center = self.centroid
		--self.width = (eyepointsR[2]-eyepointsR[1]).norm
		--self.height = (eyepointsR[2]-eyepointsR[3]).norm
		
	end
	
	function PR:get_planev4(ii)
		local frame = PR.planes[ii].frame
		-- local Z = frame.Z
		-- local spp1 = PR.epointsR[quads[ii][1]]
		-- local D = spp1*Z
		-- local fac = 1
		-- if D > 0 then fac = -1 end
		-- local spplane = vec4(Z*fac,-D*fac)
		--print("------------------------------------------")
		--print("get_planev4 from quad",ii,spplane)
		return {X=frame.X,Y=frame.Y,Z=frame.Z,center=frame.center}
	end
	
	local function calcVline(eyepoints)
		--get vanishing points
		local l1 = eyepoints[1]:cross(eyepoints[2])
		local l2 = eyepoints[4]:cross(eyepoints[3])
		local vpointX = l1:cross(l2)
		vpointX = vpointX/vpointX.z

		l1 = eyepoints[1]:cross(eyepoints[4])
		l2 = eyepoints[2]:cross(eyepoints[3])
		local vpointY = l1:cross(l2)
		vpointY = vpointY/vpointY.z

		-- vanishing line
		local vline = vpointX:cross(vpointY)
		--if vline.z < 0 then vline = -vline end
		return vpointX, vpointY, vline
	end
	
	function PR:deletemesh(iplane,maker,imesh)
		self.Makers[maker]:deletemesh(imesh)
		--reindex PR.quad_meshes
		for is=1,#PR.planes do
			if PR.quad_meshes[is] then
				for k,spk in ipairs(PR.quad_meshes[is]) do
					local spknum = spk[1]
					local spkmaker = spk[2]
					if spkmaker == maker then
						if spknum > imesh then
							PR.quad_meshes[is][k] = {spknum-1,maker}
						elseif spknum == imesh then
							assert(is==iplane)
							table.remove(PR.quad_meshes[is],k)
						end
					end
				end
			end
		end
	end
	
	function PR:delete_plane(i)
		--delete quad_meshes
		for j,sp in ipairs(self.quad_meshes[i]) do
			local spnum = sp[1]
			local maker = sp[2]
			self:deletemesh(i,maker,spnum)
		end
		table.remove(self.planes,i)
		table.remove(self.quads,i)
		table.remove(self.quad_meshes,i)
		reconstruct()
	end
	
	function PR:reset_mesh(iplane,maker,imesh)
		local frame = PR:get_planev4(iplane)
		sppoints = {}
		for i,ind in ipairs(quads[iplane]) do
			local p = points[ind]
			sppoints[i] = vec2(p.x,p.y)
		end
		PR.Makers[maker]:resetmesh(imesh, frame, sppoints)
	end
	
	function PR:reset_planes()
		for i,quad in ipairs(PR.quads) do
			local frame = PR:get_planev4(i)
			for j,spl in ipairs(PR.quad_meshes[i]) do
				local splnum = spl[1]
				local splmaker = spl[2]
				PR.Makers[splmaker]:set_frame(frame,splnum)
			end
		end
	end
	
	function PR:Rectify()
		
		for i,quad in ipairs(self.quads) do
			local epoints = {}
			for j,ind in ipairs(quad) do
				local point = points[ind]
				epoints[j] = self:Viewport2Eye(point)
				self.epoints[ind] = epoints[j]
			end

			local vpointX, vpointY, vline = calcVline(epoints)
			local frame = {}
			frame.X = vpointX.normalize
			frame.Z = vline.normalize
            frame.Y = frame.Z:cross(frame.X).normalize
			
			local lvao 
			if self.planes[i] then
				lvao = self.planes[i].vao_lines
			else
				lvao = initVaos()
			end
			self.planes[i] = {frame = frame,
			quad = quad, vao_lines=lvao, vpointX = vpointX, vpointY=vpointY}
			self.quad_meshes[i] = self.quad_meshes[i] or {}
		end
		
	end
	function PR:Rectify2()
		self:set_pointsR()

		self.camMV = camera:MV()
		camMVinv = camera:MV().inv
		self.camMVinv = camMVinv
		camMPinv = camera:MP().inv
		camMP = camera:MP()
		camNear = camera.NMC.nearZ
		
		self:set_points_vao()
		
		--updatefunc(self)

	end
	
	function PR:save()
		local sav_points = {}
		for i,p in ipairs(points) do
			sav_points[i] = {p.x,p.y}
		end
		
		local pars = {sav_points=sav_points,quads=quads,VP={GL.W,GL.H},quad_meshes=PR.quad_meshes}
		pars.dial = NM:GetValues()
		pars.Makers = {}
		for i,m in ipairs(MakersG) do
			pars.Makers[i] = self.Makers[i]:save()
		end
		return pars
	end
	function PR:load(par)
		--print"rhomboidsH load"
		doupdate = false
		points = {}
		local VP = par.VP --or {GL.W,GL.H}
		for i,v in ipairs(par.sav_points) do
			v[1] = v[1]*GL.W/VP[1]
			v[2] = v[2]*GL.H/VP[2]
			points[i] = ig.ImVec2(v[1],v[2])
		end
		self.points = points
		quads = par.quads
		self.quads = quads
		--planes = {}
		self.planes = {} --planes
		self.quad_meshes = par.quad_meshes or {}
		NM:SetValues(par.dial or {})
		NM.vars.edit[0] = false
		self:Rectify()
		curr_plane = #self.planes > 0 and #self.planes or nil

		for i,m in ipairs(MakersG) do
			self.Makers[i]:deleteall()
		end

		if par.Makers then
		for i,m in ipairs(MakersG) do
			self.Makers[i]:load(par.Makers[i])
		end
		end
		--print"go to reconstruc--------------------"
		reconstruct()
		doupdate = true
	end
	
	GL:add_plugin(PR,"rhomboids")
	return PR
end 
---------------------------
--[=[
local GL = GLcanvas{W=800,viewH=600,aspect=1,aspectNO=1024/768,vsync=1}--DEBUG=true}


local camera = Camera(GL,"tps")--"lookat")
camera.NM.vars.dist[0] = 1.5
local MVinv = camera:MV().inv
local edit

local objects = {}
local DboxO = GL:DialogBox("objects",true)
local function makeObj(sp,MVinv,MVnor,iplane)
	local i,maker = sp[1],sp[2]
	local meshE,frame = edit.Makers[maker]:get_mesh(i)
	local meshW = meshE:clone()
	meshW:M4(MVinv)
	local gtex
--[[
	if NM.gentex then 
		gtex = MI:MeshRectify(meshE,true) 
	end
--]]

	local frame = mesh.move_frame(frame,MVinv)
	objects[maker] = objects[maker] or {}
	local object = objects[maker][i] 
	if not object then
		object = require"anima.Object3D"(GL,camera,{name="obj_"..maker.."_"..i})
		object:init()
		objects[maker][i] = object
		DboxO:add_dialog(object.NM)
	end
	object:setMesh(meshW,gtex, frame)
end
local function set_objects()
	print"set_objects"
	local MVinv = camera:MV().inv
	local MVnor = camera:MV().t
	for iplane,qm in ipairs(edit.quad_meshes) do
		for i,sp in ipairs(qm) do
			makeObj(sp,MVinv,MVnor,iplane)
		end
	end
end

local PShaper = require"Shapes"
local SP3D = require"Spline3D"
local MakersG = {PShaper,SP3D,names={"pshaper","sp3d"}}

edit = PlanesPicker(GL,camera,set_objects,MakersG)

local Dbox = GL:DialogBox("rectif")
Dbox:add_dialog(camera.NM)
Dbox:add_dialog(edit.NM)
-- GL.use_presets = true
function GL.init()
	--object = require"anima.Object3D"(GL,camera)
end
function GL.draw(t,w,h)
	ut.Clear()
	edit:draw(t,w,h)
	for im,mako in pairs(objects) do
		for i,o in ipairs(mako) do
			o:draw()
		end
	end
end
GL:start()
--]=]

return PlanesPicker