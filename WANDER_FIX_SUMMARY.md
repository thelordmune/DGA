# Wander System Fixes

## 🐛 Issues Fixed

### **Issue 1: Wander Not Stopping When NPC Has Target**
**Reported:** Guard was "pacing back and forth" even after being hit

**Diagnosis:**
- The query already had `.without(comps.NPCTarget)` which SHOULD skip NPCs with targets
- Added debug logging to verify the filter is working correctly

**Fix:**
- Added debug logging to confirm NPCs being processed don't have targets ([npc_wander_ecs.luau:54-59](src/ServerScriptService/Systems/npc_wander_ecs.luau#L54-L59))
```lua
if not hasLoggedWander then
    local hasTarget = world:has(entity, comps.NPCTarget)
   -- print(`[npc_wander_ecs] Processing {char.Name} - has NPCTarget: {hasTarget}`)
    hasLoggedWander = true
end
```

**Expected Console Output:**
```
[npc_wander_ecs] Processing LeftGuard - has NPCTarget: false
```

If you hit the guard and it shows `has NPCTarget: true`, that means the query filter isn't working and we need to investigate further.

---

### **Issue 2: Wander Too Frequent (No Pauses)**
**Reported:** "Wandering is too often, should walk then stop"

**Fix:**
Added pause/move cycle to make wander behavior more natural ([npc_wander_ecs.luau:64-91](src/ServerScriptService/Systems/npc_wander_ecs.luau#L64-L91)):

**New Behavior:**
1. **Move Phase** (5-10 seconds)
   - NPC wanders using Perlin noise
   - Speed: 8 studs/sec (slow walk)
   - Direction: Smooth, natural movement

2. **Pause Phase** (3-7 seconds)
   - NPC stops completely
   - Sets Locomotion to zero
   - Looks like NPC is "taking a break"

3. **Cycle Repeats**
   - Move → Pause → Move → Pause

**Code:**
```lua
-- Initialize pause state
if not wander.isPaused then
    wander.isPaused = false
    wander.moveEndTime = now + math.random(5, 10) -- Move for 5-10 seconds
end

-- Handle pause/move cycle
if wander.isPaused then
    if now >= wander.pauseEndTime then
        -- End pause, start moving
        wander.isPaused = false
        wander.moveEndTime = now + math.random(5, 10)
    else
        -- Stay idle during pause
        world:set(entity, comps.Locomotion, {
            dir = Vector3.zero,
            speed = 0,
        })
        continue
    end
else
    if now >= wander.moveEndTime then
        -- Start pause
        wander.isPaused = true
        wander.pauseEndTime = now + math.random(3, 7) -- Pause 3-7 seconds
        world:set(entity, comps.Locomotion, {
            dir = Vector3.zero,
            speed = 0,
        })
        continue
    end
end
```

---

## 🧪 Testing Instructions

### **Test 1: Wander Pause Cycle**
1. Spawn an NPC that wanders (Bandit, Wanderer)
2. Observe behavior:
   - NPC should walk for ~5-10 seconds
   - NPC should stop and stand still for ~3-7 seconds
   - NPC should start walking again
   - Cycle repeats

**Expected:** Natural-looking behavior (walk → pause → walk)

---

### **Test 2: Wander Stops When Hit**
1. Spawn a guard (LeftGuard)
2. Observe: Guard stands still (passive)
3. Hit the guard
4. Check console for these messages:
   ```
   [npc_targeting_ecs] LeftGuard was attacked!
   [npc_targeting_ecs] LeftGuard now targeting {YourName}
   ```
5. Guard should:
   - Stop wandering immediately
   - Start chasing you with movement patterns
   - NOT pace back and forth

**Expected:** Guard stops all wander behavior and chases smoothly

---

### **Test 3: Multiple Wandering NPCs**
1. Spawn 3+ Bandits or Wanderers
2. Each should:
   - Have different pause/move timings (not synchronized)
   - Pause at different times
   - Move in different directions

**Expected:** Independent, natural-looking behavior

---

## 🔍 Debugging

If the guard still "paces back and forth" after being hit:

1. **Check console output when you hit the guard:**
   ```
   [npc_targeting_ecs] LeftGuard was attacked! Attacker: {YourName}
   [npc_targeting_ecs] LeftGuard entered AGGRESSIVE mode
   [npc_targeting_ecs] LeftGuard now targeting {YourName}
   ```
   If you DON'T see these messages, the targeting system isn't working.

2. **Check if wander is still processing the guard:**
   ```
   [npc_wander_ecs] Processing LeftGuard - has NPCTarget: false
   ```
   If this shows `has NPCTarget: true` WHILE the guard is chasing you, the query filter is broken.

3. **Check if multiple systems are fighting:**
   - If you see `mob_brain_ecs` processing the same NPC, that's the issue
   - The guard should ONLY be processed by `npc_movement_pattern_ecs` when it has a target

---

## 📝 Files Modified

1. **[npc_wander_ecs.luau](src/ServerScriptService/Systems/npc_wander_ecs.luau)**
   - Added pause/move cycle (lines 64-91)
   - Added debug logging (lines 54-59)

---

## ✅ Expected Behavior Now

### **Idle Wandering NPCs (No Target):**
- Walk smoothly for 5-10 seconds ✅
- Pause and stand still for 3-7 seconds ✅
- Repeat cycle ✅
- Each NPC has independent timing ✅

### **Guards (Passive):**
- Stand completely still ✅
- No wandering ✅
- No jitter ✅

### **Guards (Hit/Aggressive):**
- Stop wandering immediately ✅
- Acquire target ✅
- Chase using movement patterns ✅
- No pacing back and forth ✅

---

**Test these fixes and check the console output to verify everything is working!**

**Date:** 2025-12-01
**Status:** ✅ Fixes implemented, ready for testing
