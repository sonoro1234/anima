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
vec2 texs = textureSize(tex,0);
void main()
{
	
	float valmin = 10;
	for(int x=-kernelsize;x<=kernelsize;x++){
		for(int y=-kernelsize;y<=kernelsize;y++){
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
	local fixed_fbos = args.fixed_fbos
	local plugin = require"anima.plugins.plugin"
	local M = plugin.new({res={GL.W,GL.H}},GL)
	local NM = GL:Dialog("morphol",
	{{"op",0,guitypes.combo,{"erode","dilate","open","close","TopHatW","TopHatB"}},
	{"kernelsize",1,guitypes.drag,{min=0,max=10}},
	{"doneg",false,guitypes.toggle},
	{"bypass",false,guitypes.toggle}
	})
	NM.plugin = M
	M.NM = NM

	local program_erode,program_dilate, program_substract,quade,quadd,quads
	local fbo,fbo2
	function M:init()
		program_erode = GLSL:new():compile(vert,frag_erode)
		program_dilate = GLSL:new():compile(vert,frag_dilate)
		program_substract = GLSL:new():compile(vert,frag_substract)
		quade = mesh.quad():vao(program_erode)
		quadd = mesh.quad():vao(program_dilate)
		quads = mesh.quad():vao(program_substract)
		if fixed_fbos then
			fbo = GL:initFBO{no_depth=true}
			fbo2 = GL:initFBO{no_depth=true}
		end
	end
	
	local program,quad,program2,quad2
	function M:process(srctex,w,h)
		if NM.bypass then srctex:drawcenter(w,h); return end
		srctex:Bind()
		srctex:set_wrap(glc.GL_MIRRORED_REPEAT)
		local subs = false
		if NM.op == 0 then
			program = program_erode
			quad = quade
			program2 = nil
		elseif NM.op == 1 then
			program = program_dilate
			quad = quadd
			program2 = nil
		elseif NM.op == 2 then
			program = program_erode
			quad = quade
			program2 = program_dilate
			quad2 = quadd
		elseif NM.op == 3 then
			program = program_dilate
			quad = quadd
			program2 = program_erode
			quad2 = quade
		elseif NM.op == 4 then
			program = program_erode
			quad = quade
			program2 = program_dilate
			quad2 = quadd
			subs = true
		elseif NM.op == 5 then
			program = program_dilate
			quad = quadd
			program2 = program_erode
			quad2 = quade
			subs = true
		end
		if not program2 then
			program:use()
			program.unif.kernelsize:set{NM.kernelsize}
			program.unif.tex:set{0}
			gl.glViewport(0,0,w or self.res[1], h or self.res[2])
			--ut.Clear()
			quad:draw_elm()
		else
			if not fixed_fbos then fbo = GL:get_fbo() end
			fbo:Bind()
			program:use()
			program.unif.kernelsize:set{NM.kernelsize}
			program.unif.tex:set{0}
			gl.glViewport(0,0,w or self.res[1], h or self.res[2])
			--ut.Clear()
			quad:draw_elm()
			fbo:UnBind()
			if subs then
				if not fixed_fbos then fbo2 = GL:get_fbo() end
				fbo2:Bind()
			end
			fbo:tex():Bind()
			program2:use()
			program2.unif.kernelsize:set{NM.kernelsize}
			program2.unif.tex:set{0}
			gl.glViewport(0,0,w or self.res[1], h or self.res[2])
			--ut.Clear()
			quad2:draw_elm()
			if not fixed_fbos then fbo:release() end
			if subs then
				fbo2:UnBind()
				if NM.op == 4 then
					srctex:Bind(0)
					fbo2:tex():Bind(1)
				else
					srctex:Bind(1)
					fbo2:tex():Bind(0)
				end
				program_substract:use()
				program_substract.unif.tex:set{0}
				program_substract.unif.tex2:set{1}
				program_substract.unif.doneg:set{NM.doneg}
				gl.glViewport(0,0,w or self.res[1], h or self.res[2])
				--ut.Clear()
				quads:draw_elm()
				if not fixed_fbos then fbo2:release() end
			end
		end
	end
	GL:add_plugin(M,"morphology")
	return M
end

--[=[
local GL = GLcanvas{H=700,aspect=1}

NM = GL:Dialog("test",{
	{"orig",false,guitypes.toggle}
})

fileName = [[C:\luaGL\frames_anima\msquares\imagen2.tif]]
--fileName = [[C:\luaGL\frames_anima\im_test\Cosmos_original.jpg]]
--fileName = [[C:\luaGL\frames_anima\im_test\unnamed0.jpg]]
local im = require"imffi"
local vicim = require"anima.vicimag"
-- local image = im.FileImageLoadBitmap(fileName)
-- print(image:DataType(),im.BYTE,im.DataTypeName(image:DataType()),im.DataTypeName(im.BYTE))
local pd = vicim.load_im(fileName)
local texture,program_erode,quad
function GL.init()
	fx = morphology(GL)
	fx.NM.vars.op[0]=4
	texture = pd:totex(GL) --GL:Texture():Load(fileName)
	GL:set_WH(texture.width,texture.height)
	--GL:DirtyWrap()
end

function GL.draw(t,w,h)

	ut.Clear()
	if NM.orig then
		texture:drawcenter(w,h)
	else
		fx:process(texture)
	end
end


GL:start()
--]=]
return morphology