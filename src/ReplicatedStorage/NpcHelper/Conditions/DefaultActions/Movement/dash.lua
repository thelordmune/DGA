local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
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

	-- Use while loop with CFrame manipulation for NPC dash
	local Speed = 100  -- Studs per second
	local Duration = 0.4

	-- Store the dash state in mainConfig so follow_enemy knows not to override it
	if not mainConfig.Movement then
		mainConfig.Movement = {}
	end
	mainConfig.Movement.IsDashing = true
	mainConfig.Movement.DashDirection = dashVector

	-- Spawn the dash in a separate thread
	task.spawn(function()
		local startTime = os.clock()
		local startCFrame = root.CFrame

		while os.clock() - startTime < Duration do
			-- Check if NPC still exists
			if not npc or not npc.Parent or not root or not root.Parent then
				break
			end

			-- Calculate progress and speed with deceleration
			local elapsed = os.clock() - startTime
			local progress = elapsed / Duration
			local speedMultiplier = 1 - (progress * 0.8) -- Slow down to 20% of original speed

			-- Calculate movement delta for this frame
			local dt = task.wait()
			local moveDistance = Speed * speedMultiplier * dt

			-- Move the NPC using CFrame
			root.CFrame = root.CFrame + (dashVector * moveDistance)
		end

		-- Cleanup
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
