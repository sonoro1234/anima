
require"anima"
local vec2 = mat.vec2


local function mod(a,b)
	return ((a-1)%b)+1
end

--this version allows identical points
local function CatmulRom(p0,p1,p2,p3,ps,alpha,amountOfPoints,last)

	local function GetT( t,  p0,  p1,alpha)
	    local a = math.pow((p1.x-p0.x), 2.0) + math.pow((p1.y-p0.y), 2.0);
	    local b = math.pow(a, 0.5);
	    local c = math.pow(b, alpha);
	   
	    return (c + t);
	end
	
	local t0 = 0.0;
	local t1 = GetT(t0, p0, p1, alpha);
	local t2 = GetT(t1, p1, p2, alpha);
	local t3 = GetT(t2, p2, p3, alpha);
	
	--print(t0,t1,t2,t3)
	local range = last and amountOfPoints or (amountOfPoints - 1)
	
	--special cases
	local A1s,A3s
	if p1==p2 then
		for i=0,range do ps[#ps + 1] = p1 end
		return
	end
	if p0==p1 then A1s = p0 end
	if p2==p3 then A3s = p2 end
	
	local inc = (t2-t1)/amountOfPoints
	for i=0,range do
		local t = t1 + inc*i
	--for t=t1; t<t2; t+=((t2-t1)/amountOfPoints))
	    local A1 = A1s or (t1-t)/(t1-t0)*p0 + (t-t0)/(t1-t0)*p1;
	    local A2 = (t2-t)/(t2-t1)*p1 + (t-t1)/(t2-t1)*p2;
	    local A3 = A3s or (t3-t)/(t3-t2)*p2 + (t-t2)/(t3-t2)*p3;

	    local B1 = (t2-t)/(t2-t0)*A1 + (t-t0)/(t2-t0)*A2;
	    local B2 = (t3-t)/(t3-t1)*A2 + (t-t1)/(t3-t1)*A3;

	    local C = (t2-t)/(t2-t1)*B1 + (t-t1)/(t2-t1)*B2;
	   -- print(C)
	    ps[#ps + 1] = C
	end
end

local function Spline(points,alpha,amountOfPoints,closed)
	--print("Spline alpha",alpha)
	local ps = {}
	local i0,i1,i2,i3
	if closed then
		if #points < 3 then return ps end
		for i=1,#points-3 do
			CatmulRom(points[i],points[i+1],points[i+2],points[i+3],ps,alpha,amountOfPoints)
		end
		CatmulRom(points[#points-2],points[#points-1],points[#points],points[1],ps,alpha,amountOfPoints)
		CatmulRom(points[#points-1],points[#points],points[1],points[2],ps,alpha,amountOfPoints)
		CatmulRom(points[#points],points[1],points[2],points[3],ps,alpha,amountOfPoints,true)
		ps[#ps] = nil --delete repeated
	else
		if #points < 4 then return ps end
		for i=1,#points-4 do
			CatmulRom(points[i],points[i+1],points[i+2],points[i+3],ps,alpha,amountOfPoints)
		end
		local i = #points-3
		CatmulRom(points[i],points[i+1],points[i+2],points[i+3],ps,alpha,amountOfPoints,true)
	end
	return ps
end


local function Editor(GL,updatefunc,args)
	args = args or {}
	updatefunc = updatefunc or function() end
	
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}
	
	local numsplines = 1
	M.sccoors = {}
	M.ps = {}
	M.good_indexes = {}
	M.alpha = {}
	M.divs = {}
	
	local NM 
	
	local vars = {
	{"newspline",0,guitypes.button,function(this) 
		numsplines=numsplines+1;
		this.vars.curr_spline[0]=numsplines 
		this.defs.curr_spline.args.max=numsplines 
		M:newshape() end},
	{"orientation",0,guitypes.button,function() M:change_orientation(); M:process_all() end,{sameline=true}},
	{"set_last",0,guitypes.toggle},
	{"clear spline",0,guitypes.button,function(this) 
			M:newshape()
		end,
		{sameline=true}},
	{"curr_spline",1,guitypes.valint,{min=1,max=numsplines}},
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
		local igio = ig.GetIO()
		local mpos = igio.MousePos
		local dl = ig.GetBackgroundDrawList()
		local keepflags = dl.Flags
		dl.Flags = bit.band(dl.Flags,bit.bnot(ig.lib.ImDrawListFlags_AntiAliasedLines))
		for i,v in ipairs(M.sccoors[NM.curr_spline]) do
			local scpoint = ViewportToScreen(v.x,v.y)
			local color = i==1 and ig.U32(1,1,0,1) or ig.U32(1,0,0,1)
			dl:AddCircleFilled(scpoint, 4, color)
		end
		for i=1,numsplines do
			local pointsI = ffi.new("ImVec2[?]",#M.ps[i])
			for j,p in ipairs(M.ps[i]) do
				local scpoint = ViewportToScreen(p.x,p.y)
				pointsI[j-1] = scpoint
			end
			dl:AddPolyline(pointsI,#M.ps[i],ig.U32(1,1,0,1),true, 1)
		end
		dl.Flags = keepflags
	end
	
	local doingedit = false
	NM = GL:Dialog("spline",vars,function(this)
		local NM = this
		
		if ig.SliderFloat("alpha",M.alpha[NM.curr_spline],0,1) then
			M:process_all()
		end
		if ig.SliderInt("divs",M.divs[NM.curr_spline],1,30) then
			M:process_all()
		end
		
		local igio = ig.GetIO()
		local mpos = igio.MousePos
		local mposvp = vec2(ScreenToViewport(mpos.x, mpos.y))
		
		if NM.set_last then
			if igio.MouseClicked[0] then
				local touched = -1
				for i,v in ipairs(M.sccoors[NM.curr_spline]) do
					local vec = v - mposvp
					if (vec.norm) < 3 then touched = i; break end
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
				table.insert(M.sccoors[NM.curr_spline],mposvp)
				M:calc_spline()
				updatefunc(M)
			end
		elseif this.points == 3 then --edit
			if doingedit then
				M.sccoors[NM.curr_spline][doingedit] = mposvp
				M:process_all()
				if igio.MouseReleased[0] then
					doingedit = false
				end
			elseif igio.MouseClicked[0] and not igio.MouseDownOwned[0] then
				local touched = -1
				for i,v in ipairs(M.sccoors[NM.curr_spline]) do
					local vec = v - mposvp
					if (vec.norm) < 3 then touched = i; break end
				end
				if touched > 0 then doingedit = touched end
			end
		elseif this.points == 4 then --clear
			if igio.MouseClicked[0] then
				local touched = -1
				for i,v in ipairs(M.sccoors[NM.curr_spline]) do
					local vec = v - mposvp
					if (vec.norm) < 3 then touched = i; break end
				end
				if touched > 0 then
					table.remove(M.sccoors[NM.curr_spline],touched)
					M:process_all()
				end
			end
		end
		::SHOW::
		ShowSplines(this)
	end)

	M.NM = NM
	NM.plugin = M


	function M:newshape()
		self.sccoors[NM.curr_spline] = {}
		self.ps[NM.curr_spline] = {}
		M.good_indexes[NM.curr_spline] = true
		M.alpha[NM.curr_spline] = ffi.new("float[1]",0.5)
		M.divs[NM.curr_spline] = ffi.new("int[1]",3)
	end
	
	
	function M:process_all()
		-- local scoorsO = self.sccoors[NM.curr_spline] 
		-- self:newshape()
		-- for i,v in ipairs(scoorsO) do
			-- table.insert(self.sccoors[NM.curr_spline],v)
		-- end
		M:calc_spline()
		updatefunc(self)
	end
	function M:numpoints(ind)
		ind = ind or NM.curr_spline
		return #self.sccoors[ind]
	end

	function M:change_orientation()
		local sc,nsc = self.sccoors[NM.curr_spline],{}
		for i=#sc,1,-1 do
			nsc[#nsc + 1] = sc[i]
		end
		self.sccoors[NM.curr_spline] = nsc
	end
	function M:set_last(ind)
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
	end
	
	function M:calc_spline(ii)
		ii = ii or NM.curr_spline
		if #self.sccoors[ii] > 0 then
		if self:numpoints()>2 then
			self.ps[ii] = Spline(self.sccoors[ii],M.alpha[ii][0],M.divs[ii][0],true)
		end
		end
	end
	function M:set_all_splines()
		for i=1,numsplines do
			self:calc_spline(i)
		end
		updatefunc(self)
	end
	local CG = require"anima.CG3"
	function M:triangulate(ii)
		local indexes
		indexes,self.good_indexes[ii] = CG.EarClipSimple(self.ps[ii])
	end
	
	function M:save()
		local pars = {sccoors=self.sccoors,VP={GL.W,GL.H}}
		pars.dial = NM:GetValues()
		pars.numsplines = numsplines
		return pars
	end
	function M:load(params)
		if not params then return end
		for j,sc in ipairs(params.sccoors) do
		for i,v in ipairs(sc) do
			sc[i] = v/vec2(GL.W/params.VP[1],GL.H/params.VP[2])
		end
		end
		NM:SetValues(params.dial or {})
		M.sccoors = params.sccoors
		for j,sc in ipairs(params.sccoors) do
			NM.vars.curr_spline[0] = j
			self:process_all()
		end
		numsplines = params.numsplines
		NM.defs.curr_spline.args.max=numsplines
		NM.vars.points[0]=1 --no edit acction
	end
	M.draw = function() end --dummy value for plugin
	M:newshape()
	return M
end

--[=[
local GL = GLcanvas{H=500,aspect=1,DEBUG=true}
--local camara = newCamera(GL,"ident")
local function update(n) print("update spline",n) end
local edit = Editor(GL,update,{region=false})--,doblend=true})
local plugin = require"anima.plugins.plugin"
edit.fb = plugin.serializer(edit)
--GL.use_presets = true

GL:start()
--]=]

return Editor