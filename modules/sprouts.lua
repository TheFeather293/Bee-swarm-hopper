-- modules/sprout.lua
local Webhook = require(game.ServerScriptService.webhook)

local Sprout = {}
Sprout.sentSprouts = {}

function Sprout.handleSprout(sprout)
    if sprout:IsA("MeshPart") then
        task.wait(0.5) -- wait for GUI
        Webhook.sendSproutWebhook(sprout, Sprout.sentSprouts)
    end
end

return Sprout
