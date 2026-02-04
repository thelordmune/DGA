--[[
	Anti-Fling System

	Prevents excessive velocities from flinging the character.
	Monitors AssemblyLinearVelocity and clamps it to safe values.
	Also cleans up orphaned body movers that can cause flinging.
]]

local AntiFling = {}
local CSystem = require(script.Parent)

local RunService = CSystem.Service.RunService
local ReplicatedStorage = CSystem.Service.ReplicatedStorage
local Players = CSystem.Service.Players

local Player = Players.LocalPlayer

-- Get Library for body mover cleanup
local Library = require(ReplicatedStorage.Modules.Library)

-- Configuration
local MAX_HORIZONTAL_VELOCITY = 150
local MAX_VERTICAL_VELOCITY = 120
local VELOCITY_CHECK_INTERVAL = 0
local BODY_MOVER_CHECK_INTERVAL = 0.3

-- Track last check time
local lastCheckTime = 0
local lastBodyMoverCheckTime = 0

-- Track when body movers were created (to detect orphaned ones)
local bodyMoverCreationTimes = {}
local MAX_BODY_MOVER_LIFETIME = 2

-- PERFORMANCE: Cache body movers instead of GetDescendants every frame
local cachedBodyMovers = {}
local descendantConnections = {}

-- Function to clamp velocity
local function clampVelocity(velocity: Vector3): Vector3
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local vertical = Vector3.new(0, velocity.Y, 0)

	-- Clamp horizontal velocity
	if horizontal.Magnitude > MAX_HORIZONTAL_VELOCITY then
		horizontal = horizontal.Unit * MAX_HORIZONTAL_VELOCITY
	end

	-- Clamp vertical velocity
	if math.abs(vertical.Y) > MAX_VERTICAL_VELOCITY then
		vertical = Vector3.new(0, math.sign(velocity.Y) * MAX_VERTICAL_VELOCITY, 0)
	end

	return horizontal + vertical
end

-- PERFORMANCE: Check if instance is a body mover type
local function isBodyMover(instance)
	return instance:IsA("BodyVelocity")
		or instance:IsA("BodyPosition")
		or instance:IsA("BodyGyro")
		or instance:IsA("BodyAngularVelocity")
		or instance:IsA("LinearVelocity")
		or instance:IsA("AngularVelocity")
end

-- Function to clean up orphaned body movers (now uses cached list)
local function cleanupOrphanedBodyMovers()
	local currentTime = os.clock()

	-- PERFORMANCE: Iterate cached body movers instead of GetDescendants
	for mover, _ in pairs(cachedBodyMovers) do
		if not mover.Parent then
			-- Body mover was destroyed externally
			cachedBodyMovers[mover] = nil
			bodyMoverCreationTimes[mover] = nil
		else
			-- Track when this body mover was first seen
			if not bodyMoverCreationTimes[mover] then
				bodyMoverCreationTimes[mover] = currentTime
			end

			-- Check if this body mover has been around too long
			local lifetime = currentTime - bodyMoverCreationTimes[mover]
			if lifetime > MAX_BODY_MOVER_LIFETIME then
				-- This is an orphaned body mover, remove it
				cachedBodyMovers[mover] = nil
				bodyMoverCreationTimes[mover] = nil
				mover:Destroy()
			end
		end
	end
end

-- Setup monitoring for a character
local function setupCharacterMonitoring(Character)
	Character:WaitForChild("HumanoidRootPart")

	-- Reset timers
	lastCheckTime = 0
	lastBodyMoverCheckTime = 0

	-- Clear previous tracking
	table.clear(bodyMoverCreationTimes)
	table.clear(cachedBodyMovers)

	-- Disconnect previous descendant connections
	for _, conn in pairs(descendantConnections) do
		conn:Disconnect()
	end
	table.clear(descendantConnections)

	-- PERFORMANCE: Use event-based tracking instead of GetDescendants every frame
	-- Initial scan for existing body movers
	for _, descendant in pairs(Character:GetDescendants()) do
		if isBodyMover(descendant) then
			cachedBodyMovers[descendant] = true
		end
	end

	-- Listen for new body movers being added
	descendantConnections[1] = Character.DescendantAdded:Connect(function(descendant)
		if isBodyMover(descendant) then
			cachedBodyMovers[descendant] = true
		end
	end)

	-- Listen for body movers being removed
	descendantConnections[2] = Character.DescendantRemoving:Connect(function(descendant)
		if cachedBodyMovers[descendant] then
			cachedBodyMovers[descendant] = nil
			bodyMoverCreationTimes[descendant] = nil
		end
	end)

	-- Monitor velocity every frame
	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not Character or not Character.Parent then
			connection:Disconnect()
			-- Cleanup descendant connections too
			for _, conn in pairs(descendantConnections) do
				conn:Disconnect()
			end
			table.clear(descendantConnections)
			return
		end

		local rootPart = Character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			connection:Disconnect()
			return
		end

		-- Check velocity at interval
		lastCheckTime = lastCheckTime + deltaTime
		if lastCheckTime >= VELOCITY_CHECK_INTERVAL then
			lastCheckTime = 0

			-- Get current velocity
			local currentVelocity = rootPart.AssemblyLinearVelocity

			-- Check if velocity is excessive
			local horizontalSpeed = Vector3.new(currentVelocity.X, 0, currentVelocity.Z).Magnitude
			local verticalSpeed = math.abs(currentVelocity.Y)

			if horizontalSpeed > MAX_HORIZONTAL_VELOCITY or verticalSpeed > MAX_VERTICAL_VELOCITY then
				-- Clamp the velocity
				local clampedVelocity = clampVelocity(currentVelocity)
				rootPart.AssemblyLinearVelocity = clampedVelocity
			end
		end

		-- Check for orphaned body movers at interval (now uses cached list)
		lastBodyMoverCheckTime = lastBodyMoverCheckTime + deltaTime
		if lastBodyMoverCheckTime >= BODY_MOVER_CHECK_INTERVAL then
			lastBodyMoverCheckTime = 0
			cleanupOrphanedBodyMovers()
		end
	end)
end

-- Initialize
task.spawn(function()
	local Character = Player.Character or Player.CharacterAdded:Wait()
	setupCharacterMonitoring(Character)

	-- Reconnect when character respawns
	Player.CharacterAdded:Connect(function(newCharacter)
		setupCharacterMonitoring(newCharacter)
	end)
end)

return AntiFling
