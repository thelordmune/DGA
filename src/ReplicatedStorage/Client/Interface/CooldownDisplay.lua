--!strict
-- Cooldown Display UI - Shows skill cooldowns in bottom left corner

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Library = require(ReplicatedStorage.Modules.Library)

local CooldownDisplay = {}

-- Configuration
local CONFIG = {
	POSITION = UDim2.new(0, 20, 1, -20), -- Bottom left with padding
	ICON_SIZE = UDim2.fromOffset(50, 50),
	SPACING = 5,
	MAX_VISIBLE = 8, -- Maximum number of cooldowns to show
	FADE_DURATION = 0.2,
	UPDATE_RATE = 0.05, -- Update every 50ms (20 times per second)
}

-- Skills to track (will be populated based on player's weapon and alchemy)
local TRACKED_SKILLS = {
	-- Combat
	"M1",
	"M2",
	"Critical",
	"Block",
	"Parry",
	
	-- Movement
	"Dash",
	"Dodge",
	
	-- Will be populated with weapon skills
	-- Will be populated with alchemy skills
}

local screenGui: ScreenGui
local container: Frame
local cooldownFrames = {} -- {skillName = frame}
local lastUpdate = 0

-- Create the UI
local function createUI()
	-- print("📦 Creating CooldownDisplay UI...")

	-- Create ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CooldownDisplay"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")
	-- print("  ✓ ScreenGui created and parented to PlayerGui")

	-- Create container frame
	container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint = Vector2.new(0, 1)
	container.Position = CONFIG.POSITION
	container.Size = UDim2.fromOffset(60, 500) -- Will auto-size based on content
	container.BackgroundTransparency = 1
	container.Parent = screenGui
	-- print("  ✓ Container frame created at position:", CONFIG.POSITION)

	-- Create a test label to verify UI is visible
	local testLabel = Instance.new("TextLabel")
	testLabel.Name = "TestLabel"
	testLabel.Size = UDim2.fromOffset(120, 40)
	testLabel.Position = UDim2.new(0, 0, 0, -50) -- Above container
	testLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	testLabel.BackgroundTransparency = 0.2
	testLabel.Text = "Cooldowns"
	testLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	testLabel.TextSize = 18
	testLabel.Font = Enum.Font.GothamBold
	testLabel.BorderSizePixel = 0
	testLabel.Parent = container

	-- Add corner to test label
	local testCorner = Instance.new("UICorner")
	testCorner.CornerRadius = UDim.new(0, 8)
	testCorner.Parent = testLabel

	-- Add stroke to test label
	local testStroke = Instance.new("UIStroke")
	testStroke.Color = Color3.fromRGB(255, 200, 0)
	testStroke.Thickness = 2
	testStroke.Transparency = 0.5
	testStroke.Parent = testLabel

	-- Make test label clickable to manually test cooldown display
	local testButton = Instance.new("TextButton")
	testButton.Size = UDim2.new(1, 0, 1, 0)
	testButton.BackgroundTransparency = 1
	testButton.Text = ""
	testButton.Parent = testLabel

	testButton.MouseButton1Click:Connect(function()
		-- print("🧪 TEST: Manually triggering M1 cooldown")
		local char = player.Character
		if char then
			Library.SetCooldown(char, "M1", 3) -- 3 second test cooldown
			-- print("🧪 TEST: M1 cooldown set for 3 seconds")
		end
	end)

	-- print("  ✓ Test label created (click it to test cooldowns!)")

	-- Add UIListLayout for automatic positioning
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	listLayout.Padding = UDim.new(0, CONFIG.SPACING)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = container
	-- print("  ✓ UIListLayout added")

	-- print("📦 UI creation complete!")
end

