--[[
	Loading Screen Module

	Displays a loading screen matching death screen style:
	- Black background with rotating image and FMA tip
	- Waits for actual game/character loading
	- Skip button after minimum time
	- Smooth fade out transition
]]

local LoadingScreen = {}
local CSystem = require(script.Parent)

local TweenService = CSystem.Service.TweenService
local RunService = CSystem.Service.RunService
local StarterGui = CSystem.Service.StarterGui
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = CSystem.Service.ReplicatedStorage
local Players = CSystem.Service.Players

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local scoped = Fusion.scoped

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local MIN_LOADING_TIME = 2 -- Minimum time before skip is available
local FADE_OUT_TIME = 0.8
local IMAGE_ROTATION_SPEED = 15 -- Degrees per second

-- Colors
local TIP_COLOR = Color3.fromRGB(180, 180, 180)
local LOADING_IMAGE_ID = "rbxassetid://128446959644937"

-- FMA-themed loading tips
local LOADING_TIPS = {
	"The truth within truth is the path to understanding.",
	"Equivalent Exchange: To obtain, something of equal value must be lost.",
	"A lesson without pain is meaningless.",
	"Endure and survive. That's what alchemy teaches us.",
	"Even when our eyes are closed, there's a whole world out there.",
	"Stand up and walk. Keep moving forward.",
	"Humankind cannot gain anything without first giving something in return.",
	"The world isn't perfect, but it's there for us.",
	"A heart made fullmetal cannot be broken easily.",
	"One is all, all is one.",
	"There's no such thing as a painless lesson.",
	"The power of one man doesn't amount to much.",
	"Even your faults are part of who you are.",
	"Laws exist to be bent, but principles should never break.",
	"An alchemist must be willing to sacrifice.",
	"Pride comes before the fall.",
	"The Gate demands its toll.",
	"Nothing's perfect. The world's not perfect. But it's there for us, trying the best it can.",
}

