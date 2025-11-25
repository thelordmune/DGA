# NPC Movement System Fix - Summary

## Problem Identified

**Issue:** Combat NPCs were not moving with the new ECS systems enabled because:
1. **Behavior tree movement conditions** were calling `humanoid:Move()` every Heartbeat, overriding ECS movement
2. **Old `npc_movement_ecs.luau` system** was also running, conflicting with new RPGJECS-style ECS systems

## Solution Applied

### 1. ✅ Disabled Old NPC Movement System
**File:** `ironveil/src/ServerScriptService/Systems/npc_movement_ecs.luau`

**Action:** Renamed to `npc_movement_ecs.luau.disabled` to prevent it from loading

**Reason:** This old system was using different components (`NPCTarget`, `NPCConfig`, `NPCWander`) and calling `humanoid:Move()` directly, conflicting with the new RPGJECS-style ECS systems.

### 2. ✅ Fixed Behavior Tree Movement Conditions
**Files Modified:**
- `wander.lua`
- `walk_to_spawn.lua`
- `run_away.lua`
- `wander_point.lua`
- `idle_at_spawn.lua`
- `dash.lua`

**Change Applied:** Added combat NPC check at the start of each movement condition:
```lua
-- Skip if this is a combat NPC (ECS AI handles movement)
local ECSBridge = require(game.ReplicatedStorage.NpcHelper.ECSBridge)
if ECSBridge.isCombatNPC(npc) then
    return false
end
```

**Result:** 
- Combat NPCs now use ECS movement exclusively
- Dialogue NPCs continue using behavior tree movement
- No more conflicts between systems

## System Architecture After Fix

### Combat NPC Movement Pipeline
```
mob_brain_ecs (8 Hz)
    ↓ Sets Locomotion component
mob_avoid_ecs (10 Hz)
    ↓ Adjusts Locomotion for separation
mob_movement_ecs (20 Hz)
    ↓ Executes movement via humanoid:Move()
NPC Model moves
```

### Dialogue NPC Movement Pipeline
```
Behavior Tree (Heartbeat)
    ↓ Movement conditions check isCombatNPC()
    ↓ Returns false for combat NPCs
    ↓ Calls humanoid:Move() for dialogue NPCs only
NPC Model moves
```

## Files Modified

### Disabled:
- `ironveil/src/ServerScriptService/Systems/npc_movement_ecs.luau` → `npc_movement_ecs.luau.disabled`

### Modified (Added Combat NPC Checks):
- `ironveil/src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Movement/wander.lua`
- `ironveil/src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Movement/walk_to_spawn.lua`
- `ironveil/src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Movement/run_away.lua`
- `ironveil/src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Movement/wander_point.lua`
- `ironveil/src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Movement/idle_at_spawn.lua`
- `ironveil/src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Movement/dash.lua`

## Testing Checklist

### ✅ Pre-Testing Setup
- [x] Old npc_movement_ecs.luau disabled
- [x] Behavior tree movement conditions updated with combat NPC checks
- [x] All movement conflicts resolved

### 🎮 In-Game Testing (TODO)
- [ ] Combat NPCs move correctly with ECS AI
- [ ] Combat NPCs wander when no target
- [ ] Combat NPCs chase players
- [ ] Combat NPCs don't overlap (avoidance works)
- [ ] Dialogue NPCs still move via behavior trees
- [ ] Dialogue NPCs can wander/idle
- [ ] No movement conflicts or stuttering

## Next Steps

1. **Test in-game** - Spawn combat NPCs and verify they move correctly
2. **Test dialogue NPCs** - Verify they still work with behavior tree movement
3. **Monitor console** - Check for any errors or warnings
4. **Performance test** - Verify no performance degradation

---

**Status:** ✅ Movement conflicts resolved. Ready for in-game testing.

