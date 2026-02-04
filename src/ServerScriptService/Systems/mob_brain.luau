
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

local Character = comps.Character
local Mob = comps.Mob
local Transform = comps.Transform
local Locomotion = comps.Locomotion
local AIState = comps.AIState
local Traits = comps.Traits
local Wander = comps.Wander
local Player = comps.Player
local CombatNPC = comps.CombatNPC
local NPCCombatState = comps.NPCCombatState

-- BUG 3.3 FIX: Removed legacy Stun component - using StateManager instead
local _Stun = comps.Stun -- Kept for reference, prefixed with _ to silence unused warning
local Knocked = comps.Knocked
local Dead = comps.Dead
local Ragdoll = comps.Ragdoll
local CantMove = comps.CantMove

local mobs = world
    :query(Character, Transform, Locomotion, AIState, Traits, Wander)
    :with(Mob)
    :with(CombatNPC)
    :cached()

local players = world
    :query(Character, Transform)
    :with(Player)
    :cached()

local EPS = 1e-4

local function randRange(min: number, max: number): number
    return min + (max - min) * math.random()
end

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

local function canAct(entity: number): boolean
    local character = world:get(entity, Character)
    if not character then return false end

    -- Dead is now a tag - use world:has instead of world:get
    if world:has(entity, Dead) then return false end

    -- BUG 3.3 FIX: Use only StateManager for stun checks (removed legacy Stun component check)
    -- StateManager is now the single source of truth for state management
    if StateManager.StateCount(character, "Stuns") then
        return false
    end

    -- Also check for active actions that would prevent new actions
    if StateManager.StateCount(character, "Actions") then
        return false
    end

    local knocked = world:get(entity, Knocked)
    if knocked and knocked.value then return false end

    local ragdoll = world:get(entity, Ragdoll)
    if ragdoll and ragdoll.value then return false end

    local cantMove = world:get(entity, CantMove)
    if cantMove and cantMove.value then return false end

    return true
end

local function updateWanderDir(
    wander: any,
    pos: Vector3,
    speed: number,
    dt: number,
    locoPrev: any
): (Vector3, number)
    local now = os.clock()

    if now < wander.nextMove then
        local prevDir = locoPrev and locoPrev.dir or Vector3.zero
        return prevDir, speed * 0.5
    end


    wander.nextMove = now + randRange(2, 5)

    local toCenter = wander.center - pos
    local distFromCenter = toCenter.Magnitude

    local dir: Vector3
    if distFromCenter > wander.radius then

        dir = toCenter.Unit
    else

        local angle = math.random() * math.pi * 2
        dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
    end

    return dir, speed * 0.5
end


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


    if dist <= (traits.preferDistance or 3) then
        if fleeWeight > chaseWeight then
            state = "flee"
        else
            state = "chase"
        end

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

        if fleeWeight > 0.5 and math.random() < fleeWeight then
            state = "flee"
        else
            state = "wander"
        end
    end


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

local hasLoggedBrain = false


local function mobBrainStep(dt: number)
    for e, char, transform, loco, ai, traits, wander in mobs do
        if not hasLoggedBrain then
            hasLoggedBrain = true
        end

        if world:has(e, comps.NPCTarget) then
            continue
        end

        if world:has(e, comps.NPCWander) then
            continue
        end

        if not canAct(e) then

            world:set(e, Locomotion, {
                dir = Vector3.zero,
                speed = 0,
            })
            continue
        end

        local npcState = world:get(e, NPCCombatState)
        local isPassive = npcState and npcState.isPassive
        local isAggressive = npcState and npcState.isAggressive
        local hasBeenAttacked = npcState and npcState.hasBeenAttacked

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

        if isPassive and not isAggressive and not hasBeenAttacked then

            world:set(e, Locomotion, {
                dir = Vector3.zero,
                speed = 0,
            })

            -- HasTarget/MobState/TargetPos attributes removed - use ECS components instead
            -- (AIState component contains state, NPCTarget component indicates target)

            continue
        end

        -- HasTarget/MobState/TargetPos attributes removed - ECS is now the source of truth

        if ai.t >= ai.dur then
            local state, dur, circleSign = pickNewState(hasPlayer, dist, traits)
            ai.state = state
            ai.t = 0
            ai.dur = dur
            ai.circleSign = circleSign
        end

        local dir = Vector3.zero
        local baseSpeed = 30
        local speed = baseSpeed * (traits.baseSpeedMul or 1)


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
            local d, s = updateWanderDir(wander, pos, speed, dt, loco)
            dir = d
            speed = s
        end

        if dir.Magnitude <= EPS then
            speed = 0
            dir = Vector3.zero
        end

        world:set(e, Locomotion, {
            dir = dir,
            speed = speed,
        })
        world:set(e, AIState, ai)
    end
end

local BRAIN_HZ = 4
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
    run = function(world, dt)
        brainWrapper(dt)
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}

