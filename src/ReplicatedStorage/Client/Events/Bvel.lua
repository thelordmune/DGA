local TweenService = game:GetService("TweenService")
local Replicated = game:GetService("ReplicatedStorage")
local Visuals = require(Replicated.Modules.Visuals)
local Utilities = require(Replicated.Modules.Utilities)
local RunService = game:GetService("RunService")
local Debris = Utilities.Debris
local NetworkModule = {}
local Client = require(script.Parent.Parent)

NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

type Entity = {
	Name: string,
	Character: Model,
}

NetworkModule.EndPoint = function(Player, Data)
	if Data.Name == "BFKnockback" then
		NetworkModule[Data.Name](Data.Character, Data.Direction, Data.HorizontalPower, Data.UpwardPower)
	elseif Data.Name == "StoneLaunchVelocity" or Data.Name == "PincerForwardVelocity" or Data.Name == "RemovePincerForwardVelocity" then
		NetworkModule[Data.Name](Data.Character, Data)
	elseif Data.Name == "NPCDash" then
		-- Pass both direction name and velocity vector
		NetworkModule[Data.Name](Data.Character, Data.Direction, Data.Velocity)
	else
		NetworkModule[Data.Name](Data.Character, Data.Targ)
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
	---- print(`[PIBvel] Cleaning body movers before creating new velocity`)
	for _, child in pairs(rootPart:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
			---- print(`[PIBvel] Destroying existing {child.ClassName}: {child.Name}`)
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

	---- print(`[RemoveBvel] [{startTime}] START - Cleaning body movers from {Character.Name}`)
	---- print(`[RemoveBvel] Current position: {rootPart.Position}`)
	---- print(`[RemoveBvel] Current velocity: {rootPart.AssemblyLinearVelocity}`)

	local moversFound = 0
	-- Remove all body movers from HumanoidRootPart
	for _, v in pairs(Character:GetDescendants()) do
		if v:IsA("LinearVelocity") or v:IsA("BodyVelocity") or v:IsA("BodyPosition") or v:IsA("BodyGyro") then
			---- print(`[RemoveBvel] Destroying {v.ClassName}: {v.Name} (Parent: {v.Parent.Name})`)
			moversFound = moversFound + 1
			v:Destroy()
		end
	end

	-- Also clear assembly velocity to remove any residual momentum
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	local endTime = os.clock()
	---- print(`[RemoveBvel] [{endTime}] COMPLETE - Removed {moversFound} body movers in {(endTime - startTime) * 1000}ms`)
	---- print(`[RemoveBvel] Final position: {rootPart.Position}`)
	---- print(`[RemoveBvel] Final velocity: {rootPart.AssemblyLinearVelocity}`)
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
	---- print(tim)
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

NetworkModule["KnockbackBvel"] = function(Character: Model | Entity, Targ: Model | Entity)
	local root = Character.HumanoidRootPart
	local eroot = Targ.HumanoidRootPart

	-- Clean up any existing velocities and body movers to prevent flinging
	for _, child in ipairs(eroot:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
			child:Destroy()
		end
	end

	-- Calculate knockback direction (away from attacker)
	local direction = (eroot.Position - root.Position).Unit
	direction = Vector3.new(direction.X, 0, direction.Z).Unit  -- Flatten to horizontal

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

	local maxPower = 80
	local duration = 0.75 -- Match animation duration better

	-- Reset any existing velocity first
	eroot.AssemblyLinearVelocity = Vector3.zero
	eroot.AssemblyAngularVelocity = Vector3.zero

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(50000, 0, 50000)
	bv.Velocity = Vector3.zero -- Start at zero
	bv.Parent = eroot

	-- Use Heartbeat to smoothly update velocity
	local startTime = os.clock()
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			connection:Disconnect()
			return
		end

		-- Calculate progress using Exponential EaseIn
		local progress = elapsed / duration
		local easedProgress = progress ^ 3 -- Exponential ease in (cubic)
		local currentPower = maxPower * easedProgress

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
		animationName = "SDash"
	elseif Direction == "Left" then
		animationName = "ADash"
	elseif Direction == "Right" then
		animationName = "DDash"
	else
		animationName = "WDash"
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
	Base.Shake("Once", {
		3,  -- magnitude
		10, -- roughness
		0,  -- fadeInTime
		0.3, -- fadeOutTime
		Vector3.new(0.3, 0.3, 0.3), -- posInfluence
		Vector3.new(1, 1, 1) -- rotInfluence
	})
end

-- Parry screen shake for target (person who parried)
NetworkModule["ParryShakeTarget"] = function(Character)
	if not Character then return end

	-- Slight screen shake for the person who successfully parried
	local Base = require(Replicated.Effects.Base)
	Base.Shake("Once", {
		2,  -- magnitude (slightly less than invoker)
		8,  -- roughness
		0,  -- fadeInTime
		0.25, -- fadeOutTime
		Vector3.new(0.2, 0.2, 0.2), -- posInfluence
		Vector3.new(0.8, 0.8, 0.8) -- rotInfluence
	})
end

return NetworkModule
