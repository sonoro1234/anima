
local gui = {}


function gui.KeyFramer(NMC,use_spline)

	if NMC.KF then error("already has keyframer") end
	local GL = NMC.GL
	local KF = {}
	KF.currkey = ffi.new("int[1]",1)
	KF.max_currkey = 1
	KF.currkey_time = ffi.new"char[32]"
	KF.edit = ffi.new("bool[1]",false)

	local function_names = {}
	for k,v in pairs(unit_maps) do
		function_names[#function_names + 1] = k
	end
	table.sort(function_names)
	function_names[0] = "nil"
	--prtable(function_names)
	local function_name_idx = {}
	for k=0,#function_names do 
		function_name_idx[function_names[k]] = k ; 
	end
	--prtable(function_name_idx)
	local anchor = {}
	for i = 0,#function_names  do
		anchor[i] = ffi.new("const char*",function_names[i])
		--KF.functions_combo[i] = anchor[i]
	end
	KF.functions_combo = ffi.new("const char* const[?]",(#function_names + 1),anchor)
	KF.curr_function_num = ffi.new("int[1]",0)
	KF.functions_combo_count = #function_names + 1
	
	KF.curr_args = ffi.new("char[64]")
	
	KF.dialog = function()
	
			ig.BeginChild("key editor",ig.ImVec2(0,ig.GetFrameHeightWithSpacing()*5),true,imgui.ImGuiWindowFlags_AlwaysAutoResize)
			--local text = (KF.edit and "edit x") or "edit"
			--if imgui.igSmallButton(text) then KF.edit = not KF.edit end
			ig.Checkbox("edit", KF.edit)
			ig.SameLine(0,-1)
			ffi.copy(KF.currkey_time, tostring(KF.Keys[KF.currkey[0]].time))
			if ig.InputText("time",KF.currkey_time,32,imgui.ImGuiInputTextFlags_CharsDecimal + imgui.ImGuiInputTextFlags_EnterReturnsTrue, nil, nil) then
				KF.Keys[KF.currkey[0]].time = tonumber(ffi.string(KF.currkey_time))
				table.sort(KF.Keys, function(a,b) return a.time < b.time end)
				KF.Animation = KF:MakeAnim(KF.Keys)
			end
			--KF.curr_function_num[0] = KF.Keys[KF.currkey[0]].func_num or -1
			KF.curr_function_num[0] = KF.Keys[KF.currkey[0]].funcname and function_name_idx[KF.Keys[KF.currkey[0]].funcname] or 0
			if ig.Combo("function", KF.curr_function_num, KF.functions_combo, KF.functions_combo_count, -1) then
				--print(KF.functions_combo[KF.curr_function_num[0]])
				KF.Keys[KF.currkey[0]].funcname = ffi.string(KF.functions_combo[KF.curr_function_num[0]])
				--KF.Keys[KF.currkey[0]].func_num = KF.curr_function_num[0]
				KF.Animation = KF:MakeAnim(KF.Keys)
			end
			ffi.copy(KF.curr_args, KF.Keys[KF.currkey[0]].args or "")
			if ig.InputText("args", KF.curr_args, 64, imgui.ImGuiInputTextFlags_EnterReturnsTrue,nil, nil) then
				KF.Keys[KF.currkey[0]].args = ffi.string(KF.curr_args)
				KF.Animation = KF:MakeAnim(KF.Keys)
			end
			if ig.SmallButton"add" then
				KF.max_currkey  = KF.max_currkey  + 1
				KF:addkey()
			end
			ig.SameLine(0,-1)
			if ig.SmallButton"modify" then
				KF:modifykey()
			end
			ig.SameLine(0,-1)
			if ig.SmallButton"delete" then
				if #KF.Keys > 1 then
					KF.max_currkey  = KF.max_currkey  + 1
					KF:deletekey()
				end
			end
			ig.SameLine(0,-1)
			if ig.SmallButton"clipboard" then
				KF:to_clipboard()
			end
			if ig.SliderInt("key", KF.currkey, 1, KF.max_currkey, "%.0f") then
				GL.timeprovider:set_time(KF.Keys[KF.currkey[0]].time + KF.clippos + 0.01)
			end
			ig.EndChild()
		end
	
	NMC.KF_dialog = KF.dialog
	NMC.KF = KF
	KF.parent = NMC
	table.insert(NMC.GL.keyframers, KF)
	function KF:MakeAnim(cp,animfunc)
		animfunc = animfunc or unit_maps.linearmap
		self.Keys = cp
		self.max_currkey = #cp
		if #cp < 1 then return nil end
		
		local automs = {}
		--for k,v in pairs(NMC.vars) do automs[k] = {} end
		for k,v in pairs(cp[1].vals) do automs[k] = {} end
		
		local keys = {}
		for i=1,#cp-1 do
			local dur = cp[i+1].time - cp[i].time
			for k,v in pairs(automs) do
				local func
				if type(cp[i].vals[k])=="boolean" then 
					--print"zzzzzzzzzzzzzzzzzzzzzzz using constant map"
					func = unit_maps.constantmap 
				else
					if cp[i].funcname and cp[i].funcname ~="nil" then
						func = unit_maps[cp[i].funcname]
						if cp[i].args and cp[i].args ~="" then
							local args = stsplit(cp[i].args,",")
							--print("unpack(args)",unpack(args))
							func = func(unpack(args))
						end
					end
				end
				if use_spline and not (func==unit_maps.constantmap) then
					--print("spl",k,use_spline,use_spline and (not (func==unit_maps.constantmap)),func)
					v[#v+1] = {cp[i].vals[k],dur}
				else
					--print("fun",k,use_spline,use_spline and (not (func==unit_maps.constantmap)),func)
					v[#v+1] = {cp[i].vals[k],cp[i+1].vals[k],dur,func or animfunc}
				end
			end
			keys[i] = ConstVal(i,dur)
		end
		for k,v in pairs(automs) do
			v[#v+1] = ConstVal(cp[#cp].vals[k],1)
		end
		keys[#cp] = ConstVal(#cp,1)
		
		local anim = Animation:new({fps = GL.fps})
		for k,v in pairs(automs) do 
			if #automs[k][1] == 2 then --spline
				--print("add splines",k)
				anim:add_animatable(spl_anim:new(NMC.vars[k],automs[k]))
			else
				--print("add funcs",k)
				anim:add_setable(NMC.vars[k],automs[k])
			end
		end
		anim:add_setable(self.currkey,keys)
		
		self.Animation = anim
		return anim
	end
	KF.clippos = 0
	function KF:get_time()
		return GL:get_time() - self.clippos
	end
	function KF:addkey()
		local Keys = self.Keys
		Keys[#Keys + 1] = {time=self:get_time(),vals=NMC:GetValues()}
		table.sort(Keys, function(a,b) return a.time < b.time end)
		self.Animation = self:MakeAnim(Keys)
		prtable(Keys)
	end
	function KF:modifykey()
		local Keys = self.Keys
		Keys[self.currkey[0]].vals = NMC:GetValues()
		self.Animation = self:MakeAnim(Keys)
	end
	function KF:deletekey()
		local Keys = self.Keys
		table.remove(Keys,self.currkey[0])
		self.Animation = self:MakeAnim(Keys)
	end
	function KF:to_clipboard()
		--glfw.glfwSetClipboardString(GL.window,serializeTable("Keys",self.Keys))
		GL.window:SetClipboardString(serializeTable("Keys",self.Keys))
		print(self:serialize_str())
	end
	function KF:serialize_str()
		return serializeTable(NMC.name,self.Keys)
	end
	function KF:queue()
		--NMC.GL.animated_keyframers = NMC.GL.animated_keyframers or {}
		table.insert(NMC.GL.animated_keyframers,self)
	end
	function KF:animate(time)
		if not self.edit[0] then self.Animation:animate(time) end
	end
	KF.Keys = {{time=0,vals=NMC:GetValues()}} 
	KF.Animation = KF:MakeAnim(KF.Keys)
	return KF
end
function gui.YesNo(msg)
	local D = {}
	function D.open() 
		ig.OpenPopup("yesno") 
	end
	function D.draw(doit)
		local resp = doit
		if ig.BeginPopupModal("yesno",nil,0) then
			ig.Text(msg)
			if ig.Button("yes") then
				resp = true
				ig.CloseCurrentPopup(); 
			end
			ig.SameLine()
			if ig.Button("no") then
				resp = false
				ig.CloseCurrentPopup(); 
			end
			ig.EndPopup()
		end
		return resp
	end
	return D
end
--args.key, args.curr_dir, args.pattern, args.filename, args.check_existence, args.addext
function gui.FileBrowser(filename_p, args, funcOK)
	
	args = args or {}
	args.key = args.key or "filechooser"
	local pattern_ed = ffi.new("char[32]",args.pattern or "")
	--ffi.copy(pattern_ed, args.pattern or "" )
	local pathut = require"anima.path"
	local curr_dir = args.curr_dir or pathut.this_script_path() 
	local curr_dir_ed = ffi.new("char[256]")
	ffi.copy(curr_dir_ed, curr_dir )
	
	local curr_dir_done = false
	local curr_dir_files = {}
	local curr_dir_dirs = {}
	local fullname
	
	local lfs = require"lfs"
	local function funcdir(path, patt)
		for file in lfs.dir(path) do
			if file ~= "."  then --and file ~= ".." then
					local f = pathut.chain(path,file) --path..pathut.sep..file
					local attr = lfs.attributes (f)
					assert (type(attr) == "table")
					if attr.mode == "directory" then
						table.insert(curr_dir_dirs, {path=f,name=file,is_dir=true})
					elseif (not patt) or file:match(patt) then
						table.insert(curr_dir_files, {path=f,name=file,is_dir=false})
					end
			end
		end
	end
	
	local yesnoD = gui.YesNo("overwrite?")
	
	--local regionsize = ffi.new("ImVec2[1]")
	local save_file_name = ffi.new("char[256]",args.filename or "")
	local function filechooser()
	
		
		if (imgui.igBeginPopupModal(args.key, nil, ffi.C.ImGuiWindowFlags_AlwaysAutoResize)) then

			local tsize = ig.CalcTextSize(curr_dir_ed, nil,false, -1.0);
			ig.PushItemWidth(tsize.x + ig.GetStyle().ItemInnerSpacing.x * 2)
			if ig.InputText("##dir",curr_dir_ed,256,0,nil,nil) then
				curr_dir = ffi.string(curr_dir_ed)
				curr_dir_done = false 
			end
			ig.PopItemWidth()
			
			if not curr_dir_done then
				curr_dir_files , curr_dir_dirs = {},{} 
				funcdir(curr_dir,ffi.string(pattern_ed))
				curr_dir_done = true
			end
			
			local regionsize = ig.GetContentRegionAvail()
			local desiredY = math.max(regionsize.y - ig.GetFrameHeightWithSpacing()*4,200)
			ig.BeginChild("files", ig.ImVec2(0,desiredY), true, 0)
			
			for i,v in ipairs(curr_dir_dirs) do
				if(ig.Selectable(v.name.." ->",false,ig.lib.ImGuiSelectableFlags_AllowDoubleClick,ig.ImVec2(0,0))) then 
					if (ig.IsMouseDoubleClicked(0)) then
							ffi.copy(save_file_name, "")
							curr_dir = pathut.abspath(v.path)
							ffi.copy(curr_dir_ed,curr_dir)
							curr_dir_done = false
					end
				end
			end
			for i,v in ipairs(curr_dir_files) do
				if(ig.Selectable(v.name,false,ig.lib.ImGuiSelectableFlags_AllowDoubleClick,ig.ImVec2(0,0))) then
					if (ig.IsMouseDoubleClicked(0)) then
						ffi.copy(save_file_name, v.name)
					end
				end
				
			end
			ig.EndChild()
			
			ig.InputText("file",save_file_name,256,0)
			if ig.InputText("pattern",pattern_ed,32,ig.lib.ImGuiInputTextFlags_EnterReturnsTrue) then curr_dir_done = false end
			local doit = false
			
			if ig.Button("OK") then
				local savefilename = ffistr(save_file_name)
				fullname = ""
				if #savefilename > 0 then
					fullname = pathut.chain(curr_dir,savefilename)
					if args.addext then --for saving with ext
						local ext = pathut.ext(savefilename)
						if ext =="" or not ext then fullname = fullname.."."..ffistr(pattern_ed) end
					end
					if args.check_existence then
						if lfs.attributes(fullname) then
							print("check_existence true",fullname)
							yesnoD.open()
						else
							print("check_existence false",fullname)
							doit = true
						end
					else
						doit = true
					end
				elseif args.choose_dir then
					doit = true
				else
					ig.CloseCurrentPopup(); 
				end
			end
			doit = yesnoD.draw(doit)
			if doit then
				if funcOK then
					funcOK(fullname,curr_dir) --curr_filetype and curr_filetype[0] or -1)
				else
					filename_p[0] = fullname
				end
				ig.CloseCurrentPopup();
			end
			ig.SameLine()
			if ig.Button("CANCEL") then 
				ig.CloseCurrentPopup(); 
			end
			ig.EndPopup()
	
		end
	end
	return {draw = filechooser, open = function() curr_dir_done = false;ig.OpenPopup(args.key) end,func = funcOK}
end

function ToolBox(GL)
	local toolbox = {}
	local icons = GL.Ficons
	function toolbox:draw()
		if ig.BeginPopup("toolbox") then 
			--if ig.Button("hand") then 
			if icons:Button(icons.cursorcps.hand) then
				GL.tool = "hand";
				--glfw.glfwSetCursor(GL.window, GL.cursors.hand);
				GL:SetCursor(GL.cursors.hand)
				ig.GetIO().ConfigFlags =  bit.bor(ig.GetIO().ConfigFlags, ig.lib.ImGuiConfigFlags_NoMouseCursorChange)
				imgui.igCloseCurrentPopup()				
			end
			--if ig.Button("glass") then 
			if icons:Button(icons.cursorcps.glass_p) then
				GL.tool = "glass";
				--glfw.glfwSetCursor(GL.window, GL.cursors.glass_p);
				GL:SetCursor(GL.cursors.glass_p)
				ig.GetIO().ConfigFlags =  bit.bor(ig.GetIO().ConfigFlags, ig.lib.ImGuiConfigFlags_NoMouseCursorChange)
				imgui.igCloseCurrentPopup() 
			end
			if ig.Button("std") then 
				GL.tool = nil;
				--glfw.glfwSetCursor(GL.window, nil);
				GL:SetCursor(nil)
				ig.GetIO().ConfigFlags =  bit.band(ig.GetIO().ConfigFlags, bit.bnot(ig.lib.ImGuiConfigFlags_NoMouseCursorChange))
				imgui.igCloseCurrentPopup() 
			end
			ig.EndPopup()
		end
	end
	return toolbox
end
gui.ToolBox = ToolBox

local function HoverActionFactory(dur,minv,maxv)

	minv = minv or 0
	maxv = maxv or 1
	local range = maxv - minv
	local lastFrameHovered = false
	local actionTime = 0
	local actionUP = false
	local iniVal = 0
	local currVal = 0
	
	local function SetAction(dir)
		lastFrameHovered = dir
		actionTime = 0
		actionUP = dir
		iniVal = currVal
	end

	local function HoverAction()
		if ig.IsWindowHovered(imgui.ImGuiHoveredFlags_AllowWhenBlockedByPopup + imgui.ImGuiHoveredFlags_AllowWhenBlockedByActiveItem) then
			if not lastFrameHovered then SetAction(true) end
		elseif lastFrameHovered then
			SetAction(false)
		end
		local fac = actionTime/dur
		fac = actionUP and fac or -fac
		currVal = math.min(1,math.max(0,iniVal + fac))
		actionTime = actionTime + ig.GetIO().DeltaTime
		return minv + range*currVal
	end
	return HoverAction
end

function gui.ImGui_Transport(GL)
	local transport = {}
	local filetypes = {png="PNG",tif="TIFF",jpg="JPEG"}
	local save_image_browser = gui.FileBrowser(nil,{check_existence=true},function(fname) 
				GL.save_image[0] = fname
				GL.save_image_type = filetypes[fname:match("%.([^%.]+)$")]
				print(fname,GL.save_image_type) 
			end)
	local play_but_text = "  > "
	function transport.play()
		local tp = GL.timeprovider
		if not tp.playing then
			play_but_text = " || "
			tp:start()
		else
			play_but_text = "  > "
			tp:stop()
		end
	end
	
	local HoverAction = HoverActionFactory(0.5,0.0001,1)

	function transport:draw()
		if GL.has_imgui_viewport then --imgui viewport branch
			local vwp = ig.GetMainViewport()
			ig.SetNextWindowViewport(vwp.ID)
			ig.SetNextWindowPos(ig.ImVec2(vwp.Pos.x, vwp.Pos.y + ig.GetMainViewport().Size.y), 0, ig.ImVec2(0.0, 1.0));
			ig.SetNextWindowSize(ig.ImVec2(ig.GetMainViewport().Size.x,0))--height));
		else
			--local height = ig.GetFrameHeightWithSpacing() + ig.GetStyle().WindowPadding.y*2
			ig.SetNextWindowPos(ig.ImVec2(0.0, ig.GetIO().DisplaySize.y), 0, ig.ImVec2(0.0, 1.0));
			--ig.SetNextWindowPos(ig.ImVec2(0, ig.GetIO().DisplaySize.y - height));
			ig.SetNextWindowSize(ig.ImVec2(ig.GetIO().DisplaySize.x,0))--height));
		end
		ig.PushStyleVar_Float(imgui.ImGuiStyleVar_Alpha,0.0001)
		
		if ig.Begin("Transport",nil,imgui.ImGuiWindowFlags_NoTitleBar + imgui.ImGuiWindowFlags_NoResize) then

			ig.PushStyleVar_Float(imgui.ImGuiStyleVar_Alpha,HoverAction())
			
			if ig.Button(play_but_text) then 
				transport.play()
			end
			
			ig.SameLine()
			ig.Text("(%05.1f FPS)", ig.GetIO().Framerate)
			--print(ig.GetIO().Framerate)
			ig.SameLine()
			if ig.Button("next") then 
				GL.timeprovider:set_time(GL.globaltime[0] + 1/GL.fps)
			end
			ig.SameLine()
			if ig.Button("prev") then 
				GL.timeprovider:set_time(GL.globaltime[0] - 1/GL.fps)
			end
			ig.SameLine()
			
			if ig.Button("save") then  save_image_browser.open() end
				ig.PushStyleVar_Float(imgui.ImGuiStyleVar_Alpha,1)
				save_image_browser.draw()
				ig.PopStyleVar(1)
			ig.SameLine()
			
			if GL.opentoolbox then ig.OpenPopup"toolbox";GL.opentoolbox=false end
			if ig.Button("tools") then ig.OpenPopup("toolbox") end
				ig.PushStyleVar_Float(imgui.ImGuiStyleVar_Alpha,1)
				ToolBox(GL):draw()
				ig.PopStyleVar(1)
			ig.SameLine()
			
			ig.PushItemWidth(-1)
			--print("slider", GL.globaltime[0], 0, tonumber(GL.timeprovider.totdur), "%.3f", 1.0)
			if ig.SliderFloat("##timeslider", GL.globaltime, 0, tonumber(GL.timeprovider.totdur), "%.3f") then
				GL.timeprovider:set_time(GL.globaltime[0])
			end
			ig.PopItemWidth()
			ig.PopStyleVar(1) --windowborder and alfa
		end
		
		ig.End()
		ig.PopStyleVar(1) --windowborder and alfa
	end
	return transport
end
local mat = require"anima.matrixffi"
guitypes = {val=1,dial=2,toggle=3,button=4,valint=5,drag=6,combo=7,color=8,curve=9,slider_enum=10}
gui.types = guitypes

local array_mt = {
	__new = function(tp,t)
			if type(t)=="table" then
				return ffi.new(tp,#t,{#t,t})
			elseif type(t)=="number" then
				return ffi.new(tp,t,{t,{}})
			end
		end,
	__add = function(a,b)
			local ret = ffi.new(a,a.size,{a.size})   ---a:new(a.size)
			for i=0,a.size-1 do
				ret.data[i] = a.data[i] + b.data[i]
			end
			return ret
		end,
	__tostring = function(a) 
			local ret = {"<"}
			for i=0,a.size-1 do
				table.insert(ret,a.data[i])				
			end
			table.insert(ret,">")
			return table.concat(ret,",")
		end,
	__index = {
		set = function(a,v)
			if type(v)=="table" then
				for i,vv in ipairs(v) do
					a.data[i-1] = vv
				end
			elseif ffi.istype(mat.vec3,v) then --a.size == 3 then
				a.data[0],a.data[1],a.data[2] = v.x,v.y,v.z
			else
				error("bad set value for array: "..tostring(v))
			end
		end,
		get = function(a)
			local ret = {}
			for i=0,a.size-1 do
				ret[i+1] = a.data[i]
			end
			return ret
		end,
	}

}

local function makearray(ct)
	local tp = ffi.typeof("struct {int size; $ data[?];}",ct)
	return ffi.metatype(tp, array_mt)
end

local farray = makearray(ffi.typeof"float")
local iarray = makearray(ffi.typeof"int")
gui.farray = farray
gui.iarray = iarray

function gui.Dialog(name,vars,func, invisible)
	
	local pointers = {}
	local defs = {}
	local NM = {name = name ,vars=pointers, defs=defs,invisible=invisible, func = func, dirty = true, isDialog=true}

	local double_p = ffi.typeof("double[1]")
	local float_p = ffi.typeof("float[1]")
	local int_p = ffi.typeof("int[1]")
	local bool_p = ffi.typeof("bool[1]")
	
	for i,v in ipairs(vars) do
		if v[3] == guitypes.val or v[3] == guitypes.dial then
			v[4] = v[4] or {}
			if ffi.istype("float[1]",v[2]) then
				pointers[v[1]] = v[2]
			else
				pointers[v[1]] = float_p(v[2])
			end
			defs[v[1]] = {default= v[2],type=v[3],args=v[4]}
		elseif v[3] == guitypes.drag then
			v[4] = v[4] or {}
			local size, sizeN = 1,""
			if type(v[2])=="table" then --is array
				pointers[v[1]] = farray(v[2])
				size = #v[2]
				sizeN = tostring(size)
			else
				pointers[v[1]] = float_p(v[2])
			end
			if v[4] and v[4].olddrag then
				defs[v[1]] = {default= v[2],type=v[3],args=v[4], size=size, sizeN=sizeN}
			else
				defs[v[1]] = {default= v[2],type=v[3],args=v[4], size=size, sizeN=sizeN,MVE = gui.MultiValueEdit(v[1],size)}
			end
		elseif v[3] == guitypes.color then
			local size, sizeN = 1,""
			if type(v[2])=="table" then --is array
				pointers[v[1]] = farray(v[2])
				size = #v[2]
				sizeN = tostring(size)
			end
			assert(size ==3 or size == 4,"size for color must be 3 or 4")
			defs[v[1]] = {default= v[2],type=v[3],args=v[4], size=size, sizeN=sizeN}
		elseif v[3] == guitypes.valint then
			v[4] = v[4] or {}
			if ffi.istype("int[1]",v[2]) then
				pointers[v[1]] = v[2]
			else
				pointers[v[1]] = int_p(v[2])
			end
			defs[v[1]] = {default= v[2],type=v[3],args=v[4]}
		elseif v[3] == guitypes.toggle then
			pointers[v[1]] = bool_p(v[2])
			defs[v[1]] = {default= v[2],type=v[3],args=v[4]}
		elseif v[3] == guitypes.button then
			defs[v[1]] = {default= v[2],type=v[3]}
		elseif v[3] == guitypes.combo then
			pointers[v[1]] = int_p(v[2])
			local items = ffi.new("const char*[?]",#v[4])
			for i,v in ipairs(v[4]) do
				items[i-1] = ffi.new("const char*",v)
			end
			defs[v[1]] = {default= v[2],type=v[3],args=v[4],items=items,n_items=#v[4]}
		elseif v[3] == guitypes.slider_enum then
			pointers[v[1]] = int_p(v[2])
			--local items = ffi.new("const char*[?]",#v[4])
			for i,v in ipairs(v[4]) do
				--items[i-1] = ffi.new("const char*",v)
			end
			defs[v[1]] = {default= v[2],type=v[3],args=v[4],items=items,n_items=#v[4]}
		elseif v[3] == guitypes.curve then
			v[4] = v[4] or {numpoints=10,LUTsize=720}
			local siz_def = #v[2]/2
			assert(siz_def==math.floor(siz_def))
			local numpoints = v[4].numpoints or 10
			numpoints = math.max(numpoints,siz_def + 1)
			local LUTsize = v[4].LUTsize or 720
			local pressed_on_modified = v[4].pressed_on_modified
			local curve = gui.Curve(v[1],numpoints,LUTsize,pressed_on_modified)
			local points = curve.points
			for i=0,siz_def-1 do
				points[i].x = v[2][i*2+1]
				points[i].y = v[2][i*2+2]
			end
			points[siz_def].x = -1
			curve:get_data()
			pointers[v[1]] = points
			defs[v[1]] = {default=v[2],type=v[3],curve=curve,args=v[4]}
		else
			error("unknown guitype",2)
		end
	end
	
	function NM:GetValues()
		local vals = {}
		for k,v in pairs(self.vars) do
			if ffi.istype(farray,self.vars[k]) then
				vals[k] = self.vars[k]:get(v)
			elseif defs[k].type == guitypes.curve then
				vals[k] = defs[k].curve:getpoints()
			else
				vals[k]= self[k] --eq to self.vars[k][0]
			end
		end 
		return vals
	end
	function NM:SetValues(vals)
		if not vals then return end
		for k,v in pairs(vals) do
			if self.vars[k] then
				if self.defs[k].type == guitypes.combo and type(v)=="string" then
					for i,nn in ipairs(self.defs[k].args) do
						if nn==v then v=i-1;break end
					end
				end
				if ffi.istype(farray,self.vars[k]) then
					self.vars[k]:set(v)
				elseif defs[k].type == guitypes.curve then
					defs[k].curve:setpoints(v)
				else
					self.vars[k][0] = v
				end
			end
		end
		self.dirty = true
	end
	function NM:draw()
		--if self.invisible then return end
		if invisible then return end
		--if (imgui.igBegin(name,nil,0)) then
		local namevar
		for i,v in ipairs(vars) do
			local label = v[1]
			if defs[label].invisible then goto NEXTITEM end
			
			if (v[3] == guitypes.button or v[3] == guitypes.toggle or v[3] == guitypes.color) then
				if v[5] and v[5].sameline then ig.SameLine() end
				if v[5] and v[5].separator then ig.Separator() end
			else
				if v[4].sameline then ig.SameLine() end
				if v[4].separator then ig.Separator() end 
			end
			
			if v[3] == guitypes.val then
				local flag = (v[4].power and v[4].power ~=1) and imgui.ImGuiSliderFlags_Logarithmic or imgui.ImGuiSliderFlags_None
				if ig.SliderFloat(v[1], pointers[v[1]], v[4].min, v[4].max, v[4].format or "%.3f",flag) then
					self.dirty = true
					namevar = v[1]
					if v[5] then 
						v[5](pointers[v[1]][0],self) 
					end
				end
			elseif v[3] == guitypes.drag then
				local formatst = v[4].format or "%.3f"
				if v[4] and v[4].olddrag then
					local vspeed = v[4].precission or 0.003
					if defs[v[1]].size > 1 then
						if ig["DragFloat"..defs[v[1]].sizeN](v[1], pointers[v[1]].data,vspeed, v[4].min or ig.FLT_MAX , v[4].max or ig.FLT_MAX , formatst) then
							self.dirty = true
							namevar = v[1]
							if v[5] then 
								v[5](pointers[v[1]],self) 
							end
						end
					else
						if ig.DragFloat(v[1], pointers[v[1]],vspeed, v[4].min, v[4].max, formatst) then
							self.dirty = true
							namevar = v[1]
							if v[5] then 
								v[5](pointers[v[1]],self) 
							end
						end
					end
				else
					local pp = defs[v[1]].size > 1 and pointers[v[1]].data or pointers[v[1]]
					if defs[v[1]].MVE:Draw(pp,v[4].min, v[4].max,v[4].precission or 0.1,formatst,nil) then
						self.dirty = true
						namevar = v[1]
						if v[5] then 
							v[5](pointers[v[1]],self) 
						end
					end
				end
			elseif v[3] == guitypes.color then
				if defs[v[1]].size == 3 then
					if imgui.igColorEdit3(v[1], pointers[v[1]].data, imgui.ImGuiColorEditFlags_Float) then
						self.dirty = true
						namevar = v[1]
						if v[4] then 
							v[4](pointers[v[1]],self) 
						end
					end
				else --4
					if imgui.igColorEdit4(v[1], pointers[v[1]].data, 0) then
						self.dirty = true
						namevar = v[1]
						if v[4] then 
							v[4](pointers[v[1]],self) 
						end
					end
				end
			elseif v[3] == guitypes.valint then
				if ig.SliderInt(v[1], pointers[v[1]], v[4].min, v[4].max, "%.0f") then
					self.dirty = true
					namevar = v[1]
					if v[5] then v[5](pointers[v[1]][0],self) end
				end
			elseif v[3] == guitypes.combo then
				if ig.Combo(v[1],pointers[v[1]], defs[v[1]].items,defs[v[1]].n_items,-1) then
					self.dirty = true
					namevar = v[1]
					if v[5] then
						v[5](pointers[v[1]][0],self)
					end
				end
			elseif v[3] == guitypes.slider_enum then
				if ig.SliderInt(v[1],pointers[v[1]], 1,defs[v[1]].n_items,defs[v[1]].args[pointers[v[1]][0]]) then
					self.dirty = true
					namevar = v[1]
					if v[5] then
						v[5](pointers[v[1]][0],self)
					end
				end
			elseif  v[3] == guitypes.dial then
				if ig.dial(v[1], pointers[v[1]], 20, v[4] and v[4].fac) then
					self.dirty = true
					namevar = v[1]
					if v[5] then 
						v[5](pointers[v[1]][0],self) 
					end
				end
			elseif v[3] == guitypes.toggle then
				if gui.ToggleButton(v[1],pointers[v[1]]) then
				--if ig.Checkbox(v[1],pointers[v[1]]) then 
					self.dirty = true
					namevar = v[1]
					if v[4] then
						v[4](pointers[v[1]][0],self)
					end 
				end
			elseif v[3] == guitypes.button then
				if imgui.igSmallButton(v[1]) then
					self.dirty = true
					namevar = v[1]
					if type(v[4])=="function" then 
						v[4](self)
					end
				end
			elseif v[3] == guitypes.curve then
				local curve = defs[v[1]].curve
				if curve:draw() then
					if type(v[5])=="function" then 
						v[5](curve,self)
					end
					self.dirty = true
				end
			end
			::NEXTITEM::
		end
		
		if self.func then self:func(namevar) end
		if self.KF_dialog then self.KF_dialog() end
	end
	
	function NM:KeyFramer(doqueue,edit,use_spline)
		if self.KF then print(self.name, "already has KeyFramer"); return end
		self.KF = gui.KeyFramer(self,use_spline)
		self.KF.edit[0] = edit or false
		if doqueue then self.KF:queue() end
		return self.KF
	end
---[[	
	local NM_mt = {}
	function NM_mt.__index(t,k)
		--if ffi.istype(float_p,pointers[k]) or ffi.istype(int_p,pointers[k]) then
		if pointers[k] then
			--if ffi.istype("float[3]",pointers[k]) then
			if defs[k].size and defs[k].size > 1 then
				return pointers[k].data
			end
			return pointers[k][0]
		end
		return nil
	end
	
	NM = setmetatable(NM,NM_mt)
--]]	
	return NM
end

function gui.DialogBox(name,autosaved)
	local DB = {name=name,dialogs={},isDBox=true}
	function DB:add_dialog(D, dontremove)
		--quitar de imguimodals
		assert(D.name)
		if self.GL then --if was created with GL:DialogBox
		for i,v in ipairs(self.GL.imguimodals) do
			if v == D then
				table.remove(self.GL.imguimodals,i)
				break;
			end
		end
		end
		D.dboxed = true
		table.insert(self.dialogs,D)
	end
	function DB:Dialog(...)
		local D = gui.Dialog(...)
		table.insert(self.dialogs,D)
		return D
	end
	function DB:draw()
		for i,D in ipairs(self.dialogs) do
			if ig.CollapsingHeader(D.name) then
				ig.Indent(5)
				ig.PushID(D.name)
				D.collapsed = false
				D:draw()
				ig.PopID()
				ig.Unindent(5)
			else
				D.collapsed = true
			end
		end
		if self.func then self:func() end
	end
	if autosaved then
		function DB:GetValues()
			local vals = {}
			for i,D in ipairs(self.dialogs) do
				print(self.name,"DB:Getvalues on",D.name,D.plugin and D.plugin.save)
				if D.plugin and D.plugin.save then
					vals[D.name] = D.plugin:save()
				else
					vals[D.name] = D:GetValues()
				end
			end
			return vals
		end
		function DB:SetValues(pars)
			for i,D in ipairs(self.dialogs) do
				if pars[D.name] then
					if D.plugin and D.plugin.load then
						print(self.name,"Dbox call load on",D.name)
						D.plugin:load(pars[D.name])
					else
						print(self.name,"Dbox call setvalues on",D.name)
						D:SetValues(pars[D.name])
						if D.plugin and D.plugin.update then
							D.plugin:update()
						end
					end
				else
					print("DBox SetValues no values for",D.name)
				end
			end
			return vals
		end
	end
	return DB
end
function gui.FontIcons(GL,source,ranges,size)
	local path = require"anima.path"
	local fontpath = path.chain(path.animapath(),"fonts","fontawesome-webfont.ttf")
	source = source or fontpath
	--ranges = ranges or ffi.new("ImWchar[3]",{0xf000,0xf2e0,0})
	ranges = ranges or ffi.new("ImWchar[3]",{0xf000,0xf0a7,0})
	size = size or 16
	local FAicons = {source=source,size=size,ranges=ranges}
	
	function FAicons:LoadFont()
		FAicons.atlas = ig.GetIO().Fonts
		local fnt_cfg = ig.ImFontConfig()
		fnt_cfg.PixelSnapH = true
		fnt_cfg.OversampleH = 1
		FAicons.font = FAicons.atlas:AddFontFromFileTTF(source, size, fnt_cfg,ranges)
		assert(FAicons.font~=nil,"could not load font!!!")
		--self.font:SetFallbackChar(self.ranges[0])
	end
	function FAicons:Button(cp,ID)
		--local glyph = self.font:FindGlyphNoFallback(cp + self.ranges[0])
		--if glyph==nil then print("bad codepoint",cp);return false end
		local glyph = self.font:FindGlyph(cp + self.ranges[0])
		ID = ID or tostring(cp)
		ig.PushID(ID)
		local ret = ig.ImageButton(self.atlas.TexID,ig.ImVec2(self.size,self.size),ig.ImVec2(glyph.U0,glyph.V0),ig.ImVec2(glyph.U1,glyph.V1),  -1, ig.ImVec4(0,0,0,0), ig.ImVec4(1,1,1,1));
		ig.PopID()
		return ret
	end
	
	function FAicons:GetCursors(cps)
		
		cps = cps or {hand=166,glass=2,glass_p=14,glass_m=16}
		self.cursorcps = cps
		
		-- local img = ffi.new("unsigned char[?]",self.atlas.TexWidth * self.atlas.TexHeight * 4)
		-- gl.glBindTexture(glc.GL_TEXTURE_2D,ffi.cast("GLuint",self.atlas.TexID))
		-- gl.glGetTexImage(glc.GL_TEXTURE_2D,0,glc.GL_RGBA,glc.GL_UNSIGNED_BYTE,img);
		print("atlas data",FAicons.atlas.TexWidth,FAicons.atlas.TexHeight)
		--local imgp = ffi.new("unsigned char*[1]")
		local wi = ffi.new("int[1]")
		local hi = ffi.new("int[1]")
		--self.atlas:GetTexDataAsRGBA32(imgp,wi,hi)
		local atlas = ig.GetIO().Fonts
		
		local img = ffi.cast("unsigned char*",atlas.TexPixelsRGBA32)
		--print("wi,hi",wi[0],hi[0])
		--local img = imgp[0]

		local cursors = {}
		
		for k,cp in pairs(cps) do
			local glyph = self.font:FindGlyph(cp + self.ranges[0])
			assert(glyph~=nil,"no glyph!!")
			local basex = math.floor(glyph.U0*self.atlas.TexWidth)
			local basey = math.floor(glyph.V0*self.atlas.TexHeight)
			local width = math.floor((glyph.U1-glyph.U0)*self.atlas.TexWidth)
			local height = math.floor((glyph.V1-glyph.V0)*self.atlas.TexHeight)
			print("glyph data",width,height,self.atlas.TexWidth,self.atlas.TexHeight)
			
			if not GL.SDL then
				local image = ffi.new("GLFWimage")
				image.width = width
				image.height = height
				image.pixels = ffi.new("unsigned char[?]",width*height*4)
				--
				for i=0,width-1 do
					for j = 0,height-1 do
						for p=0,3 do
							image.pixels[(i + j*width)*4 + p] = img[(basex+i + (basey+j)*self.atlas.TexWidth)*4 + p]
						end
					end
				end
				cursors[k] = glfw.glfwCreateCursor(image, 0, 0);
				assert(cursors[k]~=nil,"glfwCreateCursor failed")
			else --SDL
				--local surface = sdl.createRGBSurface(0, width, height, 32, 0, 0, 0, 0);
				local surface = sdl.C.SDL_CreateRGBSurfaceWithFormat(0, width, height, 32, sdl.PIXELFORMAT_ABGR8888)
				local pitch = surface.pitch
				--local formato = surface.format
				
				local pixels = ffi.cast("unsigned char*",surface.pixels)
				print("surface.pixels",pixels,pitch)
				-- print(formato.format,sdl.PIXELFORMAT_RGBA8888,formato.palette, formato.BitsPerPixel, formato.BytesPerPixel)
				-- for k,v in pairs(sdl) do
					-- if formato.format == v then print("format",k); break end
				-- end
				for i=0,width-1 do
					for j = 0,height-1 do
						for p=0,3 do
							--pixels[(i + j*width)*4 + p] = img[(basex+i + (basey+j)*self.atlas.TexWidth)*4 + p]
							pixels[i*4 + j*pitch + p] = img[(basex+i + (basey+j)*self.atlas.TexWidth)*4 + p]
						end
					end
				end
				cursors[k] = sdl.createColorCursor(surface,0,0)
				sdl.freeSurface(surface)
				assert(cursors[k]~=nil,"sdl.createColorCursor failed")
			end
		end

		return cursors
	end
	
	return FAicons
end --FAicons

local function strconcat(...)
	local str=""
	for i=1, select('#', ...) do
		str = str .. tostring(select(i, ...)) .. "\t"
	end
	str = str .. "\n"
	return str
	-- return table.concat({...},'\t') .. "\n"
end

function gui.SetImGui(GL)
	if GL.SDL then
		ig = require"imgui.sdl"
	else
		ig = require"imgui.glfw"
	end
	imgui = ig.lib
	------now in LuaJIT-ImGui
	gui.Curve = ig.Curve
	gui.dial = ig.dial
	gui.pad = ig.pad
	gui.Plotter = ig.Plotter
	-----------------------
	local W = require"anima.igwidgets"
	for k,v in pairs(W) do
		assert(not gui[k],"gui already open")
		gui[k] = v
	end
	-------------------------
	GL.imguimodals =  {}
	GL.presetmanaged =  {}
	
	if GL.use_log then
		GL.Log = ig.Log()
		GL.luaprint = print
		print = function(...) GL.Log:Add(strconcat(...)) end
	end
	
	
	local KFsaver = gui.FileBrowser(nil,{check_existence=true,filename="KEYFRAMERS",key="save_keyframes"},function(filename)  
		local nms = {}
		local str = {}
		for k,v in ipairs(GL.keyframers) do
			table.insert(nms,v.parent.name)
			table.insert(str,v:serialize_str()) 
		end
	
		table.insert(str,"KEYFRAMERS = {}\n")
		for i,v in ipairs(nms) do
			table.insert(str,"KEYFRAMERS['"..v.."'] = "..v.."\n")
		end
		table.insert(str,"return KEYFRAMERS")
		print(table.concat(str))
	
		--local file,err = io.open(path.chain(path.this_script_path(),"KEYFRAMERS"),"w")
		local file,err = io.open(filename,"w")
		if not file then print(err); return end
		file:write(table.concat(str))
		file:close()
	end)

	local KFloader = gui.FileBrowser(nil,{filename="KEYFRAMERS",key="load_keyframes"},function(filename)  
			--local func,err = loadfile(path.chain(path.this_script_path(),"KEYFRAMERS"))
			local func,err = loadfile(filename)
			if not func then print(err); return end
			local KFs = func()
			for k,v in ipairs(GL.keyframers) do
				if KFs[v.parent.name] then
					v:MakeAnim(KFs[v.parent.name])
					print("loading ", v.parent.name)
				end
			end
	end)
	
	
	local PresetSaver = gui.FileBrowser(nil,{check_existence=true,filename="preset",key="save_preset"},function(filename)
		local nms = {}
		local str = {}
		for k,v in ipairs(GL.imguimodals) do
			table.insert(nms,v.name)
			--for kk,vv in pairs(v) do print(kk) end
			if v.plugin and v.plugin.save then
				print("svaing :save",v.name)
				table.insert(str,serializeTable(v.name,v.plugin:save())) 
			else
				print("saving :getvalues",v.name)
				table.insert(str,serializeTable(v.name,v:GetValues()))
			end
		end
		
		for k,v in ipairs(GL.presetmanaged) do
			table.insert(nms,v.name)
			--for kk,vv in pairs(v) do print(kk) end
			if v.plugin and v.plugin.save then
				print("svaing :save",v.name)
				table.insert(str,serializeTable(v.name,v.plugin:save())) 
			else
				print("saving :getvalues",v.name)
				table.insert(str,serializeTable(v.name,v:GetValues()))
			end
		end
	
		table.insert(str,"PRESET = {}\n")
		for i,name in ipairs(nms) do
			table.insert(str,"PRESET['"..name.."'] = "..name.."\n")
		end
		table.insert(str,"return PRESET")
		--prtable(str)
	
		local file,err = io.open(filename,"w")
		if not file then print(err); return end
		file:write(table.concat(str))
		file:close()
	end)
	
	function GL:preset_load(fname,doerror)
		local func,err = loadfile(fname)
		if not func then print(err); if doerror then error"" end return end
		local NMs = func()
		--prtable("NMs",NMs)
		for k,v in ipairs(GL.imguimodals) do
			if NMs[v.name] then
				--prtable("NMs[v.name]",NMs[v.name])
				if v.plugin and v.plugin.load then
					print("plugin.load",v.name)
					v.plugin:load(NMs[v.name])
				else
					print("setvalues",v.name)
					v:SetValues(NMs[v.name])
					if v.plugin and v.plugin.update then
						v.plugin:update()
					end
				end
			end
		end
		for k,v in ipairs(GL.presetmanaged) do
			print("presermanaged",v.name)
			if NMs[v.name] then
				--prtable("NMs[v.name]",NMs[v.name])
				if v.plugin and v.plugin.load then
					print("plugin.load",v.name)
					v.plugin:load(NMs[v.name])
				else
					print("setvalues",v.name)
					v:SetValues(NMs[v.name])
					if v.plugin and v.plugin.update then
						v.plugin:update()
					end
				end
			end
		end
	end
	
	local PresetLoader =  gui.FileBrowser(nil,{filename="preset",key="load_preset"},function(filename)
			GL:preset_load(filename)
	end)
	GL.PresetLoader = PresetLoader
	local curr_notmodal = 1
	function GL:set_initial_curr_notmodal()
		for i,v in ipairs(self.imguimodals) do
			if not v.invisible then curr_notmodal=i end
		end
	end
	local maxx_needed = 0
	function GL:draw_imgui_not_modal()
		maxx_needed = math.max(300,math.min(ig.GetIO().DisplaySize.x,maxx_needed))
		if #self.imguimodals < 1 then return end
		--ig.SetNextWindowSize(ig.ImVec2(maxx_needed,0))--, imgui.ImGuiCond_Once)
		maxx_needed = 0
		--ig.SetNextWindowSizeConstraints(ig.ImVec2(200,200),ig.ImVec2(ig.GetIO().DisplaySize.x,-1))
		--if ig.Begin("params",nil,bit.bor(imgui.ImGuiWindowFlags_AlwaysAutoResize,imgui.ImGuiWindowFlags_HorizontalScrollbar)) then
		ig.SetNextWindowSizeConstraints(ig.ImVec2(250,-1),ig.ImVec2(ig.FLT_MAX,ig.FLT_MAX))
		if ig.Begin("params",nil,imgui.ImGuiWindowFlags_AlwaysAutoResize) then
			if #GL.keyframers > 0 then
				--imgui.igColumns(3, nil, false)
				if ig.Button("KF save") then KFsaver.open() end
				KFsaver.draw()
				ig.SameLine(0,-1)
				if ig.Button("KF load") then KFloader.open() end
				KFloader.draw()
				ig.SameLine(0,-1)
			end
			if GL.use_presets then
				if ig.SmallButton("NM save") then PresetSaver.open() end
				PresetSaver.draw()
				ig.SameLine()
				if ig.SmallButton("NM load") then PresetLoader.open() end
				PresetLoader.draw()
			end
			local style = ig.GetStyle()
			--local window_visible_x2 = ig.GetWindowPos().x + ig.GetWindowContentRegionMax().x
			local window_visible_x2 =   ig.GetIO().DisplaySize.x -- - ig.GetWindowPos().x
			local last_button_x2 = 0
			---[[
			for i,v in ipairs(self.imguimodals) do
				if not v.invisible then 
					local dopop = false
					if i == curr_notmodal then
						ig.PushStyleColor(imgui.ImGuiCol_Button, ig.ImVec4(1,0,0,1)); dopop = true
					end
					
					local button_szx = ig.CalcTextSize(v.name).x + 2*style.FramePadding.x
					maxx_needed = maxx_needed + button_szx + style.ItemSpacing.x
					local next_button_x2 = last_button_x2 + style.ItemSpacing.x + button_szx;
					if (next_button_x2 < window_visible_x2) then 
						if i>1 then ig.SameLine(0,1) end
					end
					if (ig.Button(v.name)) then curr_notmodal = i end
					if dopop then ig.PopStyleColor(1); end
					last_button_x2 = ig.GetItemRectMax().x;
				end
			end
			ig.Separator();
			self.imguimodals[curr_notmodal]:draw()
			--]]
			--[[ TabBar
			if ig.BeginTabBar("MyTabBar",0) then
				for i,v in ipairs(self.imguimodals) do
					if ig.BeginTabItem(v.name) then
						v:draw()
						ig.EndTabItem()
					end
				end
				ig.EndTabBar()
			end
			--]]
		end
		ig.End()
	end
	GL.show_imgui = true
	
	local function MainDockSpace1()
		if not GL.has_imgui_viewport then return end
		if (bit.band(ig.GetIO().ConfigFlags , imgui.ImGuiConfigFlags_DockingEnable)==0) then return end
		
		--ig.GetIO().ConfigDockingWithShift=true
		local window_flags = 0--bit.bor(ig.lib.ImGuiWindowFlags_MenuBar , );
        window_flags = bit.bor(window_flags, ig.lib.ImGuiWindowFlags_NoDocking, ig.lib.ImGuiWindowFlags_NoTitleBar, ig.lib.ImGuiWindowFlags_NoCollapse, ig.lib.ImGuiWindowFlags_NoResize, ig.lib.ImGuiWindowFlags_NoMove)
        window_flags = bit.bor(window_flags, ig.lib.ImGuiWindowFlags_NoBringToFrontOnFocus, ig.lib.ImGuiWindowFlags_NoNavFocus)
		--if (dockspace_flags & ImGuiDockNodeFlags_PassthruCentralNode)
        window_flags = bit.bor(window_flags, ig.lib.ImGuiWindowFlags_NoBackground)
		
		local viewport = ig.GetMainViewport();
        ig.SetNextWindowPos(viewport:GetWorkPos());
        ig.SetNextWindowSize(viewport:GetWorkSize());
        ig.SetNextWindowViewport(viewport.ID);
		
        ig.PushStyleVar(ig.lib.ImGuiStyleVar_WindowRounding, 0.0);
        ig.PushStyleVar(ig.lib.ImGuiStyleVar_WindowBorderSize, 0.0);
		ig.PushStyleVar(ig.lib.ImGuiStyleVar_WindowPadding, ig.ImVec2(0.0, 0.0));
		ig.Begin("anima DockSpace", nil, window_flags);
		ig.PopStyleVar();
		ig.PopStyleVar(2);
		
		local dockspace_id = ig.GetIDStr("anima MyDockSpace");
		local dockspace_flags = bit.bor(ig.lib.ImGuiDockNodeFlags_NoDockingInCentralNode, ig.lib.ImGuiDockNodeFlags_AutoHideTabBar, ig.lib.ImGuiDockNodeFlags_PassthruCentralNode, ig.lib.ImGuiDockNodeFlags_NoTabBar, ig.lib.ImGuiDockNodeFlags_HiddenTabBar) --ImGuiDockNodeFlags_NoSplit
		ig.DockSpace(dockspace_id, ig.ImVec2(0.0, 0.0), dockspace_flags);
		ig.End()
	end
	
	local function MainDockSpace()
		if not GL.has_imgui_viewport then return end
		if (bit.band(ig.GetIO().ConfigFlags , imgui.ImGuiConfigFlags_DockingEnable)==0) then return end
		
		local dockspace_flags = bit.bor(ig.lib.ImGuiDockNodeFlags_NoDockingInCentralNode, ig.lib.ImGuiDockNodeFlags_AutoHideTabBar, ig.lib.ImGuiDockNodeFlags_PassthruCentralNode, ig.lib.ImGuiDockNodeFlags_NoTabBar, ig.lib.ImGuiDockNodeFlags_HiddenTabBar) --ImGuiDockNodeFlags_NoSplit
		ig.DockSpaceOverViewport(nil, dockspace_flags);
	end
	
	function GL:postdraw() 
		if GL.show_imgui then

			GL:makeContextCurrent()
			

			self.Impl:NewFrame()
			
			MainDockSpace()

			if self.Log then self.Log:Draw() end
		
			self:draw_imgui_not_modal()

			if self.imgui then self:imgui() end

			self.transport:draw()

			self.Impl:Render()
			
			gl.glGetError() --TODO: REMOVE after Ati Radeon bug is solved https://github.com/ocornut/imgui/issues/2519

			if self.postimgui then self.postimgui() end

			--viewport branch
			if GL.has_imgui_viewport then
				local igio = ig.GetIO()
				if bit.band(igio.ConfigFlags , ig.lib.ImGuiConfigFlags_ViewportsEnable) ~= 0 then
					ig.UpdatePlatformWindows();
					ig.RenderPlatformWindowsDefault();
					GL:makeContextCurrent()
				end
			end

		else
			self.FPScounter:fps(os.clock())
		end
	end
	local function printAtlas(at)
		print("atlas print--------------")
		--print(at.GlyphRangesBuilder.UsedChars)
		--print(at.CustomRect)
		print(at.Flags)
		print(at.TexID)
		print(at.TexDesiredWidth)
		print(at.TexGlyphPadding)
		print(at.TexPixelsAlpha8)
		print(at.TexPixelsRGBA32)
		print(at.TexWidth)
		print(at.TexHeight)
		print(at.TexUvScale)
		print(at.TexUvWhitePixel)
		print(at.Fonts)
		print(at.CustomRects)
		print(at.ConfigData)
		print"atlas print end--------------------"
		--int CustomRectIds[1];
	end
	local rangescyr
	function GL.set_imgui_fonts(imguifontloader)
		print[[set_imgui_fonts------------------]]
		local FontsAt = ig.GetIO().Fonts

		--FontsAt:AddFontDefault()
		---[=[
		local fnt_cfg = ig.ImFontConfig()
		fnt_cfg.PixelSnapH = false
		fnt_cfg.OversampleH = 1
		fnt_cfg.OversampleV = 1
		rangescyr = FontsAt:GetGlyphRangesCyrillic()
		print("FontsAt:GetGlyphRangesCyrillic()",rangescyr,ffi.sizeof(rangescyr))
		local totranges = 0
		for i=0,10000,2 do
			if rangescyr[i]==0 or rangescyr[i+1]==0 then break end
			totranges = totranges + rangescyr[i+1] - rangescyr[i] + 1
		end
		print("totranges",totranges)
		local path = require"anima.path"
		local fontpath = path.chain(path.animapath(),"fonts","ProggyTiny.ttf")
		local theFONT = FontsAt:AddFontFromFileTTF(fontpath, 10,fnt_cfg,rangescyr)
		--local theFONT = FontsAt:AddFontFromFileTTF([[C:\luaGL\gitsources\Fonts\Anonymous-Pro\Anonymous_pro.ttf]],12,fnt_cfg,rangescyr)
		assert(theFONT ~= nil)
		--theFONT.DisplayOffset.y = theFONT.DisplayOffset.y +1
		imgui.igGetIO().FontDefault = theFONT
		--]=]
		if imguifontloader then imguifontloader() end
		GL.Ficons:LoadFont() 
		--FyndGlyph in GetCursors needs frame to work!!
		print"Fonts"
		local cfg_data = FontsAt.ConfigData
		for i=0,cfg_data.Size-1 do
			print(i,ffistr(cfg_data.Data[i].Name))
		end

		print[[set_imgui_fonts end ------------------]]
		GetGLError"set_imgui_fonts"
	end

	function GL:SetKeyFramers(doedit,use_spline)
		for i,v in ipairs(GL.imguimodals) do
			if not v.KF then
				v:KeyFramer(true,doedit,use_spline)
			end
		end
	end
	local repeated_names = {}
	local function number_name(name)
		name = name or "un"
		name = name:gsub("%s","_") --TODO deberian evitarse numeros al final de nombre
		for i,v in ipairs(GL.imguimodals) do
			if v.name == name then
				repeated_names[name] = 1 + (repeated_names[name] or 0)
				name = name .. "" .. repeated_names[name]
				return name
			end
		end
		return name
	end
	function GL:Dialog(name,def,func,invisible)
		name = number_name(name)
		local NM = gui.Dialog(name,def,func,invisible)
		self.imguimodals[#self.imguimodals + 1] = NM
		NM.GL = self
		return NM
	end
	function GL:DialogBox(name,autosaved)
		name = number_name(name)
		local DB = gui.DialogBox(name,autosaved)
		self.imguimodals[#self.imguimodals + 1] = DB
		DB.GL = self
		return DB
	end
end --SetImGui

function gui.Histogram(GL,bins,linear)
	local Histogram1 = require"anima.plugins.histogram"(GL,bins)
	local histovalues = ffi.new("float[?]",bins)
	local linearhistovalues = ffi.new("float[?]",bins)
	local maxval = ffi.new("float[1]",1)
	local automaxval = ffi.new("bool[1]",true)
	local showlinear = ffi.new("bool[1]",linear or false)
	local frame = 0
	return function()
		if ig.Begin("histogram") then
			if frame > 10 then
				Histogram1:set_texture(GL.fbo:GetTexture())
				Histogram1:calc()
				--Histogram1.fbohist:get_pixels(glc.GL_RED,glc.GL_FLOAT,0,histovalues)
				if GL.SRGB then
					Histogram1.fbohist:get_pixels(glc.GL_RED,glc.GL_FLOAT,0,linearhistovalues)
					for i=0,bins-1 do
						local gm_bin 
						if not showlinear[0] then gm_bin = math.pow(i/(bins-1),2.4)*(bins-1) else gm_bin = i end
						histovalues[i] = linearhistovalues[gm_bin]
					end
				else
					Histogram1.fbohist:get_pixels(glc.GL_RED,glc.GL_FLOAT,0,histovalues)
				end
				frame = 0
			end
			frame = frame + 1
			ig.Checkbox("automax",automaxval)
			ig.SameLine()
			ig.Checkbox("showlinear",showlinear)
			ig.SameLine()
			ig.SliderFloat("max", maxval, 0, 0.1, "%0.4f");
			if automaxval[0] then maxval[0] = ig.FLT_MAX end 
			ig.PushItemWidth(-1)
			ig.PlotLines("histo", histovalues, bins, 0, nil, 0,maxval[0], ig.ImVec2(0,200));
			ig.PopItemWidth()
		end
		ig.End()
	end, Histogram1
end


return gui