return function(actor: Actor, mainConfig: table)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then
		return false
	end

	-- Skip if this is a combat NPC (ECS AI handles movement)
	local ECSBridge = require(game.ReplicatedStorage.NpcHelper.ECSBridge)
	if ECSBridge.isCombatNPC(npc) then
		return false
	end

	-- Skip if this is a wanderer NPC (ECS AI handles flee behavior)
	if ECSBridge.isWandererNPC(npc) then
		return false
	end

	local root,humanoid = npc:FindFirstChild("HumanoidRootPart") :: BasePart,npc:FindFirstChild("Humanoid") :: Humanoid
	if not root or not humanoid then
		return false
	end

	local victim: Model = mainConfig.getTarget()
	if not victim then
		return false
	end

	local vRoot,vHum = victim:FindFirstChild("HumanoidRootPart") :: BasePart,victim:FindFirstChild("Humanoid") :: Humanoid
	if not vRoot or not vHum then
		return false
	end

	local distanceToVictim = (root.Position - vRoot.Position).Magnitude
	if distanceToVictim <= mainConfig.EnemyDetection.RunAway.Ranges.SafeRange then
		local targetDirection = -(vRoot.Position - root.Position).Unit

		if root.AssemblyLinearVelocity.Magnitude < (humanoid.WalkSpeed  * .75) then
			humanoid.Jump = true
		end

		-- Smooth interpolation for movement direction
		local alpha = mainConfig.Movement.SmoothingAlpha
		local smoothedDirection = mainConfig.Movement.CurrentDirection:Lerp(targetDirection, alpha)
		mainConfig.Movement.CurrentDirection = smoothedDirection

		-- Apply smoothed movement
		humanoid:Move(smoothedDirection)
	else
		mainConfig.Idle.PauseDuration.Current = nil;
		mainConfig.Idle.NextPause.Current = nil;

		mainConfig.cleanup(true)
	end


	return true
end