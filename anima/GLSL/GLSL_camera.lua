local cameraGLSL = [[

uniform vec4 euler;
uniform float focaldist;
uniform vec3 center;
uniform vec2 WindowSize;
vec3 eyepos,up;

mat4 LookAtMatrix(vec3 eye, vec3 center, vec3 up) {
	up = normalize(up);
    vec3 f = normalize(center - eye);
    vec3 s = cross(f, up);
    vec3 u = cross(normalize(s), f);
    return mat4(
        vec4(s, -dot(eye,s)),
        vec4(u, -dot(eye,u)),
        vec4(-f,  -dot(eye,-f)),
        vec4(0.0, 0.0, 0.0, 1)
    );
}
//rotates point p around axis (normalized) om radians
vec3 Twist(vec3 p,vec3 ax,float om)
{
	float sinom = sin(om);
	float cosom = cos(om);
	float ux = dot(p,ax)*(1.0-cosom);
	return ax*ux + p*cosom + cross(ax,p)*sinom;
}

mat4 CalcCamera(float dist, float azim,float elev,float twist,vec3 center,out vec3 eye,out vec3 up)
{

	float cosel = cos(elev);
	eye.x = cosel* sin(azim)*dist;
	eye.y = sin(elev)*dist;
	eye.z = cosel* cos(azim)*dist;
		
	up = cross(eye,vec3(eye.z,0,-eye.x));
	if (cosel < 0) 
		up = -up;
	up = Twist(up, eye, twist);

	//return xL + x,yL + y,zL + z,xL,yL,zL,upX,upY,upZ

	return LookAtMatrix(eye,center,up);
}

vec3 GetDir(vec2 fragcoord)
{
	vec2 uv = fragcoord / WindowSize.xy;
    uv = uv * 2.0 - 1.0;
    uv.x *= WindowSize.x / WindowSize.y;    

    // ray objeto en 0
	vec3 dir = normalize(vec3(uv.xy,-focaldist));
	
	mat4 MV = CalcCamera(euler.w,euler.x,euler.y,euler.z,center,eyepos,up);
	
	vec4 dir4 = MV * vec4(dir,1);
	dir = dir4.xyz/dir4.w;
	return normalize(dir);
}
]]

local raymarchGLSL = [[
uniform int MAX_MARCHING_STEPS = 30;
uniform float EPSdigN = 6;
float EPS_N	= pow(0.1,EPSdigN);
uniform float EPSdig = 6;
float EPS = pow(0.1,EPSdig);//1e-6;
const float end = 100;
float raymarchOLD(vec3 eye,vec3 rd,out vec3 p)
{
	float t = 0;//start;
	for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
		p = eye + t * rd;
		float dist = sceneSDF(p);
		
		if (abs(dist) < EPS) return t;
	
		//if( dist<precis || t>end ) break;
		// Move along the view ray
		t += dist;
		if (t >= end) 
			return -1.0;
	}
	
	return -1.0;
}

float raymarch(vec3 eye,vec3 rd,out vec3 p)
{
	float t = 0;//start;
	for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
		float precis = EPS*t;
		p = eye + t * rd;
		float dist = sceneSDF(p);
	
		if( dist<precis || t>end ) break;
		// Move along the view ray
		t += dist;
	}
	if (t >= end) 
			return -1.0;
	return t;
}

float raymarchHeight2(vec3  ro, const vec3  rd, out vec3 p)
{
    const float delt = 0.01f;
    const float mint = 0.001f;
    const float maxt = 10.0f;
    for( float t = mint; t < maxt; t += delt )
    {
        p = ro + rd*t;
        if( sceneSDF(p)<EPS )
        {
            t -= 0.5f*delt;
			p = ro + rd*t;
			return t;
        }
    }
    return -1.0;
}
/*
float raymarchHeight(vec3 ro,vec3 rd, out vec3 p )
{
    float delt = 0.01f;
    const float mint = 0.001f;
    const float maxt = 10.0f;
    float lh = 0.0f;
    float ly = 0.0f;
    for( float t = mint; t < maxt; t += delt )
    {
        const vec3  p = ro + rd*t;
        float dist = sceneSDF(p);
		float h = p.y - dist;
        if( dist < EPS )
        {
            // interpolate the intersection distance
            t -= dt + dt*(lh-ly)/(p.y-ly-h+lh);
			p = ro + rd*t;
			return t;
        }
        // allow the error to be proportinal to the distance
        delt = 0.01f*t;
        lh = h;
        ly = p.y;
    }
    return -1.0;
}
*/
vec3 estimateNormal( vec3 p) {
    vec3 e = vec3(EPS_N,-EPS_N,0.0);
    return normalize( vec3(
        e.xyy*sceneSDF(p+e.xyy) +
        e.yyx*sceneSDF(p+e.yyx) +
        e.yxy*sceneSDF(p+e.yxy) +
        e.xxx*sceneSDF(p+e.xxx))
    );
}

]]

