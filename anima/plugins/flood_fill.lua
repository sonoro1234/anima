require"anima"


local vicim = require"anima.vicimag"
--recursive, produces stack overflow
local function flood_fill_scanline(pd,pd2,x1,x2,y,th)
	local function Cond(x,y)
		return pd:pix(x,y)[0] <= th and pd2:pix(x,y)[0]~=1
	end
	--print("flood fil",x1,x2,y,th)
	local xmin,xmax,ymin,ymax = 0,pd.w-1,0,pd.h-1
	if y < ymin or y > ymax then return end
	--scan left
	local xLs
	for xL=x1,xmin,-1 do
		xLs = xL
		if Cond(xL,y) then
			pd2:pix(xL,y)[0] = 1
		else
			break
		end
	end
	if xLs < x1 then
		flood_fill_scanline(pd,pd2,xLs,x2,y-1,th)
		flood_fill_scanline(pd,pd2,xLs,x2,y+1,th)
		--x1 = x1 + 1
	end
	--scan right
	local xRs
	for xR=x2,xmax do
		xRs = xR
		if Cond(xR,y) then
			pd2:pix(xR,y)[0] = 1
		else
			break
		end
	end
	if xRs > x2 then
		flood_fill_scanline(pd,pd2,x2,xRs,y-1,th)
		flood_fill_scanline(pd,pd2,x2,xRs,y+1,th)
		--x2 = x2 - 1
	end
	--scan between
	local limitx = math.min(x2,xmax)
	for xR=x1,limitx do
		if Cond(xR,y) then
			pd2:pix(xR,y)[0] = 1
		else
			if x1 < xR then
				flood_fill_scanline(pd,pd2,x1,xR-1,y-1,th)
				flood_fill_scanline(pd,pd2,x1,xR-1,y+1,th)
				x1 = xR
			end
			--[[
			while xR <= limitx do
				if Cond(xR,y) then
					pd2:pix(xR,y)[0] = 1
					x1 = xR
					xR = xR - 1
					break
				end
				xR = xR + 1
			end
			--]]
		end
	end
	
end

local function flood_fill_queue_round(pd,pd2,x,y,th, toyield_t, fr_t)
	local function Cond(x,y)
		return pd2:pix(x,y)[0]~=1 and pd:pix(x,y)[0] <= th 
	end
	if Cond(x,y) then
		pd2:pix(x,y)[0] = 1
		pd2:pix(x,y)[3] = 0.5
		local Q = {}
		table.insert(Q,{x=x,y=y})
		while #Q>0 do
			local n = table.remove(Q,1)
			if n.x > 0 then
				if Cond(n.x-1,n.y) then
				pd2:pix(n.x-1,n.y)[0] = 1
				pd2:pix(n.x-1,n.y)[3] = 0.5
				table.insert(Q,{x=n.x-1, y=n.y})
				end
				if n.y > 0 and Cond(n.x-1,n.y-1) then
					pd2:pix(n.x-1,n.y-1)[0] = 1
					pd2:pix(n.x-1,n.y-1)[3] = 0.5
					table.insert(Q,{x=n.x-1,y=n.y-1})
				end
			end
			if n.x < pd.w-1 then
				if Cond(n.x+1,n.y) then
				pd2:pix(n.x+1,n.y)[0] = 1
				pd2:pix(n.x+1,n.y)[3] = 0.5
				table.insert(Q,{x=n.x+1,y=n.y})
				end
				if n.y < pd.h-1 and Cond(n.x+1,n.y+1) then
					pd2:pix(n.x+1,n.y+1)[0] = 1
					pd2:pix(n.x+1,n.y+1)[3] = 0.5
					table.insert(Q,{x=n.x+1,y=n.y+1})
				end
			end
			if n.y > 0 then
				if Cond(n.x,n.y-1) then
				pd2:pix(n.x,n.y-1)[0] = 1
				pd2:pix(n.x,n.y-1)[3] = 0.5
				table.insert(Q,{x=n.x,y=n.y-1})
				end
				if n.x < pd.w-1 and Cond(n.x+1,n.y-1) then
					pd2:pix(n.x+1,n.y-1)[0] = 1
					pd2:pix(n.x+1,n.y-1)[3] = 0.5
					table.insert(Q,{x=n.x+1, y=n.y-1})
				end
			end
			if n.y < pd.h-1 then
				if Cond(n.x,n.y+1) then
				pd2:pix(n.x,n.y+1)[0] = 1
				pd2:pix(n.x,n.y+1)[3] = 0.5
				table.insert(Q,{x=n.x,y=n.y+1})
				end
				if n.x > 0 and Cond(n.x-1,n.y+1) then
					pd2:pix(n.x-1,n.y+1)[0] = 1
					pd2:pix(n.x-1,n.y+1)[3] = 0.5
					table.insert(Q,{x=n.x-1,y=n.y+1})
				end
			end
			
			if (secs_now() - toyield_t) >= fr_t then
				local co,is_main = coroutine.running()
				if not is_main then 
					--print("yield");
					coroutine.yield(pd2) 
				end
				toyield_t = secs_now()
			end
		end

	end
