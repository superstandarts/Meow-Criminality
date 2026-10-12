return function(moduleSource)
    local passed = 0
    local failed = 0
    local fixtures = {}
    local stateEnum = { Ragdoll = "Ragdoll", FallingDown = "FallingDown" }

    local function equal(actual, expected, message)
        assert(actual == expected, (message or "Unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end

    local function count(entries)
        local total = 0
        for _ in pairs(entries) do total += 1 end
        return total
    end

    local function signal()
        local self = { Connections = {} }
        function self:Connect(callback)
            local connection = { Connected = true, Callback = callback }
            function connection:Disconnect() self.Connected = false end
            table.insert(self.Connections, connection)
            return connection
        end
        function self:Fire(...)
            for _, connection in ipairs(table.clone(self.Connections)) do
                if connection.Connected then connection.Callback(...) end
            end
        end
        return self
    end

    local function fixture(options)
        options = options or {}
        local h = {
            Time = 0, Tasks = {}, Errors = {}, Writes = {}, StateWrites = {},
            SpawnCount = 0, CancelCount = 0, Signals = {}, Backing = {},
        }
        table.insert(fixtures, h)
        h.World = { Name = "Workspace" }
        h.Library = { Options = {}, Toggles = {}, Unloaded = false, UnloadCallbacks = {} }
        function h.Library:OnUnload(callback) table.insert(self.UnloadCallbacks, callback) end
        function h.Library:Unload()
            self.Unloaded = true
            for _, callback in ipairs(self.UnloadCallbacks) do callback() end
        end
        h.Runtime = { Threads = {} }
        function h.Runtime.Connect(event, callback)
            assert(not h.Library.Unloaded, "Connecting after unload")
            table.insert(h.Signals, event)
            return event:Connect(function(...)
                if not h.Library.Unloaded then callback(...) end
            end)
        end
        function h.Runtime.Spawn(callback)
            if h.Library.Unloaded then return nil end
            h.SpawnCount += 1
            local thread = coroutine.create(function()
                local ok, err = pcall(callback)
                h.Runtime.Threads[coroutine.running()] = nil
                if not ok then table.insert(h.Errors, tostring(err)) end
            end)
            h.Runtime.Threads[thread] = true
            h.Tasks[thread] = { Due = h.Time }
            return thread
        end
        function h.Runtime.Cancel(thread)
            assert(thread ~= coroutine.running(), "Attempted to cancel running coroutine")
            assert(h.Runtime.Threads[thread], "Canceled unowned thread")
            h.CancelCount += 1
            h.Runtime.Threads[thread] = nil
            if not h.IgnoreCancel then
                h.Tasks[thread] = nil
                coroutine.close(thread)
            end
        end
        function h:Step(delta)
            self.Time += delta
            local due = {}
            for thread, entry in pairs(self.Tasks) do
                if entry.Due <= self.Time then table.insert(due, thread) end
            end
            for _, thread in ipairs(due) do
                if self.Tasks[thread] then
                    local ok, delay = coroutine.resume(thread)
                    if not ok then table.insert(self.Errors, tostring(delay)) end
                    if coroutine.status(thread) == "dead" then
                        self.Tasks[thread] = nil
                    else
                        self.Tasks[thread].Due = self.Time + delay
                    end
                end
            end
        end
        function h:Flush()
            self:Step(0)
            self:Step(0.15)
        end
        function h:NewCharacter(parent)
            local char = { Parent = parent or self.World, Children = {}, ChildAdded = signal(), ChildRemoved = signal() }
            function char:IsDescendantOf(root)
                local node = self.Parent
                while node do
                    if node == root then return true end
                    node = node.Parent
                end
                return false
            end
            function char:FindFirstChildWhichIsA(class)
                equal(class, "Humanoid")
                for _, child in ipairs(self.Children) do
                    if child:IsA(class) then return child end
                end
            end
            return char
        end
        function h:NewHumanoid(char, props)
            local hum = newproxy(true)
            local data = {
                Properties = { Parent = char, Health = 100, WalkSpeed = 21, JumpPower = 61, UseJumpPower = false },
                States = { Ragdoll = true, FallingDown = true }, ReadErrors = {}, WriteErrors = {},
                StateReadErrors = {}, StateWriteErrors = {}, Died = signal(),
            }
            for key, value in pairs(props or {}) do data.Properties[key] = value end
            local methods = {}
            function methods:IsA(class) return class == "Humanoid" end
            function methods:GetStateEnabled(state)
                if data.StateReadErrors[state] then error("LuaError: state read " .. state) end
                return data.States[state]
            end
            function methods:SetStateEnabled(state, value)
                if data.StateWriteErrors[state] then error("LuaError: state write " .. state) end
                table.insert(h.StateWrites, { Humanoid = hum, State = state, Value = value })
                data.States[state] = value
            end
            getmetatable(hum).__index = function(_, key)
                if data.ReadErrors[key] then error("LuaError: read " .. key) end
                if key == "Died" then return data.Died end
                return methods[key] or data.Properties[key]
            end
            getmetatable(hum).__newindex = function(_, key, value)
                if data.WriteErrors[key] then error("LuaError: write " .. key) end
                if data.BeforeWrite then data.BeforeWrite(hum, key, value) end
                table.insert(h.Writes, { Humanoid = hum, Property = key, Value = value })
                data.Properties[key] = value
            end
            self.Backing[hum] = data
            table.insert(char.Children, hum)
            return hum
        end
        function h:RemoveHumanoid(char, hum)
            for index, child in ipairs(char.Children) do
                if child == hum then table.remove(char.Children, index) break end
            end
            self.Backing[hum].Properties.Parent = nil
            char.ChildRemoved:Fire(hum)
        end
        h.Character = h:NewCharacter()
        h.Humanoid = h:NewHumanoid(h.Character, options.Properties)
        if options.Dead then h.Backing[h.Humanoid].Properties.Health = 0 end
        if options.Detached then h.Character.Parent = nil end
        if options.OutsideWorld then h.Character.Parent = { Name = "OtherRoot" } end
        h.Player = { Character = h.Character, CharacterAdded = signal(), CharacterRemoving = signal() }
        if options.NoCharacter then h.Player.Character = nil end
        h.Group = { Definitions = {} }
        local function addControl(id, definition, target)
            assert(not h.Group.Definitions[id], "Duplicate control ID")
            h.Group.Definitions[id] = definition
            local control = { Value = definition.Default, Disabled = definition.Disabled == true }
            if options.Saved and options.Saved[id] ~= nil then control.Value = options.Saved[id] end
            function control:OnChanged(callback) self.Changed = callback end
            function control:SetValue(value)
                self.Value = value
                if self.Changed and not self.Disabled then self.Changed(value) end
            end
            target[id] = control
            return control
        end
        function h.Group:AddSlider(id, definition) return addControl(id, definition, h.Library.Options) end
        function h.Group:AddToggle(id, definition) return addControl(id, definition, h.Library.Toggles) end
        local chunk = assert(loadstring(moduleSource, "Movement.luau"))
        setfenv(chunk, setmetatable({
            workspace = h.World,
            Enum = { HumanoidStateType = stateEnum },
            task = { wait = function(seconds)
                equal(seconds, 0.15, "Debounce delay")
                return coroutine.yield(seconds)
            end },
        }, { __index = getfenv() }))
        local ctx = { Library = h.Library, Runtime = h.Runtime, LocalPlayer = h.Player }
        if options.PlayerLeft then ctx.PlayerLeft = h.Group else ctx.PlayerGroup = h.Group end
        h.Api = chunk()(ctx)
        h.Controls = h.Api.Controls
        function h:Set(id, value) self.Controls[id]:SetValue(value) end
        function h:EnableBoth()
            self:Set("WalkSpeedSlider", 32)
            self:Set("JumpPowerSlider", 100)
            self:Set("WalkSpeedToggle", true)
            self:Set("JumpPowerToggle", true)
        end
        function h:Respawn()
            local old = self.Player.Character
            self.Player.CharacterRemoving:Fire(old)
            local char = self:NewCharacter()
            local hum = self:NewHumanoid(char)
            self.Player.Character = char
            self.Player.CharacterAdded:Fire(char)
            return char, hum
        end
        function h:WriteCount(property, hum)
            local total = 0
            for _, write in ipairs(self.Writes) do
                if write.Property == property and (not hum or write.Humanoid == hum) then total += 1 end
            end
            return total
        end
        return h
    end

    local function test(name, callback)
        fixtures = {}
        local ok, err = pcall(function()
            callback()
            for _, h in ipairs(fixtures) do
                h.Api.Stop()
                equal(count(h.Api.PendingTasks), 0, "Pending tasks after stop")
                equal(count(h.Runtime.Threads), 0, "Runtime threads after stop")
                equal(count(h.Api.Records), 0, "Records after stop")
                equal(#h.Errors, 0, table.concat(h.Errors, "; "))
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

    test("control IDs, defaults, limits and English labels", function()
        local h = fixture()
        equal(count(h.Group.Definitions), 6)
        equal(h.Controls.WalkSpeedSlider.Value, 16)
        equal(h.Controls.JumpPowerSlider.Value, 50)
        equal(h.Group.Definitions.WalkSpeedSlider.Max, 80)
        equal(h.Group.Definitions.JumpPowerSlider.Max, 120)
        equal(h.Group.Definitions.NoRagdoll.Text, "No Ragdoll (Humanoid)")
        equal(h.Controls.WalkSpeedToggle.Value, false)
        equal(h.Controls.JumpPowerToggle.Value, false)
        equal(h.Controls.NoRagdoll.Value, false)
        equal(#h.Writes, 0)
        equal(h.SpawnCount, 0)
    end)

    test("PlayerLeft context alias", function()
        local h = fixture({ PlayerLeft = true })
        h:Set("WalkSpeedToggle", true)
        equal(h.Humanoid.WalkSpeed, 16)
    end)

    test("shipped saved presets loaded after registration", function()
        local h = fixture()
        h:EnableBoth()
        equal(h.Humanoid.WalkSpeed, 32)
        equal(h.Humanoid.JumpPower, 100)
        equal(h.Humanoid.UseJumpPower, true)
    end)

    test("preloaded saved values and enabled toggles", function()
        local h = fixture({ Saved = {
            WalkSpeedSlider = 32, JumpPowerSlider = 100, WalkSpeedToggle = true, JumpPowerToggle = true,
        } })
        equal(h.Humanoid.WalkSpeed, 32)
        equal(h.Humanoid.JumpPower, 100)
    end)

    test("weak userdata records captured before property writes", function()
        local h = fixture()
        equal(type(h.Humanoid), "userdata")
        equal(getmetatable(h.Api.Records).__mode, "k")
        h.Backing[h.Humanoid].BeforeWrite = function(hum, property)
            local entry = h.Api.Records[hum].Properties[property]
            equal(entry.Original, h.Backing[hum].Properties[property])
        end
        h:EnableBoth()
        h.Backing[h.Humanoid].BeforeWrite = nil
    end)

    test("speed handlers never write jump properties", function()
        local h = fixture()
        h:Set("WalkSpeedToggle", true)
        h:Set("WalkSpeedSlider", 40)
        h:Flush()
        h:Set("WalkSpeedToggle", false)
        equal(h:WriteCount("JumpPower"), 0)
        equal(h:WriteCount("UseJumpPower"), 0)
    end)

    test("jump handlers never write speed", function()
        local h = fixture()
        h:Set("JumpPowerToggle", true)
        h:Set("JumpPowerSlider", 90)
        h:Flush()
        h:Set("JumpPowerToggle", false)
        equal(h:WriteCount("WalkSpeed"), 0)
    end)

    test("100 drag callbacks coalesce independently to latest", function()
        local h = fixture()
        h:EnableBoth()
        table.clear(h.Writes)
        for index = 1, 100 do
            h:Set("WalkSpeedSlider", 16 + index * 0.6)
            h:Set("JumpPowerSlider", 50 + index * 0.6)
        end
        equal(h.SpawnCount, 2)
        equal(count(h.Api.PendingTasks), 2)
        equal(#h.Writes, 0)
        h:Step(0)
        h:Step(0.149)
        equal(#h.Writes, 0)
        h:Step(0.0011)
        equal(h:WriteCount("WalkSpeed"), 1)
        equal(h:WriteCount("JumpPower"), 1)
        equal(h.Humanoid.WalkSpeed, 76)
        equal(h.Humanoid.JumpPower, 110)
        equal(count(h.Api.PendingTasks), 0)
        equal(count(h.Runtime.Threads), 0)
    end)

    test("slider updates during wait use latest value", function()
        local h = fixture()
        h:Set("WalkSpeedToggle", true)
        h:Set("WalkSpeedSlider", 32)
        h:Step(0)
        h:Set("WalkSpeedSlider", 55)
        h:Step(0.15)
        equal(h.Humanoid.WalkSpeed, 55)
        equal(h.SpawnCount, 1)
    end)

    test("disabled sliders never spawn or write", function()
        local h = fixture()
        for _ = 1, 100 do h:Set("WalkSpeedSlider", 60) h:Set("JumpPowerSlider", 110) end
        equal(h.SpawnCount, 0)
        equal(#h.Writes, 0)
    end)

    test("toggle off cancels its pending ticket only", function()
        local h = fixture()
        h:EnableBoth()
        h:Set("WalkSpeedSlider", 60)
        h:Set("JumpPowerSlider", 110)
        h:Step(0)
        h:Set("WalkSpeedToggle", false)
        equal(h.CancelCount, 1)
        equal(h.Api.PendingTasks.WalkSpeed, nil)
        assert(h.Api.PendingTasks.JumpPower)
        h:Step(0.15)
        equal(h.Humanoid.WalkSpeed, 21)
        equal(h.Humanoid.JumpPower, 110)
    end)

    test("off then on invalidates stale work", function()
        local h = fixture()
        h.IgnoreCancel = true
        h:Set("WalkSpeedToggle", true)
        h:Set("WalkSpeedSlider", 60)
        h:Step(0)
        h:Set("WalkSpeedToggle", false)
        h:Set("WalkSpeedSlider", 30)
        h:Set("WalkSpeedToggle", true)
        local writes = #h.Writes
        h:Step(0.15)
        equal(#h.Writes, writes)
        equal(h.Humanoid.WalkSpeed, 30)
    end)

    test("owned values restore original, not GUI defaults", function()
        local h = fixture()
        h:EnableBoth()
        h:Set("WalkSpeedToggle", false)
        h:Set("JumpPowerToggle", false)
        equal(h.Humanoid.WalkSpeed, 21)
        equal(h.Humanoid.JumpPower, 61)
        equal(h.Humanoid.UseJumpPower, false)
    end)

    test("original remains first value across slider updates", function()
        local h = fixture()
        h:Set("WalkSpeedToggle", true)
        h:Set("WalkSpeedSlider", 60)
        h:Flush()
        h:Set("WalkSpeedSlider", 70)
        h:Flush()
        h:Set("WalkSpeedToggle", false)
        equal(h.Humanoid.WalkSpeed, 21)
    end)

    test("external overrides preserved on disable", function()
        local h = fixture()
        h:EnableBoth()
        h.Backing[h.Humanoid].Properties.WalkSpeed = 45
        h.Backing[h.Humanoid].Properties.JumpPower = 85
        h:Set("WalkSpeedToggle", false)
        h:Set("JumpPowerToggle", false)
        equal(h.Humanoid.WalkSpeed, 45)
        equal(h.Humanoid.JumpPower, 85)
        equal(h.Humanoid.UseJumpPower, false)
    end)

    test("external UseJumpPower override preserved independently", function()
        local h = fixture()
        h:EnableBoth()
        h.Backing[h.Humanoid].Properties.UseJumpPower = false
        table.clear(h.Writes)
        h:Set("JumpPowerToggle", false)
        equal(h.Humanoid.JumpPower, 61)
        equal(h:WriteCount("UseJumpPower"), 0)
    end)

    test("already matching property is never owned", function()
        local h = fixture({ Properties = { WalkSpeed = 16, UseJumpPower = true } })
        h:Set("WalkSpeedToggle", true)
        h:Set("JumpPowerToggle", true)
        equal(h.Api.Records[h.Humanoid].Properties.WalkSpeed, nil)
        equal(h.Api.Records[h.Humanoid].Properties.UseJumpPower, nil)
        h:Set("JumpPowerToggle", false)
        equal(h.Humanoid.UseJumpPower, true)
    end)

    test("reenabling recaptures a fresh original", function()
        local h = fixture()
        h:Set("WalkSpeedToggle", true)
        h:Set("WalkSpeedToggle", false)
        h.Backing[h.Humanoid].Properties.WalkSpeed = 24
        h:Set("WalkSpeedToggle", true)
        h:Set("WalkSpeedToggle", false)
        equal(h.Humanoid.WalkSpeed, 24)
    end)

    test("restoration errors do not couple jump and UseJumpPower", function()
        local h = fixture()
        h:EnableBoth()
        h.Backing[h.Humanoid].WriteErrors.JumpPower = true
        h:Set("JumpPowerToggle", false)
        equal(h.Humanoid.UseJumpPower, false)
        equal(h.Humanoid.JumpPower, 100)
    end)

    test("UseJumpPower restore error does not stop JumpPower restore", function()
        local h = fixture()
        h:EnableBoth()
        h.Backing[h.Humanoid].ReadErrors.UseJumpPower = true
        h:Set("JumpPowerToggle", false)
        equal(h.Humanoid.JumpPower, 61)
    end)

    test("write errors do not mark property as applied", function()
        local h = fixture()
        h.Backing[h.Humanoid].WriteErrors.WalkSpeed = true
        h:Set("WalkSpeedToggle", true)
        equal(h.Api.Records[h.Humanoid].Properties.WalkSpeed.LastApplied, nil)
        h.Backing[h.Humanoid].WriteErrors.WalkSpeed = nil
        h.Backing[h.Humanoid].Properties.WalkSpeed = 16
        h:Set("WalkSpeedToggle", false)
        equal(h.Humanoid.WalkSpeed, 16)
    end)

    test("read errors skip only affected property", function()
        local h = fixture()
        h.Backing[h.Humanoid].ReadErrors.UseJumpPower = true
        h:Set("JumpPowerToggle", true)
        equal(h.Humanoid.JumpPower, 50)
    end)

    test("positive finite values bounded by specified ranges", function()
        local h = fixture()
        h:Set("WalkSpeedSlider", 250)
        h:Set("JumpPowerSlider", 300)
        h:Set("WalkSpeedToggle", true)
        h:Set("JumpPowerToggle", true)
        equal(h.Humanoid.WalkSpeed, 80)
        equal(h.Humanoid.JumpPower, 120)
        h:Set("WalkSpeedSlider", 1)
        h:Set("JumpPowerSlider", 1)
        h:Flush()
        equal(h.Humanoid.WalkSpeed, 16)
        equal(h.Humanoid.JumpPower, 50)
    end)

    test("invalid numeric and nonnumeric slider values use safe defaults", function()
        local h = fixture()
        h:EnableBoth()
        local invalid = { 0, -1, math.huge, -math.huge, 0 / 0, "60", false, {} }
        for _, value in ipairs(invalid) do
            h:Set("WalkSpeedSlider", value)
            h:Set("JumpPowerSlider", value)
            h:Flush()
            equal(h.Humanoid.WalkSpeed, 16)
            equal(h.Humanoid.JumpPower, 50)
        end
        h:Set("WalkSpeedSlider", nil)
        h:Set("JumpPowerSlider", nil)
        h:Flush()
        equal(h.Humanoid.WalkSpeed, 16)
        equal(h.Humanoid.JumpPower, 50)
    end)

    test("dead model never receives feature writes", function()
        local h = fixture({ Dead = true })
        h:EnableBoth()
        h:Set("NoRagdoll", true)
        h:Set("WalkSpeedSlider", 60)
        h:Flush()
        equal(#h.Writes, 0)
        equal(#h.StateWrites, 0)
        equal(h.SpawnCount, 0)
    end)

    test("unparented character never receives writes", function()
        local h = fixture({ Detached = true })
        h:EnableBoth()
        equal(#h.Writes, 0)
    end)

    test("character outside workspace never receives writes", function()
        local h = fixture({ OutsideWorld = true })
        h:EnableBoth()
        h:Set("NoRagdoll", true)
        equal(#h.Writes, 0)
        equal(#h.StateWrites, 0)
    end)

    test("humanoid must belong directly to current character", function()
        local h = fixture()
        h.Backing[h.Humanoid].Properties.Parent = h.World
        h:EnableBoth()
        equal(#h.Writes, 0)
    end)

    test("stale character rejected at callback execution", function()
        local h = fixture()
        h:EnableBoth()
        h:Set("WalkSpeedSlider", 65)
        h:Step(0)
        h.Player.Character = h:NewCharacter()
        local writes = #h.Writes
        h:Step(0.15)
        equal(#h.Writes, writes)
    end)

    test("Health guard rechecked after debounce", function()
        local h = fixture()
        h:EnableBoth()
        h:Set("WalkSpeedSlider", 65)
        h:Step(0)
        h.Backing[h.Humanoid].Properties.Health = 0
        local writes = #h.Writes
        h:Step(0.15)
        equal(#h.Writes, writes)
    end)

    test("Died event cancels both pending tasks without writes", function()
        local h = fixture()
        h:EnableBoth()
        h:Set("WalkSpeedSlider", 65)
        h:Set("JumpPowerSlider", 110)
        h:Step(0)
        h.Backing[h.Humanoid].Properties.Health = 0
        local writes = #h.Writes
        h.Backing[h.Humanoid].Died:Fire()
        equal(h.CancelCount, 2)
        equal(count(h.Api.PendingTasks), 0)
        h:Step(1)
        equal(#h.Writes, writes)
    end)

    test("respawn restores old humanoid and applies latest to new", function()
        local h = fixture()
        h:EnableBoth()
        h:Set("WalkSpeedSlider", 65)
        h:Set("JumpPowerSlider", 110)
        h:Step(0)
        local _, hum = h:Respawn()
        equal(h.CancelCount, 2)
        equal(h.Humanoid.WalkSpeed, 21)
        equal(h.Humanoid.JumpPower, 61)
        equal(hum.WalkSpeed, 65)
        equal(hum.JumpPower, 110)
        equal(h.Api.Records[h.Humanoid], nil)
        local writes = #h.Writes
        h:Step(1)
        equal(#h.Writes, writes)
    end)

    test("CharacterAdded without Removing safely releases previous", function()
        local h = fixture()
        h:EnableBoth()
        h.Backing[h.Humanoid].Properties.WalkSpeed = 47
        local char = h:NewCharacter()
        local hum = h:NewHumanoid(char)
        h.Player.Character = char
        h.Player.CharacterAdded:Fire(char)
        equal(h.Humanoid.WalkSpeed, 47)
        equal(h.Humanoid.JumpPower, 61)
        equal(hum.WalkSpeed, 32)
    end)

    test("late humanoid ChildAdded binds and applies enabled controls", function()
        local h = fixture({ NoCharacter = true })
        h:EnableBoth()
        local char = h:NewCharacter()
        h.Player.Character = char
        h.Player.CharacterAdded:Fire(char)
        equal(#h.Writes, 0)
        local hum = h:NewHumanoid(char)
        char.ChildAdded:Fire(hum)
        equal(hum.WalkSpeed, 32)
        equal(hum.JumpPower, 100)
    end)

    test("Humanoid replacement releases old and binds new", function()
        local h = fixture()
        h:EnableBoth()
        h:Set("WalkSpeedSlider", 55)
        h:Step(0)
        local hum = h:NewHumanoid(h.Character, { WalkSpeed = 25 })
        h:RemoveHumanoid(h.Character, h.Humanoid)
        equal(h.Humanoid.WalkSpeed, 21)
        equal(hum.WalkSpeed, 55)
        equal(h.CancelCount, 1)
        h.Api.Stop()
        equal(hum.WalkSpeed, 25)
    end)

    test("irrelevant child events never enforce external overrides", function()
        local h = fixture()
        h:EnableBoth()
        h.Backing[h.Humanoid].Properties.WalkSpeed = 45
        local writes = #h.Writes
        h.Character.ChildAdded:Fire({})
        h.Character.ChildRemoved:Fire({})
        equal(#h.Writes, writes)
        equal(h.Humanoid.WalkSpeed, 45)
    end)

    test("unrelated old character lifecycle events ignored", function()
        local h = fixture()
        h:EnableBoth()
        local _, hum = h:Respawn()
        local writes = #h.Writes
        h.Player.CharacterRemoving:Fire(h.Character)
        h.Player.CharacterAdded:Fire(h.Character)
        h.Character.ChildAdded:Fire(h.Humanoid)
        equal(#h.Writes, writes)
        equal(hum.WalkSpeed, 32)
    end)

    test("unload restores properties, cancels work and disconnects", function()
        local h = fixture()
        h:EnableBoth()
        h:Set("WalkSpeedSlider", 60)
        h:Set("JumpPowerSlider", 110)
        h:Step(0)
        h.Library:Unload()
        equal(h.Humanoid.WalkSpeed, 21)
        equal(h.Humanoid.JumpPower, 61)
        equal(h.Humanoid.UseJumpPower, false)
        equal(h.CancelCount, 2)
        for _, event in ipairs(h.Signals) do
            for _, connection in ipairs(event.Connections) do equal(connection.Connected, false) end
        end
        local writes = #h.Writes
        h:Set("WalkSpeedToggle", true)
        h:Set("JumpPowerSlider", 120)
        h.Player.CharacterAdded:Fire(h.Character)
        h:Step(1)
        equal(#h.Writes, writes)
    end)

    test("Stop is idempotent and terminal", function()
        local h = fixture()
        h:EnableBoth()
        h.Api.Stop()
        local writes = #h.Writes
        h.Api.Stop()
        h:Set("WalkSpeedToggle", true)
        h:Set("JumpPowerToggle", true)
        h:Set("NoRagdoll", true)
        h:Respawn()
        equal(#h.Writes, writes)
    end)

    test("Stop never cancels its running scheduled coroutine", function()
        local h = fixture()
        h:Set("WalkSpeedToggle", true)
        h:Set("WalkSpeedSlider", 60)
        h:Step(0)
        local thread = h.Api.PendingTasks.WalkSpeed.Thread
        local chunk = assert(loadstring("return function(api) api.Stop() end"))()
        h.Tasks[thread] = nil
        h.Runtime.Threads[thread] = nil
        coroutine.close(thread)
        local stoppingThread = coroutine.create(function() chunk(h.Api) end)
        h.Api.PendingTasks.WalkSpeed.Thread = stoppingThread
        h.Runtime.Threads[stoppingThread] = true
        local ok, err = coroutine.resume(stoppingThread)
        assert(ok, tostring(err))
        h.Runtime.Threads[stoppingThread] = nil
        equal(h.CancelCount, 0)
    end)

    test("unload inside property writer does not cancel running task", function()
        local h = fixture()
        h:Set("WalkSpeedToggle", true)
        h:Set("WalkSpeedSlider", 60)
        h:Step(0)
        local fired = false
        h.Backing[h.Humanoid].BeforeWrite = function()
            if not fired then
                fired = true
                h.Library:Unload()
            end
        end
        h:Step(0.15)
        equal(h.CancelCount, 0)
        equal(count(h.Api.PendingTasks), 0)
        equal(count(h.Runtime.Threads), 0)
        h.Backing[h.Humanoid].BeforeWrite = nil
    end)

    test("NoRagdoll only disables two local engine states", function()
        local h = fixture()
        h:Set("NoRagdoll", true)
        equal(h.Humanoid:GetStateEnabled("Ragdoll"), false)
        equal(h.Humanoid:GetStateEnabled("FallingDown"), false)
        equal(#h.StateWrites, 2)
        equal(#h.Writes, 0)
        equal(h.SpawnCount, 0)
        h:Set("NoRagdoll", false)
        equal(h.Humanoid:GetStateEnabled("Ragdoll"), true)
        equal(h.Humanoid:GetStateEnabled("FallingDown"), true)
    end)

    test("previously false states remain false on unload", function()
        local h = fixture()
        h.Backing[h.Humanoid].States.Ragdoll = false
        h:Set("NoRagdoll", true)
        equal(#h.StateWrites, 1)
        h.Library:Unload()
        equal(h.Humanoid:GetStateEnabled("Ragdoll"), false)
        equal(h.Humanoid:GetStateEnabled("FallingDown"), true)
    end)

    test("external state override is not overwritten on cleanup", function()
        local h = fixture()
        h:Set("NoRagdoll", true)
        h.Backing[h.Humanoid].States.Ragdoll = true
        table.clear(h.StateWrites)
        h.Library:Unload()
        equal(#h.StateWrites, 1)
        equal(h.StateWrites[1].State, "FallingDown")
    end)

    test("unsupported state checks and writes fail independently", function()
        local h = fixture()
        h.Backing[h.Humanoid].StateReadErrors.Ragdoll = true
        h:Set("NoRagdoll", true)
        equal(h.Humanoid:GetStateEnabled("FallingDown"), false)
        h:Set("NoRagdoll", false)
        equal(h.Humanoid:GetStateEnabled("FallingDown"), true)
        h.Backing[h.Humanoid].StateReadErrors.Ragdoll = nil
        h.Backing[h.Humanoid].StateWriteErrors.Ragdoll = true
        h:Set("NoRagdoll", true)
        equal(h.Api.Records[h.Humanoid].States.Ragdoll.LastApplied, nil)
        h.Backing[h.Humanoid].StateWriteErrors.Ragdoll = nil
        h:Set("NoRagdoll", false)
        equal(h.Humanoid:GetStateEnabled("Ragdoll"), true)
    end)

    test("state restoration failure does not stop other state restore", function()
        local h = fixture()
        h:Set("NoRagdoll", true)
        h.Backing[h.Humanoid].StateWriteErrors.Ragdoll = true
        h:Set("NoRagdoll", false)
        equal(h.Humanoid:GetStateEnabled("FallingDown"), true)
    end)

    test("NoRagdoll respawn restores old states and captures new states", function()
        local h = fixture()
        h:Set("NoRagdoll", true)
        local _, hum = h:Respawn()
        equal(h.Humanoid:GetStateEnabled("Ragdoll"), true)
        equal(hum:GetStateEnabled("Ragdoll"), false)
        h.Api.Stop()
        equal(hum:GetStateEnabled("Ragdoll"), true)
        equal(hum:GetStateEnabled("FallingDown"), true)
    end)

    test("NoFallDamage disabled, honest tooltip, saved true normalizes false", function()
        local h = fixture({ Saved = { NoFallDamage = true } })
        local definition = h.Group.Definitions.NoFallDamage
        equal(definition.Default, false)
        equal(definition.Disabled, true)
        equal(definition.Tooltip, "No verified server fall-damage interface; local state changes do not prevent server damage.")
        equal(definition.DisabledTooltip, definition.Tooltip)
        equal(h.Controls.NoFallDamage.Value, false)
        h:Set("NoFallDamage", true)
        equal(h.Controls.NoFallDamage.Value, false)
        h:Set("NoFallDamage", false)
        equal(h.Controls.NoFallDamage.Value, false)
        equal(#h.Writes, 0)
        equal(#h.StateWrites, 0)
    end)

    test("only character lifecycle and Died signals are connected", function()
        local h = fixture()
        equal(#h.Signals, 5)
        equal(h.Signals[1], h.Player.CharacterAdded)
        equal(h.Signals[2], h.Player.CharacterRemoving)
        equal(h.Signals[3], h.Character.ChildAdded)
        equal(h.Signals[4], h.Character.ChildRemoved)
        equal(h.Signals[5], h.Backing[h.Humanoid].Died)
        h:Step(100)
        equal(h.SpawnCount, 0)
    end)

    print("Movement tests: " .. passed .. " passed, " .. failed .. " failed")
    assert(failed == 0, "Movement regression tests failed")
end
