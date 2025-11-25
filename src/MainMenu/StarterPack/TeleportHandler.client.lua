--!strict
-- Main Menu Teleport Handler (Client)
-- Requests server to teleport player from main menu to main game

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for remote events
local teleportRemote = ReplicatedStorage:WaitForChild("RequestTeleport", 10)
local teleportErrorRemote = ReplicatedStorage:WaitForChild("TeleportError", 10)

if not teleportRemote then
	warn("[TeleportHandler] RequestTeleport remote not found!")
	return
end

-- Wait for the Play button to be created
local intermission = playerGui:WaitForChild("Intermission", 30)
if not intermission then
	warn("[TeleportHandler] Intermission GUI not found")
	return
end

local playButton = intermission:WaitForChild("Play", 30)
if not playButton then
	warn("[TeleportHandler] Play button not found")
	return
end

-- Loading GUI reference
local loadingGui = nil

-- Function to show loading screen
local function showLoadingScreen()
	if loadingGui then
		return -- Already showing
	end

	loadingGui = Instance.new("ScreenGui")
	loadingGui.Name = "LoadingGui"
	loadingGui.IgnoreGuiInset = true
	loadingGui.ResetOnSpawn = false
	loadingGui.DisplayOrder = 100

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0
	frame.Parent = loadingGui

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "Entering Ironveil..."
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = frame

	loadingGui.Parent = playerGui
end

-- Function to hide loading screen
local function hideLoadingScreen()
	if loadingGui then
		loadingGui:Destroy()
		loadingGui = nil
	end
end

-- Function to show error message
local function showError(message: string)
	hideLoadingScreen()

	local currentIntermission = playerGui:FindFirstChild("Intermission")
	if not currentIntermission then
		return
	end

	local errorLabel = Instance.new("TextLabel")
	errorLabel.Size = UDim2.fromScale(0.5, 0.1)
	errorLabel.Position = UDim2.fromScale(0.25, 0.8)
	errorLabel.BackgroundColor3 = Color3.fromRGB(163, 0, 0)
	errorLabel.Text = message
	errorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	errorLabel.TextScaled = true
	errorLabel.Font = Enum.Font.GothamBold
	errorLabel.Parent = currentIntermission

	task.delay(3, function()
		if errorLabel and errorLabel.Parent then
			errorLabel:Destroy()
		end
	end)
end

-- Function to request teleport from server
local function teleportToMainGame()
	print("[TeleportHandler] Requesting teleport from server...")

	-- Show loading screen
	-- showLoadingScreen()

	-- Request teleport from server
	teleportRemote:FireServer()

	-- Set a timeout in case something goes wrong
	task.delay(10, function()
		if loadingGui then
			-- If we're still showing loading after 10 seconds, something went wrong
			--showError("Teleport timed out. Please try again.")
		end
	end)
end

-- Listen for teleport errors from server
if teleportErrorRemote then
	teleportErrorRemote.OnClientEvent:Connect(function(errorMessage)
		warn("[TeleportHandler] Teleport error from server:", errorMessage)
		showError("Teleport failed: " .. tostring(errorMessage))
	end)
end

-- Connect to Play button
playButton.Activated:Connect(function()
	print("[TeleportHandler] Play button clicked")
	teleportToMainGame()
end)

print("[TeleportHandler] Initialized and ready")

