local AnimationController = {}
local Client = require(script.Parent)
local ClientConfig = require(script.Parent.ClientConfig)
AnimationController.__index = AnimationController
local self = setmetatable({}, AnimationController)
local Defaults = require(script.Cache)

AnimationController.LastCall = 0
AnimationController.FrameCount = 0

AnimationController.CurrentAnimation = ""
AnimationController.CurrentTrack = nil
AnimationController.CurrentInstance = nil
AnimationController.CurrentSpeed = 1.0
AnimationController.Connections = {}

AnimationController.FreeFallTime = 0
AnimationController.JumpAnimTime = 0
AnimationController.JumpAnimDuration = ClientConfig.Animation.JUMP_ANIM_DURATION
AnimationController.FallTransitionTime = ClientConfig.Animation.FALL_TRANSITION_TIME

AnimationController.KillCache = {
	"Dead",
	"GettingUp",
	"FallingDown",
	"Seated",
	"PlatformStanding",
}

AnimationController.Cache = {}
AnimationController.Pose = "Standing"
AnimationController.Listeners = {}
AnimationController.InitConnections = {} -- Connections created during Init (cleaned up on re-init)

local Methods = {}
local function Disconnect(Table)
	for _, Connection: RBXScriptConnection in next, Table do
		Connection:Disconnect()
	end
end

AnimationController.AddToConfig = function(Name, Weight, ID)
    if self.Cache[Name] then
        -- If this is the currently playing animation, stop it first
        if self.CurrentAnimation == Name and self.CurrentTrack then
            self.CurrentTrack:Stop(0.1)
            self.CurrentTrack:Destroy()
            self.CurrentTrack = nil
            self.CurrentAnimation = ""
            self.CurrentInstance = nil
        end

        if self.Cache[Name].Animation then
            self.Cache[Name].Animation:Destroy()
        end

        Disconnect(self.Cache[Name].Connections)
        self.Cache[Name].Connections = {}

        self.Cache[Name].Animation = Instance.new("Animation")
        self.Cache[Name].Animation.Name = Name
        self.Cache[Name].Animation.AnimationId = ("rbxassetid://%d"):format(ID)
        self.Cache[Name].Weight = Weight

        -- If we just updated the idle animation and we should be idling, restart it
        if Name == "Idling" and self.Pose == "Standing" then
            task.wait(0.1) -- Small delay to ensure the new animation is ready
            self.PlayAnimation("Idling", 0.1)
        end
    end
end

AnimationController.SetupConfig = function(Name, Data)
	self.Cache[Name] = {}
	self.Cache[Name].Connections = {}

	self.Cache[Name].Animation = Instance.new("Animation")
	self.Cache[Name].Animation.Name = Name
	self.Cache[Name].Animation.AnimationId = ("rbxassetid://%d"):format(Data.ID)
	self.Cache[Name].Weight = Data.Weight
end

AnimationController.ResetConfig = function(Name)
	if self.Cache[Name] ~= nil then
		Disconnect(self.Cache[Name].Connections)
		if self.Cache[Name].Animation then
			self.Cache[Name].Animation:Destroy()
		end

		self.SetupConfig(Name, Defaults[Name])
	end
end

AnimationController.StopAllAnimations = function()
	local OldAnim = self.CurrentAnimation

	self.CurrentAnimation = ""
	self.CurrentInstance = nil

	if self.Connections and #self.Connections > 0 then
		for _, Connection: RBXScriptConnection in next, self.Connections do
			Connection:Disconnect()
		end

		self.Connections = {}
	end

	if self.CurrentLeft ~= nil then
		self.CurrentLeft:Disconnect()
		self.CurrentLeft = nil
	end
	if self.CurrentRight ~= nil then
		self.CurrentRight:Disconnect()
		self.CurrentRight = nil
	end

	if self.CurrentTrack ~= nil then
		self.CurrentTrack:Stop()
		self.CurrentTrack:Destroy()
		self.CurrentTrack = nil
	end

	-- Also cleanup any raw animation tracks
	for _, track in pairs(self.RawTracks) do
		if track then
			track:Stop(0.1)
			track:Destroy()
		end
	end
	self.RawTracks = {}

	return OldAnim
