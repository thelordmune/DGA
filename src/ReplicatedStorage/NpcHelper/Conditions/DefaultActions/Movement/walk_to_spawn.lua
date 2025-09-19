local CLEAR_DAMAGE_LOG_ON_MAX_HEALTH = false;

return function(actor: Actor, mainConfig: table)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then
		return false
	end


	--task.synchronize()
	--TODO: if obstacles are in the way , switch method to pathfind
	npc.Humanoid:MoveTo(mainConfig.Spawning.SpawnedAt)
	--task.desynchronize()

	return true
end