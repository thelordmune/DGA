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
	print("[Sliding] Start() called")

	if self.Parent.Busy then
		print("[Sliding] Blocked - Parent busy")
		return
	end

	local Character: Model = self.Character
	local RootPart: BasePart = Character.HumanoidRootPart
	local Humanoid: Humanoid = Character.Humanoid

	if Humanoid.FloorMaterial == Enum.Material.Air then
		print("[Sliding] Blocked - In air")
		return
	end

	print("[Sliding] Starting slide...")
	
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
	LV.MaxForce = 5000 -- Moderate force - enough to slide but not fling
	LV.VectorVelocity = Velocity
	LV.RelativeTo = Enum.ActuatorRelativeTo.World
	LV.Parent = RootPart
	self.Cleaner:AddTask(LV)

	-- AlignOrientation is only used on slopes/stairs to tilt the character
	-- On flat ground, the sliding animation handles orientation
	local AO = Instance.new('AlignOrientation')
	AO.Attachment0 = Attachment
	AO.Mode = Enum.OrientationAlignmentMode.OneAttachment
	AO.MaxTorque = 0 -- Start disabled, only enable on slopes/stairs
	AO.Responsiveness = 30 -- Smooth transitions
	AO.CFrame = RootPart.CFrame - RootPart.CFrame.Position -- Match current rotation
	AO.Parent = RootPart
	self.Cleaner:AddTask(AO)

	local SlideElapsed = 0

	-- For stair smoothing - only initialize when actually on stairs
	local smoothedY = nil

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

			local lookVector
			local slopeVelocity = Vector3.zero
			local isOnSlope = false
			local isOnStairs = false

			if not groundDetection then
				-- In air - use current look direction and reduce slide time
				lookVector = RootPart.CFrame.LookVector
				SlideElapsed += dt * 2
			else
				-- On ground - calculate slope angle and direction
				local surfaceNormal = groundDetection.Normal
				local slopeAngle = math.acos(surfaceNormal:Dot(Vector3.yAxis))
				isOnSlope = slopeAngle > math.rad(5) -- More than 5 degrees is considered a slope

				-- Check for stairs by raycasting ahead to detect height drops
				if not isOnSlope then
					local forwardDirection = RootPart.CFrame.LookVector
					local checkDistance = 4 -- Check 4 studs ahead

					-- Raycast down ahead to find the ground in front
					local forwardGroundDetection = Raycast({
						Start = RootPart.Position + (forwardDirection * checkDistance),
						Direction = Vector3.new(0, -10, 0),
						Params = self.Parent.Params
					})

					-- If there's a height difference ahead (going down), we're on stairs
					if forwardGroundDetection then
						local heightDifference = RootPart.Position.Y - forwardGroundDetection.Position.Y

						-- If ground ahead is lower by at least 0.5 studs, treat as stairs/slope
						if heightDifference > 0.5 then
							isOnStairs = true
						end
					end
				end

				if isOnSlope or isOnStairs then
					-- Get the downward slope direction (where gravity pulls us)
					local gravityVector = Vector3.new(0, -1, 0)

					if isOnStairs then
						-- For stairs, use horizontal forward direction only (no downward tilt)
						local flatForward = (RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
						lookVector = flatForward

						-- Initialize smoothedY when first hitting stairs
						if smoothedY == nil then
							smoothedY = RootPart.Position.Y
						end

						-- Smooth the Y position to glide over stairs instead of bumping
						-- Target is just the ground position (no offset to avoid lifting)
						local targetY = groundDetection.Position.Y + Height.Y
						smoothedY = smoothedY + (targetY - smoothedY) * math.min(dt * 5, 1) -- Gentler interpolation

						-- Only apply if we're going DOWN stairs (not up)
						if targetY < RootPart.Position.Y then
							local currentPos = RootPart.Position
							RootPart.CFrame = CFrame.new(currentPos.X, smoothedY, currentPos.Z) * (RootPart.CFrame - RootPart.CFrame.Position)
						end
					else
						-- For slopes, use proper surface projection
						local projectedDown = gravityVector - (surfaceNormal * gravityVector:Dot(surfaceNormal))
						lookVector = projectedDown.Unit
						smoothedY = nil -- Reset stair smoothing
					end

					-- Calculate slope velocity boost - small constant boost, not accumulated
					local slopeBoost = 5 -- Small constant boost on slopes/stairs
					if isOnSlope then
						slopeBoost = math.sin(slopeAngle) * 10 -- Max 10 extra velocity based on steepness
					end
					slopeVelocity = lookVector * slopeBoost

					-- Still count time on slopes/stairs, but slower (extends slide by 50%)
					SlideElapsed += dt * 0.5

					-- Disable AlignOrientation - let animation handle it
					AO.MaxTorque = 0
				else
					-- On flat ground - slide in the direction perpendicular to slope normal
					lookVector = surfaceNormal:Cross(RootPart.CFrame.RightVector)
					SlideElapsed += dt
					smoothedY = nil -- Reset stair smoothing

					-- Disable AlignOrientation on flat ground - let animation handle it
					AO.MaxTorque = 0
				end
			end

			local groundTime = math.clamp((self.SlidingDuration - SlideElapsed)/self.SlidingDuration, 0, 1)

			-- Calculate and apply velocity - ALWAYS decay over time
			-- Base velocity decays with groundTime, slope/stairs just add a small constant boost
			local baseVelocity = lookVector * self.InitialVelocity * groundTime

			if isOnSlope or isOnStairs then
				-- On slope/stairs: add small constant slope boost to decaying base velocity
				Velocity = baseVelocity + slopeVelocity
			else
				-- On flat ground: just use decaying base velocity
				Velocity = baseVelocity
			end

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

	-- Add to Cleaner for cleanup on interrupt (e.g., getting stunned during leap)
	self.Cleaner:AddTask(BodyVel)

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
