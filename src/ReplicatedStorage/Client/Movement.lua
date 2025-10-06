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

Movement.DodgeCancel = function()
	if not Client.Dodging then return end;
	if not Client.Character then return end;
	if not Client.Root or not Client.Humanoid then return end;
	if not Client.Actions or not Client.Stuns then return end;
	if not Client.Library.StateCheck(Client.Statuses, "Dodging") then return end
	if Client.Library.CheckCooldown(Client.Character, "DodgeCancel") or Client.Library.StateCount(Client.Stuns) then return end
	
	Client.Library.RemoveState(Client.Statuses, "Dodging")
	Client.Library.SetCooldown(Client.Character, "DodgeCancel", 4);
	Client.Library.StopMovementAnimations(Client.Character);
	Client.Library.PlaySound(Client.Character,Client.Service.ReplicatedStorage.Assets.SFX.Movement.RollCancel)
	coroutine.wrap(function()
		for _, BodyMover in next, Client.Root:GetChildren() do
			if BodyMover.Name == "Dodge" then BodyMover:Destroy() end;
		end
	end)();
	
	
	local Direction = self.GetDirection(Client.Humanoid, Client.Root);
	if Direction == "Right" or Direction == "Forward" then
		Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Dashes["CancelRight"])
	else
		Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Dashes["CancelLeft"])
	end
	
	Client.Packets.DodgeCancel.send();
	Client.Library.ResetCooldown(Client.Character, "Dodge");
end

Movement.Dodge = function()
	if not Client.Character then return end
	if not Client.Root or not Client.Humanoid then return end
	if not Client.Actions or not Client.Stuns then return end

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
		print("Dodge blocked: Already dodging")
		return
	end
	if Client.Library.StateCount(Client.Actions) or
		Client.Library.StateCount(Client.Stuns) or
		Client.Library.StateCheck(Client.Speeds, "M1Speed12") then
		print("Dodge blocked: Character has active states")
		return
	end

	-- Check cooldown only if out of charges
	if Client.DodgeCharges <= 0 then
		if Client.Library.CheckCooldown(Client.Character, "Dodge") then
			print("Dodge blocked: On cooldown")
			return
		end
		Client.DodgeCharges = 2  -- Reset charges
		print("Dodge charges reset to 2")
	end

	Client.DodgeCharges = Client.DodgeCharges - 1
	print("Dodge charge used, remaining:", Client.DodgeCharges)

	-- Set cooldown when out of charges
	if Client.DodgeCharges <= 0 then
		Client.Library.SetCooldown(Client.Character, "Dodge", 2)
		print("Dodge cooldown set")
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

    -- Clean up any existing velocities and body movers to prevent interference
    for _, child in ipairs(Client.Root:GetChildren()) do
        if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
            child:Destroy()
        end
    end

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

    print("Dash: Speed =", Speed, "Slowdown =", SlowdownSpeed, "Duration =", Duration, "Direction =", Direction)
    
    Animation.Stopped:Once(function()
        -- Velocity cleanup is handled by the tween completion
        Client.Dodging = false
        Client.Library.RemoveState(Client.Statuses, "Dodging")
    end)
end


Movement.Run = function(State)
	if not Client.Character then return end;
	if not Client.Root or not Client.Humanoid then return end;
	if not Client.Actions or not Client.Stuns or not Client.Speeds then return end;
	
	local Weapon   = Client.Player:GetAttribute("Weapon");
	local Equipped = Client.Character:GetAttribute("Equipped");
	
	if State and not Client.Library.StateCount(Client.Stuns) and not Client.Library.StateCount(Client.Actions) and not Client.Running then
		Client.Library.StopAllAnims(Client.Character);
		Client.Library.AddState(Client.Speeds, "RunSpeedSet24")
		Client.Running = true;
		Client.RunAtk = true;
		
		if Client["RunAtkDelay"] then
			task.cancel(Client["RunAtkDelay"])
			Client["RunAtkDelay"] = nil
		end
		
		if Equipped then
			Client.RunAnim = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Movement.WeaponRun);
		else
			Client.RunAnim = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Movement.Run);
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
		Client.Running = false;
		Client.Library.RemoveState(Client.Speeds, "RunSpeedSet24")
		
		if Client.RunAnim then Client.RunAnim:Stop(); Client.RunAnim = nil end;
		
		Client["RunAtkDelay"] = task.delay(.1,function()
			Client.RunAtk = false
			Client["RunAtkDelay"] = nil
		end)
		
		for _, v : RBXScriptConnection in next, self.Connections do
			v:Disconnect()
		end
	end
end

return Movement
