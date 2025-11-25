local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Library = require(ReplicatedStorage.Modules.Library)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

-- Get Server from main VM
local function getServer()
	local Server = require(ServerScriptService.ServerConfig.Server)
	if _G.ServerModules then
		Server.Modules = _G.ServerModules
	end
	return Server
end

local Server = getServer()

return function(actor: Actor, mainConfig: table, direction: string)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then
		return false
	end

	-- Skip if this is a combat NPC (ECS AI handles movement)
	local ECSBridge = require(ReplicatedStorage.NpcHelper.ECSBridge)
	if ECSBridge.isCombatNPC(npc) then
		return false
	end

	local root = npc:FindFirstChild("HumanoidRootPart")
	local humanoid = npc:FindFirstChild("Humanoid")

	if not root or not humanoid then
		return false
	end

	-- Check if NPC is in Actions or Stuns state (e.g., during Strategist Combination)
	local actions = npc:FindFirstChild("Actions")
	local stuns = npc:FindFirstChild("Stuns")

	if (actions and Library.StateCount(actions)) or (stuns and Library.StateCount(stuns)) then
		-- NPC is performing an action or stunned, cannot dash
		return false
	end

	-- Check dash cooldown
	local lastDash = mainConfig.States.LastDash or 0
	local dashCooldown = 1.0 -- Minimum time between dash executions

	if os.clock() - lastDash < dashCooldown then
		return false
	end

	-- Determine dash direction
	local dashVector
	if direction == "Back" then
		dashVector = -root.CFrame.LookVector
	elseif direction == "Left" then
		dashVector = -root.CFrame.RightVector
	elseif direction == "Right" then
		dashVector = root.CFrame.RightVector
	else
		-- Forward or no direction specified
		dashVector = root.CFrame.LookVector
	end

	-- Store original WalkSpeed
	local originalWalkSpeed = humanoid.WalkSpeed
	local dashSpeed = 50  -- Reduced from 80 - shorter dash distance
	local Duration = 0.35  -- Reduced from 0.5 - quicker dash

	-- Store the dash state in mainConfig so follow_enemy knows not to override it
	if not mainConfig.Movement then
		mainConfig.Movement = {}
	end
	mainConfig.Movement.IsDashing = true
	mainConfig.Movement.DashDirection = dashVector

	-- Set Dashing component to true for ECS by finding the entity with this NPC's Character component
	for entity in world:query(comps.Character) do
		local character = world:get(entity, comps.Character)
		if character == npc then
			world:set(entity, comps.Dashing, true)
			break
		end
	end

	-- Play dash animation (same as player dash system)
	local dashAnimations = ReplicatedStorage.Assets.Animations.Dashes
	local animationName
	if direction == "Back" then
		animationName = "Back"
	elseif direction == "Left" then
		animationName = "Left"
	elseif direction == "Right" then
		animationName = "Right"
	else
		animationName = "Forward"
	end

	local dashAnim = dashAnimations:FindFirstChild(animationName)
	if dashAnim then
		Library.StopMovementAnimations(npc)
		-- Library.PlayAnimation already plays the animation, so we don't need to call :Play() again
		local dashTrack = Library.PlayAnimation(npc, dashAnim, 0.05) -- Fast transition for responsive dash
		if dashTrack then
			dashTrack.Priority = Enum.AnimationPriority.Action
			-- print("[NPC Dash] Playing dash animation:", animationName, "for", npc.Name)
		else
			warn("[NPC Dash] Failed to load animation track for:", animationName)
		end
	else
		warn("[NPC Dash] Animation not found:", animationName, "in", dashAnimations:GetFullName())
	end

	-- Make the humanoid move in the dash direction
	humanoid:Move(dashVector)

	-- Tween WalkSpeed up to dash speed, then back down with smoother easing
	local tweenInfoUp = TweenInfo.new(
		Duration * 0.3,  -- 30% of duration to ramp up
		Enum.EasingStyle.Sine,  -- Changed to Sine for smoother acceleration
		Enum.EasingDirection.Out
	)

	local tweenInfoDown = TweenInfo.new(
		Duration * 0.7,  -- 70% of duration to ramp down
		Enum.EasingStyle.Sine,  -- Smoother deceleration
		Enum.EasingDirection.In
	)

	local tweenUp = TweenService:Create(humanoid, tweenInfoUp, {
		WalkSpeed = dashSpeed
	})

	local tweenDown = TweenService:Create(humanoid, tweenInfoDown, {
		WalkSpeed = originalWalkSpeed
	})

	-- Play the speed-up tween
	tweenUp:Play()

	-- When speed-up completes, play the slow-down tween
	tweenUp.Completed:Connect(function()
		tweenDown:Play()
	end)

	-- Cleanup after dash completes
	task.delay(Duration, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalWalkSpeed
		end

		if mainConfig.Movement then
			mainConfig.Movement.IsDashing = false
			mainConfig.Movement.DashDirection = nil
		end

		-- Clear Dashing component by finding the entity again
		for entity in world:query(comps.Character) do
			local character = world:get(entity, comps.Character)
			if character == npc then
				world:set(entity, comps.Dashing, false)
				break
			end
		end
	end)

	-- Play dash VFX
	Server.Visuals.Ranged(root.Position, 300, {
		Module = "Base",
		Function = "DashFX",
		Arguments = {npc, direction or "Forward"}
	})

	-- Add IFrames during dash
	if npc:FindFirstChild("IFrames") then
		Library.TimedState(npc.IFrames, "Dodge", 0.3)
	end

	-- Track last dash time
	mainConfig.States.LastDash = os.clock()

	return true
end
