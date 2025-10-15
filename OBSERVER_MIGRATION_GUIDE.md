# ECS Observer & Ref System Migration Guide

## Overview

The game has been modernized to use **jecs-utils** observers, monitors, and ref system for reactive, event-driven ECS architecture.

---

## What Changed?

### 1. **New Ref System** (`jecs_ref_manager.luau`)

**Old Way** (Player-specific only):
```lua
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local entity = ref.get("player", robloxPlayer)
```

**New Way** (Unified system):
```lua
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)

-- For players (uses old system internally)
local playerEntity = RefManager.player.get("player", robloxPlayer)

-- For NPCs/Models (uses new jecs-utils ref)
local npcEntity = RefManager.entity(npcModel, function(e)
    -- Initialize entity components
    world:set(e, comps.Character, npcModel)
    world:set(e, comps.Mob, true)
end)

-- Find existing entity
local existingEntity = RefManager.entity.find(npcModel)

-- Singletons
local systemEntity = RefManager.singleton("literal", "MySystemName")
```

---

### 2. **Observer System** (`jecs_observers.luau`)

Observers automatically react to component changes instead of polling every frame.

**Old Way** (Polling):
```lua
-- Runs every frame
for entity in world:query(comps.QuestAccepted):iter() do
    local questAccepted = world:get(entity, comps.QuestAccepted)
    -- Process quest...
    world:remove(entity, comps.QuestAccepted)
end
```

**New Way** (Reactive):
```lua
-- Set up once, reacts automatically
local questObserver = observers.observer(
    world:query(comps.QuestAccepted),
    function(entity)
        local questAccepted = world:get(entity, comps.QuestAccepted)
        -- Process quest...
        world:remove(entity, comps.QuestAccepted)
    end
)
```

---

## Migration Steps

### Step 1: Update Imports

**Before:**
```lua
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
```

**After:**
```lua
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local ref = RefManager.player -- For player-specific code
-- OR
local entityRef = RefManager.entity -- For NPC/model code
```

---

### Step 2: Convert Polling Systems to Observers

**Example: Quest System**

**Before** (`questsystem.luau`):
```lua
-- Runs every frame
return {
    run = function()
        for entity in world:query(comps.QuestAccepted):iter() do
            -- Process...
        end
    end,
    settings = { phase = "Heartbeat" }
}
```

**After** (Handled by `jecs_observers.luau`):
```lua
-- In jecs_observers.luau
local questAcceptedObserver = observers.observer(
    world:query(comps.QuestAccepted),
    function(entity)
        -- Process quest acceptance
    end
)
```

The old system file can be simplified or removed.

---

### Step 3: Use Monitors for State Transitions

**Example: Combat State**

```lua
local combatMonitor = observers.monitor(
    world:query(comps.Character, comps.InCombat)
)

combatMonitor:added(function(entity)
    -- Entity entered combat
    print("Combat started!")
end)

combatMonitor:removed(function(entity)
    -- Entity left combat
    print("Combat ended!")
end)
```

---

## Modernized Systems

### ✅ Fully Modernized

1. **`mobs.luau`** - Uses new ref system for NPC tracking
2. **`questsystem.luau`** - Quest acceptance handled by observers
3. **`questcleanup.luau`** - Deprecated (observers handle cleanup)
4. **`statelistener.luau`** - Optimized to only track durations, observers handle state changes
5. **`playerloader.luau`** - Uses RefManager for player entities

### 🔄 Partially Modernized

- **`jecs_observers.luau`** - Central observer management (NEW)
- **`jecs_ref_manager.luau`** - Unified ref system (NEW)

---

## Observer Types

### **Observer** - React to entities entering a query

```lua
local observer = observers.observer(
    world:query(comps.Character, comps.Stun),
    function(entity)
        -- Called when entity gets Stun component
    end
)
```

### **Monitor** - React to both entering AND leaving

```lua
local monitor = observers.monitor(
    world:query(comps.Character, comps.Ragdoll)
)

monitor:added(function(entity)
    -- Entity got ragdolled
end)

monitor:removed(function(entity)
    -- Entity recovered from ragdoll
end)
```

---

