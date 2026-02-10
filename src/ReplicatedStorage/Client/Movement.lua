local Movement = {}; local Client = require(script.Parent);
Movement.__index = Movement;
local self = setmetatable({}, Movement);

-- ECS State Management (replaces StringValue waiting)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
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

	-- Clean up any existing dodges first
	for _, BodyMover in next, Client.Root:GetChildren() do
		if BodyMover.Name == "Dodge" then BodyMover:Destroy() end
	end

	-- Initialize charges if needed
	if not Client.DodgeCharges then
		Client.DodgeCharges = 2
	end

	if Client.Dodging then return end

	if StateManager.StateCount(Client.Character, "Stuns") then return end

	if Client.Character:FindFirstChild("Ragdoll") then return end

	-- Check cooldown only if out of charges
	if Client.DodgeCharges <= 0 then
		if Client.Library.CheckCooldown(Client.Character, "Dodge") then return end
		Client.DodgeCharges = 2
	end

	Client.DodgeCharges = Client.DodgeCharges - 1

	if Client.DodgeCharges <= 0 then
		Client.Library.SetCooldown(Client.Character, "Dodge", 2.5)
	end

	-- Save running state before dash so we can resume after
	local wasRunning = Client.Running
	if Client.Running then
		Client.Running = false
		StateManager.RemoveState(Client.Character, "Speeds", "RunSpeedSet30")
		Client.Library.EndAction(Client.Character, "Sprinting")
		if Client.RunAnim then
			Client.RunAnim:Stop()
		end
	end

	StateManager.AddState(Client.Character, "Status", "Dodging")

	local Speed = 45
	local Duration = 0.5

	local Direction = self.GetDirection(Client.Humanoid, Client.Root)

	Client.Library.StopMovementAnimations(Client.Character)
	Client.Library.StopAllAnims(Client.Character)
	local Animation = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Dashes[Direction])

	if Animation then
		Animation.Priority = Enum.AnimationPriority.Action4
	end

	Client.Dodging = true
	Client.DashDirection = Direction

	-- World-space initial direction from character facing
	local initialWorldDir = Client.Root.CFrame:VectorToWorldSpace(self.Vectors[Direction])
	local direction = Vector3.new(initialWorldDir.X, 0, initialWorldDir.Z).Unit

	local camera = workspace.CurrentCamera

	-- Check for Focus Mini Mode
	local isMiniMode = Client.Character:GetAttribute("FocusMiniMode") == true

	-- Helper: collect visible parts and effects on character
	local function collectVisuals()
		local parts = {}
		local emitters = {}
		for _, desc in Client.Character:GetDescendants() do
			if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" and desc.Transparency < 1 then
				table.insert(parts, { part = desc, orig = desc.Transparency })
			elseif (desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail")) and desc.Enabled then
				table.insert(emitters, desc)
			end
		end
		return parts, emitters
	end

	local function hideAll(parts, emitters)
		for _, data in parts do
			if data.part and data.part.Parent then data.part.Transparency = 1 end
		end
		for _, e in emitters do
			if e and e.Parent then e.Enabled = false end
		end
	end

	local function showAll(parts, emitters)
		for _, data in parts do
			if data.part and data.part.Parent then data.part.Transparency = data.orig end
		end
		for _, e in emitters do
			if e and e.Parent then e.Enabled = true end
		end
	end

	local function doFlicker(parts, duration, rate)
		local interval = 1 / rate
		local elapsed = 0
		local on = false
		while elapsed < duration do
			on = not on
			for _, data in parts do
				if data.part and data.part.Parent then
					data.part.Transparency = on and math.min(data.orig + 0.5, 0.9) or data.orig
				end
			end
			task.wait(interval)
			elapsed += interval
		end
	end

	-- Helper: emit Teleport VFX at a world position (feet level)
	local function emitTeleportAt(pos)
		local teleportTemplate = ReplicatedStorage:FindFirstChild("Assets")
			and ReplicatedStorage.Assets:FindFirstChild("VFX")
			and ReplicatedStorage.Assets.VFX:FindFirstChild("Focus")
			and ReplicatedStorage.Assets.VFX.Focus:FindFirstChild("Teleport")
		if not teleportTemplate then return end
		local clone = teleportTemplate:Clone()
		local feetPos = pos + Vector3.new(0, -3, 0)
		if clone:IsA("BasePart") then
			clone.CFrame = CFrame.new(feetPos)
			clone.Anchored = true
		elseif clone:IsA("Model") then
			clone:PivotTo(CFrame.new(feetPos))
		end
		clone.Parent = workspace.World and workspace.World.Visuals or workspace
		for _, emitter in clone:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter:Emit(emitter:GetAttribute("EmitCount") or 10)
			end
		end
		Debris:AddItem(clone, 3)
	end

	-- MINI MODE: Forward/Back = teleport, Left/Right = enhanced invisible dash
	if isMiniMode and (Direction == "Forward" or Direction == "Back") then
		-- TELEPORT DASH
		Client.Packets.Dodge.send(self.DirectionToEnum[Direction])

		local teleportDistance = Speed * Duration * 0.7
		local startPos = Client.Root.Position
		local endPos = startPos + direction * teleportDistance

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { Client.Character }
		local rayResult = workspace:Raycast(startPos, direction * teleportDistance, rayParams)
		if rayResult then
			endPos = rayResult.Position - direction * 2
		end

		local flickerParts, hiddenEmitters = collectVisuals()

		-- Pre-teleport flicker
		doFlicker(flickerParts, 0.15, 30)
		hideAll(flickerParts, hiddenEmitters)

		-- Spawn teleport VFX at start (feet)
		local TeleportVFX = ReplicatedStorage:FindFirstChild("Assets")
			and ReplicatedStorage.Assets:FindFirstChild("VFX")
			and ReplicatedStorage.Assets.VFX:FindFirstChild("Focus")
			and ReplicatedStorage.Assets.VFX.Focus:FindFirstChild("Teleport")
		local feetOffset = Vector3.new(0, -3, 0)
		if TeleportVFX then
			local startVFX = TeleportVFX:Clone()
			local startFeetPos = startPos + feetOffset
			if startVFX:IsA("BasePart") then
				startVFX.CFrame = CFrame.new(startFeetPos)
				startVFX.Anchored = true
			elseif startVFX:IsA("Model") then
				startVFX:PivotTo(CFrame.new(startFeetPos))
			end
			startVFX.Parent = workspace.World and workspace.World.Visuals or workspace
			for _, emitter in startVFX:GetDescendants() do
				if emitter:IsA("ParticleEmitter") then
					emitter:Emit(emitter:GetAttribute("EmitCount") or 10)
				end
			end
			task.delay(2, function() startVFX:Destroy() end)
		end

		-- Warp
		Client.Root.CFrame = CFrame.new(endPos) * Client.Root.CFrame.Rotation

		-- Spawn teleport VFX at end (feet)
		if TeleportVFX then
			local endVFX = TeleportVFX:Clone()
			local endFeetPos = endPos + feetOffset
			if endVFX:IsA("BasePart") then
				endVFX.CFrame = CFrame.new(endFeetPos)
				endVFX.Anchored = true
			elseif endVFX:IsA("Model") then
				endVFX:PivotTo(CFrame.new(endFeetPos))
			end
			endVFX.Parent = workspace.World and workspace.World.Visuals or workspace
			for _, emitter in endVFX:GetDescendants() do
				if emitter:IsA("ParticleEmitter") then
					emitter:Emit(emitter:GetAttribute("EmitCount") or 10)
				end
			end
			task.delay(2, function() endVFX:Destroy() end)
		end

		-- Re-show + brief arrival flicker
		showAll(flickerParts, hiddenEmitters)
		doFlicker(flickerParts, 0.1, 30)
		showAll(flickerParts, hiddenEmitters)

		Client.Dodging = false
		Client.DashDirection = nil
		Client.CancelDashFn = nil
		StateManager.RemoveState(Client.Character, "Status", "Dodging")

		if wasRunning and Client.Character and Client.Character.Parent and not StateManager.StateCount(Client.Character, "Stuns") then
			Client.Running = true
			Client._Running = true
			StateManager.AddState(Client.Character, "Speeds", "RunSpeedSet30")
			local Equipped = Client.Character:GetAttribute("Equipped")
			if Equipped then
				Client.RunAnim = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Movement.WeaponRun)
			else
				Client.RunAnim = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Movement.Run)
			end
			if Client.RunAnim then
				Client.RunAnim.Priority = Enum.AnimationPriority.Action
			end
		end

		return -- Skip normal velocity-based dash
	end

	-- MINI MODE SIDE DASH: enhanced invisible velocity dash with Pop VFX
	local miniSideDash = isMiniMode and (Direction == "Left" or Direction == "Right")
	if miniSideDash then
		Speed = 55
		Duration = 0.6
	end

	local Velocity = Instance.new("LinearVelocity")
	Velocity.MaxAxesForce = Vector3.new(100000, 0, 100000)
	Velocity.ForceLimitsEnabled = true
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.Attachment0 = Client.Root.RootAttachment
	Velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	Velocity.VectorVelocity = direction * Speed
	Velocity.Name = "Dodge"
	Velocity.Parent = Client.Root

	local AlignOrient = Instance.new("AlignOrientation")
	AlignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	AlignOrient.Attachment0 = Client.Root.RootAttachment
	AlignOrient.RigidityEnabled = false
	AlignOrient.Responsiveness = 30
	AlignOrient.Enabled = false
	AlignOrient.Name = "DodgeAlign"
	AlignOrient.Parent = Client.Root

	Client.Packets.Dodge.send(self.DirectionToEnum[Direction])

	local dashCancelled = false

	-- Cancel dash function (called by stun detection, M1, or M2 cancel)
	local function cancelDash()
		if dashCancelled then return end
		dashCancelled = true
	end

	-- Expose cancel function so Attack/Critical inputs can call it
	Client.CancelDashFn = cancelDash

	-- Mini side dash: hide character and emit Teleport VFX at start
	local sideDashParts, sideDashEmitters
	if miniSideDash then
		sideDashParts, sideDashEmitters = collectVisuals()
		hideAll(sideDashParts, sideDashEmitters)
		emitTeleportAt(Client.Root.Position)
	end

	-- Dash velocity loop in a spawned thread (like reference updateDashVelocity)
	task.spawn(function()
		local start = os.clock()
		local fullSpeedPhase = Duration * 0.7
		local falloffPhase = Duration * 0.3

		while os.clock() - start <= Duration do
			if dashCancelled then break end

			-- Character validity check
			if not Client.Character or not Client.Character.Parent then break end

			-- Stun detection
			local allStuns = StateManager.GetAllStates(Client.Character, "Stuns")
			for _, stunName in ipairs(allStuns) do
				if stunName ~= "Dashing" then
					dashCancelled = true
					break
				end
			end
			if dashCancelled then break end

			local elapsed = os.clock() - start
			local speed
			if elapsed <= fullSpeedPhase then
				speed = Speed
			else
				-- Unlock actions as soon as full-speed phase ends
				if Client.Dodging then
					Client.Dodging = false
					Client.DashDirection = nil
					Client.CancelDashFn = nil
					StateManager.RemoveState(Client.Character, "Status", "Dodging")
				end
				-- Ease-out falloff: power drops off smoothly in the later half
				local falloffT = (elapsed - fullSpeedPhase) / falloffPhase
				speed = Speed * (1 - falloffT) ^ 3.5
			end

			-- Update direction from player input (allows steering mid-dash)
			if Client.Humanoid.MoveDirection.Magnitude > 0 then
				direction = Client.Humanoid.MoveDirection
				AlignOrient.Enabled = false
			else
				-- No input: face camera forward and keep dashing that way
				local camLook = camera.CFrame.LookVector
				local pos = Vector3.new(camLook.X, 0, camLook.Z)
				if pos.Magnitude > 0 then
					pos = pos.Unit
					AlignOrient.Enabled = true
					AlignOrient.CFrame = CFrame.lookAt(Client.Root.Position, Client.Root.Position + pos)
					direction = pos
				end
			end

			if direction.Magnitude > 0 then
				Velocity.VectorVelocity = direction * speed
			else
				Velocity.VectorVelocity = Velocity.VectorVelocity.Unit * speed
			end

			task.wait()
		end

		-- Cleanup velocity and align
		AlignOrient:Destroy()
		Velocity:Destroy()

		-- Mini side dash: show character and emit Teleport VFX at end
		if miniSideDash then
			emitTeleportAt(Client.Root.Position)
			showAll(sideDashParts, sideDashEmitters)
		end

		-- Clean up dash state (may already be cleared by early unlock)
		Client.Dodging = false
		Client.DashDirection = nil
		Client.CancelDashFn = nil
		StateManager.RemoveState(Client.Character, "Status", "Dodging")

		-- Stop animation if still playing and was cancelled
		if dashCancelled and Animation and Animation.IsPlaying then
			Animation:Stop()
		end

		-- Resume running if player was running before dash and isn't stunned
		if wasRunning and not dashCancelled then
			if Client.Character and Client.Character.Parent and not StateManager.StateCount(Client.Character, "Stuns") then
				Client.Running = true
				Client._Running = true
				StateManager.AddState(Client.Character, "Speeds", "RunSpeedSet30")

				local Equipped = Client.Character:GetAttribute("Equipped")
				if Equipped then
					Client.RunAnim = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Movement.WeaponRun)
				else
					Client.RunAnim = Client.Library.PlayAnimation(Client.Character, Client.Service["ReplicatedStorage"].Assets.Animations.Movement.Run)
				end

				if Client.RunAnim then
					Client.RunAnim.Priority = Enum.AnimationPriority.Action
				end
			end
		end
	end)
end

-- Exposed cancel functions for input modules
Movement.CancelDash = function()
	if Client.CancelDashFn then
		Client.CancelDashFn()
	end
end

local ROLL_CANCEL_COOLDOWN = 3.5
local lastRollCancelTime = 0

Movement.CancelDashWithAnimation = function(cancelAnimName)
	if not Client.CancelDashFn then return end

	-- Enforce cooldown between roll cancels
	if os.clock() - lastRollCancelTime < ROLL_CANCEL_COOLDOWN then return end
	lastRollCancelTime = os.clock()

	Client.CancelDashFn()

	-- Play the cancel animation
	local anim = Client.Service["ReplicatedStorage"].Assets.Animations.Dashes[cancelAnimName]
	if anim then
		Client.Library.PlayAnimation(Client.Character, anim)
	end

	-- Tell server about the cancel
	Client.Packets.DodgeCancel.send()
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
