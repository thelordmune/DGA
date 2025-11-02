local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Emitter2D = require(ReplicatedStorage.Modules.Utils["2dEmitter"])

local Children, scoped, peek =
	Fusion.Children, Fusion.scoped, Fusion.peek

return function(Target, props)
	props = props or {}
	local scope = scoped(Fusion, {})

	local rotation = scope:Value(0)
	local otherrotation = scope:Value(0)
	local started = scope:Value(true) -- Always started (always spinning)
	local positionsActive = scope:Value(false) -- Controls position animations
	local mainFrame -- Declare at the very top
	local visible = scope:Value(true) -- Always visible
	local opacity = scope:Value(0) -- Start at 0 (invisible), will fade in
	local isCasting = scope:Value(false) -- Track if actively casting (G pressed)

	-- Individual fade states for each element (start visible, fade to 0 = fully visible)
	local fadeStates = {
		scope:Value(0), -- Triangle - start visible
		scope:Value(0), -- Hexagon - start visible
		scope:Value(0), -- HexCircle - start visible
		scope:Value(0), -- ThickInner - start visible
		scope:Value(0), -- ThinInner - start visible
		scope:Value(0), -- TriCircles - start visible
		scope:Value(0), -- Circle - start visible
		scope:Value(1), -- InnerLetters - start hidden (only show when casting)
		scope:Value(1), -- Letters - start hidden (only show when casting)
		scope:Value(1), -- ThickInnerLetters - start hidden (only show when casting)
	}

	-- Create computed transparency values that combine fadeState with opacity
	local transparencies = {}
	for i = 1, #fadeStates do
		transparencies[i] = scope:Computed(function(use)
			local fadeValue = use(fadeStates[i])
			local opacityValue = use(opacity)
			-- Combine: if opacity is 0, fully transparent (1). If opacity is 1, use fadeValue
			return fadeValue + (1 - opacityValue)
		end)
	end

	-- Track which items use rotation (not otherrotation)
	-- Items: Triangle, Hexagon, HexCircle, ThickInner, ThinInner, TriCircles, Circle
	local rotatingItems = {
		{name = "Triangle", multiplier = 1, stopped = scope:Value(false), flashing = scope:Value(false), gaussian = nil, stoppedRotation = 0, targetRotation = scope:Value(0)},
		{name = "Hexagon", multiplier = 1.5, stopped = scope:Value(false), flashing = scope:Value(false), gaussian = nil, stoppedRotation = 0, targetRotation = scope:Value(0)},
		{name = "HexCircle", multiplier = 3.3, stopped = scope:Value(false), flashing = scope:Value(false), gaussian = nil, stoppedRotation = 0, targetRotation = scope:Value(0)},
		{name = "ThickInner", multiplier = 0.7, stopped = scope:Value(false), flashing = scope:Value(false), gaussian = nil, stoppedRotation = 0, targetRotation = scope:Value(0)},
		{name = "ThinInner", multiplier = 1, stopped = scope:Value(false), flashing = scope:Value(false), gaussian = nil, stoppedRotation = 0, targetRotation = scope:Value(0)},
		{name = "TriCircles", multiplier = 1, stopped = scope:Value(false), flashing = scope:Value(false), gaussian = nil, stoppedRotation = 0, targetRotation = scope:Value(0)},
		{name = "Circle", multiplier = 1.35, stopped = scope:Value(false), flashing = scope:Value(false), gaussian = nil, stoppedRotation = 0, targetRotation = scope:Value(0)},
	}

	local allStopped = scope:Value(false)
	local confirmed = scope:Value(false)

	-- Key sequence tracking
	local keySequence = scope:Value("")

	-- Flash connections
	local flashConnections = {}

	local LIGHT_BLUE = Color3.fromRGB(100, 200, 255) -- Consistent light blue color

	local function startFlashing(itemData)
		if flashConnections[itemData.name] then return end

		itemData.flashing:set(true)
		local flashTime = 0
		flashConnections[itemData.name] = RunService.RenderStepped:Connect(function(dt)
			flashTime = flashTime + dt
			local flashValue = (math.sin(flashTime * 10) + 1) / 2
			if itemData.gaussian then
				-- Flash between white and light blue
				itemData.gaussian.ImageColor3 = Color3.fromRGB(255, 255, 255):Lerp(LIGHT_BLUE, flashValue)
			end
		end)
	end

	local function stopFlashing(itemData)
		if flashConnections[itemData.name] then
			flashConnections[itemData.name]:Disconnect()
			flashConnections[itemData.name] = nil
		end
		itemData.flashing:set(false)
	end

	local function stopRandomRotation()
		-- Find all items that are still rotating
		local availableItems = {}
		for _, item in ipairs(rotatingItems) do
			if not peek(item.stopped) then
				table.insert(availableItems, item)
			end
		end

		if #availableItems > 0 then
			local chosen = availableItems[math.random(1, #availableItems)]

			-- Store the current rotation value and set target
			local currentRot = peek(rotation) * chosen.multiplier
			chosen.targetRotation:set(currentRot)
			chosen.stopped:set(true)

			startFlashing(chosen)

			-- Check if all are stopped
			local allAreStopped = true
			for _, item in ipairs(rotatingItems) do
				if not peek(item.stopped) then
					allAreStopped = false
					break
				end
			end
			allStopped:set(allAreStopped)
		end
	end

	local function finalize()
		confirmed:set(true)

		local TweenService = game:GetService("TweenService")
		local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local fastFade = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

		-- Stop all flashing
		for _, item in ipairs(rotatingItems) do
			stopFlashing(item)
		end

		-- Tween all non-letter gaussians to light blue
		for _, item in ipairs(rotatingItems) do
			if item.gaussian then
				local tween = TweenService:Create(item.gaussian, tweenInfo, {ImageColor3 = LIGHT_BLUE})
				tween:Play()
			end
		end

		-- Stop letter rotations after a brief moment
		task.wait(0.3)
		started:set(false)

		-- Wait before shatter
		task.wait(.5)

		-- Wait for mainFrame to be created if not yet available
		if not mainFrame then
			warn("mainFrame is nil!")
			return
		end

		-- Shake effect before breaking
		local originalPosition = mainFrame.Position
		local shakeIntensity = 8
		local shakeDuration = 2
		local shakeStartTime = tick()

		local shakeConnection
		shakeConnection = RunService.RenderStepped:Connect(function()
			local elapsed = tick() - shakeStartTime
			if elapsed >= shakeDuration then
				mainFrame.Position = originalPosition
				shakeConnection:Disconnect()
				return
			end

			-- Random shake offset that decreases over time
			local progress = elapsed / shakeDuration
			local intensity = shakeIntensity * (1 - progress)
			local offsetX = math.random(-intensity, intensity)
			local offsetY = math.random(-intensity, intensity)

			mainFrame.Position = originalPosition + UDim2.fromOffset(offsetX, offsetY)
		end)

		-- Wait for shake to complete
		task.wait(shakeDuration - .4)

		-- Create particle emitters for shatter effect on all ImageLabels
		local function createShatterParticles(frame)
			if not frame then return end

			-- Process all descendants, not just direct children
			for _, child in ipairs(frame:GetDescendants()) do
				if child:IsA("ImageLabel") then
					-- Create a container frame for the emitter
					local emitterContainer = Instance.new("Frame")
					emitterContainer.Size = UDim2.fromScale(1, 1)
					emitterContainer.Position = UDim2.fromScale(0, 0)
					emitterContainer.BackgroundTransparency = 1
					emitterContainer.Parent = mainFrame

					-- Create particle emitter
					local emitter = Emitter2D.new()
					emitter.Parent = emitterContainer

					-- Get absolute position of the image
					local centerX = child.AbsolutePosition.X + (child.AbsoluteSize.X / 2)
					local centerY = child.AbsolutePosition.Y + (child.AbsoluteSize.Y / 2)

					-- Set emitter position
					emitter.Position = UDim2.fromOffset(centerX, centerY)

					-- Configure particle properties for glass shatter effect
					emitter.Color = child.ImageColor3
					emitter.Size = math.random(8, 16)
					emitter.Texture = child.Image -- Use same texture as the image
					emitter.Transparency = 0
					emitter.ZOffset = 2

					emitter.EmissionDirection = "Top"
					emitter.Enabled = false -- We'll manually emit
					emitter.Lifetime = NumberRange.new(0.8, 1.5)
					emitter.Rate = 50
					emitter.Rotation = math.random(0, 360)
					emitter.RotSpeed = math.random(-200, 200)
					emitter.Speed = math.random(100, 300)
					emitter.SpreadAngle = 180 -- Burst in all directions

					emitter.Acceleration = Vector2.new(0, 400) -- Gravity effect

					-- Bind to update loop
					emitter:BindToRenderStepped()

					-- Emit burst of particles
					local particleCount = math.random(20, 40)
					emitter:Emit(particleCount)

					-- Fade out the original image quickly
					local fadeTween = TweenService:Create(child, fastFade, {
						ImageTransparency = 1
					})
					fadeTween:Play()

					-- Clean up emitter after particles are done
					task.delay(2, function()
						emitter:Destroy()
						emitterContainer:Destroy()
					end)
				end
			end

			-- Also fade out all Frames quickly
			for _, child in ipairs(frame:GetDescendants()) do
				if child:IsA("Frame") and child.Name ~= "ButtonContainer" then
					local fadeTween = TweenService:Create(child, fastFade, {
						BackgroundTransparency = 1
					})
					fadeTween:Play()
				end
			end
		end

		createShatterParticles(mainFrame)

		-- Fade main frame background quickly
		local frameFade = TweenService:Create(mainFrame, fastFade, {BackgroundTransparency = 1})
		frameFade:Play()

		-- Hide buttons quickly
		local buttonContainer = mainFrame:FindFirstChild("ButtonContainer")
		if buttonContainer then
			for _, button in ipairs(buttonContainer:GetChildren()) do
				if button:IsA("TextButton") then
					local buttonFade = TweenService:Create(button, fastFade, {
						BackgroundTransparency = 1,
						TextTransparency = 1
					})
					buttonFade:Play()
				end
			end
		end

		-- Wait for particles to finish, then reset
		task.delay(2, function()
			-- Hide UI before transitioning back to center
			visible:set(false)
			opacity:set(0) -- Reset opacity to 0

			-- Reset all rotating items FIRST
			for _, item in ipairs(rotatingItems) do
				item.stopped:set(false)
				item.flashing:set(false)
				item.targetRotation:set(0)
				-- Reset gaussian color to white and transparency
				if item.gaussian then
					item.gaussian.ImageColor3 = Color3.fromRGB(255, 255, 255)
					item.gaussian.ImageTransparency = 0
				end
			end

			-- Reset all ImageLabel transparencies back to 0 (visible)
			for _, child in ipairs(mainFrame:GetDescendants()) do
				if child:IsA("ImageLabel") and child.Name ~= "GaussianBlur" then
					child.ImageTransparency = 0
				end
			end

			-- Reset all Frame transparencies
			for _, child in ipairs(mainFrame:GetDescendants()) do
				if child:IsA("Frame") and child.Name ~= "ButtonContainer" then
					child.BackgroundTransparency = 0
				end
			end

			-- Reset main frame transparency
			mainFrame.BackgroundTransparency = 1

			-- Reset fade states - geometric shapes visible (0), letters hidden (1)
			for i = 1, 7 do
				fadeStates[i]:set(0) -- Geometric shapes visible
			end
			for i = 8, 10 do
				fadeStates[i]:set(1) -- Letters hidden
			end

			-- Reset all other states
			started:set(true) -- Keep spinning
			positionsActive:set(false)
			confirmed:set(false)
			allStopped:set(false)
			keySequence:set("")

			-- Return to idle state (center position, spinning)
			isCasting:set(false)

			-- Wait for spring animation to complete, then fade in
			task.wait(0.5) -- Wait for spring animation to complete
			visible:set(true)

			-- Fade in over 0.5 seconds
			local fadeStartTime = tick()
			local fadeConnection
			fadeConnection = RunService.RenderStepped:Connect(function()
				local elapsed = tick() - fadeStartTime
				local progress = math.min(elapsed / 0.5, 1) -- 0.5 second fade
				opacity:set(progress)

				if progress >= 1 then
					fadeConnection:Disconnect()
				end
			end)
		end)
	end

	-- Rotation update loop
	RunService.RenderStepped:Connect(function(dt)
		if not peek(started) then return end
		rotation:set((peek(rotation) + (dt * math.random(20,60))) % 360)
		otherrotation:set((peek(otherrotation) - (dt * math.random(20,60))) % 360)
	end)

	-- Public API for external control
	local api = {
		Start = function()
			-- Start casting - move to side and show letter elements
			isCasting:set(true)

			-- Fade in the letter elements (indices 8, 9, 10)
			for i = 8, 10 do
				fadeStates[i]:set(0)
			end
		end,

		StopRotation = function(key)
			stopRandomRotation()
			-- Add key to sequence display
			if key then
				local current = peek(keySequence)
				keySequence:set(current .. key)
			end
		end,

		Confirm = function()
			if not peek(confirmed) then
				-- Stop all rotations first
				for _, item in ipairs(rotatingItems) do
					if not peek(item.stopped) then
						local currentRot = peek(rotation) * item.multiplier
						item.targetRotation:set(currentRot)
						item.stopped:set(true)
					end
				end
				allStopped:set(true)

				-- Run finalize animation
				task.spawn(finalize)
			end
		end,

		IsAllStopped = function()
			return peek(allStopped)
		end,

		IsConfirmed = function()
			return peek(confirmed)
		end,

		ShowCooldownFeedback = function()
			-- Tween all gaussians to orange to indicate cooldown
			local TweenService = game:GetService("TweenService")
			local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local orangeColor = Color3.fromRGB(255, 140, 0) -- Orange color

			-- Tween all rotating items' gaussians to orange
			for _, item in ipairs(rotatingItems) do
				if item.gaussian then
					local tween = TweenService:Create(item.gaussian, tweenInfo, {ImageColor3 = orangeColor})
					tween:Play()
				end
			end

			-- After showing orange, fade back and reset
			task.delay(0.5, function()
				-- Fade back to normal and reset
				for _, item in ipairs(rotatingItems) do
					if item.gaussian then
						local fadeTween = TweenService:Create(item.gaussian, tweenInfo, {
							ImageTransparency = 1
						})
						fadeTween:Play()
					end
				end

				-- Reset after fade
				task.delay(0.3, function()
					visible:set(false)
					started:set(false)
					confirmed:set(false)
					allStopped:set(false)
					keySequence:set("")

					for _, item in ipairs(rotatingItems) do
						item.stopped:set(false)
						item.flashing:set(false)
						item.targetRotation:set(0)
					end

					for _, fadeState in ipairs(fadeStates) do
						fadeState:set(1)
					end
				end)
			end)
		end
	}

	mainFrame = scope:New "CanvasGroup" {
		Parent = Target,
		Name = "Frame",
		BackgroundColor3 = Color3.fromRGB(62, 62, 62),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		GroupTransparency = scope:Spring(
			scope:Computed(function(use)
				return 1 - use(opacity) -- Invert: opacity 0 = transparent 1, opacity 1 = transparent 0
			end),
			20,
			1
		),
		-- Position animates based on casting state
		Position = scope:Spring(
			scope:Computed(function(use)
				if use(isCasting) then
					-- Move to side when casting (left side of health bar)
					return UDim2.fromScale(-0.15, 0.5)
				else
					-- Idle position (center of health UI, replacing the circle)
					return UDim2.fromScale(0.5, 0.5)
				end
			end),
			30,
			6
		),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(115, 115), -- Match health UI size
		Visible = scope:Computed(function(use)
			return use(visible)
		end),
        ZIndex = -1,

		[Children] = {
			-- Key Sequence Indicator
			scope:New "TextLabel" {
				Name = "KeySequenceIndicator",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, -0.15),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(300, 50),
				Font = Enum.Font.GothamBold,
				Text = scope:Computed(function(use)
					local seq = use(keySequence)
					return seq == "" and "" or seq
				end),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 36,
				TextStrokeTransparency = scope:Computed(function(use)
					local opacityValue = use(opacity)
					return 0.5 + (1 - opacityValue) * 0.5 -- Fade stroke with opacity
				end),
				TextTransparency = scope:Computed(function(use)
					local opacityValue = use(opacity)
					-- Only show when casting (isCasting = true)
					if use(isCasting) then
						return 1 - opacityValue -- Visible when opacity is 1
					else
						return 1 -- Hidden when not casting
					end
				end),
				ZIndex = 10,
			},

			-- Triangle (uses rotation)
			scope:New "ImageLabel" {
				Name = "Triangle",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://86064034964012",
				ImageTransparency = scope:Spring(transparencies[1], 20, 1),
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5), -- Always centered
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = -1,
				Rotation = scope:Spring(
					scope:Computed(function(use)
						if use(rotatingItems[1].stopped) then
							return use(rotatingItems[1].targetRotation)
						end
						return use(rotation) * rotatingItems[1].multiplier
					end),
					30,
					6
				),

				[Children] = {
					(function()
						local gaussian = scope:New "ImageLabel" {
							Name = "TriangleGaussian",
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Image = "rbxassetid://126920523509886",
							ImageColor3 = Color3.fromRGB(255, 255, 255),
							ImageTransparency = scope:Spring(transparencies[1], 20, 1),
							Size = UDim2.fromScale(1, 1),
							ZIndex = -1,
						}
						rotatingItems[1].gaussian = gaussian
						return gaussian
					end)(),
				}
			},

			-- Hexagon (uses rotation * 1.5)
			scope:New "ImageLabel" {
				Name = "Hexagon",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://89861359797736",
				ImageTransparency = scope:Spring(transparencies[2], 20, 1),
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5), -- Always centered
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = -1,
				Rotation = scope:Spring(
					scope:Computed(function(use)
						if use(rotatingItems[2].stopped) then
							return use(rotatingItems[2].targetRotation)
						end
						return use(rotation) * rotatingItems[2].multiplier
					end),
					30,
					6
				),

				[Children] = {
					(function()
						local gaussian = scope:New "ImageLabel" {
							Name = "HexagonGaussian",
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Image = "rbxassetid://86027245839806",
							ImageColor3 = Color3.fromRGB(255, 255, 255),
							ImageTransparency = scope:Spring(transparencies[2], 20, 1),
							Size = UDim2.fromScale(1, 1),
							ZIndex = -1,
						}
						rotatingItems[2].gaussian = gaussian
						return gaussian
					end)(),
				}
			},

			-- HexCircle (uses rotation * 3.3)
			scope:New "ImageLabel" {
				Name = "HexCircle",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://112087117675236",
				ImageTransparency = scope:Spring(transparencies[3], 20, 1),
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5), -- Always centered
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = scope:Spring(
					scope:Computed(function(use)
						if use(rotatingItems[3].stopped) then
							return use(rotatingItems[3].targetRotation)
						end
						return use(rotation) * rotatingItems[3].multiplier
					end),
					30,
					6
				),

				[Children] = {
					(function()
						local gaussian = scope:New "ImageLabel" {
							Name = "HexCircleGaussian",
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Image = "rbxassetid://86902109046940",
							ImageColor3 = Color3.fromRGB(255, 255, 255),
							ImageTransparency = scope:Spring(transparencies[3], 20, 1),
							Size = UDim2.fromScale(1, 1),
							ZIndex = -1,
						}
						rotatingItems[3].gaussian = gaussian
						return gaussian
					end)(),
				}
			},

			-- ThickInner (uses rotation * 0.7)
			scope:New "ImageLabel" {
				Name = "ThickInner",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://118819453385760",
				ImageTransparency = scope:Spring(transparencies[4], 20, 1),
				ZIndex = -1,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5), -- Always centered
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = scope:Spring(
					scope:Computed(function(use)
						if use(rotatingItems[4].stopped) then
							return use(rotatingItems[4].targetRotation)
						end
						return use(rotation) * rotatingItems[4].multiplier
					end),
					30,
					6
				),

				[Children] = {
					(function()
						local gaussian = scope:New "ImageLabel" {
							Name = "ThickInnerGaussian",
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Image = "rbxassetid://94075865495096",
							ImageColor3 = Color3.fromRGB(255, 255, 255),
							ImageTransparency = scope:Spring(transparencies[4], 20, 1),
							Size = UDim2.fromScale(1, 1),
							ZIndex = -1,
						}
						rotatingItems[4].gaussian = gaussian
						return gaussian
					end)(),
				}
			},

			-- ThinInner (uses rotation)
			scope:New "ImageLabel" {
				Name = "ThinInner",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://111296265599522",
				ImageTransparency = scope:Spring(transparencies[5], 20, 1),
				ZIndex = -1,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5), -- Always centered
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = scope:Spring(
					scope:Computed(function(use)
						if use(rotatingItems[5].stopped) then
							return use(rotatingItems[5].targetRotation)
						end
						return use(rotation) * rotatingItems[5].multiplier
					end),
					30,
					6
				),

				[Children] = {
					(function()
						local gaussian = scope:New "ImageLabel" {
							Name = "ThinInnerGaussian",
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Image = "rbxassetid://77612423255783",
							ImageColor3 = Color3.fromRGB(255, 255, 255),
							ImageTransparency = scope:Spring(transparencies[5], 20, 1),
							Size = UDim2.fromScale(1, 1),
							ZIndex = -1,
						}
						rotatingItems[5].gaussian = gaussian
						return gaussian
					end)(),
				}
			},

			-- TriCircles (uses rotation)
			scope:New "ImageLabel" {
				Name = "TriCircles",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://75745563950147",
				ImageTransparency = scope:Spring(transparencies[6], 20, 1),
				ZIndex = -1,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5), -- Always centered
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = scope:Spring(
					scope:Computed(function(use)
						if use(rotatingItems[6].stopped) then
							return use(rotatingItems[6].targetRotation)
						end
						return use(rotation) * rotatingItems[6].multiplier
					end),
					30,
					6
				),

				[Children] = {
					(function()
						local gaussian = scope:New "ImageLabel" {
							Name = "TriCirclesGaussian",
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Image = "rbxassetid://84958789919903",
							ImageColor3 = Color3.fromRGB(255, 255, 255),
							ImageTransparency = scope:Spring(transparencies[6], 20, 1),
							Size = UDim2.fromScale(1, 1),
							ZIndex = -1,
						}
						rotatingItems[6].gaussian = gaussian
						return gaussian
					end)(),
				}
			},

			-- Circle (uses rotation * 1.35)
			scope:New "ImageLabel" {
				Name = "Circle",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://140710938151976",
				ImageTransparency = scope:Spring(transparencies[7], 20, 1),
				ZIndex = -1,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5), -- Always centered
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = scope:Spring(
					scope:Computed(function(use)
						if use(rotatingItems[7].stopped) then
							return use(rotatingItems[7].targetRotation)
						end
						return use(rotation) * rotatingItems[7].multiplier
					end),
					30,
					6
				),

				[Children] = {
					(function()
						local gaussian = scope:New "ImageLabel" {
							Name = "CircleGaussian",
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Image = "rbxassetid://125312893384553",
							ImageColor3 = Color3.fromRGB(255, 255, 255),
							ImageTransparency = scope:Spring(transparencies[7], 20, 1),
							Size = UDim2.fromScale(1, 1),
							ZIndex = -1,
						}
						rotatingItems[7].gaussian = gaussian
						return gaussian
					end)(),
				}
			},

			-- InnerLetters (uses otherrotation - NOT AFFECTED)
			scope:New "ImageLabel" {
				Name = "InnerLetters",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://77169026051033",
				ImageTransparency = scope:Spring(transparencies[8], 20, 1),
				ZIndex = -1,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = scope:Computed(function(use) return use(otherrotation) end),

				[Children] = {
					scope:New "ImageLabel" {
						Name = "InnerLettersGaussian",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://72074880829814",
						ImageTransparency = scope:Spring(transparencies[8], 20, 1),
						Size = UDim2.fromScale(1, 1),
						ZIndex = -1,
					},
				}
			},

			-- Letters (uses otherrotation - NOT AFFECTED)
			scope:New "ImageLabel" {
				Name = "Letters",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://121601902182489",
				ImageTransparency = scope:Spring(transparencies[9], 20, 1),
				ZIndex = -1,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5), -- Always centered
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = scope:Computed(function(use) return use(otherrotation) end),

				[Children] = {
					scope:New "ImageLabel" {
						Name = "LettersGaussian",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://135957360987869",
						ImageTransparency = scope:Spring(transparencies[9], 20, 1),
						Size = UDim2.fromScale(1, 1),
						ZIndex = -1,
					},
				}
			},

			-- ThickInnerLetters (uses otherrotation - NOT AFFECTED)
			scope:New "ImageLabel" {
				Name = "ThickInnerLetters",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://81055312846796",
				ImageTransparency = scope:Spring(transparencies[10], 20, 1),
				ZIndex = -1,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5), -- Always centered
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = scope:Computed(function(use) return use(otherrotation) end),

				[Children] = {
					scope:New "ImageLabel" {
						Name = "ThickInnerLettersGaussian",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://103623487479394",
						ImageTransparency = scope:Spring(transparencies[10], 20, 1),
						Size = UDim2.fromScale(1, 1),
						ZIndex = -1,
					},
				}
			},
		}
	}

	-- Initial fade-in on component load
	local fadeConnection = nil
	task.delay(1, function() -- Wait 1 second before appearing
		local fadeStartTime = tick()
		fadeConnection = RunService.RenderStepped:Connect(function()
			local elapsed = tick() - fadeStartTime
			local progress = math.min(elapsed / 0.5, 1) -- 0.5 second fade
			opacity:set(progress)

			if progress >= 1 then
				fadeConnection:Disconnect()
				fadeConnection = nil
			end
		end)
	end)

	-- Cleanup function for fade connection
	local cleanupFade = function()
		if fadeConnection then
			fadeConnection:Disconnect()
			fadeConnection = nil
		end
	end

	-- Add cleanup to scope
	table.insert(scope, cleanupFade)

	-- Return the API for external control (including scope for cleanup)
	api.scope = scope
	return api
end
