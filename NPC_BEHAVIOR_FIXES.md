# NPC Behavior Fixes - Wandering and Blocking Issues

## Overview
This document details the fixes applied to resolve two critical NPC behavior issues:
1. NPCs wandering and getting aggro'd without being attacked
2. NPCs getting stuck in blocking state

---

## Issue 1: NPCs Wandering/Aggroing Without Being Hit

### Problem
After making NPCs aggressive by default to improve combat responsiveness, **all NPCs** (including passive wandering NPCs) would immediately aggro onto players within their capture distance, even without being attacked.

**Root Cause:**
- [mobs.luau:285-286](src/ServerScriptService/Systems/mobs.luau#L285-L286) set `isAggressive=true` for ALL NPCs
- [npc_targeting_ecs.luau:318-320](src/ServerScriptService/Systems/npc_targeting_ecs.luau#L318-L320) checks `isPassive` before acquiring targets
- Result: All NPCs with `captureDistance > 0` would hunt players immediately

### Solution
**Conditional Aggressive Mode** - Only set NPCs aggressive if they have a capture distance configured.

**File:** [mobs.luau:283-298](src/ServerScriptService/Systems/mobs.luau#L283-L298)

**Before:**
```lua
-- NPCCombatState (CHANGED: Start aggressive for faster reactions)
world:set(e, comps.NPCCombatState, {
    isPassive = false, -- CHANGED: Start aggressive, not passive
    isAggressive = true, -- CHANGED: Start aggressive immediately
    hasBeenAttacked = false,
    -- ...
})
```

**After:**
```lua
-- NPCCombatState (FIXED: Only start aggressive if they have capture range > 0)
-- This prevents wandering NPCs from aggroing without being attacked
local shouldStartAggressive = captureDistance > 0
world:set(e, comps.NPCCombatState, {
    isPassive = not shouldStartAggressive, -- FIXED: Passive by default unless capture range set
    isAggressive = shouldStartAggressive,  -- FIXED: Only aggressive if they hunt players
    hasBeenAttacked = false,
    -- ...
})
```

### Impact
- ✅ **Wandering NPCs remain passive** until attacked (captureDistance = 0)
- ✅ **Combat NPCs are aggressive** immediately (captureDistance > 0)
- ✅ **Proper behavior distinction** between NPC types
- ✅ **Guards/enemies still hunt players** within their configured range

---

## Issue 2: NPCs Stuck Blocking

### Problem
Guards would enter blocking state and remain stuck blocking indefinitely, unable to transition to other states or attack.

**Root Cause:**
- [npc_guard_pattern_ecs.luau:97-98](src/ServerScriptService/Systems/npc_guard_pattern_ecs.luau#L97-L98) continuously checked if player was attacking
- No cooldown between blocks → guard would repeatedly trigger block
- Block animation/state would overlap and never release properly

### Solution 1: Block Cooldown in Guard Pattern
Added **1-second cooldown** between blocks to prevent rapid re-triggering.

**File:** [npc_guard_pattern_ecs.luau:95-107](src/ServerScriptService/Systems/npc_guard_pattern_ecs.luau#L95-L107)

**Before:**
```lua
if currentState == GuardPatterns.DEFENSIVE then
    -- IMPROVED: Less defensive - only block when player is very close
    if PlayerStateDetector.IsAttacking(target) and distance < 8 then
        skillToUse = "Block"
    else
        -- Be more aggressive - switch to counter earlier
        return false
    end
```

**After:**
```lua
if currentState == GuardPatterns.DEFENSIVE then
    -- FIXED: Add cooldown to prevent getting stuck blocking
    local now = os.clock()
    local timeSinceLastBlock = now - (combatState.lastBlockTime or 0)

    -- Only block if player is attacking AND we haven't blocked recently (1s cooldown)
    if PlayerStateDetector.IsAttacking(target) and distance < 8 and timeSinceLastBlock > 1.0 then
        skillToUse = "Block"
        combatState.lastBlockTime = now
    else
        -- Be more aggressive - switch to counter earlier
        return false
    end
```

### Solution 2: Failsafe Block Release
Added **1.5-second failsafe** to force block release even if normal release fails.

**File:** [npc_defense_ecs.luau:134-166](src/ServerScriptService/Systems/npc_defense_ecs.luau#L134-L166)

**Before:**
```lua
mainConfig.InitiateBlock(true)

-- Release block after 0.5s
task.delay(0.5, function()
    if character and character.Parent and mainConfig.InitiateBlock then
        -- Don't release if guard broken or stunned
        if not StateManager.StateCheck(character, "Stuns", "BlockBreakStun")
            and not StateManager.StateCheck(character, "Stuns", "GuardbreakStun") then
            mainConfig.InitiateBlock(false)
        end
    end
end)
```

**After:**
```lua
mainConfig.InitiateBlock(true)

-- Release block after 0.5s
task.delay(0.5, function()
    if character and character.Parent and mainConfig.InitiateBlock then
        -- Don't release if guard broken or stunned
        if not StateManager.StateCheck(character, "Stuns", "BlockBreakStun")
            and not StateManager.StateCheck(character, "Stuns", "GuardbreakStun") then
            mainConfig.InitiateBlock(false)
        end
    end
end)

-- FIXED: Failsafe - force release after 1.5s to prevent getting stuck
task.delay(1.5, function()
    if character and character.Parent and mainConfig.InitiateBlock then
        mainConfig.InitiateBlock(false)
    end
end)
```

### Impact
- ✅ **Guards can't spam block** - 1s cooldown between blocks
- ✅ **Block always releases** - failsafe ensures release after 1.5s max
- ✅ **More aggressive combat** - Guards spend less time blocking
- ✅ **State machine works properly** - Proper transitions between DEFENSIVE → COUNTER → PRESSURE

---

## Combined Impact

### Before Fixes:
- ❌ Wandering NPCs would aggro players without provocation
- ❌ Guards stuck blocking indefinitely
- ❌ Poor combat flow - too defensive
- ❌ Confusing NPC behavior (passive NPCs hunting)

### After Fixes:
- ✅ **Proper NPC type distinction** - Wanderers stay passive, guards hunt
- ✅ **Guards block strategically** - Only when needed with proper cooldown
- ✅ **Always recovers from block** - Failsafe prevents stuck states
- ✅ **Better combat pacing** - More attacking, less blocking
- ✅ **Clear behavioral logic** - Capture distance determines aggression

---

## Technical Details

### Aggressive Mode Logic:
```lua
-- NPC becomes aggressive if:
1. captureDistance > 0 (configured to hunt players) OR
2. hasBeenAttacked = true (attacked by player)

-- Targeting system only finds targets if:
1. NOT isPassive (prevents passive NPCs from hunting) OR
2. hasBeenAttacked = true (allows passive NPCs to retaliate)
```

### Block Cooldown Logic:
```lua
-- Block triggers if ALL conditions met:
1. currentState == GuardPatterns.DEFENSIVE
2. PlayerStateDetector.IsAttacking(target) = true
3. distance < 8 studs
4. (os.clock() - lastBlockTime) > 1.0 seconds ← NEW COOLDOWN

-- Block releases at:
1. 0.5s after block (normal release) OR
2. 1.5s after block (failsafe release) ← NEW FAILSAFE
```

---

## Testing Recommendations

### Test 1: Wandering NPC Behavior
1. Spawn passive wandering NPCs (captureDistance = 0)
2. Walk near them WITHOUT attacking
3. **Expected:** NPCs continue wandering, do NOT aggro
4. Attack an NPC
5. **Expected:** Attacked NPC enters combat, others remain passive

### Test 2: Guard Aggression
1. Spawn guards with captureDistance > 0
2. Walk within capture range
3. **Expected:** Guards immediately detect and chase player
4. **Expected:** Guards attack without needing to be hit first

### Test 3: Block Recovery
1. Engage a guard in combat
2. Attack guard to trigger block
3. **Expected:** Guard blocks for ~0.5s, then transitions to counter
4. Continue attacking
5. **Expected:** Guard blocks again after 1s cooldown (not immediately)
6. **Expected:** Block always releases within 1.5s maximum

---

## Files Modified

1. **[mobs.luau:283-298](src/ServerScriptService/Systems/mobs.luau#L283-L298)**
   - Added conditional aggressive mode based on captureDistance

2. **[npc_guard_pattern_ecs.luau:95-107](src/ServerScriptService/Systems/npc_guard_pattern_ecs.luau#L95-L107)**
   - Added 1s block cooldown to prevent spam blocking

3. **[npc_defense_ecs.luau:134-166](src/ServerScriptService/Systems/npc_defense_ecs.luau#L134-L166)**
   - Added 1.5s failsafe block release

---

## Summary

These fixes restore proper NPC behavioral distinctions while maintaining the improved combat responsiveness from previous optimizations:

1. 🎯 **Smart Aggression** - Only combat NPCs hunt players by default
2. 🛡️ **Strategic Blocking** - Guards block tactically with cooldown
3. ✅ **Guaranteed Recovery** - Failsafe prevents stuck states
4. ⚡ **Fast Reactions** - NPCs still respond quickly (20 Hz updates)
5. 🎮 **Better Gameplay** - More challenging combat without annoying behavior

The system now properly balances:
- **Passive exploration** (wandering NPCs don't interfere)
- **Active combat** (guards immediately engage within range)
- **Dynamic defense** (blocks when needed, not constantly)
- **Aggressive offense** (more attacks, less blocking)
