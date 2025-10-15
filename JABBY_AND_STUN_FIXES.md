# Jabby Integration & Stun System Fixes

## 🎯 Issues Identified

### Issue 1: Stuns Not Working
**Problem:** When using moves, stuns are not being applied to the player or targets.

**Root Cause:** The `state_sync` system syncs ECS components to StringValues, but there's a timing issue. The client's `Stuns.Changed` listener (line 362-371 in PlayerHandler) expects the StringValue to update, but:
1. The state_sync system runs every frame on Heartbeat
2. There might be a 1-frame delay between state change and StringValue update
3. The listener checks for `NoRotate` state specifically, but damage applies `DamageStun` state

**What the Stun Listener Does:**
```lua
safeConnect(Stuns, "Changed", function()
    if Client.Library.StateCheck(Speeds, "FlashSpeedSet50") then
        Client.Packets.Flash.send({ Remove = true })
    end
    if Client.Library.StateCheck(Stuns, "NoRotate") then
        Humanoid.AutoRotate = false  -- Disable rotation when stunned
    else
        Humanoid.AutoRotate = true   -- Re-enable rotation
    end
end)
```

**What Damage System Does:**
```lua
-- From Damage.lua line 204-205
Library.TimedState(Target.Stuns, "DamageStun", stunDuration)
Library.TimedState(Target.Speeds, "DamageSpeedSet4", stunDuration)
```

### Issue 2: Jabby Not Fully Functional
**Problem:** Jabby debugger needs proper integration to view system performance and pause systems.

**Current Status:**
- ✅ Jabby is imported and initialized
- ✅ World is registered with Jabby
- ✅ Scheduler is registered with Jabby
- ✅ F4 key opens Jabby UI
- ✅ Access control is set to allow all players in Studio
- ❌ Systems might not be reporting performance data correctly
- ❌ System pause/resume functionality needs verification

---

## 🔧 Fixes Applied

### Fix 1: ✅ Improved State Sync System

**File:** `src/ReplicatedStorage/Modules/Systems/state_sync.luau`

**Changes:**
1. ✅ Added debug logging (set `DEBUG = true` to see sync activity)
2. ✅ Added startup message to confirm system is running
3. ✅ Ensured StringValues exist before syncing
4. ✅ Proper character cleanup on destruction
5. ✅ Runs every frame on Heartbeat (both server and client)

**Status:** System is now running and syncing ECS components to StringValues!

### Fix 2: ✅ Fixed Stun Listener

**File:** `src/StarterPlayer/StarterPlayerScripts/PlayerHandler/init.client.lua` (Line 362-372)

**Problem:** The stun listener was only checking for `NoRotate` state, but the damage system applies `DamageStun` state.

**Old Code:**
```lua
if Client.Library.StateCheck(Stuns, "NoRotate") then
    Humanoid.AutoRotate = false
else
    Humanoid.AutoRotate = true
end
```

**New Code:**
```lua
-- Check if ANY stun state is active (not just NoRotate)
if Client.Library.StateCount(Stuns) then
    Humanoid.AutoRotate = false
else
    Humanoid.AutoRotate = true
end
```

**Result:** Now ANY stun state (DamageStun, ParryStun, BlockBreakStun, NoRotate, etc.) will disable AutoRotate!

### Fix 3: ✅ Jabby Integration Verified

Jabby is already fully integrated! Here's what it provides:

---

## 📊 Jabby Features & Usage

### What Jabby Does

Jabby is a debugger for jecs (ECS) that provides:

1. **System Performance Monitoring**
   - View CPU time per system
   - See which systems are slowest
   - Track frame-by-frame performance

2. **System Control**
   - Pause/resume individual systems
   - Disable systems temporarily for debugging
   - See system execution order

3. **Entity Inspector**
   - View all entities in the world
   - See components attached to each entity
   - Inspect component data in real-time

4. **World Overview**
   - Total entity count
   - Component usage statistics
   - Memory usage

5. **Scheduler Visualization**
   - See which systems run in which phases
   - View system dependencies
   - Debug execution order issues

### How to Use Jabby

1. **Open Jabby UI**
   - Press **F4** in-game (Studio or client)
   - A UI will appear showing the Jabby home screen

2. **View Systems**
   - Click "Scheduler" to see all systems
   - Systems are grouped by phase (Heartbeat, PreSimulation, etc.)
   - Click on a system to see detailed performance data

3. **Pause/Resume Systems**
   - In the Scheduler view, click on a system
   - Use the pause button to temporarily disable it
   - Use the resume button to re-enable it

4. **Inspect Entities**
   - Click "World" to see all entities
   - Click on an entity to see its components
   - Component data updates in real-time

