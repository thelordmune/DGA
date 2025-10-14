local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)

local Children, scoped, peek = Fusion.Children, Fusion.scoped, Fusion.peek

local TInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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

-- Fade Diverge Animation IN (SwagText style)
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

		-- Set initial state
		if isImageLabel then
			character.ImageTransparency = 1
		else
			character.TextTransparency = 1
		end
		character.Position = originalPos - UDim2.fromOffset(xOffset, yOffset)

		-- Animate
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		local props = { Position = originalPos }
		props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 0

		TweenService:Create(character, tweenInfo, props):Play()
		task.wait(delayPerChar)
	end
end

-- Fade Diverge Animation OUT (reverse)
local function fadeDivergeOutAnimation(textFrame, delayPerChar)
	delayPerChar = delayPerChar or 0.01

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

		-- Animate to diverged position and fade out
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		local props = { Position = originalPos + UDim2.fromOffset(xOffset, yOffset) }
		props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 1

		TweenService:Create(character, tweenInfo, props):Play()
		task.wait(delayPerChar)
	end
end

-- Rainbow color animation for items
local function animateRainbow(textFrame)
	task.spawn(function()
		local hue = 0
		while textFrame and textFrame.Parent do
			hue = (hue + 0.01) % 1
			local color = Color3.fromHSV(hue, 1, 1)
			
			for _, character in getCharacters(textFrame) do
				if character:IsA("TextLabel") then
					character.TextColor3 = color
				elseif character:IsA("ImageLabel") then
					character.ImageColor3 = color
				end
			end
			
			task.wait(0.03)
		end
	end)
end

return function(scope, props: {})
	local notifType: string = props.notifType -- "Skill", "Item", or "Quest"
	local itemName: string = props.itemName
	local parent = props.Parent
	local slot: number = props.slot or 0 -- Vertical slot position (0-4)
	local onComplete = props.onComplete -- Callback when notification finishes

	local visible = scope:Value(false)
	local textRendered = scope:Value(false)

	-- Calculate Y position based on slot (stacked from bottom)
	local NOTIFICATION_HEIGHT = 30 -- Height + spacing between notifications (smaller for text-only)
	local yOffset = -(slot * NOTIFICATION_HEIGHT)

	-- Determine text color based on type
	local textColor
	if notifType == "Skill" then
		textColor = Color3.fromRGB(100, 150, 255) -- Blue for skills
	elseif notifType == "Quest" then
		textColor = Color3.fromRGB(200, 100, 255) -- Purple for quests
	else
		textColor = Color3.fromRGB(255, 255, 255) -- White for items
	end

	-- Create textFrame using Fusion scope (same as DialogueComp)
	local textFrame = scope:New("Frame")({
		Name = "TextContainer",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0, 0),
	})

	-- Track if this notification is being destroyed
	local isDestroying = false
	
	-- Create the notification frame (transparent, text-only)
	local notificationFrame = scope:New("Frame")({
		Name = "Notification",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = scope:Tween(
			scope:Computed(function(use)
				-- Slide in from right, positioned based on slot
				local xPos = if use(visible) then 0 else 200 -- Slide from off-screen
				return UDim2.new(1, xPos, 1, yOffset)
			end),
			TInfo
		),
		Size = UDim2.fromOffset(200, 25), -- Smaller size for text-only
		Parent = parent,

		[Children] = {
			-- Text container (added to Children like DialogueComp)
			textFrame,
		},
	})
	
	-- Animate in and create text
	task.spawn(function()
		-- Wait for frame to be in DataModel and properly parented
		local maxWait = 0
		while (not notificationFrame:IsDescendantOf(game) or not textFrame:IsDescendantOf(game)) and maxWait < 100 do
			task.wait(0.01)
			maxWait = maxWait + 1
		end

		if not textFrame:IsDescendantOf(game) then
			warn("[NotificationComp] TextFrame not in DataModel after waiting")
			if onComplete then
				onComplete()
			end
			return
		end

		-- Wait for next Heartbeat to ensure frame is fully processed
		RunService.Heartbeat:Wait()

		-- Verify frame is still valid
		if not textFrame or not textFrame.Parent then
			warn("[NotificationComp] TextFrame became invalid")
			if onComplete then
				onComplete()
			end
			return
		end

		-- Clear any existing children (important for TextPlus)
		for _, child in textFrame:GetChildren() do
			child:Destroy()
		end

		-- Wait one more frame to ensure cleanup is complete
		RunService.Heartbeat:Wait()

		-- Create the text with TextPlus drop shadow
		local success, err = pcall(function()
			-- Create full text with TextPlus
			local fullText
			if notifType == "Quest" then
				fullText = "[+] Quest : New Quest Added to Index"
			else
				fullText = "[+] " .. notifType .. " : " .. itemName
			end

			TextPlus.Create(textFrame, fullText, {
				Font = Font.new("rbxasset://fonts/families/Prompt.json", Enum.FontWeight.Bold),
				Size = 20, -- Smaller text
				Color = textColor,
				Transparency = 1,
				XAlignment = "Right", -- Align to right
				YAlignment = "Center",
				--Drop shadow using TextPlus built-in feature
				ShadowOffset = Vector2.new(.5, .5), -- Shadow offset (x, y)
				ShadowColor = textColor, -- Black shadow
				ShadowTransparency = 0.9, -- 50% transparent
				StrokeSize = .2,
				StrokeColor = Color3.fromRGB(0, 0, 0),
				StrokeTransparency = 0.5,
			})
		end)

		if not success then
			warn("[NotificationComp] Failed to create TextPlus:", err)
			if onComplete then
				onComplete()
			end
			return
		end

		textRendered:set(true)

		-- Slide in
		visible:set(true)
		task.wait(0.5)

		-- Animate text with fade diverge
		fadeDivergeAnimation(textFrame, 0.01)

		-- If it's an item, start rainbow animation
		if notifType == "Item" then
			task.wait(0.3) -- Wait for fade diverge to mostly complete
			animateRainbow(textFrame)
		end

		-- Wait before fading out
		task.wait(3)

		-- Mark as destroying
		isDestroying = true

		-- Fade diverge OUT animation (characters spread and fade)
		fadeDivergeOutAnimation(textFrame, 0.01)
		task.wait(0.3) -- Wait for fade diverge out to complete

		-- Slide out the notification frame to the right
		visible:set(false)
		task.wait(0.5) -- Wait for slide-out animation to complete

		-- Now clear TextPlus children after all animations
		for _, child in textFrame:GetChildren() do
			child:Destroy()
		end

		-- Wait for cleanup
		task.wait(0.1)

		-- Cleanup callback
		if onComplete then
			onComplete()
		end

		-- Destroy the frame
		if notificationFrame and notificationFrame.Parent then
			notificationFrame:Destroy()
		end
	end)
	
	return notificationFrame
end

