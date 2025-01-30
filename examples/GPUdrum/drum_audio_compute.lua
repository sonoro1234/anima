--Solo un pase de gpugpu
--reflexion en fragment world coord
require"anima"
local sndf = require"sndfile_ffi"
------------------------points calc

local add_drop_hexa_fs = [[
#version 430 compatibility
const float PI = 3.141592653589793;
const ivec2 dx = ivec2(1.0, 0.0);
const ivec2 dy = ivec2(0.0, 1.0);

uniform float loss;
uniform float a;
uniform float slfac;
uniform vec2 center = vec2(30,30);
uniform ivec2 micro;
uniform float radius = 10;
uniform float strength = 0.2;
uniform float atfac;
uniform float damp;

layout (local_size_x = 32 ,local_size_y = 32) in;
layout (r32f, binding = 0) writeonly uniform imageBuffer audio_buffer;
layout (r32f, binding = 1) readonly uniform image2D shape_buffer;
layout (r32f, binding = 2) readonly uniform image2DArray waveguides;
layout (r32f, binding = 3) writeonly uniform image2DArray waveguides1;
layout (rgba32f, binding = 4) uniform image2D X;
layout (rgba32f, binding = 5) uniform image2D Xout;

uniform int slot;
float radiusinv = 5/radius;
void main() {

	float ix = int(gl_GlobalInvocationID.x);
	float iy = int(gl_GlobalInvocationID.y);
	ivec2 coord = ivec2(ix,iy);
	
	//vec4 info = texelFetch(X, coord,0);// * imageLoad(shape_buffer,coord).r;
	vec4 info = imageLoad(X, coord);// * imageLoad(shape_buffer,coord).r;
	
	float drop = max(0.0, 1.0 - length(center - coord) / radius);
    drop = (0.5 - cos(drop * PI) * 0.5)*radiusinv;
	float imp = drop*strength*atfac;
	float dampi = (1-0.99)*damp + 0.99*info.g;
	float dampii = 1- dampi;
	
	float wgN = imageLoad(waveguides, ivec3(coord,0)).r;
	float wgE = imageLoad(waveguides, ivec3(coord,1)).r;
	float wgS = imageLoad(waveguides, ivec3(coord,2)).r;
	float wgO = imageLoad(waveguides, ivec3(coord,3)).r;
	float wgSE = imageLoad(waveguides, ivec3(coord,4)).r;
	float wgNO = imageLoad(waveguides, ivec3(coord,5)).r;
	float wgL = imageLoad(waveguides, ivec3(coord,6)).r;

	float Vj = (2*(wgN + wgE + wgS + wgO + wgSE + wgNO + slfac*wgL)+ imp)/(6+slfac) ;

	//float Vj = (2*(wgN + wgE + wgS + wgO) + drop*strength*atfac)*0.25;
	Vj *= imageLoad(shape_buffer,coord).r*loss;
	
	Vj = Vj*(1+a) - a*info.r;
	
	imageStore(waveguides1,ivec3(coord + dy,2), vec4(Vj - wgN)*dampii);
	imageStore(waveguides1,ivec3(coord + dx,3), vec4(Vj - wgE)*dampii);
	imageStore(waveguides1,ivec3(coord - dy,0), vec4(Vj - wgS)*dampii);
	imageStore(waveguides1,ivec3(coord - dx,1), vec4(Vj - wgO)*dampii);
	imageStore(waveguides1,ivec3(coord + dx - dy,5), vec4(Vj - wgSE)*dampii);
	imageStore(waveguides1,ivec3(coord - dx + dy,4), vec4(Vj - wgNO)*dampii);
	imageStore(waveguides1,ivec3(coord,6), vec4(Vj - wgL)*dampii);
	
	//vec4 info;
	info.b = ix;
	info.a = iy;
	info.r = Vj;
	info.g = dampi;
    imageStore(Xout, coord, info);
	if(ix==micro.x && iy==micro.y)
		imageStore(audio_buffer,slot,info*10);
}

]]

