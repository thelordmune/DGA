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

-- Function to clean up orphaned body movers
local function cleanupOrphanedBodyMovers(Character)
	if not Character or not Character.Parent then return end

	local currentTime = os.clock()
	local moversRemoved = 0

	-- Check all descendants for body movers
	for _, descendant in pairs(Character:GetDescendants()) do
		if descendant:IsA("BodyVelocity")
			or descendant:IsA("BodyPosition")
			or descendant:IsA("BodyGyro")
			or descendant:IsA("BodyAngularVelocity")
			or descendant:IsA("LinearVelocity")
			or descendant:IsA("AngularVelocity") then

			-- Track when this body mover was first seen
			if not bodyMoverCreationTimes[descendant] then
				bodyMoverCreationTimes[descendant] = currentTime
			end

			-- Check if this body mover has been around too long
			local lifetime = currentTime - bodyMoverCreationTimes[descendant]
			if lifetime > MAX_BODY_MOVER_LIFETIME then
				-- This is an orphaned body mover, remove it
				bodyMoverCreationTimes[descendant] = nil
				descendant:Destroy()
				moversRemoved = moversRemoved + 1
			end
		end
	end

	-- Clean up tracking for destroyed body movers
	for mover, _ in pairs(bodyMoverCreationTimes) do
		if not mover.Parent then
			bodyMoverCreationTimes[mover] = nil
		end
	end
end

-- Setup monitoring for a character
local function setupCharacterMonitoring(Character)
	Character:WaitForChild("HumanoidRootPart")

	-- Reset timers
	lastCheckTime = 0
	lastBodyMoverCheckTime = 0

	-- Clear body mover tracking
	table.clear(bodyMoverCreationTimes)

	-- Monitor velocity every frame
	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not Character or not Character.Parent then
			connection:Disconnect()
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

		-- Check for orphaned body movers at interval
		lastBodyMoverCheckTime = lastBodyMoverCheckTime + deltaTime
		if lastBodyMoverCheckTime >= BODY_MOVER_CHECK_INTERVAL then
			lastBodyMoverCheckTime = 0
			cleanupOrphanedBodyMovers(Character)
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
