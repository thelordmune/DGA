local TweenService = game:GetService("TweenService")
local Replicated = game:GetService("ReplicatedStorage")
local Visuals = require(Replicated.Modules.Visuals)
local Utilities = require(Replicated.Modules.Utilities)
local RunService = game:GetService("RunService")
local StateManager = require(Replicated.Modules.ECS.StateManager)
local Debris = Utilities.Debris
local NetworkModule = {}
local Client = require(script.Parent.Parent)

NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

type Entity = {
	Name: string,
	Character: Model,
}

-- BvelSimple Effect enum: uint8 -> function name
local BvelSimpleEffectNames = {
	[0] = "M1Bvel",
	[1] = "M2Bvel",
	[2] = "JumpBvel",
	[3] = "LungeBvel",
	[4] = "DashForward",
	[5] = "DashBack",
	[6] = "DashLeft",
	[7] = "DashRight",
}

-- BvelRemove Effect enum: uint8 -> what to remove
local BvelRemoveEffectNames = {
	[0] = "All",          -- RemoveBvel (removes all)
	[1] = "M1",           -- RemoveM1Bvel
	[2] = "M2",           -- RemoveM2Bvel
	[3] = "Knockback",    -- RemoveKnockbackBvel
	[4] = "Dash",         -- RemoveDashBvel
	[5] = "Pincer",       -- RemovePincerForwardVelocity
	[6] = "Lunge",        -- RemoveLungeBvel
	[7] = "IS",           -- RemoveISVelocity
}

NetworkModule.EndPoint = function(Player, Data)
	if not Data or not Data.Name then
		warn("[Bvel] EndPoint called with invalid data")
		return
	end

	local func = NetworkModule[Data.Name]
	if not func then
		warn(`[Bvel] No function found for: {Data.Name}`)
		return
	end

	if Data.Name == "BFKnockback" then
		func(Data.Character, Data.Direction, Data.HorizontalPower, Data.UpwardPower)
	elseif Data.Name == "StoneLaunchVelocity" or Data.Name == "PincerForwardVelocity" or Data.Name == "RemovePincerForwardVelocity" or Data.Name == "ISVelocity" or Data.Name == "RemoveISVelocity" then
		func(Data.Character, Data)
	elseif Data.Name == "NPCDash" then
		-- Pass both direction name and velocity vector
		func(Data.Character, Data.Direction, Data.Velocity)
	elseif Data.Name == "KnockbackBvelFromNPC" then
		-- NPC attacker: velocity pre-computed by server, no NPC model ref needed
		func(Data.Character, Data.Velocity)
	elseif Data.Name == "KnockbackFollowUpHighlight" then
		-- Highlight on knockback target + duration (ChronoId for NPC targets, Targ for player targets)
		func(Data.Character, Data.Targ, Data.duration, Data.ChronoId)
	elseif Data.Name == "KnockbackFollowUpBvel" then
		-- Bezier chase toward target + duration (ChronoId for NPC targets, Targ for player targets)
		func(Data.Character, Data.Targ, Data.duration, Data.ChronoId)
	elseif Data.Name == "CriticalChargeStart" or Data.Name == "CriticalChargeRelease" then
		-- Charged M2 VFX (Character only, no target)
		func(Data.Character)
	elseif Data.Name == "AerialAttackBvel" then
		-- Aerial attack launch velocity (Character only)
		func(Data.Character)
	else
		func(Data.Character, Data.Targ)
	end
end

NetworkModule["M1Bvel"] = function(Character) -- // Linear Version
	-- Calculate world-space forward direction and flatten to horizontal
	local forwardDirection = Character.PrimaryPart.CFrame.LookVector
	forwardDirection = Vector3.new(forwardDirection.X, 0, forwardDirection.Z).Unit

	local Velocity = Instance.new("LinearVelocity")
	Velocity.Attachment0 = Character.PrimaryPart.RootAttachment
	Velocity.ForceLimitsEnabled = true
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.MaxAxesForce = Vector3.new(50000, 0, 50000)  -- Reduced from 100000 for stability
	Velocity.RelativeTo = Enum.ActuatorRelativeTo.World  -- Changed from Attachment0 to World
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.VectorVelocity = forwardDirection * 60
	Velocity.Parent = Character.PrimaryPart

	Debris:AddItem(Velocity, 0.15)

	TweenService:Create(
		Velocity,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, 0) }
	):Play()
end

NetworkModule["M2Bvel"] = function(Character) -- // Linear Version
	-- Calculate world-space forward direction and flatten to horizontal
	local forwardDirection = Character.PrimaryPart.CFrame.LookVector
	forwardDirection = Vector3.new(forwardDirection.X, 0, forwardDirection.Z).Unit

	local Velocity = Instance.new("LinearVelocity")
	Velocity.Attachment0 = Character.PrimaryPart.RootAttachment
	Velocity.ForceLimitsEnabled = true
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.MaxAxesForce = Vector3.new(50000, 0, 50000)  -- Reduced from 100000 for stability
	Velocity.RelativeTo = Enum.ActuatorRelativeTo.World  -- Changed from Attachment0 to World
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.VectorVelocity = forwardDirection * 80
	Velocity.Parent = Character.PrimaryPart

	Debris:AddItem(Velocity, 0.35)

	TweenService:Create(
		Velocity,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, 0) }
	):Play()
end

NetworkModule["Bone GauntletsRunningBvel"] = function(Character)
	-- Calculate world-space forward direction and flatten to horizontal
	local forwardDirection = Character.PrimaryPart.CFrame.LookVector
	forwardDirection = Vector3.new(forwardDirection.X, 0, forwardDirection.Z).Unit

	local Velocity = Instance.new("LinearVelocity")
	Velocity.Attachment0 = Character.PrimaryPart.RootAttachment
	Velocity.ForceLimitsEnabled = true
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.MaxAxesForce = Vector3.new(50000, 0, 50000)  -- Reduced from 100000 for stability
	Velocity.RelativeTo = Enum.ActuatorRelativeTo.World  -- Changed from Attachment0 to World
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.VectorVelocity = forwardDirection * 80
	Velocity.Parent = Character.PrimaryPart

	Debris:AddItem(Velocity, 0.35)

	TweenService:Create(
		Velocity,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, 0) }
	):Play()
