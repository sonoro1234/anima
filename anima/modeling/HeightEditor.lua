require"anima"


local function mod(a,b)
	return ((a-1)%b)+1
end

local function HeightEditor(GL,updatefunc)
	updatefunc = updatefunc or function() end
	local M = {psor={},ps={}}
	
	local SPLINEDIRTY = true
	local NM = gui.Dialog("Height",
	{
	{"op",1,guitypes.slider_enum,{"curve","tube","poly"},function(val) M:process() end},
	{"zplane",0,guitypes.val,{min=-20,max=0}, function() M:set_zplane();M:process() end },
	{"height",0,guitypes.val,{min=-1,max=1},function(val) M:process() end},
	{"alpha",1,guitypes.drag,{min=0,max=6},function() M:process() end},
	{"proy_height",false,guitypes.toggle,function() M:process() end},
	{"curves",1,guitypes.slider_enum,{"line","circle","pow"},function() M:process() end},
	{"grid",3,guitypes.valint,{min=1,max=30},function() M:process() end},
	})


	local vec3 = mat.vec3
	function M:set_spline(ps) 
		M.psor = {}
		for i,pt in ipairs(ps) do
			M.psor[i] = vec3(pt.x,pt.y,pt.z)
		end
		M:set_zplane()
		SPLINEDIRTY = true
		M:process()
	end
	
	function M:set_zplane()
		local fac = NM.zplane==0 and 1 or -NM.zplane
		M.ps = {}
		for i,pt in ipairs(M.psor) do
			M.ps[i] = fac*pt
		end
	end

	M.NM = NM

	
	local CG = require"anima.CG3" 
		
	local CDTinsertion = CG.CDTinsertion
	local heights = {}
	local Plength = 0
	local maxh = 0
	local function HeightSet(P,Pol)
		if NM.height == 0 then return end
		local function dist2seg(a,b,c)
			local ac = (c - a).xy
			local bc = (c - b).xy
			local ab = (b - a).xy
			
			local scosa = ab*ac
			local scosb = -ab*bc
			if scosa < 0 or scosb < 0 then --angulo obtuso cogemos la menor
				local dista = ac.norm
				local distb = bc.norm
				return (dista < distb) and dista or distb
			else --angulos agudos distancia punto recta
				local abn = ab.normalize
				abn = mat.vec2(-abn.y,abn.x)
				return math.abs(abn*ac)
			end
		end
		if SPLINEDIRTY or #P~=Plength then
			--print("DIRT",not SPLINEDIRTY , #P~=Plength)
			Plength = #P
			heights = {}
			for i=1,#P do
				local p = P[i]
				heights[i] = math.huge
				for j=1,#Pol do
					local a = P[Pol[j]]
					local b = P[Pol[mod(j+1,#Pol)]]
	
					local dis = dist2seg(a,b,p)
					heights[i] = (dis < heights[i]) and dis or heights[i]
				end
			end
			maxh = 0
			for i,v in ipairs(heights) do
				maxh = (v > maxh) and v or maxh
			end
			for i,v in ipairs(heights) do
				heights[i] = v / maxh
				if not (heights[i]>=0 and heights[i]<=1) then
					print("heights[i]",i,heights[i])
				end
			end
			local minhe,maxhe = math.huge,-math.huge
			for i,v in ipairs(heights) do
				minhe = minhe < heights[i] and minhe or heights[i]
				maxhe = maxhe > heights[i] and maxhe or heights[i]
			end
			print("minhe,maxhe",minhe,maxhe)
		end
		SPLINEDIRTY = false
		local sqrt,pow = math.sqrt, math.pow
		local NMheight = NM.height
		local alpha = NM.alpha
		for i,he in ipairs(heights) do
			local alt 
			if NM.curves==1 then
				alt = he
			elseif NM.curves==2 then
				--alt = NM.height*sqrt(1-(1-he)^2)
				alt = sqrt(he*(2-he))
			else --3
				alt = pow(he,alpha)
			end
			alt = NMheight*alt
			if NM.proy_height then
				P[i] = P[i]/P[i].z*(NM.zplane+alt)
			else
				P[i].z = NM.zplane  + alt
			end
		end
	end
	
	function M:process()
		if NM.op == 1 then
			M:process_curves()
		elseif NM.op == 2 then
			M:process_tube()
		elseif NM.op == 3 then
			M:process_poly()
		end
	end
	
	function M:process_poly()
		if #self.ps < 3 then return end
		local minb,maxb = CG.bounds(self.ps)
		local indexes = CG.EarClipSimple2(self.ps)
		--make tcoords
		local diff = maxb-minb
		local tcoords = {}
		for i,v in ipairs(self.ps) do
			local vv = v.xy - minb
			 tcoords[i] = mat.vec2(vv.x/diff.x,vv.y/diff.y)
		end
		self.mesh = mesh.mesh({points=self.ps,tcoords=tcoords,triangles=indexes})
		updatefunc(self)
	end
	
	function M:process_tube()
		if #self.ps < 3 then return end
		self.ps[#self.ps + 1] = self.ps[ 1]
		local section = mesh.tb2section(self.ps)
		self.ps[#self.ps] = nil
		local meshW = mesh.tube(section,NM.grid)
		meshW:M4(mat.translate(vec3(0,0,NM.zplane))*mat.scale(1,1,NM.height))
		self.mesh = meshW
		updatefunc(self)
	end
	
	function M:process_curves()

		if #self.ps < 3 then return end
		--prtable(self.ps)
		--generate grid mesh based on spline bounds
		local epsv = vec3(1e-5,1e-5,1e-5)
		local minb,maxb = CG.bounds(self.ps)
		
		local grid = mesh.gridB(NM.grid,{minb-epsv,maxb+epsv},NM.zplane)
		local points_add = grid.points
		local indexes = grid.triangles
		
		local Polind = CG.AddPoints2Mesh(self.ps,points_add,indexes)
		---prtable(points_add)
		---[[
		indexes =	CDTinsertion(points_add,indexes,Polind, true) --NM.outpoly)
		---------------------
		--delete points not used
		local map = mesh.clean_points(points_add, indexes)
		for i,ind in ipairs(Polind) do
			Polind[i] = map[ind]
		end
		---------------------
		--]]
		--centroid
		-- local cent = mat.vec3(0,0,0)
		-- for i,v in ipairs(points_add) do
			-- cent = cent + v
		-- end
		-- cent = cent/#points_add
		-- self.centroid = cent
		
		HeightSet(points_add,Polind)
		
		--make tcoords
		local diff = maxb-minb
		local tcoords = {}
		for i,v in ipairs(points_add) do
			local vv = v.xy - minb
			 tcoords[i] = mat.vec2(vv.x/diff.x,vv.y/diff.y)
		end

		self.mesh = mesh.mesh({points=points_add,tcoords=tcoords,triangles=indexes})
		--self.mesh.centroid = cent
		updatefunc(self)
	end
	
	function M:save()
		local pars = {}
		pars.dial = NM:GetValues()
		return pars
	end
	function M:load(params)
		if not params then return end
		NM:SetValues(params.dial or {})
	end

	return M
end


return HeightEditor