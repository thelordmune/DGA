local camera = workspace.CurrentCamera
local targetPart = workspace.menuthing.BrokenArm:WaitForChild("Hand")
local stone = workspace.Gem

camera.CameraType = Enum.CameraType.Scriptable
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TInfo = TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, true)

-- Camera offset from target
local heightOffset = 5 -- How high above
local backwardOffset = 0 -- How far back (positive = behind, negative = in front)
local sideOffset = 0 -- How far to the side (positive = right, negative = left)

-- Rotation adjustment (in degrees) - adjust these to rotate the camera view
local rotationAngle = -90 -- Rotate the camera around the target (0-360 degrees)

-- Mouse parallax settings
local maxMouseOffset = 2 -- Maximum distance the camera can shift from mouse movement
local mouseSensitivity = 0.5 -- How much the mouse affects the camera (0-1)
local lerpSpeed = 0.1 -- How smoothly the camera follows mouse (0-1, lower = smoother)

local cameraOffset = Vector3.new(sideOffset, heightOffset, backwardOffset)
local currentMouseOffset = Vector3.new(0, 0, 0)

-- Get screen center
local function getMouseDelta()
	local mouseLocation = UserInputService:GetMouseLocation()
	local screenSize = camera.ViewportSize

	-- Calculate normalized mouse position (-1 to 1)
	local normalizedX = ((mouseLocation.X / screenSize.X) - 0.5) * 2
	local normalizedY = ((mouseLocation.Y / screenSize.Y) - 0.5) * 2

	return normalizedX, normalizedY
end

game:GetService("RunService").RenderStepped:Connect(function()
	-- Get mouse offset
	local mouseX, mouseY = getMouseDelta()

	-- Calculate target offset based on mouse position (in 2D screen space)
	local screenOffsetX = mouseX * maxMouseOffset * mouseSensitivity
	local screenOffsetY = mouseY * maxMouseOffset * mouseSensitivity

	-- Lerp the 2D offsets
	local targetOffsetX = screenOffsetX
	local targetOffsetY = screenOffsetY

	currentMouseOffset = currentMouseOffset:Lerp(
		Vector3.new(targetOffsetX, targetOffsetY, 0),
		lerpSpeed
	)

	-- Apply base offset
	local targetPosition = targetPart.Position
	local cameraPosition = targetPosition + cameraOffset

	-- Create base CFrame looking at target
	local baseCFrame = CFrame.lookAt(cameraPosition, targetPosition)

	-- Apply rotation around the viewing axis
	local rotatedCFrame = baseCFrame * CFrame.Angles(0, 0, math.rad(rotationAngle))

	-- Apply mouse offset in camera's local space (so it moves relative to view, not world)
	local finalCFrame = rotatedCFrame * CFrame.new(currentMouseOffset.X, currentMouseOffset.Y, 0)

	camera.CFrame = finalCFrame
end)

TweenService:Create(stone.Highlight, TInfo, {FillColor = Color3.fromRGB(0,0,0)}):Play()

task.delay(3, function()
	script.Sound:Play()
end)

