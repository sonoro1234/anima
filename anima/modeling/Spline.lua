
require"anima"
local vec2 = mat.vec2
local CG = require"anima.CG3"
----------------------shaders for making masks from spline
local vert_sh = [[
	in vec2 position;
	void main(){
		gl_Position = vec4(position,-1,1);
	}]]

local frag_sh = [[
	uniform vec4 color = vec4(1);
	void main(){
		gl_FragColor = color;
	}]]

local function mod(a,b)
	return ((a-1)%b)+1
end

local maskprog 

local function Editor(GL,updatefunc1,args)
	args = args or {}
	
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}
	
	local numsplines = 0
	M.sccoors = {}
	M.ps = {}
	M.triangulation = {}
	M.alpha = {}
	M.divs = {}
	--local updatefunc = updatefunc or function() end
	local updatefunc = function(E,...)
			if E.NM.curr_spline > 0 then
				E:triangulate(E.NM.curr_spline);
			end
			if updatefunc1 then updatefunc1(E, ...) end
	end
	
	local NM 
	local curr_hole = ffi.new("int[1]")
	
	local vars = {
	{"curr_spline",0,guitypes.valint,{min=0,max=numsplines},function() curr_hole[0] = 0 end},
	{"newspline",0,guitypes.button,function(this) 
		M:newspline() end},
	{"newhole",0,guitypes.button,function(this) 
		M:newhole() end,{sameline=true}},
	{"orientation",0,guitypes.button,function() M:change_orientation(); M:process_all() end},
	{"rotate",0,guitypes.button,function() M:rotate(); M:process_all() end,{sameline=true}},
	{"set_last",0,guitypes.toggle},
	{"clear spline",0,guitypes.button,function(this) 
			M:clearshape()
		end,
		{sameline=true}},
	{"delete spline",0,guitypes.button,function(this) 
			M:deletespline()
		end,
		{sameline=true}},
	{"points",1,guitypes.slider_enum,{"nil","set","edit","clear"}},
	}
	
	if args.region then table.insert(vars,{"drawregion",false,guitypes.toggle,function() updatefunc(M) end}) end
	
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
	local function PolyArrow(dl, points, numpoints, color)
		local lenh = 10
		local lena = 1/math.sqrt(3)
		for i=0,numpoints-2 do
			dl:AddLine(points[i],points[i+1],color)
			local vec = points[i] - points[i+1]
			vec = vec*(lenh/#vec)
			local veca = ig.ImVec2(vec.y,-vec.x)*lena
			local vecb = ig.ImVec2(-vec.y,vec.x)*lena
			dl:AddTriangleFilled(points[i+1], points[i+1] + vec + veca, points[i+1] + vec + vecb, color)
		end
		dl:AddLine(points[numpoints-1],points[0],color)
		local vec = points[numpoints-1] - points[0]
		vec = vec*(lenh/#vec)
		local veca = ig.ImVec2(vec.y,-vec.x)*lena
		local vecb = ig.ImVec2(-vec.y,vec.x)*lena
		dl:AddTriangleFilled(points[0], points[0] + vec + veca, points[0] + vec + vecb, color)
	end
	local function DrawTriangulation(dl, trian,color)
		--print"DrawTriangulation"
		local pointsI = {}
		for i=1,#trian.points do local p = trian.points[i];pointsI[i-1] = ViewportToScreen(p.x, p.y) end
		local tr = trian.tr
		for i=1,#tr,3 do dl:AddTriangleFilled(pointsI[tr[i]], pointsI[tr[i+1]], pointsI[tr[i+2]],color) end
	end
	local function ShowSplines(NM)
		--if numsplines==0 then return end
		--if NM.curr_spline == 0 then return end
		local igio = ig.GetIO()
		local mpos = igio.MousePos
		local dl = ig.GetBackgroundDrawList(ig.GetMainViewport())
		local keepflags = dl.Flags
		dl.Flags = bit.band(dl.Flags,bit.bnot(ig.lib.ImDrawListFlags_AntiAliasedLines))
		--points in curr_spline
		if NM.curr_spline > 0 then
		if curr_hole[0]>0 then
			for i,v in ipairs(M.sccoors[NM.curr_spline].holes[curr_hole[0]]) do
				local scpoint = ViewportToScreen(v.x,v.y)
				local color = i==1 and ig.U32(1,1,0,1) or ig.U32(1,0,0,1)
				dl:AddCircleFilled(scpoint, 4, color)
			end
		else
			for i,v in ipairs(M.sccoors[NM.curr_spline]) do
				local scpoint = ViewportToScreen(v.x,v.y)
				local color = i==1 and ig.U32(1,1,0,1) or ig.U32(1,0,0,1)
				dl:AddCircleFilled(scpoint, 4, color)
			end
		end
		end
		--polylines
		for i=1,numsplines do
			local color = i == NM.curr_spline and ig.U32(0.75,1,0,1) or ig.U32(0.75,1,0,0.2) --(0.25,0.5,0,0.5)
			local color2 = i == NM.curr_spline and ig.U32(0.75,1,0,0.1) or ig.U32(0.75,1,0,0.05) --(0.25,0.5,0,0.5)
			local colorhole = i == NM.curr_spline and ig.U32(1,0,0,1) or ig.U32(0.75,1,0,0.2) --(0.25,0.5,0,0.5)
			local pointsI = ffi.new("ImVec2[?]",#M.ps[i])
			for j,p in ipairs(M.ps[i]) do
				local scpoint = ViewportToScreen(p.x,p.y)
				pointsI[j-1] = scpoint
			end
			if NM.drawregion then
				--print"drawregion"
				if not M.triangulation[i] then M:triangulate(i) end
				DrawTriangulation(dl,M.triangulation[i],color2)
				--dl:AddConcavePolyFilled(pointsI,#M.ps[i],color2)
			end
			--dl:AddPolyline(pointsI, #M.ps[i], color, ig.lib.ImDrawFlags_Closed, 1)
			PolyArrow(dl, pointsI, #M.ps[i], color)
			if M.ps[i].holes then
				for j,hole in ipairs(M.ps[i].holes) do
					local pointsI = ffi.new("ImVec2[?]",#hole)
					for k,p in ipairs(hole) do
						local scpoint = ViewportToScreen(p.x,p.y)
						pointsI[k-1] = scpoint
					end
					--dl:AddPolyline(pointsI, #hole, colorhole, ig.lib.ImDrawFlags_Closed, 1)
					PolyArrow(dl, pointsI, #hole, colorhole)
				end
			end
		end
		if NM.curr_spline > 0 then
		if NM.points == 3 or NM.points == 4 then --edit or clear
			local mposvp = vec2(ScreenToViewport(mpos.x, mpos.y))
			if curr_hole[0] == 0 then
				for i,sc in ipairs(M.sccoors[NM.curr_spline]) do
					if (sc-mposvp):norm() < 5 then
						dl:AddCircleFilled(ViewportToScreen(sc.x,sc.y), 4, ig.U32(1,1,1,1))
					end
				end
			else
				local hole = M.sccoors[NM.curr_spline].holes[curr_hole[0]]
				for i,sc in ipairs(hole) do
					if (sc-mposvp):norm() < 5 then
						dl:AddCircleFilled(ViewportToScreen(sc.x,sc.y), 4, ig.U32(1,1,1,1))
					end
				end
			end
		end
		end
		dl.Flags = keepflags
	end
	--------import
	local function polyset_apply(polys, fun)
	for _, pol in ipairs(polys) do
		for j, v in ipairs(pol) do
			pol[j] = fun(v)
		end
		if pol.holes then
			for _, hole in ipairs(pol.holes) do
				for j, v in ipairs(hole) do
					hole[j] = fun(v)
				end
			end
		end
	end
end
local function center_polys(polys)
	local box = CG.box2d_polyset(polys)
	local dims = box[2] - box[1]
	local maxdim = dims.x > dims.y and dims.x or dims.y
	local maxview = math.max(GL.W, GL.H)
	local inv_maxdim = 0.9*maxview/maxdim
	local box_center = 0.5 * (box[2] + box[1])
	--print("center polis", box, dims, box_center, maxdim, maxview)
	polyset_apply(polys, function(v) return v - box_center end)
	polyset_apply(polys, function(v) return v * inv_maxdim end)
	polyset_apply(polys, function(v) return v + vec2(GL.W*0.5, GL.H*0.5) end)
end
local function load_polyset( filename)
		local func,err = loadfile(filename)
		if not func then print(err); error();return end
		local params = func()
		numsplines = #params
		center_polys(params)
		M.sccoors = params
		M.alpha = {}
		for i=1,numsplines do M.alpha[i] = ffi.new("float[1]",0.5) end
		M.divs = {}
		for i=1,numsplines do M.divs[i] = ffi.new("int[1]",1) end
		M.ps = {}
		NM.defs.curr_spline.args.max=numsplines
		NM.vars.points[0]=1 --no edit acction
		NM.vars.curr_spline[0] = 1
		M:calc_all_splines()

end

local polyloader = gui.FileBrowser(nil,{filename="phfx",key="import",pattern="polyset"},load_polyset)
	-----------------
	
	local doingedit = false
	NM = gui.Dialog("spline",vars,function(this)
		local NM = this
		--if numsplines==0 then return end
		local igio = ig.GetIO()
		local mpos = igio.MousePos
		local mposvp = vec2(ScreenToViewport(mpos.x, mpos.y))
		if NM.curr_spline == 0 then goto SHOW end
		
		if ig.SliderFloat("alpha",M.alpha[NM.curr_spline],0,1) then
			M:process_all()
		end
		if ig.SliderInt("divs",M.divs[NM.curr_spline],1,30) then
			M:process_all()
		end
		
		if M.sccoors[NM.curr_spline].holes then
		ig.SliderInt("curr_hole",curr_hole,0, #M.sccoors[NM.curr_spline].holes) 
		end
		

		
		if NM.set_last then
			if igio.MouseClicked[0] then
				local touched = -1
				if curr_hole[0] == 0 then
					for i,v in ipairs(M.sccoors[NM.curr_spline]) do
						local vec = v - mposvp
						if (vec:norm()) < 5 then touched = i; break end
					end
				else
					local hole = M.sccoors[NM.curr_spline].holes[curr_hole[0]]
					for i,v in ipairs(hole) do
						local vec = v - mposvp
						if (vec:norm()) < 5 then touched = i; break end
					end
				end
				if touched > 0 then
					M:set_last(touched)
					--M:process_all()
					NM.vars.set_last[0] = false
				end
			end
			goto SHOW
		end
		if this.points == 1 then goto SHOW end
		ig.SetMouseCursor(ig.lib.ImGuiMouseCursor_Hand);
		if this.points == 2 then --set
			if igio.MouseClicked[0] and not igio.MouseDownOwned[0] then
				if curr_hole[0]==0 then
					table.insert(M.sccoors[NM.curr_spline],mposvp)
				else
					table.insert(M.sccoors[NM.curr_spline].holes[curr_hole[0]],mposvp)
				end
				updatefunc(M,"insert")
				M:calc_spline()
				if M:numpoints(ii)>2 then updatefunc(M) end
			end
			
		elseif this.points == 3 then --edit
			if doingedit then
				if curr_hole[0] == 0 then
					M.sccoors[NM.curr_spline][doingedit] = mposvp
				else
					M.sccoors[NM.curr_spline].holes[curr_hole[0]][doingedit] = mposvp
				end
				M:process_all()
				if igio.MouseReleased[0] then
					doingedit = false
				end
			elseif igio.MouseClicked[0] and not igio.MouseDownOwned[0] then
				local touched = -1
				if curr_hole[0] == 0 then
					for i,v in ipairs(M.sccoors[NM.curr_spline]) do
						local vec = v - mposvp
						if (vec:norm()) < 5 then touched = i; break end
					end
				else
					local hole = M.sccoors[NM.curr_spline].holes[curr_hole[0]]
					for i,v in ipairs(hole) do
						local vec = v - mposvp
						if (vec:norm()) < 5 then touched = i; break end
					end
				end
				if touched > 0 then doingedit = touched end
			end
		elseif this.points == 4 then --clear
			if igio.MouseClicked[0] then
				local touched = -1
				if curr_hole[0] == 0 then
					for i,v in ipairs(M.sccoors[NM.curr_spline]) do
						local vec = v - mposvp
						if (vec:norm()) < 5 then touched = i; break end
					end
					if touched > 0 then
						table.remove(M.sccoors[NM.curr_spline],touched)
						M:process_all()
					end
				else
					local hole = M.sccoors[NM.curr_spline].holes[curr_hole[0]]
					for i,v in ipairs(hole) do
						local vec = v - mposvp
						if (vec:norm()) < 5 then touched = i; break end
					end
					if touched > 0 then
						table.remove(hole,touched)
						M:process_all()
					end
				end
			end
		end
		::SHOW::
		if ig.SmallButton("import polyset") then
			polyloader.open()
		end
		polyloader.draw()
		ShowSplines(this)
	end)

	M.NM = NM
	NM.plugin = M
	
	function M:init()
		if not maskprog then
			maskprog = GLSL:new():compile(vert_sh,frag_sh)
		end
	end
	
	function M:spline2mask(fbo, front_color, ii)
		ii = ii or NM.curr_spline
		
		local points = self.ps[ii]
		if not points then print"No Spline:select spline" return end
		local points,indexes = CG.EarClipSimple2(points, true)
		local ndc = {}
		for i=1,#points do
			ndc[i] =  (points[i] + mat.vec2(0.5,0.5))*2/mat.vec2(GL.W,GL.H) - mat.vec2(1,1)
		end
		
		local vaoT = VAO({position=ndc},maskprog,indexes)
		maskprog:use()
		maskprog.unif.color:set(front_color)
		fbo:Bind()
		ut.ClearDepth()
		gl.glDisable(glc.GL_DEPTH_TEST)
		fbo:viewport()
		vaoT:draw_elm()
		vaoT:draw(glc.GL_LINE_LOOP)
		vaoT:draw(glc.GL_POINTS)
		fbo:UnBind()
	end
	
	local function box2d(points)
		local floor = math.floor
	
		local function round(x)
			return floor(x+0.5)
		end
		local minx,maxx,miny,maxy = math.huge,-math.huge,math.huge,-math.huge
		for i,p in ipairs(points) do
			minx = p.x < minx and p.x or minx
			maxx = p.x > maxx and p.x or maxx
			miny = p.y < miny and p.y or miny
			maxy = p.y > maxy and p.y or maxy
		end
		return {vec2(round(minx),round(miny)),vec2(round(maxx),round(maxy))}
	end
	
	function M:box2d(ii)
		ii = ii or NM.curr_spline
		return box2d(self.ps[ii])
	end
	
	function M:newspline(pts, dontcalc)
		numsplines=numsplines+1;
		NM.vars.curr_spline[0]=numsplines 
		NM.defs.curr_spline.args.max=numsplines 
		M:clearshape()
		if pts then
			for i,p in ipairs(pts) do
				self.sccoors[NM.curr_spline][i] = p
			end
			--dontcalc used in Spline3D before setting frame
			if not dontcalc then M:calc_spline() end
		end
		--M:process_all()
		return numsplines
	end
	
	function M:newhole(pts)
		if NM.curr_spline==0 then return end
		self.sccoors[NM.curr_spline].holes = self.sccoors[NM.curr_spline].holes or {}
		table.insert(self.sccoors[NM.curr_spline].holes,{})
		curr_hole[0] = #self.sccoors[NM.curr_spline].holes
		if pts then
			local hole = self.sccoors[NM.curr_spline].holes[curr_hole[0]]
			for i,p in ipairs(pts) do
				hole[i] = p
			end
		end
	end
	
	function M:set_current(i)
		self.NM.vars.curr_spline[0] = i
		curr_hole[0] = math.min(curr_hole[0],self.sccoors[i].holes and #self.sccoors[i].holes or 0)
	end
	
	function M:external_control(yes)
		NM.defs.curr_spline.invisible = yes
		NM.defs.newspline.invisible = yes
	end
	
	function M:deletespline(ii)
		ii = ii or NM.curr_spline
		if ii > numsplines then return numsplines end
		table.remove(M.sccoors,ii)
		table.remove(M.ps,ii)
		table.remove(M.alpha,ii)
		table.remove(M.divs,ii)
		numsplines=numsplines-1;
		NM.vars.curr_spline[0]=numsplines 
		NM.defs.curr_spline.args.max=numsplines 
		--M:process_all()
		return numsplines
	end
	
	function M:deleteall()
		for i=#M.sccoors,1,-1 do
			self:deletespline(i)
		end
	end
	
	function M:clearshape()
		if NM.curr_spline==0 then return end
		curr_hole[0] = 0
		self.sccoors[NM.curr_spline] = {}
		self.ps[NM.curr_spline] = {}
		M.alpha[NM.curr_spline] = ffi.new("float[1]",0.5)
		M.divs[NM.curr_spline] = ffi.new("int[1]",1)
	end
	
	
	function M:process_all()
		M:calc_spline()
		if M:numpoints()>2 then updatefunc(self) end
	end
	function M:numpoints(ind)
		ind = ind or NM.curr_spline
		return self.sccoors[ind] and #self.sccoors[ind] or 0
	end
	
	local floor = math.floor
	local function reverse(t)
		local s = #t+1
		for i=1,floor(#t/2) do
			t[i],t[s-i] = t[s-i],t[i]
		end
		return t
	end
	function M:change_orientation()
		if NM.curr_spline == 0 then return end
		local sc
		if curr_hole[0] == 0 then
			sc = self.sccoors[NM.curr_spline]
		else
			sc = self.sccoors[NM.curr_spline].holes[curr_hole[0]]
		end
		reverse(sc)
	end
	
	function M:rotate()
		if NM.curr_spline == 0 then return end
		local sc
		if curr_hole[0] == 0 then
			sc = self.sccoors[NM.curr_spline]
		else
			sc = self.sccoors[NM.curr_spline].holes[curr_hole[0]]
		end
		local first = table.remove(sc,1)
		table.insert(sc,first)
	end
	
	function M:set_last(ind)
		if NM.curr_spline == 0 then return end
		if curr_hole[0] == 0 then
			if ind == #self.sccoors[NM.curr_spline] then return end
			local sc,nsc = self.sccoors[NM.curr_spline],{}
			local first = mod(ind+1,#sc)
			for i=first,#sc do
				nsc[#nsc + 1] = sc[i]
			end
			for i=1,ind do
				nsc[#nsc + 1] = sc[i]
			end
			self.sccoors[NM.curr_spline] = nsc
		else
			local sc,nsc = self.sccoors[NM.curr_spline].holes[curr_hole[0]],{}
			local first = mod(ind+1,#sc)
			for i=first,#sc do
				nsc[#nsc + 1] = sc[i]
			end
			for i=1,ind do
				nsc[#nsc + 1] = sc[i]
			end
			self.sccoors[NM.curr_spline].holes[curr_hole[0]] = nsc
		end
	end
	
	function M:calc_spline(ii)
		ii = ii or NM.curr_spline
		if self:numpoints(ii)>2 then
			self.ps[ii] = CG.Spline(self.sccoors[ii],M.alpha[ii][0],M.divs[ii][0],true)
			if self.sccoors[ii].holes then
				self.ps[ii].holes = {}
				for i,hole in ipairs(self.sccoors[ii].holes) do
					if #hole > 2 then
						self.ps[ii].holes[i] = CG.Spline(hole,M.alpha[ii][0],M.divs[ii][0],true)
					end
				end
			end
		end
	end
	function M:calc_all_splines()
		for i=1,numsplines do
			self:calc_spline(i)
		end
		updatefunc(self)
	end
	
	function M:triangulate(ii)
		print("triangulate",ii)
		if #self.ps[ii] < 3 then return end
		local good
		self.triangulation[ii] = {}
		self.triangulation[ii].points, self.triangulation[ii].tr, good = CG.EarClipSimple2(self.ps[ii],true)
		if not good then print"bad EarClip" end
		--return indexes,good
	end
	
	function M:save()
		local pars = {sccoors=self.sccoors,VP={GL.W,GL.H}}
		pars.alpha = self.alpha
		pars.divs = self.divs
		pars.dial = NM:GetValues()
		pars.numsplines = numsplines
		return pars
	end
	function M:load(params)
		if not params then return end
		for j,sc in ipairs(params.sccoors) do
			for i,v in ipairs(sc) do
				sc[i] = v/vec2(params.VP[1]/GL.W, params.VP[2]/GL.H)
			end
			if sc.holes then
				for k,hole in ipairs(sc.holes) do
					for l,v in ipairs(hole) do
						hole[l] = v/vec2(params.VP[1]/GL.W, params.VP[2]/GL.H)
					end
				end
			end
		end
		NM:SetValues(params.dial or {})
		M.sccoors = params.sccoors
		M.alpha = params.alpha
		M.divs = params.divs
		M.ps = {}
		-- for j,sc in ipairs(params.sccoors) do
			-- NM.vars.curr_spline[0] = j
			-- self:process_all()
		-- end
		numsplines = params.numsplines
		NM.defs.curr_spline.args.max=numsplines
		NM.vars.points[0]=1 --no edit acction
		NM.vars.curr_spline[0] = 1
		M:calc_all_splines()
	end
	M.draw = function() end --dummy value for plugin
	--M:clearshape()
	GL:add_plugin(M,"spliner")
	return M
end

--[=[
local GL = GLcanvas{H=800,aspect=1,DEBUG=true,use_imgui_viewport=false}
local function update(n) print("update spline",n) end
local edit = Editor(GL,update,{region=true})--,doblend=true})
local plugin = require"anima.plugins.plugin"
edit.fb = plugin.serializer(edit)
local DBox = GL:DialogBox("Spline demo",true)
function GL.init()
	DBox:add_dialog(edit.NM)
end
function GL.imgui()
	--ig.ShowDemoWindow()
	--edit.NM:draw()
end
GL:start()
--]=]

return Editor