end
NetworkModule["BFKnockback"] = function(Character, direction, horizontalPower, upwardPower)
	local rootPart = Character.PrimaryPart
	if not rootPart then return end

	-- Cancel all client actions when knockback is received (for local player)
	if Character == Client.Character and Client.ClearClientActions then
		Client.ClearClientActions()
	end

	-- Remove any existing dash velocity
	local dashVelocity = rootPart:FindFirstChild("Dodge")
	if dashVelocity then
		dashVelocity:Destroy()
	end

	-- Create attachment
	local attachment = rootPart:FindFirstChild("BFKnockbackAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "BFKnockbackAttachment"
		attachment.Parent = rootPart
	end

	-- Remove any existing knockback velocity
	local oldLV = rootPart:FindFirstChild("BFKnockbackVelocity")
	if oldLV then
		oldLV:Destroy()
	end

	-- Calculate velocity vector (horizontal + upward arc)
	local horizontalDir = Vector3.new(direction.X, 0, direction.Z).Unit
	local velocity = Vector3.new(
		horizontalDir.X * horizontalPower,
		upwardPower,
		horizontalDir.Z * horizontalPower
	)

	-- Create LinearVelocity
	local lv = Instance.new("LinearVelocity")
	lv.Name = "BFKnockbackVelocity"
	lv.MaxForce = math.huge
	lv.VectorVelocity = velocity
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	-- Clean up after duration (only destroy LinearVelocity, not attachment)
	task.delay(0.65, function()
		if lv and lv.Parent then
			lv:Destroy()
		end
	end)
end

NetworkModule["FistRunningBvel"] = function(Character)
	local lv = Instance.new("LinearVelocity")
	local attachment = Instance.new("Attachment")
	attachment.Parent = Character.PrimaryPart

	local rootPart = Character.PrimaryPart
	local speed = 50
	local duration = 0.65
	local startTime = os.clock()

	lv.MaxForce = 200000  -- Reduced from math.huge to prevent excessive force
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	-- Connection to update velocity every frame
	local conn
	conn = RunService.Heartbeat:Connect(function()
		-- Calculate remaining duration (0 to 1)
		local elapsed = os.clock() - startTime
		local progress = math.clamp(1 - (elapsed / duration), 0, 1)

		-- Get current forward direction and flatten to horizontal
		local forwardVector = rootPart.CFrame.LookVector
		forwardVector = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit

		-- Apply velocity with gradual decay
		lv.VectorVelocity = forwardVector * speed * progress
	end)

	-- Cleanup after duration seconds
	task.delay(duration, function()
		conn:Disconnect()
		lv:Destroy()
		attachment:Destroy()
	end)
end
NetworkModule["PIBvel"] = function(Character)
	if not Character or not Character.PrimaryPart then
		warn("PIBvel: Character or PrimaryPart is nil")
		return
	end

	local rootPart = Character.PrimaryPart

	-- Clean up any existing body movers FIRST
	------ print(`[PIBvel] Cleaning body movers before creating new velocity`)
	for _, child in pairs(rootPart:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
			------ print(`[PIBvel] Destroying existing {child.ClassName}: {child.Name}`)
			child:Destroy()
		end
	end

	-- Clear residual velocity
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	-- Wait for physics to update (critical to prevent teleporting!)
	task.wait()

	local lv = Instance.new("LinearVelocity")
	local attachment = Instance.new("Attachment")
	attachment.Parent = rootPart

	local speed = 40
	local duration = .71
	local startTime = os.clock()

	lv.MaxForce = 200000  -- Reduced from math.huge to prevent excessive force
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	-- Connection to update velocity every frame
	local conn
	conn = RunService.Heartbeat:Connect(function()
		-- Calculate remaining duration (0 to 1)
		local elapsed = os.clock() - startTime
		local progress = math.clamp(1 - (elapsed / duration), 0, 1)

		-- Cubic ease out for smoother stop at the end
		-- This makes the deceleration more gradual near the end
		local easedProgress = 1 - (1 - progress) ^ 3

		-- Get current forward direction (flattened to prevent going into ground)
		local forwardVector = rootPart.CFrame.LookVector
		forwardVector = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit

		-- Apply velocity with smooth decay (no downward component)
		lv.VectorVelocity = forwardVector * speed * easedProgress
	end)

	-- Cleanup after duration seconds
	task.delay(duration, function()
		conn:Disconnect()
		lv:Destroy()
		attachment:Destroy()
	end)
end
NetworkModule["PIBvel2"] = function(Character)
	if not Character or not Character.PrimaryPart then
		warn("PIBvel2: Character or PrimaryPart is nil")
		return
	end

	local lv = Instance.new("LinearVelocity")
	local attachment = Instance.new("Attachment")
	attachment.Parent = Character.PrimaryPart

	local rootPart = Character.PrimaryPart
	local speed = 45
	local duration = .3
	local startTime = os.clock()

	lv.MaxForce = 200000  -- Reduced from math.huge to prevent excessive force
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	-- Connection to update velocity every frame
	local conn
	conn = RunService.Heartbeat:Connect(function()
		-- Calculate remaining duration (0 to 1)
		local elapsed = os.clock() - startTime
		local progress = math.clamp(1 - (elapsed / duration), 0, 1)

		-- Smooth easing (quadratic ease out)
		local easedProgress = 1 - (1 - progress) ^ 2

		-- Get current forward direction (flattened)
		local forwardVector = rootPart.CFrame.LookVector
		forwardVector = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit

		-- Add small upward component for a slight hop
		-- Starts at 8 studs/sec upward, decays with progress
		local verticalComponent = 8 * easedProgress

		-- Apply velocity with smooth decay and slight upward motion
		lv.VectorVelocity = forwardVector * speed * easedProgress + Vector3.new(0, verticalComponent, 0)
	end)

	-- Cleanup after duration seconds
	task.delay(duration, function()
		conn:Disconnect()
		lv:Destroy()
		attachment:Destroy()
	end)
end

NetworkModule["FistBvel"] = function(Character: Model)
	-- Calculate world-space forward direction and flatten to horizontal
	local forwardDirection = Character.PrimaryPart.CFrame.LookVector
	forwardDirection = Vector3.new(forwardDirection.X, 0, forwardDirection.Z).Unit

	local Velocity = Instance.new("LinearVelocity")
	Velocity.Attachment0 = Character.PrimaryPart.RootAttachment
	Velocity.ForceLimitsEnabled = true
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.MaxAxesForce = Vector3.new(50000, 0, 50000)  -- Reduced from 100000 for stability
	Velocity.RelativeTo = Enum.ActuatorRelativeTo.World  -- Changed from Attachment0 to World
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.VectorVelocity = Vector3.new(0, 0, 0)
	Velocity.Parent = Character.PrimaryPart

	Debris:AddItem(Velocity, 84 / 60)

	TweenService:Create(
		Velocity,
		TweenInfo.new(12 / 60, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ VectorVelocity = forwardDirection * 50 }  -- Use world direction
	):Play()

	task.wait(12 / 60)

	if not Velocity then
		return
	end

	TweenService:Create(
		Velocity,
		TweenInfo.new(8 / 60, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, -20) }
	):Play()

	task.wait(8 / 60)

	if not Velocity then
		return
	end

	TweenService:Create(
		Velocity,
		TweenInfo.new(4 / 60, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, -37) }
	):Play()

	task.wait(4 / 60)

	if not Velocity then
		return
	end

	TweenService:Create(
		Velocity,
		TweenInfo.new(40 / 60, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, -20) }
	):Play()

	task.wait(41 / 60)

	if not Velocity then
		return
	end

	TweenService:Create(
		Velocity,
		TweenInfo.new(4 / 60, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, -37) }
	):Play()

	task.wait(4 / 60)

	if not Velocity then
		return
	end

	TweenService:Create(
		Velocity,
		TweenInfo.new(15 / 60, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, 9) }
	):Play()

	--[[task.delay(8/60,function()
		if Velocity then
			TweenService:Create(Velocity, TweenInfo.new(8/60, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {VectorVelocity = Vector3.new(0,0,0)}):Play()
		end
	end)]]
	--
end

NetworkModule["BaseBvel"] = function(Character: Model)
	-- Clean up any existing velocities and body movers to prevent flinging
	for _, child in ipairs(Character.PrimaryPart:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
			child:Destroy()
		end
	end

	-- Calculate world-space backward direction and flatten to horizontal
	local backwardDirection = -Character.PrimaryPart.CFrame.LookVector
	backwardDirection = Vector3.new(backwardDirection.X, 0, backwardDirection.Z).Unit

	local Velocity = Instance.new("LinearVelocity")
	Velocity.Attachment0 = Character.PrimaryPart.RootAttachment
	Velocity.ForceLimitsEnabled = true
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.MaxAxesForce = Vector3.new(50000, 0, 50000)  -- Reduced from 100000 for stability
	Velocity.RelativeTo = Enum.ActuatorRelativeTo.World  -- Changed from Attachment0 to World
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.VectorVelocity = backwardDirection * 50
	Velocity.Parent = Character.PrimaryPart

	Debris:AddItem(Velocity, 0.15)

	TweenService:Create(
		Velocity,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, 0) }
	):Play()
