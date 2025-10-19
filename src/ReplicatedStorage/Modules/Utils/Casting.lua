--[[
	DirectionalCasting Module

	A modular directional input system for alchemy casting with mouse/gamepad support.
	Integrates with Library StateManager for state tracking.

	Usage:
		local Casting = require(ReplicatedStorage.Modules.Utils.Casting)
		local caster = Casting.new()

		caster.OnSequenceComplete:Connect(function(sequence, isModifier)
			-- print("Cast:", sequence, "Modifier:", isModifier)
		end)

		caster:StartCasting()
--]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import required modules
local Library = require(ReplicatedStorage.Modules.Library)
local Combinations = require(ReplicatedStorage.Modules.Shared.Combinations)

local DirectionalCasting = {}
DirectionalCasting.__index = DirectionalCasting

-- Configuration
local CONFIG = {
	UI = {
		SIZE = UDim2.fromOffset(200, 200),
		CENTER_SIZE = UDim2.fromOffset(10, 10),
		TRIANGLE_SIZE = UDim2.fromOffset(40, 40),
		DEAD_ZONE = 70,
		MOUSE_SENSITIVITY = 5
	},
	COLORS = {
		inactive = Color3.fromRGB(100, 100, 100),
		hover = Color3.fromRGB(255, 255, 0),
		active = Color3.fromRGB(0, 255, 0),
		modifier = Color3.fromRGB(255, 0, 0),
		modifierHover = Color3.fromRGB(255, 100, 100),
		background = Color3.fromRGB(0, 100, 200)
	},
	ANIMATION = {
		DURATION = 0.2,
		STYLE = Enum.EasingStyle.Quad,
		DIRECTION = Enum.EasingDirection.Out
	}
}

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DirectionalUI"
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.fromOffset(200, 200)
container.Position = UDim2.fromScale(0.5, 0.5)
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.BackgroundTransparency = 1
container.Parent = screenGui

local center = Instance.new("Frame")
center.Name = "Center"
center.Size = UDim2.fromOffset(10, 10)
center.Position = UDim2.fromScale(0.5, 0.5)
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
center.BackgroundTransparency = 1
center.Visible = false
center.Parent = container

local centerCorner = Instance.new("UICorner")
centerCorner.CornerRadius = UDim.new(1, 0)
centerCorner.Parent = center

local function createTriangle(direction, position, rotation)
	local triangle = Instance.new("TextLabel")
	triangle.Name = direction .. "Triangle"
	triangle.Size = UDim2.fromOffset(40, 40)
	triangle.Position = position
	triangle.AnchorPoint = Vector2.new(0.5, 0.5)
	triangle.BackgroundTransparency = 1
	triangle.Text = "▲"
	triangle.TextColor3 = Color3.fromRGB(100, 100, 100)
	triangle.TextSize = 30
	triangle.TextStrokeTransparency = 1
	triangle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	triangle.TextTransparency = 1
	triangle.Font = Enum.Font.SourceSansBold
	triangle.Rotation = rotation
	triangle.Visible = false
	triangle.Parent = container

	return triangle
end

local triangles = {
	up = createTriangle("Up", UDim2.fromScale(0.5, 0.2), 0),
	down = createTriangle("Down", UDim2.fromScale(0.5, 0.8), 180),
	left = createTriangle("Left", UDim2.fromScale(0.2, 0.5), -90),
	right = createTriangle("Right", UDim2.fromScale(0.8, 0.5), 90)
}

local colors = {
	inactive = Color3.fromRGB(100, 100, 100),
	hover = Color3.fromRGB(255, 255, 0),
	active = Color3.fromRGB(0, 255, 0),
	modifier = Color3.fromRGB(255, 0, 0),
	modifierHover = Color3.fromRGB(255, 100, 100)
}

local currentTriangle = nil
local lastTriangle = nil

local isCasting = false
local isModifying = false
local directionSequence = {}
local modifierSequence = {}
local savedBaseSequence = {}
local castingStartTime = 0

local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function formatSequence(sequence)
	local formatted = ""
	for _, direction in ipairs(sequence) do
		formatted = formatted .. string.sub(direction, 1, 1)
	end
	return formatted
end

local function startCasting()
	isCasting = true
	isModifying = false
	directionSequence = {}
	modifierSequence = {}
	savedBaseSequence = {}
	castingStartTime = tick()

	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
	end

	local castingTween = TweenService:Create(container, tweenInfo, {
		BackgroundTransparency = 0.8,
		BackgroundColor3 = Color3.fromRGB(0, 100, 200)
	})
	castingTween:Play()

	center.BackgroundTransparency = 1
	center.Visible = true
	local centerFadeIn = TweenService:Create(center, tweenInfo, {
		BackgroundTransparency = 0
	})
	centerFadeIn:Play()

	for _, triangle in pairs(triangles) do
		triangle.TextTransparency = 1
		triangle.TextStrokeTransparency = 1
		triangle.Visible = true

		local fadeInTween = TweenService:Create(triangle, tweenInfo, {
			TextTransparency = 0,
			TextStrokeTransparency = 0
		})
		fadeInTween:Play()
	end
end

local function startModifying()
	if not isCasting then return end

	savedBaseSequence = {}
	for i, direction in ipairs(directionSequence) do
		savedBaseSequence[i] = direction
	end

	isModifying = true
	modifierSequence = {}

	for _, triangle in pairs(triangles) do
		local modifierTween = TweenService:Create(triangle, tweenInfo, {
			TextColor3 = colors.modifier
		})
		modifierTween:Play()
	end
end

local function stopEverything()
	isModifying = false
	isCasting = false

	local endTween = TweenService:Create(container, tweenInfo, {
		BackgroundTransparency = 1
	})
	endTween:Play()

	local centerFadeOut = TweenService:Create(center, tweenInfo, {
		BackgroundTransparency = 1
	})
	centerFadeOut:Play()
	centerFadeOut.Completed:Connect(function()
		center.Visible = false
	end)

	for _, triangle in pairs(triangles) do
		local fadeOutTween = TweenService:Create(triangle, tweenInfo, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			TextColor3 = colors.inactive,
			TextSize = 30
		})
		fadeOutTween:Play()

		fadeOutTween.Completed:Connect(function()
			triangle.Visible = false
		end)
	end

	currentTriangle = nil
	directionSequence = {}
	modifierSequence = {}
	savedBaseSequence = {}
