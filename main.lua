local Sprout = require(script.modules.sprouts)
local Workspace = game:GetService("Workspace")

-- Wait for Sprouts folder
local sproutsFolder = Workspace:WaitForChild("Sprouts")

-- Handle existing sprouts
for _, sprout in pairs(sproutsFolder:GetChildren()) do
    Sprout.handleSprout(sprout)
end

-- Listen for new sprouts
sproutsFolder.ChildAdded:Connect(function(sprout)
    Sprout.handleSprout(sprout)
end)

-- Clean up when removed
sproutsFolder.ChildRemoved:Connect(function(sprout)
    Sprout.sentSprouts[sprout] = nil
end)

print("Sprout tracker initialized! Monitoring all sprouts...")