## Active Observers

All observers are initialized in `jecs_observers.luau`:

1. **NPC Spawn Monitor** - Tracks NPC creation/destruction
2. **Combat Monitor** - InCombat state changes
3. **Stun Monitor** - Stun state changes
4. **Ragdoll Monitor** - Ragdoll state changes
5. **Quest Accepted Observer** - Quest acceptance
6. **Quest Completed Observer** - Quest completion + auto-cleanup
7. **Player Monitor** - Player entity creation/removal

---

## Benefits

### Performance
- ✅ **No more polling** - Observers react only when changes occur
- ✅ **Optimized queries** - Observers cache matching archetypes
- ✅ **Reduced frame time** - Less work per frame

### Code Quality
- ✅ **Event-driven** - Clear cause and effect
- ✅ **Centralized** - All observers in one place
- ✅ **Type-safe** - Full Luau typing support
- ✅ **Maintainable** - Easy to add new observers

### Developer Experience
- ✅ **Easier debugging** - Clear observer callbacks
- ✅ **Better separation** - Systems vs reactions
- ✅ **Flexible** - Mix observers with traditional systems

---

## Common Patterns

### Pattern 1: NPC Initialization

```lua
local npcEntity = RefManager.entity(npcModel, function(e)
    world:set(e, comps.Character, npcModel)
    world:set(e, comps.Mob, true)
    world:set(e, comps.Health, {current = 175, max = 175})
    -- ... more components
end)
```

### Pattern 2: State Change Notification

```lua
local stateMonitor = observers.monitor(
    world:query(comps.Character, comps.MyState)
)

stateMonitor:added(function(entity)
    local state = world:get(entity, comps.MyState)
    if state.value then
        -- Notify clients, play effects, etc.
    end
end)
```

### Pattern 3: Cleanup After Delay

```lua
local cleanupObserver = observers.observer(
    world:query(comps.SomeComponent),
    function(entity)
        task.delay(10, function()
            if world:contains(entity) then
                world:remove(entity, comps.SomeComponent)
            end
        end)
    end
)
```

---

## Troubleshooting

### Issue: Observer not firing

**Check:**
1. Is the observer initialized? (Check `jecs_observers.luau`)
2. Is the query correct? (Use `:with()` and `:without()` filters)
3. Is the component being added/removed correctly?

### Issue: Multiple observer calls

**Cause:** Component is being set multiple times

**Fix:** Use `world:has()` to check before setting:
```lua
if not world:has(entity, comps.MyComponent) then
    world:set(entity, comps.MyComponent, value)
end
```

### Issue: Entity not found with ref

**Check:**
1. Is the entity initialized? (Check NPC spawn observer)
2. Is the key correct? (Model instance, not name)
3. Use `RefManager.entity.find()` to check if entity exists

---

## Next Steps

1. ✅ Test all observers are working
2. ✅ Monitor performance improvements
3. 🔄 Add more observers for other state changes
4. 🔄 Convert remaining polling systems to observers
5. 🔄 Add client-side observers for UI reactivity

---

## Files Modified

- ✅ `src/ReplicatedStorage/Modules/ECS/jecs_ref_manager.luau` (NEW)
- ✅ `src/ReplicatedStorage/Modules/ECS/jecs_observers.luau` (NEW)
- ✅ `src/ReplicatedStorage/Modules/ECS/jecs_start.luau` (Updated)
- ✅ `src/ServerScriptService/Systems/mobs.luau` (Modernized)
- ✅ `src/ServerScriptService/Systems/questsystem.luau` (Simplified)
- ✅ `src/ServerScriptService/Systems/questcleanup.luau` (Deprecated)
- ✅ `src/ServerScriptService/Systems/statelistener.luau` (Optimized)
- ✅ `src/ServerScriptService/Systems/playerloader.luau` (Updated imports)

---

## Questions?

Check the jecs-utils documentation:
- Observers: `Packages/_Index/pepeeltoro41_jecs-utils@1.1.0/jecs-utils/src/observers.luau`
- Ref: `Packages/_Index/pepeeltoro41_jecs-utils@1.1.0/jecs-utils/src/ref.luau`