local add_drop_fs = [[
#version 430 compatibility
const float PI = 3.141592653589793;
const ivec2 dx = ivec2(1.0, 0.0);
const ivec2 dy = ivec2(0.0, 1.0);

uniform float loss;
uniform float a;
uniform float slfac;
uniform vec2 center = vec2(30,30);
uniform ivec2 micro;
uniform float radius = 10;
uniform float strength = 0.2;
uniform float atfac;
uniform float damp;

layout (local_size_x = 32 ,local_size_y = 32) in;
layout (r32f, binding = 0) writeonly uniform imageBuffer audio_buffer;
layout (r32f, binding = 1) readonly uniform image2D shape_buffer;
layout (r32f, binding = 2) readonly uniform image2DArray waveguides;
layout (r32f, binding = 3) writeonly uniform image2DArray waveguides1;
layout (rgba32f, binding = 4) uniform image2D X;
layout (rgba32f, binding = 5) uniform image2D Xout;

uniform int slot;

float radiusinv = 5/radius;
void main() {

	float ix = int(gl_GlobalInvocationID.x);
	float iy = int(gl_GlobalInvocationID.y);
	ivec2 coord = ivec2(ix,iy);
	
	
	vec4 info = imageLoad(X, coord);// * imageLoad(shape_buffer,coord).r;
	
	float drop = max(0.0, 1.0 - length(center - coord) / radius);
    drop = (0.5 - cos(drop * PI) * 0.5)*radiusinv;
	float imp = drop*strength*atfac;
	//float imp = (1-0.9)*impi + 0.9*info.g;
	//float imp = impi + polec*(info.g -impi);
	float dampi = (1-0.99)*damp + 0.99*info.g;
	float dampii = 1- dampi;
	
	float wgN = imageLoad(waveguides, ivec3(coord,0)).r;
	float wgE = imageLoad(waveguides, ivec3(coord,1)).r;
	float wgS = imageLoad(waveguides, ivec3(coord,2)).r;
	float wgO = imageLoad(waveguides, ivec3(coord,3)).r;
	float wgL = imageLoad(waveguides, ivec3(coord,4)).r;

	float Vj = (2*(wgN + wgE + wgS + wgO + slfac*wgL)+ imp)/(4+slfac) ;

	Vj *= imageLoad(shape_buffer,coord).r*loss;//*(1-dampi);//*(1-imp);//dampen
	
	Vj = Vj*(1+a) - a*info.r;
	
	imageStore(waveguides1,ivec3(coord + dy,2), vec4(Vj - wgN)*dampii);
	imageStore(waveguides1,ivec3(coord + dx,3), vec4(Vj - wgE)*dampii);
	imageStore(waveguides1,ivec3(coord - dy,0), vec4(Vj - wgS)*dampii);
	imageStore(waveguides1,ivec3(coord - dx,1), vec4(Vj - wgO)*dampii);
	imageStore(waveguides1,ivec3(coord,4), vec4(Vj - wgL)*dampii);
	
	//vec4 info;
	info.b = ix;
	info.a = iy;
	info.r = Vj;
	info.g = dampi;
    imageStore(Xout, coord, info);
	if(ix==micro.x && iy==micro.y)
		imageStore(audio_buffer,slot,info);//*10);
}

]]

local function fillShape(texture_size_x, texture_size_y,shapevals)
	--fill shape
	local center = mat.vec2(math.floor(texture_size_x*0.5),math.floor(texture_size_y*0.5))
	local maxradio = math.floor(texture_size_x*0.5)-1
	local count = 0
	for i=0,texture_size_x-1 do 
	for j=0,texture_size_y-1 do	 
		
			local vec = mat.vec2(i,j) - center
			local dist = vec:norm()
			if dist <= maxradio then
			--if i>0 and i<numX-1 and j>0 and j<numY-1 then
				shapevals[count] = 1
			else
				shapevals[count] = 0
			end
			count = count + 1;
		end
	end
	local shape_image = image2D(texture_size_x, texture_size_y, "GL_RED", shapevals)
	local waveguides = {}
	waveguides[0] = image2DArray(texture_size_x, texture_size_y, 5, "GL_RED")
	waveguides[1] = image2DArray(texture_size_x, texture_size_y, 5, "GL_RED")
	return shape_image, waveguides
end

