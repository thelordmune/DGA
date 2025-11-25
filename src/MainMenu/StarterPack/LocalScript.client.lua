repeat task.wait() until game:IsLoaded()

local camera = workspace.CurrentCamera
local targetPart = workspace.menuthing.BrokenArm:WaitForChild("Hand")
local stone = workspace:WaitForChild("Gem")
local player = game:GetService("Players").LocalPlayer
local plrGui = player.PlayerGui
local pl = workspace.menuthing.Holder.PointLight
local hf = workspace.menuthing.BrokenArm:WaitForChild("HandFoundation")

camera.CameraType = Enum.CameraType.Scriptable
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TInfo = TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, true)
local TInfo2 = TweenInfo.new(2, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, -1, true)
local tinfo1 = TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut)
local intermission = plrGui.Intermission
if intermission then
	intermission.Enabled = true
end

local Fusion = require(game:GetService("ReplicatedStorage").Modules.Fusion)

local Children, scoped, peek, out, OnEvent, Value, Computed, Tween = 
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.Value, Fusion.Computed, Fusion.Tween


local scope = scoped(Fusion, { Play = require(game:GetService("ReplicatedStorage").Modules.Components.Play) })

local heightOffset = 5
local backwardOffset = 0
local sideOffset = 0

local rotationAngle = -100

local maxMouseOffset = 1
local mouseSensitivity = 0.25
local lerpSpeed = 0.1

local cameraOffset = Vector3.new(sideOffset, heightOffset, backwardOffset)
local currentMouseOffset = Vector3.new(0, 0, 0)
camera.FieldOfView = 70


local function getMouseDelta()
	local mouseLocation = UserInputService:GetMouseLocation()
	local screenSize = camera.ViewportSize

	local normalizedX = ((mouseLocation.X / screenSize.X) - 0.5) * 2
	local normalizedY = ((mouseLocation.Y / screenSize.Y) - 0.5) * 2

	return normalizedX, normalizedY
end

local cursorPart = Instance.new("Part")
cursorPart.Name = "CursorFollower"
cursorPart.Size = Vector3.new(0.5, 0.5, 0.5)
cursorPart.Transparency = 1
cursorPart.Anchored = true
cursorPart.CanCollide = false
cursorPart.CastShadow = false
cursorPart.CanQuery = false
cursorPart.Parent = workspace

local cursorLight = Instance.new("PointLight")
cursorLight.Color = Color3.fromRGB(255, 255, 255)
cursorLight.Brightness = 2
cursorLight.Range = 1
cursorLight.Parent = cursorPart

game:GetService("RunService").RenderStepped:Connect(function()
	local mouseX, mouseY = getMouseDelta()

	local screenOffsetX = mouseX * maxMouseOffset * mouseSensitivity
	local screenOffsetY = mouseY * maxMouseOffset * mouseSensitivity

	local targetOffsetX = screenOffsetX
	local targetOffsetY = screenOffsetY

	currentMouseOffset = currentMouseOffset:Lerp(
		Vector3.new(targetOffsetX, targetOffsetY, 0),
		lerpSpeed
	)

	local targetPosition = targetPart.Position
	local cameraPosition = targetPosition + cameraOffset

	local baseCFrame = CFrame.lookAt(cameraPosition, targetPosition)

	local rotatedCFrame = baseCFrame * CFrame.Angles(0, 0, math.rad(rotationAngle))

	local finalCFrame = rotatedCFrame * CFrame.new(currentMouseOffset.X, currentMouseOffset.Y, 0)

	camera.CFrame = finalCFrame

	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {cursorPart, player.Character}

	local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)

	if raycastResult then
		cursorPart.Position = raycastResult.Position
	else
		cursorPart.Position = ray.Origin + ray.Direction * 50
	end
end)

TweenService:Create(stone.Highlight, TInfo, {FillColor = Color3.fromRGB(122, 0, 0)}):Play()

local started = scope:Value(false)
local clicked = scope:Value(false)
local dialogue = scope:Value("")
scope:Play({
	Parent = intermission,
	Started = started,
	Clicked = clicked,
	Dialogue = dialogue
})

task.delay(10, function()
	TweenService:Create(intermission.Frame, tinfo1, {Transparency = 1}):Play()
	TweenService:Create(intermission.Frame.ImageLabel, tinfo1, {Transparency = 1, ImageTransparency = 1}):Play()
	script.Sound:Play()
	script.Wind:Play()
	stone.Philo:Play()

	started:set(true)
	TweenService:Create(pl, TInfo2, {Range = 1.5}):Play()
	TweenService:Create(pl, TInfo2, {Brightness = 10}):Play()
end)

local RunService = game:GetService("RunService")
local ImageLabel = plrGui.Intermission.Frame.ImageLabel

local speed = .05
local minSize = 0.05
local maxSize = 0.3
local direction = 1
local currentT = 0


local conn
conn = RunService.RenderStepped:Connect(function(deltaTime)
	currentT = currentT + (deltaTime * speed * direction)

	if currentT >= 1 then
		currentT = 1
		direction = -1
	elseif currentT <= 0 then
		currentT = 0
		direction = 1
	end

	local size = minSize + (maxSize - minSize) * currentT
	ImageLabel.TileSize = UDim2.fromScale(size, size)

end)

local play = intermission:WaitForChild("Play", 600)
play.Activated:Connect(function()
	TweenService:Create(intermission.Frame, tinfo1, {Transparency = 0}):Play()
	TweenService:Create(intermission.Frame.ImageLabel, tinfo1, {Transparency = 0, ImageTransparency = 0}):Play()
end)

stone.ClickDetector.MouseClick:Connect(function()
	dialogue:set("<color=#a30000><italic><bold>The echoes of the dead transmit through the stone. A sharp tingle engulfs your body<pause=.3>...</> or maybe its just the wind, <pause=.3><shake>who knows?</></></></></>")
	script.chime:Play()
	clicked:set(true)
	task.wait(5)
	clicked:set(false)
end)

hf.ClickDetector.MouseClick:Connect(function()
	for _, v in hf.Parent.Wires.Attachment:GetChildren() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end
	script.shock:Play()
	dialogue:set("<color=#a30000><italic><bold>Sparks of life breathe through the dismantled arm. October 3rd, 1911, the ultimate price was paid. Through this arm we know that nothing is gained without sacrifice</></></>")
	clicked:set(true)
	task.wait(5)
	clicked:set(false)
end)

