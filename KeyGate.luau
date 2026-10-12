local environment = (type(getgenv) == "function" and getgenv()) or _G
local service = environment.__ENDHUB_KEY_SERVICE_URL
if service == nil then service = ENDHUB_SERVICE_URL end
local requestAPI = (syn and syn.request) or (http and http.request) or http_request or request
local memory
local pattern = "^END%-%d%d%d%d%-%d%d%d%d%-%d%d%d%d%-%d%d%d%d$"
local plans = { weekly = true, monthly = true, ["60days"] = true, permanent = true }
local configured = false
if type(service) == "string" then
    local host = service:match("^https://([%w%.%-]+)/?$")
    if host and #host <= 253 and host:find("%.") and not host:find("%.%.")
        and not host:lower():find("placeholder", 1, true) and not host:lower():find("your-", 1, true) then
        configured = true
        for label in host:gmatch("[^%.]+") do
            if #label > 63 or not label:match("^[%w].*[%w]$") and not label:match("^[%w]$") then configured = false end
        end
        if host:sub(1, 1) == "." or host:sub(-1) == "." then configured = false end
    end
end
if configured then service = service:gsub("/$", "") end

local function Validate()
    if not configured then return false, "Key service is not configured" end
    if type(requestAPI) ~= "function" then return false, "This executor cannot send key validation requests" end
    if type(memory) ~= "string" or not memory:match(pattern) then return false, "Use END-0000-0000-0000-0000" end
    local ok, response, data = pcall(function()
        local httpService = game:GetService("HttpService")
        local reply = requestAPI({ Url = service .. "/v1/validate", Method = "POST",
            Headers = { ["Content-Type"] = "application/json", Accept = "application/json" },
            Body = httpService:JSONEncode({ key = memory }) })
        if type(reply) ~= "table" or type(reply.Body) ~= "string" then return reply, nil end
        if reply.StatusCode ~= 200 then return reply, nil end
        assert(utf8.len(reply.Body) and reply.Body:match("^%s*{"))
        return reply, httpService:JSONDecode(reply.Body)
    end)
    if not ok then return false, "Key service is unavailable" end
    local status = type(response) == "table" and response.StatusCode
    if status == 403 then return false, "Key is invalid, expired, or revoked" end
    if status == 429 then return false, "Too many attempts. Try again later" end
    if status == 503 then return false, "Key service is unavailable" end
    if status ~= 200 or type(data) ~= "table" or data[1] ~= nil
        or data.valid ~= true or type(data.plan) ~= "string" or not plans[data.plan]
        or data.message ~= nil and type(data.message) ~= "string" then
        return false, "Key validation failed"
    end
    if data.plan == "permanent" then
        if data.expiresAt ~= false then return false, "Key validation failed" end
    else
        if type(data.expiresAt) ~= "string" or not data.expiresAt:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.?%d*Z$") then
            return false, "Key validation failed"
        end
        local parsed, expiry = pcall(function() return DateTime.fromIsoDate(data.expiresAt).UnixTimestamp end)
        if not parsed or type(expiry) ~= "number" or not (expiry > os.time()) then return false, "Key is expired" end
    end
    return true, "Key accepted"
end

