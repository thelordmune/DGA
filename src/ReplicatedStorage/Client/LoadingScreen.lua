--[[
	Loading Screen Module

	Displays a 20-second loading screen with:
	- Character viewport animation
	- Progress bar and percentage
	- Hides default Roblox UI during loading
	- Smooth fade out transition
]]

local LoadingScreen = {}
local CSystem = require(script.Parent)

local TweenService = CSystem.Service.TweenService
local RunService = CSystem.Service.RunService
local StarterGui = CSystem.Service.StarterGui
local ReplicatedStorage = CSystem.Service.ReplicatedStorage
local Players = CSystem.Service.Players

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Initialize
task.spawn(function()
	repeat task.wait() until game:IsLoaded()

	-- Create a loading screen flag to prevent HUD from loading too early
	local loadingScreenActive = true
	_G.LoadingScreenActive = loadingScreenActive

	-- Hide default Roblox UI during loading screen
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)

	-- Create our own loading screen ScreenGui
	local screengui = Instance.new("ScreenGui")
	screengui.Name = "LoadingScreen"
	screengui.ResetOnSpawn = false
	screengui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screengui.DisplayOrder = 100
	screengui.Parent = playerGui
	screengui.IgnoreGuiInset = true

	-- Create a ViewportFrame for the character display
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ViewportFrame"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Position = UDim2.fromScale(0, 0)
	viewport.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	viewport.BorderSizePixel = 0
	viewport.Parent = screengui

	-- Show the loading screen and ensure it stays visible
	screengui.Enabled = true

	-- Monitor and prevent the ScreenGui from being disabled
	local enabledConnection
	enabledConnection = screengui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not screengui.Enabled and loadingScreenActive then
			screengui.Enabled = true
		end
	end)

	-- Load character
	local character = ReplicatedStorage:FindFirstChild("Classified")
	if character then
		character = character:Clone()
		character.PrimaryPart = character:FindFirstChild("HumanoidRootPart")
	else
		warn("Classified character not found in ReplicatedStorage!")
		character = Instance.new("Model")
		character.Name = "PlaceholderCharacter"
		local part = Instance.new("Part")
		part.Name = "HumanoidRootPart"
		part.Size = Vector3.new(2, 2, 1)
		part.Material = Enum.Material.Neon
		part.BrickColor = BrickColor.new("Bright blue")
		part.Anchored = true
		part.Parent = character
		character.PrimaryPart = part
	end

	-- Clear previous models
	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("WorldModel") then
			child:ClearAllChildren()
		end
	end

	-- Add to viewport
	character.Parent = viewport:FindFirstChild("WorldModel") or viewport
	if character.PrimaryPart then
		character.PrimaryPart.CFrame = character.PrimaryPart.CFrame * CFrame.Angles(0, math.rad(180), 0)
	else
		warn("Character has no PrimaryPart!")
	end

	-- Camera setup
	local camera = Instance.new("Camera")
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 90
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Adjust camera
	camera.CFrame = CFrame.new(-11.932, 2.5, 8.533) * CFrame.Angles(math.rad(-25), 0, 0)

	-- Play animation
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://128209591266447"
		local success, animationTrack = pcall(function()
			return humanoid:LoadAnimation(animation)
		end)

		if success and animationTrack then
			animationTrack:Play()
			animationTrack.Looped = true
		else
			warn("Failed to load animation:", animationTrack)
		end
	else
		warn("No Humanoid found in character")
	end

	-- Ensure the screen is visible with a solid background
	local backgroundFrame = Instance.new("Frame")
	backgroundFrame.Name = "LoadingBackground"
	backgroundFrame.Size = UDim2.fromScale(1, 1)
	backgroundFrame.Position = UDim2.fromScale(0, 0)
	backgroundFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backgroundFrame.BorderSizePixel = 0
	backgroundFrame.ZIndex = 1
	backgroundFrame.Parent = screengui

	-- Add a simple test element to ensure visibility
	local testLabel = Instance.new("TextLabel")
	testLabel.Name = "TestLabel"
	testLabel.Size = UDim2.new(0, 200, 0, 50)
	testLabel.Position = UDim2.new(0.5, -100, 0.1, 0)
	testLabel.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	testLabel.Text = "LOADING SCREEN ACTIVE"
	testLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	testLabel.TextSize = 18
	testLabel.Font = Enum.Font.SourceSansBold
	testLabel.ZIndex = 20
	testLabel.Parent = screengui

	-- Create loading text
	local loadingText = Instance.new("TextLabel")
	loadingText.Name = "LoadingText"
	loadingText.Size = UDim2.new(0, 400, 0, 50)
	loadingText.Position = UDim2.new(0.5, -200, 0.8, 0)
	loadingText.BackgroundTransparency = 1
	loadingText.Text = "Loading..."
	loadingText.TextColor3 = Color3.fromRGB(255, 255, 255)
	loadingText.TextSize = 24
	loadingText.Font = Enum.Font.SourceSansBold
	loadingText.TextStrokeTransparency = 0.5
	loadingText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	loadingText.ZIndex = 10
	loadingText.Parent = screengui

	-- Create loading progress bar
	local progressFrame = Instance.new("Frame")
	progressFrame.Name = "ProgressFrame"
	progressFrame.Size = UDim2.new(0, 300, 0, 6)
	progressFrame.Position = UDim2.new(0.5, -150, 0.85, 0)
	progressFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	progressFrame.BorderSizePixel = 0
	progressFrame.ZIndex = 10
	progressFrame.Parent = screengui

	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(0, 0, 1, 0)
	progressBar.Position = UDim2.new(0, 0, 0, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progressBar.BorderSizePixel = 0
	progressBar.ZIndex = 11
	progressBar.Parent = progressFrame

	-- Add corner radius to progress elements
	local progressFrameCorner = Instance.new("UICorner")
	progressFrameCorner.CornerRadius = UDim.new(0, 3)
	progressFrameCorner.Parent = progressFrame

	local progressBarCorner = Instance.new("UICorner")
	progressBarCorner.CornerRadius = UDim.new(0, 3)
	progressBarCorner.Parent = progressBar

	-- Animate loading progress over 20 seconds
	local loadingDuration = 20
	local startTime = tick()

	local progressConnection
	progressConnection = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local progress = math.min(elapsed / loadingDuration, 1)

		-- Update progress bar
		progressBar.Size = UDim2.new(progress, 0, 1, 0)

		-- Update loading text with dots animation
		local dots = string.rep(".", math.floor((elapsed * 2) % 4))
		loadingText.Text = "Loading" .. dots

		-- Show percentage
		local percentage = math.floor(progress * 100)
		loadingText.Text = "Loading" .. dots .. " " .. percentage .. "%"

		if progress >= 1 then
			progressConnection:Disconnect()
			loadingText.Text = "Complete!"
		end
	end)

	-- Wait for 20 seconds, then hide the loading screen and allow HUD to load
	task.wait(loadingDuration)

	-- Hide the loading screen with a smooth fade out
	local fadeInfo = TweenInfo.new(
		1,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)

	-- Fade out the viewport
	local viewportFadeTween = TweenService:Create(viewport, fadeInfo, {
		BackgroundTransparency = 1
	})

	-- Fade out loading text and progress bar
	local textFadeTween = TweenService:Create(loadingText, fadeInfo, {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})

	local progressFrameFadeTween = TweenService:Create(progressFrame, fadeInfo, {
		BackgroundTransparency = 1
	})

	local progressBarFadeTween = TweenService:Create(progressBar, fadeInfo, {
		BackgroundTransparency = 1
	})

	local backgroundFadeTween = TweenService:Create(backgroundFrame, fadeInfo, {
		BackgroundTransparency = 1
	})

	local testLabelFadeTween = TweenService:Create(testLabel, fadeInfo, {
		BackgroundTransparency = 1,
		TextTransparency = 1
	})

	-- Start the fade out
	viewportFadeTween:Play()
	textFadeTween:Play()
	progressFrameFadeTween:Play()
	progressBarFadeTween:Play()
	backgroundFadeTween:Play()
	testLabelFadeTween:Play()

	-- Wait for fade to complete, then disable the screen
	backgroundFadeTween.Completed:Connect(function()
		-- Disconnect the enabled monitoring connection
		if enabledConnection then
			enabledConnection:Disconnect()
		end

		screengui.Enabled = false
		loadingScreenActive = false
		_G.LoadingScreenActive = false

		-- Re-enable default Roblox UI
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)

		-- Clean up the character model and loading UI
		if character then
			character:Destroy()
		end
		if loadingText then
			loadingText:Destroy()
		end
		if progressFrame then
			progressFrame:Destroy()
		end
		if backgroundFrame then
			backgroundFrame:Destroy()
		end
		if testLabel then
			testLabel:Destroy()
		end
	end)
end)

return LoadingScreen
