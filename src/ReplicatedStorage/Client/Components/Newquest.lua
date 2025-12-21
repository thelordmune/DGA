local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)

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

local function fadeDivergeAnimation(scope, textLabel, delayPerChar)
	delayPerChar = delayPerChar or 0.015

	-- Store original properties BEFORE modifying the label
	local originalText = textLabel.Text
	local originalZIndex = textLabel.ZIndex
	local originalColor = textLabel.TextColor3
	local originalFont = textLabel.FontFace
	local originalSize = textLabel.TextSize

	-- Hide the label IMMEDIATELY
	textLabel.Text = ""
	textLabel.TextTransparency = 1

	-- Create text with TextPlus
	local textPlusConfig = {
		Font = originalFont,
		Size = originalSize,
		Color = originalColor,
		Transparency = 1, -- Start invisible
		XAlignment = "Left",
		YAlignment = "Center",
		CharacterSpacing = 1,
	}

	TextPlus.Create(textLabel, originalText, textPlusConfig)

	task.wait(0.05)

	local characters = getCharacters(textLabel)
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

		-- Set character ZIndex to match parent
		character.ZIndex = originalZIndex

		-- Hide character initially
		if isImageLabel then
			character.ImageTransparency = 1
		else
			character.TextTransparency = 1
		end

		local originalPos = character.Position
		local originalSize = character.Size
		local distanceFromCenter = i - centerIndex
		local divergeAmount = 3
		local xOffset = distanceFromCenter * (divergeAmount / totalChars) * 2

		-- Alternate between top and bottom with sparkle effect
		local verticalOffset = (i % 2 == 1) and math.random(8, 15) or math.random(8, 15)
		local yOffset = verticalOffset

		-- Create spring values for smooth animation with pop
		local charTransparency = scope:Value(1)
		local charPositionX = scope:Value(originalPos.X.Scale)
		local charPositionY = scope:Value(originalPos.Y.Scale)
		local charScale = scope:Value(0) -- Start at 0 for pop effect

		-- Springs - lower damping for more bounce/pop
		local transparencySpring = scope:Spring(charTransparency, 35, 0.8)
		local positionXSpring = scope:Spring(charPositionX, 28, 0.7)
		local positionYSpring = scope:Spring(charPositionY, 28, 0.7)
		local scaleSpring = scope:Spring(charScale, 22, 0.45)

		character.Position = originalPos - UDim2.fromOffset(xOffset, -yOffset)
		character.Size = UDim2.fromOffset(0, 0)

		-- Store initial values
		local startX = (originalPos.X.Scale - xOffset / textLabel.AbsoluteSize.X)
		local startY = (originalPos.Y.Scale + yOffset / textLabel.AbsoluteSize.Y)

		charPositionX:set(startX)
		charPositionY:set(startY)

		-- Apply spring values with Observers
		scope:Observer(transparencySpring):onChange(function()
			if character.Parent then
				local value = scope.peek(transparencySpring)
				if isImageLabel then
					character.ImageTransparency = value
				else
					character.TextTransparency = value
				end
			end
		end)

		scope:Observer(positionXSpring):onChange(function()
			if character.Parent then
				local x = scope.peek(positionXSpring)
				local y = scope.peek(positionYSpring)
				character.Position = UDim2.new(
					x,
					originalPos.X.Offset,
					y,
					originalPos.Y.Offset
				)
			end
		end)

		scope:Observer(positionYSpring):onChange(function()
			if character.Parent then
				local x = scope.peek(positionXSpring)
				local y = scope.peek(positionYSpring)
				character.Position = UDim2.new(
					x,
					originalPos.X.Offset,
					y,
					originalPos.Y.Offset
				)
			end
		end)

		-- Scale with pop effect
		scope:Observer(scaleSpring):onChange(function()
			if character.Parent then
				local scale = scope.peek(scaleSpring)
				character.Size = UDim2.fromOffset(
					originalSize.X.Offset * scale,
					originalSize.Y.Offset * scale
				)
			end
		end)

		-- Trigger animation
		task.spawn(function()
			charTransparency:set(0)
			charPositionX:set(originalPos.X.Scale)
			charPositionY:set(originalPos.Y.Scale)
			charScale:set(1.2) -- Overshoot to 120% then settle to 100%
			task.wait(0.15)
			charScale:set(1) -- Settle back to normal size
		end)

		task.wait(delayPerChar)
	end