local function keyUI(message)
    local parent
    if type(gethui) == "function" then
        local ok, value = pcall(gethui)
        if ok then parent = value end
    end
    if not parent then
        pcall(function()
            local player = game:GetService("Players").LocalPlayer
            parent = player and player:FindFirstChildOfClass("PlayerGui")
        end)
    end
    if not parent then warn("[EndHub] No GUI parent is available"); return false end
    local gui, key, status, submit, close
    local created = pcall(function()
        local function new(class, owner, properties)
            local item = Instance.new(class)
            if class == "ScreenGui" then gui = item end
            for name, value in pairs(properties) do item[name] = value end
            item.Parent = owner
            return item
        end
        gui = new("ScreenGui", parent, { Name = "EndHubKey", ResetOnSpawn = false, DisplayOrder = 2147483647, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
        local frame = new("Frame", gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, 270), BackgroundColor3 = Color3.fromRGB(20, 23, 30) })
        new("UISizeConstraint", frame, { MaxSize = Vector2.new(420, 270) })
        new("UICorner", frame, { CornerRadius = UDim.new(0, 12) })
        local function text(class, name, value, y, height)
            return new(class, frame, { Name = name, Text = value, Position = UDim2.new(0, 20, 0, y), Size = UDim2.new(1, -40, 0, height), BackgroundColor3 = Color3.fromRGB(32, 37, 48), TextColor3 = Color3.fromRGB(235, 239, 247), TextSize = 16, Font = Enum.Font.Gotham, BorderSizePixel = 0 })
        end
        text("TextLabel", "Title", "EndHub", 15, 35)
        key = text("TextBox", "Key", "", 65, 40)
        key.PlaceholderText, key.ClearTextOnFocus = "END-0000-0000-0000-0000", false
        status = text("TextLabel", "Status", message, 115, 45)
        status.TextWrapped, status.TextSize = true, 14
        submit = text("TextButton", "Submit", "Submit", 170, 36)
        text("TextLabel", "Footer", "Powered by EndHub", 225, 25).TextSize = 12
        close = new("TextButton", frame, { Name = "Close", Text = "X", Position = UDim2.new(1, -35, 0, 10), Size = UDim2.fromOffset(25, 25), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(235, 239, 247), TextSize = 18 })
    end)
    if not created then
        if gui then pcall(function() gui:Destroy() end) end
        warn("[EndHub] Key interface is unavailable")
        return false
    end
    local accepted, closed, busy = false, false, false
    local connections, worker, last = {}, nil, -math.huge
    local attached = parent:IsDescendantOf(game)
    local function present()
        return gui.Parent == parent and (not attached or gui:IsDescendantOf(game))
    end
    local function dispose()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        if worker and worker ~= coroutine.running() then pcall(task.cancel, worker) end
        gui:Destroy()
    end
    local function stop()
        if closed or accepted then return end
        closed, memory = true, nil
        dispose()
    end
    local function send()
        if closed or accepted or busy or os.clock() - last < 2 then return end
        if not present() then stop(); return end
        if not key.Text:match(pattern) then status.Text = "Use END-0000-0000-0000-0000"; return end
        busy, last, memory = true, os.clock(), key.Text
        status.Text = "Checking key..."
        worker = task.defer(function()
            local valid, result = Validate()
            busy = false
            if closed then return end
            if not present() then stop(); return end
            if valid then accepted = true; dispose() else memory = nil; status.Text = result end
        end)
    end
    table.insert(connections, close.Activated:Connect(stop))
    table.insert(connections, submit.Activated:Connect(send))
    table.insert(connections, key.FocusLost:Connect(function(enter) if enter then send() end end))
    table.insert(connections, gui.Destroying:Connect(stop))
    table.insert(connections, gui.AncestryChanged:Connect(function() if not present() then stop() end end))
    while not accepted and not closed do
        if not present() then stop() else task.wait(0.1) end
    end
    return accepted and not closed
end

local function Authorize()
    local candidate = memory or environment.__ENDHUB_KEY
    environment.__ENDHUB_KEY = nil
    memory = candidate
    local valid, message = Validate()
    if valid then return true end
    memory = nil
    return keyUI(message)
end

local function Logo()
    local ok, asset = pcall(function()
        assert(configured and type(writefile) == "function" and type(isfolder) == "function")
        local customAsset = getcustomasset or getsynasset
        assert(type(customAsset) == "function")
        local bytes
        if type(requestAPI) == "function" then
            local response = requestAPI({ Url = service .. "/logo.png", Method = "GET" })
            assert(type(response) == "table" and response.StatusCode == 200)
            bytes = response.Body
        else bytes = game:HttpGet(service .. "/logo.png") end
        assert(type(bytes) == "string" and #bytes < 2 * 1024 * 1024 and bytes:sub(1, 8) == "\137PNG\r\n\26\n")
        if not isfolder("EndHub") then assert(type(makefolder) == "function"); makefolder("EndHub") end
        writefile("EndHub/logo.png", bytes)
        local value = customAsset("EndHub/logo.png")
        assert(type(value) == "string" and value ~= "")
        return value
    end)
    if ok then return asset end
    warn("[EndHub] Logo is unavailable; using shield icon")
    return "shield"
end

return { Authorize = Authorize, Validate = Validate, Logo = Logo }
