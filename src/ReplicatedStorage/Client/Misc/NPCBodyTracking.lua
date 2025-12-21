local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Client = require(script.Parent.Parent)

local NPCBodyTracking = {}

local DETECTION_RANGE = 15
local UPDATE_INTERVAL = 0.1
local ROTATION_SPEED = 0.25
local VERTICAL_RESTRICTION = 0.75
local HORIZONTAL_RESTRICTION = 0.75

local trackedNPCs = {}
local lastUpdateTime = 0
local active = false

local function getTrackableNPCs()
	local npcs = {}

	-- Get NPCs from Dialogue folder (quest givers, shopkeepers, etc.)
	local dialogueFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Dialogue")
	if dialogueFolder then
		for _, npc in dialogueFolder:GetChildren() do
			if npc:IsA("Model") and npc:FindFirstChild("Humanoid") and npc:FindFirstChild("HumanoidRootPart") then
				table.insert(npcs, npc)
			end
		end
	end

	-- Get wandering NPCs from Live folder (citizens)
	local liveFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Live")
	if liveFolder then
		for _, npc in liveFolder:GetChildren() do
			-- Check if it's a wanderer NPC (has IsWandererNPC attribute or name contains "Wanderer")
			if npc:IsA("Model") and npc:FindFirstChild("Humanoid") and npc:FindFirstChild("HumanoidRootPart") then
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local isWanderer = (hrp and hrp:GetAttribute("IsWandererNPC")) or npc.Name:lower():find("wanderer")
				-- Only track if player is nearby (TrackPlayer attribute set by proximity system)
				local shouldTrack = npc:GetAttribute("TrackPlayer")
				if isWanderer and shouldTrack then
					table.insert(npcs, npc)
				end
			end
		end
	end

	return npcs
end

local function isPlayerInRange(npcModel)
	if not Client.Character then
		return false
	end

	local playerRoot = Client.Character:FindFirstChild("HumanoidRootPart")
	local playerHumanoid = Client.Character:FindFirstChild("Humanoid")
	local npcRoot = npcModel:FindFirstChild("HumanoidRootPart")

	if not playerRoot or not playerHumanoid or not npcRoot then
		return false
	end
	if playerHumanoid.Health <= 0 then
		return false
	end

	local distance = (playerRoot.Position - npcRoot.Position).Magnitude
	return distance <= DETECTION_RANGE
end

local function initializeNPC(npcModel)
	if trackedNPCs[npcModel] then
		return
	end

	local head = npcModel:FindFirstChild("Head")
	local torso = npcModel:FindFirstChild("Torso")
	if not head or not torso then
		return
	end

	local neck = torso:FindFirstChild("Neck")
	if not neck then
		return
	end

	local surfaceGuiPart = torso:FindFirstChild("Part")

	trackedNPCs[npcModel] = {
		head = head,
		neck = neck,
		surfaceGuiPart = surfaceGuiPart,
		originalNeckC0 = neck.C0,
		originalSurfaceGuiCFrame = surfaceGuiPart and surfaceGuiPart.CFrame or nil,
		currentNeckTween = nil,
		currentSurfaceGuiTween = nil,
		isTracking = false,
	}
end

local function updateNPCHead(npcModel, shouldTrack)
	local npcData = trackedNPCs[npcModel]
	if not npcData then
		return
	end

	local playerRoot = Client.Character and Client.Character:FindFirstChild("HumanoidRootPart")
	local playerHead = Client.Character and Client.Character:FindFirstChild("Head")

	if npcData.currentNeckTween then
		npcData.currentNeckTween:Cancel()
		npcData.currentNeckTween = nil
	end
	if npcData.currentSurfaceGuiTween then
		npcData.currentSurfaceGuiTween:Cancel()
		npcData.currentSurfaceGuiTween = nil
	end

	if shouldTrack and playerHead then
		local direction =
			npcData.head.CFrame:ToObjectSpace(CFrame.new(npcData.head.Position, playerHead.Position)).LookVector

		local neckRotation = npcData.originalNeckC0
			* CFrame.Angles(
				-math.asin(direction.Y) * VERTICAL_RESTRICTION,
				0,
				-math.asin(direction.X) * HORIZONTAL_RESTRICTION
			)

		npcData.currentNeckTween = TweenService:Create(
			npcData.neck,
			TweenInfo.new(ROTATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ C0 = neckRotation }
		)
		npcData.currentNeckTween:Play()

		if npcData.surfaceGuiPart and playerRoot then
			local surfaceGuiPos = npcData.surfaceGuiPart.Position
			local playerPos = playerRoot.Position

			local lookVector = (playerPos - surfaceGuiPos) * Vector3.new(1, 0, 1)
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
		if npcData.isTracking then
			npcData.currentNeckTween = TweenService:Create(
				npcData.neck,
				TweenInfo.new(ROTATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ C0 = npcData.originalNeckC0 }
			)
			npcData.currentNeckTween:Play()

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

local function updateBodyTracking()
	if not active then
		return
	end

	local currentTime = os.clock()
	if currentTime - lastUpdateTime < UPDATE_INTERVAL then
		return
	end
	lastUpdateTime = currentTime

	local npcs = getTrackableNPCs()

	for npcModel, _ in pairs(trackedNPCs) do
		if not npcModel.Parent then
			trackedNPCs[npcModel] = nil
		end
	end

	for _, npcModel in npcs do
		initializeNPC(npcModel)

		local inRange = isPlayerInRange(npcModel)

		updateNPCHead(npcModel, inRange)
	end
end

NPCBodyTracking.Start = function()
	if active then
		return
	end

	active = true

	RunService.RenderStepped:Connect(updateBodyTracking)
end

return NPCBodyTracking
