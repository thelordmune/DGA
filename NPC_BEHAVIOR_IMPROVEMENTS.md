# NPC Behavior Improvements

## Overview
This document details the behavioral improvements made to the NPC combat systems to make them more reactive, aggressive, and challenging.

---

## Key Improvements

### 1. **Reduced Circle Strafe Radius**
**Problem:** NPCs circled too far from players (20 studs), making them easy to avoid and less threatening.

**Solution:** Reduced `maxStrafeRadius` from **20 → 12 studs**

**File:** [mobs.luau:222](src/ServerScriptService/Systems/mobs.luau#L222)

**Impact:**
- NPCs stay closer during combat
- More pressure on the player
- Harder to escape from NPC attacks

---

### 2. **Aggressive by Default**
**Problem:** NPCs started in passive mode and were slow to react to players.

**Solution:** Changed initial state to **aggressive** instead of passive

**File:** [mobs.luau:285-286](src/ServerScriptService/Systems/mobs.luau#L285-L286)

**Before:**
```lua
isPassive = true,
isAggressive = false,
```

**After:**
```lua
isPassive = false,   -- CHANGED: Start aggressive
isAggressive = true, -- CHANGED: Start aggressive immediately
```

**Impact:**
- NPCs immediately engage players within detection range
- No delay before attacking
- More challenging combat encounters

---

### 3. **Dash Mechanic for Dodging**
**Problem:** NPCs used LinearVelocity for dodging, which looked unnatural and didn't match player dash mechanics.

**Solution:** Implemented proper dash using **Locomotion system** with speed boost + animation

**File:** [npc_defense_ecs.luau:162-211](src/ServerScriptService/Systems/npc_defense_ecs.luau#L162-L211)

**Features:**
- Uses locomotion for smooth dash movement
- Speed: **60 studs/s** (brief burst)
- Duration: **0.4 seconds**
- Sets `Dashing` component for animation triggers
- Maintains IFrame during dash
- Random direction selection (right/left/back)

**Code:**
```lua
-- IMPROVED: Use locomotion system for dash (brief speed boost)
local dashSpeed = 60 -- Fast dash speed
world:set(entity, comps.Locomotion, {
    dir = dodgeVector.Unit,
    speed = dashSpeed
})

-- Set dash component to trigger animation
world:set(entity, comps.Dashing, true)
```

**Impact:**
- More responsive dodging
- Looks like player dash
- NPCs can dash away from AOE attacks
- More dynamic combat

---

### 4. **Faster Reaction Speed**
**Problem:** NPCs had slow update rates (8-15 Hz), making them sluggish to react.

**Solution:** Increased update frequencies across all systems

| System | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Targeting** | 15 Hz (0.067s) | **20 Hz (0.05s)** | +33% faster |
| **Skill Scoring** | 15 Hz (0.067s) | **20 Hz (0.05s)** | +33% faster |
| **Movement Pattern** | 8 Hz (0.125s) | **15 Hz (0.067s)** | +88% faster |
| **Wander** | 8 Hz (0.125s) | **10 Hz (0.1s)** | +25% faster |

**Files:**
- [npc_targeting_ecs.luau:45-47](src/ServerScriptService/Systems/npc_targeting_ecs.luau#L45-L47)
- [npc_skill_scoring_ecs.luau:209-211](src/ServerScriptService/Systems/npc_skill_scoring_ecs.luau#L209-L211)
- [npc_movement_pattern_ecs.luau:33-35](src/ServerScriptService/Systems/npc_movement_pattern_ecs.luau#L33-L35)
- [npc_wander_ecs.luau:31-33](src/ServerScriptService/Systems/npc_wander_ecs.luau#L31-L33)

**Impact:**
- NPCs detect players faster
- Quicker skill selection
- More responsive movement
- Less "standing around" behavior

---

### 5. **Less Defensive Guard Behavior**
**Problem:** Guards spent too much time blocking, making them passive.

**Solution:**
- Reduced defensive stance duration (1.0s → **0.5s**)
- Only block when player is **very close** (12 studs → **8 studs**)

**File:** [npc_guard_pattern_ecs.luau:50-52, 96-101](src/ServerScriptService/Systems/npc_guard_pattern_ecs.luau#L50-L52)

**Before:**
```lua
if timeInState > 1.0 and distance < 10 then  -- Slow transition
    return GuardPatterns.COUNTER
end

if PlayerStateDetector.IsAttacking(target) and distance < 12 then
    skillToUse = "Block"
```

**After:**
```lua
if timeInState > 0.5 and distance < 10 then  -- FASTER transition
    return GuardPatterns.COUNTER
end

-- IMPROVED: Less defensive - only block when player is very close
if PlayerStateDetector.IsAttacking(target) and distance < 8 then
    skillToUse = "Block"
```

**Impact:**
- Guards attack more often
- Less blocking, more aggression
- Faster combat pace

---

## Combined Impact

### Before:
- ❌ NPCs circled too far away (20 studs)
- ❌ Started passive, slow to engage
- ❌ No proper dash mechanic
- ❌ Sluggish reactions (8-15 Hz updates)
- ❌ Too defensive (blocking constantly)

### After:
- ✅ Tighter circle strafe (12 studs)
- ✅ Aggressive by default
- ✅ Proper dash with speed burst + animation
- ✅ Fast reactions (15-20 Hz updates)
- ✅ More offensive combat style

---

## Gameplay Changes

### Player Experience:
1. **More Challenging** - NPCs are now more aggressive and harder to avoid
2. **Faster Combat** - Less waiting, more action
3. **Better AI** - NPCs dash to avoid attacks and stay close
4. **Reactive Enemies** - NPCs respond quickly to player movements

### Combat Balance:
- **Tighter Engagement Range** - Stay close or lose combat advantage
- **Punishing Mistakes** - NPCs capitalize on openings faster
- **Dynamic Movement** - Dashing adds unpredictability
- **Aggressive Pressure** - Less defensive posturing, more attacking

---

## Performance Notes

Despite faster update rates, performance remains excellent due to optimizations:
- Spatial grid for targeting (from previous optimizations)
- Player state caching
- Query caching
- Obstacle check caching

The faster update rates primarily affect the **decision-making** systems, not rendering or physics.

---

## Testing Recommendations

1. **Spawn multiple NPCs** - Verify they engage immediately
2. **Test circle strafe** - Should feel tighter and more threatening
3. **Check dash mechanic** - NPCs should dash away from AOE attacks
4. **Observe guard behavior** - Should attack more, block less
5. **Monitor performance** - Should remain smooth despite faster updates

---

## Future Enhancements

1. **Dash Animation Hook** - Connect dash to specific animation tracks
2. **Difficulty Scaling** - Make update rates configurable per NPC type
3. **Combo Chains** - NPCs could use dash to extend combos
4. **Predictive Dashing** - Dash based on player attack patterns
5. **Formation Combat** - Multiple NPCs coordinate dashes

---

## Summary

These improvements transform NPCs from **passive observers** to **active combatants**. They now:

- 🎯 **Engage immediately** when players approach
- ⚡ **React faster** to player actions
- 🏃 **Dash dynamically** to dodge attacks
- 👊 **Attack more** and defend less
- 🎮 **Stay close** for intense combat

The result is **significantly more challenging and engaging** combat encounters!
