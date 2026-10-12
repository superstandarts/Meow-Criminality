if not EndHubKeyGate.Authorize() then return end

local environment = (getgenv and getgenv()) or _G
local previousLibrary = environment.__ENDHUB_CRIMINALITY_LIBRARY or environment.__MEOW_CRIMINALITY_LIBRARY
if previousLibrary and not previousLibrary.Unloaded then
	previousLibrary:Unload()
end
environment.__MEOW_CRIMINALITY_LIBRARY = nil

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/placeholder14331/dependencies/refs/heads/main/ThemeManager")
)()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Runtime = { Threads = {} }

function Runtime.Connect(signal, callback)
	if Library.Unloaded then return nil end
	local connection = signal:Connect(function(...)
		if not Library.Unloaded then
			callback(...)
		end
	end)
	if Library.Unloaded then
		connection:Disconnect()
		return nil
	end
	return Library:GiveSignal(connection)
end

function Runtime.Spawn(callback)
	if Library.Unloaded then return nil end
	local thread = task.defer(function()
		local ok, err = pcall(callback)
		Runtime.Threads[coroutine.running()] = nil
		if not ok and not Library.Unloaded then
			warn("[EndHub] " .. tostring(err))
		end
	end)
	Runtime.Threads[thread] = true
	return thread
end

function Runtime.Cancel(thread)
	if not thread then return end
	Runtime.Threads[thread] = nil
	if thread ~= coroutine.running() and coroutine.status(thread) ~= "dead" then
		pcall(task.cancel, thread)
	end
end

local replacedLibrary = environment.__ENDHUB_CRIMINALITY_LIBRARY
environment.__ENDHUB_CRIMINALITY_LIBRARY = Library
if replacedLibrary and replacedLibrary ~= Library and not replacedLibrary.Unloaded then
	replacedLibrary:Unload()
end
if Library.Unloaded then return end
Library:OnUnload(function()
	for thread in pairs(Runtime.Threads) do
		Runtime.Cancel(thread)
	end
	if environment.__ENDHUB_CRIMINALITY_LIBRARY == Library then
		environment.__ENDHUB_CRIMINALITY_LIBRARY = nil
	end
end)

 
 
 
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local cam = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Terrain = workspace:FindFirstChildOfClass("Terrain")
local Camera = workspace.CurrentCamera
local Options = Library.Options
local Toggles = Library.Toggles
local player = Players.LocalPlayer
local Player = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Gui = Player:WaitForChild("PlayerGui")
if Library.Unloaded then return end
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalizationService = game:GetService("LocalizationService")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local TeleportService = game:GetService("TeleportService")
local startTime = os.time()

local executorName = (identifyexecutor and identifyexecutor())
	or (getexecutorname and getexecutorname())
	or "Unknown Executor"

local regionSuccess, userRegion = pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, LocalPlayer)
if Library.Unloaded then return end
userRegion = regionSuccess and userRegion or "Global"

Runtime.Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
	cam = workspace.CurrentCamera
	Camera = cam
end)
cam = workspace.CurrentCamera
Camera = cam

 
 
 
local Window = Library:CreateWindow({
	Title = "EndHub",
	Icon = EndHubKeyGate.Logo(),
	ShowCustomCursor = false,
	DisableSearch = false,
	Size = UDim2.fromOffset(740, 540),
	IconSize = UDim2.fromOffset(40, 40),
	Footer = "Powered by EndHub",
	NotifySide = "Right",
	Resizable = true,
	ToggleKeybind = Enum.KeyCode.RightControl,
})
Library.ScreenGui.DisplayOrder = 2147483647

 
 
 
local Tabs = {
	Home = Window:AddTab("Home", "house"),
    Combat = Window:AddTab("Combat", "crosshair"),
    ESP = Window:AddTab("ESP", "scan-eye"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Automation = Window:AddTab("Automation", "rotate-ccw"),
    Player = Window:AddTab("Player", "user"),
    Settings = Window:AddTab("Settings", "settings"),
}

local UseCheapESP = not Drawing
pcall(function()
    local executor = string.lower(tostring(executorName))
    if executor:find("xeno") or executor:find("solara") then UseCheapESP = true end
end)

local CombatLeft = Tabs.Combat:AddTabbox({ Side = "Left", Name = "CombatLeft", PopOut = false })
local CombatRight = Tabs.Combat:AddTabbox({ Side = "Right", Name = "CombatRight", PopOut = false })
local CombatGroups = {}
CombatGroups.Weapons = CombatLeft:AddTab("Weapons")
CombatGroups.Aim = CombatLeft:AddTab("Aim")
CombatGroups.Melee = CombatLeft:AddTab("Melee")
CombatGroups.ShotAssist = CombatRight:AddTab("Shot Assist")
CombatGroups.MeleeTargets = CombatRight:AddTab("Targets")

local ESPLeftTabs = Tabs.ESP:AddTabbox({ Side = "Left", Name = "ESPLeft", PopOut = false })
local ESPRightTabs = Tabs.ESP:AddTabbox({ Side = "Right", Name = "ESPRight", PopOut = false })
local ESPGroups = {}
ESPGroups.General = ESPLeftTabs:AddTab("Players")
ESPGroups.World = ESPLeftTabs:AddTab("World")
ESPGroups.Boxes = ESPRightTabs:AddTab(UseCheapESP and "Chams" or "Boxes")
ESPGroups.Text = ESPRightTabs:AddTab("Text")
ESPGroups.Health = ESPRightTabs:AddTab("Health")
ESPGroups.Lines = ESPRightTabs:AddTab("Lines")

 
 
 
local SettingsGroupLeft = Tabs.Settings:AddLeftGroupbox("Menu Customization", "app-window")

SettingsGroupLeft:AddToggle("KeybindMenuOpen", {
	Default = Library.KeybindFrame.Visible,
	Text = "Show Keybind Menu",
	Callback = function(value)
		Library.KeybindFrame.Visible = value
	end,
})

local MyToggle = SettingsGroupLeft:AddToggle("MyToggle", {
	Text = "Custom Cursor",
	Default = false,
})

Toggles.MyToggle:OnChanged(function(state)
	Library.ShowCustomCursor = state
end)

SettingsGroupLeft:AddDivider()

SettingsGroupLeft:AddDropdown("DPIDropdown", {
	Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
	Default = "100%",
	Text = "Interface Scale (DPI)",
	Callback = function(Value)
		Value = Value:gsub("%%", "")
		local DPI = tonumber(Value)
		Library:SetDPIScale(DPI)
	end,
})

SettingsGroupLeft:AddDivider()

SettingsGroupLeft:AddLabel("Menu Bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightControl",
	NoUI = true,
	Text = "Menu keybind",
})

SettingsGroupLeft:AddButton("Unload Script", function()
	if not Library.Unloaded then Library:Unload() end
end)

Library.ToggleKeybind = Options.MenuKeybind

 
 
 
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetLoadingOrder(true, { "Input", "ColorPicker", "Slider", "Dropdown", "Toggle", "KeyPicker" })
ThemeManager:SetFolder("EndHub")
ThemeManager:SetDefaultTheme({
	MainColor = "191919",
	FontFace = "Code",
	AccentColor = "a0a0a0",
	OutlineColor = "282828",
	BackgroundColor = "0f0f0f",
	FontColor = "ffffff",
})
SaveManager:SetFolder("EndHub")
SaveManager:SetSubFolder("Criminality")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)


 
 
 
do
	local request = (syn and syn.request) or (http and http.request) or http_request or request

	local ProfileBox = Tabs.Home:AddLeftGroupbox("Profile", "user")
	local SystemBox = Tabs.Home:AddLeftGroupbox("Environment", "activity")
	local CommunityBox = Tabs.Home:AddRightGroupbox("System Credentials", "shield")

	 
	local Thumbnail =
		Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    if Library.Unloaded then return end
	ProfileBox:AddImage("UserAvatar", {
		Image = Thumbnail,
		Transparency = 0.05,
		Color = Color3.fromRGB(255, 218, 224),
		ScaleType = Enum.ScaleType.Fit,
		Height = 130,
	})

	ProfileBox:AddDivider()
	ProfileBox:AddLabel({
		Text = "Welcome back, <font color='#ffb6c1'><b>" .. LocalPlayer.DisplayName .. "</b></font> ♡",
	})
	ProfileBox:AddLabel({ Text = "@" .. LocalPlayer.Name })

	local accountCreationTimestamp = os.time() - (LocalPlayer.AccountAge * 86400)
	local creationDate = os.date("%d.%m.%Y", accountCreationTimestamp)
	ProfileBox:AddLabel({ Text = "Created: <font color='#bfe3b4'>" .. creationDate .. "</font>" })

	 
	local success, productInfo = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
    if Library.Unloaded then return end
	local gameName = success and productInfo.Name or "Unknown Universe"

	SystemBox:AddLabel({ Text = "<b>Game:</b> " .. gameName, DoesWrap = true })
	SystemBox:AddDivider()

	SystemBox:AddLabel({ Text = "Connection: <font color='#bfe3b4'>Stable</font>" })
	SystemBox:AddLabel({ Text = "Executor: <font color='#aec6cf'>" .. executorName .. "</font>" })

	 
	CommunityBox:AddLabel({ Text = "<b>EndHub</b>", DoesWrap = true })

	local uptimeLabel = CommunityBox:AddLabel({ Text = "Uptime: 00:00:00" })
	local serverTimeLabel = CommunityBox:AddLabel({ Text = "Time: " .. os.date("%X") })
	local livePingLabel = CommunityBox:AddLabel({ Text = "Latency: Fetching..." })

	CommunityBox:AddDivider()

	CommunityBox:AddLabel({ Text = "Account Age: <font color='#aec6cf'>" .. LocalPlayer.AccountAge .. " Days</font>" })
	CommunityBox:AddLabel({ Text = "Region: <font color='#ffdfba'>" .. userRegion .. "</font>" })

	CommunityBox:AddDivider()

	 
	Runtime.Spawn(function()
		while task.wait(1) do
			if Library.Unloaded then
				break
			end

			local diff = os.time() - startTime
			local hours = math.floor(diff / 3600)
			local minutes = math.floor((diff % 3600) / 60)
			local seconds = diff % 60

			local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())

			uptimeLabel:SetText(
				string.format("Uptime: <font color='#bfe3b4'>%02d:%02d:%02d</font>", hours, minutes, seconds)
			)
			serverTimeLabel:SetText("Server Time: <font color='#ffdfba'>" .. os.date("%X") .. "</font>")
			livePingLabel:SetText("Latency: <font color='#aec6cf'>" .. ping .. "ms</font>")
		end
	end)

	local inviteCode = "ZtRSZY8qaD"
	CommunityBox:AddButton({
		Text = "Original Author's Discord",
		Func = function()
			setclipboard("https://discord.gg/" .. inviteCode)

			if request then
				request({
					Url = "http://127.0.0.1:6463/rpc?v=1",
					Method = "POST",
					Headers = {
						["Content-Type"] = "application/json",
						["Origin"] = "https://discord.com",
					},
					Body = HttpService:JSONEncode({
						cmd = "INVITE_BROWSER",
						nonce = HttpService:GenerateGUID(false),
						args = { code = inviteCode },
					}),
				})

				Library:Notify({
					Title = "EndHub",
					Description = "Opening Discord App...",
					Time = 4,
				})
			else
				Library:Notify({
					Title = "EndHub",
					Description = "Invite copied to clipboard!",
					Time = 4,
				})
			end
		end,
		DoubleClick = false,
	})
