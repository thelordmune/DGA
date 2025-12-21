local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local Children, scoped, peek, out, OnEvent, OnChange =
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.OnChange

local TInfo = TweenInfo.new(0.7, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)
local TInfo2 = TweenInfo.new(1.1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

return function(scope: any, props: {})
	local ingamename = props.IGN
	local title = props.Title
	local faction = props.Faction
	return scope:New("Frame")({
		Name = "Player",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.038),
		Size = UDim2.fromOffset(180, 50),
		

		[Children] = {
			scope:New("ImageLabel")({
				Name = "Border",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://103925877937964",
				Position = UDim2.fromScale(0, 0.104),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.997, 0.896),
				SliceScale = 0.5,

				[Children] = {
					scope:New("UIGradient")({
						Name = "UIGradient",
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(1, 0),
						}),
					}),
				},
			}),
			-- peek(ingamename)
			scope:New("TextLabel")({
				Name = "IGN",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
              BackgroundTransparency = 1,
              BorderColor3 = Color3.fromRGB(0, 0, 0),
              BorderSizePixel = 0,
              FontFace = Font.new(
                "rbxasset://fonts/families/Sarpanch.json",
                Enum.FontWeight.Regular,
                Enum.FontStyle.Italic
              ),
              Position = UDim2.fromScale(0.513, 0.104),
              Size = UDim2.fromScale(0.425, 0.448),
              Text = peek(ingamename),
              TextColor3 = Color3.fromRGB(255, 255, 255),
              TextSize = 14,
              TextStrokeTransparency = 0,

				[Children] = {
					scope:New("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
							ColorSequenceKeypoint.new(0.393, Color3.fromRGB(255, 255, 255)),
							ColorSequenceKeypoint.new(0.678, Color3.fromRGB(99, 99, 99)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
						}),
						Rotation = 90,
					}),

					scope:New("UIStroke")({
						Name = "UIStroke",
						Thickness = 0.5,
					}),
				},
			}),

			scope:New("TextLabel")({
				Name = "Title",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/Sarpanch.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.566, 0.414),
				Size = UDim2.fromScale(0.428, 0.306),
				Text = peek(title),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 11,
				TextStrokeTransparency = 0,
				ZIndex = 3,

				[Children] = {
					scope:New("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 198)),
						}),
						Rotation = 90,
					}),
					scope:New("UIStroke")({
						Name = "UIStroke",
					}),
				},
			}),
		},
	})
end
