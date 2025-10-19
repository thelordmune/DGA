# ECS State & Cooldown System Test Guide

## Quick Test Script

Run this in the server console to verify the ECS state and cooldown systems are working:

```lua
-- Get required modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local CooldownManager = require(ReplicatedStorage.Modules.ECS.CooldownManager)
local Library = require(ReplicatedStorage.Modules.Library)

-- Get first player
local player = Players:GetPlayers()[1]
if not player then
    warn("No players in game!")
    return
end

local character = player.Character
if not character then
    warn("Player has no character!")
    return
end

-- print("=== Testing ECS State & Cooldown Systems ===")
-- print("Player:", player.Name)
-- print("Character:", character.Name)

-- Get entity
local entity = RefManager.player.get("player", player)
-- print("Entity ID:", entity)

-- Test 1: Direct ECS State Management
-- print("\n--- Test 1: Direct ECS State Management ---")
StateManager.AddState(character, "Actions", "TestState1")
StateManager.AddState(character, "Actions", "TestState2")
-- print("Added states: TestState1, TestState2")

local hasState1 = StateManager.StateCheck(character, "Actions", "TestState1")
-- print("Has TestState1:", hasState1)  -- Should be true

local allStates = StateManager.GetAllStates(character, "Actions")
-- print("All Actions states:", table.concat(allStates, ", "))

StateManager.RemoveState(character, "Actions", "TestState1")
-- print("Removed TestState1")

local hasState1After = StateManager.StateCheck(character, "Actions", "TestState1")
-- print("Has TestState1 after removal:", hasState1After)  -- Should be false

-- Test 2: Library Backwards Compatibility
-- print("\n--- Test 2: Library Backwards Compatibility ---")
if character:FindFirstChild("Actions") then
    Library.AddState(character.Actions, "LibraryTest")
    -- print("Added LibraryTest via Library.AddState")
    
    local hasLibraryTest = Library.StateCheck(character.Actions, "LibraryTest")
    -- print("Has LibraryTest:", hasLibraryTest)  -- Should be true
    
    Library.RemoveState(character.Actions, "LibraryTest")
    -- print("Removed LibraryTest")
    
    local hasLibraryTestAfter = Library.StateCheck(character.Actions, "LibraryTest")
    -- print("Has LibraryTest after removal:", hasLibraryTestAfter)  -- Should be false
else
    warn("Character has no Actions StringValue - this is expected with pure ECS")
end

-- Test 3: Direct ECS Cooldown Management
-- print("\n--- Test 3: Direct ECS Cooldown Management ---")
CooldownManager.SetCooldown(character, "TestCooldown", 5)
-- print("Set TestCooldown for 5 seconds")

local isOnCooldown = CooldownManager.CheckCooldown(character, "TestCooldown")
-- print("Is on cooldown:", isOnCooldown)  -- Should be true

local remainingTime = CooldownManager.GetCooldownTime(character, "TestCooldown")
-- print("Remaining time:", remainingTime, "seconds")

CooldownManager.ResetCooldown(character, "TestCooldown")
-- print("Reset TestCooldown")

local isOnCooldownAfter = CooldownManager.CheckCooldown(character, "TestCooldown")
-- print("Is on cooldown after reset:", isOnCooldownAfter)  -- Should be false

-- Test 4: Library Cooldown Backwards Compatibility
-- print("\n--- Test 4: Library Cooldown Backwards Compatibility ---")
Library.SetCooldown(character, "LibraryCooldown", 3)
-- print("Set LibraryCooldown for 3 seconds via Library")

local isOnLibraryCooldown = Library.CheckCooldown(character, "LibraryCooldown")
-- print("Is on cooldown:", isOnLibraryCooldown)  -- Should be true

local libraryRemainingTime = Library.GetCooldownTime(character, "LibraryCooldown")
-- print("Remaining time:", libraryRemainingTime, "seconds")

-- Test 5: ECS Component Verification
-- print("\n--- Test 5: ECS Component Verification ---")
if world:has(entity, comps.StateActions) then
    local stateActions = world:get(entity, comps.StateActions)
    -- print("StateActions component:", table.concat(stateActions, ", "))
else
    -- print("No StateActions component (will be created on first use)")
end

if world:has(entity, comps.Cooldowns) then
    local cooldowns = world:get(entity, comps.Cooldowns)
    -- print("Cooldowns component:")
    for skill, expiry in pairs(cooldowns) do
        local remaining = math.max(0, expiry - os.clock())
        -- print("  -", skill, ":", remaining, "seconds remaining")
    end
else
    -- print("No Cooldowns component (will be created on first use)")
end

-- Test 6: Timed State
-- print("\n--- Test 6: Timed State ---")
StateManager.TimedState(character, "Actions", "TimedTest", 2)
-- print("Added TimedTest state for 2 seconds")

local hasTimedTest = StateManager.StateCheck(character, "Actions", "TimedTest")
-- print("Has TimedTest immediately:", hasTimedTest)  -- Should be true

task.wait(2.5)

local hasTimedTestAfter = StateManager.StateCheck(character, "Actions", "TimedTest")
-- print("Has TimedTest after 2.5 seconds:", hasTimedTestAfter)  -- Should be false

-- Test 7: Multiple State Categories
-- print("\n--- Test 7: Multiple State Categories ---")
StateManager.AddState(character, "Actions", "Action1")
StateManager.AddState(character, "Stuns", "Stun1")
StateManager.AddState(character, "IFrames", "IFrame1")
-- print("Added states to Actions, Stuns, and IFrames")

local allCharacterStates = StateManager.GetAllStatesFromCharacter(character)
-- print("All character states:")
for category, states in pairs(allCharacterStates) do
    if #states > 0 then
        -- print("  -", category, ":", table.concat(states, ", "))
    end
end

-- Cleanup
-- print("\n--- Cleanup ---")
StateManager.ClearCategory(character, "Actions")
StateManager.ClearCategory(character, "Stuns")
StateManager.ClearCategory(character, "IFrames")
CooldownManager.ClearAllCooldowns(character)
-- print("Cleared all test states and cooldowns")

-- print("\n=== All Tests Complete! ===")
```

