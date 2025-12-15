# Leveling Data Persistence System

## Overview

The leveling system now automatically saves player Level, Experience, and Alignment data to the DataStore whenever these values change.

## Changes Made

### 1. **Updated Data Template** (`src/ServerScriptService/ServerConfig/Server/Data/Template.lua`)

Added Experience and TotalExperience fields to the player data template:

```lua
["Level"] = 1,
["Experience"] = 0,          -- NEW: Current XP towards next level
["TotalExperience"] = 0,     -- NEW: Total XP earned (lifetime)
["Alignment"] = 0,
```

### 2. **Enhanced LevelingManager** (`src/ReplicatedStorage/Modules/Utils/LevelingManager.lua`)

#### Loading from DataStore

The `initialize()` function now accepts optional `playerData` parameter:

```lua
LevelingManager.initialize(entity, playerData)
```

- If `playerData` is provided, loads saved Level, Experience, and Alignment
- If not provided, uses default values (Level 1, 0 XP, 0 Alignment)

#### Auto-Save to DataStore

Added new function `saveToDataStore()`:

```lua
LevelingManager.saveToDataStore(player, entity)
```

This function:
- Gets current Level, Experience, and Alignment from ECS components
- Updates the player's ProfileService data
- Uses the Global.SetData() function for safe data updates

#### Automatic Saving

The following functions now **automatically save** when called on the server:

- `LevelingManager.addExperience(entity, amount)` - Saves after adding XP/leveling up
- `LevelingManager.setLevel(entity, newLevel)` - Saves after setting level
- `LevelingManager.addAlignment(entity, amount)` - Saves after changing alignment

**How it works:**
1. Function modifies the ECS components
2. Checks if running on server (`RunService:IsServer()`)
3. Gets the Player instance from the entity's Player component
4. Calls `saveToDataStore()` to persist changes

### 3. **Updated Player Loader** (`src/ServerScriptService/Systems/playerloader.luau`)

Modified character initialization to load saved data using the **Global module**:

```lua
-- Initialize leveling components with saved data
local LevelingManager = require(ReplicatedStorage.Modules.Utils.LevelingManager)
local Global = require(ReplicatedStorage.Modules.Shared.Global)
local playerData = Global.GetData(player)
LevelingManager.initialize(e, playerData)
```

Now when a player spawns:
1. Uses `Global.GetData(player)` to load ProfileService data
2. Initializes Level/Experience/Alignment components with saved values
3. Player continues from where they left off

## Data Flow

### On Player Join

```
Player Joins
    ↓
ProfileService loads data from DataStore
    ↓
playerloader.luau calls Global.GetData(player)
    ↓
LevelingManager.initialize(entity, playerData)
    ↓
ECS components set with saved values
```

### On Level/XP/Alignment Change

```
Quest completed / XP gained
    ↓
LevelingManager.addExperience(entity, amount)
    ↓
ECS components updated
    ↓
LevelingManager.saveToDataStore(player, entity)
    ↓
Global.SetData() updates ProfileService
    ↓
ProfileService auto-saves to DataStore
```

## Usage Examples

### Adding Experience (Auto-saves)

```lua
local LevelingManager = require(ReplicatedStorage.Modules.Utils.LevelingManager)

-- Add 500 XP - automatically saves to DataStore
local success, levelsGained = LevelingManager.addExperience(playerEntity, 500)

if success and levelsGained > 0 then
    ---- print("Player leveled up!", levelsGained, "times")
end
```

### Setting Level (Auto-saves)

```lua
-- Give player a free level - automatically saves to DataStore
LevelingManager.setLevel(playerEntity, 10)
```

### Changing Alignment (Auto-saves)

```lua
-- Add alignment (good action) - automatically saves to DataStore
LevelingManager.addAlignment(playerEntity, 25)

-- Subtract alignment (evil action) - automatically saves to DataStore
LevelingManager.addAlignment(playerEntity, -25)
```

### Manual Save (if needed)

```lua
-- Manually save leveling data (rarely needed since auto-save is enabled)
LevelingManager.saveToDataStore(player, playerEntity)
```

## Data Structure

### In DataStore (ProfileService)

```lua
Profile.Data = {
    Level = 15,              -- Current level (1-50)
    Experience = 350,        -- Current XP towards next level
    TotalExperience = 12500, -- Total XP earned (lifetime stat)
    Alignment = 42,          -- Alignment value (-100 to +100)
    -- ... other player data
}
```

### In ECS Components

```lua
-- Level component
world:get(entity, comps.Level) = {
    current = 15,
    max = 50
}

-- Experience component
world:get(entity, comps.Experience) = {
    current = 350,      -- Current XP towards next level
    required = 2475,    -- XP needed for next level
    total = 12500       -- Total XP earned
}

-- Alignment component
world:get(entity, comps.Alignment) = {
    value = 42,
    min = -100,
    max = 100
}
```

## Benefits

1. **Automatic Persistence** - No need to manually save after every change
2. **Data Integrity** - ECS components and DataStore stay in sync
3. **Player Progression** - Players keep their level/XP when rejoining
4. **Backward Compatible** - Existing code continues to work
5. **Server-Only** - Auto-save only runs on server (safe)

## Testing

To test the system:

1. **Join the game** - Check that your saved level/XP loads
2. **Complete a quest** - Verify XP/level/alignment changes
3. **Rejoin the game** - Confirm progress persists
4. **Check output** - Look for initialization logs showing loaded values

Example log output:
```
[Character] Initialized leveling components for PlayerName - Level: 5, XP: 250
```

## Notes

- Auto-save only runs on the **server** (client calls are ignored)
- **Uses Global module** for all data operations:
  - `Global.GetData(player)` - Loads player data on spawn
  - `Global.SetData(player, modifier)` - Saves leveling changes
- ProfileService handles auto-saving to DataStore via Replion
- No performance impact - saves are batched by ProfileService
- Compatible with existing quest/leveling systems

## Global Module Integration

The system uses your codebase's **Global module** (`src/ReplicatedStorage/Modules/Shared/Global.luau`) for all data access:

### Loading Data
```lua
local Global = require(ReplicatedStorage.Modules.Shared.Global)
local playerData = Global.GetData(player)
-- Returns entire player data table
```

### Saving Data
```lua
Global.SetData(player, function(data)
    data.Level = 15
    data.Experience = 350
    data.TotalExperience = 12500
    data.Alignment = 42
    return data
end)
```

This ensures consistency with the rest of your codebase and leverages Replion's automatic replication and ProfileService's auto-save functionality.

