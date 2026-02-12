local HttpService = game:GetService("HttpService")
local request = request or http_request or syn.request

local utils = {}

function utils.sendWebhook(webhookUrl, data)
    local success, err = pcall(function()
        request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
    
    if not success then
        warn("Webhook failed:", err)
    end
    
    return success
end

function utils.getFieldName(pos)
    local Workspace = game:GetService("Workspace")
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

function utils.getServerInfo()
    local Players = game:GetService("Players")
    return {
        playerCount = #Players:GetPlayers(),
        maxPlayers = Players.MaxPlayers,
        jobId = game.JobId,
        placeId = game.PlaceId
    }
end

function utils.createJoinLinks(placeId, jobId)
    return {
        web = string.format("https://www.roblox.com/games/start?placeId=%s&launchData=%%7B%%22gameId%%22%%3A%%22%s%%22%%7D", placeId, jobId),
        direct = string.format("roblox://placeID=%s&gameInstanceId=%s", placeId, jobId)
    }
end

return utils