end

NetworkModule["RemoveBvel"] = function(Character: Model)
	local startTime = os.clock()
	local rootPart = Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	------ print(`[RemoveBvel] [{startTime}] START - Cleaning body movers from {Character.Name}`)
	------ print(`[RemoveBvel] Current position: {rootPart.Position}`)
	------ print(`[RemoveBvel] Current velocity: {rootPart.AssemblyLinearVelocity}`)

	local moversFound = 0
	-- Remove all body movers from HumanoidRootPart
	for _, v in pairs(Character:GetDescendants()) do
		if v:IsA("LinearVelocity") or v:IsA("BodyVelocity") or v:IsA("BodyPosition") or v:IsA("BodyGyro") then
			------ print(`[RemoveBvel] Destroying {v.ClassName}: {v.Name} (Parent: {v.Parent.Name})`)
			moversFound = moversFound + 1
			v:Destroy()
		end
	end

	-- Also clear assembly velocity to remove any residual momentum
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	local endTime = os.clock()
	------ print(`[RemoveBvel] [{endTime}] COMPLETE - Removed {moversFound} body movers in {(endTime - startTime) * 1000}ms`)
	------ print(`[RemoveBvel] Final position: {rootPart.Position}`)
	------ print(`[RemoveBvel] Final velocity: {rootPart.AssemblyLinearVelocity}`)
end

NetworkModule["MineM1Bvel"] = function(Character)
	for _, Mover in pairs(Character.HumanoidRootPart:GetChildren()) do
		if Mover:IsA("BodyVelocity") then
			Mover:Destroy()
		end
	end

	local function lerp(start, goal, alpha)
		return start + (goal - start) * alpha
	end

	local DefaultSpeed = 50

	local BodyVelocity = Instance.new("BodyVelocity")
	BodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 100000
	BodyVelocity.Velocity = Character.HumanoidRootPart.CFrame.LookVector * DefaultSpeed
	BodyVelocity.Parent = Character.HumanoidRootPart

	local SpeedValue = Instance.new("IntValue")
	SpeedValue.Value = DefaultSpeed
	SpeedValue.Parent = BodyVelocity

	Debris:AddItem(BodyVelocity, 0.15)

	TweenService:Create(SpeedValue, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 0 })
		:Play()

	local EndConnection2 = false

	Utilities:AddToTempLoop(function()
		if not Character then
			return true
		end
		if BodyVelocity and BodyVelocity.Parent == Character.HumanoidRootPart then
			BodyVelocity.Velocity = Character.HumanoidRootPart.CFrame.LookVector * SpeedValue.Value
		else
			EndConnection2 = true

			if BodyVelocity then
				BodyVelocity:Destroy()
			end
		end
		return EndConnection2
	end)
end

NetworkModule["MadM1Bvel"] = function(Character)
	for _, Mover in pairs(Character.HumanoidRootPart:GetChildren()) do
		if Mover:IsA("BodyVelocity") then
			Mover:Destroy()
		end
	end

	local function lerp(start, goal, alpha)
		return start + (goal - start) * alpha
	end

	local DefaultSpeed = 50
	local ogSpeed = 4

	local BodyVelocity = Instance.new("BodyVelocity")
	BodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 100000
	BodyVelocity.Velocity = Character.HumanoidRootPart.CFrame.LookVector * DefaultSpeed
	BodyVelocity.Parent = Character.HumanoidRootPart

	local SpeedValue = Instance.new("IntValue")
	SpeedValue.Value = DefaultSpeed
	SpeedValue.Parent = BodyVelocity

	Debris:AddItem(BodyVelocity, 0.15)

	local StartTime = tick()

	TweenService:Create(SpeedValue, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 0 })
		:Play()

	local EndConnection2 = false

	local Speed = 4

	Utilities:AddToTempLoop(function()
		if not Character then
			return true
		end

		local i = math.clamp(((tick() - StartTime) / 0.1), 0, 1)
		Speed = lerp(50, ogSpeed, i)

		if BodyVelocity and BodyVelocity.Parent == Character.HumanoidRootPart then
			BodyVelocity.Velocity = Character.HumanoidRootPart.CFrame.LookVector * Speed
		else
			EndConnection2 = true

			if BodyVelocity then
				BodyVelocity:Destroy()
			end
		end
		return EndConnection2
	end)
end

