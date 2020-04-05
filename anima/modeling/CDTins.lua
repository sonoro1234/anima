require"anima"
local mat = require"anima.matrixffi"
local TA = require"anima.TA"
local path = require"anima.path"
path.require_here()
local vert_sh = [[
	in vec3 position;
	uniform mat4 MP;
	void main()
	{
		gl_Position = MP * vec4(position,1);
	
	}
	]]

local frag_sh = [[
	uniform vec3 color = vec3(1);
	void main()
	{
		gl_FragColor = vec4(color,1);
	}
	]]

	
local program

local function mod(a,b)
	return ((a-1)%b)+1
end



local function Editor(GL,camera,updatefunc)
	updatefunc = updatefunc or function() end
	local M = {}
	
	local NM = GL:Dialog("CDTins",
	{{"set_cam",0,guitypes.button,function() M:set_cam() end},
	{"zplane",-1,guitypes.val,{min=-20,max=-0.2}, function()
			M.update(M.SE)
			--M:process_all() 
			end },
	{"height",0,guitypes.val,{min=0,max=0.2},function() M:set_vaos() end},
	{"proy_height",false,guitypes.toggle,function() M:set_vaos() end},
	{"lineheight",true,guitypes.toggle,function() M:set_vaos() end},
	{"grid",3,guitypes.valint,{min=1,max=30},function() M:set_vaos() end},
	{"delaunay",true,guitypes.toggle,function() M:set_vaos() end},
	{"CDT",true,guitypes.toggle,function() M:set_vaos() end},
	{"outpoly",true,guitypes.toggle,function() M:set_vaos() end},
	})


	local vec3 = mat.vec3
	local function update(se) 
		M:newshape()
		local ps = {}
		for i,pt in ipairs(se.ps[1]) do
			ps[i] = M:takespline(pt)
		end
		M.ps = ps
		M:process_all()
	end
	M.update = update
	local SE = require"anima.plugins.Spline"(GL,update)--,{doblend=true})
	M.SE = SE
	
	local Dbox = GL:DialogBox("CDTins",true) --autosaved
	--Dbox:add_dialog(camera.NMC)
	Dbox:add_dialog(SE.NM)
	Dbox:add_dialog(NM)
	Dbox.plugin = M
	
	M.NM = Dbox
	--NM.plugin = M
	
	local vaopoints, vaoT
	function M:init()
		if not program then
			program = GLSL:new():compile(vert_sh,frag_sh)
		end
		vaopoints = VAO({position=TA():Fill(0,12)},program)
		vaoT = VAO({position=TA():Fill(0,12)},program,{0,1,2,3})
		self:save_cam()
		self:newshape()
	end
	function M:newshape()
		--self.eyepointsW = {}
		self.eyepointsP = {}
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
		local eyepoint = MPinv * mat.vec4(v2.x,v2.y,-1,1)
		--print(ndc,eyepoint)
		eyepoint = eyepoint/eyepoint.w
		eyepoint = (NM.zplane*(eyepoint/eyepoint.z)).xyz
		table.insert(self.eyepointsP,eyepoint)
		return eyepoint
	end
	
	function M:process_all()
		M:set_vaos()
	end
	function M:numpoints()
		return #self.eyepointsP
	end
	
	vec2vao = mat.vec2vao

	
	function M:set_vaos()
		if #self.eyepointsP > 0 then
			local lp = vec2vao(self.eyepointsP)
			vaopoints:set_buffer("position",lp,(#self.eyepointsP)*3)
		end
		self:set_vaoT()
	end
	
	local CG = require"anima.CG3" --CG2bis
		
	local CDTinsertion = CG.CDTinsertion
	
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
		local heights = {}
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
		local maxh = 0
		for i,v in ipairs(heights) do
			maxh = (v > maxh) and v or maxh
		end
		--print("maxh",maxh)
		for i,he in ipairs(heights) do
			local alt 
			if NM.lineheight then
				alt = NM.height*he/maxh
			else
				alt = NM.height*math.sqrt(1-(1-he/maxh)^2)
			end
			if NM.proy_height then
				P[i] = P[i]/P[i].z*(NM.zplane+alt)
			else
				P[i].z = NM.zplane  + alt
			end
			 
		end
	end
	
	function M:set_vaoT()

		---[[
		--generate grid mesh based on spline bounds
		local points_add = {}
		local minb,maxb = CG.bounds(self.ps)
		local diff = maxb-minb
		local step = diff/NM.grid
		
		for i=0,NM.grid do
			local x = i==NM.grid and maxb.x or (minb.x + i*step.x)
			for j=0,NM.grid do
				local y = j==NM.grid and maxb.y or (minb.y + j*step.y)
				local p = mat.vec3(x,y,NM.zplane)
				points_add[#points_add+1]=p
			end
			--case j=NM.grid avoid roundings
			--points_add[#points_add+1]= mat.vec3(x,maxb.y,NM.zplane)
		end
		-- tr indexes for grid
		local indexes = mesh.triangs(NM.grid+1,NM.grid+1)
		
		--local inipadd = #points_add
		local Polind --= TA():series(#self.ps,inipadd+1)
		if NM.delaunay then
			Polind = CG.AddPoints2Mesh(self.ps,points_add,indexes)
			if NM.CDT then
				indexes,E =	CDTinsertion(points_add,indexes,Polind,NM.outpoly)
			end
			HeightSet(points_add,Polind)
		end
		
		--centroid
		local cent = mat.vec3(0,0,0)
		for i,v in ipairs(points_add) do
			cent = cent + v
		end
		cent = cent/#points_add
		self.centroid = cent
		
		local lps = vec2vao(points_add)
		vaoT:set_buffer("position",lps,(#points_add)*3)
		vaoT:set_indexes(indexes)
		--make tcoords
		local tcoords = {}
		for i,v in ipairs(points_add) do
			local vv = v.xy - minb
			 tcoords[i] = mat.vec2(vv.x/diff.x,vv.y/diff.y)
			 --print(tcoords[i])
		end
		self.mesh = mesh.mesh({points=points_add,tcoords=tcoords,triangles=indexes})
		self.mesh.centroid = cent
		updatefunc(self)
	end
	
	function M:draw(t,w,h)
		if NM.collapsed then return end
		gl.glDisable(glc.GL_DEPTH_TEST)
		gl.glViewport(0, 0, w, h)
		program:use()
		local MP1 = camera:MP()
		program.unif.MP:set(MP1.gl)

		program.unif.color:set{1,1,1}
		
		if M:numpoints()>2 then
		vaoT:draw_mesh()
		end
		
		--gl.glEnable(glc.GL_BLEND)
		--gl.glBlendFunc(glc.GL_ONE,glc.GL_ONE)
		--glext.glBlendEquation(glc.GL_FUNC_ADD)
		SE:draw(t,w,h)
		--gl.glDisable(glc.GL_BLEND)
		
		gl.glEnable(glc.GL_DEPTH_TEST)
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

	GL:add_plugin(M,"CDTins")
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
	--edit:set_vaos()
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