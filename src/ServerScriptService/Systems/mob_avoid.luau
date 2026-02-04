--!strict


local ReplicatedStorage = game:GetService("ReplicatedStorage")

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

local Mob = comps.Mob
local Transform = comps.Transform
local Locomotion = comps.Locomotion
local Size = comps.Size
local CombatNPC = comps.CombatNPC

local moving = world
    :query(Transform, Locomotion, Size)
    :with(Mob)
    :with(CombatNPC)
    :cached()


local neighbors = world
    :query(Transform, Size)
    :with(Mob)
    :with(CombatNPC)
    :cached()

local EPS = 1e-4


local RADIUS_FACTOR = 0.35
local SEPARATION_STRENGTH = 12

local SEP_HZ = 9
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
                local penetration = targetDist - dist
                local pushStrength = penetration / targetDist

                separation += offset.Unit * pushStrength
            end
        end

        if separation.Magnitude > EPS then
            local sepDir = separation.Unit

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
    run = function(world, dt)
        sepWrapper(dt)
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}

