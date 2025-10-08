# Dialogue Module Cheat Sheet

Quick reference for creating dialogue modules.

---

## Basic Template

```lua
return {
	NPCName = "NPCName",
	Nodes = {
		-- Your nodes here
	}
}
```

---

## Node Templates

### Root Node (Required)
```lua
{
	Name = "Root",
	Type = "DialogueRoot",
	Priority = 0,
	Outputs = {"FirstNode"}
}
```

### Simple Dialogue
```lua
{
	Name = "NodeName",
	Type = "Prompt",
	Priority = 0,
	Text = "What the NPC says",
	Outputs = {"NextNode"}
}
```

### End Dialogue (No Outputs)
```lua
{
	Name = "Goodbye",
	Type = "Prompt",
	Priority = 0,
	Text = "Farewell!",
	Outputs = {} -- Empty = end dialogue
}
```

### Player Responses
```lua
{
	Name = "PlayerChoice",
	Type = "Response",
	Priority = 0,
	Text = "Question or prompt",
	Responses = {
		{
			Text = "Option 1",
			Outputs = {"Node1"}
		},
		{
			Text = "Option 2",
			Outputs = {"Node2"}
		}
	}
}
```

---

## Quest Integration

### Accept Quest
```lua
{
	Name = "AcceptQuest",
	Type = "Dialogue",
	Priority = 0,
	Text = "Thank you for helping!",
	Quest = {
		Action = "Accept",
		QuestName = "QuestNameHere"
	},
	Outputs = {}
}
```

### Complete Quest
```lua
{
	Name = "CompleteQuest",
	Type = "Dialogue",
	Priority = 2,
	Text = "You did it! Here's your reward.",
	Quest = {
		Action = "Complete",
		QuestName = "QuestNameHere"
	},
	Outputs = {}
}
```

---

## Conditional Dialogue

### Has Active Quest
```lua
{
	Name = "QuestReminder",
	Type = "Dialogue",
	Priority = 1,
	Text = "Did you find the item yet?",
	Condition = {
		Module = "HasActiveQuest",
		Args = {"NPCName"}
	},
	Outputs = {}
}
```

### Has Completed Quest
```lua
{
	Name = "AfterQuest",
	Type = "Dialogue",
	Priority = 2,
	Text = "Thanks again for your help!",
	Condition = {
		Module = "HasCompletedQuest",
		Args = {"NPCName", "QuestName"}
	},
	Outputs = {}
}
```

---

## Priority Levels

| Priority | Use Case |
|----------|----------|
| 0 | Default dialogue (no conditions) |
| 1 | Active quest dialogue |
| 2 | Completed quest dialogue |
| 3+ | Custom conditions |

**Higher priority = shown first when condition is true**

---

## Common Patterns

### Quest Flow
```lua
-- Root with 3 paths
{
	Name = "Root",
	Type = "DialogueRoot",
	Priority = 0,
	Outputs = {"Default", "QuestActive", "QuestComplete"}
},

-- Default (Priority 0)
{
	Name = "Default",
	Type = "Dialogue",
	Priority = 0,
	Text = "I need help!",
	Outputs = {"OfferQuest"}
},

-- Quest Active (Priority 1)
{
	Name = "QuestActive",
	Type = "Dialogue",
	Priority = 1,
	Text = "Any progress?",
	Condition = {
		Module = "HasActiveQuest",
		Args = {"NPCName"}
	},
	Outputs = {}
},

-- Quest Complete (Priority 2)
{
	Name = "QuestComplete",
	Type = "Dialogue",
	Priority = 2,
	Text = "Thank you!",
	Condition = {
		Module = "HasCompletedQuest",
		Args = {"NPCName", "QuestName"}
	},
	Outputs = {}
}
```

### Branching Dialogue
```lua
{
	Name = "Question",
	Type = "Response",
	Priority = 0,
	Text = "What do you want to know?",
	Responses = {
		{
			Text = "Tell me about yourself",
			Outputs = {"AboutMe"}
		},
		{
			Text = "What's this place?",
			Outputs = {"AboutPlace"}
		},
		{
			Text = "Never mind",
			Outputs = {"Goodbye"}
		}
	}
}
```

### Looping Dialogue
```lua
-- Main menu that loops back to itself
{
	Name = "MainMenu",
	Type = "Response",
	Priority = 0,
	Text = "What can I do for you?",
	Responses = {
		{
			Text = "Option 1",
			Outputs = {"DoThing1", "MainMenu"} -- Do thing, then back to menu
		},
		{
			Text = "Option 2",
			Outputs = {"DoThing2", "MainMenu"}
		},
		{
			Text = "Leave",
			Outputs = {"Goodbye"}
		}
	}
}
```

---

## Quick Tips

✅ **Node names** must be unique  
✅ **Outputs** must match node names exactly (case-sensitive)  
✅ **Priority 0** = default, always shown if no higher priority matches  
✅ **Empty Outputs** = end dialogue  
✅ **Quest.Action** = "Accept" or "Complete"  
✅ **Condition.Module** = name of module in DialogueConditions folder  

---

## Testing Checklist

- [ ] Root node exists with Type = "DialogueRoot"
- [ ] All node names are unique
- [ ] All Outputs reference existing nodes
- [ ] Quest names match quest data
- [ ] Condition modules exist
- [ ] Priority levels are correct
- [ ] No circular references (infinite loops)
- [ ] Dialogue ends properly (empty Outputs or loops back)

---

## Building Dialogue

### Auto-build on game start:
Dialogue is automatically built by `InitDialogues.client.lua`

### Manual build:
```lua
local DialogueBuilder = require(ReplicatedStorage.Modules.Utils.DialogueBuilder)
DialogueBuilder.BuildDialogue("NPCName")
```

### Build all:
```lua
DialogueBuilder.BuildAll()
```

---

## File Structure

```
ReplicatedStorage
├── Modules
│   ├── DialogueData
│   │   ├── Magnus.lua
│   │   ├── SimpleShopkeeper.lua
│   │   └── YourNPC.lua
│   └── Utils
│       ├── DialogueBuilder.lua
│       └── DialogueConditions
│           ├── HasActiveQuest.lua
│           └── HasCompletedQuest.lua
└── Dialogues (auto-generated)
    ├── Magnus (Folder with Configurations)
    ├── SimpleShopkeeper
    └── YourNPC
```

---

## Example: Complete Simple NPC

```lua
return {
	NPCName = "Guard",
	
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
			Text = "Halt! State your business.",
			Outputs = {"AskBusiness"}
		},
		
		{
			Name = "AskBusiness",
			Type = "Response",
			Priority = 0,
			Text = "What brings you here?",
			Responses = {
				{
					Text = "Just passing through.",
					Outputs = {"PassThrough"}
				},
				{
					Text = "I'm looking for work.",
					Outputs = {"LookingForWork"}
				}
			}
		},
		
		{
			Name = "PassThrough",
			Type = "Dialogue",
			Priority = 0,
			Text = "Very well. Move along.",
			Outputs = {}
		},
		
		{
			Name = "LookingForWork",
			Type = "Dialogue",
			Priority = 0,
			Text = "Talk to the captain inside.",
			Outputs = {}
		}
	}
}
```

---

That's it! Copy a template, fill in your dialogue, and you're done! 🎉

