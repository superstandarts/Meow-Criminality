return function(ctx)
    local Library = ctx.Library
    local Runtime = ctx.Runtime
    local LocalPlayer = ctx.LocalPlayer
    local group = ctx.PlayerGroup or ctx.PlayerLeft
    local records = setmetatable({}, { __mode = "k" })
    local pendingTasks = {}
    local connections = {}
    local characterConnections = {}
    local character
    local humanoid
    local diedConnection
    local stopped = false
    local controls = {}
    local states = { Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown }

    local function disconnect(list)
        for _, connection in ipairs(list) do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(list)
    end

    local function connect(signal, callback, list)
        if signal then
            local connection = Runtime.Connect(signal, callback)
            if connection then table.insert(list, connection) end
            return connection
        end
    end

    local function cancel(property)
        local ticket = pendingTasks[property]
        pendingTasks[property] = nil
        if ticket and ticket.Thread and ticket.Thread ~= coroutine.running() then
            Runtime.Cancel(ticket.Thread)
        end
    end

    local function getHumanoid()
        if stopped or Library.Unloaded then return nil end
        local ok, result = pcall(function()
            if not character or character ~= LocalPlayer.Character or not character.Parent
                or not character:IsDescendantOf(workspace) then return nil end
            local hum = character:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.Parent == character and hum.Health > 0 then return hum end
            return nil
        end)
        return ok and result or nil
    end

    local function recordFor(hum)
        local record = records[hum]
        if not record then
            record = { Properties = {}, States = {} }
            records[hum] = record
        end
        return record
    end

    local function writeProperty(hum, property, value)
        local ok, current = pcall(function() return hum[property] end)
        if not ok or current == value then return end
        local entries = recordFor(hum).Properties
        local entry = entries[property]
        if not entry then
            entry = { Original = current }
            entries[property] = entry
        end
        if pcall(function() hum[property] = value end) then entry.LastApplied = value end
    end

    local function restoreProperty(hum, record, property)
        local entry = record.Properties[property]
        if not entry then return end
        pcall(function()
            if entry.LastApplied ~= nil and hum[property] == entry.LastApplied then
                hum[property] = entry.Original
            end
        end)
        record.Properties[property] = nil
    end

    local function restoreStates(hum, record)
        for state, entry in pairs(record.States) do
            pcall(function()
                if entry.LastApplied == false and hum:GetStateEnabled(state) == false then
                    hum:SetStateEnabled(state, entry.Original)
                end
            end)
            record.States[state] = nil
        end
    end

    local function restoreAll()
        for hum, record in pairs(records) do
            restoreProperty(hum, record, "WalkSpeed")
            restoreProperty(hum, record, "JumpPower")
            restoreProperty(hum, record, "UseJumpPower")
            restoreStates(hum, record)
            records[hum] = nil
        end
    end

    local function valueFor(property)
        local value = controls[property .. "Slider"].Value
        local minimum = property == "WalkSpeed" and 16 or 50
        local maximum = property == "WalkSpeed" and 80 or 120
        if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
            return minimum
        end
        return math.clamp(value, minimum, maximum)
    end

    local function apply(property)
        local hum = getHumanoid()
        if not hum or hum ~= humanoid or controls[property .. "Toggle"].Value ~= true then return end
        if property == "JumpPower" then writeProperty(hum, "UseJumpPower", true) end
        writeProperty(hum, property, valueFor(property))
    end

    local function applyStates()
        local hum = getHumanoid()
        if not hum or hum ~= humanoid or controls.NoRagdoll.Value ~= true then return end
        for _, state in ipairs(states) do
            local ok, current = pcall(function() return hum:GetStateEnabled(state) end)
            if ok and current == true then
                local entries = recordFor(hum).States
                local entry = entries[state]
                if not entry then
                    entry = { Original = current }
                    entries[state] = entry
                end
                if pcall(function() hum:SetStateEnabled(state, false) end) then
                    entry.LastApplied = false
                end
            end
        end
    end

    local function schedule(property)
        if stopped or Library.Unloaded or controls[property .. "Toggle"].Value ~= true
            or not getHumanoid() or pendingTasks[property] then return end
        local ticket = {}
        pendingTasks[property] = ticket
        ticket.Thread = Runtime.Spawn(function()
            task.wait(0.15)
            if pendingTasks[property] ~= ticket then return end
            pendingTasks[property] = nil
            apply(property)
        end)
        if not ticket.Thread then pendingTasks[property] = nil end
    end

    local function toggle(property)
        if stopped or Library.Unloaded then return end
        cancel(property)
        if controls[property .. "Toggle"].Value == true then
            apply(property)
        else
            for hum, record in pairs(records) do
                restoreProperty(hum, record, property)
                if property == "JumpPower" then restoreProperty(hum, record, "UseJumpPower") end
            end
        end
    end

    controls.WalkSpeedSlider = group:AddSlider("WalkSpeedSlider", {
        Text = "Walk Speed", Min = 16, Max = 80, Default = 16, Rounding = 0,
    })
    controls.WalkSpeedToggle = group:AddToggle("WalkSpeedToggle", {
        Text = "Enable Walk Speed", Default = false,
    })
    controls.JumpPowerSlider = group:AddSlider("JumpPowerSlider", {
        Text = "Jump Power", Min = 50, Max = 120, Default = 50, Rounding = 0,
    })
    controls.JumpPowerToggle = group:AddToggle("JumpPowerToggle", {
        Text = "Enable Jump Power", Default = false,
    })
    controls.NoRagdoll = group:AddToggle("NoRagdoll", {
        Text = "No Ragdoll (Humanoid)", Default = false,
        Tooltip = "Local Humanoid Ragdoll and FallingDown states only; custom constraints and server behavior are unaffected.",
    })
    local fallTooltip = "No verified server fall-damage interface; local state changes do not prevent server damage."
    controls.NoFallDamage = group:AddToggle("NoFallDamage", {
        Text = "No Fall Damage", Default = false, Disabled = true,
        Tooltip = fallTooltip, DisabledTooltip = fallTooltip,
    })
    local setFallValue = controls.NoFallDamage.SetValue
    controls.NoFallDamage.SetValue = function(self)
        return setFallValue(self, false)
    end
    controls.NoFallDamage:SetValue(false)

    controls.WalkSpeedToggle:OnChanged(function() toggle("WalkSpeed") end)
    controls.JumpPowerToggle:OnChanged(function() toggle("JumpPower") end)
    controls.WalkSpeedSlider:OnChanged(function() schedule("WalkSpeed") end)
    controls.JumpPowerSlider:OnChanged(function() schedule("JumpPower") end)
    controls.NoRagdoll:OnChanged(function()
        if stopped or Library.Unloaded then return end
        if controls.NoRagdoll.Value == true then
            applyStates()
        else
            for hum, record in pairs(records) do restoreStates(hum, record) end
        end
    end)

    local function releaseHumanoid()
        cancel("WalkSpeed")
        cancel("JumpPower")
        if diedConnection then pcall(function() diedConnection:Disconnect() end) end
        diedConnection = nil
        restoreAll()
        humanoid = nil
    end

    local function refreshHumanoid()
        local hum = getHumanoid()
        if hum == humanoid then return end
        releaseHumanoid()
        humanoid = hum
        if not hum then return end
        diedConnection = connect(hum.Died, function()
            cancel("WalkSpeed")
            cancel("JumpPower")
        end, {})
        apply("WalkSpeed")
        apply("JumpPower")
        applyStates()
    end

    local function bindCharacter(newCharacter)
        if stopped or Library.Unloaded or newCharacter ~= LocalPlayer.Character then return end
        disconnect(characterConnections)
        releaseHumanoid()
        character = newCharacter
        if character then
            connect(character.ChildAdded, refreshHumanoid, characterConnections)
            connect(character.ChildRemoved, refreshHumanoid, characterConnections)
        end
        refreshHumanoid()
    end

    local function stop()
        if stopped then return end
        stopped = true
        disconnect(connections)
        disconnect(characterConnections)
        releaseHumanoid()
        character = nil
    end

    connect(LocalPlayer.CharacterAdded, bindCharacter, connections)
    connect(LocalPlayer.CharacterRemoving, function(oldCharacter)
        if oldCharacter ~= character then return end
        disconnect(characterConnections)
        releaseHumanoid()
        character = nil
    end, connections)
    Library:OnUnload(stop)
    bindCharacter(LocalPlayer.Character)
    return { Stop = stop, Records = records, PendingTasks = pendingTasks, Controls = controls }
end
