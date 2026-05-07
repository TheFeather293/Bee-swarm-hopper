_G.timeout = "10"
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players         = game:GetService("Players")
local HttpService     = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Workspace       = game:GetService("Workspace")

repeat task.wait() until Players.LocalPlayer
local LocalPlayer = Players.LocalPlayer

local XOR_KEY = 0x4A

local function xorDecode(hexStr)
    local result = {}
    for byte in hexStr:gmatch("%x%x") do
        local decoded = bit32.bxor(tonumber(byte, 16), XOR_KEY)
        table.insert(result, string.char(decoded))
    end
    return table.concat(result)
end

local function decodeJoinLink(url)
    if not url then return nil, nil end
    local launchData = url:match("[?&]launchData=([^&]+)")
    if not launchData then return nil, nil end
    launchData = launchData:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end)
    local placeId, encodedJobId = launchData:match("^(%d+)/(.+)$")
    if not placeId or not encodedJobId then return nil, nil end
    local jobId = xorDecode(encodedJobId)
    return tonumber(placeId), jobId
end

local function normalizeChannelList(rawChannels)
    local channels = {}
    if type(rawChannels) == "string" or type(rawChannels) == "number" then
        return { tostring(rawChannels) }
    end
    if type(rawChannels) ~= "table" then return channels end
    for _, item in ipairs(rawChannels) do
        local channelId = item
        if type(item) == "table" then
            channelId = item.id or item.channelId or item.channel
        end
        if channelId ~= nil then
            channelId = tostring(channelId)
            if channelId ~= "" then
                table.insert(channels, channelId)
            end
        end
    end
    return channels
end

local function splitFilterTerms(rawFilter)
    local terms = {}
    if type(rawFilter) == "table" then
        for _, value in ipairs(rawFilter) do
            if value ~= nil then
                value = tostring(value):match("^%s*(.-)%s*$")
                if value and value ~= "" then
                    table.insert(terms, value:lower())
                end
            end
        end
        return terms
    end
    rawFilter = tostring(rawFilter or "")
    for value in rawFilter:gmatch("([^,]+)") do
        value = tostring(value):match("^%s*(.-)%s*$")
        if value and value ~= "" then
            table.insert(terms, value:lower())
        end
    end
    return terms
end

local cfg = getgenv().cfg

local HISTORY_FOLDER            = "sprout-joiner"
local MESSAGE_RECHECK_SECONDS   = 60
local TELEPORT_WATCHDOG_SECONDS = 8

local CONFIG = {
    pollInterval        = tonumber(_G.joinerPollInterval) or 0.8,
    messagesPerChannel  = math.max(1, math.floor(tonumber(_G.joinerMessagesPerChannel) or 1)),
    idleTimeout         = tonumber(_G.timeout) or 60,
    historyLimit        = math.max(10, math.floor(tonumber(_G.joinerHistoryLimit) or 100)),
    jobCooldown         = math.max(30, math.floor(tonumber(_G.joinerJobCooldown) or 600)),
    messageHistoryLimit = math.max(25, math.floor(tonumber(_G.joinerMessageHistoryLimit) or 200)),
    messagesUrl         = "https://discord.com/api/v10/channels/%s/messages?limit=%d",
    token               = cfg.discord_token or "",
    channels            = normalizeChannelList(cfg.channels or {}),
    join_sprouts        = cfg.join_sprouts,
    sprouts             = cfg.sprouts or "",
    sproutGoneDelay     = math.max(0, tonumber(cfg.sprout_gone_delay) or 20),
    join_vicious        = cfg.join_vicious,
    vicious_bees        = cfg.vicious_bees or "",
    join_windy          = cfg.join_windy,
    join_stick_bug      = cfg.join_stick_bug,
    load_script         = cfg.load_script,
    load_script_delay   = math.max(0, tonumber(cfg.load_script_delay) or 5),
    loadScriptOnTargetOnly = cfg.load_script_on_target_only ~= true,
    script_url          = cfg.script_url or "",
}

