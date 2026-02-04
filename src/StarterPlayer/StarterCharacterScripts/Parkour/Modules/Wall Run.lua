-- // services
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UIS = game:GetService('UserInputService')

-- // variables
local Utils = script.Parent.Parent.Util
local Camera = workspace.CurrentCamera

-- // requires
local Maid = require(Utils.Maid)
local Raycast = require(Utils.Raycast)
local Base = require(ReplicatedStorage.Effects.Base)
local Client = require(ReplicatedStorage.Client)

local Sliding = {}
Sliding.__index = Sliding

function Sliding.new(Parkour)
	local self = setmetatable({}, Sliding)
	self.Parent = Parkour
	self.Cleaner = Maid.new()

	self.Character = self.Parent.Character
	self.RunSpeed = 25
	self.WallRunDuration = 3
	self.Side = nil
	self.JustWallJumped = false
	self.WallJumpTime = 0
	self.AirDashUsed = false -- Track if air dash was used after wall jump

	local range = 8
	self.Directions = {
		Left = -range,
		Right = range
	}

	-- Listen for space bar to perform camera-based air dash after wall jump
	-- Store connection for cleanup to prevent memory leak
	self.InputConnection = UIS.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then return end

		if input.KeyCode == Enum.KeyCode.Space then
			self:TryAirDash()
		end
	end)

	return self
end

function Sliding:_stopWallrunning(keepAutoRotateOff)
	local Character: Model = self.Character
	local RootPart: BasePart = Character.HumanoidRootPart
	local Humanoid: Humanoid = Character.Humanoid
	local AnimationService = self.Parent.AnimationService

	self.Cleaner:Destroy()

	-- Only reset AutoRotate if we're not doing a wall jump
	if not keepAutoRotateOff then
		Humanoid.AutoRotate = true
	end

	AnimationService:Stop('Wall Run Right')
	AnimationService:Stop('Wall Run Left')

	-- Only zero velocity if we're not doing a wall jump
	if not keepAutoRotateOff then
		RootPart.AssemblyLinearVelocity = Vector3.zero
	end

	-- Stop wall run dust particles
	Base.StopWallRunDust(Character)

	Client.WallRunning = false -- Clear Client state
	self.Parent.Busy = false
end

