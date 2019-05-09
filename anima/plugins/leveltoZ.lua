require"anima"

local vert_sh = [[
#version 330     
in vec2 position;
uniform sampler2D tex0;
uniform float extfac=1;
uniform float levels;
uniform float time;
uniform vec2 tvec;
float Quantize(float val,float levels)
{
	//return floor(val*levels)/levels;
	return val;
}
void main()
{
	
	vec4 vertex = vec4(position,0,1);
	gl_TexCoord[0] = gl_TextureMatrix[0]* vertex;
	vec4 color = texture2D(tex0,gl_TexCoord[0].st);

	
	float lum = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722)) - 0.5;
	vertex.z = Quantize(lum,levels)*time*extfac;
	/*
	if(extfac > 0.0){
		gl_Vertex.xyz += normal*lum*extfac;
	}else{
		gl_Vertex.xyz += normal*(lum-1.0)*extfac;
	}	
	*/
	gl_Position = vertex + vec4(tvec,0,0);
}

]]
local vert_billboard = [[
#version 330                                                                        
                                                                                    
layout (location = 0) in vec3 Position;                                             
                                                                                    
void main()                                                                         
{                                                                                   
    gl_Position = vec4(Position, 1.0);                                              
}   
]]

local frag_billboard = [[
#version 330                                                                        
                                                                                    
uniform sampler2D gColorMap;                                                        
                                                                                    
in vec2 TexCoord;                                                                   
out vec4 FragColor;                                                                 
                                                                                    
void main()                                                                         
{                                                                                   
    FragColor = texture2D(gColorMap, TexCoord);//*0.3;                                     
    /*                                                                                
    if (FragColor.r >= 0.9 && FragColor.g >= 0.9 && FragColor.b >= 0.9) {           
        discard;                                                                    
    }  
*/	
}
]]
local geom_billboard = [[
#version 330                                                                        
                                                                                    
layout(points) in;                                                                  
layout(triangle_strip) out;                                                         
layout(max_vertices = 4) out;                                                       
                                                                                                                                             
uniform vec3 gCameraPos; 
uniform vec3 gCameraUp;                                                            
uniform float gBillboardSize;   
                                                
uniform vec2 tvec;
                                                                                    
out vec2 TexCoord;                                                                  
                                                                                    
void main()                                                                         
{   
	vec3 tvec3 = vec3(tvec,0);
    mat4 gVP2 = gl_ModelViewProjectionMatrix;
	
	vec3 Posi = gl_in[0].gl_Position.xyz; 
	
    vec3 toCamera = normalize(gCameraPos - Posi);                                    
	vec3 up = normalize(gCameraUp);//vec3(0.0, 1.0, 0.0);                                                  
    vec3 right = cross(toCamera, up) * gBillboardSize*0.5;                              
    vec3 alto = up*gBillboardSize*0.5;
	
    vec3 Pos = Posi - right - alto;                                                                   
    gl_Position = gVP2 * vec4(Pos , 1.0);                                             
    TexCoord = (gl_TextureMatrix[0]*vec4(Pos - tvec3, 1.0)).st;
    EmitVertex();                                                                   
                                                                                    
    Pos = Posi - right + alto;                                                        
    gl_Position = gVP2 * vec4(Pos , 1.0);                                             
    TexCoord = (gl_TextureMatrix[0]*vec4(Pos - tvec3, 1.0)).st;                                           
    EmitVertex();                                                                   
                                                                                    
    Pos = Posi + right - alto;                                                                    
    gl_Position = gVP2 * vec4(Pos , 1.0);                                             
    TexCoord = (gl_TextureMatrix[0]*vec4(Pos - tvec3, 1.0)).st;                                               
    EmitVertex();                                                                   
                                                                                    
    Pos = Posi + right + alto;                                                        
    gl_Position = gVP2 * vec4(Pos , 1.0);                                             
    TexCoord = (gl_TextureMatrix[0]*vec4(Pos - tvec3, 1.0)).st;                                              
    EmitVertex();                                                                   
                                                                                    
    EndPrimitive();                                                                 
}                                                                                   

]]

local frag_sh = [[
#version 330     
in vec2 TexCoord;
out vec4 color;
uniform sampler2D tex0;
void main()
{
  color = texture2D(tex0,TexCoord);
}
]]

function make(GL)
local NM = GL:Dialog("leveltoZ",
{
{"extfac",0.5,guitypes.val,{min=-2,max=2}},
{"levels",10,guitypes.val,{min=1,max=10}},
{"billsize",1,guitypes.val,{min=0,max=2}},
})

local function make_points(w,h)
	local asp = w/h
	w = w -1
	h = h -1

	--local div = w<h and w or h
	local points = {};
    for i = 0, w do
        local X = asp*(i+0.0) / w;
        for j = 0, h do
            local Y = (j+0.0) / h;
            points[#points + 1] = X
            points[#points + 1] = Y
        end
    end
	return points
end

local thisdraw = {}
function thisdraw:init()
	--textura = Texture():Load[[H:\pelis\hadas\master1080\leslie_giro1\frame-0001.tif]]
	--textura = Texture():Load[[C:\luagl\animacion\resonator6\resonator-001.jpg]]
	self.program = GLSL:new():compile(vert_sh,frag_sh,geom_billboard)
	self.texc = make_points(GL.W,GL.H)
	self.vao = VAO({position=self.texc},self.program)
	self.camara = newCamera(GL,true)
	
	self.fbo = GL:initFBO()
	--prtable(frclip)
end




function thisdraw:draw(t,w,h,args)

	self.fbo:Bind()
	args.clip[1]:draw(t,w,h,args.clip)
	self.fbo:UnBind()
	
	local program = self.program
	program:use()
	program.unif.extfac:set{NM.extfac}
	program.unif.time:set{args.elong}
	program.unif.levels:set{math.floor(NM.levels)}
	program.unif.tex0:set{0}
	program.unif.tvec:set{-0.5*1.5,-0.5}
	
	local x,y,z,_,_,_,ux,uy,uz = self.camara:CalcCamera()
    program.unif.gCameraPos:set{x,y,z} 
	program.unif.gCameraUp:set{ux,uy,uz}
	program.unif.gBillboardSize:set{1.05/h}
	
	self.camara:Set()
	gl.glClearColor(0,0,0,0)
	ut.Clear()
	--textura:Bind()
	self.fbo:GetTexture():Bind()
	--gl.glTranslatef(-0.5*1.5,-0.5,0)
	
	glext.glActiveTexture(glc.GL_TEXTURE0);
	gl.glMatrixMode(glc.GL_TEXTURE);
	gl.glLoadIdentity();
	gl.glScalef(1/1.5,1,1)
	
	--gl.glPointSize(1.5)
	self.vao:draw(glc.GL_POINTS)
end
	GL:add_plugin(thisdraw)
	return thisdraw
end

--[=[

GL = GLcanvas{H=1080,viewH=700,aspect=1.5}
ext = make(GL)
function GL.init()

	--textura = Texture():Load[[C:\luajitbin2.0.2-copia\animacion\resonator6\resonator-038.jpg]]
	textura = Texture():Load[[G:\VICTOR\pelis\hadas\master1080\leslie_giro1\frame-0001.tif]]
	--texblur = textura:
end

function GL.draw(t,w,h)
	--textura:draw(t,w,h)
	ext:draw(t,w,h,{clip={textura},elong=1})
end

GL:start()
--]=]

return make

