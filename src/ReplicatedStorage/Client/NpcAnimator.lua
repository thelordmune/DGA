--[[
	NPC Animator - Client-side animation for Chrono NPCs

	Since Chrono bypasses default Roblox replication, animations don't replicate.
	This module plays walk/idle animations locally based on NPC velocity.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Only run on client
if RunService:IsServer() then
	return {}
end

local NpcAnimator = {}

-- Animation IDs (same as player animations from Animate/Cache.lua)
local ANIMATION_IDS = {
	Idle = 180435571,
	Walk = 180426354, -- Standard R6 walk animation
}

-- Track NPC animation state
local npcAnimations = {} -- [model] = { animator, walkTrack, idleTrack, lastState }

-- Minimum velocity to be considered walking
local WALK_VELOCITY_THRESHOLD = 0.5

local function getOrCreateAnimator(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	return animator
end

local function loadAnimation(animator: Animator, animationId: number): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = `rbxassetid://{animationId}`

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if success then
		return track
	else
		warn(`[NpcAnimator] Failed to load animation {animationId}`)
		return nil
	end
end

local function setupNpcAnimations(model: Model)
	if npcAnimations[model] then
		return -- Already set up
	end

	local animator = getOrCreateAnimator(model)
	if not animator then
		return
	end

	local walkTrack = loadAnimation(animator, ANIMATION_IDS.Walk)
	local idleTrack = loadAnimation(animator, ANIMATION_IDS.Idle)

	if not walkTrack or not idleTrack then
		return
	end

	-- Configure tracks
	walkTrack.Priority = Enum.AnimationPriority.Core
	walkTrack.Looped = true

	idleTrack.Priority = Enum.AnimationPriority.Core
	idleTrack.Looped = true

	npcAnimations[model] = {
		animator = animator,
		walkTrack = walkTrack,
		idleTrack = idleTrack,
		lastState = "none", -- "idle", "walk", or "none"
		lastPosition = model.PrimaryPart and model.PrimaryPart.Position or Vector3.zero,
		lastTime = os.clock(),
	}

	-- Start with idle
	idleTrack:Play(0.2)
	npcAnimations[model].lastState = "idle"
end

local function cleanupNpcAnimations(model: Model)
	local data = npcAnimations[model]
	if not data then
		return
	end

	if data.walkTrack then
		data.walkTrack:Stop(0)
		data.walkTrack:Destroy()
	end

	if data.idleTrack then
		data.idleTrack:Stop(0)
		data.idleTrack:Destroy()
	end

	npcAnimations[model] = nil
end

local function updateNpcAnimation(model: Model)
	local data = npcAnimations[model]
	if not data then
		return
	end

	local primaryPart = model.PrimaryPart
	if not primaryPart then
		return
	end

	-- Calculate velocity from position change
	local currentPosition = primaryPart.Position
	local timeDelta = os.clock() - data.lastTime

	if timeDelta < 0.016 then -- Don't calculate too frequently
		return
	end

	local velocity = (currentPosition - data.lastPosition) / timeDelta
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	data.lastPosition = currentPosition
	data.lastTime = os.clock()

	-- Determine if walking or idle
	local shouldWalk = horizontalSpeed > WALK_VELOCITY_THRESHOLD

	if shouldWalk and data.lastState ~= "walk" then
		-- Transition to walk
		data.idleTrack:Stop(0.2)
		data.walkTrack:Play(0.2)
		data.lastState = "walk"
	elseif not shouldWalk and data.lastState ~= "idle" then
		-- Transition to idle
		data.walkTrack:Stop(0.2)
		data.idleTrack:Play(0.2)
		data.lastState = "idle"
	end
end

-- Initialize Chrono connection
local function initializeChrono()
	local success, Chrono = pcall(function()
		return require(ReplicatedStorage.Modules.Chrono)
	end)

	if not success or not Chrono then
		warn("[NpcAnimator] Failed to require Chrono module")
		return false
	end

	if not Chrono.NpcRegistry then
		warn("[NpcAnimator] Chrono.NpcRegistry not available")
		return false
	end

	-- Listen for new NPCs
	Chrono.NpcRegistry.NpcAdded:Connect(function(_npcId, model, _initData)
		task.defer(function()
			setupNpcAnimations(model)
		end)
	end)

	-- Listen for NPC removal
	Chrono.NpcRegistry.NpcRemoved:Connect(function(_npcId, model)
		if model then
			cleanupNpcAnimations(model)
		end
	end)

	-- Set up existing NPCs by scanning the Camera folder where Chrono stores them
	local camera = workspace.CurrentCamera
	if camera then
		for _, child in camera:GetChildren() do
			if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
				task.defer(function()
					setupNpcAnimations(child)
				end)
			end
		end
	end

	return true
end

-- Update loop
RunService.Heartbeat:Connect(function()
	for model in npcAnimations do
		if not model or not model.Parent then
			npcAnimations[model] = nil
			continue
		end
		updateNpcAnimation(model)
	end
end)

-- Initialize immediately since this module is required after Chrono is ready
initializeChrono()

return NpcAnimator