NetworkModule["AABvel"] = function(Character: Model)
	local tim = 0.71
	------ print(tim)
	local lv = Instance.new("LinearVelocity")
	local attachment = Instance.new("Attachment")
	attachment.Parent = Character.HumanoidRootPart

	local rootPart = Character.HumanoidRootPart
	local baseSpeed = 30 -- Starting speed
	local maxSpeed = 100 -- Maximum speed at end of duration
	local elapsedTime = 0

	lv.MaxForce = 200000  -- Reduced from math.huge to prevent excessive force
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	-- Connection to update direction and speed every frame
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsedTime = elapsedTime + dt

		-- Calculate quadratic speed increase (t^2)
		local progress = math.min(elapsedTime / tim, 1) -- Normalized to [0,1]
		local currentSpeed = baseSpeed + (maxSpeed - baseSpeed) * (progress ^ 2)

		-- Get current forward direction (flattened)
		local forwardVector = rootPart.CFrame.LookVector
		forwardVector = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit

		-- Apply velocity (forward + slight upward) with quadratic speed
		lv.VectorVelocity = -forwardVector * currentSpeed + Vector3.new(0, 1.2, 0)
	end)

	Debris:AddItem(lv, tonumber(tim) - 0.1)
	task.delay(tonumber(tim) - 0.1, function()
		conn:Disconnect()
		attachment:Destroy()
	end)
end

