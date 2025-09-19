return function(actor: Actor, mainConfig: table)
    -- Check if NPC is configured to be passive
    -- if mainConfig.EnemyDetection and mainConfig.EnemyDetection.AttackOnlyWhenAttacked then
    --     -- If passive and hasn't been attacked, return true (should remain passive)
    --     local Conditions = require(game.ReplicatedStorage.NpcHelper.Conditions)
    --     local hasBeenAttacked = Conditions.has_been_attacked(actor, mainConfig)
        
    --     return not hasBeenAttacked
    -- end
    
    -- -- Not configured as passive
    -- return false

    return true
end