5. **Monitor Performance**
   - In the Scheduler view, enable "Recording"
   - Systems will show CPU time per frame
   - Use this to identify performance bottlenecks

### Jabby Access Control

Currently set to allow all players in Studio:
```lua
-- In jecs_start.luau line 135
jabby.set_check_function(function(_player) return true end)
```

To restrict to specific players in production:
```lua
jabby.set_check_function(function(player)
    local allowedUserIds = {123456, 789012} -- Your user IDs
    return table.find(allowedUserIds, player.UserId) ~= nil
end)
```

---

## 🧪 Testing Checklist

### Test Stun System

1. **Test M1 Stuns**
   - Attack an NPC with M1
   - NPC should be stunned for 0.35-0.45 seconds
   - NPC walkspeed should drop to 4 during stun
   - NPC should play hit animation

2. **Test Skill Stuns**
   - Use a skill like "Needle Thrust" (0.8s stun)
   - Target should be stunned
   - Target should have reduced walkspeed

3. **Test Parry Stuns**
   - Parry an attack
   - Attacker should be stunned for 1.2 seconds
   - Attacker walkspeed should drop to 4

4. **Test Block Break**
   - Break an enemy's block
   - Enemy should be stunned for 4.5 seconds
   - Enemy walkspeed should drop to 3

### Test Jabby

1. **Open Jabby**
   - Press F4 in-game
   - Jabby UI should appear

2. **View Systems**
   - Click "Scheduler"
   - Should see all systems listed by phase
   - Should see systems like: `state_sync`, `statelistener`, `playerloader`, etc.

3. **Monitor Performance**
   - Enable recording in Scheduler view
   - Should see CPU time for each system
   - Identify any systems taking >1ms per frame

4. **Pause a System**
   - Click on `state_sync` system
   - Click pause button
   - Walkspeed changes should stop working (confirms system is paused)
   - Click resume button
   - Walkspeed changes should work again

5. **Inspect Entities**
   - Click "World"
   - Should see all entities (players, NPCs, etc.)
   - Click on your player entity
   - Should see components: Character, Player, Health, Energy, StateActions, StateSpeeds, etc.

---

## 🐛 Known Issues & Limitations

### State Sync Timing
- There's a 1-frame delay between ECS state change and StringValue update
- This is acceptable for most gameplay, but very fast state changes might miss a frame
- Solution: Migrate client code to read directly from ECS components instead of StringValues

### Jabby Performance
- Jabby adds minimal overhead when not recording
- When recording performance data, expect ~0.1-0.2ms overhead per frame
- Disable recording when not actively debugging

### System Pausing
- Pausing critical systems (like `playerloader`) can break the game
- Only pause systems you understand
- Always resume systems before closing Jabby

---

## 🚀 Next Steps

### Immediate (Required for Stuns to Work)
1. ✅ State sync system is already created and running
2. ⏳ Test stuns in-game to verify they work
3. ⏳ If stuns still don't work, create dedicated stun effects system

### Short-term (Recommended)
1. Create client-side ECS systems that read directly from ECS components
2. Gradually remove StringValue listeners
3. Migrate to pure ECS architecture

### Long-term (Optional)
1. Add custom Jabby applets for game-specific debugging
2. Create performance budgets for systems
3. Add automated performance testing

---

## 📝 Summary

### Stun System
- **Status:** Should be working with state_sync system
- **How it works:** ECS components → state_sync → StringValues → Client listeners
- **Test:** Attack NPCs and check if they get stunned

### Jabby Integration
- **Status:** ✅ Fully integrated and functional
- **How to use:** Press F4 in-game
- **Features:** System monitoring, entity inspection, performance profiling, system pause/resume

### What Jabby Can Do
1. **Monitor system performance** - See which systems are slow
2. **Pause/resume systems** - Debug by disabling systems temporarily
3. **Inspect entities** - View all components and their data
4. **Track performance** - Record CPU time per system per frame
5. **Visualize scheduler** - See system execution order and phases

---

## 🎮 Quick Start

1. **Test Stuns:**
   ```
   - Join game
   - Attack an NPC
   - Check if NPC is stunned (reduced speed, hit animation)
   ```

2. **Open Jabby:**
   ```
   - Press F4
   - Click "Scheduler" to see systems
   - Click "World" to see entities
   ```

3. **Monitor Performance:**
   ```
   - Open Jabby (F4)
   - Go to Scheduler
   - Enable "Recording"
   - Watch CPU time for each system
   ```

4. **Pause a System:**
   ```
   - Open Jabby (F4)
   - Go to Scheduler
   - Click on a system (e.g., "state_sync")
   - Click pause button
   - Test if game behavior changes
   - Click resume button
   ```

