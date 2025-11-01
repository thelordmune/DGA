local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"
local TweenService = game:GetService "TweenService"

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)

local Children = Fusion.Children

local MARKER_TYPES = {
	waypoint = {
		color = Color3.fromRGB(255, 215, 94),
		icon = "rbxassetid://18621831828", -- Location pin icon
		name = "Waypoint",
	},
	objective = {
		color = Color3.fromRGB(121, 197, 255),
		icon = "rbxassetid://18621831828", -- Star icon
		name = "Objective",
	},
		mission = {
		color = Color3.fromRGB(210, 235, 231),
		icon = "rbxassetid://18621831828", -- Star icon
		name = "Mission",
	},
	quest = {
		color = Color3.fromRGB(143, 255, 143),
		icon = "rbxassetid://18621831828", -- Checkmark icon
		name = "Quest",
	},
}

local function formatDistance(distance)
	if distance < 10 then
		return string.format("%.1f m", distance)
	elseif distance < 1000 then
		return string.format("%d m", math.floor(distance))
	else
		return string.format("%.1f km", distance / 1000)
	end
end

local function Marker(scope, props)
	local markerType = MARKER_TYPES[props.Type] or MARKER_TYPES.waypoint
	local markerColor = props.Color or markerType.color
	local markerIcon = props.Icon or markerType.icon
	local label = props.Label or markerType.name

	-- Animation states
	local pulse = scope:Value(1)
	local gridRotation = scope:Value(45)
	local vignetteSize = scope:Value(UDim2.fromScale(1, 1))
	local turn = scope:Value(0)
	local peek = scope.peek

	-- Calculate arrow position based on rotation (orbits around the icon)
	local arrowPosition = scope:Computed(function(use)
		local rotation = use(props.ArrowRotation) or 0
		local angle = math.rad(rotation)
		local radius = 30 -- Distance from icon center in pixels


		local x = math.sin(angle) * radius
		local y = -math.cos(angle) * radius

		return UDim2.fromOffset(40 + x, 25 + y) -- 40, 25 is center of icon
	end)

	-- Create continuous rotation animation for grid
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			local r = peek(gridRotation) + (1.2 * (dt * 60))
			if r > 390 then
				r = 0
			end
			gridRotation:set(r)
		end)
	)

	-- Create pulsing animation for glow and vignette
	table.insert(
		scope,
		task.spawn(function()
			while task.wait(0.25) do
				turn:set(peek(turn) + 1)
				pulse:set(peek(turn) % 2 == 0 and 1.1 or 1)
				vignetteSize:set(peek(turn) % 2 == 0 and UDim2.fromScale(1.5, 1.5) or UDim2.fromScale(1.1, 1.1))
			end
		end)
	)

	-- Smooth transparency based on visibility
	local transparencyTween = scope:Spring(
		scope:Computed(function(use)
			return use(props.Visible) and 0 or 1
		end),
		25,
		0.5
	)

	-- Calculate scale based on distance
	local distanceScale = scope:Computed(function(use)
		local distance = use(props.Distance)
		if distance then
			local scale
			if distance <= 200 then
				scale = 0.5 + (distance - 50) / (200 - 50) * 0.5
			else
				local excessDistance = distance - 200
				scale = 1.0 + math.min(excessDistance / 300, 0.5)
			end
			return math.clamp(scale, 0.85, 1.2)
		end
		return 1
	end)

	print(`[MarkerIcon] 🎨 Creating marker frame: Label={label}, Icon={markerIcon}, Color={markerColor}`)

	return scope:New "Frame" {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = scope:Spring(
			props.Position or UDim2.fromScale(0.5, 0.5),
			scope:Computed(function(use)
				return use(props.ShowArrow) and 25 or 125125
			end)
		),
		Size = UDim2.fromOffset(80, 100),
		Parent = props.Parent,

		[Children] = {
			-- Arrow indicator for off-screen markers
			scope:New "UIScale" {
				Scale = 	scope:Spring(scope:Computed(function(use)
					return use(props.ShowArrow) and 1 or use(distanceScale)
				end),15),
			},
			scope:New "Frame" {
				Name = "ArrowFrame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = arrowPosition, -- Orbits around the marker
				Size = UDim2.fromOffset(21, 21),
				Rotation = scope:Computed(function(use)
					return use(props.ArrowRotation) or 0
				end),
				Visible = scope:Computed(function(use)
					return use(props.ShowArrow) or false
				end),
				ZIndex = 5,

				[Children] = {
					-- Arrow pointing to off-screen marker
					scope:New "ImageLabel" {
						Name = "Arrow",
						Image = "rbxassetid://99034290227012", -- Arrow icon
						ImageColor3 = markerColor,
						ImageTransparency = transparencyTween,
						AnchorPoint = Vector2.new(0.5, 0.5),
						ResampleMode = Enum.ResamplerMode.Pixelated,
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
						ZIndex = 5,
					},
				},
			},
			-- Container for marker icon and effects
			scope:New "Frame" {
				Name = "IconContainer",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromOffset(50, 50),

				[Children] = {
					-- Glow effect behind icon
					scope:New "ImageLabel" {
						Name = "Glow",
						Image = "rbxassetid://14609205558",
						ImageColor3 = markerColor,
						ImageTransparency = scope:Computed(function(use)
							return 0.7 + (use(transparencyTween) * 0.7)
						end),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = scope:Spring(
							scope:Computed(function(use)
								return UDim2.fromScale(1.3 * use(pulse), 1.3 * use(pulse))
							end),
							30,
							0.6
						),
						ZIndex = 1,
					},

					-- Vignette background (pulsing)
					scope:New "ImageLabel" {
						Name = "Vignette",
						Image = "rbxassetid://18959024745",
						ImageColor3 = Color3.fromRGB(122, 113, 91),
						ImageTransparency = scope:Computed(function(use)
							return 0.6 + (use(transparencyTween) * 0.4)
						end),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = scope:Spring(vignetteSize),
						ResampleMode = Enum.ResamplerMode.Pixelated,
						ZIndex = 0,
					},

					-- Rotating grid background
					scope:New "ImageLabel" {
						Name = "GridRotate",
						Image = "rbxassetid://80989206568872",
						ImageColor3 = markerColor,
						ImageTransparency = transparencyTween,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
						Rotation = scope:Spring(gridRotation, 25, 0.45),
						ResampleMode = Enum.ResamplerMode.Pixelated,
						ZIndex = 1,
					},

					-- Main icon
					scope:New "ImageLabel" {
						Name = "Icon",
						Image = "rbxassetid://83499550882277",
						ImageColor3 = markerColor,
						ImageTransparency = transparencyTween,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						ResampleMode = Enum.ResamplerMode.Default,

						Size = UDim2.fromScale(0.6, 0.6),
						ZIndex = 3,
					},
				},
			},

			-- Label and distance text container
			scope:New "Frame" {
				Name = "TextContainer",
				AnchorPoint = Vector2.new(0.5, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0, 0),
				ZIndex = 3,

				[Children] = {

					scope:New "UIListLayout" {
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 1),
					},


					-- Label text (using TextPlus)
				(function()
					local labelFrame = scope:New "Frame" {
						Name = "Label",
						Size = UDim2.fromOffset(200, 20), -- Fixed size to prevent wrapping
						BackgroundTransparency = 1,
						LayoutOrder = 1,
					}

					-- Create text with TextPlus
					TextPlus.Create(labelFrame, label, {
						Font = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
						Size = 14,
						Color = Color3.fromRGB(255, 255, 255),
						Transparency = 1, -- Start invisible for animation
						StrokeSize = 1,
						StrokeColor = Color3.fromRGB(0, 0, 0),
						StrokeTransparency = 0,
						XAlignment = "Center",
						YAlignment = "Center",
					})

					-- Get all character instances for animation
					local function getCharacters(frame)
						local chars = {}
						for _, child in frame:GetChildren() do
							if child:IsA("TextLabel") or child:IsA("ImageLabel") then
								table.insert(chars, child)
							end
						end
						return chars
					end

					-- Fade diverge animation with rainbow effect (same as DialogueComp + rainbow)
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
							local divergeAmount = 2
							local xOffset = distanceFromCenter * (divergeAmount / totalChars) * 2

							-- Alternate between top and bottom
							local verticalOffset = (i % 2 == 1) and math.random(1, 5) or math.random(8, 15)
							local yOffset = verticalOffset

							-- Calculate rainbow color based on character position
							local hue = (i / totalChars) % 1
							local rainbowColor = Color3.fromHSV(hue, 0.9, 1)

							if isImageLabel then
								character.ImageTransparency = 1
								character.ImageColor3 = rainbowColor
							else
								character.TextTransparency = 1
								character.TextColor3 = rainbowColor
							end
							character.Position = originalPos - UDim2.fromOffset(xOffset, -yOffset)

							local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
							local props = { Position = originalPos }
							props[isImageLabel and "ImageTransparency" or "TextTransparency"] = 0

							TweenService:Create(character, tweenInfo, props):Play()
							task.wait(delayPerChar)
						end

						-- After animation completes, fade all characters back to white
						task.wait(0.3) -- Wait for last character's tween to finish
						for i, character in characters do
							if not character.Parent then break end

							local isImageLabel = character:IsA("ImageLabel")
							local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
							local fadeProps = {}

							if isImageLabel then
								fadeProps.ImageColor3 = Color3.fromRGB(255, 255, 255)
							else
								fadeProps.TextColor3 = Color3.fromRGB(255, 255, 255)
							end

							TweenService:Create(character, fadeInfo, fadeProps):Play()
						end
					end

					-- Animate text in on creation
					task.spawn(function()
						task.wait(0.05)
						fadeDivergeAnimation(labelFrame, 0.015)
					end)

					-- Repeat animation every 3 seconds
					local animationThread = task.spawn(function()
						while true do
							task.wait(3)

							if not labelFrame or not labelFrame.Parent then
								return
							end

							-- Re-animate with fade diverge
							fadeDivergeAnimation(labelFrame, 0.015)
						end
					end)

					-- Store thread in scope for cleanup
					table.insert(scope, function()
						task.cancel(animationThread)
					end)

					return labelFrame
				end)(),

				-- Distance text
					scope:New "TextLabel" {
						Name = "Distance",
						Text = scope:Computed(function(use)
							local distance = use(props.Distance)
							return if distance then formatDistance(distance) else ""
						end),
						TextColor3 = markerColor,
						TextSize = 12,
						FontFace = Font.new "rbxasset://fonts/families/Balthazar.json",
						TextStrokeTransparency = 0,
						TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
						TextTransparency = transparencyTween,
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						LayoutOrder = 2,
						Visible = scope:Computed(function(use)
							return use(props.Distance) ~= nil
						end),
						TextWrapped = false,
					},
				},
			},
		},
	}
end

return Marker
