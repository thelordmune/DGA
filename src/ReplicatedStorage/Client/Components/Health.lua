local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local CastingComponent = require(ReplicatedStorage.Client.Components.Casting)

local Children, scoped, peek, out, OnEvent, Value, Computed =
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.Value, Fusion.Computed

-- ULTRA-OPTIMIZED Health Bar Column Component
-- Drastically reduced reactive objects: NO per-column Computed/Observer/Spring
-- All animations driven by direct property updates in RenderStepped
local function HealthBarColumn(columnIndex: number, parentFrame: Instance)
	local frame = Instance.new("Frame")
	frame.Name = string.format("Column%d", columnIndex)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 1 -- Start hidden
	frame.BorderSizePixel = 0
	frame.LayoutOrder = columnIndex
	frame.Size = UDim2.new(0, 5, 0, 0) -- Start at 0 height
	frame.Parent = parentFrame

	-- Red glow effect (static, no reactive bindings)
	local glow = Instance.new("ImageLabel")
	glow.Name = "GaussianBlur"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundTransparency = 1
	glow.Image = "rbxassetid://90951534866312"
	glow.ImageColor3 = Color3.fromRGB(255, 0, 0)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.5, 1.5)
	glow.ImageTransparency = 1 -- Start hidden
	glow.Parent = frame

	-- Silver gradient (static color, offset updated directly)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "SilverFlash"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 100, 100)),
		ColorSequenceKeypoint.new(0.324, Color3.fromRGB(143, 143, 143)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(249, 249, 249)),
		ColorSequenceKeypoint.new(0.692, Color3.fromRGB(103, 103, 103)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 100, 100)),
	})
	gradient.Parent = glow

	return {
		frame = frame,
		glow = glow,
		gradient = gradient,
		columnIndex = columnIndex,
		-- Animation state (updated directly, no Fusion reactivity)
		targetHeight = 0,
		currentHeight = 0,
		targetTransparency = 1,
		currentTransparency = 1,
		glowTargetTransparency = 1,
		glowCurrentTransparency = 1,
	}
end

-- CONTINUATION FROM PART 1

