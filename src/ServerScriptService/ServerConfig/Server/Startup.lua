local module = {}

local Server = require(script.Parent)
local CollectionService = game:GetService("CollectionService")

task.delay(5, function()
    require(game.ReplicatedStorage:WaitForChild("Regions"))
    
    -- Monitor workspace.World.Live for new NPCs (including nested in folders)
    local function onNpcAdded(npc)
        if npc:IsA("Model") and npc:IsDescendantOf(workspace.World.Live) then
            -- print("NPC detected in Live folder:", npc.Name)

            -- Wait for all essential body parts to exist before initializing
            local humanoidRootPart = npc:WaitForChild("HumanoidRootPart", 15)
            if not humanoidRootPart then
                warn(`[Startup] NPC {npc.Name} doesn't have HumanoidRootPart after 15 seconds - skipping initialization`)
                return
            end

            -- For R6 characters, wait for essential limbs
            local humanoid = npc:FindFirstChild("Humanoid")
            if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
                local requiredParts = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
                for _, partName in requiredParts do
                    local part = npc:WaitForChild(partName, 5)
                    if not part then
                        warn(`[Startup] NPC {npc.Name} missing {partName} - skipping initialization`)
                        return
                    end
                end
            end

            -- Ensure NPC is properly initialized with entity system
            local entity = Server.Modules.Entities.Get(npc)
            if not entity then
                -- print("Initializing entity for NPC:", npc.Name)
                Server.Modules.Entities.Init(npc)
            else
                -- print("NPC", npc.Name, "already has entity")
            end
        end
    end

    local function onNpcRemoved(npc)
        -- print("NPC removed from Live folder:", npc.Name)
    end

    -- DON'T use CollectionService immediate trigger - it fires before appearance loads
    -- CollectionService:GetInstanceAddedSignal("Humanoids"):Connect(onNpcAdded)
    -- CollectionService:GetInstanceRemovedSignal("Humanoids"):Connect(onNpcRemoved)

    -- Monitor all descendants of workspace.World.Live with delay to allow appearance to load
    workspace.World.Live.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Model") and CollectionService:HasTag(descendant, "Humanoids") then
            -- Wait 5 seconds for appearance and body parts to load (InsertService can be slow)
            task.delay(5, function()
                onNpcAdded(descendant)
            end)
        end
    end)

    workspace.World.Live.DescendantRemoving:Connect(function(descendant)
        if descendant:IsA("Model") then
            onNpcRemoved(descendant)
        end
    end)
end)

return module