require"anima"

GL = GLcanvas{fps=25,vsync=0,H=600,aspect=1,SDL=false}

local SR = 44100
local nFrames =  64 --128 --256 --512 --512 --512 --256 --s320 --224 --12*32 --256 --4096 --2*128
local NBUFFS = 2 --12
local NNx = 3*32 --4*32

local glframedur = 1/GL.fps
local HEXA = ffi.new("bool[1]",true) --true --true

local phys = require"drum_audio_compute"
local clip

local sndf = require"sndfile_ffi"
local rt = require"rtaudio_ffi"
local ring_scsp = require"ring_scsp"

local auinf = rt.GetAllInfo()
local ocombos = auinf.out_combos(ig)
local oAPI,odevice = auinf.first_out()
ocombos.Set(oAPI, odevice)

local function initAudio(nFrames, NBUFSS)
	ud = ring_scsp.circ_buf(nFrames,NBUFSS)
	local audio_init = require"circ_buf_audio"
	local bufferFrames = ffi.new("unsigned int[1]", nFrames)
	print("InitAudio",oAPI,odevice)
	local dac = rt.create(rt.compiled_api_by_name(oAPI))
	local dev = odevice --dac:get_default_output_device()
	local api = auinf.API[oAPI]
	local SRs = api.devices[api.devices_by_ID[odevice]].sample_rates
	local allowedSR = false
	for i,sr in ipairs(SRs) do
		if tonumber(sr)==SR then allowedSR = true; break end
	end
	if not allowedSR then print(SR, "not allowed in ", oAPI, odevice); dac = nil; return end
	local outpars = ffi.new("rtaudio_stream_parameters_t[1]", {{dev,2}})
	local options = ffi.new("rtaudio_stream_options_t[1]",{{rt.FLAGS_HOG_DEVICE +rt.FLAGS_NONINTERLEAVED+rt.FLAGS_MINIMIZE_LATENCY}})
	local thecallback = rt.MakeAudioCallback(audio_init, nFrames,SR)
	local ret = rt.open_stream(dac, outpars, nil, rt.FORMAT_FLOAT32, SR, bufferFrames, thecallback, ud, options , nil)
    if ret < 0 then
        local err = dac:error()
        error(err~=nil and ffi.string(err) or "unknown error opening device")
    end
	assert(bufferFrames[0] == nFrames, bufferFrames[0])
	return ud, dac
end
local rtmidi = require"rtmidi_ffi"
local info = rtmidi.GetAllInfo()

local PortCombo = ig.LuaCombo("port")
local mAPIcombo = ig.LuaCombo("api", info.APIdisplay_names, function(val,i)
	local api = info.APIbyi[i]
	PortCombo:set(info.API[api].ins)
end)
local midi_in
local function set_midi_in(api,port)
	local portname = PortCombo:get_name()
	print("opening midi in:", mAPIcombo:get_name(),portname,"\n")
	if portname=="none" then return end
	local m_in = rtmidi.rtmidi_in(api)
	m_in:open_port( port,"Mi input port" );
	if m_in.ok == false then error(ffi.string(m_in.msg)) end
	m_in:in_ignore_types( true, true, true );
	midi_in = m_in
end

local close
local dac,ud
local function set_odev(API,dev)
	oAPI,odevice = API,dev
	ud,dac = initAudio(nFrames,NBUFFS)
	if not dac then
		--if midi_in then midi_in:close_port(); midi_in:free(); midi_in = nil end
		close()
		return
	end
	local audioframedur = nFrames/SR
	local aufr_per_glfr = math.ceil(glframedur/audioframedur)
	clip = phys(GL,nFrames,aufr_per_glfr,SR,NNx,ud, midi_in, close)
	clip:init({recordNo="grabar.wav",hexa=HEXA[0]})
	local errty = dac:start_stream()
	if errty~=rt.ERROR_NONE then
		error(ffi.string(dac:error()))
	end
end

close = function()
	print("closing")
	if clip then clip:close(); clip = nil end
	if dac then
		dac:stop_stream();
		--print"stoped"
		dac:close_stream();
		dac = nil
		--print"done" 
	end
end

local standardSampleRates = {
    11025.0, 12000.0, 16000.0, 22050.0, 24000.0, 32000.0,
    44100.0, 48000.0}
for i,v in ipairs(standardSampleRates) do standardSampleRates[i] = tostring(v) end
local SRcombo = ig.LuaCombo("SampleRate##in",standardSampleRates,function(val,id) 
	SR = tonumber(val)
end)
SRcombo:set_name("44100")

local bufsizes = {}
for i= 6,11 do table.insert(bufsizes, tostring(2^i)) end
local BScombo = ig.LuaCombo("buffer size##in",bufsizes,function(val,ind) 
	nFrames = tonumber(val)
end)
BScombo:set_name("512")

local nomidi = ffi.new("bool[1]",false)
function GL.imgui()
	if not clip then
		ig.Text"Audio settings"
		ocombos:draw()
		ig.Separator()
		ig.Text"Midi settings"
		mAPIcombo:draw()
		PortCombo:draw()
		ig.Checkbox("Dont use midi but gui pad.",nomidi)
		SRcombo:draw()
		BScombo:draw()
		ig.Checkbox("hexagonal grid",HEXA)
		if ig.Button("set devices.") then
			if not nomidi[0] then
				local _,apii = mAPIcombo:get()
				local _,porti = PortCombo:get()
				set_midi_in(info.APIbyi[apii],porti-1)
			end
			set_odev(ocombos.Get())
		end
	end
end

function GL.draw(t,w,h)
	if clip then
		clip:draw(t,w,h)
	end
end

GL:start()
close()