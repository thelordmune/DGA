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

	local range = 8
	self.Directions = {
		Left = -range,
		Right = range
	}

	-- Listen for space bar to perform camera-based air dash after wall jump
	UIS.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then return end

		if input.KeyCode == Enum.KeyCode.Space then
			self:TryAirDash()
		end
	end)

	return self
end

function Sliding:_stopWallrunning()
	local Character: Model = self.Character
	local RootPart: BasePart = Character.HumanoidRootPart
	local Humanoid: Humanoid = Character.Humanoid
	local AnimationService = self.Parent.AnimationService

	self.Cleaner:Destroy()
	Humanoid.AutoRotate = true

	AnimationService:Stop('Wall Run Right')
	AnimationService:Stop('Wall Run Left')

	RootPart.AssemblyLinearVelocity = Vector3.zero

	-- Stop wall run dust particles
	Base.StopWallRunDust(Character)

	self.Parent.Busy = false
end

function Sliding:Start()
	if self.Parent.Busy and not self.Cleaner.WallRunning then
		return
	end

	local Character: Model = self.Character
	local RootPart: BasePart = Character.HumanoidRootPart
	local Humanoid: Humanoid = Character.Humanoid
	local AnimationService = self.Parent.AnimationService

	if self.Cleaner.WallRunning then
		self:_stopWallrunning()

		local Inverse = {
			Right = 'Left',
			Left = 'Right'
		}

		RootPart.AssemblyLinearVelocity = (self.CrossVector + self.Normal + Vector3.yAxis) * 50
		AnimationService:Play('Wall Jump Run '.. Inverse[self.Side])

		-- Mark that we just wall jumped to enable air dash
		self.JustWallJumped = true
		self.WallJumpTime = os.clock()

		-- Reset the flag after a short window
		task.delay(1.5, function()
			self.JustWallJumped = false
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

function Sliding:TryAirDash()
	local Character: Model = self.Character
	local RootPart: BasePart = Character.HumanoidRootPart
	local Humanoid: Humanoid = Character.Humanoid

	-- Check if we can air dash (just wall jumped and in air)
	if not self.JustWallJumped then
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

	-- Reset the wall jump flag so we can only dash once per wall jump
	self.JustWallJumped = false

	print("Air dashing in camera direction:", dashDirection)
end

return Sliding