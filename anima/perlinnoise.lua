--[[
function Noise1(integer x, integer y)
	local n = x + y * 57
	n = (n<<13) ^ n;
	return ( 1.0 - ( (n * (n * n * 15731 + 789221) + 1376312589) & 7fffffff) / 1073741824.0);    
end
--]]
local simplexnoise = require"simplexnoise"
if not bit32 then
	if bit then
		bit32 = bit
	else
		bit32 = require"bitOp"
	end
end
local function Noise2D(x,y)
	local n = x + bit32.tobit(y * 57)
	n = bit32.bxor(bit32.lshift(n, 13),n)
	return bit32.band((bit32.tobit(n * (bit32.tobit(bit32.tobit(n * n) * 15731) + 789221)) + 1376312589),0x7fffffff) / 2147483648.0
end
local function IntNoise(n)
	n = bit32.bxor(bit32.lshift(n, 13),n)
	return bit32.band((bit32.tobit(n * (bit32.tobit(bit32.tobit(n * n) * 15731) + 789221)) + 1376312589),0x7fffffff) / 2147483648.0
end
local function LCGRandom(last)
	--return bit32.tobit(bit32.tobit(1103515245 * last) + 12345) % 0x100000000;
	return bit32.band(bit32.tobit(1103515245 * last) + 12345, 0x7FFFFFFF);
	--return bit32.tobit(bit32.tobit(1103515245 * lastValue) + 12345)
end
local function hash(i,j,k)
	local FNV_PRIME = 16777619
	local OFFSET_BASIS = 2166136261
	--return (uint)((((((OFFSET_BASIS ^ (uint)i) * FNV_PRIME) ^ (uint)j) * FNV_PRIME) ^ (uint)k) * FNV_PRIME);
	return bit32.tobit(bit32.bxor(bit32.tobit(bit32.bxor(bit32.tobit(bit32.bxor(OFFSET_BASIS,i) * FNV_PRIME),j) * FNV_PRIME),k) * FNV_PRIME);
end
local function Noise2D2(x,y)
	--return LCGRandom(x + y * 57)/0x7FFFFFFF
	return LCGRandom(hash(x,y,17))/0x7FFFFFFF
end

local function SmoothedNoise2D( x,  y)
    local corners = ( Noise(x-1, y-1)+Noise(x+1, y-1)+Noise(x-1, y+1)+Noise(x+1, y+1) ) / 16
    local sides   = ( Noise(x-1, y)  +Noise(x+1, y)  +Noise(x, y-1)  +Noise(x, y+1) ) /  8
    local center  =  Noise(x, y) / 4
    return corners + sides + center
end

local function Linear_Interpolate(a, b, x)
	return  a*(1-x) + b*x
end

local function Cosine_Interpolate(a, b, x)
	local ft = x * math.pi
	local f = (1 - math.cos(ft)) * .5
	return  a*(1-f) + b*f
end

local function Cubic_Interpolate(v0, v1, v2, v3,x)
	local P = (v3 - v2) - (v0 - v1)
	local Q = (v0 - v1) - P
	local R = v2 - v0
	local S = v1
	return P*x^3 + Q*x^2 + R*x + S
end

local function InterpolatedNoise1D( x, InterpolateFunc , NoiseFunc)
	InterpolateFunc = InterpolateFunc or Linear_Interpolate
	NoiseFunc = NoiseFunc or IntNoise
	
	local integer_X    = math.floor(x)
	local fractional_X = x - integer_X
	
	return InterpolateFunc(NoiseFunc(integer_X) , NoiseFunc(integer_X + 1) , fractional_X)
end 

local function InterpolatedNoise1DCubic( x, InterpolateFunc , NoiseFunc)
	--InterpolateFunc = InterpolateFunc or Linear_Interpolate
	NoiseFunc = NoiseFunc or IntNoise
	
	local integer_X    = math.floor(x)
	local fractional_X = x - integer_X
	
	return Cubic_Interpolate(NoiseFunc(integer_X-1),NoiseFunc(integer_X) , NoiseFunc(integer_X + 1), NoiseFunc(integer_X + 2) , fractional_X)
end 

