# Client-Side Quest Handler

The Client-Side Quest Handler allows you to create quest-specific logic that runs only on the client, including stage-specific waypoint markers, UI updates, and visual effects that only the player with the active quest can see.

## Overview

The quest system is split into two parts:

- **Server-Side**: Handles quest progression, validation, rewards, and data persistence
- **Client-Side**: Handles UI, waypoint markers, visual feedback, and player-specific effects

## How It Works

1. Player accepts a quest from an NPC
2. Server sets the `ActiveQuest` component on the player entity
3. Client-Side Quest Handler detects the quest and loads the quest module
4. Quest module's `OnStageStart` is called with the current stage
5. Quest module creates waypoint markers, UI, etc.
6. When stage changes, `OnStageEnd` is called, markers are cleaned up, and `OnStageStart` is called for the new stage
7. When quest completes, `OnQuestComplete` is called

## Quest Module Structure

Quest modules use `RunService:IsServer()` to separate server and client logic:

```lua
local RunService = game:GetService("RunService")
local isServer = RunService:IsServer()

if isServer then
    -- Server-side logic
    return {
        Start = function(player) end,
        Complete = function(player, questName, choice) end,
    }
else
    -- Client-side logic
    return {
        OnStageStart = function(stage, questData) end,
        OnStageUpdate = function(stage, questData) end,
        OnStageEnd = function(stage, questData) end,
        OnQuestComplete = function(questData) end,
    }
end
```

## Client-Side Functions

### OnStageStart(stage, questData)

Called when a quest stage begins. This is where you should create waypoint markers and initialize stage-specific UI.

**Parameters:**
- `stage` (number): The current stage number
- `questData` (table): Quest information
  - `npcName` (string): NPC who gave the quest
  - `questName` (string): Name of the quest
  - `stage` (number): Current stage
  - `progress` (table): Quest progress data

**Example:**
```lua
OnStageStart = function(stage, questData)
    local QuestHandler = require(ReplicatedStorage.Client.QuestHandler)
    
    if stage == 1 then
        local location = Workspace:FindFirstChild("QuestLocation")
        if location then
            QuestHandler.CreateWaypoint(location, "Objective", {
                color = Color3.fromRGB(255, 215, 0),
                heightOffset = 10,
                maxDistance = 1000,
            })
        end
    end
end
```

### OnStageUpdate(stage, questData)

Called every frame while on a stage. **Use sparingly!** Only use this for frame-by-frame checks like proximity detection.

**Parameters:**
- `stage` (number): The current stage number
- `questData` (table): Quest information

**Example:**
```lua
OnStageUpdate = function(stage, questData)
    -- Check if player is near objective
    local player = Players.LocalPlayer
    local character = player.Character
    
    if character and character.PrimaryPart then
        local objective = Workspace:FindFirstChild("Objective")
        if objective then
            local distance = (character.PrimaryPart.Position - objective.Position).Magnitude
            if distance < 10 then
                -- Player reached objective
            end
        end
    end
end
```

### OnStageEnd(stage, questData)

Called when leaving a stage. Waypoint markers are automatically cleaned up, but you can add custom cleanup here.

**Parameters:**
- `stage` (number): The stage that just ended
- `questData` (table): Quest information

**Example:**
```lua
OnStageEnd = function(stage, questData)
   -- print(`Stage {stage} completed!`)
    -- Custom cleanup here
end
```

### OnQuestComplete(questData)

Called when the quest is completed.

**Parameters:**
- `questData` (table): Quest completion information
  - `npcName` (string): NPC who gave the quest
  - `questName` (string): Name of the quest
  - `completedTime` (number): Time when quest was completed

**Example:**
```lua
OnQuestComplete = function(questData)
   -- print("Quest completed!")
    -- Play celebration effects, sounds, etc.
end
```

## QuestHandler API

### QuestHandler.CreateWaypoint(part, label, config)

Creates a waypoint marker that is automatically cleaned up when the stage ends.

**Parameters:**
- `part` (BasePart | Model): The part to place the marker on
- `label` (string, optional): Custom label text
- `config` (table, optional): Configuration options
  - `color` (Color3): Marker color
  - `heightOffset` (number): Height above part
  - `maxDistance` (number): Max visibility distance

