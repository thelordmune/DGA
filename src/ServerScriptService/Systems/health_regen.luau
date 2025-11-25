--!strict
--[[
    Health Regeneration System
    
    Provides passive health regeneration for all entities with Health component.
    Regeneration rate is faster when out of combat.
    
    Regeneration Rates:
    - Out of Combat: 2 HP per second
    - In Combat: 0.5 HP per second
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

-- Regeneration rates (HP per second)
local REGEN_OUT_OF_COMBAT = 2
local REGEN_IN_COMBAT = 0.5

-- Accumulator for fractional health
local healthAccumulators = {}

local function health_regen(_world, dt: number)
    -- Only run on server
    if RunService:IsClient() then
        return
    end

    -- Query all entities with Health component that are fully initialized
    for entity, health in world:query(comps.Health):with(comps.ComponentsReady) do
        -- Skip if health is already at max
        if health.current >= health.max then
            continue
        end
        
        -- Check if entity is in combat
        local inCombat = world:get(entity, comps.InCombat)
        local isInCombat = inCombat and inCombat.value or false
        
        -- Determine regeneration rate
        local regenRate = isInCombat and REGEN_IN_COMBAT or REGEN_OUT_OF_COMBAT
        
        -- Calculate health to add this frame
        local healthToAdd = regenRate * dt
        
        -- Initialize accumulator if needed
        if not healthAccumulators[entity] then
            healthAccumulators[entity] = 0
        end
        
        -- Add to accumulator
        healthAccumulators[entity] = healthAccumulators[entity] + healthToAdd
        
        -- Only apply when we have at least 1 HP to add
        if healthAccumulators[entity] >= 1 then
            local wholeHealth = math.floor(healthAccumulators[entity])
            healthAccumulators[entity] = healthAccumulators[entity] - wholeHealth
            
            -- Add health (clamped to max)
            local newHealth = math.min(health.current + wholeHealth, health.max)
            health.current = newHealth
            
            -- Update the component
            world:set(entity, comps.Health, health)
            
            -- Update character's Humanoid if it exists
            local character = world:get(entity, comps.Character)
            if character and character:FindFirstChild("Humanoid") then
                local humanoid = character.Humanoid :: Humanoid
                humanoid.Health = newHealth
            end
        end
    end
end

return {
    run = health_regen,
    settings = {
        server_only = true,
        phase = "Heartbeat",
    }
}

