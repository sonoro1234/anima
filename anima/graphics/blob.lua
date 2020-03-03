--taken from https://github.com/BlockoS/blob, which is an
-- implementation of "A linear-time component-labeling algorithm using contour
-- tracing technique" by Fu Chang, Chun-Jen Chen, and Chi-Jen Lu.


require"anima"
local vicim = require"anima.vicimag"
local vec2 = mat.vec2


local M = {}

function M.find_boundary(tex)
	
	local data = tex:get_pixels(glc.GL_FLOAT,glc.GL_RED)
	local pd = vicim.pixel_data(data,tex.width,tex.height,1)
	local pdlabel = vicim.pixel_data(nil,tex.width,tex.height,1)
	--set border label
	pdlabel:pix(-1,0)[0] = -1
	assert(pdlabel:pix(0,pdlabel.h)[0]==-1)
	
	local neigs = {[0]=vec2(1,0),vec2(1,1),vec2(0,1),vec2(-1,1),vec2(-1,0),vec2(-1,-1),vec2(0,-1),vec2(1,-1)}
	local function contour_trace(external,current,pd,pdlabel,x,y,poly)
		local band = bit.band
		local i = external and 7 or 3
		local c = vec2(x,y)
		local x0 = vec2(x,y);
		local xx = vec2(-1,-1);
		local done = false;
		pdlabel:pixR(x,y)[0] = current
		
		while not done do
			poly[#poly+1] = x0
			local found = false
			for j=0,7 do
				local x1 = x0 + neigs[i]
				if x1.x < 0 or x1.x >= pd.w then goto continue end
				if x1.y < 0 or x1.y >= pd.h then goto continue end
				
				if (pd:pixR(x1.x,x1.y)[0] > 0.5) then
					pdlabel:pixR(x1.x,x1.y)[0] = current
					if xx.x < 0 and xx.y < 0 then
						xx = x1 
					else
						done = c == x0 and xx == x1
					end
					x0 = x1
					found = true
					break
				else
					pdlabel:pixR(x1.x,x1.y)[0] = -1
				end
				::continue::
				i = (i + 1)%8
				-- i = band(i + 1, 7)
			end
			if not found then
				done = true -- isolated point
			end
			i = (i + 6)%8
			-- local previous = (i + 4)%8
			-- i = (previous + 2)%8
			-- local previous = band(i + 4, 7)
			-- i = band(previous + 2, 7)
		end
		--delete repeated ini end point
		poly[#poly] = nil
		return true
	end
	
	local polys = {}
	local current = 1 --current label
	for i,j,pix in pd:iterator() do
		if pix[0]>0.5 then
			local below_in  = pd:pix(i,j-1)[0]; --(j > 0) ? *(ptr_in - in_w) : 0;
            local above_in  = pd:pix(i,j+1)[0] --(j < (roi_h-1)) ? *(ptr_in + in_w) : 0; 
            local above_label = pdlabel:pix(i,j+1)[0] --(j < (roi_h-1)) ? *(ptr_label + roi_w) : -1;
			
			local this_label = pdlabel:pixR(i,j)[0]
			--new external contour
			if this_label==0 and below_in < 0.5 then
				polys[#polys+1] = {holes={}}
				contour_trace(true,current,pd,pdlabel,i,j,polys[#polys])
				current = current + 1
			-- new internal contour
			elseif above_in < 0.5 and above_label == 0 then
				local current_label = this_label ~= 0 and this_label or (pdlabel:pixR(i,j)-1)[0]
				local current_poly = polys[current_label]
				current_poly.holes[#current_poly.holes + 1] = {}
				contour_trace(false,current_label,pd,pdlabel,i,j,current_poly.holes[#current_poly.holes])
			--internal point, extend interior label
			elseif this_label == 0 then
				pdlabel:pixR(i,j)[0] = i>0 and pdlabel:pixR(i-1,j)[0] or 0
			end
		end
	end
	
	return polys
end

function M.sanitize_boundary(polys)
	local function mod(a,b)
		return ((a-1)%b)+1
	end
	--sanitize repeated points between poly and holes
	for npoly,poly in ipairs(polys) do
		--avoid self repetition
		local modpoly = {}
		for i=1,#poly-1 do
			local pt = poly[i]
			for j=i+1,#poly do
			local pt2 = poly[j]
				if pt==pt2 then 
					local a = poly[i] - poly[mod(i-1,#poly)]
					local b = poly[mod(i+1,#poly)] - poly[i]
					local ap = vec2(-a.y,a.x).normalize 
					local bp = vec2(-b.y,b.x).normalize
					local cp = (0.5*(ap+bp)).normalize
					modpoly[i] = poly[i] - cp*0.025 --out
					local a = poly[j] - poly[mod(j-1,#poly)]
					local b = poly[mod(j+1,#poly)] - poly[j]
					local ap = vec2(-a.y,a.x).normalize 
					local bp = vec2(-b.y,b.x).normalize
					local cp = (0.5*(ap+bp)).normalize
					modpoly[j] = poly[j] - cp*0.025 --out
				end
			end
		end
		for k,v in pairs(modpoly) do poly[k] = v end
		--contract holes
		for ih,hole in ipairs(poly.holes) do
			local modhole = {}
			for j=1,#hole do
				--if pt == hole[j] then
					local a = hole[j] - hole[mod(j-1,#hole)]
					local b = hole[mod(j+1,#hole)] - hole[j]
					local ap = vec2(a.y,-a.x).normalize 
					local bp = vec2(b.y,-b.x).normalize
					local cp = (0.5*(ap+bp)).normalize
					modhole[j] = hole[j] + cp*0.05
				--end
			end
			--copy
			for k,v in pairs(modhole) do hole[k] = v end
		end
	end
end

return M