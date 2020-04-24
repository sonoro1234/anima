
--------------
require"anima"


local function mod(a,b)
	return ((a-1)%b)+1
end



local function Editor(GL,camera,updatefunc)
	updatefunc = updatefunc or function() end
	local M = {}
	
	local SPLINEDIRTY = true
	local NM = GL:Dialog("Height",
	{{"set_cam",0,guitypes.button,function() M:set_cam() end},
	{"zplane",-1,guitypes.val,{min=-20,max=-0.2}, function()
			M.update(M.SE)
			end },
	{"height",0,guitypes.val,{min=-1,max=1},function(val) 
		--if val> 0 then DIRTYISHEIGHT=true end
		M:process() end},
	{"alpha",1,guitypes.drag,{min=0,max=6},function() M:process() end},
	{"proy_height",false,guitypes.toggle,function() M:process() end},
	{"curves",1,guitypes.slider_enum,{"line","circle","pow"},function() M:process() end},
	{"grid",3,guitypes.valint,{min=1,max=30},function() M:process() end},
	})


	local vec3 = mat.vec3
	local function update(se) 
		M:newshape()
		local ps = {}
		for i,pt in ipairs(se.ps[1]) do
			ps[i] = M:takespline(pt)
		end
		M.ps = ps
		SPLINEDIRTY = true
		M:process()
	end
	M.update = update
	local SE = require"anima.modeling.Spline"(GL,update)
	M.SE = SE
	
	local Dbox = GL:DialogBox("SpHeight",true) --autosaved
	Dbox:add_dialog(SE.NM)
	Dbox:add_dialog(NM)
	Dbox.plugin = M
	
	M.NM = Dbox

	function M:init()
		self:save_cam()
		self:newshape()
	end
	function M:newshape()
		self.ps = {}
	end

	local MP,MPinv
	function M:save_cam()
		MP = camera:MP()
		MPinv = MP.inv
	end
	function M:set_cam()
		print"set_cam"
		self:save_cam()
		update(SE)
	end
	
	function M:takespline(v2)
		local v2 = v2*2/mat.vec2(GL.W,GL.H) - mat.vec2(1,1)
		local eyepoint = MPinv * mat.vec4(v2.x,v2.y,-1,1)
		eyepoint = eyepoint/eyepoint.w
		eyepoint = (NM.zplane*(eyepoint/eyepoint.z)).xyz
		return eyepoint
	end
	
	function M:numpoints()
		return #self.ps
	end

	
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
				assert(heights[i]>=0 and heights[i]<=1)
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

		if #self.ps < 3 then return end
		--generate grid mesh based on spline bounds
		local minb,maxb = CG.bounds(self.ps)
		
		local grid = mesh.gridB(NM.grid,{minb,maxb},NM.zplane)
		local points_add = grid.points
		local indexes = grid.triangles
		
		local Polind = CG.AddPoints2Mesh(self.ps,points_add,indexes)
		indexes =	CDTinsertion(points_add,indexes,Polind, true) --NM.outpoly)
		---------------------
		--delete points not used
		local map = mesh.clean_points(points_add, indexes)
		for i,ind in ipairs(Polind) do
			Polind[i] = map[ind]
		end
		---------------------
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
	
	--dummy draw
	function M:draw(t,w,h)
		
	end
	function M:save()
		local pars = {}
		pars.SE = SE:save()
		pars.dial = NM:GetValues()
		return pars
	end
	function M:load(params)
		if not params then return end
		NM:SetValues(params.dial or {})
		SE:load(params.SE)
		M:set_cam()
	end
	M:init()
	--GL:add_plugin(M,"SpHeight")
	return M
end

--[=[

local GL = GLcanvas{H=800,aspect=1,DEBUG=false,vsync=true}
local camara = newCamera(GL,"tps")
local edit = Editor(GL,camara)
local plugin = require"anima.plugins.plugin"
edit.pse = plugin.serializer(edit)

--GL.use_presets = true
function GL.init()
	local initt = secs_now()
	--ProfileStart("3vfsi4m1")
	--edit.pse.load(path.chain(path.this_script_path(),"testquadmesh2"))
	--edit.pse.load(path.chain(path.this_script_path(),"aaaQ2b"))
	--edit.pse.load(path.chain(path.this_script_path(),"phfx2.CDTins"))
	--for i=1,500 do edit:set_vaoT() end

	--ProfileStop()
	print("----------done in",secs_now()-initt)
	GL:DirtyWrap()
end
function GL.draw(t,w,h)
	--edit:process()
	ut.Clear()
	edit:draw(t,w,h)
end
GL:start()
--]=]
--[=[
local GL = GLcanvas{H=800,aspect=3/2}
local camara = newCamera(GL,"ident")
local edit = Editor(GL,camara)
local plugin = require"anima.plugins.plugin"
edit.ps = plugin.serializer(edit)
GL.use_presets = true
--local blur = require"anima.plugins.gaussianblur2"(GL)
-- local blur = require"anima.plugins.liquid".make(GL)
local blur = require"anima.plugins.photofx".make(GL)
local fboblur,fbomask,tex
local tproc
NM = GL:Dialog("proc",{{"showmask",false,guitypes.toggle}})

function GL.init()
	fboblur = GL:initFBO({no_depth=true})
	fbomask = GL:initFBO({no_depth=true})
	tex = GL:Texture():Load[[c:\luagl\media\estanque3.jpg]]
	tproc = require"anima.plugins.texture_processor"(GL,3,NM)
	tproc:set_textures{tex,fboblur:GetTexture(),fbomask:GetTexture()}
	tproc:set_process[[vec4 process(){
		if (showmask)
		return c3 + c1*(vec4(1)-c3);
		else
		return mix(c1,c2,c3.r);
	}
	]]
end
function GL.draw(t,w,h)
	fboblur:Bind()
	blur:draw(t,w,h,{clip={tex}})
	fboblur:UnBind()
	
	fbomask:Bind()
	ut.Clear()
	edit:draw(t,w,h)
	fbomask:UnBind()
	
	ut.Clear()
	--fboblur:GetTexture():draw(t,w,h)
	--fbomask:GetTexture():draw(t,w,h)
	--edit:draw(t,w,h)
	tproc:process()
end
GL:start()
--]=]
return Editor