function clamp(x,minVal,maxVal)
	return math.min(math.max (x, minVal), maxVal)
end
function smoothstep(edge0,edge1,x)
	local t = clamp((x - edge0) / (edge1 - edge0), 0, 1);
	return t* t * (3 - 2 * t);
end

function REPEAT_SEGMENTS(n,...)
	local T = {}
	for i=1,n do 
		for j=1,select('#',...) do
			local t = select(j,...)
			T[#T+1]=t 
		end
	end
	return unpack(T)
end

--given t and dur
-- returns a 0-1 ramp lasting f1
-- then constant 1 until dur-f2
-- then 1-0 ramp lasting f2
function fadeInOut(t,dur,f1,f2)
	f2 = f2 or f1
	if t < f1 then
		return t/f1
	elseif t > dur - f2 then
		return 1 - clamp((t - dur + f2)/f2,0,1)
	else
		return 1
	end
end

unit_maps = {}
local function clip(val,mini,maxi)
    return math.max(mini,math.min(val,maxi))
end
function unit_maps.linearmap(s,e)
	local a = e-s
	return function(v)
		return s + a*v
	end
end
function unit_maps.in_quad(s,e)
	local a = e - s
	return function(v)
		return s + v*v * a
	end
end
function unit_maps.out_quad(s,e)
	local a = s - e
	return function(v)
		--return s  +v*b + v*v * a
		return s  + (v-2)*a*v
	end
end
function unit_maps.inout_quad(s,e)
	local a = (e - s)/2
	return function(v)
		v = v * 2
		if v < 1 then
			return s + v*v * a
		else
			v = v - 1 
			return -a * (v*(v-2) - 1) +s;
		end
	end
end
function unit_maps.inout_pow(f)
 return function (s,e)
	local a = (e - s)/2
	return function(v)
		v = v * 2
		if v < 1 then
			return s + math.pow(v,f) * a
		else
			v = v - 1 
			return  s + a + (1 - math.pow(1 - v,f)) * a;
		end
	end
end
end
function unit_maps.in_pow(f)
 return function (s,e)
	local a = (e - s)
	return function(v)
		return s + math.pow(v,f) * a
	end
end
end
function unit_maps.easing(name)
	local easing = require"anima.easing"
	return function(ini,endp,dur)
		local vari = endp - ini
		return function(v)
			return easing[name](v,ini,vari,1)
		end
	end
end
function unit_maps.constantmap(s,e)
	return function() return s end
end


function ConstVal(v,t)
	return {v,v,t,unit_maps.constantmap}
end

function unit_maps.trigval(s,e)
	local done = false
	local oldfrac = 0
	return function(frac,seg_,time)
		--print("frac",frac)
		if frac < oldfrac then done=false end
		oldfrac = frac
		if not done then
			--print("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzTRIG",s)
			done = true
			return s
		else
			--print("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzTRIGNOT",s)
			return e
		end
	end
end

function TrigVal(val,dur)
	return {val,0,dur,unit_maps.trigval}
end

local function map2unit(v,s,dur)
	return (v-s)/(dur)
end

function linearmap(v,s,e,ds,de)
    return ((de-ds)*(v-s)/(e-s)) + ds
end
function unit_maps.sigmoidal(ampL,ampR)
	return function(minV,maxV)
		local minV2 = 1/(1+math.exp(-ampL))
		local maxV2 = 1/(1+math.exp(-ampR))
		local escale = (maxV - minV)/(maxV2 - minV2)
		local offset = maxV - maxV2 * escale
		return function(frac)
			local i = linearmap(frac,0,1,ampL,ampR);
			return offset + escale/(1 + math.exp(-i))
		end
	end
end
--alias
sigmoidalFunc = unit_maps.sigmoidal

function unit_maps.sinemap(s2,e2)
	return function(v)
		--local omega = unit_maps.linearmap(v,0,math.pi) + math.pi*1.5
		local omega = linearmap(v,0,1,0,math.pi) + math.pi*1.5
		local sine = math.sin(omega)
		return linearmap(sine,-1,1,s2,e2)
	end
end
function unit_maps.sinemapf(f)
	return function(s2,e2)
		return function(v)
			--local omega = unit_maps.linearmap(v,0,math.pi*f) + math.pi --*1.5
			local omega = linearmap(v,0,1,0,math.pi*f) + math.pi --*1.5
			local sine = math.cos(omega)
			return linearmap(sine,-1,1,s2,e2)
		end
	end
end
require"anima.perlinnoise"
function unit_maps.perlinvar(fac,seed)
	return function(ini,endp)
		local vari = endp - ini
		return function(frac,seg_,time)
			return ini + vari * PerlinNoise_1D(time*fac + seed) --,4,0.5)
		end
	end