local phong = [[
uniform vec3 LightPosition = vec3(1.0);
uniform float SpecularContribution = 0.3;
uniform float brightness = 1.0;
float DiffuseContribution = 1.0 - SpecularContribution;
uniform float ambient = 0.01;
uniform float shininess = 16;

float phong_light(float t,vec3 point,vec3 eye,vec3 N,vec3 ligthpos)
{
	float lum = ambient;
	vec3 L = ligthpos - point;
	//float light_dist = length(L);
	float distfac = 1.0;///(1.0 + light_dist*light_dist);
	L = normalize(L);
	
	vec3 R = reflect(-L, N);
	vec3 V = normalize(eye-point);
	
	float diffuse = max(dot(L, N), 0.0);
	//float diffuse = abs(dot(L, N));
	
	float spec = 0.0;
	//if (diffuse > 0.0){
		spec = max(dot(R,V),0.0);//abs(dot(R, V));
		spec = pow(spec, shininess);
	//}
	lum += (DiffuseContribution * diffuse + SpecularContribution * spec)*distfac;
	lum *= brightness;
	lum *= exp( -0.0005*t*t*t );
	return pow(lum, 1.0/2.2);
	//return linearColor;
}

float calcSoftshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax, int technique )
{
	float res = 1.0;
    float t = mint;
    float ph = 1e10; // big, such that y = 0 on the first iteration
    
    for( int i=0; i<32; i++ )
    {
		float h = sceneSDF( ro + rd*t );

        // traditional technique
        if( technique==0 )
        {
        	res = min( res, 10.0*h/t );
        }
        // improved technique
        else
        {
            // use this if you are getting artifact on the first iteration, or unroll the
            // first iteration out of the loop
            //float y = (i==0) ? 0.0 : h*h/(2.0*ph); 

            float y = h*h/(2.0*ph);
            float d = sqrt(h*h-y*y);
            res = min( res, 10.0*d/max(0.0,t-y) );
            ph = h;
        }
        
        t += h;
        
        if( res<0.0001 || t>tmax ) break;
        
    }
    return clamp( res, 0.0, 1.0 );
}

float calcAO( in vec3 pos, in vec3 nor )
{
	float occ = 0.0;
    float sca = 1.0;
    for( int i=0; i<5; i++ )
    {
        float h = 0.001 + 0.15*float(i)/4.0;
        float d = sceneSDF( pos + h*nor );
        occ += (h-d)*sca;
        sca *= 0.95;
    }
    return clamp( 1.0 - 1.5*occ, 0.0, 1.0 );    
}

vec3 render( in vec3 pos,in vec3 ro,float t, in vec3 rd, in int technique)
{ 
    vec3  col = vec3(0.0);

    if( t>-0.5 )
    {
        //vec3 pos = ro + t*rd;
        vec3 nor = estimateNormal( pos );
        
        // material        
		vec3 mate = vec3(0.3);

        // key light
        //vec3  lig = normalize( vec3(-0.1, 0.3, 0.6) );
		vec3 lig = normalize(LightPosition-pos);
        vec3  hal = normalize( lig-rd );
        float dif = clamp( dot( nor, lig ), 0.0, 1.0 ) * 
                    calcSoftshadow( pos, lig, 0.01, 10.0, technique );

		float spe = pow( clamp( dot( nor, hal ), 0.0, 1.0 ),shininess)*
                    dif *
                    (0.04 + 0.96*pow( clamp(1.0+dot(hal,rd),0.0,1.0), 5.0 ));

		col = mate * 4.0*dif*vec3(1.00,0.70,0.5);
        col +=      12.0*spe*vec3(1.00,0.70,0.5);
        
        // ambient light
        float occ = calcAO( pos, nor );
		float amb = clamp( 0.5+0.5*nor.y, 0.0, 1.0 );
        col += mate*amb*occ*vec3(0.0,0.08,0.1);
        
        // fog
        col *= exp( -0.0005*t*t*t );
    }

	return col;
}
]]

local function make(GL)
local M = {GL=GL}

function M:Dialogs(GL)
	self.NM = GL:Dialog("Euler",
	{
	{"azimuth",0,guitypes.dial,{orientation="CIRCULAR"}},
	{"elevation",0,guitypes.dial,{orientation="CIRCULAR"}},
	{"twist",0,guitypes.dial,{orientation="CIRCULAR"}},
	{"dist",7,guitypes.dial,{orientation="CIRCULAR"}},
	{"focaldist",3,guitypes.dial,{orientation="CIRCULAR"}},
	{"xL",0,guitypes.dial,{orientation="CIRCULAR"}},
	{"yL",0,guitypes.dial,{orientation="CIRCULAR"}},
	{"zL",0,guitypes.dial,{orientation="CIRCULAR"}},
	
	})
	self.NMphong = GL:Dialog("Phong",
	{{"brightness",1,guitypes.val,{min=0,max=10}},
	{"SpecularContribution",0.3,guitypes.val,{min=0,max=1}},
	{"shininess",16,guitypes.val,{min=0,max=100}},
	{"ambient",0.01,guitypes.val,{min=0,max=0.1}},
	{"LightPosition",{1,1.6,-3},guitypes.drag}
	})
	self.NMraymarching = GL:Dialog("raymarch",
	{{"EPSdig",3,guitypes.val,{min=0,max=10}},
	{"EPSdigN",3,guitypes.val,{min=0,max=10}},
	{"MAX_MARCHING_STEPS",64,guitypes.valint,{min=1,max=150}}
	})
