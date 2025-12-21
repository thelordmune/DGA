local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)
local TweenService = game:GetService("TweenService")

local Children, scoped, peek, out, OnEvent, Value, Tween =
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.Value, Fusion.Tween

local TInfo = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0, true) -- PingPong for automatic back-and-forth

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

local function fadeDivergeAnimation(textFrame, delayPerChar)
	delayPerChar = delayPerChar or 0.015

	local characters = getCharacters(textFrame)
	if #characters == 0 then
		return
	end

	local totalChars = #characters
	local centerIndex = totalChars / 2

	for i, character in characters do
		if not character.Parent then
			break
		end

		local isImageLabel = character:IsA("ImageLabel")
		local isTextLabel = character:IsA("TextLabel")
		if not isImageLabel and not isTextLabel then
			continue
		end

		local originalPos = character.Position
		local distanceFromCenter = i - centerIndex
		local divergeAmount = 2
		local xOffset = distanceFromCenter * (divergeAmount / totalChars) * 2

		-- Alternate between top and bottom: odd indices from top, even from bottom
		local verticalOffset = (i % 2 == 1) and math.random(1, 5) or math.random(8, 15)
		local yOffset = verticalOffset

		if isImageLabel then
			character.ImageTransparency = 1
		else
			character.TextTransparency = 1
		end
		character.Position = originalPos - UDim2.fromOffset(xOffset, -yOffset)

		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		local props = { Position = originalPos }
		props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 0

		TweenService:Create(character, tweenInfo, props):Play()
		task.wait(delayPerChar)
	end
end

local function popFadeAnimation(textFrame, delayPerChar)
	delayPerChar = delayPerChar or 0.02

	local characters = getCharacters(textFrame)
	if #characters == 0 then
		return
	end

	for i, character in characters do
		if not character.Parent then
			break
		end

		local isImageLabel = character:IsA("ImageLabel")
		local isTextLabel = character:IsA("TextLabel")
		if not isImageLabel and not isTextLabel then
			continue
		end

		-- Store original size
		local originalSize = character.Size

		-- Start invisible and at 50% scale
		if isImageLabel then
			character.ImageTransparency = 1
		else
			character.TextTransparency = 1
		end
		character.Size = UDim2.fromOffset(originalSize.X.Offset * 0.5, originalSize.Y.Offset * 0.5)

		-- Pop up to 120% size then settle to 100% with fade in
		local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local props = {
			Size = originalSize,
		}
		props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 0

		TweenService:Create(character, tweenInfo, props):Play()
		task.wait(delayPerChar)
	end
end

local function disperseAnimation(textFrame, delayPerChar)
	delayPerChar = delayPerChar or 0.008

	local characters = getCharacters(textFrame)
	if #characters == 0 then
		return
	end

	local totalChars = #characters
	local centerIndex = totalChars / 2

	for i = #characters, 1, -1 do
		local character = characters[i]
		if not character.Parent then
			break
		end

		local isImageLabel = character:IsA("ImageLabel")
		local isTextLabel = character:IsA("TextLabel")
		if not isImageLabel and not isTextLabel then
			continue
		end

		local originalPos = character.Position

		local distanceFromCenter = i - centerIndex
		local disperseAmount = 12
		local xOffset = distanceFromCenter * (disperseAmount / totalChars) * 2
		local yOffset = math.abs(distanceFromCenter) * 0.8

		local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		local props = {
			Position = originalPos + UDim2.fromOffset(xOffset, yOffset),
		}
		props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 1

		TweenService:Create(character, tweenInfo, props):Play()
		task.wait(delayPerChar)
	end

	task.wait(0.2)
	for _, child in textFrame:GetChildren() do
		child:Destroy()
	end
end

local function animateTextIn(textFrame, delayPerChar)
	task.wait(0.05)

	fadeDivergeAnimation(textFrame, delayPerChar)
	-- slideUpAnimation(textFrame, delayPerChar)
	-- popInAnimation(textFrame, delayPerChar)
	-- popFadeAnimation(textFrame, delayPerChar)  -- Pop up with fade in
end

