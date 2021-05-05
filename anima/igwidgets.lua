local W = {}

local function IM_COL32(a,b,c,d)
	return ig.U32(a/255,b/255,c/255,d/255)
end
function W.ToggleButton(str_id, v)
    local p = ig.GetCursorScreenPos();
    local draw_list = ig.GetWindowDrawList();

    local height = ig.GetFrameHeight();
    local width = height * 1.55;
    local radius = height * 0.50;
	
	local ret = false
    if (ig.InvisibleButton(str_id, ig.ImVec2(width, height))) then
        v[0] = not v[0]
		ret = true
	end
    local col_bg;
    if (ig.IsItemHovered()) then
        col_bg = v[0] and ig.GetColorU32(ig.lib.ImGuiCol_ButtonHovered) or IM_COL32(218-20, 218-20, 218-20, 255);
    else
        col_bg = v[0] and ig.GetColorU32(ig.lib.ImGuiCol_Button) or IM_COL32(218, 218, 218, 255);
	end
	
    draw_list:AddRectFilled(p, ig.ImVec2(p.x + width, p.y + height), col_bg, height * 0.5);
    draw_list:AddCircleFilled(ig.ImVec2(v[0] and (p.x + width - radius) or (p.x + radius), p.y + radius), radius - 1.5, IM_COL32(255, 255, 255, 255));
	ig.SameLine();ig.Text(str_id)
	return ret
end