local EVENT_RULES = {
    sprout = {
        enabled   = CONFIG.join_sprouts,
        terms     = splitFilterTerms(CONFIG.sprouts),
        label     = "sprouts",
        usesTerms = true,
    },
    vicious = {
        enabled   = CONFIG.join_vicious,
        terms     = splitFilterTerms(CONFIG.vicious_bees),
        label     = "vicious",
        usesTerms = true,
    },
    windy = {
        enabled   = CONFIG.join_windy,
        terms     = {},
        label     = "windy",
        usesTerms = false,
    },
    stick_bug = {
        enabled   = CONFIG.join_stick_bug,
        terms     = {},
        label     = "stick bug",
        usesTerms = false,
    },
}

local requestFn =
    request
    or http_request
    or (syn and syn.request)
    or (http and http.request)

if type(requestFn) ~= "function" then
    warn("[JOINER] request() is not available in this executor.")
    return
end

if CONFIG.token == "" then
    warn("[JOINER] Set discord_token in cfg before running.")
    return
end

if #CONFIG.channels == 0 then
    warn("[JOINER] No Discord channels configured. Add channel IDs to cfg.channels.")
    return
end

local function hasEnabledRules()
    for _, rule in pairs(EVENT_RULES) do
        if rule.enabled then return true end
    end
    return false
end

if not hasEnabledRules() then
    warn("[JOINER] No event filters are enabled in cfg.")
    return
end

-- ============================================================
-- IMPROVEMENT 1: Request with timeout to prevent freezes
-- ============================================================
local function performRequestWithTimeout(options, timeoutSeconds)
    timeoutSeconds = timeoutSeconds or 10
    local result, hadError = nil, false
    local done = false

    task.spawn(function()
        local ok, response = pcall(function() return requestFn(options) end)
        if not done then
            result = ok and response or nil
            hadError = not ok
            done = true
        end
    end)

    local elapsed = 0
    while not done and elapsed < timeoutSeconds do
        task.wait(0.1)
        elapsed += 0.1
    end

    if not done then
        warn("[JOINER] Request timed out after " .. timeoutSeconds .. "s")
        done = true
        return nil, true
    end
    return result, hadError
end

local state = {
    isTeleporting       = false,
    isHandlingTarget    = false,
    isPolling           = false,   -- IMPROVEMENT 2: polling guard
    lastStateChangeAt   = os.time(),
    teleportStartedAt   = nil,
    lastFailedJobId     = nil,
    currentTargetLabel  = nil,
    currentTargetType   = nil,
    missingTargetSince  = nil,
    loadScriptStarted   = false,
    recentJobs          = {},
    seenMessages        = {},
    seenMessageOrder    = {},
}

local historyPath = string.format("%s/%s.json", HISTORY_FOLDER, LocalPlayer.UserId)

local function ensureHistoryFolder()
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return end
    pcall(function()
        if not isfolder(HISTORY_FOLDER) then makefolder(HISTORY_FOLDER) end
    end)
end

local function pruneRecentJobs()
    local rows = {}
    local now  = os.time()
    for jobId, timestamp in pairs(state.recentJobs) do
        local ts = tonumber(timestamp)
        if ts and (now - ts) < CONFIG.jobCooldown then
            table.insert(rows, { jobId = jobId, timestamp = ts })
        else
            state.recentJobs[jobId] = nil
        end
    end
    table.sort(rows, function(a, b) return a.timestamp > b.timestamp end)
    for i = CONFIG.historyLimit + 1, #rows do
        state.recentJobs[rows[i].jobId] = nil
    end
end

local function saveHistory()
    if type(writefile) ~= "function" then return end
    ensureHistoryFolder()
    pruneRecentJobs()
    pcall(function()
        writefile(historyPath, HttpService:JSONEncode({ recentJobs = state.recentJobs }))
    end)
end