-- Wall Break Velocity (when wallbanged player gets hit again)
NetworkModule["WallBreakVelocity"] = function(Character: Model | Entity, Targ: Model | Entity, Velocity: Vector3)
	local eroot = Targ.HumanoidRootPart

	-- Clean up any existing velocities and body movers
	for _, child in ipairs(eroot:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
			child:Destroy()
		end
	end

	-- Create attachment
	local attachment = eroot:FindFirstChild("WallBreakAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "WallBreakAttachment"
		attachment.Parent = eroot
	end

	-- Create LinearVelocity
	local lv = Instance.new("LinearVelocity")
	lv.Name = "WallBreakVelocity"
	lv.MaxForce = math.huge
	lv.VectorVelocity = Velocity
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = eroot

	-- Clean up after duration
	task.delay(0.8, function()
		if lv and lv.Parent then
			lv:Destroy()
		end
	end)
end

NetworkModule["KnockbackBvel"] = function(Character: Model | Entity, Targ: Model | Entity)
	local root = Character.HumanoidRootPart
	local eroot = Targ.HumanoidRootPart

	-- Cancel all client actions when knockback is received (for local player)
	if Targ == Client.Character and Client.ClearClientActions then
		Client.ClearClientActions()
	end

	-- Disable AutoRotate for the target
	local targetHumanoid = Targ:FindFirstChild("Humanoid")
	if targetHumanoid then
		targetHumanoid.AutoRotate = false
	end

	-- Clean up any existing velocities and body movers to prevent flinging
	for _, child in ipairs(eroot:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
			child:Destroy()
		end
	end

	-- Knockback direction: opposite of where the TARGET is facing (knocked backwards)
	local targetLook = eroot.CFrame.LookVector
	local direction = -Vector3.new(targetLook.X, 0, targetLook.Z).Unit

	-- Make target face the attacker using BodyGyro (more reliable than setting CFrame)
	local lookDirection = (root.Position - eroot.Position).Unit
	lookDirection = Vector3.new(lookDirection.X, 0, lookDirection.Z).Unit -- Flatten to horizontal
	local targetCFrame = CFrame.new(eroot.Position, eroot.Position + lookDirection)

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(0, math.huge, 0) -- Only rotate on Y axis
	bodyGyro.P = 10000
	bodyGyro.D = 500
	bodyGyro.CFrame = targetCFrame
	bodyGyro.Parent = eroot

	local maxPower = 60
	local duration = 1.267 -- Match KnockbackStun animation length
	local rampUpTime = 0.15 -- Ease-in from 0 to maxPower
	local fullSpeedTime = 0.5 -- Hold at max until this point, then decelerate

	-- Reset any existing velocity first
	eroot.AssemblyLinearVelocity = Vector3.zero
	eroot.AssemblyAngularVelocity = Vector3.zero

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(50000, 0, 50000)
	bv.Velocity = Vector3.zero -- Start slow
	bv.Parent = eroot

	-- Three-phase velocity: ramp up (0.15s) → full speed → cubic ease-out deceleration
	local startTime = os.clock()
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			connection:Disconnect()
			return
		end

		local currentPower
		if elapsed < rampUpTime then
			-- Phase 1: Ease-in ramp from 0 to maxPower (quadratic)
			local t = elapsed / rampUpTime
			currentPower = maxPower * (t * t) -- Quadratic ease-in: slow start, fast finish
		elseif elapsed < fullSpeedTime then
			-- Phase 2: Full speed
			currentPower = maxPower
		else
			-- Phase 3: Gradually slow down (cubic ease-out, same as before)
			local slowdownProgress = (elapsed - fullSpeedTime) / (duration - fullSpeedTime)
			local easedProgress = 1 - (1 - slowdownProgress) ^ 3
			currentPower = maxPower * (1 - easedProgress)
		end

		if bv and bv.Parent then
			bv.Velocity = direction * currentPower
			eroot.AssemblyLinearVelocity = direction * currentPower
		else
			connection:Disconnect()
		end
	end)

	-- Clean up after duration
	task.delay(duration, function()
		if connection then
			connection:Disconnect()
		end
		if bv and bv.Parent then
			bv:Destroy()
		end
		if bodyGyro and bodyGyro.Parent then
			bodyGyro:Destroy()
		end
		-- Re-enable AutoRotate after knockback ends (will be managed by stun state handler)
		if targetHumanoid then
			-- Check if there are still stun states active using ECS StateManager
			if not StateManager.StateCount(Targ, "Stuns") then
				targetHumanoid.AutoRotate = true
			end
		end
	end)
end

-- Knockback from NPC: same as KnockbackBvel but uses pre-computed velocity from server
-- (NPC model refs may not serialize via ByteNet.inst, so server sends direction directly)
NetworkModule["KnockbackBvelFromNPC"] = function(Character: Model | Entity, Velocity: Vector3?)
	local eroot = Character.HumanoidRootPart
	if not eroot then return end

	-- Cancel all client actions when knockback is received (for local player)
	if Character == Client.Character and Client.ClearClientActions then
		Client.ClearClientActions()
	end

	-- Disable AutoRotate for the target
	local targetHumanoid = Character:FindFirstChild("Humanoid")
	if targetHumanoid then
		targetHumanoid.AutoRotate = false
	end

	-- Clean up any existing velocities and body movers to prevent flinging
	for _, child in ipairs(eroot:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
			child:Destroy()
		end
	end

	-- Use pre-computed velocity from server, or fall back to backward direction
	local direction
	local maxPower = 60
	if Velocity and Velocity.Magnitude > 0 then
		direction = Velocity.Unit
		maxPower = Velocity.Magnitude
	else
		direction = -eroot.CFrame.LookVector
		direction = Vector3.new(direction.X, 0, direction.Z).Unit
	end

	-- Face the attacker (opposite of knockback direction)
	local lookDirection = -direction
	local targetCFrame = CFrame.new(eroot.Position, eroot.Position + lookDirection)

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(0, math.huge, 0)
	bodyGyro.P = 10000
	bodyGyro.D = 500
	bodyGyro.CFrame = targetCFrame
	bodyGyro.Parent = eroot

	local duration = 1.267 -- Match KnockbackStun animation length
	local rampUpTime = 0.15 -- Ease-in from 0 to maxPower
	local fullSpeedTime = 0.5 -- Hold at max until this point, then decelerate

	eroot.AssemblyLinearVelocity = Vector3.zero
	eroot.AssemblyAngularVelocity = Vector3.zero

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(50000, 0, 50000)
	bv.Velocity = Vector3.zero -- Start slow
	bv.Parent = eroot

	-- Three-phase velocity: ramp up → full speed → cubic ease-out deceleration
	local startTime = os.clock()
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			connection:Disconnect()
			return
		end

		local currentPower
		if elapsed < rampUpTime then
			local t = elapsed / rampUpTime
			currentPower = maxPower * (t * t)
		elseif elapsed < fullSpeedTime then
			currentPower = maxPower
		else
			local slowdownProgress = (elapsed - fullSpeedTime) / (duration - fullSpeedTime)
			local easedProgress = 1 - (1 - slowdownProgress) ^ 3
			currentPower = maxPower * (1 - easedProgress)
		end

		if bv and bv.Parent then
			bv.Velocity = direction * currentPower
			eroot.AssemblyLinearVelocity = direction * currentPower
		else
			connection:Disconnect()
		end
	end)

	task.delay(duration, function()
		if connection then
			connection:Disconnect()
		end
		if bv and bv.Parent then
			bv:Destroy()
		end
		if bodyGyro and bodyGyro.Parent then
			bodyGyro:Destroy()
		end
		if targetHumanoid then
			if not StateManager.StateCount(Character, "Stuns") then
				targetHumanoid.AutoRotate = true
			end
		end
	end)
end

NetworkModule["NTBvel"] = function(Character)
    local rootPart = Character.PrimaryPart
    if not rootPart then return end

    -- Stop ONLY movement animations (Walking, Running, Dash, etc.) but NOT skill animations
    local humanoid = Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            local tracks = animator:GetPlayingAnimationTracks()

            -- List of movement animation names to stop
            local movementAnimNames = {"Walking", "Running", "Right", "Left", "Forward", "Backward", "Idle", "Jump", "Fall", "Climb", "Sit"}

            for _, track in ipairs(tracks) do
                local animName = track.Animation.Name
                local shouldStop = false

                -- Check if this is a movement animation
                for _, moveName in ipairs(movementAnimNames) do
                    if animName == moveName then
                        shouldStop = true
                        break
                    end
                end

                if shouldStop then
                    track:Stop(0) -- Stop immediately with 0 fade time
                end
            end
        end
    end

    -- Clean up any existing body movers FIRST
    for _, child in pairs(rootPart:GetChildren()) do
        if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
            child:Destroy()
        end
    end

    -- Clear residual velocity
    rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

    local lv = Instance.new("LinearVelocity")
    local attachment = Instance.new("Attachment")
    attachment.Parent = rootPart

    local speed = 50
    local duration = 0.6
    local animStartTime = os.clock()

    lv.MaxForce = 200000  -- Reduced from math.huge to prevent excessive force
    lv.Attachment0 = attachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = rootPart

    -- Connection to update velocity every frame
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local elapsed = os.clock() - animStartTime
        local progress = math.clamp(elapsed / duration, 0, 1)

        -- Get current forward direction and flatten to horizontal
        local forwardVector = rootPart.CFrame.LookVector
        forwardVector = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit

        -- Create arc motion with faster descent
        local verticalComponent
        if progress < 0.3 then
            -- Quick rise
            verticalComponent = (progress / 0.3) * 12
        else
            -- Faster fall with gravity-like acceleration
            local fallProgress = (progress - 0.3) / 0.7
            verticalComponent = 12 * (1 - fallProgress^2) - 20 * fallProgress
        end

        local horizontalSpeed = speed * (1 - progress)

        -- Apply velocity with arc motion
        lv.VectorVelocity = forwardVector * horizontalSpeed + Vector3.new(0, verticalComponent, 0)
    end)

    -- Cleanup after duration seconds
    task.delay(duration, function()
        conn:Disconnect()
        lv:Destroy()
        attachment:Destroy()
    end)
end

NetworkModule["FlameRunningBvel"] = function(Character)
	local lv = Instance.new("LinearVelocity")
	local attachment = Instance.new("Attachment")
	attachment.Parent = Character.PrimaryPart

	local rootPart = Character.PrimaryPart
	local speed = 50
	local duration = 0.65
	local startTime = os.clock()

	lv.MaxForce = 200000  -- Reduced from math.huge to prevent excessive force
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	-- Connection to update velocity every frame
	local conn
	conn = RunService.Heartbeat:Connect(function()
		-- Calculate remaining duration (0 to 1)
		local elapsed = os.clock() - startTime
		local progress = math.clamp(1 - (elapsed / duration), 0, 1)

		-- Get current forward direction and flatten to horizontal
		local forwardVector = rootPart.CFrame.LookVector
		forwardVector = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit

		-- Apply velocity with gradual decay
		lv.VectorVelocity = forwardVector * speed * progress
	end)

	-- Cleanup after duration seconds
	task.delay(duration, function()
		conn:Disconnect()
		lv:Destroy()
		attachment:Destroy()
	end)
end

-- NPC Dash - Client-side replication using WalkSpeed tweening
NetworkModule["NPCDash"] = function(Character, Direction, DashVector)
	if not Character or not Character.PrimaryPart then
		warn("NPCDash: Character or PrimaryPart is nil")
		return
	end

	local humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("NPCDash: No Humanoid found")
		return
	end

	-- Store original WalkSpeed
	local originalWalkSpeed = humanoid.WalkSpeed
	local dashSpeed = 80  -- Peak dash speed (reduced from 100)
	local Duration = 0.5  -- Increased from 0.4

	-- Play dash animation
	local Library = require(Replicated.Modules.Library)
	local dashAnimations = Replicated.Assets.Animations.Dashes
	local animationName
	if Direction == "Back" then
		animationName = "Back"
	elseif Direction == "Left" then
		animationName = "Left"
	elseif Direction == "Right" then
		animationName = "Right"
	else
		animationName = "Front"
	end

	local dashAnim = dashAnimations:FindFirstChild(animationName)
	if dashAnim then
		Library.StopMovementAnimations(Character)
		local dashTrack = Library.PlayAnimation(Character, dashAnim)
		if dashTrack then
			dashTrack.Priority = Enum.AnimationPriority.Action
		end
	end

	-- Make the humanoid move in the dash direction
	humanoid:Move(DashVector)

	-- Tween WalkSpeed up to dash speed, then back down with smoother easing
	local tweenInfoUp = TweenInfo.new(
		Duration * 0.3,  -- 30% of duration to ramp up
		Enum.EasingStyle.Sine,  -- Smoother acceleration
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
	end)
end

NetworkModule["GunsRunningBvel"] = function(Character)
	local lv = Instance.new("LinearVelocity")
	local attachment = Instance.new("Attachment")
	attachment.Parent = Character.PrimaryPart

	local rootPart = Character.PrimaryPart
	local speed = 50
	local duration = 0.65
	local startTime = os.clock()

	lv.MaxForce = 200000  -- Reduced from math.huge to prevent excessive force
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	-- Connection to update velocity every frame
	local conn
	conn = RunService.Heartbeat:Connect(function()
		-- Calculate remaining duration (0 to 1)
		local elapsed = os.clock() - startTime
		local progress = math.clamp(1 - (elapsed / duration), 0, 1)

		-- Get current forward direction and flatten to horizontal
		local forwardVector = rootPart.CFrame.LookVector
		forwardVector = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit

		-- Apply velocity with gradual decay
		lv.VectorVelocity = forwardVector * speed * progress
	end)

	-- Cleanup after duration seconds
	task.delay(duration, function()
		conn:Disconnect()
		lv:Destroy()
		attachment:Destroy()
	end)
end

-- Inverse Slide velocity (rightward movement with slight upward arc)
NetworkModule["ISVelocity"] = function(Character, Data)
	if not Character or not Character.PrimaryPart then
		warn("ISVelocity: Character or PrimaryPart is nil")
		return
	end

	local rootPart = Character.PrimaryPart
	local attachment = rootPart:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = rootPart
	end

	-- Create LinearVelocity
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ISVelocity"
	lv.MaxForce = math.huge
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.Parent = rootPart

	local startTime = os.clock()
	local duration = Data.duration or 0.5 -- Default duration
	local rightwardSpeed = Data.HorizontalPower or 25
	local upwardSpeed = Data.UpwardPower or 8

	-- Connection to update velocity every frame
	local conn
	conn = RunService.Heartbeat:Connect(function()
		-- Calculate remaining duration (0 to 1)
		local elapsed = os.clock() - startTime
		local progress = math.clamp(1 - (elapsed / duration), 0, 1)

		-- Quad EaseOut easing
		local easedProgress = 1 - (1 - progress) ^ 2

		-- Get current right direction (flattened to horizontal)
		local rightVector = rootPart.CFrame.RightVector
		rightVector = Vector3.new(rightVector.X, 0, rightVector.Z).Unit

		-- Apply velocity with gradual decay
		local currentRightSpeed = rightwardSpeed * easedProgress
		local currentUpSpeed = upwardSpeed * easedProgress

		lv.VectorVelocity = rightVector * currentRightSpeed + Vector3.new(0, currentUpSpeed, 0)
	end)

	-- Cleanup after duration seconds
	task.delay(duration, function()
		conn:Disconnect()
		lv:Destroy()
	end)
end

-- Remove Inverse Slide velocity
NetworkModule["RemoveISVelocity"] = function(Character, Data)
	if not Character or not Character.PrimaryPart then
		return
	end

	local rootPart = Character.PrimaryPart
	local lv = rootPart:FindFirstChild("ISVelocity")
	if lv then
		lv:Destroy()
	end
end

-- Stone Lance launch velocity for targets
NetworkModule["StoneLaunchVelocity"] = function(Character, Data)
	if not Character or not Character.PrimaryPart then
		warn("StoneLaunchVelocity: Character or PrimaryPart is nil")
		return
	end

	local hitTargetRoot = Character.PrimaryPart
	local attachment = hitTargetRoot:FindFirstChild("StoneLanceAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "StoneLanceAttachment"
		attachment.Parent = hitTargetRoot
	end

	-- Clean up old velocity
	local oldLV = hitTargetRoot:FindFirstChild("StoneLaunchVelocity")
	if oldLV then
		oldLV:Destroy()
	end

	local velocity = Data.Velocity or Vector3.new(0, 30, 0)

	local lv = Instance.new("LinearVelocity")
	lv.Name = "StoneLaunchVelocity"
	lv.MaxForce = 200000  -- Reduced from math.huge to prevent excessive force
	lv.VectorVelocity = velocity
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = hitTargetRoot

	task.delay(0.8, function()
		if lv and lv.Parent then
			lv:Destroy()
		end
	end)
end

-- Pincer Impact forward velocity
NetworkModule["PincerForwardVelocity"] = function(Character)
	if not Character or not Character.PrimaryPart then
		warn("PincerForwardVelocity: Character or PrimaryPart is nil")
		return
	end

	local rootPart = Character.PrimaryPart
	local attachment = rootPart:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = rootPart
	end

	-- Clean up old velocity
	local oldVel = rootPart:FindFirstChild("PincerImpactVelocity")
	if oldVel then
		oldVel:Destroy()
	end

	-- Flatten forward direction to horizontal
	local forwardDirection = rootPart.CFrame.LookVector
	forwardDirection = Vector3.new(forwardDirection.X, 0, forwardDirection.Z).Unit

	local forwardVelocity = Instance.new("LinearVelocity")
	forwardVelocity.Name = "PincerImpactVelocity"
	forwardVelocity.MaxForce = 200000  -- Reduced from math.huge to prevent excessive force
	forwardVelocity.VectorVelocity = forwardDirection * 30
	forwardVelocity.Attachment0 = attachment
	forwardVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	forwardVelocity.Parent = rootPart
end

-- Remove Pincer Impact forward velocity
NetworkModule["RemovePincerForwardVelocity"] = function(Character)
	if not Character or not Character.PrimaryPart then
		return
	end

	local rootPart = Character.PrimaryPart
	local forwardVelocity = rootPart:FindFirstChild("PincerImpactVelocity")
	if forwardVelocity then
		forwardVelocity:Destroy()
	end
end

-- Parry screen shake for invoker (person who got parried)
NetworkModule["ParryShakeInvoker"] = function(Character)
	if not Character then return end

	-- Slight screen shake for the person who got parried
	local Base = require(Replicated.Effects.Base)
	-- New API: Base.Shake(magnitude: number, frequency: number?, location: Vector3?)
	Base.Shake(3, 10, Character and Character:FindFirstChild("HumanoidRootPart") and Character.HumanoidRootPart.Position or nil)
end

-- Parry screen shake for target (person who parried)
NetworkModule["ParryShakeTarget"] = function(Character)
	if not Character then return end

	-- Slight screen shake for the person who successfully parried
	local Base = require(Replicated.Effects.Base)
	-- New API: Base.Shake(magnitude: number, frequency: number?, location: Vector3?)
	Base.Shake(2, 8, Character and Character:FindFirstChild("HumanoidRootPart") and Character.HumanoidRootPart.Position or nil)
end

-- ============================================
-- KNOCKBACK FOLLOW-UP HANDLERS
-- ============================================

-- Highlight on knockback target (visible only to the attacker)
NetworkModule["KnockbackFollowUpHighlight"] = function(_Character: Model, Targ: Model?, duration: number?, chronoId: number?)
	-- Resolve target: either by ChronoId (NPC in client camera) or direct Instance ref (player)
	local resolvedTarget = nil
	if chronoId then
		for _, child in ipairs(workspace:GetChildren()) do
			if child.Name == "NpcRegistryCamera" and child:IsA("Camera") and child:GetAttribute("ClientOwned") then
				resolvedTarget = child:FindFirstChild(tostring(chronoId))
				break
			end
		end
	elseif Targ and typeof(Targ) == "Instance" then
		resolvedTarget = Targ
	end

	if not resolvedTarget then return end

	-- Remove any existing follow-up highlight
	local existing = resolvedTarget:FindFirstChild("KnockbackFollowUpHighlight")
	if existing then existing:Destroy() end

	-- Create golden highlight on the target
	local highlight = Instance.new("Highlight")
	highlight.Name = "KnockbackFollowUpHighlight"
	highlight.FillColor = Color3.fromRGB(255, 200, 50) -- Golden
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.fromRGB(255, 150, 0) -- Orange outline
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded -- Visible through walls
	highlight.Parent = resolvedTarget

	-- Remove after knockback duration
	local highlightDuration = duration or 1.267
	task.delay(highlightDuration, function()
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end)
end

-- Bezier curve chase velocity for follow-up attack
NetworkModule["KnockbackFollowUpBvel"] = function(Character: Model, Targ: Model?, duration: number?, chronoId: number?)
	if not Character then return end
	if typeof(Character) ~= "Instance" then return end

	local rootPart = Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Resolve target: either by ChronoId (NPC in client camera) or direct Instance ref (player)
	local resolvedTarget = nil
	if chronoId then
		-- Find the client's Chrono camera clone
		for _, child in ipairs(workspace:GetChildren()) do
			if child.Name == "NpcRegistryCamera" and child:IsA("Camera") and child:GetAttribute("ClientOwned") then
				resolvedTarget = child:FindFirstChild(tostring(chronoId))
				break
			end
		end
	elseif Targ and typeof(Targ) == "Instance" then
		resolvedTarget = Targ
	end

	if not resolvedTarget then return end

	local targetRoot = resolvedTarget:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	-- Clean up existing body movers
	for _, child in ipairs(rootPart:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
			child:Destroy()
		end
	end

	local travelTime = duration or 0.5

	-- Bezier curve setup: P0=start, P1=midpoint+arc, P2=target(live)
	local startPos = rootPart.Position
	local endPos = targetRoot.Position
	local dist = (endPos - startPos).Magnitude
	local midpoint = (startPos + endPos) / 2 + Vector3.new(0, math.clamp(dist * 0.3, 3, 12), 0)

	local attachment = rootPart:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = rootPart
	end

	local lv = Instance.new("LinearVelocity")
	lv.Name = "KnockbackFollowUpVelocity"
	lv.MaxForce = math.huge
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.zero
	lv.Parent = rootPart

	local startTime = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		local t = math.clamp(elapsed / travelTime, 0, 1)

		if t >= 1 then
			if conn then conn:Disconnect() end
			if lv and lv.Parent then lv:Destroy() end
			return
		end

		-- Quadratic bezier derivative: B'(t) = 2(1-t)(P1-P0) + 2t(P2-P1)
		local p0 = startPos
		local p1 = midpoint
		local p2 = targetRoot.Position -- Track target position live

		local velocity = 2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)
		velocity = velocity / travelTime

		if lv and lv.Parent then
			lv.VectorVelocity = velocity
		else
			if conn then conn:Disconnect() end
		end
	end)

	-- Safety cleanup after travel time
	task.delay(travelTime, function()
		if conn then conn:Disconnect() end
		if lv and lv.Parent then lv:Destroy() end
	end)
end

-- ============================================
-- CHARGED CRITICAL (M2) VFX
-- ============================================

NetworkModule["CriticalChargeStart"] = function(Character: Model)
	if not Character or not Character.Parent then return end

	-- Resolve Chrono NPC clones
	if typeof(Character) ~= "Instance" then return end

	-- Remove any existing charge highlight
	local existing = Character:FindFirstChild("CriticalChargeHighlight")
	if existing then existing:Destroy() end

	local highlight = Instance.new("Highlight")
	highlight.Name = "CriticalChargeHighlight"
	highlight.FillColor = Color3.fromRGB(255, 255, 255) -- Stage 1: White
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0.3
	highlight.Parent = Character

	local startTime = os.clock()
	local MAX_CHARGE = 1.0

	-- Stage colors
	local stage1Color = Color3.fromRGB(255, 255, 255) -- White
	local stage2Color = Color3.fromRGB(255, 220, 50)  -- Yellow
	local stage3Color = Color3.fromRGB(255, 50, 50)   -- Red

	local conn
	conn = game:GetService("RunService").Heartbeat:Connect(function()
		if not highlight or not highlight.Parent then
			if conn then conn:Disconnect() end
			return
		end

		local elapsed = os.clock() - startTime
		if elapsed >= MAX_CHARGE + 0.1 then
			-- Auto-cleanup after max charge
			if conn then conn:Disconnect() end
			return
		end

		-- Tween between stages
		local t = math.clamp(elapsed / MAX_CHARGE, 0, 1)
		local fillColor, fillTransparency, outlineColor

		if t < 0.33 then
			-- Stage 1: White, subtle
			local st = t / 0.33
			fillColor = stage1Color
			fillTransparency = 0.7 - (st * 0.1) -- 0.7 → 0.6
			outlineColor = stage1Color
		elseif t < 0.66 then
			-- Stage 2: White → Yellow
			local st = (t - 0.33) / 0.33
			fillColor = stage1Color:Lerp(stage2Color, st)
			fillTransparency = 0.6 - (st * 0.1) -- 0.6 → 0.5
			outlineColor = stage1Color:Lerp(stage2Color, st)
		else
			-- Stage 3: Yellow → Red
			local st = (t - 0.66) / 0.34
			fillColor = stage2Color:Lerp(stage3Color, st)
			fillTransparency = 0.5 - (st * 0.2) -- 0.5 → 0.3
			outlineColor = stage2Color:Lerp(stage3Color, st)
		end

		highlight.FillColor = fillColor
		highlight.FillTransparency = fillTransparency
		highlight.OutlineColor = outlineColor

		-- Pulsing outline
		highlight.OutlineTransparency = 0.2 + math.sin(elapsed * 8) * 0.15
	end)

	-- Safety cleanup after max time
	task.delay(MAX_CHARGE + 0.5, function()
		if conn then conn:Disconnect() end
		if highlight and highlight.Parent then highlight:Destroy() end
	end)
end

NetworkModule["CriticalChargeRelease"] = function(Character: Model)
	if not Character or not Character.Parent then return end
	if typeof(Character) ~= "Instance" then return end

	local highlight = Character:FindFirstChild("CriticalChargeHighlight")
	if not highlight then return end

	-- Brief flash then destroy
	highlight.FillTransparency = 0
	highlight.OutlineTransparency = 0
	task.delay(0.1, function()
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end)
end

-- ============================================
-- AERIAL ATTACK VELOCITY
-- ============================================

NetworkModule["AerialAttackBvel"] = function(Character: Model)
	if not Character or not Character.Parent then return end
	if typeof(Character) ~= "Instance" then return end

	local eroot = Character:FindFirstChild("HumanoidRootPart")
	if not eroot then return end

	local forward = eroot.CFrame.LookVector

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(50000, 50000, 50000)
	bv.Velocity = forward * 35 + Vector3.new(0, 25, 0)
	bv.Parent = eroot

	-- Smooth diving arc: strong upward launch then forward dive down
	-- Total ~0.45s — noticeable lift before the dive
	local startTime = os.clock()
	local duration = 0.45
	local conn
	conn = game:GetService("RunService").Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			if conn then conn:Disconnect() end
			if bv and bv.Parent then bv:Destroy() end
			return
		end

		local t = elapsed / duration -- 0 to 1 over duration

		-- Forward: strong burst that eases out smoothly
		local fwdPower = 40 * (1 - t * t) -- Quadratic ease-out

		-- Vertical: strong lift in first ~30%, then dive down
		local vertPower = 25 * math.cos(t * math.pi * 1.1) - 18 * t

		bv.Velocity = forward * fwdPower + Vector3.new(0, vertPower, 0)
	end)
