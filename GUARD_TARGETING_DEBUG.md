# Guard Targeting Debug Guide

**Issue:** Guards don't follow player when attacked

---

## 🔍 Debug Steps

### Step 1: Verify Systems Are Running

When you start the server, check the console for these startup messages:

```
[npc_targeting_ecs] Processing LeftGuard
[npc_movement_pattern_ecs] Processing LeftGuard targeting nil
[mob_movement_ecs] Moving LeftGuard - dir: {0, 0, 0}, speed: 0
```

**If missing:** System isn't loading - check for errors on server start.

---

### Step 2: Attack the Guard

Hit the guard with M1 and check console for:

```
[npc_targeting_ecs] LeftGuard was attacked! Attacker: YourUsername
[npc_targeting_ecs] LeftGuard entered AGGRESSIVE mode
[npc_targeting_ecs] LeftGuard now targeting YourUsername
```

**If missing:** Targeting system isn't detecting hits - see "Targeting Not Working" section below.

**If present:** Targeting is working, issue is with movement systems.

---

### Step 3: Verify Movement System Picks Up Target

After attacking, check console for:

```
[npc_movement_pattern_ecs] Processing LeftGuard targeting YourUsername
```

**If missing:** Movement pattern system isn't seeing the target - see "Movement System Not Running" section below.

**If present:** Movement system is running but guard still not moving - see "Guard Not Moving Despite Systems Running" section.

---

## 🐛 Problem: Targeting Not Working

### Symptoms:
- No `[npc_targeting_ecs] LeftGuard was attacked!` message
- No targeting messages at all

### Possible Causes:

#### Cause 1: Damage_Log Not Being Created
**Check:**
```lua
-- Run in F9 Developer Console:
local guard = workspace.NPCs:FindFirstChild("LeftGuard")
if guard then
   -- print("Damage_Log:", guard:FindFirstChild("Damage_Log"))
end
```

**Expected:** `Damage_Log Folder`
**If nil:** Combat system isn't creating Damage_Log

**Fix:** Check if guard has `IsNPC` attribute:
```lua
local guard = workspace.NPCs:FindFirstChild("LeftGuard")
if guard then
   -- print("IsNPC:", guard:GetAttribute("IsNPC"))
end
```

Should print `IsNPC: true`. If false/nil, add it:
```lua
guard:SetAttribute("IsNPC", true)
```

#### Cause 2: npc_targeting_ecs Not Running
**Check:** No `[npc_targeting_ecs] Processing` message at all

**Fix:** System failed to load. Check server console for errors on startup.

---

## 🐛 Problem: Movement System Not Running

### Symptoms:
- Targeting works (target is set)
- No `[npc_movement_pattern_ecs] Processing` message

### Possible Causes:

#### Cause 1: NPCMovementPattern Component Missing
**Check:**
```lua
-- Run in F9 Developer Console:
local comps = require(game.ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(game.ReplicatedStorage.Modules.ECS.jecs_world)
local RefManager = require(game.ReplicatedStorage.Modules.ECS.jecs_ref_manager)

local guard = workspace.NPCs:FindFirstChild("LeftGuard")
if guard then
    local entity = RefManager.entity.find(guard)
    if entity then
       -- print("Has NPCTarget:", world:has(entity, comps.NPCTarget))
       -- print("Has NPCMovementPattern:", world:has(entity, comps.NPCMovementPattern))
       -- print("Has Locomotion:", world:has(entity, comps.Locomotion))
       -- print("Has Transform:", world:has(entity, comps.Transform))

        if world:has(entity, comps.NPCTarget) then
            local target = world:get(entity, comps.NPCTarget)
           -- print("Target:", target and target.Name or "nil")
        end
    else
       -- print("ERROR: No entity found for guard!")
    end
end
```

**Expected:**
```
Has NPCTarget: true
Has NPCMovementPattern: true
Has Locomotion: true
Has Transform: true
Target: YourUsername
```