end

 
 
 
do
	local Melee = CombatGroups.Melee
	local Targets = CombatGroups.MeleeTargets

	 
	 
	 
	local MeleeAura_Enabled = false
	local AuraRange = 5

	local SwingAnimation = false
	local ShowTarget = false
	local HitEffect = false
	local Highlight

	local LastSwing = 0
	local SwingCooldown = 0.35

	local CurrentTarget = nil
	local SelectedHitPart = "Closest"

	local TargetMode = "Closest"

	 
	 
	 
	local LastNotification = 0

	local function Notify(desc, time)
		if tick() - LastNotification < 1 then
			return
		end

		LastNotification = tick()

		Library:Notify({
			Title = "EndHub",
			Description = desc,
			Time = time or 4,
		})
	end

	 
	 
	 
	local MyToggle = Melee:AddToggle("MeleeAuraToggle", {
		Text = "Melee Aura",
		Default = false,
	})

	MyToggle:AddKeyPicker("AutoFarmKey", {
		Default = "None",
		Text = "Melee",
		Mode = "Toggle",
		SyncToggleState = true,
	})

	 
	 
	 
	Melee:AddToggle("ShowAuraRange", {
		Text = "Show Range",
		Default = false,
	})

	 
	 
	 
	Melee:AddToggle("ShowTargetToggle", {
		Text = "Show Target",
		Default = false,
	})

	Toggles.ShowTargetToggle:OnChanged(function(Value)
		ShowTarget = Value

		if not Value and Highlight then
			Highlight.Enabled = false
			Highlight.Adornee = nil
		end
	end)

	 
	 
	 
	Melee:AddToggle("SwingAnimationToggle", {
		Text = "Swing Animation",
		Default = false,
	})

	Toggles.SwingAnimationToggle:OnChanged(function(Value)
		SwingAnimation = Value
	end)

	 
	 
	 
	Melee:AddToggle("HitEffectToggle", {
		Text = "Hit Effect",
		Default = false,
	})

	Toggles.HitEffectToggle:OnChanged(function(Value)
		HitEffect = Value
	end)

	 
	 
	 
	Melee:AddSlider("MeleeAuraRange", {
		Text = "Aura Range",
		Default = 5,
		Min = 1,
		Max = 13.5,
		Rounding = 1,
		Suffix = " Studs",
	})

	Options.MeleeAuraRange:OnChanged(function(Value)
		AuraRange = Value

		Notify(string.format("Aura Range: %.1f", AuraRange), 3)
	end)

	 
	 
	 
	Melee:AddDropdown("MeleeHitPart", {
		Text = "Hit Part",
		Values = {
			"Head",
			"Torso",
			"Arms",
			"Legs",
			"Closest",
		},
		Default = 5,
		Multi = false,
	})

	Options.MeleeHitPart:OnChanged(function(Value)
		SelectedHitPart = Value

		Notify("Hit Part: " .. tostring(Value), 3)
	end)

	 
	 
	 
	Targets:AddDropdown("TargetMode", {
		Text = "Target Mode",
		Values = {
			"Closest",
			"Lowest HP",
			"Highest HP",
		},
		Default = 1,
		Multi = false,
	})

	Options.TargetMode:OnChanged(function(Value)
		TargetMode = Value

		Notify("Target Mode: " .. tostring(Value), 3)
	end)

	 
	 
	 
	local Whitelist = {}

	local WhitelistDropdown = Targets:AddDropdown("MeleeWhitelist", {
		Text = "Whitelist",
		Values = {},
		Multi = true,
		Default = {},
	})

	local function RefreshWhitelist()
		local names = {}

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				table.insert(names, plr.Name)
			end
		end

		WhitelistDropdown:SetValues(names)
	end

	RefreshWhitelist()

	Runtime.Connect(Players.PlayerAdded, function()
		task.wait(1)
		if not Library.Unloaded then RefreshWhitelist() end
	end)

	Runtime.Connect(Players.PlayerRemoving, function()
		task.wait(1)
		if not Library.Unloaded then RefreshWhitelist() end
	end)

	WhitelistDropdown:OnChanged(function(Value)
		Whitelist = Value
	end)

	 
	 
	 
	local RangePart = Instance.new("Part")
	RangePart.Name = "EndHubAuraRange"
	RangePart.Anchored = true
	RangePart.CanCollide = false
	RangePart.CanQuery = false
	RangePart.CanTouch = false
	RangePart.Transparency = 0.5
	RangePart.Color = Color3.fromRGB(120, 170, 255)
	RangePart.Material = Enum.Material.Neon
	RangePart.Shape = Enum.PartType.Cylinder
	RangePart.Parent = workspace

	local PulseTime = 0

	Runtime.Connect(RunService.RenderStepped, function(delta)
		PulseTime += delta * 2

		if not MeleeAura_Enabled or not Toggles.ShowAuraRange.Value then
			RangePart.Transparency = 1
			return
		end

		local Character = LocalPlayer.Character

		if not Character then
			RangePart.Transparency = 1
			return
		end

		local HRP = Character:FindFirstChild("HumanoidRootPart")

		if not HRP then
			RangePart.Transparency = 1
			return
		end

		local Pulse = math.sin(PulseTime) * 0.15

		local Diameter = (AuraRange * 2) + Pulse

		RangePart.Size = Vector3.new(0.1, Diameter, Diameter)

		RangePart.Transparency = 0.5

		RangePart.CFrame = CFrame.new(HRP.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end)

	 
	 
	 
	Highlight = Instance.new("Highlight")
	Highlight.Enabled = false
	Highlight.FillColor = Color3.fromRGB(120, 170, 255)
	Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	Highlight.FillTransparency = 0.45
	Highlight.OutlineTransparency = 0
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.Parent = CoreGui

	 
	 
	 
	local HitGui = Instance.new("ScreenGui")
	HitGui.Name = "EndHubHitFX"
	HitGui.IgnoreGuiInset = true
	HitGui.ResetOnSpawn = false
	HitGui.Parent = CoreGui

	local HitFlash = Instance.new("Frame")
	HitFlash.BackgroundColor3 = Color3.new(1, 1, 1)
	HitFlash.BackgroundTransparency = 1
	HitFlash.BorderSizePixel = 0
	HitFlash.Size = UDim2.fromScale(1, 1)
	HitFlash.Parent = HitGui

	local HitEffectTween

	local function CreateHitEffect()
		if not HitEffect then
			return
		end

		if HitEffectTween then
			pcall(function()
				HitEffectTween:Cancel()
			end)
		end

		HitFlash.BackgroundTransparency = 0.93

		HitEffectTween =
			TweenService:Create(HitFlash, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			})

		HitEffectTween:Play()
	end

	 
	 
	 
	local CurrentSlash = 1
	local SwingTracks = {}
	local SwingAnimator

	local function PlaySwingAnimation(tool)
		if not SwingAnimation then
			return
		end

		if tick() - LastSwing < SwingCooldown then
			return
		end

		LastSwing = tick()

		local CharacterFolder = workspace:FindFirstChild("Characters")

		if not CharacterFolder then
			return
		end

		local PlayerCharacter = CharacterFolder:FindFirstChild(LocalPlayer.Name)

		if not PlayerCharacter then
			return
		end

		local WeaponModel = PlayerCharacter:FindFirstChild(tool.Name)

		if not WeaponModel then
			return
		end

		local AnimsFolder = WeaponModel:FindFirstChild("AnimsFolder")

		if not AnimsFolder then
			return
		end

		local SlashAnims = {
			AnimsFolder:FindFirstChild("Slash1"),
			AnimsFolder:FindFirstChild("Slash2"),
			AnimsFolder:FindFirstChild("Slash3"),
		}

		local AnimObject = SlashAnims[CurrentSlash]

		if not AnimObject then
			return
		end

		local Character = LocalPlayer.Character

		if not Character then
			return
		end

		local Humanoid = Character:FindFirstChildOfClass("Humanoid")

		if not Humanoid then
			return
		end

		local Animator = Humanoid:FindFirstChildOfClass("Animator")

		if not Animator then
			return
		end

		if SwingAnimator ~= Animator then
			for _, track in pairs(SwingTracks) do track:Destroy() end
			table.clear(SwingTracks)
			SwingAnimator = Animator
		end
		local track = SwingTracks[AnimObject]
		if not track then
			local success, loadedTrack = pcall(Animator.LoadAnimation, Animator, AnimObject)
			if not success then return end
			track = loadedTrack
			SwingTracks[AnimObject] = track
		end

		if track then
			track:Play(0.05, 1, 1)

			CurrentSlash += 1

			if CurrentSlash > #SlashAnims then
				CurrentSlash = 1
			end
		end
	end

	 
	 
	 
	local function RunMeleeAuraOnce()
		local me = LocalPlayer
		local eventsFolder = ReplicatedStorage:FindFirstChild("Events")

		if not eventsFolder then
			return
		end

		local remote1 = eventsFolder:FindFirstChild("XMHH.2")
		local remote2 = eventsFolder:FindFirstChild("XMHH2.2")

		if not remote1 or not remote2 then
			return
		end

		if not me.Character then
			return
		end

		local hrp = me.Character:FindFirstChild("HumanoidRootPart")
		local tool = me.Character:FindFirstChildOfClass("Tool")

		if not hrp or not tool then
			return
		end

		local targetChar = nil
		local bestValue = nil

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= me and plr.Character and not Whitelist[plr.Name] then
				local c = plr.Character
				local hrp2 = c:FindFirstChild("HumanoidRootPart")
				local hum = c:FindFirstChildOfClass("Humanoid")

				if hrp2 and hum and hum.Health > 15 and not c:FindFirstChildOfClass("ForceField") then
					local dist = (hrp.Position - hrp2.Position).Magnitude

					if dist <= AuraRange then
						if TargetMode == "Closest" then
							if not bestValue or dist < bestValue then
								bestValue = dist
								targetChar = c
							end
						elseif TargetMode == "Lowest HP" then
							if not bestValue or hum.Health < bestValue then
								bestValue = hum.Health
								targetChar = c
							end
						elseif TargetMode == "Highest HP" then
							if not bestValue or hum.Health > bestValue then
								bestValue = hum.Health
								targetChar = c
							end
						end
					end
				end
			end
		end

		CurrentTarget = targetChar

		if Toggles.ShowTargetToggle.Value and CurrentTarget and CurrentTarget.Parent then
			Highlight.Enabled = true
			Highlight.Adornee = CurrentTarget
		else
			Highlight.Enabled = false
			Highlight.Adornee = nil
		end

		if not targetChar then
			return
		end

		 
		 
		 
		local hitPart = nil

		if SelectedHitPart == "Head" then
			hitPart = targetChar:FindFirstChild("Head")
		elseif SelectedHitPart == "Torso" then
			hitPart = targetChar:FindFirstChild("UpperTorso")
				or targetChar:FindFirstChild("Torso")
				or targetChar:FindFirstChild("LowerTorso")
		elseif SelectedHitPart == "Arms" then
			hitPart = targetChar:FindFirstChild("RightHand")
				or targetChar:FindFirstChild("LeftHand")
				or targetChar:FindFirstChild("Right Arm")
				or targetChar:FindFirstChild("Left Arm")
		elseif SelectedHitPart == "Legs" then
			hitPart = targetChar:FindFirstChild("RightFoot")
				or targetChar:FindFirstChild("LeftFoot")
				or targetChar:FindFirstChild("Right Leg")
				or targetChar:FindFirstChild("Left Leg")
		elseif SelectedHitPart == "Closest" then
			local parts = {}

			for _, obj in ipairs(targetChar:GetChildren()) do
				if obj:IsA("BasePart") then
					table.insert(parts, obj)
				end
			end

			local closestDistance = math.huge

			for _, part in ipairs(parts) do
				local dist = (hrp.Position - part.Position).Magnitude

				if dist < closestDistance then
					closestDistance = dist
					hitPart = part
				end
			end
		end

		if not hitPart then
			return
		end

		local hitPartName = hitPart.Name

		local hum = targetChar:FindFirstChildOfClass("Humanoid")

		if not hum then
			return
		end

		local oldHealth = hum.Health

		PlaySwingAnimation(tool)

		local ok, result = pcall(function()
			return remote1:InvokeServer("🍞", tick(), tool, "43TRFWX", "Normal", tick(), true)
		end)

		if not ok then
			return
		end

		task.wait(0.05)

		local handle = tool:FindFirstChild("WeaponHandle")
			or tool:FindFirstChild("Handle")
			or me.Character:FindFirstChild("Right Arm")

		if not handle then
			return
		end

		local success = pcall(function()
			remote2:FireServer(
				"🍞",
				tick(),
				tool,
				"2389ZFX34",
				result,
				false,
				handle,
				hitPart,
				targetChar,
				hrp.Position,
				hitPart.Position
			)
		end)

		if not success then
			return
		end

		task.wait(0.15)

		if hum.Health < oldHealth then
			CreateHitEffect()

			local hp = math.floor(hum.Health)

			if hp > 0 then
				Notify(string.format("Hit %s [%s] (%d HP)", targetChar.Name, hitPartName, hp), 4)
			else
				Notify(string.format("Killed %s [%s] :3", targetChar.Name, hitPartName), 4)
			end
		end
	end

	 
	 
	 
	local auraThread
	Toggles.MeleeAuraToggle:OnChanged(function(state)
		Runtime.Cancel(auraThread)
		auraThread = nil
		MeleeAura_Enabled = state

		if state then
			Notify("Melee Aura Enabled", 3)

			auraThread = Runtime.Spawn(function()
				while MeleeAura_Enabled and not Library.Unloaded do
					RunMeleeAuraOnce()
					task.wait(0.08)
				end
			end)
		else
			RangePart.Transparency = 1

			Highlight.Enabled = false
			Highlight.Adornee = nil

			Notify("Melee Aura Disabled", 3)
		end
	end)
    Library:OnUnload(function()
        MeleeAura_Enabled = false
        if HitEffectTween then HitEffectTween:Cancel() end
        for _, track in pairs(SwingTracks) do track:Destroy() end
        table.clear(SwingTracks)
        RangePart:Destroy()
        Highlight:Destroy()
        HitGui:Destroy()
    end)
end

 
 
 
do
local GunLeft = CombatGroups.Weapons

local Options = Library.Options
local Toggles = Library.Toggles

local NoRecoil_Enabled = false
local NoRecoil_Connections = {}
local GlobalOriginalValues = {}
local WeaponCache = {}
local Settings = {GunMods={NoRecoil=true,Spread=true,SpreadAmount=0}}
local Player_nr = LocalPlayer

local function cacheWeapons()
    WeaponCache = {}
    for _, v in pairs(getgc(true)) do
        if type(v) == 'table' and rawget(v, 'EquipTime') then
            table.insert(WeaponCache, v)
            if not GlobalOriginalValues[v] then
                GlobalOriginalValues[v] = {
                    Recoil = v.Recoil,
                    CameraRecoilingEnabled = v.CameraRecoilingEnabled,
                    AngleX_Min = v.AngleX_Min, AngleX_Max = v.AngleX_Max,
                    AngleY_Min = v.AngleY_Min, AngleY_Max = v.AngleY_Max,
                    AngleZ_Min = v.AngleZ_Min, AngleZ_Max = v.AngleZ_Max,
                    Spread = v.Spread
                }
            end
        end
    end
end

local function applyGunMods()
    for _, weapon in ipairs(WeaponCache) do
        if Settings.GunMods.NoRecoil then
            weapon.Recoil = 0
            weapon.CameraRecoilingEnabled = false
            weapon.AngleX_Min = 0; weapon.AngleX_Max = 0
            weapon.AngleY_Min = 0; weapon.AngleY_Max = 0
            weapon.AngleZ_Min = 0; weapon.AngleZ_Max = 0
        end
        if Settings.GunMods.Spread then
            weapon.Spread = Settings.GunMods.SpreadAmount
        end
    end
end

local function resetGunMods()
    for weapon, values in pairs(GlobalOriginalValues) do
        weapon.Recoil = values.Recoil
        weapon.CameraRecoilingEnabled = values.CameraRecoilingEnabled
        weapon.AngleX_Min = values.AngleX_Min; weapon.AngleX_Max = values.AngleX_Max
        weapon.AngleY_Min = values.AngleY_Min; weapon.AngleY_Max = values.AngleY_Max
        weapon.AngleZ_Min = values.AngleZ_Min; weapon.AngleZ_Max = values.AngleZ_Max
        weapon.Spread = values.Spread
    end
end

local weaponRefreshThread
local function handleWeapon(weapon)
    if NoRecoil_Enabled then
        Runtime.Cancel(weaponRefreshThread)
        weaponRefreshThread = Runtime.Spawn(function()
            task.wait(0.1)
            if NoRecoil_Enabled and not Library.Unloaded then
                cacheWeapons()
                applyGunMods()
            end
        end)
    end
end

local function onCharacterAdded_nr(character)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then handleWeapon(child) end
    end
    table.insert(NoRecoil_Connections, Runtime.Connect(character.ChildAdded, function(child)
        if child:IsA("Tool") then handleWeapon(child) end
    end))
end

local function NoRecoil_Enable()
    if NoRecoil_Enabled then return end
    NoRecoil_Enabled = true
    cacheWeapons()
    applyGunMods()
    table.insert(NoRecoil_Connections, Runtime.Connect(Player_nr.CharacterAdded, onCharacterAdded_nr))
    if Player_nr.Character then onCharacterAdded_nr(Player_nr.Character) end
end

local function NoRecoil_Disable()
    if not NoRecoil_Enabled then return end
    NoRecoil_Enabled = false
    Runtime.Cancel(weaponRefreshThread)
    weaponRefreshThread = nil
    resetGunMods()
    for _, conn in ipairs(NoRecoil_Connections) do conn:Disconnect() end
    NoRecoil_Connections = {}
end

local NoRecoilToggle = GunLeft:AddToggle("NoRecoilToggle", {
    Text = "No Recoil",
    Default = false,
})

Toggles.NoRecoilToggle:OnChanged(function(state)
    if state then
        NoRecoil_Enable()
    else
        NoRecoil_Disable()
    end
end)

local player = Players.LocalPlayer
local AutoReload = false
local reloadThread

 
local MIN_DELAY = 0.15
local MAX_DELAY = 0.35

local function getCharacter()
    return player.Character
end

local function getTool(character)
    return character:FindFirstChildOfClass("Tool")
end

local function reload(tool)
    local characters = workspace:FindFirstChild("Characters")
    local character = characters and characters:FindFirstChild(player.Name)
    local weapon = character and character:FindFirstChild(tool.Name)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild("GNX_R")
    if not weapon or not remote then return end
    local args = {
        [1] = tick(),
        [2] = "KLWE89U0",
        [3] = weapon,
    }

    remote:FireServer(unpack(args))
end

 
local MyToggle = GunLeft:AddToggle("InstantReload", {
    Text = "Auto Reload",
    Default = false,
})

