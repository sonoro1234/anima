require"anima"

local vert = [[

in vec3 position;
void main(){
	gl_Position = vec4(position,1);
}

]]

local frag_dilate = [[

uniform sampler2D tex;
uniform int kernelsize = 1;
void main()
{
	float valmax = -10;
	for(int x=-kernelsize;x<=kernelsize;x++){
		for(int y=-kernelsize;y<=kernelsize;y++){
			float val = texelFetch(tex,ivec2(gl_FragCoord.xy)+ivec2(x,y),0).r;
			valmax = max(valmax,val);
		}
	}
	gl_FragColor = vec4(vec3(valmax),1);
}

]]

local frag_erode = [[

uniform sampler2D tex;
uniform int kernelsize = 1;
uniform bool cross;
vec2 texs = textureSize(tex,0);
void main()
{
	
	float valmin = 10;
	int rest;
	for(int x=-kernelsize;x<=kernelsize;x++){
		if(cross)
			rest = kernelsize - abs(x);
		else
			rest = kernelsize;
		for(int y=-rest;y<=rest;y++){
			//float val = texelFetch(tex,ivec2(gl_FragCoord.xy)+ivec2(x,y),0).r;
			float val = texture(tex,(gl_FragCoord.xy+vec2(x,y))/texs,0).r;
			valmin = min(valmin,val);
		}
	}
	gl_FragColor = vec4(vec3(valmin),1);
}

]]

local frag_substract = [[
uniform sampler2D tex;
uniform sampler2D tex2;
uniform bool doneg;
void main()
{
	float val = texelFetch(tex,ivec2(gl_FragCoord.xy),0).r - texelFetch(tex2,ivec2(gl_FragCoord.xy),0).r;
	if(doneg){
		gl_FragColor = vec4(vec3(1.0 - val),1);
	}else{
		gl_FragColor = vec4(vec3(val),1);
	}
}

]]

