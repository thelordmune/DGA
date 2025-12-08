# Complete NPC Behavioral System ECS Migration Plan

## Executive Summary

This document outlines the complete migration of Ironveil's NPC behavioral system from a behavior tree architecture to a high-performance ECS (Entity Component System) using jecs.

**Goals:**
- ✅ **Maximum Performance** - Batch processing, data locality, archetype storage
- ✅ **Complete Logic Preservation** - All behavior tree logic migrated faithfully
- ✅ **Maintainability** - Clear system separation, component-based design
- ✅ **Scalability** - Support for 100+ NPCs at 60 FPS

---

## Current State Analysis

### What's Already ECS
1. **mob_brain_ecs.luau** - Simple wander/chase AI (8 Hz)
2. **mob_movement_ecs.luau** - Locomotion execution (20 Hz)
3. **npc_targeting_ecs.luau** - Target acquisition (15 Hz)
4. **mobs.luau** - NPC initialization and component setup

### What's Still Behavior Trees
1. **Movement Patterns** - Strafe, CircleStrafe, SideApproach, ZigZag, Direct
2. **Pathfinding** - PathfindingService integration, waypoint following
3. **Combat Actions** - M1 attacks, skill usage, blocking, parrying
4. **Skill Scoring** - intelligent_attack decision-making
5. **Smart Defense** - Reactive parrying/blocking/dodging
6. **State Management** - Humanoid WalkSpeed/JumpPower based on states
7. **Wander** - Perlin noise natural movement
8. **Sprint/Dash** - Movement speed modifications

### Performance Bottlenecks (Behavior Trees)
1. **Per-frame distance calculations** for ALL NPCs → O(NPCs × Players)
2. **CollectionService:GetTagged()** iterations → O(TotalTaggedEntities)
3. **Skill scoring without caching** → O(NumSkills) per attack
4. **JSON state decoding 6+ times per 0.15s** → Heavy string parsing
5. **Movement pattern overhead** → Constraint creation/destruction
6. **Pathfinding thread spawning** → Thread allocation per NPC
7. **Noise generator closures** → Memory leaks

---

## ECS Architecture Design

### Component Structure

