# Quest Marker System - Testing Guide

This guide will help you test the Quest Marker System to ensure it's working correctly.

## Prerequisites

Before testing, ensure:
1. ✅ The game is running in Play mode or on a server
2. ✅ You have a character spawned in the world
3. ✅ NPCs are present in `workspace.World.Dialogue`
4. ✅ Quest data is defined in `ReplicatedStorage.Modules.Quests`
5. ✅ QuestMarkers module is initialized by PlayerHandler

## Test 1: Quest Available Marker (Gold "!")

**Objective**: Verify that NPCs with available quests show a gold "!" marker.

### Steps:
1. Start the game
2. Wait 2-3 seconds for the marker system to initialize
3. Look for Magnus NPC in `workspace.World.Dialogue`
4. Ensure you **don't** have an active quest

### Expected Result:
- ✅ A **gold "!" marker** appears above Magnus
- ✅ The marker shows "New Quest" as the label
- ✅ The marker shows distance in meters
- ✅ The marker follows Magnus as he moves (if applicable)

### Troubleshooting:
- **No marker appears**: Check console for errors
- **Wrong color**: Verify you don't have an active quest
- **Marker not following NPC**: Check that NPC has HumanoidRootPart

---

## Test 2: Quest Active Marker (Gold "!")

**Objective**: Verify that the marker updates when a quest is accepted.

### Steps:
1. Walk up to Magnus (with the gold "!" marker)
2. Press **E** to talk to Magnus
3. Accept the quest "Missing Pocketwatch"
4. Walk away from Magnus

### Expected Result:
- ✅ The marker remains **gold "!"**
- ✅ The label changes to "Missing Pocketwatch"
- ✅ The marker continues to follow Magnus

### Troubleshooting:
- **Marker disappears**: Check that ActiveQuest component was set
- **Marker doesn't update**: Wait 1 second for the update cycle

---

## Test 3: Quest Objective Marker (Blue Star)

**Objective**: Verify that quest items in the world show markers.

### Steps:
1. With the "Missing Pocketwatch" quest active
2. Look around for the pocketwatch item in the world
3. The pocketwatch should be in `workspace.World.Quests.Magnus`

### Expected Result:
- ✅ A **blue star marker** appears above the pocketwatch
- ✅ The marker shows "Quest Item" as the label
- ✅ The marker shows distance to the item
- ✅ The marker follows the item's position

### Troubleshooting:
- **No marker appears**: 
  - Check that quest item exists in `workspace.World.Quests.Magnus`
  - Verify you have an active quest
  - Check console for errors
- **Marker appears on wrong item**: Check item hierarchy

---

## Test 4: Quest Turn-in Marker (Green "?")

**Objective**: Verify that the marker changes when quest is complete.

### Steps:
1. With the "Missing Pocketwatch" quest active
2. Walk to the pocketwatch and pick it up (touch it)
3. Return to Magnus

### Expected Result:
- ✅ The blue star marker **disappears** when you pick up the item
- ✅ Magnus's marker changes to **green "?"**
- ✅ The label shows "Missing Pocketwatch"
- ✅ This indicates you can turn in the quest

### Troubleshooting:
- **Marker doesn't change color**: 
  - Check that QuestItemCollected component was set
  - Wait 1 second for the update cycle
- **Blue marker doesn't disappear**: Check quest item pickup logic

---

## Test 5: Off-Screen Arrow Indicator

**Objective**: Verify that off-screen markers show directional arrows.

### Steps:
1. With any active marker visible
2. Turn your camera away from the marker
3. The marker should go off-screen

### Expected Result:
- ✅ An **arrow appears** at the edge of the screen
- ✅ The arrow **points** in the direction of the marker
- ✅ The arrow **rotates** as you turn the camera
- ✅ When you turn back, the arrow disappears and the full marker appears

### Troubleshooting:
- **Arrow doesn't appear**: Check `ShowArrow` logic in the module
- **Arrow doesn't rotate**: Check `arrowRotation` calculation
- **Arrow position wrong**: Check edge clamping logic

---

## Test 6: Distance-Based Visibility

**Objective**: Verify that markers hide when too far away.

### Steps:
1. With any active marker visible
2. Walk far away from the marker (>500 studs)
3. Walk back towards the marker

### Expected Result:
- ✅ Marker **fades out** when distance > 500 studs
- ✅ Marker **fades in** when distance < 500 studs
- ✅ Distance text updates in real-time

