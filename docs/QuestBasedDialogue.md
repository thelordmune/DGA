# Quest-Based Dialogue System

This guide explains how to create dialogue that changes based on quest progress, allowing NPCs to say different things when players have active quests.

## Overview

The dialogue system supports **conditional dialogue paths** that check the player's quest status. This allows you to create:
- Different dialogue when a player has an active quest
- Reminder dialogue ("Did you find the item yet?")
- Completion dialogue when returning with quest items
- Default dialogue for players without quests

## Available Dialogue Conditions

### 1. HasActiveQuest
**Location:** `src/ReplicatedStorage/Modules/Utils/DialogueConditions/HasActiveQuest.lua`

Checks if the player has an active quest from a specific NPC.

**Returns:**
- `true` - Player has an active quest from this NPC
- `false` - Player does not have an active quest

**Usage:**
```lua
HasActiveQuest.Run("Magnus") -- Check if player has active quest from Magnus
```

### 2. HasCompletedQuest
**Location:** `src/ReplicatedStorage/Modules/Utils/DialogueConditions/HasCompletedQuest.lua`

Checks if the player has completed a specific quest.

**Returns:**
- `true` - Player has completed the quest
- `false` - Player has not completed the quest

**Usage:**
```lua
HasCompletedQuest.Run("Magnus", "Missing Pocketwatch") -- Check specific quest completion
```

## How to Set Up Quest-Based Dialogue

### Step 1: Create Your Dialogue Tree Structure

In Roblox Studio, create a dialogue tree with multiple paths:

```
DialogueTree (Folder in ReplicatedStorage.Dialogues)
├── Root (Start node)
├── DefaultGreeting (For players without quests)
│   ├── Text: "Hello traveler! I need your help..."
│   └── [Leads to quest offer]
├── QuestReminderGreeting (For players with active quest)
│   ├── Text: "Did you find my pocketwatch yet?"
│   └── [Leads to quest progress check]
└── CompletionGreeting (For players returning with quest complete)
    ├── Text: "You found it! Thank you so much!"
    └── [Leads to reward]
```

### Step 2: Add Condition Nodes

1. **Create a Condition Node:**
   - In your dialogue tree, create a new Instance
   - Set its `Type` attribute to `"Condition"`
   - Set its `Priority` attribute (this determines which path to take)

2. **Add the Condition Module:**
   - Add the condition ModuleScript as a child of the Condition node
   - For example, add `HasActiveQuest` module

3. **Connect the Condition:**
   - The Condition node should be an input to the dialogue node you want to conditionally show
   - If the condition returns `true`, the dialogue path will be followed
   - If the condition returns `false`, the dialogue path will be skipped

### Step 3: Example Dialogue Tree Setup

Here's a complete example for an NPC named "Magnus":

#### Tree Structure:
```
Magnus (Dialogue Tree)
├── Root
│   ├── Output → DefaultPath
│   └── Output → QuestActivePath
│
├── Condition_HasActiveQuest
│   ├── Type: "Condition"
│   ├── Priority: 1
│   └── HasActiveQuest (ModuleScript)
│
├── DefaultPath (Priority: 0)
│   ├── Input ← Root
│   ├── Input ← Condition_HasActiveQuest (inverted)
│   └── Text: "Hello! I've lost my pocketwatch..."
│
└── QuestActivePath (Priority: 1)
    ├── Input ← Root
    ├── Input ← Condition_HasActiveQuest
    └── Text: "Did you find my pocketwatch yet?"
```

### Step 4: Configure Priority System

The dialogue system uses **Priority** attributes to determine which path to take:

- **Priority 0**: Default path (no quest)
- **Priority 1**: Active quest path
- **Priority 2**: Completed quest path

**How it works:**
1. The condition module returns `true` or `false`
2. The system compares this to the node's Priority attribute
3. If they match, the dialogue path is followed
4. If they don't match, the path is skipped

### Step 5: Modify Condition Modules for Your NPC

You can pass the NPC name to the condition:

