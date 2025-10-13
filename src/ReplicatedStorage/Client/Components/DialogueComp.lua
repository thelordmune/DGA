local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Players = game:GetService("Players")
local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)
local plr = Players.LocalPlayer

local Children, scoped, peek, out = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out

local TInfo = TweenInfo.new(0.7, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)
local TInfo2 = TweenInfo.new(1.1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)


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
		local distanceFromCenter = i - centerIndex
		local divergeAmount = 8
		local xOffset = distanceFromCenter * (divergeAmount / totalChars) * 2
		local yOffset = math.abs(distanceFromCenter) * 0.5

		if isImageLabel then
			character.ImageTransparency = 1
		else
			character.TextTransparency = 1
		end
		character.Position = originalPos - UDim2.fromOffset(xOffset, yOffset)

		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		local props = { Position = originalPos }
		props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 0

		TweenService:Create(character, tweenInfo, props):Play()
		task.wait(delayPerChar)
	end
end

local function slideUpAnimation(textFrame, delayPerChar)
	delayPerChar = delayPerChar or 0.02

	local characters = getCharacters(textFrame)
	if #characters == 0 then return end

	for i, character in characters do
		if not character.Parent then break end

		local isImageLabel = character:IsA("ImageLabel")
		local isTextLabel = character:IsA("TextLabel")
		if not isImageLabel and not isTextLabel then continue end

		local originalPos = character.Position

		if isImageLabel then
			character.ImageTransparency = 1
		else
			character.TextTransparency = 1
		end
		character.Position = originalPos + UDim2.fromOffset(0, 8)

		local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		local props = { Position = originalPos }
		props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 0

		TweenService:Create(character, tweenInfo, props):Play()
		task.wait(delayPerChar)
	end
end

local function popInAnimation(textFrame, delayPerChar)
	delayPerChar = delayPerChar or 0.02

	local characters = getCharacters(textFrame)
	if #characters == 0 then return end

	for i, character in characters do
		if not character.Parent then break end

		local isImageLabel = character:IsA("ImageLabel")
		local isTextLabel = character:IsA("TextLabel")
		if not isImageLabel and not isTextLabel then continue end

		if isImageLabel then
			character.ImageTransparency = 1
		else
			character.TextTransparency = 1
		end
		character.Size = UDim2.fromOffset(0, 0)

		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local props = {
			Size = UDim2.fromOffset(character:GetAttribute("OriginalWidth") or 10, character:GetAttribute("OriginalHeight") or 18)
		}
		props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 0

		TweenService:Create(character, tweenInfo, props):Play()
		task.wait(delayPerChar)
	end
end

local function disperseAnimation(textFrame, delayPerChar)
	delayPerChar = delayPerChar or 0.008

	local characters = getCharacters(textFrame)
	if #characters == 0 then return end

	local totalChars = #characters
	local centerIndex = totalChars / 2

	for i = #characters, 1, -1 do
		local character = characters[i]
		if not character.Parent then break end

		local isImageLabel = character:IsA("ImageLabel")
		local isTextLabel = character:IsA("TextLabel")
		if not isImageLabel and not isTextLabel then continue end

		local originalPos = character.Position

		local distanceFromCenter = i - centerIndex
		local disperseAmount = 12
		local xOffset = distanceFromCenter * (disperseAmount / totalChars) * 2
		local yOffset = math.abs(distanceFromCenter) * 0.8

		local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		local props = {
			Position = originalPos + UDim2.fromOffset(xOffset, yOffset)
		}
		props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 1

		TweenService:Create(character, tweenInfo, props):Play()
		task.wait(delayPerChar)
	end

	task.wait(0.2)
	for _, child in textFrame:GetChildren() do
		child:Destroy()
	end
end

local function animateTextIn(textFrame, delayPerChar)
	task.wait(0.05)

	fadeDivergeAnimation(textFrame, delayPerChar)
	-- slideUpAnimation(textFrame, delayPerChar)
	-- popInAnimation(textFrame, delayPerChar)
end

