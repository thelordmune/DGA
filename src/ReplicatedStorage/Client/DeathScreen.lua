--[[
	Death Screen Module

	Handles death visual effects:
	- Ragdolls player on death (before respawn)
	- Shows black screen fade that transitions to white
	- Fades back to normal when respawned
]]

local DeathScreen = {}
local CSystem = require(script.Parent)

local TweenService = CSystem.Service.TweenService
local Players = CSystem.Service.Players
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local RAGDOLL_DURATION = 2
local FADE_TO_BLACK_TIME = 0.5
local HOLD_BLACK_TIME = 0.5
local FADE_TO_WHITE_TIME = 0.3
local HOLD_WHITE_TIME = 0.2
local FADE_FROM_WHITE_TIME = 0.8

-- UI Elements
local screenGui = nil
local deathOverlay = nil
local currentDeathConnection = nil

-- Create death screen UI
local function createUI()
	if screenGui then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DeathScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 1000
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	deathOverlay = Instance.new("Frame")
	deathOverlay.Name = "Overlay"
	deathOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	deathOverlay.BackgroundTransparency = 1
	deathOverlay.Size = UDim2.fromScale(1, 1)
	deathOverlay.BorderSizePixel = 0
	deathOverlay.Parent = screenGui
end

-- Ragdoll the character (client-side visual)
local function ragdollCharacter(character: Model)
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.PlatformStand = true
	humanoid.AutoRotate = false

	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		humanoid.HipHeight = 0
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
	end
end

-- Play death sequence
local function playDeathSequence(character: Model)
	if not screenGui then createUI() end
	screenGui.Enabled = true

	ragdollCharacter(character)
	task.wait(RAGDOLL_DURATION * 0.5)

	deathOverlay.BackgroundTransparency = 1
	deathOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

	local fadeToBlack = TweenService:Create(deathOverlay, TweenInfo.new(FADE_TO_BLACK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 0
	})
	fadeToBlack:Play()
	fadeToBlack.Completed:Wait()

	task.wait(HOLD_BLACK_TIME)

	local fadeToWhite = TweenService:Create(deathOverlay, TweenInfo.new(FADE_TO_WHITE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	})
	fadeToWhite:Play()
	fadeToWhite.Completed:Wait()

	task.wait(HOLD_WHITE_TIME)
end

-- Play respawn sequence
local function playRespawnSequence()
	if not screenGui or not screenGui.Enabled then return end

	deathOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	deathOverlay.BackgroundTransparency = 0

	task.wait(0.3)

	local fadeFromWhite = TweenService:Create(deathOverlay, TweenInfo.new(FADE_FROM_WHITE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	})
	fadeFromWhite:Play()
	fadeFromWhite.Completed:Wait()

	screenGui.Enabled = false
end

-- Setup character death handling
local function setupCharacter(character: Model)
	if currentDeathConnection then
		currentDeathConnection:Disconnect()
		currentDeathConnection = nil
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end

	currentDeathConnection = humanoid.Died:Connect(function()
		playDeathSequence(character)
	end)
end

-- Initialize
task.spawn(function()
	createUI()

	player.CharacterAdded:Connect(function(character)
		playRespawnSequence()
		setupCharacter(character)
	end)

	if player.Character then
		setupCharacter(player.Character)
	end
end)

return DeathScreen
