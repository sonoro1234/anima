local CG = require"anima.CG3.base"

local SegmentIntersect = CG.SegmentIntersect
--takes P: table of points, indexes: openGL tr over P (offset -1 for being 0-indexed)
-- Polinds: table of poligon indexes over P 
-- delout: (boolean) delete edges out of polygon
function CG.CDTinsertion(P,indexes,Polinds,bridges,delout)
		--assert(type(Polinds[1])=="table")-- for change in behaviour
		if type(Polinds[1])~="table" then Polinds = {Polinds} end

		local Ed = CG.TR2Ed(indexes)
		--prtable(indexes)
		--prtable("Ed",Ed)
				
		--edges of polygon 
		local Polis = {}
		for i,Polind in ipairs(Polinds) do
			local Poli = {}
			for ii=1,#Polind-1 do
				if not bridges[ii] then
					Poli[#Poli+1] = {Polind[ii],Polind[ii+1]}
				end
			end
			if not bridges[#Polind] then
				Poli[#Poli+1] = {Polind[#Polind],Polind[1]}
			end
			Polis[#Polis+1] = Poli
		end

		--polygon points
		local Pols = {}
		for i,Polind in ipairs(Polinds) do
			local Pol = {}
			for i=1,#Polind do
				Pol[i] = P[Polind[i]]
			end
			Pols[#Pols+1] = Pol
		end
		
		local IsPointInPoly = CG.IsPointInPoly
		local deleteTriangle = CG.deleteTriangle
		
		local function ClasifyVerts(c,d,sc,sd,Pu,Pl)
			if sc > 0 then
			--if sc < 0 then
				Pu[#Pu+1] = c
				Pl[#Pl+1] = d
			else
				--assert(sd > 0)
				Pu[#Pu+1] = d
				Pl[#Pl+1] = c
			end
			-- if CG.IsPointInPoly(Pol,P[Pl[#Pl]]) then
				-- print("should not be Pl",Pl[#Pl],sc,sd,c,d,CG.IsPointInPoly(Pol,P[Pu[#Pu]]))
			-- end
		end
		
		local function InterClassify(P,a,b,c,d,Pu,Pl)
			local inter,sc,sd = SegmentIntersect(P[a],P[b],P[c],P[d])
			if inter then
				ClasifyVerts(c,d,sc,sd,Pu,Pl)
			end
			return inter
		end
		
		
		--buscar arista en triangulo incidente en a que interseca recta a-b
		--returns c-d and the sign of them respect to line a-b
		local function FindTriangleInterAB2(a,b,E)
			--print("find",a,b)
			local inter,sc,sd
			for op2a,op2 in pairs(E[a]) do
					--print("FindTriangleInterAB2 test",a,b,op2a,op2)
					inter,sc,sd,sgabcd = SegmentIntersect(P[a],P[b],P[op2a],P[op2])
					--print("\t",inter,sc,sd,sgabcd)
					if inter then
						return op2a,op2,sc,sd
					end
					
			end

			print("FindTriangleInterAB2 finds nothing")
			print("")
			return false
			--error("FindTriangleInterAB2 finds nothing")
		end
		
		local function Walk(a,b,c,d,Pu,Pl)
			--print("Walk",a,b,c,d)
			local a1 = a
			while true do 
				--print("while",a1,b,c,d)
				--seguir desde c-d hasta b
				--segundo triangulo es el opuesto de a sobre c-d
				--print("test",c,d,a1)
				--assert(Ed[c][d]==a1)
				local op = Ed[d][c] --CG.Eopposite(Ed[c][d],a1)
				if not (op) then
					
					prtable("no opos in:",c,d,a1,Ed[c][d],Ed[d][c])
					prtable(Ed)
					error"no op"
				end
				--print("opos",op)
				--print("a,b",a,b)
				if op == b then
					--print("op == b")
					break
				else
					--test c-op
					if InterClassify(P,a,b,c,op,Pu,Pl) then
						a1,c,d = d,c,op
					elseif InterClassify(P,a,b,op,d,Pu,Pl) then --test d-op
						a1,c,d = c,op,d
					else
						--should be a,b,op collinear
						
						print("Walk: no edge intersect",CG.Sign(P[a],P[b],P[op]))
						return
					end
				end
			end
		end
		
		local function Tpseudo(E,P,Ps,a,b)
			--print("Tpseudo",a,b)
			--prtable(Ps)
			local ci = 1
			if #Ps > 1 then
				for i=2,#Ps do
					if CG.Circumcircle2(a,b,Ps[ci],Ps[i],P) then
						ci = i
					end
				end
				local Pe,Pd = {},{}
				for i=1,ci-1 do
					Pe[i] = Ps[i]
				end
				for i=ci+1,#Ps do
					Pd[#Pd + 1] = Ps[i]
				end
				Tpseudo(E,P,Pe,a,Ps[ci])
				Tpseudo(E,P,Pd,Ps[ci],b)
			end
			if #Ps > 0 then --crear a,b,Ps[ci]
				-- local area = CG.TArea(P[a],P[Ps[ci]],P[b]) --testTODO
				-- if math.abs(area)<1e-16 then 
					-- print("area Tpseudozer0",area,a,Ps[ci],b) 
				-- end
				CG.setTriangle(E,a,Ps[ci],b)
				--testCW(P,a,Ps[ci],b)
			end
		end
		--lista de aristas por vertice
		--print"xxxxxxxxxxxxxxxxxxxxxlista aristas"
		
		local function deleteRepeated(aa)
			local i=2
			while i<= #aa do
				if aa[i] == aa[i-1] then
					table.remove(aa,i)
				else
					i = i + 1
				end
			end
		end
		
		-- local function reverse(t)
			-- local t2 ={}
			-- for i=#t,1,-1 do t2[#t2+1] = t[i] end
			-- return t2
		-- end
		
		local floor = math.floor
		local function reverse(t)
			local s = #t+1
			for i=1,floor(#t/2) do
				t[i],t[s-i] = t[s-i],t[i]
			end
			return t
		end
		
		local function IsPointInPolis(Polys,pt)
			local wn = 0
			--print("IsPointInPolis",pt)
			for ip,Pol in ipairs(Polys) do
				local intt,wn1 = CG.IsPointInPolyWn(Pol,pt)
				wn = wn + wn1
				--print(ip,"is_in1",is_in1,CG.IsPointInPolyX(Pol,pt),CG.IsPointInPolyCn(Pol,pt),CG.IsPointInPolyWn(Pol,pt))
				--is_in = is_in1 or is_in
			end
			return wn~=0,wn
		end
		
		local Pdelout = {}
		--local Pdelouts = {}
		--CHECK(Ed)
		for ip,Poli in ipairs(Polis) do
		local Pol = Pols[ip]
		local sigA = CG.signed_area(Pol)
		--print("sigA",sigA)
		--local Pdelout = {}
		--Pdelouts[ip] = Pdelout
		for i=1,#Poli do
			local a = Poli[i][1]
			local b = Poli[i][2] --Poli[mod(i+1,#Poli)]
			local e = Ed[a][b] or Ed[b][a]
			--print("---check edge",a,b)
			if not e then --no esta, hay que insertar
				--print("searchingxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",a,b)
				local Pu,Pl = {},{} --{a},{a}
				--primero buscar punto a y arista intersecada
				local c,d,sc,sd =	FindTriangleInterAB2(a,b,Ed)
				--print("c",c,d,sc,sd,Ed[c][d],Ed[d][c])
				assert(c)
				if not c then return CG.Ed2TR(Ed),Ed,false end
				ClasifyVerts(c,d,sc,sd,Pu,Pl)
				--ahora recorrer los triangulos hasta b
				Walk(a,b,c,d,Pu,Pl)
				---[[
				if #Pu > 0 or #Pl> 0 then
					--assert(#Pu == #Pl)
					--prtable("going Tpseudo",Pu,Pl)
					for j=1,#Pu do
						local xa,xb = Pu[j],Pl[j]
						if not Ed[xa][xb] then xa,xb=xb,xa end
						--assert(Pu[j],Pl[j])])
						--print("delete",xa,xb,Ed[xa][xb],Ed[xb][xa])
						CG.DeleteEdge(Ed,xa,xb)
						--CHECK(Ed)
					end
					--delete consecutive equal vertex
					deleteRepeated(Pu)
					deleteRepeated(Pl)
					
					--do triangulation
					Tpseudo(Ed,P,Pu,a,b)
					Pl = reverse(Pl)
					Tpseudo(Ed,P,Pl,b,a)
					if delout then
						--CW poly
						-- if sigA < 0 then
						-- for i=1,#Pl do 
							-- if not IsPointInPoly(Pol,P[Pl[i]]) then
								-- Pdelout[Pl[i]] = true 
							-- end
						-- end
						-- else
						--CCW poly
						local PUi = Ed[b][a]
						for i=1,#Pu do 
							if PUi == Pu[i] then Pdelout[Pu[i]] = true; break end
							-- if not IsPointInPolis(Pols,P[Pu[i]]) then
								-- Pdelout[Pu[i]] = true 
							-- end
						end
						--end
					end

					--prtable("Pu",Pu)
					--prtable("Pl",Pl)
				end
				--]]
			else
				--print(a,b,"intriangul")
			end
		end
		end
		
		if delout then
		--print"delout"
			---[=[
			--for ip,Polind in ipairs(Polinds) do
			--do
			--local ip,Polind = 1,Polinds[1]
			--local Pol = Pols[ip]
			--local Pdelout = Pdelouts[ip]
			--move polygon points from Pdelout to Polv
			local Polv = {}
			for ip,Polind in ipairs(Polinds) do
			for i=1,#Polind do
				Polv[Polind[i]] = true
				Pdelout[Polind[i]] = nil 
			end
			end

			local fin
			repeat
				fin = true
				local Pdelout2 = {} --for inserting in Pdelout while doing pairs
				for ka,_ in pairs(Pdelout) do
					--print("delout",ka)
					if Ed[ka] then
						local todel = {}
						for kb,vv in pairs(Ed[ka]) do
							todel[#todel+1] = kb
						end
						
						for i=1,#todel do
							local kb = todel[i]
							if not Polv[kb] then --not in poly
								Pdelout2[kb] = true
							end
							local c = Ed[ka][kb]
							if not Polv[c] then --not in poly
								Pdelout2[c] = true
							end
							deleteTriangle(Ed,ka,kb,c)
						end
						Pdelout[ka] = nil
						fin = false --so repeat
						break
					else
						Pdelout[ka] = nil
					end
				end
				for ka,_ in pairs(Pdelout2) do
					Pdelout[ka] = true
				end
			until fin
			--]=]
			--[=[
			-- remove rests
			local doneT = {}
			local TriangleKey = CG.TriangleKey
			for ka,v in pairs(Ed) do
				for kb,op in pairs(v) do
					local hash = TriangleKey(ka,kb,op)
					if not doneT[hash] then
						--if all points are from poly
						--if Polv[ka] and Polv[kb] and Polv[op] then
						--if any point is from poly
						if Polv[ka] or Polv[kb] or Polv[op] then
							local bari = (P[ka] + P[kb] + P[op])/3
							--print("bari",ka,kb,op)
							--local is_in = false
							--for ip,Pol in ipairs(Pols) do
							if not IsPointInPolis(Pols,bari) then
								deleteTriangle(Ed,ka,kb,op)
							end
								--is_in = IsPointInPoly(Pol,bari) or is_in
							--end
							--if not is_in then deleteTriangle(Ed,ka,kb,op) end
						end
						doneT[hash] = true
					end
				end
			end
			--]=]
			---[=[
			--remove rests 2
			local doneT = {}
			local TriangleKey = CG.TriangleKey
			for ip,Poli in ipairs(Polis) do
				for i,e in ipairs(Poli) do
					--search triangles oposed
					local c = Ed[e[2]][e[1]]
					if c then
						deleteTriangle(Ed,e[2],e[1],c)
					end
				end
			end
			--]=]
			--end
		end
		
		--recreate triangulation

		return CG.Ed2TR(Ed),Ed
end

--given a set of polygon points and a mesh of points triangulated by tr (opengl 0-indexed)
--add new polygon points to mesh points and recreates the triangulation
--poli: table of polygon points to add
--points: original mesh points
--tr: triangulation indexes of mesh points (openGL style 0-indexed)
--returns Polind as indexes of polygon points over the points table (Lua 1-indexed)
--modifies points and tr
function CG.AddPoints2Mesh(poli,points,tr)
	--print("AddPoly------------------------------",#poli,#points,#tr)
	local inipoints = #points
	local eps = 0 --1e-18 --1e-11
	local abs = math.abs
	local remove = table.remove
	local IsPointInTri = CG.IsPointInTri
	local polind = {}
	
	local function addtrian(tr,a,b,c)
		tr[#tr+1] = a
		tr[#tr+1] = b
		tr[#tr+1] = c
		--[[
		local P = points
		local area = CG.TArea(P[a+1],P[b+1],P[c+1])
		if abs(area)<=eps then 
			print("area zeri",area,a,b,c) 
			return false
		end
		--]]
		return true
	end
	local function insert_3triangs(tr,i,a,b,c)
		local r = addtrian(tr,i,a,b)
		r = addtrian(tr,i,b,c) and r
		r = addtrian(tr,i,c,a) and r
		return r
	end
	local function insert_2triangs(tr,i,a,b,c)
		local r = addtrian(tr,i,b,c)
		r = addtrian(tr,i,c,a) and r
		return r
	end
	local function degen()
	end
	for i=1,#poli do
		local a = poli[i]
		local added = false
		local intri,l1,l2,l3
		local testtable = {}
		--print("tr---",#tr)
		--for j=1,#tr,3 do print((j-1)/3 +1,tr[j]+1,tr[j+1]+1,tr[j+2]+1) end
		local firstdegen=false
		::REPEAT::
		for j=1,#tr,3 do
			--print("searchT",inipoints+i,j,#points+1,"inds",tr[j]+1,tr[j+1]+1,tr[j+2]+1)
			local ptr1,ptr2,ptr3 = points[tr[j]+1],points[tr[j+1]+1],points[tr[j+2]+1]
			if 	(ptr1.x > a.x and ptr2.x > a.x and ptr3.x > a.x) or
				(ptr1.x < a.x and ptr2.x < a.x and ptr3.x < a.x) or
				(ptr1.y > a.y and ptr2.y > a.y and ptr3.y > a.y) or
				(ptr1.y < a.y and ptr2.y < a.y and ptr3.y < a.y) then
				goto continue
			end
				
			intri,l1,l2,l3 = IsPointInTri(a,points[tr[j]+1],points[tr[j+1]+1],points[tr[j+2]+1])
			testtable[#testtable+1] = {intri=intri,l1=l1,l2=l2,l3=l3}
			local weld = false
			local goodins = true

			
			--degenerated cases pt over triangle edge
			if (abs(l1)<=eps or abs(l2)<=eps or abs(l3)<=eps) then
				firstdegen = not firstdegen
				--print("degen",#points+1,intri,l1,l2,l3,tr[j]+1,tr[j+1]+1,tr[j+2]+1)
				if firstdegen then points[#points+1] = a end
				--points[#points+1] = a 
				local added2 = false
				if ((abs(l1)<=eps) and (l2*l3>=0)) then 
				--ifl2*l3==0 es un vertice entonces generar poli con indice hacia antiguo punto
				--y return en funcion
					if (l2*l3>0) then
						goodins =insert_2triangs(tr,#points-1,tr[j+1],tr[j+2],tr[j])
						-- goodins =insert_3triangs(tr,#points-1,tr[j],tr[j+1],tr[j+2])
					else --eq
						weld = (abs(l2)<=eps) and tr[j+2] or tr[j+1]
					end
					
					added2 = true
				elseif	((abs(l2)<=eps) and (l1*l3>=0)) then
					if (l1*l3>0) then
						goodins =insert_2triangs(tr,#points-1,tr[j+2],tr[j],tr[j+1])
						-- goodins =insert_3triangs(tr,#points-1,tr[j],tr[j+1],tr[j+2])
					else --eq
						weld = (abs(l1)<=eps) and tr[j+2] or tr[j]
					end
					added2 = true
				elseif	((abs(l3)<=eps) and (l2*l1>=0)) then
					if (l2*l1>0) then
						goodins =insert_2triangs(tr,#points-1,tr[j],tr[j+1],tr[j+2])
						-- goodins =insert_3triangs(tr,#points-1,tr[j],tr[j+1],tr[j+2])
					else --eq
						weld = (abs(l2)<=eps) and tr[j] or tr[j+1]
					end
					added2 = true
				end
				if added2 then
					--print"added2"
					if not goodins then print("badins2",l1,l2,l3) end
					if not weld then
						--firstdegen = not firstdegen
						--print"not weld"
						if firstdegen then
							polind[#polind + 1] = #points
						--else
							--points[#points] = nil --delete or second time
						end
						remove(tr,j)
						remove(tr,j)
						remove(tr,j)
						--find the opposite triangle for adding
						--for k=j,#tr
					else --reuse vertex weld
						--print"weld"
						points[#points] = nil
						polind[#polind+1] = weld + 1
						assert(firstdegen,"weld after 1 degen point")
						firstdegen = false
					end
					added = true
					--firstdegen = not firstdegen
					--print("firstdegen",firstdegen)
					if firstdegen then goto REPEAT else break end
					--break
				else
					points[#points] = nil
				end
			-- elseif (abs(l1)<=eps or abs(l2)<=eps or abs(l3)<=eps) then
				-- points[#points+1] = a
				-- polind[#polind+1] = #points
				----tr index is i-1
				-- goodins = insert_4triangs(tr,#points-1,tr[j],tr[j+1],tr[j+2])
				-- if not goodins then print("badins1",l1,l2,l3) end
				----delete triangle j,j+1,j+2
				-- remove(tr,j)
				-- remove(tr,j)
				-- remove(tr,j)
				-- added = true
				-- break
			elseif intri then --or (abs(l1)<=eps or abs(l2)<=eps or abs(l3)<=eps) then
				points[#points+1] = a
				polind[#polind+1] = #points
				--tr index is i-1
				goodins = insert_3triangs(tr,#points-1,tr[j],tr[j+1],tr[j+2])
				if not goodins then print("badins1",l1,l2,l3) end
				--delete triangle j,j+1,j+2
				remove(tr,j)
				remove(tr,j)
				remove(tr,j)
				added = true
				break
			end
		::continue::
		end
		if not added then print("not added",i,poli[i]) end --;prtable(testtable) end
	end
	--testTODO
	--[=[
	for i=1,#tr,3 do
		local P = points
		local area = CG.TArea(P[tr[i]+1],P[tr[i+1]+1],P[tr[i+2]+1])
		local sign = CG.Sign(P[tr[i]+1],P[tr[i+1]+1],P[tr[i+2]+1])
		if abs(area) < eps then
			print("area zero",i,area,sign,tr[i],tr[i+1],tr[i+2]) 
		end
		if not( sign > 0) then
			print("xxAdd poly2mesh error sign2",i,sign,inipoints)
		end
	end
	--]=]
	return polind
end
	
