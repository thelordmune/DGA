--[[
	Night Transition Module

	Displays atmospheric text when transitioning to night time.
	Uses TextPlus for styled text with sequential word fade-in effect.
]]

local NightTransition = {}
local CSystem = require(script.Parent)

local Lighting = game:GetService("Lighting")
local TweenService = CSystem.Service.TweenService
local RunService = CSystem.Service.RunService
local ReplicatedStorage = CSystem.Service.ReplicatedStorage
local Players = CSystem.Service.Players

local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Night transition messages
local NIGHT_MESSAGES = {
	"The sun sets over Amestris...",
	"Darkness falls upon the land...",
	"Night approaches...",
	"The day gives way to twilight...",
	"As shadows lengthen...",
}

local DAWN_MESSAGES = {
	"A new day dawns...",
	"The sun rises over Amestris...",
	"Light returns to the land...",
	"Morning breaks...",
}

local NIGHT_HOUR = 19
local DAWN_HOUR = 6

local lastTimeState = nil
local isTransitioning = false
local screenGui = nil
local container = nil

local function createUI()
	if screenGui then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NightTransitionUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.4)
	container.Size = UDim2.fromOffset(900, 80)
	container.Parent = screenGui
end

local function showTransitionText(message: string, isNight: boolean)
	if isTransitioning then return end
	isTransitioning = true

	createUI()
	TextPlus.Clear(container)

	local textColor = isNight
		and Color3.fromRGB(200, 180, 220)
		or Color3.fromRGB(255, 220, 150)

	TextPlus.Create(container, message, {
		Size = 42,
		Color = textColor,
		Transparency = 1,
		StrokeSize = 3,
		StrokeColor = Color3.fromRGB(0, 0, 0),
		StrokeTransparency = 1,
		XAlignment = "Center",
		YAlignment = "Center",
		CharacterSpacing = 1.1,
		WordSorting = true,
	})

	local wordFolders = {}
	for _, child in container:GetChildren() do
		if child:IsA("Folder") then
			table.insert(wordFolders, child)
		end
	end

	table.sort(wordFolders, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	for i, wordFolder in ipairs(wordFolders) do
		task.delay((i - 1) * 0.18, function()
			for _, charLabel in wordFolder:GetChildren() do
				if charLabel:IsA("TextLabel") or charLabel:IsA("ImageLabel") then
					local mainLabel = charLabel:FindFirstChild("Main")
					local labelsToAnimate = mainLabel and {charLabel, mainLabel} or {charLabel}

					for _, label in labelsToAnimate do
						if label:IsA("TextLabel") then
							TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								TextTransparency = 0,
							}):Play()

							local stroke = label:FindFirstChildOfClass("UIStroke")
							if stroke then
								TweenService:Create(stroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
									Transparency = 0.3,
								}):Play()
							end
						elseif label:IsA("ImageLabel") then
							TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								ImageTransparency = 0,
							}):Play()
						end
					end
				end
			end
		end)
	end

	task.wait(#wordFolders * 0.18 + 2.5)

	for _, wordFolder in ipairs(wordFolders) do
		for _, charLabel in wordFolder:GetChildren() do
			if charLabel:IsA("TextLabel") or charLabel:IsA("ImageLabel") then
				local mainLabel = charLabel:FindFirstChild("Main")
				local labelsToAnimate = mainLabel and {charLabel, mainLabel} or {charLabel}

				for _, label in labelsToAnimate do
					if label:IsA("TextLabel") then
						TweenService:Create(label, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							TextTransparency = 1,
						}):Play()

						local stroke = label:FindFirstChildOfClass("UIStroke")
						if stroke then
							TweenService:Create(stroke, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
								Transparency = 1,
							}):Play()
						end
					elseif label:IsA("ImageLabel") then
						TweenService:Create(label, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							ImageTransparency = 1,
						}):Play()
					end
				end
			end
		end
	end

	task.wait(1.2)
	TextPlus.Clear(container)
	isTransitioning = false
end

-- Initialize
task.spawn(function()
	createUI()

	local lastCheck = 0
	local CHECK_INTERVAL = 1

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastCheck < CHECK_INTERVAL then return end
		lastCheck = now

		local timeOfDay = Lighting.TimeOfDay
		local hour = tonumber(timeOfDay:match("(%d+):"))
		if not hour then return end

		local currentState
		if hour >= NIGHT_HOUR or hour < DAWN_HOUR then
			currentState = "night"
		else
			currentState = "day"
		end

		if lastTimeState and lastTimeState ~= currentState then
			local message
			local isNight = currentState == "night"
			if isNight then
				message = NIGHT_MESSAGES[math.random(1, #NIGHT_MESSAGES)]
			else
				message = DAWN_MESSAGES[math.random(1, #DAWN_MESSAGES)]
			end

			task.spawn(function()
				showTransitionText(message, isNight)
			end)
		end

		lastTimeState = currentState
	end)

	-- Initialize state
	local hour = tonumber(Lighting.TimeOfDay:match("(%d+):")) or 12
	if hour >= NIGHT_HOUR or hour < DAWN_HOUR then
		lastTimeState = "night"
	else
		lastTimeState = "day"
	end
end)

return NightTransition
