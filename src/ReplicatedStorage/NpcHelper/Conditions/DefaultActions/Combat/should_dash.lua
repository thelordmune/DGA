--[[
    Determines if NPC should dash during combat
    - Dash forward when far from attacker
    - Dash sideways when getting repeatedly hit (better angle)
    - Dash back when pressured/low health
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage.Modules.Library)

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
    local dashCooldown = 3.0 -- Dash moderately - not too spammy

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

    -- Check if NPC is being stunned (getting hit)
    local stuns = npc:FindFirstChild("Stuns")
    if stuns and Library.StateCount(stuns) then
        mainConfig.States.HitsTaken = mainConfig.States.HitsTaken + 1
        mainConfig.States.LastHitTime = os.clock()
    end

    -- Dash sideways if getting attacked (2+ hits in 3 seconds) - reduced from 3 for more reactive dodging
    if mainConfig.States.HitsTaken >= 2 then
        mainConfig.States.HitsTaken = 0 -- Reset counter
        return true
    end

    -- Dash forward if too far from target (can't reach to attack)
    if distance > 12 and distance < 20 then
        return true
    end

    -- Dash back if low health and too close
    local humanoid = npc:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health / humanoid.MaxHealth < 0.3 and distance < 5 then
        return true
    end

    -- NEW: Tactical dashing for better positioning (reduced chances - less spammy)
    -- Dash to reposition if at awkward mid-range (15% chance)
    if distance > 6 and distance < 10 and math.random() < 0.15 then
        return true
    end

    -- Dash to close distance if player is far (10% chance)
    if distance > 15 and distance < 25 and math.random() < 0.1 then
        return true
    end

    -- Dash to create space if too close (20% chance)
    if distance < 4 and math.random() < 0.2 then
        return true
    end

    -- Random tactical dash for unpredictability (5% chance when in combat range)
    if distance > 5 and distance < 15 and math.random() < 0.05 then
        return true
    end

    return false
end