return function(Target)
	local scope = scoped(Fusion, {})

	local started = scope:Value(false)
	local display = scope:Value(false)
	local circleRotation = scope:Value(0)
	local showCastingCircle = scope:Value(false) -- Control whether to show casting UI instead of health circle

	-- Health and Adrenaline values (0-100) - exposed for external updates
	local health = scope:Value(100)
	local adrenaline = scope:Value(0)
	local money = scope:Value(0) -- Player's money for display
	local stamina = scope:Value(100) -- Stamina for Nen abilities (0-100)
	local posture = scope:Value(0) -- Posture damage (0 = fresh, 100 = about to break)

	-- ULTRA-OPTIMIZED: Direct animation state (no Fusion reactivity for columns)
	local COLUMNS = 84
	local healthColumns = {} -- Will hold column data objects
	local gradientOffset = -1 -- Direct value, not Fusion Value
	local waveTime = 0 -- Direct value, not Fusion Value
	local isDisplayed = false -- Direct boolean for column visibility
	local currentHealth = 100
	local currentAdrenaline = 0

	-- ULTRA-OPTIMIZED: Single RenderStepped updates ALL 84 columns directly
	-- No Fusion Computed/Spring overhead - just direct property manipulation
	local LERP_SPEED = 12 -- Spring-like smoothing factor
	local rotationConnection = RunService.RenderStepped:Connect(function(dt)
		-- Update circle rotation (still uses Fusion for the main UI elements)
		circleRotation:set((peek(circleRotation) + (dt * 50)) % 360)

		-- Update gradient offset (direct value)
		gradientOffset = gradientOffset + (dt * 1.2)
		if gradientOffset > 2 then
			gradientOffset = -1
		end

		-- Update wave time (direct value)
		waveTime = waveTime + dt * 0.2

		-- Get current values from Fusion (only reads, minimal overhead)
		currentHealth = peek(health)
		currentAdrenaline = peek(adrenaline)
		isDisplayed = peek(display)

		-- Calculate how many columns should be visible based on health
		local maxColumnsVisible = math.floor((currentHealth / 100) * COLUMNS)

		-- Calculate base height from adrenaline
		local baseHeight
		if currentAdrenaline <= 33 then
			baseHeight = 0.3
		elseif currentAdrenaline <= 66 then
			baseHeight = 0.6
		else
			baseHeight = 0.9
		end

		-- BATCH UPDATE all 84 columns in single loop (no Fusion overhead)
		for i, colData in ipairs(healthColumns) do
			local columnIndex = colData.columnIndex
			local isVisible = columnIndex <= maxColumnsVisible and isDisplayed

			-- Calculate target height with wave animation
			local wave = math.sin(waveTime + columnIndex * 0.1) * 0.2
			local flutter = math.sin(columnIndex * 1.7) * 0.05
			local targetHeight = isVisible and math.clamp(baseHeight + wave + flutter, 0.1, 1) or 0

			-- Calculate target transparencies
			local targetTransparency = isDisplayed and 0.45 or 1
			local glowTargetTransparency = isVisible and 0 or 1

			-- Smooth lerp towards targets (spring-like behavior)
			colData.currentHeight = colData.currentHeight + (targetHeight - colData.currentHeight) * math.min(1, dt * LERP_SPEED)
			colData.currentTransparency = colData.currentTransparency + (targetTransparency - colData.currentTransparency) * math.min(1, dt * LERP_SPEED)
			colData.glowCurrentTransparency = colData.glowCurrentTransparency + (glowTargetTransparency - colData.glowCurrentTransparency) * math.min(1, dt * LERP_SPEED)

			-- Apply to instances (direct property set, no Fusion)
			colData.frame.Size = UDim2.new(0, 5, colData.currentHeight, 0)
			colData.frame.BackgroundTransparency = colData.currentTransparency
			colData.glow.ImageTransparency = colData.glowCurrentTransparency
			colData.gradient.Offset = Vector2.new(gradientOffset, 0)
		end
	end)

	-- Initial animation delay
	task.delay(3, function()
		started:set(true)
		task.wait(2)
		display:set(true)
	end)

	-- CONTINUATION FROM PART 2 - Main Holder Frame

	-- Key sequence display state (will be set by casting component)
	local keySequenceText = scope:Value("")
	local isCasting = scope:Value(false)

	local holderFrame = scope:New("Frame")({
		Parent = Target,
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(started) then UDim2.fromScale(0.5, 0) else UDim2.fromScale(0.5, 0)
			end),
			30,
			9
		),
		Size = scope:Spring(
			scope:Computed(function(use)
				return if use(started) then UDim2.fromOffset(612, 115) else UDim2.fromOffset(0, 115)
			end),
			30,
			2
		),
		ClipsDescendants = false, -- Allow casting UI to move outside bounds

		[Children] = {
			-- Corners decoration
			-- scope:New("ImageLabel")({
			-- 	Name = "Corners",
			-- 	BackgroundTransparency = 1,
			-- 	Image = "rbxassetid://106093959266071",
			-- 	ImageColor3 = Color3.fromRGB(0, 0, 0),
			-- 	ScaleType = Enum.ScaleType.Slice,
			-- 	Size = UDim2.fromScale(1, 1),
			-- 	SliceCenter = Rect.new(200, 300, 870, 300),
			-- 	SliceScale = 0.5,
			-- }),

			-- Rotating circle background (hidden when casting UI is shown)
			scope:New("ImageLabel")({
				Name = "Circle",
				BackgroundTransparency = 1,
				Image = "rbxassetid://102790439571584",
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(1, 1),
				TileSize = UDim2.fromScale(0.025, 1),
				Rotation = scope:Computed(function(use)
					return use(circleRotation)
				end),
				Visible = scope:Computed(function(use)
					return not use(showCastingCircle) -- Hide when casting UI is shown
				end),
				ZIndex = -3000,
				[Children] = {
					scope:New("UIGradient")({
						Rotation = 360,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.356),
							NumberSequenceKeypoint.new(0.495, 0.387),
							NumberSequenceKeypoint.new(1, 0.306),
						}),
					}),
				},
			}),

			scope:New("ImageLabel")({
				Name = "ImageLabel",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://130684158382755",
				ImageTransparency = scope:Spring(
					scope:Computed(function(use)
						return if use(display) then 0 else 1
					end),
					30,
					9
				),
				Position = UDim2.fromScale(0, -0.0696),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromOffset(612, 129),
				SliceCenter = Rect.new(44, 134, 473, 169),
				SliceScale = 0.5,
				ZIndex = -30,

				[Children] = {
					scope:New("UIGradient")({
						Name = "UIGradient",
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.0499, 0.944),
							NumberSequenceKeypoint.new(0.202, 0.119),
							NumberSequenceKeypoint.new(0.424, 0.762),
							NumberSequenceKeypoint.new(0.555, 0.756),
							NumberSequenceKeypoint.new(0.798, 0.181),
							NumberSequenceKeypoint.new(0.964, 0.944),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),
				},
			}),

			-- Health bar visualizer container
			scope:New("Frame")({
				Name = "Health",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.0759, 0.0609),
				Size = UDim2.fromOffset(517, 55),
				ClipsDescendants = true,
				[Children] = {
					scope:New("Frame")({
						Name = "Main",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.00774, 0.0364),
						Size = UDim2.fromOffset(501, 48),
						ClipsDescendants = true,
						[Children] = {
							scope:New("Folder")({
								Name = "CenterHp",
								[Children] = {
									-- Layout for horizontal bar chart
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										Padding = UDim.new(0, 1),
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Bottom, -- Bars grow upward
									}),
									-- Columns created separately after frame exists (see below)
								},
							}),
						},
					}),
				},
			}),

			-- Adrenaline label
			scope:New("Frame")({
				Name = "Adrenaline",
				BackgroundTransparency = 1,
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(display) then UDim2.fromScale(0.71, 0.696) else UDim2.fromScale(1.71, 0.696)
					end),
					30,
					3
				),
				Size = UDim2.fromOffset(100, 29),
				[Children] = {
					scope:New("ImageLabel")({
						Name = "ImageLabel",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://85574222946216",
						Position = UDim2.fromScale(-0.19, -0.103),
						ScaleType = Enum.ScaleType.Crop,
						Size = UDim2.fromScale(1.3, 1.3),
						ZIndex = -100,
						ImageTransparency = scope:Spring(
							scope:Computed(function(use)
								return if use(display) then 0 else 1
							end),
							30,
							9
						),

						[Children] = {
							-- scope:New("UICorner")({
							-- 	Name = "UICorner",
							-- }),
							scope:New("TextLabel")({
								Name = "TL",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxassetid://12187607287",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Size = UDim2.fromScale(1, 1),
								Text = scope:Computed(function(use)
									local adrLvl = use(adrenaline)
									local level = adrLvl > 66 and "High" or (adrLvl > 33 and "Medium" or "Low")
									return "Adrenaline: " .. level
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = false,
								TextStrokeTransparency = 0,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTransparency = scope:Spring(
									scope:Computed(function(use)
										return if use(display) then 0 else 1
									end),
									30,
									9
								),
								[Children] = {
									scope:New("UIGradient")({
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
											ColorSequenceKeypoint.new(0.36, Color3.fromRGB(255, 255, 255)),
											ColorSequenceKeypoint.new(0.521, Color3.fromRGB(143, 143, 143)),
											ColorSequenceKeypoint.new(0.567, Color3.fromRGB(252, 252, 252)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
										}),
										Rotation = 90,
									}),
								},
							}),
							scope:New("UIGradient")({
								Name = "UIGradient",
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 1),
									NumberSequenceKeypoint.new(0.0948, 0.0188),
									NumberSequenceKeypoint.new(1, 1),
								}),
							}),
						},
					}),
				},
			}),

			-- Posture bar (Deepwoken-style - fills up when blocking, breaks at 100%)
			scope:New("Frame")({
				Name = "Posture",
				BackgroundTransparency = 1,
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(display) then UDim2.fromScale(0.0824, 0.652) else UDim2.fromScale(0.0824, 1.652)
					end),
					17,
					2
				),
				Size = UDim2.fromOffset(372, 28),
				[Children] = {
					-- Background bar
					scope:New("Frame")({
						Name = "Background",
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						BorderColor3 = Color3.fromRGB(255, 255, 255),
						BorderSizePixel = 2,
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = scope:Spring(
							scope:Computed(function(use)
								return if use(display) then 0.3 else 1
							end),
							30,
							9
						),
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
							scope:New("UIStroke")({
								-- Stroke color changes based on posture level
								Color = scope:Computed(function(use)
									local p = use(posture)
									if p > 75 then
										return Color3.fromRGB(255, 50, 50) -- Red when near break
									elseif p > 50 then
										return Color3.fromRGB(255, 150, 50) -- Orange when medium
									else
										return Color3.fromRGB(200, 200, 200) -- Normal
									end
								end),
								Thickness = 1,
								Transparency = scope:Spring(
									scope:Computed(function(use)
										return if use(display) then 0.5 else 1
									end),
									30,
									9
								),
							}),
						},
					}),
					-- Filled posture bar (fills up as posture damage increases)
					scope:New("Frame")({
						Name = "Fill",
						-- Color gradient: Yellow -> Orange -> Red based on posture level
						BackgroundColor3 = scope:Computed(function(use)
							local p = use(posture)
							if p > 75 then
								return Color3.fromRGB(255, 50, 50) -- Red when near break
							elseif p > 50 then
								return Color3.fromRGB(255, 150, 50) -- Orange when medium
							else
								return Color3.fromRGB(255, 220, 100) -- Yellow when low
							end
						end),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.005, 0.1),
						Size = scope:Spring(
							scope:Computed(function(use)
								local posturePercent = use(posture) / 100
								return UDim2.new(posturePercent * 0.99, 0, 0.8, 0)
							end),
							25,
							8
						),
						BackgroundTransparency = scope:Spring(
							scope:Computed(function(use)
								return if use(display) then 0 else 1
							end),
							30,
							9
						),
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
							-- Gradient for shine effect
							scope:New("UIGradient")({
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
									ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 200, 200)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
								}),
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0.7),
									NumberSequenceKeypoint.new(0.5, 0.5),
									NumberSequenceKeypoint.new(1, 0.7),
								}),
								Rotation = 90,
							}),
						},
					}),
					-- Posture text label
					scope:New("TextLabel")({
						Name = "PostureText",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.8, 0.8),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Font = Enum.Font.GothamBold,
						Text = scope:Computed(function(use)
							local p = use(posture)
							if p > 75 then
								return "POSTURE: DANGER!"
							elseif p > 50 then
								return string.format("POSTURE: %.0f%%", p)
							elseif p > 0 then
								return string.format("POSTURE: %.0f%%", p)
							else
								return "POSTURE: OK"
							end
						end),
						TextColor3 = scope:Computed(function(use)
							local p = use(posture)
							if p > 75 then
								return Color3.fromRGB(255, 100, 100) -- Red text when danger
							else
								return Color3.fromRGB(255, 255, 255)
							end
						end),
						TextScaled = true,
						TextStrokeTransparency = 0.5,
						TextTransparency = scope:Spring(
							scope:Computed(function(use)
								return if use(display) then 0 else 1
							end),
							30,
							9
						),
					}),
				},
			}),

			-- CONTINUATION - Add these to the holderFrame [Children] in Part 3

			-- -- Health border
			-- scope:New("ImageLabel")({
			-- 	Name = "HealthBorder",
			-- 	BackgroundTransparency = 1,
			-- 	Image = "rbxassetid://122523747392433",
			-- 	Position = scope:Spring(
			-- 		scope:Computed(function(use)
			-- 			return if use(display) then UDim2.fromScale(0.0825, 0.05) else UDim2.fromScale(0.0825, -1.55)
			-- 		end),
			-- 		70,
			-- 		9
			-- 	),
			-- 	ScaleType = Enum.ScaleType.Slice,
			-- 	Size = UDim2.fromOffset(508, 51),
			-- 	SliceCenter = Rect.new(13, 13, 37, 33),
			-- 	SliceScale = 0.8,
			-- 	ImageTransparency = scope:Spring(
			-- 		scope:Computed(function(use)
			-- 			return if use(display) then 0 else 1
			-- 		end),
			-- 		30,
			-- 		9
			-- 	),
			-- }),

			-- -- Health overlay
			-- scope:New("Frame")({
			-- 	Name = "HealthOverlay",
			-- 	BackgroundTransparency = 1,
			-- 	Position = scope:Spring(
			-- 		scope:Computed(function(use)
			-- 			return if use(display)
			-- 				then UDim2.fromScale(0.0853, 0.0783)
			-- 				else UDim2.fromScale(0.0853, -1.0783)
			-- 		end),
			-- 		70,
			-- 		9
			-- 	),
			-- 	Size = UDim2.fromOffset(504, 51),
			-- 	[Children] = {
			-- 		scope:New("ImageLabel")({
			-- 			BackgroundTransparency = 1,
			-- 			Image = "rbxassetid://139828588507940",
			-- 			ImageTransparency = scope:Spring(
			-- 				scope:Computed(function(use)
			-- 					return if use(display) then 0.8 else 1
			-- 				end),
			-- 				30,
			-- 				9
			-- 			),
			-- 			Position = UDim2.fromScale(-0.0865, 0),
			-- 			ScaleType = Enum.ScaleType.Crop,
			-- 			Size = UDim2.fromScale(1.172, 0.895),
			-- 		}),
			-- 	},
			-- }),

			-- Background pattern
			scope:New("ImageLabel")({
				Name = "BG",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://77843373818875",
				Position = UDim2.fromScale(0.075, 0.078),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(0.83, 0.443),
				SliceCenter = Rect.new(19, 19, 1004, 108),
				SliceScale = 0.1,
				TileSize = UDim2.fromScale(0.025, 1),
				ZIndex = -29,
				ImageTransparency = scope:Spring(
					scope:Computed(function(use)
						return if use(display) then 0.3 else 1
					end),
					30,
					9
				),
			}),
			scope:New("ImageLabel")({
				Name = "Border",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://77878711116522",
				Position = UDim2.fromScale(0.0653, 0),
				Size = UDim2.fromScale(0.847, 0.591),
				SliceCenter = Rect.new(0, 0, 1023, 133),
				TileSize = UDim2.fromScale(0.025, 1),
				ImageTransparency = scope:Spring(
					scope:Computed(function(use)
						return if use(display) then 0.3 else 1
					end),
					30,
					9
				),
			}),

			scope:New("ImageLabel")({
				Name = "ImageLabel",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://71879249073635",
				Size = UDim2.fromScale(1, 1),
				ZIndex = -500000000,
				ScaleType = Enum.ScaleType.Crop,
				ImageTransparency = scope:Spring(
					scope:Computed(function(use)
						return if use(display) then 0 else 1
					end),
					30,
					9
				),
				[Children] = {
					scope:New("UIGradient")({
						Name = "UIGradient",
						Rotation = 78,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(0.0312, 1),
							NumberSequenceKeypoint.new(0.251, 0.113),
							NumberSequenceKeypoint.new(0.544, 1),
							NumberSequenceKeypoint.new(1, 0),
						}),
					}),
				},
			}),
		},
	})

	-- ULTRA-OPTIMIZED: Create all 84 columns AFTER holderFrame exists
	-- Using direct Instance creation instead of Fusion (eliminates 840+ reactive objects)
	local centerHpFolder = holderFrame:WaitForChild("Health"):WaitForChild("Main"):WaitForChild("CenterHp")
	for col = 1, COLUMNS do
		local colData = HealthBarColumn(col, centerHpFolder)
		table.insert(healthColumns, colData)
	end

	-- Create the Casting component inside the holderFrame
	local castingAPI = CastingComponent(holderFrame)

	-- Show the casting UI in idle state immediately (replaces the health circle)
	showCastingCircle:set(true) -- Hide the health circle

	-- Create key sequence display above the HUD
	local keySequenceDisplay = scope:New("TextLabel")({
		Parent = Target,
		Name = "KeySequenceDisplay",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.88), -- Above the HUD (HUD is at bottom)
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(400, 60),
		Font = Enum.Font.GothamBold,
		Text = scope:Computed(function(use)
			return castingAPI.keySequence and use(castingAPI.keySequence) or ""
		end),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 48,
		TextStrokeTransparency = 0.3,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextTransparency = scope:Spring(
			scope:Computed(function(use)
				-- Only show when casting
				local casting = castingAPI.isCasting and use(castingAPI.isCasting) or false
				return casting and 0 or 1
			end),
			25,
			1
		),
		ZIndex = 10,
	})

	-- Cleanup function to disconnect rotation connection and clean up casting component
	local cleanupRotation = function()
		if rotationConnection then
			rotationConnection:Disconnect()
			rotationConnection = nil
		end

		-- Clean up casting component scope
		if castingAPI and castingAPI.scope then
			castingAPI.scope:doCleanup()
		end
	end

	-- Add cleanup to scope
	table.insert(scope, cleanupRotation)

	-- Money display in bottom left corner of screen
	local moneyDisplay = scope:New("Frame")({
		Parent = Target,
		Name = "MoneyDisplay",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(display) then UDim2.new(0, 20, 1, -20) else UDim2.new(0, -150, 1, -20)
			end),
			30,
			3
		),
		Size = UDim2.fromOffset(150, 30),
		ZIndex = 100,

		[Children] = {
			-- Money amount (no coin icon)
			scope:New("TextLabel")({
				Name = "MoneyAmount",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				Text = scope:Computed(function(use)
					local amount = use(money)
					-- Format with commas for thousands
					local formatted = tostring(amount)
					local k = 1
					while true do
						formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", '%1,%2')
						if k == 0 then break end
					end
					return "$" .. formatted
				end),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 18,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextStrokeTransparency = 0.3,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextTransparency = scope:Spring(
					scope:Computed(function(use)
						return if use(display) then 0 else 1
					end),
					30,
					9
				),

				[Children] = {
					-- Gold gradient on text
					scope:New("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 223, 128)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0)),
						}),
						Rotation = 90,
					}),
				},
			}),
		},
	})

	-- Return the UI frame, values, and scope for external updates and cleanup
	return {
		frame = holderFrame,
		healthValue = health,
		adrenalineValue = adrenaline,
		moneyValue = money, -- Expose money value for external updates
		staminaValue = stamina, -- Expose stamina value for Nen system
		postureValue = posture, -- Expose posture value for Deepwoken-style posture system
		castingAPI = castingAPI, -- Expose casting API for external control
		scope = scope, -- Expose scope for cleanup on death

		-- Reset function for reuse on respawn (avoids recreating 840+ Fusion objects)
		reset = function()
			health:set(100)
			adrenaline:set(0)
			money:set(0)
			stamina:set(100)
			posture:set(0) -- Reset posture to 0 (no damage)
			-- Reset display state to trigger re-animation
			display:set(false)
			task.delay(0.1, function()
				display:set(true)
			end)
			-- Reset casting state if needed
			if castingAPI and castingAPI.keySequence then
				castingAPI.keySequence:set("")
			end
			if castingAPI and castingAPI.isCasting then
				castingAPI.isCasting:set(false)
			end
		end,
	}
end