local function loadHistory()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    ensureHistoryFolder()
    pcall(function()
        if not isfile(historyPath) then return end
        local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(historyPath)) end)
        if not ok or type(decoded) ~= "table" then return end
        state.recentJobs = type(decoded.recentJobs) == "table" and decoded.recentJobs or decoded
    end)
    pruneRecentJobs()
end

-- ============================================================
-- IMPROVEMENT 3: Fixed pruneSeenMessages (scans all, not just front)
-- ============================================================
local function pruneSeenMessages()
    local now = os.time()
    while #state.seenMessageOrder > CONFIG.messageHistoryLimit do
        local id = table.remove(state.seenMessageOrder, 1)
        if id then state.seenMessages[id] = nil end
    end
    local fresh = {}
    for _, id in ipairs(state.seenMessageOrder) do
        local seenAt = state.seenMessages[id]
        if seenAt and (now - seenAt) < MESSAGE_RECHECK_SECONDS then
            table.insert(fresh, id)
        else
            state.seenMessages[id] = nil
        end
    end
    state.seenMessageOrder = fresh
end

local function hasSeenMessage(messageId)
    if not messageId or messageId == "" then return false end
    return state.seenMessages[messageId] ~= nil
end

local function clearSeenMessages()
    state.seenMessages     = {}
    state.seenMessageOrder = {}
end

local function rememberMessage(messageId)
    if not messageId or messageId == "" then return end
    if state.seenMessages[messageId] then return end
    state.seenMessages[messageId] = os.time()
    table.insert(state.seenMessageOrder, messageId)
    pruneSeenMessages()
end

local function rememberJob(jobId)
    if not jobId then return end
    jobId = tostring(jobId)
    if jobId == "" then return end
    state.recentJobs[jobId] = os.time()
    saveHistory()
end

local function hasRecentJob(jobId)
    if not jobId then return false end
    jobId = tostring(jobId)
    if jobId == "" then return false end
    pruneRecentJobs()
    return state.recentJobs[jobId] ~= nil
end

local function executeLoadScript()
    if not CONFIG.load_script then return end
    if not CONFIG.script_url or CONFIG.script_url == "" then
        warn("[SCRIPT] load_script is true but script_url is empty.")
        return
    end
    if state.loadScriptStarted then return end
    state.loadScriptStarted = true
    task.spawn(function()
        if CONFIG.load_script_delay > 0 then
            task.wait(CONFIG.load_script_delay)
        end
        if CONFIG.loadScriptOnTargetOnly and not state.isHandlingTarget then
            state.loadScriptStarted = false
            print("[SCRIPT] Target ended before script delay finished; skipping load.")
            return
        end
        local ok, err = pcall(function()
            -- Use timeout version here too
            local response, timedOut = performRequestWithTimeout({
                Url    = CONFIG.script_url,
                Method = "GET",
            }, 15)
            if timedOut or not response or response.StatusCode ~= 200 then
                error("fetch failed, status=" .. tostring(response and response.StatusCode or "timeout"))
            end
            local source = response.Body or response.body
            if type(source) ~= "string" or source == "" then
                error("fetch returned empty script body")
            end
            local loaded, compileError = loadstring(source)
            if not loaded then
                error(compileError or "loadstring returned nil")
            end
            if setfenv then
                setfenv(loaded, getgenv())
            end
            print("[SCRIPT] Starting: " .. tostring(CONFIG.script_url))
            local ran, runtimeError = xpcall(loaded, function(e)
                if debug and type(debug.traceback) == "function" then
                    return debug.traceback(tostring(e), 2)
                end
                return tostring(e)
            end)
            if not ran then error(runtimeError) end
        end)
        if not ok then
            warn("[SCRIPT] Execution error: " .. tostring(err))
        else
            print("[SCRIPT] ✓ Loaded: " .. tostring(CONFIG.script_url))
        end
    end)
end

local channelErrorCounts = {}

