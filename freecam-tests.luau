return function(moduleSource)
    local passed, failed = 0, 0
    local fixtures = {}
    local function equal(actual, expected, message)
        assert(actual == expected, (message or "Unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
    local function near(actual, expected, message)
        assert(math.abs(actual - expected) < 0.000001, (message or "Unexpected number") .. ": expected " .. expected .. ", got " .. actual)
    end
    local function count(entries)
        local total = 0
        for _ in pairs(entries) do total += 1 end
        return total
    end

    local Vector3 = {}
    local vectorMeta = {}
    function Vector3.new(x, y, z)
        return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vectorMeta)
    end
    vectorMeta.__index = function(v, property)
        if property == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
        if property == "Unit" then return v / v.Magnitude end
    end
    vectorMeta.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
    vectorMeta.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
    vectorMeta.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
    vectorMeta.__mul = function(a, b)
        if type(a) == "number" then a, b = b, a end
        return Vector3.new(a.X * b, a.Y * b, a.Z * b)
    end
    vectorMeta.__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
    vectorMeta.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
    local function vectorNear(actual, expected)
        near(actual.X, expected.X, "Vector X")
        near(actual.Y, expected.Y, "Vector Y")
        near(actual.Z, expected.Z, "Vector Z")
    end

    local CFrame = {}
    local frameMeta = {}
    local function frame(position, rotation)
        return setmetatable({ Position = position, Rotation = rotation }, frameMeta)
    end
    function CFrame.new(x, y, z)
        return frame(type(x) == "table" and x or Vector3.new(x, y, z), { 1, 0, 0, 0, 1, 0, 0, 0, 1 })
    end
    function CFrame.fromOrientation(x, y, z)
        local sx, cx, sy, cy, sz, cz = math.sin(x), math.cos(x), math.sin(y), math.cos(y), math.sin(z), math.cos(z)
        return frame(Vector3.new(), {
            cy * cz + sy * sx * sz, -cy * sz + sy * sx * cz, sy * cx,
            cx * sz, cx * cz, -sx,
            -sy * cz + cy * sx * sz, sy * sz + cy * sx * cz, cy * cx,
        })
    end
    local function rotate(r, v)
        return Vector3.new(r[1] * v.X + r[2] * v.Y + r[3] * v.Z,
            r[4] * v.X + r[5] * v.Y + r[6] * v.Z,
            r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
    end
    frameMeta.__index = function(cf, property)
        local r = cf.Rotation
        if property == "LookVector" then return Vector3.new(-r[3], -r[6], -r[9]) end
        if property == "RightVector" then return Vector3.new(r[1], r[4], r[7]) end
        if property == "ToOrientation" then
            return function() return math.asin(math.clamp(-r[6], -1, 1)), math.atan2(r[3], r[9]), math.atan2(r[4], r[5]) end
        end
    end
    frameMeta.__mul = function(a, b)
        if getmetatable(b) == vectorMeta then return a.Position + rotate(a.Rotation, b) end
        local r, s, result = a.Rotation, b.Rotation, {}
        for row = 0, 2 do
            for col = 1, 3 do
                result[row * 3 + col] = r[row * 3 + 1] * s[col] + r[row * 3 + 2] * s[col + 3] + r[row * 3 + 3] * s[col + 6]
            end
        end
        return frame(a.Position + rotate(r, b.Position), result)
    end
    frameMeta.__eq = function(a, b)
        if a.Position ~= b.Position then return false end
        for i = 1, 9 do if a.Rotation[i] ~= b.Rotation[i] then return false end end
        return true
    end

    local Enum = {
        KeyCode = {}, CameraType = { Custom = "Custom", Scriptable = "Scriptable", Attach = "Attach" },
        MouseBehavior = { Default = "Default", LockCurrentPosition = "LockCurrentPosition", LockCenter = "LockCenter" },
        UserInputType = { MouseButton2 = "MouseButton2", MouseMovement = "MouseMovement", Keyboard = "Keyboard" },
        UserInputState = { Begin = "Begin", End = "End", Cancel = "Cancel", Change = "Change" },
        ContextActionResult = { Pass = "Pass", Sink = "Sink" }, RenderPriority = { Camera = { Value = 200 } },
    }
    for _, name in ipairs({ "W", "A", "S", "D", "Q", "E", "Space", "LeftControl", "LeftShift" }) do
        Enum.KeyCode[name] = name
    end
    local function signal()
        local event = { Connections = {} }
        function event:Connect(callback)
            local connection = { Connected = true, Callback = callback }
            function connection:Disconnect()
                self.Connected = false
                if self.FailDisconnect then error("Disconnect failed") end
            end
            table.insert(self.Connections, connection)
            return connection
        end
        function event:Fire(...)
            for _, connection in ipairs(table.clone(self.Connections)) do
                if connection.Connected then connection.Callback(...) end
            end
        end
        return event
    end

    local function fixture(options)
        options = options or {}
        local h = { Writes = {}, Backing = {}, Frames = {}, Actions = {}, Signals = {}, RenderBinds = 0, RenderUnbinds = 0, ActionBinds = 0, ActionUnbinds = 0 }
        table.insert(fixtures, h)
        function h:Object(properties, methods)
            local object = newproxy(true)
            local data = { Properties = properties, ReadErrors = {}, WriteErrors = {} }
            self.Backing[object] = data
            getmetatable(object).__index = function(_, property)
                if data.ReadErrors[property] then error("Read failed: " .. property) end
                return (methods or {})[property] or data.Properties[property]
            end
            getmetatable(object).__newindex = function(_, property, value)
                if data.WriteErrors[property] then error("Write failed: " .. property) end
                table.insert(h.Writes, { Object = object, Property = property, Value = value })
                data.Properties[property] = value
            end
            return object
        end
        function h:NewCamera(initial)
            return self:Object({
                CFrame = initial or CFrame.new(10, 20, 30) * CFrame.fromOrientation(0.3, 0.7, 0.2),
                Focus = CFrame.new(1, 2, 3), CameraType = Enum.CameraType.Custom,
                CameraSubject = newproxy(), FieldOfView = 83,
            })
        end
        h.Camera = h:NewCamera(options.Initial)
        h.Original = table.clone(h.Backing[h.Camera].Properties)
        h.CameraChanged = signal()
        h.World = { CurrentCamera = h.Camera }
        function h.World:GetPropertyChangedSignal(property)
            equal(property, "CurrentCamera")
            return h.CameraChanged
        end
        function h:Replace(camera)
            self.World.CurrentCamera = camera
            self.CameraChanged:Fire()
        end
        h.Library = { Unloaded = false, Options = {}, Toggles = {}, UnloadCallbacks = {} }
        function h.Library:OnUnload(callback) table.insert(self.UnloadCallbacks, callback) end
        function h.Library:Unload()
            self.Unloaded = true
            for _, callback in ipairs(self.UnloadCallbacks) do callback() end
        end
        h.Runtime = {}
        function h.Runtime.Connect(event, callback)
            if options.FailConnect == #h.Signals + 1 then error("Connection failed") end
            if options.NilConnect == #h.Signals + 1 then return nil end
            table.insert(h.Signals, event)
            return event:Connect(function(...)
                if not h.Library.Unloaded then callback(...) end
            end)
        end
        function h.Runtime.Spawn() error("FreeCam must not spawn workers") end
        h.Input = h:Object({
            InputBegan = signal(), InputEnded = signal(), InputChanged = signal(), WindowFocusReleased = signal(),
            MouseBehavior = Enum.MouseBehavior.Default,
        }, { GetFocusedTextBox = function()
            if h.FailFocus then error("Focus unavailable") end
            return h.TextBox
        end })
        h.RunService = {}
        function h.RunService:BindToRenderStep(name, priority, callback)
            h.RenderBinds += 1
            equal(name, "EndHubFreeCam")
            equal(priority, 202)
            assert(not h.Frames[name], "Duplicate render binding")
            h.Frames[name] = callback
            if options.FailRender then error("Render bind failed") end
        end
        function h.RunService:UnbindFromRenderStep(name)
            h.RenderUnbinds += 1
            h.Frames[name] = nil
            if h.FailRenderUnbind then error("Render unbind failed") end
        end
        h.CAS = {}
        function h.CAS:BindActionAtPriority(name, callback, touch, priority, ...)
            h.ActionBinds += 1
            equal(name, "EndHubFreeCamInput")
            equal(touch, false)
            equal(priority, 3000)
            assert(not h.Actions[name], "Duplicate action binding")
            h.Actions[name] = { Callback = callback, Keys = { ... } }
            if options.FailAction then error("Action bind failed") end
        end
        function h.CAS:UnbindAction(name)
            h.ActionUnbinds += 1
            h.Actions[name] = nil
            if h.FailActionUnbind then error("Action unbind failed") end
        end
        if options.MissingBind then h.CAS.BindActionAtPriority = nil end
        h.Group = { Definitions = {} }
        local function addControl(id, definition, target)
            assert(not h.Group.Definitions[id], "Duplicate control")
            h.Group.Definitions[id] = definition
            local control = { Value = definition.Default }
            if options.Saved and options.Saved[id] ~= nil then control.Value = options.Saved[id] end
            function control:OnChanged(callback) self.Changed = callback end
            function control:SetValue(value)
                self.Value = value
                if self.Changed then self.Changed(value) end
            end
            function control:AddKeyPicker(pickerID, pickerDefinition)
                local picker = addControl(pickerID, pickerDefinition, h.Library.Options)
                function picker:Press()
                    if pickerDefinition.SyncToggleState then control:SetValue(not control.Value) end
                end
                return picker
            end
            target[id] = control
            return control
        end
        function h.Group:AddToggle(id, definition) return addControl(id, definition, h.Library.Toggles) end
        function h.Group:AddSlider(id, definition) return addControl(id, definition, h.Library.Options) end
        local player = newproxy(true)
        getmetatable(player).__index = function() error("FreeCam must not read character data") end
        getmetatable(player).__newindex = function() error("FreeCam must not write character data") end
        local gameMock = {}
        function gameMock:GetService(name)
            if name == "RunService" then return h.RunService end
            if name == "UserInputService" then return h.Input end
            if name == "ContextActionService" then
                if options.NoCAS then error("CAS unavailable") end
                return h.CAS
            end
            error("Unexpected service: " .. name)
        end
        local chunk = assert(loadstring(moduleSource, "FreeCam.luau"))
        setfenv(chunk, setmetatable({
            game = gameMock, workspace = h.World, Enum = Enum, CFrame = CFrame, Vector3 = Vector3,
            task = setmetatable({}, { __index = function() error("No tasks allowed") end }),
        }, { __index = getfenv() }))
        h.Api = chunk()({ Library = h.Library, Runtime = h.Runtime, LocalPlayer = player, Group = h.Group })
        h.Controls = h.Api.Controls
        function h:Set(id, value) self.Controls[id]:SetValue(value) end
        function h:Enable() self:Set("FreeCamToggle", true) end
        function h:Step(delta)
            for _, callback in pairs(table.clone(self.Frames)) do callback(delta) end
        end
        function h:Key(name, state)
            local action = self.Actions.EndHubFreeCamInput
            assert(action, "Action not bound")
            return action.Callback("EndHubFreeCamInput", state or Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode[name] })
        end
        function h:Mouse(event, kind, x, y, processed)
            self.Input[event]:Fire({ UserInputType = Enum.UserInputType[kind], Delta = Vector3.new(x, y, 0) }, processed)
        end
        function h:WriteCount(property, object)
            local total = 0
            for _, write in ipairs(self.Writes) do
                if write.Property == property and (not object or write.Object == object) then total += 1 end
            end
            return total
        end
        function h:AssertOff()
            equal(self.Api.IsActive(), false)
            equal(self.Controls.FreeCamToggle.Value, false)
            equal(count(self.Frames), 0)
            equal(count(self.Actions), 0)
            for _, event in ipairs(self.Signals) do
                for _, connection in ipairs(event.Connections) do equal(connection.Connected, false) end
            end
        end
        return h
    end

    local function test(name, callback)
        fixtures = {}
        local ok, err = pcall(function()
            callback()
            for _, h in ipairs(fixtures) do
                h.Api.Stop()
                h:AssertOff()
                equal(h:WriteCount("FieldOfView"), 0)
                equal(h:WriteCount("CameraSubject"), 0)
                for _, write in ipairs(h.Writes) do
                    assert(write.Object == h.Input or h.Backing[write.Object].Properties.CameraType, "Non-camera write")
                end
            end
        end)
        if ok then
            passed += 1
            print("PASS " .. name)
        else
            failed += 1
            print("FAIL " .. name .. ": " .. tostring(err))
        end
    end

    test("GUI IDs, keypicker sync, English labels and limits", function()
        local h = fixture()
        local d = h.Group.Definitions
        equal(count(d), 4)
        equal(d.FreeCamToggle.Text, "Free Cam")
        equal(d.FreeCamToggle.Default, false)
        equal(d.FreeCamToggle.Tooltip, "WASD move, Q/E down/up, right mouse look, Shift boost.")
        equal(d.FreeCamKey.Default, "None")
        equal(d.FreeCamKey.Mode, "Toggle")
        equal(d.FreeCamKey.SyncToggleState, true)
        equal(d.FreeCamSpeed.Default, 32)
        equal(d.FreeCamSpeed.Min, 1)
        equal(d.FreeCamSpeed.Max, 200)
        equal(d.FreeCamSensitivity.Text, "Mouse Sensitivity")
        equal(d.FreeCamSensitivity.Default, 0.2)
        equal(d.FreeCamSensitivity.Min, 0.05)
        equal(d.FreeCamSensitivity.Max, 1)
        equal(d.FreeCamSensitivity.Rounding, 2)
        h.Controls.FreeCamKey:Press()
        equal(h.Api.IsActive(), true)
        h.Controls.FreeCamKey:Press()
        h:AssertOff()
    end)

    test("disabled feature has no input hooks, workers or camera effects", function()
        local h = fixture()
        h:Mouse("InputBegan", "MouseButton2")
        h:Mouse("InputChanged", "MouseMovement", 500, 500)
        h.Input.WindowFocusReleased:Fire()
        h:Set("FreeCamSpeed", 200)
        h:Set("FreeCamSensitivity", 1)
        h:Step(1)
        h:Set("FreeCamToggle", false)
        equal(#h.Writes, 0)
        equal(#h.Signals, 0)
        equal(h.RenderBinds + h.RenderUnbinds + h.ActionBinds + h.ActionUnbinds, 0)
        h:AssertOff()
    end)

    test("matrix mocks and initial camera Euler position are correct", function()
        local rotated = CFrame.new(1, 2, 3) * CFrame.fromOrientation(0, math.pi / 2, 0)
        vectorNear(rotated * Vector3.new(0, 0, -2), Vector3.new(-1, 2, 3))
        vectorNear(2 * Vector3.new(1, 2, 3), Vector3.new(2, 4, 6))
        equal(CFrame.new(1, 2, 3), CFrame.new(1, 2, 3))
        local h = fixture()
        h:Enable()
        equal(#h.Signals, 5)
        equal(h.Signals[1], h.Input.InputBegan)
        equal(h.Signals[2], h.Input.InputEnded)
        equal(h.Signals[3], h.Input.InputChanged)
        equal(h.Signals[4], h.Input.WindowFocusReleased)
        equal(h.Signals[5], h.CameraChanged)
        equal(h.Camera.CameraType, Enum.CameraType.Scriptable)
        vectorNear(h.Camera.CFrame.Position, h.Original.CFrame.Position)
        local pitch, yaw, roll = h.Camera.CFrame:ToOrientation()
        near(pitch, 0.3)
        near(yaw, 0.7)
        near(roll, 0)
        vectorNear(h.Camera.Focus.Position, h.Camera.CFrame.Position + h.Camera.CFrame.LookVector * 10)
    end)

    test("WASD follows horizontal yaw and Q E use world Y", function()
        local h = fixture({ Initial = CFrame.new(10, 20, 30) * CFrame.fromOrientation(1, math.pi / 2, 0) })
        h:Enable()
        h:Key("W")
        h:Step(1)
        vectorNear(h.Camera.CFrame.Position, Vector3.new(-22, 20, 30))
        h:Key("W", Enum.UserInputState.End)
        h:Key("D")
        h:Step(1)
        vectorNear(h.Camera.CFrame.Position, Vector3.new(-22, 20, -2))
        h:Key("D", Enum.UserInputState.End)
        h:Key("E")
        h:Step(0.5)
        vectorNear(h.Camera.CFrame.Position, Vector3.new(-22, 36, -2))
        h:Key("E", Enum.UserInputState.End)
        h:Key("Q")
        h:Step(0.5)
        vectorNear(h.Camera.CFrame.Position, Vector3.new(-22, 20, -2))
        h:Key("Q", Enum.UserInputState.End)
        h:Key("S")
        h:Key("A")
        h:Step(1)
        vectorNear(h.Camera.CFrame.Position, Vector3.new(-22 + 32 / math.sqrt(2), 20, -2 + 32 / math.sqrt(2)))
    end)

    test("normalized diagonals, Shift x3 and frame-rate independent speed", function()
        local a, b = fixture({ Initial = CFrame.new() }), fixture({ Initial = CFrame.new() })
        for _, h in ipairs({ a, b }) do
            h:Enable()
            h:Key("W")
            h:Key("D")
            h:Key("E")
            h:Key("LeftShift")
        end
        a:Step(1)
        for _ = 1, 120 do b:Step(1 / 120) end
        vectorNear(a.Camera.CFrame.Position, b.Camera.CFrame.Position)
        near(a.Camera.CFrame.Position.Magnitude, 96)
        a:Key("LeftShift", Enum.UserInputState.Cancel)
        local start = a.Camera.CFrame.Position
        a:Step(1)
        near((a.Camera.CFrame.Position - start).Magnitude, 32)
        a:Key("A")
        a:Key("S")
        a:Key("Q")
        start = a.Camera.CFrame.Position
        a:Step(1)
        vectorNear(a.Camera.CFrame.Position, start)
    end)

    test("live speed slider bounds, invalid numbers and delta validation", function()
        local h = fixture({ Initial = CFrame.new() })
        h:Enable()
        h:Key("W")
        for _, entry in ipairs({ { 100, 100 }, { 1000, 200 }, { -5, 1 }, { math.huge, 32 }, { 0 / 0, 32 }, { "50", 32 } }) do
            h:Set("FreeCamSpeed", entry[1])
            local start = h.Camera.CFrame.Position
            h:Step(1)
            near((h.Camera.CFrame.Position - start).Magnitude, entry[2])
        end
        local start = h.Camera.CFrame.Position
        for _, delta in ipairs({ -1, 0, math.huge, 0 / 0, "1" }) do h:Step(delta) end
        h:Step(nil)
        vectorNear(h.Camera.CFrame.Position, start)
    end)

    test("held right mouse uses native delta sensitivity and pitch clamp", function()
        local h = fixture({ Initial = CFrame.new() })
        h:Enable()
        h:Mouse("InputChanged", "MouseMovement", 20, 20)
        h:Step(0)
        near(select(1, h.Camera.CFrame:ToOrientation()), 0)
        h:Mouse("InputBegan", "MouseButton2")
        equal(h.Input.MouseBehavior, Enum.MouseBehavior.LockCurrentPosition)
        h:Mouse("InputChanged", "Keyboard", 90, 90)
        h:Mouse("InputChanged", "MouseMovement", 30, 40)
        h:Step(0)
        local pitch, yaw = h.Camera.CFrame:ToOrientation()
        near(pitch, math.rad(-8))
        near(yaw, math.rad(-6))
        h:Set("FreeCamSensitivity", 0.5)
        h:Mouse("InputChanged", "MouseMovement", 10, -10000)
        h:Step(0)
        pitch, yaw = h.Camera.CFrame:ToOrientation()
        near(pitch, math.rad(89))
        near(yaw, math.rad(-11))
        h:Mouse("InputChanged", "MouseMovement", 0, 10000)
        h:Step(0)
        near(select(1, h.Camera.CFrame:ToOrientation()), math.rad(-89))
        h:Mouse("InputEnded", "MouseButton2")
        equal(h.Input.MouseBehavior, Enum.MouseBehavior.Default)
        h:Mouse("InputChanged", "MouseMovement", 40, 50)
        h:Step(0)
        near(select(1, h.Camera.CFrame:ToOrientation()), math.rad(-89))
        local bounded = fixture({ Initial = CFrame.new() })
        bounded:Enable()
        bounded:Mouse("InputBegan", "MouseButton2")
        local expectedYaw = 0
        for _, entry in ipairs({ { 10, 1 }, { -1, 0.05 }, { math.huge, 0.2 }, { 0 / 0, 0.2 }, { "1", 0.2 } }) do
            bounded:Set("FreeCamSensitivity", entry[1])
            bounded:Mouse("InputChanged", "MouseMovement", 10, 0)
            bounded:Step(0)
            expectedYaw -= math.rad(10 * entry[2])
            local _, actualYaw = bounded.Camera.CFrame:ToOrientation()
            near(actualYaw, expectedYaw)
        end
    end)

    test("mouse ignores processed input and restores only owned capture", function()
        local h = fixture()
        h:Enable()
        h:Mouse("InputBegan", "MouseButton2", 0, 0, true)
        equal(h.Input.MouseBehavior, Enum.MouseBehavior.Default)
        h:Mouse("InputBegan", "MouseButton2")
        h:Mouse("InputBegan", "MouseButton2")
        equal(h:WriteCount("MouseBehavior"), 1)
        h.Backing[h.Input].Properties.MouseBehavior = Enum.MouseBehavior.LockCenter
        local original = h.Camera.CFrame
        h:Mouse("InputChanged", "MouseMovement", 50, 50)
        h:Step(0)
        equal(h.Camera.CFrame, original)
        h:Mouse("InputEnded", "MouseButton2")
        equal(h.Input.MouseBehavior, Enum.MouseBehavior.LockCenter)
        h:Mouse("InputBegan", "MouseButton2")
        h:Mouse("InputEnded", "MouseButton2")
        equal(h.Input.MouseBehavior, Enum.MouseBehavior.LockCenter)
        h.Backing[h.Input].Properties.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        local writes = h:WriteCount("MouseBehavior")
        h:Mouse("InputBegan", "MouseButton2")
        h:Mouse("InputEnded", "MouseButton2")
        equal(h:WriteCount("MouseBehavior"), writes)
    end)

    test("CAS sinks all avatar keys but passes typing and clears motion", function()
        local h = fixture({ Initial = CFrame.new() })
        h:Enable()
        local keys = h.Actions.EndHubFreeCamInput.Keys
        equal(#keys, 9)
        local seen = {}
        for _, name in ipairs(keys) do seen[name] = true end
        for name in pairs(Enum.KeyCode) do equal(seen[name], true, name) end
        equal(h:Key("Space"), Enum.ContextActionResult.Sink)
        equal(h:Key("LeftControl"), Enum.ContextActionResult.Sink)
        h:Step(1)
        vectorNear(h.Camera.CFrame.Position, Vector3.new())
        equal(h:Key("W"), Enum.ContextActionResult.Sink)
        h.TextBox = {}
        equal(h:Key("W", Enum.UserInputState.End), Enum.ContextActionResult.Pass)
        equal(h:Key("D"), Enum.ContextActionResult.Pass)
        h:Step(1)
        h.TextBox = nil
        h:Step(1)
        vectorNear(h.Camera.CFrame.Position, Vector3.new())
        h:Key("W")
        h:Key("W", Enum.UserInputState.End)
        h:Key("D")
        h:Key("D", Enum.UserInputState.Cancel)
        h:Step(1)
        vectorNear(h.Camera.CFrame.Position, Vector3.new())
    end)

    test("textbox acquired without input stops movement and releases mouse", function()
        local h = fixture()
        h:Enable()
        h:Key("W")
        h:Mouse("InputBegan", "MouseButton2")
        h.TextBox = {}
        h:Step(1)
        vectorNear(h.Camera.CFrame.Position, h.Original.CFrame.Position)
        equal(h.Input.MouseBehavior, Enum.MouseBehavior.Default)
        h:Mouse("InputBegan", "MouseButton2")
        equal(h.Input.MouseBehavior, Enum.MouseBehavior.Default)
        h.TextBox = nil
        h:Step(1)
        vectorNear(h.Camera.CFrame.Position, h.Original.CFrame.Position)
    end)

    test("window focus release clears held keys and mouse lock", function()
        local h = fixture()
        h:Enable()
        h:Key("W")
        h:Key("LeftShift")
        h:Mouse("InputBegan", "MouseButton2")
        h.Input.WindowFocusReleased:Fire()
        equal(h.Input.MouseBehavior, Enum.MouseBehavior.Default)
        h:Mouse("InputChanged", "MouseMovement", 100, 100)
        h:Step(1)
        vectorNear(h.Camera.CFrame.Position, h.Original.CFrame.Position)
        h:Key("W")
        h:Step(1)
        near((h.Camera.CFrame.Position - h.Original.CFrame.Position).Magnitude, 32)
    end)

    test("disable restores originals and preserves external property overrides", function()
        local h = fixture()
        h:Enable()
        h:Key("W")
        h:Step(1)
        h:Mouse("InputBegan", "MouseButton2")
        h:Set("FreeCamToggle", false)
        h:AssertOff()
        for property, original in pairs(h.Original) do equal(h.Camera[property], original, property) end
        equal(h.Input.MouseBehavior, Enum.MouseBehavior.Default)
        h:Enable()
        local externalFrame, externalFocus = CFrame.new(100, 200, 300), CFrame.new(4, 5, 6)
        local data = h.Backing[h.Camera].Properties
        data.CFrame, data.Focus, data.FieldOfView, data.CameraSubject = externalFrame, externalFocus, 99, newproxy()
        local subject = data.CameraSubject
        h:Set("FreeCamToggle", false)
        equal(h.Camera.CFrame, externalFrame)
        equal(h.Camera.Focus, externalFocus)
        equal(h.Camera.CameraType, h.Original.CameraType)
        equal(h.Camera.FieldOfView, 99)
        equal(h.Camera.CameraSubject, subject)
    end)

    test("camera replacement restores old owned values and captures new camera", function()
        local h = fixture()
        h:Enable()
        h:Key("W")
        h:Step(1)
        local externalFocus = CFrame.new(6, 7, 8)
        h.Backing[h.Camera].Properties.Focus = externalFocus
        local nextCamera = h:NewCamera(CFrame.new(100, 200, 300) * CFrame.fromOrientation(-0.5, -0.8, 0.1))
        local original = table.clone(h.Backing[nextCamera].Properties)
        h:Replace(nextCamera)
        equal(h.Camera.CFrame, h.Original.CFrame)
        equal(h.Camera.Focus, externalFocus)
        equal(h.Camera.CameraType, h.Original.CameraType)
        equal(nextCamera.CameraType, Enum.CameraType.Scriptable)
        vectorNear(nextCamera.CFrame.Position, original.CFrame.Position)
        local pitch, yaw = nextCamera.CFrame:ToOrientation()
        near(pitch, -0.5)
        near(yaw, -0.8)
        h:Step(1)
        near((nextCamera.CFrame.Position - original.CFrame.Position).Magnitude, 32)
        h:Set("FreeCamToggle", false)
        for property, value in pairs(original) do equal(nextCamera[property], value, property) end
        h:Enable()
        h:Replace(nil)
        h:AssertOff()
        equal(nextCamera.CameraType, original.CameraType)
    end)

    test("external CameraType takeover stops instead of forcing Scriptable", function()
        local h = fixture()
        h:Enable()
        h:Key("W")
        h:Step(1)
        local externalFrame = CFrame.new(90, 80, 70)
        local props = h.Backing[h.Camera].Properties
        props.CameraType, props.CFrame = Enum.CameraType.Attach, externalFrame
        local writes = h:WriteCount("CameraType")
        h:Step(1)
        h:AssertOff()
        equal(h.Camera.CameraType, Enum.CameraType.Attach)
        equal(h.Camera.CFrame, externalFrame)
        equal(h:WriteCount("CameraType"), writes)
        equal(h.Camera.Focus, h.Original.Focus)
    end)

    test("unload and Stop are terminal, idempotent and disconnect everything", function()
        local h = fixture()
        h:Enable()
        h:Mouse("InputBegan", "MouseButton2")
        local staleRender = h.Frames.EndHubFreeCam
        local staleAction = h.Actions.EndHubFreeCamInput.Callback
        h.Library:Unload()
        h:AssertOff()
        equal(h.Camera.CFrame, h.Original.CFrame)
        equal(h.Input.MouseBehavior, Enum.MouseBehavior.Default)
        local writes = #h.Writes
        staleRender(1)
        equal(staleAction("EndHubFreeCamInput", Enum.UserInputState.Begin, { KeyCode = "W" }), Enum.ContextActionResult.Pass)
        h:Enable()
        h:Mouse("InputBegan", "MouseButton2")
        h.Api.Stop()
        h.Api.Stop()
        equal(#h.Writes, writes)
        h:AssertOff()
        local other = fixture()
        other:Enable()
        other.Api.Stop()
        other:Enable()
        other:AssertOff()
        local flagged = fixture()
        flagged:Enable()
        flagged.Library.Unloaded = true
        flagged:Step(1)
        flagged:AssertOff()
    end)

    test("missing CAS API and partially failed action binding roll back", function()
        for _, options in ipairs({ { NoCAS = true }, { MissingBind = true }, { FailAction = true } }) do
            local h = fixture(options)
            h:Enable()
            h:AssertOff()
            equal(#h.Writes, 0)
            equal(#h.Signals, 0)
            equal(h.RenderBinds, 0)
            if options.FailAction then equal(h.ActionUnbinds, 1) else equal(h.ActionBinds, 0) end
        end
    end)

    test("input hookup errors and absent connections roll back independently", function()
        for _, options in ipairs({ { FailConnect = 3 }, { NilConnect = 4 } }) do
            local h = fixture(options)
            h:Enable()
            h:AssertOff()
            equal(#h.Writes, 0)
            equal(h.ActionUnbinds, 1)
        end
        local h = fixture()
        h:Enable()
        h.FailFocus = true
        equal(h:Key("W"), Enum.ContextActionResult.Pass)
        h:AssertOff()
        equal(h.Camera.CFrame, h.Original.CFrame)
        local mouse = fixture()
        mouse:Enable()
        mouse.Backing[mouse.Input].WriteErrors.MouseBehavior = true
        mouse:Mouse("InputBegan", "MouseButton2")
        mouse:AssertOff()
        equal(mouse.Camera.CameraType, mouse.Original.CameraType)
    end)

    test("partial render bind and camera write errors restore acquired state", function()
        local h = fixture({ FailRender = true })
        h:Enable()
        h:AssertOff()
        equal(h.RenderUnbinds, 1)
        equal(h.Camera.CFrame, h.Original.CFrame)
        equal(h.Camera.Focus, h.Original.Focus)
        equal(h.Camera.CameraType, h.Original.CameraType)
        local snapshotFailure = fixture()
        snapshotFailure.Backing[snapshotFailure.Camera].ReadErrors.Focus = true
        snapshotFailure:Enable()
        snapshotFailure:AssertOff()
        equal(#snapshotFailure.Writes, 0)
        for _, property in ipairs({ "CFrame", "Focus", "CameraType" }) do
            local other = fixture()
            other.Backing[other.Camera].WriteErrors[property] = true
            other:Enable()
            other:AssertOff()
            equal(other.Camera.CameraType, other.Original.CameraType)
        end
        local live = fixture()
        live:Enable()
        live.Backing[live.Camera].WriteErrors.CFrame = true
        live:Key("W")
        live:Step(1)
        live:AssertOff()
        equal(live.Camera.Focus, live.Original.Focus)
        equal(live.Camera.CameraType, live.Original.CameraType)
    end)

    test("cleanup failures do not couple camera, mouse, hooks or stale callbacks", function()
        local h = fixture()
        h:Enable()
        h:Mouse("InputBegan", "MouseButton2")
        local staleRender = h.Frames.EndHubFreeCam
        local staleInput = h.Input.InputChanged.Connections[1].Callback
        h.FailRenderUnbind, h.FailActionUnbind = true, true
        h.Input.InputBegan.Connections[1].FailDisconnect = true
        h.Backing[h.Camera].WriteErrors.CFrame = true
        h.Backing[h.Input].WriteErrors.MouseBehavior = true
        h.Api.Stop()
        h:AssertOff()
        equal(h.Camera.Focus, h.Original.Focus)
        equal(h.Camera.CameraType, h.Original.CameraType)
        local writes = #h.Writes
        staleRender(1)
        staleInput({ UserInputType = Enum.UserInputType.MouseMovement, Delta = Vector3.new(30, 40, 0) })
        equal(#h.Writes, writes)
        local other = fixture()
        other:Enable()
        other.Backing[other.Camera].ReadErrors.Focus = true
        other.Api.Stop()
        equal(other.Camera.CFrame, other.Original.CFrame)
        equal(other.Camera.CameraType, other.Original.CameraType)
    end)

    test("saved enabled state, repeated cycles and fresh ownership snapshots", function()
        local h = fixture({ Saved = { FreeCamToggle = true, FreeCamSpeed = 50 } })
        equal(h.Api.IsActive(), true)
        h:Key("W")
        h:Step(1)
        near((h.Camera.CFrame.Position - h.Original.CFrame.Position).Magnitude, 50)
        h:Set("FreeCamToggle", false)
        local nextFrame = CFrame.new(-10, -20, -30)
        h.Backing[h.Camera].Properties.CFrame = nextFrame
        h.Backing[h.Camera].Properties.CameraType = Enum.CameraType.Scriptable
        local typeWrites = h:WriteCount("CameraType")
        for _ = 1, 5 do
            h:Enable()
            h:Enable()
            h:Step(1)
            vectorNear(h.Camera.CFrame.Position, nextFrame.Position)
            h:Key("E")
            h:Step(1)
            h:Set("FreeCamToggle", false)
            equal(h.Camera.CFrame, nextFrame)
            equal(h.Camera.CameraType, Enum.CameraType.Scriptable)
            h:AssertOff()
        end
        equal(h:WriteCount("CameraType"), typeWrites)
        equal(h.RenderBinds, h.RenderUnbinds)
        equal(h.ActionBinds, h.ActionUnbinds)
    end)

    print("FreeCam tests: " .. passed .. " passed, " .. failed .. " failed")
    assert(failed == 0, "FreeCam regression tests failed")
end
