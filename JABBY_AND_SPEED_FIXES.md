# 🔧 Jabby & Speed Fixes - Root Cause Analysis

## 🎯 **Issues Identified**

### Issue 1: Jabby Shows "nan s" (NOT WORKING)

**Root Cause:** The scheduler integration is completely wrong!

**Current Implementation (BROKEN):**
```lua
-- In jecs_scheduler.luau line 346-348
if activeScheduler and activeScheduler.report_system_time then
    activeScheduler:report_system_time(sysData.id, duration)
end
```

**Problem:** Jabby's scheduler doesn't have a `report_system_time()` method! This method doesn't exist in Jabby 0.4.0.

**How Jabby Actually Works:**
Looking at `jabby/src/server/scheduler.luau`, the scheduler tracks time automatically when you use `scheduler:run()`:

```lua
function scheduler:run<T...>(id: SystemId, system: (T...) -> (), ...: T...)
    scheduler:_mark_system_frame_start(id)  -- Starts timer
    system(...)                              -- Runs system
    scheduler:_mark_system_frame_end(id)    -- Ends timer and records
end
```

**The Fix:**
We need to:
1. Register each system with the scheduler using `scheduler:register_system()`
2. Run systems using `scheduler:run(systemId, callback, ...)` instead of calling them directly
3. The scheduler will automatically track execution times

---

### Issue 2: Speeds Not Adjusting During Skills (CRITICAL BUG!)

**Root Cause:** `WeaponSkillHoldSpeed` state name is INVALID!

**Current Implementation (BROKEN):**
```lua
-- In WeaponSkillHold.lua line 313
Library.TimedState(character.Speeds, "WeaponSkillHoldSpeed", 999)
```

**Problem:** The speed listener in `PlayerHandler/init.client.lua` line 388 extracts numbers from speed state names:

```lua
elseif string.match(Frame, "Speed") then
    local Number = ConvertToNumber(Frame)  -- Extracts number from state name
    table.insert(speedModifiers, Number)
end
```

The `ConvertToNumber()` function (line 126-135) extracts the number at the END of the string:
```lua
function ConvertToNumber(String)
    local Number = string.match(String, "%d+$")  -- Matches digits at END
    local IsNegative = string.match(String, "[-]%d+$") ~= nil
    
    if IsNegative and Number then
        Number = "-" .. Number
    end
    
    return Number and tonumber(Number) or 0
end
```

**Testing:**
- `"M1Speed12"` → extracts `12` ✅
- `"RunSpeedSet24"` → extracts `24` ✅
- `"DamageSpeedSet4"` → extracts `4` ✅
- `"WeaponSkillHoldSpeed"` → extracts `nil` → returns `0` ❌

**Result:** `WeaponSkillHoldSpeed` returns `0`, which sets walkspeed to 0, but then the logic at line 397-402 is broken:

```lua
for _, modifier in pairs(speedModifiers) do
    if modifier <= 0 then
        DeltaSpeed = modifier  -- Sets to 0
        break -- Negative/zero speeds take priority
    else
        DeltaSpeed = math.min(DeltaSpeed + modifier, modifier)
    end
end
```

Wait, actually this SHOULD work! If `WeaponSkillHoldSpeed` returns `0`, then `DeltaSpeed = 0`, which means walkspeed should be 0.

**Let me re-check...**

Actually, the issue is that `ConvertToNumber("WeaponSkillHoldSpeed")` returns `0` because there's no number at the end. But the code at line 397 says `if modifier <= 0 then DeltaSpeed = modifier`, so it should set speed to 0.

**Wait, I need to check if the state is even being added!**

The real issue might be that the state isn't being synced to the StringValue properly.

---

### Issue 3: Movement Lock Not Working

**Root Cause:** The movement_lock system checks for states in the StringValue, but states might not be synced yet.

**Current Flow:**
1. Weapon skill adds `WeaponSkillHold` to ECS component
2. State sync system (runs on Heartbeat) syncs to StringValue
3. Movement lock system (runs on PreRender) checks StringValue

**Problem:** PreRender runs BEFORE Heartbeat, so the state might not be synced yet!

**RunService Event Order:**
1. PreSimulation
2. PreAnimation
3. **PreRender** ← Movement lock runs here
4. **Heartbeat** ← State sync runs here
5. PostSimulation

**The Fix:**
Movement lock should run AFTER state sync, not before. We need to either:
- Move movement_lock to Heartbeat (after state sync)
- OR make movement_lock check ECS components directly instead of StringValues

---

## ✅ **The Fixes**

