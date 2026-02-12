local Workspace = game:GetService("Workspace")

-- Wait for global to be ready
local maxWait = 5
local waited = 0
while (not _G.BSSMonitor or not _G.BSSMonitor.config or not _G.BSSMonitor.utils) and waited < maxWait do
    task.wait(0.1)
    waited = waited + 0.1
end

-- Verify we have what we need
if not _G.BSSMonitor then
    error("_G.BSSMonitor is not defined!")
end

if not _G.BSSMonitor.config then
    error("_G.BSSMonitor.config is not loaded!")
end

if not _G.BSSMonitor.utils then
    error("_G.BSSMonitor.utils is not loaded!")
end

-- Access shared modules from global
local config = _G.BSSMonitor.config
local utils = _G.BSSMonitor.utils

-- Debug: Verify we can access functions
print("[SPROUT DEBUG] Config webhook:", config.WEBHOOK_URL and "FOUND" or "MISSING")
print("[SPROUT DEBUG] Utils.sendWebhook:", type(utils.sendWebhook))
print("[SPROUT DEBUG] Utils.getFieldName:", type(utils.getFieldName))

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
    
    -- Debug
    print("[SPROUT] Processing sprout:", sprout.Name)
    
    local pos = sprout.Position
    local fieldName = utils.getFieldName(pos)
    local sproutType, embedColor, emoji = SproutMonitor.getSproutType(sprout.BrickColor.Name)
    
    print("[SPROUT] Field detected:", fieldName)
    print("[SPROUT] Type detected:", sproutType)
    
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
    
    print("[SPROUT] Thumbnail URL:", thumbnailUrl or "NOT FOUND")
    
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
    
    local webhookSuccess = utils.sendWebhook(config.WEBHOOK_URL, { embeds = {embed} })
    
    if webhookSuccess then
        print(string.format("[SPROUT] ✓ Webhook sent: %s %s in %s", emoji, sproutType, fieldName))
    else
        warn(string.format("[SPROUT] ✗ Webhook failed: %s %s in %s", emoji, sproutType, fieldName))
    end
end

function SproutMonitor.init()
    print("[SPROUT MONITOR] Starting initialization...")
    
    local sproutsFolder = Workspace:WaitForChild("Sprouts")
    print("[SPROUT MONITOR] Found Sprouts folder")
    
    -- Check existing sprouts
    local existingSprouts = 0
    for _, sprout in pairs(sproutsFolder:GetChildren()) do
        if sprout:IsA("MeshPart") then
            existingSprouts = existingSprouts + 1
            task.spawn(function()
                SproutMonitor.sendSproutWebhook(sprout)
            end)
        end
    end
    
    print(string.format("[SPROUT MONITOR] Found %d existing sprout(s)", existingSprouts))
    
    -- Listen for new sprouts
    sproutsFolder.ChildAdded:Connect(function(sprout)
        if sprout:IsA("MeshPart") then
            print("[SPROUT MONITOR] New sprout detected!")
            task.wait(0.5)
            SproutMonitor.sendSproutWebhook(sprout)
        end
    end)
    
    -- Cleanup
    sproutsFolder.ChildRemoved:Connect(function(sprout)
        SproutMonitor.sentSprouts[sprout] = nil
    end)
    
    print("[SPROUT MONITOR] ✓ Initialized and monitoring")
end

return SproutMonitor