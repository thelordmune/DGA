local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Players = game:GetService("Players")
local RichText = require(ReplicatedStorage.Modules.RichText)
local plr = Players.LocalPlayer

local Children, scoped, peek, out, OnEvent, OnChange = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.OnChange

local TInfo = TweenInfo.new(.7, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)
local TInfo2 = TweenInfo.new(1.1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

return function(scope, props: {})
	local squad: boolean = props.squadselected
	local temp: boolean = props.tempselected
	local started: boolean = props.started
	local invited: boolean = props.invited
	local user: string = props.user
	local parent: Instance = props.parent
	
	return scope:New "Frame" {
		Parent = parent,
		Name = "Frame",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(started) then  UDim2.fromOffset(50,458) else  UDim2.fromOffset(-350,458)
			end),
			10,
			.8
			),
		Size = UDim2.fromOffset(185, 139),

		[Children] = {
			scope:New "ImageLabel" {
				Name = "Border",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://121279258155271",
				--ImageContent = Content.new(Content),
				SelectionOrder = -3,
				Size = UDim2.fromScale(1, 1),
			},

			scope:New "ImageLabel" {
				Name = "Background",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://85774200010476",
				--ImageContent = Content.new(Content),
				SelectionOrder = -3,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,

				[Children] = {
					scope:New "UICorner" {
						Name = "UICorner",
					},
				}
			},

			scope:New "ImageLabel" {
				Name = "Corners",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://80175650219598",
				--ImageContent = Content.new(Content),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(1, 1),
				SliceCenter = Rect.new(10, 17, 561, 274),
			},

			scope:New "ImageLabel" {
				Name = "Seperation",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://109954600116552",
				--ImageContent = Content.new(Content),
				Position = UDim2.fromScale(0.0891, -0.687),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(152, 289),
			},

			scope:New "TextButton" {
				Name = "TEMP",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/Sarpanch.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.0432, 0.0719),
				Size = UDim2.fromOffset(80, 28),
				Text = "TEMP",
				TextColor3 = Color3.fromRGB(0, 0, 0),
				TextSize = 14,

				[Children] = {
					scope:New "UICorner" {
						Name = "UICorner",
					},

					scope:New "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(208, 199, 131)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 70, 67)),
						}),
						Rotation = 90,
					},
				},
				[OnEvent "Activated"] = function(_, numclicks)
						squad:set(false)
						temp:set(true)
				end,
			},

			scope:New "TextButton" {
				Name = "SQUAD",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/Sarpanch.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.535, 0.0719),
				Size = UDim2.fromOffset(80, 28),
				Text = "SQUAD",
				TextColor3 = Color3.fromRGB(0, 0, 0),
				TextSize = 14,

				[Children] = {
					scope:New "UICorner" {
						Name = "UICorner",
					},

					scope:New "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(208, 199, 131)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 70, 67)),
						}),
						Rotation = 90,
					},
				},
				[OnEvent "Activated"] = function(_, numclicks)
						temp:set(false)
						squad:set(true)
				end,
			},

			scope:New "TextButton" {
				Name = "INVITE",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/Sarpanch.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.281, 0.705),
				Size = UDim2.fromOffset(80, 28),
				Text = "INVITE",
				TextColor3 = Color3.fromRGB(0, 0, 0),
				TextSize = 14,

				[Children] = {
					scope:New "UICorner" {
						Name = "UICorner",
					},

					scope:New "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(208, 199, 131)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 70, 67)),
						}),
						Rotation = 90,
					},
				},
				[OnEvent "Activated"] = function(_, numclicks)
					if peek(user) then
						for _, v in Players:GetChildren() do
							if v.Name == peek(user) then
								---- print("valid user found proceeding")
                                invited:set(true)
								task.delay(3, function()
									invited:set(false)
								end)
								--send invite to party here, validate user
							end
						end
					elseif not peek(user) then
                        ---- print("invalid user found")
						--notification alert system here for invalid user
					end
				end,
			},

			scope:New "Frame" {
				Name = "Frame",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.0649, 0.403),
				Size = UDim2.fromOffset(160, 32),

				[Children] = {
					scope:New "UIListLayout" {
						Name = "UIListLayout",
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						HorizontalFlex = Enum.UIFlexAlignment.Fill,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						VerticalFlex = Enum.UIFlexAlignment.Fill,
					},

					scope:New "TextBox" {
						Name = "TextButton",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Size = UDim2.fromOffset(160, 32),
						Text = "USERNAME",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 14,
						TextWrapped = true,

						[Children] = {
							scope:New "ImageLabel" {
								Name = "ImageLabel",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								Image = "rbxassetid://80175650219598",
								--ImageContent = Content.new(Content),
								ScaleType = Enum.ScaleType.Slice,
								Size = UDim2.fromOffset(160, 35),
								SliceCenter = Rect.new(10, 17, 561, 274),
							},

							scope:New "ImageLabel" {
								Name = "Border",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								Image = "rbxassetid://121279258155271",
								--ImageContent = Content.new(Content),
								SelectionOrder = -3,
								Size = UDim2.fromOffset(160, 35),
							},
						},
						
						[OnChange "Text"] = function(newtext)
							---- print("changing text to " .. newtext)
							user:set(newtext)
						end,
					},
				}
			},

			scope:New "Frame" {
				Name = "TEMPH",
				Active = true,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				LayoutOrder = -1,
				Position = UDim2.fromScale(0.0432, 0.0719),
				Selectable = true,
				Size = UDim2.fromOffset(80, 28),
				ZIndex = 0,

				[Children] = {
					scope:New "UICorner" {
						Name = "UICorner",
					},

					scope:New "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(182, 182, 182)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(59, 59, 59)),
						}),
						Rotation = 45,
					},

					scope:New "UIStroke" {
						Name = "UIStroke",
						Color = scope:Tween(scope:Computed(function(use)
								return if use(invited) then Color3.fromRGB(1, 255, 86) else Color3.fromRGB(255, 255, 255)
							end),
                            TInfo
                        ),
						Thickness = 1.5,
					},
				}
			},

			scope:New "Frame" {
				Name = "SQUADH",
				Active = true,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				LayoutOrder = -1,
				Position = UDim2.fromScale(0.535, 0.072),
				Selectable = true,
				Size = UDim2.fromOffset(80, 28),
				ZIndex = 0,

				[Children] = {
					scope:New "UICorner" {
						Name = "UICorner",
					},

					scope:New "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(182, 182, 182)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(59, 59, 59)),
						}),
						Rotation = 45,
					},

					scope:New "UIStroke" {
						Name = "UIStroke",
						Color = scope:Tween(scope:Computed(function(use)
								return if use(invited) then Color3.fromRGB(1, 255, 86) else Color3.fromRGB(255, 255, 255)
							end),
                            TInfo
                        ),
						Thickness = 1.5,
					},
				}
			},

			scope:New "Frame" {
				Name = "INVITEH",
				Active = true,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				LayoutOrder = -1,
				Position = UDim2.fromScale(0.281, 0.705),
				Selectable = true,
				Size = UDim2.fromOffset(80, 28),
				ZIndex = 0,

				[Children] = {
					scope:New "UICorner" {
						Name = "UICorner",
					},

					scope:New "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(182, 182, 182)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(59, 59, 59)),
						}),
						Rotation = 45,
					},

					scope:New "UIStroke" {
						Name = "UIStroke",
						Color = scope:Tween(scope:Computed(function(use)
								return if use(invited) then Color3.fromRGB(1, 255, 86) else Color3.fromRGB(255, 255, 255)
							end),
                            TInfo
                        ),
						Thickness = 1.5,
					},
				}
			},
		}
	}
end