All components already defined in [jecs_components.luau](src/ReplicatedStorage/Modules/ECS/jecs_components.luau#L124-L209):

```lua
-- Already exist:
NPCTarget: Entity<Model>
NPCCombatState: Entity<{...}>
NPCSkillScoring: Entity<{...}>
NPCGuardPattern: Entity<{...}>
NPCPathfinding: Entity<{...}>
NPCMovementPattern: Entity<{...}>
NPCWander: Entity<{...}>
NPCConfig: Entity<{...}>
NPCSpawnData: Entity<{...}>
Locomotion: Entity<{dir: Vector3, speed: number}>
Transform: Entity<{new: CFrame, old: CFrame}>
```

**New Components Needed:**
```lua
-- Combat action execution
NPCAttackExecution: Entity<{
    isAttacking: boolean,
    attackName: string,
    attackStartTime: number,
    attackDuration: number,
    targetPosition: Vector3?,
}>

-- Defense state
NPCDefenseState: Entity<{
    isBlocking: boolean,
    isParrying: boolean,
    lastDefenseAction: string, -- "block" | "parry" | "dodge"
    lastDefenseTime: number,
    defenseSuccess: boolean,
}>

-- Sprint/Dash state
NPCLocomotionState: Entity<{
    isSprinting: boolean,
    isDashing: boolean,
    dashDirection: Vector3?,
    dashStartTime: number,
    dashDuration: number,
}>

-- Shared path for multiple NPCs
SharedPath: Entity<{
    destination: Vector3,
    waypoints: {Vector3},
    computedAt: number,
    subscribers: {number}, -- Entity IDs using this path
}>
```

### System Architecture

**System Update Frequencies:**
- **4 Hz** (0.25s) - Expensive logic (skill scoring, pathfinding)
- **8 Hz** (0.125s) - Brain logic (state decisions, target validation)
- **15 Hz** (0.067s) - Targeting, defense reactions
- **20 Hz** (0.05s) - Movement execution, locomotion
- **60 Hz** (0.0167s) - State management (WalkSpeed/JumpPower updates)

---

## System Breakdown

### 1. Targeting System (ALREADY EXISTS - npc_targeting_ecs.luau)

**Purpose:** Detect and track player targets

**Current Implementation:** ✅ Already migrated
- Runs at 15 Hz
- Checks Damage_Log for attacks
- Sets NPCTarget component
- Manages aggressive/passive mode

**Enhancements Needed:**
- Add spatial partitioning for players (grid-based lookup)
- Cache player list per frame instead of recomputing
- Share detection results between nearby NPCs

---

### 2. Movement Pattern System (NEW)

**File:** `npc_movement_pattern_ecs.luau`

**Purpose:** Replace `follow_enemy` movement patterns

**Update Rate:** 8 Hz

**Logic:**
```lua
-- Query NPCs with target
local query = world:query(
    Character, Transform, NPCTarget,
    NPCMovementPattern, NPCConfig, Locomotion
):with(CombatNPC)

for entity, char, transform, target, pattern, config, loco in query do
    -- Get target position
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if not targetRoot then continue end

    local npcPos = transform.new.Position
    local targetPos = targetRoot.Position
    local distance = (targetPos - npcPos).Magnitude

    -- Determine if should sprint
    local shouldSprint = distance > 15

    -- Update movement pattern (every 2-3 seconds)
    if os.clock() - pattern.lastChanged > pattern.duration then
        pattern.current = pickMovementPattern(
            distance,
            config.canStrafe,
            config.maxStrafeRadius,
            npcPos, targetPos,
            targetRoot.CFrame.LookVector
        )
        pattern.lastChanged = os.clock()
        pattern.duration = math.random(2, 3)
    end

    -- Calculate movement direction based on pattern
    local direction = calculatePatternDirection(
        pattern.current,
        npcPos, targetPos,
        pattern -- contains circleDirection, zigzagDirection, etc.
    )

    -- Set locomotion
    local speed = shouldSprint and config.runSpeed or config.walkSpeed
    world:set(entity, Locomotion, {
        dir = direction,
        speed = speed,
    })

    -- Update NPCMovementPattern
    world:set(entity, NPCMovementPattern, pattern)
end
```

**Pattern Calculations (helper functions):**
```lua
local function pickMovementPattern(
    distance: number,
    canStrafe: boolean,
    maxStrafeRadius: number,
    npcPos: Vector3,
    targetPos: Vector3,
    targetLook: Vector3
): string
    if not canStrafe or distance > maxStrafeRadius then
        return "Direct"
    end

    -- Check alignment (player looking at NPC)
    local toNpc = (npcPos - targetPos).Unit
    local alignment = toNpc:Dot(targetLook)
    if alignment < 0.5 then
        return "Direct"
    end

    -- Weighted random selection
    local patterns = {
        {name = "Direct", weight = 1},
        {name = "Strafe", weight = 8},
        {name = "SideApproach", weight = 4},
        {name = "CircleStrafe", weight = 15},
        {name = "ZigZag", weight = 2},
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

local function calculatePatternDirection(
    patternName: string,
    npcPos: Vector3,
    targetPos: Vector3,
    pattern: any
): Vector3
    local toTarget = (targetPos - npcPos).Unit
    local toTarget2D = Vector3.new(toTarget.X, 0, toTarget.Z).Unit

    if patternName == "Direct" then
        return toTarget2D

    elseif patternName == "Strafe" then
        -- Alternate left/right strafe
        local right = Vector3.new(-toTarget2D.Z, 0, toTarget2D.X)
        pattern.strafeDirection = pattern.strafeDirection or right
        return (toTarget2D * 1.2 + pattern.strafeDirection * 2.0).Unit

    elseif patternName == "SideApproach" then
        -- Approach from side
        local sideDir = pattern.sideDirection or (math.random() > 0.5 and "Left" or "Right")
        pattern.sideDirection = sideDir
        local right = Vector3.new(-toTarget2D.Z, 0, toTarget2D.X)
        local side = (sideDir == "Left") and -right or right
        return (toTarget2D * 1.3 + side * 2.5).Unit

    elseif patternName == "CircleStrafe" then
        -- Circle around target
        local right = Vector3.new(-toTarget2D.Z, 0, toTarget2D.X)
        return (toTarget2D + right * pattern.circleDirection).Unit

    elseif patternName == "ZigZag" then
        -- Zig-zag pattern
        pattern.zigzagTimer = (pattern.zigzagTimer or 0) + 0.125
        if pattern.zigzagTimer > 1.0 then
            pattern.zigzagTimer = 0
            pattern.zigzagDirection = -pattern.zigzagDirection
        end
        local right = Vector3.new(-toTarget2D.Z, 0, toTarget2D.X)
        return (toTarget2D * 1.0 + right * pattern.zigzagDirection * 0.5).Unit
    end

    return toTarget2D
end
```

---

### 3. Pathfinding System (NEW)

**File:** `npc_pathfinding_ecs.luau`

**Purpose:** Replace behavior tree pathfinding with shared paths

**Update Rate:** 4 Hz (expensive PathfindingService calls)

**Key Features:**
- Share paths between nearby NPCs going to same destination
- Recompute paths every 1-2 seconds (not 0.5s like behavior trees)
- Use archetypes to only process NPCs that need pathfinding

**Logic:**
```lua
local PathfindingService = game:GetService("PathfindingService")

-- Query NPCs that need pathfinding
local query = world:query(
    Character, Transform, NPCTarget, NPCPathfinding, Locomotion
):with(CombatNPC)

-- Shared path cache (destination → SharedPath entity)
local sharedPaths: {[string]: number} = {} -- key: "x,y,z" → SharedPath entity

for entity, char, transform, target, pathfinding, loco in query do
    local npcPos = transform.new.Position
    local targetPos = target:FindFirstChild("HumanoidRootPart").Position

    -- Check if need to pathfind (raycast blocked)
    local rayResult = workspace:Raycast(npcPos, targetPos - npcPos, raycastParams)

    if not rayResult then
        -- Direct path available
        pathfinding.pathState = "Direct"
        pathfinding.isActive = false
        world:set(entity, NPCPathfinding, pathfinding)
        continue
    end

    -- Need pathfinding
    pathfinding.pathState = "Pathfind"
    pathfinding.isActive = true

    -- Check if can reuse shared path
    local destKey = `{math.floor(targetPos.X)},{math.floor(targetPos.Y)},{math.floor(targetPos.Z)}`
    local sharedPathEntity = sharedPaths[destKey]

    if sharedPathEntity then
        local sharedPath = world:get(sharedPathEntity, SharedPath)

        -- Check if path is still valid (computed recently)
        if os.clock() - sharedPath.computedAt < 2.0 then
            -- Reuse shared path
            pathfinding.waypoints = sharedPath.waypoints
            pathfinding.currentWaypointIndex = 1
            world:set(entity, NPCPathfinding, pathfinding)
            continue
        end
    end

    -- Compute new path
    if os.clock() - pathfinding.lastRecomputeTime < 1.0 then
        -- Don't recompute too frequently
        continue
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
    })

    local success, err = pcall(function()
        path:ComputeAsync(npcPos, targetPos)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()

        -- Create/update shared path
        if not sharedPathEntity then
            sharedPathEntity = world:entity()
            sharedPaths[destKey] = sharedPathEntity
        end

        world:set(sharedPathEntity, SharedPath, {
            destination = targetPos,
            waypoints = waypoints,
            computedAt = os.clock(),
            subscribers = {entity},
        })

        pathfinding.waypoints = waypoints
        pathfinding.currentWaypointIndex = 1
        pathfinding.lastRecomputeTime = os.clock()
    end

    world:set(entity, NPCPathfinding, pathfinding)
end

-- Execute waypoint following (separate system at 20 Hz)
-- This reads NPCPathfinding.waypoints and updates Locomotion
```

---

### 4. Combat Decision System (NEW)

**File:** `npc_combat_decision_ecs.luau`

**Purpose:** Replace `intelligent_attack` skill scoring

**Update Rate:** 4 Hz (expensive skill scoring)

**Logic:**
```lua
-- Skill properties (migrate from CombatProperties)
local SKILL_PROPERTIES = {
    M1 = {
        MinRange = 0, MaxRange = 15,
        Cooldown = 2.5,
        SkillPriority = 1.0,
        IsOffensive = true,
    },
    M2 = {
        MinRange = 0, MaxRange = 18,
        Cooldown = 3.0,
        SkillPriority = 1.5,
        IsOffensive = true,
        IsGuardBreak = true,
    },
    -- ... all other skills
}

local query = world:query(
    Character, Transform, NPCTarget, NPCCombatState,
    NPCSkillScoring, Cooldowns
):with(CombatNPC)

for entity, char, transform, target, combatState, skillScoring, cooldowns in query do
    -- Only rescore every 0.5s (caching)
    if os.clock() - skillScoring.lastScoringTime < 0.5 then
        continue
    end

    local npcPos = transform.new.Position
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if not targetRoot then continue end

    local targetPos = targetRoot.Position
    local distance = (targetPos - npcPos).Magnitude

    local bestSkill = nil
    local bestScore = 0

    -- Score all available skills
    for skillName, props in SKILL_PROPERTIES do
        -- Check range
        if distance < props.MinRange or distance > props.MaxRange then
            continue
        end

        -- Check cooldown
        local lastUsed = cooldowns[skillName] or 0
        if os.clock() - lastUsed < props.Cooldown then
            continue
        end

        -- Base score
        local score = props.SkillPriority

        -- Context modifiers
        if props.IsOffensive and combatState.isAggressive then
            score *= 1.3
        end

        -- Player state reactions
        if isPlayerBlocking(target) then
            if props.IsGuardBreak then
                score *= 3.0 -- Prioritize guard breaks
            else
                score *= 0.3 -- Penalize normal attacks
            end
        end

        -- Low health bonus
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health / humanoid.MaxHealth < 0.3 then
            if props.IsDefensive then
                score *= 1.8
            end
        end

        -- Track best
        if score > bestScore then
            bestScore = score
            bestSkill = skillName
        end
    end

    -- Update skill scoring component
    skillScoring.bestSkill = bestSkill
    skillScoring.bestScore = bestScore
    skillScoring.lastScoringTime = os.clock()
    world:set(entity, NPCSkillScoring, skillScoring)
end
```

---

### 5. Combat Execution System (NEW)

**File:** `npc_combat_execution_ecs.luau`

**Purpose:** Execute attacks, blocks, parries based on combat decisions

**Update Rate:** 15 Hz (reactive to player actions)

**Logic:**
```lua
local Server = require(game.ServerScriptService.ServerConfig.Server)
local Combat = Server.Modules.Combat

local query = world:query(
    Character, NPCTarget, NPCCombatState,
    NPCSkillScoring, NPCAttackExecution, Cooldowns
):with(CombatNPC)

for entity, char, target, combatState, skillScoring, attackExec, cooldowns in query do
    -- Check if already attacking
    if attackExec.isAttacking then
        if os.clock() - attackExec.attackStartTime < attackExec.attackDuration then
            continue -- Still executing attack
        else
            -- Attack finished
            attackExec.isAttacking = false
            world:set(entity, NPCAttackExecution, attackExec)
        end
    end

    -- Check global action cooldown
    if os.clock() - combatState.lastActionTime < 0.3 then
        continue
    end

    -- Execute best skill
    if skillScoring.bestSkill and skillScoring.bestScore > 0 then
        local skillName = skillScoring.bestSkill

        -- Execute skill via Combat module
        if skillName == "M1" then
            Combat.Light(char)
        else
            Combat[skillName](char) -- Call skill function
        end

        -- Update state
        attackExec.isAttacking = true
        attackExec.attackName = skillName
        attackExec.attackStartTime = os.clock()
        attackExec.attackDuration = 1.0 -- Skill-specific duration

        combatState.lastActionTime = os.clock()
        combatState.lastAttackTime = os.clock()
        cooldowns[skillName] = os.clock()

        world:set(entity, NPCAttackExecution, attackExec)
        world:set(entity, NPCCombatState, combatState)
        world:set(entity, Cooldowns, cooldowns)
    end
end
```

---

### 6. Defense System (NEW)

**File:** `npc_defense_ecs.luau`

**Purpose:** Replace `smart_defense` - reactive blocking/parrying/dodging

**Update Rate:** 15 Hz (needs to react quickly to player attacks)

**Logic:**
```lua
local query = world:query(
    Character, NPCTarget, NPCDefenseState, NPCCombatState
):with(CombatNPC)

for entity, char, target, defenseState, combatState in query do
    -- Check if player is attacking
    local playerAttacking = isPlayerAttacking(target)
    if not playerAttacking then
        -- Stop blocking if no threat
        if defenseState.isBlocking then
            stopBlocking(char)
            defenseState.isBlocking = false
            world:set(entity, NPCDefenseState, defenseState)
        end
        continue
    end

    -- Get player attack type
    local attackType = getPlayerAttackType(target)

    -- Decide defense action (probabilities from smart_defense.lua)
    local action = pickDefenseAction(attackType)

    if action == "parry" then
        -- Execute parry
        parry(char)
        defenseState.isParrying = true
        defenseState.lastDefenseAction = "parry"
        defenseState.lastDefenseTime = os.clock()
        combatState.justParried = true
        combatState.parryTime = os.clock()

    elseif action == "block" then
        -- Execute block
        initiateBlock(char, true)
        defenseState.isBlocking = true
        defenseState.lastDefenseAction = "block"
        defenseState.lastDefenseTime = os.clock()

    elseif action == "dodge" then
        -- Execute dash away
        dash(char, "Back")
        defenseState.lastDefenseAction = "dodge"
        defenseState.lastDefenseTime = os.clock()
    end

    world:set(entity, NPCDefenseState, defenseState)
    world:set(entity, NPCCombatState, combatState)
end

-- Helper function: Defense action probabilities
function pickDefenseAction(attackType: string): string
    local probabilities = {
        M1 = {parry = 0.40, block = 0.45, none = 0.15},
        M2 = {block = 0.60, parry = 0.25, none = 0.15},
        Running = {parry = 0.50, block = 0.35, none = 0.15},
        AOE = {dodge = 0.70, none = 0.30},
        Heavy = {block = 0.60, parry = 0.20, none = 0.20},
    }

    local probs = probabilities[attackType] or probabilities.M1
    local rand = math.random()

    local acc = 0
    for action, prob in probs do
        acc += prob
        if rand < acc then
            return action
        end
    end

    return "none"
end
```

---

### 7. Wander System (NEW)

**File:** `npc_wander_ecs.luau`

**Purpose:** Replace behavior tree wander with Perlin noise movement

**Update Rate:** 8 Hz

**Logic:**
```lua
-- Perlin noise function (simplified)
local function noise(x: number, y: number): number
    local n = x + y * 57
    n = bit32.bxor(n, bit32.lshift(n, 13))
    return 1.0 - bit32.band(n * (n * n * 15731 + 789221) + 1376312589, 0x7fffffff) / 1073741824.0
end

local query = world:query(
    Character, Transform, NPCWander, NPCSpawnData, Locomotion
):with(CombatNPC):without(NPCTarget) -- Only wander when no target

for entity, char, transform, wander, spawnData, loco in query do
    local currentPos = transform.new.Position
    local spawnPos = spawnData.spawnPosition

    -- Calculate Perlin noise direction
    local time = os.clock() + wander.noiseOffset
    local swayX = noise(time * 0.5, 0)
    local swayY = noise(0, time * 0.5)

    local direction = Vector3.new(swayX, 0, swayY)

    -- Weight toward spawn if too far
    local distanceFromSpawn = (currentPos - spawnPos).Magnitude
    local maxDistance = spawnData.maxWanderDistance

    if distanceFromSpawn > maxDistance then
        local toSpawn = (spawnPos - currentPos).Unit
        local weight = math.clamp(distanceFromSpawn / maxDistance, 0, 1)
        direction = direction:Lerp(toSpawn, weight)
    end

    -- Smooth interpolation
    if direction.Magnitude > 0.01 then
        direction = direction.Unit
    else
        direction = Vector3.zero
    end

    local smoothed = wander.currentDirection:Lerp(direction, 0.5)
    wander.currentDirection = smoothed

    -- Update locomotion
    world:set(entity, Locomotion, {
        dir = smoothed,
        speed = 8, -- Slow wander speed
    })

    world:set(entity, NPCWander, wander)
end
```

---

### 8. State Management System (ENHANCE EXISTING)

**File:** Enhance existing state systems

**Purpose:** Replace `manage_humanoid_state` - set WalkSpeed/JumpPower based on states

**Update Rate:** 60 Hz (needs to be reactive)

**Logic:**
```lua
local query = world:query(Character, Stun, Knocked, CantMove, Ragdoll, Sprinting):cached()

for entity, char, stun, knocked, cantMove, ragdoll, sprinting in query do
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then continue end

    -- Priority order (from manage_humanoid_state.lua)
    if knocked and knocked.value then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0

    elseif stun and stun.value then
        humanoid.WalkSpeed = 3
        humanoid.JumpPower = 0

    elseif cantMove and cantMove.value then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0

    elseif ragdoll and ragdoll.value then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0

    elseif sprinting and sprinting.value then
        local config = world:get(entity, NPCConfig)
        humanoid.WalkSpeed = config.runSpeed

    else
        -- Default
        local config = world:get(entity, NPCConfig)
        humanoid.WalkSpeed = config.walkSpeed
        humanoid.JumpPower = config.jumpPower
    end

    -- AutoRotate management
    humanoid.AutoRotate = not (
        ragdoll and ragdoll.value
        or stun and stun.value
        or knocked and knocked.value
        or cantMove and cantMove.value
    )
end
```

---

## Migration Phases

### Phase 1: Foundation (Week 1)
**Goal:** Set up new systems without breaking existing behavior

1. ✅ Create movement pattern system (`npc_movement_pattern_ecs.luau`)
2. ✅ Create pathfinding system (`npc_pathfinding_ecs.luau`)
3. ✅ Create wander system (`npc_wander_ecs.luau`)
4. ✅ Initialize new components in `mobs.luau`
5. ⚠️ Keep behavior trees active (parallel systems)

**Testing:** Verify systems run without errors, log output

### Phase 2: Movement Migration (Week 2)
**Goal:** Replace behavior tree movement with ECS

1. ✅ Activate movement pattern system
2. ✅ Activate pathfinding system
3. ✅ Activate wander system
4. ✅ Disable `follow_enemy` for combat NPCs
5. ✅ Test: NPCs move smoothly, follow players, use patterns

**Success Criteria:**
- Guards use movement patterns when chasing
- Bandits wander when idle
- NPCs pathfind around obstacles
- No choppy movement

### Phase 3: Combat Decision Migration (Week 3)
**Goal:** Replace `intelligent_attack` with ECS

1. ✅ Create combat decision system (`npc_combat_decision_ecs.luau`)
2. ✅ Migrate skill scoring logic
3. ✅ Cache skill scores for 0.5s
4. ✅ Create combat execution system (`npc_combat_execution_ecs.luau`)
5. ✅ Test: NPCs use appropriate skills based on context

**Success Criteria:**
- Guards use guard breaks when player blocks
- NPCs use defensive skills when low health
- Skill cooldowns respected
- Smooth attack execution

### Phase 4: Defense Migration (Week 4)
**Goal:** Replace `smart_defense` with ECS

1. ✅ Create defense system (`npc_defense_ecs.luau`)
2. ✅ Migrate parry/block/dodge probabilities
3. ✅ Integrate with combat state
4. ✅ Test: NPCs parry M1s, block M2s, dodge AOEs

**Success Criteria:**
- Guards parry/block appropriately
- NPCs dodge AOE attacks
- Defense actions respect cooldowns
- Parry counter-attacks work

### Phase 5: Cleanup & Optimization (Week 5)
**Goal:** Remove behavior trees, optimize systems

1. ✅ Disable behavior tree brain for combat NPCs
2. ✅ Remove old conditions (follow_enemy, intelligent_attack, etc.)
3. ✅ Profile performance (CPU usage, FPS)
4. ✅ Optimize query caching
5. ✅ Add spatial partitioning for player detection

**Success Criteria:**
- 100+ NPCs at 60 FPS
- CPU usage < 10% for NPC AI
- All behaviors preserved
- No memory leaks

---

## Performance Targets

### Current (Behavior Trees)
- **20 NPCs**: 45-55 FPS
- **50 NPCs**: 25-35 FPS
- **100 NPCs**: 10-15 FPS (unplayable)

### Target (Full ECS)
- **20 NPCs**: 60 FPS
- **50 NPCs**: 60 FPS
- **100 NPCs**: 50-60 FPS
- **200 NPCs**: 40-50 FPS

### Key Optimizations
1. **Batch Processing** - Process all NPCs in single loop (data locality)
2. **Query Caching** - Use `.cached()` for frequently used queries
3. **Update Throttling** - Run expensive systems at 4-8 Hz, not 60 Hz
4. **Shared Resources** - Share paths, player lists between NPCs
5. **Spatial Partitioning** - Grid-based player detection (O(1) instead of O(n))
6. **Component Reuse** - Avoid allocating new tables every frame

---

## Testing Strategy

### Unit Tests (Per System)
- Movement patterns produce correct directions
- Pathfinding generates valid waypoints
- Skill scoring selects appropriate skills
- Defense probabilities match expected values

### Integration Tests (Multiple Systems)
- Guard spawns → wanders → detects player → chases → attacks → returns to idle
- Bandit spawns → wanders → gets attacked → enters aggressive → uses skills → dies
- Multiple NPCs share paths to same destination
- NPCs avoid each other (collision avoidance)

### Performance Tests
- 20/50/100/200 NPC stress tests
- CPU profiling (MicroProfiler)
- Memory profiling (Developer Console)
- Frame time analysis

### Behavior Validation
- Guards use structured attack patterns
- NPCs parry M1s 40% of time
- NPCs use guard breaks when player blocks
- NPCs flee when low health
- Aggressive mode timeout works (60s)

---

## Rollback Plan

If migration fails or introduces critical bugs:

1. **Keep Behavior Trees** - Behavior tree code remains in repository
2. **Toggle System** - Add `USE_ECS_AI = false` flag to disable ECS systems
3. **Revert Components** - Remove ECS-only components if needed
4. **Fallback Priority** - Behavior trees check `BehaviorTreeOverride` flag

---

## Success Metrics

1. ✅ **Performance**: 100+ NPCs at 60 FPS
2. ✅ **Behavior Preservation**: All NPC behaviors match behavior tree system
3. ✅ **Code Quality**: Systems are modular, well-documented, maintainable
4. ✅ **No Regressions**: Guards, Bandits, Wanderers behave identically
5. ✅ **Scalability**: Can add new NPC types easily

---

## Conclusion

This migration plan provides a complete roadmap for converting Ironveil's NPC behavioral system to a high-performance ECS architecture while preserving all existing functionality.

**Key Principles:**
- Incremental migration (don't break existing systems)
- Performance-first design (batch processing, caching)
- Faithful logic preservation (migrate, don't redesign)
- Comprehensive testing (unit, integration, performance)

**Timeline:** 5 weeks for full migration

**Risk Level:** Medium (behavior trees remain as fallback)

---

**Next Steps:** Begin Phase 1 implementation with movement pattern system.
