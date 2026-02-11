--!strict
-- En Input Handler (V Key - Hold)
-- Expands an En detection sphere while V is held.
-- Server creates the En model in workspace for all players to see.
-- Client detects entities locally and renders animated ghost clone prediction visuals.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

-- State
self.EnActive = false
self.HoldConnection = nil
self.HoldStartTime = 0
self.RenderConnection = nil

-- Config
local GROWTH_RATE = 10 -- studs per second radius growth
local MAX_RADIUS = 50 -- max radius
local MIN_RADIUS = 5 -- starting radius
local PREDICTION_TIME = 0.6 -- how far ahead to predict (seconds)
local DETECTION_INTERVAL = 0.15 -- detect at ~7Hz
local GHOST_TRANSPARENCY = 0.6 -- ghost clone transparency
local VELOCITY_SMOOTHING = 0.3 -- exponential smoothing factor (0-1, lower = smoother)
local GHOST_LERP_SPEED = 8 -- how fast ghosts interpolate to target position per second

-- Ghost clone tracking
local activeGhosts: {[string]: any} = {}

-- Client-side velocity tracking (smoothed)
local previousPositions: {[string]: Vector3} = {}
local smoothedVelocities: {[string]: Vector3} = {}
local lastDetectionTime = 0

-- Latest detection results
local latestDetected: {any} = {}

local NEN_DEFAULT_COLOR = Color3.fromRGB(100, 200, 255)

local function getNenColor(): Color3
	local player = Players.LocalPlayer
	if not player then return NEN_DEFAULT_COLOR end

	local ok, Global = pcall(function()
		return require(ReplicatedStorage.Client.Global)
	end)
	if not ok or not Global then return NEN_DEFAULT_COLOR end

	local nenData = Global.GetData(player, "Nen")
	if not nenData then return NEN_DEFAULT_COLOR end

	local colorData = nenData.Color
	if colorData and colorData.R and colorData.G and colorData.B then
		local r, g, b = colorData.R, colorData.G, colorData.B
		if r >= 250 and g >= 250 and b >= 250 then
			return NEN_DEFAULT_COLOR
		end
		return Color3.fromRGB(r, g, b)
	end
	return NEN_DEFAULT_COLOR
end

-- Find the client's own NpcRegistryCamera (tagged with ClientOwned attribute)
local cachedClientCamera = nil
local function getClientNpcCamera()
	if cachedClientCamera and cachedClientCamera.Parent then
		return cachedClientCamera
	end
	for _, child in workspace:GetChildren() do
		if child.Name == "NpcRegistryCamera" and child:IsA("Camera") and child:GetAttribute("ClientOwned") then
			cachedClientCamera = child
			return child
		end
	end
	return nil
end

-- Sync animations from source model to ghost clone
local function syncGhostAnimations(ghostData)
	local ghost = ghostData.ghost
	local sourceModel = ghostData.sourceModel
	if not ghost or not ghost.Parent or not sourceModel or not sourceModel.Parent then return end

	-- Get source animator
	local sourceHumanoid = sourceModel:FindFirstChildOfClass("Humanoid")
	if not sourceHumanoid then return end
	local sourceAnimator = sourceHumanoid:FindFirstChildOfClass("Animator")
	if not sourceAnimator then return end

	-- Get ghost animator
	local ghostHumanoid = ghost:FindFirstChildOfClass("Humanoid")
	if not ghostHumanoid then return end
	local ghostAnimator = ghostHumanoid:FindFirstChildOfClass("Animator")
	if not ghostAnimator then
		ghostAnimator = Instance.new("Animator")
		ghostAnimator.Parent = ghostHumanoid
	end

	-- Get currently playing tracks on source
	local sourceTracks = sourceAnimator:GetPlayingAnimationTracks()

	-- Build a set of source animation IDs for comparison
	local sourceAnimIds: {[string]: {track: AnimationTrack}} = {}
	for _, track in sourceTracks do
		if track.IsPlaying and track.Animation then
			local animId = track.Animation.AnimationId
			if animId and animId ~= "" then
				sourceAnimIds[animId] = { track = track }
			end
		end
	end

	-- Get currently playing tracks on ghost
	local ghostTracks = ghostAnimator:GetPlayingAnimationTracks()
	local ghostAnimIds: {[string]: AnimationTrack} = {}
	for _, track in ghostTracks do
		if track.Animation then
			local animId = track.Animation.AnimationId
			if animId and animId ~= "" then
				ghostAnimIds[animId] = track
			end
		end
	end

	-- Stop ghost tracks that are no longer playing on source
	for animId, ghostTrack in ghostAnimIds do
		if not sourceAnimIds[animId] then
			ghostTrack:Stop(0.2)
		end
	end

	-- Play/sync source tracks on ghost
	for animId, sourceData in sourceAnimIds do
		local existingGhostTrack = ghostAnimIds[animId]
		if existingGhostTrack and existingGhostTrack.IsPlaying then
			-- Already playing, sync time position and speed
			existingGhostTrack:AdjustSpeed(sourceData.track.Speed)
		else
			-- Not playing on ghost yet, load and play
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			local ok2, ghostTrack = pcall(function()
				return ghostAnimator:LoadAnimation(anim)
			end)
			if ok2 and ghostTrack then
				ghostTrack:Play(0.15)
				ghostTrack.TimePosition = sourceData.track.TimePosition
				ghostTrack:AdjustSpeed(sourceData.track.Speed)
			end
		end
	end
