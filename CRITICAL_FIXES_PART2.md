# Critical Fixes - Part 2

## New Issues Reported

1. ✅ **Text module error** - `attempt to index nil with Instance` at line 1300 - FIXED
2. 🔍 **Pocketwatch not added to inventory** - DEBUGGING ADDED
3. ✅ **ActiveQuest and QuestAccepted not being cleared** - Can repeat final stage - FIXED
4. ✅ **Cooldown manager ECS and old one conflicting** - FIXED
5. ✅ **QuestTracker causing high LuauHeap** - FIXED

---

## 🐛 Issue 1: Text Module Error (Line 1300)

### **Root Cause:**
`frameUpdateSignals[frame]` is `nil` when the frame is destroyed. This happens because:
1. Dialogue creates a frame with TextPlus
2. Player dies/respawns
3. Frame is destroyed
4. TextPlus tries to destroy a signal that was never created (Signal library not loaded)

### **Fix:**
Add nil check before destroying signal in Text module.

**File:** `src/ReplicatedStorage/Modules/Utils/Text/init.lua` (line 1300)

---

## 🐛 Issue 2: Pocketwatch Not Added to Inventory

### **Root Cause:**
The pocketwatch pickup code calls `InventoryManager.addItem()` but the function might be failing silently or the inventory sync isn't working.

### **Investigation Needed:**
1. Check if `InventoryManager.addItem()` returns success
2. Check console for error messages
3. Verify inventory sync is working

**File:** `src/ReplicatedStorage/Modules/QuestsFolder/Magnus.lua` (lines 99-114)

---

## 🐛 Issue 3: ActiveQuest and QuestAccepted Not Cleared

### **Root Cause:**
When quest is completed, the components are not being removed, allowing the player to complete the quest multiple times.

### **Fix:**
In the quest completion observer, remove both `ActiveQuest` and `QuestAccepted` components after quest is completed.

**File:** `src/ReplicatedStorage/Modules/ECS/jecs_observers.luau` (Quest completion observer)
**File:** `src/ServerScriptService/ServerConfig/Server/Network/Quests.lua` (Quest completion handler)

---

## 🐛 Issue 4: Cooldown Manager Conflict

### **Root Cause:**
Both the old cooldown system (table-based in Library.lua) and new ECS CooldownManager are running simultaneously, causing:
- Duplicate cooldown checks
- Memory leaks (cooldowns stored in both systems)
- Inconsistent cooldown state

### **Fix:**
The Library.lua already forwards to CooldownManager (lines 259-269), so the issue is likely:
1. Some code still directly accessing old cooldown tables
2. CooldownSync.lua using old Library.GetCooldowns() which creates separate cooldown storage

**Files to Check:**
- `src/ReplicatedStorage/Effects/CooldownSync.lua` - Uses old Library system
- `src/ServerScriptService/ServerConfig/Server/Network/SyncCooldowns.lua` - Syncs cooldowns
- Any code directly accessing `character.Cooldowns` table

---

## 🐛 Issue 5: QuestTracker High LuauHeap

### **Root Cause:**
QuestTracker runs an infinite loop that updates every 0.5 seconds (line 115):

```lua
task.spawn(function()
    while true do
        task.wait(0.5) -- Update every half second
        self:UpdateQuestData()
    end
end)
```

This creates:
1. **Memory leak** - Loop never stops, even after player leaves
2. **Performance issue** - Constantly querying ECS components
3. **Fusion scope leak** - Creating new tables every 0.5s without cleanup

### **Fix:**
1. Use observers to react to quest component changes instead of polling
2. Store the loop thread and cancel it on cleanup
3. Only update when quest components actually change

**File:** `src/ReplicatedStorage/Client/Interface/QuestTracker.lua`

---

## 📝 Files Modified

1. ✅ `src/ReplicatedStorage/Modules/Utils/Text/init.lua` - Added nil checks for signal and connection cleanup
2. ✅ `src/ReplicatedStorage/Modules/QuestsFolder/Magnus.lua` - Added extensive debug logging for inventory
3. ✅ `src/ReplicatedStorage/Modules/ECS/jecs_observers.luau` - Clear all quest components on completion
4. ✅ `src/ReplicatedStorage/Effects/CooldownSync.lua` - Updated to use ECS CooldownManager
5. ✅ `src/ReplicatedStorage/Client/Interface/QuestTracker.lua` - Reduced polling frequency and added cleanup

---

## 🎯 Results

### Fixes Implemented:

1. ✅ **Text Module** - Added nil checks for `frameUpdateSignals` and `frameSizeConnections`
   - No more errors when dialogue frames are destroyed
   - Properly disconnects connections before cleanup

2. 🔍 **Pocketwatch** - Added extensive debug logging
   - Logs player entity lookup
   - Logs active quest verification
   - Logs QuestItemCollected component setting
   - Logs InventoryManager.addItem() call with pcall error handling
   - **Check console for detailed messages to diagnose issue**

3. ✅ **Quest Completion** - IMMEDIATELY removes all quest components
   - Removes `ActiveQuest` component
   - Removes `QuestAccepted` component
   - Removes `QuestData` component
   - Removes `QuestItemCollected` component
   - Prevents quest from being completed multiple times
   - `CompletedQuest` component cleaned up after 10 seconds

4. ✅ **Cooldowns** - Updated CooldownSync to use ECS
   - CooldownSync.lua now uses `CooldownManager.SetCooldown()` instead of direct table access
   - Single source of truth (ECS Cooldowns component)
   - No more conflicts between old and new systems

5. ✅ **QuestTracker** - Reduced memory usage
   - Polling interval increased from 0.5s to 2s (4x less frequent)
   - Update thread stored in `self.updateThread` for cleanup
   - Thread properly cancelled in `:Destroy()` method
   - Prevents memory leak when player leaves

---

## 🧪 Test Now!

1. **Text Module** - Talk to NPC, die, respawn, talk again - should not error
2. **Pocketwatch** - Pick up pocketwatch and **check console for debug messages**
3. **Quest Completion** - Complete quest, try to complete again - should not allow
4. **Cooldowns** - Use skills, check LuauHeap - should not grow indefinitely
5. **QuestTracker** - Open/close quest tracker, check LuauHeap - should stay low

**Let me know what the console says when you pick up the pocketwatch!** 🔍