MyToggle:OnChanged(function(state)
    Runtime.Cancel(reloadThread)
    reloadThread = nil
    AutoReload = state

    if state then
        reloadThread = Runtime.Spawn(function()
            while AutoReload and not Library.Unloaded do
                pcall(function()
                    local character = getCharacter()
                    local tool = character and getTool(character)

                    if tool then
                         
                        local ammo = tool:FindFirstChild("Ammo")

                        if ammo then
                            if ammo.Value <= 0 then
                                reload(tool)
                            end
                        else
                             
                            reload(tool)
                        end
                    end
                end)

                task.wait(math.random(MIN_DELAY*100, MAX_DELAY*100)/100)
            end
        end)
    end
end)
Library:OnUnload(function()
    AutoReload = false
    NoRecoil_Disable()
    table.clear(WeaponCache)
    table.clear(GlobalOriginalValues)
end)
end

 
 
 
do
    local AimbotLeft = CombatGroups.Aim
    local AimbotRight = CombatGroups.ShotAssist

    local on = false
    local tgtPart = "Head"
    local sensitivity = 50
    local fovRadius = 40
    local visibleCheck = false

     
    local GlobalWhitelist = {}

     
    local fovCircle
    if Drawing then
        fovCircle = Drawing.new("Circle")
        fovCircle.Visible = false
        fovCircle.Radius = fovRadius
        fovCircle.Thickness = 1
        fovCircle.Filled = false
        fovCircle.NumSides = 100
        fovCircle.Color = Color3.fromRGB(255,255,255)
    end

     
    local function getTargetPart(char, partName)
        if not char then return end
        if partName == "Torso" then
            return char:FindFirstChild("UpperTorso") 
                or char:FindFirstChild("LowerTorso") 
                or char:FindFirstChild("Torso")
        end
        return char:FindFirstChild("Head")
    end

     
    local aimRaycastParams = RaycastParams.new()
    aimRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local function isVisible(part, character)
        if not visibleCheck then return true end
        local origin = cam.CFrame.Position
        local direction = (part.Position - origin)
        aimRaycastParams.FilterDescendantsInstances = {LocalPlayer.Character, character}
        local result = workspace:Raycast(origin, direction, aimRaycastParams)
        return not result
    end

     
    local function getClosestTarget()
        if not cam then return nil end
        local closestPart = nil
        local shortestDist = fovRadius
        local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)

        for _,plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                
                 
                if GlobalWhitelist[plr.Name] then continue end

                local humanoid = plr.Character:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local part = getTargetPart(plr.Character, tgtPart)
                    if part then
                        local pos, visible = cam:WorldToViewportPoint(part.Position)
                        if visible and pos.Z > 0 then
                            local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                            if dist < shortestDist and isVisible(part, plr.Character) then
                                shortestDist = dist
                                closestPart = part
                            end
                        end
                    end
                end
            end
        end
        return closestPart
    end

     
    local aimTarget
    local aimTargetAccumulator = 0
    Runtime.Connect(RunService.Heartbeat, function(deltaTime)
        if not on or (Toggles.FreeCamToggle and Toggles.FreeCamToggle.Value) then return end
        aimTargetAccumulator += deltaTime
        if aimTargetAccumulator >= (1 / 30) then
            aimTargetAccumulator %= (1 / 30)
            aimTarget = getClosestTarget()
        end
    end)
    RunService:BindToRenderStep("EndHubAimbot", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
        if Library.Unloaded or not cam then return end
        if Toggles.FreeCamToggle and Toggles.FreeCamToggle.Value then return end
        if fovCircle and on then
            local vp = cam.ViewportSize
            fovCircle.Position = Vector2.new(vp.X/2, vp.Y/2)
            fovCircle.Radius = fovRadius
        end
        if on then
            local part = aimTarget
            local character = part and part.Parent
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if part and part:IsDescendantOf(workspace) and humanoid and humanoid.Health > 0 then
                local current = cam.CFrame
                local target = CFrame.new(current.Position, part.Position)
                local alpha = math.clamp(sensitivity / 100, 0.05, 1)
                cam.CFrame = (sensitivity >= 100) and target  or current:Lerp(target, alpha)
            end
        end
    end)

     
     
     
    local SA = {
        On = false, MagicBullet = false, InstantPelletDelivery = false, DrawCircle = false, DrawSize = 100, ChkDowned = false, ChkTeam = false, VisChk = false,
        MaxDist = 500, AutoWall = true, HitChance = 100, UseFOV = true, Debug = false,
        FOVCol = Color3.fromRGB(255, 255, 255), TMode = "Head",
        Parts = { 
            ["Head"] = {"Head"}, 
            ["Torso"] = {"Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
            ["Arms"] = {"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "Left Arm", "Right Arm"},
            ["Legs"] = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Left Leg", "Right Leg"}
        }
    }

    local saTargetAccumulator = 0
    local saTargetRevision = 0
    local function isSAActive()
        return not Library.Unloaded and (SA.On or SA.MagicBullet)
    end

    local function clearSATarget()
        _G.CurSATarget = nil
        saTargetAccumulator = 1 / 30
         
        saTargetRevision += 1
    end

    local SACircle = nil
    local function crFOVCircle()
        if SACircle then SACircle:Remove(); SACircle = nil end
        if isSAActive() and SA.DrawCircle and Drawing then
            SACircle = Drawing.new("Circle"); SACircle.Color = SA.FOVCol; SACircle.Filled = false
            SACircle.Thickness = 0.5; SACircle.Radius = SA.DrawSize; SACircle.Visible = true; SACircle.Transparency = 1
        end
    end

    local saRaycastParams = RaycastParams.new()
    saRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local randomModes = {"Head", "Torso", "Arms", "Legs"}
    local function getSAFOVDistance(character, camera, centerPos)
        local closestLimbDist = math.huge
        for _, limb in pairs(character:GetChildren()) do
            if limb:IsA("BasePart") then
                local lsP, lsOnSc = camera:WorldToViewportPoint(limb.Position)
                if lsOnSc and lsP.Z > 0 then
                    local ld2m = (centerPos - Vector2.new(lsP.X, lsP.Y)).Magnitude
                    if ld2m < closestLimbDist then closestLimbDist = ld2m end
                end
            end
        end
        return closestLimbDist
    end

    local function getValidT()
        if not isSAActive() then return nil end
        local Cam = workspace.CurrentCamera
        if not Cam then return nil end
        local t = nil; local minD = math.huge; local centerPos = UIS:GetMouseLocation()
        local LP = Players.LocalPlayer
        local myC = LP.Character
        local myR = myC and myC:FindFirstChild("HumanoidRootPart")
        saRaycastParams.FilterDescendantsInstances = {myC, Cam}
        
        for _, p in pairs(Players:GetPlayers()) do
            if p == LP then continue end
            
             
            if GlobalWhitelist[p.Name] then continue end
            
            if not p.Character then continue end
            local c = p.Character; local h = c:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 then continue end

            local currentMode = SA.MagicBullet and "Head" or SA.TMode
            if currentMode == "Random" then
                currentMode = randomModes[math.random(1, #randomModes)]
            end

            local validP = SA.Parts[currentMode]; if not validP then validP = {"Head"} end
            local avail = {}; for _, pn in ipairs(validP) do local pt = c:FindFirstChild(pn); if pt and pt:IsA("BasePart") then table.insert(avail, pt) end end
            if #avail == 0 then continue end
            
            local sel = avail[math.random(1, #avail)]

            local tp = sel; local pPos = tp.Position
            if myR then local d = (myR.Position - pPos).Magnitude; if d > SA.MaxDist then continue end end
            
            local sPos, onSc = Cam:WorldToViewportPoint(pPos); if not onSc or sPos.Z <= 0 then continue end
            local targetDist
            if SA.UseFOV then
                local closestLimbDist = getSAFOVDistance(c, Cam, centerPos)
                
                if closestLimbDist > SA.DrawSize + 35 then continue end
                targetDist = closestLimbDist
            else
                if not myR then continue end
                targetDist = (myR.Position - pPos).Magnitude
            end
            if targetDist >= minD then continue end

             
            if not SA.MagicBullet then
                local origin = Cam.CFrame.Position
                local result = workspace:Raycast(origin, pPos - origin, saRaycastParams)
                local hit = result and result.Instance
                if hit and not hit:IsDescendantOf(c) and hit.Transparency < 1 then continue end
            end
            minD = targetDist
            t = {Player=p, Char=c, Part=tp, PName=tp.Name, Pos=pPos, Dist=SA.UseFOV and targetDist or 0, ScPos=sPos, WDist=(myR and (myR.Position-pPos).Magnitude) or 0, Revision=saTargetRevision}
        end
        
        return t
    end

    local function canFire(t)
        if not isSAActive() or not t or t.Revision ~= saTargetRevision then return false end
        if t.Player.Parent ~= Players or t.Player.Character ~= t.Char or GlobalWhitelist[t.Player.Name]
            or not t.Char:IsDescendantOf(workspace) or t.Part.Parent ~= t.Char
            or t.Char:FindFirstChild(t.PName) ~= t.Part then
            return false
        end
        if SA.MagicBullet and t.PName ~= "Head" then return false end
        local h = t.Char:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then return false end
        local Cam = workspace.CurrentCamera
        if not Cam then return false end
        local myC = LocalPlayer.Character
        local myR = myC and myC:FindFirstChild("HumanoidRootPart")
        if myR then
            if (myR.Position - t.Part.Position).Magnitude > SA.MaxDist then return false end
        elseif not SA.UseFOV then
            return false
        end
        local projected, onSc = Cam:WorldToViewportPoint(t.Part.Position)
        if not onSc or projected.Z <= 0 then return false end
        if SA.UseFOV and getSAFOVDistance(t.Char, Cam, UIS:GetMouseLocation()) > SA.DrawSize + 35 then
            return false
        end
        if not SA.MagicBullet then
            saRaycastParams.FilterDescendantsInstances = {myC, Cam}
            local origin = Cam.CFrame.Position
            local result = workspace:Raycast(origin, t.Part.Position - origin, saRaycastParams)
            local hit = result and result.Instance
            if hit and not hit:IsDescendantOf(t.Char) and hit.Transparency < 1 then return false end
        end
        return true
    end

    local SALoopConn = nil

    local function updFOVCircle()
        if SACircle and SA.DrawCircle then
            SACircle.Position = UIS:GetMouseLocation()
            SACircle.Radius = SA.DrawSize; SACircle.Visible = isSAActive(); SACircle.Color = SA.FOVCol
        end
    end

    local function startSALoop()
        if SALoopConn then return end
        SALoopConn = Runtime.Connect(RunService.Heartbeat, function(deltaTime)
            updFOVCircle()
            saTargetAccumulator += deltaTime
            if saTargetAccumulator >= (1 / 30) then
                saTargetAccumulator %= (1 / 30)
                _G.CurSATarget = getValidT()
            end
        end)
    end

    local SAShootConn = nil
    local ev2_bindable = game:GetService("ReplicatedStorage"):FindFirstChild("Events2")
    local ZFK_remote = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and game:GetService("ReplicatedStorage").Events:FindFirstChild("ZFKLF__H")

    local function hookShoot()
        if SAShootConn then return end
        local LP = Players.LocalPlayer
        
        if ev2_bindable and ZFK_remote then
            local viz = ev2_bindable:FindFirstChild("Visualize")
            if viz then
                SAShootConn = Runtime.Connect(viz.Event, function(_, sc, _, gun, _, sPos, bps)
                    if not isSAActive() then return end
                    local char = LP.Character; if not char then return end
                    local myG = char:FindFirstChildOfClass("Tool"); if not myG or myG ~= gun then return end
                    local t = _G.CurSATarget
                    if not canFire(t) or math.random(1, 100) > SA.HitChance then return end
                    local tp = t.Part; local pPos = tp.Position
                    local instantPelletDelivery = SA.InstantPelletDelivery
                    local rOff = Vector3.new((math.random()-0.5)*0.5,(math.random()-0.5)*0.5,(math.random()-0.5)*0.5)
                    local hitPos = SA.MagicBullet and pPos or pPos + rOff
                    local newB = {}; for i=1,#bps do
                        local dir = (hitPos - sPos).Unit; local spAmt = (100 - SA.HitChance)/500
                        local sp = Vector3.new((math.random()-0.5)*spAmt,(math.random()-0.5)*spAmt,(math.random()-0.5)*spAmt)
                        table.insert(newB, dir+sp)
                    end
                    Runtime.Spawn(function()
                         
                        for i=1,#newB do
                            if not instantPelletDelivery then task.wait(0.01) end
                             
                            if (i == 1 or not instantPelletDelivery)
                                and (not canFire(t) or LP.Character ~= char or gun.Parent ~= char) then break end
                            pcall(function() ZFK_remote:FireServer("🧈", gun, sc, i, tp, hitPos, newB[i]) end)
                        end
                    end)
                    if gun:FindFirstChild("Hitmarker") then gun.Hitmarker:Fire(tp) end
                end)
            end
        end
    end

    local function syncSARuntime()
        clearSATarget()
        if isSAActive() then
            crFOVCircle(); startSALoop(); hookShoot()
            return
        end
        if SALoopConn then SALoopConn:Disconnect(); SALoopConn = nil end
        if SACircle then SACircle:Remove(); SACircle = nil end
        if SAShootConn then SAShootConn:Disconnect(); SAShootConn = nil end
    end

     
     
     

    AimbotLeft:AddToggle("AimEnabled", { Text = "Aimbot", Default = false }):AddKeyPicker("AimbotKey", { Default = "None", Text = "Aimbot", Mode = "Toggle", SyncToggleState = true })
    Toggles.AimEnabled:OnChanged(function(state)
        on = state
        aimTarget = nil
        aimTargetAccumulator = 1 / 30
        if fovCircle then fovCircle.Visible = state end
    end)

    AimbotLeft:AddDropdown("TargetPart", { Text = "Target Part", Values = { "Head", "Torso" }, Default = 1 })
    Options.TargetPart:OnChanged(function() tgtPart = Options.TargetPart.Value end)

    AimbotLeft:AddToggle("VisibleCheck", { Text = "Visible Check", Default = false })
    Toggles.VisibleCheck:OnChanged(function(state) visibleCheck = state end)

    AimbotLeft:AddSlider("Sensitivity", { Text = "Sensitivity", Default = 50, Min = 0, Max = 100, Rounding = 0, Suffix = "%" })
    Options.Sensitivity:OnChanged(function(v) sensitivity = v end)

    AimbotLeft:AddSlider("FOV", { Text = "FOV Size", Default = 40, Min = 10, Max = 500, Rounding = 0, Suffix = "px" })
    Options.FOV:OnChanged(function(v) fovRadius = v end)

    AimbotLeft:AddDropdown("PlayerWhitelistAimbot", { Text = "Whitelist (Don't Lock)", Values = {}, Multi = true, Default = {} })

    AimbotRight:AddToggle("AimbotToggle", { Text = "Enable Silent Aim", Default = false }):AddKeyPicker("SilentAimKey", { Default = "None", Text = "Silent Aim", Mode = "Toggle", SyncToggleState = true })
    Toggles.AimbotToggle:OnChanged(function(state) SA.On = state; syncSARuntime() end)

    AimbotRight:AddToggle("MagicBullet", {
        Text = "Magic Bullet", Default = false,
        Tooltip = "Targets Head only and skips the client wall check. Shares FOV, whitelist, max distance and hit chance. Requires server acceptance; no curved bullet visuals.",
    }):AddKeyPicker("MagicBulletKey", { Default = "None", Text = "Magic Bullet", Mode = "Toggle", SyncToggleState = true })
    Toggles.MagicBullet:OnChanged(function(state) SA.MagicBullet = state; syncSARuntime() end)

    AimbotRight:AddToggle("InstantPelletDelivery", {
        Text = "Instant Pellet Delivery", Default = false,
        Tooltip = "For Silent Aim / Magic Bullet: sends the existing projectiles of one shot without EndHub's delay. Does not fire a whole magazine, create extra bullets, or guarantee a kill.",
    })
    Toggles.InstantPelletDelivery:OnChanged(function(state)
        SA.InstantPelletDelivery = state
        clearSATarget()
    end)
    AimbotRight:AddDivider()

    AimbotRight:AddDropdown("SATargetPart", { Text = "Target Part", Values = { "Head", "Torso", "Arms", "Legs", "Random" }, Default = 1 })
    Options.SATargetPart:OnChanged(function() SA.TMode = Options.SATargetPart.Value; clearSATarget() end)

    AimbotRight:AddToggle("DrawFOVToggle", { Text = "Draw FOV Circle", Default = false })
    Toggles.DrawFOVToggle:OnChanged(function(state) SA.DrawCircle = state; crFOVCircle() end)

    AimbotRight:AddSlider("FOVSize", { Text = "FOV Size", Default = 100, Min = 50, Max = 300, Rounding = 0, Suffix = "px" })
    Options.FOVSize:OnChanged(function(v) SA.DrawSize = v; clearSATarget(); if SACircle then SACircle.Radius = v end end)

    AimbotRight:AddSlider("HitChance", { Text = "Hit Chance", Default = 100, Min = 0, Max = 100, Rounding = 0, Suffix = "%" })
    Options.HitChance:OnChanged(function(v) SA.HitChance = v end)

    AimbotRight:AddSlider("MaxDistance", { Text = "Max Distance", Default = 500, Min = 100, Max = 2000, Rounding = 0, Suffix = "studs" })
    Options.MaxDistance:OnChanged(function(v) SA.MaxDist = v; clearSATarget() end)

    AimbotRight:AddDropdown("PlayerWhitelistSilent", { Text = "Whitelist (Don't Shoot)", Values = {}, Multi = true, Default = {} })

    local function UpdateWhitelistDropdowns()
        local playerNames = {}
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer then
                table.insert(playerNames, v.Name)
            end
        end
        local aimbotWhitelist = Options and Options.PlayerWhitelistAimbot
        local silentWhitelist = Options and Options.PlayerWhitelistSilent

        if aimbotWhitelist and type(aimbotWhitelist.SetValues) == "function" then
            aimbotWhitelist:SetValues(playerNames)
        end

        if silentWhitelist and type(silentWhitelist.SetValues) == "function" then
            silentWhitelist:SetValues(playerNames)
        end
    end

    local syncingWhitelist = false
    Options.PlayerWhitelistAimbot:OnChanged(function()
        if syncingWhitelist then return end
        syncingWhitelist = true
        GlobalWhitelist = {}
        for name, selected in pairs(Options.PlayerWhitelistAimbot.Value) do
            if selected then GlobalWhitelist[name] = true end
        end
        aimTarget = nil
        clearSATarget()
        Options.PlayerWhitelistSilent:SetValue(Options.PlayerWhitelistAimbot.Value)
        syncingWhitelist = false
    end)

    Options.PlayerWhitelistSilent:OnChanged(function()
        if syncingWhitelist then return end
        syncingWhitelist = true
        GlobalWhitelist = {}
        for name, selected in pairs(Options.PlayerWhitelistSilent.Value) do
            if selected then GlobalWhitelist[name] = true end
        end
        aimTarget = nil
        clearSATarget()
        Options.PlayerWhitelistAimbot:SetValue(Options.PlayerWhitelistSilent.Value)
        syncingWhitelist = false
    end)

    Runtime.Connect(Players.PlayerAdded, UpdateWhitelistDropdowns)
    Runtime.Connect(Players.PlayerRemoving, UpdateWhitelistDropdowns)
    UpdateWhitelistDropdowns()
    Library:OnUnload(function()
        on = false
        aimTarget = nil
        RunService:UnbindFromRenderStep("EndHubAimbot")
        SA.On = false
        SA.MagicBullet = false
        syncSARuntime()
        if fovCircle then fovCircle:Remove(); fovCircle = nil end
    end)
end

 
 
 
do

local ESPGeneral = ESPGroups.General
local ESPBoxes = ESPGroups.Boxes
local ESPText = ESPGroups.Text
local ESPHealth = ESPGroups.Health
local ESPLines = ESPGroups.Lines
local ViewRight = Tabs.Visuals:AddRightGroupbox("Crosshair", "crosshair")
local ChamsRight = Tabs.Visuals:AddRightGroupbox("Weapon Appearance", "blend")

ESPGeneral:AddLabel({
    Text = "Customize boxes/chams, text, health, and lines in the right-side tabs.",
    DoesWrap = true,
})

 
 
 

if UseCheapESP then

    ESPGeneral:AddToggle("ESPEnabled", {
        Text = "Enable ESP",
        Default = false,
    })

    ESPBoxes:AddToggle("ESPChams", {
        Text = "Chams Fill", Default = true,
    }):AddColorPicker("ESPFillColor", {
        Title = "Chams Fill Color", Default = Color3.new(1, 1, 1),
    })
    ESPBoxes:AddSlider("ESPFillOpacity", {
        Text = "Chams Fill Opacity", Default = 30, Min = 0, Max = 100, Rounding = 0, Suffix = "%",
    })

    ESPBoxes:AddToggle("ESPChamsOutline", {
        Text = "Chams Outline", Default = true,
    }):AddColorPicker("ESPBoxColor", {
        Title = "Chams Outline Color", Default = Color3.new(1, 1, 1),
    })
    ESPBoxes:AddSlider("ESPBoxOpacity", {
        Text = "Chams Outline Opacity", Default = 100, Min = 0, Max = 100, Rounding = 0, Suffix = "%",
    })

    ESPText:AddToggle("ESPName", {
        Text = "Name ESP", Default = true,
    }):AddColorPicker("ESPNameColor", {
        Title = "Name Color", Default = Color3.new(1, 1, 1),
    })
    ESPText:AddSlider("ESPTextOpacity", {
        Text = "Text Opacity", Default = 100, Min = 0, Max = 100, Rounding = 0, Suffix = "%",
    })
    ESPText:AddSlider("ESPTextSize", {
        Text = "Text Size", Default = 13, Min = 10, Max = 25, Rounding = 0,
    })
    ESPText:AddToggle("ESPTextOutline", {
        Text = "Text Outline", Default = true,
    })

    ESPLines:AddToggle("ESPTracer", {
        Text = "Line ESP (Tracer)", Default = false,
    }):AddColorPicker("ESPTracerColor", {
        Title = "Line Color", Default = Color3.new(1, 1, 1),
    })
    ESPLines:AddSlider("ESPTracerOpacity", {
        Text = "Line Opacity", Default = 100, Min = 0, Max = 100, Rounding = 0, Suffix = "%",
    })
    ESPLines:AddSlider("ESPTracerThickness", {
        Text = "Line Thickness", Default = 2, Min = 1, Max = 5, Rounding = 0,
    })
    ESPLines:AddDropdown("ESPTracerOrigin", {
        Text = "Line Origin", Values = { "Bottom", "Center", "Mouse", "Top" }, Default = 1,
    })
    ESPLines:AddDropdown("ESPTracerTarget", {
        Text = "Line Target", Values = { "Head", "Torso", "Feet" }, Default = 3,
    })
    ESPGeneral:AddSlider("ESPMaxDistance", {
        Text = "Max Distance", Default = 500, Min = 100, Max = 5000, Rounding = 0, Suffix = "studs",
    })

    ESPHealth:AddLabel({
        Text = "Health overlays are available in Drawing mode.",
        DoesWrap = true,
    })

    local ESPFolder = Instance.new("Folder")
    ESPFolder.Name = "EndHubESP"
    ESPFolder.Parent = CoreGui

    local LineGui = Instance.new("ScreenGui")
    LineGui.Name = "EndHubESPTracers"
    LineGui.IgnoreGuiInset = true
    LineGui.ResetOnSpawn = false
    LineGui.Enabled = false
    LineGui.Parent = CoreGui

    local ESPData = {}
    local ESPConnections = {}
    local Style
    local UpdateInterval = 1 / 30
    local Accumulator = 0
    local FeetOffset = Vector3.new(0, 3, 0)

    local function UpdateVisibility(Cache)
        local ShowHighlight = Style.Enabled and Cache.InRange and (Style.Chams or Style.ChamsOutline)
        local ShowName = Style.Enabled and Cache.InRange and Style.Name and Cache.Head ~= nil
        local ShowLine = Style.Enabled and Cache.InRange and Style.Tracer and Cache.TracerOnScreen

        if Cache.HighlightVisible ~= ShowHighlight then
            Cache.HighlightVisible = ShowHighlight
            Cache.Highlight.Enabled = ShowHighlight
        end
        if Cache.NameVisible ~= ShowName then
            Cache.NameVisible = ShowName
            Cache.Billboard.Enabled = ShowName
        end
        if Cache.LineVisible ~= ShowLine then
            Cache.LineVisible = ShowLine
            Cache.Line.Visible = ShowLine
        end
    end

    local function ApplyStyle(Cache)
        Cache.Highlight.FillColor = Style.FillColor
        Cache.Highlight.OutlineColor = Style.OutlineColor
        Cache.Highlight.FillTransparency = Style.Chams and Style.FillTransparency or 1
        Cache.Highlight.OutlineTransparency = Style.ChamsOutline and Style.OutlineTransparency or 1
        Cache.Billboard.MaxDistance = Style.MaxDistance
        Cache.Billboard.Size = UDim2.fromOffset(200, Style.TextSize + 8)
        Cache.Text.TextColor3 = Style.NameColor
        Cache.Text.TextTransparency = Style.TextTransparency
        Cache.Text.TextSize = Style.TextSize
        Cache.Text.TextStrokeTransparency = Style.TextOutline and Style.TextTransparency or 1
        Cache.Line.BackgroundColor3 = Style.TracerColor
        Cache.Line.BackgroundTransparency = Style.TracerTransparency
        Cache.Line.Size = UDim2.fromOffset(Cache.Line.Size.X.Offset, Style.TracerThickness)
    end

     
    local function RefreshStyle()
        if Library.Unloaded then return end
        Style = {
            Enabled = Toggles.ESPEnabled.Value,
            Chams = Toggles.ESPChams.Value and Options.ESPFillOpacity.Value > 0,
            ChamsOutline = Toggles.ESPChamsOutline.Value and Options.ESPBoxOpacity.Value > 0,
            Name = Toggles.ESPName.Value and Options.ESPTextOpacity.Value > 0,
            TextOutline = Toggles.ESPTextOutline.Value,
            Tracer = Toggles.ESPTracer.Value and Options.ESPTracerOpacity.Value > 0,
            FillColor = Options.ESPFillColor.Value,
            FillTransparency = 1 - Options.ESPFillOpacity.Value / 100,
            OutlineColor = Options.ESPBoxColor.Value,
            OutlineTransparency = 1 - Options.ESPBoxOpacity.Value / 100,
            NameColor = Options.ESPNameColor.Value,
            TextTransparency = 1 - Options.ESPTextOpacity.Value / 100,
            TextSize = Options.ESPTextSize.Value,
            TracerColor = Options.ESPTracerColor.Value,
            TracerTransparency = 1 - Options.ESPTracerOpacity.Value / 100,
            TracerThickness = Options.ESPTracerThickness.Value,
            TracerOrigin = Options.ESPTracerOrigin.Value,
            TracerTarget = Options.ESPTracerTarget.Value,
            MaxDistance = Options.ESPMaxDistance.Value,
            MaxDistanceSquared = Options.ESPMaxDistance.Value ^ 2,
        }
        Style.HasVisuals = Style.Chams or Style.ChamsOutline or Style.Name or Style.Tracer
        if LineGui.Enabled ~= Style.Enabled then LineGui.Enabled = Style.Enabled end
        for _, Cache in pairs(ESPData) do
            ApplyStyle(Cache)
            if not Style.Enabled or not Style.HasVisuals then
                Cache.InRange = false
                Cache.TracerOnScreen = false
            end
            UpdateVisibility(Cache)
        end
    end

    RefreshStyle()
    for _, Name in ipairs({
        "ESPEnabled", "ESPChams", "ESPChamsOutline", "ESPName", "ESPTextOutline", "ESPTracer",
    }) do
        Toggles[Name]:OnChanged(RefreshStyle)
    end
    for _, Name in ipairs({
        "ESPFillColor", "ESPFillOpacity", "ESPBoxColor", "ESPBoxOpacity", "ESPNameColor",
        "ESPTextOpacity", "ESPTextSize", "ESPTracerColor", "ESPTracerOpacity", "ESPTracerThickness",
        "ESPTracerOrigin", "ESPTracerTarget", "ESPMaxDistance",
    }) do
        Options[Name]:OnChanged(RefreshStyle)
    end

    local function BindCharacter(Cache, Character)
        if Cache.Character == Character then return end
        if Cache.ChildAddedConnection then Cache.ChildAddedConnection:Disconnect() end
        if Cache.ChildRemovedConnection then Cache.ChildRemovedConnection:Disconnect() end
        Cache.ChildAddedConnection = nil
        Cache.ChildRemovedConnection = nil
        Cache.Character = Character
        Cache.Root = nil
        Cache.Humanoid = nil
        Cache.Head = nil
        Cache.InRange = false
        Cache.TracerOnScreen = false
        Cache.Highlight.Adornee = Character
        Cache.Billboard.Adornee = nil
        UpdateVisibility(Cache)
        if not Character then return end

        local function CacheChild(Child)
            if Cache.Character ~= Character then return end
            if Child.Name == "HumanoidRootPart" and Child:IsA("BasePart") then
                Cache.Root = Child
            elseif Child.Name == "Head" and Child:IsA("BasePart") then
                Cache.Head = Child
                Cache.Billboard.Adornee = Child
            elseif Child:IsA("Humanoid") then
                Cache.Humanoid = Child
            end
        end

        Cache.ChildAddedConnection = Runtime.Connect(Character.ChildAdded, CacheChild)
        Cache.ChildRemovedConnection = Runtime.Connect(Character.ChildRemoved, function(Child)
            if Cache.Character ~= Character then return end
            local Changed = false
            if Child == Cache.Root then Cache.Root = nil; Changed = true end
            if Child == Cache.Humanoid then Cache.Humanoid = nil; Changed = true end
            if Child == Cache.Head then
                Cache.Head = nil
                Cache.Billboard.Adornee = nil
                Changed = true
            end
            if Changed then
                Cache.InRange = false
                Cache.TracerOnScreen = false
                UpdateVisibility(Cache)
            end
        end)
        for _, Child in ipairs(Character:GetChildren()) do CacheChild(Child) end
    end

    local function CreateESP(Player)
        if Player == LocalPlayer or ESPData[Player] then return end

        local Holder = Instance.new("Folder")
        Holder.Name = Player.Name
        Holder.Parent = ESPFolder

        local Highlight = Instance.new("Highlight")
        Highlight.Enabled = false
        Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        Highlight.Parent = Holder

        local Billboard = Instance.new("BillboardGui")
        Billboard.Name = "NameESP"
        Billboard.Enabled = false
        Billboard.AlwaysOnTop = true
        Billboard.StudsOffset = Vector3.new(0, 2.2, 0)
        Billboard.Parent = Holder

        local Text = Instance.new("TextLabel")
        Text.BackgroundTransparency = 1
        Text.Size = UDim2.fromScale(1, 1)
        Text.Text = Player.Name
        Text.TextScaled = false
        Text.TextStrokeColor3 = Color3.new(0, 0, 0)
        Text.Font = Enum.Font.SourceSansBold
        Text.Parent = Billboard

        local Line = Instance.new("Frame")
        Line.Name = Player.Name
        Line.AnchorPoint = Vector2.new(0.5, 0.5)
        Line.BorderSizePixel = 0
        Line.Visible = false
        Line.Parent = LineGui

        local Cache = {
            Holder = Holder, Highlight = Highlight, Billboard = Billboard, Text = Text, Line = Line,
            InRange = false, TracerOnScreen = false,
            HighlightVisible = false, NameVisible = false, LineVisible = false,
        }
        ESPData[Player] = Cache
        ApplyStyle(Cache)
        Cache.CharacterAddedConnection = Runtime.Connect(Player.CharacterAdded, function(Character)
            BindCharacter(Cache, Character)
        end)
        Cache.CharacterRemovingConnection = Runtime.Connect(Player.CharacterRemoving, function(Character)
            if Cache.Character == Character then BindCharacter(Cache, nil) end
        end)
        BindCharacter(Cache, Player.Character)
    end

    local function RemoveESP(Player)
        local Cache = ESPData[Player]
        if not Cache then return end
        ESPData[Player] = nil
        Cache.CharacterAddedConnection:Disconnect()
        Cache.CharacterRemovingConnection:Disconnect()
        BindCharacter(Cache, nil)
        Cache.Holder:Destroy()
        Cache.Line:Destroy()
    end

    table.insert(ESPConnections, Runtime.Connect(Players.PlayerAdded, CreateESP))
    table.insert(ESPConnections, Runtime.Connect(Players.PlayerRemoving, RemoveESP))
    for _, Player in ipairs(Players:GetPlayers()) do CreateESP(Player) end

    table.insert(ESPConnections, Runtime.Connect(RunService.RenderStepped, function(DeltaTime)
        if not Style.Enabled or not Style.HasVisuals then return end
        Accumulator += DeltaTime
        if Accumulator < UpdateInterval then return end
        Accumulator = 0

        local CurrentCamera = Camera
        local CameraPosition = CurrentCamera and CurrentCamera.CFrame.Position
        local From

        for _, Cache in pairs(ESPData) do
            Cache.InRange = false
            Cache.TracerOnScreen = false
            local Character, Root, Humanoid = Cache.Character, Cache.Root, Cache.Humanoid
            if CurrentCamera and Character and Character.Parent and Root and Root.Parent == Character
                and Humanoid and Humanoid.Parent == Character and Humanoid.Health > 0 then
                local RootPosition = Root.Position
                local Offset = RootPosition - CameraPosition
                if Offset:Dot(Offset) <= Style.MaxDistanceSquared then
                    Cache.InRange = true
                    if Style.Tracer then
                        local Target
                        if Style.TracerTarget == "Head" then
                            Target = Cache.Head and Cache.Head.Position
                        elseif Style.TracerTarget == "Torso" then
                            Target = RootPosition
                        else
                            Target = RootPosition - FeetOffset
                        end
                        if Target then
                            local Projected, OnScreen = CurrentCamera:WorldToViewportPoint(Target)
                            if OnScreen and Projected.Z > 0 then
                                if not From then
                                    local Viewport = CurrentCamera.ViewportSize
                                    if Style.TracerOrigin == "Mouse" then
                                        From = UserInputService:GetMouseLocation()
                                    elseif Style.TracerOrigin == "Center" then
                                        From = Viewport * 0.5
                                    elseif Style.TracerOrigin == "Top" then
                                        From = Vector2.new(Viewport.X * 0.5, 0)
                                    else
                                        From = Vector2.new(Viewport.X * 0.5, Viewport.Y)
                                    end
                                end
                                local To = Vector2.new(Projected.X, Projected.Y)
                                local Delta = To - From
                                local Length = Delta.Magnitude
                                if Length > 0 then
                                    local Midpoint = (From + To) * 0.5
                                    Cache.Line.Position = UDim2.fromOffset(Midpoint.X, Midpoint.Y)
                                    Cache.Line.Size = UDim2.fromOffset(Length, Style.TracerThickness)
                                    Cache.Line.Rotation = math.deg(math.atan2(Delta.Y, Delta.X))
                                    Cache.TracerOnScreen = true
                                end
                            end
                        end
                    end
                end
            end
            UpdateVisibility(Cache)
        end
    end))

    Library:OnUnload(function()
        for _, Connection in ipairs(ESPConnections) do Connection:Disconnect() end
        table.clear(ESPConnections)
        for Player in pairs(ESPData) do RemoveESP(Player) end
        ESPFolder:Destroy()
        LineGui:Destroy()
    end)

 
 
 

else

ESPGeneral:AddToggle("ESPEnabled", {
    Text = "Enable ESP",
    Default = false,
})

local BoxToggle = ESPBoxes:AddToggle("ESPBox", {
    Text = "Box ESP",
    Default = false,
})

BoxToggle:AddColorPicker("ESPBoxColor", {
    Default = Color3.fromRGB(167,251,255),
    Title = "Box Color",
})

local FillToggle = ESPBoxes:AddToggle("ESPFill", {
    Text = "Filled Box",
    Default = false,
})

FillToggle:AddColorPicker("ESPFillColor", {
    Default = Color3.fromRGB(167,251,255),
    Title = "Fill Color",
})

local NameToggle = ESPText:AddToggle("ESPName", {
    Text = "Name ESP",
    Default = false,
})

NameToggle:AddColorPicker("ESPNameColor", {
    Default = Color3.fromRGB(167,251,255),
    Title = "Name Color",
})

local DistanceToggle = ESPText:AddToggle("ESPDistance", {
    Text = "Distance ESP",
    Default = false,
})

DistanceToggle:AddColorPicker("ESPDistanceColor", {
    Default = Color3.fromRGB(167,251,255),
    Title = "Distance Color",
})

local HealthBarToggle = ESPHealth:AddToggle("ESPHealthBar", {
    Text = "Health Bar",
    Default = false,
})
HealthBarToggle:AddColorPicker("ESPHealthColor", {
    Default = Color3.fromRGB(0,255,100),
    Title = "Custom Health Color",
})

ESPHealth:AddToggle("ESPHealthText", {
    Text = "Health Text",
    Default = false,
})

local TracerToggle = ESPLines:AddToggle("ESPTracer", {
    Text = "Line ESP (Tracer)",
    Default = false,
})

TracerToggle:AddColorPicker("ESPTracerColor", {
    Default = Color3.fromRGB(167,251,255),
    Title = "Tracer Color",
})

ESPGeneral:AddSlider("ESPMaxDistance", {
    Text = "Max Distance",
    Default = 2000,
    Min = 100,
    Max = 5000,
    Rounding = 0,
    Suffix = "m",
})

ESPBoxes:AddSlider("ESPThickness", {
    Text = "Box Thickness",
    Default = 2,
    Min = 1,
    Max = 5,
    Rounding = 1,
})

ESPText:AddSlider("ESPTextSize", {
    Text = "Text Size",
    Default = 13,
    Min = 10,
    Max = 25,
    Rounding = 0,
})

ESPBoxes:AddSlider("ESPBoxOpacity", {
    Text = "Box Opacity",
    Default = 100,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
})
ESPBoxes:AddSlider("ESPFillOpacity", {
    Text = "Fill Opacity",
    Default = 20,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
})
ESPText:AddSlider("ESPTextOpacity", {
    Text = "Text Opacity",
    Default = 100,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
})
ESPHealth:AddSlider("ESPHealthOpacity", {
    Text = "Health Bar Opacity",
    Default = 100,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
})
ESPText:AddToggle("ESPTextOutline", {
    Text = "Text Outline",
    Default = true,
})
ESPText:AddDropdown("ESPFont", {
    Text = "Text Font",
    Values = { "UI", "System", "Plex", "Monospace" },
    Default = 3,
})
ESPText:AddDropdown("ESPNameMode", {
    Text = "Name Format",
    Values = { "Username", "Display Name", "Both" },
    Default = 1,
})
ESPHealth:AddDropdown("ESPHealthColorMode", {
    Text = "Health Color",
    Values = { "Health Gradient", "Custom" },
    Default = 1,
})
ESPGeneral:AddDropdown("ESPRefreshRate", {
    Text = "ESP Update Rate",
    Values = { "15 Hz", "30 Hz", "60 Hz" },
    Default = 3,
    Tooltip = "Only changes the ESP update rate, not the game's FPS limit.",
})

ESPLines:AddSlider("ESPTracerOpacity", {
    Text = "Line Opacity",
    Default = 100,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
})
ESPLines:AddSlider("ESPTracerThickness", {
    Text = "Line Thickness",
    Default = 2,
    Min = 1,
    Max = 5,
    Rounding = 1,
})
ESPLines:AddDropdown("ESPTracerOrigin", {
    Text = "Tracer Origin",
    Values = {
        "Bottom",
        "Center",
        "Mouse",
        "Top"
    },
    Default = 1,
})
ESPLines:AddDropdown("ESPTracerTarget", {
    Text = "Line Target",
    Values = { "Head", "Torso", "Feet" },
    Default = 3,
})


local ToggleStates = {
    ArmsChams = false
}
local OriginalArms = {}

 
local ArmsChamsToggle = ChamsRight:AddToggle("ArmsChamsToggle", {
    Text = "Arms Chams",
    Default = false,
})

 
ArmsChamsToggle:AddColorPicker("ArmsColor", {
    Default = Color3.fromRGB(0, 255, 255),  
    Title = "Arms Color",
    Transparency = 0,
})

 
local function updateArms()
    if not ToggleStates.ArmsChams then
        for arm, original in pairs(OriginalArms) do
            if arm.Parent then
                arm.Material = original.Material
                arm.Color = original.Color
            end
        end
        table.clear(OriginalArms)
        return
    end
    if not Camera then return end
    local view_model = Camera:FindFirstChild("ViewModel")
    if not view_model then return end

    local left_arm = view_model:FindFirstChild("Left Arm")
    local right_arm = view_model:FindFirstChild("Right Arm")

    for _, arm in pairs({left_arm, right_arm}) do
        if not OriginalArms[arm] then
            OriginalArms[arm] = {Material = arm.Material, Color = arm.Color}
        end
        arm.Material = Enum.Material.ForceField
        arm.Color = Options.ArmsColor.Value
    end
end

 
Toggles.ArmsChamsToggle:OnChanged(function(state)
    ToggleStates.ArmsChams = state
    updateArms()
end)

 
Options.ArmsColor:OnChanged(function()
    if ToggleStates.ArmsChams then updateArms() end
end)

 
Runtime.Connect(LocalPlayer.CharacterAdded, function(new_char)
    Runtime.Spawn(function()
        local camera = workspace.CurrentCamera
        if camera and camera:WaitForChild("ViewModel", 5)
            and not Library.Unloaded and LocalPlayer.Character == new_char then
            updateArms()
        end
    end)
end)
Library:OnUnload(function()
    ToggleStates.ArmsChams = false
    updateArms()
end)

 
 
 

local ESPCache = {}
local ESPFonts = { UI = 0, System = 1, Plex = 2, Monospace = 3 }

local function Create(Type, Props)

    local Obj = Drawing.new(Type)

    for i,v in pairs(Props) do
        Obj[i] = v
    end

    return Obj
end

local function HideESP(Cache)
    if not Cache or Cache.Hidden then
        return
    end

    for _, Obj in ipairs(Cache.Drawings) do
        Obj.Visible = false
    end
    Cache.Hidden = true
    Cache.TracerVisible = false
end

local function UpdateESPStyle(Cache)
    Cache.Box.Color = Options.ESPBoxColor.Value
    Cache.Box.Thickness = Options.ESPThickness.Value
    Cache.Box.Transparency = Options.ESPBoxOpacity.Value / 100
    Cache.Fill.Color = Options.ESPFillColor.Value
    Cache.Fill.Transparency = Options.ESPFillOpacity.Value / 100
    Cache.Name.Color = Options.ESPNameColor.Value
    Cache.Distance.Color = Options.ESPDistanceColor.Value
    local nameMode = Options.ESPNameMode.Value
    local username = Cache.Player.Name
    local displayName = Cache.Player.DisplayName
    Cache.Name.Text = nameMode == "Both" and (displayName .. " (@" .. username .. ")")
        or (nameMode == "Display Name" and displayName or username)
    for _, text in ipairs({Cache.Name, Cache.Distance, Cache.HealthText}) do
        text.Size = Options.ESPTextSize.Value
        text.Transparency = Options.ESPTextOpacity.Value / 100
        text.Outline = Toggles.ESPTextOutline.Value
        text.Font = ESPFonts[Options.ESPFont.Value]
    end
    Cache.HealthBar.Transparency = Options.ESPHealthOpacity.Value / 100
    Cache.HealthBarOutline.Transparency = Options.ESPHealthOpacity.Value / 100
    Cache.LastHealthTextPercent = nil
    Cache.LastHealthBarPercent = nil
    if Options.ESPHealthColorMode.Value == "Custom" then
        Cache.HealthText.Color = Options.ESPHealthColor.Value
        Cache.HealthBar.Color = Options.ESPHealthColor.Value
    end
    Cache.Tracer.Color = Options.ESPTracerColor.Value
    Cache.Tracer.Thickness = Options.ESPTracerThickness.Value
    Cache.Tracer.Transparency = Options.ESPTracerOpacity.Value / 100
end

local function CreateESP(Player)
    if ESPCache[Player] then return end

    ESPCache[Player] = {
        Player = Player,
        Character = nil,
        Humanoid = nil,
        Root = nil,
        Head = nil,
        CharacterConnection = nil,
        Hidden = true,

        Box = Create("Square", {
            Visible = false,
            Filled = false,
            Thickness = 2,
        }),

        Fill = Create("Square", {
            Visible = false,
            Filled = true,
            Transparency = 0.2,
        }),

        Name = Create("Text", {
            Text = Player.Name,
            Visible = false,
            Center = true,
            Outline = true,
            Font = 2,
            Size = 13,
        }),

        Distance = Create("Text", {
            Visible = false,
            Center = true,
            Outline = true,
            Font = 2,
            Size = 13,
        }),

        HealthText = Create("Text", {
            Visible = false,
            Center = true,
            Outline = true,
            Font = 2,
            Size = 13,
        }),

        HealthBarOutline = Create("Square", {
            Visible = false,
            Filled = true,
            Color = Color3.new(0,0,0),
        }),

        HealthBar = Create("Square", {
            Visible = false,
            Filled = true,
        }),

        Tracer = Create("Line", {
            Visible = false,
            Thickness = 2,
        }),
    }

    local Cache = ESPCache[Player]
    Cache.Drawings = {
        Cache.Box, Cache.Fill, Cache.Name, Cache.Distance,
        Cache.HealthText, Cache.HealthBarOutline, Cache.HealthBar, Cache.Tracer,
    }
    UpdateESPStyle(Cache)

    local function UpdateCharacter(Character)
        HideESP(Cache)
        if Cache.ChildAddedConnection then Cache.ChildAddedConnection:Disconnect() end
        if Cache.ChildRemovedConnection then Cache.ChildRemovedConnection:Disconnect() end
        Cache.ChildAddedConnection = nil
        Cache.ChildRemovedConnection = nil
        Cache.Character = Character
        Cache.Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        Cache.Root = Character and Character:FindFirstChild("HumanoidRootPart")
        Cache.Head = Character and Character:FindFirstChild("Head")
        if Character then
            Cache.ChildAddedConnection = Runtime.Connect(Character.ChildAdded, function(child)
                if child:IsA("Humanoid") then Cache.Humanoid = child end
                if child.Name == "HumanoidRootPart" and child:IsA("BasePart") then Cache.Root = child end
                if child.Name == "Head" and child:IsA("BasePart") then Cache.Head = child end
            end)
            Cache.ChildRemovedConnection = Runtime.Connect(Character.ChildRemoved, function(child)
                if child == Cache.Humanoid then Cache.Humanoid = nil end
                if child == Cache.Root then Cache.Root = nil end
                if child == Cache.Head then Cache.Head = nil end
            end)
        end
    end

    Cache.CharacterConnection = Runtime.Connect(Player.CharacterAdded, function(Character)
        UpdateCharacter(Character)
    end)
    Cache.CharacterRemovingConnection = Runtime.Connect(Player.CharacterRemoving, function(Character)
        if Cache.Character == Character then UpdateCharacter(nil) end
    end)

    UpdateCharacter(Player.Character)
end

for _,Player in pairs(Players:GetPlayers()) do

    if Player ~= LocalPlayer then
        CreateESP(Player)
    end
end

Runtime.Connect(Players.PlayerAdded, function(Player)

    if Player ~= LocalPlayer then
        CreateESP(Player)
    end
end)

local function RemoveESP(Player)
    local Cache = ESPCache[Player]
    if not Cache then return end
    for _, key in ipairs({"CharacterConnection", "CharacterRemovingConnection", "ChildAddedConnection", "ChildRemovedConnection"}) do
        if Cache[key] then Cache[key]:Disconnect() end
    end
    for _, Obj in ipairs(Cache.Drawings) do Obj:Remove() end
    ESPCache[Player] = nil
end

Runtime.Connect(Players.PlayerRemoving, RemoveESP)
Library:OnUnload(function()
    for Player in pairs(ESPCache) do RemoveESP(Player) end
end)

for _, name in ipairs({
    "ESPBoxColor", "ESPThickness", "ESPFillColor", "ESPNameColor",
    "ESPTextSize", "ESPDistanceColor", "ESPTracerColor",
    "ESPBoxOpacity", "ESPFillOpacity", "ESPTextOpacity", "ESPHealthOpacity",
    "ESPTracerOpacity", "ESPTracerThickness", "ESPFont", "ESPNameMode",
    "ESPHealthColor", "ESPHealthColorMode",
}) do
    Options[name]:OnChanged(function()
        for _, Cache in pairs(ESPCache) do UpdateESPStyle(Cache) end
    end)
end
Toggles.ESPTextOutline:OnChanged(function()
    for _, Cache in pairs(ESPCache) do UpdateESPStyle(Cache) end
end)

Toggles.ESPEnabled:OnChanged(function(state)
    if not state then
        for _, Cache in pairs(ESPCache) do HideESP(Cache) end
    end
end)

 
 
 

local espUpdateAccumulator = 0
local espUpdateInterval = 1 / 60
Options.ESPRefreshRate:OnChanged(function(value)
    local rate = tonumber(value:match("%d+")) or 60
    espUpdateInterval = 1 / math.clamp(rate, 15, 60)
    espUpdateAccumulator = espUpdateInterval
end)
Runtime.Connect(RunService.RenderStepped, function(deltaTime)

    local espToggle = Toggles and Toggles.ESPEnabled
    if not espToggle or not espToggle.Value or not Camera then return end

    espUpdateAccumulator += deltaTime
    if espUpdateAccumulator < espUpdateInterval then return end
    espUpdateAccumulator %= espUpdateInterval

    local showBox = Toggles.ESPBox.Value and Options.ESPBoxOpacity.Value > 0
    local showFill = Toggles.ESPBox.Value and Toggles.ESPFill.Value and Options.ESPFillOpacity.Value > 0
    local textVisible = Options.ESPTextOpacity.Value > 0
    local showName = Toggles.ESPName.Value and textVisible
    local showDistance = Toggles.ESPDistance.Value and textVisible
    local showHealthText = Toggles.ESPHealthText.Value and textVisible
    local showHealthBar = Toggles.ESPHealthBar.Value and Options.ESPHealthOpacity.Value > 0
    local showTracer = Toggles.ESPTracer.Value and Options.ESPTracerOpacity.Value > 0
    local healthGradient = Options.ESPHealthColorMode.Value == "Health Gradient"
    local tracerTarget = Options.ESPTracerTarget.Value
    local mode = (showBox and 1 or 0) + (showFill and 2 or 0) + (showName and 4 or 0)
        + (showDistance and 8 or 0) + (showHealthText and 16 or 0)
        + (showHealthBar and 32 or 0) + (showTracer and 64 or 0)
    if mode == 0 then
        for _, Cache in pairs(ESPCache) do HideESP(Cache) end
        return
    end

    local cameraPosition = Camera.CFrame.Position
    local viewport = Camera.ViewportSize
    local maxDistance = Options.ESPMaxDistance.Value
    local tracerFrom
    if showTracer then
        local origin = Options.ESPTracerOrigin.Value
        if origin == "Mouse" then
            tracerFrom = UserInputService:GetMouseLocation()
        elseif origin == "Center" then
            tracerFrom = viewport / 2
        else
            tracerFrom = Vector2.new(viewport.X / 2, origin == "Top" and 0 or viewport.Y)
        end
    end

    for Player,Cache in pairs(ESPCache) do

        local Character = Cache.Character
        local Humanoid = Cache.Humanoid
        local Root = Cache.Root

        if not Character
        or not Humanoid
        or not Root
        or not Root.Parent
        or Humanoid.Health <= 0 then

            HideESP(Cache)
            continue
        end

        local rootPosition = Root.Position
        local Distance = (rootPosition - cameraPosition).Magnitude

        if Distance > maxDistance then

            HideESP(Cache)
            continue
        end

        local Vector, OnScreen =
            Camera:WorldToViewportPoint(rootPosition)

        if not OnScreen or Vector.Z <= 0 then

            HideESP(Cache)
            continue
        end

        local Top =
            Camera:WorldToViewportPoint(
                rootPosition + Vector3.new(0,3,0)
            )

        local Bottom =
            Camera:WorldToViewportPoint(
                rootPosition - Vector3.new(0,3,0)
            )

        local Height = math.clamp(math.abs(Top.Y - Bottom.Y), 1, viewport.Y * 2)
        local Width = Height / 2

        local X = Vector.X - Width / 2
        local Y = Vector.Y - Height / 2

        if Cache.Hidden or Cache.Mode ~= mode then
            Cache.Box.Visible = showBox
            Cache.Fill.Visible = showFill
            Cache.Name.Visible = showName
            Cache.Distance.Visible = showDistance
            Cache.HealthText.Visible = showHealthText
            Cache.HealthBarOutline.Visible = showHealthBar
            Cache.HealthBar.Visible = showHealthBar
            Cache.Tracer.Visible = showTracer
            Cache.TracerVisible = showTracer
            Cache.Hidden = false
            Cache.Mode = mode
        end

        if showBox or showFill then
            local size = Vector2.new(Width, Height)
            local position = Vector2.new(X, Y)
            if showBox then
                Cache.Box.Size = size
                Cache.Box.Position = position
            end
            if showFill then
                Cache.Fill.Size = size
                Cache.Fill.Position = position
            end
        end
        if showName then Cache.Name.Position = Vector2.new(Vector.X, Y - 16) end
        if showDistance then
            local distance = math.floor(Distance)
            if Cache.LastDistance ~= distance then
                Cache.Distance.Text = distance .. "m"
                Cache.LastDistance = distance
            end
            Cache.Distance.Position = Vector2.new(Vector.X, Y + Height + 2)
        end
        if showHealthText or showHealthBar then
            local healthPercent = math.clamp(Humanoid.Health / math.max(Humanoid.MaxHealth, 1), 0, 1)
            if healthGradient and ((showHealthText and Cache.LastHealthTextPercent ~= healthPercent)
                or (showHealthBar and Cache.LastHealthBarPercent ~= healthPercent)) then
                local color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                if showHealthText and Cache.LastHealthTextPercent ~= healthPercent then
                    Cache.HealthText.Color = color
                    Cache.LastHealthTextPercent = healthPercent
                end
                if showHealthBar and Cache.LastHealthBarPercent ~= healthPercent then
                    Cache.HealthBar.Color = color
                    Cache.LastHealthBarPercent = healthPercent
                end
            end
            if showHealthText then
                local health = math.floor(Humanoid.Health)
                if Cache.LastHealth ~= health then
                    Cache.HealthText.Text = tostring(health)
                    Cache.LastHealth = health
                end
                Cache.HealthText.Position = Vector2.new(X - 25, Y + Height - 10)
            end
            if showHealthBar then
                local barHeight = Height * healthPercent
                Cache.HealthBarOutline.Size = Vector2.new(4, Height)
                Cache.HealthBarOutline.Position = Vector2.new(X - 7, Y)
                Cache.HealthBar.Size = Vector2.new(2, barHeight)
                Cache.HealthBar.Position = Vector2.new(X - 6, Y + Height - barHeight)
            end
        end
        if showTracer then
            local target = tracerTarget == "Torso" and Vector or Bottom
            if tracerTarget == "Head" then
                local head = Cache.Head
                target = head and Camera:WorldToViewportPoint(head.Position) or Top
            end
            local lineVisible = target.Z > 0 and target.X >= 0 and target.X <= viewport.X
                and target.Y >= 0 and target.Y <= viewport.Y
            if Cache.TracerVisible ~= lineVisible then
                Cache.Tracer.Visible = lineVisible
                Cache.TracerVisible = lineVisible
            end
            if lineVisible then
                Cache.Tracer.From = tracerFrom
                Cache.Tracer.To = Vector2.new(target.X, target.Y)
            end
        end
    end
end)

end
 
 
 

local UserInputService = game:GetService("UserInputService")

local CrosshairGui = nil
local RotationConnection = nil
local Rotation = 0
local SpinVelocity = 0
local CurrentStyle = "Default"

local CrosshairColor = Color3.fromRGB(167,251,255)

 
local CrosshairToggle = ViewRight:AddToggle("CrosshairToggle", {
    Text = "Enable Crosshair",
    Default = false,
})

local SpinToggle = ViewRight:AddToggle("SpinToggle", {
    Text = "Spin",
    Default = true,
})

local FollowMouseToggle = ViewRight:AddToggle("FollowMouseToggle", {
    Text = "Follow Mouse",
    Default = false,
})

 
CrosshairToggle:AddColorPicker("CrosshairColor", {
    Default = CrosshairColor,
    Title = "Crosshair Color",
})

 
ViewRight:AddDropdown("CrosshairStyle", {
    Text = "Crosshair Style",
    Values = {
        "Default",
        "Tiny",
        "Dot",
        "Custom"
    },
    Default = 1,
})

 
local GapSlider = ViewRight:AddSlider("CrosshairGap", {
    Text = "Crosshair Gap",
    Default = 13,
    Min = 2,
    Max = 25,
    Rounding = 0,
    Suffix = "px",
})

 
local CustomInput = ViewRight:AddInput("CustomCrosshairID", {
    Text = "Custom Roblox Image ID",
    Placeholder = "rbxassetid://123456",
    Default = "",
})

CustomInput:SetVisible(false)

 
local ImageScaleSlider = ViewRight:AddSlider("CustomImageScale", {
    Text = "Custom Image Scale",
    Default = 40,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Suffix = "px",
})

ImageScaleSlider:SetVisible(false)

 
local function NormalizeAsset(input)

    input = tostring(input or "")

    if input == "" then
        return ""
    end

    if string.find(input, "rbxassetid://") then
        return input
    end

    return "rbxassetid://" .. input
end

local function CreateCorner(obj)

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(1,0)
    Corner.Parent = obj
end

local function CreateLine(parent, x, y, w, h)

    local Line = Instance.new("Frame")
    Line.BorderSizePixel = 0
    Line.BackgroundColor3 = CrosshairColor

    Line.Size = UDim2.new(0, w, 0, h)

    Line.Position = UDim2.new(
        0.5,
        x,
        0.5,
        y
    )

    Line.AnchorPoint = Vector2.new(0.5,0.5)
    Line.ZIndex = 2
    Line.Parent = parent

    CreateCorner(Line)

    return Line
end

local function CreateDot(parent, size)

    local Dot = Instance.new("Frame")
    Dot.BorderSizePixel = 0
    Dot.BackgroundColor3 = CrosshairColor

    Dot.Size = UDim2.new(0,size,0,size)

    Dot.Position = UDim2.new(
        0.5,
        0,
        0.5,
        0
    )

    Dot.AnchorPoint = Vector2.new(0.5,0.5)
    Dot.ZIndex = 2
    Dot.Parent = parent

    CreateCorner(Dot)

    return Dot
end

 
local function CreateCrosshair()

    if CrosshairGui then
        CrosshairGui:Destroy()
    end

    local Gap = Options.CrosshairGap.Value

    local Gui = Instance.new("ScreenGui")
    Gui.Name = "CustomCrosshair"
    Gui.ResetOnSpawn = false
    Gui.IgnoreGuiInset = true
    Gui.Parent = CoreGui

    local Holder = Instance.new("Frame")
    Holder.Name = "Holder"

    Holder.Size = UDim2.new(0,120,0,120)

    Holder.Position = UDim2.new(
        0.5,
        0,
        0.5,
        0
    )

    Holder.AnchorPoint = Vector2.new(0.5,0.5)

    Holder.BackgroundTransparency = 1
    Holder.Parent = Gui

     
    if CurrentStyle == "Default" then

        CreateLine(Holder,0,-Gap,3,14)
        CreateLine(Holder,0,Gap,3,14)

        CreateLine(Holder,-Gap,0,14,3)
        CreateLine(Holder,Gap,0,14,3)

     
    elseif CurrentStyle == "Tiny" then

        local TinyGap = math.max(4, Gap - 5)

        CreateLine(Holder,0,-TinyGap,2,8)
        CreateLine(Holder,0,TinyGap,2,8)

        CreateLine(Holder,-TinyGap,0,8,2)
        CreateLine(Holder,TinyGap,0,8,2)

     
    elseif CurrentStyle == "Dot" then

        CreateDot(Holder,6)

     
    elseif CurrentStyle == "Custom" then

        local Size = Options.CustomImageScale.Value

        local Image = Instance.new("ImageLabel")
        Image.BackgroundTransparency = 1

        Image.Size = UDim2.new(0,Size,0,Size)

        Image.Position = UDim2.new(
            0.5,
            0,
            0.5,
            0
        )

        Image.AnchorPoint = Vector2.new(0.5,0.5)

        Image.Image = NormalizeAsset(
            Options.CustomCrosshairID.Value
        )

        Image.ImageColor3 = Color3.new(1,1,1)

        Image.ZIndex = 2
        Image.Parent = Holder
    end

    CrosshairGui = Gui

    if RotationConnection then
        RotationConnection:Disconnect()
    end

    RotationConnection = Runtime.Connect(RunService.RenderStepped, function(delta)

        if Toggles.FollowMouseToggle.Value then

            local MousePos = UserInputService:GetMouseLocation()

            Holder.Position = UDim2.new(
                0,
                MousePos.X,
                0,
                MousePos.Y
            )

        else

            Holder.Position = UDim2.new(
                0.5,
                0,
                0.5,
                0
            )
        end

        if Toggles.SpinToggle.Value then
            SpinVelocity = SpinVelocity + ((120 - SpinVelocity) * (delta * 4))
        else
            SpinVelocity = SpinVelocity + ((0 - SpinVelocity) * (delta * 6))
        end

        Rotation += SpinVelocity * delta
        Holder.Rotation = Rotation
    end)
end

 
Options.CrosshairColor:OnChanged(function()

    CrosshairColor = Options.CrosshairColor.Value

    if Toggles.CrosshairToggle.Value
    and CurrentStyle ~= "Custom" then
        CreateCrosshair()
    end
end)

 
Options.CrosshairStyle:OnChanged(function()

    CurrentStyle = Options.CrosshairStyle.Value

    local IsCustom = CurrentStyle == "Custom"
    local IsDot = CurrentStyle == "Dot"

    CustomInput:SetVisible(IsCustom)
    ImageScaleSlider:SetVisible(IsCustom)

    GapSlider:SetVisible(
        not IsCustom
        and not IsDot
    )

    SpinToggle:SetVisible(not IsDot)

    if IsDot then Toggles.SpinToggle:SetValue(false) end

    if Toggles.CrosshairToggle.Value then
        CreateCrosshair()
    end
end)

Options.CrosshairStyle:SetValue("Default")

 
Options.CrosshairGap:OnChanged(function()

    if CurrentStyle ~= "Custom"
    and CurrentStyle ~= "Dot"
    and Toggles.CrosshairToggle.Value then
        CreateCrosshair()
    end
end)

 
Options.CustomCrosshairID:OnChanged(function()

    if CurrentStyle == "Custom"
    and Toggles.CrosshairToggle.Value then
        CreateCrosshair()
    end
end)

 
Options.CustomImageScale:OnChanged(function()

    if CurrentStyle == "Custom"
    and Toggles.CrosshairToggle.Value then
        CreateCrosshair()
    end
end)

 
Toggles.CrosshairToggle:OnChanged(function(state)

    if state then

        CreateCrosshair()

    else

        if RotationConnection then
            RotationConnection:Disconnect()
            RotationConnection = nil
        end

        if CrosshairGui then
            CrosshairGui:Destroy()
            CrosshairGui = nil
        end
    end
end)
Library:OnUnload(function()
    if CrosshairGui then CrosshairGui:Destroy(); CrosshairGui = nil end
    RotationConnection = nil
end)
end























 
 
 
do
    local CameraBox = Tabs.Visuals:AddLeftGroupbox("Camera", "camera")
    local LightingBox = Tabs.Visuals:AddRightGroupbox("Lighting", "sun")
    local PerformanceBox = Tabs.Settings:AddRightGroupbox("Performance", "gauge")
    local WorldESP = ESPGroups.World

     
    local Players = game:GetService("Players")
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")

    local LocalPlayer = Players.LocalPlayer
    local Terrain = workspace:FindFirstChildOfClass("Terrain")

    local FullBright_Enabled = false
    local OriginalLighting

     
     
     

    local fpsEnabled = false
    local saved = {}

    local function enableFPS()
        if next(saved) then return end

        saved.GlobalShadows = Lighting.GlobalShadows
         
        saved.FogEnd = FullBright_Enabled and OriginalLighting.FogEnd or Lighting.FogEnd
        saved.Brightness = FullBright_Enabled and OriginalLighting.Brightness or Lighting.Brightness

        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 0

        if Terrain then
            saved.Terrain = {
                WaterWaveSize = Terrain.WaterWaveSize,
                WaterWaveSpeed = Terrain.WaterWaveSpeed,
                WaterReflectance = Terrain.WaterReflectance,
                WaterTransparency = Terrain.WaterTransparency,
            }
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 1
        end

        for _, v in ipairs(workspace:GetDescendants()) do
            if Camera and v:IsDescendantOf(Camera) then continue end
            if v:IsA("BasePart") then
                if not saved[v] then
                    saved[v] = {
                        Material = v.Material,
                        Reflectance = v.Reflectance
                    }
                end

                v.Material = Enum.Material.Plastic
                v.Reflectance = 0

            elseif v:IsA("Decal") or v:IsA("Texture") then
                if not saved[v] then
                    saved[v] = {
                        Transparency = v.Transparency
                    }
                end

                v.Transparency = 1

            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                if not saved[v] then
                    saved[v] = {
                        Enabled = v.Enabled
                    }
                end

                v.Enabled = false
            end
        end
    end

    local function disableFPS()
        if not next(saved) then return end

        Lighting.GlobalShadows = saved.GlobalShadows
        Lighting.FogEnd = saved.FogEnd
        Lighting.Brightness = saved.Brightness

        if Terrain and saved.Terrain then
            for property, value in pairs(saved.Terrain) do
                Terrain[property] = value
            end
        end

        for obj, data in pairs(saved) do
            if typeof(obj) == "Instance" and obj.Parent then
                if obj:IsA("BasePart") then
                    obj.Material = data.Material
                    obj.Reflectance = data.Reflectance

                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = data.Transparency

                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                    obj.Enabled = data.Enabled
                end
            end
        end

        table.clear(saved)
        if FullBright_Enabled then
            Lighting.Brightness = 5
            Lighting.FogEnd = 100000
        end
    end

    PerformanceBox:AddToggle("FPSBoost", {
        Text = "FPS Boost",
        Default = false,
    })

    Toggles.FPSBoost:OnChanged(function(state)
        if state == fpsEnabled or Library.Unloaded then return end
        fpsEnabled = state

        if state then
            enableFPS()
        else
            disableFPS()
        end
    end)

     
     
     

    local FullBright_Connection

    OriginalLighting = {
        ClockTime = Lighting.ClockTime,
        Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ColorShift_Top = Lighting.ColorShift_Top,
        FogStart = Lighting.FogStart,
        FogEnd = Lighting.FogEnd,
    }

    local function applyFullBright()
        Lighting.Brightness = 5
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.new(1,1,1)
        Lighting.OutdoorAmbient = Color3.new(1,1,1)
        Lighting.ColorShift_Top = Color3.new(0,0,0)
        Lighting.FogStart = 0
        Lighting.FogEnd = 100000
    end

    local function FullBright_Enable()
        if FullBright_Enabled or Library.Unloaded then
            return
        end

        for property in pairs(OriginalLighting) do
            OriginalLighting[property] = Lighting[property]
        end
        if fpsEnabled then
            OriginalLighting.Brightness = saved.Brightness
            OriginalLighting.FogEnd = saved.FogEnd
        end
        FullBright_Enabled = true

        applyFullBright()

        FullBright_Connection = Runtime.Spawn(function()
            while FullBright_Enabled and not Library.Unloaded do
                applyFullBright()
                task.wait(0.25)
            end
        end)
    end

    local function FullBright_Disable()
        if not FullBright_Enabled then return end
        FullBright_Enabled = false

        Runtime.Cancel(FullBright_Connection)
        FullBright_Connection = nil

        for i, v in pairs(OriginalLighting) do
            Lighting[i] = v
        end
        if fpsEnabled then
            Lighting.Brightness = 0
            Lighting.FogEnd = 9e9
        end
    end

    LightingBox:AddToggle("FullBrightToggle", {
        Text = "FullBright",
        Default = false,
    })

    Toggles.FullBrightToggle:OnChanged(function(state)
        if state then
            FullBright_Enable()
        else
            FullBright_Disable()
        end
    end)

     
     
     

    local FovOriginals = {}
    local Fov_Enabled = false
    local function restoreFov()
        for camera, value in pairs(FovOriginals) do
            if camera.Parent then camera.FieldOfView = value end
        end
        table.clear(FovOriginals)
    end

    CameraBox:AddToggle("FovToggle", {
        Text = "High Fov",
        Default = false,
    })

    EndHubFreeCam({ Library = Library, Runtime = Runtime, LocalPlayer = LocalPlayer, Group = CameraBox })

    CameraBox:AddSlider("FovSlider", {
        Text = "Field of View",
        Default = 80,
        Min = 50,
        Max = 120,
        Rounding = 0,
        Suffix = "°",
        Visible = false,
    })

    Toggles.FovToggle:OnChanged(function(state)
        if Library.Unloaded or state == Fov_Enabled then return end
        Fov_Enabled = state

        Options.FovSlider:SetVisible(state)

        if not state then
            restoreFov()
        end
    end)

    Runtime.Connect(RunService.RenderStepped, function()
        if Fov_Enabled and Camera then
            if not FovOriginals[Camera] then FovOriginals[Camera] = Camera.FieldOfView end
            local value = Options.FovSlider.Value
            if Camera.FieldOfView ~= value then Camera.FieldOfView = value end
        end
    end)

    Library:OnUnload(function()
        FullBright_Disable()
        disableFPS()
        fpsEnabled = false
        Fov_Enabled = false
        restoreFov()
    end)

     
     
     

    local espEnabled = false
    local espObjects = {}

    local function watchESPContainer(resolve, descendants, create, remove)
        Runtime.Spawn(function()
            local container
            local addedConnection
            local removingConnection
            local tracked = {}
            local function added(obj)
                tracked[obj] = true
                create(obj)
            end
            local function removing(obj)
                tracked[obj] = nil
                remove(obj)
            end
            Library:OnUnload(function()
                for obj in pairs(tracked) do remove(obj) end
                table.clear(tracked)
            end)
            while not Library.Unloaded do
                local nextContainer = resolve()
                if nextContainer ~= container then
                    if addedConnection then addedConnection:Disconnect() end
                    if removingConnection then removingConnection:Disconnect() end
                    for obj in pairs(tracked) do remove(obj) end
                    table.clear(tracked)
                    container = nextContainer
                    if container then
                        addedConnection = Runtime.Connect(descendants and container.DescendantAdded or container.ChildAdded, added)
                        removingConnection = Runtime.Connect(descendants and container.DescendantRemoving or container.ChildRemoved, removing)
                        for _, obj in ipairs(descendants and container:GetDescendants() or container:GetChildren()) do
                            added(obj)
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    end

    local function getPileContainer()
        local filter = workspace:FindFirstChild("Filter")
        return filter and filter:FindFirstChild("SpawnedPiles")
    end

    local function isBest(particle)
        if not particle or not particle:IsA("ParticleEmitter") then
            return false
        end

        local kp = particle.Color.Keypoints

        if #kp == 0 then
            return false
        end

        local c = kp[1].Value

        local function close(a, b)
            return math.abs(a - b) < 0.08
        end

        return close(c.R,1)
            and close(c.G,0.18)
            and close(c.B,0.18)
    end

    local function getDistance(pos)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not hrp then
            return nil
        end

        return math.floor((hrp.Position - pos).Magnitude)
    end

    local function createESP(obj)
        if not Drawing then return end
        if not obj:IsA("MeshPart") then
            return
        end

        if espObjects[obj] then
            return
        end

        local particle = obj:FindFirstChildOfClass("ParticleEmitter")

        if not isBest(particle) then
            return
        end

        local text = Drawing.new("Text")
        text.Size = 16
        text.Center = true
        text.Outline = true
        text.OutlineColor = Color3.fromRGB(0,0,0)
        text.Color = Color3.fromRGB(255,0,0)
        text.Visible = false

        espObjects[obj] = text
    end

    local function removeESP(obj)
        if espObjects[obj] then
            espObjects[obj]:Remove()
            espObjects[obj] = nil
        end
    end

    Library:OnUnload(function()
        espEnabled = false
        for obj in pairs(espObjects) do removeESP(obj) end
    end)
    watchESPContainer(getPileContainer, true, createESP, removeESP)

    local crateEspAccumulator = 0
    Runtime.Connect(RunService.RenderStepped, function(deltaTime)
        if not espEnabled or not cam then return end
        crateEspAccumulator += deltaTime
        if crateEspAccumulator < (1 / 30) then return end
        crateEspAccumulator = 0

        for obj, drawing in pairs(espObjects) do
            if obj and obj.Parent then
                local pos, onScreen = cam:WorldToViewportPoint(obj.Position)

                if onScreen then
                    local dist = getDistance(obj.Position)
                    if not dist then
                        drawing.Visible = false
                        continue
                    end

                    drawing.Position = Vector2.new(pos.X, pos.Y)
                    local label = "Red Crate [" .. dist .. "m]"
                    if drawing.Text ~= label then drawing.Text = label end
                    drawing.Visible = true
                else
                    drawing.Visible = false
                end
            else
                drawing.Visible = false
            end
        end
    end)

    WorldESP:AddToggle("BestESP", {
        Text = "Red Crate ESP",
        Default = false,
        Disabled = not Drawing,
    })

    Toggles.BestESP:OnChanged(function(state)
        espEnabled = state
        if not state then
            for _, drawing in pairs(espObjects) do
                drawing.Visible = false
            end
        end
    end)

     
     
     

    local safeEspEnabled = false
    local safeEspObjects = {}

    local selectedSafeFilter = "All"

    local function getSafeCleanName(name)
        if name:find("MediumSafe") then
            return "MediumSafe"
        elseif name:find("Register") then
            return "Register"
        elseif name:find("SmallSafe") then
            return "SmallSafe"
        end
    end

    local function getSafePosition(obj)
        if obj:IsA("BasePart") then
            return obj.Position
        elseif obj:IsA("Model") then
            local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            return primary and primary.Position
        end
    end

    local function isSafeBroken(obj)
        local values = obj:FindFirstChild("Values")
        local broken = values and values:FindFirstChild("Broken")

        return broken and broken.Value or false
    end

    local function createSafeESP(obj)
        if not Drawing then return end
        local clean = getSafeCleanName(obj.Name)

        if not clean or safeEspObjects[obj] then
            return
        end

        local nameText = Drawing.new("Text")
        nameText.Size = 16
        nameText.Center = true
        nameText.Outline = true
        nameText.OutlineColor = Color3.fromRGB(0,0,0)
        nameText.Visible = false

        nameText.Text = clean

        local distText = Drawing.new("Text")
        distText.Size = 14
        distText.Center = true
        distText.Outline = true
        distText.OutlineColor = Color3.fromRGB(0,0,0)
        distText.Color = Color3.fromRGB(255,255,255)
        distText.Visible = false

        safeEspObjects[obj] = {
            name = nameText,
            dist = distText,
            label = clean
        }
    end

    local function removeSafeESP(obj)
        if safeEspObjects[obj] then
            safeEspObjects[obj].name:Remove()
            safeEspObjects[obj].dist:Remove()
            safeEspObjects[obj] = nil
        end
    end

    Library:OnUnload(function()
        safeEspEnabled = false
        for obj in pairs(safeEspObjects) do removeSafeESP(obj) end
    end)
    watchESPContainer(function()
        local map = workspace:FindFirstChild("Map")
        return map and map:FindFirstChild("BredMakurz")
    end, true, createSafeESP, removeSafeESP)

    local safeEspAccumulator = 0
    Runtime.Connect(RunService.RenderStepped, function(deltaTime)
        if not safeEspEnabled or not cam then return end
        safeEspAccumulator += deltaTime
        if safeEspAccumulator < (1 / 30) then return end
        safeEspAccumulator = 0

        for obj, data in pairs(safeEspObjects) do
            if obj and obj.Parent then
                local pos3d = getSafePosition(obj)

                if pos3d then
                    local pos, onScreen = cam:WorldToViewportPoint(pos3d)

                    if onScreen then
                        if selectedSafeFilter ~= "All"
                            and data.label ~= selectedSafeFilter then

                            data.name.Visible = false
                            data.dist.Visible = false
                            continue
                        end

                        local dist = getDistance(pos3d)
                        if not dist then
                            data.name.Visible = false
                            data.dist.Visible = false
                            continue
                        end

                        data.name.Color = isSafeBroken(obj)
                            and Color3.fromRGB(255,0,0)
                            or Color3.fromRGB(0,255,0)

                        data.name.Position = Vector2.new(pos.X, pos.Y)
                        data.name.Visible = true

                        data.dist.Position = Vector2.new(pos.X, pos.Y + 14)
                        local label = "[" .. dist .. "m]"
                        if data.dist.Text ~= label then data.dist.Text = label end
                        data.dist.Visible = true
                    else
                        data.name.Visible = false
                        data.dist.Visible = false
                    end
                else
                    data.name.Visible = false
                    data.dist.Visible = false
                end
            else
                data.name.Visible = false
                data.dist.Visible = false
            end
        end
    end)

    WorldESP:AddToggle("SafeESP", {
        Text = "Safe ESP",
        Default = false,
        Disabled = not Drawing,
    })

    Toggles.SafeESP:OnChanged(function(state)
        safeEspEnabled = state
        if not state then
            for _, data in pairs(safeEspObjects) do
                data.name.Visible = false
                data.dist.Visible = false
            end
        end
    end)

    WorldESP:AddDropdown("SafeFilter", {
        Text = "Safe Filter",
        Values = { "All", "MediumSafe", "Register", "SmallSafe" },
        Default = 1,
    })

    Options.SafeFilter:OnChanged(function()
        selectedSafeFilter = Options.SafeFilter.Value
    end)

    Options.SafeFilter:SetValue("All")

     
     
     

    local pileEspEnabled = false
    local pileEspObjects = {}

    local selectedPileFilter = "All"

    local function getPileDistance(pos)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not hrp then
            return nil
        end

        return math.floor((hrp.Position - pos).Magnitude)
    end

    local function getPilePosition(model)
        if not model or not model.Parent then
            return nil
        end

        local primary = model.PrimaryPart

        if primary then
            return primary.Position
        end

        local part = model:FindFirstChildWhichIsA("BasePart")

        if part then
            return part.Position
        end

        return nil
    end

    local function getPileType(name)
        if string.find(name, "S1") then
            return "S1"
        elseif string.find(name, "S2") then
            return "S2"
        end

        return nil
    end

    local function createPileESP(model)
        if not Drawing then return end
        if not model:IsA("Model") then
            return
        end

        if pileEspObjects[model] then
            return
        end

        local pileType = getPileType(model.Name)

        if not pileType then
            return
        end

        local nameText = Drawing.new("Text")
        nameText.Size = 16
        nameText.Center = true
        nameText.Outline = true
        nameText.OutlineColor = Color3.fromRGB(0,0,0)
        nameText.Visible = false
        nameText.Text = pileType .. " Pile"
        nameText.Color = pileType == "S1"
            and Color3.fromRGB(0,255,100)
            or Color3.fromRGB(255,80,80)

        local distText = Drawing.new("Text")
        distText.Size = 14
        distText.Center = true
        distText.Outline = true
        distText.OutlineColor = Color3.fromRGB(0,0,0)
        distText.Color = Color3.fromRGB(255,255,255)
        distText.Visible = false

        pileEspObjects[model] = {
            name = nameText,
            dist = distText,
            pileType = pileType
        }
    end

    local function removePileESP(model)
        local data = pileEspObjects[model]

        if not data then
            return
        end

        if data.name then
            data.name:Remove()
        end

        if data.dist then
            data.dist:Remove()
        end

        pileEspObjects[model] = nil
    end

    Library:OnUnload(function()
        pileEspEnabled = false
        for model in pairs(pileEspObjects) do removePileESP(model) end
    end)
    watchESPContainer(getPileContainer, false, createPileESP, removePileESP)

    local pileEspAccumulator = 0
    Runtime.Connect(RunService.RenderStepped, function(deltaTime)
        if not pileEspEnabled or not cam then return end
        pileEspAccumulator += deltaTime
        if pileEspAccumulator < (1 / 30) then return end
        pileEspAccumulator = 0

        for model, data in pairs(pileEspObjects) do
            if not model or not model.Parent then
                removePileESP(model)
                continue
            end

            if selectedPileFilter ~= "All"
                and data.pileType ~= selectedPileFilter then

                data.name.Visible = false
                data.dist.Visible = false
                continue
            end

            local pos3d = getPilePosition(model)

            if not pos3d then
                data.name.Visible = false
                data.dist.Visible = false
                continue
            end

            local pos, onScreen = cam:WorldToViewportPoint(pos3d)

            if not onScreen then
                data.name.Visible = false
                data.dist.Visible = false
                continue
            end

            local dist = getPileDistance(pos3d)
            if not dist then
                data.name.Visible = false
                data.dist.Visible = false
                continue
            end

            data.name.Position = Vector2.new(pos.X, pos.Y)
            data.name.Visible = true

            data.dist.Position = Vector2.new(pos.X, pos.Y + 14)
            local label = "[" .. dist .. "m]"
            if data.dist.Text ~= label then data.dist.Text = label end
            data.dist.Visible = true
        end
    end)

    WorldESP:AddToggle("PileESP", {
        Text = "Pile ESP",
        Default = false,
        Disabled = not Drawing,
    })

    Toggles.PileESP:OnChanged(function(state)
        pileEspEnabled = state
        if not state then
            for _, data in pairs(pileEspObjects) do
                data.name.Visible = false
                data.dist.Visible = false
            end
        end
    end)

    WorldESP:AddDropdown("PileFilter", {
        Text = "Pile Filter",
        Values = { "All", "S1", "S2" },
        Default = 1,
    })

    Options.PileFilter:OnChanged(function()
        selectedPileFilter = Options.PileFilter.Value
    end)

    Options.PileFilter:SetValue("All")

     
     
     

    local DealerESPFolder

    local DealerESPObjects = {}

    local function removeDealerESP(model)
        local data = DealerESPObjects[model]
        if not data then return end
        data.highlight:Destroy()
        data.billboard:Destroy()
        if data.humanoid then
            data.humanoid.DisplayDistanceType = data.displayDistanceType
        end
        DealerESPObjects[model] = nil
    end

    local function clearDealerESP()
        for model in pairs(DealerESPObjects) do
            removeDealerESP(model)
        end
    end

    local function createDealerESP(model)
        if Library.Unloaded or not DealerESPFolder or not Toggles.DealerESP.Value
            or not model:IsA("Model") or model.Parent ~= DealerESPFolder then
            return
        end

        if DealerESPObjects[model] or model:FindFirstChild("DealerHighlight") then
            return
        end

        local humanoid = model:FindFirstChildWhichIsA("Humanoid")

        local adornee =
            model:FindFirstChild("Head")
            or model:FindFirstChild("HumanoidRootPart")
            or model.PrimaryPart
            or model:FindFirstChildWhichIsA("BasePart")

        if not adornee then
            return
        end

        local displayDistanceType = humanoid and humanoid.DisplayDistanceType
        if humanoid then
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end

        local highlight = Instance.new("Highlight")
        highlight.Name = "DealerHighlight"
        highlight.Adornee = model
        highlight.FillColor = Color3.fromRGB(255,140,0)
        highlight.OutlineColor = Color3.fromRGB(255,200,120)
        highlight.FillTransparency = 0.4
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = model

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "DealerBillboard"
        billboard.Adornee = adornee
        billboard.Size = UDim2.new(0,170,0,20)
        billboard.StudsOffset = Vector3.new(0,3,0)
        billboard.AlwaysOnTop = true
        billboard.MaxDistance = 1000
        billboard.Parent = model

        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1,0,1,0)
        text.BackgroundTransparency = 1
        text.TextColor3 = Color3.fromRGB(255,140,0)
        text.TextStrokeTransparency = 0
        text.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        text.Font = Enum.Font.GothamBold
        text.TextSize = 13
        text.Text = ""
        text.Visible = false
        text.Parent = billboard

        DealerESPObjects[model] = {
            highlight = highlight,
            billboard = billboard,
            text = text,
            adornee = adornee,
            humanoid = humanoid,
            displayDistanceType = displayDistanceType,
        }
    end

    local function enableDealerESP()
        clearDealerESP()
        if not DealerESPFolder then return end

        for _, v in ipairs(DealerESPFolder:GetChildren()) do
            if v:IsA("Model") then
                createDealerESP(v)
            end
        end
    end

    WorldESP:AddToggle("DealerESP", {
        Text = "Dealer ESP",
        Default = false,
    })

    Toggles.DealerESP:OnChanged(function(state)
        if Library.Unloaded then return end
        if state then
            enableDealerESP()
        else
            clearDealerESP()
        end
    end)

    watchESPContainer(function()
        local map = workspace:FindFirstChild("Map")
        DealerESPFolder = map and map:FindFirstChild("Shopz")
        return DealerESPFolder
    end, false, function(v)
        if Toggles.DealerESP.Value and v:IsA("Model") then
            Runtime.Spawn(function()
                task.wait(0.2)
                if Library.Unloaded or not DealerESPFolder or not Toggles.DealerESP.Value
                    or v.Parent ~= DealerESPFolder then return end
                createDealerESP(v)
            end)
        end
    end, removeDealerESP)

    local dealerEspAccumulator = 0
    Runtime.Connect(RunService.RenderStepped, function(deltaTime)
        if not Toggles.DealerESP.Value then return end
        dealerEspAccumulator += deltaTime
        if dealerEspAccumulator < 0.2 then return end
        dealerEspAccumulator = 0

        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        for model, data in pairs(DealerESPObjects) do
            if not DealerESPFolder or model.Parent ~= DealerESPFolder or not data.adornee.Parent then
                removeDealerESP(model)
            elseif root then
                local distance = math.floor((root.Position - data.adornee.Position).Magnitude)
                local label = model.Name .. " [" .. distance .. "m]"
                if data.text.Text ~= label then data.text.Text = label end
                data.text.Visible = true
            else
                data.text.Visible = false
            end
        end
    end)

    Library:OnUnload(function()
        clearDealerESP()
    end)
end

 
 
 
do
local MiscRight = Tabs.Automation:AddLeftGroupbox("Loot & Crates", "package")
local Doors = Tabs.Automation:AddRightGroupbox("Doors", "door-open")
local MiscLeft = Tabs.Automation:AddLeftGroupbox("Interactions", "hand")
local Lockpicking = Tabs.Automation:AddRightGroupbox("Lockpicking", "key-round")

local Distance = 10
local LastCollect = 0
local CollectCooldown = 0.75

MiscRight:AddToggle("AutoCashDrop", {
    Text = "Auto Collect Cash",
    Default = false,
})

Runtime.Spawn(function()
    while not Library.Unloaded do
        task.wait(0.1)
        if Library.Unloaded then break end
        local autoCashToggle = Toggles and Toggles.AutoCashDrop
        if not autoCashToggle or not autoCashToggle.Value then
            continue
        end

        pcall(function()
            local Character = LocalPlayer.Character
            local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")

            if not HumanoidRootPart then
                return
            end

            local SpawnedBread = workspace.Filter:FindFirstChild("SpawnedBread")

            if not SpawnedBread then
                return
            end

            for _, Cash in pairs(SpawnedBread:GetChildren()) do
                if Cash.Name == "CashDrop1" then
                    local Prompt = Cash:FindFirstChildWhichIsA("ProximityPrompt", true)

                    if Prompt then
                        local PromptPart = Prompt.Parent

                        if PromptPart and PromptPart:IsA("BasePart") then
                            local DistanceCheck = (HumanoidRootPart.Position - PromptPart.Position).Magnitude

                            if DistanceCheck <= Distance and tick() - LastCollect >= CollectCooldown then
                                LastCollect = tick()

                                fireproximityprompt(Prompt, 1)
                            end
                        end
                    end
                end
            end
        end)
    end
end)

Toggles.AutoCashDrop:OnChanged(function(state)
end)

local AutoPickup = false
local AutoPickupThread

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getClosestPart(maxDistance)
    local root = getRoot()
    if not root then return nil end

    local filter = workspace:FindFirstChild("Filter")
    local piles = filter and filter:FindFirstChild("SpawnedPiles")
    if not piles then return nil end

    local closestPart = nil
    local closestDistance = maxDistance

    for _, part in pairs(piles:GetChildren()) do
        local basePart = part:FindFirstChildWhichIsA("BasePart")

        if basePart then
            local distance = (basePart.Position - root.Position).Magnitude

            if distance < closestDistance then
                closestDistance = distance
                closestPart = part
            end
        end
    end

    return closestPart
end

 
local MyToggle = MiscRight:AddToggle("AutoPickup", {
    Text = "Auto Open Crates",
    Default = false,
})

 
MyToggle:OnChanged(function(state)
    Runtime.Cancel(AutoPickupThread)
    AutoPickupThread = nil
    AutoPickup = state

    if state and not Library.Unloaded then
        AutoPickupThread = Runtime.Spawn(function()
            while AutoPickup and not Library.Unloaded do
                pcall(function()  
                    local part = getClosestPart(10)

                    if part then
                        local id = part:GetAttribute("Id")

                        if id then
                            local events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
                            local pickup = events and events:FindFirstChild("PIC_PU")
                            if pickup then pickup:FireServer(tostring(id)) end
                        end
                    end
                end)

                task.wait(0.5)
            end
        end)
    end
end)

local AutoOpen = false
local AutoOpenThread

local MAX_DISTANCE = 10

local function getClosestDoor()
    local root = getRoot()
    if not root then return nil end

    local map = workspace:FindFirstChild("Map")
    local doors = map and map:FindFirstChild("Doors")
    if not doors then return nil end
    local closestDoor = nil
    local closestDistance = MAX_DISTANCE

    for _, door in pairs(doors:GetChildren()) do
        local basePart = door:FindFirstChildWhichIsA("BasePart")

        if basePart then
            local distance = (basePart.Position - root.Position).Magnitude

            if distance < closestDistance then
                closestDistance = distance
                closestDoor = door
            end
        end
    end

    return closestDoor
end

 
local OpenToggle = Doors:AddToggle("AutoOpenDoor", {
    Text = "Auto Open Door",
    Default = false,
})

OpenToggle:OnChanged(function(state)
    Runtime.Cancel(AutoOpenThread)
    AutoOpenThread = nil
    AutoOpen = state

    if state and not Library.Unloaded then
        AutoOpenThread = Runtime.Spawn(function()
            while AutoOpen and not Library.Unloaded do
                pcall(function()
                    local door = getClosestDoor()

                    if door then
                        local knob = door:FindFirstChild("Knob1")
                        local event = door:FindFirstChild("Events") and door.Events:FindFirstChild("Toggle")
                        local values = door:FindFirstChild("Values")
                        local open = values and values:FindFirstChild("Open")

                         
                        if knob and event and open and open.Value == false then
                            local args = {
                                [1] = "Open",
                                [2] = knob
                            }

                            event:FireServer(unpack(args))
                            print("Opened:", door.Name)
                        end
                    end
                end)

                task.wait(0.5)
            end
        end)
    end
end)


local AutoDoor = false
local AutoDoorThread

 
local MyToggle = Doors:AddToggle("AutoDoor", {
    Text = "Auto Unlock Door",
    Default = false,
})

MyToggle:OnChanged(function(state)
    Runtime.Cancel(AutoDoorThread)
    AutoDoorThread = nil
    AutoDoor = state

    if state and not Library.Unloaded then
        AutoDoorThread = Runtime.Spawn(function()
            while AutoDoor and not Library.Unloaded do
                pcall(function()
                    local door = getClosestDoor()

                    if door then
                        local lock = door:FindFirstChild("Lock")
                        local event = door:FindFirstChild("Events") and door.Events:FindFirstChild("Toggle")
                        local values = door:FindFirstChild("Values")
                        local locked = values and values:FindFirstChild("Locked")

                         
                        if lock and event and locked and locked.Value == true then
                            local args = {
                                [1] = "Unlock",
                                [2] = lock
                            }

                            event:FireServer(unpack(args))
                            print("Unlocked:", door.Name)
                        end
                    end
                end)

                task.wait(0.5)
            end
        end)
    end
end)

 
local MAX_DISTANCE = 20
local KEY = Enum.KeyCode.E

 
local enabled = false
local promptThread

 
local prompts = {}

local function restorePrompt(prompt, original)
    if original.HoldDuration == nil then return end
    pcall(function()
        prompt.HoldDuration = original.HoldDuration
        prompt.RequiresLineOfSight = original.RequiresLineOfSight
        prompt.MaxActivationDistance = original.MaxActivationDistance
    end)
    table.clear(original)
end

local function applyPrompt(prompt, original)
    if original.HoldDuration == nil then
        original.HoldDuration = prompt.HoldDuration
        original.RequiresLineOfSight = prompt.RequiresLineOfSight
        original.MaxActivationDistance = prompt.MaxActivationDistance
    end
    if prompt.HoldDuration ~= 0 then prompt.HoldDuration = 0 end
    if prompt.RequiresLineOfSight then prompt.RequiresLineOfSight = false end
    if prompt.MaxActivationDistance ~= MAX_DISTANCE then
        prompt.MaxActivationDistance = MAX_DISTANCE
    end
end

local function setupPrompt(prompt)
    if Library.Unloaded or prompts[prompt] then return end
    local original = {}
    prompts[prompt] = original
    if enabled then applyPrompt(prompt, original) end
end

local function removePrompt(prompt)
    local original = prompts[prompt]
    if not original then return end
    restorePrompt(prompt, original)
    prompts[prompt] = nil
end

 
local function isNear(prompt)
    local char = LocalPlayer.Character
    if not char then return false end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local parent = prompt.Parent
    if not parent then return false end
    local part = parent:IsA("BasePart") and parent
        or parent:FindFirstChildWhichIsA("BasePart")

    if not part then return false end

    return (hrp.Position - part.Position).Magnitude <= MAX_DISTANCE
end

 
for _,v in pairs(workspace:GetDescendants()) do
    if v:IsA("ProximityPrompt") then
        setupPrompt(v)
    end
end

 
Runtime.Connect(workspace.DescendantAdded, function(v)
    if v:IsA("ProximityPrompt") then
        setupPrompt(v)
    end
end)
Runtime.Connect(workspace.DescendantRemoving, removePrompt)

 
local MyToggle = MiscLeft:AddToggle("FastInteractToggle", {
    Text = "Instant Interaction",
    Default = false,
})

Toggles.FastInteractToggle:OnChanged(function(state)
    Runtime.Cancel(promptThread)
    promptThread = nil
    enabled = state

    if state and not Library.Unloaded then
        promptThread = Runtime.Spawn(function()
            while enabled and not Library.Unloaded do
                for prompt, original in pairs(prompts) do
                    if prompt.Parent then
                        applyPrompt(prompt, original)
                    else
                        removePrompt(prompt)
                    end
                end
                task.wait(0.2)
            end
        end)
    else
        enabled = false
        for prompt, original in pairs(prompts) do
            restorePrompt(prompt, original)
        end
    end
end)

local AllowanceCooldown = 1
local LastAllowance = 0

local function isAllowancePrompt(prompt)
    local text = (prompt.ActionText .. " " .. prompt.ObjectText):lower()
    if text:find("allowance") or text:find("atm") then
        return true
    end
    local node = prompt.Parent
    for _ = 1, 5 do
        if not node or node == workspace then
            break
        end
        if node.Name:lower():find("atm") then
            return true
        end
        node = node.Parent
    end
    return false
end

MiscLeft:AddToggle("AutoAllowance", {
    Text = "Auto Collect Allowance",
    Default = false,
})

MiscLeft:AddSlider("AllowanceDistance", {
    Text = "Allowance Distance",
    Min = 5,
    Max = 40,
    Default = 15,
    Rounding = 0,
})

Runtime.Spawn(function()
    while not Library.Unloaded do
        task.wait(0.1)
        if Library.Unloaded then
            break
        end
        local toggle = Toggles and Toggles.AutoAllowance
        if toggle and toggle.Value then
            pcall(function()
                if tick() - LastAllowance < AllowanceCooldown then
                    return
                end
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then
                    return
                end
                local distance = Options.AllowanceDistance and Options.AllowanceDistance.Value or 15
                for prompt in pairs(prompts) do
                    if prompt.Parent and prompt.Enabled and isAllowancePrompt(prompt) then
                        local part = prompt.Parent
                        if not part:IsA("BasePart") then
                            part = part:FindFirstChildWhichIsA("BasePart")
                        end
                        if part and (hrp.Position - part.Position).Magnitude <= distance then
                            LastAllowance = tick()
                            fireproximityprompt(prompt, 1)
                            return
                        end
                    end
                end
            end)
        end
    end
end)

 
local function interactAll()
    if not enabled then return end

    for prompt in pairs(prompts) do
        if prompt and prompt.Parent and prompt.Enabled and isNear(prompt) then
            pcall(function()
                fireproximityprompt(prompt, 0)
                fireproximityprompt(prompt, 0)
            end)
        end
    end
end

 
Runtime.Connect(UIS.InputBegan, function(input, gp)
    if gp or not enabled then return end

    if input.KeyCode == KEY then
        interactAll()
    end
end)

 
Runtime.Connect(UIS.TouchStarted, function(_, gp)
    if gp or not enabled then return end
    interactAll()
end)

local AutoLockpick = Lockpicking:AddToggle("AutoLockpick", {
    Text = "Auto Lockpick",
    Default = false,
})

local CurrentBar = 1
local LastY = nil
local StoppedTime = 0
local lockpickMouseDown = false

Runtime.Spawn(function()
    while not Library.Unloaded do
        local autoLockpickToggle = Toggles and Toggles.AutoLockpick
        if not autoLockpickToggle or not autoLockpickToggle.Value then
            task.wait(0.2)
            continue
        end
        task.wait()
        if Library.Unloaded then break end
        if not autoLockpickToggle.Value then continue end

        local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local LockpickGUI = PlayerGui and PlayerGui:FindFirstChild("LockpickGUI")

        if not LockpickGUI then
            CurrentBar = 1
            LastY = nil
            continue
        end

        local MF = LockpickGUI:FindFirstChild("MF")
        local LP_Frame = MF and MF:FindFirstChild("LP_Frame")

        if not LP_Frame then
            continue
        end

        local Frames = LP_Frame:FindFirstChild("Frames")
        local Line = LP_Frame:FindFirstChild("Line")

        if not Frames or not Line then
            continue
        end

        local B = Frames:FindFirstChild("B" .. CurrentBar)

        if not B or not B:FindFirstChild("Bar") then
            continue
        end

        local Selection = B.Bar:FindFirstChild("Selection")

        if not Selection then
            continue
        end

        local SelectionY = math.floor(Selection.AbsolutePosition.Y)
        local LineY = math.floor(Line.AbsolutePosition.Y)

         
        if LastY and LastY == SelectionY then
            if tick() - StoppedTime > 0.15 then
                CurrentBar += 1
                LastY = nil
                continue
            end
        else
            StoppedTime = tick()
        end

        LastY = SelectionY

         
        if math.abs(SelectionY - LineY) <= 3 then
            lockpickMouseDown = true
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.03)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            lockpickMouseDown = false

            print("Clicked B" .. CurrentBar)

            task.wait(0.2)
        end
    end
end)

Toggles.AutoLockpick:OnChanged(function(state)
end)

Library:OnUnload(function()
    enabled = false
    AutoPickup = false
    AutoOpen = false
    AutoDoor = false
    Runtime.Cancel(promptThread)
    Runtime.Cancel(AutoPickupThread)
    Runtime.Cancel(AutoOpenThread)
    Runtime.Cancel(AutoDoorThread)
    promptThread = nil
    AutoPickupThread = nil
    AutoOpenThread = nil
    AutoDoorThread = nil
    for prompt, original in pairs(prompts) do restorePrompt(prompt, original) end
    table.clear(prompts)
    if lockpickMouseDown then
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        lockpickMouseDown = false
    end
end)
end

 
 
 
do
    local PlayerLeft = Tabs.Player:AddLeftGroupbox("Movement & Stamina", "user")
    local PlayerRight = Tabs.Player:AddRightGroupbox("Spectate", "users")

     
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local CoreGui = game:GetService("CoreGui")

    local LocalPlayer = Players.LocalPlayer
    local Camera = workspace.CurrentCamera


     
     
     

    local staminaConnection
    local staminaEnabled = false
    local staminaOriginals = {}

    local function enableStamina()
        if staminaEnabled or Library.Unloaded then
            return
        end

        staminaEnabled = true

        staminaConnection = Runtime.Connect(RunService.RenderStepped, function()
            if not staminaEnabled then
                return
            end

            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildWhichIsA("Humanoid")

            if hum then
                if not staminaOriginals[hum] then
                    staminaOriginals[hum] = { value = hum:GetAttribute("ZSPRN_M") }
                end
                if hum:GetAttribute("ZSPRN_M") ~= true then
                    hum:SetAttribute("ZSPRN_M", true)
                end
            end
        end)
    end

    local function disableStamina()
        staminaEnabled = false

        if staminaConnection then
            staminaConnection:Disconnect()
            staminaConnection = nil
        end

        for hum, original in pairs(staminaOriginals) do
            hum:SetAttribute("ZSPRN_M", original.value)
        end
        table.clear(staminaOriginals)
    end

    Runtime.Connect(LocalPlayer.CharacterRemoving, function(character)
        for hum, original in pairs(staminaOriginals) do
            if hum:IsDescendantOf(character) then
                hum:SetAttribute("ZSPRN_M", original.value)
                staminaOriginals[hum] = nil
            end
        end
    end)

    PlayerLeft:AddToggle("InfStaminaToggle", {
        Text = "Infinite Stamina",
        Default = false,
    })

    Toggles.InfStaminaToggle:OnChanged(function(state)
        if state then
            enableStamina()
        else
            disableStamina()
        end
    end)

    local movement = EndHubMovement({ Library = Library, Runtime = Runtime, LocalPlayer = LocalPlayer, PlayerGroup = PlayerLeft })

    local SelectedPlayer = nil
    local Spectating = false
    local SpectateSubjects = {}

    local function SetSpectateSubject(humanoid)
        if Toggles.FreeCamToggle and Toggles.FreeCamToggle.Value then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        if not SpectateSubjects[camera] then
            SpectateSubjects[camera] = { subject = camera.CameraSubject }
        end
        if camera.CameraSubject ~= humanoid then camera.CameraSubject = humanoid end
    end

    PlayerRight:AddDropdown("PlayerSelect", {
        Text = "Select Player",
        Values = {},
        Multi = false,
        Default = nil,
    })

    local function RefreshPlayers()
        local PlayerTable = {}

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                table.insert(PlayerTable, plr.Name)
            end
        end

        local playerSelect = Options and Options.PlayerSelect

        if playerSelect and type(playerSelect.SetValues) == "function" then
            playerSelect:SetValues(PlayerTable)
        end
    end

    RefreshPlayers()

    Runtime.Connect(Players.PlayerAdded, RefreshPlayers)
    Runtime.Connect(Players.PlayerRemoving, RefreshPlayers)

    Options.PlayerSelect:OnChanged(function()
        local name = Options.PlayerSelect.Value
        SelectedPlayer = name and Players:FindFirstChild(name) or nil

        if Spectating and SelectedPlayer and SelectedPlayer.Character then
            local hum = SelectedPlayer.Character:FindFirstChildOfClass("Humanoid")

            if hum then
                SetSpectateSubject(hum)
            end
        end
    end)

    local function StopSpectate()
        Spectating = false

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        for camera, original in pairs(SpectateSubjects) do
            if camera.Parent then
                local subject = original.subject
                if subject and not subject.Parent then subject = hum end
                camera.CameraSubject = subject
            end
        end
        table.clear(SpectateSubjects)
    end

    local function StartSpectate()
        if not SelectedPlayer or Library.Unloaded then
            return
        end

        local char = SelectedPlayer.Character

        if not char then
            return
        end

        local hum = char:FindFirstChildOfClass("Humanoid")

        if not hum then
            return
        end

        Spectating = true
        SetSpectateSubject(hum)
    end

    PlayerRight:AddToggle("SpectateToggle", {
        Text = "Spectate",
        Default = false
    })

    Toggles.SpectateToggle:OnChanged(function(v)
        if v then
            StartSpectate()
        else
            StopSpectate()
        end
    end)

    Runtime.Connect(RunService.RenderStepped, function()
        if not Spectating then
            return
        end

        if not SelectedPlayer or not SelectedPlayer.Parent then
            StopSpectate()
            return
        end

        local char = SelectedPlayer.Character

        if not char then
            return
        end

        local hum = char:FindFirstChildOfClass("Humanoid")

        if hum then SetSpectateSubject(hum) end
    end)

local NoclipToggle = PlayerLeft:AddToggle("NoclipToggle", {
    Text = "Noclip",
    Default = false,
})

local Keybind = NoclipToggle:AddKeyPicker("NoclipKey", {
    Default = "None",
    Text = "NoClip",
    Mode = "Toggle",
    SyncToggleState = true,
})

local noclipEnabled = false
local noclipParts = {}
local noclipCharacter
local noclipAddedConnection
local noclipRemovingConnection

local function restoreNoclipPart(part, original)
    if original.CanCollide ~= nil then
        part.CanCollide = original.CanCollide
        original.CanCollide = nil
    end
end

local function cacheNoclipPart(part)
    if not part:IsA("BasePart") or noclipParts[part] then return end
    local original = {}
    noclipParts[part] = original
    if noclipEnabled then
        original.CanCollide = part.CanCollide
        part.CanCollide = false
    end
end

local function clearNoclipCharacter()
    if noclipAddedConnection then noclipAddedConnection:Disconnect() end
    if noclipRemovingConnection then noclipRemovingConnection:Disconnect() end
    noclipAddedConnection = nil
    noclipRemovingConnection = nil
    noclipCharacter = nil
    for part, original in pairs(noclipParts) do restoreNoclipPart(part, original) end
    table.clear(noclipParts)
end

local function cacheNoclipCharacter(character)
    clearNoclipCharacter()
    if Library.Unloaded then return end
    noclipCharacter = character
    noclipAddedConnection = Runtime.Connect(character.DescendantAdded, cacheNoclipPart)
    noclipRemovingConnection = Runtime.Connect(character.DescendantRemoving, function(part)
        local original = noclipParts[part]
        if original then
            restoreNoclipPart(part, original)
            noclipParts[part] = nil
        end
    end)
    for _, part in ipairs(character:GetDescendants()) do cacheNoclipPart(part) end
end

Runtime.Connect(LocalPlayer.CharacterAdded, cacheNoclipCharacter)
Runtime.Connect(LocalPlayer.CharacterRemoving, function(character)
    if character == noclipCharacter then clearNoclipCharacter() end
end)
if LocalPlayer.Character then cacheNoclipCharacter(LocalPlayer.Character) end

Runtime.Connect(RunService.Stepped, function()
    if not noclipEnabled then return end
    for part in pairs(noclipParts) do
        if part.CanCollide then part.CanCollide = false end
    end
end)

Toggles.NoclipToggle:OnChanged(function(state)
    noclipEnabled = state and not Library.Unloaded
    for part, original in pairs(noclipParts) do
        if noclipEnabled then
            if original.CanCollide == nil then original.CanCollide = part.CanCollide end
            if part.CanCollide then part.CanCollide = false end
        else
            restoreNoclipPart(part, original)
        end
    end
end)

Library:OnUnload(function()
    pcall(disableStamina)
    movement.Stop()
    pcall(StopSpectate)
    SelectedPlayer = nil
    noclipEnabled = false
    pcall(clearNoclipCharacter)
end)
end

 
SettingsGroupLeft:AddButton("Load Saved Autoload (Explicit)", function()
    Runtime.Spawn(function() SaveManager:LoadAutoloadConfig() end)
end)
Runtime.Spawn(function()
    while not Library.Unloaded do
        task.wait(300)
        if Library.Unloaded then return end
        if not EndHubKeyGate.Validate() then
            Library:Unload()
            warn("[EndHub] Key validation failed; script unloaded.")
            return
        end
    end
end)
