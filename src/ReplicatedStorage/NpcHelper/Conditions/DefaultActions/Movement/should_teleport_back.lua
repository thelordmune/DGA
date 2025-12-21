local CLEAR_DAMAGE_LOG_ON_MAX_HEALTH = false;

return function(actor: Actor, mainConfig: table)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then
		return false
	end

	-- Skip if this is a wanderer NPC (ECS AI handles movement)
	local ECSBridge = require(game.ReplicatedStorage.NpcHelper.ECSBridge)
	if ECSBridge.isWandererNPC(npc) then
		return false
	end

	if not mainConfig.Spawning.Despawning.Enabled  then
		return false
	end
	
	--mainConfig.EnemyDetection.Current or mainConfig.GetTarget().PrimaryPart.Position
	
	if (npc:GetPivot().Position - mainConfig.Spawning.SpawnedAt).Magnitude >= mainConfig.Spawning.Despawning.DespawnDistance then 
		return true
	end

	return false
end