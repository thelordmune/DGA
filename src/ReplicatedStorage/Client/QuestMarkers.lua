--[[
	Quest Marker System
	
	Displays visual markers above quest NPCs and quest objectives in the game world.
	
	Features:
	- Gold "!" for available/active quests
	- Green "?" for quest turn-in
	- Blue star for quest objectives
	- Off-screen directional arrows
	- Distance-based visibility
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local scoped = Fusion.scoped

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Marker configuration
local MARKER_CONFIG = {
	questAvailable = {
		type = "quest",
		color = Color3.fromRGB(255, 255, 255), -- Gold
		icon = "rbxassetid://18621831828",
	},
	questActive = {
		type = "quest",
		color = Color3.fromRGB(143, 255, 143), -- Green
		icon = "rbxassetid://18621831828",
	},
	questObjective = {
		type = "objective",
		color = Color3.fromRGB(121, 197, 255), -- Blue
		icon = "rbxassetid://18621831828",
	},
	waypoint = {
		type = "waypoint",
		color = Color3.fromRGB(255, 255, 255), -- White
		icon = "rbxassetid://18621831828",
	},
}

-- Store marker scopes for cleanup
local markerScopes = {}

-- Calculate distance from player to a position
local function getDistanceToPlayer(position: Vector3): number
	local character = player.Character
	if not character or not character.PrimaryPart then
		return math.huge
	end
	return (character.PrimaryPart.Position - position).Magnitude
end

-- Convert world position to screen position with off-screen handling
local function worldToScreen(worldPosition: Vector3): (UDim2, boolean, number?)
	local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPosition)

	-- Check if marker is in front of camera (Z > 0) and within screen bounds
	local screenSize = camera.ViewportSize
	local isInBounds = viewportPoint.Z > 0
		and viewportPoint.X >= 0 and viewportPoint.X <= screenSize.X
		and viewportPoint.Y >= 0 and viewportPoint.Y <= screenSize.Y

	if isInBounds then
		return UDim2.fromOffset(viewportPoint.X, viewportPoint.Y), true, nil
	else
		-- Marker is off-screen or behind camera
		local screenCenter = Vector2.new(screenSize.X / 2, screenSize.Y / 2)

		-- If marker is behind camera (Z <= 0), flip the direction
		local screenPoint = Vector2.new(viewportPoint.X, viewportPoint.Y)
		if viewportPoint.Z <= 0 then
			-- Marker is behind camera, flip the screen point to opposite side
			screenPoint = screenCenter - (screenPoint - screenCenter)
		end

		local direction = (screenPoint - screenCenter)
		local directionMagnitude = direction.Magnitude

		if directionMagnitude > 0 then
			direction = direction / directionMagnitude -- Normalize
		else
			direction = Vector2.new(0, -1) -- Default to pointing up if at center
		end

		-- Clamp to screen edges with margin
		local margin = 50
		local maxX = screenSize.X / 2 - margin
		local maxY = screenSize.Y / 2 - margin

		local x = screenCenter.X + direction.X * maxX
		local y = screenCenter.Y + direction.Y * maxY

		-- Ensure within bounds
		x = math.clamp(x, margin, screenSize.X - margin)
		y = math.clamp(y, margin, screenSize.Y - margin)

		-- Calculate rotation angle (pointing from screen edge toward marker)
		-- atan2(y, x) gives angle in radians, convert to degrees
		-- Add 90 to make arrow point up by default (since arrow image points up at 0°)
		local angle = math.atan2(direction.Y, direction.X)
		local rotation = math.deg(angle) + 90

		return UDim2.fromOffset(x, y), false, rotation
	end
end

-- Create a marker for an NPC or object
local function createNPCMarker(target: Model | BasePart, markerType: string, questName: string?)
	---- --print(`[QuestMarkers] 🎯 createNPCMarker called for {target.Name}, type={markerType}, quest={questName or "none"}`)

	local targetRoot: BasePart? = nil

	if target:IsA("Model") then
		targetRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso") or target.PrimaryPart
	elseif target:IsA("BasePart") then
		targetRoot = target
	end

	if not targetRoot then
		warn("[QuestMarkers] Target missing valid part:", target.Name)
		return
	end

	---- --print(`[QuestMarkers]   ✅ Found targetRoot: {targetRoot.Name}`)

	local config = MARKER_CONFIG[markerType]
	if not config then
		warn("[QuestMarkers] Invalid marker type:", markerType)
		return
	end

	---- --print(`[QuestMarkers]   ✅ Config found: type={config.type}, icon={config.icon}`)

	-- Create a unique key for this marker
	local markerKey = target.Name .. "_" .. markerType

	---- --print(`[QuestMarkers]   🔑 Marker key: {markerKey}`)

	-- Clean up existing marker if it exists
	if markerScopes[markerKey] then
		---- --print(`[QuestMarkers]   🗑️ Cleaning up existing marker`)
		markerScopes[markerKey]:doCleanup()
		markerScopes[markerKey] = nil
	end

	-- Create new scope for this marker
	local markerScope = scoped(Fusion, {
		MarkerIcon = require(ReplicatedStorage.Client.Components.MarkerIcon),
	})

	---- --print(`[QuestMarkers]   ✅ Created marker scope`)

	-- Create reactive values
	local position = markerScope:Value(UDim2.fromScale(0.5, 0.5))
	local distance = markerScope:Value(0)
	local visible = markerScope:Value(true)
	local showArrow = markerScope:Value(false)
	local arrowRotation = markerScope:Value(0)

	-- Create the marker UI
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QuestMarker_" .. markerKey
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 100
	screenGui.Enabled = true

	local playerGui = player:WaitForChild("PlayerGui")
	screenGui.Parent = playerGui

	---- --print(`[QuestMarkers]   ✅ Created ScreenGui: {screenGui.Name}, Enabled={screenGui.Enabled}, Parent={screenGui.Parent.Name}`)

	markerScope:MarkerIcon({
		Type = config.type,
		Color = config.color,
		Icon = config.icon,
		Label = questName or target.Name,
		Position = position,
		Distance = distance,
		Visible = visible,
		ShowArrow = showArrow,
		ArrowRotation = arrowRotation,
		Parent = screenGui,
	})

	---- --print(`[QuestMarkers]   ✅ Created MarkerIcon component`)

	-- Update marker position and visibility every frame
	local frameCount = 0
	local updateConnection = RunService.RenderStepped:Connect(function()
		frameCount += 1

		-- Check if target still exists
		if not target or not target.Parent or not targetRoot.Parent then
			---- --print(`[QuestMarkers]   ⚠️ Target {target.Name} no longer exists, cleaning up marker`)
			markerScopes[markerKey]:doCleanup()
			markerScopes[markerKey] = nil
			return
		end

		-- Calculate marker position above target's head
		local markerWorldPos = targetRoot.Position + Vector3.new(0, 5, 0)
		local dist = getDistanceToPlayer(markerWorldPos)
		local screenPos, onScreen, rotation = worldToScreen(markerWorldPos)

		-- Update reactive values
		distance:set(dist)
		position:set(screenPos)
		visible:set(dist < 500) -- Only show markers within 500 studs
		showArrow:set(not onScreen)
		if rotation then
			arrowRotation:set(rotation)
		end

		-- Debug every 60 frames (once per second at 60fps)
		if frameCount % 60 == 0 then
			---- --print(`[QuestMarkers]   🔄 Update: dist={math.floor(dist)}, screenPos={screenPos}, onScreen={onScreen}, visible={dist < 500}`)
		end
	end)

	---- --print(`[QuestMarkers]   ✅ Connected RenderStepped update loop`)

	-- Store cleanup function and references for enable/disable
	table.insert(markerScope, updateConnection)
	table.insert(markerScope, screenGui)
	markerScope.screenGui = screenGui
	markerScope.visible = visible

	markerScopes[markerKey] = markerScope

	---- --print(`[QuestMarkers]   ✅ Marker fully created and stored with key: {markerKey}`)
end

-- Remove a marker for an NPC
local function removeNPCMarker(npcName: string, markerType: string)
	local markerKey = npcName .. "_" .. markerType

	if markerScopes[markerKey] then
		markerScopes[markerKey]:doCleanup()
		markerScopes[markerKey] = nil
	end
end

-- Update quest objective markers (for items in the world)
-- DISABLED: Quest items should NOT show markers
local function updateQuestObjectiveMarkers()
	-- Clean up any existing objective markers
	for key, scope in pairs(markerScopes) do
		if key:match("_questObjective$") then
			scope:doCleanup()
			markerScopes[key] = nil
		end
	end
end

-- Helper function to find NPC model in the world
local function findNPCModel(npcName: string): Model?
	-- Check workspace.World.Dialogue first (static NPCs)
	local dialogueFolder = Workspace.World:FindFirstChild("Dialogue")
	if dialogueFolder then
		local npc = dialogueFolder:FindFirstChild(npcName)
		if npc and npc:IsA("Model") and npc:FindFirstChild("HumanoidRootPart") then
			---- --print(`[QuestMarkers] ✅ Found {npcName} in workspace.World.Dialogue`)
			return npc
		end
	end

	-- Check workspace.World.Live regions (spawned NPCs)
	local liveFolder = Workspace.World:FindFirstChild("Live")
	if liveFolder then
		for _, region in liveFolder:GetChildren() do
			local npcsFolder = region:FindFirstChild("NPCs")
			if npcsFolder then
				for _, npcFile in npcsFolder:GetChildren() do
					-- Check if this NPC file matches the name we're looking for
					local setName = npcFile:GetAttribute("SetName")
					local defaultName = npcFile:GetAttribute("DefaultName")

					if setName == npcName or defaultName == npcName then
						-- Find the actual NPC model inside the Actor
						local actor = npcFile:FindFirstChild("Actor")
						if actor then
							local npcModel = actor:FindFirstChildOfClass("Model")
							if npcModel and npcModel:FindFirstChild("HumanoidRootPart") then
								---- --print(`[QuestMarkers] ✅ Found {npcName} in workspace.World.Live.{region.Name}`)
								return npcModel
							end
						end
					end
				end
			end
		end
	end

	---- --print(`[QuestMarkers] ❌ Could not find NPC: {npcName}`)
	return nil
end

-- Update markers based on player's quest state
local function updateQuestMarkers()
	local playerEntity = ref.get("local_player")
	if not playerEntity then
		---- --print("[QuestMarkers] ⚠️ No player entity found")
		return
	end

	-- Get player's active quest
	local activeQuest = nil
	if world:has(playerEntity, comps.ActiveQuest) then
		activeQuest = world:get(playerEntity, comps.ActiveQuest)
		---- --print(`[QuestMarkers] 📋 Active quest: {activeQuest.questName} from {activeQuest.npcName}`)
	else
		---- --print("[QuestMarkers] 📋 No active quest")
	end

	local hasQuestItem = world:has(playerEntity, comps.QuestItemCollected)
	if hasQuestItem then
		---- --print("[QuestMarkers] ✅ Player has quest item")
	end

	-- Get all quest NPCs from quest data
	local QuestData = require(ReplicatedStorage.Modules.Quests)

	-- Count quest NPCs (QuestData is a dictionary, not an array)
	local questNPCCount = 0
	for _ in pairs(QuestData) do
		questNPCCount += 1
	end

	---- --print(`[QuestMarkers] 🔍 Checking {questNPCCount} quest NPCs...`)

	-- Track which markers should be active
	local activeMarkers = {}

	for npcName, _ in pairs(QuestData) do
		---- --print(`[QuestMarkers] Looking for NPC: {npcName}`)

		-- Find the NPC model in the world
		local npcModel = findNPCModel(npcName)

		if npcModel then
			local markerType = nil
			local questName = nil

			if activeQuest and activeQuest.npcName == npcName then
				-- This NPC has the player's active quest
				if hasQuestItem then
					-- Player has quest item, show turn-in marker (green ?)
					---- --print(`[QuestMarkers]   🟢 Enabling turn-in marker for {npcName}`)
					markerType = "questActive"
					questName = activeQuest.questName
				else
					-- Quest is active but not complete, don't show marker
					-- Player needs to find the quest item first
					---- --print(`[QuestMarkers]   ⚪ Quest active but item not collected - no marker for {npcName}`)
					markerType = nil
				end
			else
				-- NPC has a quest and player doesn't have an active quest
				if not activeQuest then
					---- --print(`[QuestMarkers]   🟡 Enabling available quest marker for {npcName}`)
					markerType = "questAvailable"
					questName = "New Quest"
				end
			end

			if markerType then
				local markerKey = npcName .. "_" .. markerType
				activeMarkers[markerKey] = true

				-- Create marker if it doesn't exist, otherwise just enable it
				if not markerScopes[markerKey] then
					createNPCMarker(npcModel, markerType, questName)
				else
					-- Marker exists, just make sure it's enabled
					local scope = markerScopes[markerKey]
					if scope.screenGui then
						scope.screenGui.Enabled = true
					end
					if scope.visible then
						scope.visible:set(true)
					end
				end
			end
		end
	end

	-- Disable markers that shouldn't be active
	for markerKey, scope in pairs(markerScopes) do
		if not activeMarkers[markerKey] then
			---- --print(`[QuestMarkers]   💤 Disabling marker: {markerKey}`)
			if scope.screenGui then
				scope.screenGui.Enabled = false
			end
			if scope.visible then
				scope.visible:set(false)
			end
		end
	end

	-- Update quest objective markers
	updateQuestObjectiveMarkers()
end

local QuestMarkers = {}

function QuestMarkers.Init()
	-- Wait for character to load
	task.spawn(function()
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(1) -- Wait for character to fully load
		-- Disabled automatic NPC quest markers
		-- Only waypoint markers created manually via QuestHandler will be shown
		-- updateQuestMarkers()
	end)

	-- Disabled automatic marker updates
	-- Quest markers are now only created manually via CreateWaypoint()
	--[[
	task.spawn(function()
		while task.wait(1) do
			updateQuestMarkers()
		end
	end)
	]]

	-- Initial update disabled
	-- task.wait(2)
	-- updateQuestMarkers()

	--print("[QuestMarkers] ✅ Initialized (automatic NPC markers disabled)")
end

-- Cleanup all markers (called on death)
function QuestMarkers.Cleanup()
	--print("[QuestMarkers] 🧹 Cleaning up all markers...")
	for markerKey, scope in pairs(markerScopes) do
		if scope and scope.doCleanup then
			scope:doCleanup()
		end
	end
	table.clear(markerScopes)
	--print("[QuestMarkers] ✅ All markers cleaned up")
end

--[[
	Create a custom waypoint marker on a part

	@param part - The BasePart or Model to place the marker on
	@param label - Optional label text for the marker (defaults to part name)
	@param config - Optional configuration table with:
		- color: Color3 (default: white)
		- icon: string asset ID (default: star icon)
		- heightOffset: number (default: 5 studs above part)
		- maxDistance: number (default: 500 studs)
	@return markerKey - String key that can be used to remove the marker later
]]
function QuestMarkers.CreateWaypoint(part: Model | BasePart, label: string?, config: {
	color: Color3?,
	icon: string?,
	heightOffset: number?,
	maxDistance: number?
}?): string?
	if not part or not part.Parent then
		warn("[QuestMarkers] Cannot create waypoint: invalid part")
		return nil
	end

	-- Get or create config
	local waypointConfig = config or {}
	local markerColor = waypointConfig.color or Color3.fromRGB(255, 255, 255)
	local markerIcon = waypointConfig.icon or "rbxassetid://18621831828"
	local heightOffset = waypointConfig.heightOffset or 5
	local maxDistance = waypointConfig.maxDistance or 500

	-- Find the root part
	local targetRoot: BasePart? = nil
	if part:IsA("Model") then
		targetRoot = part:FindFirstChild("HumanoidRootPart") or part:FindFirstChild("Torso") or part.PrimaryPart
	elseif part:IsA("BasePart") then
		targetRoot = part
	end

	if not targetRoot then
		warn("[QuestMarkers] Cannot create waypoint: part has no valid root")
		return nil
	end

	-- Create unique marker key
	local markerKey = "waypoint_" .. targetRoot:GetFullName():gsub("%.", "_")

	-- Clean up existing marker if it exists
	if markerScopes[markerKey] then
		markerScopes[markerKey]:doCleanup()
		markerScopes[markerKey] = nil
	end

	-- Create new scope for this marker
	local markerScope = scoped(Fusion, {
		MarkerIcon = require(ReplicatedStorage.Client.Components.MarkerIcon),
	})

	-- Create reactive values
	local position = markerScope:Value(UDim2.fromScale(0.5, 0.5))
	local distance = markerScope:Value(0)
	local visible = markerScope:Value(true)
	local showArrow = markerScope:Value(false)
	local arrowRotation = markerScope:Value(0)

	-- Create the marker UI
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QuestMarker_" .. markerKey
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 100
	screenGui.Enabled = true

	local playerGui = player:WaitForChild("PlayerGui")
	screenGui.Parent = playerGui

	markerScope:MarkerIcon({
		Type = "waypoint",
		Color = markerColor,
		Icon = markerIcon,
		Label = label or part.Name,
		Position = position,
		Distance = distance,
		Visible = visible,
		ShowArrow = showArrow,
		ArrowRotation = arrowRotation,
		Parent = screenGui,
	})

	-- Update marker position and visibility every frame
	local updateConnection = RunService.RenderStepped:Connect(function()
		-- Check if target still exists
		if not part or not part.Parent or not targetRoot.Parent then
			markerScopes[markerKey]:doCleanup()
			markerScopes[markerKey] = nil
			return
		end

		-- Calculate marker position above target
		local markerWorldPos = targetRoot.Position + Vector3.new(0, heightOffset, 0)
		local dist = getDistanceToPlayer(markerWorldPos)
		local screenPos, onScreen, rotation = worldToScreen(markerWorldPos)

		-- Update reactive values
		distance:set(dist)
		position:set(screenPos)
		visible:set(dist < maxDistance)
		showArrow:set(not onScreen)
		if rotation then
			arrowRotation:set(rotation)
		end
	end)

	-- Store cleanup function
	table.insert(markerScope, updateConnection)
	table.insert(markerScope, screenGui)
	markerScope.screenGui = screenGui
	markerScope.visible = visible

	markerScopes[markerKey] = markerScope

	--print(`[QuestMarkers] ✅ Created waypoint marker: {markerKey}`)
	return markerKey
end

--[[
	Remove a custom waypoint marker

	@param markerKey - The key returned from CreateWaypoint, or the part itself
]]
function QuestMarkers.RemoveWaypoint(markerKey: string | Model | BasePart)
	local key: string

	-- If a part was passed, generate the key from it
	if typeof(markerKey) ~= "string" then
		local part = markerKey
		local targetRoot: BasePart? = nil

		if part:IsA("Model") then
			targetRoot = part:FindFirstChild("HumanoidRootPart") or part:FindFirstChild("Torso") or part.PrimaryPart
		elseif part:IsA("BasePart") then
			targetRoot = part
		end

		if not targetRoot then
			warn("[QuestMarkers] Cannot remove waypoint: invalid part")
			return
		end

		key = "waypoint_" .. targetRoot:GetFullName():gsub("%.", "_")
	else
		key = markerKey
	end

	if markerScopes[key] then
		markerScopes[key]:doCleanup()
		markerScopes[key] = nil
		--print(`[QuestMarkers] 🗑️ Removed waypoint marker: {key}`)
	else
		warn(`[QuestMarkers] Cannot remove waypoint: marker not found ({key})`)
	end
end

return QuestMarkers

