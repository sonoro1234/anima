require"anima"
local plugin = require"anima.plugins.plugin"

local vert_shad = [[

uniform float timenow;
uniform float perlinfac;
uniform float perlindistfac;
uniform float facX;
uniform float plane_angle;
uniform float heightlimit;

//const float halfpi = 3.14159*0.5;
//float tanalfa = tan(halfpi-plane_angle);
vec3 V3c = vec3(0.0,-sin(plane_angle),cos(plane_angle));
vec4 pcenter4 = gl_ModelViewMatrix * vec4(0.0,0.0,0.0,1.0);
vec4 pcenter4b = pcenter4/pcenter4.w;
vec3 pcenter = pcenter4b.xyz;


vec3 trans_angle(vec3 p)
{
	vec4 PP = gl_ModelViewMatrix * vec4(p,1.0);
	vec3 P = PP.xyz/PP.w;
	if(plane_angle == 0.0)
		return P;
	else{
		return P*dot(V3c,pcenter)/dot(V3c,P);
	}
}

vec3 H3 = trans_angle(vec3(0,heightlimit,0));
vec3 trans_angleH(vec3 p)
{
	vec4 PP = gl_ModelViewMatrix * vec4(p,1.0);
	vec3 P = PP.xyz/PP.w;
	if(plane_angle == 0.0)
		return P;
	else{
		//return P*dot(dot(vec3(0,0,-1),H3)/dot(vec3(0,0,-1),P);
		return P*H3.z/P.z;
	}
}


vec3 V1 = normalize(trans_angle(vec3(1.0,0.0,0.0)) - pcenter);
vec3 w2 = trans_angle(vec3(0.0,1.0,0.0)) - pcenter;
float wa = dot(V1,w2);
vec3 V2 = normalize(w2 - wa*V1);

vec2 plane_project(vec3 v)
{
	vec2 res;
	vec3 zerobased = v - pcenter;
	res.x = dot(zerobased,V1);
	res.y = dot(zerobased,V2);
	return res;
}

void main()
{
	vec4 p4 =  gl_Vertex;
	p4 = p4 / p4.w;
	vec3 p = p4.xyz;
	
	if( p.y < heightlimit){
		p = trans_angle(p);
		vec2 plXYc = plane_project(p);
		float zper = snoise(vec3(plXYc.x*perlindistfac*facX,plXYc.y*perlindistfac,timenow*0.1))* perlinfac;
		//float zper = perlinfac* sin(plXYc.y*perlindistfac +timenow*0.1)*sin(plXYc.x*perlindistfac +timenow*0.1);
		p = p + (zper )*V3c ;
	}else{
		p = trans_angleH(p);
	}
	
	gl_TexCoord[0] = gl_MultiTexCoord0;

	gl_Position = gl_ProjectionMatrix * vec4(p,1.0);
}

]]

local frag_shad = [[

uniform sampler2D tex0;

void main()
{
	
	vec4 color = texture2D(tex0, gl_TexCoord[0].st);
    gl_FragColor = color;
	
}

]]
local GLSL_perlin = require"anima.GLSL.GLSL_perlin"
vert_shad =  GLSL_perlin .. vert_shad


local function CreateMesh(MESHW,MESHH,piecesX,piecesY)
	
	local wfac,yfac

	wfac = MESHW/(piecesX)
	yfac = MESHH/(piecesY)
		
	local meshList = gl.glGenLists(1);
	--print("making meshList clip1",Clip.meshList)
	gl.glNewList(meshList, glc.GL_COMPILE);
	for j=-0.2*piecesY,1.2*piecesY do
		gl.glBegin(glc.GL_TRIANGLE_STRIP)
        for i=-0.2*piecesX,1.2*piecesX do
			--[j][i] = {}
			for k=0,1 do
				local x = i*wfac
				local y = (j+k)*yfac 
				local yt = (j+k)/piecesY
				local xt = i/piecesX
				local xu,yu,zu = x-MESHW*0.5,y-MESHH*0.5,0 
				gl.glTexCoord2f(xt, yt);
				gl.glVertex3f( xu, yu,zu) 
			end
		end
		gl.glEnd()
	end
	gl.glEndList();
	return meshList
