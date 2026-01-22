require"anima"


local reducer_min = [[
 #version 430
            const float infinity = 1. / 0.;

            layout(local_size_x = ${workersX}, local_size_y = 1) in;
            
            uniform int computeWidth;
            uniform int recursionStep;
            
            layout (std430, binding = 0) buffer buffValues
            {
                vec4 values[];
            };
            
            shared vec4[${workersX}] localBuff;
            
            vec4 reduction(vec4[${workersX}] arr){
            // Compute minimum;
                vec4 m = arr[0];
                for (int i=0; i < arr.length(); i++){
                    if (arr[i].x < m.x){
                        m = arr[i];
                    }
                }
                return m;
            }
            
            void main(){
                  const int id = int(gl_LocalInvocationID.x);
                  const int k = int(gl_WorkGroupID.x);
                  
                  int stride = int(pow(${workersX}, recursionStep));
                  int globalId = (id + k * ${workersX}) * stride;
				  
				
				if (globalId < computeWidth) {
					localBuff[id] = values[globalId];
				}else{
					localBuff[id] = vec4(infinity,1,1,1);
				}
				
                  barrier(); // Forces threads in the SAME group to be in sync;
                  
                  vec4 minimum = reduction(localBuff); // Compute  minimum (or the reduction implemented);
                  
                  // Writes on the local index thread;
                  if (id == 0){
                    values[k * ${workersX} * stride] = minimum;
                   }  
            }
]]

local reducer_max = [[
 #version 430
            const float infinity = 1. / 0.;

            layout(local_size_x = ${workersX}, local_size_y = 1) in;
            
            uniform int computeWidth;
            uniform int recursionStep;
            
            //layout (std430, binding = 0) buffer buffValues
			layout ( binding = 0) buffer buffValues
            {
                vec4 values[];
            };
            
            shared vec4[${workersX}] localBuff;
            
            vec4 reduction(vec4[${workersX}] arr){
            // Compute maximum;
                vec4 m = arr[0];
                for (int i=0; i < arr.length(); i++){
                    if (arr[i].x > m.x){
                        m = arr[i];
                    }
                }
                return m;
            }
            
            void main(){
                  const int id = int(gl_LocalInvocationID.x);
                  const int k = int(gl_WorkGroupID.x);
                  
                  int stride = int(pow(${workersX}, recursionStep));
                  int globalId = (id + k * ${workersX}) * stride;
				  
				
				if (globalId < computeWidth) {
					localBuff[id] = values[globalId];
				}else{
					localBuff[id] = vec4(-infinity,1,1,1);
				}
				
                  barrier(); // Forces threads in the SAME group to be in sync;
				  //memoryBarrier();
                  
                  vec4 maximum = reduction(localBuff); // Compute  maximum (or the reduction implemented);
                  
                  // Writes on the local index thread;
                  if (id == 0){
                    values[k * ${workersX} * stride] = maximum;
                   }  
            }
]]

require"anima"


local log = math.log
local function Log(a,x)
	return log(x)/log(a)
end

--gives pot so that: SIZE <= DW^pot
local function PotForSize(DW,SIZE)
	return math.ceil(Log(DW,SIZE))
end


