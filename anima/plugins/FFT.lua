--From
--#Fourier Image Filtering
--[http://david.li/filtering](http://david.li/filtering)
--

local 	PING_TEXTURE_UNIT = 0
local    PONG_TEXTURE_UNIT = 1
local    FILTER_TEXTURE_UNIT = 2
local    ORIGINAL_SPECTRUM_TEXTURE_UNIT = 3
local    FILTERED_SPECTRUM_TEXTURE_UNIT = 4
local    IMAGE_TEXTURE_UNIT = 5
local    FILTERED_IMAGE_TEXTURE_UNIT = 6
local    READOUT_TEXTURE_UNIT = 7



local FORWARD = 0
local INVERSE = 1;


local FULLSCREEN_VERTEX_SOURCE = [[
    in vec2 a_position;
    out vec2 v_coordinates; //this might be phased out soon (no pun intended)
    void main (void) {
        v_coordinates = a_position * 0.5 + 0.5;
        gl_Position = vec4(a_position, 0.0, 1.0);
    }
]]

local SUBTRANSFORM_FRAGMENT_SOURCE = [[
    //precision highp float;

    const float PI = 3.14159265;

    uniform sampler2D u_input;

    uniform float u_resolution;
    uniform float u_subtransformSize;

    uniform bool u_horizontal;
    uniform bool u_forward;
    uniform bool u_normalize;

    vec2 multiplyComplex (vec2 a, vec2 b) {
        return vec2(a[0] * b[0] - a[1] * b[1], a[1] * b[0] + a[0] * b[1]);
    }

    void main (void) {

        float index = 0.0;
        if (u_horizontal) {
            index = gl_FragCoord.x - 0.5;
        } else {
            index = gl_FragCoord.y - 0.5;
        }

        float evenIndex = floor(index / u_subtransformSize) * (u_subtransformSize / 2.0) + mod(index, u_subtransformSize / 2.0);
        
        vec4 even = vec4(0.0), odd = vec4(0.0);

        if (u_horizontal) {
            even = texture2D(u_input, vec2(evenIndex + 0.5, gl_FragCoord.y) / u_resolution);
            odd = texture2D(u_input, vec2(evenIndex + u_resolution * 0.5 + 0.5, gl_FragCoord.y) / u_resolution);
        } else {
            even = texture2D(u_input, vec2(gl_FragCoord.x, evenIndex + 0.5) / u_resolution);
            odd = texture2D(u_input, vec2(gl_FragCoord.x, evenIndex + u_resolution * 0.5 + 0.5) / u_resolution);
        }

        //normalisation
        if (u_normalize) {
            even /= u_resolution * u_resolution;
            odd /= u_resolution * u_resolution;
        }

        float twiddleArgument = 0.0;
        if (u_forward) {
            twiddleArgument = 2.0 * PI * (index / u_subtransformSize);
        } else {
            twiddleArgument = -2.0 * PI * (index / u_subtransformSize);
        }
        vec2 twiddle = vec2(cos(twiddleArgument), sin(twiddleArgument));

        vec2 outputA = even.rg + multiplyComplex(twiddle, odd.rg);
        vec2 outputB = even.ba + multiplyComplex(twiddle, odd.ba);

        gl_FragColor = vec4(outputA, outputB);
		//if(!u_forward)
		//	gl_FragColor = vec4(1,0,0,1);
    }
]]

local FILTER_FRAGMENT_SOURCE = [[
    //precision highp float;

    uniform sampler2D u_input;
    uniform float u_resolution;

    uniform float u_maxEditFrequency;

    uniform sampler2D u_filter;

    void main (void) {
        vec2 coordinates = gl_FragCoord.xy - 0.5;
        float xFrequency = (coordinates.x < u_resolution * 0.5) ? coordinates.x : coordinates.x - u_resolution;
        float yFrequency = (coordinates.y < u_resolution * 0.5) ? coordinates.y : coordinates.y - u_resolution;

        float frequency = sqrt(xFrequency * xFrequency + yFrequency * yFrequency);

        float gain = texture2D(u_filter, vec2(frequency / u_maxEditFrequency, 0.5)).r*2.0;
        vec4 originalPower = texture2D(u_input, gl_FragCoord.xy / u_resolution);

        gl_FragColor = originalPower * gain;

    }
]]

local POWER_FRAGMENT_SOURCE = [[
    //precision highp float;

    in vec2 v_coordinates;

    uniform sampler2D u_spectrum;
    uniform float u_resolution;

    vec2 multiplyByI (vec2 z) {
        return vec2(-z[1], z[0]);
    }

    vec2 conjugate (vec2 z) {
        return vec2(z[0], -z[1]);
    }

    vec4 encodeFloat (float v) { //hack because WebGL cannot read back floats
        vec4 enc = vec4(1.0, 255.0, 65025.0, 160581375.0) * v;
        enc = fract(enc);
        enc -= enc.yzww * vec4(1.0 / 255.0, 1.0 / 255.0, 1.0 / 255.0, 0.0);
        return enc;
    }

    void main (void) {
        vec2 coordinates = v_coordinates - 0.5;

        vec4 z = texture2D(u_spectrum, coordinates);
        vec4 zStar = texture2D(u_spectrum, 1.0 - coordinates + 1.0 / u_resolution);
        zStar = vec4(conjugate(zStar.xy), conjugate(zStar.zw));

        vec2 r = 0.5 * (z.xy + zStar.xy);
        vec2 g = -0.5 * multiplyByI(z.xy - zStar.xy);
        vec2 b = z.zw;

        float rPower = length(r);
        float gPower = length(g);
        float bPower = length(b);

        float averagePower = (rPower + gPower + bPower) / 3.0;
        //gl_FragColor = encodeFloat(averagePower / (u_resolution * u_resolution));
		gl_FragColor = vec4(averagePower / (u_resolution * u_resolution));
    }
]]

local IMAGE_FRAGMENT_SOURCE = [[
    //precision highp float;

    in vec2 v_coordinates;

    //uniform float u_resolution;

    uniform sampler2D u_texture;
    //uniform sampler2D u_spectrum;

    void main (void) {
        vec3 image = texture2D(u_texture, v_coordinates).rgb;

        gl_FragColor = vec4(image, 1.0);
    }
]]

local function buildFramebuffer( attachment)
	local fb = ffi.new("GLuint[1]")
	glext.glGenFramebuffers(1, fb);
    local framebuffer = fb[0] --gl.createFramebuffer();
    glext.glBindFramebuffer(glc.GL_FRAMEBUFFER, framebuffer);
    glext.glFramebufferTexture2D(glc.GL_FRAMEBUFFER, glc.GL_COLOR_ATTACHMENT0, glc.GL_TEXTURE_2D, attachment, 0);
    return framebuffer;
end

local function buildTexture( unit, format, type, width, height, data, wrapS, wrapT, minFilter, magFilter) 
	local format1 = glc.GL_RGBA32F
	local pTex = ffi.new("GLuint[?]",1)
	gl.glGenTextures(1,pTex) 
    local texture = pTex[0]
    glext.glActiveTexture(glc.GL_TEXTURE0 + unit);
    gl.glBindTexture(glc.GL_TEXTURE_2D, texture);
    gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, format1, width, height, 0, format, type, data);
    gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, wrapS);
    gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, wrapT);
    gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MIN_FILTER, minFilter);
    gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAG_FILTER, magFilter);
    return texture;
