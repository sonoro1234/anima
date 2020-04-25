require"anima"

local GL = GLcanvas{H=600,aspect=1,DORENDER=false,RENDERINI=0,RENDEREND=25,vsync=true,profile="CORE"}
GL.rootdir = path.this_script_path()
GL:setMovie(GL.rootdir.."/pelicorazon")
GL.use_presets = true

local MI,ME
local camera,tex,mask
local object
local MVinv
local function make_mesh()
		print"makemesh"
		---[[
		local vec3 = mat.vec3
		local vec2 = mat.vec2
		local meshE = ME.mesh or mesh.mesh{triangles={0,2,1}, points={vec3(-1,-1,0), vec3(0,1,0), vec3(1,-1,0)}, tcoords={vec2(0,0.5),vec2(0.5,1),vec2(1,1)}}
		--]]
		local meshW = meshE:clone()
		meshW:M4(MVinv)
		meshW:calc_centroid()
		local minb,maxb = meshW:bounds()
		local center = vec3(meshW.centroid.x,meshW.centroid.y,minb.z)

		if NM.gentex then MI:MeshRectify(meshE) end
		local frame = {X=vec3(1,0,0),Y=vec3(0,1,0),Z=vec3(0,0,1),center=center}
		object:setMesh(meshW,MI.texR, frame)
	end

NM = GL:Dialog("test",{
{"make_mesh",0,gui.types.button,function() make_mesh() end},
{"draw_image",true,gui.types.toggle},
{"gentex",false,gui.types.toggle},
})


function REPEAT(n,...)
	local T = {}
	for i=1,n do 
		for j=1,select('#',...) do
			local t = select(j,...)
			T[#T+1]=t 
		end
	end
	return unpack(T)
end


local Dbox
local mssa 
local mblur
function GL:init()
	tex = GL:Texture():Load("heart.png")

	GL:set_WH(tex.width, tex.height)
	mssa = GL:initFBOMultiSample()
	
	camera = Camera(GL,"tps")
	MVinv = camera:MV().inv
	ME = require"anima.modeling.SpHeight"(GL,camera,make_mesh)
	--local plugin = require"anima.plugins.plugin"
	--ME.SE.fb = plugin.serializer(ME.SE)
	object = require"anima.Object3D"(GL,camera)
	MI = require"anima.modeling.mesh_image"(GL,camera,tex)
	mblur = require"anima.plugins.motion_blur".make(GL)
	
	Dbox = GL:DialogBox("corazon",true) --true for allow saving-loading
	Dbox:add_dialog(NM)
	Dbox:add_dialog(camera.NM)
	Dbox:add_dialog(ME.NM)
	Dbox:add_dialog(object.NM)
	
	GL:preset_load("corazon.preset")
	local vec3 = mat.vec3
	local gr = 1.7
	local gr2 = gr --1.5
	
	---[[
	local zval = pointer()
	local hook = function()
		object.NM.vars.scale:set(vec3(1,1,zval[0]))
		object:make_model_mat()
	end
	local aaa = spl_anim:new(zval,{{1,3},REPEAT(40,{1,0.25},{gr,0.3},{1.3,0.4},{1.45,0.1},{gr2,0.3})},hook)
	GL.animation:add_animatable(aaa)
	--]]
end

local NN = {}
function NN:draw(t,w,h)
	mssa:Bind()
	
	ut.Clear()
	if NM.draw_image then
		tex:drawcenter()
		ut.ClearDepth()
	end

	object:draw()
	
	mssa:Dump()
end

function GL.draw(t,w,h)
	mblur:draw(t,w,h,{clip={NN}})
end

GL:start()