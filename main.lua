repeat task.wait() until game:IsLoaded()

print("=================================")
print("  BSS Monitor Suite v1.0")
print("  Loading from GitHub...")
print("=================================")

-- Create shared environment FIRST
if not _G.BSSMonitor then
    _G.BSSMonitor = {
        config = nil,
        utils = nil,
        modules = {}
    }
end

-- GitHub base URL
local GITHUB_BASE = "https://raw.githubusercontent.com/TheFeather293/Bee-swarm-hopper/refs/heads/main/"

-- Load function
local function loadFromGitHub(url, name)
    print(string.format("[...] Loading %s", name))
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    
    if success then
        local func, err = loadstring(result)
        if func then
            local module = func()
            print(string.format("[✓] Loaded: %s", name))
            return module
        else
            warn(string.format("[✗] Loadstring error in %s: %s", name, err))
            return nil
        end
    else
        warn(string.format("[✗] Failed to download %s: %s", name, result))
        return nil
    end
end

-- Load core modules FIRST and set them globally
print("\n--- Loading Core Modules ---")
_G.BSSMonitor.config = loadFromGitHub(GITHUB_BASE .. "config.lua", "config.lua")
_G.BSSMonitor.utils = loadFromGitHub(GITHUB_BASE .. "utils.lua", "utils.lua")

-- Verify core modules loaded
if not _G.BSSMonitor.config then
    error("Failed to load config.lua! Cannot continue.")
    return
end

if not _G.BSSMonitor.utils then
    error("Failed to load utils.lua! Cannot continue.")
    return
end

print("\n[✓] Core modules loaded successfully!")
print(string.format("    - Config webhook: %s", _G.BSSMonitor.config.WEBHOOK_URL and "SET" or "MISSING"))
print(string.format("    - Utils functions: %d", (function()
    local count = 0
    for _ in pairs(_G.BSSMonitor.utils) do count = count + 1 end
    return count
end)()))

-- Small delay to ensure _G is fully set
task.wait(0.1)

-- Load monitor modules
print("\n--- Loading Monitor Modules ---")
local monitors = {}

monitors.sprouts = loadFromGitHub(GITHUB_BASE .. "modules/sprouts.lua", "sprouts.lua")
-- Add more monitors here:
-- monitors.meteors = loadFromGitHub(GITHUB_BASE .. "modules/meteors.lua", "meteors.lua")

-- Initialize all loaded monitors
print("\n=================================")
print("  Initializing Monitors...")
print("=================================\n")

for name, monitor in pairs(monitors) do
    if monitor and type(monitor.init) == "function" then
        task.spawn(function()
            local success, err = pcall(function()
                monitor.init()
            end)
            if not success then
                warn(string.format("[✗] Failed to initialize %s: %s", name, tostring(err)))
            end
        end)
    else
        warn(string.format("[✗] Monitor '%s' has no init function!", name))
    end
end

task.wait(1) -- Give monitors time to initialize

print("\n=================================")
print("  BSS Monitor Suite Active!")
print("=================================")