-- Create a cooldown frame for a skill
local function createCooldownFrame(skillName: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = skillName
	frame.Size = CONFIG.ICON_SIZE
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = container
	
	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	
	-- Add stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0.7
	stroke.Parent = frame
	
	-- Skill name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "SkillName"
	nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
	nameLabel.Position = UDim2.fromScale(0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = skillName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = frame
	
	-- Cooldown timer label
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.Size = UDim2.new(1, 0, 0.7, 0)
	timerLabel.Position = UDim2.fromScale(0, 0.3)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "0.0"
	timerLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.Parent = frame
	
	-- Cooldown overlay (fills from bottom to top)
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.fromScale(0, 1)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 2
	overlay.Parent = frame
	
	-- Match corner rounding
	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0, 8)
	overlayCorner.Parent = overlay
	
	return frame
end

-- Show a cooldown frame with fade-in animation
local function showCooldownFrame(frame: Frame)
	frame.Visible = true
	frame.BackgroundTransparency = 1
	
	local tween = TweenService:Create(
		frame,
		TweenInfo.new(CONFIG.FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 0.3}
	)
	tween:Play()
end

-- Hide a cooldown frame with fade-out animation
local function hideCooldownFrame(frame: Frame)
	local tween = TweenService:Create(
		frame,
		TweenInfo.new(CONFIG.FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{BackgroundTransparency = 1}
	)
	tween:Play()
	
	tween.Completed:Connect(function()
		frame.Visible = false
	end)
end

-- Update a single cooldown display
local function updateCooldown(skillName: string, timeRemaining: number, totalCooldown: number)
	local frame = cooldownFrames[skillName]
	if not frame then
		frame = createCooldownFrame(skillName)
		cooldownFrames[skillName] = frame
		-- print("📦 Created cooldown frame for:", skillName)
	end

	if timeRemaining > 0 then
		-- Show the frame if hidden
		if not frame.Visible then
			showCooldownFrame(frame)
			-- print("👁️ Showing cooldown frame for:", skillName, "Time:", timeRemaining)
		end

		-- Update timer text
		local timerLabel = frame:FindFirstChild("Timer") :: TextLabel
		if timerLabel then
			timerLabel.Text = string.format("%.1f", timeRemaining)
		end

		-- Update overlay fill (inverse progress - starts full, empties as cooldown finishes)
		local overlay = frame:FindFirstChild("Overlay") :: Frame
		if overlay then
			local progress = timeRemaining / totalCooldown
			overlay.Size = UDim2.fromScale(1, progress)
		end
	else
		-- Hide the frame when cooldown is done
		if frame.Visible then
			hideCooldownFrame(frame)
			-- print("🙈 Hiding cooldown frame for:", skillName)
		end
	end
end

-- Get player's weapon skills from inventory/hotbar
local function getWeaponSkills(): {string}
	-- print("🔧 Getting weapon skills from hotbar...")

	local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
	local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)

	local pent = ref.get("local_player", player)
	if not pent then
		-- print("  ⚠️ Player entity not found")
		return {}
	end

	local weaponSkills = {}

	-- Check hotbar slots 1-7 for weapon skills
	for slotNumber = 1, 7 do
		local item = InventoryManager.getHotbarItem(pent, slotNumber)
		if item and item.typ == "skill" then
			table.insert(weaponSkills, item.name)
			-- print("  ✓ Found weapon skill in slot", slotNumber .. ":", item.name)
		end
	end

	if #weaponSkills == 0 then
		-- print("  ⚠️ No weapon skills found in hotbar")
	end

	return weaponSkills
end

-- Get player's alchemy skills
local function getAlchemySkills(): {string}
	-- print("🧪 Getting alchemy skills...")

	-- Get alchemy combinations
	local combinationsModule = ReplicatedStorage.Modules.Shared:FindFirstChild("Combinations")
	if combinationsModule then
		local success, combinations = pcall(function()
			return require(combinationsModule)
		end)

		if success and combinations then
			local alchemySkills = {}
			for skillName, _ in pairs(combinations) do
				table.insert(alchemySkills, skillName)
				-- print("  ✓ Found alchemy skill:", skillName)
			end
			return alchemySkills
		end
	end

	-- print("  ⚠️ No alchemy skills found")
	return {}
end

-- Populate tracked skills based on player's loadout
local function populateTrackedSkills()
	TRACKED_SKILLS = {
		-- Combat
		"M1",
		"M2",
		"Critical",
		"Block",
		"Parry",
		
		-- Movement
		"Dash",
		"Dodge",
	}
	
	-- Add weapon skills
	local weaponSkills = getWeaponSkills()
	for _, skillName in ipairs(weaponSkills) do
		table.insert(TRACKED_SKILLS, skillName)
	end
	
	-- Add alchemy skills
	local alchemySkills = getAlchemySkills()
	for _, skillName in ipairs(alchemySkills) do
		table.insert(TRACKED_SKILLS, skillName)
	end
end

-- Get cooldown duration for a skill from skill data
local function getSkillCooldownDuration(skillName: string): number
	-- Try to get from Combat skill data
	local combatData = ReplicatedStorage:FindFirstChild("Skill_Data")
	if combatData then
		local combatModule = combatData:FindFirstChild("Combat")
		if combatModule then
			local success, data = pcall(function()
				return require(combatModule)
			end)
			if success and data[skillName] and data[skillName].Cooldown then
				return data[skillName].Cooldown
			end
		end

		-- Try Misc skill data
		local miscModule = combatData:FindFirstChild("Misc")
		if miscModule then
			local success, data = pcall(function()
				return require(miscModule)
			end)
			if success and data[skillName] and data[skillName].Cooldown then
				return data[skillName].Cooldown
			end
		end
	end

	-- Check if it's a weapon skill (from hotbar)
	local weaponSkills = getWeaponSkills()
	for _, weaponSkill in ipairs(weaponSkills) do
		if weaponSkill == skillName then
			return 5 -- Default weapon skill cooldown
		end
	end

	-- Default cooldowns for common skills
	local defaultCooldowns = {
		M1 = 0.3,
		M2 = 1,
		Critical = 5,
		Block = 0,
		Parry = 0.5,
		Dash = 1.75,
		Dodge = 2, -- Updated to match actual cooldown
	}

	return defaultCooldowns[skillName] or 1
end

-- Main update loop
local hasLoggedFirstUpdate = false
local function updateCooldowns()
	local character = player.Character
	if not character then return end

	local currentTime = os.clock()

	-- Throttle updates
	if currentTime - lastUpdate < CONFIG.UPDATE_RATE then
		return
	end
	lastUpdate = currentTime

	-- Get cooldowns from Library using the new getter function
	local characterCooldowns = Library.GetCooldowns(character)

	-- Debug: Log first update
	if not hasLoggedFirstUpdate then
		hasLoggedFirstUpdate = true
		-- print("🔄 First cooldown update running")
		-- print("  Character:", character.Name)
		-- print("  Tracked skills:", #TRACKED_SKILLS)

		-- Check if any cooldowns are active
		local activeCooldowns = 0
		for skillName, _ in pairs(characterCooldowns) do
			activeCooldowns = activeCooldowns + 1
		end
		-- print("  Active cooldowns:", activeCooldowns)
	end

	-- Update each tracked skill
	for _, skillName in ipairs(TRACKED_SKILLS) do
		local cooldownEnd = characterCooldowns[skillName]

		if cooldownEnd then
			local timeRemaining = math.max(0, cooldownEnd - currentTime)
			local totalCooldown = getSkillCooldownDuration(skillName)

			-- Debug: Log when a cooldown is detected
			if timeRemaining > 0 and not cooldownFrames[skillName] or (cooldownFrames[skillName] and not cooldownFrames[skillName].Visible) then
				-- print("⏱️ Cooldown detected:", skillName, "Time remaining:", timeRemaining)
			end

			updateCooldown(skillName, timeRemaining, totalCooldown)
		else
			-- No cooldown active
			updateCooldown(skillName, 0, 1)
		end
	end
end

-- Initialize the system
function CooldownDisplay.Init()
	-- print("🎯 CooldownDisplay.Init() called")

	local success, err = pcall(function()
		createUI()
		-- print("✅ UI created successfully")

		populateTrackedSkills()
		-- print("✅ Tracked skills populated:", #TRACKED_SKILLS, "skills")

		-- Update cooldowns every frame
		RunService.Heartbeat:Connect(updateCooldowns)
		-- print("✅ Update loop connected")

		-- Listen for hotbar updates to refresh tracked skills
		local Bridges = require(ReplicatedStorage.Modules.Bridges)
		Bridges.UpdateHotbar:Connect(function()
			-- print("🔄 Hotbar updated, refreshing tracked skills...")
			populateTrackedSkills()
		end)

		-- Also listen for weapon changes
		player:GetAttributeChangedSignal("Weapon"):Connect(function()
			-- print("🔄 Weapon changed, refreshing tracked skills...")
			task.wait(0.5) -- Wait for hotbar to update
			populateTrackedSkills()
		end)

		-- Repopulate skills when character respawns
		player.CharacterAdded:Connect(function()
			task.wait(1) -- Wait for character to fully load
			populateTrackedSkills()
		end)

		-- print("✅ Cooldown Display initialized successfully")
	end)

	if not success then
		warn("❌ CooldownDisplay initialization failed:", err)
	end
end

return CooldownDisplay

