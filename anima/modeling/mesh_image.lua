require"anima"
local vec3 = mat.vec3
local vec2 = mat.vec2
local vertRI_sh = [[
in vec3 position;
in vec2 tcoords;
out vec2 f_tcoords;
uniform mat4 MP;
void main()
{
	f_tcoords = tcoords;
	gl_Position = MP * vec4(position,1);
}
]]

fragRI_sh = [[
uniform sampler2D tex;
in vec2 f_tcoords;
void main()
{
	vec4 color = texture(tex,f_tcoords);
	gl_FragColor = color;
}

]]


local mesh = require"anima.mesh"
local mat = require"anima.matrixffi"


local programI

local function MeshRectify(GL,camara,tex,facdim)
	facdim = facdim or 0.5
	local MR = {}
	
	local meshcyl_eye
	local camMP
	local vao_makeimage,vao_triang, vao_triang2, fboim,fboim_inter
	local MOrtho = mat.ortho(0,1,0,1,-1,1)
	
	local vxpos,vypos,vW,vH = getAspectViewport(GL.W,GL.H,tex.width, tex.height)
	local NM = {vxpos=vxpos,vypos=vypos,vW=vW,vH=vH}
	MR.clamp_to_border = false


local function rotAB2d(a,b)
	local an = a:normalize()
	local bn = b:normalize()
	local cosR = an*bn
	local sinR = an.x*bn.y-an.y*bn.x
	return mat.mat3(cosR,-sinR,0,
						sinR,cosR,0,
						0	,0	,1)
end
-- a being new y destination
local function shearH(a,inv)
	local yinv = false
	local an = a:normalize()
	if an.y < 0 then an.y = -an.y;yinv=true end
	local cosS = an.x
	local sinS = an.y
	--assert(sinS~=0)
	local cotS = cosS/sinS
	local A1 = mat.identity3()
	A1.m21 = inv and -cotS or cotS
	if yinv then A1.m22 = -1 end
	return A1,sinS~=0
