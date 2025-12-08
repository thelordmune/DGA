# NPC Critical Issues - Root Cause Analysis & Fixes

**Date:** 2025-12-01
**Status:** 🔴 CRITICAL - 3 Major Issues Found

---

## 🐛 Issue #1: NPCs Clustering at Specific Location

### **Root Cause:**
`npc_wander_ecs.luau` uses `spawnData.spawnPosition` as the wander center, but this is shared across all NPCs that spawn from the same spawner. If guards spawn from the same location, they all wander around that SAME point.

### **Evidence:**
```lua
-- npc_wander_ecs.luau:62-63
local spawnPos = spawnData.spawnPosition
local maxDistance = spawnData.maxWanderDistance or 30

-- Lines 114-119: NPCs are weighted toward spawn point
if distanceFromSpawn > maxDistance then
    local toSpawn = (spawnPos - currentPos).Unit
    local weight = math.clamp(distanceFromSpawn / maxDistance, 0, 1)
    direction = direction:Lerp(toSpawn, weight)
end
```

**Problem:** If LeftGuard and RightGuard both have `spawnPosition = Vector3.new(100, 0, 100)`, they BOTH wander around (100, 0, 100) instead of staying at their current locations.

### **Fix:**
```lua
-- In mobs.luau, when initializing NPCWander, use CURRENT position as center, not spawn position
world:set(e, comps.NPCWander, {
    center = transform.new.Position, -- Use current position, not spawnPos
    radius = 30,
    nextMove = math.random() * 3,
    noiseOffset = math.random() * 1000,
    currentDirection = Vector3.zero,
    isPaused = false,
    pauseEndTime = 0,
    moveEndTime = 0,
})
```