local function fillShapeHexa(texture_size_x, texture_size_y,shapevals)
	--fill shape
	--correction matrix
	local mm = mat.mat2(1,1/2,0,math.sqrt(3)/2)
	print(mm)
	print(mm*mat.vec2(0,1))
	local center = mat.vec2(math.floor(texture_size_x*0.5),math.floor(texture_size_y*0.5))
	local maxradio = math.floor(texture_size_x*0.5*math.sqrt(3)/2)-1
	local count = 0
	for i=0,texture_size_x-1 do 
	for j=0,texture_size_y-1 do	 
		
			local vec = mat.vec2(i,j) - center
			vec = mm*vec
			local dist = vec:norm()
			if dist <= maxradio then
				shapevals[count] = 1
			else
				shapevals[count] = 0
			end
			count = count + 1;
		end
	end
	local shape_image = image2D(texture_size_x, texture_size_y, "GL_RED", shapevals)
	local waveguides = {}
	waveguides[0] = image2DArray(texture_size_x, texture_size_y, 7, "GL_RED")
	waveguides[1] = image2DArray(texture_size_x, texture_size_y, 7, "GL_RED")
	return shape_image, waveguides
end
--------------------------------------------
function make(GL, nFrames,nREPS, SR ,NNX,ud,midi_in,reset_devices,Pa_stream)
	local buff = buff or ffi.new("float[?]",nFrames)

	local Physics = {currentTime = 0,readID=0,writeID=1}
	function Physics:swap_buffers()
		self.readID,self.writeID  = self.writeID,self.readID;
	end
	
local numX , numY= NNX,NNX 
local total_points = (numX+1)*(numY+1)

local X_pos = ffi.new("float[?][4]",total_points)
local shapevals = ffi.new("float[?]",total_points)
local tcoords = ffi.new("float[?][2]",total_points)
local numindices = numX*numY*2*3
local indices = ffi.new("GLuint[?]",numindices)
	Physics.numX = numX
	Physics.numY = numY
local do_add_drop = false
	function Physics.setdo_add_drop(val)
		do_add_drop = val
	end

local VARS = {}
VARS.center = ffi.new("float[2]",{0.6,0.5})
VARS.micro = ffi.new("float[2]",{0.6,0.5})
VARS.cpuload = 0
local NM = GL:Dialog("drum",
	{{"reset_devices",0,guitypes.button,function() reset_devices() end},
	{"beat_radio",5,guitypes.val,{min=1,max=100}},
	{"beat_strength",1,guitypes.val,{min=0,max=1}},
	{"slfac",0,guitypes.val,{min=0.0,max=20}},
	{"loss",1,guitypes.val,{min=0.9999,max=1,power=0.1,format="%.6f"}},
	{"a",0.06,guitypes.val,{min=0,max=1,power=0.1,format="%.6f"}},
	{"samplesdur",100,guitypes.valint,{min=1,max=200}},
	},function(this) 
		ig.Text("cpuload: %5.2f",VARS.cpuload)
		ig.ProgressBar(VARS.cpuload)
		if Pa_stream then
			ig.Text("Pa audioload")
			ig.ProgressBar(Pa_stream:GetStreamCpuLoad())
		end
		ig.Text("audioload: %5.2f",ud and ud.cpuload[0] or 0)
		ig.ProgressBar(ud.cpuload[0])
		ig.Text("ring buffer load:")
		ig.ProgressBar(((ud.Wpos - ud.Rpos)%ud.Size)/(ud.Size-1))
		local data = VARS.center --this.vars.center.data
		if ig.pad("gui drum pad",data,200,0,1) then
			do_add_drop= true 
		end
		local data2 = VARS.micro --this.vars.micro.data
		ig.SameLine()
		ig.pad("micro position",data2,200,0,1) 
		
	end)
	Physics.NM = NM

local texture_size_x,texture_size_y,add_drop_sh,add_drop_hexa_sh
local audio_buf,audio_tbo
local audio_bufptr
local persistent_audio = false
local shape_image
local waveguides
local memb_image