local function morphology(GL,args)
	args = args or {}

	local plugin = require"anima.plugins.plugin"
	local M = plugin.new({res={GL.W,GL.H}},GL)
	local NM = GL:Dialog("morphol",
	{{"op",0,guitypes.combo,{"erode","dilate","open","close","TopHatW","TopHatB","border","cl-op","op-cl"}},
	{"kernelsize",1,guitypes.valint,{min=0,max=10}},
	{"iters",1,guitypes.valint,{min=1,max=30}},
	{"cross",false,guitypes.toggle},
	{"doneg",false,guitypes.toggle},
	{"bypass",false,guitypes.toggle}
	})
	NM.plugin = M
	M.NM = NM

	local program_erode,program_dilate, program_substract,quade,quadd,quads
	local slab
	function M:init()
		program_erode = GLSL:new():compile(vert,frag_erode)
		program_dilate = GLSL:new():compile(vert,frag_dilate)
		program_substract = GLSL:new():compile(vert,frag_substract)
		quade = mesh.quad():vao(program_erode)
		quadd = mesh.quad():vao(program_dilate)
		quads = mesh.quad():vao(program_substract)

		slab = GL:make_slab()
	end
	
	local program,quad,program2,quad2,program3
	function M:process(srctex,w,h)
		if NM.bypass then srctex:drawcenter(w,h); return end

		local subs = false
		program3 = nil
		if NM.op == 0 then --erode
			program = program_erode
			quad = quade
			program2 = nil
		elseif NM.op == 1 then --dilate
			program = program_dilate
			quad = quadd
			program2 = nil
		elseif NM.op == 2 then --open
			program = program_erode
			quad = quade
			program2 = program_dilate
			quad2 = quadd
		elseif NM.op == 3 then --close
			program = program_dilate
			quad = quadd
			program2 = program_erode
			quad2 = quade
		elseif NM.op == 4 then --tophatW
			program = program_erode
			quad = quade
			program2 = program_dilate
			quad2 = quadd
			subs = true
		elseif NM.op == 5 then --tophatB
			program = program_dilate
			quad = quadd
			program2 = program_erode
			quad2 = quade
			subs = true
		elseif NM.op == 6 then --border
			program = program_erode
			quad = quade
			program2 = nil
			subs = true
		elseif NM.op == 7 then --cl-op
			program = program_dilate
			program2 = program_erode
			program3 = program_dilate
		elseif NM.op == 8 then --op-cl
			program = program_erode
			program2 = program_dilate
			program3 = program_erode
		end

		srctex:Bind()
		srctex:set_wrap(glc.GL_MIRRORED_REPEAT)
		
		slab:Bind()
		program:use()
		program.unif.kernelsize:set{NM.kernelsize}
		program.unif.cross:set{NM.cross}
		program.unif.tex:set{0}
		gl.glViewport(0,0,w or self.res[1], h or self.res[2])
		--quad:draw_elm()
		program.vaos[1]:draw_elm()
		slab:UnBind()
		for i=2,NM.iters do
			slab:tex():Bind()
			slab:Bind()
			program.vaos[1]:draw_elm()
			--quad:draw_elm()
			slab:UnBind()
		end

		if program2 then
			slab:tex():Bind()
			slab:Bind()
			program2:use()
			program2.unif.kernelsize:set{NM.kernelsize}
			program2.unif.tex:set{0}
			gl.glViewport(0,0,w or self.res[1], h or self.res[2])
			--quad2:draw_elm()
			program2.vaos[1]:draw_elm()
			slab:UnBind()
			local mul = program3 and 2 or 1 --cl-op or op-cl
			for i=2,NM.iters*mul do
				slab:tex():Bind()
				slab:Bind()
				--quad2:draw_elm()
				program2.vaos[1]:draw_elm()
				slab:UnBind()
			end
		end
		
		if program3 then
			slab:tex():Bind()
			slab:Bind()
			program3:use()
			program3.unif.kernelsize:set{NM.kernelsize}
			program3.unif.tex:set{0}
			gl.glViewport(0,0,w or self.res[1], h or self.res[2])
			program3.vaos[1]:draw_elm()
			slab:UnBind()
			for i=2,NM.iters do
				slab:tex():Bind()
				slab:Bind()
				program3.vaos[1]:draw_elm()
				slab:UnBind()
			end
		end
		
		if not subs then 
			slab:tex():drawcenter()
		else
			if NM.op == 4 or NM.op == 6 then --tophatW or border
				srctex:Bind(0)
				slab:tex():Bind(1)
			else -- op==5 -- tophatB
				srctex:Bind(1)
				slab:tex():Bind(0)
			end
			program_substract:use()
			program_substract.unif.tex:set{0}
			program_substract.unif.tex2:set{1}
			program_substract.unif.doneg:set{NM.doneg}
			gl.glViewport(0,0,w or self.res[1], h or self.res[2])
			--quads:draw_elm()
			program_substract.vaos[1]:draw_elm()
		end
	end
	GL:add_plugin(M,"morphology")
	return M
end

--[=[
local GL = GLcanvas{H=700,aspect=1,fbo_nearest=true}

NM = GL:Dialog("test",{
	{"orig",false,guitypes.toggle},
	{"rep",false,guitypes.toggle},
})

--fileName = [[C:\luaGL\frames_anima\msquares\imagen2.tif]]
fileName = [[C:\luaGL\frames_anima\im_test\Cosmos_original.jpg]]
--fileName = [[C:\luaGL\frames_anima\flood_fill\dummy.png]]
--fileName = [[C:\luaGL\frames_anima\im_test\unnamed0.jpg]]
local im = require"imffi"
local vicim = require"anima.vicimag"
-- local image = im.FileImageLoadBitmap(fileName)
-- print(image:DataType(),im.BYTE,im.DataTypeName(image:DataType()),im.DataTypeName(im.BYTE))
local pd = vicim.load_im(fileName)
local texture,program_erode,quad
local fbo ,fbo2

function GL.init()
	
	texture = pd:totex(GL) --GL:Texture():Load(fileName)
	GL:set_WH(texture.width,texture.height)
	fx = morphology(GL,{fixed_fbos=true})
	fx.NM.vars.op[0]=6
	fbo = GL:initFBO({no_depth=true})
	fbo2 = GL:initFBO({no_depth=true})
	GL:DirtyWrap()
end

function GL.draw(t,w,h)

	ut.Clear()
	if NM.orig then
		texture:drawcenter(w,h)
	else
		--fx.NM:SetValues{op="border"}
		fx:process_fbo(fbo,texture)
		if NM.rep then
		fx.NM:SetValues{op="erode"}
		fx:process_fbo(fbo2,fbo:tex())
		fbo2:tex():drawcenter()
		else
		fbo:tex():drawcenter()
		end
	end
end


GL:start()
--]=]
return morphology