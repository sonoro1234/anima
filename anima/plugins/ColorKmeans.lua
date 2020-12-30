
local vert_std = [[
in vec3 position;
	void main()
	{
		gl_Position = vec4(position,1);
	}
	]]
local frag_findcenter = [[
uniform sampler2D tex;
uniform sampler2D texcenters;
uniform int K=16;

void main(){

	vec3 color = texelFetch(tex,ivec2(gl_FragCoord.st),0).rgb;
	float mindist = 10000000;
	int minK = K+1;
	for(int i=0;i<K;i++){
		vec3 v = color-texelFetch(texcenters,ivec2(i,0),0).rgb;
		float dis = dot(v,v);
		if(dis < mindist){
			mindist = dis;
			minK = i;
		}
	}
	gl_FragColor = vec4(color,minK);
}

]]

local frag_findcenter_apply = [[
uniform sampler2D tex;
uniform sampler2D texcenters;
uniform int K=16;

void main(){

	vec3 color = texelFetch(tex,ivec2(gl_FragCoord.st),0).rgb;
	float mindist = 10000000;
	int minK = K+1;
	vec3 mincentercolor = vec3(0);
	//vec3 centercolor = vec3(0);
	for(int i=0;i<K;i++){
		vec3 centercolor = texelFetch(texcenters,ivec2(i,0),0).rgb;
		vec3 v = color-centercolor;
		float dis = dot(v,v);
		if(dis < mindist){
			mincentercolor = centercolor;
			mindist = dis;
			minK = i;
		}
	}
	gl_FragColor = vec4(mincentercolor,minK);
}

]]

local frag_showcol=[[
uniform sampler2D tex;
uniform sampler2D texcenters;

void main(){
	vec4 color = texelFetch(tex,ivec2(gl_FragCoord.st),0);
	vec4 colorquant = texelFetch(texcenters,ivec2(color.a,0),0);
	gl_FragColor = colorquant;
}

]]
local vert_updatecenters=[[
uniform sampler2D tex;
in vec3 position;
out vec4 center;
uniform float K=5;
out float centerind;
void main()
{

	vec4 col = texelFetch(tex, ivec2(position.xy+0.0),0);
	centerind = col.a;
	//gl_Position = vec4((centerind/(K-1.0) - 0.5)*2.0,0,0.0,1.0);
	gl_Position = vec4(2.0*(col.a+0.4)/K - 1.0, 0.0, 0.0,1.0);
	center = vec4(col.rgb,1.0);
}

]]

local frag_updatecenters=[[
in float centerind;
in vec4 center;
void main()
{
	/*if(centerind==2){
		discard;
	}else*/
		gl_FragColor = center;
}
]]

local vert_loss=[[

uniform sampler2D tex;
uniform sampler2D texcenters;
in vec3 position;
out vec4 dist;
void main()
{

	vec4 col = texelFetch(tex, ivec2(position.xy), 0);
	float centerind = col.a;
	vec4 colcenter = texelFetch(texcenters, ivec2(centerind,0),0);
	
	vec3 v = col.rgb - colcenter.rgb;
	dist = vec4(dot(v,v));
	gl_Position = vec4(-1,0,0.0,1.0);
}
]]

local frag_loss=[[
in vec4 dist;
void main(){
	gl_FragColor = dist;
}
]]

local frag_tolab = require"anima.GLSL.GLSL_color"..[[
uniform sampler2D tex;
uniform float Lfac;
const float fac = 1.0/216.0; //-107.8 is maximum value
void main()
{
	vec4 color = texelFetch(tex,ivec2(gl_FragCoord.st),0);

	vec3 colorlab = XYZ2LAB(RGB2XYZ(sRGB2RGB(color.rgb)),D65);
	colorlab *= vec3(Lfac*fac, fac, fac);
	colorlab += vec3(0.0,0.5,0.5);
	//colorlab = clamp(colorlab,vec3(0.0),vec3(1.0));
	color = vec4(colorlab,color.a);
	gl_FragColor = color;
}
]]