function Sliding:Start()
	print("[WallRun] Start() called")
	print("[WallRun] Busy:", self.Parent.Busy, "WallRunning:", self.Cleaner.WallRunning ~= nil)

	if self.Parent.Busy and not self.Cleaner.WallRunning then
		print("[WallRun] Blocked - Busy and not wall running")
		return
	end

	local Character: Model = self.Character
	local RootPart: BasePart = Character.HumanoidRootPart
	local Humanoid: Humanoid = Character.Humanoid
	local AnimationService = self.Parent.AnimationService

	if self.Cleaner.WallRunning then
		print("[WallRun] WALL JUMP TRIGGERED!")
		-- Store wall jump data BEFORE stopping wall run
		local wallJumpSide = self.Side

		local Inverse = {
			Right = 'Left',
			Left = 'Right'
		}

		-- Stop wall running but keep AutoRotate off and don't zero velocity
		self:_stopWallrunning(true)

		-- Keep AutoRotate off during the jump
		Humanoid.AutoRotate = false

		-- Calculate wall jump direction with much stronger forces
		-- Don't normalize - we want the full magnitude
		local upwardForce = Vector3.new(0, 80, 0) -- Very strong upward
		local outwardForce = self.Normal * 50 -- Push hard away from wall
		local forwardForce = self.CrossVector * 30 -- Some forward momentum

		local wallJumpVelocity = upwardForce + outwardForce + forwardForce

		print(`[WallRun] Jump velocity: {wallJumpVelocity}`)

		-- Apply wall jump velocity
		RootPart.AssemblyLinearVelocity = wallJumpVelocity

		-- Wait a frame and reapply to prevent it being overridden
		task.wait()
		RootPart.AssemblyLinearVelocity = wallJumpVelocity

		print(`[WallRun] Final velocity applied: {RootPart.AssemblyLinearVelocity}`)

		-- Play wall jump animation
		AnimationService:Play('Wall Jump Run '.. Inverse[wallJumpSide], 1.5)

		-- Mark that we just wall jumped to enable air dash
		self.JustWallJumped = true
		self.WallJumpTime = os.clock()
		self.AirDashUsed = false -- Reset air dash availability

		-- Re-enable AutoRotate and reset flags after jump completes
		task.delay(1.5, function()
			Humanoid.AutoRotate = true
			self.JustWallJumped = false
			self.AirDashUsed = false
		end)

		self.Side = nil
		return
	end

	if Humanoid.FloorMaterial ~= Enum.Material.Air then
		return
	end

	local ghostPart = Instance.new('Part')
	ghostPart.CFrame = RootPart.CFrame
	self.Cleaner:AddTask(ghostPart)

	local function getCross(dt)
		local Side
		local ray : RaycastResult

		for Direction, Velocity in self.Directions do
			ray = Raycast({
				Start = ghostPart.Position + ghostPart.CFrame.LookVector * (dt and dt * self.RunSpeed or 1),
				Direction = ghostPart.CFrame.RightVector * Velocity,
				Params = self.Parent.Params,
				Ignore = {self.Character}
			})

			if ray then
				Side = Direction
				break
			end
		end

		if not Side then
			return
		end

		local CrossVector = ray.Normal:Cross(Vector3.yAxis) * (Side == 'Left' and -1 or 1)
		return CrossVector, ray, Side
	end

	local CrossVector, Ray, Side = getCross()
	if not CrossVector then
		return
	end

	self.Side = Side
	self.CrossVector = CrossVector
	self.Normal = Ray.Normal

	local BP = Instance.new('BodyPosition')
	BP.MaxForce = Vector3.one * 100000  -- Reduced from 2e9 to prevent teleporting
	BP.Position = Ray.Position + Ray.Normal * 1.5
	BP.P = 50000  -- Reduced from 99999 for smoother movement
	BP.Parent = RootPart
	self.Cleaner:AddTask(BP)

	local BG = Instance.new('BodyGyro')
	BG.MaxTorque = Vector3.one * 100000  -- Reduced from 2e9 to prevent snapping
	BG.CFrame = CFrame.new(Vector3.zero, CrossVector)
	BG.P = 2500
	BG.Parent = RootPart
	self.Cleaner:AddTask(BG)

	ghostPart.CFrame = BG.CFrame + BP.Position
	Humanoid.AutoRotate = false

	AnimationService:Play('Wall Run '.. Side)

	local elapsed = 0
	self.Parent.Busy = true
	Client.WallRunning = true -- Set Client state

	self.Cleaner.WallRunning = RunService.Heartbeat:Connect(function(dt)
		local ForwardDetection = Raycast({
			Start = RootPart.Position,
			Direction = RootPart.CFrame.LookVector,
			Params = self.Parent.Params,
			Ignore = {self.Character}
		})

		local CrossVector, Raycast = getCross(dt)

		if not CrossVector then
			self:_stopWallrunning()
			self.Side = nil
			return
		end

		if elapsed >= self.WallRunDuration or Humanoid.FloorMaterial ~= Enum.Material.Air then
			self:_stopWallrunning()
			self.Side = nil
			return
		end

		if ForwardDetection and ForwardDetection.Distance < 1 then
			self:_stopWallrunning()
			self.Side = nil
			return
		end

		local verticalOffset = (2 - elapsed) * dt
		BP.Position = Raycast.Position + Raycast.Normal * 1.5 + Vector3.yAxis * verticalOffset
		BG.CFrame = CFrame.new(Vector3.zero, CrossVector)
		ghostPart.CFrame = BG.CFrame + BP.Position

		-- Update wall run dust particles
		local wallColor = Raycast.Instance.Color or Color3.fromRGB(150, 150, 150)
		Base.WallRunDust(Character, Raycast.Position, Raycast.Normal, wallColor)

		elapsed += dt
	end)
end

function Sliding:End()
end

function Sliding:Destroy()
	-- Cleanup InputConnection to prevent memory leak
	if self.InputConnection then
		self.InputConnection:Disconnect()
		self.InputConnection = nil
	end

	-- Also cleanup any active wall running
	self.Cleaner:Destroy()
end

function Sliding:TryAirDash()
	local Character: Model = self.Character
	local RootPart: BasePart = Character.HumanoidRootPart
	local Humanoid: Humanoid = Character.Humanoid

	-- Check if we can air dash (just wall jumped and in air, and haven't used it yet)
	if not self.JustWallJumped or self.AirDashUsed then
		return
	end

	if Humanoid.FloorMaterial ~= Enum.Material.Air then
		return
	end

	-- Get camera direction (full 3D, including up/down)
	local Camera = workspace.CurrentCamera
	local cameraLookVector = Camera.CFrame.LookVector

	-- Use the full camera look vector for true directional dashing
	local dashDirection = cameraLookVector.Unit

	-- Apply velocity in camera direction
	local dashSpeed = 70
	local dashVelocity = dashDirection * dashSpeed

	RootPart.AssemblyLinearVelocity = dashVelocity

	-- Play forward dash animation (WDash)
	local ReplicatedStorage = game:GetService('ReplicatedStorage')
	local Library = require(ReplicatedStorage.Modules.Library)
	Library.PlayAnimation(Character, ReplicatedStorage.Assets.Animations.Dashes.Forward)

	-- Mark air dash as used so we can only dash once per wall jump
	self.AirDashUsed = true

	-- Set air dash flag to prevent landing animation
	Client.AirDashing = true
	Client.AirDashLanding = true

	-- Clear the air dash landing flag after a short delay
	-- This prevents the landing animation from playing
	task.delay(0.5, function()
		Client.AirDashing = false
		-- Keep AirDashLanding flag for a bit longer to ensure landing animation doesn't play
		task.delay(0.3, function()
			Client.AirDashLanding = false
		end)
	end)

	---- print("Air dashing in camera direction:", dashDirection)
end

return Sliding