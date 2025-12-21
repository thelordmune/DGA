local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)

local Children = Fusion.Children

-- Helper: Get all characters from textFrame
local function getCharacters(textFrame)
	local characters = {}
	for _, character in TextPlus.GetCharacters(textFrame) do
		table.insert(characters, character)
	end
	if #characters == 0 then
		for _, child in textFrame:GetChildren() do
			if child:IsA("TextLabel") or child:IsA("ImageLabel") then
				table.insert(characters, child)
			end
		end
	end
	return characters
end

-- Fade Diverge Animation IN (SwagText style - same as dialogue)
local function fadeDivergeAnimation(textFrame, delayPerChar)
	delayPerChar = delayPerChar or 0.015

	local characters = getCharacters(textFrame)
	if #characters == 0 then return end

	local totalChars = #characters
	local centerIndex = totalChars / 2

	for i, character in characters do
		if not character.Parent then break end

		local isImageLabel = character:IsA("ImageLabel")
		local isTextLabel = character:IsA("TextLabel")
		if not isImageLabel and not isTextLabel then continue end

		local originalPos = character.Position

		-- Calculate diverge offset (spread from center)
		local distanceFromCenter = i - centerIndex
		local divergeAmount = 8
		local xOffset = distanceFromCenter * (divergeAmount / totalChars) * 2
		local yOffset = math.abs(distanceFromCenter) * 0.5

		if isImageLabel then
			character.ImageTransparency = 1
		else
			character.TextTransparency = 1
		end
		character.Position = originalPos + UDim2.fromOffset(xOffset, yOffset)

		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		local props = { Position = originalPos }
		props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 0

		TweenService:Create(character, tweenInfo, props):Play()
		task.wait(delayPerChar)
	end
end

-- Disperse Animation OUT (same as dialogue)
local function disperseAnimation(textFrame, delayPerChar)
	delayPerChar = delayPerChar or 0.008

	local characters = getCharacters(textFrame)
	if #characters == 0 then return end

	local totalChars = #characters
	local centerIndex = totalChars / 2

	-- Animate from center outward (reverse order)
	for i = #characters, 1, -1 do
		local character = characters[i]
		if not character or not character.Parent then continue end

		local isImageLabel = character:IsA("ImageLabel")
		local isTextLabel = character:IsA("TextLabel")
		if not isImageLabel and not isTextLabel then continue end

		local originalPos = character.Position

		-- Calculate diverge offset (spread from center)
		local distanceFromCenter = i - centerIndex
		local divergeAmount = 8
		local xOffset = distanceFromCenter * (divergeAmount / totalChars) * 2
		local yOffset = math.abs(distanceFromCenter) * 0.5

		local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		local props = { Position = originalPos + UDim2.fromOffset(xOffset, yOffset) }
		props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 1

		TweenService:Create(character, tweenInfo, props):Play()
		task.wait(delayPerChar)
	end

	task.wait(0.2)
	for _, child in textFrame:GetChildren() do
		child:Destroy()
	end
end

-- Animate text in
local function animateTextIn(textFrame, delayPerChar)
	task.wait(0.05)
	fadeDivergeAnimation(textFrame, delayPerChar)
end