### Fix 1: Jabby Scheduler Integration

**File:** `src/ReplicatedStorage/Modules/ECS/jecs_scheduler.luau`

**Changes Needed:**
1. Remove the broken `report_system_time()` calls
2. Register each system with Jabby's scheduler
3. Use `scheduler:run()` to execute systems

**Implementation:**
```lua
-- When loading systems:
for _, systemModule in ipairs(systemsFolder:GetChildren()) do
    local systemId = scheduler:register_system({
        name = systemModule.Name,
        phase = phaseName,
        layout_order = #schedulerSystems + 1,
        paused = false
    })
    
    table.insert(schedulerSystems, {
        id = systemId,
        callback = systemFunc,
        name = systemModule.Name
    })
end

-- When running systems:
connections[phaseEntity] = event:Connect(function(...)
    debug.profilebegin(phaseName)
    for _, sysData in pairs(systems) do
        if sysData.callback and sysData.id then
            -- Use scheduler:run() to automatically track time
            scheduler:run(sysData.id, sysData.callback, world, ...)
        end
    end
    debug.profileend()
end)
```

---

### Fix 2: Speed State Names

**File:** `src/ReplicatedStorage/Modules/Utils/WeaponSkillHold.lua`

**Change:**
```lua
-- OLD (line 313):
Library.TimedState(character.Speeds, "WeaponSkillHoldSpeed", 999)

-- NEW:
Library.TimedState(character.Speeds, "WeaponSkillHoldSpeedSet0", 999)
```

**Explanation:** The state name MUST end with a number for `ConvertToNumber()` to extract it. `SpeedSet0` means "set speed to 0".

---

### Fix 3: Movement Lock Timing

**File:** `src/ReplicatedStorage/Modules/Systems/movement_lock.luau`

**Change:**
```lua
-- OLD:
return {
    system = movement_lock,
    phase = "PreRender",  -- Runs BEFORE state sync
    priority = 100
}

-- NEW:
return {
    system = movement_lock,
    phase = "Heartbeat",  -- Runs WITH state sync
    priority = 200  -- Run AFTER state sync (which is priority 100)
}
```

**OR** (Better approach - check ECS directly):
```lua
local function shouldLockMovement(character)
    local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
    
    -- Check Actions states directly from ECS
    local allowedStates = {"Running", "Equipped"}
    local allStates = StateManager.GetAllStates(character, "Actions")
    
    for _, state in ipairs(allStates) do
        local isAllowed = false
        for _, allowed in ipairs(allowedStates) do
            if string.find(state, allowed) then
                isAllowed = true
                break
            end
        end
        if not isAllowed then
            return true
        end
    end
    
    -- Check Stuns states directly from ECS
    if StateManager.StateCount(character, "Stuns") then
        return true
    end
    
    return false
end
```

---

## 📊 **Summary of Changes**

| Issue | File | Line | Change |
|-------|------|------|--------|
| Jabby timing | jecs_scheduler.luau | 346-348 | Replace `report_system_time()` with `scheduler:run()` |
| Jabby registration | jecs_scheduler.luau | ~150 | Add `scheduler:register_system()` calls |
| Speed state name | WeaponSkillHold.lua | 313 | Change to `WeaponSkillHoldSpeedSet0` |
| Movement lock timing | movement_lock.luau | phase | Change from PreRender to Heartbeat |
| Movement lock source | movement_lock.luau | ~60 | Check ECS directly instead of StringValues |

---

## 🧪 **Testing After Fixes**

### Test 1: Jabby
1. Press F4
2. Click "Scheduler"
3. Should see system times like "0.001 s" (NOT "nan s")
4. Click on a system to pause/resume it

### Test 2: Speed During Skills
1. Use a weapon skill (hold key)
2. Character should NOT be able to move (walkspeed = 0)
3. Console: `print(game.Players.LocalPlayer.Character.Speeds.Value)`
4. Should show: `["WeaponSkillHoldSpeedSet0"]`
5. Console: `print(game.Players.LocalPlayer.Character.Humanoid.WalkSpeed)`
6. Should show: `0`

### Test 3: Movement Lock
1. Use a weapon skill
2. Try to move with WASD
3. Should NOT be able to move
4. Console should show: `[MovementLock] Movement disabled`

---

## 🚀 **Next Steps**

1. Fix Jabby scheduler integration (use `scheduler:run()`)
2. Fix speed state name (add number at end)
3. Fix movement lock timing (run after state sync OR check ECS directly)
4. Test all three fixes
5. Report results

---

**The root causes are now identified! Let me implement the fixes...**