local function GPUwait () --GL_SYNC_GPU_COMMANDS_COMPLETE,
	local syncObject = glext.glFenceSync(glc.GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
	local ret = glext.glClientWaitSync(syncObject, glc.GL_SYNC_FLUSH_COMMANDS_BIT, 1000*1000*1000);
	if (ret == glc.GL_WAIT_FAILED or ret == glc.GL_TIMEOUT_EXPIRED) then
		print("glClientWaitSync failed./n");
	end
	--glext.glMemoryBarrier(glc.GL_ALL_BARRIER_BITS);
	glext.glDeleteSync(syncObject);
end

local function bufInfo(buf)
	local ww = ffi.new( "GLint64[1]")
	local infos = {
"GL_BUFFER_ACCESS",
"GL_BUFFER_ACCESS_FLAGS",
"GL_BUFFER_IMMUTABLE_STORAGE",
"GL_BUFFER_MAPPED",
"GL_BUFFER_MAP_LENGTH",
"GL_BUFFER_MAP_OFFSET",
"GL_BUFFER_SIZE",
"GL_BUFFER_STORAGE_FLAGS",
"GL_BUFFER_USAGE"}
	print("Buffer Info-------------------")
	buf:Bind()
	for i,v in ipairs(infos) do
		glext.glGetBufferParameteri64v(buf.kind, glc[v], ww)
		print(v,ww[0])
	end
end

local function reducer(GL, SIZE, kind)
	local M = {}
	local workersX = 32
	local pot = PotForSize(workersX, SIZE)
	local data = ffi.new("float[?]",4)
	M.buf = VBOk(glc.GL_PIXEL_PACK_BUFFER)
	local inited
	local function initProg()
		local code = kind=="max" and reducer_max or reducer_min
		local shader = code:gsub("%${workersX}",tostring(workersX))
		M.computeReduce = GLSL:new():compile{comp=shader}
	end
	local function initVBO()
		if M.buf then M.buf:delete() end
		M.buf = VBOk(glc.GL_PIXEL_PACK_BUFFER)
		--bufInfo(M.buf)
		--M.buf:BufferStorage(ffi.cast("void*",0), glc.GL_MAP_READ_BIT, 4*ffi.sizeof"float"*SIZE)
		M.buf:BufferStorage(nil, glc.GL_MAP_PERSISTENT_BIT+glc.GL_MAP_READ_BIT+glc.GL_MAP_COHERENT_BIT, 4*ffi.sizeof"float"*SIZE)
		M.bufptr = glext.glMapBufferRange(M.buf.kind, 0, SIZE*4*ffi.sizeof"float", glc.GL_MAP_PERSISTENT_BIT+glc.GL_MAP_READ_BIT+glc.GL_MAP_COHERENT_BIT)
	end
	function M.init()
		print"--------------glsl_reduce init"
		initProg()
		initVBO()
		inited = true
		print"--------------glsl_reduce init end"
	end
	function M:setWorkers(DW)
		workersX, pot = CalcWorkers3(SIZE, DW)
		initProg()
		initVBO()
	end
	function M:setWorkersPot(DW, po)
		workersX, pot = DW, po
		initProg()
		initVBO()
	end
	function M:reduce(fbo, offX, offY, W, H, doget)
		--print( "M:reduce(",fbo, offX, offY, W, H, doget)
		if doget==nil then doget=true end
		if not inited then self.init() end
		if W*H ~= SIZE then
			print("RESIZE--------------------------",W*H)
			SIZE = W*H
			pot = PotForSize(workersX, SIZE)
			initProg()
			initVBO()
		end
		--read fbo
		M.buf:Bind()
		
		-- local vv = ffi.new("GLint64[1]")
		-- glext.glGetInteger64v(glc.GL_PIXEL_PACK_BUFFER_BINDING, vv)
		-- print("GL_PIXEL_PACK_BUFFER_BINDING",vv[0],glc.GL_PIXEL_PACK_BUFFER)
		
		--M.buf:BufferStorage(ffi.cast("void*",0), nil, 4*ffi.sizeof"float"*SIZE)
		--M.buf:BufferStorage(nil, glc.GL_MAP_PERSISTENT_BIT+glc.GL_MAP_READ_BIT+glc.GL_MAP_COHERENT_BIT, 4*ffi.sizeof"float"*SIZE)
		--M.buf:BufferStorage(nil, glc.GL_MAP_PERSISTENT_BIT+glc.GL_MAP_READ_BIT+glc.GL_MAP_COHERENT_BIT, 4*ffi.sizeof"float"*SIZE)
		--M.buf:BufferData(ffi.cast("void*",0), nil, 4*ffi.sizeof"float"*SIZE)
		
		local oldfbo = fbo:BindRead()
		gl.glReadBuffer(glc.GL_COLOR_ATTACHMENT0 + 0);
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(offX, offY, W, H, glc.GL_RGBA, glc.GL_FLOAT, ffi.cast("void*",0))
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER, oldfbo);
		--M.buf:UnBind()
		--compute reduce
		---[[
		M.computeReduce:use()
		M.buf:Bind(glc.GL_SHADER_STORAGE_BUFFER)
		M.buf:BindBufferBase(0, glc.GL_SHADER_STORAGE_BUFFER)
		--iters
		local n = workersX ^ pot
		local numSteps = n / workersX
        local dispatchNum = numSteps
        local s = 0
		
		-----------------------------
		while(dispatchNum >= 1) do
			--print("-----------compute step",s, "dispatchNum",dispatchNum,SIZE)
			
            M.computeReduce.unif.recursionStep:set{s}
            M.computeReduce.unif.computeWidth:set{ SIZE}
			glext.glDispatchCompute(dispatchNum, 1, 1);
			
			dispatchNum = dispatchNum/ workersX
            s = s + 1
        end
		--]]
		--[[
		if doget then
		M.buf:MapR(function(ptr)
				local pos = ffi.cast("float*",ptr)
				ffi.copy(data,pos,4*ffi.sizeof"float")
			end)
		end
		--]]
		--[[
		if doget then
			glext.glGetBufferSubData(glc.GL_SHADER_STORAGE_BUFFER, 0, 4*ffi.sizeof"float", data)
		end
		--]]
		--glext.glFlushMappedBufferRange(glc.GL_SHADER_STORAGE_BUFFER, 0,  4*ffi.sizeof"float")
		---[[
		if doget then
			GPUwait()
			--gl.glFlush()
			ffi.copy(data, ffi.cast("float*", M.bufptr), 4*ffi.sizeof"float")
		end
		--]]
		M.buf:UnBind()
		return data[0],data[1],data[2],data[3]
	end
	function M:get_Workers()
		return workersX, pot
	end
	--GL:add_plugin(M)
	return M
