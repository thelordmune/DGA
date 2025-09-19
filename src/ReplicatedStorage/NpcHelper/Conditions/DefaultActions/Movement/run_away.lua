return function(actor: Actor, mainConfig: table)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then 
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
		local runDirection = -(vRoot.Position - root.Position).Unit

		--task.synchronize()	
		if root.AssemblyLinearVelocity.Magnitude < (humanoid.WalkSpeed  * .75) then
			humanoid.Jump = true
		end
		humanoid:Move(runDirection)
		--task.desynchronize()
	else
		mainConfig.Idle.PauseDuration.Current = nil;
		mainConfig.Idle.NextPause.Current = nil;

		mainConfig.cleanup(true)
	end


	return true
end