function W.SingleValueEdit()
        local JogDialStates = 
        {
            Inactive=0,
            Dialing=1,
            StartedTextInput=2,
            TextInput=3,
        }
		
		local function IsNaN(v) return v~=v end		
		--local InputEditStateFlags = {ResetToDefault=0,Finished=1,Started=2,Modified=3,Nothing=4}
        local InputEditStateFlags = {ResetToDefault=false,Finished=false,Started=false,Modified=true,Nothing=false}

		local SVE = {_state = JogDialStates.Inactive, _jogDialText = "", _numberFormat = "%.3f"}
		
		function SVE:FormatValueForButton(value)
            return string.format(self._numberFormat, value);
		end

		function SVE:SetState(newState)
            if newState == JogDialStates.Inactive then
                    self._activeJogDialId = 0;
			elseif newState == JogDialStates.Dialing then
                    self._center = ig.GetMousePos();
            -- elseif newState == JogDialStates.StartedTextInput then
                    --break;
            -- elseif newState == JogDialStates.TextInput then
                    --break;
            end
            self._state = newState;
        end
		
		--- A horrible ImGui work around to have button that stays active while its label changes.  
        function SVE:DrawButtonWithDynamicLabel(label, size)
            --local color1 = ig.GetColorU32(ig.lib.ImGuiCol_Text);
            --local keepPos = ig.GetCursorScreenPos();
            --ig.Button("##dial"..tostring(self), size);
            --ig.GetWindowDrawList():AddText(keepPos + ig.ImVec2(4, 4), color1, label);
			ig.SetNextItemWidth(size.x)
			local ttt = ffi.new("char[20]",label)
			ig.InputText("##dial"..tostring(self),ttt,20,ig.lib.ImGuiInputTextFlags_ReadOnly)
        end
		
		function SVE:DrawInt(value, min, max, scale, size)
			local doubleValue = ffi.new("int[1]",value[0])
            local result = self:Draw(doubleValue, min, max, scale, "%.0f", size);
            value[0] = doubleValue[0];
            return result;
		end
        function SVE:Draw(value, min, max, scale, format, size)
			size = size or ig.CalcTextSize("xxx.xxx") + ig.GetStyle().FramePadding*2
            min = min or (- ig.FLT_MAX)
			max = max or (ig.FLT_MAX)
			scale = scale or 1
			format = format or "%.3f" 
			self._numberFormat = format;
			
			local iog = ig.GetIO();
            local id = ig.GetID("jog"..tostring(self));
            if (id == self._activeJogDialId) then

                if self._state == JogDialStates.Dialing then
                        ig.PushStyleColor(ig.lib.ImGuiCol_Button, ig.U32(0,0,0,1));
                        ig.PushStyleColor(ig.lib.ImGuiCol_ButtonHovered, ig.U32(0,0,0,1));
                        ig.PushStyleColor(ig.lib.ImGuiCol_ButtonActive, ig.U32(0,0,0,1));
                        self:DrawButtonWithDynamicLabel(self:FormatValueForButton(self._editValue), size);
                        ig.PopStyleColor(3);

                        if (ig.IsMouseReleased(0)) then
                            local wasClick = ig.GetIO().MouseDragMaxDistanceSqr[0] < 4;
                            if (wasClick) then
                                if (iog.KeyCtrl) then
                                    self:SetState(JogDialStates.Inactive);
                                    return InputEditStateFlags.ResetToDefault;
                                else
                                    self:SetState(JogDialStates.StartedTextInput);
                                end
                            else
                                self:SetState(JogDialStates.Inactive);
                            end
                        elseif (ig.IsItemDeactivated()) then
                            self:SetState(JogDialStates.Inactive);
                        else
							self:JogDialOverlayDraw(iog, min, max, scale);
                        end

                elseif self._state == JogDialStates.TextInput or self._state ==  JogDialStates.StartedTextInput then
						if self._state ==  JogDialStates.StartedTextInput then
							ig.SetKeyboardFocusHere();
							self:SetState(JogDialStates.TextInput);
						end
                        ig.PushStyleColor(ig.lib.ImGuiCol_Text, IsNaN(self._editValue)
                                                                and ig.U32(1,0,0,1)
                                                                or ig.U32(1,1,1,1));
                        ig.SetNextItemWidth(size.x);
						local ttt = ffi.new("char[20]",self._jogDialText or "")
						local tinput = false
                        if ig.InputText("##dialInput"..tostring(self), ttt, 20) then
							self._jogDialText = ffi.string(ttt)
							tinput = true
						end
                        ig.PopStyleColor();

                        if (ig.IsItemDeactivated()) then
                            self:SetState(JogDialStates.Inactive);
                            if (IsNaN(self._editValue)) then
                                self._editValue = self._startValue;
							end
                        end

                        self._editValue = tonumber(self._jogDialText) or 0;
						if tinput then
							self._startValue = self._editValue
							value[0] = self._editValue;
							return true
						end
                end

                value[0] = self._editValue;
                if (self._state == JogDialStates.Inactive) then
                    return InputEditStateFlags.Finished;
                end

                self._editValue = math.floor((self._editValue * 1000) + 0.5) / 1000;
                return math.abs(self._editValue - self._startValue) > 0.0001 and InputEditStateFlags.Modified or InputEditStateFlags.Started;
            end

            self:DrawButtonWithDynamicLabel(self:FormatValueForButton(value[0]), size);
            --if (ig.IsItemActivated()) then
			 if (ig.IsItemClicked()) then
                self._activeJogDialId = id;
                self._editValue = value[0];
                self._startValue = value[0];
                self._jogDialText = self:FormatValueForButton(value[0]);
                self:SetState(JogDialStates.Dialing);
            end

            return InputEditStateFlags.Nothing;
        end

        -- Draws a circular dial to manipulate values with various speeds
        function SVE:JogDialOverlayDraw(iog, min, max, scale)
			local SegmentWidth = 90;
            local NeutralRadius = 10;
            local RadialIndicatorSpeed = (2 * math.pi / 20);
            local Padding = 2;

            local SegmentSpeeds = {
                                   (0.15 / math.pi),
                                   (10 * 0.5 / math.pi)}

            local SegmentColor = ig.U32(1, 1, 1, 0.2);
            local ActiveSegmentColor = ig.U32(1, 1, 1, 0.2);
 
                local foreground = ig.GetForegroundDrawList();
                ig.SetMouseCursor(ig.lib.ImGuiMouseCursor_Hand);

                local pLast = iog.MousePos - iog.MouseDelta - self._center;
                local pNow = iog.MousePos - self._center;

                local distanceToCenter = math.sqrt(pNow.x*pNow.x+pNow.y*pNow.y) --pNow.Length();

                local r = NeutralRadius;
                local activeSpeed = 0;

                local rot = math.fmod((self._editValue - self._startValue) * RadialIndicatorSpeed, 2 * math.pi);

				for index, segmentSpeed in ipairs(SegmentSpeeds) do
                    local isLastSegment = (index == #SegmentSpeeds)
                    local isActive =
                        (distanceToCenter > r and distanceToCenter < r + SegmentWidth) or
                        (isLastSegment and distanceToCenter > r + SegmentWidth);

                    if (isActive) then
                        activeSpeed = segmentSpeed;
                        local opening = 3.14 * 1.75;

                        foreground:PathArcTo(
                                             self._center,
                                             r + SegmentWidth / 2,
                                             rot,
                                             rot + opening,
                                              64);
                        foreground:PathStroke(ActiveSegmentColor, false, SegmentWidth - Padding);
                    else
                    
                        foreground:AddCircle(self._center,
                                              r + SegmentWidth / 2,
                                             SegmentColor,
                                              64,
                                              SegmentWidth - Padding);
                    end

                    r = r + SegmentWidth;
                    index = index + 1
                end

                local aLast = math.atan2(pLast.x, pLast.y);
                local aNow = math.atan2(pNow.x, pNow.y);
                local delta = aLast - aNow;
                if (delta > 1.5) then
                    delta = delta - (2 * math.pi);
                elseif (delta < -1.5) then
                    delta = delta + (2 * math.pi);
                end

                --delta = math.floor((delta * 50)+0.5) / 50;
				if iog.KeyCtrl then activeSpeed = activeSpeed*0.1 end
                self._editValue = self._editValue + delta * activeSpeed * scale * 100;
                self._editValue = math.min(max, math.max(min,self._editValue))
            end
       
        
	return SVE
end

function W.MultiValueEdit(label,n)
	local MVE = {}
	for i=1,n do MVE[i] = W.SingleValueEdit() end
	
	function MVE:Draw(val,...)
		local ret = false
		for i=1,n do 
			local ret1 = MVE[i]:Draw(val + (i-1),...); ig.SameLine() 
			ret = ret or ret1
		end
		ig.Text(label)		
		return ret
	end
	return MVE
end

return W