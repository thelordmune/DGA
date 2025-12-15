-- NPC Continuous Attack System - for aggressive NPCs to attack repeatedly
return function(actor: Actor, mainConfig: table)
    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then 
        return false 
    end
    
    local target = mainConfig.getTarget()
    if not target then
        return false
    end
    
    -- Check if target is still valid and in range
    local targetHumanoid = target:FindFirstChild("Humanoid")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    local npcRoot = npc:FindFirstChild("HumanoidRootPart")
    
    if not targetHumanoid or not targetRoot or not npcRoot or targetHumanoid.Health <= 0 then
        return false
    end
    
    local distance = (targetRoot.Position - npcRoot.Position).Magnitude
    local attackRange = 15 -- Base attack range
    
    if distance > attackRange then
        return false
    end
    
    -- Only attack if aggressive
    if not (mainConfig.States and mainConfig.States.AggressiveMode) then
        return false
    end
    
    -- Check attack cooldown - much shorter for continuous attacks
    local lastAttack = mainConfig.States.LastContinuousAttack or 0
    local attackCooldown = 0.8 -- Very fast attacks when aggressive
    
    if os.clock() - lastAttack < attackCooldown then
        return false
    end
    
    ---- print("NPC", npc.Name, "performing continuous attack on", target.Name, "at range", math.floor(distance))
    
    -- Update last attack time
    mainConfig.States.LastContinuousAttack = os.clock()
    
    -- Face the target
    local lookDirection = (targetRoot.Position - npcRoot.Position).Unit
    local lookCFrame = CFrame.lookAt(npcRoot.Position, npcRoot.Position + Vector3.new(lookDirection.X, 0, lookDirection.Z))
    npcRoot.CFrame = npcRoot.CFrame:Lerp(lookCFrame, 0.5)
    
    -- Use the same combat system as players
    local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
    
    -- Ensure NPC has an entity in the system
    local Entity = Server.Modules.Entities.Get(npc)
    if not Entity then
        ---- print("Warning: NPC", npc.Name, "does not have an entity - creating one")
        -- Try to create entity for NPC
        Server.Modules.Entities.Init(npc)
        Entity = Server.Modules.Entities.Get(npc)
        if not Entity then
            ---- print("Error: Could not create entity for NPC", npc.Name)
            return false
        end
    end
    
    -- Clear any blocking states that might prevent attacking
    local actions = npc:FindFirstChild("Actions")
    if actions then
        -- Clear any previous attacking states to prevent blocking
        Server.Library.RemoveState(actions, "Attacking")
    end

    -- Use Combat.Light just like players do
    ---- print("NPC", npc.Name, "calling Combat.Light with entity:", Entity and "found" or "not found")
    Server.Modules.Combat.Light(npc)
    ---- print("NPC", npc.Name, "Combat.Light call completed")

    return true
end
