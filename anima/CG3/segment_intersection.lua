--Bentley–Ottmann algorithm
--still slower than brute force
require"anima"
--lexi sort
local function compare(p,q)
	return (p.x < q.x) or ((p.x == q.x) and (p.y < q.y))
end

local function mod(a,b)
	return ((a-1)%b)+1
end

local function modPol(self,i)
		return self[((i-1)%#self)+1]
end

local function modPolind(self,i)
		return ((i-1)%#self)+1
end

local EventPoint = {}
EventPoint.__index = EventPoint
EventPoint.__lt = function(p,q)
	return compare(p.p,q.p)
end
EventPoint.__eq = function(p,q)
	return p.p==q.p
end
EventPoint.__tostring = function(v)
	return "p="..tostring(v.p).." "..#v.U.." "..#v.L
end

function EventPoint:new(p)
	local o = {p = p,U={},L={},C={}}
	setmetatable(o, EventPoint)
	return o
end

function EventPoint:add_seg(segment,mode)
	if mode=="U" then
		self.U[#self.U+1] = segment
	elseif mode=="L" then
		self.L[#self.L+1] = segment
	elseif mode=="C" then
		self.C[#self.C+1] = segment
	else
		error"add_seg unknown mode."
	end
end

local function sls_compare(s1,s2)
	return (s1.sls < s2.sls) or ((s1.sls == s2.sls) and (s1.slope < s2.slope))
end
local Segment = {}
Segment.__index = Segment
Segment.__lt = sls_compare
-- Segment.__eq = function(s1,s2)
	-- return rawequal(s1,s2)
-- end
Segment.__tostring = function(v)
	local P,ind = next(v.ref)
	return tostring(P).."["..ind.."] sls="..v.sls.." slope="..v.slope
end
function Segment:new(s)
	setmetatable(s, Segment)
	return s
end

local BTree = require"anima.algorithm.bstree"
local AVLTree3 = require"anima.algorithm.avl_tree"
local ffiAVLTree3 = require"anima.algorithm.ffi_avl"
local CG = require"anima.CG3"

local function IntersectorAddSegment(Int,P,ind)
	local p1 = P:mod(ind)
	local p2 = P:mod(ind+1)
	local upp = compare(p1,p2)
	local dir = p1-p2
	local slope = dir.y/dir.x
	local bi = p1.y - slope*p1.x
	Int.Segments[P] = Int.Segments[P] or {}
	Int.Segments[P][ind] = Segment:new{p1, p2, ref={[P]=ind},upp=upp,slope=slope,bi=bi}
	local segment = Int.Segments[P][ind]
	
	local newev = EventPoint:new(p1)
	local exist,node = Int.EvPtree:contains(newev)
	if not exist then 
		newev:add_seg(segment,upp and "U" or "L")
		Int.EvPtree:insert(newev)
	else
		assert(node._data.p == p1)
		node._data:add_seg(segment,upp and "U" or "L")
	end
	
	local newev = EventPoint:new(p2)
	local exist,node = Int.EvPtree:contains(newev)
	if not exist then 
		newev:add_seg(segment,(not upp) and "U" or "L")
		Int.EvPtree:insert(newev)
	else
		assert(node._data.p == p2)
		node._data:add_seg(segment,(not upp) and "U" or "L")
	end
end

local function ffi_avl_sls_compare(s1,s2)
	if s1 == s2 then
		return 0
	elseif (s1.sls < s2.sls) or ((s1.sls == s2.sls) and (s1.slope < s2.slope)) then
		return -1
	else
		return 1
	end
end
--segment
-- S = {pu,pd} upper point down point
local function initIntersector(polyset)

	local Intersector = {
	EvPtree = BTree:new(),
	--EvPtree = AVLTree3:new(),
	Segments = {}, 
	--SLS = AVLTree3:new(),
	--SLS = ffiAVLTree3.new(ffi_avl_sls_compare),
	SLS = BTree:new(),
	Intersections = {}}
	
	for j=1,#polyset do
		local P1 = polyset[j]
		P1.mod = modPol
		for i=1,#P1 do
			IntersectorAddSegment(Intersector,P1,i)
		end
	end
	return Intersector
end

local function FindNewEvent(Int,s1,s2,Ev)
	--local pt,ok,t,t2 = CG.IntersecPoint3(s1[1],s1[2],s2[1],s2[2])
	--if ok and t>=0 and t<=1 and t2>=0 and t2 <=1 then
	--local pt,ok,t = CG.IntersecPoint2(s1[1],s1[2],s2[1],s2[2])
	--if ok and t>=0 and t<=1 then
	local ok = CG.SegmentIntersect(s1[1],s1[2],s2[1],s2[2])
	if ok then
		local pt = CG.IntersecPoint(s1[1],s1[2],s2[1],s2[2])
		if compare(Ev.p,pt) then
			local newev = EventPoint:new(pt)
			local exist,node = Int.EvPtree:contains(newev)
			if not exist then 
				newev:add_seg(s1,"C")
				newev:add_seg(s2,"C")
				Int.EvPtree:insert(newev)
			else
			end 
		end
	end
end
local algo = require"anima.algorithm.algorithm"
local function checkSLS(Int)
	local previ
		Int.SLS:traverse(function(v)
			if previ then
				assert(previ<v)
			end
			previ=v
		end)
end
local function checkSLS() return end
local function iterateIntersector(Int)
	
	local Ev = Int.EvPtree:first()
	local SLSupdater = function(s)
				s.sls = s.slope*Ev.p.x + s.bi
			end
	local countEv = 0
	while Ev do
		countEv = countEv + 1
		--print("-------------iteration",countEv)
		if #Ev.U + #Ev.L + #Ev.C > 1 then
			local allS = {}
			for _,S in ipairs{Ev.U,Ev.L,Ev.C} do
				for i,s in ipairs(S) do
					table.insert(allS,s)
				end
			end
			local validPairs = {}
			for i=1,#allS-1 do
				local s1 = allS[i]
				local P1,ind1 = next(s1.ref)
				for j=i+1,#allS do
					local s2 = allS[j]
					local P2,ind2 = next(s2.ref)
					local ind_distance = math.abs(ind1-ind2)
					--not from the same polygon or from the same but not consecutive
					if P1~=P2 or (ind_distance>1 and ind_distance~=#P1-1) then
						validPairs[#validPairs+1] = {s1,s2}
					end
				end
			end
			if #validPairs > 0 then
				--print("intersection",#allS,#validPairs,Ev.p)
				for i,v in ipairs(validPairs) do
					local P1,ind1 = next(v[1].ref)
					local P2,ind2 = next(v[2].ref)
					--print(P1,ind1,P2,ind2)
					table.insert(Int.Intersections,{Ev.p,P1,ind1,P2,ind2})
				end
				--prtable(Ev.U, Ev.L ,Ev.C)
			end
		end
		-------------------------------
		--check SLS
		checkSLS(Int)

		local onlyL = (#Ev.U + #Ev.C == 0)
		local prevL,nextL
		--delete L from SLS
		for i,s in ipairs(Ev.L) do
			if onlyL then
			--TODO: check several L
				prevL = Int.SLS:prev(s)
				nextL = Int.SLS:next(s)
			end
			local ok,node = Int.SLS:remove(s)
		end
		checkSLS(Int)
		-- delete C from SLS
		for i,s in ipairs(Ev.C) do
			local node = Int.SLS:remove(s)
			--print("remove C",node,node and node.value)
		end
		
		checkSLS(Int)
				---[[
		--update sls
		Int.SLS:traverse(SLSupdater)
		for _,S in ipairs{Ev.U,Ev.C,Ev.L} do
			for i,s in ipairs(S) do
				s.sls = Ev.p.y 
			end
		end
		--]]
		checkSLS(Int)
		---insert U and C
		local allUC = {}
		for i,s in ipairs(Ev.U) do
			table.insert(allUC,s)
			Int.SLS:insert(s)
		end
		for i,s in ipairs(Ev.C) do
			table.insert(allUC,s)
			Int.SLS:insert(s)
		end
		checkSLS(Int)
		--print("SLS onlyL",onlyL,"countEv",countEv)
		--Int.SLS:traverse(function(s) print(tostring(s)) end)
		
		--find New Events
		if onlyL then
			if prevL and nextL then FindNewEvent(Int,prevL,nextL,Ev) end
		else
			--sort allUC
			algo.quicksort(allUC,1,#allUC,sls_compare)
			--leftmost (downmost)
			for i,s in ipairs(allUC) do
				local prev = Int.SLS:prev(s)
				if prev then
					FindNewEvent(Int,prev,s,Ev)
					break
				end
			end
			--rightmost (upmost)
			for i=#allUC,1,-1 do
				local s = allUC[i]
				local nex = Int.SLS:next(s)
				if nex then 
					FindNewEvent(Int,nex,s,Ev)
					break
				end
			end
		end
		-----------------
		Ev = Int.EvPtree:next(Ev)
	end
end

------tests

math.randomseed(3)
local Poly = {}
for i=1,500 do
	Poly[i] = mat.vec2((2*math.random()-1)*10,(2*math.random()-1)*10)
end

local Poly2 = {}
for i=1,500 do
	Poly2[i] = mat.vec2((2*math.random()-1)*10,(2*math.random()-1)*10)
end

--[[
Poly = {}
Poly[1] = mat.vec2(0,0)
Poly[2] = mat.vec2(0,1)
Poly[3] = mat.vec2(1,0)
Poly[4] = mat.vec2(1,1)
Poly[5] = mat.vec2(0,1)
Poly[6] = mat.vec2(-1,0.5)
--]]

--[[
Poly = {}
Poly[1] = mat.vec2(0,0)
Poly[2] = mat.vec2(0,1)
Poly[3] = mat.vec2(1,0)
Poly[4] = mat.vec2(1,1)
--]]

local CHP = require"anima.CG3.check_poly"
--local cros = CHP.check_self_crossings(Poly,true)
ProfileStart("3vfsi4m1")
local ini_t = secs_now()
local cros = CHP.check_polyset_crossings{Poly,Poly2}
print("cros",#cros,secs_now()-ini_t)
--prtable(cros)

local ini_t = secs_now()
local II = initIntersector{Poly,Poly2}

--II.EvPtree:traverse(function(ev) assert(#ev.U+#ev.L==2) end)
--II.EvPtree:print()

--print("count",II.EvPtree:count())
print("inited in",secs_now()-ini_t)
--prtable(II.EvPtree:first())
--prtable(EventPoint)

iterateIntersector(II)

print("intersections",#II.Intersections,secs_now()-ini_t)
--prtable(II.Intersections)

ProfileStop()
do return end
local evpoints = {}
II.EvPtree:traverse(function(ev) table.insert(evpoints,ev.p) end)


-----------------------------------------------------
local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "widgets",{vsync=true,use_implot=true})
local win = igwin:GLFW(800,400, "widgets",{vsync=true,use_implot=true})

local ffi = require"ffi"
local xs1, ys1 = ffi.new("float[?]",#Poly+1),ffi.new("float[?]",#Poly+1)
for i = 0,#Poly do
    xs1[i] = Poly:mod(i+1).x
    ys1[i] = Poly:mod(i+1).y;
end

local xs2, ys2 = ffi.new("float[?]",#II.Intersections),ffi.new("float[?]",#II.Intersections)
for i = 0,#II.Intersections-1 do
	local pt = II.Intersections[i+1][1]
    xs2[i] = pt.x;
    ys2[i] = pt.y;
end

local xs3, ys3
if evpoints then
 xs3, ys3 = ffi.new("float[?]",#evpoints),ffi.new("float[?]",#evpoints)
for i = 0,#evpoints-1 do
	local pt = evpoints[i+1]
    xs3[i] = pt.x;
    ys3[i] = pt.y;
end
end

local offset = ffi.new"int[1]"
function win:draw(ig)
    ig.Begin("Ploters")
	ig.SliderInt("Offset", offset, 0, #Poly+1);
    if (ig.ImPlot_BeginPlot("Line Plot", "x", "f(x)", ig.ImVec2(-1,-1))) then
          ig.ImPlot_PlotLine("poly", xs1, ys1, #Poly+1);
		  ig.ImPlot_PlotScatter("puntos", xs2, ys2, #II.Intersections);
		  --ig.ImPlot_PlotScatter("vertex", xs1, ys1, 2,offset[0]);
		  ig.ImPlot_PlotScatterFloatPtrFloatPtr("vertex", xs1+offset[0], ys1+offset[0], 1)--,offset[0]);
		  if evpoints then ig.ImPlot_PlotScatter("ev", xs3, ys3, #evpoints); end
        ig.ImPlot_EndPlot();
    end
    ig.End()
end

win:start()