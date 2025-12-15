-- Function to make NPCs enter aggressive mode when attacked
return function(actor: Actor, mainConfig: table)
    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        return false
    end

    -- ------ print("enter_aggressive_mode: Checking NPC", npc.Name, "for recent attacks")

    -- Check if NPC has been recently attacked
    local damageLog = npc:FindFirstChild("Damage_Log")
    local hasBeenAttacked = false
    local attacker = nil

    -- ------ print("enter_aggressive_mode: Damage log exists:", damageLog ~= nil)
    
    if damageLog and #damageLog:GetChildren() > 0 then
        hasBeenAttacked = true
        -- Get the most recent attacker
        local recentAttack = damageLog:GetChildren()[#damageLog:GetChildren()]
        if recentAttack and recentAttack.Value then
            attacker = recentAttack.Value
        end
    end
    
    -- Also check for attack states in IFrames (but only if we don't already have an attacker from damage log)
    if not hasBeenAttacked then
        local iFrames = npc:FindFirstChild("IFrames")
        if iFrames and iFrames:IsA("StringValue") then
            local Library = require(game.ReplicatedStorage.Modules.Library)
            if Library.StateCheck(iFrames, "RecentlyAttacked") or
               Library.StateCheck(iFrames, "Damaged") then
                hasBeenAttacked = true
                -- ------ print("enter_aggressive_mode: Found attack state in IFrames")
            end
        end
    end
    
    if hasBeenAttacked then
        -- Only enter aggressive mode if not already aggressive
        if not (mainConfig.States and mainConfig.States.AggressiveMode) then
            ------ print("NPC", npc.Name, "has been attacked! Entering aggressive mode")

            -- Set the NPC to no longer be passive
            if mainConfig.States then
                mainConfig.States.IsPassive = false
                mainConfig.States.AggressiveMode = true
                mainConfig.States.AggressiveModeStartTime = os.clock()
                ------ print("Set aggressive mode - IsPassive:", mainConfig.States.IsPassive, "AggressiveMode:", mainConfig.States.AggressiveMode)
            end
        end

        -- Set the attacker as the target if we found one
        if attacker and attacker:IsA("Model") and attacker:FindFirstChild("Humanoid") then
            -- ------ print("Setting attacker", attacker.Name, "as target for aggressive NPC", npc.Name)
            mainConfig.EnemyDetection.Current = attacker

            -- Alert the NPC
            mainConfig.Alert(npc)

            -- Mark first detection
            if mainConfig.States.FirstDetection == nil then
                mainConfig.States.FirstDetection = true
            end
        end
        
        -- Increase aggression stats
        if mainConfig.EnemyDetection then
            -- Increase capture distance when aggressive
            mainConfig.EnemyDetection.CaptureDistance = math.max(
                mainConfig.EnemyDetection.CaptureDistance, 
                120  -- Minimum aggressive capture distance
            )
            
            -- Increase let go distance so they don't give up easily
            mainConfig.EnemyDetection.LetGoDistance = math.max(
                mainConfig.EnemyDetection.LetGoDistance,
                150  -- Minimum aggressive let go distance
            )
        end
        
        -- Make them more aggressive in combat
        if mainConfig.Setting then
            mainConfig.Setting.CanWander = false  -- Stop wandering, focus on combat
        end
        
        return true
    end
    
    return false
end
