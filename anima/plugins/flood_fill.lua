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
local function flood_fill_queue(pd,pd2,x,y,th)
	local function Cond(x,y)
		return pd2:pix(x,y)[0]~=1 and pd:pix(x,y)[0] <= th 
	end
	if Cond(x,y) then
		pd2:pix(x,y)[0] = 1
		local Q = {}
		table.insert(Q,{x=x,y=y})
		while #Q>0 do
			local n = table.remove(Q)--,1)
			if n.x > 0 and Cond(n.x-1,n.y) then
				pd2:pix(n.x-1,n.y)[0] = 1
				table.insert(Q,{x=n.x-1, y=n.y})
			end
			if n.x < pd.w-1 and Cond(n.x+1,n.y) then
				pd2:pix(n.x+1,n.y)[0] = 1
				table.insert(Q,{x=n.x+1,y=n.y})
			end
			if n.y > 0 and Cond(n.x,n.y-1) then
				pd2:pix(n.x,n.y-1)[0] = 1
				table.insert(Q,{x=n.x,y=n.y-1})
			end
			if n.y < pd.h-1 and Cond(n.x,n.y+1) then
				pd2:pix(n.x,n.y+1)[0] = 1
				table.insert(Q,{x=n.x,y=n.y+1})
			end
		end

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

local function flood_fill(pd,pd2,X,Y,threshold)
	--return flood_fill_scanline_queue(pd,pd2,X,X,Y,threshold) --0.9
	--return flood_fill_scanline(pd,pd2,X,X,Y,threshold) --stack overflow
	return flood_fill_queue(pd,pd2,X,Y,threshold) --0.25
	--return flood_fill_recurse(pd,pd2,X,Y,threshold) -- stack overflow
end

local function Flood_fill(tex,tex2,point,threshold)
	local ini_ti = secs_now()
	local X,Y = math.floor(point[0]+0.5),math.floor(point[1]+0.5)
	local data = tex:get_pixels(glc.GL_FLOAT,glc.GL_RED)
	--print("tex dims",tex.width,tex.height)
	local pd = vicim.pixel_data(data,tex.width,tex.height,1)
	local pd2 = vicim.pixel_data(nil,pd.w, pd.h, 4)
	
	threshold = threshold or pd:get_pix(X,Y)[0]
	--print("pd:get_pix(X,Y)[0]",pd:get_pix(X,Y)[0])
	--assert(pd:get_pix(X,Y)[0]==0)
	flood_fill(pd,pd2,X,Y,threshold)
	
	--set alpha 0.5 for R > 0
	for i,j,pix in pd2:iterator() do
		if pix[0]>0 then pix[3] = 0.5 end
	end
	
	tex2:set_data(pd2.data, 4, 4)
	print("flood_fill time",secs_now()-ini_ti)
	return pd2
end

local vert_coldist=[[
in vec3 position;
in vec2 texcoords;
out vec2 texcoord_f;
void main(){
	texcoord_f = texcoords;
	gl_Position = vec4(position,1); 
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
void main(){

	vec4 color = texture2D(tex,texcoord_f);
	float dis = LabDistance(color.rgb,refcolor);
	gl_FragColor = vec4(dis);
}

]]


local progcoldist

local function FloodF(GL)
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new{res={GL.W,GL.H}}
	
	local DOFINDCOMPONENTS
	local fbo, adder
	local NM = GL:Dialog("flood_fill",{
	{"threshold",0.1,guitypes.val,{min=0,max=1},function() DOFINDCOMPONENTS=true end},
	{"pick",0,guitypes.button,function(this) 

		GL.mouse_pick = {action=function(X,Y)
							
							print("t1",GL:ScreenToViewport(X,Y))
							--this.vars.color:set{pUD[0],pUD[1],pUD[2]} 
							this.vars.point:set{GL:ScreenToViewport(X,Y)} 
							GL.mouse_pick = nil
							--GL.fbo_nearest = false
							--this.vars.orig[0] = false
							DOFINDCOMPONENTS = true
							this.dirty = true
							--Flood_fill(fbo:tex(),tex2, this.point,this.threshold)
						end}

end},
{"op",1,guitypes.slider_enum,{"none","add","subs"}},
{"point",{187,520},guitypes.drag}
})
	M.NM = NM
	NM.plugin = M
	
	
	function M:init()
		if not progcoldist then
			progcoldist = GLSL:new():compile(vert_coldist,frag_coldist)
			mesh.quad():vao(progcoldist)
		end
		fbo = GL:initFBO()
		M.fbo = fbo
		M.mask = GL:Texture(GL.W,GL.H)
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
	
	function M:process(texture)
	
		if DOFINDCOMPONENTS then
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
		
			local texF,fboF
			if NM.op>1 then
				texF = GL:Texture(GL.W,GL.H)
				fboF = GL:initFBO{no_depth=true}
			else
				texF = self.mask
			end
			Flood_fill(fbo:tex(),texF, NM.point,NM.threshold)
			if NM.op>1 then
				adder:process_fbo(fboF,{self.mask,texF})
				self.mask = fboF:tex()
			end
			DOFINDCOMPONENTS = false
		end
		
		texture:drawcenter()
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
--[=[
local GL = GLcanvas{H=700,aspect=1,DEBUG=false,fbo_nearest=false}


local path = require"anima.path"
fileName = [[C:\luaGL\frames_anima\msquares\imagen.png]]
--fileName = [[C:\luaGL\frames_anima\im_test\Cosmos_original.jpg]]
--fileName = path.this_script_path()..[[\imagenes\unnamed0.jpg]]
--fileName=[[C:\luagl\animacion\resonator6\resonator-038.jpg]]
--fileName = [[C:\LuaGL\frames_anima\flood_fill\dummy.png]]
--fileName = path.this_script_path()..[[\labyrinth.png]]
local texture
local FF,mixer,fbo
function GL.init()
	
	texture = GL:Texture():Load(fileName)
	--texture = texture:resample_fac(0.25)
	GL:set_WH(texture.width,texture.height)
	FF = FloodF(GL)
	mixer = require"anima.plugins.mixer"(GL,2)
	fbo = GL:initFBO{no_depth=true}
	GL:DirtyWrap()
end

function GL.draw(t,w,h)

	ut.Clear()
	FF:process_fbo(fbo,texture)
	fbo:tex():drawcenter()
	
	
	-- mixer.NM.dirty = true
	-- ut.Clear()
	-- mixer:process{texture,FF.tex2}

end


GL:start()
--]=]
return FloodF