end
------------------------------------

---[=[
if not ... then
require"anima"
-------------------------- CPU calc
local vicim = require"anima.vicimag"
local function CPUmax(fbo,offX, offY, W, H)

	local maxprio = -math.huge
	local maxind = -1
	
	local prios = {}
	
	-- local priopd = vicim.tex2pd(prio_fbo:tex())
	local subdata = fbo:get_pixels(glc.GL_RGBA,glc.GL_FLOAT,0,nil, offX, offY, W, H)
	local priopd = vicim.pixel_data(subdata, W, H, 4)

	for np=0,priopd.npix-1 do
		local pix = priopd:lpix(np)
		--if pix[2] > 0 then
			--assert(pix[1]>0)
		--if pix[1] > 0 then
			if pix[0] > maxprio then
				maxprio = pix[0]
				local i,j = priopd:lpixTOij(np)
				prios[#prios+1] = {i=i+offX,j=j+offY,prio=maxprio,i2=pix[1],j2=pix[2]}
				maxind = #prios
			end
		--end
	end
	local ptt = prios[maxind]
	--print("calcPriorityGPU", maxind, ptt and ptt.prio, ptt and ptt.i, ptt and ptt.j)

	return prios[maxind]
end
-----------------------
local pointX, pointY = 15,0
local vert_sh=[[
in vec3 position;
void main(){
	gl_Position = vec4(position,1); 
}
]]

local frag_sh= [[

void main(){
	
	vec2 pos = gl_FragCoord.xy;
	
	float val = (abs(int(pos.x)-50) + abs(int(pos.y)-40 ))/(300.0+300.0);
///*
	if (ivec2(pos)==ivec2(]]..pointX..[[,]]..pointY..[[)){
		val = 0.0;
	}else{
		val = 0.5;
	}
//*/
	val = 1.0 - val;
	gl_FragColor = vec4(vec3(val,int(pos.x),int(pos.y)),1);
}
]]


-- for i=2,128 do
	-- print(i,PotForSize(i,290*290))
-- end
-- do return end

local offX, offY = 0,0 --10,10 --40,30 --10,10
local test_sideX, test_sideY = 200,200
local test_size = test_sideX*test_sideY
local try_workers = {}
-- for i=2,64 do
for i=15,15 do
	--local DW,pot = CalcWorkers3(290*290, i)
	local DW, pot = i, PotForSize(i,test_size)
	--GL_MAX_COMPUTE_WORK_GROUP_COUNT = 65535
	if DW and (DW ^ (pot - 1)) <= 65535 then
		table.insert(try_workers, {DW=DW,pot=pot,N=DW^pot,SIZE=test_size})
	else
		print("DW Fail:",DW)
	end
end

--do return end
local GL = GLcanvas{H=300,aspect=1,DEBUG=true}
local prog, fbo, prog_vao
local buf
local BadDW = {}
function GL.init()
	fbo = GL:initFBO{no_depth = true}
	prog = GLSL:new():compile{vert=vert_sh,frag = frag_sh}
	prog_vao = mesh.quad():vao(prog)
	
	fbo:Bind()
	fbo:viewport()
	ut.Clear()
	prog_vao:draw_elm()
	fbo:UnBind()
	
	local reduc = reducer(GL, test_size, "max")
	reduc:reduce(fbo,offX,offY,test_sideX, test_sideY,true)
	-- reduc:reduce(fbo,offX,offY,100,100,true)
	
	---[[
	for i,v in ipairs(try_workers) do
		print("set workers",v.DW)
		reduc:setWorkersPot(v.DW, v.pot)
		local val, x, y = reduc:reduce(fbo,offX,offY,test_sideX,test_sideY,true)
		print("--------------done redux",val,x,y, reduc:get_Workers())
		v.res = {val,x,y}
		if x == pointX and y == pointY then
			v.good = true
		else
			table.insert(BadDW, v)
			v.good = false
		end
		local maxCPU = CPUmax(fbo, offX,offY,test_sideX,test_sideY)
		if maxCPU then
		print("---------maxCPU", maxCPU.prio, maxCPU.i, maxCPU.j, maxCPU.i2, maxCPU.j2)
		else
		print("---------maxCPU nil")
		end
	end
	--]]
end

function GL.draw(t, w, h)
	ut.Clear()
	--fbo:tex():drawcenter()
	fbo:tex():togrey(nil, nil, {1,0,0,0})
end

GL:start()

--prtable("-------------------------------------",try_workers)
prtable("-------------------------------------",BadDW)
end
--]=]

return reducer