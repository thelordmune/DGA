# Quest-Based Dialogue - Quick Start Guide

## 5-Minute Setup for "Did you find the item yet?" Dialogue

This guide shows you exactly how to set up an NPC that says different things based on quest progress.

---

## What You'll Create

**Before Quest:**
> "Hello traveler! I've lost my pocketwatch. Can you help me find it?"

**During Quest (when player returns):**
> "Did you find my pocketwatch yet? Check the market stalls!"

**After Quest:**
> "Thank you for finding my pocketwatch! Here's your reward."

---

## Step-by-Step Setup in Roblox Studio

### Step 1: Create the Dialogue Tree Structure

1. Open **ReplicatedStorage** in Explorer
2. Find or create a folder called **Dialogues**
3. Inside Dialogues, create a new **Folder** named **Magnus** (or your NPC's name)

Your structure should look like:
```
ReplicatedStorage
└── Dialogues
    └── Magnus (Folder)
```

### Step 2: Create the Root Node

1. Inside the Magnus folder, create a new **Folder** called **Root**
2. Set an **Attribute** on Root:
   - Name: `Type`
   - Type: String
   - Value: `"Start"`

### Step 3: Create Default Dialogue (No Quest)

1. Create a **Folder** called **DefaultGreeting**
2. Add these attributes to DefaultGreeting:
   - `Type` = `"Dialogue"` (String)
   - `Priority` = `0` (Number)
3. Inside DefaultGreeting, create a **StringValue** called **Text**
4. Set Text.Value to: `"Hello traveler! I've lost my pocketwatch. Can you help me find it?"`

### Step 4: Create Quest Active Dialogue

1. Create a **Folder** called **QuestActiveGreeting**
2. Add these attributes:
   - `Type` = `"Dialogue"` (String)
   - `Priority` = `1` (Number)
3. Inside QuestActiveGreeting, create a **StringValue** called **Text**
4. Set Text.Value to: `"Did you find my pocketwatch yet? Check the market stalls!"`

### Step 5: Create the Condition Node

1. Create a **Folder** called **Condition_ActiveQuest**
2. Add these attributes:
   - `Type` = `"Condition"` (String)
   - `Priority` = `1` (Number)
3. Inside Condition_ActiveQuest, add the **ExampleMagnusActiveQuest** ModuleScript
   - Copy it from: `ReplicatedStorage.Modules.Utils.DialogueConditions.ExampleMagnusActiveQuest`
   - Or create a new ModuleScript and paste the code (see below)

### Step 6: Connect the Nodes

You need to create connections between nodes using **ObjectValue** instances:

#### Connect Root to DefaultGreeting:
1. In **Root**, create an **ObjectValue** called **Output1**
2. Set Output1.Value to **DefaultGreeting**

#### Connect Root to QuestActiveGreeting:
1. In **Root**, create an **ObjectValue** called **Output2**
2. Set Output2.Value to **QuestActiveGreeting**

#### Connect Condition to QuestActiveGreeting:
1. In **QuestActiveGreeting**, create an **ObjectValue** called **Input1**
2. Set Input1.Value to **Condition_ActiveQuest**

---

## Final Structure

Your dialogue tree should look like this:

```
Magnus (Folder)
├── Root (Folder)
│   ├── Type: "Start"
│   ├── Output1 → DefaultGreeting
│   └── Output2 → QuestActiveGreeting
│
├── DefaultGreeting (Folder)
│   ├── Type: "Dialogue"
│   ├── Priority: 0
│   └── Text (StringValue): "Hello traveler! I've lost my pocketwatch..."
│
├── QuestActiveGreeting (Folder)
│   ├── Type: "Dialogue"
│   ├── Priority: 1
│   ├── Input1 → Condition_ActiveQuest
│   └── Text (StringValue): "Did you find my pocketwatch yet?..."
│
└── Condition_ActiveQuest (Folder)
    ├── Type: "Condition"
    ├── Priority: 1
    └── ExampleMagnusActiveQuest (ModuleScript)
```

---

## Condition Module Code

If you need to create the condition module manually, here's the code:

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

local MagnusActiveQuest = {}

function MagnusActiveQuest.Run()
    local player = Players.LocalPlayer
    if not player then return false end
    
    local playerEntity = ref.get("local_player")
    if not playerEntity then return false end
    
    if not world:has(playerEntity, comps.ActiveQuest) then
        return false
    end
    
    local activeQuest = world:get(playerEntity, comps.ActiveQuest)
    if not activeQuest then return false end
    
    -- Check if it's Magnus's quest
    if activeQuest.npcName == "Magnus" then
        print("[Magnus] Player has active quest:", activeQuest.questName)
        return true
    end
    
    return false
end

return MagnusActiveQuest
```

---

## Testing

### Test 1: No Quest
1. Walk up to Magnus NPC
2. Press E to talk
3. Should see: "Hello traveler! I've lost my pocketwatch..."

### Test 2: Active Quest
1. Accept Magnus's quest
2. Walk away from Magnus
3. Walk back to Magnus
4. Press E to talk
5. Should see: "Did you find my pocketwatch yet?..."

### Test 3: After Completing Quest
1. Complete the quest objectives
2. Return to Magnus
3. Should see completion dialogue (if you set it up)

---

## Troubleshooting

### "Dialogue not changing when I have quest"

**Check:**
- ✅ Condition_ActiveQuest has `Type = "Condition"` attribute
- ✅ Condition_ActiveQuest has `Priority = 1` attribute
- ✅ QuestActiveGreeting has `Priority = 1` attribute
- ✅ QuestActiveGreeting has Input1 ObjectValue pointing to Condition_ActiveQuest
- ✅ The ModuleScript is inside Condition_ActiveQuest folder

### "Getting errors in console"

**Check:**
- ✅ All module paths are correct
- ✅ ECS components are loaded
- ✅ Player entity exists (wait a few seconds after spawning)

### "NPC not showing any dialogue"

**Check:**
- ✅ NPC is in workspace.World.Dialogue folder
- ✅ NPC has HumanoidRootPart
- ✅ Dialogue tree is in ReplicatedStorage.Dialogues
- ✅ Dialogue tree name matches NPC name

---

## Next Steps

Once you have basic quest dialogue working, you can:

1. **Add more dialogue paths** for different quest states
2. **Create custom conditions** for specific quest objectives
3. **Add response options** for player choices
4. **Implement quest completion dialogue** with rewards

See the full documentation in `docs/QuestBasedDialogue.md` for advanced features!

---

## Summary

✅ Create dialogue tree in ReplicatedStorage.Dialogues  
✅ Add Root, DefaultGreeting, and QuestActiveGreeting nodes  
✅ Create Condition_ActiveQuest with the condition module  
✅ Connect nodes with ObjectValue references  
✅ Set correct Type and Priority attributes  
✅ Test with and without active quest  

That's it! Your NPC now has quest-aware dialogue! 🎉