end
local function flood_fill_queue_diamond(pd,pd2,x,y,th, toyield_t, fr_t)
	local function Cond(x,y)
		return pd2:pix(x,y)[0]~=1 and pd:pix(x,y)[0] <= th 
	end
	if Cond(x,y) then
		pd2:pix(x,y)[0] = 1
		pd2:pix(x,y)[3] = 0.5
		local Q = {}
		local iters = 0
		table.insert(Q,{x=x,y=y})
		while #Q>0 do
			local n = table.remove(Q,1)
			iters = iters + 1
			if n.x > 0 and Cond(n.x-1,n.y) then
				pd2:pix(n.x-1,n.y)[0] = 1
				pd2:pix(n.x-1,n.y)[3] = 0.5
				table.insert(Q,{x=n.x-1, y=n.y})
			end
			if n.x < pd.w-1 and Cond(n.x+1,n.y) then
				pd2:pix(n.x+1,n.y)[0] = 1
				pd2:pix(n.x+1,n.y)[3] = 0.5
				table.insert(Q,{x=n.x+1,y=n.y})
			end
			if n.y > 0 and Cond(n.x,n.y-1) then
				pd2:pix(n.x,n.y-1)[0] = 1
				pd2:pix(n.x,n.y-1)[3] = 0.5
				table.insert(Q,{x=n.x,y=n.y-1})
			end
			if n.y < pd.h-1 and Cond(n.x,n.y+1) then
				pd2:pix(n.x,n.y+1)[0] = 1
				pd2:pix(n.x,n.y+1)[3] = 0.5
				table.insert(Q,{x=n.x,y=n.y+1})
			end
			if iters%1000==0 then
			if (secs_now() - toyield_t) >= fr_t then
				local co,is_main = coroutine.running()
				if not is_main then 
					--print("yield");
					coroutine.yield(pd2) 
				end
				toyield_t = secs_now()
			end
			end
		end
		print("=====iters",iters)
	end
end
local function flood_fill_recurse(pd,pd2,x,y,th)
	if pd:get_pix(x,y)[0] <= th and pd2:get_pix(x,y)[0] ~= 1 then
		pd2:get_pix(x,y)[0] = 1
		if x > 0 then
			flood_fill_recurse(pd,pd2,x-1,y,th)
		end
		if x < pd.w-1 then
			flood_fill_recurse(pd,pd2,x+1,y,th)
		end
		if y > 0 then
			flood_fill_recurse(pd,pd2,x,y-1,th)
		end
		if y < pd.h-1 then
			flood_fill_recurse(pd,pd2,x,y+1,th)
		end
	end