local frag_fromlab = require"anima.GLSL.GLSL_color"..[[
uniform sampler2D tex;
uniform float Lfac;
const float fac = 216.0;
void main()
{
	vec4 colorlab = texelFetch(tex,ivec2(gl_FragCoord.st),0);
	vec3 colorlab3 = colorlab.rgb;
	colorlab3 -= vec3(0.0,0.5,0.5);
	colorlab3 *= vec3(fac/Lfac,fac,fac);
	vec3 color = RGB2sRGB(XYZ2RGB(LAB2XYZ(colorlab3,D65)));
	//color = clamp(color,vec3(0.0),vec3(1.0));
	gl_FragColor = vec4(color,colorlab.a);
}
]]


require"anima"
local plugin = require"anima.plugins.plugin"
local function ColorKmeans(GL,K)
	local M = {}
	local NM=GL:Dialog("ColorKmeans",{
{"K",K,guitypes.valint,{min=1,max=100}},--function(val) M:setK(val) end},
{"th",3,guitypes.valint,{min=1,max=9}},
--{"randominit",false,guitypes.toggle},
{"maxiters",100,guitypes.valint,{min=50,max=200}},
{"Lab",false,guitypes.toggle},
{"Lfac",1,guitypes.val,{min=1e-3,max=20}},

})
	M = plugin:new(M,GL,NM)
	M.NM = NM
	--random init
	local function initCenters(fbo,tex)
		math.randomseed(17)
		local npix = tex.width*tex.height
		local datat = tex:get_pixels(glc.GL_FLOAT,glc.GL_RGB)
		--print("initCenters",ffi.sizeof(datat)/(ffi.sizeof"float"*3))
		local data = ffi.new("float[?]",NM.K*3)
		for i=0,NM.K-1 do
			local indpix = math.random()*(npix-1)
			data[i*3] = datat[indpix*3]
			data[i*3+1] = datat[indpix*3+1]
			data[i*3+2] = datat[indpix*3+2]
			--print("initcenters",i,data[i*3],data[i*3+1],data[i*3+2])
		end
		fbo:tex():set_data(data,3,4)
	end
	local function initCentersKmeanpp(fbo,tex)

		local npix = tex.width*tex.height
		local datat = tex:get_pixels(glc.GL_FLOAT,glc.GL_RGB)
		--print("initCenters",ffi.sizeof(datat)/(ffi.sizeof"float"*3),npix)
		
		local function diss(i,b)
			local x = datat[3*i] - b[1]
			local y = datat[3*i+1] - b[2]
			local z = datat[3*i+2] -b[3]
			return x*x+y*y+z*z
		end
		
		local K = 1
		local centers = {}
		-- take one center c1, chosen uniformly at random from 'data'
		local i = math.random(0, npix-1)
		centers[K] = {datat[i*3], datat[i*3+1], datat[i*3+2]}
		local D = {}
		-- repeat until we have taken 'nclusters' centers
		while K < NM.K do
		-- take a new center ck, choosing a point 'i' of 'data' with probability 
		-- D(i)^2 / sum_{i=1}^n D(i)^2 
			
			local sum_D = 0.0
			for i = 0,npix-1 do
				local min_d = D[i]
				local d = diss(i, centers[K])
				if min_d == nil or d < min_d then
					min_d = d
				end
				D[i] = min_d
				sum_D = sum_D + min_d
			end
			
			
			repeat
			local repeated = false
			---[[
			local sum = math.random() * sum_D
			for i = 0,npix-1 do
				sum = sum - D[i]
				if sum <= 0 then 
					K = K + 1
					centers[K] = {datat[3*i], datat[3*i+1], datat[3*i+2]}
					break
				end
			end
			--]]
			--[[
			local ra = math.random()*sum_D
			local sum = 0
			for i = 0,npix-1 do
				if ra >= sum and ra < sum + D[i] then 
					K = K + 1
					centers[K] = {datat[3*i], datat[3*i+1], datat[3*i+2]}
					break
				end
				sum = sum + D[i]
			end
			--]]
			--check equal centroids
			for i= 1,K-1 do
				if centers[i][1]==centers[K][1] and 
				centers[i][2]==centers[K][2] and 
				centers[i][1]==centers[K][1] then
					print("repeated centroid ------------------------------------------",i)
					repeated = true
					K = K -1
					break
				end
			end
			until not repeated

		end
		local data = ffi.new("float[?]",NM.K*3)
		for i=1,K do
			local j = i-1
			data[3*j] = centers[i][1]
			data[3*j+1] = centers[i][2]
			data[3*j+2] = centers[i][3]
			--print("initcenters",j,data[j*3],data[j*3+1],data[j*3+2])
		end
		fbo:tex():set_data(data,3,4)
	end
	local function DoMESH(w, h,prog)
		print("DOMESH",w,h)
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
		return VAO({position=Pos},prog)
	end
	local programfindcenters,programupdatecenters,programloss,programshowcol
	local lossfbo
	local ptolab,pfromlab
	function M:init()
		programfindcenters = GLSL:new():compile(vert_std,frag_findcenter)
		mesh.quad():vao(programfindcenters)
		
		programfindcenters_apply = GLSL:new():compile(vert_std,frag_findcenter_apply)
		mesh.quad():vao(programfindcenters_apply)
	
		programupdatecenters = GLSL:new():compile(vert_updatecenters,frag_updatecenters)
		
		programloss = GLSL:new():compile(vert_loss,frag_loss)
		
		programshowcol = GLSL:new():compile(vert_std,frag_showcol)
		mesh.quad():vao(programshowcol)
		
		lossfbo = GL:initFBO({no_depth=true},1,1)
		
		ptolab = GLSL:new():compile(vert_std,frag_tolab)
		mesh.quad():vao(ptolab)
		
		pfromlab = GLSL:new():compile(vert_std,frag_fromlab)
		mesh.quad():vao(pfromlab)
	end
	local fbo1,centersfbo,fbo
	function M:check()
		if not fbo1:is_framebuffer() then print"fbo1 not good" end
		if not centersfbo:is_framebuffer() then print"centersfbo not good" end
		if not fbo:is_framebuffer() then print"fbo not good" end
		if not lossfbo:is_framebuffer() then print"lossfbo not good" end
		if not centersfbo:tex():is_texture() then print("centersfbo tex not good",centersfbo:tex().tex) end
		print"check done"
	end
	function M:setK(K)
		print"setK--------------------"
		if K and NM.K~=K then NM.vars.K[0] = K end
		if centersfbo==nil or centersfbo.width ~= NM.K then
			if centersfbo then centersfbo:delete(true) end --keep tex centerstex
			centersfbo = GL:initFBO({no_depth=true},NM.K,1)
		end
	end
	function M:set_texture(texr)
		print"set_texture--------------"
		fbo1 = texr:make_fbo()
		fbo = texr:make_fbo()
		
		programupdatecenters.vaos = nil
		DoMESH(texr.width,texr.height,programupdatecenters);
		programloss.vaos = nil
		DoMESH(texr.width,texr.height,programloss)
		
		self:setK()
		self.texr = texr
	end
	function M:fromlab(tex)
			local labfbo = tex:make_fbo()
			labfbo:Bind()
			pfromlab:use()
			pfromlab.unif.tex:set{0}
			pfromlab.unif.Lfac:set{NM.Lfac}
			tex:Bind()
			labfbo:viewport()
			ut.Clear()
			pfromlab.vaos[1]:draw_elm()
			labfbo:UnBind()
			local tex2 = labfbo:tex()
			labfbo:delete(true)
			return tex2
	end
	function M:tolab(tex)
			local labfbo = tex:make_fbo()
			labfbo:Bind()
			ptolab:use()
			ptolab.unif.tex:set{0}
			ptolab.unif.Lfac:set{NM.Lfac}
			tex:Bind()
			labfbo:viewport()
			ut.Clear()
			ptolab.vaos[1]:draw_elm()
			labfbo:UnBind()
			local tex2 = labfbo:tex()
			labfbo:delete(true)
			return tex2
	end
	local function check(tex)
		local npix = tex.width*tex.height
		local data = tex:get_pixels(glc.GL_FLOAT,glc.GL_RGBA)
		local centers = {}
		local sum = 0
		for i=0,npix-1 do
			centers[data[4*i+3]]= 1 + (centers[data[4*i+3]] or 0)
		end
		return centers
	end
	function M:kmeans()
		print"kmeans--------------------------------------------"
		local texr = self.texr
		gl.glDisable(glc.GL_BLEND)
		if NM.Lab then
			texr = self:tolab(texr)
		end
		
		self:setK()
		
		-- if NM.randominit then
			-- initCenters(centersfbo, texr)
		-- else
			-- initCentersKmeanpp(centersfbo,texr)
		-- end
		
		initCentersKmeanpp(centersfbo,texr)
		
		local updated = false
		local oldloss = math.huge
		fbo1:Bind()
		fbo1:viewport()
		ut.Clear()
		fbo1:UnBind()
		local countiters = 0
		--print"first check"
		--prtable(check(fbo1:tex()))
		repeat
			updated = false
			gl.glDisable(glc.GL_BLEND)
			programfindcenters:use()
			local U = programfindcenters.unif
			U.tex:set{0}
			U.texcenters:set{1}
			U.K:set{NM.K}
			fbo1:Bind()
			fbo1:viewport()
			texr:Bind()
			centersfbo:tex():Bind(1)
			--ut.Clear()
			programfindcenters.vaos[1]:draw_elm()
			fbo1:UnBind()
			
			--prtable(check(fbo1:tex()))
			
			programupdatecenters:use()
			local U = programupdatecenters.unif
			U.tex:set{0}
			U.K:set{NM.K}
			centersfbo:Bind()
			centersfbo:viewport()
			gl.glClearColor(0.0, 0.0, 0.0, 0)
			ut.Clear()
			local T = fbo1:tex()
			T:Bind()
			T:set_wrap(glc.GL_CLAMP_TO_EDGE)
			T:min_filter(glc.GL_NEAREST)
			T:mag_filter(glc.GL_NEAREST)
			--gl.glViewport(0,0,NM.K,1)

			gl.glEnable(glc.GL_BLEND)
			gl.glBlendFunc(glc.GL_ONE,glc.GL_ONE)
			glext.glBlendEquation(glc.GL_FUNC_ADD)
			programupdatecenters.vaos[1]:draw(glc.GL_POINTS)
			
			centersfbo:UnBind()
			
			local data = centersfbo:tex():get_pixels(glc.GL_FLOAT,glc.GL_RGBA)
			local sum = 0
			local posterror = false
			for i=0,NM.K-1 do
				local pix = data + i*4
				if(pix[3]==0) then posterror=true end
				pix[0] = pix[0]/pix[3]
				pix[1] = pix[1]/pix[3]
				pix[2] = pix[2]/pix[3]
				sum = sum +pix[3]
				--print(i,pix[0],pix[1],pix[2],pix[3])
			end
			if posterror then
				for i=0,NM.K-1 do
					local pix = data + i*4
					print(i,pix[0],pix[1],pix[2],pix[3])
				end
				print(sum, texr.width*texr.height)
				error"zero pixels assigned to "
			end

			if sum~=texr.width*texr.height then
				print(sum,texr.width*texr.height,"sum==texr.width*texr.height")
			end
			centersfbo:tex():set_data(data,4,4)
			
			--loss calc
			lossfbo:Bind()
			programloss:use()
			local U = programloss.unif
			U.tex:set{0}
			U.texcenters:set{1}
			fbo1:tex():Bind()
			gl.glViewport(0,0,1,1)
			ut.Clear()
			programloss.vaos[1]:draw(glc.GL_POINTS)
			lossfbo:UnBind()
			local data = lossfbo:tex():get_pixels(glc.GL_FLOAT,glc.GL_RED)
			
			--print("loss",data[0],(oldloss-data[0])/data[0])
			updated = true
			--if data[0] == oldloss then updated=false end
			if math.abs(oldloss-data[0])/data[0] <= 0.1^NM.th then updated=false end
			--assert(oldloss >=data[0])
			oldloss = data[0]
			countiters = countiters +1
		until not updated or countiters > NM.maxiters
		print("iterattions",countiters,oldloss)
		gl.glDisable(glc.GL_BLEND)
	end
	function M:apply()
		fbo:Bind()
		gl.glDisable(glc.GL_BLEND)
		programshowcol:use()
		local U = programshowcol.unif
		U.tex:set{0}
		U.texcenters:set{1}
		fbo1:tex():Bind()
		centersfbo:tex():Bind(1)
		fbo:viewport()
		ut.Clear()
		programshowcol.vaos[1]:draw_elm()
		fbo:UnBind()
		if not NM.Lab then
			return fbo:tex()
		else
			return self:fromlab(fbo:tex())
		end
	end
	function M:find_apply(tex)
		if NM.Lab then
			tex = self:tolab(tex)
		end
		gl.glDisable(glc.GL_BLEND)
		local fboapp = tex:make_fbo()
		fboapp:Bind()
		fboapp:viewport()
		ut.Clear()
		programfindcenters_apply:use()
		local U = programfindcenters_apply.unif
		U.tex:set{0}
		U.texcenters:set{1}
		U.K:set{NM.K}
		tex:Bind()
		centersfbo:tex():Bind(1)
		programfindcenters_apply.vaos[1]:draw_elm()
		fboapp:UnBind()
		---check all applied
		--[[
		local fbotex = fboapp:tex()
		local data = fbotex:get_pixels(glc.GL_FLOAT,glc.GL_RGBA)
		local used = {}
		local npix = fbotex.width*fbotex.height
		for i=0,npix-1 do
			local val = data[i*4+3]
			used[val] = 1 + (used[val] or 0)
		end
		prtable(used)
		--]]
		---
		local tex2 = fboapp:tex()
		--print("find apply tex",tex2.tex)
		fboapp:delete(true)
		if not NM.Lab then
			return tex2
		else
			return self:fromlab(tex2)
		end
	end
	local oldtexsignature
	function M:process(texture)
		if not oldtexsignature or oldtexsignature~=texture:get_signature() then
			oldtexsignature=texture:get_signature()
			local texr = texture:resample_fac(0.1)
			self:set_texture(texr)
		end
		self:kmeans()
		self.texx = self:apply()
		self.centerstex = self:getcenters()
		self.texturax = self:find_apply(texture)
	end
	function M:getcenters()
		if NM.Lab then
			return self:fromlab(centersfbo:tex())
		else
			return centersfbo:tex()
		end
	end
	GL:add_plugin(M,"ColorKmeans")
	return M
