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
local Client = require(ReplicatedStorage.Client)

local Sliding = {}
Sliding.__index = Sliding

function Sliding.new(Parkour)
	local self = setmetatable({}, Sliding)
	self.Parent = Parkour
	self.Cleaner = Maid.new()

	self.Character = self.Parent.Character
	self.SlidingDuration = 1 -- Reduced from 3 for snappier feel
	self.InitialVelocity = 30 -- Increased from 30 for better slide
	self.Sliding = false
	self.SlideEndTime = 0 -- Track when slide ended for jump buffer
	self.JumpBufferTime = 0.2 -- 200ms window to press jump after releasing slide

	-- Listen for jump input to trigger slide jump
	self.JumpConnection = UIS.InputBegan:Connect(function(input, gpe)
		if gpe then return end

		if input.KeyCode == Enum.KeyCode.Space then
			-- Check if we're sliding OR just released slide recently
			local timeSinceSlideEnd = os.clock() - self.SlideEndTime
			if self.Sliding or (timeSinceSlideEnd <= self.JumpBufferTime and timeSinceSlideEnd > 0) then
				self:SlideJump()
			end
		end
	end)

	return self
end

function Sliding:Start()
	if self.Parent.Busy then
		return
	end

	local Character: Model = self.Character
	local RootPart: BasePart = Character.HumanoidRootPart
	local Humanoid: Humanoid = Character.Humanoid

	if Humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	
	local Height = Vector3.yAxis * (RootPart.Size.Y * 0.5 + Character['Right Leg'].Size.Y)
	local groundDetection = Raycast({
		Start = RootPart.Position,
		Direction = -Height - Vector3.yAxis * 5,
		Params = self.Parent.Params
	})
	
	local Velocity = (groundDetection and groundDetection.Normal or Vector3.yAxis):Cross(RootPart.CFrame.RightVector) * self.InitialVelocity
	local AnimationService = self.Parent.AnimationService
	AnimationService:Play('Slide')

	-- Use modern LinearVelocity instead of BodyPosition
	local Attachment = RootPart:FindFirstChild("RootAttachment") or Instance.new("Attachment")
	Attachment.Name = "RootAttachment"
	Attachment.Parent = RootPart

	local LV = Instance.new('LinearVelocity')
	LV.Attachment0 = Attachment
	LV.MaxForce = math.huge
	LV.VectorVelocity = Velocity
	LV.RelativeTo = Enum.ActuatorRelativeTo.World
	LV.Parent = RootPart
	self.Cleaner:AddTask(LV)

	-- Use AlignOrientation instead of BodyGyro
	local AO = Instance.new('AlignOrientation')
	AO.Attachment0 = Attachment
	AO.Mode = Enum.OrientationAlignmentMode.OneAttachment
	AO.MaxTorque = 10000
	AO.Responsiveness = 200
	AO.CFrame = RootPart.CFrame
	AO.Parent = RootPart
	self.Cleaner:AddTask(AO)

	local SlideElapsed = 0
	local slopeTime = 0

	self.Parent.Busy = true
	self.Sliding = true
	Client.Sliding = true -- Update Client state
	Humanoid.PlatformStand = true
	
	self.Cleaner:AddTask(
		RunService.Heartbeat:Connect(function(dt)
			-- Check if slide should end
			if SlideElapsed >= self.SlidingDuration then
				self:End()
				return
			end

			groundDetection = Raycast({
				Start = RootPart.Position,
				Direction = -Height - Vector3.yAxis * 5,
				Params = self.Parent.Params
			})

			local lookVector = (groundDetection and groundDetection.Normal or Vector3.yAxis):Cross(RootPart.CFrame.RightVector)
			local slopeVelocity = Vector3.zero

			if not groundDetection then
				-- In air - reduce slide time
				SlideElapsed += dt * 2
			else
				-- On ground
				slopeVelocity = (groundDetection.Normal - Vector3.yAxis) * workspace.Gravity

				if slopeVelocity.Y ~= 0 then
					-- On slope - don't count toward slide end
					SlideElapsed = 0
					slopeTime = math.min(slopeTime + dt * 2, 5)
				else
					-- On flat ground
					SlideElapsed += dt
					slopeTime = 0
				end
			end

			local groundTime = math.clamp((self.SlidingDuration - SlideElapsed)/self.SlidingDuration, 0, 1)

			-- Update orientation to face slide direction
			AO.CFrame = CFrame.new(Vector3.zero, lookVector)

			-- Calculate and apply velocity
			Velocity = (lookVector * self.InitialVelocity * groundTime) + (slopeVelocity * slopeTime)
			LV.VectorVelocity = Velocity
		end)
	)
end