end

AnimationController.SetAnimationSpeed = function(Speed: number)
	if Speed ~= self.CurrentSpeed then
		self.CurrentSpeed = Speed
		self.CurrentTrack:AdjustSpeed(self.CurrentSpeed)
	end
end

AnimationController.CurrentLeft = nil
AnimationController.CurrentRight = nil
AnimationController.RawTracks = {} -- Track raw animation tracks for cleanup

AnimationController.PlayAnimation = function(Animation, Transition)
    local Anim = self.Cache[Animation].Animation
    local Weight = self.Cache[Animation].Weight

    if Anim ~= self.CurrentInstance then
        self.CurrentSpeed = 1.0

        -- Always stop and destroy the current track when switching animations
        if self.CurrentTrack ~= nil then
            self.CurrentTrack:Stop(Transition)
            self.CurrentTrack:Destroy()
            self.CurrentTrack = nil
        end

        -- Clear current animation state
        self.CurrentAnimation = ""
        self.CurrentInstance = nil

        ---- print(Anim.Name)

        if typeof(Anim) == "table" then
            ---- print(table.unpack(Anim))
        end

        self.CurrentTrack = Client.Humanoid:LoadAnimation(Anim)
        self.CurrentTrack.Priority = Enum.AnimationPriority.Core
        self.CurrentTrack:Play(Transition)

        self.CurrentAnimation = Animation
        self.CurrentInstance = Anim

        -- Clear existing connections
        if self.CurrentLeft ~= nil then
            self.CurrentLeft:Disconnect()
            self.CurrentLeft = nil
        end
        if self.CurrentRight ~= nil then
            self.CurrentRight:Disconnect()
            self.CurrentRight = nil
        end

        -- Set up walking sound connections
        if Animation == "Walking" then
            self.CurrentLeft = self.CurrentTrack:GetMarkerReachedSignal("Left"):Connect(function()
                if
                    Client.InAir
                    or Client.Dashing
                    or not Client.Humanoid
                    or Client.Character:GetAttribute("Ragdolled")
                then
                    return
                end
                Client.Modules["Sounds"].Step(Client.Humanoid.FloorMaterial)
            end)

            self.CurrentRight = self.CurrentTrack:GetMarkerReachedSignal("Right"):Connect(function()
                if
                    Client.InAir
                    or Client.Dashing
                    or not Client.Humanoid
                    or Client.Character:GetAttribute("Ragdolled")
                then
                    return
                end
                Client.Modules["Sounds"].Step(Client.Humanoid.FloorMaterial)
            end)
        end
    end
end

AnimationController.PlayRawAnimation = function(Animation, Transition, Priority)
	local Anim = self.Cache[Animation].Animation

	if Anim ~= self.CurrentInstance then
		-- Stop and destroy any existing raw track for this animation
		if self.RawTracks[Animation] then
			self.RawTracks[Animation]:Stop(0.1)
			self.RawTracks[Animation]:Destroy()
			self.RawTracks[Animation] = nil
		end

		local Track = Client.Humanoid:LoadAnimation(Anim)
		Track.Priority = Priority
		Track:Play(Transition)

		-- Store track for cleanup
		self.RawTracks[Animation] = Track

		-- Auto-cleanup when track stops
		Track.Stopped:Once(function()
			if self.RawTracks[Animation] == Track then
				Track:Destroy()
				self.RawTracks[Animation] = nil
			end
		end)

		return Track
	end
	return nil
end

AnimationController.Listeners["Move"] = function()
	local Speed = Client.Humanoid.MoveDirection.Magnitude

	-- Don't play walking animations during parkour actions
	-- NOTE: Removed Client.InAir check here - the Humanoid.Running event already knows if we're grounded
	-- The InAir raycast cache (10Hz) was causing stale state issues where animations wouldn't update
	if Client.WallRunning or Client.LedgeClimbing or Client.Leaping then
		return
	end

	-- Also skip if humanoid is in freefall or jumping state (more reliable than Client.InAir)
	local state = Client.Humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		return
	end

	if Speed > 0 then
		self.PlayAnimation("Walking", 0.1)
		self.Pose = "Running"
	else
		self.PlayAnimation("Idling", 0.1)
		self.Pose = "Standing"
	end
