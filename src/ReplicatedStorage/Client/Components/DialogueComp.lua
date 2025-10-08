local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Players = game:GetService("Players")
local RichText = require(ReplicatedStorage.Modules.RichText)
local plr = Players.LocalPlayer

local Children, scoped, peek, out = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out

local TInfo = TweenInfo.new(0.7, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)
local TInfo2 = TweenInfo.new(1.1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

return function(scope, props: {})
	local displayText: string? = props.displayText
	local npcname: string = props.npcname
	local model: Model = props.model
	local start: boolean = props.start
	local framein: boolean = props.fade
	local responseMode: boolean = props.responseMode
	local parent = props.Parent
	local responses: { order: number, text: string, node: Configuration } = props.responses

	local text = scope:New("TextLabel")({
		Name = "Text",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
		Position = UDim2.fromScale(0.05, 0.05), -- Position inside DialogueHolder
		Size = UDim2.fromScale(0.9, 0.9), -- Fill DialogueHolder with padding
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	scope:Computed(function(use)
		local currentText = use(displayText)
		local isStarted = use(start :: boolean)
		if isStarted and currentText then
			text.Text = ""
			return RichText.AnimateText(currentText, text, 0.015, Enum.Font.SourceSans, "fade diverge", 1, 14)
		else
			return ""
		end
	end)

	return scope:New("Frame")({
		Name = "Frame",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = scope:Tween(
			scope:Computed(function(use)
				return if use(framein) then 0 else 1
			end),
			TInfo
		),
		BorderSizePixel = 0,
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(framein) then UDim2.fromScale(0.342, 0.611) else UDim2.fromScale(0.342, 1.2)
			end),
			18,
			0.4
		),
		  Size = UDim2.fromOffset(453, 236),
		Parent = parent,

		[Children] = {
			scope:New("ImageLabel")({
				Name = "Background",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://85774200010476",
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0 else 1
					end),
					TInfo
				),
				SelectionOrder = -3,
				Size = UDim2.fromOffset(453, 236),

				[Children] = {
					scope:New("UICorner")({
						Name = "UICorner",
					}),
				},
			}),

			scope:New("UICorner")({
				Name = "UICorner",
			}),

			scope:New("ImageLabel")({
				Name = "Border",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://121279258155271",
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0 else 1
					end),
					TInfo
				),
				SelectionOrder = -3,
				Size = UDim2.fromOffset(453, 236),
			}),

			scope:New("ImageLabel")({
				Name = "Corners",
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://139183149783612",
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0 else 1
					end),
					TInfo
				),
				ScaleType = Enum.ScaleType.Slice,
				SelectionOrder = -3,
				Size = UDim2.fromOffset(453, 236),
				SliceCenter = Rect.new(208, 266, 814, 276),
				SliceScale = 0.2,
				ZIndex = 2,

				[Children] = {
					scope:New("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(93, 93, 93)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
						}),
						Offset = Vector2.new(3, 3),
					}),
				},
			}),

			scope:New("ViewportFrame")({
				Name = "Model",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0.8 else 1
					end),
					TInfo
				),
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0 else 1
					end),
					TInfo
				),
				BorderColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.056, 0.102),
				Size = UDim2.fromOffset(65, 68),

				[Children] = {
					scope:New("ImageLabel")({
						Name = "ImageLabel",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://80175650219598",
						ImageTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(framein) then 0 else 1
							end),
							TInfo
						),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromOffset(65, 68),
						SliceCenter = Rect.new(10, 17, 561, 274),
					}),
				},
			}),

			scope:New("ImageLabel")({
				Name = "Seperation",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://109954600116552",
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0 else 1
					end),
					TInfo
				),
				Position = UDim2.fromScale(0.035, 0.45),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(421, 144),
			}),

			scope:New("TextLabel")({
				Name = "NPCName",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
				Position = UDim2.fromScale(0.056, 0.39), -- Below ViewportFrame (0.102 + 68/236 ≈ 0.39)
				Size = UDim2.fromOffset(65, 23), -- Same width as ViewportFrame
				Text = npcname or "NPC",
				TextTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0 else 1
					end),
					TInfo
				),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 12,
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(255, 255, 255),

				[Children] = {
					scope:New("ImageLabel")({
						Name = "ImageLabel",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://80175650219598",
						ImageTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(framein) then 0 else 1
							end),
							TInfo
						),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromOffset(65, 23),
						SliceCenter = Rect.new(10, 17, 561, 274),
					}),

					scope:New("ImageLabel")({
						Name = "Border",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://121279258155271",
						ImageTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(framein) then 0 else 1
							end),
							TInfo
						),
						SelectionOrder = -3,
						Size = UDim2.fromOffset(65, 23),
					}),
				},
			}),

			scope:New("ImageLabel")({
				Name = "Border",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://121279258155271",
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0 else 1
					end),
					TInfo
				),
				Position = UDim2.fromScale(0.231, 0.102),
				SelectionOrder = -3,
				Size = UDim2.fromOffset(320, 129),
			}),

			scope:New("ImageLabel")({
				Name = "DialogueHolder",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://80175650219598",
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0 else 1
					end),
					TInfo
				),
				Position = UDim2.fromScale(0.231, 0.102),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromOffset(320, 129),
				SliceCenter = Rect.new(10, 17, 561, 274),

				[Children] = {
					text, -- Add text as child of DialogueHolder
				},
			}),
			scope:New("Frame")({
				Name = "ResponseFrame",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(responseMode) then UDim2.fromScale(0.056, 0.75) else UDim2.fromScale(0.056, 1.2)
					end),
					18,
					0.4
				),
				Size = UDim2.fromScale(0.88, 0.15), -- Use scale to stay within bounds

				[Children] = {
					scope:New("UIListLayout")({
						Name = "UIListLayout",
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 5), -- Add spacing between buttons
					}),

					scope:ForValues(responses or {}, function(_, innerScope, response, index)
						local safeIndex = index or 1

						return innerScope:New("TextButton")({
							Name = "ResponseButton" .. tostring(safeIndex),
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							AutomaticSize = Enum.AutomaticSize.X, -- Auto-size based on content
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Size = UDim2.fromScale(0, 1), -- Height fills parent, width auto
							Text = response.text or "",
							TextWrapped = false,
							TextTransparency = innerScope:Tween(
								innerScope:Computed(function(use)
									return if use(responseMode) then 0 else 1
								end),
								TInfo
							),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							TextSize = 14,
							LayoutOrder = response.order or safeIndex,

							[Children] = {
								innerScope:New("ImageLabel")({
									Name = "ImageLabel",
									BackgroundColor3 = Color3.fromRGB(255, 255, 255),
									BackgroundTransparency = 1,
									BorderColor3 = Color3.fromRGB(0, 0, 0),
									BorderSizePixel = 0,
									Image = "rbxassetid://80175650219598",
									ImageTransparency = innerScope:Tween(
										innerScope:Computed(function(use)
											return if use(responseMode) then 0 else 1
										end),
										TInfo
									),
									ScaleType = Enum.ScaleType.Slice,
									Size = UDim2.fromScale(1, 1), -- Fill button
									SliceCenter = Rect.new(10, 17, 561, 274),
								}),

								innerScope:New("ImageLabel")({
									Name = "Border",
									BackgroundColor3 = Color3.fromRGB(255, 255, 255),
									BackgroundTransparency = 1,
									BorderColor3 = Color3.fromRGB(0, 0, 0),
									BorderSizePixel = 0,
									Image = "rbxassetid://121279258155271",
									ImageTransparency = innerScope:Tween(
										innerScope:Computed(function(use)
											return if use(responseMode) then 0 else 1
										end),
										TInfo
									),
									SelectionOrder = -3,
									Size = UDim2.fromScale(1, 1), -- Fill button
								}),
							},
						})
					end),
				},
			}),
		},
	})
end
