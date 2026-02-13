-- modules/sprouts.lua
local Webhook = require(script.Parent.Parent.webhook)

local Sprout = {}
Sprout.sentSprouts = {}

function Sprout.handleSprout(sprout)
    if sprout:IsA("MeshPart") then
        task.wait(0.5) -- wait for GUI
        Webhook.sendSproutWebhook(sprout, Sprout.sentSprouts)
    end
end

return Sprout
