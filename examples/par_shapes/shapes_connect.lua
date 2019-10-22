require"anima"
local par_shapes = require"anima.par_shapes"

local vert_sh = [[
#version 330
in vec3 position;
in vec3 normal;

uniform vec3 color;
out vec4 out_color;
uniform mat4 MV;
uniform mat4 MVP;
mat4 normalmat = transpose(inverse(MV));

out vec3 fnormal;
out vec4 fpos;
void main()
{
    vec4 point = vec4(position,1.0);
    fpos = MV*point;
    vec4 normalvec = normalmat * vec4(normal,1.0);
    fnormal = normalize( normalvec.xyz);
    gl_Position = MVP * point;
    out_color = vec4(color,1.0);
}

]]

local frag_sh = [[
#version 330
uniform vec3 LightPosition = vec3(0.3);
uniform float SpecularContribution = 0.3;
uniform float brightness = 1.0;
float DiffuseContribution = 1.0 - SpecularContribution;
uniform float ambient = 0.0;
float compute_light(vec4 point,vec3 ligthpos, vec3 normal)
{
    vec3 ecPosition = vec3( point);
    
    vec3 tnorm = normal;
    
    vec3 lightVec = ligthpos - ecPosition;
    float light_dist = length(lightVec);
    float distfac = 1.0/(1.0 + light_dist*light_dist);
    lightVec = normalize(lightVec);
    
    vec3 reflectVec = reflect(-lightVec, tnorm);
    vec3 viewVec = normalize(-ecPosition);
    //float diffuse = max(dot(lightVec, tnorm), 0.0);
    float diffuse = abs(dot(lightVec, tnorm));
    float spec = 0.0;
    //if (diffuse > 0.0){
        spec = abs(dot(reflectVec, viewVec));//, 0.0);
        spec = pow(spec, 16.0);
    //}
    float linearColor = (DiffuseContribution * diffuse + SpecularContribution * spec)*distfac;
    linearColor *= brightness;
    linearColor += ambient;
    return pow(linearColor, 1.0/2.2);
}
in vec4 out_color;
in vec3 fnormal;
in vec4 fpos;
void main()
{ 
    float LightIntensity = compute_light(fpos,LightPosition,fnormal);
    gl_FragColor = out_color*LightIntensity;
}
]]

local vert_normals_sh = [[
#version 330
in vec3 position;
in vec3 normal;
out vec4 normal_g;
varying vec4 out_color;
uniform mat4 MV;
mat4 normalmat = transpose(inverse(MV));
void main()
{
    gl_Position = vec4(position,1.0);
    out_color = vec4(1.0,0,0,1.0);
    normal_g = vec4(normal,0.0);
}
]]

local geom_normals_sh = [[
#version 330
uniform mat4 MVP;
layout(points) in;
layout(line_strip, max_vertices = 2) out;  
in vec4 normal_g[1];    
void main()
{
    vec4 point = gl_in[0].gl_Position;
    gl_Position = MVP*point;
    EmitVertex(); 
    gl_Position = MVP*(point + normal_g[0]);
    EmitVertex();  
    EndPrimitive(); 
}
]]

local frag_normals_sh = [[
#version 330
varying vec4 out_color;
void main()
{
    gl_FragColor = vec4(1.0,0,0,1.0);
}
]]

local GL = GLcanvas{fps=60,aspect=1.5,H=700,profile="CORE"}

local mesh, vao, vao_normals, program,prog_normals, mssa, camara
function GL.init()

    --create mesh
    local slices = 32
    mesh = par_shapes.create.empty()
    local tube = par_shapes.create.cylinder(slices, 1);
    local cone = par_shapes.create.cone(slices,1)

    mesh:merge(tube)
    cone:translate(1,1,3)
    mesh:connect(cone,slices)
    mesh:merge(cone)
    mesh:compute_welded_normals()
    
    --compile programs and vaos
    program = GLSL:new():compile(vert_sh,frag_sh)
    
    prog_normals = GLSL:new():compile(vert_normals_sh,frag_normals_sh,geom_normals_sh)
    
    vao = VAO({position=mesh.points,normal=mesh.normals},program,mesh.triangles,
    {position=mesh.npoints*3,normal=mesh.npoints*3},mesh.ntriangles*3)
    
    vao_normals = vao:clone(prog_normals)
    
    --init mssa
    mssa = initFBOMultiSample(GL)
    
    --set camera
    camara = newCamera(GL,true)
    camara.NMC.vars.distfac[0]=5
    camara.NMC.vars.azimuth[0]=1.396
    camara.NMC.vars.zcamL[0]=1.291
    camara.NMC.vars.ycamL[0]=-0.294
    
    -- set imgui dialog
    NM = GL:Dialog("specular",{
{"brightness",73,guitypes.val,{min=0,max=100}},
{"specular",0.5,guitypes.val,{min=0,max=1}},
{"ambient",0,guitypes.val,{min=0,max=0.1}},
{"mssa",false,guitypes.toggle},
{"cull",false,guitypes.toggle},
{"points",false,guitypes.toggle},
{"normals",false,guitypes.toggle},
{"faces",true,guitypes.toggle},
},function() end)

end


function GL.draw(t,w,h)

    gl.glViewport(0,0,w,h)

    if NM.mssa then mssa:Bind() end
    
    if NM.cull then gl.glEnable(glc.GL_CULL_FACE) else gl.glDisable(glc.GL_CULL_FACE) end

    program:use()
    program.unif.color:set{1,0,0}
    program.unif.SpecularContribution:set{NM.specular}
    program.unif.brightness:set{NM.brightness}
    program.unif.ambient:set{NM.ambient}
    --camara:Set()
    program.unif.MV:set(camara:MV().gl)
    program.unif.MVP:set(camara:MVP().gl)
    ut.Clear()

    gl.glPointSize(5);
    if NM.points then vao:draw(glc.GL_POINTS,mesh.npoints) end
    
    program.unif.color:set{0,1,0}
    if NM.faces then vao:draw_elm() end

    if NM.normals then
        prog_normals:use()
        prog_normals.unif.MV:set(camara:MV().gl)
        prog_normals.unif.MVP:set(camara:MVP().gl)
        vao_normals:draw_elm(glc.GL_POINTS)
    end
    gl.glDisable(glc.GL_CULL_FACE)
    
    if NM.mssa then mssa:Dump() end
end

GL:start()