### Troubleshooting:
- **Marker always visible**: Check distance calculation
- **Marker never visible**: Check visibility threshold (500 studs)

---

## Test 7: Multiple Markers

**Objective**: Verify that multiple markers can exist simultaneously.

### Steps:
1. Ensure multiple NPCs exist in `workspace.World.Dialogue`
2. Each NPC should have quest data defined
3. Look around the world

### Expected Result:
- ✅ Each NPC shows its own marker
- ✅ Markers don't overlap or interfere
- ✅ Each marker updates independently

### Troubleshooting:
- **Markers overlap**: This is expected if NPCs are close together
- **Some markers missing**: Check that each NPC has quest data

---

## Test 8: Quest Completion

**Objective**: Verify that markers clean up after quest completion.

### Steps:
1. With the green "?" marker on Magnus
2. Talk to Magnus and complete the quest
3. Choose either "Return Watch" or "Keep Watch"

### Expected Result:
- ✅ Magnus's marker **disappears** after quest completion
- ✅ No new markers appear (since no new quests available)
- ✅ All quest-related markers are cleaned up

### Troubleshooting:
- **Marker doesn't disappear**: Check CompletedQuest component
- **Marker reappears**: Check quest completion logic

---

## Test 9: Character Respawn

**Objective**: Verify that markers persist after character respawn.

### Steps:
1. With markers visible
2. Reset your character (or die)
3. Wait for respawn

### Expected Result:
- ✅ Markers **reappear** after respawn
- ✅ Marker states are **correct** (based on quest progress)
- ✅ No duplicate markers

### Troubleshooting:
- **Markers don't reappear**: Check CharacterAdded connection in PlayerHandler
- **Duplicate markers**: Check cleanup logic

---

## Test 10: Performance

**Objective**: Verify that the marker system doesn't cause lag.

### Steps:
1. Open the **Developer Console** (F9)
2. Check the **Performance** tab
3. Monitor FPS and memory usage

### Expected Result:
- ✅ FPS remains stable (60 FPS)
- ✅ No significant memory leaks
- ✅ Markers update smoothly

### Troubleshooting:
- **Low FPS**: 
  - Reduce marker update frequency
  - Reduce visibility distance
  - Check for memory leaks
- **Memory leaks**: Check that scopes are properly cleaned up

---

## Common Issues

### Issue: "No markers appear at all"

**Possible Causes:**
1. Module not initialized by PlayerHandler
2. No NPCs in workspace.World.Dialogue
3. No quest data defined
4. Player entity not initialized

**Solutions:**
1. Check Output for errors
2. Verify NPC placement
3. Verify quest data in Quests.luau
4. Wait a few seconds after spawning
5. Check that PlayerHandler calls `QuestMarkers.Init()`

---

### Issue: "Markers appear in wrong positions"

**Possible Causes:**
1. NPC missing HumanoidRootPart
2. Camera position calculation error
3. World-to-screen conversion issue

**Solutions:**
1. Ensure NPCs have HumanoidRootPart
2. Check camera reference
3. Verify worldToScreen function

---

### Issue: "Markers don't update"

**Possible Causes:**
1. Update loop not running
2. ECS components not set
3. Quest state not changing

**Solutions:**
1. Check for script errors
2. Verify component states in ECS debugger
3. Check quest manager logic

---

## Debug Commands

Run these in the **Command Bar** to debug:

### Check Player Entity
```lua
local ref = require(game.ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local playerEntity = ref.get("local_player")
print("Player Entity:", playerEntity)
```

### Check Active Quest
```lua
local world = require(game.ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(game.ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(game.ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local playerEntity = ref.get("local_player")
if world:has(playerEntity, comps.ActiveQuest) then
    local quest = world:get(playerEntity, comps.ActiveQuest)
   -- print("Active Quest:", quest.npcName, quest.questName)
else
   -- print("No active quest")
end
```

### List All Markers
```lua
local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
for _, gui in playerGui:GetChildren() do
    if gui.Name:match("^QuestMarker_") then
       -- print("Marker:", gui.Name)
    end
end
```

---

## Success Criteria

The Quest Marker System is working correctly if:

- ✅ All 10 tests pass
- ✅ No errors in the console
- ✅ Markers appear and update correctly
- ✅ Performance is acceptable (60 FPS)
- ✅ Markers clean up properly

---

## Next Steps

After testing:
1. Report any bugs or issues
2. Suggest improvements or new features
3. Test with different quest types
4. Test with multiple players (if applicable)

