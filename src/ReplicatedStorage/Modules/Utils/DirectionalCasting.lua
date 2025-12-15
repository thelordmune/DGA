--[[
	DirectionalCasting Module
	
	A modular directional input system for alchemy casting with mouse/gamepad support.
	Integrates with Library StateManager for state tracking.
	
	Usage:
		local Casting = require(ReplicatedStorage.Modules.Utils.DirectionalCasting)
		local caster = Casting.new()
		
		caster.OnSequenceComplete:Connect(function(sequence, isModifier)
			---- print("Cast:", sequence, "Modifier:", isModifier)
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
local CastingComponent = require(ReplicatedStorage.Client.Components.Casting)

local DirectionalCasting = {}
DirectionalCasting.__index = DirectionalCasting

-- Configuration
local CONFIG = {
	UI = {
		SIZE = UDim2.fromOffset(200, 200),
		CENTER_SIZE = UDim2.fromOffset(10, 10),
		TRIANGLE_SIZE = UDim2.fromOffset(40, 40),
		DEAD_ZONE = 30, -- Reduced from 50 to make alchemy easier in shift lock
		MOUSE_SENSITIVITY = 8 -- Increased from 5 for better shift lock responsiveness
	},
	CAMERA = {
		CASTING_SENSITIVITY = 0.36 -- Reduce camera sensitivity to 20% during casting
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
	self.accumulatedMouseDelta = Vector2.new(0, 0) -- For shift-lock mode mouse reset
	self.lastRegisteredDirection = nil -- Track last registered direction to prevent repeats
	self.inDeadZone = false -- Track if currently in dead zone
	self.deadZoneEnterTime = 0 -- Time when entered dead zone

	-- ZXC sequence tracking
	self.zxcSequence = {} -- Tracks Z/X/C key presses in order

	-- Casting cooldown
	self.lastCastTime = 0
	self.castCooldown = 3.5 -- 3.5 second cooldown between casts (gives time for UI reset)

	-- UI Components
	self.screenGui = nil
	self.container = nil
	self.center = nil
	self.triangles = {}
	self.connections = {}
	self.castingUI = nil -- The new Casting component API

	-- Camera sensitivity control during casting
	self.originalMouseSensitivity = nil

	-- Initialize UI
	self:_createUI()

	return self
end

-- Create the UI elements
function DirectionalCasting:_createUI()
	-- Wait for the Health component to be initialized and get the casting API from it
	task.spawn(function()
		local playerGui = player:WaitForChild("PlayerGui")
		local screenGui = playerGui:WaitForChild("ScreenGui", 10)
		if not screenGui then
			warn("[DirectionalCasting] ScreenGui not found!")
			return
		end

		local statsFrame = screenGui:WaitForChild("Stats", 10)
		if not statsFrame then
			warn("[DirectionalCasting] Stats frame not found!")
			return
		end

		-- Wait for the Health component's Holder frame to appear
		local holderFrame = statsFrame:WaitForChild("Holder", 10)
		if not holderFrame then
			warn("[DirectionalCasting] Holder frame not found!")
			return
		end

		-- Wait for the Casting Frame to appear inside Holder
		local castingFrame = holderFrame:WaitForChild("Frame", 10)
		if not castingFrame then
			warn("[DirectionalCasting] Casting Frame not found!")
			return
		end

		-- Get the casting API from the Stats module
		-- We'll access it through a global reference set by Stats.lua
		local Client = require(ReplicatedStorage.Client)
		if Client.Stats and Client.Stats.healthComponentData and Client.Stats.healthComponentData.castingAPI then
			self.castingUI = Client.Stats.healthComponentData.castingAPI
			print("[DirectionalCasting] ✅ Connected to Health component's casting UI")
		else
			warn("[DirectionalCasting] Could not find castingAPI in Stats module")
		end
	end)
end

-- Create directional triangles
function DirectionalCasting:_createTriangles()
	-- Directional triangles are disabled for ZXC casting system
	-- We use the Fusion-based Casting component instead
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

-- Lock character rotation during casting (shift lock mode)
function DirectionalCasting:_lockCharacterRotation()
	if self.rotationLocked then return end -- Already locked

	-- Check if in shift lock mode
	local isShiftLock = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter

	if isShiftLock and self.Character then
		local humanoid = self.Character:FindFirstChild("Humanoid")

		if humanoid then
			-- Store original AutoRotate state
			self.originalAutoRotate = humanoid.AutoRotate

			-- Disable AutoRotate to prevent character from rotating with mouse movement
			humanoid.AutoRotate = false

			self.rotationLocked = true

			-- ---- print("🔒 AutoRotate DISABLED for casting (shift lock mode)")
		end
	end
end

-- Unlock character rotation after casting
function DirectionalCasting:_unlockCharacterRotation()
	if not self.rotationLocked then return end

	-- Restore AutoRotate
	if self.Character then
		local humanoid = self.Character:FindFirstChild("Humanoid")
		if humanoid and self.originalAutoRotate ~= nil then
			humanoid.AutoRotate = self.originalAutoRotate
		end
	end

	self.rotationLocked = false
	self.originalAutoRotate = nil

	-- ---- print("🔓 AutoRotate restored")
end

-- Reduce camera sensitivity during casting (for non-shift-lock mode)
function DirectionalCasting:_reduceCameraSensitivity()
	if self.originalMouseSensitivity then return end -- Already reduced

	-- Check if in shift lock mode
	local isShiftLock = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter

	if not isShiftLock then
		-- Normal mode: reduce sensitivity
		self.originalMouseSensitivity = UserInputService.MouseDeltaSensitivity
		UserInputService.MouseDeltaSensitivity = self.originalMouseSensitivity * CONFIG.CAMERA.CASTING_SENSITIVITY
		-- ---- print("📷 Camera sensitivity reduced for casting")
	end
end

-- Restore camera sensitivity after casting
function DirectionalCasting:_restoreCameraSensitivity()
	if not self.originalMouseSensitivity then return end -- Not reduced

	-- Restore original sensitivity
	UserInputService.MouseDeltaSensitivity = self.originalMouseSensitivity
	self.originalMouseSensitivity = nil

	-- ---- print("📷 Camera sensitivity restored")
end

-- Start casting
function DirectionalCasting:StartCasting()
	if self.isCasting then return end

	-- Check cooldown
	local currentTime = tick()
	if currentTime - self.lastCastTime < self.castCooldown then
		return
	end

	self.isCasting = true
	self.lastCastTime = currentTime
	self.isModifying = false
	self.directionSequence = {}
	self.modifierSequence = {}
	self.savedBaseSequence = {}
	self.currentTriangle = nil
	self.accumulatedMouseDelta = Vector2.new(0, 0) -- Reset accumulated delta
	self.lastRegisteredDirection = nil -- Reset last registered direction
	self.zxcSequence = {} -- Reset ZXC sequence

	-- Update states
	self:_updateStates()

	-- Lock character rotation if in shift lock mode
	self:_lockCharacterRotation()

	-- Reduce camera sensitivity during casting (for non-shift-lock)
	self:_reduceCameraSensitivity()

	-- Show UI with animations
	self:_showUI()

	-- Start the new Casting UI component
	if self.castingUI then
		self.castingUI.Start()
	end

	-- Start input tracking
	self:_startInputTracking()

	-- ---- print("🎯 CASTING STARTED - Move mouse to triangles")
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
	
	-- ---- print("🔧 MODIFIER MODE ACTIVATED - Triangles are now red")
	-- ---- print("💾 Base sequence saved: " .. self:_formatSequence(self.savedBaseSequence))
	-- ---- print("🆕 Starting fresh modifier sequence...")
end

-- Stop casting and process results
function DirectionalCasting:StopCasting()
	if not self.isCasting then return end

	-- Use ZXC sequence instead of directional sequence
	local baseSequence = table.concat(self.zxcSequence, "")
	local modifierSequence = ""

	-- For now, we don't use modifier mode with ZXC
	-- If needed in the future, we can implement it similar to directional mode

	-- Fire completion event with ZXC sequence
	self._onSequenceCompleteEvent:Fire(baseSequence, modifierSequence, false)

	-- Set the last cast time to prevent immediate recasting
	self.lastCastTime = tick()

	-- Reset state
	self.isCasting = false
	self.isModifying = false

	-- Unlock character rotation (if it was locked)
	self:_unlockCharacterRotation()

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

	-- Ensure character rotation is unlocked
	self:_unlockCharacterRotation()

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
	-- Old directional UI is now hidden - only the new Casting component is shown
	-- The new Casting UI is started in StartCasting() via castingUI.Start()
end

-- Hide UI with fade-out animations
function DirectionalCasting:_hideUI()
	-- Old directional UI is now hidden - the new Casting component handles its own cleanup
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
	-- Mouse movement tracking - Use RenderStepped for faster, more accurate input detection
	self.connections.mouseMove = RunService.RenderStepped:Connect(function()
		self:_updateMouseTracking()
	end)

	-- ZXC key tracking for stopping rotations in Casting UI
	self.connections.keyInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not self.isCasting then return end

		-- Check for Z, X, or C keys
		local keyPressed = nil
		if input.KeyCode == Enum.KeyCode.Z then
			keyPressed = "Z"
		elseif input.KeyCode == Enum.KeyCode.X then
			keyPressed = "X"
		elseif input.KeyCode == Enum.KeyCode.C then
			keyPressed = "C"
		end

		if keyPressed then
			-- Add to sequence
			table.insert(self.zxcSequence, keyPressed)

			-- Stop a rotation in the UI and pass the key for display
			if self.castingUI then
				self.castingUI.StopRotation(keyPressed)
			end
		end
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
	-- Mouse tracking is disabled for ZXC casting system
	-- We use Z/X/C key presses instead of directional mouse input
	-- This function is kept for backwards compatibility but does nothing
end

-- Get direction from angle with custom sensitivity zones
function DirectionalCasting:_getDirectionFromAngle(degrees)
	-- Standard math angles: 0° = right, 90° = down, 180° = left, 270° = up

	-- RIGHT: 315° - 45° (90° range, wraps around 0°) - Large zone
	if degrees >= 315 or degrees <= 45 then
		return "RIGHT"
	-- LEFT: 135° - 225° (90° range) - Large zone
	elseif degrees > 135 and degrees <= 225 then
		return "LEFT"
	-- DOWN: 75° - 105° (30° range) - Very small zone, hard to trigger
	elseif degrees > 75 and degrees <= 105 then
		return "DOWN"
	-- UP: 255° - 285° (30° range) - Very small zone, hard to trigger
	elseif degrees > 255 and degrees < 285 then
		return "UP"
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
			-- ---- print("🔧 Added modifier direction: " .. direction .. " (Sequence: " .. formatted .. ")")
		end
	else
		-- Add to base sequence
		if #self.directionSequence == 0 or self.directionSequence[#self.directionSequence] ~= direction then
			table.insert(self.directionSequence, direction)
			local formatted = self:_formatSequence(self.directionSequence)
			-- ---- print("📍 Added direction: " .. direction .. " (Sequence: " .. formatted .. ")")
		end
	end
end

return DirectionalCasting
