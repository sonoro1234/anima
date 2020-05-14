
require"anima"
local vec2 = mat.vec2
local CG = require"anima.CG3"

local function mod(a,b)
	return ((a-1)%b)+1
end



local function Editor(GL,updatefunc,args)
	args = args or {}
	updatefunc = updatefunc or function() end
	
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}
	
	local numsplines = 0
	M.sccoors = {}
	M.ps = {}
	M.alpha = {}
	M.divs = {}
	
	local NM 
	local curr_hole = ffi.new("int[1]")
	
	local vars = {
	{"curr_spline",0,guitypes.valint,{min=1,max=numsplines},function() curr_hole[0] = 0 end},
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
	{"points",1,guitypes.slider_enum,{"nil","set","edit","clear"}},
	}
	
	if args.region then table.insert(vars,{"drawregion",false,guitypes.toggle,function() updatefunc(M) end}) end
	
	--for converting from window coordinates to GL.fbo coordinates
	--from imgui inverted Y
	local function ScreenToViewport(X,Y)
		local sw,sh = GL:getWindowSize()
		local x,y,w,h = unpack(GL.stencil_sizes)
		return GL:ScreenToViewport(X,sh-Y)
	end
	local function ViewportToScreen(X,Y)
		local sw,sh = GL:getWindowSize()
		local x,y,w,h = unpack(GL.stencil_sizes)
		local X1,Y1 = GL:ViewportToScreen(X,Y)
		return ig.ImVec2(X1,sh-Y1)
	end
	local function ShowSplines(NM)
		--if numsplines==0 then return end
		local igio = ig.GetIO()
		local mpos = igio.MousePos
		local dl = ig.GetBackgroundDrawList()
		local keepflags = dl.Flags
		dl.Flags = bit.band(dl.Flags,bit.bnot(ig.lib.ImDrawListFlags_AntiAliasedLines))
		--points in curr_spline
		for i,v in ipairs(M.sccoors[NM.curr_spline]) do
			local scpoint = ViewportToScreen(v.x,v.y)
			local color = i==1 and ig.U32(1,1,0,1) or ig.U32(1,0,0,1)
			dl:AddCircleFilled(scpoint, 4, color)
		end
		if curr_hole[0]>0 then
			for i,v in ipairs(M.sccoors[NM.curr_spline].holes[curr_hole[0]]) do
				local scpoint = ViewportToScreen(v.x,v.y)
				local color = i==1 and ig.U32(1,1,0,1) or ig.U32(1,0,0,1)
				dl:AddCircleFilled(scpoint, 4, color)
			end
		end
		--polylines
		for i=1,numsplines do
			local color = i == NM.curr_spline and ig.U32(0.5,1,0,1) or ig.U32(0.25,0.5,0,1)
			local pointsI = ffi.new("ImVec2[?]",#M.ps[i])
			for j,p in ipairs(M.ps[i]) do
				local scpoint = ViewportToScreen(p.x,p.y)
				pointsI[j-1] = scpoint
			end
			dl:AddPolyline(pointsI,#M.ps[i],color,true, 1)
			if M.ps[i].holes then
				for j,hole in ipairs(M.ps[i].holes) do
					local pointsI = ffi.new("ImVec2[?]",#hole)
					for k,p in ipairs(hole) do
						local scpoint = ViewportToScreen(p.x,p.y)
						pointsI[k-1] = scpoint
					end
					dl:AddPolyline(pointsI,#hole,color,true, 1)
				end
			end
		end
		if NM.points == 3 or NM.points == 4 then --edit or clear
			local mposvp = vec2(ScreenToViewport(mpos.x, mpos.y))
			if curr_hole[0] == 0 then
				for i,sc in ipairs(M.sccoors[NM.curr_spline]) do
					if (sc-mposvp).norm < 5 then
						dl:AddCircleFilled(ViewportToScreen(sc.x,sc.y), 4, ig.U32(1,1,1,1))
					end
				end
			else
				local hole = M.sccoors[NM.curr_spline].holes[curr_hole[0]]
				for i,sc in ipairs(hole) do
					if (sc-mposvp).norm < 5 then
						dl:AddCircleFilled(ViewportToScreen(sc.x,sc.y), 4, ig.U32(1,1,1,1))
					end
				end
			end
		end
		dl.Flags = keepflags
	end
	
	local doingedit = false
	NM = gui.Dialog("spline",vars,function(this)
		local NM = this
		if numsplines==0 then return end
		
		if ig.SliderFloat("alpha",M.alpha[NM.curr_spline],0,1) then
			M:process_all()
		end
		if ig.SliderInt("divs",M.divs[NM.curr_spline],1,30) then
			M:process_all()
		end
		
		if M.sccoors[NM.curr_spline].holes then
		ig.SliderInt("curr_hole",curr_hole,0, #M.sccoors[NM.curr_spline].holes) 
		end
		
		local igio = ig.GetIO()
		local mpos = igio.MousePos
		local mposvp = vec2(ScreenToViewport(mpos.x, mpos.y))
		
		if NM.set_last then
			if igio.MouseClicked[0] then
				local touched = -1
				if curr_hole[0] == 0 then
					for i,v in ipairs(M.sccoors[NM.curr_spline]) do
						local vec = v - mposvp
						if (vec.norm) < 5 then touched = i; break end
					end
				else
					local hole = M.sccoors[NM.curr_spline].holes[curr_hole[0]]
					for i,v in ipairs(hole) do
						local vec = v - mposvp
						if (vec.norm) < 5 then touched = i; break end
					end
				end
				if touched > 0 then
					M:set_last(touched)
					M:process_all()
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
						if (vec.norm) < 5 then touched = i; break end
					end
				else
					local hole = M.sccoors[NM.curr_spline].holes[curr_hole[0]]
					for i,v in ipairs(hole) do
						local vec = v - mposvp
						if (vec.norm) < 5 then touched = i; break end
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
						if (vec.norm) < 5 then touched = i; break end
					end
					if touched > 0 then
						table.remove(M.sccoors[NM.curr_spline],touched)
						M:process_all()
					end
				else
					local hole = M.sccoors[NM.curr_spline].holes[curr_hole[0]]
					for i,v in ipairs(hole) do
						local vec = v - mposvp
						if (vec.norm) < 5 then touched = i; break end
					end
					if touched > 0 then
						table.remove(hole,touched)
						M:process_all()
					end
				end
			end
		end
		::SHOW::
		ShowSplines(this)
	end)

	M.NM = NM
	NM.plugin = M
	
	
	function M:newspline(pts)
		numsplines=numsplines+1;
		NM.vars.curr_spline[0]=numsplines 
		NM.defs.curr_spline.args.max=numsplines 
		M:clearshape()
		if pts then
			for i,p in ipairs(pts) do
				self.sccoors[NM.curr_spline][i] = p
			end
		end
		--M:process_all()
		return numsplines
	end
	
	function M:newhole()
		if NM.curr_spline==0 then return end
		self.sccoors[NM.curr_spline].holes = self.sccoors[NM.curr_spline].holes or {}
		table.insert(self.sccoors[NM.curr_spline].holes,{})
		curr_hole[0] = #self.sccoors[NM.curr_spline].holes
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
		if ii > numsplines then return numsplines end
		ii = ii or NM.curr_spline
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
		local indexes,good = CG.EarClipSimple2(self.ps[ii])
		return indexes,good
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
				sc[i] = v/vec2(params.VP[1]/GL.W,params.VP[2]/GL.H)
			end
			if sc.holes then
				for k,hole in ipairs(sc.holes) do
					for l,v in ipairs(hole) do
						hole[l] = v/vec2(params.VP[1]/GL.W,params.VP[2]/GL.H)
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
	return M
end

--[=[
local GL = GLcanvas{H=500,aspect=1,DEBUG=true}
local function update(n) print("update spline",n) end
local edit = Editor(GL,update,{region=false})--,doblend=true})
local plugin = require"anima.plugins.plugin"
edit.fb = plugin.serializer(edit)
function GL.imgui()
	edit.NM:draw()
end
GL:start()
--]=]

return Editor