local function getRandomTip()
	return LOADING_TIPS[math.random(1, #LOADING_TIPS)]
end

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

	local scope = scoped(Fusion)
	local Children = Fusion.Children

	-- State
	local canSkip = scope:Value(false)
	local tipFlash = scope:Value(false)
	local loadingComplete = false
	local skipped = false

	local tip = getRandomTip()

	-- Create the loading screen
	local screenGui = scope:New "ScreenGui" {
		Name = "LoadingScreen",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
		IgnoreGuiInset = true,
		Parent = playerGui,

		[Children] = {
			-- Black background
			scope:New "Frame" {
				Name = "Background",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,

				[Children] = {
					-- Rotating image in the center
					scope:New "ImageLabel" {
						Name = "LoadingImage",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.45),
						Size = UDim2.fromOffset(200, 200),
						Image = LOADING_IMAGE_ID,
						ImageTransparency = 0.1,
						ImageColor3 = Color3.fromRGB(200, 50, 50),
						Rotation = scope:Value(0),
					},

					-- Tip text
					scope:New "TextLabel" {
						Name = "TipLabel",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.7),
						Size = UDim2.fromOffset(600, 60),
						Text = '"' .. tip .. '"',
						TextColor3 = TIP_COLOR,
						TextSize = 18,
						FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Regular),
						TextWrapped = true,

						[Children] = {
							-- UIGradient for flash effect
							scope:New "UIGradient" {
								Name = "FlashGradient",
								Rotation = 0,
								Color = scope:Spring(
									scope:Computed(function(use)
										if use(tipFlash) then
											return ColorSequence.new({
												ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
												ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 220, 255)),
												ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
											})
										else
											return ColorSequence.new({
												ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
												ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
											})
										end
									end),
									30,
									0.8
								),
							},
						},
					},

					-- Skip button (appears after min time)
					scope:New "TextButton" {
						Name = "SkipButton",
						BackgroundColor3 = Color3.fromRGB(40, 40, 40),
						BackgroundTransparency = scope:Spring(
							scope:Computed(function(use)
								return use(canSkip) and 0.5 or 1
							end),
							20,
							1
						),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.85),
						Size = UDim2.fromOffset(120, 35),
						Text = "Skip",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 16,
						FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Bold),
						TextTransparency = scope:Spring(
							scope:Computed(function(use)
								return use(canSkip) and 0 or 1
							end),
							20,
							1
						),
						AutoButtonColor = true,

						[Fusion.OnEvent "Activated"] = function()
							if canSkip:get() then
								skipped = true
							end
						end,

						[Children] = {
							scope:New "UICorner" {
								CornerRadius = UDim.new(0, 6),
							},
							scope:New "UIStroke" {
								Color = Color3.fromRGB(100, 100, 100),
								Thickness = 1,
								Transparency = scope:Spring(
									scope:Computed(function(use)
										return use(canSkip) and 0 or 1
									end),
									20,
									1
								),
							},
						},
					},
				},
			},
		},
	}

	-- Get references
	local background = screenGui:FindFirstChild("Background")
	local loadingImage = background:FindFirstChild("LoadingImage")
	local tipLabel = background:FindFirstChild("TipLabel")
	local skipButton = background:FindFirstChild("SkipButton")

	-- Image rotation
	local rotationConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if loadingImage and loadingImage.Parent then
			loadingImage.Rotation = loadingImage.Rotation + (IMAGE_ROTATION_SPEED * deltaTime)
		end
	end)

	-- Flash loop
	local flashEnabled = true
	task.spawn(function()
		while flashEnabled do
			tipFlash:set(true)
			task.wait(0.15)
			tipFlash:set(false)
			task.wait(0.35)
		end
	end)

	-- Monitor and prevent the ScreenGui from being disabled during loading
	local enabledConnection
	enabledConnection = screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not screenGui.Enabled and loadingScreenActive then
			screenGui.Enabled = true
		end
	end)

	-- Wait for actual loading to complete
	local startTime = tick()

	task.spawn(function()
		-- Wait for character
		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart", 10)
		character:WaitForChild("Humanoid", 10)

		-- Preload important assets (non-blocking, with timeout)
		local assetsToPreload = {}

		-- Add commonly used UI images
		local uiAssets = ReplicatedStorage:FindFirstChild("Assets")
		if uiAssets then
			for _, asset in uiAssets:GetDescendants() do
				if asset:IsA("ImageLabel") or asset:IsA("ImageButton") then
					table.insert(assetsToPreload, asset)
				end
			end
		end

		-- Preload with timeout
		if #assetsToPreload > 0 then
			local preloadSuccess, _ = pcall(function()
				ContentProvider:PreloadAsync(assetsToPreload)
			end)
		end

		loadingComplete = true
	end)

	-- Enable skip after minimum time
	task.delay(MIN_LOADING_TIME, function()
		canSkip:set(true)
	end)

	-- Wait until loading is done OR skipped (with max timeout)
	local maxWaitTime = 10 -- Maximum 10 seconds
	local elapsed = 0
	while not loadingComplete and not skipped and elapsed < maxWaitTime do
		task.wait(0.1)
		elapsed = tick() - startTime
	end

	-- Ensure minimum time passed
	local remaining = MIN_LOADING_TIME - (tick() - startTime)
	if remaining > 0 and not skipped then
		task.wait(remaining)
	end

	-- Stop flash and rotation
	flashEnabled = false
	tipFlash:set(false)

	-- Fade out
	local fadeInfo = TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(background, fadeInfo, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(loadingImage, fadeInfo, { ImageTransparency = 1 }):Play()
	TweenService:Create(tipLabel, fadeInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(skipButton, fadeInfo, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()

	task.wait(FADE_OUT_TIME)

	-- Cleanup
	rotationConnection:Disconnect()
	if enabledConnection then
		enabledConnection:Disconnect()
	end

	screenGui.Enabled = false
	loadingScreenActive = false
	_G.LoadingScreenActive = false

	-- Re-enable some default Roblox UI (but keep Backpack and PlayerList disabled - we have custom ones)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
	-- PlayerList and Backpack remain disabled - we use custom inventory and leaderboard

	-- Cleanup scope
	scope:doCleanup()
end)

return LoadingScreen