return function(scope, props: {})
	local displayText: string? = props.displayText
	local npcname: string = props.npcname
	local model: Model = props.model
	local start: boolean = props.start
	local framein: boolean = props.fade
	local responseMode: boolean = props.responseMode
	local parent = props.Parent
	local responses: { order: number, text: string, node: Configuration } = props.responses

	local textFrame = scope:New("Frame")({
		Name = "TextPlusContainer",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.05, 0.05),
		Size = UDim2.fromScale(0.9, 0.9),
	})

	local previousText = ""
	local isAnimating = false

	scope:Computed(function(use)
		local currentText = use(displayText)
		local isStarted = use(start :: boolean)

		if isStarted and currentText and currentText ~= "" then
			task.spawn(function()
				-- Wait for any ongoing animation to finish
				while isAnimating do
					task.wait(0.05)
				end

				isAnimating = true

				local maxWait = 0
				while not textFrame:IsDescendantOf(game) and maxWait < 100 do
					task.wait(0.01)
					maxWait = maxWait + 1
				end
				if not textFrame:IsDescendantOf(game) then
					warn("[DialogueComp] TextFrame not in DataModel, cannot render text")
					isAnimating = false
					return
				end

				-- Only disperse if there's actual previous text AND it's different from current
				if previousText ~= "" and previousText ~= currentText and #textFrame:GetChildren() > 0 then
					disperseAnimation(textFrame, 0.008)
				else
					-- Just clear if no previous text or same text
					for _, child in textFrame:GetChildren() do
						child:Destroy()
					end
				end

				previousText = currentText
				TextPlus.Create(textFrame, currentText, {
					Font = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
					Size = 18,
					Color = Color3.fromRGB(255, 255, 255),
					Transparency = 1,
					XAlignment = "Left",
					YAlignment = "Top",
				})

				animateTextIn(textFrame, 0.015)
				isAnimating = false
			end)
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
				Position = UDim2.fromScale(0.056, 0.39),
				Size = UDim2.fromOffset(65, 23),
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
					textFrame,
				},
			}),
			scope:New("Frame")({
				Name = "ResponseFrame",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				-- Position at bottom of dialogue frame, inside it
				AnchorPoint = Vector2.new(0, 1), -- Anchor to bottom-left
				Position = UDim2.fromScale(0.05, 0.95), -- 5% from left, 95% from top (near bottom)
				Size = UDim2.fromScale(0.9, 0), -- 90% width, height auto-sizes
				AutomaticSize = Enum.AutomaticSize.Y, -- Auto-size vertically
				ClipsDescendants = false, -- Allow buttons to be visible
				Visible = scope:Computed(function(use)
					return use(responseMode) -- Only visible when in response mode
				end),

				[Children] = {
					scope:New("UIListLayout")({
						Name = "UIListLayout",
						FillDirection = Enum.FillDirection.Horizontal, -- Side by side
						HorizontalAlignment = Enum.HorizontalAlignment.Right, -- Align to right
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Bottom, -- Align to bottom
						Padding = UDim.new(0, 10), -- 10 pixels spacing between buttons
					}),

					scope:ForValues(responses or {}, function(_, innerScope, response, index)
						local safeIndex = index or 1

						-- Calculate button width based on number of responses
						local responseCount = 0
						for _ in pairs(responses or {}) do
							responseCount = responseCount + 1
						end

						-- Divide available width by number of responses, accounting for padding
						local buttonWidthScale = 1 / responseCount
						local paddingOffset = 10 * (responseCount - 1) / responseCount -- Account for padding

						return innerScope:New("TextButton")({
							Name = "ResponseButton" .. tostring(safeIndex),
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							-- Size based on number of responses
							Size = UDim2.new(buttonWidthScale, -paddingOffset, 0, 30),
							Text = response.text or "",
							TextWrapped = true, -- Allow wrapping for long text
							TextXAlignment = Enum.TextXAlignment.Center,
							TextTransparency = innerScope:Tween(
								innerScope:Computed(function(use)
									return if use(responseMode) then 0 else 1
								end),
								TInfo
							),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							TextSize = 14,
							TextScaled = true, -- Scale text to fit
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
									Size = UDim2.fromScale(1, 1),
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
									Size = UDim2.fromScale(1, 1),
								}),
							},
						})
					end),
				},
			}),
		},
	})
end
