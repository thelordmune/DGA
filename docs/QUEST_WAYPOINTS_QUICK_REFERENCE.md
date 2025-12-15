# Quest Waypoints - Quick Reference

> **⚠️ Important:** Automatic NPC quest markers are DISABLED. All quest markers (including NPC markers) must be created manually in quest modules using `QuestHandler.CreateWaypoint()`. This gives you full control over when and where markers appear.

## 🎯 Add Waypoint to Quest (3 Steps)

### 1. Edit Quest Module
File: `src/ReplicatedStorage/Modules/QuestsFolder/[NPCName].lua`

```lua
local RunService = game:GetService("RunService")
local isServer = RunService:IsServer()

if isServer then
    -- Keep existing server code
    return { Start = function(player) ... end }
else
    -- Add this client code
    return {
        OnStageStart = function(stage, questData)
            local QuestHandler = require(game.ReplicatedStorage.Client.QuestHandler)
            
            if stage == 1 then
                local part = workspace:FindFirstChild("LocationName", true)
                if part then
                    QuestHandler.CreateWaypoint(part, "Label", {
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

### 2. Place Part in Workspace
- Create a part where you want the waypoint
- Name it (e.g., "CentralCommandCenter")
- Done!

### 3. Test
- Accept quest → Waypoint appears
- Complete stage → Waypoint disappears

---

## 📋 Function Reference

### QuestHandler.CreateWaypoint(part, label, config)
```lua
QuestHandler.CreateWaypoint(workspace.Location, "Go Here!", {
    color = Color3.fromRGB(255, 215, 0),  -- Marker color
    heightOffset = 10,                     -- Studs above part
    maxDistance = 1000,                    -- Visibility range
})
```

### Quest Module Functions (Client-Side)

```lua
-- Called when stage starts (create markers here)
OnStageStart = function(stage, questData) end

-- Called every frame (use sparingly!)
OnStageUpdate = function(stage, questData) end

-- Called when stage ends (auto cleanup)
OnStageEnd = function(stage, questData) end

-- Called when quest completes
OnQuestComplete = function(questData) end
```

---

## 🎨 Color Codes

```lua
-- Gold (Primary objectives)
color = Color3.fromRGB(255, 215, 0)

-- Blue (Secondary objectives)
color = Color3.fromRGB(100, 200, 255)

-- Green (Return to NPC)
color = Color3.fromRGB(143, 255, 143)

-- Purple (Special objectives)
color = Color3.fromRGB(255, 100, 255)

-- Red (Danger/Combat)
color = Color3.fromRGB(255, 100, 100)
```

---

## 📝 Common Patterns

### Single Location
```lua
OnStageStart = function(stage, questData)
    local QuestHandler = require(game.ReplicatedStorage.Client.QuestHandler)
    
    if stage == 1 then
        local location = workspace:FindFirstChild("TargetLocation")
        if location then
            QuestHandler.CreateWaypoint(location, "Destination", {
                color = Color3.fromRGB(255, 215, 0),
            })
        end
    end
end
```

### Multiple Stages (with NPC return marker)
```lua
OnStageStart = function(stage, questData)
    local QuestHandler = require(game.ReplicatedStorage.Client.QuestHandler)

    if stage == 1 then
        -- First location
        local loc1 = workspace:FindFirstChild("Location1")
        if loc1 then
            QuestHandler.CreateWaypoint(loc1, "First Objective", {
                color = Color3.fromRGB(255, 215, 0), -- Gold
            })
        end
    elseif stage == 2 then
        -- Second location
        local loc2 = workspace:FindFirstChild("Location2")
        if loc2 then
            QuestHandler.CreateWaypoint(loc2, "Second Objective", {
                color = Color3.fromRGB(100, 200, 255), -- Blue
            })
        end
    elseif stage == 3 then
        -- Return to NPC (this creates a marker on the NPC)
        local npc = workspace.World.Dialogue:FindFirstChild("NPCName")
        if npc then
            QuestHandler.CreateWaypoint(npc, "Return to NPC", {
                color = Color3.fromRGB(143, 255, 143), -- Green
                heightOffset = 5,
            })
        end
    end
end
```

### Multiple Items
```lua
OnStageStart = function(stage, questData)
    local QuestHandler = require(game.ReplicatedStorage.Client.QuestHandler)
    
    if stage == 1 then
        local itemsFolder = workspace:FindFirstChild("QuestItems")
        if itemsFolder then
            for _, item in itemsFolder:GetChildren() do
                QuestHandler.CreateWaypoint(item, "Collect", {
                    color = Color3.fromRGB(100, 200, 255),
                })
            end
        end
    end
end
```

---

## ⚠️ Troubleshooting

| Problem | Solution |
|---------|----------|
| Waypoint not appearing | Check part exists, check part name, check console |
| Waypoint not disappearing | Waypoints auto-cleanup on stage change |
| Wrong location | Verify part path with `:FindFirstChild()` |
| Multiple waypoints | Each stage creates new waypoints, old ones auto-remove |

---

## 📁 File Locations

- Quest modules: `src/ReplicatedStorage/Modules/QuestsFolder/`
- QuestHandler: `src/ReplicatedStorage/Client/QuestHandler.lua`
- QuestMarkers: `src/ReplicatedStorage/Client/QuestMarkers.lua`

---

## 📚 Full Documentation

- [Client-Side Quest Handler](./ClientSideQuestHandler.md)
- [Waypoint System](./WaypointSystem.md)
- [Quest System Summary](./QUEST_SYSTEM_SUMMARY.md)

---

## ✨ Example: Complete Quest Module

```lua
local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local isServer = RunService:IsServer()

if isServer then
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
           -- print("Quest completed!")
        end,
    }
end
```

---

**That's it! Copy the pattern, change the part names, and you're done! 🎉**

