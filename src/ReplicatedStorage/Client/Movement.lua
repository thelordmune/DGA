local Movement = {}; local Client = require(script.Parent);
Movement.__index = Movement;
local self = setmetatable({}, Movement);

self.GetDirection = function(Humanoid, Root)
	local Direction = "Forward" --> What the default is
	if (Humanoid.MoveDirection:Dot(Root.CFrame.LookVector) > .75) then
		Direction = "Forward"
	elseif (Humanoid.MoveDirection:Dot(-Root.CFrame.LookVector) > .75) then
		Direction = "Back"
	elseif (Humanoid.MoveDirection:Dot(Root.CFrame.RightVector) > .75) then
		Direction = "Right"
	elseif (Humanoid.MoveDirection:Dot(-Root.CFrame.RightVector) > .75) then
		Direction = "Left"
	end

	return Direction
end

self.Vectors = {
	Forward = Vector3.new(0, 0, -1);
	Back    = Vector3.new(0, 0, 1);
	Left    = Vector3.new(-1, 0, 0);
	Right   = Vector3.new(1, 0, 0);
}

self.Connections = {};

Movement.Dodge = function()
	if not Client.Character then return end
	if not Client.Root or not Client.Humanoid then return end

	-- Wait for StringValues to be ready (with timeout)
	local maxWait = 2 -- Maximum 2 seconds wait
	local startTime = os.clock()

	while (not Client.Actions or not Client.Stuns or not Client.Speeds) and (os.clock() - startTime) < maxWait do
		if not Client.Actions then
			Client.Actions = Client.Character:FindFirstChild("Actions")
		end
		if not Client.Stuns then
			Client.Stuns = Client.Character:FindFirstChild("Stuns")
		end
		if not Client.Speeds then
			Client.Speeds = Client.Character:FindFirstChild("Speeds")
		end

		if not Client.Actions or not Client.Stuns or not Client.Speeds then
			task.wait(0.1) -- Wait a bit before checking again
		end
	end

	-- Final check - if still not ready, fail
	if not Client.Actions or not Client.Stuns or not Client.Speeds then
		warn(`[Dodge] Failed: StringValues not ready after {maxWait}s`)
		return
	end

	-- Clean up any existing dodges first
	for _, BodyMover in next, Client.Root:GetChildren() do
		if BodyMover.Name == "Dodge" then BodyMover:Destroy() end
	end

	-- Initialize charges if needed
	if not Client.DodgeCharges then
		Client.DodgeCharges = 2
	end

	-- Check if we can dash
	if Client.Dodging then
		---- print("🚫 Dodge blocked: Already dodging")
		return
	end
	if Client.Library.StateCount(Client.Actions) or
		Client.Library.StateCount(Client.Stuns) or
		Client.Library.StateCheck(Client.Speeds, "M1Speed8") then
		---- print("🚫 Dodge blocked: Character has active states")
		return
	end
	-- Prevent dashing during ragdoll
	if Client.Character:FindFirstChild("Ragdoll") then
		---- print("🚫 Dodge blocked: Character is ragdolled")
		return
	end

	---- print(`[Dodge] Current charges: {Client.DodgeCharges}`)

	-- Check cooldown only if out of charges
	if Client.DodgeCharges <= 0 then
		if Client.Library.CheckCooldown(Client.Character, "Dodge") then
			---- print("🚫 Dodge blocked: On cooldown")
			return
		end
		Client.DodgeCharges = 2  -- Reset charges
		---- print("✅ Dodge charges reset to 2")
	end

	Client.DodgeCharges = Client.DodgeCharges - 1
	---- print(`✅ Dodge charge used, remaining: {Client.DodgeCharges}`)

	-- Set cooldown when out of charges
	if Client.DodgeCharges <= 0 then
		Client.Library.SetCooldown(Client.Character, "Dodge", 2.5)
		---- print("⏱️ Dodge cooldown set to 2.5 seconds")
	end
    
    Client.Library.AddState(Client.Statuses, "Dodging")
    
    local Direction = self.GetDirection(Client.Humanoid, Client.Root)
    local Vector = self.Vectors[Direction]
    
    Client.Library.StopMovementAnimations(Client.Character)
    Client.Library.StopAllAnims(Client.Character)
    local Animation = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Dashes[Direction])
    
    -- CONSISTENT DASH PARAMETERS
    local Speed = 135  -- Consistent speed
    local Duration = 0.5  -- Consistent duration
    local TweenDuration = Duration  -- Match tween to velocity duration
    Client.Dodging = true

    local Velocity = Instance.new("LinearVelocity")
    Velocity.MaxAxesForce = Vector3.new(100000, 0, 100000)
    Velocity.ForceLimitsEnabled = true
    Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    Velocity.Attachment0 = Client.Root.RootAttachment
    Velocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
    Velocity.VectorVelocity = Vector * Speed
    Velocity.Name = "Dodge"
    Velocity.Parent = Client.Root

    -- Ensure velocity is destroyed at the right time
    Client.Utilities.Debris:AddItem(Velocity, Duration + 0.1)

    Client.Packets.Dodge.send({Direction = Direction})

    -- Create smooth deceleration tween - gradually slow down instead of stopping abruptly
    local SlowdownSpeed = Speed * 0.15  -- End at 15% of original speed for smooth transition
    local DashTween = Client.Service["TweenService"]:Create(
        Velocity,
        TweenInfo.new(TweenDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {VectorVelocity = Vector * SlowdownSpeed}
    )
    DashTween:Play()

    -- Final cleanup - remove velocity completely after tween
    DashTween.Completed:Connect(function()
        if Velocity and Velocity.Parent then
            Velocity:Destroy()
        end
    end)

    -- -- ---- print("Dash: Speed =", Speed, "Slowdown =", SlowdownSpeed, "Duration =", Duration, "Direction =", Direction)
    
    Animation.Stopped:Once(function()
        -- Velocity cleanup is handled by the tween completion
        Client.Dodging = false
        Client.Library.RemoveState(Client.Statuses, "Dodging")
    end)
end


Movement.Run = function(State)
	---- print(`[Movement.Run] Called with State: {State}`)

	-- Basic validation checks
	if not Client.Character then
		warn("[Movement.Run] Failed: No character")
		return
	end

	if not Client.Root or not Client.Humanoid then
		warn("[Movement.Run] Failed: No Root or Humanoid")
		return
	end

	-- Verify character is still valid and in workspace
	if not Client.Character.Parent then
		warn("[Movement.Run] Failed: Character not in workspace")
		return
	end

	-- Verify humanoid is alive
	if Client.Humanoid.Health <= 0 then
		warn("[Movement.Run] Failed: Humanoid is dead")
		return
	end

	-- Wait for StringValues to be ready (with timeout)
	local maxWait = 2 -- Maximum 2 seconds wait
	local startTime = os.clock()

	while (not Client.Actions or not Client.Stuns or not Client.Speeds) and (os.clock() - startTime) < maxWait do
		if not Client.Actions then
			Client.Actions = Client.Character:FindFirstChild("Actions")
		end
		if not Client.Stuns then
			Client.Stuns = Client.Character:FindFirstChild("Stuns")
		end
		if not Client.Speeds then
			Client.Speeds = Client.Character:FindFirstChild("Speeds")
		end

		if not Client.Actions or not Client.Stuns or not Client.Speeds then
			task.wait(0.1) -- Wait a bit before checking again
		end
	end

	-- Final check - if still not ready, fail
	if not Client.Actions or not Client.Stuns or not Client.Speeds then
		warn(`[Movement.Run] Failed: StringValues not ready after {maxWait}s - Actions: {Client.Actions ~= nil}, Stuns: {Client.Stuns ~= nil}, Speeds: {Client.Speeds ~= nil}`)
		return
	end

	---- print(`[Movement.Run] ✅ StringValues ready - Actions: {Client.Actions ~= nil}, Stuns: {Client.Stuns ~= nil}, Speeds: {Client.Speeds ~= nil}`)
	---- print(`[Movement.Run] Validation passed - Actions: {Client.Library.StateCount(Client.Actions)}, Stuns: {Client.Library.StateCount(Client.Stuns)}, Running: {Client.Running}`)


	local Weapon   = Client.Player:GetAttribute("Weapon");
	local Equipped = Client.Character:GetAttribute("Equipped");

	if State and not Client.Library.StateCount(Client.Stuns) and not Client.Library.StateCount(Client.Actions) and not Client.Running then
		print("[Movement.Run] ✅ Starting running - adding RunSpeedSet30 to Speeds")
		Client.Library.StopAllAnims(Client.Character);
		Client.Library.AddState(Client.Speeds, "RunSpeedSet30")
		print(`[Movement.Run] Speeds.Value after AddState: {Client.Speeds.Value}`)
		Client.Running = true;
		Client.RunAtk = false; -- Start as false, will be enabled after 1.5 seconds

		-- Cancel any existing running attack delay
		if Client["RunAtkDelay"] then
			task.cancel(Client["RunAtkDelay"])
			Client["RunAtkDelay"] = nil
		end

		-- Enable running attack after 1.5 seconds of continuous running
		Client["RunAtkDelay"] = task.delay(1.5, function()
			if Client.Running then
				Client.RunAtk = true
				print("[Movement.Run] ✅ Running attack enabled after 1.5 seconds")
			end
			Client["RunAtkDelay"] = nil
		end)

		if Equipped then
			Client.RunAnim = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Movement.WeaponRun);
		else
			Client.RunAnim = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Movement.Run);
		end

		-- Set run animation priority to Action (higher than Movement)
		if Client.RunAnim then
			Client.RunAnim.Priority = Enum.AnimationPriority.Action
		end
		
		local function CallStepLeft()
			if Client.Humanoid.FloorMaterial == Enum.Material.Air or Client.Dodging then return end;
			Client.Modules["Sounds"].Step(Client.Humanoid.FloorMaterial)
		end

		local function CallStepRight()
			if Client.Humanoid.FloorMaterial == Enum.Material.Air or Client.Dodging then return end;
			Client.Modules["Sounds"].Step(Client.Humanoid.FloorMaterial)
		end

		self.Connections[#self.Connections + 1] = Client.RunAnim:GetMarkerReachedSignal("Left"):Connect(CallStepLeft)
		self.Connections[#self.Connections + 1] = Client.RunAnim:GetMarkerReachedSignal("Right"):Connect(CallStepRight)
		
	elseif not State and Client.Running then
		---- print("[Movement.Run] ❌ Stopping running - removing RunSpeedSet30 from Speeds")
		Client.Running = false;
		Client.Library.RemoveState(Client.Speeds, "RunSpeedSet30")

		if Client.RunAnim then Client.RunAnim:Stop(); Client.RunAnim = nil end;

		-- Cancel the running attack enable delay if it's still pending
		if Client["RunAtkDelay"] then
			task.cancel(Client["RunAtkDelay"])
			Client["RunAtkDelay"] = nil
		end

		-- Disable running attack immediately when stopping
		Client.RunAtk = false

		for _, v : RBXScriptConnection in next, self.Connections do
			v:Disconnect()
		end
	end
end

return Movement