**Returns:**
- `markerKey` (string): Unique key for the marker

**Example:**
```lua
local QuestHandler = require(ReplicatedStorage.Client.QuestHandler)

QuestHandler.CreateWaypoint(workspace.Objective, "Go Here!", {
    color = Color3.fromRGB(255, 215, 0),
    heightOffset = 10,
    maxDistance = 1000,
})
```

### QuestHandler.RegisterMarker(markerKey)

Registers a marker for automatic cleanup. Use this if you create markers manually with `QuestMarkers.CreateWaypoint()`.

**Parameters:**
- `markerKey` (string): The marker key to register

## Complete Example: Sam Quest

Here's the Sam quest with client-side waypoint markers:

```lua
local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local isServer = RunService:IsServer()

if isServer then
    -- Server-side logic
    local ref = require(Replicated.Modules.ECS.jecs_ref)
    local world = require(Replicated.Modules.ECS.jecs_world)
    local comps = require(Replicated.Modules.ECS.jecs_components)
    
    return {
        Start = function(player)
            local playerEntity = ref.get("player", player)
            if not playerEntity then return end
            
            world:set(playerEntity, comps.ActiveQuest, {
                npcName = "Sam",
                questName = "Military Exam",
                progress = {
                    stage = 1,
                    completed = false,
                    description = "Head to the central command center.",
                },
                startedTime = os.clock(),
            })
        end,
    }
else
    -- Client-side logic
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
        
        OnStageEnd = function(stage, questData)
           -- print(`Stage {stage} completed`)
        end,
        
        OnQuestComplete = function(questData)
           -- print("Military Exam completed!")
        end,
    }
end
```

## Multi-Stage Quest Example

```lua
OnStageStart = function(stage, questData)
    local QuestHandler = require(Replicated.Client.QuestHandler)
    
    if stage == 1 then
        -- Stage 1: Go to location A
        local locationA = Workspace:FindFirstChild("LocationA")
        if locationA then
            QuestHandler.CreateWaypoint(locationA, "Location A", {
                color = Color3.fromRGB(255, 215, 0),
            })
        end
        
    elseif stage == 2 then
        -- Stage 2: Go to location B
        local locationB = Workspace:FindFirstChild("LocationB")
        if locationB then
            QuestHandler.CreateWaypoint(locationB, "Location B", {
                color = Color3.fromRGB(100, 200, 255),
            })
        end
        
    elseif stage == 3 then
        -- Stage 3: Return to NPC
        local npc = Workspace.World.Dialogue:FindFirstChild("QuestNPC")
        if npc then
            QuestHandler.CreateWaypoint(npc, "Return to NPC", {
                color = Color3.fromRGB(143, 255, 143),
            })
        end
    end
end
```

## Best Practices

1. **Keep OnStageUpdate light**: Only use it for essential frame-by-frame checks
2. **Use descriptive labels**: Make waypoint labels clear and helpful
3. **Color code markers**: Use consistent colors for different marker types
4. **Check for nil**: Always check if parts exist before creating waypoints
5. **Let cleanup happen automatically**: Don't manually remove markers in OnStageEnd

## Troubleshooting

### Markers not appearing

1. Check that the part exists in workspace
2. Verify the part path is correct
3. Check console for warnings
4. Make sure you're within `maxDistance`

### Markers not cleaning up

- Markers are automatically cleaned up when stages change
- If you create markers manually, use `QuestHandler.RegisterMarker()`

### OnStageStart not being called

1. Make sure QuestHandler is initialized in PlayerHandler
2. Check that the quest module is in `ReplicatedStorage/Modules/QuestsFolder`
3. Verify the module name matches the NPC name

## Files

- **QuestHandler**: `src/ReplicatedStorage/Client/QuestHandler.lua`
- **Example Quest**: `src/ReplicatedStorage/Modules/QuestsFolder/ExampleQuest.lua`
- **Sam Quest**: `src/ReplicatedStorage/Modules/QuestsFolder/Sam.lua`
- **PlayerHandler**: `src/StarterPlayer/StarterPlayerScripts/PlayerHandler/init.client.lua`

## See Also

- [Waypoint System](./WaypointSystem.md)
- [Quest Marker System](./QuestMarkerSystem.md)
- [Dialogue System](./DialogueSystem.md)

