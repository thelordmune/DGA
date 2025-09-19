return function(actor: Actor, mainConfig: table)
	--print("alr")

	--print(":herasfdsa")
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then
		return false
	end

	--if mainConfig.Idle.Enabled ~= true then
	--	return false
	--end

	local humanoid = npc:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= mainConfig.EnemyDetection.RunAway.RunHp then 
		return false 
	end

	if not mainConfig.Setting.CanWander then
		return false
	end
	if mainConfig.EnemyDetection.Current then 
		return false
	end

	if not mainConfig.Idle.NextPause.Current then
		local duration = math.random(
			mainConfig.Idle.NextPause.Min,
			mainConfig.Idle.NextPause.Max
		)
		mainConfig.Idle.NextPause.Current = os.clock() + duration
	else 
		if os.clock() >= mainConfig.Idle.NextPause.Current then
			if not mainConfig.Idle.PauseDuration.Current then
				local duration = math.random(
					mainConfig.Idle.PauseDuration.Min,
					mainConfig.Idle.PauseDuration.Max
				)
				mainConfig.Idle.PauseDuration.Current = duration
			end 

			if os.clock() - mainConfig.Idle.NextPause.Current < mainConfig.Idle.PauseDuration.Current then
				if mainConfig.Idle.Idling then
					--task.synchronize()
					humanoid:Move(Vector3.zero)
					mainConfig.Idle.Idling = false
					--task.desynchronize()
				end 
				return false
			else 
				mainConfig.Idle.PauseDuration.Current = nil
				mainConfig.Idle.NextPause.Current = nil
			end
		end

	end

	return true
end