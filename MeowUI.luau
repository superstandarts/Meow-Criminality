return function(WindUI, configure)
	assert(type(configure) == "function", "MeowUI requires configure(WindUI, Library)")
	local UIS = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local Library = {
		Options = {},
		Toggles = {},
		Controls = {},
		WindUI = WindUI,
		Initialized = false,
		Unloaded = false,
		CallbackErrorCount = 0,
		DPIScale = 100,
	}
	local connections, unloadCallbacks, keyPickers = {}, {}, {}
	local containers, nativeTabs, createdElements, elementParents = {}, {}, {}, {}
	local nativeWindow, overlay, cursor, keybindText
	local initialToggleKey
	local customCursor, toggleKeybind = false, nil
	local cursorModified, originalMouseIcon = false, nil
	local destroyStarted, destroying, destroyCallbacksRun = false, false, false
	local destroyCallbacks = {}
	local picking, pickedInput, pickedKey
	local scaleWarning = false
	local Control = {}
	Control.__index = Control
	local Container = {}
	Container.__index = Container
	local modifierGroups = {
		Ctrl = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl },
		Shift = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift },
		Alt = { Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt },
	}

	local function invoke(callback, ...)
		if callback then
			local ok, err = pcall(callback, ...)
			if not ok then
				Library.CallbackErrorCount += 1
				warn("[MeowUI] " .. tostring(err))
			end
		end
	end

	local function same(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then return a == b end
		for key, value in pairs(a) do
			if b[key] ~= value then return false end
		end
		for key, value in pairs(b) do
			if a[key] ~= value then return false end
		end
		return true
	end

	local function keyName(value)
		if typeof(value) == "EnumItem" then value = value.Name end
		if value == "MouseLeft" or value == "MouseLeftButton" or value == "MB1" then return "MB1" end
		if value == "MouseRight" or value == "MouseRightButton" or value == "MB2" then return "MB2" end
		if value == "MouseMiddle" or value == "MouseMiddleButton" or value == "MB3" then return "MB3" end
		if type(value) ~= "string" or value == "None" or value == "Unknown" then return "None" end
		local ok, key = pcall(function() return Enum.KeyCode[value] end)
		return ok and key and key.Name or "None"
	end

	local function nativeKey(value)
		if value == "MB1" then return "MouseLeft" end
		if value == "MB2" then return "MouseRight" end
		if value == "MB3" then return "MouseMiddle" end
		return value
	end

	local function inputKey(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then return keyName(input.KeyCode) end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then return "MB1" end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MB2" end
		if input.UserInputType == Enum.UserInputType.MouseButton3 then return "MB3" end
		return "None"
	end

	local function modifierKeys(name)
		if modifierGroups[name] then return modifierGroups[name] end
		local normalized = keyName(name)
		if normalized ~= "None" and normalized:sub(1, 2) ~= "MB" then return { Enum.KeyCode[normalized] } end
		return nil
	end

	local function normalizeModifiers(modifiers)
		local result = {}
		for _, name in ipairs(modifiers or {}) do
			assert(type(name) == "string" and modifierKeys(name), "Invalid key modifier")
			table.insert(result, name)
		end
		return result
	end

	local function modifiersDown(control)
		for _, name in ipairs(control.Modifiers) do
			local down = false
			for _, key in ipairs(modifierKeys(name) or {}) do
				if UIS:IsKeyDown(key) then down = true; break end
			end
			if not down then return false end
		end
		return true
	end

	local function updateToggleKey()
		if not nativeWindow or Library.Unloaded then return end
		local value = toggleKeybind and toggleKeybind.Value
		local key
		if value and value ~= "None" and value:sub(1, 2) ~= "MB" and #toggleKeybind.Modifiers == 0 and not picking then
			key = Enum.KeyCode[value]
		end
		if not toggleKeybind and not picking then key = initialToggleKey end
		nativeWindow:SetToggleKey(key)
	end

	local function updateKeybinds()
		if not keybindText or Library.Unloaded then return end
		local lines = {}
		for _, picker in ipairs(keyPickers) do
			if not picker.NoUI and picker.Value ~= "None" then
				local prefix = #picker.Modifiers > 0 and table.concat(picker.Modifiers, "+") .. "+" or ""
				table.insert(lines, "[" .. prefix .. picker.Value .. "] " .. picker.Text .. (picker:GetState() and "  [ON]" or ""))
			end
		end
		keybindText.Text = #lines > 0 and table.concat(lines, "\n") or "No keybinds assigned"
	end

	local function restoreCursor()
		if cursorModified then
			if UIS.MouseIconEnabled == false then UIS.MouseIconEnabled = originalMouseIcon end
			cursorModified, originalMouseIcon = false, nil
		end
		if cursor then cursor.Visible = false end
	end

	local function drainNativeSignals()
		local signals = WindUI.Creator and WindUI.Creator.Signals
		if signals then
			for index = #signals, 1, -1 do
				local connection = table.remove(signals, index)
				if connection then pcall(function() connection:Disconnect() end) end
			end
		end
	end

	local function closeDropdown(native)
		if native.__type == "Dropdown" and (native.Opened or native.UIElements.MenuCanvas.Visible) then native:Close() end
	end

	local function rebuildSearch()
		if not nativeWindow or Library.Unloaded then return end
		table.clear(nativeWindow.AllElements)
		for _, tab in ipairs(nativeTabs) do table.clear(tab.Elements) end
		for _, entry in ipairs(createdElements) do
			local native, tab = entry.Native, entry.Tab
			native.Tab = tab
			table.insert(nativeWindow.AllElements, native)
			if tab then table.insert(tab.Elements, native) end
		end
	end

	local function registerElement(native, container, control)
		local entry = { Native = native, Tab = container.Tab, Container = container, Control = control }
		table.insert(createdElements, entry)
		elementParents[native] = entry
		native.Tab = entry.Tab
		if Library.Initialized then rebuildSearch() end
	end

	function Library:GiveSignal(connection)
		if self.Unloaded then
			pcall(function() connection:Disconnect() end)
		else
			table.insert(connections, connection)
		end
		return connection
	end

	function Library:OnUnload(callback)
		assert(type(callback) == "function", "OnUnload requires a function")
		if self.Unloaded then invoke(callback) else table.insert(unloadCallbacks, callback) end
		return self
	end

	function Library:Unload()
		if self.Unloaded then return end
		self.Unloaded = true
		self.Initialized = false
		for index = #connections, 1, -1 do
			local connection = table.remove(connections, index)
			pcall(function() connection:Disconnect() end)
		end
		picking, pickedInput, pickedKey = nil, nil, nil
		for _, picker in ipairs(keyPickers) do
			picker.Native.Picking = false
			picker.Held, picker.HeldInput = false, nil
		end
		for _, callback in ipairs(unloadCallbacks) do invoke(callback) end
		table.clear(unloadCallbacks)
		restoreCursor()
		if overlay then overlay:Destroy() end
		drainNativeSignals()
		if nativeWindow and not nativeWindow.Destroyed and not destroyStarted and not destroying then
			local ok, err = pcall(function() nativeWindow:Destroy() end)
			if not ok then warn("[MeowUI] " .. tostring(err)) end
		end
	end

	function Library:FinishInit()
		if not self.Unloaded then
			rebuildSearch()
			for _, entry in ipairs(createdElements) do
				local control = entry.Control
				if control and control.InitLocked then
					if not control.Disabled then control.Native:Unlock() end
					control.InitLocked = false
				end
			end
			self.Initialized = true
		end
		return self
	end

	function Library:Notify(info)
		if self.Unloaded then return end
		if type(info) == "string" then info = { Description = info } end
		return WindUI:Notify({
			Title = info.Title or "Meow",
			Content = info.Description or info.Content or "",
			Duration = info.Time or info.Duration or 5,
			Icon = info.Icon,
		})
	end

	function Library:SetDPIScale(percent)
		if self.Unloaded then return end
		percent = tonumber(percent)
		if not percent or percent <= 0 or percent ~= percent or percent == math.huge then return end
		self.DPIScale = percent
		if nativeWindow then nativeWindow:SetUIScale(percent / 100) end
		if percent ~= 100 and not scaleWarning then
			scaleWarning = true
			warn("[MeowUI] WindUI scales the root UI, but existing sections and dropdowns retain their captured layout scale.")
		end
	end

	setmetatable(Library, {
		__index = function(_, key)
			if key == "ShowCustomCursor" then return customCursor end
			if key == "ToggleKeybind" then return toggleKeybind end
		end,
		__newindex = function(self, key, value)
			if key == "ShowCustomCursor" then
				if self.Unloaded then return end
				customCursor = value == true
				if not customCursor then restoreCursor() end
			elseif key == "ToggleKeybind" then
				if self.Unloaded then return end
				toggleKeybind = value
				updateToggleKey()
			else
				rawset(self, key, value)
			end
		end,
	})

	function Control:OnChanged(callback)
		assert(type(callback) == "function", "OnChanged requires a function")
		self.Changed = callback
		return self
	end

	function Control:RunChanged()
		if Library.Unloaded or not self.Initialized or self.Disabled then return self end
		if self.Type == "Toggle" then
			for _, attached in ipairs(self.Attached) do
				if attached.Type == "KeyPicker" and attached.SyncToggleState and attached.Mode == "Toggle" then
					attached.Toggled = self.Value
				end
			end
		end
		invoke(self.Callback, self.Value, self.Transparency)
		if not Library.Unloaded then invoke(self.Changed, self.Value, self.Transparency) end
		updateKeybinds()
		return self
	end

	function Control:Normalize(value)
		if self.Type == "Toggle" then return value == true end
		if self.Type == "Slider" then
			value = tonumber(value) or self.Value or self.Min
			if value ~= value then value = self.Min end
			return math.clamp(math.round(math.clamp(value, self.Min, self.Max) / self.Step) * self.Step, self.Min, self.Max)
		end
		if self.Type == "Input" then return tostring(value or "") end
		if self.Type == "KeyPicker" then return keyName(value) end
		if self.Type == "ColorPicker" then
			if typeof(value) == "Color3" then return value end
			return self.Value
		end
		if self.Type == "Dropdown" then
			if not self.Multi then
				if type(value) == "number" then value = self.Values[value] end
				return table.find(self.Values, value) and value or nil
			end
			local selected = {}
			if type(value) == "table" then
				for key, item in pairs(value) do
					local name = item == true and key or (type(key) == "number" and item or nil)
					if type(name) == "number" then name = self.Values[name] end
					if name ~= nil and table.find(self.Values, name) then selected[name] = true end
				end
			end
			return selected
		end
		return value
	end

	function Control:NativeValue()
		if self.Type == "KeyPicker" then return nativeKey(self.Value) end
		if self.Type == "Dropdown" and self.Multi then
			local selected = {}
			for _, value in ipairs(self.Values) do
				if self.Value[value] then table.insert(selected, value) end
			end
			return selected
		end
		return self.Value
	end

	function Control:SuppressNative(action)
		local token = {}
		self.Suppression = token
		local native = self.InitLocked and not self.Disabled and (self.NativeDepth or 0) == 0 and self.Native
		self.NativeDepth = (self.NativeDepth or 0) + 1
		local ok, err = pcall(function()
			if native then native:Unlock() end
			action()
		end)
		if native and self.InitLocked then
			local locked, lockError = pcall(native.Lock, native)
			if not locked and ok then ok, err = false, lockError end
		end
		self.NativeDepth -= 1
		task.defer(function()
			task.defer(function()
				if self.Suppression == token then self.Suppression = nil end
			end)
		end)
		if not ok then error(err, 0) end
	end

	function Control:SetValue(value, mode)
		if Library.Unloaded or self.Disabled then return self end
		local modifiers = self.Modifiers
		if self.Type == "KeyPicker" and type(value) == "table" then
			modifiers = normalizeModifiers(value[3])
			mode, value = value[2], value[1]
		end
		if self.Type == "KeyPicker" and mode then
			assert(mode == "Toggle" or mode == "Hold" or mode == "Always", "Invalid key mode")
			if mode == "Toggle" and self.Mode ~= "Toggle" and self.SyncToggleState then self.Toggled = self.Parent.Value end
			self.Mode = mode
		end
		if self.Type == "KeyPicker" then self.Modifiers = modifiers end
		self.Value = self:Normalize(value)
		self:SuppressNative(function()
			if self.Type == "Dropdown" then
				self.Native:Select(self:NativeValue())
			elseif self.Type == "Toggle" then
				self.Native:Set(self.Value, false)
			elseif self.Type == "ColorPicker" then
				self.Native:Set(self.Value, self.Transparency)
			else
				self.Native:Set(self:NativeValue())
			end
		end)
		if self.Type == "KeyPicker" then self:Update() end
		if self == toggleKeybind then updateToggleKey() end
		return self:RunChanged()
	end

	function Control:SetValueRGB(value, transparency)
		if Library.Unloaded or self.Disabled then return self end
		if transparency ~= nil then self.Transparency = math.clamp(tonumber(transparency) or 0, 0, 1) end
		return self:SetValue(value)
	end

	function Control:SetValues(values)
		if Library.Unloaded or self.Type ~= "Dropdown" then return self end
		self.Values = table.clone(values)
		self.Value = self:Normalize(self.Value)
		self:SuppressNative(function()
			self.Native.Value = self:NativeValue()
			self.Native.Values = table.clone(self.Values)
			self.Native:Refresh(self.Native.Values)
		end)
		return self
	end

	function Control:SetVisible(visible)
		if Library.Unloaded then return self end
		self.Visible = visible == true
		local frame = self.Native.ElementFrame
		if frame then frame.Visible = self.Visible end
		if not self.Visible then closeDropdown(self.Native) end
		for _, attached in ipairs(self.Attached) do attached:SetVisible(self.Visible) end
		return self
	end

	function Control:SetText(text)
		if not Library.Unloaded then
			self.Text = tostring(text)
			self.Native.Title = self.Text
			self.Native:SetTitle(self.Text)
		end
		return self
	end

	function Control:GetState()
		if Library.Unloaded or self.Disabled then return false end
		if self.Mode == "Always" then return true end
		if self.Mode == "Hold" then return self.Held == true end
		return self.Toggled == true
	end

	function Control:Update()
		if Library.Unloaded or self.Type ~= "KeyPicker" or not self.Initialized or self.Disabled then return self end
		local state = self:GetState()
		if self.SyncToggleState and self.Parent.Value ~= state then self.Parent:SetValue(state) end
		updateKeybinds()
		return self
	end

	local function makeControl(container, id, kind, config, parent)
		assert(not Library.Unloaded, "MeowUI is unloaded")
		config = config or {}
		local control = setmetatable({
			Type = kind,
			ID = id,
			Text = config.Text or config.Title or id or kind,
			Callback = config.Callback,
			UIOnly = config.UIOnly == true or kind == "Label" or kind == "Image" or kind == "Divider" or kind == "Button",
			Disabled = config.Disabled == true or (parent and parent.Disabled == true) or false,
			Initialized = false,
			Visible = config.Visible ~= false,
			InitLocked = not Library.Initialized and kind ~= "Label" and kind ~= "Image" and kind ~= "Divider",
			Parent = parent,
			Container = container,
			Attached = {},
			Multi = config.Multi == true,
			Values = table.clone(config.Values or {}),
			Min = config.Min or 0,
			Max = config.Max or 100,
			Step = 10 ^ -(config.Rounding or 0),
			Transparency = config.Transparency,
			Mode = config.Mode or "Toggle",
			Modifiers = kind == "KeyPicker" and normalizeModifiers(config.Modifiers) or {},
			SyncToggleState = config.SyncToggleState == true and parent ~= nil and parent.Type == "Toggle",
			NoUI = config.NoUI == true,
			Toggled = config.Toggled == true or (config.Toggled == nil and parent ~= nil and parent.Type == "Toggle" and parent.Value == true),
			Held = false,
		}, Control)
		control.Value = kind == "ColorPicker" and config.Default or nil
		control.Value = control:Normalize(config.Default)
		local nativeConfig = {
			Title = control.Text,
			Desc = config.Tooltip,
			Locked = control.Disabled,
			Value = control:NativeValue(),
			Callback = function(value, transparency)
				if Library.Unloaded or not Library.Initialized or not control.Initialized or control.Disabled then return end
				if kind == "KeyPicker" or control.Suppression then return end
				value = control:Normalize(value)
				if same(value, control.Value) and (transparency == nil or transparency == control.Transparency) then return end
				control.Value = value
				if transparency ~= nil then control.Transparency = transparency end
				control:RunChanged()
			end,
		}
		control:SuppressNative(function()
			if kind == "Dropdown" then
				nativeConfig.Values = table.clone(control.Values)
				nativeConfig.Multi = control.Multi
				nativeConfig.AllowNone = control.Multi or config.AllowNull == true
				control.Native = container.Native:Dropdown(nativeConfig)
			elseif kind == "Slider" then
				nativeConfig.Value = { Min = control.Min, Max = control.Max, Default = control.Value }
				nativeConfig.Step = control.Step
				if config.Suffix then nativeConfig.Desc = (config.Tooltip and config.Tooltip .. "\n" or "") .. "Unit: " .. config.Suffix end
				control.Native = container.Native:Slider(nativeConfig)
			elseif kind == "Input" then
				nativeConfig.Placeholder = config.Placeholder
				control.Native = container.Native:Input(nativeConfig)
			elseif kind == "ColorPicker" then
				nativeConfig.Default = control.Value
				nativeConfig.Transparency = control.Transparency
				control.Native = container.Native:Colorpicker(nativeConfig)
			elseif kind == "KeyPicker" then
				assert(control.Mode == "Toggle" or control.Mode == "Hold" or control.Mode == "Always", "Invalid key mode")
				nativeConfig.CanChange = false
				control.Native = container.Native:Keybind(nativeConfig)
			elseif kind == "Label" or kind == "Image" then
				nativeConfig.Callback = nil
				if kind == "Image" then
					nativeConfig.Title = ""
					nativeConfig.Thumbnail = config.Image
					nativeConfig.ThumbnailSize = config.Height or 130
				end
				control.Native = container.Native:Paragraph(nativeConfig)
			elseif kind == "Button" then
				nativeConfig.Callback = function()
					if not Library.Unloaded and Library.Initialized and control.Initialized and not control.Disabled then invoke(config.Func) end
				end
				control.Native = container.Native:Button(nativeConfig)
			elseif kind == "Divider" then
				control.Native = container.Native:Divider()
			else
				control.Native = container.Native:Toggle(nativeConfig)
			end
			if control.InitLocked then control.Native:Lock() end
		end)
		registerElement(control.Native, container, control)
		control.Initialized = true
		if id then
			Library.Controls[id] = control
			if kind == "Toggle" then Library.Toggles[id] = control else Library.Options[id] = control end
		end
		if parent then table.insert(parent.Attached, control) end
		if kind == "Label" then
			local title = control.Native.ParagraphFrame.UIElements.Title
			title.RichText = true
			if config.DoesWrap ~= nil then title.TextWrapped = config.DoesWrap end
		elseif kind == "Input" and not config.Finished then
			local textbox = control.Native.ElementFrame:FindFirstChildWhichIsA("TextBox", true)
			if textbox then
				Library:GiveSignal(textbox:GetPropertyChangedSignal("Text"):Connect(function()
					if not Library.Unloaded and Library.Initialized and control.Initialized and not control.Suppression and not control.Disabled then
						control.Native:Set(textbox.Text, true)
					end
				end))
			end
		elseif kind == "Image" then
			local frame = control.Native.ParagraphFrame.UIElements.Container
			for _, child in ipairs(frame:GetChildren()) do
				local image = child:FindFirstChild("ImageLabel")
				if image then
					image.ImageTransparency = config.Transparency or 0
					image.ImageColor3 = config.Color or Color3.new(1, 1, 1)
					image.ScaleType = config.ScaleType or Enum.ScaleType.Fit
				end
			end
		elseif kind == "KeyPicker" then
			local native = control.Native
			local originalSet = native.Set
			function native:Set(value)
				if Library.Unloaded or not Library.Initialized or control.Disabled then return end
				if picking == control then
					picking, pickedInput, pickedKey = nil, nil, nil
					self.Picking = false
				end
				control.Value = keyName(value)
				control.Held, control.HeldInput = false, nil
				originalSet(self, nativeKey(control.Value))
				if control == toggleKeybind then updateToggleKey() end
				updateKeybinds()
				if control.NativeDepth == 0 then control:Update(); control:RunChanged() end
			end
			table.insert(keyPickers, control)
			Library:GiveSignal(native.KeybindFrame.UIElements.Main.MouseButton1Click:Connect(function()
				if Library.Unloaded or control.Disabled then return end
				if picking then
					picking.Native.Picking = false
					picking:SuppressNative(function() picking.Native:Set(nativeKey(picking.Value)) end)
				end
				picking, pickedInput, pickedKey = control, nil, nil
				native.Picking = true
				native.UIElements.Keybind.Frame.Frame.TextLabel.Text = "..."
				if nativeWindow then nativeWindow:SetToggleKey(nil) end
			end))
			updateKeybinds()
		end
		control:SetVisible(control.Visible and (not parent or parent.Visible))
		return control
	end

	function Control:AddColorPicker(id, config)
		makeControl(self.Container, id, "ColorPicker", config, self)
		return self
	end

	function Control:AddKeyPicker(id, config)
		makeControl(self.Container, id, "KeyPicker", config, self)
		return self
	end

	function Library.Container(native, tab, parent)
		if containers[native] then return containers[native] end
		local container = setmetatable({ Native = native, Type = "Container", Tab = tab or (native.__type == "Tab" and native) or native.Tab, Parent = parent }, Container)
		containers[native] = container
		if container.Tab == native then
			table.insert(nativeTabs, native)
			local scrollConnection
			function native:ScrollToTheElement(index)
				if Library.Unloaded or self.Locked then return self end
				local element = self.Elements[index]
				local entry = element and elementParents[element]
				if not entry or entry.Tab ~= self or not element.ElementFrame then return self end
				if scrollConnection then scrollConnection:Disconnect() end
				local ancestors, ancestor = {}, entry.Container
				while ancestor and ancestor.Parent do
					table.insert(ancestors, ancestor.Native)
					ancestor = ancestor.Parent
				end
				for position = #ancestors, 1, -1 do ancestors[position]:Open(true) end
				local ticks = 0
				scrollConnection = Library:GiveSignal(RunService.RenderStepped:Connect(function()
					if Library.Unloaded then return end
					ticks += 1
					if ticks < 2 then return end
					scrollConnection:Disconnect()
					scrollConnection = nil
					local frame, scroll = element.ElementFrame, self.UIElements.ContainerFrame
					if not frame.Parent or not frame:IsDescendantOf(scroll) then return end
					local scale = WindUI.UIScaleObj and WindUI.UIScaleObj.Scale or WindUI.UIScale or 1
					local padding = scroll:FindFirstChildOfClass("UIPadding")
					local y = scroll.CanvasPosition.Y + (frame.AbsolutePosition.Y - scroll.AbsolutePosition.Y) / scale - (padding and padding.PaddingTop.Offset or 0)
					local maximum = math.max(0, (scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y) / scale)
					scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, math.clamp(y, 0, maximum))
					if element.Highlight then element:Highlight() end
				end))
				return self
			end
		end
		return container
	end

	function Container:AddToggle(id, config) return makeControl(self, id, "Toggle", config) end
	function Container:AddSlider(id, config) return makeControl(self, id, "Slider", config) end
	function Container:AddDropdown(id, config) return makeControl(self, id, "Dropdown", config) end
	function Container:AddInput(id, config) return makeControl(self, id, "Input", config) end
	function Container:AddImage(id, config) return makeControl(self, id, "Image", config) end
	function Container:AddDivider() return makeControl(self, nil, "Divider", {}) end
	function Container:AddLabel(config)
		if type(config) == "string" then config = { Text = config } end
		return makeControl(self, nil, "Label", config)
	end
	function Container:AddButton(config, callback)
		if type(config) == "string" then config = { Text = config, Func = callback } end
		return makeControl(self, nil, "Button", config)
	end
	function Container:AddLeftGroupbox(name, icon)
		assert(not Library.Unloaded, "MeowUI is unloaded")
		local native = self.Native:Section({ Title = name, Icon = icon, Box = true, Opened = true })
		registerElement(native, self)
		return Library.Container(native, self.Tab, self)
	end
	Container.AddRightGroupbox = Container.AddLeftGroupbox
	function Container:AddTabbox()
		local parent = self
		return {
			AddTab = function(_, name)
				return parent:AddLeftGroupbox(name)
			end,
		}
	end

	Library:GiveSignal(UIS.InputBegan:Connect(function(input, processed)
		if Library.Unloaded or not Library.Initialized then return end
		local value = inputKey(input)
		if picking then
			if value == "None" then return end
			pickedKey = value == "Escape" and "None" or value
			pickedInput = input
			return
		end
		if value == "None" or UIS:GetFocusedTextBox() then return end
		for _, control in ipairs(keyPickers) do
			if control.Value == value and not control.Disabled and not control.Native.Picking and modifiersDown(control) then
				if control == toggleKeybind then
					if not nativeWindow.ToggleKey and not processed then nativeWindow:Toggle() end
				else
					local previous = control:GetState()
					if control.Mode == "Toggle" then control.Toggled = not control.Toggled end
					if control.Mode == "Hold" then control.Held, control.HeldInput = true, input end
					control:Update()
					if not control.SyncToggleState and previous ~= control:GetState() then invoke(control.Callback, control:GetState()) end
				end
			end
		end
	end))
	Library:GiveSignal(UIS.InputEnded:Connect(function(input)
		if Library.Unloaded or not Library.Initialized then return end
		if picking and input == pickedInput then
			local control, value = picking, pickedKey
			picking, pickedInput, pickedKey = nil, nil, nil
			control.Native.Picking = false
			control.Native:Set(nativeKey(value))
			updateToggleKey()
		end
		for _, control in ipairs(keyPickers) do
			if control.Held and (input == control.HeldInput or not modifiersDown(control)) then
				control.Held, control.HeldInput = false, nil
				control:Update()
				if not control.SyncToggleState then invoke(control.Callback, false) end
			end
		end
	end))

	function Library:CreateWindow(info)
		assert(not self.Unloaded and not nativeWindow, "MeowUI requires one live window")
		initialToggleKey = info.ToggleKeybind
		if not WindUI.Themes.Meow then
			local theme = table.clone(WindUI.Themes.Dark)
			theme.Name = "Meow"
			theme.Accent = Color3.fromHex("191919")
			theme.Background = Color3.fromHex("0f0f0f")
			theme.Outline = Color3.fromHex("282828")
			theme.Text = Color3.fromHex("ffffff")
			theme.Primary = Color3.fromHex("a0a0a0")
			theme.Toggle, theme.Slider, theme.Checkbox = theme.Primary, theme.Primary, theme.Primary
			WindUI:AddTheme(theme)
		end
		nativeWindow = WindUI:CreateWindow({
			Title = info.Title,
			Icon = info.Icon,
			IconSize = typeof(info.IconSize) == "UDim2" and info.IconSize.X.Offset or info.IconSize,
			Author = info.Footer,
			Theme = "Meow",
			Folder = "Meow",
			Size = info.Size,
			MinSize = Vector2.new(560, 350),
			MaxSize = Vector2.new(1000, 800),
			Resizable = info.Resizable,
			HideSearchBar = info.DisableSearch == true,
			ToggleKey = info.ToggleKeybind,
			OpenButton = { Title = info.Title, Icon = info.Icon, Enabled = true },
		})
		assert(nativeWindow, "WindUI did not create a window")
		WindUI:SetTheme("Meow")
		self.NativeWindow = nativeWindow
		if self.DPIScale ~= 100 then nativeWindow:SetUIScale(self.DPIScale / 100) end
		local originalDestroy, originalClose = nativeWindow.Destroy, nativeWindow.Close
		local originalOnDestroy = nativeWindow.OnDestroyCallback
		if originalOnDestroy then table.insert(destroyCallbacks, originalOnDestroy) end
		function nativeWindow:OnDestroy(callback)
			if destroyCallbacksRun then invoke(callback) else table.insert(destroyCallbacks, callback) end
		end
		nativeWindow.OnDestroyCallback = function()
			destroyStarted = true
			Library:Unload()
			if not destroyCallbacksRun then
				destroyCallbacksRun = true
				for _, callback in ipairs(destroyCallbacks) do invoke(callback) end
				table.clear(destroyCallbacks)
			end
			drainNativeSignals()
		end
		function nativeWindow:Close()
			if self.Destroyed or (Library.Unloaded and not destroying) then return end
			for _, entry in ipairs(createdElements) do closeDropdown(entry.Native) end
			local close = originalClose(self)
			local originalCloseDestroy = close.Destroy
			function close:Destroy()
				if destroyStarted then return end
				destroyStarted = true
				Library:Unload()
				return originalCloseDestroy(self)
			end
			return close
		end
		function nativeWindow:Destroy()
			if destroyStarted or destroying or self.Destroyed then return end
			destroying = true
			Library:Unload()
			local ok, result = pcall(originalDestroy, self)
			destroying = false
			if not ok then error(result, 0) end
			return result
		end
		local originalOpen, originalToggle = nativeWindow.Open, nativeWindow.Toggle
		function nativeWindow:Open()
			if not Library.Unloaded and not self.Destroyed then return originalOpen(self) end
		end
		function nativeWindow:Toggle()
			if not Library.Unloaded and not self.Destroyed then return originalToggle(self) end
		end
		overlay = Instance.new("ScreenGui")
		overlay.Name = "MeowUI/Widgets"
		overlay.ResetOnSpawn = false
		overlay.IgnoreGuiInset = true
		overlay.DisplayOrder = math.max(WindUI.ScreenGui.DisplayOrder + 1, 100)
		overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		overlay.Parent = WindUI.ScreenGui.Parent
		local frame = Instance.new("Frame")
		frame.Name = "Keybinds"
		frame.AnchorPoint = Vector2.new(1, 0)
		frame.Position = UDim2.new(1, -16, 0, 120)
		frame.Size = UDim2.fromOffset(230, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.BackgroundColor3 = Color3.fromHex("191919")
		frame.BackgroundTransparency = 0.1
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = overlay
		self.KeybindFrame = frame
		local padding = Instance.new("UIPadding")
		padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
		padding.Parent = frame
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = frame
		local heading = Instance.new("TextLabel")
		heading.BackgroundTransparency = 1
		heading.Size = UDim2.new(1, 0, 0, 18)
		heading.Font = Enum.Font.Code
		heading.TextSize = 16
		heading.TextColor3 = Color3.new(1, 1, 1)
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.Text = "Keybinds"
		heading.Parent = frame
		keybindText = heading:Clone()
		keybindText.Size = UDim2.new(1, 0, 0, 0)
		keybindText.AutomaticSize = Enum.AutomaticSize.Y
		keybindText.TextSize = 13
		keybindText.TextWrapped = true
		keybindText.LayoutOrder = 1
		keybindText.Parent = frame
		cursor = Instance.new("ImageLabel")
		cursor.Name = "CustomCursor"
		cursor.BackgroundTransparency = 1
		cursor.Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png"
		cursor.Size = UDim2.fromOffset(32, 32)
		cursor.AnchorPoint = Vector2.new(0.5, 0.5)
		cursor.ZIndex = 100
		cursor.Visible = false
		cursor.Parent = overlay
		self.ShowCustomCursor = info.ShowCustomCursor == true
		updateKeybinds()
		updateToggleKey()
		self:GiveSignal(RunService.RenderStepped:Connect(function()
			if Library.Unloaded then return end
			local main = nativeWindow.UIElements.Main
			local visible = customCursor and UIS.MouseEnabled and not nativeWindow.Closed and not nativeWindow.Destroyed and main.Visible
			if visible then
				cursor.Position = UDim2.fromOffset(UIS:GetMouseLocation().X, UIS:GetMouseLocation().Y)
				cursor.Visible = true
				if not cursorModified and UIS.MouseIconEnabled then
					originalMouseIcon = UIS.MouseIconEnabled
					cursorModified = true
					UIS.MouseIconEnabled = false
				end
			else
				restoreCursor()
			end
		end))
		local window = { Native = nativeWindow }
		function window:AddTab(name, icon)
			assert(not Library.Unloaded, "MeowUI is unloaded")
			local tab = nativeWindow:Tab({ Title = name, Icon = icon })
			return Library.Container(tab, tab)
		end
		return window
	end

	local ThemeManager, SaveManager = configure(WindUI, Library)
	return Library, ThemeManager, SaveManager
end