--local midi_in
function Physics:init(args)

	texture_size_x =  numX+1;
	texture_size_y =  numY+1;
	
	if args.hexa then
		add_drop_sh = GLSL:new():compile{comp=add_drop_hexa_fs}
		shape_image, waveguides = fillShapeHexa(texture_size_x, texture_size_y,shapevals)
	else
		add_drop_sh = GLSL:new():compile{comp=add_drop_fs}
		shape_image, waveguides = fillShape(texture_size_x, texture_size_y,shapevals)
	end
	
	--fill in positions
	--local center = vector(math.floor(texture_size_x*0.25),math.floor(texture_size_x*0.25))
	local count = 0
	for j=0,numY do	 
		for i=0,numX do 
			local val = 0
			
			X_pos[count] = {val,0,0,0}
			
			tcoords[count][0] = i/numX
			tcoords[count][1] = j/numY
			--print(count,i,j,tcoords[count][1],tcoords[count][2])
			count = count + 1;
		end
	end
	
	--fill in indices
	local id=indices;
	for i = 0,numY-1 do        
		for j = 0,numX-1 do          
			local i0 = i * (numX+1) + j;            
			local i1 = i0 + 1;            
			local i2 = i0 + (numX+1);            
			local i3 = i2 + 1;            
			if ((j+i)%2 == 1) then               
				id[0] = i0; id[1] = i2; id[2] = i1;                
				id[3] = i1; id[4] = i2; id[5] = i3; 
				id = id + 6
			else
				id[0] = i0; id[1] = i2; id[2] = i3;                
				id[3] = i0; id[4] = i3; id[5] = i1; 
				id = id + 6          
			end       
		end   
	end
	
	memb_image = {}
	memb_image[0] = image2D(texture_size_x, texture_size_y, "GL_RGBA", X_pos)
	memb_image[1] = image2D(texture_size_x, texture_size_y, "GL_RGBA", X_pos)
	
	audio_buf = VBOk()
	if persistent_audio then
		audio_buf:BufferStorage(nil,glc.GL_MAP_PERSISTENT_BIT+glc.GL_MAP_READ_BIT+glc.GL_MAP_COHERENT_BIT,nFrames*ffi.sizeof"float")
		audio_bufptr = glext.glMapBufferRange(audio_buf.kind,0,nFrames*ffi.sizeof"float",glc.GL_MAP_PERSISTENT_BIT+glc.GL_MAP_READ_BIT+glc.GL_MAP_COHERENT_BIT);
	else
		audio_buf:BufferData(nil,nil,nFrames*ffi.sizeof"float")
	end
	audio_tbo = audio_buf:buffer_texture(glc.GL_R32F)

	if args.record then
		self.soundf = sndf.Sndfile(args.record,"w",44100,1,sndf.SF_FORMAT_WAV+sndf.SF_FORMAT_FLOAT) 
	end
end

