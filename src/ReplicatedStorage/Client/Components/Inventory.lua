local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

-- Rarity color gradients (lighter to darker)
local RARITY_GRADIENTS = {
	common = {
		Color3.fromRGB(200, 200, 200), -- Light grey
		Color3.fromRGB(100, 100, 100)  -- Dark grey
	},
	rare = {
		Color3.fromRGB(150, 200, 255), -- Light blue
		Color3.fromRGB(50, 100, 200)   -- Dark blue
	},
	unique = {
		Color3.fromRGB(230, 150, 255), -- Light purple
		Color3.fromRGB(150, 50, 200)   -- Dark purple
	},
	forbidden = {
		Color3.fromRGB(255, 100, 100), -- Light red
		Color3.fromRGB(200, 0, 0)      -- Dark red
	},
	legendary = {
		Color3.fromRGB(255, 240, 100), -- Light gold
		Color3.fromRGB(200, 150, 0)    -- Dark gold
	},
	priceless = {
		Color3.fromRGB(255, 255, 255), -- White (will be rainbow animated)
		Color3.fromRGB(255, 255, 255)
	}
}

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

local function fadeDivergeAnimation(scope, textLabel, delayPerChar, rarityGradient)
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

	-- Create text with TextPlus (no shadows)
	local textPlusConfig = {
		Font = originalFont,
		Size = originalSize,
		Color = originalColor,
		Transparency = 1, -- Start invisible
		XAlignment = "Center",
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

		-- Apply gradient color and text stroke to character if provided
		if isTextLabel then
			-- Apply text stroke
			character.TextStrokeTransparency = 0.5
			character.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

			-- Apply gradient color if provided
			if rarityGradient then
				-- Interpolate between gradient colors based on character position
				local t = (i - 1) / math.max(totalChars - 1, 1) -- 0 to 1
				local color1 = rarityGradient[1]
				local color2 = rarityGradient[2]
				local interpolatedColor = color1:Lerp(color2, t)
				character.TextColor3 = interpolatedColor
			end
		end

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

local function dancingShadowAnimation(scope, textLabel, delayPerChar, addRainbow)
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

	-- Create text with TextPlus (no shadows)
	local textPlusConfig = {
		Font = originalFont,
		Size = originalSize,
		Color = originalColor,
		Transparency = 1, -- Start invisible
		XAlignment = "Center",
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

	-- Add rainbow gradient to entire textLabel if requested
	if addRainbow then
		local rainbowGradient = Instance.new("UIGradient")
		rainbowGradient.Name = "RainbowGradient"
		rainbowGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),     -- Red
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 127, 0)), -- Orange
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 0)), -- Yellow
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 0)),    -- Green
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),   -- Blue
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(75, 0, 130)),  -- Indigo
			ColorSequenceKeypoint.new(1, Color3.fromRGB(148, 0, 211)),    -- Violet
		})
		rainbowGradient.Offset = Vector2.new(-1, 0)
		rainbowGradient.Parent = textLabel

		-- Animate rainbow gradient
		task.spawn(function()
			while textLabel.Parent and rainbowGradient.Parent do
				local tween = TweenService:Create(
					rainbowGradient,
					TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
					{ Offset = Vector2.new(1, 0) }
				)
				tween:Play()
				tween.Completed:Wait()
				if rainbowGradient.Parent then
					rainbowGradient.Offset = Vector2.new(-1, 0)
				end
			end
		end)
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

		-- Rainbow gradient will be added to the entire textLabel, not individual characters

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