function Sliding:SlideJump()
	-- Check if we're sliding OR just ended sliding (within buffer time)
	local timeSinceSlideEnd = os.clock() - self.SlideEndTime
	local canSlideJump = self.Sliding or (timeSinceSlideEnd <= self.JumpBufferTime and timeSinceSlideEnd > 0)

	if not canSlideJump then
		return
	end

	local Character: Model = self.Character
	local RootPart: BasePart = Character.HumanoidRootPart
	local Humanoid: Humanoid = Character.Humanoid

	-- End the slide if still sliding
	if self.Sliding then
		self:End()
	end

	-- Prevent double-jumping by resetting the slide end time
	self.SlideEndTime = 0

	-- Stop running animation if active, but remember if shift is held
	local wasShiftHeld = false
	if Client.Running then
		-- Check if shift is still being held using the Run input module
		local RunInput = require(ReplicatedStorage.Client.Inputs.Run)
		wasShiftHeld = RunInput.IsShiftHeld()
		Client.Modules["Movement"].Run(false)
	end

	-- Mark as busy to prevent other parkour actions
	self.Parent.Busy = true
	Client.InAir = true -- Prevent running animations
	Client.Leaping = true -- Prevent ALL animations during leap
	Client.LeapLanding = true -- Flag to prevent landing animation after leap

	-- Clear all existing body movers to prevent interference
	local Library = require(ReplicatedStorage.Modules.Library)
	Library.RemoveAllBodyMovers(Character)

	-- Clear residual velocity
	RootPart.AssemblyLinearVelocity = Vector3.zero
	RootPart.AssemblyAngularVelocity = Vector3.zero

	-- Wait for physics to settle
	task.wait()

	-- Get the direction the character is facing
	local forwardDirection = RootPart.CFrame.LookVector
	local upwardDirection = Vector3.yAxis

	-- Create a smooth arc using BodyVelocity with manual gravity simulation
	local horizontalSpeed = 80 -- Forward speed
	local verticalSpeed = 50 -- Initial upward speed
	local arcDuration = 0.8 -- Duration of the arc

	-- Apply initial velocity
	local initialVelocity = (forwardDirection * horizontalSpeed) + (upwardDirection * verticalSpeed)
	RootPart.AssemblyLinearVelocity = initialVelocity

	-- Create BodyVelocity for smooth arc control
	local BodyVel = Instance.new("BodyVelocity")
	BodyVel.MaxForce = Vector3.new(50000, 50000, 50000)
	BodyVel.Velocity = initialVelocity
	BodyVel.Parent = RootPart

	-- Manually simulate gravity for smooth arc
	local startTime = os.clock()
	local gravity = workspace.Gravity
	local arcConnection
	arcConnection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime

		-- End the arc control after duration
		if elapsed >= arcDuration or not BodyVel or not BodyVel.Parent then
			if arcConnection then
				arcConnection:Disconnect()
			end
			if BodyVel and BodyVel.Parent then
				BodyVel:Destroy()
			end
			return
		end

		-- Calculate current velocity with gravity (parabolic arc)
		local currentVerticalSpeed = verticalSpeed - (gravity * elapsed)
		local currentVelocity = (forwardDirection * horizontalSpeed) + (upwardDirection * currentVerticalSpeed)

		if BodyVel and BodyVel.Parent then
			BodyVel.Velocity = currentVelocity
		end
	end)

	-- Cleanup BodyVelocity after arc duration
	task.delay(arcDuration, function()
		if arcConnection then
			arcConnection:Disconnect()
		end
		if BodyVel and BodyVel.Parent then
			BodyVel:Destroy()
		end
	end)

	-- Play leap animation
	local leapAnim = Library.PlayAnimation(Character, ReplicatedStorage.Assets.Animations.Movement.Leap)

	-- Get animation length to know when it completes
	local animLength = 1.0 -- Default fallback
	if leapAnim then
		animLength = leapAnim.Length or 1.0
	end

	-- Wait for leap animation to complete or character to land
	local landed = false
	local animComplete = false

	-- Function to clean up leap state
	local function cleanupLeap()
		Client.Leaping = false
		Client.InAir = false
		self.Parent.Busy = false

		-- Clear leap landing flag after a longer delay to ensure landing animation doesn't play
		task.delay(0.5, function()
			Client.LeapLanding = false
		end)

		-- Resume sprinting if shift is still held
		if wasShiftHeld then
			local RunInput = require(ReplicatedStorage.Client.Inputs.Run)
			if RunInput.IsShiftHeld() then
				task.delay(0.05, function()
					Client.Modules["Movement"].Run(true)
				end)
			end
		end
	end

	-- Track animation completion
	task.delay(animLength, function()
		animComplete = true
		if landed then
			-- Both animation and landing complete
			cleanupLeap()
		end
	end)

	-- Track landing
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if Humanoid.FloorMaterial ~= Enum.Material.Air then
			landed = true
			if animComplete then
				-- Both animation and landing complete
				cleanupLeap()
				connection:Disconnect()
			end
		end
	end)

	-- Timeout after 3 seconds as safety
	task.delay(3, function()
		cleanupLeap()
		if connection then
			connection:Disconnect()
		end
	end)
end

function Sliding:End()
	if self.Sliding then
		self.Sliding = false
		self.SlideEndTime = os.clock() -- Track when slide ended for jump buffer
		Client.Sliding = false -- Clear Client state
		self.Character.Humanoid.PlatformStand = false

		local AnimationService = self.Parent.AnimationService
		AnimationService:Stop('Slide')

		self.Cleaner:Destroy()
		self.Parent.Busy = false
	end
end

function Sliding:Destroy()
	-- Clean up jump connection
	if self.JumpConnection then
		self.JumpConnection:Disconnect()
		self.JumpConnection = nil
	end

	-- End any active slide
	self:End()
end

return Sliding
