return function(actor: Actor, mainConfig: table)
	------ print("alr")

	------ print(":herasfdsa")
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

	-- Only wander if a player is nearby (within 100-130 studs)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if root then
		local playerNearby = false
		local detectionRange = 115 -- Increased from 50 to 115 studs
		for _, player in game.Players:GetPlayers() do
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local distance = (character.HumanoidRootPart.Position - root.Position).Magnitude
				if distance <= detectionRange then
					playerNearby = true
					break
				end
			end
		end

		if not playerNearby then
			-- Stop movement when no player is nearby
			humanoid:Move(Vector3.new(0, 0, 0))
			return false
		end
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
					-- Stop movement during pause
					humanoid:Move(Vector3.new(0, 0, 0))
					mainConfig.Idle.Idling = false
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