end
local function flood_fill_scanline_queue(pd,pd2,ix1,ix2,iy,th)
	local function Cond(x,y)
		return pd:pix(x,y)[0] <= th and pd2:pix(x,y)[0]~=1
	end
	local Q = {}
	--print("flood fil",x1,x2,y,th)
	local xmin,xmax,ymin,ymax = 0,pd.w-1,0,pd.h-1
	table.insert(Q,{x1=ix1,x2=ix2,y=iy})
	while #Q > 0 do
	local n = table.remove(Q)--,1)
	local x1,x2,y = n.x1,n.x2,n.y
	if y < ymin or y > ymax then goto SKIP end
	--scan left
	local xLs
	for xL=x1,xmin,-1 do
		xLs = xL
		if Cond(xL,y) then
			pd2:pix(xL,y)[0] = 1
		else
			break
		end
	end
	if xLs < x1 then
		--flood_fill(pd,pd2,xLs,x2,y-1,th)
		--flood_fill(pd,pd2,xLs,x2,y+1,th)
		table.insert(Q,{x1=xLs,x2=x2,y=y-1})
		table.insert(Q,{x1=xLs,x2=x2,y=y+1})
		--x1 = x1 + 1
	end
	--scan right
	local xRs
	for xR=x2,xmax do
		xRs = xR
		if Cond(xR,y) then
			pd2:pix(xR,y)[0] = 1
		else
			break
		end
	end
	if xRs > x2 then
		--flood_fill(pd,pd2,x2,xRs,y-1,th)
		--flood_fill(pd,pd2,x2,xRs,y+1,th)
		table.insert(Q,{x1=x2,x2=xRs,y=y-1})
		table.insert(Q,{x1=x2,x2=xRs,y=y+1})
		--x2 = x2 - 1
	end
	--scan between
	local limitx = math.min(x2,xmax)
	for xR=x1,limitx do
		if Cond(xR,y) then
			pd2:pix(xR,y)[0] = 1
		else
			if x1 < xR then
				--flood_fill(pd,pd2,x1,xR-1,y-1,th)
				--flood_fill(pd,pd2,x1,xR-1,y+1,th)
				table.insert(Q,{x1=x1,x2=xR-1,y=y-1})
				table.insert(Q,{x1=x1,x2=xR-1,y=y+1})
				x1 = xR
			end
			
		end
	end
	::SKIP::
	end --Q
end





local vert_count = [[

uniform sampler2D tex0;
uniform sampler2D tex1;

in vec3 position;
out vec4 color;
void main()
{
	vec4 col1 = texelFetch(tex0, ivec2(position.xy), 0);
	vec4 col2 = texelFetch(tex1, ivec2(position.xy), 0);
	float dif = abs(col1.r-col2.r);
	if(dif>0)
		color = vec4(1.0);
	else
		color = vec4(0.0);
	gl_Position = vec4(0, 0, 0.0, 1.0); 

}

]]


local frag_count = [[

out vec4 fcolor;
in vec4 color;
void main()
{
	fcolor = color;
}
]]


local vert_coldist=[[
in vec3 position;
in vec2 texcoords;
out vec2 texcoord_f;
void main(){
	texcoord_f = texcoords;
	gl_Position = vec4(position,1); 
}
]]

local vert_flood = [[

in vec3 position;
void main(){
	gl_Position = vec4(position,1);
}

]]
local frag_flood = [[

uniform sampler2D tex;
uniform sampler2D texdist;
uniform float threshold;
uniform vec2 point;
//uniform int kernelsize = 1;
out vec4 fcolor;
void main()
{
	//if(gl_FragCoord.xy==point){
	if(length(gl_FragCoord.xy-point)<1.0){
		fcolor = vec4(1.0,0.0,0.0,0.5);
		return;
	}
	float valmax = 0.0;
	float valdist = texelFetch(texdist,ivec2(gl_FragCoord.xy),0).r;
	if (valdist >= threshold){
		fcolor = vec4(0.0);
	}else{
	for(int x=-1;x<=1;x++){
		for(int y=-1;y<=1;y++){
			float val = texelFetch(tex,ivec2(gl_FragCoord.xy)+ivec2(x,y),0).r;
			valmax = max(valmax,val);
		}
	}
	float alpha = 0.0;
	if (valmax > 0.0){
		valmax = 1.0;
		alpha = 0.5;
	}
	fcolor = vec4(valmax,0.0,0.0,alpha);
	//fcolor = vec4(vec3(valmax),0.5);
	}
}

]]

local frag_coldist=require"anima.GLSL.GLSL_color"..[[

vec3 labscale = vec3(1.0/100.0,1.0/115.0,1.0/115.0);
//a* is -79 to 94, and the range of b* is -112 to 93
vec3 laboffset = vec3(0.0,0.5,0.5);
float LabDistance(vec3 col1,vec3 col2){
	vec3 collab1 = XYZ2LAB(RGB2XYZ(sRGB2RGB(col1)),D65);
	vec3 collab2 = XYZ2LAB(RGB2XYZ(sRGB2RGB(col2)),D65);
	
	collab1 = collab1*labscale + laboffset;
	collab2 = collab2*labscale + laboffset;
	
	return distance(collab1,collab2);
	//return distance(collab1.yz,collab2.yz);

}

uniform sampler2D tex;

uniform vec2 point;
in vec2 texcoord_f;
vec3 refcolor = texelFetch(tex,ivec2(point),0).rgb;
out vec4 fcolor;
void main(){

	vec4 color = texture2D(tex,texcoord_f);
	float dis = LabDistance(color.rgb,refcolor);
	fcolor = vec4(dis);
}

]]