-- ============================================================
-- IMPROVEMENT 4: getRecentMessages uses timeout version
-- ============================================================
local function getRecentMessages(channelId)
    local response, hadError = performRequestWithTimeout({
        Url     = string.format(CONFIG.messagesUrl, channelId, CONFIG.messagesPerChannel),
        Method  = "GET",
        Headers = { Authorization = CONFIG.token },
    }, 10)

    if hadError or not response or response.StatusCode ~= 200 then
        channelErrorCounts[channelId] = (channelErrorCounts[channelId] or 0) + 1
        if channelErrorCounts[channelId] % 10 == 1 then
            warn(string.format("[JOINER] Channel %s fetch failed (attempt %d) | status=%s",
                tostring(channelId),
                channelErrorCounts[channelId],
                tostring(response and response.StatusCode or "no response/timeout")))
        end
        return nil, true
    end
    if channelErrorCounts[channelId] and channelErrorCounts[channelId] > 0 then
        print(string.format("[JOINER] Channel %s recovered after %d errors.", tostring(channelId), channelErrorCounts[channelId]))
        channelErrorCounts[channelId] = 0
    end
    local okDecode, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
    if not okDecode or type(data) ~= "table" then return nil, true end
    return data, false
end

local function addSearchText(parts, value)
    if value == nil then return end
    value = tostring(value)
    if value ~= "" then table.insert(parts, value) end
end

local function buildSearchText(message, embed)
    local parts = {}
    addSearchText(parts, message and message.content)
    addSearchText(parts, embed and embed.title)
    addSearchText(parts, embed and embed.description)
    if embed and type(embed.fields) == "table" then
        for _, field in ipairs(embed.fields) do
            if type(field) == "table" then
                addSearchText(parts, field.name)
                addSearchText(parts, field.value)
            end
        end
    end
    if embed and type(embed.footer) == "table" then
        addSearchText(parts, embed.footer.text)
    end
    return table.concat(parts, "\n")
end

local function normalizeComparableText(value)
    value = tostring(value or ""):lower()
    return value:gsub("[^%w]", "")
end

local function matchesAnyFilter(searchText, terms)
    local haystack           = searchText:lower()
    local normalizedHaystack = normalizeComparableText(searchText)
    if #terms == 0 then return true end
    for _, term in ipairs(terms) do
        local normalizedTerm = normalizeComparableText(term)
        local matched =
            haystack:find(term, 1, true) ~= nil
            or (normalizedTerm ~= "" and normalizedHaystack:find(normalizedTerm, 1, true) ~= nil)
        if matched then return true end
    end
    return false
end

local function getFieldValue(embed, wantedName)
    if not embed or type(embed.fields) ~= "table" then return nil end
    local targetName = tostring(wantedName):lower()
    for _, field in ipairs(embed.fields) do
        if type(field) == "table" and tostring(field.name or ""):lower() == targetName then
            return tostring(field.value or "")
        end
    end
    return nil
end

local function classifyEmbedType(embed)
    local title = tostring(embed and embed.title or ""):lower()
    if title:find("sprout", 1, true)      then return "sprout"    end
    if title:find("vicious bee", 1, true) then return "vicious"   end
    if title:find("windy bee", 1, true)   then return "windy"     end
    if title:find("stick bug", 1, true)   then return "stick_bug" end
    return nil
end

local function shouldJoinEmbed(message, embed)
    local eventType = classifyEmbedType(embed)
    local rule      = eventType and EVENT_RULES[eventType] or nil
    if not rule or not rule.enabled then return false, nil end
    if not rule.usesTerms then return true, eventType end
    local searchText = buildSearchText(message, embed)
    if matchesAnyFilter(searchText, rule.terms) then return true, eventType end
    return false, eventType
end

