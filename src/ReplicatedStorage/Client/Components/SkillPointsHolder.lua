local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)

local Children, scoped, peek, OnEvent, Value, Computed, Tween, Spring = 
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.OnEvent, Fusion.Value, Fusion.Computed, Fusion.Tween, Fusion.Spring

local TInfoFast = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0)

return function(scope, props: {})
	local showSkillPointsHolder = props.showSkillPointsHolder
	local availablePoints = props.availablePoints
	local onConfirm = props.onConfirm

	return scope:New "Frame" {
		Name = "SkillPointsHolder",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(-2.5, 0.577),  -- Restored original position
		Size = UDim2.fromOffset(253, 242),

		[Children] = {
			scope:New "ImageLabel" {
				Name = "SP",
				BackgroundTransparency = 1,
				Image = "rbxassetid://91164515802298",
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(showSkillPointsHolder) then UDim2.fromScale(0.3, 0.186) else UDim2.fromScale(0.3, 0.1)
					end),
					25,
					0.9
				),
				Size = UDim2.fromOffset(100, 100),
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(showSkillPointsHolder) then 0 else 1
					end),
					TInfoFast
				),

				[Children] = {
					scope:New "TextLabel" {
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.0874, 0),
						Size = UDim2.fromScale(0.752, 0.91),
						Text = scope:Computed(function(use)
							return tostring(use(availablePoints))
						end),
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showSkillPointsHolder) then 0 else 1
							end),
							TInfoFast
						),
					}
				}
			},

			scope:New "ImageLabel" {
				Name = "SPA",
				BackgroundTransparency = 1,
				Image = "rbxassetid://106181050430066",
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(showSkillPointsHolder) then UDim2.fromScale(-0.00395, 0.645) else UDim2.fromScale(-0.00395, 0.7)
					end),
					25,
					0.9
				),
				Size = UDim2.fromOffset(253, 27),
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(showSkillPointsHolder) then 0 else 1
					end),
					TInfoFast
				),

				[Children] = {
					scope:New "TextLabel" {
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = UDim2.fromScale(0.217, 0),
						Size = UDim2.fromScale(0.632, 1),
						Text = "ATTRIBUTE POINTS",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 14,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showSkillPointsHolder) then 0 else 1
							end),
							TInfoFast
						),
					}
				}
			},

			scope:New "ImageButton" {
				Name = "Confirm",
				BackgroundTransparency = 1,
				Image = "rbxassetid://118973584856362",
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(showSkillPointsHolder) then UDim2.fromScale(0.3, 0.785) else UDim2.fromScale(0.3, 0.85)
					end),
					25,
					0.9
				),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromOffset(100, 34),
				SliceCenter = Rect.new(171, 20, 187, 42),
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(showSkillPointsHolder) then 0 else 1
					end),
					TInfoFast
				),

				[OnEvent "Activated"] = function()
					if onConfirm then
						onConfirm()
					end
				end,

				[Children] = {
					scope:New "TextLabel" {
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Size = UDim2.fromScale(1, 1),
						Text = "CONFIRM",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 14,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showSkillPointsHolder) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIStroke" {
								Thickness = 3,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showSkillPointsHolder) then 0 else 1
									end),
									TInfoFast
								),
							},
						}
					},
				}
			},
		}
	}
end