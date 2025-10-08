# Leveling and Alignment System

## Overview

A comprehensive leveling and alignment system with:
- **Level Range:** 1-50
- **Exponential XP Curve:** Smooth progression from level 1 to 50
- **Alignment System:** -100 (Evil) to +100 (Good)
- **Quest Completion UI:** Zone-style popup showing rewards

## Components

### ECS Components

#### Level Component
```lua
Level: Entity<{current: number, max: number}>
```
- `current`: Player's current level (1-50)
- `max`: Maximum level (50)

#### Experience Component
```lua
Experience: Entity<{current: number, required: number, total: number}>
```
- `current`: Current XP towards next level
- `required`: XP needed for next level
- `total`: Total XP earned (lifetime)

#### Alignment Component
```lua
Alignment: Entity<{value: number, min: number, max: number}>
```
- `value`: Current alignment (-100 to +100)
- `min`: Minimum alignment (-100)
- `max`: Maximum alignment (+100)

## Experience Formula

**Formula:** `XP = baseXP * (level ^ exponent) + (level * multiplier)`

**Constants:**
- `baseXP = 100`
- `exponent = 1.5`
- `multiplier = 50`

**Example XP Requirements:**
- Level 1 → 2: 150 XP
- Level 10 → 11: 1,516 XP
- Level 25 → 26: 5,125 XP
- Level 49 → 50: 17,093 XP

This creates a smooth exponential curve that feels rewarding at low levels and challenging at high levels.

## Alignment Tiers

| Alignment Range | Tier Name |
|----------------|-----------|
| 75 to 100 | Saint |
| 50 to 74 | Hero |
| 25 to 49 | Good |
| -24 to 24 | Neutral |
| -49 to -25 | Evil |
| -74 to -50 | Villain |
| -100 to -75 | Demon |

## LevelingManager API

### Initialize Components
```lua
LevelingManager.initialize(entity)
```
Initializes Level, Experience, and Alignment components for a player entity.

### Add Experience
```lua
local success, levelsGained = LevelingManager.addExperience(entity, amount)
```
- Adds XP to player
- Automatically handles level ups
- Returns number of levels gained

### Set Level
```lua
LevelingManager.setLevel(entity, newLevel)
```
- Directly sets player level (for rewards like free levels)
- Resets current XP to 0

### Add Alignment
```lua
local success, newAlignment = LevelingManager.addAlignment(entity, amount)
```
- Adds/subtracts alignment
- Clamps to -100 to +100 range

### Get Stats
```lua
local level = LevelingManager.getLevel(entity)
local current, required, total = LevelingManager.getExperience(entity)
local alignment = LevelingManager.getAlignment(entity)
local tierName = LevelingManager.getAlignmentTier(alignmentValue)
local progress = LevelingManager.getProgressPercent(entity)
```

## Quest Completion System

### Quest Rewards Structure

In `src/ReplicatedStorage/Modules/Quests.luau`:
```lua
["Magnus"] = {
    ["Missing Pocketwatch"] = {
        ["Description"] = "Find Magnus' pocketwatch...",
        ["Rewards"] = {
            ["Items"] = {
                ["Amestris Pass"] = 1
            },
            ["Experience"] = 100,
            ["Alignment"] = 1  -- Base alignment reward
        }
    }
}
```

### Quest Completion Actions

#### CompleteGood
- Gives **+alignment** (from quest rewards)
- Gives **XP** (from quest rewards)
- Gives **free level** (bonus reward)

#### CompleteEvil
- Gives **-alignment** (negative of quest rewards)
- Gives **XP** (from quest rewards)
- **No free level** (penalty for evil choice)

### Dialogue Integration

Example from Magnus dialogue:
```lua
{
    Name = "ReturnWatch",
    Type = "Prompt",
    Priority = 2,
    Text = "Thank you! Here's a reward and a free level!",
    Quest = {
        Action = "CompleteGood",
        QuestName = "Missing Pocketwatch"
    },
    Outputs = {}
},
{
    Name = "KeepWatch",
    Type = "Prompt",
    Priority = 2,
    Text = "You thief! I trusted you!",
    Quest = {
        Action = "CompleteEvil",
        QuestName = "Missing Pocketwatch"
    },
    Outputs = {}
}
```

## Quest Completion UI

### QuestCompletionPopup Component

Displays:
- Quest name
- Experience gained (+100 XP)
- Alignment change (+5 Alignment / -5 Alignment)
- Level up notification (LEVEL UP! → 15)

**Styling:**
- Gold border and title
- Green text for positive alignment
- Red text for negative alignment
- Blue text for experience
- Slides in from top
- Auto-hides after 5 seconds

### Usage

Server-side (automatic):
```lua
-- In quest completion handler
Bridges.QuestCompleted:Fire(Player, {
    questName = "Missing Pocketwatch",
    experienceGained = 100,
    alignmentGained = 5,  -- or -5 for evil
    leveledUp = true,
    newLevel = 15,
})
```

Client-side (automatic):
```lua
-- QuestCompletionController listens for bridge and shows popup
```

## Implementation Files

### Core System
- `src/ReplicatedStorage/Modules/ECS/jecs_components.luau` - ECS components
- `src/ReplicatedStorage/Modules/Utils/LevelingManager.lua` - Leveling logic
- `src/ServerScriptService/Systems/playerloader.luau` - Initialize components

### UI
- `src/ReplicatedStorage/Client/Components/QuestCompletionPopup.lua` - Popup component
- `src/ReplicatedStorage/Client/QuestCompletionController.lua` - Controller

### Quest Integration
- `src/ServerScriptService/ServerConfig/Server/Network/Quests.lua` - Server handler
- `src/ReplicatedStorage/Client/Dialogue.lua` - Client quest actions
- `src/ReplicatedStorage/Modules/Utils/DialogueBuilder.lua` - Quest data builder
- `src/ReplicatedStorage/Modules/Bridges.luau` - QuestCompleted bridge

### Example
- `src/ReplicatedStorage/Modules/DialogueData/Magnus.lua` - Example quest dialogue

## Testing

### Test Magnus Quest

1. **Build dialogues:**
```lua
require(game.ReplicatedStorage.TestDialogueBuilder)
```

2. **Create Magnus NPC** in `workspace.World.Dialogue`

3. **Talk to Magnus:**
   - First time: Accept quest
   - Find pocketwatch (auto-completes after 10 seconds for testing)
   - Return to Magnus
   - Choose to **return** or **keep** the watch

4. **Observe results:**
   - **Return:** +1 alignment, +100 XP, free level, popup shows rewards
   - **Keep:** -1 alignment, +100 XP, no free level, popup shows penalty

### Check Player Stats

```lua
local LevelingManager = require(game.ReplicatedStorage.Modules.Utils.LevelingManager)
local ref = require(game.ReplicatedStorage.Modules.ECS.jecs_ref)
local player = game.Players.LocalPlayer
local entity = ref.get("local_player")

print("Level:", LevelingManager.getLevel(entity))
print("XP:", LevelingManager.getExperience(entity))
print("Alignment:", LevelingManager.getAlignment(entity))
print("Tier:", LevelingManager.getAlignmentTier(LevelingManager.getAlignment(entity)))
```

## Future Enhancements

- Save/load level, XP, and alignment to player data
- Level-based stat bonuses
- Alignment-based abilities or restrictions
- Level requirements for quests/items
- Prestige system after level 50
- Alignment-based NPC reactions
- XP multipliers for events

