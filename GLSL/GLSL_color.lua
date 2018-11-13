local colorfuncs = [[
vec3 RGB2HSV(vec3 color){
	float var_R = color.r;  
	float var_G = color.g;
	float var_B = color.b;

	float var_Min = min(min( var_R, var_G), var_B );    //Min. value of RGB
	float var_Max = max(max( var_R, var_G), var_B );    //Max. value of RGB
	float del_Max = var_Max - var_Min;             //Delta RGB value

	float V = var_Max;
	float H,S;
	if ( del_Max == 0.0 )                     //This is a gray, no chroma...
	{
		H = 0.0;                               //HSV results from 0 to 1
		S = 0.0;
	}
	else                                    //Chromatic data...
	{
		S = del_Max / var_Max;
		
		float del_R = ( ( ( var_Max - var_R ) / 6.0 ) + ( del_Max / 2.0 ) ) / del_Max;
		float del_G = ( ( ( var_Max - var_G ) / 6.0 ) + ( del_Max / 2.0 ) ) / del_Max;
		float del_B = ( ( ( var_Max - var_B ) / 6.0 ) + ( del_Max / 2.0 ) ) / del_Max;
		
		if      ( var_R == var_Max ) H = del_B - del_G;
		else if ( var_G == var_Max ) H = ( 1.0 / 3.0 ) + del_R - del_B;
		else if ( var_B == var_Max ) H = ( 2.0 / 3.0 ) + del_G - del_R;
		
		if ( H < 0.0 ) H += 1.0;
		if ( H > 1.0 ) H -= 1.0;
	}
	return vec3(H,S,V);
}

vec3 HSV2RGB(vec3 hsv){
	float H = hsv.x;
	float S = hsv.y;
	float V = hsv.z;
	float var_r, var_g , var_b;
	
	if ( S == 0.0 )                       //HSV from 0 to 1
	{
		var_r = V;
		var_g = V;
		var_b = V;
	}
	else
	{
		float var_h = H * 6.0;
		if ( var_h == 6.0 ) var_h = 0.0;      //H must be < 1
		int var_i = int(floor( var_h ));             //Or ... var_i = floor( var_h )
		float var_1 = V * ( 1.0 - S );
		float var_2 = V * ( 1.0 - S * ( var_h - var_i ) );
		float var_3 = V * ( 1.0 - S * ( 1.0 - ( var_h - var_i ) ) );
		
		if      ( var_i == 0 ) { var_r = V     ; var_g = var_3 ; var_b = var_1; }
		else if ( var_i == 1 ) { var_r = var_2 ; var_g = V     ; var_b = var_1; }
		else if ( var_i == 2 ) { var_r = var_1 ; var_g = V     ; var_b = var_3; }
		else if ( var_i == 3 ) { var_r = var_1 ; var_g = var_2 ; var_b = V;     }
		else if ( var_i == 4 ) { var_r = var_3 ; var_g = var_1 ; var_b = V;    }
		else                   { var_r = V     ; var_g = var_1 ; var_b = var_2; }
		
	}
	
	return vec3(var_r, var_g , var_b);
}

float RGB2sRGB(float val)
{
	float a = 0.055;
	if (val <= 0.0031308)
		 return val*12.92;
	else
		return (1.0 + a)*pow(val,1.0/2.4) - a;
}
vec3 RGB2sRGB(vec3 v)
{
	return vec3(RGB2sRGB(v.r),RGB2sRGB(v.g),RGB2sRGB(v.b));
}
float sRGB2RGB(float val)
{
	float a = 0.055;
	if (val <= 0.04045)
		 return val/12.92;
	else
		return pow((val + a)/(1.0 + a),2.4);
}
vec3 sRGB2RGB(vec3 v)
{
	return vec3(sRGB2RGB(v.r),sRGB2RGB(v.g),sRGB2RGB(v.b));
}

vec3 RGB2XYZ(vec3 rgb)
{
	const mat3x3 Mt = {{0.4124564,  0.3575761,  0.1804375},
				{0.2126729,  0.7151522,  0.0721750},
				{0.0193339,  0.1191920,  0.9503041}};
	const mat3x3 M = transpose(Mt);
	return M * rgb;
}

vec3 XYZ2RGB(vec3 xyz)
{
	const mat3x3 Mt = {{3.2404542, -1.5371385, -0.4985314},
				{-0.9692660,  1.8760108,  0.0415560},
				{0.0556434, -0.2040259,  1.0572252}};
	const mat3x3 M = transpose(Mt);
	return M * xyz;
}
///////////XYZ LAB
float delt = 6.0/29.0;
float delt2 = delt*delt;
float delt3 = delt2*delt;
float fflab(float t)
{
	if(t > delt3)
		return pow(t, 1.0/3.0);
	else
		return t/(3.0*delt2) + 4.0/29.0;
}
float fflab_inv(float t)
{
	if(t > delt)
		return pow(t, 3.0);
	else
		return 3.0*delt2*(t - 4.0/29.0);
}
//standart white points
const vec3 A ={	1.09850, 	1.00000 ,	0.35585};
const vec3 B 	={0.99072 ,	1.00000 ,	0.85223};
const vec3 C 	={0.98074, 	1.00000 ,	1.18232};
const vec3 D50 = {	0.96422, 	1.00000, 	0.82521};
const vec3 D55 = {	0.95682, 	1.00000, 	0.92149};
const vec3 D65 = {	0.95047, 	1.00000, 	1.08883};
const vec3 D75 = {	0.94972, 	1.00000, 	1.22638};
const vec3 E 	= 	{1.00000, 	1.00000, 	1.00000};
const vec3 F2 = 	{0.99186, 	1.00000, 	0.67393};
const vec3 F7 = 	{0.95041, 	1.00000, 	1.08747};
const vec3 F11 = {	1.00962, 	1.00000, 	0.64350};
vec3 XYZ2LAB(vec3 xyz, vec3 White)
{
	vec3 xyz_n = xyz/White;
	float fx = fflab(xyz_n.x);
	float fy = fflab(xyz_n.y);
	float fz = fflab(xyz_n.z);
	float L = 116.0*fy -16.0;
	float a = 500.0*(fx - fy);
	float b = 200.0*(fy - fz);
	return vec3(L,a,b);
}

vec3 LAB2XYZ(vec3 Lab,vec3 White)
{
	float fac = (Lab.x + 16.0)/116.0;
	float X =fflab_inv(fac + Lab.y/500.0);
	float Y = fflab_inv(fac);
	float Z = fflab_inv(fac - Lab.z/200.0);
	return vec3(X,Y,Z)*White;
}
const float pi = radians(180.0);
vec3 LAB2LCH(vec3 Lab)
{
	float H = atan(Lab.z,Lab.y);
	if(H < 0) H += 2*pi;
	float C = sqrt(Lab.y*Lab.y + Lab.z*Lab.z);
	return vec3(Lab.x,C,H);
}
vec3 LCH2LAB(vec3 Lch)
{
	float a = Lch.y * cos(Lch.z);
	float b = Lch.y * sin(Lch.z);
	return vec3(Lch.x,a,b);
}

vec3 sRGB2LAB(vec3 rgb){
	return XYZ2LAB(RGB2XYZ(sRGB2RGB(rgb)),D65);
}

vec3 LAB2sRGB(vec3 lab){
	return RGB2sRGB(XYZ2RGB(LAB2XYZ(lab,D65)));
}

const mat3x3 BradT = {{ 0.8951000,  0.2664000, -0.1614000},
{-0.7502000,  1.7135000,  0.0367000},
 {0.0389000, -0.0685000,  1.0296000}};

const mat3x3  Bradford = transpose(BradT);

const mat3x3 BradinvT = {{0.9869929, -0.1470543,  0.1599627},
{ 0.4323053,  0.5183603,  0.0492912},
{-0.0085287,  0.0400428,  0.9684867}};

const mat3x3 BradfordInv = transpose(BradinvT);



]]

return colorfuncs

