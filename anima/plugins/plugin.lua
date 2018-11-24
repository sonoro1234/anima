local plugin = {}
function plugin.serializer(M)
	assert(M)
	if M.NM then
		M.load = M.load or function(self,pars) 
				M.NM:SetValues(pars)
				if M.update then M:update() end
			end
		M.save = M.save or function() return M.NM:GetValues() end
	end
	local fb = {}
	fb.load = function(filename)
		local func,err = loadfile(filename)
		if not func then print(err); error();return end
		local params = func()
		M:load(params)
	end
	fb.save = function(filename)
		local params = M:save()
		local str = {}
		table.insert(str,serializeTable("params",params))
		table.insert(str,"\nreturn params")
		local file,err = io.open(filename,"w")
		if not file then print(err); return end
		file:write(table.concat(str))
		file:close()
	end
	fb.loader = gui.FileBrowser(nil,{filename="phfx",key="loadps"},fb.load)
	fb.saver = gui.FileBrowser(nil,{check_existence=true,filename="phfx",key="saveps"},fb.save)
	function fb.draw()
		if ig.SmallButton("save") then
			fb.saver.open()
		end
		fb.saver.draw()
		ig.SameLine()
		if ig.SmallButton("load") then
			fb.loader.open()
		end
		fb.loader.draw()
	end
	if M.NM then
		if not M.NM.func then M.NM.func = function() fb.draw() end end
	end
	return fb
end
function plugin.presets(M)
	local ps = {}
	local item = ffi.new"int[1]"
	local items = ffi.new("const char*[10]")
	items[0] = ffi.new("const char*","none")
	ps.names = {}
	ps.data = {}
	--local anchor = {items[0]}
	function ps.draw()
		if ig.SmallButton"add" then
			if #ps.data > 8 then return end
			local params = M:save()
			table.insert(ps.data,params)
			local name = tostring(#ps.data)
			table.insert(ps.names,name)
			local n_item = ffi.new("const char*",name)
			items[#ps.data] = n_item
			item[0] = #ps.data
			--table.insert(anchor,n_item)
		end
		ig.SameLine()
		if ig.Combo("presets", item, items, #ps.data + 1,-1) then
			if item[0] > 0 then
				M:load(ps.data[item[0]])
			end
		end
	end
	return ps
end

function plugin.get_arg(var , timev)
	if type(var)=="table" then
		if(var.is_pointer) then
			return var[0]
		elseif var.is_animatable then
			return var:dofunc(timev)
		else
			return var
		end
	elseif type(var)=="function" then
		return var(timev)
	elseif(ffi.istype("float[1]",var) or ffi.istype("double[1]",var) or ffi.istype("int[1]",var) or ffi.istype("bool[1]",var)) then
		return var[0]
	else
		return var
	end
end

function plugin.get_args(NM,args, timev)
	t = t or {}
	for k,v in pairs(NM.vars) do
		if type(args[k])~="nil" then v[0] = plugin.get_arg(args[k], timev) end
	end
end
function plugin.get_input(t,w,h,args,fbo)
	local theclip = args.clip
	if theclip[1].isTex2D then
		theclip[1]:set_wrap(glc.GL_CLAMP)
		theclip[1]:Bind()
	elseif theclip[1].isSlab then
		theclip[1].ping:GetTexture():Bind()
		theclip[1].pong:Bind()
	else
		fbo:Bind()
		theclip[1]:draw(t, w, h,theclip)
		fbo:UnBind()
		fbo:UseTexture(0)
	end
	return theclip
end
---plugin factory
local pl_mt = {}
pl_mt.__index = {
	process_sl = function(self,slab,srctex)
		srctex = srctex or slab.ping:tex()	
		local w,h = srctex.width,srctex.height
		
		slab.pong:Bind()
		
		self:process(srctex,slab.pong.w,slab.pong.h)
		
		slab.pong:UnBind()
		slab:swapt()
	end,
	process_fbo = function(self,fbo,srctex)
		fbo:Bind()
		self:process(srctex,fbo.w,fbo.h)
		fbo:UnBind()
	end,
	draw = function(self,tim,w,h,args)
		plugin.get_args(self.NM,args, tim)
		local theclip = args.clip
		local srctex
		if theclip[1].isTex2D then
			theclip[1]:set_wrap(glc.GL_CLAMP)
			self:process(theclip[1],w,h)
		elseif theclip[1].isSlab then
			self:process_sl(theclip[1])
		else
			-- self.fbo:Bind()
			-- theclip[1]:draw(tim, w, h,theclip)
			-- self.fbo:UnBind()
			-- self:process(self.fbo:GetTexture(),w,h)
			local fbo = GL:get_fbo()
			fbo:Bind()
			theclip[1]:draw(tim, w, h,theclip)
			fbo:UnBind()
			self:process(fbo:tex(),w,h)
			fbo:release()
		end
	end,
	init = function(self) end,
	IsDirty = function(self)
		--print("IsDirty",self.NM.name,self.NM.isDBox)
		if self.NM.isDBox then
			if self.NM.dirty then return true end
			for i,D in ipairs(self.NM.dialogs) do
				--print(D.name,D.dirty)
				if D.dirty then
					--print("dbox test:",D.name,D.dirty)
					return true 
				end
			end
			return false
		else
			return self.NM.dirty
		end
	end,
	set_texsignature = function(plug,tex)
		if tex then
			if tex.isTex2D then
				if (not plug.texsignature or plug.texsignature~=tex:get_signature()) then
					plug.NM.dirty = true
					plug.texsignature = tex:get_signature()
				end
			else --is simple table
				for i,t in ipairs(tex) do
					if (not plug.texsignatures) or (not plug.texsignatures[i]) or plug.texsignatures[i]~=tex[i]:get_signature() then
						plug.NM.dirty = true
						plug.texsignatures = plug.texsignatures or {}
						plug.texsignatures[i] = tex[i]:get_signature()
					end
				end
			end
		end
	end
	}
	
function plugin.new(o,GL,NM)
	o = o or {res={GL.W,GL.H}}
	o.NM = NM
	o.GL = GL
	if NM then NM.plugin = o end
	return setmetatable(o,pl_mt)
end
return plugin