---

## Expected Output

```
=== Testing ECS State & Cooldown Systems ===
Player: YourUsername
Character: YourUsername
Entity ID: 12345

--- Test 1: Direct ECS State Management ---
Added states: TestState1, TestState2
Has TestState1: true
All Actions states: TestState1, TestState2
Removed TestState1
Has TestState1 after removal: false

--- Test 2: Library Backwards Compatibility ---
Character has no Actions StringValue - this is expected with pure ECS

--- Test 3: Direct ECS Cooldown Management ---
Set TestCooldown for 5 seconds
Is on cooldown: true
Remaining time: 5 seconds
Reset TestCooldown
Is on cooldown after reset: false

--- Test 4: Library Cooldown Backwards Compatibility ---
Set LibraryCooldown for 3 seconds via Library
Is on cooldown: true
Remaining time: 3 seconds

--- Test 5: ECS Component Verification ---
StateActions component: TestState2
Cooldowns component:
  - LibraryCooldown : 2.8 seconds remaining

--- Test 6: Timed State ---
Added TimedTest state for 2 seconds
Has TimedTest immediately: true
Has TimedTest after 2.5 seconds: false

--- Test 7: Multiple State Categories ---
Added states to Actions, Stuns, and IFrames
All character states:
  - Actions : Action1
  - Stuns : Stun1
  - IFrames : IFrame1

--- Cleanup ---
Cleared all test states and cooldowns

=== All Tests Complete! ===
```

---

## What to Check

### ✅ **State Management**
- [ ] States can be added via StateManager
- [ ] States can be checked via StateManager
- [ ] States can be removed via StateManager
- [ ] Timed states automatically remove after duration
- [ ] Multiple state categories work independently

### ✅ **Cooldown Management**
- [ ] Cooldowns can be set via CooldownManager
- [ ] Cooldowns can be checked via CooldownManager
- [ ] Cooldowns expire correctly
- [ ] Cooldown time remaining is accurate
- [ ] Cooldowns can be reset

### ✅ **Library Backwards Compatibility**
- [ ] Library.AddState works (if StringValues exist)
- [ ] Library.StateCheck works
- [ ] Library.SetCooldown works
- [ ] Library.CheckCooldown works
- [ ] Library.GetCooldownTime works

### ✅ **ECS Integration**
- [ ] StateActions component is created
- [ ] Cooldowns component is created
- [ ] Components are properly attached to entities
- [ ] Components update when states/cooldowns change

---

## Troubleshooting

### **Error: "No entity found for character"**
**Cause:** Character doesn't have an ECS entity yet.
**Fix:** Make sure the player has spawned and the playerloader system has run.

### **Error: "Component not found"**
**Cause:** Component name mismatch.
**Fix:** Check that jecs_components.luau has all the state components defined.

### **States not persisting**
**Cause:** Entity might be getting recreated.
**Fix:** Check that RefManager is properly tracking the entity.

### **Cooldowns not expiring**
**Cause:** Time comparison issue.
**Fix:** Verify os.clock() is being used consistently.

---

## Performance Test

Run this to check performance:

```lua
local start = os.clock()

-- Add 1000 states
for i = 1, 1000 do
    StateManager.AddState(character, "Actions", "State" .. i)
end

local addTime = os.clock() - start
-- print("Time to add 1000 states:", addTime, "seconds")

start = os.clock()

-- Check 1000 states
for i = 1, 1000 do
    StateManager.StateCheck(character, "Actions", "State" .. i)
end

local checkTime = os.clock() - start
-- print("Time to check 1000 states:", checkTime, "seconds")

start = os.clock()

-- Remove 1000 states
for i = 1, 1000 do
    StateManager.RemoveState(character, "Actions", "State" .. i)
end

local removeTime = os.clock() - start
-- print("Time to remove 1000 states:", removeTime, "seconds")

-- print("Total time:", addTime + checkTime + removeTime, "seconds")
```

**Expected:** Should complete in < 0.1 seconds total

---

## Integration Test

Test with actual game systems:

```lua
-- Test with combat system
local Library = require(game.ReplicatedStorage.Modules.Library)

-- Simulate M1 attack
Library.SetCooldown(character, "M1", 0.3)
Library.TimedState(character.Actions, "Attacking", 0.5)

-- print("M1 on cooldown:", Library.CheckCooldown(character, "M1"))
-- print("Is attacking:", Library.StateCheck(character.Actions, "Attacking"))

task.wait(0.6)

-- print("M1 on cooldown after 0.6s:", Library.CheckCooldown(character, "M1"))
-- print("Is attacking after 0.6s:", Library.StateCheck(character.Actions, "Attacking"))
```

---

**All tests passing = System is working correctly! ✅**

