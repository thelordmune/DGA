return function(actor: Actor, mainConfig: table)
    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        return true -- Default to passive if no NPC
    end

    -- Check if NPC is in aggressive mode
    if mainConfig.States and mainConfig.States.AggressiveMode then
        return false -- Not passive when aggressive
    end

    -- Check if NPC has been recently attacked
    local Conditions = require(game.ReplicatedStorage.NpcHelper.Conditions)
    local hasBeenAttacked = Conditions.has_been_attacked(actor, mainConfig)

    if hasBeenAttacked then
        return false -- Not passive when recently attacked
    end

    -- Default to passive behavior for guards
    return true
end