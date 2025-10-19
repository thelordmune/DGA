# Testing Module-Based Dialogues

Quick guide to test the new module-based dialogue system.

---

## Step 1: Build the Dialogues

### Option A: Automatic (Recommended)
The `InitDialogues.client.lua` script in StarterPlayerScripts will automatically build all dialogues when you join the game.

### Option B: Manual Testing
Run this in the **Command Bar** (Studio):

```lua
require(game.ReplicatedStorage.TestDialogueBuilder)
```

This will:
- Build all dialogue modules
- Create Configuration structures in `ReplicatedStorage.Dialogues`
- Print a list of all built dialogues and nodes

---

## Step 2: Verify Dialogues Were Built

1. Open **ReplicatedStorage** in Explorer
2. Look for a folder called **Dialogues**
3. Inside should be folders for each NPC:
   - `Magnus`
   - `SimpleShopkeeper`
4. Each NPC folder should contain Configuration instances for each dialogue node

### Expected Structure:
```
ReplicatedStorage
└── Dialogues
    ├── Magnus
    │   ├── Root (Configuration)
    │   ├── DefaultGreeting (Configuration)
    │   ├── QuestActiveGreeting (Configuration)
    │   └── ... (more nodes)
    └── SimpleShopkeeper
        ├── Root (Configuration)
        └── ... (more nodes)
```

---

## Step 3: Create an NPC

1. In **workspace.World**, create or find a folder called **Dialogue**
2. Inside, create a **Model** named **Magnus** (must match the dialogue module name)
3. Add a **HumanoidRootPart** to the Magnus model
4. Position the NPC where you want

### Quick NPC Setup:
```
workspace
└── World
    └── Dialogue
        └── Magnus (Model)
            ├── HumanoidRootPart (Part)
            └── ... (other parts for appearance)
```

---

## Step 4: Test the Dialogue

1. **Play the game** in Studio
2. **Walk up to Magnus** (within 10 studs)
3. You should see:
   - White outline highlight on Magnus
   - "E TO TALK" UI appears
4. **Press E** to start dialogue
5. You should see:
   - Dialogue UI appears
   - Text: "Hello traveler! I've lost my precious pocketwatch..."
   - Response options appear

---

## Step 5: Test Quest Flow

### Test 1: Accept Quest
1. Talk to Magnus
2. Choose "Yes, I'll help you find it."
3. Quest should be accepted
4. Dialogue should close

### Test 2: Quest Active Reminder
1. Walk away from Magnus
2. Walk back to Magnus
3. Press E to talk again
4. Should see: "Did you find my pocketwatch yet?"
   - This confirms the condition system is working!

### Test 3: Quest Complete
1. Complete the quest (find the pocketwatch)
2. Return to Magnus
3. Press E to talk
4. Should see: "You found it! Thank you so much!"

---

## Troubleshooting

### "Dialogues folder not found"

**Solution:**
- Run the TestDialogueBuilder script manually
- Check for errors in the Output window
- Make sure `DialogueBuilder.lua` exists in `ReplicatedStorage.Modules.Utils`

### "Dialogue not showing when I press E"

**Check:**
1. ✅ NPC model name matches dialogue module name exactly (case-sensitive)
2. ✅ NPC is in `workspace.World.Dialogue` folder
3. ✅ NPC has a HumanoidRootPart
4. ✅ Dialogues folder exists in ReplicatedStorage
5. ✅ Root node exists in the dialogue tree

**Debug:**
- Open F9 console and look for `[Dialogue]` messages
- Check if "E TO TALK" UI appears (proximity detection working)
- Look for error messages about missing dialogue trees

### "Quest reminder not showing"

**Check:**
1. ✅ Quest was accepted successfully
2. ✅ `HasActiveQuest` condition module exists
3. ✅ Condition is properly set up in Magnus.lua
4. ✅ Priority is set correctly (Priority 1 for quest active)

**Debug:**
- Check F9 console for condition check messages
- Verify quest was added to player (check ECS components)
- Make sure you walked away and came back (dialogue needs to restart)

### "Getting errors about ModuleName attribute"

**Solution:**
- Make sure you're using the updated `Dialogue.lua` with the new CheckForCondition function
- The system should support both old ModuleScript-based and new attribute-based conditions

---

## Console Output

When working correctly, you should see output like:

```
[InitDialogues] 🔧 Initializing dialogue system...
[InitDialogues] 📚 Building all dialogue trees...
[DialogueBuilder] Building dialogue for: Magnus
[DialogueBuilder] ✅ Successfully built dialogue for: Magnus
[DialogueBuilder] Building dialogue for: SimpleShopkeeper
[DialogueBuilder] ✅ Successfully built dialogue for: SimpleShopkeeper
[DialogueBuilder] ✅ Built 2 dialogue trees
[InitDialogues] ✅ Dialogue system initialized successfully!
[InitDialogues] 📋 Built dialogues:
  - Magnus
  - SimpleShopkeeper
```

When talking to NPC:

```
[Dialogue] Looking for dialogue tree: Magnus
[Dialogue] Getting root node from tree: Magnus
[Dialogue] Found root node: Root
[Dialogue] Creating Fusion dialogue UI
[Dialogue] Loading node: DefaultGreeting of type: Dialogue
[Dialogue] Checking conditions for node: DefaultGreeting
[Dialogue] Checked 0 conditions, all passed
```

When quest is active:

```
[Dialogue] Checking condition (Attribute): HasActiveQuest
[Magnus Dialogue] Player has active quest from Magnus: Missing Pocketwatch
[Dialogue] Condition result: true
[Dialogue] Loading node: QuestActiveGreeting of type: Dialogue
```

---

## Next Steps

Once basic dialogue is working:

1. **Create more NPCs** - Copy Magnus.lua and modify for new NPCs
2. **Add custom conditions** - Create new condition modules
3. **Complex branching** - Add more response options and paths
4. **Quest integration** - Connect to your quest system

---

## Quick Reference

### Build all dialogues:
```lua
require(game.ReplicatedStorage.TestDialogueBuilder)
```

### Build specific NPC:
```lua
local DialogueBuilder = require(game.ReplicatedStorage.Modules.Utils.DialogueBuilder)
DialogueBuilder.BuildDialogue("Magnus")
```

### Check if dialogue exists:
```lua
local dialogue = game.ReplicatedStorage.Dialogues:FindFirstChild("Magnus")
-- print(dialogue and "Found!" or "Not found")
```

### List all nodes:
```lua
local dialogue = game.ReplicatedStorage.Dialogues.Magnus
for _, node in ipairs(dialogue:GetChildren()) do
    -- print(node.Name, node:GetAttribute("Type"), node:GetAttribute("Priority"))
end
```

---

Good luck testing! 🎉

