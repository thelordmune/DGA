local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Library = require(ReplicatedStorage.Modules.Library)

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
	local dashCooldown = 1.5 -- Cooldown between dashes

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
	local dashSpeed = 100  -- Peak dash speed
	local Duration = 0.4

	-- Store the dash state in mainConfig so follow_enemy knows not to override it
	if not mainConfig.Movement then
		mainConfig.Movement = {}
	end
	mainConfig.Movement.IsDashing = true
	mainConfig.Movement.DashDirection = dashVector

	-- Make the humanoid move in the dash direction
	humanoid:Move(dashVector)

	-- Tween WalkSpeed up to dash speed, then back down
	local tweenInfo = TweenInfo.new(
		Duration / 2,  -- Half duration to ramp up
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local tweenUp = TweenService:Create(humanoid, tweenInfo, {
		WalkSpeed = dashSpeed
	})

	local tweenDown = TweenService:Create(humanoid, tweenInfo, {
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
