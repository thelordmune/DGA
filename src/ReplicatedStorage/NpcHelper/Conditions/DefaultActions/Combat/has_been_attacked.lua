return function(actor: Actor, mainConfig: table)
    local npc = mainConfig.getNpc()
    if not npc then return false end

    -- Check if NPC has been recently attacked
    local damageLog = npc:FindFirstChild("Damage_Log")
    if damageLog and #damageLog:GetChildren() > 0 then
        return true
    end

    -- Check for attack states using hasState (which uses ECS StateManager)
    if mainConfig.hasState(npc, "RecentlyAttacked") or
       mainConfig.hasState(npc, "Damaged") then
        return true
    end

    -- Check LastPunched timestamp
    if mainConfig.Setting and mainConfig.Setting.LastPunched and
       mainConfig.Setting.LastPunched > 0 then
        local timeSinceAttacked = tick() - mainConfig.Setting.LastPunched
        -- Consider "recently attacked" for 30 seconds
        if timeSinceAttacked < 30 then
            return true
        end
    end

    return false
end