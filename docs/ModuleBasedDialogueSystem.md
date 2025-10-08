## Module-Based Dialogue System

A clean, easy-to-use dialogue system that converts Lua modules into Configuration structures automatically.

---

## Why Use This System?

### ❌ Old Way (Configuration-based):
- Create Configurations manually in Studio
- Set attributes one by one
- Create ObjectValues for connections
- Easy to make mistakes
- Hard to version control
- Difficult to read and maintain

### ✅ New Way (Module-based):
- Write dialogue in clean Lua tables
- Automatic conversion to Configurations
- Easy to read and edit
- Version control friendly
- Type checking and validation
- Copy/paste friendly

---

## Quick Start

### Step 1: Create a Dialogue Module

Create a new ModuleScript in `ReplicatedStorage/Modules/DialogueData/YourNPCName.lua`:

```lua
return {
	NPCName = "YourNPCName",
	
	Nodes = {
		{
			Name = "Root",
			Type = "DialogueRoot",
			Priority = 0,
			Outputs = {"Greeting"}
		},
		
		{
			Name = "Greeting",
			Type = "Dialogue",
			Priority = 0,
			Text = "Hello traveler!",
			Outputs = {}
		}
	}
}
```

### Step 2: Build the Dialogue

The dialogue is automatically built when the game starts via `InitDialogues.client.lua`.

Or manually build it:
```lua
local DialogueBuilder = require(ReplicatedStorage.Modules.Utils.DialogueBuilder)
DialogueBuilder.BuildDialogue("YourNPCName")
```

### Step 3: Done!

Your dialogue is now available in `ReplicatedStorage.Dialogues.YourNPCName` as Configurations.

---

## Node Types

### 1. DialogueRoot
The starting point of your dialogue tree.

```lua
{
	Name = "Root",
	Type = "DialogueRoot",
	Priority = 0,
	Outputs = {"FirstNode", "SecondNode"}
}
```

### 2. Dialogue
A dialogue line spoken by the NPC.

```lua
{
	Name = "Greeting",
	Type = "Dialogue",
	Priority = 0,
	Text = "Hello! How can I help you?",
	Outputs = {"AskQuestion"}
}
```

### 3. Response
Player response options.

```lua
{
	Name = "PlayerChoice",
	Type = "Response",
	Priority = 0,
	Text = "What would you like to do?",
	Responses = {
		{
			Text = "Ask about quests",
			Outputs = {"QuestInfo"}
		},
		{
			Text = "Say goodbye",
			Outputs = {"Goodbye"}
		}
	}
}
```

---

## Advanced Features

### Quest Integration

#### Accept Quest
```lua
{
	Name = "AcceptQuest",
	Type = "Dialogue",
	Priority = 0,
	Text = "Thank you for helping!",
	Quest = {
		Action = "Accept",
		QuestName = "Missing Pocketwatch"
	},
	Outputs = {}
}
```

#### Complete Quest
```lua
{
	Name = "CompleteQuest",
	Type = "Dialogue",
	Priority = 2,
	Text = "You found it! Thank you!",
	Quest = {
		Action = "Complete",
		QuestName = "Missing Pocketwatch"
	},
	Outputs = {"GiveReward"}
}
```

### Conditional Dialogue

Show different dialogue based on quest status:

```lua
{
	Name = "QuestActiveGreeting",
	Type = "Dialogue",
	Priority = 1,
	Text = "Did you find the item yet?",
	Condition = {
		Module = "HasActiveQuest",
		Args = {"Magnus"}
	},
	Outputs = {"StillLooking"}
}
```

**Available Conditions:**
- `HasActiveQuest` - Check if player has active quest from NPC
- `HasCompletedQuest` - Check if player completed a quest
- Custom conditions (create your own!)

---

## Complete Example: Magnus NPC

```lua
return {
	NPCName = "Magnus",
	
	Nodes = {
		-- Root
		{
			Name = "Root",
			Type = "DialogueRoot",
			Priority = 0,
			Outputs = {"DefaultGreeting", "QuestActiveGreeting", "QuestCompleteGreeting"}
		},
		
		-- Default greeting (no quest)
		{
			Name = "DefaultGreeting",
			Type = "Dialogue",
			Priority = 0,
			Text = "Hello! I've lost my pocketwatch. Can you help?",
			Outputs = {"OfferQuest"}
		},
		
		-- Offer quest
		{
			Name = "OfferQuest",
			Type = "Response",
			Priority = 0,
			Text = "Will you help me?",
			Responses = {
				{
					Text = "Yes, I'll help.",
					Outputs = {"Accept"}
				},
				{
					Text = "No, sorry.",
					Outputs = {"Decline"}
				}
			}
		},
		
		-- Accept quest
		{
			Name = "Accept",
			Type = "Dialogue",
			Priority = 0,
			Text = "Thank you! Check the market stalls!",
			Quest = {
				Action = "Accept",
				QuestName = "Missing Pocketwatch"
			},
			Outputs = {}
		},
		
		-- Decline quest
		{
			Name = "Decline",
			Type = "Dialogue",
			Priority = 0,
			Text = "I understand. Come back if you change your mind.",
			Outputs = {}
		},
		
		-- Quest active (player has quest)
		{
			Name = "QuestActiveGreeting",
			Type = "Dialogue",
			Priority = 1,
			Text = "Did you find my pocketwatch yet?",
			Condition = {
				Module = "HasActiveQuest",
				Args = {"Magnus"}
			},
			Outputs = {}
		},
		
		-- Quest complete
		{
			Name = "QuestCompleteGreeting",
			Type = "Dialogue",
			Priority = 2,
			Text = "You found it! Thank you so much!",
			Condition = {
				Module = "HasCompletedQuest",
				Args = {"Magnus", "Missing Pocketwatch"}
			},
			Quest = {
				Action = "Complete",
				QuestName = "Missing Pocketwatch"
			},
			Outputs = {}
		}
	}
}
```

