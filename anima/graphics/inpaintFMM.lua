
--based on
--https://github.com/antimatter15/inpaint.js
---------------------
local function inpaintFMM3(width,height,image,maskpd,eik,radius,progress)
	radius = radius or 5
	progress = progress or function() end
	
	local priority_queue = require"anima.algorithm.priority_queue"
	local vicim = require"anima.vicimag"
	
	local floor, sqrt, min, abs = math.floor, math.sqrt, math.min, math.abs
	local LARGE_VALUE = 1e6;
	local SMALL_VALUE = 1e-6;

	local size = width * height;
	local sizem1 = size -1
	local flagpd = vicim.pixel_data(nil,width,height,1) --ffi.new("float[?]",size)
	local flag = flagpd.data
	local mask = maskpd.data
	local u = eik --ffi.new("float[?]",size)
	
	
	local KNOWN = 0
	local BAND = 1
	local INSIDE = 2
	
	--[[
	for i,j,mpix in maskpd:iterator() do
		if mpix[0] == 1 then
			for dx,dy,fpix in flagpd:square_it(i,j,1) do
				--cross shape
				if dx==0 or dy==0 then
					fpix[0] = 1
				end
			end
		end
	end
	--]]
	---[[
	for i,j,mpix in maskpd:iterator() do
		if mpix[0] == 1 then
			local n = j*width + i
			if i < width-1 then flag[n + 1] = 1 end
			if j < height-1 then flag[n + width] = 1 end
			if i > 0 then flag[n - 1] = 1 end
			if j > 0 then flag[n - width] = 1 end
		end
	end
	--]]
	local function XOR(a,b)
		return ((a>0 and b==0) or (a==0 and b>0)) and 1 or 0
	end
	
	local sizemask = 0
	for i = 0,sizem1 do
		flag[i] = (flag[i] * 2) - XOR(mask[i] , flag[i])
		if(flag[i] == INSIDE) then 
			u[i] = LARGE_VALUE;
			sizemask = sizemask+1
		end
	end
	
	local heap = priority_queue()
	
	for i = 0,sizem1 do
		if flag[i]==BAND then
			heap:put(i,u[i])
		end
	end
	
	local indices_centered = {}
	-- generate a mask for a circular structuring element
	for i = -radius,radius do
		local h = floor(sqrt(radius * radius - i * i))
		for  j = -h, h do
			table.insert(indices_centered,(i + j * width))
		end
	end
	
	local function eikonal(n1, n2)
		local u_out = LARGE_VALUE
		if n1 < 0 or n1>sizem1 or n2 < 0 or n2 > sizem1 then return u_out end
		local u1 = u[n1]
		local u2 = u[n2]
		--assert(flag[n1]~=0 and u2~=0)
		if(flag[n1] == KNOWN) then
			if(flag[n2] == KNOWN) then
				local perp = sqrt(2 - (u1 - u2) * (u1 - u2));
				local s = (u1 + u2 - perp) * 0.5;
				if(s >= u1 and s >= u2) then
					u_out = s
				else
					s = s + perp;
					if(s >= u1 and s >= u2) then
						u_out = s;
					end
				end
			else
				u_out = 1 + u1
			end
		elseif(flag[n2] == KNOWN) then
			u_out = 1 + u2
		end
		return u_out
	end
	
	-- this is meant to return the x-gradient
	local function grad_func(array, n, step)
		if flag[n + step] ~= INSIDE then 
			if(flag[n - step] ~= INSIDE) then
				return (array[n + step] - array[n - step]) * 0.5
			else
				return array[n + step] - array[n]
			end
		else
			if(flag[n - step] ~= INSIDE) then
				return array[n] - array[n - step]
			else
				return 0
			end
		end
	end
	
	local function inpaint_point(n)
		local Ia, norm = ffi.new("float[?]",image.p), 0
		-- var Jx = 0, Jy = 0;
		local gradx_u = grad_func(u, n, 1)
		local grady_u = grad_func(u, n, width); 
		
		local i = n % width
		local j = floor(n / width);


		for k,centerind in ipairs(indices_centered) do
			local nb = n + centerind;
			--if nb < 0 or nb > sizem1 then goto continue end
			local i_nb = nb % width
			local j_nb = floor(nb / width);

			--if(i_nb <= 1 or j_nb <= 1 or i_nb >= width - 1 or j_nb >= height - 1) then goto continue end
			if(i_nb <= 1 or j_nb <= 1 or i_nb >= width - 1 or j_nb >= height - 1) then goto continue end

			if(flag[nb] ~= KNOWN) then goto continue end 

			local rx = i - i_nb
			local ry = j - j_nb;

			local geometric_dst = 1 / ((rx * rx + ry * ry) * sqrt(rx * rx + ry * ry))
			local levelset_dst = 1 / (1 + abs(u[nb] - u[n]))
			local direction = abs(rx * gradx_u + ry * grady_u);
			local weight = geometric_dst * levelset_dst * direction + SMALL_VALUE;
			-- var gradx_img = grad_func(image, nb, 1) + SMALL_VALUE,
			-- 	grady_img = grad_func(image, nb, width) + SMALL_VALUE;
			
			--Ia = Ia + weight * image[nb]
			for l=0,image.p-1 do
				Ia[l] = Ia[l] + weight* image:lpix(nb)[l]
			end
			
			-- Jx -= weight * gradx_img * rx
			-- Jy -= weight * grady_img * ry
			norm = norm + weight
			::continue::
		end
		-- the fmm.py which this is based on actually implements a slightly different
		-- algorithm which apparently "considers the effect of gradient of intensity value"
		-- which is some kind of voodoo magic that I don't understand which is apparently
		-- in the OpenCV implementation. Unless I've been porting the algorithm wrong,
		-- which is certainly a possibility and I invested quite a bit of effort into
		-- that hypothesis by way of rewriting and checking every line of code a few
		-- times. 
		--image[n] = Ia / norm;
			for l=0,image.p-1 do
				image:lpix(n)[l] = Ia[l]/norm
			end
		-- image[n] = Ia / norm + (Jx + Jy) / Math.sqrt(Jx * Jx + Jy * Jy);
	end
	
	local maskdone = 0
	while(not heap:empty()) do
		
		local n = heap:pop();
		local i = n % width
		local j = floor(n / width);
		flag[n] = KNOWN
		--if(i <= 1 or j <= 1 or i >= width - 1 or j >= height - 1) then goto continue end
		--if(i <= 0 or j <= 0 or i >= width - 1 or j >= height - 1) then goto continue end
		if(i < 0 or j < 0 or i > width - 1 or j > height - 1) then goto continue end
		for _,k in ipairs{-width, -1, width, 1} do
			local nb = n + k
			if flag[nb] ~= KNOWN then
				
				
				u[nb] = min(eikonal(nb - width, nb - 1),
                                 eikonal(nb + width, nb - 1),
                                 eikonal(nb - width, nb + 1),
                                 eikonal(nb + width, nb + 1));
			 
				if(flag[nb] == INSIDE) then
					flag[nb] = BAND
					heap:put(nb,u[nb])
					inpaint_point(nb)
					maskdone = maskdone + 1
					progress(maskdone/sizemask)
				end
			end
		end
		::continue::
	end
	
	local maxU = -math.huge
	for i=0,sizem1 do maxU = maxU < u[i] and u[i] or maxU end
	for i=0,sizem1 do u[i] = u[i]/maxU  end
	
end

return inpaintFMM3
