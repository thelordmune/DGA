--!nonstrict
--[[
	MouseLockController - Replacement for ShiftLockController, manages use of mouse-locked mode
	2018 Camera Update - AllYourBlox
--]]

--[[ Constants ]]--

local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
local DEFAULT_MOUSE_LOCK_CURSOR = "rbxassetid://136407814892642"

local CONTEXT_ACTION_NAME = "MouseLockSwitchAction"
local MOUSELOCK_ACTION_PRIORITY = Enum.ContextActionPriority.Medium.Value
local CAMERA_OFFSET_DEFAULT = Vector3.new(1.75,0,0)  

--[[ Services ]]--
local PlayersService = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Settings = UserSettings()	-- ignore warning
local GameSettings = Settings.GameSettings

--[[ Imports ]]
local CameraUtils = require(script.Parent:WaitForChild("CameraUtils"))

local FFlagUserFixCameraOffsetJitter = FlagUtil.getUserFlag("UserFixCameraOffsetJitter2")

--[[ The Module ]]--
local MouseLockController = {}
MouseLockController.__index = MouseLockController

function MouseLockController.new()
	local self = setmetatable({}, MouseLockController)

	self.isMouseLocked = false
	self.savedMouseCursor = nil
	self.boundKeys = {Enum.KeyCode.LeftAlt, Enum.KeyCode.RightShift} -- defaults

	self.mouseLockToggledEvent = Instance.new("BindableEvent")

	-- Smooth transition properties
	self.transitionStartTime = 0
	self.transitionDuration = 0.5 -- 0.5 second transition
	self.isTransitioning = false
	self.startOffset = Vector3.new()
	self.targetOffset = Vector3.new()
	self.currentOffset = Vector3.new()

	-- Icon rotation
	self.iconRotation = 0
	self.rotationConnection = nil

	local boundKeysObj = script:FindFirstChild("BoundKeys")
	if (not boundKeysObj) or (not boundKeysObj:IsA("StringValue")) then
		-- If object with correct name was found, but it's not a StringValue, destroy and replace
		if boundKeysObj then
			boundKeysObj:Destroy()
		end

		boundKeysObj = Instance.new("StringValue")
		-- Luau FIXME: should be able to infer from assignment above that boundKeysObj is not nil
		assert(boundKeysObj, "")
		boundKeysObj.Name = "BoundKeys"
		boundKeysObj.Value = "LeftAlt,RightShift"
		boundKeysObj.Parent = script
	end

	if boundKeysObj then
		boundKeysObj.Changed:Connect(function(value)
			self:OnBoundKeysObjectChanged(value)
		end)
		self:OnBoundKeysObjectChanged(boundKeysObj.Value) -- Initial setup call
	end

	-- Watch for changes to user's ControlMode and ComputerMovementMode settings and update the feature availability accordingly
	GameSettings.Changed:Connect(function(property)
		if property == "ControlMode" or property == "ComputerMovementMode" then
			self:UpdateMouseLockAvailability()
		end
	end)

	-- Watch for changes to DevEnableMouseLock and update the feature availability accordingly
	PlayersService.LocalPlayer:GetPropertyChangedSignal("DevEnableMouseLock"):Connect(function()
		self:UpdateMouseLockAvailability()
	end)

	-- Watch for changes to DevEnableMouseLock and update the feature availability accordingly
	PlayersService.LocalPlayer:GetPropertyChangedSignal("DevComputerMovementMode"):Connect(function()
		self:UpdateMouseLockAvailability()
	end)

	self:UpdateMouseLockAvailability()

	return self
end

function MouseLockController:GetIsMouseLocked()
	return self.isMouseLocked
end

function MouseLockController:GetBindableToggleEvent()
	return self.mouseLockToggledEvent.Event
end

function MouseLockController:GetMouseLockOffset()
	-- Update smooth transition if active
	if self.isTransitioning then
		local elapsed = tick() - self.transitionStartTime
		local progress = math.min(elapsed / self.transitionDuration, 1)

		-- Cubic ease-out for smooth transition
		local easedProgress = 1 - (1 - progress) ^ 3

		-- Interpolate between start and target offset
		self.currentOffset = self.startOffset:Lerp(self.targetOffset, easedProgress)

		-- End transition when complete
		if progress >= 1 then
			self.isTransitioning = false
			self.currentOffset = self.targetOffset
		end
	end

	-- Return the smoothly transitioning offset if transitioning, otherwise default
	if self.isTransitioning or self.isMouseLocked then
		return self.currentOffset
	end

	if FFlagUserFixCameraOffsetJitter then
		return CAMERA_OFFSET_DEFAULT
	else
		local offsetValueObj: Vector3Value = script:FindFirstChild("CameraOffset") :: Vector3Value
		if offsetValueObj and offsetValueObj:IsA("Vector3Value") then
			return offsetValueObj.Value
		else
			-- If CameraOffset object was found but not correct type, destroy
			if offsetValueObj then
				offsetValueObj:Destroy()
			end
			offsetValueObj = Instance.new("Vector3Value")
			assert(offsetValueObj, "")
			offsetValueObj.Name = "CameraOffset"
			offsetValueObj.Value = Vector3.new(1.75,0,0) -- Legacy Default Value
			offsetValueObj.Parent = script
		end

		if offsetValueObj and offsetValueObj.Value then
			return offsetValueObj.Value
		end

		return Vector3.new(1.75,0,0)
	end
