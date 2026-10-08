require"anima"
local Editor = require"anima.modeling.Spline"

local GL = GLcanvas{H=800,aspect=1,DEBUG=true}
--local function update(n) print("update spline",n) end
local edit = Editor(GL,update,{region=true})--,doblend=true})
local plugin = require"anima.plugins.plugin"
edit.fb = plugin.serializer(edit)

local CG3 = require"anima.CG3"
local CHK = require"anima.CG3.check_poly"
local function box2d(points)
		local floor = math.floor
	
		local function round(x)
			return x --floor(x+0.5)
		end
		local minx,maxx,miny,maxy = math.huge,-math.huge,math.huge,-math.huge
		for i,p in ipairs(points) do
			minx = p.x < minx and p.x or minx
			maxx = p.x > maxx and p.x or maxx
			miny = p.y < miny and p.y or miny
			maxy = p.y > maxy and p.y or maxy
		end
		return {mat.vec2(round(minx),round(miny)),mat.vec2(round(maxx),round(maxy))}
	end


local function Checker(sp)
	local ii = ii or sp.NM.curr_spline
		
	local points = sp.sccoors[ii]
	if not points then print"No Spline:select spline" return end
	--prtable(points)
	local polys = CHK.check_repair_self_crossings(points)
		if #polys > 1 then
			print(#polys,"polys returned")
			for j=1,#polys do
				--CG3.degenerate_poly_repair(polys[j],true)
				--local cross = CHK.check_self_crossings(polys[j])
				--if #cross > 0 then print("bad repair crossing with cross") end
				-- table.insert(polyset, polys[j])
				sp:newspline(polys[j])
				--prtable(sp.sccoors[sp.NM.curr_spline])
			end
		else
			print"no self crossings"
		end
end

local function Checker3(sp)
	local ii = ii or sp.NM.curr_spline
		
	local points = sp.sccoors[ii]
	if not points then print"No Spline:select spline" return end
	--prtable(points)
	local polys = CHK.check_repair_self_crossings_rep(points)
		if #polys > 1 then
			print(#polys,"polys returned")
			for j=1,#polys do
				--CG3.degenerate_poly_repair(polys[j],true)
				--local cross = CHK.check_self_crossings(polys[j])
				--if #cross > 0 then print("bad repair crossing with cross") end
				-- table.insert(polyset, polys[j])
				assert(#polys[j]==#points)
				prtable(polys[j])
				sp:newspline(polys[j])
				--prtable(sp.sccoors[sp.NM.curr_spline])
			end
		else
			print"no self crossings"
		end
end
local function Checker4(sp)
	local ii = ii or sp.NM.curr_spline
		
	local points = sp.sccoors[ii]
	if not points then print"No Spline:select spline" return end
	local SR = require"anima.CG3.subramaniam"
	--prtable(points)
	local polys = SR.repair_crossings(points)
		if #polys > 1 then
			print(#polys,"polys returned")
			for j=1,#polys do
				--CG3.degenerate_poly_repair(polys[j],true)
				--local cross = CHK.check_self_crossings(polys[j])
				--if #cross > 0 then print("bad repair crossing with cross") end
				-- table.insert(polyset, polys[j])
				----assert(#polys[j]==#points)
				prtable(polys[j])
				sp:newspline(polys[j])
				--prtable(sp.sccoors[sp.NM.curr_spline])
			end
		else
			print"no self crossings"
		end
end
local function subramaniam_cont(sp)
	print("======================== subramaniam_cont ========================")
	local ii = ii or sp.NM.curr_spline
		
	local points = sp.sccoors[ii]
	if not points then print"No Spline:select spline" return end
	local SR = require"anima.CG3.subramaniam"
	--prtable(points)
	local pts,contours = SR.spline2contours(sp.ps[ii])
	local pts2,cont2 = SR.repair_contour_crossings(pts,contours)
	local polys = SR.contours2polys(pts2,cont2)
		if #polys > 1 then
			sp.triangulation = {{points=pts2,tr={}}}
			print(#polys,"polys returned")
			for j=1,#polys do
				--CG3.degenerate_poly_repair(polys[j],true)
				--local cross = CHK.check_self_crossings(polys[j])
				--if #cross > 0 then print("bad repair crossing with cross") end
				-- table.insert(polyset, polys[j])
				----assert(#polys[j]==#points)
				prtable(polys[j])
				sp:newspline(polys[j])
				--prtable(sp.sccoors[sp.NM.curr_spline])
			end
		else
			print"no self crossings"
		end
end
local function Checker5(sp)
	local ii = ii or sp.NM.curr_spline
		
	local points = sp.sccoors[ii]
	if not points then print"No Spline:select spline" return end
	local SR = require"anima.CG3.subramaniam"

	local poly = SR.repair_crossings_split(points)
	prtable(poly)
	sp:newspline(poly)
	-- local polys = SR.repair_crossings_split(points)
	-- for j=1,#polys do
		-- sp:newspline(polys[j])
	-- end

end

local function Checker2(sp)
	local ii = ii or sp.NM.curr_spline
		
	local points = sp.sccoors[ii]
	if not points then print"No Spline:select spline" return end
	
	local points2 = {}
	for i=1,#points do points2[i] = points[i] end
	
	local cross = CHK.check_self_crossings_rep(points2)
		if #cross > 0 then
			sp:newspline(points2)
			--[[
			for j=1,#polys do
				--CG3.degenerate_poly_repair(polys[j],true)
				--local cross = CHK.check_self_crossings(polys[j])
				--if #cross > 0 then print("bad repair crossing with cross") end
				-- table.insert(polyset, polys[j])
				sp:newspline(polys[j])
				--prtable(sp.sccoors[sp.NM.curr_spline])
			end
			--]]
		else
			print"no self crossings"
		end
end

local NM = GL:Dialog("check",{
{"docheck",false,guitypes.button,function() Checker(edit) end},
{"docheck_rep",false,guitypes.button,function() Checker2(edit) end},
{"docheck_rep2",false,guitypes.button,function() Checker3(edit) end},
{"subramaniam",false,guitypes.button,function() Checker4(edit) end},
{"maxsplit",false,guitypes.button,function() Checker5(edit) end},
{"subramaniam contours",false,guitypes.button,function() subramaniam_cont(edit) end},
{"delete_spline",false,guitypes.button,function() edit:deletespline(edit.NM.curr_spline) end},
{"print_spline",false,guitypes.button,function() prtable(edit.sccoors[edit.NM.curr_spline]) end},
{"print_spline_ps",false,guitypes.button,function() prtable(edit.ps[edit.NM.curr_spline]) end},
{"calc_to_spline",false,guitypes.button,function() 
	local inicurspl = edit.NM.curr_spline
	local comp1 = edit.ps[inicurspl]
	local endcurspl = edit:newspline(comp1)
	local comp2 = edit.sccoors[endcurspl]
		print("#",#comp1, #comp2)
		for i,v in ipairs(comp1) do
			if not (v == comp2[i]) then		--v ~= comp2[i] then
				print("diff",i, v, comp2[i])
			end
		end
	end},
{"testsc",false,guitypes.button,function() 
	local curspl = edit.NM.curr_spline
	local comp1 = edit.ps[curspl]
	local comp2 = edit.sccoors[curspl]
		print("#",#comp1, #comp2)
		for i,v in ipairs(comp1) do
			if not (v == comp2[i]) then		--v ~= comp2[i] then
				print("diff",i, v, comp2[i])
			end
		end
	end},
{"load_datapoly",false,guitypes.button,function() 
	local comp1 = dofile("datapoly.lua")[1]
	local box = box2d(comp1)
	local size = box[2] - box[1]
	local sizemax = math.max(size.x, size.y)
	local fac = 800/sizemax
	for i,v in ipairs(comp1) do comp1[i] = (v-box[1])*fac end
	edit:newspline(comp1)
	end},
{"EarClip",false,guitypes.button,function() 
	local curspl = edit.NM.curr_spline
	local comp1 = edit.ps[curspl]
	local ptsr,trs,ok,rest,restind = CG3.EarClipSimple2(comp1, true)
		--assert(ok,ch.cp)
		if not ok then
			print("--------------------------bad EarClip-----------------------------------------")
			--table.insert(Rests,mesh.mesh{points=rest})
		end
		prtable(trs)
	end},
{"degenerate_poly_repair",false,guitypes.button,function() 
	local curspl = edit.NM.curr_spline
	local comp1 = edit.sccoors[curspl]
	local remr,remc = CG3.degenerate_poly_repair(comp1,true)
	print(comp1[1]==comp1[2])
	print(remr, remc)
	end},
{"crossing_repair",false,guitypes.button,function() 
	local CG3 = require"anima.CG3.check_poly"
	local curspl = edit.NM.curr_spline
	local sc = edit.sccoors[curspl]
	local contours = {sc}
	if sc.holes then
		for i=1,#sc.holes do
			table.insert(contours,sc.holes[i])
		end
	end
	
	local polys = CG3.check_repair_contours_crossings(contours)
	prtable(polys)
	for i,pol in ipairs(polys) do
		edit:newspline(pol)
	end
	end},
{"pad",20,guitypes.drag},
{"polypad",false,guitypes.button,function(this) 
	local curspl = edit.NM.curr_spline
	local comp1 = edit.ps[curspl]
	local padded,pad2 = CG3.PolygonPad(comp1,this.pad)
	edit:newspline(padded)
	edit:newspline(pad2)
	end},
{"maskdraw",false,guitypes.toggle}})
local DBox = GL:DialogBox("SPl_check",true)

DBox:add_dialog(NM)
DBox:add_dialog(edit.NM)
local fbo
function GL.init()
	fbo = GL:initFBO({no_depth=true})
end
function GL.imgui()
	--edit.NM:draw()
end
function GL.draw(t,w,h)
	ut.Clear()
	if NM.maskdraw then
		fbo:Bind()
		ut.Clear()
		fbo:UnBind()
		edit:spline2mask(fbo,{1,0,0,0},edit.NM.curr_spline)
		fbo:tex():drawcenter()
	end
end
GL:start()