end

-- ============================================
-- SPECIALIZED PACKET ENDPOINTS (Optimized)
-- ============================================

-- BvelSimple: Character + Effect uint8 (M1, M2, Jump, Lunge, Dash directions)
NetworkModule.EndPointSimple = function(Player, Data)
	if not Data or not Data.Character then
		warn("[BvelSimple] EndPoint called with invalid data")
		return
	end

	local effectName = BvelSimpleEffectNames[Data.Effect]
	if not effectName then
		warn("[BvelSimple] Unknown effect:", Data.Effect)
		return
	end

	local func = NetworkModule[effectName]
	if func then
		func(Data.Character)
	else
		warn("[BvelSimple] No function found for effect:", effectName)
	end
end

-- BvelKnockback: Character + Direction vec3 + HorizontalPower + UpwardPower
NetworkModule.EndPointKnockback = function(Player, Data)
	if not Data or not Data.Character then
		warn("[BvelKnockback] EndPoint called with invalid data")
		return
	end

	-- Call BFKnockback with the typed parameters
	NetworkModule["BFKnockback"](Data.Character, Data.Direction, Data.HorizontalPower, Data.UpwardPower)
end

-- BvelRemove: Character + Effect uint8 (what to remove)
NetworkModule.EndPointRemove = function(Player, Data)
	if not Data or not Data.Character then
		warn("[BvelRemove] EndPoint called with invalid data")
		return
	end

	local effectType = BvelRemoveEffectNames[Data.Effect]
	if not effectType then
		warn("[BvelRemove] Unknown effect type:", Data.Effect)
		return
	end

	local Character = Data.Character
	local rootPart = Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	if effectType == "All" then
		-- Remove all body movers (RemoveBvel)
		NetworkModule["RemoveBvel"](Character)
	elseif effectType == "Pincer" then
		-- Remove Pincer velocity specifically
		NetworkModule["RemovePincerForwardVelocity"](Character)
	elseif effectType == "IS" then
		-- Remove Inverse Slide velocity
		NetworkModule["RemoveISVelocity"](Character, {})
	else
		-- For specific types, remove by name pattern
		for _, v in pairs(Character:GetDescendants()) do
			if v:IsA("LinearVelocity") or v:IsA("BodyVelocity") then
				if effectType == "M1" and v.Name:find("M1") then
					v:Destroy()
				elseif effectType == "M2" and v.Name:find("M2") then
					v:Destroy()
				elseif effectType == "Knockback" and v.Name:find("Knockback") then
					v:Destroy()
				elseif effectType == "Dash" and v.Name:find("Dash") then
					v:Destroy()
				elseif effectType == "Lunge" and v.Name:find("Lunge") then
					v:Destroy()
				end
			end
		end
	end
