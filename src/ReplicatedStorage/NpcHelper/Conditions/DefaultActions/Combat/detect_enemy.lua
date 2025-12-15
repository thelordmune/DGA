local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
local Library = Server.Library

-- local   = false

-- local function  ---- print(npcName, ...)
--     -- Only   Guards
--     if npcName and npcName:match("Guard") then
--         ------ print("[DetectEnemy]", npcName, ...)
--     elseif   then
--         ---- print("[DetectEnemy]", ...)
--     end
-- end

return function(actor: Actor, mainConfig: table)
    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        return false
    end

    local root = npc:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end

     ---- print(npc.Name, "Starting enemy detection")

    -- Check if current target is still valid
    if mainConfig.EnemyDetection.Current and
        (not mainConfig.EnemyDetection.Current.Parent or
            not mainConfig.EnemyDetection.Current:FindFirstChild("Humanoid")) then
         ---- print("Current target is invalid, cleaning up:", mainConfig.EnemyDetection.Current and mainConfig.EnemyDetection.Current.Name or "nil")
        mainConfig.cleanup(true)
        mainConfig.EnemyDetection.Current = nil
    end

    -- Check existing target
    if mainConfig.EnemyDetection.Current then
        local victim = mainConfig.EnemyDetection.Current
         ---- print("Checking existing target:", victim.Name)

        local victimStates = Library.GetAllStatesFromCharacter(victim)
         ---- print("Victim states:", victimStates)

        local vRoot = victim:FindFirstChild("HumanoidRootPart")
        local vHum = victim:FindFirstChild("Humanoid")

        if vRoot and vHum then
            local distance = (vRoot.Position - root.Position).Magnitude
             ---- print("Distance to current target:", distance, "LetGoDistance:", mainConfig.EnemyDetection.LetGoDistance)

            -- Clear target if they died (Health <= 0) or are too far away
            if vHum.Health <= 0 then
                 ---- print("Target died, clearing target:", victim.Name)
                mainConfig.cleanup(true)
                mainConfig.EnemyDetection.Current = nil
            elseif distance <= mainConfig.EnemyDetection.LetGoDistance then
                 ---- print("Keeping current target:", victim.Name)
                return true
            else
                 ---- print("Target too far away, clearing target:", victim.Name)
                mainConfig.cleanup(true)
                mainConfig.EnemyDetection.Current = nil
            end
        else
             ---- print("Lost current target (missing parts), cleaning up:", victim.Name)
            mainConfig.cleanup(true)
            mainConfig.EnemyDetection.Current = nil
        end
    end

     ---- print("Current target:", mainConfig.getTarget())
    if mainConfig.getTarget() == nil then
         ---- print("Searching for new targets in groups:", mainConfig.EnemyDetection.TargetGroups)
        
        for _, groupName in mainConfig.EnemyDetection.TargetGroups do
             ---- print("Checking group:", groupName)
            local taggedEntities = game.CollectionService:GetTagged(groupName)
             ---- print("Found", #taggedEntities, "entities with tag:", groupName)
            
            for _, victim in taggedEntities do
                 ---- print("Evaluating potential victim:", victim.Name)
                
                if victim == npc then
                     ---- print("Skipping self:", victim.Name)
                    continue
                end
                
                if mainConfig.EnemyDetection.Current then
                     ---- print("Already have target, skipping:", victim.Name)
                    continue
                end

                -- if not victim:IsDescendantOf(workspace.World.Live) then
                --      ---- print("Victim not in Live folder:", victim.Name)
                --     continue 
                -- end

                if root.Anchored then
                     ---- print("NPC root is anchored, skipping detection")
                    continue
                end

               local victimStates = Library.GetAllStatesFromCharacter(victim)
                if not victimStates then
                     ---- print("No victim states found for:", victim.Name)
                    continue
                end
                 ---- print("Victim states for", victim.Name, ":", victimStates)

                -- Check for protective states in all state tables
                local hasProtectiveState = false
                for tableName, stateArray in pairs(victimStates) do
                    if type(stateArray) == "table" then
                        if table.find(stateArray, "IFrame") or table.find(stateArray, "ForceField") then
                            hasProtectiveState = true
                            break
                        end
                    end
                end
                
                if hasProtectiveState then
                     ---- print("Victim has protective states:", victim.Name)
                    continue 
                end

                local vRoot = victim:WaitForChild("HumanoidRootPart")
                local vHum = victim:WaitForChild("Humanoid")
                
                 ---- print("Victim parts check for", victim.Name, "- Root:", vRoot and "Found" or "Missing", "Humanoid:", vHum and "Found" or "Missing", "Health:", vHum and vHum.Health or "N/A")

                if vRoot and vHum and vHum.Health > 0 then
                    local distance = (vRoot.Position - root.Position).Magnitude
                     ---- print("Distance to", victim.Name, ":", distance, "CaptureDistance:", mainConfig.EnemyDetection.CaptureDistance)
                    
                    if distance <= mainConfig.EnemyDetection.CaptureDistance then
                         ---- print("Victim in range, checking max targets")

                        local maxNpcValues = victim:FindFirstChild("Max_Npc_Values") or
                            Instance.new("Folder", victim)
                        maxNpcValues.Name = "Max_Npc_Values"

                        local maxAllowed = mainConfig.EnemyDetection.MaxTargetsPerGroup[groupName] or 1
                        local currentTargeting = #maxNpcValues:GetChildren()
                         ---- print("Current targeting count:", currentTargeting, "Max allowed:", maxAllowed)
                        
                        if currentTargeting < maxAllowed then
                             ---- print("ENEMY DETECTED! Setting target:", victim.Name)
                            
                            local reference = Instance.new("ObjectValue")
                            reference.Name = npc.Name
                            reference.Value = npc
                            reference.Parent = maxNpcValues
                            table.insert(mainConfig.Storage, reference)

                            mainConfig.EnemyDetection.Current = victim
                            mainConfig.Alert(npc)
                            
                            if mainConfig.States.FirstDetection == nil then
                                 ---- print("First detection for NPC:", npc.Name)
                                mainConfig.States.FirstDetection = true
                            end

                            return true
                        else
                             ---- print("Max targets reached for group:", groupName)
                        end
                    end
                else
                     ---- print("Invalid victim parts or health for:", victim.Name)
                end
            end
        end
    end
    
     ---- print("No enemy detected for NPC:", npc.Name)
    return false
end