end

--[=[
GL = GLcanvas{fps=25,H=700,aspect = 1.5,DEBUG=true,fbo_nearest=true,SDL=false}

local textura
local ColorK = ColorKmeans(GL,5)

local NM = GL:Dialog("test",{
{"orig",false,guitypes.toggle},
{"show",2,guitypes.slider_enum,{"lowres","hires","centers"}}
})

local Dbox = GL:DialogBox()
Dbox:add_dialog(NM)
Dbox:add_dialog(ColorK.NM)
local fileName = [[C:\LuaGL\frames_anima\edges_detection\flowers2.png]]
--local fileName = [[C:\LuaGL\frames_anima\edges_detection\bici.png]]
function GL.init()
	--GLSL.default_version = "#version 330\n"
	--textura = GL:Texture():Load([[C:\luaGL\frames_timeline2\media\fiestaafrica.tif]],srgb)
	textura = GL:Texture():Load(fileName,srgb)
	--textura = GL:Texture():Load(path.this_script_path()..[[\Lab_ab.tif]]--[[\lab1.tif]])
	--textura = GL:Texture():Load([[D:\VICTOR\pelis\loopmar\master1080\loop1\frame-0001.tif]],srgb)
	--textura = GL:Texture():Load[[D:\VICTOR\pelis\mixolidian\animacion\mixxxx\frame-0029.tif]]
	GL:set_WH(textura.width, textura.height)
	
	GL:DirtyWrap()
end

function GL.draw(tim,w,h)

	ut.Clear()
	if NM.orig then
		textura:drawcenter()
	else
		ColorK:process(textura)
		
		assert(ColorK.texx:is_texture())
		if not ColorK.centerstex:is_texture() then prtable(GL.textures) end
		assert(ColorK.centerstex:is_texture(),"not texture centers "..ColorK.centerstex.tex)
		if not ColorK.texturax:is_texture() then prtable(GL.textures) end
		assert(ColorK.texturax:is_texture(),"not texture "..ColorK.texturax.tex)
		
		if NM.show==3 then
			ColorK.centerstex:Bind()
			ColorK.centerstex:mag_filter(glc.GL_NEAREST)
			ColorK.centerstex:drawcenter(w,h)
		elseif NM.show==2 then
			ColorK.texturax:drawcenter(w,h)
		else
			ColorK.texx:drawcenter(w,h)
		end
	end

	collectgarbage()
	collectgarbage()
end

GL:start()
--]=]

return ColorKmeans