local function extractTargetFromEmbed(message, embed)
    if type(embed) ~= "table" then return nil, nil end
    local joinValue =
        getFieldValue(embed, "Join Server")
        or getFieldValue(embed, "Join Game")
        or getFieldValue(embed, "Join")
    if joinValue then
        local url = joinValue:match("%((.-)%)") or joinValue:match("(https?://%S+)")
        if url then
            local placeId, jobId = decodeJoinLink(url)
            if placeId and jobId and jobId ~= "" then
                return placeId, jobId
            end
        end
    end
    local searchText = buildSearchText(message, embed)
    for url in searchText:gmatch("https?://%S+") do
        local placeId, jobId = decodeJoinLink(url)
        if placeId and jobId and jobId ~= "" then
            return placeId, jobId
        end
    end
    return nil, nil
end

local function extractCandidate(message, channelId)
    if type(message) ~= "table" or type(message.embeds) ~= "table" then return nil end
    for _, embed in ipairs(message.embeds) do
        if type(embed) == "table" then
            local shouldJoin, eventType = shouldJoinEmbed(message, embed)
            if shouldJoin then
                local placeId, jobId = extractTargetFromEmbed(message, embed)
                if placeId and jobId then
                    local isCurrentServer = placeId == game.PlaceId and jobId == game.JobId
                    if not isCurrentServer and not hasRecentJob(jobId) then
                        print(string.format("[JOINER] Decoded job: %.8s... (place %s)", jobId, tostring(placeId)))
                        return {
                            placeId   = placeId,
                            jobId     = jobId,
                            channelId = tostring(channelId),
                            messageId = tostring(message.id or ""),
                            title     = tostring(embed.title or "Target"),
                            eventType = eventType,
                        }
                    end
                end
            end
        end
    end
    return nil
end

