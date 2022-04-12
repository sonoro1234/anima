local PARTICLE_GROUP_SIZE     = 1024 --128 --1024
local PARTICLE_GROUP_COUNT    = 128 --1024 --320 --8192
local PARTICLE_COUNT          = (PARTICLE_GROUP_SIZE * PARTICLE_GROUP_COUNT)
local MAX_ATTRACTORS          = 4

local render_vs =
        [[#version 430 core
        in vec4 vert;
        uniform mat4 mvp;
        out float intensity;
        void main(void)
        {
            intensity = vert.w;
            gl_Position = mvp * vec4(vert.xyz, 1.0);
        }]]

local render_fs =
        [[#version 430 core
        layout (location = 0) out vec4 color;
        in float intensity;
		uniform float value;
        void main(void)
        {
            vec4 color1 = mix(vec4(0.0f, 0.2f, 1.0f, 1.0f), vec4(0.2f, 0.05f, 0.0f, 1.0f), intensity);
			color = pow(color1,vec4(value));
			//color = vec4(1);
        }]]
local render_fsAtt =
        [[#version 430 core
        layout (location = 0) out vec4 color;
        in float intensity;
        void main(void)
        {
            //color = mix(vec4(0.0f, 0.2f, 1.0f, 1.0f), vec4(0.2f, 0.05f, 0.0f, 1.0f), intensity);
			color = vec4(1,0,0,1);
        }]]


local compute_sh = [[#version 430 core
// Uniform block containing positions and masses of the attractors
layout (std140, binding = 0) uniform attractor_block {
	vec4 attractor[64]; // xyz = position, w = mass
};
// Process particles in blocks of PARTICLE_GROUP_SIZE
//layout (local_size_x = 128) in;
layout (local_size_x = ]]..PARTICLE_GROUP_SIZE..[[) in;
// Buffers containing the positions and velocities of the particles
layout (rgba32f, binding = 0) uniform imageBuffer velocity_buffer;
layout (rgba32f, binding = 1) uniform imageBuffer position_buffer;

// Delta time
uniform float dt;
void main(void)
{
	// Read the current position and velocity from the buffers
	vec4 vel = imageLoad(velocity_buffer, int(gl_GlobalInvocationID.x));
	vec4 pos = imageLoad(position_buffer, int(gl_GlobalInvocationID.x));
	int i;
	// Update position using current velocity * time
	pos.xyz += vel.xyz * dt;
	// Update "life" of particle in w component
	pos.w -= 0.0001 * dt;
	// For each attractor...
	for (i = 0; i < ]]..MAX_ATTRACTORS..[[; i++)
	{
		// Calculate force and update velocity accordingly
		vec3 dist = (attractor[i].xyz - pos.xyz);
		vel.xyz += dt * dt * attractor[i].w * normalize(dist) / (dot(dist, dist) + 1.0);
		//vel.xyz += attractor[i].w * normalize(dist) / (dot(dist, dist) + 1.0);
	}
	// If the particle expires, reset it
	if (pos.w <= 0.0)
	{
		//pos.xyz = -pos.xyz * 0.01;
		vel.xyz *= 0.01;
		pos.w += 1.0f;
	}
	// Store the new position and velocity back into the buffers
	imageStore(position_buffer, int(gl_GlobalInvocationID.x), pos);
	imageStore(velocity_buffer, int(gl_GlobalInvocationID.x), vel);
}]]

require"anima"

local GL = GLcanvas{fps=250,vsync=false,H=900, aspect=1,DEBUG=false}

local NM = GL:Dialog("vals",
{
{"delta_t",0,guitypes.drag},
{"value",1,guitypes.drag}})

local cpt_prog, render_prog, render_progAtt

local pos_buf, vel_buf
local pos_tbo, vel_tbo
local render_vao
local attractors
local attractors_mass = ffi.new("float[?]",MAX_ATTRACTORS)
local camera, render_vao2
local random = math.random
local function randomvec(minv,maxv)
	local vec = mat.vec3(random()*2-1,random()*2-1,random()*2-1)
	vec = vec:normalize()
	return vec*(minv + random()*(maxv-minv))
end



