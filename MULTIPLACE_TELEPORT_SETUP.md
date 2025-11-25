# Multiplace Teleport System - Complete Setup Guide

## Overview

This system ensures:
1. ✅ Players can only join the main game from the main menu (not directly)
2. ✅ Studio testing is always allowed (bypasses access control)
3. ✅ Player data is properly saved and persists across teleports
4. ✅ Smooth teleportation experience with loading screens

## Place IDs

- **Main Menu**: `138824307106116`
- **Main Game**: `134137392851607`

## Files Created

### Main Menu (Menu Place)

1. **`src/MainMenu/StarterPack/TeleportHandler.client.lua`** (Client)
   - Handles the Play button click
   - Shows loading screen during teleport
   - Requests teleport from server via RemoteEvent
   - Handles teleport errors gracefully

2. **`src/MainMenu/ServerScriptService/TeleportService.server.lua`** (Server)
   - Receives teleport requests from clients
   - Performs server-side teleportation using TeleportService
   - Handles teleport failures and cooldowns
   - Sends error messages back to clients

### Main Game (Game Place)

1. **`src/ServerScriptService/AccessControl.server.lua`**
   - Checks where players are joining from
   - Allows: Studio, Main Menu, or same place (server hop)
   - Blocks: Direct joins from website/game page
   - Redirects unauthorized players back to main menu

2. **`src/ServerScriptService/TeleportDataHandler.server.lua`**
   - Ensures player data is saved before teleporting
   - Syncs Replion data to ProfileService
   - Handles teleport failures
   - Provides manual save request option

## How It Works

### Player Journey

1. **Player joins Main Menu**
   - Menu loads with camera effects and UI
   - Play button becomes available
   - Player clicks Play button

2. **Teleportation Process (Client → Server)**
   - Client: Loading screen appears: "Entering Ironveil..."
   - Client: Fires RemoteEvent to server requesting teleport
   - Server: Receives request and validates player
   - Server: Uses TeleportService:TeleportAsync() to teleport player
   - Player's join data includes source place ID

3. **Main Game Entry**
   - AccessControl checks source place ID
   - If from main menu or studio: Allow entry
   - If direct join: Redirect to main menu
   - Player data loads normally via ProfileService

4. **Data Persistence**
   - ProfileService handles all data storage
   - Data is automatically saved when player leaves
   - TeleportDataHandler ensures sync before teleport
   - Same DataStore used across all places in the game

### Access Control Logic

```lua
-- In Studio: Always allowed
if RunService:IsStudio() then
    return true
end

-- Check source place
if joinData.SourcePlaceId == MAIN_MENU_PLACE_ID then
    return true  -- Came from menu
end

if joinData.SourcePlaceId == MAIN_GAME_PLACE_ID then
    return true  -- Server hop or rejoin
end

-- Otherwise: Redirect to menu
return false
```

## Testing

### In Studio (Development)

1. **Test Main Menu:**
   ```bash
   rojo serve menu.project.json --port 34873
   ```
   - Open Studio, connect to `localhost:34873`
   - Test Play button functionality
   - Note: Teleport won't work in Studio (different place)

2. **Test Main Game:**
   ```bash
   rojo serve default.project.json
   ```
   - Open Studio, connect to `localhost:34872`
   - Access control is DISABLED in Studio
   - All players can join for testing

### In Production (Published)

1. **Publish both places:**
   - Build: `rojo build menu.project.json -o MainMenu.rbxl`
   - Build: `rojo build default.project.json -o MainGame.rbxl`
   - Publish both to Roblox under the same game

2. **Test the flow:**
   - Join the Main Menu place from Roblox
   - Click Play button
   - Should teleport to Main Game
   - Try joining Main Game directly from website
   - Should redirect back to Main Menu

3. **Verify data persistence:**
   - Make changes in Main Game (level up, get items, etc.)
   - Leave and rejoin through Main Menu
   - Data should persist

## Data Persistence Details

### How Data is Shared

Both places use the **same DataStore** because they're part of the same game:
- DataStore key: `"Player_" .. player.UserId`
- ProfileService manages the data
- Replion syncs data to clients
- Data automatically saves on player leave

### What Data Persists

Everything in the player's profile persists:
- Level, Experience, Alignment
- Inventory, Weapons, Alchemy
- Stats (Health, Energy, etc.)
- Quests progress
- Appearance and customization
- All other data in `Template.lua`

### Data Flow

```
Main Menu → Main Game:
1. Player data loads in menu (if needed)
2. Player clicks Play
3. Data auto-saves (ProfileService)
4. Teleport to main game
5. Main game loads same data (same UserId key)
6. Player continues with their data

Main Game → Main Menu:
1. Player data saves automatically
2. Teleport back to menu
3. Menu loads same data
4. Data is consistent
```

## Troubleshooting

### Issue: Players can still join main game directly

**Solution:** 
- Verify AccessControl.server.lua is in ServerScriptService
- Check that place IDs are correct
- Ensure the game is published (not just the places)

### Issue: Data not persisting between places

**Solution:**
- Both places must be under the same game
- Check that ProfileService is using the same DataStore name
- Verify player data is saving before teleport

### Issue: Teleport fails with error

**Solution:**
- Check that both places are published and active
- Verify place IDs are correct
- Check Roblox API services are enabled
- Look for errors in TeleportHandler output

### Issue: Infinite redirect loop

**Solution:**
- Check that MAIN_MENU_PLACE_ID is correct
- Verify the menu place is published
- Check for errors in AccessControl script

## Configuration

### Changing Place IDs

If you need to update the place IDs:

1. **Main Menu** - `src/MainMenu/StarterPack/TeleportHandler.client.lua`:
   ```lua
   local MAIN_GAME_PLACE_ID = YOUR_MAIN_GAME_ID
   ```

2. **Main Game** - `src/ServerScriptService/AccessControl.server.lua`:
   ```lua
   local MAIN_MENU_PLACE_ID = YOUR_MENU_ID
   local MAIN_GAME_PLACE_ID = YOUR_GAME_ID
   ```

### Customizing Loading Screen

Edit `TeleportHandler.client.lua` to customize the loading screen appearance, text, and animations.

### Disabling Access Control (Testing)

To temporarily disable access control for testing:

In `AccessControl.server.lua`, change:
```lua
local isStudio = RunService:IsStudio()
```
to:
```lua
local isStudio = true  -- Always allow (TESTING ONLY)
```

**⚠️ WARNING: Never publish with access control disabled!**

## Best Practices

1. **Always test in Studio first** before publishing
2. **Verify place IDs** are correct before publishing
3. **Test the full flow** from menu → game → menu
4. **Monitor data persistence** during testing
5. **Check error logs** in both places
6. **Keep backup** of working place files

## Future Enhancements

Possible improvements:
- Reserved servers for parties/squads
- Teleport with friends (group teleport)
- Custom loading screens per destination
- Teleport analytics and tracking
- Queue system for full servers

