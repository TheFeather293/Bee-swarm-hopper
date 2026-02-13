repeat task.wait() until game:IsLoaded()
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local request = request or http_request or syn.request
local WEBHOOK_URL = "https://discord.com/api/webhooks/1471934269462024217/0mVk1Hbl4Fi_1EtrFGPkwhE3fUyjMBcg7rwEwPpW1clj8l_Gs94C2h0seASRbspsTpIA"

-- Configuration
local PLACE_ID = game.PlaceId
local HOP_DELAY = 1
local TELEPORT_TIMEOUT = 8 -- Seconds before trying next server
local MIN_PLAYERS_TO_JOIN = 2 -- Ignore servers with fewer players (likely new/empty)
local PREFER_POPULATED_SERVERS = true -- Prioritize servers with more players (older servers)

-- Server hop state - EACH ACCOUNT NOW HAS UNIQUE HISTORY
local file = {}
local file2 = "sprout-hop/history_" .. Players.LocalPlayer.UserId .. ".json"  -- Unique per account
local currentTeleportAttempt = 0
local lastTeleportTime = 0

-- Create folder and load history
pcall(function() 
    if not isfolder("sprout-hop") then 
        makefolder("sprout-hop") 
    end 
end)

pcall(function() 
    if isfile(file2) then 
        file = HttpService:JSONDecode(readfile(file2)) 
    end 
end)

-- Save visited servers
local function savehist()
    local c = 0
    for _ in pairs(file) do c = c + 1 end
    if c >= 50 then file = {} end
    pcall(function() 
        writefile(file2, HttpService:JSONEncode(file)) 
    end)
end