end

AnimationController.Listeners["Died"] = function()
	self.Pose = "Dead"
end

AnimationController.Listeners["Jumping"] = function()
	self.PlayAnimation("Jumping", 0.1)
	self.JumpAnimTime = self.JumpAnimDuration
	self.Pose = "Jumping"
end

AnimationController.Listeners["Freefall"] = function()
	-- Don't track freefall time during leap or air dash (prevents landing animation)
	if not Client.Leaping and not Client.AirDashing then
		self.FreeFallTime = os.clock()
	end
	self.Pose = "FreeFall"

	if self.JumpAnimTime <= 0 then
		self.PlayAnimation("Falling", self.FallTransitionTime)
	end
end

AnimationController.Listeners["Swimming"] = function()
	local Speed = Client.Humanoid.MoveDirection.Magnitude

	if Speed > 0 then
		self.Pose = "Running"
	else
		self.Pose = "Standing"
	end
end

AnimationController.Listeners["Landed"] = function()
	-- Don't play landing animation if we're leaping, air dashing, or just finished either
	if Client.Leaping or Client.LeapLanding or Client.AirDashing or Client.AirDashLanding then
		self.FreeFallTime = 0
		return
	end

	if self.FreeFallTime ~= 0 and (os.clock() - self.FreeFallTime >= 1) then
		self.PlayRawAnimation("Landing", 0.1, Enum.AnimationPriority.Idle)
		self.Pose = "Landing"
		self.FreeFallTime = 0

		-- Add forward momentum during landing roll
		local Character = Client.Character
		if Character and Character:FindFirstChild("HumanoidRootPart") then
			local RootPart = Character.HumanoidRootPart
			local forwardDirection = RootPart.CFrame.LookVector
			-- Apply forward velocity during the roll (20 studs/s forward)
			RootPart.AssemblyLinearVelocity = Vector3.new(
				forwardDirection.X * 20,
				RootPart.AssemblyLinearVelocity.Y, -- Preserve vertical velocity
				forwardDirection.Z * 20
			)
		end

		-- Automatically transition out of landing pose after animation completes
		-- Landing animation is typically ~0.5 seconds
		task.delay(0.6, function()
			if self.Pose == "Landing" then
				self.Pose = "Standing"
				self.PlayAnimation("Idling", 0.1)
			end
		end)
	end
end

AnimationController.Listeners["GettingUp"] = function()
	self.Pose = "GettingUp"
end

AnimationController.Listeners["PlatformStanding"] = function()
	self.Pose = "PlatformStanding"
end

AnimationController.Listeners["FallingDown"] = function()
	self.Pose = "FallingDown"
end

AnimationController.Listeners["Seated"] = function()
	self.Pose = "Seated"
end

