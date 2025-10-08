--[[
	Simple Dialogue Proximity System
	Replaces the ECS dialogue checker with a straightforward proximity detection
	Shows highlight and "E TO TALK" prompt when near NPCs
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Settings
local DETECTION_RANGE = 10 -- Distance to detect NPCs
local CHECK_INTERVAL = 0.5 -- How often to check (in seconds)

-- State tracking
local currentNearbyNPC = nil
local currentHighlight = nil
local proximityUI = nil
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
	if proximityUI then
		proximityUI:Destroy()
		proximityUI = nil
	end
	currentNearbyNPC = nil
end)

-- Create the "E TO TALK" UI
local function createProximityUI()
	if proximityUI then
		proximityUI:Destroy()
	end
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DialogueProximityUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player.PlayerGui
	
	local frame = Instance.new("Frame")
	frame.Name = "ProximityFrame"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromScale(0.444, 0.664)
	frame.Size = UDim2.fromScale(0.112, 0.112)
	frame.Parent = screenGui
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "ProximityText"
	textLabel.BackgroundTransparency = 1
	textLabel.Position = UDim2.fromScale(-0.108, 0.27)
	textLabel.Size = UDim2.fromScale(1.21, 0.5)
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.Text = "E TO TALK"
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextSize = 14
	textLabel.TextTransparency = 1 -- Start invisible
	textLabel.Parent = frame
	
	proximityUI = screenGui
	return textLabel
end

-- Show the proximity UI with animation
local function showProximityUI()
	local textLabel = proximityUI and proximityUI:FindFirstChild("ProximityFrame"):FindFirstChild("ProximityText")
	if not textLabel then
		textLabel = createProximityUI()
	end
	
	-- Fade in
	local tween = TweenService:Create(
		textLabel,
		TweenInfo.new(0.7, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
		{TextTransparency = 0}
	)
	tween:Play()
end

-- Hide the proximity UI with animation
local function hideProximityUI()
	if not proximityUI then return end
	
	local textLabel = proximityUI:FindFirstChild("ProximityFrame"):FindFirstChild("ProximityText")
	if textLabel then
		local tween = TweenService:Create(
			textLabel,
			TweenInfo.new(0.7, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
			{TextTransparency = 1}
		)
		tween:Play()
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
			print("📍 Near NPC:", nearbyNPC.Name)
			addHighlight(nearbyNPC)
			showProximityUI()
			
			-- Set attribute for other systems to use
			if character then
				character:SetAttribute("Commence", true)
				character:SetAttribute("NearbyNPC", nearbyNPC.Name)
			end
		else
			-- Left range of NPC
			print("🚶 Left NPC range")
			removeHighlight()
			hideProximityUI()
			
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

-- Initial check
task.wait(1)
updateProximity()

print("✅ Dialogue Proximity System loaded")