local function DoMESH(w, h,prog)
print("DoMESH flood_fill",w, h,prog)
	local zplane = 0
	local Pos = ffi.new("float[?]",w*h*3)
	local ind = 0
	for i=0,w-1,1 do
		for j=0,h-1,1 do
			Pos[ind] = i
			Pos[ind+1] = j
			Pos[ind+2] = zplane
			ind = ind + 3
		end
	end
	local MM = {vao =  VAO({position=Pos},prog)}
	Pos = nil
	function MM:delete()
		MM.vao:delete()
	end
	function MM:draw(X,W)
		local ini = (X*h)
		local count = W*h
		MM.vao:draw(glc.GL_POINTS,count, ini)
	end
	return MM
end

local progcoldist

local function FloodF(GL)
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}
	
	local DOFINDCOMPONENTS, CALCDISTANCES,DOFINDCOMPONENTSth
	local fbo, adder
	local picking = false
	
	-------------------------------------
	local saved_mask 
	local mask_repair = require"anima.plugins.texture_processor"(GL,1)
	mask_repair:set_process[[vec4 process(vec2 pos){
				return vec4(c1.r,0.0,0.0,c1.r*0.5);
		}]]
	-- save masks
	local function save_mask(fname)
		saved_mask = fname
		M.mask:save(fname, "PNG", nil , glc.GL_RED)
	end
	local fbsave = gui.FileBrowser(nil,{check_existence=true,filename="mask",key="fbsaveFF",pattern="png",addext=true},save_mask)
	-- load masks
	local function load_mask(fname)
		saved_mask = fname
		M.mask:Load(fname, nil, true)
		local fbo1 = GL:initFBO({no_depth=true})
		mask_repair:process_fbo(fbo1, {M.mask})
		M.mask = fbo1:texcopy()
		M.mask:Bind()
		M.mask:gen_mipmap()
		M.NM.dirty = true
		--M.mask:save(fname.."CHK.png")
	end
	local fbload = gui.FileBrowser(nil,{filename="mask",key="fbloadFF",pattern="png"},load_mask)
	
	local NM = GL:Dialog("flood_fill",{
	{"threshold",0.1,guitypes.val,{min=0,max=0.4,is_deactivated=true},function() DOFINDCOMPONENTS=true end},
	{"op",1,guitypes.slider_enum,{"simple","add","subs",sameline=false}},
	{"use_gpu",false,guitypes.toggle, function() DOFINDCOMPONENTS=true end,{sameline=false}},
	{"point",{187,520},guitypes.drag,{sameline=false}},
	{"pick",0,guitypes.button,function(this) 
		--isitemdeactivatedafteredit
		picking = true
		GL.mouse_pick = {action=function(X,Y)
							
							print("point",GL:ScreenToViewport(X,Y))
							--this.vars.color:set{pUD[0],pUD[1],pUD[2]} 
							this.vars.point:set{GL:ScreenToViewport(X,Y)} 
							GL.mouse_pick = nil
							--GL.fbo_nearest = false
							--this.vars.orig[0] = false
							DOFINDCOMPONENTS = true
							CALCDISTANCES = true
							this.dirty = true
							GL:SetCursor(nil)
							picking = false
							--Flood_fill(fbo:tex(),tex2, this.point,this.threshold)
						end}

end,{sameline=false}},

},function()
	ig.Separator()
	if ig.SmallButton("save mask") then
		fbsave.open()
	end
	fbsave.draw()
	ig.SameLine()
	if ig.SmallButton("load mask") then
		fbload.open()
	end
	fbload.draw()
	
	if picking then GL:SetCursor(GL.cursors.pickcolor) end
end)
	M.NM = NM
	NM.plugin = M
	-----------------------------
	local program_flood, program_count, quad_count, fbo_count
	local slab
	local corut
	local min, max = math.min, math.max
	local function dif_count(tex1,tex2,X,i)
		if not quad_count then
			quad_count = DoMESH(GL.W, GL.H,program_count);
		end
		local X1, W1 = max(0,X-i), min(M.res[1],2*i+1)
		program_count:use()
		fbo_count:Bind()

		tex1:Bind()--:set_wrap(glc.GL_CLAMP_TO_EDGE)
		tex2:Bind(1)--:set_wrap(glc.GL_CLAMP_TO_EDGE)
		program_count.unif.tex0:set{0}
		program_count.unif.tex1:set{1}

		gl.glViewport(0, 0, 1, 1)
	
		gl.glEnable(glc.GL_BLEND)
		gl.glBlendFunc(glc.GL_ONE,glc.GL_ONE)
		glext.glBlendEquation(glc.GL_FUNC_ADD)
		gl.glDisable(glc.GL_DEPTH_TEST);
	
		gl.glClearColor(0.0, 0.0, 0.0, 0)
		gl.glClear(bit.bor(glc.GL_COLOR_BUFFER_BIT,glc.GL_DEPTH_BUFFER_BIT))
		
		gl.glPointSize(1.5)
		
		quad_count:draw(X1,W1)--glc.GL_POINTS)

		gl.glDisable(glc.GL_BLEND)
		fbo_count:UnBind()
		
		gl.glPointSize(1)
		local histovalues = ffi.new("float[?]",1,1)
		fbo_count:get_pixels(glc.GL_RED,glc.GL_FLOAT,0,histovalues)
		return histovalues[0]
	end
	local function flood_fill_gpu(texdist,tex2,X,Y,threshold, toyield_t, fr_t)
		local program = program_flood
		--clear slab
		gl.glClearColor(0,0,0,0)
		slab:Bind()
		ut.Clear()
		slab:UnBind()
		slab:Bind()
		ut.Clear()
		slab:UnBind()
		------------------------

		local function set_viewport(i)
			gl.glViewport(max(0,X-i),max(0,Y-i),min(M.res[1],2*i+1),min(M.res[2],2*i+1))
			-- gl.glViewport(0,0,M.res[1],M.res[2])
		end
		local function setprog(i)
			program:use()
			--slab:Bind()
	
			--tex2:Bind(0)
			texdist:Bind(1)
			
			program.unif.tex:set{0}
			program.unif.texdist:set{1}
			program.unif.threshold:set{threshold}
			program.unif.point:set{X,Y}
			--gl.glViewport(0,0,w or M.res[1], h or M.res[2])
			--gl.glViewport(X-i,Y-i,X+i,Y+i)
			set_viewport(i)
		end
		setprog(1)
		slab:Bind()
		tex2:Bind(0)
		texdist:Bind(1)
		program.vaos[1]:draw_elm()
		slab:UnBind()
		local i = 1
		--for i=2,10000 do
		while true do
			i = i + 1
			--setprog(i)
			slab:tex():Bind(0)
			slab:Bind()
			program.vaos[1]:draw_elm()
			slab:UnBind()
			local count = 1
			if i%100==0 then
				count = dif_count(slab.ping:tex(),slab.pong:tex(),X,i)
				--print(i,count)
				if count==0 then print("====================",i,"iterations");break end
				if (secs_now() - toyield_t) >= fr_t then
					local co,is_main = coroutine.running()
					if not is_main then 
						--print("yield");
						coroutine.yield(slab:tex()) 
					end
					toyield_t = secs_now()
					--setprog(i)
				end
				setprog(i)
			else
				set_viewport(i)
			end
		end
		return slab:tex()
	end
	local function flood_fill(pd,pd2,X,Y,threshold, toyield_t, fr_t)
		--return flood_fill_scanline_queue(pd,pd2,X,X,Y,threshold) --0.9
		--return flood_fill_scanline(pd,pd2,X,X,Y,threshold) --stack overflow
		-- return flood_fill_queue_round(pd,pd2,X,Y,threshold, toyield_t, fr_t) 
		return flood_fill_queue_diamond(pd,pd2,X,Y,threshold, toyield_t, fr_t)
		--return flood_fill_gpu(pd,pd2,X,Y,threshold, toyield_t, fr_t)
		--return flood_fill_recurse(pd,pd2,X,Y,threshold) -- stack overflow
	end
	local function Flood_fill_finish(tex2,pd2)
		tex2:set_data(pd2.data, 4, 4)
		return pd2
	end
	local function Flood_fill(tex,tex2,point,threshold)
		local ini_ti = secs_now()
		local fr_t = 1/10
		local toyield_t = ini_ti
		local X,Y = math.floor(point[0]+0.5),math.floor(point[1]+0.5)
		local data = tex:get_pixels(glc.GL_FLOAT,glc.GL_RED)
		--print("tex dims",tex.width,tex.height)
		local pd = vicim.pixel_data(data,tex.width,tex.height,1)
		local pd2 = vicim.pixel_data(nil,pd.w, pd.h, 4)
		
		threshold = threshold or pd:get_pix(X,Y)[0]
		--print("pd:get_pix(X,Y)[0]",pd:get_pix(X,Y)[0])
		--assert(pd:get_pix(X,Y)[0]==0)
		flood_fill(pd,pd2,X,Y,threshold, toyield_t, fr_t)
		
		Flood_fill_finish(tex2,pd2)
		print("flood_fill time",secs_now()-ini_ti)
		return pd2, true
	end
	local function Flood_fill_gpu(tex,tex2,point,threshold)
		local ini_ti = secs_now()
		local fr_t = 1/10
		local toyield_t = ini_ti
		--local X,Y = math.floor(point[0]+0.5),math.floor(point[1]+0.5)
		local X,Y = math.floor(point[0]),math.floor(point[1])
		print("X,Y",X,Y)
		--print("pd:get_pix(X,Y)[0]",pd:get_pix(X,Y)[0])
		--assert(pd:get_pix(X,Y)[0]==0)
		tex2 = flood_fill_gpu(tex,tex2,X,Y,threshold, toyield_t, fr_t)
		
		--Flood_fill_finish(tex2,pd2)
		print("flood_fill time",secs_now()-ini_ti)
		return tex2, true
	end
	-----------------------------
	function M:Set_WH()
		fbo = GL:initFBO({no_depth=true})
		--M.fbo = fbo
		M.mask = GL:Texture(GL.W,GL.H)
		slab = GL:make_slab()
		if quad_count then quad_count:delete();quad_count=nil end
		--quad_count = DoMESH(GL.W, GL.H,program_count);
	end
	function M:init()
		if not progcoldist then
			progcoldist = GLSL:new():compile(vert_coldist,frag_coldist)
			program_flood = GLSL:new():compile(vert_flood,frag_flood)
			program_count = GLSL:new():compile(vert_count,frag_count)
			fbo_count = GL:initFBO({no_depth=true},1,1)
			--quad_count = DoMESH(GL.W, GL.H,program_count);
			mesh.quad():vao(progcoldist)
			mesh.quad():vao(program_flood)
		end
		fbo = GL:initFBO({no_depth=true})
		--M.fbo = fbo
		M.mask = GL:Texture(GL.W,GL.H)
		slab = GL:make_slab()
		adder = require"anima.plugins.texture_processor"(GL,2,NM)
		adder:set_process[[vec4 process(vec2 pos){
			if(op==2)
			return max(c1,c2);
			if(op==3){
			   if(c1.r >=1){
					if(c2.r>=1)
						return c1 - c2;
					else
						return c1;
			   }else
					return c1;
					
			}
		}]]
	end

	local texsign
	local texF,fboF
	function M:process(texture)
		if GL.dirty_wrapped and (not texsign or texsign~=texture:get_signature()) then
			--DOFINDCOMPONENTS = true
			texsign = texture:get_signature()
		end

		if corut or DOFINDCOMPONENTS then
			if DOFINDCOMPONENTS then
				saved_mask = nil
				--print"----pick"
				if CALCDISTANCES then
					--print("CALCDISTANCES---")
					fbo:Bind()
					ut.Clear()
					progcoldist:use()
					local U = progcoldist.unif
					U.tex:set{0}
					U.point:set(NM.point)
					texture:Bind()
					fbo:viewport()
					progcoldist.vaos[1]:draw_elm()
					fbo:UnBind()
					CALCDISTANCES = false
				end
			
				if NM.op>1 then
					texF = GL:Texture(GL.W,GL.H)
					fboF = GL:initFBO{no_depth=true}
				else
					texF = GL:Texture(GL.W,GL.H)--self.mask
					fboF = GL:initFBO{no_depth=true}
				end
				--print("texF = self.mask",texF == self.mask,texF, self.mask)
				--Flood_fill(fbo:tex(),texF, NM.point,NM.threshold)
				local ffprog
				if NM.use_gpu then
					--self.mask 
					--texF = Flood_fill_gpu(fbo:tex(),texF, NM.point,NM.threshold)
					ffprog = Flood_fill_gpu
				else
					ffprog = Flood_fill
				end --not gpu
				---[[
				corut = coroutine.create(ffprog)
				self.always_dirty = true
				local ok,pd22,finished = coroutine.resume(corut, fbo:tex(),texF, NM.point,NM.threshold ) 
				if not ok then 
					print(pd22, "status:", coroutine.status(corut))
					self.always_dirty = nil
					corut = nil
				elseif finished then --finished
					self.always_dirty = nil
					corut = nil
					if NM.use_gpu then
						texF = pd22
					end
				else --doing
					if NM.use_gpu then
						texF = pd22
					else
						Flood_fill_finish(texF, pd22)
					end
				end
				--]]

			elseif corut and coroutine.status(corut)~="dead" then
				--print("resumme")
				--print("texF = self.mask",texF == self.mask,texF, self.mask)
				local ok,pd22,finished = coroutine.resume(corut, fbo:tex(),texF, NM.point,NM.threshold ) 
				if not ok then 
					print(pd22, "status:", coroutine.status(corut))
					self.always_dirty = nil
					corut = nil
				elseif finished then --finished
					self.always_dirty = nil
					corut = nil
					if NM.use_gpu then
						texF = pd22
					end
				else --doing
					if NM.use_gpu then
						texF = pd22
					else
						Flood_fill_finish(texF, pd22)
					end
				end
			end
			if NM.op>1 then
				--print"adding"
				--print("texF = self.mask",texF == self.mask,texF, self.mask)
				adder:process_fbo(fboF,{self.mask,texF})
				self.mask = fboF:texcopy()
			else
				fboF:Bind()
				texF:blit()
				fboF:UnBind()
				self.mask = fboF:texcopy()
			end
			self.mask:inc_signature()
			DOFINDCOMPONENTS = false
		end
	end
	function M:show_mask()
		ut.ClearDepth()
			gl.glEnable(glc.GL_BLEND)
			gl.glBlendFunc(glc.GL_SRC_ALPHA, glc.GL_ONE_MINUS_SRC_ALPHA)
			glext.glBlendEquation(glc.GL_FUNC_ADD)
			self.mask:drawcenter()
			gl.glDisable(glc.GL_BLEND)
	end
	GL:add_plugin(M,"flood_fill")
	return M