local function GPUwait ()
	local syncObject = glext.glFenceSync(glc.GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
	local ret = glext.glClientWaitSync(syncObject, glc.GL_SYNC_FLUSH_COMMANDS_BIT, 1000*1000*1000);
	if (ret == glc.GL_WAIT_FAILED or ret == glc.GL_TIMEOUT_EXPIRED) then
		print("glClientWaitSync failed./n");
	end
	--glext.glMemoryBarrier(glc.GL_ALL_BARRIER_BITS);
	glext.glDeleteSync(syncObject);
end
local lastsamp = 0
local fulltime = nFrames/SR
local lp_time = require"luapower.time"
local secs_now =lp_time.clock
function Physics:draw(tim,w,h,args)
	for i=1,nREPS do
		local begintime = secs_now()
		local cc = self:update(nFrames)
		local endtime = secs_now()
		VARS.cpuload = (endtime-begintime)/fulltime
		 -- glext.glFenceSync(glc.GL_SYNC_GPU_COMMANDS_COMPLETE,0)
		 -- gl.glFinish()
		  --gl.glFlush()
		  --glext.glMemoryBarrier(glc.GL_CLIENT_MAPPED_BUFFER_BARRIER_BIT)
		  --glext.glMemoryBarrier(glc.GL_BUFFER_UPDATE_BARRIER_BIT)
		if persistent_audio then
			GPUwait()
			ffi.copy(buff,ffi.cast("float*",audio_bufptr),nFrames*ffi.sizeof"float")
		else
			audio_buf:Bind()
			audio_buf:MapR(function(ptr)
				local pos = ffi.cast("float*",ptr)
				ffi.copy(buff,pos,nFrames*ffi.sizeof"float")
			end)
		end
		if self.soundf then self.soundf:writef_float(buff,nFrames) end
		if ud then ud:write(buff) end
	end
end


----------- checkmidi
local msg = ffi.new("unsigned char[?]",256)
local size = ffi.new("size_t[1]")
local setatfac = false
local lastret = 0
local sample = 0
local place = 0.5
local damp = 0
local max = math.max
local MIDI_CODE_MASK = 0xf0
local MIDI_CHN_MASK  = 0x0f
local function checkmidi(U)
	size[0] = 255
	local stamp = midi_in:in_get_message(msg, size)
	if midi_in.ok == false then error(ffi.string(midi_in.msg)) end
	if size[0] > 0 then
		local code = bit.band(MIDI_CODE_MASK,msg[0])
		if code == 144 then --noteon
			setatfac = true
			lastret = msg[2]/127
			sample = NM.samplesdur
			place = ((msg[1]-60)%24)/23
			VARS.center[0] = place
			U.center:set{VARS.center[0]*texture_size_x,VARS.center[1]*texture_size_y}
			--print("note on",lastret)
			--return lastret*lastret,place,damp
		--elseif code == 128 then --noteoff
			--print"note off"
			--lastret = 0
			--return 0,0.09
		elseif code == 176 then --pedal or wheel
			if msg[1] == 64 then --pedal
				damp = msg[2]==127 and 1 or 0
				U.damp:set{damp}
			elseif msg[1] == 1 then
				--NM.vars.slfac[0] = 10*msg[2]/127
				NM.vars.beat_radio[0] = 3 + 97*msg[2]/127
			end
		end
	end
	if setatfac then 
		lastret = lastret*sample/NM.samplesdur
		sample = max(0,sample-1)
		U.atfac:set{lastret*lastret} 
		if sample == 0 then setatfac = false end
	end
end
local function checkpad(U)
	if do_add_drop then
		setatfac = true
		lastret = 1
		sample = NM.samplesdur
		place = VARS.center[0] --NM.center[0]
		U.center:set{VARS.center[0]*texture_size_x,VARS.center[1]*texture_size_y}
		do_add_drop = false
	end
	if setatfac then
		lastret = lastret*sample/NM.samplesdur
		sample = max(0,sample-1)
		U.atfac:set{lastret*lastret} 
		if sample == 0 then setatfac = false end
	end
end
local checkbeat
if midi_in then
	checkbeat = checkmidi
else
	checkbeat = checkpad
end
function Physics:update(NUM_ITER)

		local slot = 0

		audio_tbo:BindI(0,glc.GL_WRITE_ONLY)
		add_drop_sh:use()
		shape_image:Bind(1,glc.GL_READ_ONLY)
		local U = add_drop_sh.unif
		U.micro:set{VARS.micro[0]*texture_size_x,VARS.micro[1]*texture_size_y}
		U.center:set{VARS.center[0]*texture_size_x,VARS.center[1]*texture_size_y}
		U.strength:set{NM.beat_strength}
		U.radius:set{NM.beat_radio}
		U.loss:set{NM.loss}
		U.a:set{-NM.a}
		U.slfac:set{NM.slfac}
		U.damp:set{damp}
		for j=1,NUM_ITER do

			checkbeat(U)

			memb_image[self.readID]:Bind(4,glc.GL_READ_ONLY)
			memb_image[self.writeID]:Bind(5,glc.GL_WRITE_ONLY)
			waveguides[self.readID]:Bind(2)
			waveguides[self.writeID]:Bind(3)

			U.slot:set{slot}
			slot = slot + 1
			--glext.glDispatchCompute(8,8, 1);
			glext.glDispatchCompute(4,4, 1);
			glext.glMemoryBarrier(glc.GL_SHADER_IMAGE_ACCESS_BARRIER_BIT)--+glc.GL_CLIENT_MAPPED_BUFFER_BARRIER_BIT*0);
			self:swap_buffers()
		end
end

function Physics:close()
	if self.soundf then self.soundf:close() end
	if midi_in then midi_in:close_port(); midi_in:free() end
	if ud then ud.abort = true end
	self.NM:close()
end


	return Physics
end

return make