end

-- BvelVelocity: Character + Velocity vec3 + optional Duration
NetworkModule.EndPointVelocity = function(Player, Data)
	if not Data or not Data.Character then
		warn("[BvelVelocity] EndPoint called with invalid data")
		return
	end

	local Character = Data.Character
	local rootPart = Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local attachment = rootPart:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = rootPart
	end

	-- Create LinearVelocity with the specified velocity
	local lv = Instance.new("LinearVelocity")
	lv.Name = "BvelVelocity"
	lv.MaxForce = 200000
	lv.VectorVelocity = Data.Velocity
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	local duration = Data.Duration or 0.5

	-- Tween out the velocity
	TweenService:Create(
		lv,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, 0) }
	):Play()

	Debris:AddItem(lv, duration)
end

-- ============================================
-- REGISTER SPECIALIZED PACKET LISTENERS
-- ============================================
-- These are registered here since the Events/init.lua only auto-registers
-- packets matching the module name (Bvel). The specialized packets need
-- manual registration to their respective endpoint functions.

local function registerSpecializedListeners()
	-- BvelSimple: Character + Effect uint8
	if Client.Packets.BvelSimple then
		Client.Packets.BvelSimple.listen(function(Data)
			NetworkModule.EndPointSimple(nil, Data)
		end)
	end

	-- BvelKnockback: Character + Direction + HorizontalPower + UpwardPower
	if Client.Packets.BvelKnockback then
		Client.Packets.BvelKnockback.listen(function(Data)
			NetworkModule.EndPointKnockback(nil, Data)
		end)
	end

	-- BvelRemove: Character + Effect uint8
	if Client.Packets.BvelRemove then
		Client.Packets.BvelRemove.listen(function(Data)
			NetworkModule.EndPointRemove(nil, Data)
		end)
	end

	-- BvelVelocity: Character + Velocity + optional Duration
	if Client.Packets.BvelVelocity then
		Client.Packets.BvelVelocity.listen(function(Data)
			NetworkModule.EndPointVelocity(nil, Data)
		end)
	end
end

-- Register on module load
registerSpecializedListeners()

return NetworkModule
