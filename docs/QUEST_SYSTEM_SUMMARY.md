# Quest System Summary

This document provides a quick overview of the complete quest system, including waypoints and client-side handlers.

## System Components

### 1. Quest Markers (Manual Only)
- **Location**: `src/ReplicatedStorage/Client/QuestMarkers.lua`
- **Purpose**: Create custom waypoint markers via quest modules
- **Note**: Automatic NPC markers are DISABLED - all markers must be created manually in quest modules

### 2. Waypoint System (Manual)
- **Location**: `src/ReplicatedStorage/Client/QuestMarkers.lua`
- **Purpose**: Create custom markers on any part
- **Usage**: `QuestMarkers.CreateWaypoint(part, label, config)`
- **See**: [WaypointSystem.md](./WaypointSystem.md)

### 3. Client-Side Quest Handler (NEW!)
- **Location**: `src/ReplicatedStorage/Client/QuestHandler.lua`
- **Purpose**: Manages quest-specific client logic and stage-based waypoints
- **Features**:
  - Monitors active quest stages
  - Calls quest module functions on stage changes
  - Automatically cleans up waypoint markers
  - Only visible to the player with the quest
- **See**: [ClientSideQuestHandler.md](./ClientSideQuestHandler.md)

## Quick Start: Adding Waypoints to a Quest

### Step 1: Create/Edit Quest Module

Edit your quest module in `src/ReplicatedStorage/Modules/QuestsFolder/[NPCName].lua`:

```lua
local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local isServer = RunService:IsServer()

if isServer then
    -- Server-side logic (existing code)
    return {
        Start = function(player)
            -- Your server logic here
        end,
    }
else
    -- Client-side logic (NEW!)
    return {
        OnStageStart = function(stage, questData)
            local QuestHandler = require(Replicated.Client.QuestHandler)
            
            if stage == 1 then
                -- Find the location part
                local location = Workspace:FindFirstChild("YourLocationPart", true)
                
                if location then
                    -- Create waypoint marker
                    QuestHandler.CreateWaypoint(location, "Objective Name", {
                        color = Color3.fromRGB(255, 215, 0), -- Gold
                        heightOffset = 10,
                        maxDistance = 1000,
                    })
                end
            end
        end,
    }
end
```

### Step 2: Place Location Part in Workspace

1. Create a part in workspace where you want the waypoint
2. Name it something descriptive (e.g., "CentralCommandCenter")
3. The waypoint will automatically appear when the player has the quest

### Step 3: Test

1. Accept the quest from the NPC
2. The waypoint marker should appear at the location
3. When you complete the stage or quest, the marker automatically disappears

## Example: Sam Quest with Waypoint

```lua
-- src/ReplicatedStorage/Modules/QuestsFolder/Sam.lua
if isServer then
    return {
        Start = function(player)
            -- Set quest stage 1
            world:set(playerEntity, comps.ActiveQuest, {
                npcName = "Sam",
                questName = "Military Exam",
                progress = {
                    stage = 1,
                    description = "Head to the central command center.",
                },
                startedTime = os.clock(),
            })
        end,
    }
else
    return {
        OnStageStart = function(stage, questData)
            local QuestHandler = require(Replicated.Client.QuestHandler)
            
            if stage == 1 then
                local commandCenter = Workspace:FindFirstChild("CentralCommandCenter", true)
                if commandCenter then
                    QuestHandler.CreateWaypoint(commandCenter, "Central Command Center", {
                        color = Color3.fromRGB(255, 215, 0),
                        heightOffset = 10,
                        maxDistance = 1000,
                    })
                end
            end
        end,
    }
end
```

## Multi-Stage Quests

