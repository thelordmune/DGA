# Quest Marker System

The Quest Marker System displays visual markers above quest NPCs and quest objectives in the game world, helping players navigate and track their quests.

## Features

### 1. **Quest NPC Markers**
- **Available Quest (Gold "!")**: Shows when an NPC has a quest available and the player doesn't have an active quest
- **Active Quest (Gold "!")**: Shows when the player has accepted a quest from this NPC but hasn't completed it yet
- **Turn-in Quest (Green "?")**: Shows when the player has completed the quest objectives and can turn in the quest

### 2. **Quest Objective Markers**
- **Blue Star Icon**: Shows above quest items in the world (e.g., Magnus's Pocketwatch)
- Automatically appears when a quest is active
- Disappears when the quest item is collected

### 3. **Dynamic Positioning**
- Markers follow NPCs and objects in 3D space
- Convert world positions to screen positions in real-time
- Show distance to the marker

### 4. **Off-Screen Indicators**
- When a marker is off-screen, an arrow appears at the edge of the screen
- Arrow points in the direction of the marker
- Helps players find quest objectives even when not visible

### 5. **Distance-Based Visibility**
- Markers only show within 500 studs
- Scale based on distance for better depth perception
- Fade out when too far away

## Implementation

### Components Added

#### 1. **ECS Component: QuestMarker**
```lua
QuestMarker: Entity<{markerType: string, npcName: string, questName: string?}>
```

Added to `src/ReplicatedStorage/Modules/ECS/jecs_components.luau`

#### 2. **Client Module: QuestMarkers.lua**
Location: `src/ReplicatedStorage/Client/QuestMarkers.lua`

This module:
- Monitors the player's active quest state
- Creates/updates markers for NPCs in `workspace.World.Dialogue`
- Creates/updates markers for quest items in `workspace.World.Quests`
- Uses the `MarkerIcon` Fusion component for rendering
- Initialized by `PlayerHandler` on character spawn

### How It Works

1. **Initialization**
   - Module is loaded by `PlayerHandler` on character spawn
   - `QuestMarkers.Init()` is called from `PlayerHandler/init.client.lua`
   - Waits for character to load
   - Begins monitoring quest state

2. **NPC Marker Updates**
   - Scans `workspace.World.Dialogue` for NPCs
   - Checks player's active quest state
   - Determines which marker type to show:
     - No active quest + NPC has quest = Gold "!" (available)
     - Active quest from this NPC + no item = Gold "!" (in progress)
     - Active quest from this NPC + has item = Green "?" (turn-in)

3. **Objective Marker Updates**
   - Scans `workspace.World.Quests/[NPCName]` for quest items
   - Only shows when player has an active quest
   - Hides when quest item is collected

4. **Real-time Positioning**
   - Uses `RunService.RenderStepped` for smooth updates
   - Converts 3D world positions to 2D screen positions
   - Calculates distance from player
   - Determines if marker is on/off screen

## Usage

### For Quest Designers

The system automatically works with the existing quest system. To add quest markers:

1. **Quest NPCs**: Place NPCs in `workspace.World.Dialogue`
2. **Quest Items**: Place items in `workspace.World.Quests/[NPCName]/`
3. **Quest Data**: Define quests in `ReplicatedStorage.Modules.Quests`

Example:
```lua
-- In Quests.luau
return {
    ["Magnus"] = {
        ["Missing Pocketwatch"] = {
            ["Description"] = "Find Magnus' pocketwatch...",
            ["Rewards"] = {...}
        }
    }
}
```

### Marker Types

```lua
local MARKER_CONFIG = {
    questAvailable = {
        type = "quest",
        color = Color3.fromRGB(255, 215, 0), -- Gold
        icon = "rbxassetid://18621831828",
    },
    questActive = {
        type = "quest",
        color = Color3.fromRGB(143, 255, 143), -- Green
        icon = "rbxassetid://18621831828",
    },
    questObjective = {
        type = "objective",
        color = Color3.fromRGB(121, 197, 255), -- Blue
        icon = "rbxassetid://18621831828",
    },
}
```

## Integration with Existing Systems

### Quest System
- Monitors `ActiveQuest` component on player entity
- Monitors `QuestItemCollected` component
- Uses `QuestData` from `ReplicatedStorage.Modules.Quests`

### Dialogue System
- Reads NPCs from `workspace.World.Dialogue`
- Works with existing dialogue proximity detection

### ECS (Entity Component System)
- Uses `ref.get("local_player")` to get player entity
- Queries components using `world:has()` and `world:get()`

## Performance Considerations

1. **Update Frequency**
   - NPC markers update every 1 second
   - Position updates every frame (RenderStepped)
   - Efficient cleanup when markers are removed

2. **Distance Culling**
   - Markers beyond 500 studs are hidden
   - Reduces rendering overhead

3. **Scope Management**
   - Each marker has its own Fusion scope
   - Proper cleanup prevents memory leaks
   - Scopes are destroyed when markers are removed

## Future Enhancements

Potential improvements:
- Custom icons for different quest types
- Quest path/waypoint system
- Mini-map integration
- Quest chain indicators
- Multiple active quests support
- Quest priority indicators

## Troubleshooting

### Markers Not Showing

1. **Check NPC Location**: NPCs must be in `workspace.World.Dialogue`
2. **Check Quest Data**: Quest must be defined in `Quests.luau`
3. **Check Distance**: Player must be within 500 studs
4. **Check Console**: Look for warnings in output

### Markers Not Updating

1. **Check Active Quest**: Use ECS debugger to verify `ActiveQuest` component
2. **Check Quest Item**: Verify `QuestItemCollected` component state
3. **Restart Script**: Try rejoining the game

### Performance Issues

1. **Too Many Markers**: Limit quest items in the world
2. **Update Frequency**: Adjust the 1-second update interval if needed
3. **Distance Culling**: Reduce the 500 stud visibility range

## Code References

- **QuestMarkers Module**: `src/ReplicatedStorage/Client/QuestMarkers.lua`
- **PlayerHandler**: `src/StarterPlayer/StarterPlayerScripts/PlayerHandler/init.client.lua`
- **MarkerIcon Component**: `src/ReplicatedStorage/Client/Components/MarkerIcon.lua`
- **Quest System**: `src/ReplicatedStorage/Modules/Utils/QuestManager.lua`
- **ECS Components**: `src/ReplicatedStorage/Modules/ECS/jecs_components.luau`
- **Quest Data**: `src/ReplicatedStorage/Modules/Quests.luau`