**If NPCMovementPattern is false:** Guard is missing the component - this is initialization bug in mobs.luau

**Fix:** Check [mobs.luau:323-334](src/ServerScriptService/Systems/mobs.luau#L323-L334) - NPCMovementPattern should be added.

#### Cause 2: System Failed to Load
**Check:** No system startup message at all

**Fix:** Check server console for errors when loading npc_movement_pattern_ecs.luau

---

## 🐛 Problem: Guard Not Moving Despite Systems Running

### Symptoms:
- `[npc_targeting_ecs]` shows target set
- `[npc_movement_pattern_ecs]` shows processing
- Guard still doesn't move

### Possible Causes:

#### Cause 1: Locomotion Not Being Applied by mob_movement_ecs
**Check:**
```lua
-- Run in F9 Developer Console:
local comps = require(game.ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(game.ReplicatedStorage.Modules.ECS.jecs_world)
local RefManager = require(game.ReplicatedStorage.Modules.ECS.jecs_ref_manager)

local guard = workspace.NPCs:FindFirstChild("LeftGuard")
if guard then
    local entity = RefManager.entity.find(guard)
    if entity then
        local loco = world:get(entity, comps.Locomotion)
        if loco then
           -- print("Locomotion dir:", loco.dir)
           -- print("Locomotion speed:", loco.speed)
        end
    end
end
```

**Expected:**
```
Locomotion dir: {some non-zero vector}
Locomotion speed: 16 or 24
```

**If dir is {0, 0, 0}:** Movement pattern system isn't calculating direction correctly

**If speed is 0:** NPC is too close (within 3 studs) or movement pattern is broken

#### Cause 2: mob_movement_ecs Not Applying Humanoid:Move()
**Check console for:**
```
[mob_movement_ecs] Moving LeftGuard - dir: {X, Y, Z}, speed: 16
```

**If missing:** mob_movement_ecs not processing guard

**Possible reasons:**
1. Guard has knockback states active (check with StateManager)
2. System not running
3. Guard missing from query

#### Cause 3: Humanoid WalkSpeed is 0
**Check:**
```lua
local guard = workspace.NPCs:FindFirstChild("LeftGuard")
if guard then
    local humanoid = guard:FindFirstChild("Humanoid")
    if humanoid then
       -- print("WalkSpeed:", humanoid.WalkSpeed)
    end
end
```

**Expected:** `WalkSpeed: 16` or higher

**If 0:** Something is setting WalkSpeed to 0

---

## 🔧 Quick Diagnostic Script

Run this in F9 Developer Console after attacking the guard:

```lua
local comps = require(game.ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(game.ReplicatedStorage.Modules.ECS.jecs_world)
local RefManager = require(game.ReplicatedStorage.Modules.ECS.jecs_ref_manager)

-- Find guard in workspace.Live.Mobs (adjust path as needed)
local guard = nil
local live = workspace:FindFirstChild("Live")
if live then
    local mobs = live:FindFirstChild("Mobs")
    if mobs then
        for _, npc in mobs:GetDescendants() do
            if npc.Name:match("LeftGuard") or npc.Name:match("RightGuard") then
                guard = npc
                break
            end
        end
    end
end

if not guard then
   -- print("ERROR: Guard not found in workspace.Live.Mobs")
   -- print("Searching entire workspace...")
    for _, desc in workspace:GetDescendants() do
        if desc:IsA("Model") and (desc.Name:match("LeftGuard") or desc.Name:match("RightGuard")) then
           -- print("Found guard at:", desc:GetFullName())
            guard = desc
            break
        end
    end
    if not guard then
       -- print("ERROR: No guard found anywhere in workspace")
        return
    end
end

print("Found guard:", guard:GetFullName())

print("=== GUARD DIAGNOSTIC ===")
print("1. Basic Info:")
print("   - IsNPC:", guard:GetAttribute("IsNPC"))
print("   - Has Humanoid:", guard:FindFirstChild("Humanoid") ~= nil)
print("   - Humanoid Health:", guard:FindFirstChild("Humanoid") and guard:FindFirstChild("Humanoid").Health or "N/A")
print("   - Humanoid WalkSpeed:", guard:FindFirstChild("Humanoid") and guard:FindFirstChild("Humanoid").WalkSpeed or "N/A")

print("\n2. Damage Log:")
local damageLog = guard:FindFirstChild("Damage_Log")
print("   - Has Damage_Log:", damageLog ~= nil)
if damageLog then
   -- print("   - Attack count:", #damageLog:GetChildren())
    for _, record in damageLog:GetChildren() do
       -- print("   - Attack:", record.Name, record.Value and record.Value.Name or "nil")
    end
end

print("\n3. ECS Entity:")
local entity = RefManager.entity.find(guard)
print("   - Entity exists:", entity ~= nil)

if entity then
   -- print("\n4. ECS Components:")
   -- print("   - CombatNPC:", world:has(entity, comps.CombatNPC))
   -- print("   - NPCTarget:", world:has(entity, comps.NPCTarget))
   -- print("   - NPCMovementPattern:", world:has(entity, comps.NPCMovementPattern))
   -- print("   - NPCCombatState:", world:has(entity, comps.NPCCombatState))
   -- print("   - Locomotion:", world:has(entity, comps.Locomotion))
   -- print("   - Transform:", world:has(entity, comps.Transform))

   -- print("\n5. Component Values:")

    if world:has(entity, comps.NPCTarget) then
        local target = world:get(entity, comps.NPCTarget)
       -- print("   - NPCTarget:", target and target.Name or "nil")
    end

    if world:has(entity, comps.NPCCombatState) then
        local state = world:get(entity, comps.NPCCombatState)
       -- print("   - isPassive:", state.isPassive)
       -- print("   - isAggressive:", state.isAggressive)
       -- print("   - hasBeenAttacked:", state.hasBeenAttacked)
    end

    if world:has(entity, comps.Locomotion) then
        local loco = world:get(entity, comps.Locomotion)
       -- print("   - Locomotion dir:", loco.dir)
       -- print("   - Locomotion speed:", loco.speed)
    end
end

print("\n=== END DIAGNOSTIC ===")
```

---

## 📊 Expected Full Flow

### Correct sequence of events:

1. **Player attacks guard:**
   - Combat system calls `DamageService.Tag()`
   - `Damage_Log` folder created with attack record

2. **npc_targeting_ecs detects attack (15 Hz):**
   - Finds `Damage_Log`
   - Sets `NPCCombatState.isAggressive = true`
   - Adds `NPCTarget` component with player model
   - Console: `[npc_targeting_ecs] LeftGuard now targeting PlayerName`

3. **mob_brain_ecs skips guard (8 Hz):**
   - Sees guard has `NPCTarget`
   - Skips processing (line 228-231)
   - Console: (no message, this is correct)

4. **npc_movement_pattern_ecs takes over (8 Hz):**
   - Query matches guard (has NPCTarget)
   - Calculates movement direction
   - Updates `Locomotion` component
   - Console: `[npc_movement_pattern_ecs] Processing LeftGuard targeting PlayerName`

5. **mob_movement_ecs applies movement (20 Hz):**
   - Reads `Locomotion` component
   - Calls `Humanoid:Move(dir)`
   - Sets `Humanoid.WalkSpeed = speed`
   - Console: `[mob_movement_ecs] Moving LeftGuard - dir: {X, Y, Z}, speed: 16`

6. **Guard chases player!**

---

## 🎯 Most Likely Issues

Based on the symptoms, the most likely problems are:

1. **NPCMovementPattern component not added to guards** (check mobs.luau initialization)
2. **npc_targeting_ecs not detecting hits** (check IsNPC attribute and Damage_Log creation)
3. **mob_movement_ecs not processing guards** (check if guards are in query)

Run the diagnostic script above to identify which step is failing!