return function(scope, props: {
	npc: Model?,
	text: any?, -- string or Fusion Value<string>
	visible: any?, -- Fusion Value<boolean>
	onComplete: (() -> ())?,
	Parent: Instance?
})
	local npcModel = props.npc
	-- Support both string and Fusion Value for text
	local textValue = props.text
	if typeof(textValue) == "string" then
		textValue = scope:Value(textValue)
	elseif not textValue then
		textValue = scope:Value("")
	end
	local visible = props.visible or scope:Value(false)
	local parent = props.Parent

	-- Create text frame for TextPlus
	local textFrame = scope:New("Frame")({
		Name = "TextPlusContainer",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.034, 0.198),
		Size = UDim2.fromScale(0.928, 0.591),
	})

	-- Setup viewport with NPC model
	local viewportFrame = scope:New("ViewportFrame")({
		Name = "ViewportFrame",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BackgroundTransparency = 0.3,
		BorderColor3 = Color3.fromRGB(100, 100, 120),
		BorderSizePixel = 2,
		Position = UDim2.fromScale(0.65, 0.15), -- Right side of screen
		Size = UDim2.fromScale(0.3, 0.5), -- 30% width, 50% height
		Ambient = Color3.fromRGB(255, 255, 255),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -1),
	})

	-- Setup camera for viewport
	local camera = Instance.new("Camera")
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 70
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	-- Clone and setup NPC model in viewport
	if npcModel then
		-- Deep clone the NPC model
		local clonedNPC = npcModel:Clone()
		print("[VPNoti] Cloned NPC:", clonedNPC.Name)

		-- Create WorldModel for proper viewport rendering
		local worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewportFrame

		-- Parent NPC to WorldModel
		clonedNPC.Parent = worldModel

		-- Position the NPC at origin
		local rootPart = clonedNPC.PrimaryPart or clonedNPC:FindFirstChild("HumanoidRootPart")
		if rootPart then
			-- Set PrimaryPart if not set
			if not clonedNPC.PrimaryPart then
				clonedNPC.PrimaryPart = rootPart
			end

			-- Position NPC at origin
			rootPart.CFrame = CFrame.new(0, 0, 0)

			-- Get the head for better camera positioning
			local head = clonedNPC:FindFirstChild("Head")
			local headHeight = head and head.Position.Y or (rootPart.Position.Y + 1.5)

			-- Position camera to look at the NPC's upper body/head
			-- Camera is in front of NPC, looking back at it
			camera.CFrame = CFrame.new(0, headHeight, 4) * CFrame.Angles(0, math.rad(180), 0)

			print("[VPNoti] ✅ NPC positioned in WorldModel")
			print("[VPNoti] Camera CFrame:", camera.CFrame)
			print("[VPNoti] Head height:", headHeight)
		else
			warn("[VPNoti] ⚠️ No HumanoidRootPart found in NPC!")
		end
	else
		warn("[VPNoti] ⚠️ No NPC model provided to VPNoti component!")
	end

	-- Render text with TextPlus when visible
	local previousText = ""
	scope:Computed(function(use)
		local isVisible = use(visible)
		local currentText = use(textValue)
		if isVisible and currentText ~= "" then
			task.spawn(function()
				-- Wait for frame to be in DataModel
				local maxWait = 0
				while not textFrame:IsDescendantOf(game) and maxWait < 100 do
					task.wait(0.01)
					maxWait = maxWait + 1
				end

				if not textFrame:IsDescendantOf(game) then
					warn("[VPNoti] TextFrame not in DataModel")
					return
				end

				RunService.Heartbeat:Wait()

				-- Disperse old text if it exists and is different
				if previousText ~= "" and previousText ~= currentText and #textFrame:GetChildren() > 0 then
					disperseAnimation(textFrame, 0.008)
				else
					-- Just clear if no previous text or same text
					for _, child in textFrame:GetChildren() do
						child:Destroy()
					end
				end

				previousText = currentText

				RunService.Heartbeat:Wait()

				-- Create text with TextPlus (start invisible for animation)
				pcall(function()
					TextPlus.Create(textFrame, currentText, {
						Font = Font.new("rbxasset://fonts/families/Sarpanch.json"),
						Size = 18,
						Color = Color3.fromRGB(255, 255, 255),
						Transparency = 1, -- Start invisible for animation
						XAlignment = "Left",
						YAlignment = "Top",
					})
				end)

				-- Animate text in (same as dialogue)
				animateTextIn(textFrame, 0.015)
			end)
		end
	end)

	return scope:New("ScreenGui")({
		Name = "VPNoti",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,

		[Children] = {
			scope:New("Frame")({
				Name = "Holder",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(920, 79),
				Size = UDim2.fromOffset(612, 115),
				GroupTransparency = scope:Spring(
					scope:Computed(function(use)
						return if use(visible) then 0 else 1
					end),
					30,
					1
				),

				[Children] = {
					scope:New("ImageLabel")({
						Name = "Corners",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://106093959266071",
						ImageColor3 = Color3.fromRGB(0, 0, 0),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromScale(1, 1),
						SliceCenter = Rect.new(200, 300, 870, 300),
						SliceScale = 0.5,
					}),

					scope:New("ImageLabel")({
						Name = "Circle",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://102790439571584",
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(1, 1),
						TileSize = UDim2.fromScale(0.025, 1),

						[Children] = {
							scope:New("UIGradient")({
								Name = "UIGradient",
								Rotation = 360,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0.356),
									NumberSequenceKeypoint.new(0.495, 0.387),
									NumberSequenceKeypoint.new(1, 0.306),
								}),
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Health",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.0759, 0.0609),
						Size = UDim2.fromOffset(517, 55),

						[Children] = {
							scope:New("Frame")({
								Name = "Main",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								Position = UDim2.fromScale(0.00774, 0.15),
								Size = UDim2.fromOffset(508, 63),

								[Children] = {
									scope:New("ImageLabel")({
										Name = "ImageLabel",
										BackgroundColor3 = Color3.fromRGB(255, 255, 255),
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(0, 0, 0),
										BorderSizePixel = 0,
										Image = "rbxassetid://85774200010476",
										ImageTransparency = 0.21,
										ScaleType = Enum.ScaleType.Crop,
										Size = UDim2.fromScale(1, 1),
									}),

									scope:New("ImageLabel")({
										Name = "HealthBorder",
										BackgroundColor3 = Color3.fromRGB(255, 255, 255),
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(0, 0, 0),
										BorderSizePixel = 0,
										Image = "rbxassetid://122523747392433",
										ScaleType = Enum.ScaleType.Slice,
										Size = UDim2.fromScale(1, 1),
										SliceCenter = Rect.new(13, 13, 37, 33),
										SliceScale = 0.8,
									}),

									textFrame,
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Seperater",
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.3,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.0627, 0.8),
						Size = UDim2.fromOffset(534, 2),

						[Children] = {
							scope:New("UIGradient")({
								Name = "UIGradient",
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.192, 0.894),
									NumberSequenceKeypoint.new(0.499, 0),
									NumberSequenceKeypoint.new(0.797, 0.875),
									NumberSequenceKeypoint.new(1, 0),
								}),
							}),
						},
					}),

					scope:New("ImageLabel")({
						Name = "BG",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://72101690551510",
						ImageColor3 = Color3.fromRGB(0, 0, 0),
						ImageTransparency = 0.8,
						Size = UDim2.fromScale(1, 1),
						TileSize = UDim2.fromScale(0.025, 1),

						[Children] = {
							scope:New("UIGradient")({
								Name = "UIGradient",
								Rotation = 360,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0.356),
									NumberSequenceKeypoint.new(0.495, 0.387),
									NumberSequenceKeypoint.new(1, 0.306),
								}),
							}),
						},
					}),

					scope:New("UIScale")({
						Name = "UIScale",
						Scale = 0.8,
					}),
				},
			}),

			scope:New("UIScale")({
				Name = "UIScale",
				Scale = 0.9,
			}),

			viewportFrame,
		},
	})
end
