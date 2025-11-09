--[[
	Simple Dialogue Proximity System
	Replaces the ECS dialogue checker with a straightforward proximity detection
	Shows Prompt UI on a SurfaceGui next to NPCs
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local scoped = Fusion.scoped

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Settings
local DETECTION_RANGE = 10 -- Distance to detect NPCs
local CHECK_INTERVAL = 0.5 -- How often to check (in seconds)

-- State tracking
local currentNearbyNPC = nil
local currentHighlight = nil
local promptScope = nil -- Fusion scope for prompt UI
local promptStarted = nil -- Fusion value for animation state
local promptFadeIn = nil -- Fusion value for fade in state
local promptTextStart = nil -- Fusion value for text animation state
local lastCheckTime = 0

-- Wait for game to load
repeat task.wait() until game:IsLoaded()

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
	currentNearbyNPC = nil
end)

-- Create the prompt UI on a SurfaceGui next to the NPC
local function createPromptUI(npc)
	-- Clean up old scope if it exists
	if promptScope then
		promptScope:doCleanup()
	end

	-- Find or create a SurfaceGui on the NPC's head
	local head = npc:FindFirstChild("Torso").Part
	local surfaceGui = head and head:FindFirstChild("PromptSurfaceGui")
	if not surfaceGui and head then
		surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "PromptSurfaceGui"
		surfaceGui.Face = Enum.NormalId.Front
		surfaceGui.Parent = head
		surfaceGui.AlwaysOnTop = true
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfaceGui.PixelsPerStud = 50
	end

	if not surfaceGui then return end

	-- Create Fusion scope with Prompt component
	promptScope = scoped(Fusion, {
		Prompt = require(ReplicatedStorage.Client.Components.Prompt),
	})

	-- Create reactive values for animation states
	promptStarted = promptScope:Value(false)
	promptFadeIn = promptScope:Value(false)
	promptTextStart = promptScope:Value(false)

	-- Create the Prompt component with NPC name
	promptScope:Prompt({
		begin = promptStarted,
		fadein = promptFadeIn,
		textstart = promptTextStart,
		npcName = npc.Name, -- Pass the NPC name
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

-- Add highlight to NPC
local function addHighlight(npc)
	-- Remove existing highlight if any
	if currentHighlight then
		currentHighlight:Destroy()
	end
	
	-- Create new highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "DialogueHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.Parent = npc
	
	-- Fade in the outline
	local tween = TweenService:Create(
		highlight,
		TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
		{OutlineTransparency = 0}
	)
	tween:Play()
	
	currentHighlight = highlight
end

-- Remove highlight from NPC
local function removeHighlight()
	if not currentHighlight then return end
	
	-- Fade out the outline
	local tween = TweenService:Create(
		currentHighlight,
		TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
		{OutlineTransparency = 1}
	)
	tween:Play()
	tween.Completed:Connect(function()
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
	end)
end

-- Find nearby NPC
local function findNearbyNPC()
	if not character then return nil end
	
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	
	local dialogueFolder = workspace.World:FindFirstChild("Dialogue")
	if not dialogueFolder then
		return nil
	end
	
	-- Find closest NPC within range
	local closestNPC = nil
	local closestDistance = DETECTION_RANGE
	
	for _, npc in dialogueFolder:GetChildren() do
		local npcRoot = npc:FindFirstChild("HumanoidRootPart")
		if npcRoot then
			local distance = (root.Position - npcRoot.Position).Magnitude
			if distance <= closestDistance then
				closestNPC = npc
				closestDistance = distance
			end
		end
	end
	
	return closestNPC
end

-- Update proximity effects
local function updateProximity()
	local nearbyNPC = findNearbyNPC()

	-- NPC state changed
	if nearbyNPC ~= currentNearbyNPC then
		if nearbyNPC then
			-- Entered range of an NPC
			-- print("📍 Near NPC:", nearbyNPC.Name)
			addHighlight(nearbyNPC)
			createPromptUI(nearbyNPC)
			showPromptUI()

			-- Set attribute for other systems to use
			if character then
				character:SetAttribute("Commence", true)
				character:SetAttribute("NearbyNPC", nearbyNPC.Name)
			end
		else
			-- Left range of NPC
			-- print("🚶 Left NPC range")
			removeHighlight()
			hidePromptUI()

			-- Clear attribute
			if character then
				character:SetAttribute("Commence", false)
				character:SetAttribute("NearbyNPC", nil)
			end
		end

		currentNearbyNPC = nearbyNPC
	end
end

-- Main update loop
RunService.Heartbeat:Connect(function()
	local currentTime = os.clock()

	-- Only check at intervals
	if currentTime - lastCheckTime >= CHECK_INTERVAL then
		lastCheckTime = currentTime
		updateProximity()
	end
end)

-- Cleanup function for death/respawn
local function cleanup()
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
	currentNearbyNPC = nil

	-- Clear character attributes
	if character then
		character:SetAttribute("Commence", false)
		character:SetAttribute("NearbyNPC", nil)
	end
end

-- Expose functions globally so other systems can call them
_G.DialogueProximity_HidePrompt = hidePromptUI
_G.DialogueProximity_Cleanup = cleanup

-- Initial check
task.wait(1)
updateProximity()

-- print("✅ Dialogue Proximity System loaded")