end

local function QuestUI(scope, props)
	local Children = scope.Children

	-- Ensure we have a parent
	if not props.Parent then
		error("QuestUI requires a Parent property")
	end

	-- Quest icon (default)
	local DEFAULT_QUEST_ICON = "rbxassetid://99100008402900"

	-- Active quests list - pass from props or create new
	local questsList = props.questsList or scope:Value({})

	-- Visibility state - pass from props or create new
	local isVisible = props.isVisible or scope:Value(true)

	-- Spring values for scrolling frame animation
	local scrollingFrameTransparency = scope:Value(1)
	local scrollingFrameTransparencySpring = scope:Spring(scrollingFrameTransparency, 25, 0.8)

	-- Main scrolling frame
	local scrollingFrame = scope:New("ScrollingFrame")({
		Name = "ScrollingFrame",
		Active = true,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.0148, 0.0223),
		ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0),
		ScrollBarImageTransparency = 1,
		Size = UDim2.fromOffset(364, 426),
		CanvasSize = UDim2.fromOffset(364, 0),
		ScrollBarThickness = 6,
		Parent = props.Parent,
	})

	local listLayout = scope:New("UIListLayout")({
		Name = "UIListLayout",
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
		Parent = scrollingFrame,
	})

	-- Update canvas size when list layout changes
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollingFrame.CanvasSize = UDim2.fromOffset(364, listLayout.AbsoluteContentSize.Y + 10)
	end)

	-- Function to create a quest entry
	local function createQuestEntry(questData, index)
		-- Spring values for quest background animation
		local bgTransparency = scope:Value(1)
		local bgTransparencySpring = scope:Spring(bgTransparency, 25, 0.75)

		-- Spring values for icon slide-in
		local iconXPosition = scope:Value(-0.1) -- Start off-screen to the left
		local iconXPositionSpring = scope:Spring(iconXPosition, 22, 0.7)
		local iconTransparency = scope:Value(1)
		local iconTransparencySpring = scope:Spring(iconTransparency, 25, 0.75)

		local questBackground = scope:New("ImageLabel")({
			Name = "Background",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Image = "rbxassetid://113472025813543",
			Position = UDim2.fromScale(0, 0.00433),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(364, 65),
			ImageTransparency = bgTransparencySpring,
			LayoutOrder = index,
			Parent = scrollingFrame,
		})

		-- Quest Icon
		local questIcon = scope:New("ImageLabel")({
			Name = "QuestIcon",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Image = questData.icon,
			Position = scope:Computed(function(use)
				return UDim2.fromScale(use(iconXPositionSpring), 0.0923)
			end),
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromOffset(48, 48),
			ImageTransparency = iconTransparencySpring,
			Parent = questBackground,
		})

		-- Quest Name Label
		local questNameLabel = scope:New("TextLabel")({
			Name = "QuestName",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			FontFace = Font.new(
				"rbxasset://fonts/families/Sarpanch.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Italic
			),
			Position = UDim2.fromScale(0.302, 0.18), -- Moved up from 0.282
			Size = UDim2.fromScale(0.65, 0.298),
			Text = "", -- Start with empty text
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 14,
			TextStrokeTransparency = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 1,
			ZIndex = 2,
			Parent = questBackground,
		})

		local nameGradient = scope:New("UIGradient")({
			Name = "UIGradient",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
				ColorSequenceKeypoint.new(0.393, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.678, Color3.fromRGB(99, 99, 99)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
			}),
			Rotation = 90,
			Parent = questNameLabel,
		})

		local nameStroke = scope:New("UIStroke")({
			Name = "UIStroke",
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 0.5,
			Parent = questNameLabel,
		})

		local nameStrokeGradient = scope:New("UIGradient")({
			Name = "UIGradient",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.393, Color3.fromRGB(153, 153, 153)),
				ColorSequenceKeypoint.new(0.678, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
			}),
			Rotation = 90,
			Parent = nameStroke,
		})

		-- Quest Description Label
		local questDescLabel = scope:New("TextLabel")({
			Name = "QuestDescription",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			FontFace = Font.new(
				"rbxasset://fonts/families/Sarpanch.json",
				Enum.FontWeight.Regular,
				Enum.FontStyle.Italic
			),
			Position = UDim2.fromScale(0.302, 0.466),
			Size = UDim2.fromScale(0.65, 0.298),
			Text = "", -- Start with empty text
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 14,
			TextStrokeTransparency = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 1,
			ZIndex = 2,
			Parent = questBackground,
		})

		local descGradient = scope:New("UIGradient")({
			Name = "UIGradient",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
				ColorSequenceKeypoint.new(0.393, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.678, Color3.fromRGB(99, 99, 99)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
			}),
			Rotation = 90,
			Parent = questDescLabel,
		})

		local descStroke = scope:New("UIStroke")({
			Name = "UIStroke",
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 0.5,
			Parent = questDescLabel,
		})

		local descStrokeGradient = scope:New("UIGradient")({
			Name = "UIGradient",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.393, Color3.fromRGB(153, 153, 153)),
				ColorSequenceKeypoint.new(0.678, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
			}),
			Rotation = 90,
			Parent = descStroke,
		})

		-- Animate entry in sequence
		task.spawn(function()
			-- Fade in background
			bgTransparency:set(0)

			-- Wait a bit
			task.wait(0.2)

			-- Slide in icon from left
			iconTransparency:set(0)
			iconXPosition:set(0.17) -- Slide to final position

			-- Wait for icon to settle
			task.wait(0.4)

			-- Set the text THEN animate with TextPlus
			questNameLabel.Text = questData.name
			fadeDivergeAnimation(scope, questNameLabel, 0.02)

			-- Wait for name animation to complete (estimate based on character count)
			local nameCharCount = #questData.name
			task.wait(nameCharCount * 0.02 + 0.5)

			-- Add red gradient flash with bounce to each TextPlus character sequentially
			local nameCharacters = getCharacters(questNameLabel)
			for i, character in nameCharacters do
				if character.Parent then
					-- Store original size
					local originalSize = character.Size

					-- Add red gradient (dark red to bright red to dark red)
					local redGradient = Instance.new("UIGradient")
					redGradient.Name = "RedFlash"
					redGradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 0, 0)),      -- Dark red
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 50, 50)), -- Bright red
						ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0)),      -- Dark red
					})
					redGradient.Offset = Vector2.new(-2, 0) -- Start further left for longer gradient
					redGradient.Parent = character

					-- Bounce animation
					task.spawn(function()
						-- Bounce up
						character.Size = UDim2.fromOffset(
							originalSize.X.Offset * 1.5,
							originalSize.Y.Offset * 1.5
						)
						task.wait(0.08)
						-- Bounce back
						character.Size = UDim2.fromOffset(
							originalSize.X.Offset * 0.95,
							originalSize.Y.Offset * 0.95
						)
						task.wait(0.06)
						-- Return to normal
						character.Size = originalSize
					end)

					-- Animate red gradient across this character (longer distance)
					task.spawn(function()
						local redTween = TweenService:Create(
							redGradient,
							TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
							{ Offset = Vector2.new(2, 0) } -- End further right for longer gradient
						)
						redTween:Play()
						redTween.Completed:Wait()
						redGradient:Destroy()
					end)

					task.wait(0.04) -- Faster wave between characters
				end
			end

			-- Wait for all red flashes to complete
			task.wait(0.3)

			-- Wait a bit before description
			task.wait(0.2)

			-- Set the text THEN animate with TextPlus
			questDescLabel.Text = questData.desc
			fadeDivergeAnimation(scope, questDescLabel, 0.015)

			-- Wait for description animation to complete
			local descCharCount = #questData.desc
			task.wait(descCharCount * 0.015 + 0.6)

			-- Add silver gradient flash with bounce to each TextPlus character sequentially
			local descCharacters = getCharacters(questDescLabel)
			for i, character in descCharacters do
				if character.Parent then
					-- Store original size
					local originalSize = character.Size

					-- Add silver gradient (longer for more coverage)
					local silverGradient = Instance.new("UIGradient")
					silverGradient.Name = "SilverFlash"
					silverGradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 100, 100)),  -- Dark silver
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 240, 240)), -- Bright silver
						ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 100, 100)),  -- Dark silver
					})
					silverGradient.Offset = Vector2.new(-2, 0) -- Start further left for longer gradient
					silverGradient.Parent = character

					-- Bounce animation
					task.spawn(function()
						-- Bounce up
						character.Size = UDim2.fromOffset(
							originalSize.X.Offset * 1.4,
							originalSize.Y.Offset * 1.4
						)
						task.wait(0.07)
						-- Bounce back
						character.Size = UDim2.fromOffset(
							originalSize.X.Offset * 0.95,
							originalSize.Y.Offset * 0.95
						)
						task.wait(0.05)
						-- Return to normal
						character.Size = originalSize
					end)

					-- Animate silver across this character (longer distance)
					task.spawn(function()
						local silverTween = TweenService:Create(
							silverGradient,
							TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
							{ Offset = Vector2.new(2, 0) } -- End further right for longer gradient
						)
						silverTween:Play()
						silverTween.Completed:Wait()
						silverGradient:Destroy()
					end)

					task.wait(0.03) -- Faster wave between characters
				end
			end
		end)

		return questBackground
	end

	-- Track the previous quest count to detect new quests
	local previousQuestCount = 0

	-- Observer to automatically add quests when they appear in the questsList
	scope:Observer(questsList):onChange(function()
		local currentQuests = scope.peek(questsList)
		local currentCount = #currentQuests

		-- Play quest sound only when a new quest is added
		if currentCount > previousQuestCount then
			local questSound = ReplicatedStorage.Assets.SFX.MISC.Quest:Clone()
			questSound.Parent = game:GetService("SoundService")
			questSound:Play()
			game:GetService("Debris"):AddItem(questSound, questSound.TimeLength)
		end

		-- Clear all existing quest entries
		for _, child in scrollingFrame:GetChildren() do
			if child:IsA("ImageLabel") and child.Name == "Background" then
				child:Destroy()
			end
		end

		-- Create quest entries for all quests in the list
		for index, questData in ipairs(currentQuests) do
			if questData.name and questData.desc then
				createQuestEntry({
					name = questData.name,
					desc = questData.desc,
					icon = questData.icon or DEFAULT_QUEST_ICON
				}, index)
			end
		end

		previousQuestCount = currentCount
	end)

	-- Initial entrance animation
	task.delay(0.1, function()
		-- Fade in scrolling frame
		scrollingFrameTransparency:set(0)
	end)

	-- Observer for visibility changes (fade out when closing)
	scope:Observer(isVisible):onChange(function()
		local visible = scope.peek(isVisible)
		if not visible then
			-- Fade out all quest entries
			for _, child in scrollingFrame:GetChildren() do
				if child:IsA("ImageLabel") and child.Name == "Background" then
					-- Fade out the background
					local bgTransparency = child:GetAttribute("BgTransparency")
					if bgTransparency then
						TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							BackgroundTransparency = 1
						}):Play()
					end

					-- Fade out all descendants
					for _, descendant in child:GetDescendants() do
						if descendant:IsA("GuiObject") then
							TweenService:Create(descendant, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								BackgroundTransparency = 1
							}):Play()
						end
						if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
							TweenService:Create(descendant, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								TextTransparency = 1
							}):Play()
						end
						if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
							TweenService:Create(descendant, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								ImageTransparency = 1
							}):Play()
						end
					end
				end
			end
		else
			-- Fade in when opening (reset transparencies)
			task.delay(0.1, function()
				scrollingFrameTransparency:set(0)
			end)
		end
	end)

	return scrollingFrame
end

return QuestUI