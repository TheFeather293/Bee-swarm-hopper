repeat task.wait() until game:IsLoaded()

print("=================================")
print("  BSS Monitor Suite v1.0")
print("  Loading from GitHub...")
print("=================================")

-- Create shared environment
_G.BSSMonitor = _G.BSSMonitor or {}

-- GitHub base URL
local GITHUB_BASE = "https://raw.githubusercontent.com/TheFeather293/Bee-swarm-hopper/refs/heads/main/"

-- Load function
local function loadFromGitHub(url, name)
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    
    if success then
        print("[✓] Loaded:", name)
        local func, err = loadstring(result)
        if func then
            return func()
        else
            warn("[✗] Loadstring error in", name, ":", err)
            return nil
        end
    else
        warn("[✗] Failed to download:", name, "-", result)
        return nil
    end
end

-- Load core modules first (order matters!)
print("\nLoading core modules...")
_G.BSSMonitor.config = loadFromGitHub(GITHUB_BASE .. "config.lua", "config.lua")
_G.BSSMonitor.utils = loadFromGitHub(GITHUB_BASE .. "utils.lua", "utils.lua")

-- Check if core modules loaded
if not _G.BSSMonitor.config or not _G.BSSMonitor.utils then
    error("Failed to load core modules! Cannot continue.")
    return
end

-- Load monitor modules
print("\nLoading monitors...")
local monitors = {}

monitors.sprouts = loadFromGitHub(GITHUB_BASE .. "modules/sprouts.lua", "sprouts.lua")
-- Add more monitors here as you create them:
-- monitors.meteors = loadFromGitHub(GITHUB_BASE .. "modules/meteors.lua", "meteors.lua")
-- monitors.bosses = loadFromGitHub(GITHUB_BASE .. "modules/bosses.lua", "bosses.lua")

-- Initialize all loaded monitors
print("\n=================================")
print("  Initializing monitors...")
print("=================================\n")

for name, monitor in pairs(monitors) do
    if monitor and monitor.init then
        task.spawn(function()
            local success, err = pcall(function()
                monitor.init()
            end)
            if not success then
                warn(string.format("[✗] Failed to initialize %s: %s", name, err))
            end
        end)
    end
end

print("\n=================================")
print("  All monitors active!")
print("=================================")