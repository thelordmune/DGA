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

	--task.synchronize()

	if (root.Position - mainConfig.Idle.GoalPoint).Magnitude <= 3 then
		mainConfig.Idle.LastArrived = os.clock()
		mainConfig.Idle.GoalPoint = nil
		mainConfig.Idle.ReachedGoal = true
		humanoid:MoveTo(root.Position)
	else
		local moveStartTime = mainConfig.States.MoveStartTime or 0

		if moveStartTime == 0 then
			mainConfig.States.MoveStartTime = os.clock()
			humanoid:MoveTo(mainConfig.Idle.GoalPoint)
		else
			humanoid:MoveTo(mainConfig.Idle.GoalPoint)
			-- doing it like this because for SOME reason when it does :MoveTo() the root velocity is very high, idk why tho this usually never happened
			if os.clock() - moveStartTime > 0.5 then
				if root.Velocity.Magnitude < (humanoid.WalkSpeed * 0.75) then
					humanoid.Jump = true
				end
			end
		end
	end

	if mainConfig.Idle.ReachedGoal then
		mainConfig.States.MoveStartTime = 0
	end

	--task.desynchronize()
	return true
end