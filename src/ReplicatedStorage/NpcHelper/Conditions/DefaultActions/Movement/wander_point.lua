return function(actor: Actor, mainConfig: table)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then
		return false 
	end

	local humanoid = npc:FindFirstChild("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return false 
	end

	if not mainConfig.Idle.GoalPoint then 
		return false 
	end

	if (root.Position - mainConfig.Idle.GoalPoint).Magnitude <= 3 then
		mainConfig.Idle.LastArrived = os.clock()
		mainConfig.Idle.GoalPoint = nil
		mainConfig.Idle.ReachedGoal = true
		-- Stop movement smoothly
		if mainConfig.Movement and mainConfig.Movement.TargetDirection then
			mainConfig.Movement.TargetDirection = Vector3.new(0, 0, 0)
		else
			humanoid:MoveTo(root.Position)
		end
	else
		local moveStartTime = mainConfig.States.MoveStartTime or 0

		if moveStartTime == 0 then
			mainConfig.States.MoveStartTime = os.clock()
		end

		-- Calculate direction to goal and apply smoothed movement
		local targetDirection = (mainConfig.Idle.GoalPoint - root.Position).Unit

		-- Smooth interpolation for movement direction
		local alpha = mainConfig.Movement.SmoothingAlpha
		local smoothedDirection = mainConfig.Movement.CurrentDirection:Lerp(targetDirection, alpha)
		mainConfig.Movement.CurrentDirection = smoothedDirection

		humanoid:Move(smoothedDirection)

		-- Jump if stuck
		if os.clock() - moveStartTime > 0.5 then
			if root.Velocity.Magnitude < (humanoid.WalkSpeed * 0.75) then
				humanoid.Jump = true
			end
		end
	end

	if mainConfig.Idle.ReachedGoal then
		mainConfig.States.MoveStartTime = 0
	end

	return true
end