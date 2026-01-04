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

-- Query combat NPCs that should wander (no target)
local combatQuery = world:query(
    comps.Character,
    comps.Transform,
    comps.NPCWander,
    comps.Locomotion
):with(comps.CombatNPC):without(comps.NPCTarget):cached()

-- Query wanderer NPCs (non-combat citizens)
local wandererQuery = world:query(
    comps.Character,
    comps.Transform,
    comps.NPCWander,
    comps.Locomotion
):with(comps.WandererNPC):cached()

-- Throttle to 2 Hz for better performance (was 10 Hz / 0.1s)
local lastUpdate = 0
local UPDATE_INTERVAL = 0.5

-- Generate a random direction on the XZ plane
local function randomDirection(): Vector3
    local angle = math.random() * math.pi * 2
    return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

-- Process a single NPC's wander behavior
local function processWander(entity, char, transform, wander, now: number, isWanderer: boolean)
    -- Check if NPC is stunned - stop wandering if stunned
    if StateManager.StateCount(char, "Stuns") then
        world:set(entity, comps.Locomotion, {
            dir = Vector3.zero,
            speed = 0,
        })
        return
    end

    -- Skip if wanderer is paused due to player proximity
    if world:has(entity, comps.NPCProximity) then
        local proximity = world:get(entity, comps.NPCProximity)
        if proximity and proximity.isWanderPaused then
            return -- Proximity system handles this NPC
        end
    end

    -- Skip if wanderer is fleeing
    if world:has(entity, comps.NPCFlee) then
        local flee = world:get(entity, comps.NPCFlee)
        if flee and flee.isFleeing then
            return -- Flee system handles this NPC
        end
    end

    local currentPos = transform.new.Position

    -- Initialize wander state if needed
    if not wander.targetDirection then
        wander.targetDirection = randomDirection()
        wander.directionChangeTime = now + math.random(20, 40) -- Change direction every 20-40 seconds (was 8-20)
        wander.isPaused = false
        wander.pauseEndTime = 0
        wander.moveEndTime = now + math.random(15, 35) -- Move for 15-35 seconds (was 10-25)
    end

    -- Handle pause/move cycle
    if wander.isPaused then
        -- Currently paused - check if pause is over
        if now >= wander.pauseEndTime then
            -- End pause, start moving with new random direction
            wander.isPaused = false
            wander.targetDirection = randomDirection()
            wander.directionChangeTime = now + math.random(20, 40) -- (was 8-20)
            wander.moveEndTime = now + math.random(15, 35) -- (was 10-25)
        else
            -- Still paused - stay idle
            world:set(entity, comps.Locomotion, {
                dir = Vector3.zero,
                speed = 0,
            })
            world:set(entity, comps.NPCWander, wander)
            return
        end
    else
        -- Currently moving - check if should pause
        if now >= wander.moveEndTime then
            -- Start pause
            wander.isPaused = true
            wander.pauseEndTime = now + math.random(8, 20) -- Pause for 8-20 seconds (was 3-8)
            world:set(entity, comps.Locomotion, {
                dir = Vector3.zero,
                speed = 0,
            })
            world:set(entity, comps.NPCWander, wander)
            return
        end

        -- Check if should change direction (random turns while walking)
        if now >= wander.directionChangeTime then
            -- Pick a new random direction (with some bias toward current direction for natural movement)
            local newDir = randomDirection()
            -- 70% chance to turn slightly, 30% chance to turn completely
            if math.random() < 0.7 then
                wander.targetDirection = wander.targetDirection:Lerp(newDir, 0.3 + math.random() * 0.4)
            else
                wander.targetDirection = newDir
            end
            wander.directionChangeTime = now + math.random(15, 30) -- (was 5-15)
        end
    end

    -- Use the target direction
    local direction = wander.targetDirection

    -- Wanderers can roam freely - only redirect if they hit map boundaries
    -- Check if too far from spawn (use large radius for free roaming)
    local wanderCenter = wander.center
    local distanceFromCenter = (currentPos - wanderCenter).Magnitude
    local maxDistance = isWanderer and 150 or (wander.radius or 30) -- Wanderers can go 150 studs

    -- Only redirect toward center if very far out
    if distanceFromCenter > maxDistance then
        local toCenter = (wanderCenter - currentPos).Unit
        local weight = math.clamp((distanceFromCenter - maxDistance) / 50, 0, 1)
        direction = direction:Lerp(toCenter, weight)
        wander.targetDirection = direction -- Update target so they don't fight the correction
    end

    -- Normalize direction
    if direction.Magnitude > 0.01 then
        direction = direction.Unit
    else
        direction = Vector3.zero
    end

    -- Smooth interpolation for natural movement
    local smoothingAlpha = 0.15 -- Slower lerp for smoother turns
    local smoothed = wander.currentDirection:Lerp(direction, smoothingAlpha)

    -- Update wander state
    wander.currentDirection = smoothed
    world:set(entity, comps.NPCWander, wander)

    -- Update locomotion (wanderers move slower than combat NPCs)
    local wanderSpeed = isWanderer and 8 or 8
    world:set(entity, comps.Locomotion, {
        dir = smoothed,
        speed = wanderSpeed,
    })
end

-- Main system function
local function updateWander()
    local now = os.clock()
    if now - lastUpdate < UPDATE_INTERVAL then
        return
    end
    lastUpdate = now

    -- Process combat NPCs
    for entity, char, transform, wander, _loco in combatQuery do
        processWander(entity, char, transform, wander, now, false)
    end

    -- Process wanderer NPCs (non-combat citizens)
    for entity, char, transform, wander, _loco in wandererQuery do
        processWander(entity, char, transform, wander, now, true)
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
