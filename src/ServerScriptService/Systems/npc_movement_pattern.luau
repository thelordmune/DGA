--!strict
--[[
    NPC Movement Pattern System (ECS)

    Replaces behavior tree follow_enemy movement with high-performance ECS.

    Handles:
    - Movement pattern selection (Direct, Strafe, SideApproach, CircleStrafe, ZigZag)
    - Sprint/walk speed management
    - Smooth movement interpolation
    - Pattern-based direction calculation

    Runs at 8 Hz for performance
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)

-- Query NPCs with targets that need movement
local query = world:query(
    comps.Character,
    comps.Transform,
    comps.NPCTarget,
    comps.NPCMovementPattern,
    comps.NPCConfig,
    comps.Locomotion
):with(comps.CombatNPC):cached()

-- Throttle to 15 Hz (IMPROVED: faster movement reactions - was 8 Hz / 0.125s)
local lastUpdate = 0
local UPDATE_INTERVAL = 0.067

-- Helper: Pick movement pattern based on context
local function pickMovementPattern(
    distance: number,
    canStrafe: boolean,
    maxStrafeRadius: number,
    npcPos: Vector3,
    targetPos: Vector3,
    targetLook: Vector3
): string
    -- Can't strafe or too far
    if not canStrafe or distance > maxStrafeRadius then
        return "Direct"
    end

    -- Check alignment (player must be looking at NPC for strafing)
    local toNpc = (npcPos - targetPos).Unit
    local alignment = toNpc:Dot(targetLook)
    if alignment < 0.5 then
        return "Direct"
    end

    -- Weighted random selection (ADJUSTED: reduced CircleStrafe frequency)
    local patterns = {
        {name = "Direct", weight = 3},       -- ~13%
        {name = "Strafe", weight = 10},      -- ~43%
        {name = "SideApproach", weight = 6}, -- ~26%
        {name = "CircleStrafe", weight = 3}, -- ~13% (REDUCED from 50%)
        {name = "ZigZag", weight = 1},       -- ~4%
    }

    local totalWeight = 0
    for _, p in patterns do
        totalWeight += p.weight
    end

    local rand = math.random() * totalWeight
    local acc = 0
    for _, p in patterns do
        acc += p.weight
        if rand < acc then
            return p.name
        end
    end

    return "Direct"
end

-- Helper: Calculate direction based on movement pattern
local function calculatePatternDirection(
    patternName: string,
    npcPos: Vector3,
    targetPos: Vector3,
    pattern: any
): Vector3
    local toTarget = (targetPos - npcPos)
    local toTarget2D = Vector3.new(toTarget.X, 0, toTarget.Z)

    if toTarget2D.Magnitude < 0.001 then
        return Vector3.zero
    end

    toTarget2D = toTarget2D.Unit

    if patternName == "Direct" then
        return toTarget2D

    elseif patternName == "Strafe" then
        -- Strafe left/right while moving forward
        local right = Vector3.new(-toTarget2D.Z, 0, toTarget2D.X)

        -- Initialize or flip strafe direction
        if not pattern.strafeDirection then
            pattern.strafeDirection = right * (math.random() > 0.5 and 1 or -1)
        end

        -- Mix forward and strafe (matches behavior tree: ForwardMix=1.2, StrafeSpeed=2.0)
        local direction = toTarget2D * 1.2 + pattern.strafeDirection * 2.0
        return direction.Unit

    elseif patternName == "SideApproach" then
        -- Approach from side
        local right = Vector3.new(-toTarget2D.Z, 0, toTarget2D.X)

        -- Pick side if not set
        if not pattern.sideDirection then
            pattern.sideDirection = math.random() > 0.5 and "Left" or "Right"
        end

        local side = (pattern.sideDirection == "Left") and -right or right

        -- Mix forward and side (matches behavior tree: ForwardSpeed=1.3, SideSpeed=2.5)
        local direction = toTarget2D * 1.3 + side * 2.5
        return direction.Unit

    elseif patternName == "CircleStrafe" then
        -- Circle around target
        local right = Vector3.new(-toTarget2D.Z, 0, toTarget2D.X)
        local direction = toTarget2D + right * pattern.circleDirection
        return direction.Unit

    elseif patternName == "ZigZag" then
        -- Zig-zag pattern (switch sides every 1 second)
        pattern.zigzagTimer = (pattern.zigzagTimer or 0) + UPDATE_INTERVAL
        if pattern.zigzagTimer > 1.0 then
            pattern.zigzagTimer = 0
            pattern.zigzagDirection = -pattern.zigzagDirection
        end

        local right = Vector3.new(-toTarget2D.Z, 0, toTarget2D.X)

        -- Mix forward and side (matches behavior tree: ForwardSpeed=1.0, SideSpeed=0.5)
        local direction = toTarget2D * 1.0 + right * pattern.zigzagDirection * 0.5
        return direction.Unit
    end

    return toTarget2D
end

-- Main system function
-- ARCHETYPE OPTIMIZATION: Batch process entities for better cache performance
local function updateMovementPatterns(_dt: number)
    local now = os.clock()
    if now - lastUpdate < UPDATE_INTERVAL then
        return
    end
    lastUpdate = now

    -- Get archetypes for batch processing
    local archetypes = query:archetypes()

    for _, archetype in archetypes do
        local columns = archetype.columns_map
        local entities = archetype.entities

        -- Direct column access for better performance
        local characters = columns[comps.Character]
        local transforms = columns[comps.Transform]
        local targets = columns[comps.NPCTarget]
        local patterns = columns[comps.NPCMovementPattern]
        local configs = columns[comps.NPCConfig]
        local locos = columns[comps.Locomotion]

        -- Process all entities in this archetype
        for row, entity in entities do
            local char = characters[row]
            local transform = transforms[row]
            local target = targets[row]
            local pattern = patterns[row]
            local config = configs[row]
            local loco = locos[row]
        -- Debug: Always log for guards
        if char.Name:match("Guard") then
           ---- print(`[npc_movement_pattern_ecs] GUARD FOUND IN QUERY: {char.Name} targeting {target and target.Name or "nil"}`)
        end

        -- Check if NPC is stunned - stop movement if stunned
        if StateManager.StateCount(char, "Stuns") then
            -- PERFORMANCE: Only update if not already stopped
            if loco.speed ~= 0 or loco.dir.Magnitude > 0.001 then
                loco.dir = Vector3.zero
                loco.speed = 0
            end
            continue
        end

        -- FIXED: Prevent locomotion while blocking
        if StateManager.StateCheck(char, "Actions", "Block") then
            -- PERFORMANCE: Only update if not already stopped
            if loco.speed ~= 0 or loco.dir.Magnitude > 0.001 then
                loco.dir = Vector3.zero
                loco.speed = 0
            end
            continue
        end

        -- Validate target
        if not target or not target.Parent then
            continue
        end

        local targetRoot = target:FindFirstChild("HumanoidRootPart")
        if not targetRoot then
            continue
        end

        local npcPos = transform.new.Position
        local targetPos = targetRoot.Position
        local targetCFrame = targetRoot.CFrame
        local distance = (targetPos - npcPos).Magnitude

        -- Debug: Log movement for guards
        if char.Name:match("Guard") then
           ---- print(`[npc_movement_pattern_ecs] {char.Name} chasing {target.Name} - distance: {math.floor(distance)} studs, pattern: {pattern.current}`)
        end

        -- Stop if too close (within 3 studs - matches behavior tree "Still" pattern)
        if distance < 3 then
            -- PERFORMANCE: Only update if not already stopped
            if loco.speed ~= 0 or loco.dir.Magnitude > 0.001 then
                loco.dir = Vector3.zero
                loco.speed = 0
            end
            continue
        end

        -- Determine if should sprint (matches behavior tree: sprint if > 15 studs)
        local shouldSprint = distance > 15

        -- Update movement pattern every 2-3 seconds (matches behavior tree Duration)
        if now - pattern.lastChanged > pattern.duration then
            pattern.current = pickMovementPattern(
                distance,
                config.canStrafe,
                config.maxStrafeRadius,
                npcPos,
                targetPos,
                targetCFrame.LookVector
            )
            pattern.lastChanged = now
            pattern.duration = math.random(200, 300) / 100 -- 2.0-3.0 seconds

            -- Reset pattern-specific state when changing patterns
            if pattern.current ~= "Strafe" then
                pattern.strafeDirection = nil
            end
            if pattern.current ~= "SideApproach" then
                pattern.sideDirection = nil
            end
        end

        -- Calculate movement direction based on current pattern
        local direction = calculatePatternDirection(
            pattern.current,
            npcPos,
            targetPos,
            pattern
        )

        -- Apply smooth interpolation (matches behavior tree smoothingAlpha)
        local smoothingAlpha = config.smoothingAlpha or 0.5
        local previousDir = loco and loco.dir or Vector3.zero
        local smoothedDir = previousDir:Lerp(direction, smoothingAlpha)

        -- Normalize
        if smoothedDir.Magnitude > 0.001 then
            smoothedDir = smoothedDir.Unit
        else
            smoothedDir = Vector3.zero
        end

        -- Set speed based on sprint state
        local speed = shouldSprint and config.runSpeed or config.walkSpeed

        -- PERFORMANCE: In-place mutation with change detection (avoids archetype moves)
        -- Only update locomotion if values actually changed
        local dirChanged = (loco.dir - smoothedDir).Magnitude > 0.001
        local speedChanged = math.abs(loco.speed - speed) > 0.1
        if dirChanged or speedChanged then
            loco.dir = smoothedDir
            loco.speed = speed
        end

        -- Pattern component is mutated in-place by calculatePatternDirection, no world:set needed
        -- (strafeDirection, sideDirection, zigzagTimer, etc. are modified directly on the table)

        -- PERFORMANCE: Only update sprinting if changed
        local currentSprinting = world:get(entity, comps.Sprinting)
        if not currentSprinting or currentSprinting.value ~= shouldSprint then
            world:set(entity, comps.Sprinting, {
                value = shouldSprint,
            })
        end
        end -- end entity loop
    end -- end archetype loop
end

return {
    run = function(world: Jecs.World, dt: number)
        updateMovementPatterns(dt)
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}
