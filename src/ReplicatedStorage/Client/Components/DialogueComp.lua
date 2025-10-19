local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Players = game:GetService("Players")
local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)
local plr = Players.LocalPlayer

local Children, scoped, peek, out, ForValues = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.ForValues

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

		-- Alternate between top and bottom: odd indices from top, even from bottom
		local verticalOffset = (i % 2 == 1) and -15 or 15
		local yOffset = verticalOffset

		if isImageLabel then
			character.ImageTransparency = 1
		else
			character.TextTransparency = 1
		end
		character.Position = originalPos - UDim2.fromOffset(xOffset, -yOffset)

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

	-- Create a local state to control when responses should show (after text animation)
	local showResponses = scope:Value(false)

	-- When responseMode becomes true, check if we should show responses
	scope:Computed(function(use)
		local respMode = use(responseMode)
		if respMode then
			-- If response mode is activated, show responses after a short delay
			-- (to allow any ongoing text animation to complete)
			task.spawn(function()
				task.wait(0.5) -- Wait for any ongoing animation
				if peek(responseMode) then -- Double-check it's still in response mode
					print("[DialogueComp] Response mode activated, showing responses")
					showResponses:set(true)
				end
			end)
		else
			showResponses:set(false)
		end
	end)

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

				-- Reset showResponses when new text starts
				showResponses:set(false)

				-- Animate text in
				animateTextIn(textFrame, 0.015)

				-- After animation completes, show responses
				task.spawn(function()
					-- Calculate animation duration (chars * delay + buffer)
					local charCount = #currentText
					local animDuration = charCount * 0.015 + 0.5
					task.wait(animDuration)
					showResponses:set(true)
				end)

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
				return if use(framein) then 1 else 0
			end),
			TInfo
		),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), -- Center the frame around its position
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(framein) then UDim2.fromScale(0.5, 0.611) else UDim2.fromScale(0.5, 1.2)
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
						return if use(framein) then 0.2 else 1
					end),
					TInfo
				),
				BackgroundTransparency = 1,
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

			-- scope:New("ImageLabel")({
			-- 	Name = "Border",
			-- 	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			-- 	BackgroundTransparency = 1,
			-- 	BorderColor3 = Color3.fromRGB(0, 0, 0),
			-- 	BorderSizePixel = 0,
			-- 	Image = "rbxassetid://121279258155271",
			-- 	ImageTransparency = scope:Tween(
			-- 		scope:Computed(function(use)
			-- 			return if use(framein) then 0 else 1
			-- 		end),
			-- 		TInfo
			-- 	),
			-- 	SelectionOrder = -3,
			-- 	Size = UDim2.fromOffset(453, 236),
			-- }),

			scope:New("ImageLabel")({
				Name = "Corners",
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://137499405297167",
				ImageColor3 = Color3.fromRGB(129, 152, 255),
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0 else 1
					end),
					TInfo
				),
				ScaleType = Enum.ScaleType.Slice,
				SelectionOrder = -3,
				Size = UDim2.fromOffset(453, 236),
				SliceCenter = Rect.new(20, 20, 50, 50),
				SliceScale = 1,
				ZIndex = 2,

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
				TextScaled = false,
				TextStrokeColor3 = Color3.fromRGB(255, 255, 255),

				[Children] = {
					scope:New("ImageLabel")({
						Name = "ImageLabel",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://89598685430053",
						ImageTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(framein) then 0 else 1
							end),
							TInfo
						),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromOffset(65, 23),
						SliceCenter = Rect.new(9, 9, 21, 21),
					}),

					-- scope:New("ImageLabel")({
					-- 	Name = "Border",
					-- 	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					-- 	BackgroundTransparency = 1,
					-- 	BorderColor3 = Color3.fromRGB(0, 0, 0),
					-- 	BorderSizePixel = 0,
					-- 	Image = "rbxassetid://121279258155271",
					-- 	ImageTransparency = scope:Tween(
					-- 		scope:Computed(function(use)
					-- 			return if use(framein) then 0 else 1
					-- 		end),
					-- 		TInfo
					-- 	),
					-- 	SelectionOrder = -3,
					-- 	Size = UDim2.fromOffset(65, 23),
					-- }),
				},
			}),

			scope:New("ImageLabel")({
				Name = "Border",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://121635285699370",
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0 else 1
					end),
					TInfo
				),
				Position = UDim2.fromScale(0.231, 0.102),
				SelectionOrder = -3,
				Size = UDim2.fromOffset(320, 129),
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(13, 13, 37, 33),
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
					-- Only visible when in response mode AND text animation is complete
					local respModeValue = use(responseMode)
					local showRespValue = use(showResponses)
					local responsesValue = use(responses)

					print("[DialogueComp] ResponseFrame visibility check:")
					print("  responseMode:", respModeValue)
					print("  showResponses:", showRespValue)
					print("  responses count:", responsesValue and #responsesValue or 0)

					return respModeValue and showRespValue
				end),

				[Children] = {
					scope:New("UIListLayout")({
						Name = "UIListLayout",
						FillDirection = Enum.FillDirection.Horizontal, -- Side by side
						HorizontalAlignment = Enum.HorizontalAlignment.Right, -- Align to right
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Bottom, -- Align to bottom
						Padding = UDim.new(0, 2), -- 5 pixels spacing between buttons
					}),

					scope:ForValues(responses, function(use, innerScope, response)
						-- Get the index from the response order
						local safeIndex = response.order or 1

						print("[DialogueComp] Creating response button:", safeIndex, response.text)

						-- Use Computed to dynamically calculate size based on actual response count
						local buttonSize = innerScope:Computed(function(use)
							-- Get the actual responses table
							local responsesTable = use(responses)
							local responseCount = 0

							-- Count the actual responses in the table
							if responsesTable then
								for _ in pairs(responsesTable) do
									responseCount = responseCount + 1
								end
							end

							print("[DialogueComp] Total response count:", responseCount)

							-- Each button gets equal share of width
							-- UIListLayout handles padding automatically, so we just divide by count
							local widthScale = 1 / math.max(responseCount, 1)
							return UDim2.new(widthScale, 0, 0, 30)
						end)

						-- Animation state for this button
						local buttonScale = innerScope:Value(0)
						local buttonTransparency = innerScope:Value(1)

						-- Animate button in when it becomes visible
						innerScope:Computed(function(use)
							local shouldShow = use(showResponses) and use(responseMode)
							if shouldShow then
								task.spawn(function()
									-- Stagger animation based on button index
									task.wait((safeIndex - 1) * 0.1)

									-- Spring animation for scale (bouncy effect)
									local targetScale = 1
									local currentScale = peek(buttonScale)
									local steps = 15
									for i = 1, steps do
										local t = i / steps
										local eased = 1 - math.pow(1 - t, 3) -- Cubic ease out
										local overshoot = math.sin(t * math.pi) * 0.1 -- Small bounce
										buttonScale:set(currentScale + (targetScale - currentScale) * eased + overshoot)
										task.wait(0.02)
									end
									buttonScale:set(1)

									-- Fade in transparency
									for i = 1, 10 do
										buttonTransparency:set(1 - (i / 10))
										task.wait(0.02)
									end
									buttonTransparency:set(0)
								end)
							else
								buttonScale:set(0)
								buttonTransparency:set(1)
							end
						end)

						local button = innerScope:New("TextButton")({
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
							-- Size: equal width distribution (UIListLayout handles padding)
							Size = buttonSize,
							Text = response.text or "",
							TextWrapped = true, -- Allow wrapping for long text
							TextXAlignment = Enum.TextXAlignment.Center,
							TextYAlignment = Enum.TextYAlignment.Center,
							TextTransparency = innerScope:Computed(function(use)
								return use(buttonTransparency)
							end),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							TextSize = 14,
							TextScaled = false, -- Scale text to fit
							LayoutOrder = response.order or safeIndex,

							[Children] = {
								innerScope:New("UIScale")({
									Name = "ButtonScale",
									Scale = innerScope:Computed(function(use)
										return use(buttonScale)
									end),
								}),

								innerScope:New("ImageLabel")({
									Name = "ImageLabel",
									BackgroundColor3 = Color3.fromRGB(255, 255, 255),
									BackgroundTransparency = 1,
									BorderColor3 = Color3.fromRGB(0, 0, 0),
									BorderSizePixel = 0,
									Image = "rbxassetid://117654171793420",
									ImageTransparency = innerScope:Computed(function(use)
										return use(buttonTransparency)
									end),
									ScaleType = Enum.ScaleType.Slice,
									Size = UDim2.fromScale(1, 1),
									SliceCenter = Rect.new(13, 13, 37, 33),
								}),

								-- innerScope:New("ImageLabel")({
								-- 	Name = "Border",
								-- 	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								-- 	BackgroundTransparency = 1,
								-- 	BorderColor3 = Color3.fromRGB(0, 0, 0),
								-- 	BorderSizePixel = 0,
								-- 	Image = "rbxassetid://121279258155271",
								-- 	ImageTransparency = innerScope:Computed(function(use)
								-- 		return use(buttonTransparency)
								-- 	end),
								-- 	SelectionOrder = -3,
								-- 	Size = UDim2.fromScale(1, 1),
								-- }),
							},
						})

						-- Add click handler
						task.spawn(function()
							button.Activated:Connect(function()
								print("[DialogueComp] Response button clicked:", response.text)

								-- Fade out all buttons before progressing
								task.spawn(function()
									-- Fade out this button and all others
									for i = 1, 10 do
										buttonTransparency:set(i / 10)
										buttonScale:set(1 - (i / 20)) -- Shrink slightly
										task.wait(0.02)
									end
								end)

								-- Get the Dialogue module to handle the click
								local Dialogue = require(ReplicatedStorage.Client.Dialogue)

								-- Call the node's output
								if response.node then
									-- The response.node should have the necessary data
									-- We need to trigger the dialogue progression
									Dialogue.HandleResponseClick(response.node)
								end
							end)
						end)

						return button
					end),
				},
			}),
		},
	})
end