local function getInstancePosition(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance.Position end
    if instance:IsA("Model") then
        local root = instance.PrimaryPart or instance:FindFirstChild("HumanoidRootPart") or instance:FindFirstChildWhichIsA("BasePart", true)
        return root and root.Position or nil
    end
    local base = instance:FindFirstChildWhichIsA("BasePart", true)
    return base and base.Position or nil
end

local function getFieldName(position)
    if not position then return "Unknown Field" end
    local zones = Workspace:FindFirstChild("FlowerZones")
    if not zones then return "Unknown Field" end
    local bestZone, bestDist = nil, math.huge
    for _, zone in ipairs(zones:GetChildren()) do
        if zone:IsA("BasePart") then
            local zp = zone.Position
            local zs = zone.Size
            if math.abs(position.X - zp.X) <= zs.X / 2 and math.abs(position.Z - zp.Z) <= zs.Z / 2 then
                return zone.Name
            end
            local dist = math.abs(position.X - zp.X) + math.abs(position.Z - zp.Z)
            if dist < bestDist then bestDist = dist; bestZone = zone end
        end
    end
    return bestZone and bestZone.Name .. " (nearest)" or "Unknown Field"
end

local function getContainingFieldName(position, padding)
    if not position then return nil end
    local zones = Workspace:FindFirstChild("FlowerZones")
    if not zones then return nil end
    padding = tonumber(padding) or 0
    for _, zone in ipairs(zones:GetChildren()) do
        if zone:IsA("BasePart") then
            local zp = zone.Position
            local zs = zone.Size
            local withinX = math.abs(position.X - zp.X) <= (zs.X / 2 + padding)
            local withinZ = math.abs(position.Z - zp.Z) <= (zs.Z / 2 + padding)
            if withinX and withinZ then
                return zone.Name
            end
        end
    end
    return nil
end

local function getSproutLabel(sprout)
    local bc = sprout and sprout.BrickColor and sprout.BrickColor.Name or ""
    if bc == "Light grey metallic" then return "Rare"      end
    if bc == "Sage green"          then return "Normal"    end
    if bc == "CGA brown"           then return "Epic"      end
    if bc == "Alder"               then return "Gummy"     end
    if bc == "Medium blue"         then return "Moon"      end
    if bc == "Electric blue"       then return "Legendary" end
    return "Supreme"
end

local function getSproutPollenText(sprout)
    local text = "Unknown"
    pcall(function()
        local guiPos = sprout:FindFirstChild("GuiPos", true)
        local gui    = guiPos and guiPos:FindFirstChild("Gui", true)
        local frame  = gui and gui:FindFirstChild("Frame", true)
        local label  = frame and frame:FindFirstChild("TextLabel", true)
        if label then text = tostring(label.Text or "") end
    end)
    return text
end

local function getSproutHP(sprout)
    local text = getSproutPollenText(sprout)
    local current = text:match("(%d[%d,]*)")
    if not current then return nil end
    current = current:gsub(",", "")
    return tonumber(current)
end

local function isAliveSprout(instance)
    if not instance or instance.Parent == nil or not instance:IsA("BasePart") then return false end
    local folder = Workspace:FindFirstChild("Sprouts")
    if not folder then return false end
    local exact = folder:FindFirstChild("Sprout")
    if exact ~= instance or tostring(instance.Name or ""):lower() ~= "sprout" then return false end
    local hp = getSproutHP(instance)
    if not hp or hp <= 0 then return false end
    return getContainingFieldName(getInstancePosition(instance), 8) ~= nil
end

local function findSproutInstance()
    local folder = Workspace:FindFirstChild("Sprouts")
    if not folder then return nil end
    local sprout = folder:FindFirstChild("Sprout")
    if sprout and isAliveSprout(sprout) then return sprout end
    return nil
end

local function isAliveMonster(model, wantedName)
    if not model or model.Parent == nil or not model:IsA("Model") then return false end
    local monsters = Workspace:FindFirstChild("Monsters")
    if not monsters or model.Parent ~= monsters then return false end
    if not tostring(model.Name or ""):lower():find(wantedName, 1, true) then return false end
    local h = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChild("Humanoid", true)
    if not h or h.Health <= 0 then return false end
    return true
end

local function findMonsterInstance(wantedName)
    local monsters = Workspace:FindFirstChild("Monsters")
    if not monsters then return nil end
    for _, child in ipairs(monsters:GetChildren()) do
        if isAliveMonster(child, wantedName) then return child end
    end
    return nil
end

local function getActiveTargetInCurrentServer()
    local sproutRule = EVENT_RULES.sprout
    if sproutRule and sproutRule.enabled then
        local sprout = findSproutInstance()
        if sprout then
            local label = getSproutLabel(sprout)
            if matchesAnyFilter(label, sproutRule.terms) then
                local fieldName = getContainingFieldName(getInstancePosition(sprout), 8) or getFieldName(getInstancePosition(sprout))
                return { eventType = "sprout", label = label .. " Sprout @ " .. fieldName }
            end
        end
    end
    local viciousRule = EVENT_RULES.vicious
    if viciousRule and viciousRule.enabled then
        local vicious = findMonsterInstance("vicious bee")
        if vicious then
            local fieldName = getFieldName(getInstancePosition(vicious))
            if matchesAnyFilter(fieldName, viciousRule.terms) then
                return { eventType = "vicious", label = "Vicious Bee @ " .. fieldName }
            end
        end
    end
    if EVENT_RULES.windy and EVENT_RULES.windy.enabled then
        if findMonsterInstance("windy bee") then
            return { eventType = "windy", label = "Windy Bee" }
        end
    end
    if EVENT_RULES.stick_bug and EVENT_RULES.stick_bug.enabled then
        if findMonsterInstance("stick bug") then
            return { eventType = "stick_bug", label = "Stick Bug" }
        end
    end
    return nil
end

-- ============================================================
-- IMPROVEMENT 5: Throttled target refresh (every 3s not every 1s)
-- ============================================================
local lastTargetRefresh = 0

local function refreshTargetHoldState()
    local now = os.time()
    if now - lastTargetRefresh < 3 then
        -- Return current hold state without re-scanning Workspace
        return state.isHandlingTarget, false
    end
    lastTargetRefresh = now

    local activeTarget = getActiveTargetInCurrentServer()
    if activeTarget then
        if not state.isHandlingTarget or state.currentTargetLabel ~= activeTarget.label then
            print("[JOINER] Holding current server for " .. activeTarget.label)
        end
        state.isHandlingTarget   = true
        state.currentTargetLabel = activeTarget.label
        state.currentTargetType  = activeTarget.eventType
        state.missingTargetSince = nil
        state.lastStateChangeAt  = os.time()
        executeLoadScript()
        return true, false
    end
    if state.isHandlingTarget then
        if state.currentTargetType == "sprout" and CONFIG.sproutGoneDelay > 0 then
            if not state.missingTargetSince then
                state.missingTargetSince = now
                print("[JOINER] Sprout gone, waiting " .. tostring(CONFIG.sproutGoneDelay) .. "s before resuming hops.")
                return true, false
            end
            if now - state.missingTargetSince < CONFIG.sproutGoneDelay then
                return true, false
            end
        end
        print("[JOINER] Target finished, resuming hops.")
        state.isHandlingTarget   = false
        state.currentTargetLabel = nil
        state.currentTargetType  = nil
        state.missingTargetSince = nil
        state.lastStateChangeAt  = os.time()
        rememberJob(game.JobId)
        clearSeenMessages()
        return false, true
    end
    return false, false
end

local function captureInitialTargetState()
    for _ = 1, 5 do
        if select(1, refreshTargetHoldState()) then return true end
        task.wait(1)
    end
    return false
end

local function resetRuntimeState()
    pcall(function() TeleportService:TeleportCancel() end)
    state.isTeleporting      = false
    state.teleportStartedAt  = nil
    state.isHandlingTarget   = false
    state.lastFailedJobId    = nil
    state.currentTargetLabel = nil
    state.currentTargetType  = nil
    state.missingTargetSince = nil
    state.lastStateChangeAt  = os.time()
end

local function canTeleportToCandidate(candidate)
    if not candidate then return false end
    if not candidate.jobId or not candidate.placeId then return false end
    if candidate.placeId == game.PlaceId and candidate.jobId == game.JobId then return false end
    if hasRecentJob(candidate.jobId) then return false end
    if state.isTeleporting or state.isHandlingTarget then return false end
    state.isTeleporting = true
    return true
end

local function teleportToCandidate(candidate)
    if not canTeleportToCandidate(candidate) then return false end
    state.teleportStartedAt = os.time()
    state.lastFailedJobId   = candidate.jobId
    state.lastStateChangeAt = os.time()
    rememberJob(candidate.jobId)
    print(string.format("[JOINER] Joining %s | place=%s | job=%.8s...",
        tostring(candidate.title or "Target"),
        tostring(candidate.placeId),
        tostring(candidate.jobId)))
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(candidate.placeId, candidate.jobId, LocalPlayer)
    end)
    if not ok then
        warn("[JOINER] Teleport failed: " .. tostring(err))
        resetRuntimeState()
        return false
    end
    return true
