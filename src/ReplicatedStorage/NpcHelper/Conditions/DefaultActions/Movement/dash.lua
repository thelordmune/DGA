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

	-- Clean up any existing dash velocities
	for _, bodyMover in pairs(root:GetChildren()) do
		if bodyMover.Name == "NPCDash" then
			bodyMover:Destroy()
		end
	end

	-- Create velocity for dash (same as player dash system)
	local TweenService = game:GetService("TweenService")
	local Velocity = Instance.new("LinearVelocity")
	Velocity.Name = "NPCDash"
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.ForceLimitsEnabled = true
	Velocity.MaxAxesForce = Vector3.new(4e4, 0, 4e4)
	Velocity.VectorVelocity = dashVector * 60 -- Dash speed

	-- Create attachment if it doesn't exist
	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = root
	end

	Velocity.Attachment0 = attachment
	Velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	Velocity.Parent = root

	-- Create smooth deceleration tween - gradually slow down instead of stopping abruptly
	local TweenDuration = 0.3
	local SlowdownSpeed = 60 * 0.15  -- End at 15% of original speed for smooth transition
	local DashTween = TweenService:Create(
		Velocity,
		TweenInfo.new(TweenDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{VectorVelocity = dashVector * SlowdownSpeed}
	)
	DashTween:Play()

	-- Final cleanup - remove velocity completely after tween
	DashTween.Completed:Connect(function()
		if Velocity and Velocity.Parent then
			Velocity:Destroy()
		end
	end)

	-- Play dash animation
	local dashAnimName = direction == "Back" and "Backward" or
	                     direction == "Left" and "Left" or
	                     direction == "Right" and "Right" or "Forward"

	local dashAnim = ReplicatedStorage.Assets.Animations.Dashes:FindFirstChild(dashAnimName)
	if dashAnim then
		Library.PlayAnimation(npc, dashAnim)
	end

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
