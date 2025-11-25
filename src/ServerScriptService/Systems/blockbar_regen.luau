--!strict
--[[
    BlockBar Regeneration System
    
    Provides passive BlockBar regeneration for all entities with BlockBar component.
    BlockBar regenerates when not being hit while blocking.
    
    How it works:
    - BlockBar starts at 0 and increases when hit while blocking
    - When BlockBar reaches 100, the block is broken
    - BBRegen component is set to {value = true, duration = 2} when hit while blocking
    - After 2 seconds of not being hit, BlockBar starts regenerating back to 0
    - Regeneration rate: 20 per second (takes 5 seconds to fully regenerate from 100 to 0)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

-- Regeneration rate (BlockBar points per second)
local REGEN_RATE = 20  -- Takes 5 seconds to regenerate from 100 to 0

-- Accumulator for fractional blockbar
local blockBarAccumulators = {}

local function blockbar_regen(dt: number)
    -- Only run on server
    if RunService:IsClient() then
        return
    end

    -- Query all entities with BlockBar component that are fully initialized
    for entity, blockBar in world:query(comps.BlockBar):with(comps.ComponentsReady) do
        -- Skip if BlockBar is already at 0 (fully regenerated)
        if blockBar.Value <= 0 then
            continue
        end
        
        -- Check if BBRegen is active
        local bbRegen = world:get(entity, comps.BBRegen)
        if not bbRegen or not bbRegen.value then
            continue
        end
        
        -- BBRegen has a duration - only regenerate after the duration expires
        -- This prevents regeneration immediately after being hit
        if bbRegen.duration > 0 then
            continue
        end
        
        -- Calculate BlockBar to remove this frame
        local blockBarToRemove = REGEN_RATE * dt
        
        -- Initialize accumulator if needed
        if not blockBarAccumulators[entity] then
            blockBarAccumulators[entity] = 0
        end
        
        -- Add to accumulator
        blockBarAccumulators[entity] = blockBarAccumulators[entity] + blockBarToRemove
        
        -- Only apply when we have at least 1 point to remove
        if blockBarAccumulators[entity] >= 1 then
            local wholeBlockBar = math.floor(blockBarAccumulators[entity])
            blockBarAccumulators[entity] = blockBarAccumulators[entity] - wholeBlockBar
            
            -- Remove BlockBar (clamped to 0)
            local newValue = math.max(0, blockBar.Value - wholeBlockBar)
            blockBar.Value = newValue
            
            -- Update the component
            world:set(entity, comps.BlockBar, blockBar)
            
            -- If fully regenerated, disable BBRegen
            if newValue <= 0 then
                world:set(entity, comps.BBRegen, {value = false, duration = 0})
            end
        end
    end
end

return {
    run = blockbar_regen,
    settings = {
        server_only = true,
        phase = "Heartbeat",
    }
}

