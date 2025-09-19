local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

local startupTime = os.clock()
local hasValidated = false

local function startup_validator(world, deltaTime)
    if hasValidated then return end
    
    -- Only validate after 2 seconds to allow systems to initialize
    if os.clock() - startupTime < 2 then return end
    
    local systemCount = 0
    local phaseCount = 0
    
    -- Count systems
    for entity in world:query(comps.System):iter() do
        systemCount = systemCount + 1
    end
    
    -- Count phases
    for entity in world:query(comps.Phase):iter() do
        phaseCount = phaseCount + 1
    end
    
    print("=== ECS Startup Validation ===")
    print("Systems loaded:", systemCount)
    print("Phases created:", phaseCount)
    print("Startup time:", math.round((os.clock() - startupTime) * 1000), "ms")
    
    if systemCount == 0 then
        warn("WARNING: No systems loaded! ECS may not be working properly.")
    end
    
    if phaseCount == 0 then
        warn("WARNING: No phases created! ECS may not be working properly.")
    end
    
    hasValidated = true
end

return {
    run = function(world, deltaTime)
        startup_validator(world, deltaTime)
    end,
    settings = {
        phase = "Heartbeat",
        paused = false
    }
}