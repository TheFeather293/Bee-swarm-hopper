repeat task.wait() until game:IsLoaded()

print("=================================")
print("  BSS Monitor Suite v1.0")
print("=================================")

-- Load modules
local SproutMonitor = require(script.modules.sprouts))

-- Initialize all monitors
task.spawn(function()
    SproutMonitor.init()
end)

print("=================================")
print("  All monitors active!")
print("=================================")