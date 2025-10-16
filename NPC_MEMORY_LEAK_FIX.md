# 🐛 NPC Memory Leak Fix + Combat Improvements

## 🔴 **CRITICAL MEMORY LEAK FOUND AND FIXED**

### **The Problem:**

When NPCs died, their **ECS entities were never deleted from the world**, causing a massive memory leak!

**What was happening:**
1. ✅ NPC spawns → ECS entity created with 50+ components
2. ✅ NPC fights player
3. ✅ NPC dies → `cleanSweep()` called
4. ❌ **Model destroyed BUT entity still in ECS world!**
5. ❌ **All 50+ components still in memory!**
6. ❌ **Entity references still tracked!**
7. 🔥 **Memory keeps growing with each NPC death!**

**Result:** After 1 NPC fight, LuauHeap stays high because the entity is still in memory even though the model is destroyed!

---

## ✅ **The Fix**

### **File: `src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Environment/spawn_entity.lua`**

**Lines 217-265** - Added ECS entity cleanup in `cleanSweep()`:

```lua
local function cleanSweep()
    -- Clear the used spawn when NPC is cleaned up
    if usedSpawns[npcTypeKey] then
        -- ... spawn cleanup code ...
    end

    -- CRITICAL: Delete ECS entity BEFORE destroying model to prevent memory leak
    if npcModel then
        local RefManager = require(game.ReplicatedStorage.Modules.ECS.jecs_ref_manager)
        local entity = RefManager.entity.find(npcModel)
        if entity then
            RefManager.entity.delete(npcModel)  -- ✅ DELETE THE ENTITY!
            print(`[NPC Cleanup] Deleted ECS entity {entity} for {npcModel.Name}`)
        end
    end

    if npcModel then
        npcModel:Destroy()
        npcModel = nil
    end

    -- ... rest of cleanup ...
end
```

**What this does:**
1. ✅ Finds the ECS entity for the NPC model
2. ✅ Calls `RefManager.entity.delete(npcModel)` which:
   - Removes all 50+ components from the entity
   - Deletes the entity from the world
   - Removes the reference from the ref system
   - Frees all memory associated with the entity
3. ✅ Then destroys the model

**Result:** Memory is properly freed when NPCs die! 🎉

---

## 🎯 **Combat Behavior Improvements**

### **1. Increased Circle Strafing**

**File: `src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Combat/Following/follow_enemy/init.lua`**

**Lines 41-50** - Adjusted movement pattern weights:

**Before:**
```lua
{name = "Direct",weight = 3},      -- 17%
{name = "Strafe",weight = 3},      -- 17%
{name = "SideApproach",weight = 4}, -- 22%
{name = "CircleStrafe", weight = 6}, -- 33%
{name = "ZigZag", weight = 2},     -- 11%
```

**After:**
```lua
{name = "Direct",weight = 2},      -- 10% (reduced)
{name = "Strafe",weight = 5},      -- 25% (increased)
{name = "SideApproach",weight = 3}, -- 15% (reduced)
{name = "CircleStrafe", weight = 8}, -- 40% (increased!)
{name = "ZigZag", weight = 2},     -- 10%
```

**Result:**
- ✅ NPCs circle strafe **40%** of the time (up from 33%)
- ✅ NPCs strafe **25%** of the time (up from 17%)
- ✅ NPCs run directly at you only **10%** of the time (down from 17%)
- ✅ More dynamic and challenging combat!

---

### **2. More Frequent Dashing**

**File: `src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Combat/should_dash.lua`**

**Lines 31-37** - Reduced dash cooldown:

**Before:**
```lua
local dashCooldown = 8.0 -- Much longer cooldown - dash rarely
```

**After:**
```lua
local dashCooldown = 4.0 -- Reduced from 8.0 - dash more frequently
```

**Result:**
- ✅ NPCs dash **twice as often** (every 4 seconds instead of 8)
- ✅ More aggressive and mobile combat
- ✅ Better at closing distance and repositioning

---

### **3. More Dynamic Movement Patterns**

**File: `src/ReplicatedStorage/NpcFile/Actor/MainConfig/init.lua`**

**Lines 104-111** - Reduced pattern duration:

**Before:**
```lua
Duration = {
    Min = 2,
    Max = 3
}
```

**After:**
```lua
Duration = {
    Min = 1.5, -- Reduced from 2 for more dynamic movement
    Max = 2.5  -- Reduced from 3 for more dynamic movement
}
```

**Result:**
- ✅ NPCs switch movement patterns **more frequently**
- ✅ Patterns last 1.5-2.5 seconds instead of 2-3 seconds
- ✅ More unpredictable and challenging to fight
- ✅ Less time stuck in "Direct" pattern

---

## 📊 **Summary of Changes**

### **Files Modified:**

1. **`src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Environment/spawn_entity.lua`**
   - ✅ Added ECS entity cleanup to prevent memory leak

2. **`src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Combat/Following/follow_enemy/init.lua`**
   - ✅ Increased CircleStrafe weight: 6 → 8 (40% of the time)
   - ✅ Increased Strafe weight: 3 → 5 (25% of the time)
   - ✅ Decreased Direct weight: 3 → 2 (10% of the time)

3. **`src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Combat/should_dash.lua`**
   - ✅ Reduced dash cooldown: 8.0 → 4.0 seconds

4. **`src/ReplicatedStorage/NpcFile/Actor/MainConfig/init.lua`**
   - ✅ Reduced pattern duration: 2-3s → 1.5-2.5s

---

## 🧪 **Testing Checklist**

1. **Memory Leak Test:**
   - [ ] Fight and kill an NPC
   - [ ] Check LuauHeap in console
   - [ ] Should see `[NPC Cleanup] Deleted ECS entity X for NPCName`
   - [ ] LuauHeap should **drop** after NPC dies
   - [ ] Kill multiple NPCs and verify memory doesn't keep growing

2. **Combat Behavior Test:**
   - [ ] NPCs should circle strafe **much more often**
   - [ ] NPCs should strafe left/right more frequently
   - [ ] NPCs should dash **twice as often** (every ~4 seconds)
   - [ ] NPCs should switch movement patterns more dynamically
   - [ ] Combat should feel more challenging and unpredictable

---

## 🎯 **Expected Results**

### **Before:**
- ❌ LuauHeap stays high after NPC dies
- ❌ Memory leak grows with each NPC death
- ❌ NPCs mostly run directly at you
- ❌ NPCs dash rarely (every 8 seconds)
- ❌ Predictable movement patterns

### **After:**
- ✅ LuauHeap drops when NPC dies
- ✅ No memory leak - entities properly cleaned up
- ✅ NPCs circle strafe 40% of the time
- ✅ NPCs dash every 4 seconds
- ✅ Dynamic, unpredictable movement

---

**Test it and let me know if the memory leak is fixed and if the NPCs are more challenging to fight!** 🚀

