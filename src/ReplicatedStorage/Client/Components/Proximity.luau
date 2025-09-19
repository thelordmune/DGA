local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Players = game:GetService("Players")

local Children, scoped, peek, out = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out

local TInfo = TweenInfo.new(.7, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)
local TInfo2 = TweenInfo.new(1.1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

return function(scope, props: {})
	local started: boolean = props.begin
	local parent: ScreenGui = props.par
	return scope:New "Frame" {
		Name = "Frame",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.444, 0.664),
		Size = UDim2.fromScale(0.112, 0.112),
		Parent = parent,

		[Children] = {
			scope:New "TextLabel" {
				Name = "TextLabel",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(-0.108, 0.27),
				Size = UDim2.fromScale(1.21, 0.5),
				Text = "E TO TALK",
				TextTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(started) then 0 else 1
					end),
					TInfo
				),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
			},
		}
	}
end