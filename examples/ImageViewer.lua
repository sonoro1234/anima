require"anima"
local lfs = require"lfs_ffi"
--print("setlocale",
assert(os.setlocale(".UTF8"))
if jit.os=="Windows" then os.execute("chcp 65001");assert(lfs.unicode) end
local C = ffi.C

------------- plugins ---------------------------------

local plugins_chain = {}
local plugins_chain_dirty = false

local plugins = {
"LABfxW2",
"local_histogramStarkLabCORE",
"gaussianblur2",
"gaussianblur3",
"liquid",
"ColorKmeans",
"extrudecolor",
"photofx",
"watercolor4",
"unsharp_mask",
}

local plugins_chain_p = {}
local chain_slab
local chain_fbo

local function MakeChainFBO(GL,n)
	local ch = {}
	ch[0] = GL:initFBO({no_depth=true})
	for i=1,n do
		ch[i] = GL:initFBO({no_depth=true})
	end
	return ch
end



local function SetPluginsChain(GL)
	if plugins_chain_dirty == false then return end
	print("========= SetPluginsChain ===========================")
	if plugins_chain_dirty > 0 then --add plugin
		print("add plugin",plugins_chain_dirty,#plugins_chain,plugins_chain[#plugins_chain])
		assert(plugins_chain_dirty==#plugins_chain)
		local plugin = require("anima.plugins."..plugins_chain[#plugins_chain])
		if type(plugin) == "function" then
			plugin = plugin(GL)
		elseif type(plugin) == "table" then
			plugin = plugin.make(GL)
			assert(getmetatable(plugin))
		else
			error"bad plugin"
		end
		--plugin:init()
		GL:init_plugins()
		plugins_chain_p[#plugins_chain] = plugin
		GL:DirtyWrap(plugin)
	elseif plugins_chain_dirty < 0 then --delete plugin
		print("delete plugin",-plugins_chain_dirty,#plugins_chain_p)
		local plugin = plugins_chain_p[-plugins_chain_dirty]
		-- delete plugin
		for i,pl in ipairs(GL.plugins) do
			if pl == plugin then
				table.remove(GL.plugins,i)
				break
			end
		end
		-- delete imguimodals
		if plugin.NM then
			for i,NM1 in ipairs(GL.imguimodals) do
				if NM1 == plugin.NM then
					table.remove(GL.imguimodals,i)
					break
				end
			end
		end
		--plugins_chain_p[-plugins_chain_dirty] = nil
		table.remove(plugins_chain_p, -plugins_chain_dirty)
	--else -- reorder
	end

	chain_fbo = MakeChainFBO(GL, #plugins_chain_p)
	plugins_chain_dirty = false

	print("========= end SetPluginsChain ===========================")
end

local anchor = {}
local chain_active = ffi.new("bool[?]",1,true)
local function Open_plugins_chain(GL)
	--local dockid = GL.Dock()
	local child_flags = bit.bor(--ig.lib.ImGuiChildFlags_AutoResizeY, ig.lib.ImGuiChildFlags_AutoResizeY, 
ig.lib.ImGuiChildFlags_FrameStyle)
	local p_open = ffi.new("bool[?]",1,true)
	ig.SetNextWindowSizeConstraints(ig.ImVec2(400, 350), ig.ImVec2(600, 450))-- ig.ImVec2(ig.FLT_MAX, ig.FLT_MAX))
	if ig.Begin("plug chains", p_open) then
		--if ig.BeginChild("origin",ig.ImVec2(ig.GetContentRegionAvail().x * 0.5, -1), child_flags) then
		if ig.BeginChild("origin",ig.ImVec2(ig.GetContentRegionAvail().x * 0.5, -ig.GetFrameHeightWithSpacing()*2), child_flags) then
			ig.SeparatorText("Plugins")
			--ig.Separator()
			for i=1,#plugins do
				ig.Selectable(plugins[i])
				if ig.IsItemClicked() then print(i) end
				if ig.BeginDragDropSource(ig.lib.ImGuiDragDropFlags_SourceAllowNullID) then
					anchor.data = ffi.new("int[1]",i)
					ig.SetDragDropPayload("PLUGNM",anchor.data, ffi.sizeof"int")
					ig.Text(plugins[i])
					ig.EndDragDropSource();
				end
			end
		end
		ig.EndChild()
		ig.SameLine()
		if ig.BeginChild("dest",ig.ImVec2(0,-ig.GetFrameHeightWithSpacing()*2),child_flags) then
			ig.SeparatorText("chain (drag plugins)")
			--ig.Separator()
			local canvas_pos = ig.GetCursorScreenPos();
			ig.SetNextItemAllowOverlap()
			ig.InvisibleButton("drop_target",ig.ImVec2(-1,-1))
			if ig.BeginDragDropTarget() then
				local payload = ig.AcceptDragDropPayload("PLUGNM", ig.lib.ImGuiDragDropFlags_SourceAllowNullID)
				if (payload~=nil) then
					assert(payload.DataSize == ffi.sizeof"int");
					local num = ffi.cast("int*",payload.Data)[0]
					table.insert(plugins_chain,plugins[num])
					plugins_chain_dirty = #plugins_chain
				end
				ig.EndDragDropTarget();
			end
			ig.SetCursorScreenPos(canvas_pos)
				for i=1,#plugins_chain do
					--ig.Text(plugins_chain[i])
					ig.Selectable(plugins_chain[i].."##"..i)
					if ig.IsItemClicked() then print(plugins_chain[i]) end
					if ig.BeginDragDropSource(ig.lib.ImGuiDragDropFlags_SourceAllowNullID) then
						anchor.data2 = ffi.new("int[1]",i)
						ig.SetDragDropPayload("PLUGMOVE",anchor.data2, ffi.sizeof"int")
						ig.Text(plugins_chain[i])
						ig.EndDragDropSource();
					end
					if ig.BeginDragDropTarget() then
						local payload = ig.AcceptDragDropPayload("PLUGMOVE", ig.lib.ImGuiDragDropFlags_SourceAllowNullID)
						if (payload~=nil) then
							assert(payload.DataSize == ffi.sizeof"int");
							local num = ffi.cast("int*",payload.Data)[0]
							plugins_chain[i], plugins_chain[num] = plugins_chain[num],plugins_chain[i]
							plugins_chain_p[i], plugins_chain_p[num] = plugins_chain_p[num],plugins_chain_p[i]
							plugins_chain_dirty = 0 --reorder
						end
						ig.EndDragDropTarget();
					end
				end
		end
		ig.EndChild()
	end
	ig.Selectable("basket")
	if ig.BeginDragDropTarget() then
		local payload = ig.AcceptDragDropPayload("PLUGMOVE", ig.lib.ImGuiDragDropFlags_SourceAllowNullID)
		if (payload~=nil) then
			assert(payload.DataSize == ffi.sizeof"int");
			local num = ffi.cast("int*",payload.Data)[0]
			table.remove(plugins_chain,num)
			plugins_chain_dirty = -num
		end
		ig.EndDragDropTarget();
	end

	gui.ToggleButton("chain active", chain_active)
	ig.SameLine()
	ig.Text("plugins_chain:"..tonumber(#plugins_chain))
	ig.End()

	SetPluginsChain(GL)
	return p_open[0]
end
--------------- thumbnail ------------------
local function ImageFrame(image,sz,pre,selected)
	
	local pre = pre or ""
	local label = pre..image.filename
	local tex = image.tex
	local picked = image.picked
	--print("ImageFrame",label)
	ig.BeginGroup()
	local canvas_pos = ig.GetCursorScreenPos();
	--ig.PushClipRect(canvas_pos, canvas_pos + ig.ImVec2(sz, sz), false)

		--ig.Checkbox(label, picked)
		--ig.SetCursorScreenPos(canvas_pos)
	ig.SetNextItemAllowOverlap()
	local ret = ig.InvisibleButton(label..(tostring(tex.tex)).."t", ig.ImVec2(sz, sz), ig.lib.ImGuiButtonFlags_EnableNav) 
	local is_active = ig.IsItemActive()
	local is_hovered = ig.IsItemHovered()
	local pos,wi,hi
	local draw_list = ig.GetWindowDrawList();
		
	if tex.aspect > 1 then
		hi = sz/tex.aspect
		wi = sz
		pos = ig.ImVec2(0,0.5*(wi-hi))+canvas_pos
	else
		wi = sz*tex.aspect
		hi = sz
		pos = ig.ImVec2(0.5*(hi-wi),0)+canvas_pos
	end

	local bgcolor = selected and ig.U32(0.75,0.75,0.75,1) or ig.U32(0.25,0.25,0.25,1)
	draw_list:AddRectFilled(canvas_pos, canvas_pos + ig.ImVec2(sz, sz), bgcolor,5)
	--draw_list:AddImage( ffi.cast("void*",tex.tex),pos, pos+ig.ImVec2(wi,hi),ig.ImVec2(0,1),ig.ImVec2(1,0));
	draw_list:AddImage( ig.ImTextureRef(tex.tex)[0],pos, pos+ig.ImVec2(wi,hi),ig.ImVec2(0,1),ig.ImVec2(1,0));
	--local labsize = ig.CalcTextSize(label,nil,false)
	--local texpos = ig.ImVec2(canvas_pos.x, canvas_pos.y + sz - labsize.y)
	--draw_list:AddText(texpos,ig.U32(1,1,1,1), label)--, const char* text_end = NULL)
	
		---[[
	ig.SetCursorScreenPos(canvas_pos)
	ig.Checkbox("##"..label, picked)
	local canvas_pos3 = ig.GetCursorScreenPos();
	ig.Dummy(canvas_pos + ig.ImVec2(sz, sz) - canvas_pos3)
	
	--]]
	--ig.PopClipRect()
	ig.EndGroup()
	return ret
end 
-------------------- load_texture --------------------------------
local path = require"anima.path"

local images = {}
local butnum = {} 
-- thumbs size
local size = ffi.new("float[1]",90)
local corut_load
local texture
local curr_tex_name = ""
local curr_image_num
local hist


local function load_texture(filename, GL)
	print("=========== load texture ================")
	texture = GL:Texture()
	local ok = pcall(texture.Load, texture, filename, nil, true)
	if ok then 
		curr_tex_name = filename
		GL:set_WH(texture.width, texture.height)
		--chain_slab = GL:make_slab()
		chain_fbo = MakeChainFBO(GL,#plugins_chain_p)
	end
	print("=========== end load texture ================")
end

local insert = table.insert
local function AddImage(GL,filename, name)
	--print("AddImage",filename)
	local tex = GL:Texture()
	local ok,err = pcall(tex.Load, tex, filename)
	if not ok then print(err); return end
	local image = {picked = ffi.new("bool[1]",false)}
	image.filename = filename
	image.name = name or filename
	local maxsize = math.max(tex.width, tex.height)
	image.tex = tex:resample_fac(300/maxsize)
	tex:delete()
	--print("mmmm",tex.filename)
	insert(images, image)
	butnum[#butnum + 1] = #butnum + 1
	--print("AddImage loaded",filename, butnum[#butnum])
end

local function preparedir(GL,pathdir)

	--delete texs
	--for i,v in ipairs(images) do v.tex:delete() end
	-- images = {}
	-- butnum = {} 
	
	local imagesN = {}
	local imagesFile = {}
	path.funcdir(pathdir,function(f,file)
		--print(f)
		table.insert(imagesN,f) 
		table.insert(imagesFile,file)
	end,{".jpg",".JPG",".tif",".png",".cmp"})
	corut_load = coroutine.create(function()
		for i=1,#imagesN do
			AddImage(GL,imagesN[i], imagesFile[i])
			coroutine.yield()
		end
	end)
	local ret,err = coroutine.resume(corut_load)
	if not ret then print("coroutine error",err) end
end


------------- GLcanvas -------------------------------------
local GL = GLcanvas{H=800,aspect=16/9,SDL=false,use_log=false,profile="CORE"}

local currdir
local fB = gui.FileBrowser(nil,{curr_dir=inipath,choose_dir=true},
	function(f,dir) 
		preparedir(GL,dir)
		currdir = dir
	end)

function GL.drop_file_cb(file)
	print("dropped",file)
	AddImage(GL, file)
end

local help_txt = 
[[
Select folder to create thumnails.
Drop image files to add thumbs.
Click thumb for image edit.
F1 for full screen toggle.
F2 for imgui toggle.
]]
local showhelp = false
local show_chain = false
local view_thumbs = ffi.new("bool[?]",1,true)
local function renderMenuFile(win)
	local openfilepopup = false
    if (ig.BeginMainMenuBar()) then
            if (ig.BeginMenu("File")) then
                if (ig.MenuItem("Load directory")) then
                    openfilepopup = true
                end
                -- if (ig.MenuItem("Save","Ctrl-S")) then
                    -- local doc = opendocs[curr_opendoc]
                    -- doc:Save(doc.file_name)
                -- end
                -- if (ig.MenuItem("Save As")) then
                    -- savefilepopup = true
                -- end
                -- if (ig.MenuItem("Close")) then
                   -- doclosefile = true
                   -- close_doc = curr_opendoc
                -- end
                if (ig.MenuItem("Quit")) then
                    win:quit()
                end
                ig.EndMenu();
            end
			if ig.BeginMenu("thumbs") then
				--ig.Checkbox("thumbnails",view_thumbs)
				gui.ToggleButton("thumbnails",view_thumbs)
				if ig.MenuItem"select all" then
					for i,im in ipairs(images) do
						im.picked[0] = true
					end
				end
				if ig.MenuItem"unselect all" then
					for i,im in ipairs(images) do
						im.picked[0] = false
					end
				end
				if ig.MenuItem"clear unselected" then
					local delete = {}
					local imreorder = {}
					for i,butn in ipairs(butnum) do
						imreorder[i] = images[butn]
					end
					images = imreorder
					for i,im in ipairs(images) do
						if not im.picked[0] then
							table.insert(delete,i)
						end
					end
					for i=#delete,1,-1 do
						table.remove(images,delete[i])
					end
					butnum = {}
					for i,im in ipairs(images) do butnum[i]=i end
				end
					ig.SetNextItemWidth(100)
					ig.DragFloat("size",size)
				ig.EndMenu()
			end
			if ig.BeginMenu("_gc") then
				if ig.MenuItem"Do" then
					print(collectgarbage"count")
					collectgarbage()
					collectgarbage()
					print(collectgarbage"count")
				end
				ig.EndMenu()
			end
			if ig.BeginMenu("plugins") then
				if ig.MenuItem"Edit Chain" then
					show_chain = true
				end
				ig.EndMenu()
			end
			if ig.BeginMenu("Help") then
				showhelp = true
				ig.EndMenu()
			end
            ig.EndMainMenuBar()
        end

    -- if ig.Shortcut(bit.bor(ig.lib.ImGuiMod_Ctrl, ig.lib.ImGuiKey_S)) then
        -- local doc = opendocs[curr_opendoc]
        -- doc:Save(doc.file_name)
    -- end

    if openfilepopup then fB.open() end
    fB.draw()
	
    if showhelp then
        ig.SetNextWindowSize(ig.ImVec2(500,200));
        ig.OpenPopup("Help##p")
        if ig.BeginPopupModal("Help##p") then 
            ig.TextWrapped(help_txt)
            if ig.Button("OK") then
                ig.CloseCurrentPopup()
                showhelp = false
            end
            ig.EndPopup()
        end
    end
	
	if show_chain then
		show_chain = Open_plugins_chain(win)
	end
    -- if savefilepopup then fbs.open() end
    -- fbs.draw()
end

local inipath = [[C:\Users\Carmen\Pictures\Iphone\2014-07-31 Primera Importación]]
inipath = [[c:\luagl\media\montajes]]--\Nueva Carpeta]]
inipath = [[C:\LuaGL\frames_anima\pelis\humanoides_peli\NEVERA\ninos_master1080]]--\Nueva Carpeta]]
--inipath = [[D:\VICTOR\pelis\pelipino\master1080\pies_indios]]
--local lfs = require"lfs_ffi"
--inipath = lfs.win_utf8_to_acp(inipath)
--inipath = path.chain(path.this_script_path(),
--inipath = [[C:\LuaGL\gitsources\anima\examples\LuaJIT-IPOL\opticflow\exports\peli1]]
print(inipath)
currdir = inipath

function GL.init()
	--ListCompressedFormats()
ig.GetIO().IniFilename = nil
            local style = ig.GetStyle()
			local round = 3
            style.FrameRounding = round
            style.GrabRounding = round
            style.WindowRounding = round
            style.FrameBorderSize = 1
	--chain_slab = GL:make_slab()
	chain_fbo = MakeChainFBO(GL,0)
	texture = GL:Texture()
	preparedir(GL,inipath)
end

function GL.Dock()

	local dockspace_chains_id = ig.GetID("dockspace_chains_id")
	local viewport = ig.GetMainViewport();
	
	if (ig.DockBuilderGetNode(dockspace_chains_id) == nil) then
    local dock_id_left = ffi.new("ImGuiID[?]",1,dockspace_chains_id);
	local dock_id_bottom = ffi.new("ImGuiID[?]",1,0);
	ig.DockBuilderAddNode(dock_id_left[0],ig.lib.ImGuiDockNodeFlags_DockSpace);
	ig.DockBuilderSetNodeSize(dock_id_left[0], viewport.Size);
	ig.DockBuilderSplitNode(dock_id_left[0], ig.lib.ImGuiDir_Up, 0.50, dock_id_left, dock_id_bottom);

    ig.DockBuilderDockWindow("plug chains", dock_id_left[0]);
	ig.DockBuilderDockWindow("params", dock_id_bottom[0]);
    ig.DockBuilderFinish(dockspace_chains_id);
	end
	local p_open = ffi.new("bool[?]",1,true)
	ig.Begin("plug chains2",p_open)
	ig.DockSpace(dockspace_chains_id)
	ig.End()
	return dockspace_chains_id
end
local anchor1 ={}

local host_window_flags = bit.bor( --ig.lib.ImGuiWindowFlags_NoTitleBar , 
--ig.lib.ImGuiWindowFlags_NoCollapse,
-- ig.lib.ImGuiWindowFlags_NoResize ,
    --ig.lib.ImGuiWindowFlags_NoMove , 
    --ig.lib.ImGuiWindowFlags_NoBringToFrontOnFocus, --, --ig.lib.ImGuiWindowFlags_NoNavFocus,
    ig.lib.ImGuiWindowFlags_MenuBar
	)
local host_window_flags = bit.bor( ig.lib.ImGuiWindowFlags_NoTitleBar , ig.lib.ImGuiWindowFlags_NoCollapse, ig.lib.ImGuiWindowFlags_NoResize ,
    --ig.lib.ImGuiWindowFlags_NoMove , 
    ig.lib.ImGuiWindowFlags_NoBringToFrontOnFocus)--, --ig.lib.ImGuiWindowFlags_NoNavFocus,
    --ig.lib.ImGuiWindowFlags_MenuBar)
function GL.imgui()
	--ig.ShowDemoWindow()
	--GL.MainDockSpace()
	--GL.Dock()
	--print(ig.DockBuilderGetNode(ig.GetID("main_anima_dockspace")))
	 --print(ig.GetID("main_dock"))
	renderMenuFile(GL)
	if view_thumbs[0] then
	local igio = ig.GetIO()
	ig.SetNextWindowPos(ig.ImVec2(0, ig.GetTextLineHeight()))--ig.GetFrameHeight()))
	ig.SetNextWindowSize(ig.ImVec2(igio.DisplaySize.x,0))
	if ig.Begin("thumbnails", nil, host_window_flags) then
	--renderMenuFile(GL)
	local wsize = ig.GetContentRegionAvail()
	
	-- if ig.SmallButton("load") then
		-- fB:open()
	-- end
	-- fB:draw()
	ig.SameLine()
	ig.Text(currdir)
	-- ig.SetNextItemWidth(200)
    -- ig.DragFloat("size",size)
	--ig.SameLine()
	ig.TextUnformatted(string.format("%s width:%d height:%d aspect %f",curr_tex_name,texture.width,texture.height, texture.aspect))
	local cols = math.floor(wsize.x/(size[0]+ig.GetStyle().ItemSpacing.x))
	--print(wsize.x,cols)
    for i = 1,#butnum do
		local imnum = butnum[i]
		if ImageFrame(images[imnum],size[0],nil,curr_image_num == imnum) then
			--print(imagesN[butnum[i]])
			curr_image_num = imnum
			load_texture(images[imnum].filename, GL)
		end
		if ig.IsItemHovered() then ig.SetTooltip(images[imnum].name) end

        if ig.BeginDragDropSource(ig.lib.ImGuiDragDropFlags_SourceAllowNullID) then
            anchor1.data = ffi.new("int[1]",i)
            ig.SetDragDropPayload("ITEMN",anchor1.data, ffi.sizeof"int")--, C.ImGuiCond_Once);
			ImageFrame(images[imnum],size[0],"drag")
            ig.EndDragDropSource();
        end
        if ig.BeginDragDropTarget() then
            local payload = ig.AcceptDragDropPayload("ITEMN", ig.lib.ImGuiDragDropFlags_SourceAllowNullID)
            if (payload~=nil) then
                assert(payload.DataSize == ffi.sizeof"int");
                local num = ffi.cast("int*",payload.Data)[0]
                local tmp = butnum[num]
                table.remove(butnum,num)
                table.insert(butnum, i,tmp)
            end
            ig.EndDragDropTarget();
        end
        if (((i-1) % cols) < (cols-1)) then ig.SameLine() end
    end

	end
	ig.End()
	end --view_thumbs
	if corut_load and coroutine.status(corut_load)~="dead" then
		local ret,err = coroutine.resume(corut_load)
		if not ret then print("coroutine error",err) end
	end
	
end

function GL.drawOO(t,w,h)
	
	ut.Clear()
	if chain_active[0] then
		chain_slab:init()
		chain_slab:Bind()
		texture:drawcenter()
		chain_slab:UnBind()
		for i,pl in ipairs(plugins_chain_p) do
			chain_slab:Bind()
			pl:process(chain_slab:tex())
			chain_slab:UnBind()
		end
		chain_slab:tex():drawcenter()
	else
		texture:drawcenter()
	end
end
function GL.drawNNN(t,w,h)
	
	ut.Clear()
	if chain_active[0] then
		chain_slab:init()
		chain_slab:Bind()
		texture:drawcenter()
		chain_slab:UnBind()
		for i,pl in ipairs(plugins_chain_p) do
			--chain_slab:Bind()
			pl:process_fbo(chain_slab.pong,chain_slab:tex())
			--chain_slab:UnBind()
			chain_slab:swapt()
		end
		chain_slab:tex():drawcenter()
	else
		texture:drawcenter()
	end
end

function GL.draw(t,w,h)
	
	ut.Clear()
	if chain_active[0] then
		chain_fbo[0]:Bind()
		texture:drawcenter()
		chain_fbo[0]:UnBind()
		for i,pl in ipairs(plugins_chain_p) do
			pl:process_fbo(chain_fbo[i],chain_fbo[i-1]:tex())
		end
		chain_fbo[#chain_fbo]:tex():drawcenter()
	else
		texture:drawcenter()
	end
end

GL:start()