end

local texturebyunit = {}
local function bindtex(unit,tex, wrapS, wrapT, minFilter, magFilter)
	texturebyunit[unit] = tex
	glext.glActiveTexture(glc.GL_TEXTURE0 + unit);
	gl.glBindTexture(glc.GL_TEXTURE_2D, tex);
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, wrapS);
    gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, wrapT);
    gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MIN_FILTER, minFilter);
    gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAG_FILTER, magFilter);
end


local function Filterer(GL,args) 
	
	local FF = {}
	args = args or {}
	args.RES = args.RES or math.max(GL.W,GL.H)
	if args.power == nil then args.power = true end
	local m,e = math.frexp(args.RES)
	if m==0.5 then e=e-1 end
	args.RES = 2^e
	print("RESOLUTION",args.RES)
	local RESOLUTION = args.RES;
	FF.RESOLUTION = RESOLUTION
	local END_EDIT_FREQUENCY = 150.0;
	local END_EDIT_FREQUENCY2 = RESOLUTION*0.5 --math.sqrt(((RESOLUTION*0.5)^2)*2)
	print("END_EDIT_FREQUENCY2",END_EDIT_FREQUENCY2)
	END_EDIT_FREQUENCY = END_EDIT_FREQUENCY2
	--------------
	local plugin = require"anima.plugins.plugin"
	local presets --= plugin.presets(FF)
	local serializer --= plugin.serializer(FF)
	
	local function setcurve(NM)
		local wi = NM.width
		local gain = NM.gain*0.5
		local peak = NM.peak/END_EDIT_FREQUENCY
		local min = math.max(0,peak-wi)
		local max = math.min(1,peak+wi)
		if NM.kind == 0 then
			NM.defs.curv.curve:setpoints{{x=min,y=0.5},{x=peak,y=gain},{x=max,y=0.5},{x=-1,y=0}}
		elseif NM.kind == 1 then
			NM.defs.curv.curve:setpoints{{x=min,y=0.5},{x=peak,y=gain},{x=max,y=gain},{x=-1,y=0}}
		else --2
			NM.defs.curv.curve:setpoints{{x=min,y=gain},{x=peak,y=gain},{x=max,y=0.5},{x=-1,y=0}}
		end
		--NM.defs.curv.curve:setpoints{{x=min,y=0.5},{x=min,y=gain},{x=peak,y=gain},{x=max,y=gain},{x=max,y=0.5},{x=-1,y=0}}
	end
	
	local powersdata = ffi.new("float[?]",END_EDIT_FREQUENCY)
	local maxvalp = ffi.new("float[1]",0.001)
	local NM = GL:Dialog("fft",
	{{"unit",6,guitypes.valint,{min=0,max=7}},
	{"curv",{0,0.5,1,0.5},guitypes.curve,{pressed_on_modified=false},function(curve) FF:filter(curve.LUT,curve.LUTsize) end},
	{"peak",0.5,guitypes.val,{min=0,max=END_EDIT_FREQUENCY},function(val,this) setcurve(this) end},
	{"width",0.1,guitypes.val,{min=0,max=0.1},function(val,this) setcurve(this) end},
	{"gain",1,guitypes.val,{min=0,max=2},function(val,this) setcurve(this) end},
	{"kind",0,guitypes.combo,{"peak","lowpass","hipass"},function(val,this) setcurve(this) end},
	{"bypass",false,guitypes.toggle},
	},function(this) 
		presets.draw()
		serializer.draw()
		if args.power then
			ig.SliderFloat("max", maxvalp, 0, 0.001, "%0.4f", 1);
			ig.PlotLines("powers", powersdata, END_EDIT_FREQUENCY, 0, nil, 0,maxvalp[0], ig.ImVec2(400,200));
		end
	end)


	FF = plugin.new(FF,GL,NM)
	presets = plugin.presets(FF)
	serializer = plugin.serializer(FF)
	local curve = NM.defs.curv.curve
	