**Implementation Location:** [mobs.luau:336-344](src/ServerScriptService/Systems/mobs.luau#L336-L344)

---

## 🐛 Issue #2: Targeting System Not Detecting Hits

### **Root Cause:**
The targeting system IS working correctly, but there are THREE potential issues:

#### **Issue 2A: Query Filter May Be Broken**
The query has `.without(comps.NPCTarget)` which should skip NPCs with targets, but the debug logging shows this might not be working.

**Query Definition:**
```lua
-- npc_wander_ecs.luau:21-28
local query = world:query(
    comps.Character,
    comps.Transform,
    comps.NPCWander,
    comps.NPCSpawnData,
    comps.Locomotion
):with(comps.CombatNPC):without(comps.NPCTarget):cached()
```

**Debug Check:**
```lua
-- Lines 54-59: Verify filter is working
if not hasLoggedWander then
    local hasTarget = world:has(entity, comps.NPCTarget)
    print(`[npc_wander_ecs] Processing {char.Name} - has NPCTarget: {hasTarget}`)
    hasLoggedWander = true
end
```

**Expected:** Should print `has NPCTarget: false`
**If Broken:** Would print `has NPCTarget: true` even after being hit

#### **Issue 2B: `Damage_Log` Not Being Created**
Check if the combat system is actually calling `DamageService.Tag()` when player attacks NPC.

**Where It's Created:**
```lua
-- Damage.lua:599-620
if Target:GetAttribute("IsNPC") then
    -- Log the attack for NPC aggression system
    local damageLog = Target:FindFirstChild("Damage_Log")
    if not damageLog then
        damageLog = Instance.new("Folder")
        damageLog.Name = "Damage_Log"
        damageLog.Parent = Target
    end

    -- Create attack record
    local attackRecord = Instance.new("ObjectValue")
    attackRecord.Name = "Attack_" .. os.clock()
    attackRecord.Value = Invoker
    attackRecord.Parent = damageLog
end
```

**Where It's Checked:**
```lua
-- npc_targeting_ecs.luau:44-62
local function hasBeenAttacked(character: Model): (boolean, Model?)
    -- Check Damage_Log
    local damageLog = character:FindFirstChild("Damage_Log")
    if damageLog and #damageLog:GetChildren() > 0 then
        local recentAttack = damageLog:GetChildren()[#damageLog:GetChildren()]
        if recentAttack and recentAttack.Value then
            return true, recentAttack.Value
        end
        return true, nil
    end

    -- Check IFrames for attack states
    if StateManager.StateCheck(character, "IFrames", "RecentlyAttacked") or
       StateManager.StateCheck(character, "IFrames", "Damaged") then
        return true, nil
    end

    return false, nil
end
```

#### **Issue 2C: System Not Running**
Verify `npc_targeting_ecs` is actually being loaded and executed.

**Check Console For:**
```
[npc_targeting_ecs] Processing LeftGuard
[npc_targeting_ecs] LeftGuard was attacked! Attacker: {PlayerName}
[npc_targeting_ecs] LeftGuard entered AGGRESSIVE mode
[npc_targeting_ecs] LeftGuard now targeting {PlayerName}
```

**If Missing:** System isn't running at all.

### **Testing Steps:**
1. Hit the guard with M1
2. Check console for these messages:
   - `[npc_targeting_ecs] Processing {NPCName}` - System is running
   - `[npc_targeting_ecs] {NPCName} was attacked!` - Attack detection works
   - `[npc_targeting_ecs] {NPCName} now targeting {PlayerName}` - Target set
3. Use F9 Developer Console to check NPC character:
   ```lua
   -- Check if Damage_Log exists
   print(workspace.NPCs.LeftGuard:FindFirstChild("Damage_Log"))
   -- Should print: Damage_Log (Folder)

   -- Check attack records
   local log = workspace.NPCs.LeftGuard:FindFirstChild("Damage_Log")
   if log then
       for _, v in log:GetChildren() do
           print(v.Name, v.Value)
       end
   end
   ```

---

## 🐛 Issue #3: Knockback Not Working on NPCs

### **Root Cause:**
`mob_movement_ecs` is calling `Humanoid:Move()` every frame, which OVERRIDES the knockback physics applied by `ServerBvel.KnockbackBvel`.

### **Evidence:**
```lua
-- mob_movement_ecs.luau:82-89
if dir.Magnitude > EPS then
    humanoid:Move(dir)           -- ❌ This overrides knockback velocity
    humanoid.WalkSpeed = speed
else
    humanoid:Move(Vector3.zero)  -- ❌ This also cancels knockback
end
```

**Knockback Application:**
```lua
-- Damage.lua:786-801
local function Knockback()
    Library.StopAllAnims(Target)
    local Animation = Library.PlayAnimation(Target, Replicated.Assets.Animations.Misc.KnockbackStun)
    Animation.Priority = Enum.AnimationPriority.Action3

    -- Lock rotation and disable controls during knockback
    Library.TimedState(Target.Stuns, "NoRotate", 0.65)
    Library.TimedState(Target.Stuns, "KnockbackStun", 0.65)

    Server.Packets.Bvel.sendToAll({ Character = Invoker, Name = "KnockbackBvel", Targ = Target })
    handleWallbang()
end
```

**Problem:** ECS movement system runs at 20 Hz, so every 0.05 seconds it's calling `Humanoid:Move()`, which cancels the knockback LinearVelocity applied by `ServerBvel.KnockbackBvel`.

### **Fix:**
Make `mob_movement_ecs` skip NPCs that have knockback states active.

```lua
-- In mob_movement_ecs.luau:53-72, add state checks:
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

for e, char, transform, loco in moving_mobs do
    if not char or not char:IsDescendantOf(workspace) then
        continue
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then
        continue
    end

    -- CRITICAL: Skip if NPC has knockback/stun states
    if StateManager.StateCheck(char, "Stuns", "KnockbackStun") or
       StateManager.StateCheck(char, "Stuns", "ParryKnockback") or
       StateManager.StateCheck(char, "Stuns", "NoRotate") then
        -- NPC is being knocked back - don't override physics
        continue
    end

    -- ... rest of movement logic
end
```

**Implementation Location:** [mob_movement_ecs.luau:52-96](src/ServerScriptService/Systems/mob_movement_ecs.luau#L52-L96)

---

## 🔧 Additional Fixes Needed

### **Fix #4: Guards Should Not Wander At All**
Guards are supposed to stand completely still until attacked. The `NPCWander` component should NOT be added to guards.

**Current Code (mobs.luau:334-344):**
```lua
-- Add wander component for NPCs that should wander
if npcData.canWander then
    world:set(e, comps.NPCWander, {
        center = spawnPos,
        radius = 30,
        -- ...
    })
end
```

**Problem:** `npcData.canWander` might be `true` for guards when it should be `false`.

**Check Guard Config:**
```lua
-- In LeftGuard.lua or RightGuard.lua
{
    canWander = false, -- Should be false for guards
    isPassive = true,  -- Guards start passive
    -- ...
}
```

---

## ✅ Implementation Checklist

### **Priority 1: Critical Fixes** (Do These First)
- [ ] Fix NPCWander center point (use current position, not spawn position)
- [ ] Fix mob_movement_ecs to skip knockback states
- [ ] Verify guards have `canWander = false` in their config

### **Priority 2: Debugging** (If Issues Persist)
- [ ] Add debug logging to verify Damage_Log creation
- [ ] Add debug logging to verify npc_targeting_ecs is running
- [ ] Add debug logging to verify npc_wander_ecs query filter works

### **Priority 3: Testing**
- [ ] Test guard idle behavior (should stand still)
- [ ] Test guard targeting when hit
- [ ] Test knockback moves (Triple Kick, etc.)
- [ ] Test wander behavior for wandering NPCs (Bandits, etc.)

---

## 📊 Expected Console Output After Fixes

### **When Spawning Guard:**
```
[mobs] Initializing LeftGuard (Combat NPC)
[mobs] - isPassive: true, canWander: false
[mobs] Added components: NPCCombatState, NPCConfig, NPCMovementPattern
```

### **When Hitting Guard:**
```
[npc_targeting_ecs] Processing LeftGuard
[npc_targeting_ecs] LeftGuard was attacked! Attacker: PlayerName
[npc_targeting_ecs] LeftGuard entered AGGRESSIVE mode
[npc_targeting_ecs] LeftGuard now targeting PlayerName
```

### **When Using Knockback Move:**
```
[Knockback] Applying knockback to LeftGuard from PlayerName
[Knockback] Sent KnockbackBvel packet
[mob_movement_ecs] Skipping LeftGuard - has KnockbackStun state
```

---

## 🎯 Root Cause Summary

| Issue | Root Cause | Fix |
|-------|------------|-----|
| NPCs clustering | Shared spawn position used as wander center | Use current position as center |
| Targeting not working | System may not be running OR Damage_Log not created | Add debug logging, verify system runs |
| Knockback not working | ECS movement overrides knockback physics | Skip movement when knockback active |

---

**Next Steps:** Implement Priority 1 fixes and test in-game.
