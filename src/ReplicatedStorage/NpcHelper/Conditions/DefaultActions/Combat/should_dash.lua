--[[
    Determines if NPC should dash during combat

    TACTICAL DASHING ONLY - No random dashing!
    - Dash to avoid incoming attacks (player is attacking)
    - Dash sideways when getting repeatedly hit (better angle)
    - Dash forward when too far to attack
    - Dash back when low health and pressured
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local PlayerStateDetector = require(script.Parent.player_state_detector)

return function(actor: Actor, mainConfig: table)
    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        return false
    end

    local target = mainConfig.getTarget()
    if not target then
        return false
    end

    local npcRoot = npc:FindFirstChild("HumanoidRootPart")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")

    if not npcRoot or not targetRoot then
        return false
    end

    local distance = (targetRoot.Position - npcRoot.Position).Magnitude

    -- Check dash cooldown
    local lastDash = mainConfig.States.LastDash or 0
    local dashCooldown = 2.5 -- Reduced from 3.0 for more responsive dashing

    if os.clock() - lastDash < dashCooldown then
        return false
    end

    -- Track hits taken
    if not mainConfig.States.HitsTaken then
        mainConfig.States.HitsTaken = 0
        mainConfig.States.LastHitTime = 0
    end

    -- Reset hit counter if it's been a while
    if os.clock() - mainConfig.States.LastHitTime > 3 then
        mainConfig.States.HitsTaken = 0
    end

    -- Check if NPC is being stunned (getting hit) using ECS StateManager
    if StateManager.StateCount(npc, "Stuns") then
        mainConfig.States.HitsTaken = mainConfig.States.HitsTaken + 1
        mainConfig.States.LastHitTime = os.clock()
    end

    -- PRIORITY 1: Dash sideways if getting attacked (2+ hits in 3 seconds) - dodge to get better angle
    if mainConfig.States.HitsTaken >= 2 then
        mainConfig.States.HitsTaken = 0 -- Reset counter
        return true
    end

    -- PRIORITY 2: Dash to avoid incoming attacks
    local playerAction = PlayerStateDetector.GetCurrentAction(target)
    if playerAction and distance < 15 then
        -- Check if player is using a dangerous attack
        local dangerousAttacks = {
            "M11", "M12", "M13", "M14", -- M1 combos
            "M2", "RunningAttack", "Critical",
            "Needle Thrust", "Grand Cleave", -- Spear
            "Shell Piercer", "Strategist Combination", -- Guns
            "Downslam Kick", "Axe Kick", "Pincer Impact", -- Fist
            "Gazelle Punch", "Dempsey Roll", -- Boxing
            "Cascade", "Rock Skewer", "Cinder", "Firestorm", -- Alchemy
        }

        for _, attack in ipairs(dangerousAttacks) do
            if playerAction == attack then
                -- Dash to avoid the attack (40% chance to keep it tactical, not spammy)
                if math.random() < 0.4 then
                    return true
                end
            end
        end
    end

    -- PRIORITY 3: Dash forward if too far from target (can't reach to attack)
    if distance > 12 and distance < 20 then
        return true
    end

    -- PRIORITY 4: Dash back if low health and too close
    local humanoid = npc:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health / humanoid.MaxHealth < 0.3 and distance < 5 then
        return true
    end

    -- PRIORITY 5: Dash to reposition if player has hyper armor (avoid trading)
    if PlayerStateDetector.HasHyperArmor(target) and distance < 10 then
        return true
    end

    -- NO RANDOM DASHING - All dashing is now tactical and reactive!

    return false
end

