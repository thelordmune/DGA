--[[
	DirectionalCasting Module
	
	A modular directional input system for alchemy casting with mouse/gamepad support.
	Integrates with Library StateManager for state tracking.
	
	Usage:
		local Casting = require(ReplicatedStorage.Modules.Utils.DirectionalCasting)
		local caster = Casting.new()
		
		caster.OnSequenceComplete:Connect(function(sequence, isModifier)
			print("Cast:", sequence, "Modifier:", isModifier)
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
		DEAD_ZONE = 50, -- Reduced from 70 to make directions easier to reach
		MOUSE_SENSITIVITY = 5
	},
	CAMERA = {
		CASTING_SENSITIVITY = 0.5 -- Reduce camera sensitivity to 20% during casting
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

-- Constructor
function DirectionalCasting.new(character)
	local self = setmetatable({}, DirectionalCasting)
	
	-- Properties
	self.Character = character or player.Character
	
	-- Create BindableEvents for communication
	local onSequenceCompleteEvent = Instance.new("BindableEvent")
	local onCastingStateChangedEvent = Instance.new("BindableEvent")

	-- Expose the Event properties for connecting
	self.OnSequenceComplete = onSequenceCompleteEvent.Event
	self.OnCastingStateChanged = onCastingStateChangedEvent.Event

	-- Store the BindableEvents for firing
	self._onSequenceCompleteEvent = onSequenceCompleteEvent
	self._onCastingStateChangedEvent = onCastingStateChangedEvent
	
	-- State tracking
	self.isCasting = false
	self.isModifying = false
	self.directionSequence = {}
	self.modifierSequence = {}
	self.savedBaseSequence = {}
	self.currentTriangle = nil
	
	-- UI Components
	self.screenGui = nil
	self.container = nil
	self.center = nil
	self.triangles = {}
	self.connections = {}

	-- Camera sensitivity control during casting
	self.originalMouseSensitivity = nil
	
	-- Initialize UI
	self:_createUI()
	
	return self
end

-- Create the UI elements
function DirectionalCasting:_createUI()
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create ScreenGui
	self.screenGui = Instance.new("ScreenGui")
	self.screenGui.Name = "DirectionalCasting"
	self.screenGui.Parent = playerGui
	
	-- Create container
	self.container = Instance.new("Frame")
	self.container.Name = "Container"
	self.container.Size = CONFIG.UI.SIZE
	self.container.Position = UDim2.fromScale(0.5, 0.5)
	self.container.AnchorPoint = Vector2.new(0.5, 0.5)
	self.container.BackgroundColor3 = CONFIG.COLORS.background
	self.container.BackgroundTransparency = 1
	self.container.Parent = self.screenGui

	-- Add rounded corners to container
	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 10)
	containerCorner.Parent = self.container
	
	-- Create center indicator
	self.center = Instance.new("Frame")
	self.center.Name = "Center"
	self.center.Size = CONFIG.UI.CENTER_SIZE
	self.center.Position = UDim2.fromScale(0.5, 0.5)
	self.center.AnchorPoint = Vector2.new(0.5, 0.5)
	self.center.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	self.center.BackgroundTransparency = 1
	self.center.Visible = false
	self.center.Parent = self.container
	
	local centerCorner = Instance.new("UICorner")
	centerCorner.CornerRadius = UDim.new(1, 0)
	centerCorner.Parent = self.center
	
	-- Create triangles
	self:_createTriangles()
end

-- Create directional triangles
function DirectionalCasting:_createTriangles()
	local directions = {
		{name = "UP", text = "▲", position = UDim2.fromScale(0.5, 0.15)}, -- Moved closer to center
		{name = "DOWN", text = "▼", position = UDim2.fromScale(0.5, 0.8)},
		{name = "LEFT", text = "◀", position = UDim2.fromScale(0.2, 0.5)},
		{name = "RIGHT", text = "▶", position = UDim2.fromScale(0.8, 0.5)}
	}
	
	for _, dir in pairs(directions) do
		local triangle = Instance.new("TextLabel")
		triangle.Name = dir.name
		triangle.Size = CONFIG.UI.TRIANGLE_SIZE
		triangle.Position = dir.position
		triangle.AnchorPoint = Vector2.new(0.5, 0.5)
		triangle.BackgroundTransparency = 1
		triangle.Text = dir.text
		triangle.TextColor3 = CONFIG.COLORS.inactive
		triangle.TextSize = 30
		triangle.TextStrokeTransparency = 0
		triangle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		triangle.Font = Enum.Font.SourceSansBold
		triangle.Visible = false
		triangle.Parent = self.container
		
		self.triangles[dir.name] = triangle
	end
end

-- Format sequence to compact string (e.g., "DULR")
function DirectionalCasting:_formatSequence(sequence)
	local formatted = ""
	for _, direction in ipairs(sequence) do
		formatted = formatted .. string.sub(direction, 1, 1)
	end
	return formatted
end

-- Update Library StateManager states
function DirectionalCasting:_updateStates()
	if not self.Character then return end
	
	-- Find or create Actions state container
	local actionsState = self.Character:FindFirstChild("Actions")
	if not actionsState then
		actionsState = Instance.new("StringValue")
		actionsState.Name = "Actions"
		actionsState.Value = "[]"
		actionsState.Parent = self.Character
	end
	
	-- Update casting state
	if self.isCasting then
		Library.AddState(actionsState, "IsCasting")
	else
		Library.RemoveState(actionsState, "IsCasting")
	end
	
	-- Update modifying state
	if self.isModifying then
		Library.AddState(actionsState, "IsModifying")
	else
		Library.RemoveState(actionsState, "IsModifying")
	end
	
	-- Fire state change event
	self._onCastingStateChangedEvent:Fire(self.isCasting, self.isModifying)
end

-- Reduce camera sensitivity during casting
function DirectionalCasting:_reduceCameraSensitivity()
	if self.originalMouseSensitivity then return end -- Already reduced

	-- Store original sensitivity
	self.originalMouseSensitivity = UserInputService.MouseDeltaSensitivity

	-- Reduce sensitivity during casting
	UserInputService.MouseDeltaSensitivity = self.originalMouseSensitivity * CONFIG.CAMERA.CASTING_SENSITIVITY

	-- print("📷 Camera sensitivity reduced for casting")
end

-- Restore camera sensitivity after casting
function DirectionalCasting:_restoreCameraSensitivity()
	if not self.originalMouseSensitivity then return end -- Not reduced

	-- Restore original sensitivity
	UserInputService.MouseDeltaSensitivity = self.originalMouseSensitivity
	self.originalMouseSensitivity = nil

	-- print("📷 Camera sensitivity restored")
end

-- Start casting
function DirectionalCasting:StartCasting()
	if self.isCasting then return end
	
	self.isCasting = true
	self.isModifying = false
	self.directionSequence = {}
	self.modifierSequence = {}
	self.savedBaseSequence = {}
	self.currentTriangle = nil
	
	-- Update states
	self:_updateStates()
	
	-- Reduce camera sensitivity during casting
	self:_reduceCameraSensitivity()

	-- Show UI with animations
	self:_showUI()

	-- Start input tracking
	self:_startInputTracking()

	-- print("🎯 CASTING STARTED - Move mouse to triangles (camera sensitivity reduced)")
end

-- Enter modifier mode
function DirectionalCasting:EnterModifierMode()
	if not self.isCasting then return end
	
	self.isModifying = true
	
	-- Save current base sequence
	self.savedBaseSequence = {}
	for i, direction in ipairs(self.directionSequence) do
		self.savedBaseSequence[i] = direction
	end
	
	-- Start fresh modifier sequence
	self.modifierSequence = {}
	
	-- Update states
	self:_updateStates()
	
	-- Update triangle colors to red
	self:_updateTriangleColors()
	
	-- print("🔧 MODIFIER MODE ACTIVATED - Triangles are now red")
	-- print("💾 Base sequence saved: " .. self:_formatSequence(self.savedBaseSequence))
	-- print("🆕 Starting fresh modifier sequence...")
end

-- Stop casting and process results
function DirectionalCasting:StopCasting()
	if not self.isCasting then return end
	
	local baseSequence = ""
	local modifierSequence = ""
	
	if self.isModifying then
		-- We're in modifier mode - return both sequences
		baseSequence = self:_formatSequence(self.savedBaseSequence)
		modifierSequence = self:_formatSequence(self.modifierSequence)
		
		-- print("🛑 STOPPED! Final Results:")
		-- print("📋 Base sequence: " .. baseSequence .. " (Total: " .. #self.savedBaseSequence .. ")")
		-- print("🔧 Modifier sequence: " .. modifierSequence .. " (Total: " .. #self.modifierSequence .. ")")
	else
		-- Normal casting mode
		baseSequence = self:_formatSequence(self.directionSequence)
		
		-- print("✨ CAST COMPLETE! Sequence: " .. baseSequence)
		-- print("📊 Total directions: " .. #self.directionSequence)
	end
	
	-- Fire completion event
	self._onSequenceCompleteEvent:Fire(baseSequence, modifierSequence, self.isModifying)
	
	-- Reset state
	self.isCasting = false
	self.isModifying = false

	-- Restore camera sensitivity
	self:_restoreCameraSensitivity()

	-- Update states
	self:_updateStates()

	-- Hide UI
	self:_hideUI()

	-- Stop input tracking
	self:_stopInputTracking()
end

-- Check if a sequence matches any known combination
function DirectionalCasting:CheckCombination(sequence)
	for moveName, combination in pairs(Combinations) do
		if type(combination) == "string" then
			if combination == sequence then
				return moveName
			end
		elseif type(combination) == "table" and combination.base then
			if combination.base == sequence then
				return moveName, "base"
			end
		end
	end
	return nil
end

-- Destroy the casting system
function DirectionalCasting:Destroy()
	self:_stopInputTracking()

	-- Ensure camera sensitivity is restored
	self:_restoreCameraSensitivity()

	if self.screenGui then
		self.screenGui:Destroy()
	end
	
	if self._onSequenceCompleteEvent then
		self._onSequenceCompleteEvent:Destroy()
	end

	if self._onCastingStateChangedEvent then
		self._onCastingStateChangedEvent:Destroy()
	end
end

-- Show UI with fade-in animations
function DirectionalCasting:_showUI()
	local tweenInfo = TweenInfo.new(CONFIG.ANIMATION.DURATION, CONFIG.ANIMATION.STYLE, CONFIG.ANIMATION.DIRECTION)

	-- Show container background
	local containerTween = TweenService:Create(self.container, tweenInfo, {
		BackgroundTransparency = 0.8
	})
	containerTween:Play()

	-- Show center indicator
	self.center.BackgroundTransparency = 1
	self.center.Visible = true
	local centerTween = TweenService:Create(self.center, tweenInfo, {
		BackgroundTransparency = 0
	})
	centerTween:Play()

	-- Show triangles
	for _, triangle in pairs(self.triangles) do
		triangle.TextTransparency = 1
		triangle.TextStrokeTransparency = 1
		triangle.Visible = true

		local triangleTween = TweenService:Create(triangle, tweenInfo, {
			TextTransparency = 0,
			TextStrokeTransparency = 0
		})
		triangleTween:Play()
	end
end

-- Hide UI with fade-out animations
function DirectionalCasting:_hideUI()
	local tweenInfo = TweenInfo.new(CONFIG.ANIMATION.DURATION, CONFIG.ANIMATION.STYLE, CONFIG.ANIMATION.DIRECTION)

	-- Hide container background
	local containerTween = TweenService:Create(self.container, tweenInfo, {
		BackgroundTransparency = 1
	})
	containerTween:Play()

	-- Hide center indicator
	local centerTween = TweenService:Create(self.center, tweenInfo, {
		BackgroundTransparency = 1
	})
	centerTween:Play()
	centerTween.Completed:Connect(function()
		self.center.Visible = false
	end)

	-- Hide triangles
	for _, triangle in pairs(self.triangles) do
		local triangleTween = TweenService:Create(triangle, tweenInfo, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			TextColor3 = CONFIG.COLORS.inactive,
			TextSize = 30
		})
		triangleTween:Play()

		triangleTween.Completed:Connect(function()
			triangle.Visible = false
		end)
	end
end

-- Update triangle colors based on mode
function DirectionalCasting:_updateTriangleColors()
	for _, triangle in pairs(self.triangles) do
		if self.isModifying then
			triangle.TextColor3 = CONFIG.COLORS.modifier
		else
			triangle.TextColor3 = CONFIG.COLORS.inactive
		end
	end
end

-- Start input tracking
function DirectionalCasting:_startInputTracking()
	-- Mouse movement tracking
	self.connections.mouseMove = RunService.Heartbeat:Connect(function()
		self:_updateMouseTracking()
	end)
end

-- Stop input tracking
function DirectionalCasting:_stopInputTracking()
	for _, connection in pairs(self.connections) do
		if connection then
			connection:Disconnect()
		end
	end
	self.connections = {}
end

-- Update mouse tracking and direction detection
function DirectionalCasting:_updateMouseTracking()
	if not self.isCasting then return end

	local mouse
	local containerPos = self.container.AbsolutePosition
	local containerSize = self.container.AbsoluteSize
	local centerX = containerPos.X + containerSize.X / 2
	local centerY = containerPos.Y + containerSize.Y / 2

	-- Handle shift lock compatibility
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		local mouseDelta = UserInputService:GetMouseDelta()
		mouse = Vector2.new(centerX + mouseDelta.X * CONFIG.UI.MOUSE_SENSITIVITY, centerY + mouseDelta.Y * CONFIG.UI.MOUSE_SENSITIVITY)
	else
		mouse = UserInputService:GetMouseLocation()
	end

	local distance = (mouse - Vector2.new(centerX, centerY)).Magnitude

	-- Check if in dead zone
	if distance < CONFIG.UI.DEAD_ZONE then
		self:_setCurrentTriangle(nil)
		return
	end

	-- Calculate angle and determine direction
	local angle = math.atan2(mouse.Y - centerY, mouse.X - centerX)
	local degrees = math.deg(angle)
	if degrees < 0 then degrees = degrees + 360 end

	local direction = self:_getDirectionFromAngle(degrees)
	if direction then
		self:_setCurrentTriangle(self.triangles[direction])
		self:_addDirectionToSequence(direction)
	end
end

-- Get direction from angle with custom sensitivity zones
function DirectionalCasting:_getDirectionFromAngle(degrees)
	-- UP: 225° - 315° (90° range) - Much larger zone, easier to reach
	if degrees >= 225 and degrees <= 315 then
		return "UP"
	-- RIGHT: 315° - 45° (90° range)
	elseif degrees >= 315 or degrees <= 45 then
		return "RIGHT"
	-- DOWN: 75° - 105° (30° range) - less sensitive
	elseif degrees >= 75 and degrees <= 105 then
		return "DOWN"
	-- LEFT: 135° - 225° (90° range)
	elseif degrees >= 135 and degrees <= 225 then
		return "LEFT"
	end

	return nil
end

-- Set current triangle highlight
function DirectionalCasting:_setCurrentTriangle(triangle)
	-- Reset previous triangle
	if self.currentTriangle and self.currentTriangle ~= triangle then
		local resetColor = self.isModifying and CONFIG.COLORS.modifier or CONFIG.COLORS.inactive
		local resetTween = TweenService:Create(self.currentTriangle, TweenInfo.new(0.1), {
			TextColor3 = resetColor,
			TextSize = 30
		})
		resetTween:Play()
	end

	-- Highlight new triangle
	if triangle then
		local hoverColor = self.isModifying and CONFIG.COLORS.modifierHover or CONFIG.COLORS.hover
		local hoverTween = TweenService:Create(triangle, TweenInfo.new(0.1), {
			TextColor3 = hoverColor,
			TextSize = 35
		})
		hoverTween:Play()
	end

	self.currentTriangle = triangle
end

-- Add direction to appropriate sequence
function DirectionalCasting:_addDirectionToSequence(direction)
	if self.isModifying then
		-- Add to modifier sequence
		if #self.modifierSequence == 0 or self.modifierSequence[#self.modifierSequence] ~= direction then
			table.insert(self.modifierSequence, direction)
			local formatted = self:_formatSequence(self.modifierSequence)
			-- print("🔧 Added modifier direction: " .. direction .. " (Sequence: " .. formatted .. ")")
		end
	else
		-- Add to base sequence
		if #self.directionSequence == 0 or self.directionSequence[#self.directionSequence] ~= direction then
			table.insert(self.directionSequence, direction)
			local formatted = self:_formatSequence(self.directionSequence)
			-- print("📍 Added direction: " .. direction .. " (Sequence: " .. formatted .. ")")
		end
	end
end

return DirectionalCasting