-- Field thumbnail mapping
local fieldThumbnails = {
    ["Sunflower Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/e/ef/Hivesticker_sunflower_field_stamp.png",
    ["Dandelion Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/6/64/Hivesticker_dandelion_field_stamp.png",
    ["Mushroom Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/b/b0/Hivesticker_mushroom_field_stamp.png",
    ["Blue Flower Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/7/7a/Hivesticker_blue_flower_field_stamp.png",
    ["Clover Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/7/7f/Hivesticker_clover_field_stamp.png",
    ["Strawberry Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/b/bf/Hivesticker_strawberry_field_stamp.png",
    ["Spider Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/1/1c/Hivesticker_spider_field_stamp.png",
    ["Bamboo Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/0/0d/Hivesticker_bamboo_field_stamp.png",
    ["Pineapple Patch"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/1/15/Hivesticker_pineapple_patch_stamp.png",
    ["Stump Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/a/a9/Hivesticker_stump_field_stamp.png",
    ["Cactus Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/8/84/Hivesticker_cactus_field_stamp.png",
    ["Pumpkin Patch"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/c/cf/Hivesticker_pumpkin_patch_stamp.png",
    ["Pine Tree Forest"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/0/0a/Hivesticker_pine_tree_forest_stamp.png",
    ["Rose Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/d/d8/Hivesticker_rose_field_stamp.png",
    ["Mountain Top Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/8/87/Hivesticker_mountain_top_field_stamp.png",
    ["Pepper Patch"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/6/6a/Hivesticker_pepper_patch_stamp.png",
    ["Coconut Field"] = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/6/62/Hivesticker_coconut_field_stamp.png"
}

-- Function to get field name from position
local function getFieldName(pos)
    local FlowerZones = Workspace:FindFirstChild("FlowerZones")
    if not FlowerZones then return "Unknown Field" end
    
    for _, zone in pairs(FlowerZones:GetChildren()) do
        if zone:IsA("BasePart") then
            local zonePos = zone.Position
            local zoneSize = zone.Size
            
            if math.abs(pos.X - zonePos.X) <= zoneSize.X / 2 and
               math.abs(pos.Z - zonePos.Z) <= zoneSize.Z / 2 then
                return zone.Name
            end
        end
    end
    
    return "Unknown Field"
end

-- Function to send webhook
local function sendSproutWebhook(sprout)
    print("[WEBHOOK] Starting webhook send process...")
    
    task.spawn(function()
        print("[WEBHOOK] Task spawned successfully")
        
        local pos = sprout.Position
        print(string.format("[WEBHOOK] Sprout position: %.2f, %.2f, %.2f", pos.X, pos.Y, pos.Z))
        
        local fieldName = getFieldName(pos)
        print("[WEBHOOK] Field name:", fieldName)
        
        local brickColor = sprout.BrickColor.Name
        print("[WEBHOOK] BrickColor:", brickColor)
        
        local sproutType, embedColor
        
        if brickColor == "Light grey metallic" then
            sproutType = "Rare"
            embedColor = 0x5865F2
        elseif brickColor == "Sage green" then
            sproutType = "Normal"
            embedColor = 0x57F287
        elseif brickColor == "CGA brown" then
            sproutType = "Epic"
            embedColor = 0xFEE75C
        elseif brickColor == "Alder" then
            sproutType = "Gummy"
            embedColor = 0xE91E63
        elseif brickColor == "Medium blue" then
            sproutType = "Moon"
            embedColor = 0x00BFFF
        elseif brickColor == "Electric blue" then
            sproutType = "Legendary"
            embedColor = 0xFF00FF
        else
            sproutType = "Supreme"
            embedColor = 0xFFD700
        end
        
        print("[WEBHOOK] Sprout type:", sproutType, "Color:", embedColor)
        
        local pollenText = "Unknown"
        pcall(function()
            local guiLabel = sprout:FindFirstChild("GuiPos", true):FindFirstChild("Gui", true):FindFirstChild("Frame", true):FindFirstChild("TextLabel", true)
            if guiLabel then
                pollenText = guiLabel.Text
            end
        end)
        print("[WEBHOOK] Pollen text:", pollenText)
        
        local playerCount = #Players:GetPlayers()
        local maxPlayers = Players.MaxPlayers
        print(string.format("[WEBHOOK] Players: %d/%d", playerCount, maxPlayers))
        
        local jobId = game.JobId
        local placeId = game.PlaceId
        local webLink = string.format("https://www.roblox.com/games/start?placeId=%s&launchData=%%7B%%22gameId%%22%%3A%%22%s%%22%%7D", placeId, jobId)
        local directLink = string.format("roblox://placeID=%s&gameInstanceId=%s", placeId, jobId)
        
        print("[WEBHOOK] JobId:", jobId)
        print("[WEBHOOK] PlaceId:", placeId)
        
        local emoji = "🌱"
        if sproutType == "Rare" then emoji = "🌟"
        elseif sproutType == "Epic" then emoji = "🔥"
        elseif sproutType == "Gummy" then emoji = "🍬"
        elseif sproutType == "Moon" then emoji = "🌙"
        elseif sproutType == "Legendary" then emoji = "⚡"
        elseif sproutType == "Supreme" then emoji = "👑"
        end
        
        local thumbnailUrl = fieldThumbnails[fieldName]
        
        print(string.format("[FOUND] %s %s @ %s", emoji, sproutType, fieldName))
        
        local embed = {
            title = string.format("%s %s Sprout Detected!", emoji, sproutType),
            color = embedColor,
            fields = {
                {
                    name = "📍 Position",
                    value = string.format("```%.2f, %.2f, %.2f```", pos.X, pos.Y, pos.Z),
                    inline = true
                },
                {
                    name = "🌸 Pollen Left",
                    value = string.format("```%s```", pollenText),
                    inline = true
                },
                {
                    name = "🌾 Field",
                    value = string.format("```%s```", fieldName),
                    inline = true
                },
                {
                    name = "😳 Players",
                    value = string.format("```%d/%d```", playerCount, maxPlayers),
                    inline = true
                },
                {
                    name = "🔗 Join Server",
                    value = string.format("**[Click Here to Join](%s)**\n```%s```", webLink, directLink),
                    inline = false
                }
            },
            footer = {
                text = "Sprout Hopper • " .. os.date("%I:%M %p")
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%S")
        }
        
        if thumbnailUrl then
            embed.thumbnail = { url = thumbnailUrl }
        end
        
        print("[WEBHOOK] Embed created, preparing to send...")
        
        -- Check if request function exists
        if not request then
            warn("[WEBHOOK] ERROR: 'request' function not found! Your executor may not support it.")
            warn("[WEBHOOK] Try: request, http_request, or syn.request")
            return
        end
        
        print("[WEBHOOK] Request function found:", type(request))
        
        local webhookBody = HttpService:JSONEncode({ embeds = {embed} })
        print("[WEBHOOK] JSON body created, length:", #webhookBody)
        
        local success, result = pcall(function()
            print("[WEBHOOK] Sending HTTP request...")
            local response = request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = webhookBody
            })
            print("[WEBHOOK] Response received:", response)
            return response
        end)
        
        if success then
            print("[WEBHOOK] ✓ Webhook sent successfully!")
            if result then
                print("[WEBHOOK] Response status:", result.StatusCode or "unknown")
                print("[WEBHOOK] Response body:", result.Body or "no body")
            end
        else
            warn("[WEBHOOK] ✗ Failed to send webhook!")
            warn("[WEBHOOK] Error:", tostring(result))
        end
    end)
end

-- Check if we can teleport (avoid "previous teleport in progress" error)
local function canTeleport()
    local timeSinceLastTeleport = tick() - lastTeleportTime
    return timeSinceLastTeleport > TELEPORT_TIMEOUT
end

-- Reset teleport state on failure
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    if player == Players.LocalPlayer then
        warn(string.format("[HOP] Teleport failed: %s - %s", tostring(teleportResult), tostring(errorMessage)))
        lastTeleportTime = 0 -- Allow immediate retry
    end
end)

-- Server hop function - prioritizes older servers, ignores new ones
local function serverHop()
    if not canTeleport() then
        local remaining = TELEPORT_TIMEOUT - (tick() - lastTeleportTime)
        print(string.format("[HOP] Waiting %.1f seconds for previous teleport to clear...", remaining))
        return
    end
    
    local success, servers = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet('https://games.roblox.com/v1/games/' .. PLACE_ID .. '/servers/Public?sortOrder=Desc&limit=100')
        )
    end)
    
    if not success or not servers or not servers.data then
        warn("[HOP] Failed to fetch servers")
        return
    end
    
    -- Filter and sort servers by age/uptime
    local validServers = {}
    local currentTime = os.time()
    
    for _, server in ipairs(servers.data) do
        local jid = tostring(server.id)
        local playerCount = tonumber(server.playing)
        local maxPlayers = tonumber(server.maxPlayers)
        
        -- Skip if already visited, current server, or full
        if not file[jid] and jid ~= game.JobId and playerCount < maxPlayers then
            -- Calculate server age (servers with more players are usually older)
            -- Also check if server has been up for a while
            local serverScore = playerCount -- Higher player count = likely older server
            
            table.insert(validServers, {
                id = jid,
                playing = playerCount,
                maxPlayers = maxPlayers,
                score = serverScore
            })
        end
    end
    
    -- Sort by score (higher = older/better servers first)
    table.sort(validServers, function(a, b)
        return a.score > b.score
    end)
    
    print(string.format("[HOP] Found %d valid servers to check", #validServers))
    
    -- Try servers in order of priority
    for i, server in ipairs(validServers) do
        -- Skip very new servers based on MIN_PLAYERS_TO_JOIN setting
        if server.playing >= MIN_PLAYERS_TO_JOIN then
            print(string.format("[HOP] [%d/%d] Attempting server with %d/%d players (Score: %d)", 
                i, #validServers, server.playing, server.maxPlayers, server.score))
            
            -- Mark as visited BEFORE teleporting
            file[server.id] = os.time()
            savehist()
            
            -- Set teleport time
            lastTeleportTime = tick()
            
            -- Attempt teleport
            print(string.format("[HOP] Teleporting to: %s", server.id))
            local teleportSuccess = pcall(function()
                TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, Players.LocalPlayer)
            end)
            
            if teleportSuccess then
                -- Wait for teleport to complete or timeout
                return
            else
                warn("[HOP] Teleport call failed, trying next server...")
                lastTeleportTime = 0
            end
        else
            print(string.format("[HOP] Skipping new server with only %d players", server.playing))
        end
    end
    
    print("[HOP] No suitable servers found, will retry...")
end

-- Check for sprouts
local function getspr()
    local s = Workspace:FindFirstChild("Sprouts")
    if not s then 
        print("[DEBUG] Sprouts folder not found in Workspace")
        return 
    end
    
    print("[DEBUG] Sprouts folder found, checking children...")
    local childCount = 0
    for _, sprout in ipairs(s:GetChildren()) do
        childCount = childCount + 1
        print(string.format("[DEBUG] Child %d: %s (ClassName: %s)", childCount, sprout.Name, sprout.ClassName))
        if sprout:IsA("MeshPart") then
            print("[DEBUG] Found valid MeshPart sprout!")
            return sprout
        end
    end
    print(string.format("[DEBUG] Checked %d children, no MeshPart sprouts found", childCount))
end

-- Main logic
print("[HOPPER] Checking current server...")
print("[DEBUG] Workspace children:", Workspace:GetChildren())

local sprout = getspr()

if sprout then
    print("[✓] Sprout found! Sending webhook...")
    sendSproutWebhook(sprout)
    task.wait(HOP_DELAY)
else
    print("[✗] No sprouts in this server")
end

-- Start hopping loop
print("[HOP] Starting server hop cycle...")
while task.wait(3) do
    pcall(serverHop)
end