local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local CastingComponent = require(ReplicatedStorage.Client.Components.Casting)

local Children, scoped, peek, out, OnEvent, Value, Computed =
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.Value, Fusion.Computed

-- Health Bar Column Component (like audio visualizer bar)
-- Each column grows vertically like a bar chart
local function HealthBarColumn(scope, props)
	local columnIndex = props.columnIndex or 1
	local display = props.display
	local delayTime = props.delayTime or 0
	local health = props.health
	local adrenaline = props.adrenaline

	local localDisplay = scope:Value(false)

	-- Delayed fade in from right to left
	task.delay(delayTime, function()
		if peek(display) then
			localDisplay:set(true)
		end
	end)

	-- Listen for parent display changes
	scope:Observer(display):onChange(function()
		if peek(display) then
			task.delay(delayTime, function()
				localDisplay:set(true)
			end)
		else
			localDisplay:set(false)
		end
	end)

	-- Calculate if this column should be visible based on health
	-- Health controls how many columns from left are filled
	local isHealthVisible = scope:Computed(function(use)
		local currentHealth = use(health)
		local maxColumnsVisible = math.floor((currentHealth / 100) * 84)
		return columnIndex <= maxColumnsVisible
	end)

	-- Calculate bar height based on adrenaline (creates fluctuating wave effect)
	local barHeight = scope:Computed(function(use)
		local adrenalineLevel = use(adrenaline)
		local isVisible = use(isHealthVisible)

		if not isVisible then
			return 0 -- Column is hidden if past health threshold
		end

		-- Base height depending on adrenaline level
		local baseHeight
		if adrenalineLevel <= 33 then
			baseHeight = 0.3 -- Low: bars stay low (30% max height)
		elseif adrenalineLevel <= 66 then
			baseHeight = 0.6 -- Medium: bars reach middle (60% max height)
		else
			baseHeight = 0.9 -- High: bars reach high (90% max height)
		end

		-- Add wave effect across columns for smooth animation
		local time = tick() * .2 -- Speed of wave animation
		local wave = math.sin(time + columnIndex * 0.1) * 0.2 -- Wave variation per column

		-- Random flutter for more natural/organic look
		local flutter = (math.random() - 0.5) * 0.1

		return math.clamp(baseHeight + wave + flutter, 0.1, 1)
	end)

	return scope:New "Frame" {
		Name = string.format("Column%d", columnIndex),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = scope:Spring(
			scope:Computed(function(use)
				return if use(localDisplay) then 0.45 else 1 
			end),
			30,
			9
		),
		BorderSizePixel = 0,
		LayoutOrder = columnIndex,
		-- Size changes based on bar height (vertical growth)
		Size = scope:Spring(
			scope:Computed(function(use)
				local height = use(barHeight)
				local shouldDisplay = use(localDisplay)
				if shouldDisplay then
					return UDim2.new(0, 5, height, 0) -- Width: 5px, Height: 0-100%
				else
					return UDim2.new(0, 5, 0, 0)
				end
			end),
			60,
			3
		),

		[Children] = {
			-- Red glow effect on each bar
			scope:New "ImageLabel" {
				Name = "GaussianBlur",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://90951534866312",
				ImageColor3 = Color3.fromRGB(255, 0, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1.5, 1.5),
				ImageTransparency = scope:Spring(
					scope:Computed(function(use)
						local shouldDisplay = use(localDisplay)
						local isVisible = use(isHealthVisible)
						return if (shouldDisplay and isVisible) then 0 else 1
					end),
					30,
					9
				),
			},
		}
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

	-- Rotate circle background every frame
	local rotationConnection = RunService.RenderStepped:Connect(function(dt)
		circleRotation:set((peek(circleRotation) + (dt * 50)) % 360)
	end)

	-- Initial animation delay
	task.delay(3, function()
		started:set(true)
		task.wait(2)
		display:set(true)
	end)

	-- Generate all 84 columns (visualizer bars)
	local healthColumns = {}
	local COLUMNS = 84

	for col = 1, COLUMNS do
		-- Calculate delay: fade from right to left
		local columnDelay = (COLUMNS - col) * 0.002

		table.insert(healthColumns, HealthBarColumn(scope, {
			columnIndex = col,
			display = display,
			delayTime = columnDelay,
			health = health,
			adrenaline = adrenaline
		}))
	end

	-- CONTINUATION FROM PART 2 - Main Holder Frame

	local holderFrame = scope:New "Frame" {
		Parent = Target,
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(started) then UDim2.fromScale(0.5, 0) else UDim2.fromScale(0.5, 0)
			end), 30, 9
		),
		Size = scope:Spring(
			scope:Computed(function(use)
				return if use(started) then UDim2.fromOffset(612, 115) else UDim2.fromOffset(0, 115)
			end), 30, 2
		),
		ClipsDescendants = false, -- Allow casting UI to move outside bounds

		[Children] = {
			-- Corners decoration
			scope:New "ImageLabel" {
				Name = "Corners",
				BackgroundTransparency = 1,
				Image = "rbxassetid://106093959266071",
				ImageColor3 = Color3.fromRGB(0, 0, 0),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(1, 1),
				SliceCenter = Rect.new(200, 300, 870, 300),
				SliceScale = 0.5,
			},

			-- Rotating circle background (hidden when casting UI is shown)
			scope:New "ImageLabel" {
				Name = "Circle",
				BackgroundTransparency = 1,
				Image = "rbxassetid://102790439571584",
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(1, 1),
				TileSize = UDim2.fromScale(0.025, 1),
				Rotation = scope:Computed(function(use) return use(circleRotation) end),
				Visible = scope:Computed(function(use)
					return not use(showCastingCircle) -- Hide when casting UI is shown
				end),
				[Children] = {
					scope:New "UIGradient" {
						Rotation = 360,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.356),
							NumberSequenceKeypoint.new(0.495, 0.387),
							NumberSequenceKeypoint.new(1, 0.306),
						}),
					},
				}
			},

			-- Health bar visualizer container
			scope:New "Frame" {
				Name = "Health",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.0769, 0.0609),
				Size = UDim2.fromOffset(539, 55),
				ClipsDescendants = true,
				[Children] = {
					scope:New "Frame" {
						Name = "Main",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.008, -0.05),
						Size = UDim2.fromOffset(508, 51),
						ClipsDescendants = true,
						[Children] = {
							scope:New "Folder" {
								Name = "CenterHp",
								[Children] = {
									-- Layout for horizontal bar chart
									scope:New "UIListLayout" {
										FillDirection = Enum.FillDirection.Horizontal,
										Padding = UDim.new(0, 1),
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Bottom, -- Bars grow upward
									},
									-- All 84 columns inserted here
									table.unpack(healthColumns)
								}
							},
						}
					},
				}
			},

			-- Separator line
			scope:New "Frame" {
				Name = "Seperater",
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = scope:Spring(
					scope:Computed(function(use) return if use(display) then 0.3 else 1 end), 30, 9
				),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.0627, 0.591),
				Size = UDim2.fromOffset(534, 2),
				[Children] = {
					scope:New "UIGradient" {
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(0.192, 0.894),
							NumberSequenceKeypoint.new(0.499, 0),
							NumberSequenceKeypoint.new(0.797, 0.875),
							NumberSequenceKeypoint.new(1, 0),
						}),
					},
				}
			},

			-- Adrenaline label
			scope:New "Frame" {
				Name = "Adrenaline",
				BackgroundTransparency = 1,
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(display) then UDim2.fromScale(0.739, 0.696) else UDim2.fromScale(1.739, 0.696)
					end), 30, 3
				),
				Size = UDim2.fromOffset(100, 29),
				[Children] = {
					scope:New "TextLabel" {
						Name = "TL",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxassetid://12187607287", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Size = UDim2.fromScale(1, 1),
						Text = scope:Computed(function(use)
							local adrLvl = use(adrenaline)
							local level = adrLvl > 66 and "High" or (adrLvl > 33 and "Medium" or "Low")
							return "Adrenaline: " .. level
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0,
						TextTransparency = scope:Spring(
							scope:Computed(function(use) return if use(display) then 0 else 1 end), 30, 9
						),
					},
				}
			},

			-- Alignment meter
			scope:New "Frame" {
				Name = "Alignment",
				BackgroundTransparency = 1,
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(display) then UDim2.fromScale(0.0824, 0.652) else UDim2.fromScale(0.0824, 1.652)
					end), 17, 2
				),
				Size = UDim2.fromOffset(372, 34),
				[Children] = {
					scope:New "ImageLabel" {
						BackgroundTransparency = 1,
						Image = "rbxassetid://139828588507940",
						Position = UDim2.fromScale(0.00806, 0.147),
						ScaleType = Enum.ScaleType.Crop,
						Size = UDim2.fromScale(0.968, 0.676),
						ImageTransparency = scope:Spring(
							scope:Computed(function(use) return if use(display) then 0 else 1 end), 30, 9
						),
						[Children] = {
							scope:New "ImageLabel" {
								BackgroundTransparency = 1,
								Image = "rbxassetid://85168217168177",
								Position = UDim2.fromScale(0.0724, 0),
								ScaleType = Enum.ScaleType.Slice,
								Size = UDim2.fromScale(0.862, 1),
								SliceCenter = Rect.new(8, 8, 22, 22),
								ImageTransparency = scope:Spring(
									scope:Computed(function(use) return if use(display) then 0 else 1 end), 30, 9
								),
							},
							scope:New "UICorner" { CornerRadius = UDim.new(0, 6) },
							scope:New "UIGradient" { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)) },
						}
					},
					scope:New "Frame" {
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, -0.113),
						Size = UDim2.fromOffset(3, 40),
						BackgroundTransparency = scope:Spring(
							scope:Computed(function(use) return if use(display) then 0 else 1 end), 30, 9
						),
						[Children] = {
							scope:New "UIGradient" {
								Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
								Rotation = 90,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 1),
									NumberSequenceKeypoint.new(0.486, 0),
									NumberSequenceKeypoint.new(1, 1),
								}),
							},
						}
					},
				}
			},

			-- CONTINUATION - Add these to the holderFrame [Children] in Part 3

			-- Decorative lines folder
			scope:New "Folder" {
				Name = "Lines",
				[Children] = {
					scope:New "Frame" {
						Name = "LB",
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = scope:Spring(
							scope:Computed(function(use) return if use(display) then 0.3 else 1 end), 30, 9
						),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.062, 0.61),
						Size = UDim2.fromOffset(2, 20),
						[Children] = {
							scope:New "UIGradient" {
								Rotation = 90,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.429, 0.556),
									NumberSequenceKeypoint.new(1, 1),
								}),
							},
						}
					},
					scope:New "Frame" {
						Name = "Rb",
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = scope:Spring(
							scope:Computed(function(use) return if use(display) then 0.3 else 1 end), 30, 9
						),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.932, 0.42),
						Size = UDim2.fromOffset(2, 20),
						[Children] = {
							scope:New "UIGradient" {
								Rotation = 90,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 1),
									NumberSequenceKeypoint.new(0.445, 0.731),
									NumberSequenceKeypoint.new(1, 0),
								}),
							},
						}
					},
					scope:New "Frame" {
						Name = "ARB",
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = scope:Spring(
							scope:Computed(function(use) return if use(display) then 0.3 else 1 end), 30, 9
						),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.705, 0.61),
						Size = UDim2.fromOffset(2, 20),
						[Children] = {
							scope:New "UIGradient" {
								Rotation = 90,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 1),
									NumberSequenceKeypoint.new(1, 0),
								}),
							},
						}
					},
				}
			},

			-- Health border
			scope:New "ImageLabel" {
				Name = "HealthBorder",
				BackgroundTransparency = 1,
				Image = "rbxassetid://122523747392433",
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(display) then UDim2.fromScale(0.0825, 0.05) else UDim2.fromScale(0.0825, -1.55)
					end), 70, 9
				),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromOffset(508, 51),
				SliceCenter = Rect.new(13, 13, 37, 33),
				SliceScale = 0.8,
				ImageTransparency = scope:Spring(
					scope:Computed(function(use) return if use(display) then 0 else 1 end), 30, 9
				),
			},

			-- Health overlay
			scope:New "Frame" {
				Name = "HealthOverlay",
				BackgroundTransparency = 1,
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(display) then UDim2.fromScale(0.0853, 0.0783) else UDim2.fromScale(0.0853, -1.0783)
					end), 70, 9
				),
				Size = UDim2.fromOffset(504, 51),
				[Children] = {
					scope:New "ImageLabel" {
						BackgroundTransparency = 1,
						Image = "rbxassetid://139828588507940",
						ImageTransparency = scope:Spring(
							scope:Computed(function(use) return if use(display) then 0.8 else 1 end), 30, 9
						),
						Position = UDim2.fromScale(-0.0865, 0),
						ScaleType = Enum.ScaleType.Crop,
						Size = UDim2.fromScale(1.172, .895),
					},
				}
			},

			-- Background pattern
			scope:New "ImageLabel" {
				Name = "BG",
				BackgroundTransparency = 1,
				Image = "rbxassetid://72101690551510",
				ImageColor3 = Color3.fromRGB(0, 0, 0),
				ImageTransparency = scope:Spring(
					scope:Computed(function(use) return if use(display) then 0.8 else 1 end), 30, 9
				),
				Size = UDim2.fromScale(1, 1),
				TileSize = UDim2.fromScale(0.025, 1),
				[Children] = {
					scope:New "UIGradient" {
						Rotation = 360,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.356),
							NumberSequenceKeypoint.new(0.495, 0.387),
							NumberSequenceKeypoint.new(1, 0.306),
						}),
					},
				}
			},
		}
	}

	-- Create the Casting component inside the holderFrame
	local castingAPI = CastingComponent(holderFrame)

	-- Show the casting UI in idle state immediately (replaces the health circle)
	showCastingCircle:set(true) -- Hide the health circle

	-- Cleanup
	--scope:doCleanup(function()
	--	rotationConnection:Disconnect()
	--end)

	-- Return the UI frame and values for external updates
	return {
		frame = holderFrame,
		healthValue = health,
		adrenalineValue = adrenaline,
		castingAPI = castingAPI, -- Expose casting API for external control
	}
end