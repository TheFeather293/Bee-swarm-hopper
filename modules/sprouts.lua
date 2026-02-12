local Workspace = game:GetService("Workspace")

-- Access shared modules from global
local config = _G.BSSMonitor.config
local utils = _G.BSSMonitor.utils

local SproutMonitor = {}
SproutMonitor.sentSprouts = {}

function SproutMonitor.getSproutType(brickColor)
    if brickColor == "Light grey metallic" then
        return "Rare", 0x5865F2, "🌟"
    elseif brickColor == "Sage green" then
        return "Normal", 0x57F287, "🌱"
    elseif brickColor == "CGA brown" then
        return "Epic", 0xFEE75C, "🔥"
    elseif brickColor == "Alder" then
        return "Gummy", 0xE91E63, "🍬"
    elseif brickColor == "Medium blue" then
        return "Moon", 0x00BFFF, "🌙"
    else
        return "Unknown", 0x99AAB5, "🌱"
    end
end

function SproutMonitor.sendSproutWebhook(sprout)
    if SproutMonitor.sentSprouts[sprout] then return end
    SproutMonitor.sentSprouts[sprout] = true
    
    local pos = sprout.Position
    local fieldName = utils.getFieldName(pos)
    local sproutType, embedColor, emoji = SproutMonitor.getSproutType(sprout.BrickColor.Name)
    
    -- Get pollen
    local pollenText = "Unknown"
    local success, guiLabel = pcall(function()
        return sprout:WaitForChild("GuiPos", 3):WaitForChild("Gui"):WaitForChild("Frame"):WaitForChild("TextLabel")
    end)
    if success and guiLabel then
        pollenText = guiLabel.Text
    end
    
    local serverInfo = utils.getServerInfo()
    local links = utils.createJoinLinks(serverInfo.placeId, serverInfo.jobId)
    local thumbnailUrl = config.fieldThumbnails[fieldName]
    
    local embed = {
        title = string.format("%s %s Sprout Detected!", emoji, sproutType),
        color = embedColor,
        fields = {
            {
                name = "📍 Position",
                value = string.format("```%.2f, %.2f, %.2f```", pos.X, pos.Y, pos.Z),
                inline = false
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
                value = string.format("```%d/%d```", serverInfo.playerCount, serverInfo.maxPlayers),
                inline = false
            },
            {
                name = "🔗 Join Server",
                value = string.format("**[Click Here to Join](%s)**\n```%s```", links.web, links.direct),
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
    
    utils.sendWebhook(config.WEBHOOK_URL, { embeds = {embed} })
    print("[SPROUT] Detected:", sproutType, "in", fieldName)
end

function SproutMonitor.init()
    local sproutsFolder = Workspace:WaitForChild("Sprouts")
    
    -- Check existing sprouts
    for _, sprout in pairs(sproutsFolder:GetChildren()) do
        if sprout:IsA("MeshPart") then
            task.spawn(function()
                SproutMonitor.sendSproutWebhook(sprout)
            end)
        end
    end
    
    -- Listen for new sprouts
    sproutsFolder.ChildAdded:Connect(function(sprout)
        if sprout:IsA("MeshPart") then
            task.wait(0.5)
            SproutMonitor.sendSproutWebhook(sprout)
        end
    end)
    
    -- Cleanup
    sproutsFolder.ChildRemoved:Connect(function(sprout)
        SproutMonitor.sentSprouts[sprout] = nil
    end)
    
    print("[SPROUT MONITOR] Initialized ✓")
end

return SproutMonitor