------------------------
    local imageTexture,pingTexture,pongTexture,filterTexture,originalSpectrumTexture,filteredSpectrumTexture, filteredImageTexture,readoutTexture
	
	local pingFramebuffer, pongFramebuffer ,originalSpectrumFramebuffer, filteredSpectrumFramebuffer ,filteredImageFramebuffer,readoutFramebuffer
	
	local subtransformProgramWrapper, readoutProgram, imageProgram, filterProgram
	local subtransformProgramWrappervao, readoutProgramvao, imageProgramvao, filterProgramvao
	
	local old_framebuffer = ffi.new("GLuint[1]",0)
	function FF:saveoldFBO()
		gl.glGetIntegerv(glc.GL_DRAW_FRAMEBUFFER_BINDING, old_framebuffer)
	end
	function FF:setoldFBO()
		glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, old_framebuffer[0]);
	end
	function FF:bindtexs()

		bindtex(PING_TEXTURE_UNIT,pingTexture,glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)
		bindtex(PONG_TEXTURE_UNIT,pongTexture,glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)
		bindtex(FILTER_TEXTURE_UNIT,filterTexture,glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)
		bindtex(ORIGINAL_SPECTRUM_TEXTURE_UNIT,originalSpectrumTexture, glc.GL_REPEAT, glc.GL_REPEAT, glc.GL_NEAREST, glc.GL_NEAREST)
		bindtex(FILTERED_SPECTRUM_TEXTURE_UNIT,filteredSpectrumTexture, glc.GL_REPEAT, glc.GL_REPEAT, glc.GL_NEAREST, glc.GL_NEAREST)
		--bindtex(FILTERED_IMAGE_TEXTURE_UNIT,filteredImageTexture, glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)
		bindtex(FILTERED_IMAGE_TEXTURE_UNIT,filteredImageTexture, glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_LINEAR_MIPMAP_LINEAR, glc.GL_LINEAR)
		bindtex(READOUT_TEXTURE_UNIT,readoutTexture, glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)
	end
	function FF:init()
		self:saveoldFBO()
		
        pingTexture = buildTexture( PING_TEXTURE_UNIT, glc.GL_RGBA, glc.GL_FLOAT, RESOLUTION, RESOLUTION, nil, glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)
        pongTexture = buildTexture( PONG_TEXTURE_UNIT, glc.GL_RGBA, glc.GL_FLOAT, RESOLUTION, RESOLUTION, nil, glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)
        filterTexture = buildTexture( FILTER_TEXTURE_UNIT, glc.GL_RGBA, glc.GL_FLOAT, RESOLUTION, 1, nil, glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)
        originalSpectrumTexture = buildTexture( ORIGINAL_SPECTRUM_TEXTURE_UNIT, glc.GL_RGBA, glc.GL_FLOAT, RESOLUTION, RESOLUTION, nil, glc.GL_REPEAT, glc.GL_REPEAT, glc.GL_NEAREST, glc.GL_NEAREST)
        filteredSpectrumTexture = buildTexture( FILTERED_SPECTRUM_TEXTURE_UNIT, glc.GL_RGBA, glc.GL_FLOAT, RESOLUTION, RESOLUTION, nil, glc.GL_REPEAT, glc.GL_REPEAT, glc.GL_NEAREST, glc.GL_NEAREST)
        filteredImageTexture = buildTexture( FILTERED_IMAGE_TEXTURE_UNIT, glc.GL_RGBA, glc.GL_FLOAT, RESOLUTION, RESOLUTION, nil, glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)
        readoutTexture = buildTexture( READOUT_TEXTURE_UNIT, glc.GL_RGBA, glc.GL_FLOAT, RESOLUTION, RESOLUTION, nil, glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)

		pingFramebuffer = buildFramebuffer( pingTexture)
        pongFramebuffer = buildFramebuffer( pongTexture)
        originalSpectrumFramebuffer = buildFramebuffer( originalSpectrumTexture)
        filteredSpectrumFramebuffer = buildFramebuffer( filteredSpectrumTexture)
        filteredImageFramebuffer = buildFramebuffer( filteredImageTexture)
        readoutFramebuffer = buildFramebuffer( readoutTexture);

	subtransformProgramWrapper = GLSL:new():compile(FULLSCREEN_VERTEX_SOURCE, SUBTRANSFORM_FRAGMENT_SOURCE)
	subtransformProgramWrapper:use()
	subtransformProgramWrapper.unif.u_resolution:set{RESOLUTION}

	readoutProgram = GLSL:new():compile(FULLSCREEN_VERTEX_SOURCE, POWER_FRAGMENT_SOURCE)
	readoutProgram:use()
	readoutProgram.unif.u_spectrum:set{ORIGINAL_SPECTRUM_TEXTURE_UNIT}
	readoutProgram.unif.u_resolution:set{RESOLUTION}
	
	imageProgram = GLSL:new():compile(FULLSCREEN_VERTEX_SOURCE, IMAGE_FRAGMENT_SOURCE)
	imageProgram:use()
	imageProgram.unif.u_texture:set{FILTERED_IMAGE_TEXTURE_UNIT}

	filterProgram = GLSL:new():compile(FULLSCREEN_VERTEX_SOURCE, FILTER_FRAGMENT_SOURCE)
	filterProgram:use()
	filterProgram.unif.u_input:set{ORIGINAL_SPECTRUM_TEXTURE_UNIT}
	filterProgram.unif.u_filter:set{FILTER_TEXTURE_UNIT}
	filterProgram.unif.u_resolution:set{RESOLUTION}
	filterProgram.unif.u_maxEditFrequency:set{END_EDIT_FREQUENCY}
	
	subtransformProgramWrappervao = VAO({a_position={-1.0, -1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0}},subtransformProgramWrapper
	)
	readoutProgramvao = subtransformProgramWrappervao:clone(readoutProgram)
	imageProgramvao = subtransformProgramWrappervao:clone(imageProgram)
	filterProgramvao = subtransformProgramWrappervao:clone(filterProgram)
	
	self:setoldFBO()
	end
	
    local iterations = math.log(RESOLUTION) * 2/math.log(2);
	print("iterations",iterations)
    function FF:fft(inputTextureUnit, outputFramebuffer, width, height, direction) 
		--print"fft----------------"
        subtransformProgramWrapper:use()
        gl.glViewport(0, 0, RESOLUTION, RESOLUTION);
        subtransformProgramWrapper.unif.u_horizontal:set{1}
        subtransformProgramWrapper.unif.u_forward:set{(direction == FORWARD) and 1 or 0};
        for i = 0,iterations-1 do
            if (i == 0) then
                glext.glBindFramebuffer(glc.GL_FRAMEBUFFER, pingFramebuffer);
                subtransformProgramWrapper.unif.u_input:set{inputTextureUnit}
            elseif (i == iterations - 1) then
                glext.glBindFramebuffer(glc.GL_FRAMEBUFFER, outputFramebuffer);
                subtransformProgramWrapper.unif.u_input:set{PING_TEXTURE_UNIT}
            elseif (i % 2 == 1) then
                glext.glBindFramebuffer(glc.GL_FRAMEBUFFER, pongFramebuffer);
                subtransformProgramWrapper.unif.u_input:set{PING_TEXTURE_UNIT}
            else 
                glext.glBindFramebuffer(glc.GL_FRAMEBUFFER, pingFramebuffer);
                subtransformProgramWrapper.unif.u_input:set{PONG_TEXTURE_UNIT}
            end

            if (direction == INVERSE and i == 0) then
                subtransformProgramWrapper.unif.u_normalize:set{true}
			else
                subtransformProgramWrapper.unif.u_normalize:set{false}
            end

            if (i == (iterations / 2)) then
                subtransformProgramWrapper.unif.u_horizontal:set{0}
            end

            subtransformProgramWrapper.unif.u_subtransformSize:set{math.pow(2, (i % (iterations / 2)) + 1)}

			subtransformProgramWrappervao:draw(glc.GL_TRIANGLE_STRIP)
        end
    end

    function FF:setImage(image,w,h) 
        glext.glActiveTexture(glc.GL_TEXTURE0 + IMAGE_TEXTURE_UNIT);
		local tex = ffi.new("GLuint[1]")
		gl.glGenTextures(1, tex);
        imageTexture = tex[0]
        gl.glBindTexture(glc.GL_TEXTURE_2D, imageTexture);
       -- gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, glc.GL_RGB32F, RESOLUTION, RESOLUTION, 0, glc.GL_RGB, glc.GL_UNSIGNED_BYTE, image);
	   
	   --gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, glc.GL_RGB32F, w, h, 0, glc.GL_RGB, glc.GL_FLOAT, image);
	   gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, glc.GL_RGBA32F, w, h, 0, glc.GL_RGB, glc.GL_FLOAT, image);
	   
        gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, glc.GL_CLAMP_TO_EDGE);
        gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, glc.GL_CLAMP_TO_EDGE);
        gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MIN_FILTER, glc.GL_NEAREST);
        gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAG_FILTER, glc.GL_NEAREST);

        glext.glActiveTexture(glc.GL_TEXTURE0 + ORIGINAL_SPECTRUM_TEXTURE_UNIT);
        gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, glc.GL_RGBA32F, RESOLUTION, RESOLUTION, 0, glc.GL_RGBA, glc.GL_FLOAT, nil);

        self:fft(IMAGE_TEXTURE_UNIT, originalSpectrumFramebuffer, RESOLUTION, RESOLUTION, FORWARD);
    end

	local oldtexsignature
	function FF:set_texture(tex)
		if oldtexsignature and oldtexsignature==tex:get_signature() then return end
		oldtexsignature=tex:get_signature()
		--print"-------------fft texture set--------------"
		self:saveoldFBO()
		if imageTexture then imageTexture:delete() end
		imageTexture = tex:resample(RESOLUTION,RESOLUTION)
		--imageTexture = tex:resize(RESOLUTION,RESOLUTION)
		imageTexture:Bind(IMAGE_TEXTURE_UNIT)
		imageTexture:gen_mipmap()
		-- imageTexture:Bind(IMAGE_TEXTURE_UNIT)
		-- imageTexture:set_wrap(glc.GL_CLAMP_TO_EDGE)
		-- imageTexture:mag_filter(glc.GL_NEAREST)
		-- imageTexture:min_filter(glc.GL_NEAREST)
		bindtex(IMAGE_TEXTURE_UNIT,imageTexture.tex,glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)
		self:bindtexs()
		glext.glActiveTexture(glc.GL_TEXTURE0 + ORIGINAL_SPECTRUM_TEXTURE_UNIT);
        gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, glc.GL_RGBA32F, RESOLUTION, RESOLUTION, 0, glc.GL_RGBA, glc.GL_FLOAT, nil);
		self:fft(IMAGE_TEXTURE_UNIT, originalSpectrumFramebuffer, RESOLUTION, RESOLUTION, FORWARD);
		
		-------readout power
		if args.power then
		self:bindtexs()
		glext.glBindFramebuffer(glc.GL_FRAMEBUFFER, readoutFramebuffer);
        gl.glViewport(0, 0, RESOLUTION, RESOLUTION);
		readoutProgram:use()
		readoutProgramvao:draw(glc.GL_TRIANGLE_STRIP)
		
		local numpixels = RESOLUTION*RESOLUTION*1
		local pixelsUserData = ffi.new("float[?]",numpixels)
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER, readoutFramebuffer);
		gl.glReadBuffer(glc.GL_COLOR_ATTACHMENT0 + 0); 
		
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER,0)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(0,0, RESOLUTION, RESOLUTION, glc.GL_RED, glc.GL_FLOAT, pixelsUserData)
		
		local maxval = -math.huge
		for i=0,numpixels-1 do
			if pixelsUserData[i]>maxval then maxval = pixelsUserData[i] end
		end
		
		--print("maxval",maxval)
		local powersByFrequency = {}
		local pixelIndex = 0
		for yIndex=0,RESOLUTION-1 do
			local y = yIndex - RESOLUTION / 2;
			for xIndex=0,RESOLUTION-1 do
				local x = xIndex - RESOLUTION / 2
				local frequency = math.floor(0.5+math.sqrt(x * x + y * y))
                powersByFrequency[frequency] = powersByFrequency[frequency] or {}
				table.insert(powersByFrequency[frequency],pixelsUserData[pixelIndex])
				pixelIndex = pixelIndex + 1
			end
		end
		
		local data = {}
		for f,arr in pairs(powersByFrequency) do
			for i,v in ipairs(arr) do
				data[f] = v + (data[f] or 0)
			end
			data[f] = data[f]/#arr
		end
		for i=0,END_EDIT_FREQUENCY-1 do
			powersdata[i] = data[i] or 0
		end
		end --args.power
		self:setoldFBO()
	end
    function FF:filter(filterArray, length) 
		--print"fft:filter"
		self:saveoldFBO()
		
		self:bindtexs()
		
        glext.glActiveTexture(glc.GL_TEXTURE0 + FILTER_TEXTURE_UNIT);
        gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, glc.GL_RED, length, 1, 0, glc.GL_RED, glc.GL_FLOAT, filterArray);

        filterProgram:use()

        glext.glBindFramebuffer(glc.GL_FRAMEBUFFER, filteredSpectrumFramebuffer);
        gl.glViewport(0, 0, RESOLUTION, RESOLUTION);
		filterProgramvao:draw(glc.GL_TRIANGLE_STRIP)
		
        self:fft(FILTERED_SPECTRUM_TEXTURE_UNIT, filteredImageFramebuffer, RESOLUTION, RESOLUTION, INVERSE);
		--self:fft(ORIGINAL_SPECTRUM_TEXTURE_UNIT, filteredImageFramebuffer, RESOLUTION, RESOLUTION, INVERSE);

       -- self:output();
	   self:setoldFBO()
    end

    function FF:output() 
		self:output2(NM.unit)
    end
	function FF:output2(nn) 
		--print"fft output"
		--ut.Clear()
		if nn==6 or nn==5 then
			local xoff,yoff= 0,0
			local w,h = GL.W,GL.H
			if GL.H > GL.W then
				xoff = math.floor((GL.W-GL.H)*0.5+0.5)
				w = GL.H
			else
				yoff = math.floor((GL.H-GL.W)*0.5+0.5)
				h = GL.W
			end
			--gl.glViewport(0,0,GL.W,GL.H) --for resize in set_texture
			gl.glViewport(xoff,yoff,w,h) --for resample in set_texture
			bindtex(nn,texturebyunit[nn],glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_LINEAR_MIPMAP_LINEAR, glc.GL_LINEAR)
		else
			gl.glViewport(getAspectViewport(GL.W,GL.H,RESOLUTION, RESOLUTION));
		end
		
		imageProgram:use()
		imageProgram.unif.u_texture:set{nn}
		imageProgramvao:draw(glc.GL_TRIANGLE_STRIP)
		
		bindtex(IMAGE_TEXTURE_UNIT,imageTexture.tex,glc.GL_CLAMP_TO_EDGE, glc.GL_CLAMP_TO_EDGE, glc.GL_NEAREST, glc.GL_NEAREST)
		self:bindtexs()
    end
	function FF:process(texture)
		--print"---------------fftprocess"
		if NM.bypass then texture:drawcenter();return end
		self:set_texture(texture)
		self:filter(curve.LUT,curve.LUTsize)
		self:output()
	end
	GL:add_plugin(FF)
	return FF