end

local function endCasting()
	isCasting = false
	isModifying = false

	local endTween = TweenService:Create(container, tweenInfo, {
		BackgroundTransparency = 1
	})
	endTween:Play()

	local centerFadeOut = TweenService:Create(center, tweenInfo, {
		BackgroundTransparency = 1
	})
	centerFadeOut:Play()
	centerFadeOut.Completed:Connect(function()
		center.Visible = false
	end)

	for _, triangle in pairs(triangles) do
		local fadeOutTween = TweenService:Create(triangle, tweenInfo, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			TextColor3 = colors.inactive,
			TextSize = 30
		})
		fadeOutTween:Play()

		fadeOutTween.Completed:Connect(function()
			triangle.Visible = false
		end)
	end

	currentTriangle = nil
	directionSequence = {}
	modifierSequence = {}
	savedBaseSequence = {}
end

local function addDirectionToSequence(direction)
	if not isCasting then return end

	if isModifying then
		if #modifierSequence == 0 or modifierSequence[#modifierSequence] ~= direction then
			table.insert(modifierSequence, direction)
			local formatted = formatSequence(modifierSequence)
		end
	else
		if #directionSequence == 0 or directionSequence[#directionSequence] ~= direction then
			table.insert(directionSequence, direction)
			local formatted = formatSequence(directionSequence)
		end
	end
end

local function highlightTriangle(triangle)
	if triangle == currentTriangle then return end

	local showFeedback = isCasting or true

	if currentTriangle then
		local resetColor
		if showFeedback then
			resetColor = isModifying and colors.modifier or colors.inactive
		else
			resetColor = Color3.fromRGB(50, 50, 50)
		end
		local resetSize = showFeedback and 30 or 25
		local resetTween = TweenService:Create(currentTriangle, tweenInfo, {
			TextColor3 = resetColor,
			TextSize = resetSize
		})
		resetTween:Play()
	end

	if triangle then
		local highlightColor
		if showFeedback then
			highlightColor = isModifying and colors.modifierHover or colors.hover
		else
			highlightColor = Color3.fromRGB(150, 150, 150)
		end
		local highlightSize = showFeedback and 35 or 30
		local highlightTween = TweenService:Create(triangle, tweenInfo, {
			TextColor3 = highlightColor,
			TextSize = highlightSize
		})
		highlightTween:Play()

		if isCasting then
			local direction = triangle.Name:gsub("Triangle", ""):upper()
			addDirectionToSequence(direction)
		end
	end

	currentTriangle = triangle
end

local function triggerTriangle(triangle)
	if not triangle then return end

	local triggerTween = TweenService:Create(triangle, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
		TextColor3 = colors.active,
		TextSize = 40
	})
	triggerTween:Play()

	triggerTween.Completed:Connect(function()
		task.wait(0.1)
		local resetTween = TweenService:Create(triangle, tweenInfo, {
			TextColor3 = colors.hover,
			TextSize = 35
		})
		resetTween:Play()
	end)
end

local function getTriangleFromMousePosition()
	local mouse

	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		local mouseDelta = UserInputService:GetMouseDelta()
		local containerPos = container.AbsolutePosition
		local containerSize = container.AbsoluteSize
		local centerX = containerPos.X + containerSize.X / 2
		local centerY = containerPos.Y + containerSize.Y / 2

		mouse = Vector2.new(centerX + mouseDelta.X * 5, centerY + mouseDelta.Y * 5)
	else
		mouse = UserInputService:GetMouseLocation()
	end

	local containerPos = container.AbsolutePosition
	local containerSize = container.AbsoluteSize

	local centerX = containerPos.X + containerSize.X / 2
	local centerY = containerPos.Y + containerSize.Y / 2

	local relativeX = mouse.X - centerX
	local relativeY = mouse.Y - centerY

	local deadZone = 70
	local distance = math.sqrt(relativeX^2 + relativeY^2)

	if distance < deadZone then
		return nil
	end

	local angle = math.atan2(relativeY, relativeX)
	local degrees = math.deg(angle)

	if degrees < 0 then
		degrees = degrees + 360
	end

	if degrees >= 315 or degrees < 45 then
		return triangles.right
	elseif degrees >= 75 and degrees < 105 then
		return triangles.down
	elseif degrees >= 135 and degrees < 225 then
		return triangles.left
	elseif degrees >= 240 and degrees < 300 then
		return triangles.up
	end

	return nil
end

local connection
connection = RunService.Heartbeat:Connect(function()
	if isCasting or true then
		local targetTriangle = getTriangleFromMousePosition()
		highlightTriangle(targetTriangle)
		-- print("highlighting stuff")
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Z then
		if isCasting then
			endCasting()
		else
			startCasting()
		end
	end

	if input.KeyCode == Enum.KeyCode.X then
		if isCasting and not isModifying then
			startModifying()
		elseif isCasting and isModifying then
			stopEverything()
		end
	end
end)

Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		connection:Disconnect()
		screenGui:Destroy()
	end
end)