end

-- ============================================================
-- IMPROVEMENT 6: isPolling guard prevents thread pile-up
-- ============================================================
local function pollChannels()
    if state.isTeleporting or state.isHandlingTarget then return end
    if state.isPolling then return end
    state.isPolling = true

    pruneSeenMessages()
    local foundCandidate = false

    for _, channelId in ipairs(CONFIG.channels) do
        if foundCandidate then break end
        local messages, hadError = getRecentMessages(channelId)
        if not hadError and type(messages) == "table" then
            local message = messages[1]
            local messageId = tostring(message and message.id or "")
            if messageId ~= "" and hasSeenMessage(messageId) then
                -- Latest message already handled.
            else
                local candidate = extractCandidate(message, channelId)
                if candidate then
                    if messageId ~= "" then rememberMessage(messageId) end
                    if teleportToCandidate(candidate) then
                        foundCandidate = true
                    end
                else
                    if messageId ~= "" then rememberMessage(messageId) end
                end
            end
        end
    end

    state.isPolling = false
end

-- ============================================================
-- IMPROVEMENT 7: Heartbeat tracking
-- ============================================================
_G.joinerLastHeartbeat = os.time()

local function handleIdleTimeout()
    rememberJob(game.JobId)
    state.lastStateChangeAt  = os.time()
    state.lastFailedJobId    = nil
    state.isTeleporting      = false
    state.teleportStartedAt  = nil
    state.currentTargetLabel = nil
    state.currentTargetType  = nil
    state.missingTargetSince = nil
    task.wait(0.5)
    pollChannels()
