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

	local range = 8
	self.Directions = {
		Left = -range,
		Right = range
	}

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
	BP.MaxForce = Vector3.one * 2e9
	BP.Position = Ray.Position + Ray.Normal * 1.5
	BP.P = 99999
	BP.Parent = RootPart
	self.Cleaner:AddTask(BP)

	local BG = Instance.new('BodyGyro')
	BG.MaxTorque = Vector3.one * 2e9
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

		elapsed += dt
	end)
end

function Sliding:End()
end

return Sliding