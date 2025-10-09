local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local Children, scoped, peek, out, OnEvent, OnChange = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.OnChange

local TInfo = TweenInfo.new(.7, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)
local TInfo2 = TweenInfo.new(1.1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)


return function(scope: any, props: {})
	local ingamename = props.IGN
	local title = props.Title
	local faction = props.Faction
	return scope:New "Frame" {
		Name = "Player",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(-0.116, 0),
		Size = UDim2.fromOffset(126, 50),

		[Children] = {
			scope:New "ImageLabel" {
				Name = "Border",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://97767363406553",
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(1, 1),
				SliceCenter = Rect.new(9, 9, 21, 21),

				[Children] = {
					scope:New "UIGradient" {
						Name = "UIGradient",
						Color = scope:Computed(function(use)
							return if use(faction) == "None" then ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(156, 156, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(156, 156, 255)),
							})
								elseif use(faction) == "Military" then
								ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255)),
								})
								elseif use(faction) == "Rogue" then
								ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0)),
								})
								else
								ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(156, 156, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(156, 156, 255)),
								})
						end),
					},
				}
			},

			scope:New "TextLabel" {
				Name = "IGN",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
				Position = UDim2.fromScale(0.0873, 0.18),
				Size = UDim2.fromScale(0.833, 0.408),
				Text = peek(ingamename),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
			},

			scope:New "TextLabel" {
				Name = "Title",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
				Position = UDim2.fromScale(0.0873, 0.588),
				Size = UDim2.fromScale(0.833, 0.192),
				Text = peek(title),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 11,

				[Children] = {
					scope:New "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 198)),
						}),
					},
				}
			},
		}
	}
end