end



local M = {}

function M.make(GL,name,argsmake)
	name = name or "seawaves"
	argsmake = argsmake or {}
local NM = GL:Dialog(name or "seawaves",
{
{"timefac",1,guitypes.val,{min=0,max=10}},
{"perlinfac",0.014,guitypes.val,{min=0,max=1}},
{"perlindistfac",4.5,guitypes.val,{min=0,max=10}},
{"facX",1,guitypes.val,{min=0,max=1}},
{"plane_angle",-0.95,guitypes.dial,{orientation="CIRCULAR"}},
{"heightlimit",0.5,guitypes.val,{min=-1,max=1}},
})

	pieces = argsmake.pieces or 300
	local Clip = {NM=NM,name=name}
	local fbo
	
	function Clip.init()
		local aspect_ratio = GL.W/GL.H
		Clip.program = GLSL:new():compile(vert_shad,frag_shad);
		Clip.camera = argsmake.camera or newCamera(GL,argsmake.camtype,"seawaves")
		--Clip.camera.NMC.vars.ortho:setval(1)
		Clip.meshList = CreateMesh(aspect_ratio,1,pieces*aspect_ratio,pieces)
		fbo = GL:initFBO()
		Clip.inited = true
	end
	local function get_args(t, timev)
		local clip = t.clip
		local perlinfac = ut.get_var(t.perlinfac,timev,NM.perlinfac)
		local perlindistfac = ut.get_var(t.perlindistfac,timev,NM.perlindistfac)
		local plane_angle = ut.get_var(t.plane_angle,timev,NM.plane_angle)
		local heightlimit = ut.get_var(t.heightlimit,timev,NM.heightlimit)
		NM.vars.timefac[0] = ut.get_var(t.timefac,timev,NM.timefac)
		return clip,perlinfac,perlindistfac,plane_angle,heightlimit
	end
	function Clip:draw(timebegin,w,h,args)
		if not self.inited then self.init() end
		
		--local theclip,perlinfac,perlindistfac,plane_angle,heightlimit = get_args(args, timebegin)
		plugin.get_args(NM, args, timebegin)
		local theclip = args.clip
		
		local old_framebuffer = fbo:Bind()
		ut.Clear()
		theclip[1]:draw(timebegin, w, h,theclip)
		---[[
		
		--glext.glUseProgram(Clip.program.program);
		Clip.program:use()

		--glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer);
		fbo:UnBind()
		fbo:UseTexture()
		
		---------------
		local u = Clip.program.unif
		u.timenow:set{GL:get_time()*NM.timefac}

		u.perlinfac:set{NM.perlinfac}
		u.perlindistfac:set{NM.perlindistfac}
		u.facX:set{NM.facX}
		u.plane_angle:set{NM.plane_angle}
		u.heightlimit:set{NM.heightlimit}
		u.tex0:set{0}
		
		--ut.ortho_camera(w,h) -- falta lookAt
		Clip.camera:Set()
		ut.Clear()
		gl.glCallList(Clip.meshList);
		--]]
	end
	GL:add_plugin(Clip,name)
	return Clip
end

--[=[
--test

GL = GLcanvas{fps=250,RENDERINI=0,RENDEREND=208,H=700,aspect = 1.5}
function GL.init()
	textura2 = GL:Texture():Load([[C:\luaGL\media\fandema1.tif]])
	theplug = M.make(GL,"sea")--,{camtype="tps"})
	--camara = newCamera(GL,true)
end
function GL.draw(t,w,h)
	--camara:Set()
	ut.Clear()
	theplug:draw(t,w,h,{clip={textura2}})
	--show_tex:draw(t,w,h,{texture=textura2.tex})
	--textura2:draw(t,w,h)
end
GL:start()
--]=]
return M