end

-- Create a ghost clone from a source model
local function createGhostClone(sourceModel: Model, nenColor: Color3): Model?
	local ghost = sourceModel:Clone()
	ghost.Name = "EnGhost_" .. sourceModel.Name

	-- Strip non-visual stuff: scripts, sounds, GUIs, body movers
	for _, desc in ghost:GetDescendants() do
		if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
			desc:Destroy()
		elseif desc:IsA("Sound") then
			desc:Destroy()
		elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
			desc:Destroy()
		elseif desc:IsA("ProximityPrompt") then
			desc:Destroy()
		elseif desc:IsA("BodyVelocity") or desc:IsA("BodyForce") or desc:IsA("BodyGyro") or desc:IsA("BodyPosition") then
			desc:Destroy()
		end
	end

	-- Keep humanoid alive for animations but prevent physics movement
	local humanoid = ghost:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		-- Don't set PlatformStand - we need the humanoid for animation playback
		-- Anchored parts prevent any physics movement anyway
	end

	-- Make all parts ghostly: transparent, nen-colored, no collision
	for _, desc in ghost:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CanTouch = false
			desc.CastShadow = false
			desc.Transparency = GHOST_TRANSPARENCY
			desc.Material = Enum.Material.ForceField
			desc.Color = nenColor
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = 1
		elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
			desc:Destroy()
		elseif desc:IsA("SpecialMesh") then
			desc.VertexColor = Vector3.new(nenColor.R, nenColor.G, nenColor.B)
		end
	end

	local visualsFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Visuals")
	ghost.Parent = visualsFolder or workspace

	return ghost
end

