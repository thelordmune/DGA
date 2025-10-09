# Custom Leaderboard System

## Overview

A custom leaderboard UI system that replaces the default Roblox player list. Shows all players in the game with their names, titles, and factions. Toggles with the Period (`.`) key.

---

## Features

✅ **Custom UI** - Replaces default Roblox player list with custom design  
✅ **Dynamic Updates** - Automatically adds/removes players as they join/leave  
✅ **Reactive Data** - Uses Fusion for reactive UI updates  
✅ **Faction Colors** - Border colors change based on player faction  
✅ **Keybind Toggle** - Press Period (`.`) to show/hide  
✅ **Data Integration** - Pulls player data from Global module (ProfileService)  

---

## Architecture

### Components

1. **Leaderboard.lua** (`Client/Components/`)
   - Fusion component that renders the leaderboard frame
   - Contains ScrollingFrame with animated slide-in/out
   - Provides container (Folder) for player entries

2. **Player.lua** (`Client/Components/`)
   - Fusion component that renders individual player entries
   - Shows IGN (player name), Title, and Faction
   - Border color changes based on faction:
     - **None**: Blue (`156, 156, 255`)
     - **Military**: White (`255, 255, 255`)
     - **Rogue**: Red (`255, 0, 0`)

3. **Leaderboard.lua** (`Client/Interface/`)
   - Manager class that handles leaderboard logic
   - Singleton pattern (only one instance)
   - Manages player tracking and UI updates
   - Handles Period (`.`) keybind directly (not through input system)

---

## How It Works

### Initialization

1. **PlayerHandler** calls `Client.Modules["Interface"].InitLeaderboard()`
2. **LeaderboardManager** is created (singleton)
3. Default Roblox player list is disabled via `StarterGui:SetCoreGuiEnabled()`
4. Leaderboard UI is created using Fusion components
5. Player tracking is set up (PlayerAdded/PlayerRemoving)
6. Keybind listener is registered for Period (`.`)

### Player Tracking

```lua
-- When a player joins
Players.PlayerAdded:Connect(function(player)
    LeaderboardManager:AddPlayer(player)
end)

-- When a player leaves
Players.PlayerRemoving:Connect(function(player)
    LeaderboardManager:RemovePlayer(player)
end)
```

### Data Flow

```
Player joins → GetPlayerData() → Global.GetData(player) → Extract data → Create UI component
                                                                              ↓
                                                                    Fusion reactive values
                                                                              ↓
                                                                    Player component renders
```

### Data Updates

- **Automatic**: Updates every 2 seconds for all players
- **Reactive**: Uses Fusion Values for instant UI updates
- **Data Source**: `Global.GetData(player)` from ProfileService

### Player Data Structure

```lua
{
    Player = player,           -- Player instance
    IGN = "PlayerName",        -- Display name
    Title = "Civilian",        -- Player title/rank
    Faction = "None",          -- Faction/clan
    Level = 1,                 -- Player level
}
```

---

## Files Modified/Created

### Created Files

1. `src/ReplicatedStorage/Client/Interface/Leaderboard.lua`
   - Main leaderboard manager class
   - Handles Period (`.`) keybind directly via UserInputService

### Modified Files

1. `src/ReplicatedStorage/Client/Components/Leaderboard.lua`
   - Removed hardcoded player example
   - Cleaned up component structure

2. `src/ReplicatedStorage/Client/Components/Player.lua`
   - Removed unused RichText require

3. `src/ReplicatedStorage/Client/Interface/init.lua`
   - Added `InitLeaderboard()` function

4. `src/StarterPlayer/StarterPlayerScripts/PlayerHandler/init.client.lua`
   - Added leaderboard initialization call

---

## Usage

### Toggle Leaderboard

Press **Period (`.`)** to show/hide the leaderboard.

### Accessing the Leaderboard Manager

```lua
local Interface = require(ReplicatedStorage.Client.Interface)
local leaderboard = Interface.InitLeaderboard()

-- Show leaderboard
leaderboard:Show()

-- Hide leaderboard
leaderboard:Hide()

-- Toggle leaderboard
leaderboard:Toggle()
```

### Customizing Player Data

Edit `LeaderboardManager:GetPlayerData(player)` to change what data is displayed:

```lua
function LeaderboardManager:GetPlayerData(player)
    local data = Global.GetData(player)
    
    return {
        Player = player,
        IGN = player.Name,
        Title = (data and data.Title) or "Civilian",
        Faction = (data and data.Clan) or "None",
        Level = (data and data.Level) or 1,
    }
end
```

---

## Faction Colors

The Player component uses a UIGradient that changes based on faction:

```lua
-- In Player.lua
scope:Computed(function(use)
    return if use(faction) == "None" then 
        ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(156, 156, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(156, 156, 255)),
        })
    elseif use(faction) == "Military" then
        ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255)),
        })
    elseif use(faction) == "Rogue" then
        ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0)),
        })
    else
        -- Default color
        ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(156, 156, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(156, 156, 255)),
        })
end)
```

---

## Technical Details

### Fusion Scope Management

The LeaderboardManager uses a Fusion scope to manage UI lifecycle:

```lua
self.scope = scoped(Fusion, {
    PlayerComponent = require(ReplicatedStorage.Client.Components.Player),
    LeaderboardComponent = require(ReplicatedStorage.Client.Components.Leaderboard)
})
```

This ensures proper cleanup when the leaderboard is destroyed.

### Reactive Values

Each player entry uses Fusion Values for reactive updates:

```lua
local ignValue = self.scope:Value(playerData.IGN)
local titleValue = self.scope:Value(playerData.Title)
local factionValue = self.scope:Value(playerData.Faction)
```

When these values change, the UI automatically updates.

### Singleton Pattern

Only one LeaderboardManager instance can exist:

```lua
local instance = nil

function LeaderboardManager.new()
    if instance then
        return instance
    end
    -- ... create new instance
    instance = self
    return self
end
```

---

## Future Enhancements

Potential improvements:

1. **Sorting** - Sort players by level, faction, or name
2. **Search** - Filter players by name
3. **Click Actions** - Click player to view profile, send friend request, etc.
4. **Stats Display** - Show additional stats (kills, deaths, playtime)
5. **Team Grouping** - Group players by faction/team
6. **Animations** - Add entry/exit animations for players
7. **Scrollbar Styling** - Custom scrollbar design

---

## Troubleshooting

### Leaderboard doesn't show

- Check console for errors
- Verify `InitLeaderboard()` is called in PlayerHandler
- Ensure Period (`.`) keybind isn't conflicting with other systems

### Player data not updating

- Check `Global.GetData(player)` returns valid data
- Verify ProfileService is loading player data correctly
- Check update loop is running (every 2 seconds)

### UI positioning issues

- Check `Leaderboard.lua` component's Position property
- Verify ScreenGui DisplayOrder is high enough (currently 10)
- Check for conflicting UI elements

---

## Summary

The custom leaderboard system provides a clean, faction-aware player list that integrates with your existing data system. It uses Fusion for reactive UI updates and automatically tracks players joining/leaving the game.

**Key Benefits:**
- Replaces default Roblox player list
- Shows custom player data (title, faction, level)
- Reactive updates via Fusion
- Easy to extend and customize

