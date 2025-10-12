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
NetworkModule["PIBvel"] = function(Character)
	if not Character or not Character.PrimaryPart then
		warn("PIBvel: Character or PrimaryPart is nil")
		return
	end

	local rootPart = Character.PrimaryPart

	-- Clean up any existing body movers FIRST
	--print(`[PIBvel] Cleaning body movers before creating new velocity`)
	for _, child in pairs(rootPart:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
			--print(`[PIBvel] Destroying existing {child.ClassName}: {child.Name}`)
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
	-- Clean up any existing velocities and body movers to prevent flinging
	for _, child in ipairs(Character.PrimaryPart:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
			child:Destroy()
		end
	end

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
	local startTime = os.clock()
	local rootPart = Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	--print(`[RemoveBvel] [{startTime}] START - Cleaning body movers from {Character.Name}`)
	--print(`[RemoveBvel] Current position: {rootPart.Position}`)
	--print(`[RemoveBvel] Current velocity: {rootPart.AssemblyLinearVelocity}`)

	local moversFound = 0
	-- Remove all body movers from HumanoidRootPart
	for _, v in pairs(Character:GetDescendants()) do
		if v:IsA("LinearVelocity") or v:IsA("BodyVelocity") or v:IsA("BodyPosition") or v:IsA("BodyGyro") then
			--print(`[RemoveBvel] Destroying {v.ClassName}: {v.Name} (Parent: {v.Parent.Name})`)
			moversFound = moversFound + 1
			v:Destroy()
		end
	end

	-- Also clear assembly velocity to remove any residual momentum
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	local endTime = os.clock()
	--print(`[RemoveBvel] [{endTime}] COMPLETE - Removed {moversFound} body movers in {(endTime - startTime) * 1000}ms`)
	--print(`[RemoveBvel] Final position: {rootPart.Position}`)
	--print(`[RemoveBvel] Final velocity: {rootPart.AssemblyLinearVelocity}`)
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
	--print(tim)
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

	-- Clean up any existing velocities and body movers to prevent flinging
	for _, child in ipairs(eroot:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
			child:Destroy()
		end
	end

	local direction = (eroot.Position - root.Position).Unit
	local power = 60

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = direction * power
	bv.Parent = eroot

	eroot.AssemblyLinearVelocity = direction * power

	Debris:AddItem(bv, 0.35)
end

NetworkModule["NTBvel"] = function(Character)
    local startTime = os.clock()
    local callId = math.random(1000, 9999)
    --print(`[NTBvel #{callId}] [{startTime}] START - Creating velocity for {Character.Name}`)
    --print(`[NTBvel #{callId}] ⚠️ WARNING: If you see multiple calls with different IDs, the skill is being triggered multiple times!`)

    local rootPart = Character.PrimaryPart
    if not rootPart then return end

    --print(`[NTBvel #{callId}] Position before cleanup: {rootPart.Position}`)
    --print(`[NTBvel #{callId}] Velocity before cleanup: {rootPart.AssemblyLinearVelocity}`)

    -- Stop ONLY movement animations (Walking, Running, Dash, etc.) but NOT skill animations
    local humanoid = Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            local tracks = animator:GetPlayingAnimationTracks()
            --print(`[NTBvel #{callId}] Checking {#tracks} active animations`)

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
                    --print(`[NTBvel #{callId}]   - Stopping movement anim: {animName}`)
                    track:Stop(0) -- Stop immediately with 0 fade time
                else
                    --print(`[NTBvel #{callId}]   - Keeping skill anim: {animName}`)
                end
            end
        end
    end

    -- Clean up any existing body movers FIRST
    --print(`[NTBvel #{callId}] Cleaning body movers before creating new velocity`)
    local moversFound = 0
    for _, child in pairs(rootPart:GetChildren()) do
        if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
            --print(`[NTBvel #{callId}] Destroying existing {child.ClassName}: {child.Name}`)
            moversFound = moversFound + 1
            child:Destroy()
        end
    end
    --print(`[NTBvel #{callId}] Removed {moversFound} existing body movers`)

    -- Clear residual velocity
    rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

    --print(`[NTBvel #{callId}] Position after cleanup: {rootPart.Position}`)
    --print(`[NTBvel #{callId}] Velocity after cleanup: {rootPart.AssemblyLinearVelocity}`)

    local lv = Instance.new("LinearVelocity")
    local attachment = Instance.new("Attachment")
    attachment.Parent = rootPart

    local speed = 50
    local duration = 0.6
    local animStartTime = os.clock()

    --print(`[NTBvel #{callId}] Creating LinearVelocity with speed={speed}, duration={duration}`)

    lv.MaxForce = math.huge
    lv.Attachment0 = attachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = rootPart

    -- Connection to update velocity every frame
    local frameCount = 0
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local elapsed = os.clock() - animStartTime
        local progress = math.clamp(elapsed / duration, 0, 1)
        frameCount = frameCount + 1

        -- Get current forward direction
        local forwardVector = rootPart.CFrame.LookVector

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

        -- Debug tracking every 5 frames
        if frameCount % 5 == 0 then
            --print(`[NTBvel #{callId} Frame {frameCount}] Progress: {math.floor(progress * 100)}% | Pos: {rootPart.Position} | Vel: {rootPart.AssemblyLinearVelocity}`)
        end
    end)

    -- Cleanup after duration seconds
    task.delay(duration, function()
        --print(`[NTBvel #{callId}] ENDING - Final position: {rootPart.Position} | Final velocity: {rootPart.AssemblyLinearVelocity}`)
        conn:Disconnect()
        lv:Destroy()
        attachment:Destroy()
        --print(`[NTBvel #{callId}] Cleanup complete`)
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

-- NPC Dash - Client-side replication for smooth visual movement
NetworkModule["NPCDash"] = function(Character, Direction, DashVector)
	if not Character or not Character.PrimaryPart then
		warn("NPCDash: Character or PrimaryPart is nil")
		return
	end

	local root = Character.PrimaryPart

	-- Clean up any existing dash velocities
	for _, bodyMover in pairs(root:GetChildren()) do
		if bodyMover:IsA("LinearVelocity") or bodyMover:IsA("BodyVelocity") then
			if bodyMover.Name == "NPCDash" or bodyMover.Name == "NPCDodge" then
				bodyMover:Destroy()
			end
		end
	end

	-- Create smooth client-side velocity
	local Speed = 100
	local Duration = 0.4

	local Velocity = Instance.new("LinearVelocity")
	Velocity.Name = "NPCDash"
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.ForceLimitsEnabled = true
	Velocity.MaxAxesForce = Vector3.new(80000, 0, 80000)
	Velocity.VectorVelocity = DashVector * Speed
	Velocity.RelativeTo = Enum.ActuatorRelativeTo.World

	-- Create attachment if it doesn't exist
	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = root
	end

	Velocity.Attachment0 = attachment
	Velocity.Parent = root

	-- Smooth deceleration tween
	local SlowdownSpeed = Speed * 0.2
	local DashTween = TweenService:Create(
		Velocity,
		TweenInfo.new(Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{VectorVelocity = DashVector * SlowdownSpeed}
	)
	DashTween:Play()

	-- Cleanup
	DashTween.Completed:Connect(function()
		if Velocity and Velocity.Parent then
			Velocity:Destroy()
		end
	end)

	-- Safety cleanup
	task.delay(Duration + 0.1, function()
		if Velocity and Velocity.Parent then
			Velocity:Destroy()
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
	lv.MaxForce = math.huge
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

	local forwardVelocity = Instance.new("LinearVelocity")
	forwardVelocity.Name = "PincerImpactVelocity"
	forwardVelocity.MaxForce = math.huge
	forwardVelocity.VectorVelocity = rootPart.CFrame.LookVector * 30
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

return NetworkModule
