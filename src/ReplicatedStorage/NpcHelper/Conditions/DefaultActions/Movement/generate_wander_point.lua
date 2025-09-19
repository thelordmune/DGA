return function(actor: Actor, mainConfig: table)
	local npc: Model = actor:FindFirstChildOfClass("Model")
	if not npc then 
		return false
	end

	if mainConfig.Idle.GoalPoint then
		return true
	end

	if #mainConfig.Idle.Positions > 0 then
		mainConfig.Idle.GoalPoint = mainConfig.Idle.Positions[math.random(1, #mainConfig.Idle.Positions)]
	else
		local randomOffset = Vector3.new(math.random(-5, 5)*4.5,0,math.random(-5, 5)*4.5)	
		--task.synchronize()

		local visualziedPart = Instance.new("Part")
		visualziedPart.Anchored = true
		visualziedPart.CanCollide = false
		visualziedPart.CFrame = CFrame.new(mainConfig.Spawning.SpawnedAt + randomOffset)
		visualziedPart.Parent = workspace;
		
		mainConfig.Idle.GoalPoint = mainConfig.Spawning.SpawnedAt + randomOffset
		--task.desynchronize()
	end

	mainConfig.Idle.ReachedGoal = false
	return true
end