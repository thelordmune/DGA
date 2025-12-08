# Guard Movement Bug Fix - ECS System

## Problem Summary
Guards (LeftGuard, RightGuard) were moving around randomly when they should remain idle until attacked.

## Root Cause
The ECS brain system ([mob_brain_ecs.luau](src/ServerScriptService/Systems/mob_brain_ecs.luau)) was processing ALL combat NPCs, including guards, without respecting their passive state. The system would default to "wander" behavior when no player was nearby, causing guards to move randomly.

### Why Guards Were Treated as Combat NPCs
Guards are configured with:
- `Combat.Light = true` ([LeftGuard.lua:87](src/ReplicatedStorage/Regions/Forest/Npcs/LeftGuard.lua#L87))
- `Weapons.Enabled = true` ([LeftGuard.lua:91](src/ReplicatedStorage/Regions/Forest/Npcs/LeftGuard.lua#L91))
- `IsPassive = true` (default state - [LeftGuard.lua:35](src/ReplicatedStorage/Regions/Forest/Npcs/LeftGuard.lua#L35))

This causes `isCombatNPC()` to return `true`, which initializes them with full ECS AI components.

## Solution Implemented

### 1. Added NPCCombatState Component Import
**File:** [mob_brain_ecs.luau:36](src/ServerScriptService/Systems/mob_brain_ecs.luau#L36)

Added `NPCCombatState` component to access passive/aggressive state.

### 2. Added Passive State Check in Brain Loop
**File:** [mob_brain_ecs.luau:238-277](src/ServerScriptService/Systems/mob_brain_ecs.luau#L238-L277)

```lua
-- Check if NPC is passive (guards/NPCs that shouldn't move until attacked)
local npcState = world:get(e, NPCCombatState)
local isPassive = npcState and npcState.isPassive
local isAggressive = npcState and npcState.isAggressive
local hasBeenAttacked = npcState and npcState.hasBeenAttacked

-- PASSIVE GUARD LOGIC: If passive and hasn't been attacked, stay idle
-- Only move/react if:
-- 1. NPC is aggressive (has been attacked), OR
-- 2. NPC is not passive (regular combat NPC that always moves)
if isPassive and not isAggressive and not hasBeenAttacked then
    -- Guard is passive - stay completely idle
    world:set(e, Locomotion, {
        dir = Vector3.zero,
        speed = 0,
    })

    -- Update hitbox attributes for debugging
    local hitbox = world:get(e, Hitbox)
    if hitbox then
        hitbox:SetAttribute("HasTarget", false)
        hitbox:SetAttribute("MobState", "idle_passive")
    end

    continue
end
```

### 3. Aggressive Mode Trigger (Already Implemented)
**File:** [npc_targeting_ecs.luau:96-109](src/ServerScriptService/Systems/npc_targeting_ecs.luau#L96-L109)

The targeting system already handles setting guards to aggressive when attacked:

```lua
if attacked then
    -- Enter aggressive mode
    if not combatState.isAggressive then
        combatState.isAggressive = true
        combatState.isPassive = false
        combatState.hasBeenAttacked = true

        -- Increase detection ranges
        config.captureDistance = math.max(config.captureDistance, 120)
        config.letGoDistance = math.max(config.letGoDistance, 150)

        world:set(entity, comps.NPCCombatState, combatState)
        world:set(entity, comps.NPCConfig, config)
    end
end
```

## How It Works Now

### Guard Behavior Flow

1. **Initial State** (Spawn)
   - Guard spawns with `NPCCombatState.isPassive = true`
   - ECS brain checks passive state → sets `Locomotion` to zero
   - Guard remains idle at spawn point

2. **When Attacked**
   - `npc_targeting_ecs.luau` detects `Damage_Log` entries
   - Sets `isAggressive = true`, `isPassive = false`, `hasBeenAttacked = true`
   - Increases detection ranges to 120/150

3. **Aggressive State**
   - ECS brain sees `isAggressive = true` → bypasses passive check
   - Guard enters normal AI state machine (chase/attack player)
   - Uses full ECS movement and combat AI

4. **Return to Passive** (After 60 seconds)
   - Behavior tree `is_aggressive` condition times out
   - Sets `mainConfig.States.AggressiveMode = false`
   - Guard returns to idle state

## ECS vs Behavior Tree Responsibilities

### ECS System Controls:
✅ **All movement** for combat NPCs (guards included)
✅ **Target detection** and tracking
✅ **Movement patterns** (chase, flee, circle, wander, idle)
✅ **Passive/aggressive state** management

### Behavior Tree Controls:
✅ **Combat actions** (M1 attacks, skills, blocks, dashes)
✅ **Guard-specific attack patterns** (defensive stance, counter-attacks)
✅ **Timeout logic** (return to passive after 60s)

### Key Integration Points:
- `idle_at_spawn.lua` returns `false` for combat NPCs (line 7-9)
- `follow_enemy/init.lua` returns `true` without controlling movement for combat NPCs (line 170-172)
- Behavior tree never interferes with ECS movement system

## Testing Checklist

- [ ] Guards remain idle when spawned
- [ ] Guards do not wander or move randomly
- [ ] Guard reacts when hit by player
- [ ] Guard chases and attacks the player who hit them
- [ ] Guard uses ECS movement (smooth, reactive)
- [ ] Guard returns to idle after 60 seconds of no combat
- [ ] Regular combat NPCs (Bandits, etc.) still behave normally

## Performance Benefits

Using ECS for guard movement provides:
- ⚡ **8 Hz brain updates** vs frame-by-frame behavior tree ticks
- 🎯 **Pure ECS queries** - no CollectionService tag iteration
- 🚀 **Batch processing** of all NPCs in single loop
- 💾 **Component-based state** - no table lookups in MainConfig

## Files Modified

1. **[mob_brain_ecs.luau](src/ServerScriptService/Systems/mob_brain_ecs.luau)**
   - Added `NPCCombatState` component import (line 36)
   - Added passive state check in brain loop (lines 238-277)

## Files Referenced (No Changes)

1. **[npc_targeting_ecs.luau](src/ServerScriptService/Systems/npc_targeting_ecs.luau)** - Handles attack detection and aggressive mode
2. **[mobs.luau](src/ServerScriptService/Systems/mobs.luau)** - Initializes NPCCombatState with `isPassive = true`
3. **[LeftGuard.lua](src/ReplicatedStorage/Regions/Forest/Npcs/LeftGuard.lua)** - Guard configuration
4. **[Guard_BehaviorTree.lua](src/ReplicatedStorage/NpcHelper/Behaviors/Forest/Guard_BehaviorTree.lua)** - Behavior tree (combat actions only)
5. **[idle_at_spawn.lua](src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Movement/idle_at_spawn.lua)** - Returns false for combat NPCs
6. **[follow_enemy/init.lua](src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Combat/Following/follow_enemy/init.lua)** - Returns true without moving combat NPCs

## Debug Commands

To verify guard state in-game:
```lua
-- Check if guard is passive
local guard = workspace.World.Live:FindFirstChild("LeftGuard")
local entity = RefManager.entity.find(guard)
local state = world:get(entity, comps.NPCCombatState)
print("isPassive:", state.isPassive, "isAggressive:", state.isAggressive)

-- Check locomotion
local loco = world:get(entity, comps.Locomotion)
print("Movement:", loco.dir, "Speed:", loco.speed)

-- Check hitbox attributes
local hrp = guard:FindFirstChild("HumanoidRootPart")
print("MobState:", hrp:GetAttribute("MobState"))
```

## Next Steps

1. **Test in-game** - Verify guards stay idle until attacked
2. **Monitor performance** - Check that ECS system maintains 8 Hz update rate
3. **Validate combat** - Ensure guards use proper attack patterns when aggressive
4. **Check return to passive** - Verify 60-second timeout works correctly

---

**Status:** ✅ **IMPLEMENTED** - Ready for testing
**Date:** 2025-12-01
**System:** ECS Combat AI
