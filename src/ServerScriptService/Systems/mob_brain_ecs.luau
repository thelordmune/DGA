--[[
    ECS-Based Mob Brain System for Ironveil

    This is a performant, pure ECS implementation adapted from RPGJECS.
    It uses only ECS components to detect and control NPCs, making it much
    more performant than the old behavior tree system.

    Features:
    - Pure ECS queries (no CollectionService tags)
    - Weighted state machine (wander/chase/flee/circle)
    - Detects players via ECS Player component
    - Uses Locomotion component for movement intent
    - Respects Ironveil's combat states (Stun, Knocked, Dead, etc.)
    - ONLY affects combat NPCs (filters out dialogue NPCs via CombatNPC component)
    - Allows behavior trees to override via BehaviorTreeOverride component
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

-- Component shortcuts
local Character = comps.Character
local Mob = comps.Mob
local Transform = comps.Transform
local Locomotion = comps.Locomotion
local AIState = comps.AIState
local Traits = comps.Traits
local Wander = comps.Wander
local Hitbox = comps.Hitbox
local Player = comps.Player
local CombatNPC = comps.CombatNPC
local BehaviorTreeOverride = comps.BehaviorTreeOverride

-- Ironveil-specific state components
local Stun = comps.Stun
local Knocked = comps.Knocked
local Dead = comps.Dead
local Ragdoll = comps.Ragdoll
local CantMove = comps.CantMove

-- Query for COMBAT mobs with AI (filters out dialogue NPCs)
local mobs = world
    :query(Character, Transform, Locomotion, AIState, Traits, Wander)
    :with(Mob)
    :with(CombatNPC) -- ONLY combat NPCs
    :cached()

-- Query for all players
local players = world
    :query(Character, Transform)
    :with(Player)
    :cached()

local EPS = 1e-4

local function randRange(min: number, max: number): number
    return min + (max - min) * math.random()
end

-- Get closest player position using ECS queries
local function getClosestPlayer(mobPos: Vector3, detectRange: number): (Vector3?, number)
    local closest: Vector3? = nil
    local closestDist = math.huge

    for _, playerChar, playerTransform in players do
        if not playerChar or not playerChar:IsDescendantOf(workspace) then
            continue
        end

        local playerPos = playerTransform.new.Position
        local dist = (playerPos - mobPos).Magnitude

        if dist < detectRange and dist < closestDist then
            closest = playerPos
            closestDist = dist
        end
    end

    return closest, closestDist
end

-- Check if NPC can act (respects Ironveil's state system)
local function canAct(entity: number): boolean
    -- Check if dead
    local dead = world:get(entity, Dead)
    if dead then return false end

    -- Check if stunned
    local stun = world:get(entity, Stun)
    if stun and stun.value then return false end

    -- Check if knocked
    local knocked = world:get(entity, Knocked)
    if knocked and knocked.value then return false end

    -- Check if ragdolled
    local ragdoll = world:get(entity, Ragdoll)
    if ragdoll and ragdoll.value then return false end

    -- Check if can't move
    local cantMove = world:get(entity, CantMove)
    if cantMove and cantMove.value then return false end

    return true
end

-- Wander behavior
local function updateWanderDir(
    wander: any,
    pos: Vector3,
    speed: number,
    dt: number,
    locoPrev: any
): (Vector3, number)
    local now = os.clock()

    if now < wander.nextMove then
        -- Keep previous direction
        local prevDir = locoPrev and locoPrev.dir or Vector3.zero
        return prevDir, speed * 0.5
    end

    -- Pick new wander direction
    wander.nextMove = now + randRange(2, 5)

    local toCenter = wander.center - pos
    local distFromCenter = toCenter.Magnitude

    local dir: Vector3
    if distFromCenter > wander.radius then
        -- Too far from center, go back
        dir = toCenter.Unit
    else
        -- Random direction
        local angle = math.random() * math.pi * 2
        dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
    end

    return dir, speed * 0.5
end

-- Pick a new AI state based on context
local function pickNewState(
    hasPlayer: boolean,
    dist: number,
    traits: any
): (string, number, number)
    local state = "wander"
    local dur = 0
    local circleSign = (math.random(0, 1) == 0) and -1 or 1

    if not hasPlayer then
        state = "wander"
        dur = math.random(2, 5)
        return state, dur, circleSign
    end

    local chaseWeight = traits.chaseWeight or 0.5
    local fleeWeight = traits.fleeWeight or 0.2
    local circleWeight = traits.circleWeight or 0.3

    -- Close range: mostly chase or flee
    if dist <= (traits.preferDistance or 3) then
        if fleeWeight > chaseWeight then
            state = "flee"
        else
            state = "chase"
        end
    -- Mid range: weighted choice
    elseif dist > 4 then
        local total = 1 + chaseWeight + fleeWeight + circleWeight
        local r = math.random() * total
        local acc = 1

        if r < acc then
            state = "wander"
        else
            acc += chaseWeight
            if r < acc then
                state = "chase"
            else
                acc += circleWeight
                if r < acc then
                    state = "circle"
                else
                    state = "flee"
                end
            end
        end
    else
        -- Very close but not fleeing strongly
        if fleeWeight > 0.5 and math.random() < fleeWeight then
            state = "flee"
        else
            state = "wander"
        end
    end

    -- Set durations
    if state == "chase" then
        dur = randRange(0.5, 1.2)
    elseif state == "circle" then
        dur = math.random(5, 10)
    elseif state == "flee" then
        dur = math.random(1, 3)
    else
        dur = math.random(2, 6)
    end

    return state, dur, circleSign
end

-- Main brain step
local function mobBrainStep(dt: number)
    for e, char, transform, loco, ai, traits, wander in mobs do
        -- Skip if behavior tree is overriding
        if world:has(e, BehaviorTreeOverride) then
            continue
        end

        -- Skip if NPC can't act
        if not canAct(e) then
            -- Set to idle
            world:set(e, Locomotion, {
                dir = Vector3.zero,
                speed = 0,
            })
            continue
        end

        local pos = transform.new.Position
        ai.t += dt

        local detectRange = traits.detectRange or 40
        local loseSightRange = traits.loseSightRange or (detectRange + 15)

        local playerPos, dist = getClosestPlayer(pos, detectRange)
        local hasPlayer = (playerPos ~= nil)

        if hasPlayer and dist > loseSightRange then
            hasPlayer = false
            playerPos = nil
        end

        -- Update hitbox attributes for debugging/other systems
        local hitbox = world:get(e, Hitbox)
        if hitbox then
            hitbox:SetAttribute("HasTarget", hasPlayer)
            hitbox:SetAttribute("MobState", ai.state)
            if hasPlayer then
                hitbox:SetAttribute("TargetPos", playerPos)
            else
                hitbox:SetAttribute("TargetPos", nil)
            end
        end

        -- State expiry - pick new state
        if ai.t >= ai.dur then
            local state, dur, circleSign = pickNewState(hasPlayer, dist, traits)
            ai.state = state
            ai.t = 0
            ai.dur = dur
            ai.circleSign = circleSign
        end

        local dir = Vector3.zero
        local baseSpeed = 30 -- Default speed
        local speed = baseSpeed * (traits.baseSpeedMul or 1)

        -- Execute current state
        if ai.state == "chase" and playerPos then
            local toPlayer = playerPos - pos
            toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)
            if toPlayer.Magnitude > EPS then
                dir = toPlayer.Unit
            end

        elseif ai.state == "flee" and playerPos then
            local away = pos - playerPos
            away = Vector3.new(away.X, 0, away.Z)
            if away.Magnitude > EPS then
                dir = away.Unit
            end

        elseif ai.state == "circle" and playerPos then
            local toPlayer = playerPos - pos
            toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)
            if toPlayer.Magnitude > EPS then
                local forward = toPlayer.Unit
                local right = Vector3.new(-forward.Z, 0, forward.X)
                local circleDir = forward * 0.3 + right * ai.circleSign
                if circleDir.Magnitude > EPS then
                    dir = circleDir.Unit
                end
            end

        else
            -- Wander as fallback
            local d, s = updateWanderDir(wander, pos, speed, dt, loco)
            dir = d
            speed = s
        end

        -- Normalize direction
        if dir.Magnitude <= EPS then
            speed = 0
            dir = Vector3.zero
        end

        -- Update locomotion component (movement intent)
        world:set(e, Locomotion, {
            dir = dir,
            speed = speed,
        })

        -- Update AI state
        world:set(e, AIState, ai)
    end
end

-- Throttle brain updates to 8 Hz for performance
local BRAIN_HZ = 8
local BRAIN_TICK = 1 / BRAIN_HZ
local acc = 0

local function brainWrapper(dt: number)
    acc += dt
    if acc < BRAIN_TICK then return end

    local step_dt = acc
    acc = 0
    mobBrainStep(step_dt)
end

return {
    run = function(world)
        local dt = task.wait() -- Get delta time from RunService
        brainWrapper(dt)
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}

