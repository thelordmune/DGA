local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local TweenService = game:GetService("TweenService")
local TextPlus = require(ReplicatedStorage.Modules.Text)

local Children, scoped, OnEvent = Fusion.Children, Fusion.scoped, Fusion.OnEvent

local TInfo = TweenInfo.new(.2, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

-- Typewriter animation function
local function animateTextIn(textFrame, delayPerChar)
	delayPerChar = delayPerChar or 0.05

	-- Small delay to ensure TextPlus has finished rendering
	task.wait(0.05)

	-- Check if the frame has any children
	if #textFrame:GetChildren() == 0 then
		warn("No text to animate")
		return
	end

	-- Collect all character instances (handles word/line sorting)
	local characters = {}
	for _, child in textFrame:GetChildren() do
		if child:IsA("ImageLabel") or child:IsA("TextLabel") then
			table.insert(characters, child)
		elseif child:IsA("Folder") then
			-- Get characters from folders (for word/line sorting)
			for _, character in child:GetChildren() do
				if character:IsA("ImageLabel") or character:IsA("TextLabel") then
					table.insert(characters, character)
				end
			end
		end
	end

	-- Animate each character in
	for _, character in characters do
		-- Check if character still exists (in case frame was cleared during animation)
		if not character.Parent then
			break
		end

		-- Start invisible and offset down
		if character:IsA("ImageLabel") then
			character.ImageTransparency = 1
		elseif character:IsA("TextLabel") then
			character.TextTransparency = 1
		end

		local originalPos = character.Position
		character.Position = originalPos + UDim2.fromOffset(0, 5)

		-- Tween in with fade and slide up
		local tween = TweenService:Create(character, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = originalPos,
			ImageTransparency = 0,
			TextTransparency = 0
		})
		tween:Play()

		-- Wait before next character
		task.wait(delayPerChar)
	end
end

-- Clear text animation
local function animateTextOut(textFrame)
	-- Check if the frame has any children (TextPlus renders characters as children)
	if #textFrame:GetChildren() == 0 then
		-- No text to animate out, just return
		return
	end

	-- Animate all children (characters/words/lines)
	for _, child in textFrame:GetChildren() do
		-- Handle both direct characters and word/line folders
		if child:IsA("ImageLabel") or child:IsA("TextLabel") then
			local tween = TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				ImageTransparency = 1,
				TextTransparency = 1
			})
			tween:Play()
		elseif child:IsA("Folder") then
			-- Animate children of folders (for word/line sorting)
			for _, character in child:GetChildren() do
				if character:IsA("ImageLabel") or character:IsA("TextLabel") then
					local tween = TweenService:Create(character, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						ImageTransparency = 1,
						TextTransparency = 1
					})
					tween:Play()
				end
			end
		end
	end

	task.wait(0.2)
end

return function(scope: any, props: {})
	local parent = props.Parent
	local started = props.Started
	local clicked = props.Clicked

	local isHovering = scope:Value(false)

	-- Frame to hold the TextPlus rendered text
	local textFrame = scope:New "Frame" {
		Parent = parent,
		Name = "TextFrame",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(446, 199),
		Size = UDim2.fromOffset(800, 200),
		ClipsDescendants = false,
	}

	-- Watch for clicked state changes and update text
	scope:Computed(function(use)
		if use(clicked :: boolean) then
			-- Create new text with TextPlus (automatically clears previous text)
			TextPlus.Create(textFrame, "The echoes of the dead transmit through the stone. A sharp tingle engulfs your body... or maybe its just the wind, who knows?", {
				Size = 14,
				Font = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
				Color = Color3.fromHex("#a30000"),

				-- Perfect character spacing (no gaps!)
				CharacterSpacing = 1.0,
				LineHeight = 1.2,

				-- Stroke for better readability
				StrokeSize = 2,
				StrokeColor = Color3.fromRGB(0, 0, 0),
				StrokeTransparency = 0.7,

				-- Alignment
				XAlignment = "Left",
				YAlignment = "Top",

				-- Enable dynamic resizing
				Dynamic = false,
			})

			-- Animate the text in with typewriter effect
			task.spawn(function()
				animateTextIn(textFrame, 0.05)
			end)
		else
			-- Animate out then clear
			task.spawn(function()
				animateTextOut(textFrame)
				TextPlus.Create(textFrame, "", {})
			end)
		end

		return nil
	end)

	return scope:New "TextButton" {
		Parent = parent,
		Name = "Play",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		FontFace = Font.new(
			"rbxasset://fonts/families/Nunito.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		),
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(started) then UDim2.fromScale(0.021, 0.591) else UDim2.fromScale(0.021, -0.591)
			end),
			10,
			.8
		),
		Size = scope:Tween(
			scope:Computed(function(use)
				return if use(isHovering) then UDim2.fromOffset(250, 60) else UDim2.fromOffset(200, 50)
			end),
			TInfo
		),
		Text = "PLAY",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextSize = 14,
		TextWrapped = true,
		ZIndex = 0,
		[OnEvent "Activated"] = function()
			started:set(false)
			script.Click:Play()
		end,

		[OnEvent "MouseEnter"] = function()
			isHovering:set(true)
			script.Hover:Play()
		end,

		[OnEvent "MouseLeave"] = function()
			isHovering:set(false)
		end,

		[Children] = {
			textFrame
		}

	}
end

