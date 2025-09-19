local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Players = game:GetService("Players")
local RichText = require(ReplicatedStorage.Modules.RichText)

local Children, scoped, peek, out = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out

local TInfo = TweenInfo.new(.7, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)
local TInfo2 = TweenInfo.new(1.1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

return function(scope, props: {})
	local descriptionText: string = props.descriptionText
	local headerText: string = props.headerText
	local framein: boolean = props.framein

	local header = scope:New "TextLabel" {
		Name = "header",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		FontFace = Font.new("rbxassetid://12187373327"),
		Position = UDim2.fromScale(0.166, 0.105),
		Size = UDim2.fromOffset(200, 50),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextSize = 14,
		TextWrapped = true,
		Text = ""
	}

	local description = scope:New "TextLabel" {
		Name = "Description",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		FontFace = Font.new("rbxassetid://12187373327"),
		Position = UDim2.fromScale(0.166, 0.439),
		Size = UDim2.fromOffset(199, 149),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
	}

	scope:Computed(function(use)
		return if use(framein) then RichText.AnimateText(peek(descriptionText), description, 0.05, Enum.Font.SourceSans, "fade diverge", 1, 14) else ""
	end)

	scope:Computed(function(use)
		return if use(framein) then RichText.AnimateText(peek(headerText), header, 0.02, Enum.Font.SourceSans, "fade diverge", 1, 14) else ""
	end)
	return scope:New "Frame" {
		Name = "Frame",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(framein) then UDim2.fromScale(0.0833, 0.221) else UDim2.fromScale(-1, 0.221)
			end),
			18,
			.4
		),
		Size = UDim2.fromOffset(301, 342),
        Parent = props.Parent,

		[Children] = {

			header,

			description,

			-- scope:New "TextButton" {
			-- 	Name = "TextButton",
			-- 	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			-- 	BackgroundTransparency = 1,
			-- 	BorderColor3 = Color3.fromRGB(0, 0, 0),
			-- 	BorderSizePixel = 0,
			-- 	FontFace = Font.new(
			-- 		"rbxassetid://12187373327",
			-- 		Enum.FontWeight.Bold,
			-- 		Enum.FontStyle.Normal
			-- 	),
			-- 	Position = UDim2.fromScale(0.166, 0.904),
			-- 	Size = UDim2.fromOffset(200, 50),
			-- 	Text = "CANCEL",
			-- 	TextColor3 = Color3.fromRGB(255, 0, 0),
			-- 	TextScaled = true,
			-- 	TextSize = 14,
			-- 	TextWrapped = true,
			-- },
		}
	}
end


