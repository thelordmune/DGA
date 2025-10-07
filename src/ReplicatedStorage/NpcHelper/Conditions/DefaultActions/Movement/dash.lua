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

	-- Clean up any existing dash/dodge velocities to prevent conflicts
	for _, bodyMover in pairs(root:GetChildren()) do
		if bodyMover:IsA("LinearVelocity") or bodyMover:IsA("BodyVelocity") then
			if bodyMover.Name == "NPCDash" or bodyMover.Name == "NPCDodge" then
				bodyMover:Destroy()
			end
		end
	end

	-- Also clear AlignOrientation during dash for smoother movement
	local existingAlign = root:FindFirstChild("AlignOrient")
	if existingAlign then
		existingAlign:Destroy()
	end

	-- Create velocity for dash with smoother settings
	local TweenService = game:GetService("TweenService")
	local Speed = 100  -- Reduced from 135 for smoother movement
	local Duration = 0.4  -- Slightly faster for responsiveness

	-- SERVER-SIDE: Create velocity for physics (NPCs are server-owned)
	local Velocity = Instance.new("LinearVelocity")
	Velocity.Name = "NPCDash"
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.ForceLimitsEnabled = true
	Velocity.MaxAxesForce = Vector3.new(80000, 0, 80000)  -- Reduced force for smoother acceleration
	Velocity.VectorVelocity = dashVector * Speed

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
	local SlowdownSpeed = Speed * 0.2  -- End at 20% of original speed for smooth transition
	local DashTween = TweenService:Create(
		Velocity,
		TweenInfo.new(Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),  -- Sine for smoother easing
		{VectorVelocity = dashVector * SlowdownSpeed}
	)
	DashTween:Play()

	-- Final cleanup - remove velocity completely after tween
	DashTween.Completed:Connect(function()
		if Velocity and Velocity.Parent then
			Velocity:Destroy()
		end
	end)

	-- Safety cleanup in case tween doesn't complete
	task.delay(Duration + 0.1, function()
		if Velocity and Velocity.Parent then
			Velocity:Destroy()
		end
	end)

	-- CLIENT-SIDE: Send to all clients for smooth visual replication
	local success, err = pcall(function()
		local Packets = require(ReplicatedStorage.Modules.Packets)
		Packets.Bvel.sendToAll({
			Character = npc,
			Name = "NPCDash",
			Direction = direction, -- Direction name (string): "Forward", "Back", "Left", "Right"
			Velocity = dashVector  -- Dash vector (Vector3) for velocity
		})
	end)

	if not success then
		warn(`[NPC Dash] Failed to send Bvel packet: {err}`)
	end

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