end

--[=[
require"anima"
RES=400
GL = GLcanvas{H=RES,W=RES,profile="CORE",DEBUG=false,vsync=true}

NM = GL:Dialog("test",{{"orig",false,guitypes.toggle}})
local vicim = require"anima.vicimag"
local image,tex,fft,fbo
function GL.init()
	GLSL.default_version = "#version 330\n"

	image = vicim.load_im([[C:\luaGL\media\fandema1.tif]])
	
	tex = image:totex(GL)
	
	--tex = tex:resample_fac(0.25)
	GL:set_WH(tex.width,tex.height)
	fft = Filterer(GL,{power=false})
	fbo = GL:initFBO{no_depth=true}
	--print_glinfo(GL)
	GL:DirtyWrap()
end

function GL.draw(t,w,h)
	ut.Clear()
	if NM.orig then
		tex:drawcenter()
	else
		fft:process_fbo(fbo,tex)
		fbo:tex():drawcenter()
		--fft:output()
	end
end
GL:start()
--]=]

--[==[
require"anima"
local RES = 512*2
local GL = GLcanvas{H=RES,W=RES,vsync=true,SDL=false}

local NM = GL:Dialog("sines",{
{"freq",100,guitypes.val,{min=0,max=RES/2}},
{"turns",0,guitypes.dial,{fac=-0.5/math.pi}}
})



local tproc,chain,fft
local Dbox
function GL.init()
	tproc = require"anima.plugins.texture_processor"(GL,0,NM)
	---[=[
	tproc:set_process[[
	#define M_PI 3.1415926535897932384626433832795
	vec4 process(vec2 pos){
		float angle = M_PI*turns*2;
		vec2 dir = vec2(cos(angle),sin(angle));
		float dis = dot(dir,pos);
		return vec4(sin(dis*2*M_PI*freq)*0.5+0.5);
	}]]
	--]=]
	--[=[
	tproc:set_process[[vec4 process(vec2 pos){
		return vec4(sin(pos.y*2*3.14159*freq)*0.5+0.5);
	}]]
	--]=]
	--[=[
	tproc:set_process[[
		float randhash(uint seed, float b)
{
    const float InverseMaxInt = 1.0 / 4294967295.0;
    uint i=(seed^12345391u)*2654435769u;
    i^=(i<<6u)^(i>>26u);
    i*=2654435769u;
    i+=(i<<5u)^(i>>12u);
    return float(b * i) * InverseMaxInt;
}
	vec4 process(vec2 pos){
		vec2 fcoord = gl_FragCoord.xy;
		uint seed = uint(fcoord.x) * uint(fcoord.y);
		return vec4(randhash(seed,1));
	}
	]]
	--]=]
	fft = Filterer(GL)
	
	Dbox = GL:DialogBox("test",true)
	Dbox:add_dialog(tproc.NM)
	Dbox:add_dialog(fft.NM)
	
	
	local tex = GL:Texture()

	chain = tex:make_chain{tproc,fft}
	GL:DirtyWrap()
end

function GL.draw(t,w,h)
	ut.Clear()

	chain:process({})
	chain:tex():drawcenter()

end

GL:start()
--]==]


return Filterer