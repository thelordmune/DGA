local CLEAR_DAMAGE_LOG_ON_MAX_HEALTH = false;

return function(actor: Actor, mainConfig: table)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then
		return false
	end
	

	--mainConfig.EnemyDetection.Current or mainConfig.GetTarget().PrimaryPart.Position


	if (mainConfig.getNpcCFrame().Position - mainConfig.Spawning.SpawnedAt).Magnitude >= mainConfig.Idle.MaxDistance - 0.35  then 
		return true
	else
		mainConfig.Idle.WalkBack = false
	end

	if mainConfig.Idle.WalkBack then
		return true
	end


	return false
end