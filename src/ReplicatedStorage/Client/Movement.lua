local Movement = {}; local Client = require(script.Parent);
Movement.__index = Movement;
local self = setmetatable({}, Movement);

-- ECS State Management (replaces StringValue waiting)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

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

-- Direction enum for optimized packet serialization (string -> uint8)
self.DirectionToEnum = {
	Forward = 0,
	Back = 1,
	Left = 2,
	Right = 3,
}

self.Connections = {};

Movement.Dodge = function()
	if not Client.Character then return end
	if not Client.Root or not Client.Humanoid then return end

	-- ECS-based state checks (no more StringValue waiting)
	-- StateManager handles entity lookup internally

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

	-- Use ActionPriority to check if Dodge can start (cancels walking/sprinting)
	if not Client.Library.CanStartAction(Client.Character, "Dodge") then
		---- print("🚫 Dodge blocked: Higher priority action in progress")
		return
	end

	-- Stuns always block actions (use StateManager directly)
	if StateManager.StateCount(Client.Character, "Stuns") then
		---- print("🚫 Dodge blocked: Character is stunned")
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

    -- Save running state before dash so we can resume after
    local wasRunning = Client.Running
    -- Stop running state and animation if currently running
    if Client.Running then
        Client.Running = false
        StateManager.RemoveState(Client.Character, "Speeds", "RunSpeedSet30")
        Client.Library.EndAction(Client.Character, "Sprinting")
        -- Stop run animation so dash animation plays cleanly
        if Client.RunAnim then
            Client.RunAnim:Stop()
        end
    end

    StateManager.AddState(Client.Character, "Status", "Dodging")

    -- CONSISTENT DASH PARAMETERS (defined early so StartAction can use Duration)
    local Speed = 135  -- Consistent speed
    local Duration = 0.35  -- Actual dash duration
    local TweenDuration = Duration  -- Match tween to velocity duration

    -- Start Dodge action with priority system (priority 2, cancels walking/sprinting)
    -- Duration must match actual dash duration to prevent getting stuck
    Client.Library.StartAction(Client.Character, "Dodge", Duration)

    local Direction = self.GetDirection(Client.Humanoid, Client.Root)
    local Vector = self.Vectors[Direction]

    Client.Library.StopMovementAnimations(Client.Character)
    Client.Library.StopAllAnims(Client.Character)
    local Animation = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Dashes[Direction])

    -- Set dash animation to highest priority so it overrides everything
    if Animation then
        Animation.Priority = Enum.AnimationPriority.Action4
    end

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

    Client.Packets.Dodge.send(self.DirectionToEnum[Direction])

    -- Create smooth deceleration tween - gradually slow down instead of stopping abruptly
    local SlowdownSpeed = Speed * 0.15  -- End at 15% of original speed for smooth transition
    local DashTween = Client.Service["TweenService"]:Create(
        Velocity,
        TweenInfo.new(TweenDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {VectorVelocity = Vector * SlowdownSpeed}
    )
    DashTween:Play()

    -- Track tween completion connection for cleanup
    local tweenConnection

    -- Function to cancel the dash (called when stunned/hit)
    local dashCancelled = false
    local function cancelDash()
        if dashCancelled then return end
        dashCancelled = true

        -- Stop the velocity immediately
        if Velocity and Velocity.Parent then
            Velocity:Destroy()
        end

        -- Stop the dash animation
        if Animation and Animation.IsPlaying then
            Animation:Stop()
        end

        -- Clean up dash state (both flag AND ECS action)
        Client.Dodging = false
        StateManager.RemoveState(Client.Character, "Status", "Dodging")
        Client.Library.EndAction(Client.Character, "Dodge")
    end

    -- ECS-based stun detection (replaces StringValue.Changed listener)
    local heartbeatConnection

    local function cleanupConnections()
        if heartbeatConnection then
            heartbeatConnection:Disconnect()
            heartbeatConnection = nil
        end
        if tweenConnection then
            tweenConnection:Disconnect()
            tweenConnection = nil
        end
    end

    -- Final cleanup - remove velocity completely after tween (tracked connection)
    tweenConnection = DashTween.Completed:Connect(function()
        if Velocity and Velocity.Parent then
            Velocity:Destroy()
        end
        tweenConnection = nil
    end)

    -- ECS-based stun detection via Heartbeat polling
    -- This replaces the old StringValue.Changed listener with direct ECS queries
    heartbeatConnection = Client.Service.RunService.Heartbeat:Connect(function()
        if dashCancelled then
            cleanupConnections()
            return
        end

        -- Check if character was destroyed (prevents memory leak)
        if not Client.Character or not Client.Character.Parent then
            cancelDash()
            cleanupConnections()
            return
        end

        -- Check ECS stun state directly via StateManager
        local allStuns = StateManager.GetAllStates(Client.Character, "Stuns")
        for _, stunName in ipairs(allStuns) do
            if stunName ~= "Dashing" then
                cancelDash()
                cleanupConnections()
                return
            end
        end
    end)

    Animation.Stopped:Once(function()
        -- Velocity cleanup is handled by the tween completion
        Client.Dodging = false
        StateManager.RemoveState(Client.Character, "Status", "Dodging")

        -- End the Dodge action in ActionPriority system to allow other actions
        Client.Library.EndAction(Client.Character, "Dodge")

        -- Disconnect all listeners when dash ends normally
        cleanupConnections()

        -- Resume running if player was running before dash and isn't stunned
        if wasRunning and not dashCancelled then
            -- Check that character is still valid and not stunned
            if Client.Character and Client.Character.Parent and not StateManager.StateCount(Client.Character, "Stuns") then
                -- Resume running state
                Client.Running = true
                Client._Running = true
                StateManager.AddState(Client.Character, "Speeds", "RunSpeedSet30")

                -- Restart run animation
                local Equipped = Client.Character:GetAttribute("Equipped")
                if Equipped then
                    Client.RunAnim = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Movement.WeaponRun)
                else
                    Client.RunAnim = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Movement.Run)
                end

                -- Set run animation priority
                if Client.RunAnim then
                    Client.RunAnim.Priority = Enum.AnimationPriority.Action
                end
            end
        end
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

	-- ECS-based state checks (no more StringValue waiting)
	-- StateManager handles entity lookup internally


	local Equipped = Client.Character:GetAttribute("Equipped");

	-- Don't allow running during parkour actions
	-- Check for blocking actions (ignore Sprinting since we're about to set it)
	local hasBlockingAction = false
	local actionStates = StateManager.GetAllStates(Client.Character, "Actions") or {}
	for _, action in ipairs(actionStates) do
		if action ~= "Sprinting" then
			hasBlockingAction = true
			break
		end
	end

	-- Use StateManager for stun check
	local isStunned = StateManager.StateCount(Client.Character, "Stuns")

	if State and not isStunned and not hasBlockingAction and not Client.Running and not Client.Leaping and not Client.Sliding and not Client.WallRunning and not Client.LedgeClimbing then
		---- print("[Movement.Run] ✅ Starting running - adding RunSpeedSet30 to Speeds")

		Client.Library.StopAllAnims(Client.Character);
		StateManager.AddState(Client.Character, "Speeds", "RunSpeedSet30")
		Client.Running = true;
		Client._Running = true; -- Simple flag for Attack input check (bypasses ECS)

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
		Client._Running = false; -- Clear simple flag

		StateManager.RemoveState(Client.Character, "Speeds", "RunSpeedSet30")

		if Client.RunAnim then Client.RunAnim:Stop(); Client.RunAnim = nil end;

		for _, v : RBXScriptConnection in next, self.Connections do
			v:Disconnect()
		end
	end
end

return Movement