-- Client-side entity detection: checks NpcRegistryCamera clones + workspace.World.Live
local function detectEntitiesInRadius(enPosition: Vector3, enRadius: number)
	local detected = {}
	local localPlayer = Players.LocalPlayer
	local localCharacter = localPlayer and localPlayer.Character

	-- 1) Check client NPC camera clones (Chrono NPCs)
	local clientCamera = getClientNpcCamera()
	if clientCamera then
		for _, child in clientCamera:GetChildren() do
			local models = child:IsA("Folder") and child:GetChildren() or { child }
			for _, npcModel in models do
				if not npcModel:IsA("Model") then continue end
				local hrp = npcModel:FindFirstChild("HumanoidRootPart") or npcModel.PrimaryPart
				if not hrp then continue end

				local pos = hrp.Position
				local distance = (pos - enPosition).Magnitude
				if distance <= enRadius then
					local chronoId = npcModel:GetAttribute("ChronoId") or npcModel.Name
					local key = "npc_" .. tostring(chronoId)

					local prevPos = previousPositions[key]
					local rawVelocity = Vector3.zero
					if prevPos then
						rawVelocity = (pos - prevPos) / DETECTION_INTERVAL
					end
					previousPositions[key] = pos

					local prevSmoothed = smoothedVelocities[key] or Vector3.zero
					local smoothed = prevSmoothed:Lerp(rawVelocity, VELOCITY_SMOOTHING)
					smoothedVelocities[key] = smoothed

					table.insert(detected, {
						key = key,
						position = pos,
						velocity = smoothed,
						cframe = hrp.CFrame,
						name = npcModel.Name,
						model = npcModel,
					})
				end
			end
		end
	end

	-- 2) Check workspace.World.Live (other players)
	local worldLive = workspace:FindFirstChild("World")
	worldLive = worldLive and worldLive:FindFirstChild("Live")
	if worldLive then
		for _, child in worldLive:GetChildren() do
			local model = child
			if child:IsA("Actor") then
				model = child:FindFirstChildWhichIsA("Model")
			end
			if not model or not model:IsA("Model") then continue end
			if model == localCharacter then continue end
			if not model:FindFirstChild("Humanoid") then continue end

			local hrp = model:FindFirstChild("HumanoidRootPart")
			if not hrp then continue end

			local pos = hrp.Position
			local distance = (pos - enPosition).Magnitude
			if distance <= enRadius then
				local key = "live_" .. model.Name
				local prevPos = previousPositions[key]
				local rawVelocity = Vector3.zero
				if prevPos then
					rawVelocity = (pos - prevPos) / DETECTION_INTERVAL
				end
				previousPositions[key] = pos

				local prevSmoothed = smoothedVelocities[key] or Vector3.zero
				local smoothed = prevSmoothed:Lerp(rawVelocity, VELOCITY_SMOOTHING)
				smoothedVelocities[key] = smoothed

				table.insert(detected, {
					key = key,
					position = pos,
					velocity = smoothed,
					cframe = hrp.CFrame,
					name = model.Name,
					model = model,
				})
			end
		end
	end

	return detected
end

-- Calculate the target CFrame for a ghost based on entity data
local function calculateGhostTargetCFrame(entity): CFrame
	local speed = entity.velocity.Magnitude
	if speed > 0.5 then
		local predictedPos = entity.position + entity.velocity * PREDICTION_TIME
		local moveDir = entity.velocity * Vector3.new(1, 0, 1)
		if moveDir.Magnitude > 0.5 then
			return CFrame.lookAt(predictedPos, predictedPos + moveDir)
		else
			local _, ry, _ = entity.cframe:ToEulerAnglesYXZ()
			return CFrame.new(predictedPos) * CFrame.Angles(0, ry, 0)
		end
	else
		return entity.cframe + Vector3.new(0, 0.1, 0)
	end
end

