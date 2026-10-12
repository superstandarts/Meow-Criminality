return function(ctx)
    local Library = ctx.Library
    local Runtime = ctx.Runtime
    local group = ctx.Group
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local serviceOK, ContextActionService = pcall(function()
        return game:GetService("ContextActionService")
    end)
    if not serviceOK then ContextActionService = nil end
    local controls = {}
    local connections = {}
    local pressed = {}
    local active = false
    local stopped = false
    local renderBound = false
    local actionBound = false
    local camera
    local record
    local position
    local pitch = 0
    local yaw = 0
    local mouseRecord
    local looking = false
    local key = Enum.KeyCode
    local limit = math.rad(89)
    local disable

    local function releaseMouse()
        looking = false
        local entry = mouseRecord
        mouseRecord = nil
        if entry then
            pcall(function()
                if entry.LastApplied ~= nil and UserInputService.MouseBehavior == entry.LastApplied then
                    UserInputService.MouseBehavior = entry.Original
                end
            end)
        end
    end

    local function clearInput()
        table.clear(pressed)
        releaseMouse()
    end

    local function restoreCamera()
        local oldCamera, oldRecord = camera, record
        camera, record = nil, nil
        if not oldCamera or not oldRecord then return end
        for _, property in ipairs({ "CFrame", "Focus", "CameraType" }) do
            local entry = oldRecord[property]
            pcall(function()
                if entry.LastApplied ~= nil and oldCamera[property] == entry.LastApplied then
                    oldCamera[property] = entry.Original
                end
            end)
        end
    end

    local function writeCamera(property, value)
        if camera[property] == value then return end
        camera[property] = value
        record[property].LastApplied = value
    end

    local function applyCamera()
        local frame = CFrame.new(position) * CFrame.fromOrientation(pitch, yaw, 0)
        writeCamera("CFrame", frame)
        writeCamera("Focus", CFrame.new(position + frame.LookVector * 10))
    end

    local function acquireCamera()
        local nextCamera = workspace.CurrentCamera
        if nextCamera == camera then return end
        restoreCamera()
        assert(nextCamera, "No current camera")
        local snapshot = {}
        for _, property in ipairs({ "CFrame", "Focus", "CameraType" }) do
            snapshot[property] = { Original = nextCamera[property] }
        end
        camera, record = nextCamera, snapshot
        position = snapshot.CFrame.Original.Position
        pitch, yaw = snapshot.CFrame.Original:ToOrientation()
        pitch = math.clamp(pitch, -limit, limit)
        writeCamera("CameraType", Enum.CameraType.Scriptable)
        applyCamera()
    end

    local function textFocused()
        if UserInputService:GetFocusedTextBox() then
            clearInput()
            return true
        end
        return false
    end

    local function numberValue(control, default, minimum, maximum)
        local value = control.Value
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
            return default
        end
        return math.clamp(value, minimum, maximum)
    end

    disable = function()
        active = false
        clearInput()
        if renderBound then
            renderBound = false
            pcall(function() RunService:UnbindFromRenderStep("EndHubFreeCam") end)
        end
        if actionBound then
            actionBound = false
            pcall(function() ContextActionService:UnbindAction("EndHubFreeCamInput") end)
        end
        for _, connection in ipairs(connections) do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(connections)
        restoreCamera()
        if controls.FreeCamToggle.Value ~= false then
            pcall(function() controls.FreeCamToggle:SetValue(false) end)
        end
    end

    local function guarded(callback)
        return function(...)
            if not active then return end
            if stopped or Library.Unloaded then disable() return end
            if not pcall(callback, ...) then disable() end
        end
    end

    local function connect(signal, callback)
        local connection = Runtime.Connect(signal, guarded(callback))
        assert(connection, "Input connection unavailable")
        table.insert(connections, connection)
    end

    local function inputAction(_, state, input)
        if not active or stopped or Library.Unloaded then
            if active then disable() end
            return Enum.ContextActionResult.Pass
        end
        local ok, result = pcall(function()
            if textFocused() then return Enum.ContextActionResult.Pass end
            if state == Enum.UserInputState.Begin then
                pressed[input.KeyCode] = true
            elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
                pressed[input.KeyCode] = nil
            end
            return Enum.ContextActionResult.Sink
        end)
        if not ok then disable() return Enum.ContextActionResult.Pass end
        return result
    end

    local function render(delta)
        if camera and camera.CameraType ~= Enum.CameraType.Scriptable then disable() return end
        acquireCamera()
        if not textFocused() and type(delta) == "number" and delta == delta
            and delta > 0 and delta < math.huge then
            local x = (pressed[key.D] and 1 or 0) - (pressed[key.A] and 1 or 0)
            local y = (pressed[key.E] and 1 or 0) - (pressed[key.Q] and 1 or 0)
            local z = (pressed[key.W] and 1 or 0) - (pressed[key.S] and 1 or 0)
            local horizontal = CFrame.fromOrientation(0, yaw, 0)
            local direction = horizontal.RightVector * x + Vector3.new(0, y, 0) + horizontal.LookVector * z
            if direction.Magnitude > 0 then
                local speed = numberValue(controls.FreeCamSpeed, 32, 1, 200)
                position += direction.Unit * speed * (pressed[key.LeftShift] and 3 or 1) * delta
            end
        end
        applyCamera()
    end

    local function enable()
        if active or stopped or Library.Unloaded then return end
        local ok = pcall(function()
            assert(ContextActionService and type(ContextActionService.BindActionAtPriority) == "function"
                and type(ContextActionService.UnbindAction) == "function", "Input suppression unavailable")
            active = true
            actionBound = true
            ContextActionService:BindActionAtPriority("EndHubFreeCamInput", inputAction, false, 3000,
                key.W, key.A, key.S, key.D, key.Q, key.E, key.Space, key.LeftControl, key.LeftShift)
            connect(UserInputService.InputBegan, function(input, processed)
                if processed or textFocused() or input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
                if looking then return end
                mouseRecord = { Original = UserInputService.MouseBehavior }
                looking = true
                if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCurrentPosition then
                    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
                    mouseRecord.LastApplied = Enum.MouseBehavior.LockCurrentPosition
                end
            end)
            connect(UserInputService.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton2 then releaseMouse() end
            end)
            connect(UserInputService.InputChanged, function(input)
                if textFocused() or not looking or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCurrentPosition then releaseMouse() return end
                local sensitivity = math.rad(numberValue(controls.FreeCamSensitivity, 0.2, 0.05, 1))
                pitch = math.clamp(pitch - input.Delta.Y * sensitivity, -limit, limit)
                yaw -= input.Delta.X * sensitivity
            end)
            connect(UserInputService.WindowFocusReleased, clearInput)
            connect(workspace:GetPropertyChangedSignal("CurrentCamera"), acquireCamera)
            acquireCamera()
            renderBound = true
            RunService:BindToRenderStep("EndHubFreeCam", Enum.RenderPriority.Camera.Value + 2, guarded(render))
        end)
        if not ok then disable() end
    end

    controls.FreeCamToggle = group:AddToggle("FreeCamToggle", {
        Text = "Free Cam", Default = false,
        Tooltip = "WASD move, Q/E down/up, right mouse look, Shift boost.",
    })
    controls.FreeCamKey = controls.FreeCamToggle:AddKeyPicker("FreeCamKey", {
        Text = "Free Cam", Default = "None", Mode = "Toggle", SyncToggleState = true,
    })
    controls.FreeCamSpeed = group:AddSlider("FreeCamSpeed", {
        Text = "Free Cam Speed", Default = 32, Min = 1, Max = 200, Rounding = 0,
    })
    controls.FreeCamSensitivity = group:AddSlider("FreeCamSensitivity", {
        Text = "Mouse Sensitivity", Default = 0.2, Min = 0.05, Max = 1, Rounding = 2,
    })
    controls.FreeCamToggle:OnChanged(function()
        if stopped or Library.Unloaded then
            disable()
        elseif controls.FreeCamToggle.Value == true then
            enable()
        else
            disable()
        end
    end)

    local function stop()
        if stopped then return end
        stopped = true
        disable()
    end

    Library:OnUnload(stop)
    if controls.FreeCamToggle.Value == true then enable() end
    return {
        Stop = stop,
        IsActive = function() return active and not stopped and not Library.Unloaded end,
        Controls = controls,
    }
end