end
function MR:MeshRectifyTriang(num)

	local m = meshcyl_eye
	local tr = m:triangle(num)

	local p1 = m:point(tr[1])
	local p2 = m:point(tr[2])
	local p3 = m:point(tr[3])
	
	local epoints = {p1,p2,p3}
	--
	local t1 = m:tcoord(tr[1])
	local t2 = m:tcoord(tr[2])
	local t3 = m:tcoord(tr[3])
	
	local m_tc = {t1,t2,t3}
	
	--projected texcoords
	local texcoords = {}
	local pr_co = {}
	for i,v in ipairs(epoints) do
		local sc = camMP*mat.vec4(v.x,v.y,v.z,1)
		sc = sc/sc.w --ndc
		
		pr_co[i] = mat.vec3(sc.x,sc.y,sc.z)
		sc = sc*0.5 + mat.vec4(0.5,0.5,0,0)
		texcoords[i] = mat.vec2(sc.x*GL.W/NM.vW,sc.y*GL.H/NM.vH) - mat.vec2(NM.vxpos/NM.vW,NM.vypos/NM.vH) 
	end

	local vpointX, vpointY
	
	vpointX = (p1 - p3)
	vpointY = (p2 - p3)
	
	local vline = vpointX:cross(vpointY)
	--if vline.z == 0 then print(num,"vline.z==0");return end
	if vline.z == 0 then return end
	
	local P = mat.rotAB(vline,mat.vec3(0,0,1))
	local uA = P * vpointX 
	local vA = P * vpointY

	uA.z = 0
	vA.z = 0
	
	
	local has_nans = false
	
	local R = rotAB2d(uA:xy(),mat.vec2(1,0))
	
	local A1,ok = shearH(R*vA,true)
	if not ok then return end
	
	local UU =  A1*R*P 
	
	local eyepRI = {}
	for i,pO in ipairs(epoints) do
		local p = pO /pO.z

		if pO.z==0 then print(num,"pO.z zero",pO) end
		p = UU * p
		if p.z > 0 then
			p = -p
		end
		eyepRI[i] =  p

		--detect nan
		if p.x~=p.x or p.y~=p.y or p.z~=p.z then
			has_nans = true
			print(num,i,"is nan",p)
		end
	end

	-------------makeimage
	local wp = eyepRI
	local lp = mat.vec2vao{wp[1],wp[2],wp[3]}
	vao_makeimage:set_buffer("position",lp,(#wp)*3)
	
	wp = texcoords
	lp = mat.vec2vao({wp[1],wp[2],wp[3]},2)
	vao_makeimage:set_buffer("tcoords",lp,(#wp)*2)
		
	--get frustum
	local minx,maxx,miny,maxy,minz,maxz = math.huge,-math.huge,math.huge,-math.huge,math.huge,-math.huge
	for i,pO in ipairs(eyepRI) do
		local ndcZ = -pO
		minz = minz < ndcZ.z and minz or ndcZ.z
		maxz = maxz > ndcZ.z and maxz or ndcZ.z
	end

	for i,pO in ipairs(eyepRI) do
		local ndc = -pO/pO.z*minz
		minx = minx < ndc.x and minx or ndc.x
		miny = miny < ndc.y and miny or ndc.y
		maxx = maxx > ndc.x and maxx or ndc.x
		maxy = maxy > ndc.y and maxy or ndc.y
	end

	--if minx == maxx or miny == maxy then print"collapsed frustum---------------------------"; return end
	if minx == maxx or miny == maxy then return end

	fboim_inter:Bind()
	
	programI:use()
	programI.unif.tex:set{0}
	tex:Bind()
	if self.clamp_to_border then
		tex:set_wrap(glc.GL_CLAMP_TO_BORDER)
	else
		tex:set_wrap()
	end
	
	local MP = mat.frustum(minx,maxx,miny,maxy,minz,maxz+0.01)
	programI.unif.MP:set(MP.gl)
	
	fboim_inter:viewport()
	
	--[[
	if has_nans then
	gl.glClearColor(0,1,0,1)
	else
	gl.glClearColor(0.5,0.5,0.5,0)
	end
	ut.Clear() --uses 40% of time
	--]]

	vao_makeimage:draw(glc.GL_TRIANGLES,3)

	local vaotr
	local D = vline*p1
	if D < 0 then
		vaotr = vao_triang
	else
		vaotr = vao_triang2
	end


	fboim_inter:UnBind()
	vaotr:set_buffer("position",{m_tc[3].x, m_tc[3].y, 0, m_tc[1].x, m_tc[1].y, 0,
	m_tc[2].x, m_tc[2].y, 0})
	
	
	
	fboim:Bind()
	programI:use()
	programI.unif.tex:set{0}
	fboim_inter:tex():Bind()
	programI.unif.MP:set(MOrtho.gl)
	fboim:viewport()
	
	vaotr:draw(glc.GL_TRIANGLES,3)
	
	fboim:UnBind()
end


function MR:MeshRectify(mesh,newtex,filter)
	--ProfileStart()
	self.mesh = mesh
	meshcyl_eye = self.mesh

	camMP = camara:MP()
	
	if newtex then
		MR.texR = GL:Texture(tex.width,tex.height,glc.GL_RGBA32F)
	end

	fboim = GL:initFBO({no_depth=true,color_tex=self.texR.pTex},tex.width,tex.height)
	fboim:Bind()
	gl.glClearColor(0.5,0.5,0.5,0)
	ut.Clear()
	fboim:UnBind()
	
	fboim_inter = GL:initFBO({no_depth=true},tex.width*facdim,tex.height*facdim)
	
	gl.glDisable(glc.GL_CULL_FACE)
	gl.glDisable(glc.GL_DEPTH_TEST)
	
	if filter then
	programI:use()
	programI.unif.tex:set{0}
	tex:Bind()
	tex:min_filter(filter)
	tex:mag_filter(filter)
	end
	
	for i=1,meshcyl_eye.ntriangles do
		self:MeshRectifyTriang(i)
	end
	
	
	fboim:delete()
	fboim_inter:delete()
	--self.texR:gen_mipmap()
	gl.glClearColor(0,0,0,0)
	print"done rectify"
	--ProfileStop()
	return self.texR
end


	MR.texR = GL:Texture(tex.width,tex.height,glc.GL_RGBA32F)
	
	-- fboim = GL:initFBO({no_depth=true,color_tex=MR.texR.pTex},tex.width,tex.height)
	-- fboim_inter = GL:initFBO({no_depth=true},tex.width*facdim,tex.height*facdim)

	MR.camara = camara
	
	if not programI then programI = GLSL:new():compile(vertRI_sh,fragRI_sh) end
	
	vao_makeimage = VAO({position={0,0,0,0,0,0,0,0,0},tcoords={0,0,0,0,0,0}},programI)
	vao_triang = VAO({position={0,0,0,0,0,0,0,0,0},tcoords={0,0,1,0,0,1}},programI)
	vao_triang2 = VAO({position={0,0,0,0,0,0,0,0,0},tcoords={1,1,0,1,1,0}},programI)

	return MR
end

return MeshRectify