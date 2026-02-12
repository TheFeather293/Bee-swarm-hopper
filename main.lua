<<<<<<< HEAD
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
=======
print("Hello from main.lua!")
>>>>>>> 8fc4aa623d590cb0c773fc4d55b7b2e281b11de0
