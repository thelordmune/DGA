--!strict
--[[
    Mob Avoidance System (ECS) for Ironveil
    
    Prevents combat NPCs from overlapping each other using separation steering.
    Adapted from RPGJECS mob_avoid.luau
    
    Features:
    - Separation steering to push NPCs apart when too close
    - Only affects combat NPCs (filters via CombatNPC component)
    - Runs at 10 Hz for performance
    - Uses Size component for collision radius calculation
    - Blends separation force with existing movement direction
    
    How it works:
    1. For each moving NPC, check all nearby NPCs
    2. If NPCs are overlapping (within combined radius), calculate push force
    3. Blend push force into current movement direction
    4. Update Locomotion component with new direction
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

-- Component shortcuts
local Mob = comps.Mob
local Transform = comps.Transform
local Locomotion = comps.Locomotion
local Size = comps.Size
local CombatNPC = comps.CombatNPC

-- Query for moving combat NPCs (need locomotion)
local moving = world
    :query(Transform, Locomotion, Size)
    :with(Mob)
    :with(CombatNPC) -- ONLY combat NPCs
    :cached()

-- Query for all combat NPCs (neighbors pool)
local neighbors = world
    :query(Transform, Size)
    :with(Mob)
    :with(CombatNPC) -- ONLY combat NPCs
    :cached()

local EPS = 1e-4

-- Tunables:
-- Size is HitboxSize.Magnitude, so it's "overall scale".
-- radiusFactor converts that into a collision radius in studs.
local RADIUS_FACTOR = 0.25  -- tweak: bigger -> they avoid from farther away
local SEPARATION_STRENGTH = 8  -- how aggressively to push

local SEP_HZ = 10
local SEP_TICK = 1 / SEP_HZ
local sepAcc = 0

local function separationStep(dt: number)
    for e, transform, loco, sizeSelf in moving do
        local pos = transform.new.Position
        local baseDir = loco.dir

        local selfRadius = (sizeSelf or 0) * RADIUS_FACTOR
        local separation = Vector3.zero

        for other, otherTransform, sizeOther in neighbors do
            if other == e then
                continue
            end

            local otherPos = otherTransform.new.Position
            local offset = pos - otherPos
            local dist = offset.Magnitude
            if dist < EPS then
                continue
            end

            local otherRadius = (sizeOther or 0) * RADIUS_FACTOR
            local targetDist = selfRadius + otherRadius

            if dist < targetDist and targetDist > EPS then
                -- how deep we are inside each other's "bubble"
                local penetration = targetDist - dist
                local pushStrength = penetration / targetDist -- [0..1]

                separation += offset.Unit * pushStrength
            end
        end

        if separation.Magnitude > EPS then
            local sepDir = separation.Unit

            -- blend separation into current direction
            local combined = baseDir + sepDir * (SEPARATION_STRENGTH * dt)
            if combined.Magnitude > EPS then
                combined = combined.Unit
            end

            loco.dir = combined
            world:set(e, Locomotion, loco)
        end
    end
end

local function sepWrapper(dt: number)
    sepAcc += dt
    if sepAcc < SEP_TICK then return end

    local step_dt = sepAcc
    sepAcc = 0
    separationStep(step_dt)
end

return {
    run = function(world)
        local dt = task.wait()
        sepWrapper(dt)
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}

