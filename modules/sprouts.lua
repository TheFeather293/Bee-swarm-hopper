-- modules/sprouts.lua
local webhookModule = game.ServerScriptService:WaitForChild("webhook")
local Webhook = require(webhookModule)

local Sprout = {}
Sprout.sentSprouts = {}

function Sprout.handleSprout(sprout)
    if sprout:IsA("MeshPart") then
        task.wait(0.5) -- wait for GUI
        Webhook.sendSproutWebhook(sprout, Sprout.sentSprouts)
    end
end

return Sprout