---

## Node Properties Reference

### Common Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `Name` | string | ✅ | Unique identifier for the node |
| `Type` | string | ✅ | Node type (DialogueRoot, Dialogue, Response) |
| `Priority` | number | ✅ | Priority for conditional branching (0 = default, 1+ = conditional) |
| `Outputs` | table | ❌ | Array of node names to connect to |

### Dialogue-Specific Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `Text` | string | ✅ | The dialogue text to display |
| `Quest` | table | ❌ | Quest action (Accept/Complete) |
| `Condition` | table | ❌ | Conditional logic for this node |

### Response-Specific Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `Text` | string | ✅ | The question/prompt text |
| `Responses` | table | ✅ | Array of response options |

### Quest Property Structure

```lua
Quest = {
	Action = "Accept" or "Complete",
	QuestName = "Quest Name Here"
}
```

### Condition Property Structure

```lua
Condition = {
	Module = "ConditionModuleName",
	Args = {"arg1", "arg2", ...}
}
```

---

## Priority System

The priority system determines which dialogue path to take when multiple options exist:

- **Priority 0**: Default path (always available)
- **Priority 1**: Active quest path (shown when condition is true)
- **Priority 2**: Completed quest path (shown when quest is done)
- **Priority 3+**: Custom conditional paths

**How it works:**
1. System checks all nodes connected from Root
2. Evaluates conditions for each node
3. Chooses the node with the highest priority where condition is true
4. Falls back to Priority 0 if no conditions match

---

## Creating Custom Conditions

Create a new module in `ReplicatedStorage/Modules/Utils/DialogueConditions/`:

```lua
-- MyCustomCondition.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MyCustomCondition = {}

function MyCustomCondition.Run(arg1, arg2)
	local player = Players.LocalPlayer
	
	-- Your custom logic here
	if player:GetAttribute("SomeAttribute") == arg1 then
		return true
	end
	
	return false
end

return MyCustomCondition
```

Then use it in your dialogue:

```lua
{
	Name = "CustomNode",
	Type = "Dialogue",
	Priority = 1,
	Text = "Special dialogue!",
	Condition = {
		Module = "MyCustomCondition",
		Args = {"value1", "value2"}
	},
	Outputs = {}
}
```

---

## Best Practices

### ✅ DO:
- Use descriptive node names (`AcceptQuest`, not `Node1`)
- Keep dialogue text concise and readable
- Use priority system for quest-based branching
- Test dialogue paths thoroughly
- Comment complex dialogue flows

### ❌ DON'T:
- Create circular references (infinite loops)
- Use duplicate node names
- Forget to set Outputs (unless ending dialogue)
- Mix quest states in same priority level
- Hardcode quest names (use constants)

---

## Troubleshooting

### "Dialogue not showing"
- ✅ Check NPC name matches module name exactly
- ✅ Verify dialogue was built (check ReplicatedStorage.Dialogues)
- ✅ Ensure Root node exists with Type = "DialogueRoot"

### "Outputs not connecting"
- ✅ Verify output node names match exactly (case-sensitive)
- ✅ Check for typos in Outputs array
- ✅ Ensure target nodes exist

### "Condition not working"
- ✅ Verify condition module exists in DialogueConditions folder
- ✅ Check Args are correct type and order
- ✅ Test condition module independently

### "Quest not accepting/completing"
- ✅ Verify Quest.Action is "Accept" or "Complete"
- ✅ Check Quest.QuestName matches quest data
- ✅ Ensure quest system is initialized

---

## Migration from Old System

To convert existing Configuration-based dialogues:

1. **Create a new module** in DialogueData folder
2. **Copy node structure** from Studio
3. **Convert to table format** using the examples above
4. **Test thoroughly** to ensure same behavior
5. **Delete old Configurations** once verified

---

## Summary

✅ **Easy to write** - Clean Lua tables instead of Studio configurations  
✅ **Automatic conversion** - DialogueBuilder handles the complexity  
✅ **Quest integration** - Built-in quest accept/complete support  
✅ **Conditional dialogue** - Show different text based on quest status  
✅ **Version control friendly** - Track changes in Git  
✅ **Type safe** - Lua validation catches errors early  
✅ **Maintainable** - Easy to read and modify  

Write dialogue in modules, let the system handle the rest! 🎉

