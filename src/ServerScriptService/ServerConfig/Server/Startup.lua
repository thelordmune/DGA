local module = {}

local Server = require(script.Parent)
local CollectionService = game:GetService("CollectionService")

task.delay(5, function()
    require(game.ReplicatedStorage:WaitForChild("Regions"))
    
    -- Monitor workspace.World.Live for new NPCs (including nested in folders)
    local function onNpcAdded(npc)
        if npc:IsA("Model") and npc:IsDescendantOf(workspace.World.Live) then
            print("NPC detected in Live folder:", npc.Name)
            Server.Modules.Entities.Init(npc)
        end
    end

    local function onNpcRemoved(npc)
        print("NPC removed from Live folder:", npc.Name)
    end

    -- Connect to CollectionService for NPCs with tags
    CollectionService:GetInstanceAddedSignal("Humanoids"):Connect(onNpcAdded)
    CollectionService:GetInstanceRemovedSignal("Humanoids"):Connect(onNpcRemoved)

    -- Monitor all descendants of workspace.World.Live
    workspace.World.Live.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Model") and CollectionService:HasTag(descendant, "Humanoids") then
            onNpcAdded(descendant)
        end
    end)

    workspace.World.Live.DescendantRemoving:Connect(function(descendant)
        if descendant:IsA("Model") then
            onNpcRemoved(descendant)
        end
    end)
end)

return module