AnimationController.Init = function()
	-- CRITICAL: Clean up old connections from previous Init to prevent memory leaks
	for _, conn in ipairs(self.InitConnections) do
		if typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end
	self.InitConnections = {}

	for Name, Table in next, Defaults do
		task.spawn(self.SetupConfig, Name, Table)
	end
	for _, Track: AnimationTrack in next, Client.Animator:GetPlayingAnimationTracks() do
		Track:Stop(0)
		Track:Destroy()
	end

	self.PlayAnimation("Idling", 0.1)
	self.Pose = "Standing"
	self.FrameCount = 0

	table.insert(self.InitConnections, Client.Humanoid.Running:Connect(self.Listeners["Move"]))
	table.insert(self.InitConnections, Client.Humanoid.StateChanged:Connect(function(_, State: Enum.HumanoidStateType)
		if not Client.Character or not Client.Humanoid then
			return
		end
		if AnimationController.Listeners[State.Name] then
			AnimationController.Listeners[State.Name]()
		end
	end))

	table.insert(self.InitConnections, Client.Character:GetAttributeChangedSignal("Equipped"):Connect(function()
		if not Client.Character then
			return
		end
		if Client.Character:GetAttribute("Equipped") then
			local Fetch = Client.MetaData.RequestData(Client.Weapon)
			-- Check if weapon has separate equipped idle animation
			if Fetch.EquippedIdle then
				self.AddToConfig("Idling", 10, Fetch.EquippedIdle)
			else
				self.AddToConfig("Idling", 10, Fetch.Idle)
			end
		else
			local Fetch = Client.MetaData.RequestData(Client.Weapon)
			-- Check if weapon has separate unequipped idle animation
			if Fetch.UnequippedIdle then
				self.AddToConfig("Idling", 10, Fetch.UnequippedIdle)
			else
				self.AddToConfig("Idling", 10, Fetch.Idle)
			end
		end
	end))

	Client.Utilities:AddToTempLoop(function(DeltaTime)
		if not Client.Character or not Client.Humanoid then
			return true
		end
		self.FrameCount += DeltaTime

		if self.FrameCount >= 1 / 60 then
			local Amplitude = 1
			local Frequency = 1

			if self.JumpAnimTime > 0 then
				self.JumpAnimTime -= 1 / 60
			end

			if self.Pose == "FreeFall" and self.JumpAnimTime <= 0 then
				-- BUGFIX: Check if humanoid is actually in freefall - prevents stuck falling animation
				local state = Client.Humanoid:GetState()
				if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
					self.PlayAnimation("Falling", self.FallTransitionTime)
				else
					-- Not actually falling - recover to correct pose
					local moveSpeed = Client.Humanoid.MoveDirection.Magnitude
					if moveSpeed > 0 then
						self.Pose = "Running"
						self.PlayAnimation("Walking", 0.1)
					else
						self.Pose = "Standing"
						self.PlayAnimation("Idling", 0.1)
					end
				end
			elseif self.Pose == "Running" then
				-- BUGFIX: Verify we're actually moving, fix pose drift
				local moveSpeed = Client.Humanoid.MoveDirection.Magnitude
				if moveSpeed > 0 then
					self.PlayAnimation("Walking", 0.1)
				else
					self.Pose = "Standing"
					self.PlayAnimation("Idling", 0.1)
				end
			elseif self.Pose == "Standing" then
				-- BUGFIX: Verify we're actually standing still, fix pose drift
				local moveSpeed = Client.Humanoid.MoveDirection.Magnitude
				local state = Client.Humanoid:GetState()
				if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
					-- Actually in air, update pose
					self.Pose = "FreeFall"
				elseif moveSpeed > 0 then
					self.Pose = "Running"
					self.PlayAnimation("Walking", 0.1)
				else
					self.PlayAnimation("Idling", 0.1)
				end
			elseif self.Pose == "Landing" then
				-- Landing pose should transition to idle/walking based on movement
				-- This handles cases where the task.delay doesn't fire
				local moveSpeed = Client.Humanoid.MoveDirection.Magnitude
				if moveSpeed > 0 then
					self.Pose = "Running"
					self.PlayAnimation("Walking", 0.1)
				else
					self.Pose = "Standing"
					self.PlayAnimation("Idling", 0.1)
				end
			elseif table.find(self.KillCache, self.Pose) then
				self.StopAllAnimations()
				Amplitude = 0.1
				Frequency = 1

				local Angle = Amplitude * math.sin(DeltaTime * Frequency)
				Client.Character.Torso["Right Shoulder"]:SetDesiredAngle(Angle)
				Client.Character.Torso["Left Shoulder"]:SetDesiredAngle(Angle)
				Client.Character.Torso["Right Hip"]:SetDesiredAngle(-Angle)
				Client.Character.Torso["Left Hip"]:SetDesiredAngle(-Angle)
			end

			-- En sphere slowdown: reduce animation speed when EnSlowed attribute is set
			if Client.Character and Client.Character:GetAttribute("EnSlowed") then
				if self.CurrentTrack and self.CurrentTrack.IsPlaying then
					self.CurrentTrack:AdjustSpeed(0.4) -- 40% animation speed
				end
			end

			self.FrameCount -= 1 / 60
		end
	end)
end

return AnimationController
