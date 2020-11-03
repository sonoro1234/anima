local CG = require"anima.CG3.base"
local Sign = CG.Sign

local function mod(a,b)
	return ((a-1)%b)+1
end


function CG.Jarvis_Conv(P)
	--find leftmost
	local minx = 1
	for i=1,#P do
		if P[i].x < P[minx].x then 
			minx = i
		elseif (P[i].x == P[minx].x) and (P[i].y < P[minx].y) then
			minx = i
		end
	end
	local p_start = minx
	local q_next = (minx == 1) and 2 or 1

	local q = {}
	local h = 1;
	local q_now = p_start;
	repeat 
		q[h] = q_now;
		h = h + 1;
		for i = 1,#P do
			if i~=q_next and i~= q_now then
			local det = Sign(P[q_now], P[q_next], P[i])
			if (det > 0) then 
				q_next = i
			elseif det == 0 then
				local a = (P[q_next] - P[q_now]):xy():norm()
				local b = (P[q_now] - P[i]):xy():norm()
				if(a==b) then
					print(a,b,P[q_now], P[q_next], P[i])
					error("bad jarvis")
				end
				if b > a then q_next = i end
			end
			end
		end
		q_now = q_next;
		q_next = p_start;
	until(q_now == p_start)
	
	local Q = {}
	for i,v in ipairs(q) do
		Q[i] = P[v]
	end
	return Q,q
end

--returns convex hull polygon of a list P of points
function CG.SLR(P)
	--lexicografic sort
	-- table.sort(P,function(a,b) 
		-- return (a.x < b.x) or ((a.x == b.x) and (a.y < b.y))
	-- end)
	assert(P.sorted,"points should be sorted")
	local Q = {}
	Q[1] = P[1];
	local h = 1;
	-- Lower convex hull (left to right):
	for i = 2,#P do
		while (h > 1 and Sign(Q[h-1], Q[h], P[i]) <  0) do
			h = h - 1;
		end
		h = h + 1;
		Q[h] = P[i];
	end
	-- Upper convex hull (right to left):

	for i = #P-1,1,-1 do
		while (h > 1 and Sign(Q[h-1], Q[h], P[i]) <  0) do
			h = h - 1;
		end
		h = h + 1;
		Q[h] = P[i];
	end
	--clear holes in Q
	for i= h+1,#Q do Q[i] = nil end
	return Q
end


function CG.conv_sweept(P)

	assert(P.sorted,"points shoul be sorted")
	local Q = {}
	local tr = {}
	local last
	--first triangle
	local sign = Sign(P[1],P[2],P[3])
	if sign > 0 then
		Q[1],Q[2],Q[3] = 1,2,3
		tr = {0,1,2}
		last = 3
		--print"right"
	elseif sign < 0 then
		Q[1],Q[2],Q[3] = 1,3,2
		tr = {0,2,1}
		last = 2
		--print"left"
	else
		error("collinear points")
	end

	for i=4,#P do
		local u,d = last,last
		--prtable(Q)
		while (Sign(P[i],P[Q[u]],P[Q[mod(u+1,#Q)]]) < 0) do
			--local usig = mod(u+1,#Q)
			--print("u",u,usig,mod(usig+1,#Q))
			u = mod(u+1,#Q)
		end
		while (Sign(P[i],P[Q[d]],P[Q[mod(d-1,#Q)]]) > 0) do
			d = mod(d-1,#Q)
		end
		if(d >u and u~=1) then
			print(d,u)--,Sign(Q[1],Q[2],Q[3]),Sign(P[1],P[2],P[3]))
			--prtable(Q)
			error("bad sdfjlksdf")
		end

		if u > d then
			for h=1,u-d-1 do table.remove(Q,d+1) end
		else
			for j=d+1,#Q do Q[j]=nil end
		end
		table.insert(Q,d+1,i)
		last = d+1
		--]]
	end
	local CH = {}
	for i,v in ipairs(Q) do
		CH[i] = P[Q[i]]
	end
	return CH
end