```lua
OnStageStart = function(stage, questData)
    local QuestHandler = require(Replicated.Client.QuestHandler)
    
    if stage == 1 then
        -- First objective
        local loc1 = Workspace:FindFirstChild("Location1")
        if loc1 then
            QuestHandler.CreateWaypoint(loc1, "First Objective", {
                color = Color3.fromRGB(255, 215, 0), -- Gold
            })
        end
        
    elseif stage == 2 then
        -- Second objective
        local loc2 = Workspace:FindFirstChild("Location2")
        if loc2 then
            QuestHandler.CreateWaypoint(loc2, "Second Objective", {
                color = Color3.fromRGB(100, 200, 255), -- Blue
            })
        end
        
    elseif stage == 3 then
        -- Return to NPC
        local npc = Workspace.World.Dialogue:FindFirstChild("Sam")
        if npc then
            QuestHandler.CreateWaypoint(npc, "Return to Sam", {
                color = Color3.fromRGB(143, 255, 143), -- Green
            })
        end
    end
end
```

## Key Features

### ✅ Client-Side Only
- Waypoints only appear for the player with the active quest
- Other players don't see your quest markers
- Reduces server load

### ✅ Automatic Cleanup
- Markers automatically disappear when stage changes
- Markers automatically disappear when quest completes
- No manual cleanup needed

### ✅ Stage-Based
- Different markers for different quest stages
- Easy to create multi-stage quests
- Supports complex quest flows

### ✅ Customizable
- Custom colors for different marker types
- Custom labels and icons
- Adjustable height and visibility distance

## Color Coding Recommendations

- **Gold** (`255, 215, 0`): Primary objectives, important locations
- **Blue** (`100, 200, 255`): Secondary objectives, collection points
- **Green** (`143, 255, 143`): Return to NPC, quest completion
- **Purple** (`255, 100, 255`): Special objectives, boss locations
- **Red** (`255, 100, 100`): Danger zones, combat objectives

## Common Patterns

### Pattern 1: Go to Location
```lua
if stage == 1 then
    local location = Workspace:FindFirstChild("TargetLocation")
    if location then
        QuestHandler.CreateWaypoint(location, "Destination", {
            color = Color3.fromRGB(255, 215, 0),
        })
    end
end
```

### Pattern 2: Collect Items
```lua
if stage == 1 then
    -- Mark multiple collection points
    local itemsFolder = Workspace:FindFirstChild("QuestItems")
    if itemsFolder then
        for _, item in itemsFolder:GetChildren() do
            QuestHandler.CreateWaypoint(item, "Collect Item", {
                color = Color3.fromRGB(100, 200, 255),
            })
        end
    end
end
```

### Pattern 3: Return to NPC
```lua
if stage == 3 then
    local npc = Workspace.World.Dialogue:FindFirstChild("QuestNPC")
    if npc then
        QuestHandler.CreateWaypoint(npc, "Return to NPC", {
            color = Color3.fromRGB(143, 255, 143),
        })
    end
end
```

## Files Reference

- **QuestHandler**: `src/ReplicatedStorage/Client/QuestHandler.lua`
- **QuestMarkers**: `src/ReplicatedStorage/Client/QuestMarkers.lua`
- **Example Quest**: `src/ReplicatedStorage/Modules/QuestsFolder/ExampleQuest.lua`
- **Sam Quest**: `src/ReplicatedStorage/Modules/QuestsFolder/Sam.lua`

## Documentation

- [Client-Side Quest Handler](./ClientSideQuestHandler.md) - Complete API reference
- [Waypoint System](./WaypointSystem.md) - Manual waypoint creation
- [Quest Marker System](./QuestMarkerSystem.md) - Automatic NPC markers

## Troubleshooting

**Waypoint not appearing?**
1. Check that the part exists in workspace
2. Verify the part name matches your code
3. Check console for errors
4. Make sure you're within maxDistance (default: 1000 studs)

**Waypoint not disappearing?**
- Waypoints automatically clean up when stages change
- Check that your quest is progressing correctly

**Multiple waypoints appearing?**
- Each stage should create its own waypoints
- Old waypoints are automatically removed when stage changes

## Next Steps

1. Edit your quest module to add client-side logic
2. Place location parts in workspace
3. Test the quest to see waypoints appear
4. Adjust colors, labels, and distances as needed

