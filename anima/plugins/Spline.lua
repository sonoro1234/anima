
require"anima"
--local mat = require"anima.matrixffi"
local TA = require"anima.TA"
local CG = require"anima.CG3"
local vert_sh = [[
	in vec2 position;
	void main()
	{
		gl_Position = vec4(position,-1,1);
	
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




local function Editor(GL,updatefunc,args)
	args = args or {}
	updatefunc = updatefunc or function() end
	
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}
	
	--if args.doblend then M.always_dirty = true end --always draw
	
	local numsplines = 1
	local NM 
	
	local vars = {
	{"newspline",0,guitypes.button,function(this) 
		numsplines=numsplines+1;
		this.vars.curr_spline[0]=numsplines 
		this.defs.curr_spline.args.max=numsplines 
		M:newshape() end},
	{"curr_spline",1,guitypes.valint,{min=1,max=numsplines}},
	{"alpha",0.5,guitypes.val,{min=0,max=1},function() M:set_all_vaos() end},
	{"divs",3,guitypes.valint,{min=1,max=30},function() M:set_all_vaos() end},
	--{"closed",true,guitypes.toggle,function() M:set_all_vaos() end},
	--{"drawpoints",true,guitypes.toggle},
	--{"drawregion",false,guitypes.toggle},
	--{"drawspline",true,guitypes.toggle},
	{"orientation",0,guitypes.button,function() M:change_orientation(); M:process_all() end},
	{"points",1,guitypes.slider_enum,{"nil","set","edit","clear"},function(val,this)
	
		val = val - 1 --
		if val == 0 then --nil
			GL.mouse_pick = nil
		elseif val == 1 then --set
			local mousepick = {action=function(X,Y)
							local Xv,Yv = GL:ScreenToViewport(X,Y)
							--print("screen",X,Y)
							--print("viewport",Xv,Yv)
							M:process1(Xv,Yv)
							M:set_vaos()
							updatefunc(M)
						end}
			GL.mouse_pick = mousepick
		elseif val == 2 then --edit
			local mousepick = {action=function(X,Y)
							X,Y = GL:ScreenToViewport(X,Y)
							local touched = -1
							for i,v in ipairs(M.sccoors[NM.curr_spline]) do
								local vec = mat.vec2(v[1] - X, v[2] - Y)
								if (vec.norm) < 3 then touched = i; break end
							end
							if touched > 0 then
								GL.mouse_pos_cb = function(x,y)
									x,y = GL:ScreenToViewport(x,y)
									M.sccoors[NM.curr_spline][touched] = {x,y}
									M:process_all()
								end
							else
								GL.mouse_pos_cb = nil
							end
	
						end,
						action_rel = function(X,Y)
							GL.mouse_pos_cb = nil
						end}
			GL.mouse_pick = mousepick
		elseif val == 3 then --clear
			local mousepick = {action=function(X,Y)
							X,Y = GL:ScreenToViewport(X,Y)
							local touched = -1
							for i,v in ipairs(M.sccoors[NM.curr_spline]) do
								local vec = mat.vec2(v[1] - X, v[2] - Y)
								if (vec.norm) < 3 then touched = i; break end
							end
							if touched > 0 then
								table.remove(M.sccoors[NM.curr_spline],touched)
								M:process_all()
							end
						end}
			GL.mouse_pick = mousepick
		
		end
	end},
	
	{"set_last",0,guitypes.button,function(val,this)
		this.vars.points[0] = 0
		local mousepick = {action=function(X,Y)
							X,Y = GL:ScreenToViewport(X,Y)
							local touched = -1
							for i,v in ipairs(M.sccoors[NM.curr_spline]) do
								local vec = mat.vec2(v[1] - X, v[2] - Y)
								if (vec.norm) < 3 then touched = i; break end
							end
							if touched > 0 then
								M:set_last(touched)
								M:process_all()
								GL.mouse_pick = nil
							end
	
						end}
		GL.mouse_pick = mousepick
	end},
	{"clear spline",0,guitypes.button,function() M:newshape() end,{sameline=true}},
	}
	
	if args.region then table.insert(vars,{"drawregion",false,guitypes.toggle,function() updatefunc(M) end}) end
	NM = GL:Dialog("spline",vars)

	M.NM = NM
	NM.plugin = M
	
	local vaopoints, vaoS, vaoT ={},{},{}
	local function initVaos()
		vaopoints[NM.curr_spline] = VAO({position=TA():Fill(0,8)},program)
		vaoS[NM.curr_spline] = VAO({position=TA():Fill(0,8)},program)
		vaoT[NM.curr_spline] = VAO({position=TA():Fill(0,8)},program,{0,1,2,3})
	end
	function M:init()
		if not program then
			program = GLSL:new():compile(vert_sh,frag_sh)
		end
		initVaos()
		self:newshape()
	end
	M.sccoors = {}
	M.eyepoints = {}
	M.ps = {}
	M.good_indexes = {}
	function M:newshape()
		self.sccoors[NM.curr_spline] = {}
		self.eyepoints[NM.curr_spline] = {}
		self.ps[NM.curr_spline] = {}
		M.good_indexes[NM.curr_spline] = true
		if not vaopoints[NM.curr_spline] then initVaos() end
	end

	function M:process1(X,Y)
		local ndc = mat.vec2(X,Y)*2/mat.vec2(GL.W,GL.H) - mat.vec2(1,1)
		--local eyepoint = MPinv * mat.vec4(ndc.x,ndc.y,0,1)
		local eyepoint =  mat.vec2(ndc.x,ndc.y)
		table.insert(self.eyepoints[NM.curr_spline],eyepoint)
		table.insert(self.sccoors[NM.curr_spline],{X,Y})
		self.NM.dirty = true
		return X,Y
	end
	
	function M:process_all()
		local scoorsO = self.sccoors[NM.curr_spline] --deepcopy(self.sccoors)
		self:newshape()
		for i,v in ipairs(scoorsO) do
			self:process1(unpack(v))
		end
		M:set_vaos()
		updatefunc(self)
	end
	function M:numpoints(ind)
		ind = ind or NM.curr_spline
		return #self.eyepoints[ind]
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
	
	function M:set_vaos(ii)
		ii = ii or NM.curr_spline
		if #self.eyepoints[ii] > 0 then
		local lp = mat.vec2vao(self.eyepoints[ii])
		vaopoints[ii]:set_buffer("position",lp,(#self.eyepoints[ii])*2)
		if self:numpoints()>2 then
			--self.ps[ii] = Spline(self.eyepoints[ii],NM.alpha,NM.divs,NM.closed)
			self.ps[ii] = CG.Spline(self.eyepoints[ii],NM.alpha,NM.divs,true)
			local lps = mat.vec2vao(self.ps[ii])
			vaoS[ii]:set_buffer("position",lps,(#self.ps[ii])*2)

			if args.region then self:set_vaoT(ii) end
		end
		end
	end
	function M:set_all_vaos()
		for i=1,numsplines do
			self:set_vaos(i)
		end
		updatefunc(self)
	end
	local CG = require"anima.CG3"
	function M:set_vaoT(ii)
		local lps = mat.vec2vao(self.ps[ii])
		vaoT[ii]:set_buffer("position",lps,(#self.ps[ii])*2)
		local indexes
		indexes,self.good_indexes[ii] = CG.EarClipSimple(self.ps[ii])
		vaoT[ii]:set_indexes(indexes)
	end
	
	function M:draw(_,w,h)

		if NM.collapsed then return end
		w,h = w or self.res[1],h or self.res[2]

		gl.glDisable(glc.GL_DEPTH_TEST)
		gl.glViewport(0, 0, w, h)
		--if not args.doblend then ut.Clear() end --when not blending
		program:use()

		if NM.drawregion  then
			for i=1,numsplines do
				if self.good_indexes[i] then
					program.unif.color:set{1,1,1}
				else
					program.unif.color:set{1,0,0}
				end
				if M:numpoints(i) > 2 then
				vaoT[i]:draw_elm()
				end
			end
			--vaoT:draw_mesh()
		else

			program.unif.color:set{1,1,0}

			for i=1,numsplines do
				if M:numpoints(i) > 2 then
				vaoS[i]:draw(glc.GL_LINE_LOOP,(#self.ps[i]))
				end
			end

			if M:numpoints() > 0 then
				program.unif.color:set{1,0,0}
				gl.glPointSize(6)
				vaopoints[NM.curr_spline]:draw(glc.GL_POINTS,M:numpoints())
				program.unif.color:set{1,1,0}
				vaopoints[NM.curr_spline]:draw(glc.GL_POINTS,1)
				
				gl.glPointSize(1)
				--program.unif.color:set{0.2,0.2,0.2}
				--vaopoints:draw(glc.GL_LINE_STRIP,M:numpoints())
			end
		end

		gl.glEnable(glc.GL_DEPTH_TEST)
	end
	function M:save()
		--print"SplineEditor6 save"
		local pars = {sccoors=self.sccoors,VP={GL.W,GL.H}}
		pars.dial = NM:GetValues()
		pars.numsplines = numsplines
		return pars
	end
	function M:load(params)
		if not params then return end
		for j,sc in ipairs(params.sccoors) do
		for i,v in ipairs(sc) do
			v[1] = v[1]*GL.W/params.VP[1]
			v[2] = v[2]*GL.H/params.VP[2]
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
	GL:add_plugin(M)--,"spline")
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
local fbo
function GL.init()
	fbo = GL:initFBO{no_depth=true}
	GL:DirtyWrap()
end
function GL.draw(t,w,h)
	ut.Clear()
	fbo:Bind()
	ut.Clear()
	edit:draw(nil)
	fbo:UnBind()
	fbo:tex():drawcenter()
end
GL:start()
--]=]
--[=[
local GL = GLcanvas{H=800,aspect=3/2}
local edit = Editor(GL,nil,{region=true})
local plugin = require"anima.plugins.plugin"
edit.ps = plugin.serializer(edit)
--GL.use_presets = true
--local blur = require"anima.plugins.gaussianblur3"(GL)
--local blur = require"anima.plugins.liquid".make(GL)
--local blur = require"anima.plugins.photofx".make(GL)
local blur = require"anima.plugins.LCHfx".make(GL)
local fboblur,fbomask,tex
local tproc
local NM = GL:Dialog("proc",
{{"showmask",false,guitypes.toggle},
{"invert",false,guitypes.toggle},
{"minmask",0,guitypes.val,{min=0,max=1}},
{"maxmask",1,guitypes.val,{min=0,max=1}},
})

local DBox = GL:DialogBox("photomask")
DBox:add_dialog(edit.NM)
DBox:add_dialog(blur.NM)
DBox:add_dialog(NM)

function GL.init()
	fboblur = GL:initFBO({no_depth=true})
	fbomask = GL:initFBO({no_depth=true})
	tex = GL:Texture():Load[[c:\luagl\media\estanque3.jpg]]
	tproc = require"anima.plugins.texture_processor"(GL,3,NM)
	tproc:set_textures{tex,fboblur:GetTexture(),fbomask:GetTexture()}
	tproc:set_process[[vec4 process(vec2 pos){
	
		if (invert)
			c3 = vec4(1) - c3;
		c3 = min(max(c3,vec4(minmask)),vec4(maxmask));
		if (showmask)
			return c3 + c1*(vec4(1)-c3);
		else
			return mix(c1,c2,c3.r);
	}
	]]
	--GL:DirtyWrap()
end

function GL.draw(t,w,h)
	fboblur:Bind()
	blur:draw(t,w,h,{clip={tex}})
	fboblur:UnBind()
	

	fbomask:Bind()
	ut.Clear()
	edit:draw()
	fbomask:UnBind()
	edit.NM.dirty = false

	
	ut.Clear()
	tproc:process({tex,fboblur:GetTexture(),fbomask:GetTexture()})
end
GL:start()
--]=]
return Editor