local function InterpolatedNoise2D( x,  y, InterpolateFunc , NoiseFunc)

	InterpolateFunc = InterpolateFunc or Linear_Interpolate
	NoiseFunc = NoiseFunc or Noise
	
	local integer_X    = math.floor(x)
	local fractional_X = x - integer_X
	
	local integer_Y    = math.floor(y)
	
	local i1 = InterpolateFunc(NoiseFunc(integer_X, integer_Y) , NoiseFunc(integer_X + 1, integer_Y) , fractional_X)
	local i2 = InterpolateFunc(NoiseFunc(integer_X, integer_Y + 1) , NoiseFunc(integer_X + 1, integer_Y + 1) , fractional_X)
	
	return InterpolateFunc(i1 , i2 , y - integer_Y)
end
 
local raw_noise = simplexnoise.raw_noise
local raw_noise2d = simplexnoise.raw_noise2d

function PerlinNoise_1D( x, n, p)
      local total = 0
	  local maxAmp = 0
      --p = persistence
      --n = Number_Of_Octaves - 1
	  n= n or 1
	  p = p or 0.5
      for i=0,n-1 do
          local frequency = 2^i
          local amplitude = p^i
          total = total + InterpolatedNoise1D(x * frequency,Cosine_Interpolate,IntNoise) * amplitude
		  --total = total + raw_noise2d(x * frequency,1) * amplitude
		  maxAmp = maxAmp + amplitude
      end
      return total/maxAmp
end

function PerlinNoise_1DCubic( x, n, p)
      local total = 0
	  local maxAmp = 0
      --p = persistence
      --n = Number_Of_Octaves - 1
      for i=0,n-1 do
          local frequency = 2^i
          local amplitude = p^i
          total = total + InterpolatedNoise1DCubic(x * frequency,InterpolatedNoise1DCubic,IntNoise) * amplitude
		  maxAmp = maxAmp + amplitude
      end
      return total/maxAmp
end

function PerlinNoise_2D( x,  y, n, p)
      local total = 0
	  local maxAmp = 0
      --p = persistence
      --n = Number_Of_Octaves - 1
      for i=0,n-1 do
          local frequency = 2^i
          local amplitude = p^i
		  total = total + 0.5*(raw_noise2d(x* frequency,y* frequency) + 1) * amplitude
          --total = total + InterpolatedNoise2D(x * frequency, y * frequency,Cosine_Interpolate,Noise2D) * amplitude
		  maxAmp = maxAmp + amplitude
      end
      return total/maxAmp
end

function PerlinNoise_2Dx( x,  y, n, p)
      local total = 0
	  local maxAmp = 0
      local frequency = 1
	  local amplitude = 1
      --n = Number_Of_Octaves - 1
      for i=1,n do
		total = total + raw_noise2d(x* frequency,y* frequency) * amplitude
		--total = total + 0.5*(raw_noise2d(x* frequency,y* frequency)+1) * amplitude
		--total = total + InterpolatedNoise2D(x * frequency, y * frequency,Cosine_Interpolate,Noise2D) * amplitude
		maxAmp = maxAmp + amplitude
		frequency = frequency * 2
		amplitude = amplitude * p
      end
      return 0.5*(total/maxAmp + 1)
	  --return total/maxAmp
end

local function InterPol( a,  b,  x)  
    return a+(b-a)*x*x*(3-2*x);               
end

function PerlinNoise( x, y, widthd, octaves, seed)
           if (octaves>12) then octaves=12; end            -- // octaves: Numero de pasadas a distinta amplitud y periodo
           local amplitud = 1;                        --La amplitud es 128,64,32,16... para cada pasada
           local periodo = 256;             --El periodo es similar a la amplitud
           local valor = 0;
           for s =0,octaves-1 do
                amplitud = amplitud*0.5;                      --Manera rápida de dividir entre 2
                periodo = periodo*0.5;
                local freq = 1/periodo;             --Optimizacion para dividir 1 vez y multiplicar luego
                local num_pasos = math.floor(widthd*freq);         --Para el const que vimos en IntNoise
                local pasox = math.floor(x*freq);                 --Indices del vértice superior izquerda del cuadrado
                local pasoy = math.floor(y*freq);                 --en el que nos encontramos
                local cachox = x*freq-pasox;               --frac_x y frac_y en el ejemplo
                local cachoy = y*freq-pasoy;
                local casillaPseed = pasox + pasoy*num_pasos + seed;     -- índice final del IntNoise
                local a=InterPol(IntNoise(casillaPseed),IntNoise(casillaPseed + 1),cachox);
                local b=InterPol(IntNoise(casillaPseed+num_pasos),IntNoise(casillaPseed+1+num_pasos),cachox);
                valor = valor + InterPol(a,b,cachoy)*amplitud;   --superposicion del valor final con anteriores
          end
          return valor;                           --seed es un numero que permite generar imagenes distintas
end