end

local function summarizeEnabledRules()
    local summary = {}
    local order   = { "sprout", "vicious", "windy", "stick_bug" }
    for _, eventType in ipairs(order) do
        local rule = EVENT_RULES[eventType]
        if rule and rule.enabled then
            local value = rule.label
            if not rule.usesTerms then
                value = value .. "=on"
            elseif #rule.terms == 0 then
                value = value .. "=all"
            else
                value = value .. "=" .. table.concat(rule.terms, "|")
            end
            table.insert(summary, value)
        end
    end
    return #summary > 0 and table.concat(summary, "; ") or "none"
end

loadHistory()
rememberJob(game.JobId)

TeleportService.TeleportInitFailed:Connect(function(player)
    if player ~= LocalPlayer then return end
    warn("[JOINER] TeleportInitFailed")
    if state.lastFailedJobId then rememberJob(state.lastFailedJobId) end
    resetRuntimeState()
    clearSeenMessages()
    task.wait(0.5)
    pollChannels()
end)

LocalPlayer.OnTeleport:Connect(function(teleportState)
    if teleportState == Enum.TeleportState.Failed then
        warn("[JOINER] Teleport failed, resetting...")
        if state.lastFailedJobId then rememberJob(state.lastFailedJobId) end
        resetRuntimeState()
        clearSeenMessages()
        task.wait(0.5)
        pollChannels()
    end
end)

if _G.joinerLoopRunning then
    _G.joinerLoopRunning = false
    task.wait(0.25)
end

_G.joinerLoopRunning = true

print(string.format(
    "[JOINER] Ready | channels=%d | filters=%s | timeout=%ss | poll=%.1fs",
    #CONFIG.channels,
    summarizeEnabledRules(),
    tostring(CONFIG.idleTimeout),
    CONFIG.pollInterval
))

if not CONFIG.loadScriptOnTargetOnly then
    executeLoadScript()
end

local holdingInitialTarget = captureInitialTargetState()
if not holdingInitialTarget then pollChannels() end

-- Poll loop
task.spawn(function()
    while _G.joinerLoopRunning do
        task.wait(CONFIG.pollInterval)
        _G.joinerLastHeartbeat = os.time()  -- heartbeat
        pollChannels()
    end
end)

-- Prune jobs on a timer
task.spawn(function()
    while _G.joinerLoopRunning do
        task.wait(60)
        pruneRecentJobs()
    end
end)

-- State management + watchdog loop
task.spawn(function()
    while _G.joinerLoopRunning do
        local _, releasedTarget = refreshTargetHoldState()
        local timeout = tonumber(_G.timeout) or CONFIG.idleTimeout
        if releasedTarget then
            task.wait(0.5)
            pollChannels()
        end
        if timeout > 0
            and not state.isTeleporting
            and not state.isHandlingTarget
            and os.time() - state.lastStateChangeAt >= timeout then
            print("[JOINER] Idle timeout, looking for new server.")
            handleIdleTimeout()
        end
        if state.isTeleporting
            and state.teleportStartedAt
            and os.time() - state.teleportStartedAt >= TELEPORT_WATCHDOG_SECONDS then
            warn(string.format("[JOINER] Teleport watchdog triggered after %ds, resetting.", TELEPORT_WATCHDOG_SECONDS))
            if state.lastFailedJobId then rememberJob(state.lastFailedJobId) end
            resetRuntimeState()
            clearSeenMessages()
            task.wait(0.5)
            pollChannels()
        end
        task.wait(1)
    end
end)
