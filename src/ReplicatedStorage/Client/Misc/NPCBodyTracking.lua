--[[
	NPC Head Tracking System
	Makes dialogue NPCs rotate their head and SurfaceGui part to face nearby players
	Only works for NPCs in workspace.World.Dialogue (like Sam, Magnus, etc.)
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Client = require(script.Parent.Parent)

local NPCBodyTracking = {}

-- Settings
local DETECTION_RANGE = 15 -- Distance to detect player (in studs)
local UPDATE_INTERVAL = 0.1 -- How often to update head tracking (in seconds)
local ROTATION_SPEED = 0.25 -- How fast the head rotates (in seconds)
local VERTICAL_RESTRICTION = 0.75 -- How much the head can tilt up/down (0-1)
local HORIZONTAL_RESTRICTION = 0.75 -- How much the head can turn left/right (0-1)

-- Track NPCs and their original orientations
local trackedNPCs = {}
local lastUpdateTime = 0
local active = false

-- Get all dialogue NPCs
local function getDialogueNPCs()
	local npcs = {}
	
	local dialogueFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Dialogue")
	if dialogueFolder then
		for _, npc in dialogueFolder:GetChildren() do
			if npc:IsA("Model") and npc:FindFirstChild("Humanoid") and npc:FindFirstChild("HumanoidRootPart") then
				table.insert(npcs, npc)
			end
		end
	end
	
	return npcs
end

-- Check if player is in range of NPC
local function isPlayerInRange(npcModel)
	if not Client.Character then return false end
	
	local playerRoot = Client.Character:FindFirstChild("HumanoidRootPart")
	local playerHumanoid = Client.Character:FindFirstChild("Humanoid")
	local npcRoot = npcModel:FindFirstChild("HumanoidRootPart")
	
	if not playerRoot or not playerHumanoid or not npcRoot then return false end
	if playerHumanoid.Health <= 0 then return false end
	
	local distance = (playerRoot.Position - npcRoot.Position).Magnitude
	return distance <= DETECTION_RANGE
end

-- Initialize NPC tracking (store original neck C0 and SurfaceGui CFrame)
local function initializeNPC(npcModel)
	if trackedNPCs[npcModel] then return end

	local head = npcModel:FindFirstChild("Head")
	local torso = npcModel:FindFirstChild("Torso")
	if not head or not torso then return end

	local neck = torso:FindFirstChild("Neck")
	if not neck then return end

	-- Find the SurfaceGui part under Torso
	local surfaceGuiPart = torso:FindFirstChild("Part")

	-- Store original neck C0 and SurfaceGui CFrame
	trackedNPCs[npcModel] = {
		head = head,
		neck = neck,
		surfaceGuiPart = surfaceGuiPart,
		originalNeckC0 = neck.C0,
		originalSurfaceGuiCFrame = surfaceGuiPart and surfaceGuiPart.CFrame or nil,
		currentNeckTween = nil,
		currentSurfaceGuiTween = nil,
		isTracking = false
	}
end

-- Update NPC head to face player
local function updateNPCHead(npcModel, shouldTrack)
	local npcData = trackedNPCs[npcModel]
	if not npcData then return end

	local playerRoot = Client.Character and Client.Character:FindFirstChild("HumanoidRootPart")
	local playerHead = Client.Character and Client.Character:FindFirstChild("Head")

	-- Cancel previous tweens if they exist
	if npcData.currentNeckTween then
		npcData.currentNeckTween:Cancel()
		npcData.currentNeckTween = nil
	end
	if npcData.currentSurfaceGuiTween then
		npcData.currentSurfaceGuiTween:Cancel()
		npcData.currentSurfaceGuiTween = nil
	end

	if shouldTrack and playerHead then
		-- Calculate direction to player's head
		local direction = npcData.head.CFrame:ToObjectSpace(
			CFrame.new(npcData.head.Position, playerHead.Position)
		).LookVector

		-- Calculate neck rotation with restrictions
		local neckRotation = npcData.originalNeckC0 * CFrame.Angles(
			-math.asin(direction.Y) * VERTICAL_RESTRICTION,
			0,
			-math.asin(direction.X) * HORIZONTAL_RESTRICTION
		)

		-- Create tween to rotate head
		npcData.currentNeckTween = TweenService:Create(
			npcData.neck,
			TweenInfo.new(ROTATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ C0 = neckRotation }
		)
		npcData.currentNeckTween:Play()

		-- Also rotate the SurfaceGui part if it exists
		if npcData.surfaceGuiPart and playerRoot then
			local surfaceGuiPos = npcData.surfaceGuiPart.Position
			local playerPos = playerRoot.Position

			-- Create a lookAt CFrame for the SurfaceGui part
			local lookVector = (playerPos - surfaceGuiPos) * Vector3.new(1, 0, 1) -- Flatten to XZ plane
			if lookVector.Magnitude > 0 then
				lookVector = lookVector.Unit
				local surfaceGuiTargetCFrame = CFrame.new(surfaceGuiPos, surfaceGuiPos + lookVector)

				npcData.currentSurfaceGuiTween = TweenService:Create(
					npcData.surfaceGuiPart,
					TweenInfo.new(ROTATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ CFrame = surfaceGuiTargetCFrame }
				)
				npcData.currentSurfaceGuiTween:Play()
			end
		end

		npcData.isTracking = true
	else
		-- Reset to original orientation
		if npcData.isTracking then
			-- Reset neck
			npcData.currentNeckTween = TweenService:Create(
				npcData.neck,
				TweenInfo.new(ROTATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ C0 = npcData.originalNeckC0 }
			)
			npcData.currentNeckTween:Play()

			-- Reset SurfaceGui part if it exists
			if npcData.surfaceGuiPart and npcData.originalSurfaceGuiCFrame then
				npcData.currentSurfaceGuiTween = TweenService:Create(
					npcData.surfaceGuiPart,
					TweenInfo.new(ROTATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ CFrame = npcData.originalSurfaceGuiCFrame }
				)
				npcData.currentSurfaceGuiTween:Play()
			end

			npcData.isTracking = false
		end
	end
end

-- Main update loop
local function updateBodyTracking()
	if not active then return end
	
	local currentTime = os.clock()
	if currentTime - lastUpdateTime < UPDATE_INTERVAL then
		return
	end
	lastUpdateTime = currentTime
	
	-- Get all dialogue NPCs
	local npcs = getDialogueNPCs()
	
	-- Clean up removed NPCs
	for npcModel, _ in pairs(trackedNPCs) do
		if not npcModel.Parent then
			trackedNPCs[npcModel] = nil
		end
	end
	
	-- Update each NPC
	for _, npcModel in npcs do
		-- Initialize if not tracked
		initializeNPC(npcModel)

		-- Check if player is in range
		local inRange = isPlayerInRange(npcModel)

		-- Update head to face player (or reset if out of range)
		updateNPCHead(npcModel, inRange)
	end
end

-- Start the system
NPCBodyTracking.Start = function()
	if active then return end

	--print("[NPCHeadTracking] 🎯 Starting NPC head tracking system...")

	active = true

	-- Connect to RenderStepped for smooth client-side updates
	RunService.RenderStepped:Connect(updateBodyTracking)

	--print("[NPCHeadTracking] ✅ NPC head tracking system started!")
end

return NPCBodyTracking

