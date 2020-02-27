local CG = require"anima.CG3.base"

function CG.CDTinsertion1(P,Ed,Poli)
		
		local function ClasifyVerts(c,d,sc,sd,Pu,Pl)
			if sc > 0 then
				Pu[#Pu+1] = c
				Pl[#Pl+1] = d
			else
				Pu[#Pu+1] = d
				Pl[#Pl+1] = c
			end
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
		local function FindTriangleInterAB(Elist,a,b,E)
			--print("FindTriangleInterAB",a,b)
			for j,L in ipairs(Elist[a]) do
				local op2a = L.op
				for j2,L2 in ipairs(Elist[op2a]) do
					local op2 = L2.op
					local ee = E[L2.key]
					if ee and ((ee[1]==a and ee[2]) or  ee[2]==a) then
						local inter,sc,sd = SegmentIntersect(P[a],P[b],P[op2a],P[op2])
						if inter then
							return op2a,op2,sc,sd
						end
					end	
				end
			end
			print("FindTriangleInterAB finds nothing")
			error("FindTriangleInterAB finds nothing")
		end
		
		local function Walk(a,b,c,d,Pu,Pl)
			--print("Walk",a,b,c,d)
			local a1 = a
			while true do 
				--seguir desde c-d hasta b
				--segundo triangulo es el opuesto de a sobre c-d
				--print("test",c,d,a1)
				local op = CG.Eopposite(Ed[CG.EdgeKey(c,d)],a1)
				if not (op) then
					prtable("bad opos in:",Ed[CG.EdgeKey(c,d)])
					error"no op"
				end
				--print("opos",op)
				--print("a,b",a,b)
				if op == b then
					break
				else
					--test c-op
					if InterClassify(P,a,b,c,op,Pu,Pl) then
						a1,c,d = d,c,op
					elseif InterClassify(P,a,b,d,op,Pu,Pl) then --test d-op
						a1,c,d = c,d,op
					else
						--should be a,b,op collinear
						print("Walk: no edge intersect",CG.Sign(P[a],P[b],P[op]))
						return
					end
				end
			end
		end
		
		local function Tpseudo(E,P,Ps,a,b)
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
				CG.setTriangle(E,a,b,Ps[ci])
			end
		end
		--lista de aristas por vertice
		--print"xxxxxxxxxxxxxxxxxxxxxlista aristas"
		local function AdjList(Ed)
			local Elist = {}
			for k,e in pairs(Ed) do
				local a,b = e.edge[1],e.edge[2]
				Elist[a] = Elist[a] or {}
				table.insert(Elist[a],{key=k,op=b})
				Elist[b] = Elist[b] or {}
				table.insert(Elist[b],{key=k,op=a})
			end
			return Elist
		end
		local function AdjListAdd(Ed,e)
		end
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
		
		local Elist = AdjList(Ed)
		
		for i=1,#Poli do
			local a = Poli[i][1]
			local b = Poli[i][2] --Poli[mod(i+1,#Poli)]
			local key = CG.EdgeKey(a,b)
			local e = Ed[key]
			if not e then --no esta, hay que insertar
				--print("searchingxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",a,b)
				local Pu,Pl = {},{} --{a},{a}
				--primero buscar punto a y arista intersecada
				local c,d,sc,sd =	FindTriangleInterAB(Elist,a,b,Ed)
				ClasifyVerts(c,d,sc,sd,Pu,Pl)
				--ahora recorrer los triangulos hasta b
				Walk(a,b,c,d,Pu,Pl)
				
				if #Pu > 0 or #Pl> 0 then
					--assert(#Pu == #Pl)
					for j=1,#Pu do
						--assert(Ed[CG.EdgeKey(Pu[j],Pl[j])])
						CG.DeleteEdge(Ed,CG.EdgeKey(Pu[j],Pl[j]))
					end
					--delete consecutive equal vertex
					deleteRepeated(Pu)
					deleteRepeated(Pl)
					--do triangulation
					Tpseudo(Ed,P,Pu,a,b)
					Tpseudo(Ed,P,Pl,a,b)
					Elist = AdjList(Ed)
					--prtable("Pu",Pu)
					--prtable("Pl",Pl)
				end
			end
		end
		--recreate triangulation
		local Ed2 = deepcopy(Ed)
		local tr2 = {}
		for k,e in pairs(Ed2) do
			assert(e[1])
			table.insert(tr2,e.edge[1]-1)
			table.insert(tr2,e.edge[2]-1)
			table.insert(tr2,e[1]-1)
			if e[2] then
				table.insert(tr2,e.edge[1]-1)
				table.insert(tr2,e.edge[2]-1)
				table.insert(tr2,e[2]-1)
			end
			CG.DeleteEdge(Ed2,k)
		end
		return tr2,Ed
	end

local SegmentIntersect = CG.SegmentIntersect	
function CG.CDTinsertion(P,Ed,Poli,delout)
		local Pol = {}
		for i=1,#Poli do
			Pol[i] = P[Poli[i][1]]
		end
		
		local function ClasifyVerts(c,d,sc,sd,Pu,Pl)
			if sc > 0 then
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
					--print("test",a,b,op2a,op2)
					inter,sc,sd,sgabcd = SegmentIntersect(P[a],P[b],P[op2a],P[op2])
					--print("\t",inter,sc,sd,sgabcd)
					if inter then
						return op2a,op2,sc,sd
					end
					
			end

			print("FindTriangleInterAB2 finds nothing")
			print("")
			error("FindTriangleInterAB2 finds nothing")
		end
		
		local function Walk(a,b,c,d,Pu,Pl)
			--print("Walk",a,b,c,d)
			local a1 = a
			while true do 
				--seguir desde c-d hasta b
				--segundo triangulo es el opuesto de a sobre c-d
				--print("test",c,d,a1)
				--assert(Ed[c][d]==a1)
				local op = Ed[d][c] --CG.Eopposite(Ed[c][d],a1)
				if not (op) then
					
					prtable("no opos in:",c,d,a1,Ed[c][d])
					error"no op"
				end
				--print("opos",op)
				--print("a,b",a,b)
				if op == b then
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
		local function reverse(t)
			local t2 ={}
			for i=#t,1,-1 do t2[#t2+1] = t[i] end
			return t2
		end
		
		
		
		local Pdelout = {}
		--CHECK(Ed)
		for i=1,#Poli do
			local a = Poli[i][1]
			local b = Poli[i][2] --Poli[mod(i+1,#Poli)]
			local e = Ed[a][b] or Ed[b][a]
			
			if not e then --no esta, hay que insertar
				--print("searchingxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",a,b)
				local Pu,Pl = {},{} --{a},{a}
				--primero buscar punto a y arista intersecada
				local c,d,sc,sd =	FindTriangleInterAB2(a,b,Ed)
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
						for i=1,#Pl do 
							if( CG.IsPointInPoly(Pol,P[Pl[i]])) then
							else
								Pdelout[Pl[i]] = true 
							end
						end
					end

					--prtable("Pu",Pu)
					--prtable("Pl",Pl)
				end
				--]]
			--else
				--print(a,b,"intriangul")
			end
		end
		
		if delout then
		local Polv = {}
		for i=1,#Poli do
			Polv[Poli[i][1]] = true
			Pdelout[Poli[i][1]] = nil --
		end
		--test not in poli
		-- for ka,_ in pairs(Pdelout) do
			-- if( CG.IsPointInPoly(Pol,P[ka])) then
				-- print(ka,"in poly")
				-- Pdelout[ka] = nil
			-- end
		-- end
		-----------------------
		local fin
		repeat
			fin = true
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
							Pdelout[kb] = true
						end
						local c = Ed[ka][kb]
						if not Polv[c] then --not in poly
							Pdelout[c] = true
						end
						CG.deleteTriangle(Ed,ka,kb,c)
					end
					Pdelout[ka] = nil
					fin = false
					break
				else
					Pdelout[k] = nil
				end
			end
		until fin
		end
		
		--recreate triangulation

		return CG.Ed2TR(Ed),Ed
	end
	
