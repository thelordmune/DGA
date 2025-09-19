--!strict
type mainConfig = {
	Idle: {
		SwayX: () -> number,
		SwayY: () -> number,
		MaxDistance: number,
		NoiseOffset: number,
		WanderSpeed: number,
		NextPause: number,
		PauseDuration: number,
		Idling: boolean,
		WalkBack: boolean,
	},
	Spawning: {
		SpawnedAt: Vector3,
	},
	getNpcCFrame: () -> CFrame,
}

local function generateNoise()
	local Start = os.clock()
	local Seed = math.random() * 1000
	local Frequency = 5 -- Lower frequency for less rapid fluctuations
	local Resolution = 15
	local Amplitude = 2

	return function()
		return math.noise((os.clock() - Start) * Frequency / Resolution, Seed) * Amplitude
	end
end

return function(actor: Actor, mainConfig: mainConfig)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then
		return false
	end

	local humanoid = npc:FindFirstChild("Humanoid") :: Humanoid
	local root = npc:FindFirstChild("HumanoidRootPart") :: Part
	if not humanoid or not root then
		return false
	end

	-- Initialize noise generators if not already present
	if not mainConfig.Idle.SwayX then
		mainConfig.Idle.SwayX = generateNoise()
	end
	if not mainConfig.Idle.SwayY then
		mainConfig.Idle.SwayY = generateNoise()
	end

	local npcCFrame = mainConfig.getNpcCFrame()
	local X, Y = mainConfig.Idle.SwayX(), mainConfig.Idle.SwayY()
	local MaxDistance = mainConfig.Idle.MaxDistance
	local Direction = Vector3.new(X, 0, Y)
	local Difference = mainConfig.Spawning.SpawnedAt - npcCFrame.Position
	local Distance = Difference.Magnitude
	local NoiseOffset = mainConfig.Idle.NoiseOffset or 0

	-- Scale the direction toward the spawn point based on proximity to MaxDistance
	local Weight = math.clamp((Distance / MaxDistance), 0, 1)
	local ToSpawnDirection = Difference.Unit
	local SmoothedDirection = Direction:Lerp(ToSpawnDirection, Weight)

	-- Apply smoothing to the final direction over time
	local CurrentVelocity = root.AssemblyLinearVelocity
	local TargetVelocity = SmoothedDirection * humanoid.WalkSpeed
	local InterpolatedVelocity = CurrentVelocity:Lerp(TargetVelocity, 0.1) -- Adjust 0.1 for smoother/faster response

	-- Update the NPC's movement
	--task.synchronize()
	humanoid:Move(InterpolatedVelocity)
	mainConfig.Idle.NoiseOffset = NoiseOffset + 0.1
	mainConfig.Idle.Idling = true
	--task.desynchronize()

	return true
end