local vec4 = mat.vec4
function GL.init()
	--ProfileStart()
	camera = Camera(GL,{gizmo=true,type="tps"})
	camera.NM.vars.dist[0]= 80
	render_prog = GLSL:new():compile(render_vs,render_fs)
	render_progAtt = GLSL:new():compile(render_vs,render_fsAtt)
	cpt_prog = GLSL:new():compile{comp = compute_sh}

	---[[
	pos_buf = VBOk()
	pos_buf:BufferData(nil,glc.GL_DYNAMIC_COPY,PARTICLE_COUNT*ffi.sizeof"float"*4)
	pos_buf:MapW(function(ptr) 
		print(ptr)
		local pos = ffi.cast("float*",ptr)
		for i=0,PARTICLE_COUNT-1 do
			local aa = vec4(randomvec(-10,10),random()):gl()
			--print("xxxxxxxx",aa[0],aa[1],aa[2],aa[3])
			pos[i*4],pos[i*4+1],pos[i*4+2],pos[i*4+3] = aa[0],aa[1],aa[2],aa[3]--0.1,0,0,0.5--aa[0],aa[1],aa[2],aa[3]
		end
	end)
	--]]
	
	--render_vao = VAO({vert=pos},render_prog)
	--render_vao = VAO({vert={0,0,10,1, 10,0,0,1, 0,10,0,1}},render_prog)
	render_vao = VAO({vert=pos_buf},render_prog)
	pos_tbo = pos_buf:buffer_texture(glc.GL_RGBA32F)
	--pos_tbo = render_vao:vbo("vert"):buffer_texture(glc.GL_RGBA32F)
	
	vel_buf = VBOk()
	vel_buf:BufferData(nil,glc.GL_DYNAMIC_COPY,PARTICLE_COUNT*ffi.sizeof"float"*4)
	vel_buf:MapW(function(ptr) 
		local vel = ffi.cast("float*",ptr)
		for i=0,PARTICLE_COUNT-1 do
			local aa = vec4(randomvec(-0.1,0.1)*1,0):gl()
			vel[i*4],vel[i*4+1],vel[i*4+2],vel[i*4+3] = aa[0],aa[1],aa[2],aa[3]--0,0,0,0 --aa[0],aa[1],aa[2],aa[3]
		end
	end)
	
	vel_tbo = vel_buf:buffer_texture(glc.GL_RGBA32F)
	
	attractors = VBOk(glc.GL_UNIFORM_BUFFER)
	attractors:BufferData(nil, glc.GL_STATIC_DRAW, MAX_ATTRACTORS * ffi.sizeof("float[4]"))
	attractors:BindBufferBase(0);
	
	for i = 0,MAX_ATTRACTORS-1 do
        attractors_mass[i] = 0.6 + random() * 0.4;
    end
	
	render_vao2 = VAO({vert=attractors},render_progAtt)
	print"done init"
	--ProfileStop()
end
local sin, cos = math.sin, math.cos
local lastt = 0
function GL.draw(t,w,h)
	NM.vars.delta_t[0]=(t-lastt)*1
	lastt = t
	
	---[[
	local t1 = t*0.0001
	attractors:MapW(function(ptr) 
		local at = ffi.cast("float*",ptr)
		for i=0,MAX_ATTRACTORS-1 do
			at[i*4] = sin(t1 * (i + 4) * 7.5 * 20.0) * 1.0*5
			at[i*4+1] = cos(t1 * (i + 7) * 3.9 * 20.0) * 1.0*5
			at[i*4+2] = sin(t1 * (i + 3) * 5.3 * 20.0) * cos(t1 *(i + 5) * 9.1) * 2.0*5
			at[i*4+3] = attractors_mass[i]
		end
	end)
	
	if NM.delta_t > 0 then 
	cpt_prog:use()
	vel_tbo:BindI(0)
	pos_tbo:BindI(1)
	cpt_prog.unif.dt:set{NM.delta_t}
	
	glext.glDispatchCompute(PARTICLE_GROUP_COUNT, 1, 1);

    glext.glMemoryBarrier(glc.GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
	end
	--]]
	--local mvp = mat.perspective(45.0, w/h, 0.1, 1000.0) * mat.translate(0.0, 0.0, -50.0) * mat.rotate_axis(t * 1, mat.vec3(0.0, 1.0, 0.0));
	local mvp = camera:MVP()
    -- Clear, select the rendering program and draw a full screen quad
   ut.Clear()
   gl.glViewport(0, 0, w, h);
    gl.glDisable(glc.GL_DEPTH_TEST);
    render_prog:use()
	render_prog.unif.mvp:set(mvp.gl)
	render_prog.unif.value:set{NM.value}

    gl.glEnable(glc.GL_BLEND);
    gl.glBlendFunc(glc.GL_ONE, glc.GL_ONE);
    gl.glPointSize(1.0);
	render_vao:draw(glc.GL_POINTS)
	
	gl.glDisable(glc.GL_BLEND);
	render_progAtt:use()
	render_progAtt.unif.mvp:set(mvp.gl)
	 gl.glPointSize(6.0);
	render_vao2:draw(glc.GL_POINTS)
end

GL:start()