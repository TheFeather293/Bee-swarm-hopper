-- webhook.lua
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local config = require(script.Parent.config)
local Utils = require(script.Parent.utils)

local Webhook = {}

function Webhook.sendSproutWebhook(sprout, sentSprouts)
    if sentSprouts[sprout] then return end
    sentSprouts[sprout] = true

    local pos = sprout.Position
    local sproutName = sprout.Name
    local fieldName = Utils.getFieldName(pos)
    local brickColor = sprout.BrickColor.Name

    -- Determine sprout type & embed color
    local sproutType, embedColor, emoji
    if brickColor == "Light grey metallic" then
        sproutType, embedColor, emoji = "Rare", 0x5865F2, "🌟"
    elseif brickColor == "Sage green" then
        sproutType, embedColor, emoji = "Normal", 0x57F287, "🌱"
    elseif brickColor == "CGA brown" then
        sproutType, embedColor, emoji = "Epic", 0xFEE75C, "🔥"
    elseif brickColor == "Alder" then
        sproutType, embedColor, emoji = "Gummy", 0xE91E63, "🍬"
    elseif brickColor == "Medium blue" then
        sproutType, embedColor, emoji = "Moon", 0x00BFFF, "🌙"
    else
        sproutType, embedColor, emoji = "Unknown", 0x99AAB5, "🌱"
    end

    -- Pollen left
    local pollenText = "Unknown"
    local success, guiLabel = pcall(function()
        return sprout:WaitForChild("GuiPos",3):WaitForChild("Gui"):WaitForChild("Frame"):WaitForChild("TextLabel")
    end)
    if success and guiLabel then
        pollenText = guiLabel.Text
    end

    -- Players info
    local playerCount = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers

    -- Game links
    local jobId = game.JobId
    local placeId = game.PlaceId
    local webLink = string.format("https://www.roblox.com/games/start?placeId=%s&launchData=%%7B%%22gameId%%22%%3A%%22%s%%22%%7D", placeId, jobId)
    local directLink = string.format("roblox://placeID=%s&gameInstanceId=%s", placeId, jobId)

    -- Build embed
    local embed = {
        title = string.format("%s %s Sprout Detected!", emoji, sproutType),
        color = embedColor,
        fields = {
            {name="📍 Position", value=string.format("```%.2f, %.2f, %.2f```", pos.X,pos.Y,pos.Z), inline=false},
            {name="🌸 Pollen Left", value=string.format("```%s```", pollenText), inline=true},
            {name="🌾 Field", value=string.format("```%s```", fieldName), inline=true},
            {name="😳 Players", value=string.format("```%d/%d```", playerCount, maxPlayers), inline=false},
            {name="🔗 Join Server", value=string.format("**[Click Here to Join](%s)**\n```%s```", webLink,directLink), inline=false}
        },
        footer = {text="Sprout Tracker • "..os.date("%I:%M %p")},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S")
    }

    -- Add thumbnail if exists
    local thumbnailUrl = config.FIELD_THUMBNAILS[fieldName]
    if thumbnailUrl then
        embed.thumbnail = {url=thumbnailUrl}
    end

    -- Send webhook
    local request = request or http_request or syn.request
    request({
        Url = config.WEBHOOK_URL,
        Method = "POST",
        Headers = {["Content-Type"]="application/json"},
        Body = HttpService:JSONEncode({embeds={embed}})
    })
end

return Webhook
