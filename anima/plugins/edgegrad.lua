

local frag_grad = [[

uniform sampler2D tex;
uniform vec2 Res;
vec2 Res0 = textureSize(tex,0).xy;
uniform float delta = 2.0;
float getBW(vec2 pos)
{
	return dot(texture(tex,pos/Res0).xyz, vec3(0.299, 0.587, 0.114));
}
vec2 getGrad(vec2 pos,float delta)
{
    vec2 d=vec2(delta,0);

	return vec2(getBW(pos+d.xy)-getBW(pos-d.xy),
		getBW(pos+d.yx)-getBW(pos-d.yx)
	)/delta;
}

out vec4 fragColor;
void main()
{
   //centered pos
	vec2 pos=((gl_FragCoord.xy-Res.xy*.5)/Res.y*Res0.y)+Res0.xy*.5;
	vec2 gr = getGrad(pos, delta);
	float grl = length(gr);
	fragColor = vec4(normalize(gr),grl,1);
}
]]


require"anima"


function make(GL)
	local plugin = require"anima.plugins.plugin"
	
	
local NM = GL:Dialog("edgegrad",{
{"delta",1,guitypes.val,{min=0,max=4}},
})
	local M = plugin.new(nil,GL,NM)
	local pgrad
function M:init()
	pgrad = GLSL:new():compile(ut.vert_std,frag_grad)
end
function M:process(textura)
	local w,h = GL.W,GL.H
	pgrad:use()
	local U = pgrad.unif
	U.tex:set{0}
	textura:Bind(0)
	--blurtex:Bind(0)
	U.Res:set{GL.W,GL.H}
	U.delta:set{NM.delta}
	ut.Clear()
	ut.project(w,h)
	ut.DoQuad(w,h)

end
	GL:add_plugin(M)
	return M
end

--[=[
GL = GLcanvas{H=1080,aspect=1.5}
local tex,edge

function GL.init()
	tex = Texture():Load([[G:\VICTOR\pelis\pelipino\master1080\muro\frame-0001.tif]],false,true)
	edge = make(GL)
	
	--GL:DirtyWrap()
end
function GL.draw(t,w,h)
	local fbo = GL:get_fbo()
	edge:process_fbo(fbo,tex)
	fbo:tex():togrey(w,h,{0,0,1,0})
	fbo:release()
end
GL:start()
--]=]
--[=[
--print(path.this_script_path())
GL = GLcanvas{H=1080,aspect=1.5}
local tex,wcol
local fbos = {}
local curr = 0
function GL.init()
	tex = Texture():Load([[G:\VICTOR\pelis\pelipino\master1080\muro\frame-0001.tif]],false,true)
	wcol = make(GL)
	fbos[0] = initFBO(GL.W,GL.H)
	fbos[1] = initFBO(GL.W,GL.H)
	fbos[curr]:Bind()
	tex:draw(t,w,h)
	fbos[curr]:UnBind()
	curr = (curr+1)%2
	--GL:DirtyWrap()
end
function GL.draw(t,w,h)
	fbos[curr]:Bind()
	wcol:draw(t,w,h,{clip={fbos[(curr+1)%2]:tex()}})
	fbos[curr]:UnBind()
	fbos[curr]:tex():draw(t,w,h)
	curr = (curr+1)%2
end
GL:start()
--]=]
return make