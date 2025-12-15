--!strict
--[[
    NPC Wander System (ECS)

    Replaces behavior tree wander with Perlin noise-based natural movement.

    Handles:
    - Perlin noise direction generation
    - Weighting toward spawn point when too far
    - Smooth movement interpolation
    - Only active when NPC has no target

    Runs at 8 Hz for performance
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)

-- Query NPCs that should wander (no target)
local query = world:query(
    comps.Character,
    comps.Transform,
    comps.NPCWander,
    comps.Locomotion
):with(comps.CombatNPC):without(comps.NPCTarget):cached()

-- Throttle to 10 Hz (IMPROVED: was 8 Hz / 0.125s)
local lastUpdate = 0
local UPDATE_INTERVAL = 0.1

-- Simplified Perlin noise function (matches behavior tree noise generator)
local function noise(x: number, y: number): number
    -- Hash function
    local n = math.floor(x) + math.floor(y) * 57
    n = bit32.bxor(n, bit32.lshift(n, 13))
    local result = bit32.band(n * (n * n * 15731 + 789221) + 1376312589, 0x7fffffff)
    return 1.0 - result / 1073741824.0
end

-- Main system function
local hasLoggedWander = false

local function updateWander(dt: number)
    local now = os.clock()
    if now - lastUpdate < UPDATE_INTERVAL then
        return
    end
    lastUpdate = now

    for entity, char, transform, wander, loco in query do
        -- Debug: Verify this NPC doesn't have a target
        if not hasLoggedWander then
            local hasTarget = world:has(entity, comps.NPCTarget)
           -- print(`[npc_wander_ecs] Processing {char.Name} - has NPCTarget: {hasTarget}`)
            hasLoggedWander = true
        end

        -- Check if NPC is stunned - stop wandering if stunned
        if StateManager.StateCount(char, "Stuns") then
            world:set(entity, comps.Locomotion, {
                dir = Vector3.zero,
                speed = 0,
            })
            continue
        end

        local currentPos = transform.new.Position
        local wanderCenter = wander.center -- Use wander center, not spawn position

        -- Initialize pause state if needed
        if not wander.isPaused then
            wander.isPaused = false
            wander.pauseEndTime = 0
            wander.moveEndTime = now + math.random(5, 10) -- Move for 5-10 seconds
        end

        -- Handle pause/move cycle
        if wander.isPaused then
            -- Currently paused - check if pause is over
            if now >= wander.pauseEndTime then
                -- End pause, start moving
                wander.isPaused = false
                wander.moveEndTime = now + math.random(5, 10) -- Move for 5-10 seconds
            else
                -- Still paused - stay idle
                world:set(entity, comps.Locomotion, {
                    dir = Vector3.zero,
                    speed = 0,
                })
                world:set(entity, comps.NPCWander, wander)
                continue
            end
        else
            -- Currently moving - check if should pause
            if now >= wander.moveEndTime then
                -- Start pause
                wander.isPaused = true
                wander.pauseEndTime = now + math.random(3, 7) -- Pause for 3-7 seconds
                world:set(entity, comps.Locomotion, {
                    dir = Vector3.zero,
                    speed = 0,
                })
                world:set(entity, comps.NPCWander, wander)
                continue
            end
        end

        -- Generate Perlin noise direction (matches behavior tree SwayX/SwayY)
        local time = now + wander.noiseOffset
        local swayX = noise(time * 0.5, 0)
        local swayY = noise(0, time * 0.5)

        -- Create movement vector from noise
        local direction = Vector3.new(swayX, 0, swayY)

        -- Calculate distance from wander center
        local distanceFromCenter = (currentPos - wanderCenter).Magnitude
        local maxDistance = wander.radius or 30

        -- Weight toward center if too far (matches behavior tree wander.lua logic)
        if distanceFromCenter > maxDistance then
            local toCenter = (wanderCenter - currentPos).Unit
            local weight = math.clamp(distanceFromCenter / maxDistance, 0, 1)
            direction = direction:Lerp(toCenter, weight)
        end

        -- Normalize direction
        if direction.Magnitude > 0.01 then
            direction = direction.Unit
        else
            direction = Vector3.zero
        end

        -- Smooth interpolation (matches behavior tree smoothingAlpha)
        local smoothingAlpha = 0.5
        local smoothed = wander.currentDirection:Lerp(direction, smoothingAlpha)

        -- Update wander state
        wander.currentDirection = smoothed
        world:set(entity, comps.NPCWander, wander)

        -- Update locomotion (slow wander speed)
        world:set(entity, comps.Locomotion, {
            dir = smoothed,
            speed = 8, -- Slow wander speed (matches behavior tree idle speed)
        })
    end
end

return {
    run = function(world: Jecs.World, dt: number)
        updateWander(dt)
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}
