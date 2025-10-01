local CLEAR_DAMAGE_LOG_ON_MAX_HEALTH = false;

return function(actor: Actor, mainConfig: table)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then
		return false
	end

	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	-- Apply smoothed movement
	local humanoid = npc:FindFirstChild("Humanoid")
	if humanoid then
		local targetDirection = (mainConfig.Spawning.SpawnedAt - root.Position).Unit

		-- Smooth interpolation for movement direction
		local alpha = mainConfig.Movement.SmoothingAlpha
		local smoothedDirection = mainConfig.Movement.CurrentDirection:Lerp(targetDirection, alpha)
		mainConfig.Movement.CurrentDirection = smoothedDirection

		humanoid:Move(smoothedDirection)
	end

	return true
end