end

M:Dialogs(GL)

function M:set_unif(program)
	local U = program.unif
	local NM2 = self.NM
	U.euler:set{NM2.azimuth,NM2.elevation,NM2.twist,NM2.dist}
	U.focaldist:set{NM2.focaldist}
	U.center:set{NM2.xL,NM2.yL,NM2.zL}
	U.WindowSize:set{self.GL.W,self.GL.H}
	program:set_unif(self.NMphong)
	--program.unif.LightPosition:set(self.NMphong.LightPositionV)
	program:set_unif(self.NMraymarching)
end
	return M
end
---[=[

local rayfrag = require"anima.GLSL.GLSL_sdf"..cameraGLSL..
[[
uniform float ksmin = 0.1;
uniform float planeh = 1;
float sceneSDF(vec3 pos)
{
	//float d1 = sdTorus(pos,vec2(1.0,0.3));
	float d1 = sdSphere(pos,1.0);
	float d2 = sdBox(pos,vec3(1,0.5,0.3));
	float d3 = sdPlane(pos,vec4(normalize(vec3(0,1,0)),planeh));
	return min(d1,min(d2,d3));
	//return sminPol(d1,d2,ksmin);
}
float sceneSDFHeight(vec3 pos)
{
	float len =  length(vec2(pos.x,pos.z));
	if (len > 1){
		return pos.y;
	}else{
		return pos.y - sqrt(1-pos.x*pos.x-pos.z*pos.z);
	}
}
]]
..raymarchGLSL..phong..[[

float randhash(uint seed, float b)
{
    const float InverseMaxInt = 1.0 / 4294967295.0;
    uint i=(seed^12345391u)*2654435769u;
    i^=(i<<6u)^(i>>26u);
    i*=2654435769u;
    i+=(i<<5u)^(i>>12u);
    return float(b * i) * InverseMaxInt;
}
out vec4 fragColor;
uniform int AA= 1;
uniform bool Jitter;
uniform bool dophong;
uniform int tecnique = 0;
void main()
{
	vec3 color = vec3(0);
	
	for( int m=0; m<AA; m++ ){
        for( int n=0; n<AA; n++ )
        {
			vec2 rr = vec2( float(m), float(n) ) / float(AA);
			vec2 fcoord = gl_FragCoord.xy + rr;
			vec3 dir = GetDir(fcoord);
	
			if (Jitter) {
				uint seed = uint(fcoord.x) * uint(fcoord.y);
				eyepos += dir * (-0.5 + randhash(seed, 1.0));
			}
	
			vec3 p = vec3(0);
			float dist = raymarch(eyepos,dir,p);
			//float dist = raymarchHeight2(eyepos,dir,p);
	
			if (dophong){
				//if (dist < end && dist > -0.5){
				if (dist > 0.0){
					vec3 normal = estimateNormal(p);
					float brigth = phong_light(dist,p,eyepos,normal,LightPosition);	
					color += vec3(1)*brigth;
				}//else
				//color += vec3(0,1,0);
			}else{
				color += render(p,eyepos,dist,dir,tecnique);
			}
		}
	}
	
	color /= float(AA*AA);
    // post
	fragColor = vec4(pow(color,vec3(1/2.2)), 1.0);
}

]]
require"anima"
local GL = GLcanvas{H=800,aspect=1.5}
local program
local NM = GL:Dialog("shapes",
{
{"ksmin",0.1,guitypes.val,{min=0,max=0.5}},
{"planeh",1,guitypes.val,{min=-2,max=2}},
{"Jitter",false,guitypes.toggle},
{"dophong",false,guitypes.toggle},
{"AA",1,guitypes.valint,{min=1,max=4}},
{"tecnique",1,guitypes.valint,{min=0,max=1}}
})

RM = make(GL)
print(type(RM.NMphong.LightPositionV))
local msaa
function GL.init()
	program = GLSL:new():compile(ut.vert_std,rayfrag)
	--msaa = initFBOMultiSample(GL.W,GL.H)
end

function GL.draw(t,w,h)
	--if NM.msaa then msaa:Bind() end
	program:use()
	RM:set_unif(program)
	--program.unif.ksmin:set{NM.ksmin}
	program:set_unif(NM)
	ut.Clear()
	ut.project(w,h)
	ut.DoQuad(w,h)
	--if NM.msaa then msaa:Dump() end
	
end

GL:start()
--]=]


return make