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
	NetworkModule[Data.Name](Data.Character, Data.Targ)
end

NetworkModule["M1Bvel"] = function(Character) -- // Linear Version
	local Velocity = Instance.new("LinearVelocity")
	Velocity.Attachment0 = Character.PrimaryPart.RootAttachment
	Velocity.ForceLimitsEnabled = true
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.MaxAxesForce = Vector3.new(100000, 0, 100000)
	Velocity.RelativeTo = "Attachment0"
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.VectorVelocity = Vector3.new(0, 0, -60)
	Velocity.Parent = Character.PrimaryPart

	Debris:AddItem(Velocity, 0.15)

	TweenService:Create(
		Velocity,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, 0) }
	):Play()
end

NetworkModule["M2Bvel"] = function(Character) -- // Linear Version
	local Velocity = Instance.new("LinearVelocity")
	Velocity.Attachment0 = Character.PrimaryPart.RootAttachment
	Velocity.ForceLimitsEnabled = true
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.MaxAxesForce = Vector3.new(100000, 0, 100000)
	Velocity.RelativeTo = "Attachment0"
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.VectorVelocity = Vector3.new(0, 0, -80)
	Velocity.Parent = Character.PrimaryPart

	Debris:AddItem(Velocity, 0.35)

	TweenService:Create(
		Velocity,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, 0) }
	):Play()
end

NetworkModule["Bone GauntletsRunningBvel"] = function(Character)
	local Velocity = Instance.new("LinearVelocity")
	Velocity.Attachment0 = Character.PrimaryPart.RootAttachment
	Velocity.ForceLimitsEnabled = true
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.MaxAxesForce = Vector3.new(100000, 0, 100000)
	Velocity.RelativeTo = "Attachment0"
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.VectorVelocity = Vector3.new(0, 0, -80)
	Velocity.Parent = Character.PrimaryPart

	Debris:AddItem(Velocity, 0.35)

	TweenService:Create(
		Velocity,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, 0) }
	):Play()
end
NetworkModule["FistRunningBvel"] = function(Character)
	local lv = Instance.new("LinearVelocity")
	local attachment = Instance.new("Attachment")
	attachment.Parent = Character.PrimaryPart

	local rootPart = Character.PrimaryPart
	local speed = 50
	local duration = 0.65
	local startTime = os.clock()

	lv.MaxForce = math.huge
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	-- Connection to update velocity every frame
	local conn
	conn = RunService.Heartbeat:Connect(function()
		-- Calculate remaining duration (0 to 1)
		local elapsed = os.clock() - startTime
		local progress = math.clamp(1 - (elapsed / duration), 0, 1)

		-- Get current forward direction
		local forwardVector = rootPart.CFrame.LookVector

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
NetworkModule["FistBvel"] = function(Character: Model)
	local Velocity = Instance.new("LinearVelocity")
	Velocity.Attachment0 = Character.PrimaryPart.RootAttachment
	Velocity.ForceLimitsEnabled = true
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.MaxAxesForce = Vector3.new(100000, 0, 100000)
	Velocity.RelativeTo = "Attachment0"
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.VectorVelocity = Vector3.new(0, 0, 0)
	Velocity.Parent = Character.PrimaryPart

	Debris:AddItem(Velocity, 84 / 60)

	TweenService:Create(
		Velocity,
		TweenInfo.new(12 / 60, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, -50) }
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
	local Velocity = Instance.new("LinearVelocity")
	Velocity.Attachment0 = Character.PrimaryPart.RootAttachment
	Velocity.ForceLimitsEnabled = true
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.MaxAxesForce = Vector3.new(100000, 0, 100000)
	Velocity.RelativeTo = "Attachment0"
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.VectorVelocity = Vector3.new(0, 0, 50)
	Velocity.Parent = Character.PrimaryPart

	Debris:AddItem(Velocity, 0.15)

	TweenService:Create(
		Velocity,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ VectorVelocity = Vector3.new(0, 0, 0) }
	):Play()
end

NetworkModule["RemoveBvel"] = function(Character: Model)
	-- Only remove velocity objects that don't have special names (to avoid interrupting active moves)
	for _, v in pairs(Character:GetChildren()) do
		if v:IsA("BodyVelocity") or v:IsA("LinearVelocity") then
			-- Don't remove velocity objects with specific names that indicate active moves
			if not (v.Name == "NeedleThrust" or v.Name == "DownslamKick" or v.Name == "Dodge") then
				v:Destroy()
			end
		end
	end
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
	print(tim)
	local lv = Instance.new("LinearVelocity")
	local attachment = Instance.new("Attachment")
	attachment.Parent = Character.HumanoidRootPart

	local rootPart = Character.HumanoidRootPart
	local baseSpeed = 30 -- Starting speed
	local maxSpeed = 100 -- Maximum speed at end of duration
	local elapsedTime = 0

	lv.MaxForce = math.huge
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

	local direction = (eroot.Position - root.Position).Unit
	local power = 60

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = direction * power
	bv.Parent = eroot

	-- Removed conflicting AssemblyLinearVelocity assignment
	-- Let BodyVelocity handle the movement to prevent conflicts

	Debris:AddItem(bv, 0.35)
end

NetworkModule["NTBvel"] = function(Character)
    print("starting bvel")
    local lv = Instance.new("LinearVelocity")
    local attachment = Instance.new("Attachment")
    attachment.Parent = Character.PrimaryPart

    local rootPart = Character.PrimaryPart
    local speed = 50
    local duration = 0.6
    local startTime = os.clock()

    -- Ensure proper network ownership for smooth movement
    local player = game.Players:GetPlayerFromCharacter(Character)
    if player then
        rootPart:SetNetworkOwner(player)
    end

    lv.MaxForce = math.huge
    lv.Attachment0 = attachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Name = "NeedleThrust" -- Add name for tracking
    lv.Parent = rootPart

    -- Connection to update velocity every frame
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local elapsed = os.clock() - startTime
        local progress = math.clamp(elapsed / duration, 0, 1)

        -- Get current forward direction
        local forwardVector = rootPart.CFrame.LookVector

        -- Add collision detection to prevent going through walls
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {Character}
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

        local raycastResult = workspace:Raycast(
            rootPart.Position,
            forwardVector * (speed * 0.1), -- Check ahead based on current speed
            raycastParams
        )

        -- If collision detected, reduce horizontal speed
        local collisionMultiplier = raycastResult and 0.1 or 1

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

        local horizontalSpeed = speed * (1 - progress) * collisionMultiplier

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

	lv.MaxForce = math.huge
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	-- Connection to update velocity every frame
	local conn
	conn = RunService.Heartbeat:Connect(function()
		-- Calculate remaining duration (0 to 1)
		local elapsed = os.clock() - startTime
		local progress = math.clamp(1 - (elapsed / duration), 0, 1)

		-- Get current forward direction
		local forwardVector = rootPart.CFrame.LookVector

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

NetworkModule["GunsRunningBvel"] = function(Character)
	local lv = Instance.new("LinearVelocity")
	local attachment = Instance.new("Attachment")
	attachment.Parent = Character.PrimaryPart

	local rootPart = Character.PrimaryPart
	local speed = 50
	local duration = 0.65
	local startTime = os.clock()

	lv.MaxForce = math.huge
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	-- Connection to update velocity every frame
	local conn
	conn = RunService.Heartbeat:Connect(function()
		-- Calculate remaining duration (0 to 1)
		local elapsed = os.clock() - startTime
		local progress = math.clamp(1 - (elapsed / duration), 0, 1)

		-- Get current forward direction
		local forwardVector = rootPart.CFrame.LookVector

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

return NetworkModule
