--[[
	Custom Shift Lock Icon System
	- Rotating icon animation
	- Smooth transition when entering/exiting shift lock
	- Fixes camera reset issues
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ShiftLockIcon = {}

-- Configuration
local ICON_SIZE = UDim2.fromOffset(32, 32)
local ICON_POSITION = UDim2.new(1, -50, 1, -50)
local ROTATION_SPEED = 90 -- degrees per second
local TRANSITION_TIME = 0.5 -- Match camera transition time

-- State tracking
local isShiftLocked = false
local iconGui = nil
local iconFrame = nil
local iconImage = nil
local rotationConnection = nil
local transitionTween = nil

-- Create the GUI
local function createShiftLockGui()
	-- Main ScreenGui
	iconGui = Instance.new("ScreenGui")
	iconGui.Name = "ShiftLockIcon"
	iconGui.ResetOnSpawn = false
	iconGui.IgnoreGuiInset = true
	iconGui.Parent = PlayerGui
	
	-- Icon Frame
	iconFrame = Instance.new("Frame")
	iconFrame.Name = "IconFrame"
	iconFrame.Size = ICON_SIZE
	iconFrame.Position = ICON_POSITION
	iconFrame.AnchorPoint = Vector2.new(1, 1)
	iconFrame.BackgroundTransparency = 1
	iconFrame.Parent = iconGui
	
	-- Icon Image
	iconImage = Instance.new("ImageLabel")
	iconImage.Name = "IconImage"
	iconImage.Size = UDim2.fromScale(1, 1)
	iconImage.Position = UDim2.fromScale(0.5, 0.5)
	iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
	iconImage.BackgroundTransparency = 1
	iconImage.Image = "rbxassetid://136407814892642" -- Default shift lock cursor
	iconImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
	iconImage.ImageTransparency = 1 -- Start hidden
	iconImage.Parent = iconFrame
	
	-- Add subtle glow effect
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(255, 255, 255)
	uiStroke.Thickness = 1
	uiStroke.Transparency = 1
	uiStroke.Parent = iconImage
end

-- Start rotation animation (every frame)
local function startRotation()
	if rotationConnection then
		rotationConnection:Disconnect()
	end

	rotationConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if iconImage then
			local currentRotation = iconImage.Rotation
			iconImage.Rotation = currentRotation + (ROTATION_SPEED * deltaTime)
		end
	end)
end

-- Stop rotation animation
local function stopRotation()
	if rotationConnection then
		rotationConnection:Disconnect()
		rotationConnection = nil
	end
end

-- Smooth transition into shift lock
local function transitionToShiftLock()
	if not iconImage then return end
	
	-- Cancel any existing tween
	if transitionTween then
		transitionTween:Cancel()
	end
	
	-- Tween in the icon
	local tweenInfo = TweenInfo.new(
		TRANSITION_TIME,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out
	)
	
	transitionTween = TweenService:Create(iconImage, tweenInfo, {
		ImageTransparency = 0,
		ImageColor3 = Color3.fromRGB(85, 170, 255) -- Blue tint when active
	})
	
	-- Also tween the stroke
	local strokeTween = TweenService:Create(iconImage.UIStroke, tweenInfo, {
		Transparency = 0.5
	})
	
	transitionTween:Play()
	strokeTween:Play()
	
	-- Start rotation
	startRotation()
end

-- Smooth transition out of shift lock
local function transitionFromShiftLock()
	if not iconImage then return end
	
	-- Cancel any existing tween
	if transitionTween then
		transitionTween:Cancel()
	end
	
	-- Tween out the icon
	local tweenInfo = TweenInfo.new(
		TRANSITION_TIME,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.In
	)
	
	transitionTween = TweenService:Create(iconImage, tweenInfo, {
		ImageTransparency = 1,
		ImageColor3 = Color3.fromRGB(255, 255, 255) -- Back to white
	})
	
	-- Also tween the stroke
	local strokeTween = TweenService:Create(iconImage.UIStroke, tweenInfo, {
		Transparency = 1
	})
	
	transitionTween:Play()
	strokeTween:Play()
	
	-- Stop rotation after transition
	transitionTween.Completed:Connect(function()
		stopRotation()
		if iconImage then
			iconImage.Rotation = 0 -- Reset rotation
		end
	end)
end

-- Monitor shift lock state
local function monitorShiftLock()
	RunService.Heartbeat:Connect(function()
		local currentShiftLock = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		
		if currentShiftLock ~= isShiftLocked then
			isShiftLocked = currentShiftLock
			
			if isShiftLocked then
				transitionToShiftLock()
			else
				transitionFromShiftLock()
			end
		end
	end)
end

-- Initialize the system
function ShiftLockIcon.Init()
	-- Create GUI
	createShiftLockGui()
	
	-- Start monitoring
	monitorShiftLock()
	
	print("Shift Lock Icon system initialized")
end

-- Cleanup function
function ShiftLockIcon.Cleanup()
	stopRotation()
	
	if transitionTween then
		transitionTween:Cancel()
	end
	
	if iconGui then
		iconGui:Destroy()
	end
end

-- Initialize automatically
ShiftLockIcon.Init()

return ShiftLockIcon
