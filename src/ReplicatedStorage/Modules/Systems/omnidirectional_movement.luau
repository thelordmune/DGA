--[[
	Omnidirectional Movement System

	Detects player's movement direction in 8 directions and plays appropriate walk animations:
	- Forward -> FrontWalk
	- Backward -> BackWalk
	- Left -> LeftWalk
	- Right -> RightWalk
	- Diagonal (Forward Right) -> RightFront
	- Diagonal (Forward Left) -> LeftFront
	- Diagonal (Backward Right) -> Rightback
	- Diagonal (Backward Left) -> LeftBack

	ONLY ACTIVE WHEN SHIFT LOCKED!
	When not in shift lock mode, the system stops all walk animations and returns to default behavior.

	Runs on client-only, every frame (Heartbeat).
	Uses Library.PlayAnimation and Library.StopAnimation for smooth transitions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Library = require(ReplicatedStorage.Modules.Library)

local DEBUG = true -- Enable debug logging

-- Threshold for determining diagonal vs cardinal movement
local DIAGONAL_THRESHOLD = 0.5 -- If both axes are above this, it's diagonal

-- Fade time for animation transitions
local FADE_TIME = 0.25

-- Map directions to animation names
local DIRECTION_TO_ANIMATION = {
	["Forward"] = "FrontWalk",
	["Backward"] = "BackWalk",
	["Left"] = "LeftWalk",
	["Right"] = "RightWalk",
	["Diagonal (Forward Right)"] = "RightFront",
	["Diagonal (Forward Left)"] = "LeftFront",
	["Diagonal (Backward Right)"] = "RightBack",
	["Diagonal (Backward Left)"] = "LeftBack",
}

-- Track current state
local lastDirection = nil
local currentAnimationName = nil

local function GetMovementDirection(humanoid, rootPart)
	local moveDirection = humanoid.MoveDirection

	-- If not moving, return nil
	if moveDirection.Magnitude < 0.1 then
		return nil
	end

	-- Get the dot products for each direction
	local forwardDot = moveDirection:Dot(rootPart.CFrame.LookVector)
	local rightDot = moveDirection:Dot(rootPart.CFrame.RightVector)

	-- Determine if moving forward/backward
	local isForward = forwardDot > DIAGONAL_THRESHOLD
	local isBackward = forwardDot < -DIAGONAL_THRESHOLD

	-- Determine if moving left/right
	local isRight = rightDot > DIAGONAL_THRESHOLD
	local isLeft = rightDot < -DIAGONAL_THRESHOLD

	-- Determine direction based on combinations
	if isForward and isRight then
		return "Diagonal (Forward Right)"
	elseif isForward and isLeft then
		return "Diagonal (Forward Left)"
	elseif isBackward and isRight then
		return "Diagonal (Backward Right)"
	elseif isBackward and isLeft then
		return "Diagonal (Backward Left)"
	elseif isForward then
		return "Forward"
	elseif isBackward then
		return "Backward"
	elseif isRight then
		return "Right"
	elseif isLeft then
		return "Left"
	end

	return nil
end

local function PlayWalkAnimation(character, direction)
	local animationName = DIRECTION_TO_ANIMATION[direction]
	if not animationName then return end

	-- Stop previous animation with fade
	if currentAnimationName then
		Library.StopAnimation(character, currentAnimationName, FADE_TIME)
	end

	-- Play new animation with fade and set priority to Movement (lower than Core)
	local animTrack = Library.PlayAnimation(character, animationName, FADE_TIME)
	if animTrack then
		animTrack.Priority = Enum.AnimationPriority.Movement
	end
	currentAnimationName = animationName

	if DEBUG then
		print(`[Movement] Playing animation: {animationName} for direction: {direction}`)
	end
end

local function StopWalkAnimation(character)
	if currentAnimationName then
		Library.StopAnimation(character, currentAnimationName, FADE_TIME)
		currentAnimationName = nil

		if DEBUG then
			print(`[Movement] Stopped walk animation`)
		end
	end
end

local function omnidirectional_movement()
	-- Only run on client
	if RunService:IsServer() then return end

	local player = Players.LocalPlayer
	if not player then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Check if player is in shift lock mode
	local isShiftLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter

	-- If not in shift lock, stop any playing animations and return
	if not isShiftLocked then
		if currentAnimationName then
			StopWalkAnimation(character)
			lastDirection = nil
		end
		return
	end

	-- Get current movement direction (only when shift locked)
	local currentDirection = GetMovementDirection(humanoid, rootPart)

	-- Handle direction changes
	if currentDirection ~= lastDirection then
		if currentDirection then
			-- Started moving or changed direction
			PlayWalkAnimation(character, currentDirection)
		else
			-- Stopped moving
			StopWalkAnimation(character)
		end
		lastDirection = currentDirection
	end
end

return {
	run = omnidirectional_movement,
	settings = {
		phase = "Heartbeat",
		client_only = true,
		priority = 100,
	}
}