```lua
-- In your Condition node's ModuleScript
local HasActiveQuest = require(ReplicatedStorage.Modules.Utils.DialogueConditions.HasActiveQuest)

return {
    Run = function()
        return HasActiveQuest.Run("Magnus") -- Replace with your NPC name
    end
}
```

## Complete Example: Magnus Quest Dialogue

### Scenario:
Magnus has lost his pocketwatch and needs the player to find it.

### Dialogue Paths:

#### 1. First Meeting (No Quest)
```
Magnus: "Hello traveler! I've lost my precious pocketwatch somewhere in the city."
Player: [Accept Quest] / [Decline]
```

#### 2. Quest Active (Player Returns Without Completing)
```
Magnus: "Did you find my pocketwatch yet? Check the market stalls!"
Player: [Still looking] / [Cancel Quest]
```

#### 3. Quest Complete (Player Returns With Item)
```
Magnus: "You found it! Thank you so much! Here's your reward."
[Give rewards and complete quest]
```

### Implementation:

1. **Create Dialogue Tree:** `ReplicatedStorage.Dialogues.Magnus`

2. **Add Condition Nodes:**
   - `Condition_NoQuest` - Checks if player does NOT have active quest
   - `Condition_ActiveQuest` - Checks if player HAS active quest
   - `Condition_Completed` - Checks if player completed quest

3. **Create Dialogue Nodes:**
   - `FirstMeeting` (Priority 0) - Connected to Condition_NoQuest
   - `QuestReminder` (Priority 1) - Connected to Condition_ActiveQuest
   - `QuestComplete` (Priority 2) - Connected to Condition_Completed

4. **Add Text Values:**
   - Each dialogue node has a `Text` StringValue with the dialogue text

## Advanced: Custom Conditions

You can create custom conditions for more complex quest logic:

```lua
-- CustomQuestCondition.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

local CustomCondition = {}

function CustomCondition.Run()
    local player = Players.LocalPlayer
    local playerEntity = ref.get("local_player")
    
    if not playerEntity or not world:has(playerEntity, comps.ActiveQuest) then
        return false
    end
    
    local activeQuest = world:get(playerEntity, comps.ActiveQuest)
    
    -- Custom logic: Check if quest has been active for more than 5 minutes
    if activeQuest.npcName == "Magnus" then
        local timeElapsed = os.clock() - activeQuest.startTime
        if timeElapsed > 300 then -- 5 minutes
            return true -- Show "hurry up" dialogue
        end
    end
    
    return false
end

return CustomCondition
```

## Testing Your Quest Dialogue

1. **Test without quest:**
   - Walk up to NPC
   - Should see default greeting

2. **Test with active quest:**
   - Accept the quest
   - Walk away and return
   - Should see reminder dialogue

3. **Test with completed quest:**
   - Complete quest objectives
   - Return to NPC
   - Should see completion dialogue

## Troubleshooting

### Condition not working?
- Check that the condition module is a child of the Condition node
- Verify the `Type` attribute is set to `"Condition"`
- Ensure Priority attributes match your logic
- Check console for condition debug prints

### Wrong dialogue showing?
- Verify the Priority values on your dialogue nodes
- Check that condition modules return correct boolean values
- Ensure dialogue tree connections are correct

### Quest not tracking?
- Verify player has the ActiveQuest component in ECS
- Check that quest was properly accepted via QuestManager
- Look for quest system debug prints in console

## Related Files

- **Quest Manager:** `src/ReplicatedStorage/Modules/Utils/QuestManager.lua`
- **Quest Data:** `src/ReplicatedStorage/Modules/Quests.luau`
- **Dialogue System:** `src/ReplicatedStorage/Client/Dialogue.lua`
- **ECS Components:** `src/ReplicatedStorage/Modules/ECS/jecs_components.luau`

## Summary

With quest-based dialogue conditions, you can create dynamic NPC interactions that respond to player progress:

✅ **Default dialogue** for new players  
✅ **Reminder dialogue** for active quests  
✅ **Completion dialogue** for finished quests  
✅ **Custom conditions** for complex quest logic  

This creates a more immersive and responsive quest experience!

