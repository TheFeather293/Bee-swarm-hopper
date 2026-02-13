repeat task.wait() until game:IsLoaded()
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local request = request or http_request or syn.request
local WEBHOOK_URL = "https://discord.com/api/webhooks/1471567811364257948/5rWB6p3jtZCq69RV6st5q3bXHTDdgMe9NZeK_agQVMQT_QS0KTpxRZRQvqeGbotNTCMa"

-- Configuration
local PLACE_ID = game.PlaceId
local HOP_DELAY = 2 -- Seconds to wait before hopping (gives time for webhook to send)

-- Field thumbnail mapping (using exact field names from FlowerZones)
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

-- Function to server hop
local function serverHop()
    print("[HOP] Searching for new server...")
    
    local success, result = pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
        
        if servers and servers.data then
            -- Filter out current server and full servers
            local availableServers = {}
            for _, server in pairs(servers.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    table.insert(availableServers, server)
                end
            end
            
            if #availableServers > 0 then
                -- Pick random server
                local randomServer = availableServers[math.random(1, #availableServers)]
                print(string.format("[HOP] Found server with %d/%d players", randomServer.playing, randomServer.maxPlayers))
                
                TeleportService:TeleportToPlaceInstance(PLACE_ID, randomServer.id, Players.LocalPlayer)
            else
                print("[HOP] No available servers, trying again...")
                task.wait(2)
                TeleportService:Teleport(PLACE_ID, Players.LocalPlayer)
            end
        end
    end)
    
    if not success then
        warn("[HOP] Failed to hop:", result)
        task.wait(2)
        TeleportService:Teleport(PLACE_ID, Players.LocalPlayer)
    end
end

-- Function to send webhook for a sprout
local function sendSproutWebhook(sprout)
    local pos = sprout.Position
    local sproutName = sprout.Name
    local fieldName = getFieldName(pos)
    
    -- Rare / Normal / Epic / Gummy / Moon / Legendary detection
    local brickColor = sprout.BrickColor.Name
    local sproutType
    local embedColor
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
    
    -- Grab pollen left from GUI
    local pollenText = "Unknown"
    local success, guiLabel = pcall(function()
        return sprout:WaitForChild("GuiPos", 1):WaitForChild("Gui"):WaitForChild("Frame"):WaitForChild("TextLabel")
    end)
    if success and guiLabel then
        pollenText = guiLabel.Text
    end
    
    -- Players in server
    local playerCount = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    
    -- Join links
    local jobId = game.JobId
    local placeId = game.PlaceId
    local webLink = string.format("https://www.roblox.com/games/start?placeId=%s&launchData=%%7B%%22gameId%%22%%3A%%22%s%%22%%7D", placeId, jobId)
    local directLink = string.format("roblox://placeID=%s&gameInstanceId=%s", placeId, jobId)
    
    -- Emoji based on sprout type
    local emoji
    if sproutType == "Rare" then
        emoji = "🌟"
    elseif sproutType == "Epic" then
        emoji = "🔥"
    elseif sproutType == "Gummy" then
        emoji = "🍬"
    elseif sproutType == "Moon" then
        emoji = "🌙"
    elseif sproutType == "Legendary" then
        emoji = "⚡"
    elseif sproutType == "Supreme" then
        emoji = "👑"
    else
        emoji = "🌱"
    end
    
    local thumbnailUrl = fieldThumbnails[fieldName]
    
    print(string.format("[SPROUT FOUND] %s %s in %s", emoji, sproutType, fieldName))
    
    -- Build embed
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
            text = "Sprout Tracker • " .. os.date("%I:%M %p")
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S")
    }
    
    if thumbnailUrl then
        embed.thumbnail = { url = thumbnailUrl }
    end
    
    -- Send webhook
    request({
        Url = WEBHOOK_URL,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({
            embeds = {embed}
        })
    })
end

-- Main logic
print("=================================")
print("  Sprout Server Hopper")
print("  Checking current server...")
print("=================================")

local sproutsFolder = Workspace:WaitForChild("Sprouts", 5)

if sproutsFolder then
    local foundSprout = false
    
    -- Check for existing sprouts
    for _, sprout in pairs(sproutsFolder:GetChildren()) do
        if sprout:IsA("MeshPart") then
            foundSprout = true
            print("[✓] Sprout found! Sending webhook...")
            sendSproutWebhook(sprout)
            break -- Only send webhook for first sprout found
        end
    end
    
    if foundSprout then
        print(string.format("[HOP] Webhook sent! Hopping in %d seconds...", HOP_DELAY))
        task.wait(HOP_DELAY)
    else
        print("[✗] No sprouts in this server")
    end
else
    print("[✗] Sprouts folder not found")
end

-- Hop to next server
serverHop()