-- Relationship tier colors
local tierColors = {
	Stranger = Color3.fromRGB(150, 150, 150),
	Acquaintance = Color3.fromRGB(255, 255, 255),
	Friend = Color3.fromRGB(100, 200, 255),
	["Close Friend"] = Color3.fromRGB(255, 200, 50),
	Trusted = Color3.fromRGB(200, 100, 255),
}

return function(scope, props: {})
	local started = props.begin
	local fadein = props.fadein
	local textstart = props.textstart
	local npcName = props.npcName or "Magnus" -- Default to Magnus if not provided
	local occupation = props.occupation or "" -- NPC occupation (e.g., "Automail Engineer")
	local relationshipTier = props.relationshipTier or "Stranger" -- Relationship status
	local isWanderer = props.isWanderer or false -- Is this a wandering citizen NPC
	local rotation = scope:Value(0)
	local tileSize = scope:Value(0.05)
    local slowrotation = scope:Value(0)
	local tileDirection = 1
	local tileT = 0
	local parent = props.Parent

	local rotationConnection = RunService.RenderStepped:Connect(function(dt)
		rotation:set((peek(rotation) + (dt * 60)) % 360) -- Rotates 60 degrees per second
		slowrotation:set((peek(slowrotation) + (dt * 10)) % 360) -- Rotates 10 degrees per second

		-- Tile animation
		tileT = tileT + (dt * 0.05 * tileDirection)

		if tileT >= 1 then
			tileT = 1
			tileDirection = -1
		elseif tileT <= 0 then
			tileT = 0
			tileDirection = 1
		end

		local size = 0.05 + (0.2 - 0.05) * tileT
		tileSize:set(size)
	end)

	scope:Computed(function(use)
		return if use(started) then fadein:set(true) else fadein:set(false)
	end)
	scope:Computed(function(use)
		return if use(fadein) then textstart:set(true) else textstart:set(false)
	end)

	-- Use larger size for wanderers (BillboardGui)
	local frameSize = isWanderer and 150 or 100

	scope:New "Frame" {
		Parent = parent,
		Name = "Frame",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = scope:Spring(
			scope:Computed(function(use)
				return if use(started) then UDim2.fromOffset(frameSize, frameSize) else UDim2.fromOffset(frameSize, 0)
			end),
			12,
			0.7
		),

		[Children] = {
			scope:New "UIGradient" {
				Name = "UIGradient",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 61, 39)),
				}),
				Rotation = scope:Computed(function(use)
					return if use(started) then use(slowrotation) else use(slowrotation)
				end),
			},

			scope:New "ImageLabel" {
				Name = "Background",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://93299157578715",
				--ImageContent = Content.new(Content),
				ImageTransparency = 0.2,
				SelectionOrder = -3,
				Size = scope:Spring(
					scope:Computed(function(use)
						return if use(started) then UDim2.fromScale(1, 1) else UDim2.fromOffset(1, 0)
					end),
					12,
					0.7
				),
				ScaleType = Enum.ScaleType.Tile,
				TileSize = scope:Computed(function(use)
					local size = use(tileSize)
					return UDim2.fromScale(size, size)
				end),

				[Children] = {
					scope:New "UICorner" {
						Name = "UICorner",
					},

					scope:New "ImageLabel" {
						Name = "ImageLabel",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://129478135728557",
						--ImageContent = Content.new(Content),
						ScaleType = Enum.ScaleType.Slice,
						Size = scope:Spring(
							scope:Computed(function(use)
								return if use(started) then UDim2.fromOffset(frameSize, frameSize) else UDim2.fromOffset(frameSize, 0)
							end),
							12,
							0.7
						),
						SliceCenter = Rect.new(15, 15, 55, 55),
						SliceScale = 0.8,
					},

					scope:New "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
						}),
					},
				}
			},

			-- NPC Name Label
			scope:New "TextLabel" {
				Name = "NameLabel",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxassetid://12187607287", Enum.FontWeight.Regular, Enum.FontStyle.Italic),
				Position = scope:Spring(
					scope:Computed(function(use)
						-- Adjust position based on whether it's a wanderer (more info to show)
						if isWanderer then
							return if use(fadein) then UDim2.fromScale(0.5, 0.08) else UDim2.fromScale(0.5, 0.5)
						else
							return if use(fadein) then UDim2.fromScale(0.25, 0.1) else UDim2.fromScale(0.25, 0.5)
						end
					end),
					12,
					0.7
				),
				AnchorPoint = isWanderer and Vector2.new(0.5, 0) or Vector2.zero,
				Size = isWanderer and UDim2.fromOffset(130, 28) or UDim2.fromOffset(50, 20),
				Text = npcName,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = isWanderer and 16 or 10,
				TextTransparency = scope:Spring(
					scope:Computed(function(use)
						return if use(fadein) then 0 else 1
					end),
					12,
					0.7
				),

				[Children] = {
					scope:New "ImageLabel" {
						Name = "ImageLabel",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://81906702543938",
						ImageTransparency = scope:Spring(
							scope:Computed(function(use)
								return if use(fadein) then 0 else 1
							end),
							12,
							0.7
						),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromScale(1, 1),
						SliceCenter = Rect.new(14, 14, 36, 32),
						SliceScale = 0.8,
					},
				}
			},

			-- Occupation Label (only for wanderers)
			isWanderer and scope:New "TextLabel" {
				Name = "OccupationLabel",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/Sarpanch.json",
					Enum.FontWeight.Regular,
					Enum.FontStyle.Normal
				),
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(fadein) then UDim2.fromScale(0.5, 0.28) else UDim2.fromScale(0.5, 0.6)
					end),
					12,
					0.7
				),
				AnchorPoint = Vector2.new(0.5, 0),
				Size = UDim2.fromOffset(130, 18),
				Text = occupation,
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextSize = 12,
				TextTransparency = scope:Spring(
					scope:Computed(function(use)
						return if use(fadein) then 0 else 1
					end),
					12,
					0.7
				),
			} or nil,

			-- Relationship Tier Label (only for wanderers)
			isWanderer and scope:New "TextLabel" {
				Name = "RelationshipLabel",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/Sarpanch.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(fadein) then UDim2.fromScale(0.5, 0.42) else UDim2.fromScale(0.5, 0.7)
					end),
					12,
					0.7
				),
				AnchorPoint = Vector2.new(0.5, 0),
				Size = UDim2.fromOffset(130, 18),
				Text = relationshipTier,
				TextColor3 = tierColors[relationshipTier] or tierColors.Stranger,
				TextSize = 13,
				TextTransparency = scope:Spring(
					scope:Computed(function(use)
						return if use(fadein) then 0 else 1
					end),
					12,
					0.7
				),
			} or nil,

			-- E Button Label
			scope:New "TextLabel" {
				Name = "EButtonLabel",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/Sarpanch.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = scope:Spring(
					scope:Computed(function(use)
						if isWanderer then
							return if use(fadein) then UDim2.fromScale(0.5, 0.58) else UDim2.fromScale(0.5, 1.5)
						else
							return if use(fadein) then UDim2.fromScale(0.37, 0.5) else UDim2.fromScale(0.37, 1.5)
						end
					end),
					12,
					0.7
				),
				AnchorPoint = isWanderer and Vector2.new(0.5, 0) or Vector2.zero,
				Size = isWanderer and UDim2.fromOffset(40, 40) or UDim2.fromOffset(25, 25),
				Text = "E",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = isWanderer and 22 or 14,
				TextTransparency = scope:Spring(
					scope:Computed(function(use)
						return if use(fadein) then 0 else 1
					end),
					12,
					0.7
				),

				[Children] = {
					scope:New "ImageLabel" {
						Name = "RotatingImage",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://85168217168177",
						ImageTransparency = scope:Spring(
							scope:Computed(function(use)
								return if use(fadein) then 0 else 1
							end),
							12,
							0.7
						),
						--ImageContent = Content.new(Content),
						Position = UDim2.fromScale(0.13, 0.15),
						Rotation = scope:Computed(function(use)
							return if use(textstart) then use(rotation) else use(rotation)
						end),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromScale(0.8, 0.8),
						SliceCenter = Rect.new(10, 10, 20, 20),
						SliceScale = 0.8,
					},
				}
			},
		}
	}
end
