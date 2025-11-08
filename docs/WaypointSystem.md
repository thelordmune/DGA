# Waypoint Marker System

The waypoint marker system allows you to create custom markers on any part or model in the workspace. These markers appear as on-screen icons with distance indicators and off-screen directional arrows.

## Features

- ✅ Place markers on any BasePart or Model
- ✅ Customizable colors, icons, and labels
- ✅ Distance-based visibility
- ✅ Off-screen directional arrows
- ✅ Automatic cleanup when parts are destroyed
- ✅ Easy-to-use API

## Quick Start

### Method 1: Using the API

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)

-- Create a basic waypoint
local part = workspace.SomePart
local markerKey = QuestMarkers.CreateWaypoint(part, "Destination")

-- Remove the waypoint later
QuestMarkers.RemoveWaypoint(markerKey)
```

### Method 2: Using the PartWaypoint Script

1. Copy `StarterPlayerScripts/Examples/PartWaypoint.client.lua`
2. Place it inside any part in the workspace
3. Set optional attributes on the part:
   - `WaypointLabel` (string): Custom label text
   - `WaypointColor` (Color3): Marker color
   - `WaypointHeight` (number): Height offset above part
   - `WaypointDistance` (number): Max visibility distance
4. The waypoint will automatically appear when players spawn

## API Reference

### QuestMarkers.CreateWaypoint()

Creates a waypoint marker on a part or model.

**Parameters:**
- `part` (BasePart | Model): The part or model to place the marker on
- `label` (string, optional): Custom label text (defaults to part name)
- `config` (table, optional): Configuration options
  - `color` (Color3): Marker color (default: white)
  - `icon` (string): Asset ID for marker icon (default: star)
  - `heightOffset` (number): Height above part in studs (default: 5)
  - `maxDistance` (number): Max visibility distance in studs (default: 500)

**Returns:**
- `markerKey` (string): Unique key for this marker, used to remove it later

**Example:**
```lua
local markerKey = QuestMarkers.CreateWaypoint(workspace.TreasureChest, "Treasure", {
    color = Color3.fromRGB(255, 215, 0), -- Gold
    heightOffset = 10,
    maxDistance = 1000,
})
```

### QuestMarkers.RemoveWaypoint()

Removes a waypoint marker.

**Parameters:**
- `markerKey` (string | BasePart | Model): Either the key returned from CreateWaypoint, or the part itself

**Example:**
```lua
-- Remove by key
QuestMarkers.RemoveWaypoint(markerKey)

-- Remove by part reference
QuestMarkers.RemoveWaypoint(workspace.TreasureChest)
```

## Examples

### Example 1: Simple Waypoint

```lua
local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)
local destination = workspace.Destination

QuestMarkers.CreateWaypoint(destination, "Go Here!")
```

### Example 2: Custom Colored Waypoint

```lua
local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)
local objective = workspace.Objective

QuestMarkers.CreateWaypoint(objective, "Quest Objective", {
    color = Color3.fromRGB(100, 200, 255), -- Light blue
    heightOffset = 8,
    maxDistance = 750,
})
```

### Example 3: Temporary Waypoint

```lua
local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)
local tempLocation = workspace.TempLocation

-- Create waypoint
local markerKey = QuestMarkers.CreateWaypoint(tempLocation, "Temporary")

-- Remove after 30 seconds
task.delay(30, function()
    QuestMarkers.RemoveWaypoint(markerKey)
end)
```

### Example 4: Multiple Waypoints

```lua
local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)
local checkpoints = workspace.Checkpoints

for i, checkpoint in checkpoints:GetChildren() do
    QuestMarkers.CreateWaypoint(checkpoint, `Checkpoint {i}`, {
        color = Color3.fromRGB(0, 255, 0), -- Green
    })
end
```

### Example 5: Dynamic Waypoint (follows moving part)

```lua
local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)
local movingPart = workspace.MovingPlatform

-- The waypoint automatically follows the part as it moves!
QuestMarkers.CreateWaypoint(movingPart, "Moving Platform", {
    color = Color3.fromRGB(255, 100, 255), -- Purple
})
```

## Integration with Quest System

The waypoint system is built on top of the existing quest marker system, so it shares the same visual style and behavior. Quest markers are managed automatically by the quest system, while waypoints are manually created/removed via the API.

### Marker Types

- **Quest Available** (Gold): Automatically shown on NPCs with available quests
- **Quest Active** (Green): Automatically shown on NPCs for quest turn-in
- **Quest Objective** (Blue): Reserved for quest objectives
- **Waypoint** (White/Custom): Manually created custom markers

## Technical Details

### Performance

- Waypoints update every frame using `RunService.RenderStepped`
- Distance culling prevents rendering markers beyond `maxDistance`
- Automatic cleanup when parts are destroyed
- Efficient screen-space calculations

### Marker Positioning

- Markers are positioned at `part.Position + Vector3.new(0, heightOffset, 0)`
- For Models, uses HumanoidRootPart, Torso, or PrimaryPart
- Screen position updates automatically as camera moves

### Off-Screen Arrows

- When a waypoint is off-screen, a directional arrow appears at the screen edge
- Arrow points toward the waypoint's location
- Arrow rotation is calculated automatically

## Troubleshooting

### Waypoint not appearing

1. Make sure the part exists in the workspace
2. Check that you're within `maxDistance` (default: 500 studs)
3. Verify the QuestMarkers system is initialized (wait 2 seconds after character spawn)
4. Check the console for error messages

### Waypoint appears in wrong location

1. For Models, ensure they have a HumanoidRootPart, Torso, or PrimaryPart set
2. Adjust the `heightOffset` parameter
3. Verify the part hasn't been destroyed

### Multiple waypoints on same part

- Each call to `CreateWaypoint` on the same part will replace the previous waypoint
- Use different parts or remove the old waypoint first

## Files

- **QuestMarkers Module**: `src/ReplicatedStorage/Client/QuestMarkers.lua`
- **Example Scripts**: `src/StarterPlayer/StarterPlayerScripts/Examples/`
  - `WaypointExample.client.lua` - API usage examples
  - `PartWaypoint.client.lua` - Script to place inside parts
- **MarkerIcon Component**: `src/ReplicatedStorage/Client/Components/MarkerIcon.lua`
- **Documentation**: `docs/WaypointSystem.md` (this file)

## See Also

- [Quest Marker System](./QuestMarkerSystem.md)
- [Dialogue System](./DialogueSystem.md)