local function InventoryUI(scope, props)
	local Children = scope.Children
	local entity = props.entity
	local started = props.started or scope:Value(false)

	-- Reactive inventory items from ECS
	local inventoryItems = scope:Value({})

	-- Update inventory items from ECS
	local function updateInventoryDisplay()
		if not entity then
			warn("[Inventory] No entity provided to updateInventoryDisplay")
			return
		end

		if not world:has(entity, comps.Inventory) then
			warn("[Inventory] Entity does not have Inventory component")
			return
		end

		local inventory = world:get(entity, comps.Inventory)
		local items = {}

		-- Get all items from inventory (slots 8-50 are inventory items)
		for slot = 8, 50 do
			if inventory.items[slot] then
				table.insert(items, inventory.items[slot])
			end
		end

		inventoryItems:set(items)
	end

	-- Initial update
	updateInventoryDisplay()

	-- Listen for inventory changes
	local inventoryUpdateConnection = nil
	if RunService:IsClient() then
		local Bridges = require(ReplicatedStorage.Modules.Bridges)
		inventoryUpdateConnection = Bridges.Inventory:Connect(function(syncData)
			-- Update inventory display when server sends new data
			updateInventoryDisplay()
		end)
	end

	-- Cleanup connection when scope is destroyed
	table.insert(scope, function()
		if inventoryUpdateConnection then
			inventoryUpdateConnection:Disconnect()
		end
	end)

	-- Spring values for holder animation - scroll down from top (thin line to full height)
	local holderYPosition = scope:Value(0.45) -- Start at final position
	local holderYSpring = scope:Spring(holderYPosition, 20, 0.8)
	local holderHeight = scope:Value(0) -- Start as thin line
	local holderHeightSpring = scope:Spring(holderHeight, 18, 0.65) -- Bouncy spring

	-- Background transparency spring
	local bgTransparency = scope:Value(1)
	local bgTransparencySpring = scope:Spring(bgTransparency, 25, 0.8)

	-- Search query state
	local searchQuery = scope:Value("")

	-- Selected item state
	local selectedItem = scope:Value(nil)

	-- Hover desc position and float springs - slide out from left side of inventory
	local hoverDescX = scope:Value(-0.5) -- Start off-screen to the left
	local hoverDescXSpring = scope:Spring(hoverDescX, 20, 0.7)
	local hoverDescFloatX = scope:Value(0)
	local hoverDescFloatY = scope:Value(0)
	local hoverDescFloatXSpring = scope:Spring(hoverDescFloatX, 15, 0.9)
	local hoverDescFloatYSpring = scope:Spring(hoverDescFloatY, 15, 0.9)

	-- HoverDesc transparency spring
	local hoverDescTransparency = scope:Value(1)
	local hoverDescTransparencySpring = scope:Spring(hoverDescTransparency, 22, 0.75)

	-- HoverDesc fold-out springs (vertical expansion from center)
	local hoverDescHeight = scope:Value(0)
	local hoverDescHeightSpring = scope:Spring(hoverDescHeight, 20, 0.7)

	local holder = scope:New("Frame")({
		Name = "Holder",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = scope:Computed(function(use)
			return UDim2.fromScale(0.5, use(holderYSpring))
		end),
		Size = scope:Computed(function(use)
			local height = use(holderHeightSpring)
			return UDim2.fromOffset(459, height)
		end),
		ClipsDescendants = false,
		Parent = props.Parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
	})

	-- Hover description panel
	local headerTextLabel = scope:New("TextLabel")({
		Name = "Header",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		FontFace = Font.new("rbxassetid://12187365364"),
		Position = UDim2.fromScale(0.0619, 0.06),
		Size = UDim2.fromOffset(187, 32),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
		TextScaled = true,
		TextTransparency = 1, -- Start hidden
		ZIndex = 12, -- Higher than HoverDesc background
	})

	local descTextLabel = scope:New("TextLabel")({
		Name = "Descriptions",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		FontFace = Font.new("rbxassetid://12187365364"),
		Position = UDim2.fromScale(0.0619, 0.36),
		Size = UDim2.fromOffset(187, 52),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
		TextWrapped = true,
		TextTransparency = 1, -- Start hidden
		ZIndex = 12, -- Higher than HoverDesc background
	})

	local hoverDesc = scope:New("ImageLabel")({
		Name = "HoverDesc",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Image = "rbxassetid://130684158382755",
		Position = scope:Computed(function(use)
			local baseX = use(hoverDescXSpring)
			local floatX = use(hoverDescFloatXSpring)
			local floatY = use(hoverDescFloatYSpring)
			local height = use(hoverDescHeightSpring)
			-- Position relative to holder, moved down
			-- Y position accounts for height change to keep centered
			local yPos = 0.35 + (100 - height) / 2 / 549
			return UDim2.new(baseX, floatX, yPos, floatY)
		end),
		AnchorPoint = Vector2.new(1, 0.5), -- Anchor to right edge so it slides out to the left
		ImageTransparency = hoverDescTransparencySpring,
		Size = scope:Computed(function(use)
			local height = use(hoverDescHeightSpring)
			return UDim2.fromOffset(210, height)
		end),
		ClipsDescendants = true,
		ZIndex = 10, -- High ZIndex to ensure it's on top
		Parent = holder,
		[Children] = {
			headerTextLabel,
			descTextLabel,
		}
	})

	local bg = scope:New("ImageLabel")({
		Name = "BG",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Image = "rbxassetid://132636952355024",
		Position = UDim2.fromScale(0, -0.0182),
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(1, 1),
		SliceCenter = Rect.new(147, 166, 147, 748),
		ImageTransparency = bgTransparencySpring,
		Parent = holder,
	})

	local searchBox = scope:New("TextBox")({
		Name = "SearchBox",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		CursorPosition = -1,
		FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
		PlaceholderText = "Search...",
		Position = UDim2.fromScale(0.168, 0.0273),
		Size = UDim2.fromOffset(131, 10),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextTransparency = scope:Computed(function(use)
			return use(bgTransparencySpring)
		end),
		TextSize = 14,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bg,
		[scope.OnChange("Text")] = function(newText)
			searchQuery:set(newText:lower())
		end,
	})

	local iconHolder = scope:New("Frame")({
		Name = "IconHolder",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.0588, 0.0638),
		Size = UDim2.fromOffset(414, 471),
		Parent = holder,
	})

	local iconFolder = scope:New("Folder")({
		Name = "IconFolder",
		Parent = iconHolder,
	})

	local listLayout = scope:New("UIListLayout")({
		Name = "UIListLayout",
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.02, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Wraps = true,
		Parent = iconFolder,
	})

	-- HoverDesc floating connection
	local hoverDescFloatConnection = nil

	-- Store all deselect functions globally
	local deselectFunctions = {}

	-- Observer to trigger animation when started becomes true
	scope:Observer(started):onChange(function()
		local isStarted = scope.peek(started)
		if not isStarted then
			-- Hide inventory
			holderHeight:set(0)
			bgTransparency:set(1)

			-- Clear all icons when closing
			for _, child in ipairs(iconFolder:GetChildren()) do
				if child:IsA("ImageButton") then
					child:Destroy()
				end
			end

			-- Clear deselect functions
			table.clear(deselectFunctions)
			selectedItem:set(nil)

			return
		end

		-- Animate holder scrolling down with spring
		task.delay(0.1, function()
			holderHeight:set(549) -- Scroll down to full height
			bgTransparency:set(0) -- Fade in background

			-- Wait for spring to settle before showing icons
			task.wait(0.8)

			-- Create icons and animate them in rows
			local iconsPerRow = 7
			local icons = {}

			-- Get current inventory items
			local currentItems = scope.peek(inventoryItems)

			for i, item in ipairs(currentItems) do
				local itemName = item.name
				local itemDesc = item.description or "No description available."
				local itemIcon = item.icon or "rbxassetid://125715866811318" -- Default icon if none provided
				local itemRarity = item.rarity or "common" -- Default to common if no rarity specified
				local rarityGradient = RARITY_GRADIENTS[itemRarity] or RARITY_GRADIENTS.common

				-- Create spring values for each icon
				local iconTransparency = scope:Value(1)
				local iconScale = scope:Value(0)
				local hoverScale = scope:Value(1)
				local floatOffsetX = scope:Value(0)
				local floatOffsetY = scope:Value(0)

				-- Visibility spring for search filtering
				local visibilityTransparency = scope:Value(0)
				local visibilitySpring = scope:Spring(visibilityTransparency, 20, 0.7)
				local isVisible = scope:Value(true)

				-- Springs with different frequencies for variety
				local transparencySpring = scope:Spring(iconTransparency, 25, 0.7)
				local scaleSpring = scope:Spring(iconScale, 20, 0.5)
				local hoverScaleSpring = scope:Spring(hoverScale, 25, 0.6)
				local floatXSpring = scope:Spring(floatOffsetX, 30, 0.8)
				local floatYSpring = scope:Spring(floatOffsetY, 30, 0.8)

				local icon = scope:New("ImageButton")({
					Name = "Icon" .. i,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Image = itemIcon,
				Size = scope:Computed(function(use)
					local scale = use(scaleSpring)
					local hScale = use(hoverScaleSpring)
					return UDim2.fromScale(0.121 * scale * hScale, 0.102 * scale * hScale)
				end),
				Position = scope:Computed(function(use)
					local xOffset = use(floatXSpring)
					local yOffset = use(floatYSpring)
					return UDim2.fromOffset(xOffset, yOffset)
				end),
				ImageTransparency = scope:Computed(function(use)
					local baseTransparency = use(transparencySpring)
					local visTransparency = use(visibilitySpring)
					return math.max(baseTransparency, visTransparency)
				end),
				Visible = scope:Computed(function(use)
					return use(isVisible)
				end),
				LayoutOrder = i,
				Parent = iconFolder,
			})

			-- Hover effects
			local isHovering = false
			local isSelected = false
			local floatThread = nil
			local gradientThread = nil

			icon.MouseEnter:Connect(function()
				if isSelected then return end
				isHovering = true
				hoverScale:set(1.15) -- Scale up on hover

				-- Start smooth floating animation with springs
				floatThread = task.spawn(function()
					local angle = 0
					while isHovering do
						angle = angle + 0.08 -- Smooth increment
						local targetX = math.sin(angle) * 3
						local targetY = math.cos(angle * 0.8) * 2 -- Different frequency for Y
						floatOffsetX:set(targetX)
						floatOffsetY:set(targetY)
						task.wait(1/60) -- 60 FPS for smooth spring updates
					end
				end)
			end)

			icon.MouseLeave:Connect(function()
				if isSelected then return end
				isHovering = false
				if floatThread then
					task.cancel(floatThread)
				end
				hoverScale:set(1) -- Return to normal size
				floatOffsetX:set(0)
				floatOffsetY:set(0)
			end)

			local itemNameLabel = scope:New("TextLabel")({
				Name = "ItemName",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxassetid://12187365364"),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = scope:Computed(function(use)
					local hScale = use(hoverScaleSpring)
					-- Make text container smaller to prevent overflow
					return UDim2.fromScale(0.9 / hScale, 0.6 / hScale)
				end),
				Text = itemName, -- Keep the text so TextPlus can read it
				TextColor3 = Color3.fromRGB(255, 255, 255), -- Will be overridden by gradient
				TextTransparency = 1, -- Start hidden, will be animated by TextPlus
				TextSize = 12, -- Smaller text size
				TextScaled = true,
				TextWrapped = true, -- Wrap text to prevent overflow
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				-- Text stroke
				TextStrokeTransparency = 0.5,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				ZIndex = 15, -- High ZIndex so text is on top
				Parent = icon,
			})

			-- Add gradient to text
			local textGradient = scope:New("UIGradient")({
				Name = "RarityGradient",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, rarityGradient[1]),
					ColorSequenceKeypoint.new(1, rarityGradient[2]),
				}),
				Rotation = 90, -- Vertical gradient
				Parent = itemNameLabel,
			})

			-- Store rainbow animation flag for priceless items
			local isPriceless = itemRarity == "priceless"

			-- Define deselect function
			local function deselectIcon()
				isSelected = false
				hoverScale:set(1)
				floatOffsetX:set(0)
				floatOffsetY:set(0)
				if floatThread then
					task.cancel(floatThread)
					floatThread = nil
				end
				if gradientThread then
					task.cancel(gradientThread)
					gradientThread = nil
				end
				-- Remove gradients from this icon
				for _, char in itemNameLabel:GetDescendants() do
					if char:IsA("UIGradient") and char.Name == "SilverFlash" then
						char:Destroy()
					end
				end
			end

			-- Store the deselect function globally
			deselectFunctions[icon] = deselectIcon

			-- Click to select
			icon.MouseButton1Click:Connect(function()
				-- Unselect previous item
				local prevSelected = scope.peek(selectedItem)
				if prevSelected and prevSelected ~= icon then
					-- Call the deselect function for the previous icon
					if deselectFunctions[prevSelected] then
						deselectFunctions[prevSelected]()
					end
				end

				-- Toggle selection
				isSelected = not isSelected

				if isSelected then
					selectedItem:set(icon)
					hoverScale:set(1.15)

					-- Keep floating while selected with smooth spring animation
					floatThread = task.spawn(function()
						local angle = 0
						while isSelected do
							angle = angle + 0.08 -- Smooth increment
							local targetX = math.sin(angle) * 3
							local targetY = math.cos(angle * 0.8) * 2 -- Different frequency for Y
							floatOffsetX:set(targetX)
							floatOffsetY:set(targetY)
							task.wait(1/60) -- 60 FPS for smooth spring updates
						end
					end)

					-- Slide out hover desc to the LEFT of the holder (0 = at left edge of holder)
					hoverDescX:set(0)
					hoverDescHeight:set(100) -- Fold out to full height
					hoverDescTransparency:set(0)

					-- Start HoverDesc floating (smooth circular motion with springs)
					hoverDescFloatConnection = task.spawn(function()
						local angle = 0
						while scope.peek(selectedItem) == icon do
							angle = angle + 0.05 -- Smooth increment
							local radius = 2
							local targetX = math.sin(angle) * radius
							local targetY = math.cos(angle) * radius
							hoverDescFloatX:set(targetX)
							hoverDescFloatY:set(targetY)
							task.wait(1/60) -- 60 FPS for smooth spring updates
						end
					end)

					-- Clear and animate header with dancing shadow and rainbow
					task.spawn(function()
						task.wait(0.3)
						headerTextLabel.Text = itemName
						dancingShadowAnimation(scope, headerTextLabel, 0.02, true) -- true = add rainbow + dancing shadow
					end)

					-- Clear and animate description with fade diverge
					task.spawn(function()
						task.wait(0.3)
						descTextLabel.Text = itemDesc
						fadeDivergeAnimation(scope, descTextLabel, 0.015)
					end)

					-- Add silver flash gradient to ALL letters
					task.wait(0.1)
					local chars = getCharacters(itemNameLabel)
					gradientThread = task.spawn(function()
						for _, character in chars do
							if character.Parent then
								local gradient = Instance.new("UIGradient")
								gradient.Name = "SilverFlash"
								gradient.Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 150, 150)),
									ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 220, 220)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
								})
								gradient.Offset = Vector2.new(-1, 0)
								gradient.Parent = character

								-- Animate gradient across continuously
								task.spawn(function()
									while isSelected and gradient.Parent do
										local tween = TweenService:Create(
											gradient,
											TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
											{ Offset = Vector2.new(1, 0) }
										)
										tween:Play()
										tween.Completed:Wait()
										if isSelected and gradient.Parent then
											gradient.Offset = Vector2.new(-1, 0)
										end
									end
								end)
							end
						end
					end)
				else
					selectedItem:set(nil)
					deselectIcon()

					-- Stop HoverDesc floating (task.spawn returns a thread, not a connection)
					if hoverDescFloatConnection then
						task.cancel(hoverDescFloatConnection)
						hoverDescFloatConnection = nil
					end
					hoverDescFloatX:set(0)
					hoverDescFloatY:set(0)

					-- Slide back hover desc off-screen to the left, fold back in, and fade out
					hoverDescX:set(-0.5)
					hoverDescHeight:set(0) -- Fold back to 0 height
					hoverDescTransparency:set(1)
				end
			end)

			-- Search filtering observer
			scope:Observer(searchQuery):onChange(function()
				local query = scope.peek(searchQuery)
				local nameToCheck = itemName:lower()

				if query == "" or nameToCheck:find(query, 1, true) then
					-- Item matches search, make visible
					visibilityTransparency:set(0)
					isVisible:set(true)
				else
					-- Item doesn't match, fade out and hide
					visibilityTransparency:set(1)
					task.wait(0.3) -- Wait for fade animation
					isVisible:set(false)
				end
			end)

			table.insert(icons, {
				icon = icon,
				label = itemNameLabel,
				itemName = itemName,
				itemDesc = itemDesc,
				transparencyValue = iconTransparency,
				scaleValue = iconScale,
				rarityGradient = rarityGradient,
				isPriceless = isPriceless,
			})
		end

		-- Animate icons in rows with wave effect
		for rowIndex = 0, math.ceil(#icons / iconsPerRow) - 1 do
			local rowStart = rowIndex * iconsPerRow + 1
			local rowEnd = math.min(rowStart + iconsPerRow - 1, #icons)

			-- Animate each icon in the row with stagger
			for i = rowStart, rowEnd do
				local iconData = icons[i]
				local positionInRow = i - rowStart
				local delay = positionInRow * 0.08 -- Wave delay

				task.delay(delay, function()
					-- Trigger spring animation for icon
					iconData.transparencyValue:set(0)
					iconData.scaleValue:set(1)

					-- Wait for icon to finish scaling, then animate text with sparky diverge
					task.wait(0.4)
					fadeDivergeAnimation(scope, iconData.label, 0.02, iconData.rarityGradient)

					-- Add rainbow animation for priceless items
					if iconData.isPriceless then
						task.wait(0.5) -- Wait for text animation to complete
						task.spawn(function()
							local hue = 0
							while iconData.label and iconData.label.Parent do
								hue = (hue + 0.01) % 1

								-- Update all character colors
								for _, child in iconData.label:GetChildren() do
									if child:IsA("TextLabel") then
										local charIndex = tonumber(child.Name:match("%d+")) or 1
										local totalChars = #iconData.label:GetChildren()
										local offset = (charIndex - 1) / math.max(totalChars - 1, 1)
										local charHue = (hue + offset * 0.3) % 1
										child.TextColor3 = Color3.fromHSV(charHue, 1, 1)
									end
								end

								task.wait(1/30) -- 30 FPS for rainbow animation
							end
						end)
					end
				end)
			end

			-- Wait before starting next row
			task.wait(0.6)
		end
	end)
	end)

	return holder
end

return InventoryUI