-- Remove a ghost with fade out
local function removeGhost(key: string)
	local ghostData = activeGhosts[key]
	if not ghostData then return end
	activeGhosts[key] = nil

	local ghost = ghostData.ghost
	if not ghost or not ghost.Parent then return end

	-- Stop all animation tracks
	local ghostHumanoid = ghost:FindFirstChildOfClass("Humanoid")
	if ghostHumanoid then
		local ghostAnimator = ghostHumanoid:FindFirstChildOfClass("Animator")
		if ghostAnimator then
			for _, track in ghostAnimator:GetPlayingAnimationTracks() do
				track:Stop(0)
			end
		end
	end

	-- Fade out all parts then destroy
	for _, desc in ghost:GetDescendants() do
		if desc:IsA("BasePart") then
			TweenService:Create(desc, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
		end
	end

	task.delay(0.35, function()
		if ghost and ghost.Parent then ghost:Destroy() end
	end)
end

-- Remove all ghosts
local function clearAllGhosts()
	for _, ghostData in pairs(activeGhosts) do
		if ghostData.ghost and ghostData.ghost.Parent then
			ghostData.ghost:Destroy()
		end
	end
	activeGhosts = {}
end

-- Combined detection + render loop
local function startDetectionAndRender()
	if self.RenderConnection then return end

	local nenColor = getNenColor()

	self.RenderConnection = RunService.RenderStepped:Connect(function(dt)
		if not self.EnActive then return end

		local player = Players.LocalPlayer
		if not player then return end
		local character = player.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local enRadius = character:GetAttribute("EnRadius") or MIN_RADIUS
		local enPosition = hrp.Position

		-- Run detection at configured rate
		local now = os.clock()
		if now - lastDetectionTime >= DETECTION_INTERVAL then
			lastDetectionTime = now

			latestDetected = detectEntitiesInRadius(enPosition, enRadius)

			local activeKeys = {}

			for _, entity in latestDetected do
				activeKeys[entity.key] = true

				local ghostData = activeGhosts[entity.key]

				-- Create ghost if it doesn't exist or source model changed
				if not ghostData or not ghostData.ghost or not ghostData.ghost.Parent
					or ghostData.sourceModel ~= entity.model then
					if ghostData then
						removeGhost(entity.key)
					end
					local ghost = createGhostClone(entity.model, nenColor)
					if ghost then
						local targetCF = calculateGhostTargetCFrame(entity)
						ghostData = {
							ghost = ghost,
							sourceModel = entity.model,
							targetCFrame = targetCF,
							currentCFrame = targetCF,
						}
						activeGhosts[entity.key] = ghostData
						ghost:PivotTo(targetCF)

						-- Fade in
						for _, desc in ghost:GetDescendants() do
							if desc:IsA("BasePart") then
								local targetTransparency = desc.Transparency
								desc.Transparency = 1
								TweenService:Create(desc, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = targetTransparency}):Play()
							end
						end
					end
				else
					-- Update target CFrame
					ghostData.targetCFrame = calculateGhostTargetCFrame(entity)
				end

				-- Sync animations from source to ghost
				if ghostData and ghostData.ghost and ghostData.ghost.Parent then
					syncGhostAnimations(ghostData)
				end
			end

			-- Remove ghosts for entities no longer detected
			for key, _ in pairs(activeGhosts) do
				if not activeKeys[key] then
					removeGhost(key)
				end
			end
		end

		-- Every frame: smoothly interpolate all ghosts toward their target CFrame
		local lerpAlpha = math.clamp(dt * GHOST_LERP_SPEED, 0, 1)
		for _, ghostData in pairs(activeGhosts) do
			if ghostData.ghost and ghostData.ghost.Parent and ghostData.targetCFrame then
				ghostData.currentCFrame = ghostData.currentCFrame:Lerp(ghostData.targetCFrame, lerpAlpha)
				ghostData.ghost:PivotTo(ghostData.currentCFrame)
			end
		end
	end)
end

local function stopDetectionAndRender()
	if self.RenderConnection then
		self.RenderConnection:Disconnect()
		self.RenderConnection = nil
	end
	clearAllGhosts()
	previousPositions = {}
	smoothedVelocities = {}
	latestDetected = {}
	lastDetectionTime = 0
end

InputModule.InputBegan = function(_, Client)
	if self.EnActive then return end

	local player = Players.LocalPlayer
	if not player then return end
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	self.EnActive = true
	self.HoldStartTime = os.clock()

	local Bridges = require(ReplicatedStorage.Modules.Bridges)
	Bridges.NenAbility:Fire({
		action = "en_start",
		abilityName = "En",
	})

	startDetectionAndRender()

	self.HoldConnection = RunService.RenderStepped:Connect(function()
		if not self.EnActive then return end
		if not hrp or not hrp.Parent then
			InputModule.StopEn(Client)
			return
		end

		local holdTime = os.clock() - self.HoldStartTime
		local currentRadius = math.min(MIN_RADIUS + GROWTH_RATE * holdTime, MAX_RADIUS)
		character:SetAttribute("EnRadius", currentRadius)
	end)
end

InputModule.InputEnded = function(_, Client)
	InputModule.StopEn(Client)
end

function InputModule.StopEn(_Client)
	if not self.EnActive then return end
	self.EnActive = false

	if self.HoldConnection then
		self.HoldConnection:Disconnect()
		self.HoldConnection = nil
	end

	stopDetectionAndRender()

	local player = Players.LocalPlayer
	if player and player.Character then
		player.Character:SetAttribute("EnRadius", nil)
	end

	local Bridges = require(ReplicatedStorage.Modules.Bridges)
	Bridges.NenAbility:Fire({
		action = "en_stop",
		abilityName = "En",
	})
end

InputModule.InputChanged = function()
end

InputModule.IsEnActive = function()
	return self.EnActive
end

return InputModule
