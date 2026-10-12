return function(moduleSource)
    local passed, failed = 0, 0
    local keyValue = "END-1234-5678-9012-3456"
    local png = "\137PNG\r\n\26\nmock image"
    local fixtures = {}
    local function equal(actual, expected)
        assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
    local function signal()
        local event = { Connections = {} }
        function event:Connect(callback)
            local connection = { Connected = true, Callback = callback }
            function connection:Disconnect() self.Connected = false end
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
        local h = { Time = 0, Tasks = {}, Nodes = {}, Warnings = {}, Requests = {}, Writes = {}, Folders = {}, HttpGets = {},
            Data = { valid = true, plan = "weekly", expiresAt = "2099-01-01T00:00:00.000Z" },
            Status = 200, Body = '{"mock":true}', GetStatus = 200, GetBody = png }
        table.insert(fixtures, h)
        h.Game = {}
        local function new(class)
            local properties = { ClassName = class, Text = "", Activated = signal(), FocusLost = signal(), Destroying = signal(), AncestryChanged = signal() }
            local node = {}
            local methods = {}
            function methods:IsDescendantOf(root)
                local ancestor = properties.Parent
                while ancestor do
                    if ancestor == root then return true end
                    ancestor = ancestor.Parent
                end
                return false
            end
            function methods:Destroy()
                if properties.Destroyed then return end
                properties.Destroying:Fire()
                properties.Destroyed = true
                for _, child in ipairs(h.Nodes) do if child.Parent == node then child:Destroy() end end
                node.Parent = nil
            end
            setmetatable(node, {
                __index = function(_, name) return methods[name] or properties[name] end,
                __newindex = function(_, name, value)
                    properties[name] = value
                    if name == "Parent" then
                        properties.AncestryChanged:Fire(node, value)
                        for _, child in ipairs(h.Nodes) do
                            if child:IsDescendantOf(node) then child.AncestryChanged:Fire(node, value) end
                        end
                    end
                end,
            })
            table.insert(h.Nodes, node)
            return node
        end
        h.Parent = new("PlayerGui")
        h.Parent.Parent = h.Game
        h.Player = {}
        function h.Player:FindFirstChildOfClass(class) equal(class, "PlayerGui"); return not options.NoParent and h.Parent or nil end
        h.Http = {}
        function h.Http:JSONEncode(data)
            equal(type(data.key), "string")
            local fields = 0
            for _ in pairs(data) do fields += 1 end
            equal(fields, 1)
            return '{"key":"' .. data.key .. '"}'
        end
        function h.Http:JSONDecode(body)
            equal(body, h.Body)
            if h.DecodeError then error(keyValue) end
            return h.Data
        end
        function h.Game:GetService(name)
            if name == "HttpService" then return h.Http end
            equal(name, "Players")
            return { LocalPlayer = h.Player }
        end
        function h.Game:HttpGet(url)
            table.insert(h.HttpGets, url)
            if h.HttpGetError then error(keyValue) end
            return h.GetBody
        end
        h.Request = function(dto)
            table.insert(h.Requests, dto)
            if h.RequestError then error(keyValue) end
            if h.Delay then coroutine.yield(h.Delay) end
            if h.BadResponse then return h.BadResponse end
            return { StatusCode = dto.Method == "GET" and h.GetStatus or h.Status, Body = dto.Method == "GET" and h.GetBody or h.Body }
        end
        local globals = { __ENDHUB_KEY = keyValue }
        if options.NoStored then globals.__ENDHUB_KEY = nil end
        globals.__ENDHUB_KEY_SERVICE_URL = options.Override
        h.Globals = globals
        local taskAPI = {}
        function taskAPI.defer(callback)
            local thread = coroutine.create(callback)
            h.Tasks[thread] = h.Time
            return thread
        end
        function taskAPI.wait(delay) return coroutine.yield(delay) end
        function taskAPI.cancel(thread)
            if h.IgnoreCancel then return end
            h.Tasks[thread] = nil
            coroutine.close(thread)
        end
        function h:Step(delta)
            self.Time += delta or 0
            local due = {}
            for thread, when in pairs(self.Tasks) do if when <= self.Time then table.insert(due, thread) end end
            for _, thread in ipairs(due) do
                if self.Tasks[thread] then
                    local ok, delay = coroutine.resume(thread)
                    assert(ok, tostring(delay))
                    if coroutine.status(thread) == "dead" then self.Tasks[thread] = nil else self.Tasks[thread] = self.Time + delay end
                end
            end
        end
        function h:Start()
            self.Main = taskAPI.defer(function() self.Result = self.Gate.Authorize() end)
            self:Step()
        end
        function h:Node(name)
            for _, node in ipairs(self.Nodes) do if node.Name == name then return node end end
            error("Missing node " .. name)
        end
        function h:Submit(value)
            self:Node("Key").Text = value or keyValue
            self:Node("Submit").Activated:Fire()
            self:Step()
        end
        function h:Close()
            self:Node("Close").Activated:Fire()
            self:Step(0.1)
        end
        function h:Clean()
            for _, node in ipairs(self.Nodes) do
                for _, name in ipairs({ "Activated", "FocusLost", "Destroying", "AncestryChanged" }) do
                    for _, connection in ipairs(node[name].Connections) do equal(connection.Connected, false) end
                end
            end
            equal(next(self.Tasks), nil)
        end
        local env = setmetatable({
            ENDHUB_SERVICE_URL = options.Url == nil and "https://example.com" or options.Url,
            getgenv = function() return globals end, game = h.Game,
            Instance = { new = function(class) if h.GuiError then error(keyValue) end; return new(class) end },
            Enum = { ZIndexBehavior = { Sibling = "Sibling" }, Font = { Gotham = "Gotham" } },
            UDim2 = { new = function(...) return {...} end, fromScale = function(...) return {...} end, fromOffset = function(...) return {...} end },
            UDim = { new = function(...) return {...} end }, Vector2 = { new = function(...) return {...} end },
            Color3 = { fromRGB = function(...) return {...} end }, task = taskAPI,
            os = { clock = function() return h.Time end, time = function() return 1800000000 end },
            DateTime = { fromIsoDate = function()
                if h.DateError then error(keyValue) end
                return { UnixTimestamp = h.Expiry or 4000000000 }
            end },
            warn = function(message) table.insert(h.Warnings, message) end,
            isfolder = function(name) return h.Folders[name] == true end,
            makefolder = function(name) h.Folders[name] = true end,
            writefile = function(name, bytes) if h.WriteError then error(keyValue) end; h.Writes[name] = bytes end,
            getcustomasset = function(name) if h.AssetError then error(keyValue) end; return "asset://" .. name end,
        }, { __index = getfenv() })
        if not options.NoRequest then env[options.RequestName or "request"] = h.Request end
        if options.Syn then env.syn = { request = h.Request } end
        if options.Http then env.http = { request = h.Request } end
        if options.NonFunction then env.request = true end
        if options.Hidden then env.gethui = function() if options.HiddenError then error(keyValue) end; return h.Parent end end
        if options.NoAssets then env.getcustomasset, env.getsynasset, env.writefile = false, false, false end
        if options.SynAsset then env.getcustomasset = false; env.getsynasset = function() return "synasset://logo" end end
        h.Env = env
        local factory = assert(loadstring("local ENDHUB_SERVICE_URL = " .. string.format("%q", env.ENDHUB_SERVICE_URL) .. "\nlocal EndHubKeyGate = (function()\n" .. moduleSource .. "\nend)()\nreturn EndHubKeyGate", "KeyGate.luau"))
        setfenv(factory, env)
        h.Gate = factory()
        return h
    end
    local function test(name, callback)
        local ok, err = pcall(callback)
        if ok then passed += 1; print("PASS " .. name) else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
    end
    test("stored key is server-validated before any GUI", function()
        local h = fixture()
        equal(h.Gate.Authorize(), true)
        equal(#h.Nodes, 1)
        equal(h.Globals.__ENDHUB_KEY, nil)
        local dto = h.Requests[1]
        equal(dto.Url, "https://example.com/v1/validate")
        equal(dto.Method, "POST")
        equal(dto.Body, '{"key":"' .. keyValue .. '"}')
        equal(dto.Headers["Content-Type"], "application/json")
        equal(#h.HttpGets, 0)
        equal(h.Gate.Validate(), true)
        equal(#h.Requests, 2)
        equal(next(h.Writes), nil)
    end)
    test("all supported plans have strict expiry schemas", function()
        for _, plan in ipairs({ "weekly", "monthly", "60days", "permanent" }) do
            local h = fixture()
            h.Data.plan = plan
            if plan == "permanent" then h.Data.expiresAt = false end
            equal(h.Gate.Authorize(), true)
        end
    end)
    test("blank configuration displays a blocking English message", function()
        local h = fixture({ Url = "", NoStored = true })
        h:Start()
        equal(h:Node("Status").Text, "Key service is not configured")
        equal(h:Node("Title").Text, "EndHub")
        equal(h:Node("Footer").Text, "Powered by EndHub")
        h:Submit()
        equal(#h.Requests, 0)
        equal(h.Result, nil)
        h:Close()
        equal(h.Result, false)
        h:Clean()
    end)
    test("URL configuration rejects insecure roots and placeholders", function()
        for _, url in ipairs({ "", "http://example.com", "https://placeholder.workers.dev", "https://your-worker.workers.dev", "https://example.com/path", "https://u@example.com", "https://example.com?key=x", "https://example.com:443", "https://.example.com", "https://example..com", "https://-example.com", "https://example_.com" }) do
            local h = fixture({ Url = url, NoParent = true })
            equal(h.Gate.Authorize(), false)
            equal(#h.Requests, 0)
        end
        local h = fixture({ Url = "", Override = "https://gate.account.workers.dev/" })
        equal(h.Gate.Authorize(), true)
        equal(h.Requests[1].Url, "https://gate.account.workers.dev/v1/validate")
        h = fixture({ Override = "", NoParent = true })
        equal(h.Gate.Authorize(), false)
        equal(#h.Requests, 0)
    end)
    test("request API aliases and function guard", function()
        for _, options in ipairs({ { Syn = true }, { Http = true }, { RequestName = "http_request" }, {} }) do
            local h = fixture(options)
            equal(h.Gate.Authorize(), true)
        end
        for _, options in ipairs({ { NoRequest = true, NoParent = true }, { NonFunction = true, NoParent = true } }) do
            local h = fixture(options)
            equal(h.Gate.Authorize(), false)
            equal(#h.HttpGets, 0)
            equal(#h.Requests, 0)
        end
    end)
    test("captured endpoint and request API cannot drift through globals", function()
        local h = fixture()
        equal(h.Gate.Authorize(), true)
        h.Globals.__ENDHUB_KEY_SERVICE_URL = "https://other.example.com"
        h.Env.request = function() error("Unexpected replacement request") end
        h.Globals.__ENDHUB_KEY = "END-0000-0000-0000-0000"
        equal(h.Gate.Validate(), true)
        equal(h.Requests[2].Url, "https://example.com/v1/validate")
        equal(h.Requests[2].Body, h.Requests[1].Body)
    end)
    test("malformed keys and booleans never authenticate", function()
        for _, value in ipairs({ true, "END-1234-5678-9012-345", "END-1234-5678-9012-34567", "end-1234-5678-9012-3456", "END-1234-ABCD-9012-3456", keyValue .. "\n" }) do
            local h = fixture({ NoParent = true })
            h.Globals.__ENDHUB_KEY = value
            equal(h.Gate.Authorize(), false)
            equal(h.Globals.__ENDHUB_KEY, nil)
            equal(#h.Requests, 0)
        end
    end)
    test("status failures and response messages never leak keys", function()
        for _, status in ipairs({ 403, 429, 503, 500, 201, 302 }) do
            local h = fixture({ NoStored = true })
            h.Status = status
            h.Data = { valid = true, plan = "permanent", expiresAt = false, message = keyValue }
            h:Start(); h:Submit()
            equal(h.Result, nil)
            local text = h:Node("Status").Text
            assert(not text:find(keyValue, 1, true))
            if status == 403 then assert(text:find("revoked")) end
            if status == 429 then assert(text:find("Too many attempts")) end
            if status == 503 then assert(text:find("unavailable")) end
            h:Close(); h:Clean()
        end
    end)
    test("malformed response schemas fail closed", function()
        for _, data in ipairs({ false, "true", {}, { valid = false }, { valid = "true", plan = "permanent", expiresAt = false },
            { valid = true, plan = "trial", expiresAt = false }, { valid = true, plan = "permanent" },
            { valid = true, plan = "permanent", expiresAt = "2099-01-01T00:00:00Z" },
            { valid = true, plan = "weekly", expiresAt = false }, { valid = true, plan = "weekly", expiresAt = "tomorrow" },
            { valid = true, plan = "permanent", expiresAt = false, message = {} },
            { valid = true, plan = "permanent", expiresAt = false, [1] = true } }) do
            local h = fixture({ NoParent = true })
            h.Data = data
            equal(h.Gate.Authorize(), false)
        end
        for _, body in ipairs({ "true", "[]", "{\255}", "" }) do
            local h = fixture({ NoParent = true })
            h.Body = body
            equal(h.Gate.Authorize(), false)
        end
        local h = fixture({ NoParent = true })
        h.BadResponse = "true"
        equal(h.Gate.Authorize(), false)
    end)
    test("expiry and protected request/decode failures deny access", function()
        for _, field in ipairs({ "RequestError", "DecodeError", "DateError" }) do
            local h = fixture({ NoParent = true })
            h[field] = true
            equal(h.Gate.Authorize(), false)
        end
        for _, expiry in ipairs({ 1800000000, 1700000000, 0 / 0 }) do
            local h = fixture({ NoParent = true })
            h.Expiry = expiry
            equal(h.Gate.Authorize(), false)
        end
    end)
    test("native submit and Enter grant access only on server success", function()
        for _, enter in ipairs({ false, true }) do
            local h = fixture({ NoStored = true })
            h:Start()
            equal(h:Node("EndHubKey").Parent, h.Parent)
            if enter then h:Node("Key").Text = keyValue; h:Node("Key").FocusLost:Fire(true); h:Step() else h:Submit() end
            h:Step(0.1)
            equal(h.Result, true)
            equal(h:Node("EndHubKey").Destroyed, true)
            equal(h.Globals.__ENDHUB_KEY, nil)
            equal(h.Gate.Validate(), true)
            h:Clean()
        end
    end)
    test("invalid GUI key never sends HTTP", function()
        local h = fixture({ NoStored = true })
        h:Start(); h:Submit("bad key")
        equal(#h.Requests, 0)
        h:Close(); h:Clean()
    end)
    test("busy submissions coalesce and enforce a two-second cooldown", function()
        local h = fixture({ NoStored = true })
        h.Status, h.Delay = 403, 1
        h:Start(); h:Submit()
        h:Node("Submit").Activated:Fire()
        h:Node("Key").FocusLost:Fire(true)
        equal(#h.Requests, 1)
        h:Step(1)
        h:Node("Submit").Activated:Fire(); h:Step()
        equal(#h.Requests, 1)
        h:Step(1); h:Submit()
        equal(#h.Requests, 2)
        h:Close(); h:Clean()
    end)
    test("closing during HTTP suppresses late success even without cancellation", function()
        local h = fixture({ NoStored = true })
        h.Delay, h.IgnoreCancel = 3, true
        h:Start(); h:Submit(); h:Close()
        equal(h.Result, false)
        h:Step(3)
        equal(h.Result, false)
        local valid = h.Gate.Validate()
        equal(valid, false)
        equal(#h.Requests, 1)
        h:Clean()
    end)
    test("GUI and ancestor removal close the startup coroutine", function()
        for _, target in ipairs({ "gui", "parent", "destroy" }) do
            local h = fixture({ NoStored = true })
            h.Delay = 3
            h:Start(); h:Submit()
            if target == "gui" then h:Node("EndHubKey").Parent = nil
            elseif target == "parent" then h.Parent.Parent = nil else h.Parent:Destroy() end
            h:Step(0.1)
            equal(h.Result, false)
            h:Clean()
        end
    end)
    test("hidden GUI parent is optional and missing GUI fails safely", function()
        for _, options in ipairs({ { Hidden = true, NoParent = true, NoStored = true }, { Hidden = true, HiddenError = true, NoStored = true } }) do
            local h = fixture(options)
            h:Start(); h:Submit(); h:Step(0.1)
            equal(h.Result, true)
            h:Clean()
        end
        local h = fixture({ NoParent = true, NoStored = true })
        equal(h.Gate.Authorize(), false)
        h = fixture({ NoStored = true })
        h.GuiError = true
        equal(h.Gate.Authorize(), false)
    end)
    test("heartbeat always checks the server again and detects revocation", function()
        local h = fixture()
        equal(h.Gate.Authorize(), true)
        h.Status = 403
        equal(h.Gate.Validate(), false)
        equal(#h.Requests, 2)
    end)
    test("logo validates PNG bytes and uses only the EndHub asset path", function()
        local h = fixture()
        equal(h.Gate.Logo(), "asset://EndHub/logo.png")
        equal(h.Requests[1].Method, "GET")
        equal(h.Requests[1].Url, "https://example.com/logo.png")
        equal(h.Writes["EndHub/logo.png"], png)
        equal(h.Folders.EndHub, true)
        local count = 0
        for _ in pairs(h.Writes) do count += 1 end
        equal(count, 1)
        h = fixture({ SynAsset = true })
        equal(h.Gate.Logo(), "synasset://logo")
        h = fixture({ NoRequest = true })
        equal(h.Gate.Logo(), "asset://EndHub/logo.png")
        equal(h.HttpGets[1], "https://example.com/logo.png")
    end)
    test("logo failures always use shield without exposing errors", function()
        for _, options in ipairs({ { NoAssets = true }, { Url = "" }, {} }) do
            local h = fixture(options)
            if not options.NoAssets and options.Url == nil then h.AssetError = true end
            equal(h.Gate.Logo(), "shield")
            equal(#h.Warnings, 1)
        end
        for _, body in ipairs({ "<html>not a PNG</html>", png .. string.rep("x", 2 * 1024 * 1024), "" }) do
            local h = fixture()
            h.GetBody = body
            equal(h.Gate.Logo(), "shield")
            equal(next(h.Writes), nil)
        end
        for _, field in ipairs({ "RequestError", "WriteError" }) do
            local h = fixture()
            h[field] = true
            equal(h.Gate.Logo(), "shield")
        end
        local h = fixture()
        h.GetStatus = 503
        equal(h.Gate.Logo(), "shield")
    end)
    for _, h in ipairs(fixtures) do
        for _, warning in ipairs(h.Warnings) do assert(not warning:find(keyValue, 1, true), "Secret leaked in warning") end
        for thread in pairs(h.Tasks) do coroutine.close(thread) end
    end
    print("KeyGate tests: " .. passed .. " passed, " .. failed .. " failed")
    assert(failed == 0, "KeyGate regressions failed")
end
