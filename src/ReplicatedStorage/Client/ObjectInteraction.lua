--[[
	Object Interaction Module

	Detects proximity to interactable objects and shows E prompt.
	Checks workspace for objects with Interactable attribute.
]]

local ObjectInteraction = {}
local CSystem = require(script.Parent)

local TweenService = CSystem.Service.TweenService
local RunService = CSystem.Service.RunService
local ReplicatedStorage = CSystem.Service.ReplicatedStorage
local Players = CSystem.Service.Players

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local scoped = Fusion.scoped

local player = Players.LocalPlayer

-- Settings
local DETECTION_RANGE = 10
local CHECK_INTERVAL = 0.5

-- State tracking
local currentNearbyObject = nil
local currentHighlight = nil
local promptScope = nil
local promptStarted = nil
local promptFadeIn = nil
local promptTextStart = nil
local lastCheckTime = 0
local character = nil

-- Create the prompt UI on a SurfaceGui on the object
local function createPromptUI(obj, promptText)
	-- Clean up old scope if it exists
	if promptScope then
		promptScope:doCleanup()
	end

	-- Find the primary part (for models) or use the object itself (for parts)
	local primaryPart = obj:IsA("Model") and obj.PrimaryPart or obj
	if not primaryPart then
		warn("[ObjectInteraction] No PrimaryPart found for:", obj.Name, "IsModel:", obj:IsA("Model"))
		return
	end

	-- Find or create a SurfaceGui
	local surfaceGui = primaryPart:FindFirstChild("PromptSurfaceGui")
	if not surfaceGui then
		surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "PromptSurfaceGui"
		surfaceGui.Face = Enum.NormalId.Top
		surfaceGui.Parent = primaryPart
		surfaceGui.AlwaysOnTop = true
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfaceGui.PixelsPerStud = 50
	end

	-- Create Fusion scope with Prompt component
	promptScope = scoped(Fusion, {
		Prompt = require(ReplicatedStorage.Client.Components.Prompt),
	})

	-- Create reactive values for animation states
	promptStarted = promptScope:Value(false)
	promptFadeIn = promptScope:Value(false)
	promptTextStart = promptScope:Value(false)

	-- Create the Prompt component with object name
	promptScope:Prompt({
		begin = promptStarted,
		fadein = promptFadeIn,
		textstart = promptTextStart,
		npcName = promptText or obj.Name,
		Parent = surfaceGui,
	})
end

-- Show the prompt UI with animation
local function showPromptUI()
	if promptStarted then
		promptStarted:set(true)
	end
end

-- Hide the prompt UI with animation
local function hidePromptUI()
	if promptStarted then
		promptStarted:set(false)
	end
end

-- Add highlight to object
local function addHighlight(obj)
	-- Remove existing highlight if any
	if currentHighlight then
		currentHighlight:Destroy()
	end

	-- Create new highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "InteractHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.Parent = obj

	-- Fade in the outline
	local tween = TweenService:Create(
		highlight,
		TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
		{ OutlineTransparency = 0 }
	)
	tween:Play()

	currentHighlight = highlight
end

-- Remove highlight from object
local function removeHighlight()
	if not currentHighlight then return end

	-- Fade out the outline
	local tween = TweenService:Create(
		currentHighlight,
		TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
		{ OutlineTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function()
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
	end)
end

-- Find all interactable objects in workspace recursively
local function findInteractableObjects()
	local interactables = {}

	local function searchFolder(folder)
		for _, obj in ipairs(folder:GetChildren()) do
			if obj:GetAttribute("Interactable") == true then
				table.insert(interactables, obj)
			end
			-- Search children if it's a folder/model
			if obj:IsA("Folder") or obj:IsA("Model") then
				searchFolder(obj)
			end
		end
	end

	searchFolder(workspace)
	return interactables
end

-- Find closest interactable object
local function findClosestObject()
	if not character then return nil end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local closestObject = nil
	local closestDistance = DETECTION_RANGE

	-- Get all interactable objects
	local interactables = findInteractableObjects()

	for _, obj in ipairs(interactables) do
		-- Get the position of the object
		local objPosition
		if obj:IsA("Model") then
			local primaryPart = obj.PrimaryPart
			if primaryPart then
				objPosition = primaryPart.Position
			end
		elseif obj:IsA("BasePart") then
			objPosition = obj.Position
		end

		if objPosition then
			local distance = (rootPart.Position - objPosition).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestObject = obj
			end
		end
	end

	return closestObject
end

-- Update proximity detection
local function updateProximity()
	local closestObject = findClosestObject()

	if closestObject ~= currentNearbyObject then
		-- Clean up previous object
		if currentNearbyObject then
			removeHighlight()
			hidePromptUI()
			if character then
				character:SetAttribute("NearbyObject", nil)
				character:SetAttribute("CanInteract", false)
			end
		end

		-- Set up new object
		currentNearbyObject = closestObject
		if closestObject then
			-- Get interactable data from attributes
			local promptText = closestObject:GetAttribute("PromptText") or "Interact"
			local objectId = closestObject:GetAttribute("ObjectId") or closestObject.Name

			createPromptUI(closestObject, promptText)
			showPromptUI()
			addHighlight(closestObject)
			if character then
				character:SetAttribute("NearbyObject", objectId)
				character:SetAttribute("CanInteract", true)
			end
		end
	end
end

-- Initialize
task.spawn(function()
	repeat task.wait() until game:IsLoaded()

	character = player.Character or player.CharacterAdded:Wait()

	-- Update character reference when respawning
	player.CharacterAdded:Connect(function(newCharacter)
		character = newCharacter
		-- Clean up any existing effects
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
		if promptScope then
			promptScope:doCleanup()
			promptScope = nil
			promptStarted = nil
			promptFadeIn = nil
			promptTextStart = nil
		end
		currentNearbyObject = nil
	end)

	-- Make hidePromptUI accessible globally for input handler
	_G.ObjectInteraction_HidePrompt = hidePromptUI

	-- Main proximity checking loop
	RunService.Heartbeat:Connect(function()
		local currentTime = tick()
		if currentTime - lastCheckTime >= CHECK_INTERVAL then
			lastCheckTime = currentTime
			updateProximity()
		end
	end)
end)

return ObjectInteraction