end

function MouseLockController:UpdateMouseLockAvailability()
	local devAllowsMouseLock = PlayersService.LocalPlayer.DevEnableMouseLock
	local devMovementModeIsScriptable = PlayersService.LocalPlayer.DevComputerMovementMode == Enum.DevComputerMovementMode.Scriptable
	local userHasMouseLockModeEnabled = GameSettings.ControlMode == Enum.ControlMode.MouseLockSwitch
	local userHasClickToMoveEnabled =  GameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove
	local MouseLockAvailable = devAllowsMouseLock and userHasMouseLockModeEnabled and not userHasClickToMoveEnabled and not devMovementModeIsScriptable

	if MouseLockAvailable~=self.enabled then
		self:EnableMouseLock(MouseLockAvailable)
	end
end

function MouseLockController:OnBoundKeysObjectChanged(newValue: string)
	self.boundKeys = {} -- Overriding defaults, note: possibly with nothing at all if boundKeysObj.Value is "" or contains invalid values
	for token in string.gmatch(newValue,"[^%s,]+") do
		for _, keyEnum in pairs(Enum.KeyCode:GetEnumItems()) do
			if token == keyEnum.Name then
				self.boundKeys[#self.boundKeys+1] = keyEnum :: Enum.KeyCode
				break
			end
		end
	end
	self:UnbindContextActions()
	self:BindContextActions()
end

--[[ Local Functions ]]--
function MouseLockController:OnMouseLockToggled()
	self.isMouseLocked = not self.isMouseLocked

	-- Start smooth transition
	self:StartSmoothTransition()

	if self.isMouseLocked then
		-- Start icon rotation
		self:StartIconRotation()

		local cursorImageValueObj: StringValue? = script:FindFirstChild("CursorImage") :: StringValue?
		if cursorImageValueObj and cursorImageValueObj:IsA("StringValue") and cursorImageValueObj.Value then
			CameraUtils.setMouseIconOverride(cursorImageValueObj.Value)
		else
			if cursorImageValueObj then
				cursorImageValueObj:Destroy()
			end
			cursorImageValueObj = Instance.new("StringValue")
			assert(cursorImageValueObj, "")
			cursorImageValueObj.Name = "CursorImage"
			cursorImageValueObj.Value = DEFAULT_MOUSE_LOCK_CURSOR
			cursorImageValueObj.Parent = script
			CameraUtils.setMouseIconOverride(DEFAULT_MOUSE_LOCK_CURSOR)
		end
	else
		-- Stop icon rotation
		self:StopIconRotation()
		CameraUtils.restoreMouseIcon()
	end

	self.mouseLockToggledEvent:Fire()
end

function MouseLockController:StartSmoothTransition()
	-- Set up transition from current offset to target offset
	if self.isMouseLocked then
		-- Transitioning TO shift lock
		self.startOffset = Vector3.new(0, 0, 0) -- Normal camera position
		self.targetOffset = CAMERA_OFFSET_DEFAULT -- Shift lock position
	else
		-- Transitioning FROM shift lock
		self.startOffset = self.currentOffset or CAMERA_OFFSET_DEFAULT
		self.targetOffset = Vector3.new(0, 0, 0) -- Back to normal
	end

	self.currentOffset = self.startOffset
	self.transitionStartTime = tick()
	self.isTransitioning = true
end

function MouseLockController:StartIconRotation()
	if self.rotationConnection then
		self.rotationConnection:Disconnect()
	end

	self.rotationConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self.iconRotation = self.iconRotation + (90 * deltaTime) -- 90 degrees per second

		-- Update cursor icon rotation if it exists
		local mouse = PlayersService.LocalPlayer:GetMouse()
		if mouse and mouse.Icon == DEFAULT_MOUSE_LOCK_CURSOR then
			-- Note: Roblox doesn't support cursor rotation, but we track it for potential custom cursor
		end
	end)
end

function MouseLockController:StopIconRotation()
	if self.rotationConnection then
		self.rotationConnection:Disconnect()
		self.rotationConnection = nil
	end
	self.iconRotation = 0
end

function MouseLockController:DoMouseLockSwitch(name, state, input)
	if state == Enum.UserInputState.Begin then
		self:OnMouseLockToggled()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function MouseLockController:BindContextActions()
	ContextActionService:BindActionAtPriority(CONTEXT_ACTION_NAME, function(name, state, input)
		return self:DoMouseLockSwitch(name, state, input)
	end, false, MOUSELOCK_ACTION_PRIORITY, unpack(self.boundKeys))
end

function MouseLockController:UnbindContextActions()
	ContextActionService:UnbindAction(CONTEXT_ACTION_NAME)
end

function MouseLockController:IsMouseLocked(): boolean
	return self.enabled and self.isMouseLocked
end

function MouseLockController:EnableMouseLock(enable: boolean)
	if enable ~= self.enabled then

		self.enabled = enable

		if self.enabled then
			-- Enabling the mode
			self:BindContextActions()
		else
			-- Disabling
			-- Restore mouse cursor
			CameraUtils.restoreMouseIcon()

			-- Stop icon rotation
			self:StopIconRotation()

			self:UnbindContextActions()

			-- If the mode is disabled while being used, fire the event to toggle it off
			if self.isMouseLocked then
				self.mouseLockToggledEvent:Fire()
			end

			self.isMouseLocked = false
			self.isTransitioning = false
		end

	end
end

return MouseLockController
