repeat task.wait() until game:IsLoaded()
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local request = request or http_request or syn.request
local WEBHOOK_URL = "https://discord.com/api/webhooks/1471567811364257948/5rWB6p3jtZCq69RV6st5q3bXHTDdgMe9NZeK_agQVMQT_QS0KTpxRZRQvqeGbotNTCMa"

-- Configuration
local PLACE_ID = game.PlaceId
local HOP_DELAY = 1

-- Server hop state
local file = {}
local file2 = "sprout-hop/" .. Players.LocalPlayer.UserId .. ".json"
local esheposidim = false -- "we are hopping" flag
local hop = false -- "teleport in progress" flag

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
    if c >= 50 then file = {} end -- Clear after 50 servers
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
    task.spawn(function()
        local pos = sprout.Position
        local fieldName = getFieldName(pos)
        
        local brickColor = sprout.BrickColor.Name
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
        
        local pollenText = "Unknown"
        pcall(function()
            local guiLabel = sprout:FindFirstChild("GuiPos", true):FindFirstChild("Gui", true):FindFirstChild("Frame", true):FindFirstChild("TextLabel", true)
            if guiLabel then
                pollenText = guiLabel.Text
            end
        end)
        
        local playerCount = #Players:GetPlayers()
        local maxPlayers = Players.MaxPlayers
        
        local jobId = game.JobId
        local placeId = game.PlaceId
        local webLink = string.format("https://www.roblox.com/games/start?placeId=%s&launchData=%%7B%%22gameId%%22%%3A%%22%s%%22%%7D", placeId, jobId)
        local directLink = string.format("roblox://placeID=%s&gameInstanceId=%s", placeId, jobId)
        
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
        
        pcall(function()
            request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({ embeds = {embed} })
            })
        end)
    end)
end

-- Teleport to server
local function go(jid)
    if hop then return false end
    if file[jid] then return false end
    
    hop = true
    esheposidim = true
    file[jid] = os.time()
    savehist()
    
    print(string.format("[HOP] Teleporting to server: %s", jid))
    pcall(function() 
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jid, Players.LocalPlayer) 
    end)
    
    return true
end

-- Reset flags on teleport failure
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    if player == Players.LocalPlayer then
        warn(string.format("[HOP] Teleport failed: %s - %s", tostring(teleportResult), tostring(errorMessage)))
        hop = false
        esheposidim = false
    end
end)

-- Server hop function
local function serverHop()
    if esheposidim or hop then return end
    
    local success, servers = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet('https://games.roblox.com/v1/games/' .. PLACE_ID .. '/servers/Public?sortOrder=Asc&limit=100')
        )
    end)
    
    if not success or not servers or not servers.data then
        warn("[HOP] Failed to fetch servers")
        return
    end
    
    -- Try each server
    for _, server in ipairs(servers.data) do
        local jid = tostring(server.id)
        
        -- Skip if already visited or current server
        if not file[jid] and jid ~= game.JobId then
            -- Skip full servers
            if tonumber(server.playing) < tonumber(server.maxPlayers) then
                print(string.format("[HOP] Found server with %d/%d players", server.playing, server.maxPlayers))
                
                if go(jid) then
                    return
                end
            else
                print(string.format("[HOP] Skipping full server (%d/%d)", server.playing, server.maxPlayers))
            end
        end
    end
    
    print("[HOP] No new servers found in this batch")
end

-- Check for sprouts
local function getspr()
    local s = Workspace:FindFirstChild("Sprouts")
    if not s then return end
    
    for _, sprout in ipairs(s:GetChildren()) do
        if sprout:IsA("MeshPart") then
            return sprout
        end
    end
end

-- Main logic
print("[HOPPER] Checking current server...")

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
    if not esheposidim and not hop then
        pcall(serverHop)
    else
        print("[HOP] Waiting for teleport to complete...")
    end
end