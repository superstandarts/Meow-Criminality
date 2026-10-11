return function(WindUI, Library)
	local HttpService = game:GetService("HttpService")
	local filesystem = {
		isfile = isfile,
		isfolder = isfolder,
		readfile = readfile,
		writefile = writefile,
		listfiles = listfiles,
		makefolder = makefolder,
		delfile = delfile,
	}
	local controlTypes = { Input = true, ColorPicker = true, Slider = true, Dropdown = true, Toggle = true, KeyPicker = true }
	local defaultOrder = { "Input", "ColorPicker", "Slider", "Dropdown", "Toggle", "KeyPicker" }
	local ThemeManager = { Library = Library, Folder = "Meow", Records = {}, CurrentTheme = "Meow" }
	local SaveManager = {
		Library = Library,
		Folder = "Meow",
		SubFolder = "",
		Ignore = { MenuKeybind = true },
		UseLoadingOrder = true,
		LoadingOrder = table.clone(defaultOrder),
		Ready = false,
	}
	local finishAttempted = false

	local function notify(manager, text)
		local owner = manager.Library
		if owner and owner.Unloaded then return end
		if owner and type(owner.Notify) == "function" then
			local success = pcall(owner.Notify, owner, text)
			if success then return end
		end
		if WindUI and type(WindUI.Notify) == "function" then
			pcall(WindUI.Notify, WindUI, { Title = "Meow", Content = text, Duration = 5 })
		end
	end

	local function safeName(name, reserved)
		if type(name) ~= "string" or #name == 0 or #name > 128 then return false end
		if name ~= name:match("^%s*(.-)%s*$") or name:find('[<>:"/\\|?*%c]') then return false end
		if name == "." or name == ".." or name:sub(-1) == "." then return false end
		local lower = name:lower()
		local stem = lower:match("^[^.]+") or lower
		if stem == "con" or stem == "prn" or stem == "aux" or stem == "nul"
			or stem:match("^com[1-9]$") or stem:match("^lpt[1-9]$") then return false end
		return lower ~= reserved
	end

	local function safeFolder(folder)
		if type(folder) ~= "string" or #folder == 0 or #folder > 512 then return nil end
		folder = folder:gsub("\\", "/")
		if folder:sub(1, 1) == "/" or folder:sub(-1) == "/" or folder:find("//", 1, true) then return nil end
		for part in folder:gmatch("[^/]+") do
			if not safeName(part) then return nil end
		end
		return folder
	end

	local function fsCall(name, ...)
		if type(filesystem[name]) ~= "function" then return false, "Filesystem API unavailable" end
		local success, result = pcall(filesystem[name], ...)
		if not success then return false, "Filesystem operation failed" end
		return true, result
	end

	local function exists(path)
		local success, result = fsCall("isfile", path)
		if not success then return nil, result end
		if type(result) ~= "boolean" then return nil, "Filesystem returned an invalid result" end
		return result
	end

	local function makeTree(path)
		local current = ""
		for part in path:gmatch("[^/]+") do
			current = current == "" and part or current .. "/" .. part
			local success, found = fsCall("isfolder", current)
			if not success then return false, found end
			if type(found) ~= "boolean" then return false, "Filesystem returned an invalid result" end
			if not found then
				local created, result = fsCall("makefolder", current)
				if not created or result == false then return false, "Could not create settings folders" end
			end
		end
		return true
	end

	local function readText(path)
		local found, message = exists(path)
		if found == nil then return nil, message end
		if not found then return nil, "File does not exist" end
		local success, text = fsCall("readfile", path)
		if not success then return nil, text end
		if type(text) ~= "string" or #text > 4194304 then return nil, "File contents are invalid or too large" end
		return text
	end

	local function writeText(folder, filename, text)
		local success, message = makeTree(folder)
		if not success then return false, message end
		local written, result = fsCall("writefile", folder .. "/" .. filename, text)
		if not written or result == false then return false, "Could not write settings file" end
		return true
	end

	local function listNames(folder, reserved)
		local success, found = fsCall("isfolder", folder)
		if not success then return {}, found end
		if type(found) ~= "boolean" then return {}, "Filesystem returned an invalid result" end
		if not found then return {} end
		local listed, files = fsCall("listfiles", folder)
		if not listed or type(files) ~= "table" then return {}, "Could not list settings files" end
		local names, seen = {}, {}
		for _, file in pairs(files) do
			if type(file) ~= "string" then continue end
			file = file:gsub("\\", "/"):gsub("^%./", "")
			if file:find("/../", 1, true) or file:sub(1, 3) == "../" then continue end
			local basename = file:match("([^/]+)$")
			if not basename or basename:sub(-5) ~= ".json" then continue end
			local relative = folder .. "/" .. basename
			if file ~= basename and file:lower() ~= relative:lower()
				and file:sub(-#relative - 1):lower() ~= "/" .. relative:lower() then continue end
			local name = basename:sub(1, -6)
			if safeName(name, reserved) and not seen[name:lower()] then
				local present, message = exists(folder .. "/" .. basename)
				if present == nil then return {}, message end
				if present then
					seen[name:lower()] = true
					table.insert(names, name)
				end
			end
		end
		table.sort(names)
		return names
	end

	local function decode(text)
		if type(text) ~= "string" or #text == 0 or #text > 4194304 then return nil end
		local success, data = pcall(HttpService.JSONDecode, HttpService, text)
		return success and type(data) == "table" and data or nil
	end

	local function encode(data)
		local success, text = pcall(HttpService.JSONEncode, HttpService, data)
		if not success or type(text) ~= "string" then return nil, "Could not encode settings" end
		return text
	end

	local function finite(value)
		return type(value) == "number" and value == value and math.abs(value) < math.huge
	end

	local function color(value)
		if typeof(value) == "Color3" then return value end
		if type(value) ~= "string" then return nil end
		value = value:gsub("^#", "")
		if #value ~= 6 or value:find("[^%x]") then return nil end
		local success, result = pcall(Color3.fromHex, value)
		return success and result or nil
	end

	local function uiControl(owner, group, method, suffix, settings)
		local index = "__Meow" .. suffix
		local sequence = 0
		while (owner.Options and owner.Options[index]) or (owner.Toggles and owner.Toggles[index])
			or (owner.Controls and owner.Controls[index]) do
			sequence += 1
			index = "__Meow" .. suffix .. "_" .. sequence
		end
		settings.UIOnly = true
		local control = group[method](group, index, settings)
		for _, registry in ipairs({ owner.Options or {}, owner.Toggles or {}, owner.Controls or {} }) do
			if registry[index] then registry[index].UIOnly = true end
		end
		if control then control.UIOnly = true end
		return control or (owner.Options and owner.Options[index])
	end

	local function settingsPath(manager)
		return manager.Folder .. "/settings" .. (manager.SubFolder ~= "" and "/" .. manager.SubFolder or "")
	end

	local function getControl(owner, index, kind)
		local registry = kind == "Toggle" and owner.Toggles or owner.Options
		return (registry and registry[index]) or (owner.Controls and owner.Controls[index])
	end

	local function ignored(manager, index, control)
		return manager.Ignore[index] or index == "MenuKeybind" or index:sub(1, 6) == "__Meow" or control.UIOnly == true
	end

	local function parseControl(control, object)
		local kind, value = object.type, object.value
		if control.Type ~= kind then return nil end
		local parsed = {}
		if kind == "Toggle" then
			if type(value) ~= "boolean" then return nil end
			parsed.Value = value
		elseif kind == "Input" then
			if type(object.text) ~= "string" then return nil end
			parsed.Value = object.text
		elseif kind == "Slider" then
			if type(value) ~= "string" and type(value) ~= "number" then return nil end
			value = tonumber(value)
			if not finite(value) then return nil end
			parsed.Value = value
		elseif kind == "Dropdown" then
			local multi = control.Multi == true
			if object.multi ~= nil and (type(object.multi) ~= "boolean" or object.multi ~= multi) then return nil end
			if multi then
				if type(value) ~= "table" then return nil end
				local selected = {}
				for name, enabled in pairs(value) do
					if type(name) ~= "string" or type(enabled) ~= "boolean" then return nil end
					selected[name] = enabled
				end
				parsed.Value = selected
			else
				if value ~= nil and type(value) ~= "string" then return nil end
				parsed.Value = value
			end
		elseif kind == "ColorPicker" then
			parsed.Value = color(value)
			if not parsed.Value then return nil end
			local transparency = object.transparency
			if transparency ~= nil and (not finite(transparency) or transparency < 0 or transparency > 1) then return nil end
			parsed.Transparency = transparency
		elseif kind == "KeyPicker" then
			local key, mode = object.key, object.mode
			if type(key) ~= "string" or (mode ~= "Always" and mode ~= "Hold" and mode ~= "Toggle") then return nil end
			local validKey = key == "None" or key == "MB1" or key == "MB2" or key == "MB3"
			if not validKey then
				local success, item = pcall(function() return Enum.KeyCode[key] end)
				validKey = success and item ~= nil and item ~= Enum.KeyCode.Unknown
			end
			if not validKey then return nil end
			local modifiers = object.modifiers
			if modifiers ~= nil then
				if type(modifiers) ~= "table" then return nil end
				local count = 0
				for index, modifier in pairs(modifiers) do
					if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #modifiers then return nil end
					if type(modifier) ~= "string" or #modifier == 0 or #modifier > 32 or modifier:find("%c") then return nil end
					count += 1
				end
				if count ~= #modifiers then return nil end
				modifiers = table.clone(modifiers)
			end
			if object.toggled ~= nil and type(object.toggled) ~= "boolean" then return nil end
			parsed.Value = { key, mode, modifiers }
			parsed.Toggled = object.toggled
		end
		return parsed
	end

	function SaveManager:SetLibrary(owner)
		self.Library = owner
	end

	function SaveManager:SetFolder(folder)
		local validated = safeFolder(folder)
		if not validated then notify(self, "Invalid settings folder"); return false end
		self.Folder = validated
		return true
	end

	function SaveManager:SetSubFolder(folder)
		local validated = folder == "" and "" or safeFolder(folder)
		if not validated then notify(self, "Invalid settings subfolder"); return false end
		self.SubFolder = validated
		return true
	end

	function SaveManager:SetIgnoreIndexes(indexes)
		if type(indexes) ~= "table" then return false end
		for _, index in ipairs(indexes) do
			if type(index) == "string" then self.Ignore[index] = true end
		end
		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({
			"MainColor", "FontFace", "AccentColor", "OutlineColor", "BackgroundColor", "FontColor", "BackgroundImage",
			"ThemeManager_ThemeList", "ThemeManager_CustomThemeList", "ThemeManager_CustomThemeName", "ThemeManager_ThemeJSON",
			"SaveManager_ConfigName", "SaveManager_ConfigList", "SaveManager_JSON",
		})
	end

	function SaveManager:SetLoadingOrder(enabled, order)
		self.UseLoadingOrder = enabled == true
		if type(order) == "table" then
			self.LoadingOrder = {}
			for _, kind in ipairs(order) do
				if controlTypes[kind] and not table.find(self.LoadingOrder, kind) then table.insert(self.LoadingOrder, kind) end
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local names, message = listNames(settingsPath(self), "autoload")
		if message then notify(self, "Could not refresh presets: " .. message) end
		return names
	end

	function SaveManager:SaveJSON(name)
		local controls = {}
		for _, registry in ipairs({ self.Library.Controls or {}, self.Library.Options or {}, self.Library.Toggles or {} }) do
			for index, control in pairs(registry) do
				if type(index) == "string" and type(control) == "table" then controls[index] = control end
			end
		end
		local indexes = {}
		for index in pairs(controls) do table.insert(indexes, index) end
		table.sort(indexes)
		local data = { timestamp = os.date("%d.%m.%Y %H:%M:%S"), name = name or "", objects = {} }
		for _, index in ipairs(indexes) do
			local control = controls[index]
			local kind = control.Type
			if not controlTypes[kind] or ignored(self, index, control) then continue end
			local object = { type = kind, idx = index }
			if kind == "Input" then
				object.text = control.Value
			elseif kind == "ColorPicker" then
				if typeof(control.Value) ~= "Color3" then return "", false, "A color control has an invalid value" end
				object.value = control.Value:ToHex()
				object.transparency = control.Transparency == nil and 0 or control.Transparency
			elseif kind == "KeyPicker" then
				object.key, object.mode = control.Value, control.Mode
				object.modifiers, object.toggled = control.Modifiers, control.Toggled
			else
				object.value = kind == "Slider" and tostring(control.Value) or control.Value
				if kind == "Dropdown" then object.multi = control.Multi == true end
			end
			if not parseControl(control, object) then return "", false, "A control has an invalid value" end
			table.insert(data.objects, object)
		end
		local text, message = encode(data)
		if not text then return "", false, message end
		return text, true
	end

	function SaveManager:Save(name)
		if not self.Ready or self.Library.Unloaded then return false, "Presets are not ready" end
		if not safeName(name, "autoload") then return false, "Invalid preset name" end
		local text, success, message = self:SaveJSON(name)
		if not success then return false, message end
		return writeText(settingsPath(self), name .. ".json", text)
	end

	function SaveManager:LoadJSON(text)
		if not self.Ready or self.Library.Unloaded then return false, "Presets are not ready" end
		local data = decode(text)
		if not data or type(data.objects) ~= "table" then return false, "Invalid preset JSON" end
		local count = 0
		for index, object in pairs(data.objects) do
			if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #data.objects
				or type(object) ~= "table" then return false, "Invalid preset objects" end
			count += 1
		end
		if count ~= #data.objects then return false, "Invalid preset objects" end
		local pending, skipped = {}, 0
		for position, object in ipairs(data.objects) do
			if type(object.idx) ~= "string" or not controlTypes[object.type] then continue end
			local control = getControl(self.Library, object.idx, object.type)
			if not control or ignored(self, object.idx, control) then continue end
			local parsed = parseControl(control, object)
			local setter = object.type == "ColorPicker" and control.SetValueRGB or control.SetValue
			if not parsed or type(setter) ~= "function" then skipped += 1; continue end
			table.insert(pending, { Control = control, Object = object, Parsed = parsed, Position = position })
		end
		if self.UseLoadingOrder then
			table.sort(pending, function(a, b)
				local aRank = table.find(self.LoadingOrder, a.Object.type) or math.huge
				local bRank = table.find(self.LoadingOrder, b.Object.type) or math.huge
				return aRank == bRank and a.Position < b.Position or aRank < bRank
			end)
		end
		local failed = 0
		for _, entry in ipairs(pending) do
			if self.Library.Unloaded then return false, "Preset loading stopped after unload" end
			local errorsBefore = self.Library.CallbackErrorCount
			local success = pcall(function()
				local control, parsed = entry.Control, entry.Parsed
				if entry.Object.type == "ColorPicker" then
					control:SetValueRGB(parsed.Value, parsed.Transparency)
				else
					control:SetValue(parsed.Value)
				end
				if entry.Object.type == "KeyPicker" then
					if parsed.Value[3] then control.Modifiers = parsed.Value[3] end
					if entry.Object.mode == "Toggle" and parsed.Toggled ~= nil then
						control.Toggled = parsed.Toggled
						if type(control.Update) == "function" then control:Update() end
					end
				end
			end)
			local callbackFailed = type(errorsBefore) == "number"
				and type(self.Library.CallbackErrorCount) == "number"
				and self.Library.CallbackErrorCount > errorsBefore
			if not success or callbackFailed then failed += 1 end
		end
		if skipped > 0 then notify(self, "Skipped " .. skipped .. " invalid preset values") end
		if failed > 0 then return false, "Some preset callbacks failed; settings may be partially restored" end
		if skipped > 0 then return false, "Some preset values were invalid; settings may be partially restored" end
		return true
	end

	function SaveManager:Load(name)
		if not self.Ready or self.Library.Unloaded then return false, "Presets are not ready" end
		if not safeName(name, "autoload") then notify(self, "Invalid preset name; nothing was loaded"); return false, "Invalid preset name" end
		local text, message = readText(settingsPath(self) .. "/" .. name .. ".json")
		if not text then notify(self, "Could not load preset; nothing was loaded: " .. message); return false, message end
		return self:LoadJSON(text)
	end

	function SaveManager:Delete(name)
		if not self.Ready or self.Library.Unloaded then return false, "Presets are not ready" end
		if not safeName(name, "autoload") then return false, "Invalid preset name" end
		local path = settingsPath(self) .. "/" .. name .. ".json"
		local found, message = exists(path)
		if not found then return false, message or "Preset does not exist" end
		local autoload = self:GetAutoloadConfig()
		local deleted, result = fsCall("delfile", path)
		if not deleted or result == false then return false, "Could not delete preset" end
		if self.AutoloadConfig == name or autoload == name then return self:DeleteAutoLoadConfig() end
		return true
	end

	function SaveManager:GetAutoloadConfig()
		local text, message = readText(settingsPath(self) .. "/autoload.txt")
		if not text then return "none", false, message == "File does not exist" and "Autoload config is not set" or message end
		local name = text:match("^%s*(.-)%s*$")
		if not safeName(name, "autoload") then return "none", false, "Invalid autoload preset name" end
		local found, errorMessage = exists(settingsPath(self) .. "/" .. name .. ".json")
		if not found then return "none", false, errorMessage or "Autoload preset does not exist" end
		self.AutoloadConfig = name
		return name, true
	end

	function SaveManager:SaveAutoloadConfig(name)
		if not self.Ready or self.Library.Unloaded then return false, "Presets are not ready" end
		if not safeName(name, "autoload") then return false, "Invalid preset name" end
		local found, message = exists(settingsPath(self) .. "/" .. name .. ".json")
		if not found then return false, message or "Preset does not exist" end
		local success, errorMessage = writeText(settingsPath(self), "autoload.txt", name)
		if success then self.AutoloadConfig = name end
		return success, errorMessage
	end

	function SaveManager:DeleteAutoLoadConfig()
		if not self.Ready or self.Library.Unloaded then return false, "Presets are not ready" end
		local path = settingsPath(self) .. "/autoload.txt"
		local found, message = exists(path)
		if found == nil then return false, message end
		if found then
			local deleted, result = fsCall("delfile", path)
			if not deleted or result == false then return false, "Could not clear autoload preset" end
		end
		self.AutoloadConfig = nil
		return true
	end

	function SaveManager:LoadAutoloadConfig()
		if finishAttempted or self.Library.Unloaded then return false, "Initialization already finished or window unloaded" end
		finishAttempted = true
		if type(self.Library.FinishInit) ~= "function" or not pcall(self.Library.FinishInit, self.Library)
			or self.Library.Initialized ~= true or self.Library.Unloaded then
			notify(self, "Could not initialize the UI facade")
			return false, "Could not initialize the UI facade"
		end
		self.Ready = true
		local name, success, message = self:GetAutoloadConfig()
		if not success then
			if message ~= "Autoload config is not set" then notify(self, "Could not load autoload preset: " .. message) end
			return false, message
		end
		local loaded, errorMessage = self:Load(name)
		notify(self, loaded and "Autoload preset restored" or "Could not restore autoload preset: " .. errorMessage)
		return loaded, errorMessage
	end

	function SaveManager:BuildConfigSection(tab)
		if self.ConfigSection then return self.ConfigSection end
		local group = tab:AddRightGroupbox("Presets", "folder-cog")
		self.ConfigSection = group
		local built = false
		self.InputName = uiControl(self.Library, group, "AddInput", "InputName", { Text = "Preset name", Default = "", Finished = true })
		self.DropdownSelectedConfig = uiControl(self.Library, group, "AddDropdown", "DropdownSelectedConfig", {
			Text = "Selected preset", Values = self:RefreshConfigList(), AllowNull = true, Multi = false,
		})
		local function refresh()
			local selected = self.DropdownSelectedConfig.Value
			local names = self:RefreshConfigList()
			self.DropdownSelectedConfig:SetValues(names)
			self.DropdownSelectedConfig:SetValue(table.find(names, selected) and selected or nil)
		end
		local function button(text, action)
			group:AddButton(text, function()
				if not built or not self.Ready or self.Library.Unloaded then return end
				local success, message = action()
				notify(self, success and text .. " completed" or message or "Preset operation failed")
			end)
		end
		button("Save preset", function()
			local name = self.InputName.Value
			if name == "" then name = self.DropdownSelectedConfig.Value end
			local success, message = self:Save(name)
			if success then refresh(); self.DropdownSelectedConfig:SetValue(name) end
			return success, message
		end)
		button("Load preset", function() return self:Load(self.DropdownSelectedConfig.Value) end)
		button("Refresh presets", function() refresh(); return true end)
		button("Delete preset", function()
			local success, message = self:Delete(self.DropdownSelectedConfig.Value)
			if success then refresh() end
			return success, message
		end)
		button("Set autoload", function() return self:SaveAutoloadConfig(self.DropdownSelectedConfig.Value) end)
		button("Clear autoload", function() return self:DeleteAutoLoadConfig() end)
		built = true
		for _, name in ipairs({ "isfile", "isfolder", "readfile", "writefile", "listfiles", "makefolder", "delfile" }) do
			if type(filesystem[name]) ~= "function" then
				notify(self, "Preset persistence is limited: executor filesystem APIs are unavailable")
				break
			end
		end
		return group
	end

	local themeFields = { "MainColor", "AccentColor", "OutlineColor", "BackgroundColor", "FontColor" }
	local fallbackTheme = {
		MainColor = "191919", FontFace = "Code", AccentColor = "a0a0a0",
		OutlineColor = "282828", BackgroundColor = "0f0f0f", FontColor = "ffffff",
	}

	local function windTheme(name, data)
		if type(data) ~= "table" then return nil end
		local colors = {}
		for _, field in ipairs(themeFields) do
			colors[field] = color(data[field])
			if not colors[field] then return nil end
		end
		return {
			Name = name,
			Accent = colors.MainColor, Dialog = colors.MainColor,
			Outline = colors.OutlineColor, Text = colors.FontColor, Background = colors.BackgroundColor,
			Button = colors.AccentColor, Primary = colors.AccentColor, Icon = colors.AccentColor,
			Placeholder = colors.AccentColor, Toggle = colors.AccentColor, Slider = colors.AccentColor,
			Checkbox = colors.AccentColor, SliderIcon = colors.AccentColor,
			PanelBackground = colors.MainColor, PanelBackgroundTransparency = 0,
			ElementBackground = colors.MainColor, ElementBackgroundTransparency = 0,
			LabelBackground = colors.BackgroundColor, LabelBackgroundTransparency = 0,
		}
	end

	function ThemeManager:SetLibrary(owner)
		self.Library = owner
	end

	function ThemeManager:SetFolder(folder)
		local validated = safeFolder(folder)
		if not validated then notify(self, "Invalid themes folder"); return false end
		self.Folder = validated
		return true
	end

	function ThemeManager:SetDefaultTheme(data)
		if type(data) ~= "table" then return false, "Invalid default theme" end
		local normalized = table.clone(fallbackTheme)
		for _, field in ipairs(themeFields) do
			if data[field] ~= nil then
				local value = color(data[field])
				if not value then return false, "Invalid default theme color" end
				normalized[field] = value:ToHex()
			end
		end
		if typeof(data.FontFace) == "EnumItem" then normalized.FontFace = data.FontFace.Name
		elseif type(data.FontFace) == "string" then normalized.FontFace = data.FontFace end
		local success = pcall(WindUI.AddTheme, WindUI, windTheme("Meow", normalized))
		if not success then notify(self, "Could not register the Meow theme"); return false end
		self.DefaultData = normalized
		self.Records.Meow = { Key = "Meow", Name = "Meow", Data = normalized }
		return self:ApplyTheme("Meow")
	end

	function ThemeManager:RefreshThemeList()
		local records = {}
		local success, themes = pcall(WindUI.GetThemes, WindUI)
		if success and type(themes) == "table" then
			for key in pairs(themes) do
				if type(key) == "string" and key:sub(1, 12) ~= "__MeowTheme_" then
					records[key] = { Key = key, Name = key, Data = key == "Meow" and self.DefaultData or nil }
				end
			end
		else
			notify(self, "Could not list WindUI themes")
		end
		local folder = self.Folder .. "/themes"
		local names, message = listNames(folder, "default")
		if message then notify(self, "Custom theme persistence is unavailable: " .. message) end
		local invalid = 0
		for _, name in ipairs(names) do
			local text = readText(folder .. "/" .. name .. ".json")
			local data = text and decode(text)
			local key = "__MeowTheme_" .. name
			local theme = data and windTheme(key, data)
			if not theme or not pcall(WindUI.AddTheme, WindUI, theme) then invalid += 1; continue end
			records[name .. " (custom)"] = { Key = key, Name = name, Data = data }
		end
		if invalid > 0 then notify(self, "Skipped " .. invalid .. " unreadable or invalid custom themes") end
		self.Records = records
		local values = {}
		for label in pairs(records) do table.insert(values, label) end
		table.sort(values, function(a, b)
			if a == "Meow" then return b ~= "Meow" end
			if b == "Meow" then return false end
			return a < b
		end)
		return values
	end

	function ThemeManager:ApplyTheme(label)
		if self.Library.Unloaded then return false, "Window unloaded" end
		local record = self.Records[label]
		if not record then return false, "Theme does not exist" end
		local success, result = pcall(WindUI.SetTheme, WindUI, record.Key)
		if not success or result == nil then return false, "Could not apply WindUI theme" end
		self.CurrentTheme = label
		local fontName = record.Data and record.Data.FontFace
		if fontName then
			local applied = pcall(function()
				local item = Enum.Font[fontName]
				assert(item, "Invalid font")
				WindUI:SetFont(Font.fromEnum(item).Family)
				self.CurrentFontFace = fontName
			end)
			if not applied then notify(self, "Theme colors applied, but the font could not be applied") end
		end
		return true
	end

	function ThemeManager:SaveDefault(label)
		local record = self.Records[label]
		if not record or not safeName(record.Name) then return false, "Invalid default theme name" end
		local success, message = writeText(self.Folder .. "/themes", "default.txt", record.Name)
		if success then self.DefaultThemeName = record.Name end
		return success, message
	end

	function ThemeManager:SaveCustomTheme(name)
		if not safeName(name, "default") or name == "Meow" then return false, "Invalid custom theme name" end
		local record = self.Records[self.CurrentTheme]
		if not record then return false, "No theme is selected" end
		local success, themes = pcall(WindUI.GetThemes, WindUI)
		local theme = success and type(themes) == "table" and themes[record.Key]
		if not theme then return false, "Could not read current theme" end
		local data = { FontFace = self.CurrentFontFace or (self.DefaultData or fallbackTheme).FontFace }
		local mapping = { MainColor = "Accent", AccentColor = "Primary", OutlineColor = "Outline", BackgroundColor = "Background", FontColor = "Text" }
		for old, native in pairs(mapping) do
			local value = theme[native]
			if value == nil and old == "AccentColor" then value = theme.Icon or theme.Button end
			if value == nil and type(themes.Dark) == "table" then value = themes.Dark[native] end
			if typeof(value) ~= "Color3" then return false, "This theme cannot be exported as legacy colors" end
			data[old] = value:ToHex()
		end
		local text, message = encode(data)
		if not text then return false, message end
		return writeText(self.Folder .. "/themes", name .. ".json", text)
	end

	function ThemeManager:ApplyToTab(tab)
		if self.ThemeSection then return self.ThemeSection end
		if not self.DefaultData then self:SetDefaultTheme(fallbackTheme) end
		local values = self:RefreshThemeList()
		local text, message = readText(self.Folder .. "/themes/default.txt")
		local chosen = "Meow"
		if text then
			local name = text:match("^%s*(.-)%s*$")
			if safeName(name) then
				local label = self.Records[name .. " (custom)"] and name .. " (custom)" or (name == "Default" and "Meow" or name)
				if self.Records[label] then chosen = label
				else notify(self, "Saved default theme is unavailable; using Meow") end
			else notify(self, "Invalid saved default theme; using Meow") end
		elseif message ~= "File does not exist" then
			notify(self, "Could not read default theme: " .. message)
		end
		local applied, errorMessage = self:ApplyTheme(chosen)
		if not applied then notify(self, errorMessage) end
		local group = tab:AddLeftGroupbox("Themes", "paintbrush")
		self.ThemeSection = group
		local built = false
		self.ThemeDropdown = uiControl(self.Library, group, "AddDropdown", "ThemeDropdown", {
			Text = "WindUI theme", Values = values, Default = chosen, Multi = false, AllowNull = false,
			Callback = function(label)
				if not built or not SaveManager.Ready or self.Library.Unloaded or label == self.CurrentTheme then return end
				local success, applyMessage = self:ApplyTheme(label)
				if not success then notify(self, applyMessage); return end
				local saved, saveMessage = self:SaveDefault(label)
				if not saved then notify(self, "Theme applied without persistence: " .. saveMessage) end
			end,
		})
		self.InputThemeName = uiControl(self.Library, group, "AddInput", "InputThemeName", { Text = "Custom theme name", Default = "", Finished = true })
		group:AddButton("Save custom theme", function()
			if not built or not SaveManager.Ready or self.Library.Unloaded then return end
			local success, saveMessage = self:SaveCustomTheme(self.InputThemeName.Value)
			if success then
				built = false
				self.ThemeDropdown:SetValues(self:RefreshThemeList())
				self.ThemeDropdown:SetValue(self.CurrentTheme)
				built = true
			end
			notify(self, success and "Custom theme saved" or saveMessage)
		end)
		built = true
		return group
	end

	return ThemeManager, SaveManager
end