end
function unit_maps.perlinvar2(fac,seed)
	return function(ini,endp)
		local vari = endp - ini
		return function(frac,seg_,time)
			return ini + frac*vari * (PerlinNoise_1D(time*fac + seed)-0.5) --,4,0.5)
		end
	end
end
--used to avoid changing values
function unit_maps.nop()
	return function() return nil end
end
------------------------------------------


function pointer(value)
	local p = {[0]=value,is_pointer=true}
	return p
end
--[=[
local _set_mt = {}
function _set_mt.__index(t,k)
	return t.vars[k] and t.vars[k][0]
end
function Setables(t,f)

	local tt = {vars = {}}
	for i,v in ipairs(t) do
		tt.vars[v[1]] = pointer(v[2])
	end
	return setmetatable(tt,_set_mt)
end
--]=]
function AnimPlotter(anim,ini,endp,step)
	step = step or 0.1
	local steps = math.floor(0.5 + (endp-ini)*(1/step)) + 1
	local xs1, ys1 = ffi.new("float[?]",steps),ffi.new("float[?]",steps)
	for i=0, steps-1 do
		xs1[i] = i*step + ini
		ys1[i] = anim:dofunc(xs1[i])
	end

	local nsegments = 0
	local xs2t,ys2t = {},{}
	for i,seg in ipairs(anim.segments) do
		if seg.secs > endp then break end
		if seg.secs >= ini then
			if anim.is_spl_anim then
				xs2t[#xs2t + 1] = seg.secs
				ys2t[#ys2t + 1] = seg[1]
				nsegments = nsegments + 1
			else -- animatable not spline
				xs2t[#xs2t + 1] = seg.secs
				ys2t[#ys2t + 1] = seg[1]
				xs2t[#xs2t + 1] = seg.secs + seg[3]
				ys2t[#ys2t + 1] = seg[2]
				nsegments = nsegments + 2
			end
		end
	end
	local xs2, ys2 = ffi.new("float[?]",nsegments,xs2t),ffi.new("float[?]",nsegments,ys2t)
	return function()
		--if ig.CollapsingHeader(tostring(anim)) then
			if (ig.ImPlot_BeginPlot("AnimPlot "..tostring(anim), "x", "f(x)", ig.ImVec2(-1,-1))) then
				ig.ImPlot_PlotLine("tim1", xs1, ys1, steps);
				ig.ImPlot_PushStyleVarInt(ig.lib.ImPlotStyleVar_Marker, ig.lib.ImPlotMarker_Circle);
				ig.ImPlot_PlotScatter("cp", xs2, ys2, nsegments);
				ig.ImPlot_PopStyleVar();
				ig.ImPlot_EndPlot();
			end
		--end
	end
end
-----------------------------------------------------------------------
animatable = {is_animatable = true}
-- object must have setval for updtating values
-- segments = {{ini,end,dur,func},{ini,end,dur,func},...}
function animatable:new(object,segments,hook)
	local o =  {} 
	--assert(object)
	o.object = object or pointer()
	o.segmentsO = segments or {}
	o.hook = hook
	setmetatable(o, self)
	self.__index = self
	return o
end

function animatable:init()
	local secs = 0
	self.segments = {}
	for i,segment in ipairs(self.segmentsO) do
		local seg = deepcopy(segment)
		seg.secs = secs
		secs = secs + segment[3]
		local func = segment[4] or unit_maps.linearmap
		seg.func = func(segment[1],segment[2],segment[3])
		self.segments[i] = seg
	end
	self.dur = secs
	self.inited = true
end

function animatable:dofunc(time)
	assert(time,"time is nil")
	if not self.inited then self:init() end
	-- find segment
	local _segm
	for i,segment in ipairs(self.segments) do
		if (time >= segment.secs) and (time < segment.secs + segment[3]) then _segm = segment; break end
	end
	--take last segment if it is more than this
	if not _segm then _segm = self.segments[#self.segments] end
	if _segm then
		local dur = _segm[3]
		_segm.dur = dur
		local frac = clip(map2unit(time, _segm.secs, dur),0,1)
		self.curr_val = _segm.func(frac,_segm,time)
		local ok,hasset = pcall(function() return self.object.set end)
		if ok and hasset then
			-- print("has set",self.object)
			-- print(pcall(function() return self.object.set end))
			-- prtable(self.object)
			self.object:set(self.curr_val)
		else
			self.object[0] = self.curr_val
		end
		if self.hook then self:hook() end
	end
	return self.curr_val
end
function animatable:getdur()
	if not self.inited then self:init() end
	local lastsegm = self.segments[#self.segments]
	return lastsegm.secs + lastsegm[3]
end

function animatable:plotter(ini,endp,step)
	return AnimPlotter(self,ini,endp,step)
end

function ANT(t)
	return animatable:new(nil, t)
end
function AN(...)
	return animatable:new(nil, {...})
end
function AN1(set,...)
	--assert(type(set)=="table" and set.is_setable_var,"set is not setable_var")
	assert(set)
	return animatable:new(set, {...})
end
---------------------------------------------------------------------
local function Norm(a)
	if type(a)=="number" then 
		return math.abs(a) 
	else
		return a:norm()
	end
end
--this version allows identical points
local function CatmulRom(p0,p1,p2,p3,alpha)
	alpha = alpha or 0.5
	local function GetT( t,  p0,  p1,alpha)
	    local a = Norm(p1-p0) --math.pow((p1.x-p0.x), 2.0) + math.pow((p1.y-p0.y), 2.0);
	    local b = math.pow(a, 0.5);
	    local c = math.pow(b, alpha);
	   
	    return (c + t);
	end
	
	local t0 = 0.0;
	local t1 = GetT(t0, p0, p1, alpha);
	local t2 = GetT(t1, p1, p2, alpha);
	local t3 = GetT(t2, p2, p3, alpha);
	
	--print("Catmull",t0,t1,t2,t3)
	--special cases
	local A1s,A3s
	if p1==p2 then
		return function() return p1 end
	end
	if p0==p1 then A1s = p0 end
	if p2==p3 then A3s = p2 end
	
	return function(frac)
	local t = t1 + (t2-t1)*frac
	local A1 = A1s or (t1-t)/(t1-t0)*p0 + (t-t0)/(t1-t0)*p1;
	local A2 = (t2-t)/(t2-t1)*p1 + (t-t1)/(t2-t1)*p2;
	local A3 = A3s or (t3-t)/(t3-t2)*p2 + (t-t2)/(t3-t2)*p3;

	local B1 = (t2-t)/(t2-t0)*A1 + (t-t0)/(t2-t0)*A2;
	local B2 = (t3-t)/(t3-t1)*A2 + (t-t1)/(t3-t1)*A3;

	local C = (t2-t)/(t2-t1)*B1 + (t-t1)/(t2-t1)*B2;
	return  C
	end

end
--spline animatables
spl_anim = {is_spl_anim = true,is_animatable=true}
function spl_anim:new(object,segments,hook)
	local o =  {} 
	--assert(object)
	o.object = object or pointer()
	o.segmentsO = segments or {}
	o.hook = hook
	setmetatable(o, self)
	self.__index = self
	return o
end
function spl_anim:init()
	local secs = 0
	self.segments = {}
	for i,segment in ipairs(self.segmentsO) do
		local seg = deepcopy(segment)
		seg.secs = secs
		secs = secs + segment[2]
		
		local p0 = self.segments[i-1] and self.segments[i-1][1] or segment[1]
		local p1 = segment[1]
		local p2 = self.segmentsO[i+1] and self.segmentsO[i+1][1] or p1
		local p3 = self.segmentsO[i+2] and self.segmentsO[i+2][1] or p2
		--print("make CatmulRom(p0,p1,p2,p3)",p0,p1,p2,p3)
		seg.func = CatmulRom(p0,p1,p2,p3)
		self.segments[i] = seg
	end
	self.dur = secs
	self.inited = true
end
function spl_anim:dofunc(time)
	assert(time,"time is nil")
	if not self.inited then self:init() end
	-- find segment
	local _segm
	for i,segment in ipairs(self.segments) do
		if (time >= segment.secs) and (time < segment.secs + segment[2]) then _segm = segment; break end
	end
	--take last segment if it is more than this
	if not _segm then _segm = self.segments[#self.segments] end
	if _segm then
		local dur = _segm[2]
		local frac = clip(map2unit(time, _segm.secs, dur),0,1)
		self.curr_val = _segm.func(frac)
		local ok,hasset = pcall(function() return self.object.set end)
		if ok and hasset then
			self.object:set(self.curr_val)
		else
			self.object[0] = self.curr_val
		end
		if self.hook then self:hook(time,_segm) end
	end
	return self.curr_val
end

function spl_anim:plotter(ini,endp,step)
	return AnimPlotter(self,ini,endp,step)
end
-------------------------------------------------------------------------



----------------------------------
Animation = {start_frame = 1, durfr = 20, current_frame=0,fps = 25,play=true,animatables = nil}

function Animation:new(o)
	o = o or {}
	o.animatables = o.animatables or {}
	setmetatable(o, self)
	self.__index = self
	return o
end
--TODO: eliminate
function Animation:start()
	self.play = true
	self.lapse = 1/self.fps
	self.current_frame = 0
	--if Reset then Reset() end
end

function Animation:animate(time)
	if self.play then
		if time then
			if time < 0 then time = 0 end
			self.current_frame = self:sec2frames(time) --math.floor(time * self.fps) + 1 --first is 1
		else
			self.current_frame = self.current_frame + 1
		end

		--print("doing animation",self.current_frame)
		local time =  time or (self.current_frame - 1)/self.fps
		for k,v in pairs(self.animatables) do
			v:dofunc(time)
		end
		return time
	end

end
function Animation:dump()
	for k,v in pairs(self.animatables) do
			print(v.curr_val)
			--prtable(k)
	end
end
function Animation:sec2frames(secs)
	return math.floor(0.5 + secs * self.fps) -- covert ms to frames with rounding
end

function Animation:frame2secs(frame)
	return frame/self.fps
end

function Animation:add_animatable(ani)
	if ani.dur then
		ani.durfr = self:sec2frames(ani.dur)
	end
	if not ani.durfr then ani.durfr = self.durfr end
	--table.insert(self.animatables,ani)
	if self.animatables[ani.object] then print("WARNING: Animation:add_animatable: already set",ani.object); error"" end
	self.animatables[ani.object] = ani --avoids adding two times a setable
	return ani
end

function Animation:add_setable(set,segments,hook)
	assert(set,"add_setable with null pointer")
	local set_a = animatable:new(set,segments,hook)
	self:add_animatable(set_a)
	return set_a
end

function Animation:add(segments, default, callback)
	default = default or 0
	local objvar = pointer() --nil --setable_var(default,callback)
	local set_a = self:add_setable(objvar,segments)
	return set_a --objvar ,set_a
end

function Animation:add_segment(setable, segment)
	local ani = self.animatables[setable]
	table.insert(ani.segments, segment)
	ani.inited = false
end
--gives max dur from animatables
function Animation:getdur()
	local maxdur = 0
	for k, ani in pairs(self.animatables) do
		maxdur = math.max(maxdur, ani:getdur())
	end
	return maxdur
end

function Animation:insert_segment(setable, timeini, newsegment)
	local ani = self.animatables[setable]
	ani:init()
	-- find segment
	local segm_ini, i_ini
	for i,segment in ipairs(ani.segments) do
		if (timeini >= segment.secs) and (timeini < segment.secs + segment[3]) then segm_ini = segment; i_ini = i break end
	end
	if not segm_ini then -- after end
		local lastseg = ani.segments[#ani.segments]
		local lasttime = lastseg and lastseg.secs + lastseg[3] or 0
		local nop_seg = {0,0,timeini - lasttime, unit_maps.nop}
		table.insert(ani.segments, nop_seg)
		table.insert(ani.segments, newsegment)
	else

		local segm_end, i_end
		local timeend = timeini + newsegment[3]
		for i = i_ini, #ani.segments do
			local segment = ani.segments[i]
			if (timeend >= segment.secs) and (timeend < segment.secs + segment[3]) then segm_end = segment; i_end = i break end
		end
		if not segm_end then 
			--cut this
			segm_end[3] = timeini - segm_end.secs
			ani.segments[i_end + 1] = newsegment
			--delete rest
			for i = i_end + 2, #ani.segments, 1 do ani.segments[i] = nil end
		else
					error"not ready"
		end
	end
	table.insert(ani.segments, segment)
end