end
---------------------
---[=[
if not ... then
local GL = GLcanvas{H=1000,aspect=1,DEBUG=false,fbo_nearest=false,use_log = true}


local path = require"anima.path"
--fileName = [[C:\luaGL\frames_anima\msquares\imagen.png]]
fileName = [[C:\luaGL\frames_anima\im_test\Cosmos_original.jpg]]
--fileName = path.this_script_path()..[[\imagenes\unnamed0.jpg]]
--fileName=[[C:\luagl\animacion\resonator6\resonator-038.jpg]]
--fileName = [[C:\LuaGL\frames_anima\flood_fill\dummy.png]]
--fileName = [[C:\LuaGL\frames_anima\edges_detection\flowers2.png]]
--fileName = [[C:/anima64bueno/examples/inpaint/twozones.png]]
fileName = [[c:\luagl\media\estanque-001.jpg]]
fileName = [[c:\luagl\media\estanque7.jpg]]
-- fileName = "c:/luagl/media/piscina.tif"
--fileName = "c:/luagl/media/espiral.png"
local texture
local FF,mixer,fbo
function GL.init()
	
	texture = GL:Texture():Load(fileName)
	--texture = texture:resample_fac(0.25)
	GL:set_WH(texture.width,texture.height)
	FF = FloodF(GL)
	--mixer = require"anima.plugins.mixer"(GL,2)
	fbo = GL:initFBO{no_depth=true}
	GL:DirtyWrap()
end
function GL.imgui()
	ig.ShowDemoWindow()
end
function GL.draw(t,w,h)

gl.glClearColor(0,0,0,0)
	ut.Clear()
	--FF:process_fbo(fbo,texture)
	--fbo:tex():drawcenter()
	FF:process(texture)
	texture:drawcenter()
	FF:show_mask()
	-- ut.ClearDepth()
	-- FF.mask:drawcenter()
	-- mixer.NM.dirty = true
	-- ut.Clear()
	-- mixer:process{texture,FF.tex2}

end


GL:start()
end
--]=]
return FloodF