--[[
    PlayerBars Component

    Clean, modern player HUD bars for health, stamina, and parry.
    Uses UIGradient for depletion effects and 2D particle emitters for visual feedback.

    Features:
    - Health bar with right-to-left depletion via gradient offset
    - Stamina bar with same depletion pattern
    - Parry bar with center-outward expansion via gradient transparency
    - Damage chip particles when health is lost
    - Speed lines during regeneration
    - Low health blink effect
    - Flash effect on hit
    - Shake effect on damage
    - Hover text showing exact values
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Emitter2D = require(ReplicatedStorage.Modules.Utils["2dEmitter"])

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Ref = Fusion.Ref

-- Constants
local MAX_HEALTH = 100
local MAX_STAMINA = 100
local MAX_PARRY = 100

local GRADUAL_DRAIN_RATE = 15 -- per second
local PARRY_REGEN_RATE = 20 -- per second

return function(target)
	local scope = Fusion:scoped()

	-- State values (0-100 percentage)
	local health = scope:Value(MAX_HEALTH)
	local maxHealth = scope:Value(MAX_HEALTH)
	local stamina = scope:Value(MAX_STAMINA)
	local maxStamina = scope:Value(MAX_STAMINA)
	local parry = scope:Value(0) -- Parry starts at 0 (empty/centered sliver)
	local maxParry = scope:Value(MAX_PARRY)
	local money = scope:Value(0)

	-- Drain/regen flags
	local isDrainingStamina = scope:Value(false)
	local isDrainingHealth = scope:Value(false)
	local isRegenParry = scope:Value(false)
	local isRegenHealth = scope:Value(false)
	local isRegenStamina = scope:Value(false)

	-- Spring-animated values for smooth transitions (higher damping = less bouncy)
	local healthSpring = scope:Spring(health, 25, 1)
	local staminaSpring = scope:Spring(stamina, 25, 1)
	local parrySpring = scope:Spring(parry, 30, 1)

	-- Shake effect
	local shakeOffsetX = scope:Value(0)
	local shakeOffsetY = scope:Value(0)
	local isShaking = scope:Value(false)
	local shakeTime = scope:Value(0)
	local shakeDuration = 0.3
	local currentShakeIntensity = scope:Value(0)

	-- Flash effect
	local healthFlash = scope:Value(0)
	local healthFlashSpring = scope:Spring(healthFlash, 40, 1)

	-- Low health blink effect
	local lowHealthBlink = scope:Value(0)
	local blinkTime = scope:Value(0)
	local BLINK_SPEED = 4 -- blinks per second
	local LOW_HEALTH_THRESHOLD = 25

	local framePosition = scope:Computed(function(use)
		local offsetX = use(shakeOffsetX)
		local offsetY = use(shakeOffsetY)
		return UDim2.new(0.5, offsetX, 0.75, offsetY)
	end)

	-- Function to trigger shake (scales with damage)
	local function triggerShake(damageAmount)
		local intensity = math.clamp(damageAmount / 10, 2, 20) -- Scale: 2-20 pixels based on damage
		currentShakeIntensity:set(intensity)
		isShaking:set(true)
		shakeTime:set(0)
	end

	-- Function to trigger health flash
	local function triggerFlash()
		healthFlash:set(1)
		task.delay(0.05, function()
			healthFlash:set(0)
		end)
	end

	-- Refs for bar elements (for particle emitters)
	local healthBarRef = scope:Value(nil)
	local staminaBarRef = scope:Value(nil)
	local parryBarRef = scope:Value(nil)
	local healthEdgeRef = scope:Value(nil)
	local staminaEdgeRef = scope:Value(nil)
	local parryEdgeRef = scope:Value(nil)

	-- Computed position for health bar edge (where chips emit from)
	local healthEdgePosition = scope:Computed(function(use)
		local percentage = use(healthSpring) / MAX_HEALTH
		-- Position at the right edge of the visible health (right-to-left depletion)
		return UDim2.fromScale(percentage, 0.5)
	end)

	-- Computed position for stamina bar edge
	local staminaEdgePosition = scope:Computed(function(use)
		local percentage = use(staminaSpring) / MAX_STAMINA
		return UDim2.fromScale(percentage, 0.5)
	end)

	-- Computed position for parry bar edge (center outward, so at the expanding edge)
	local parryEdgePosition = scope:Computed(function(use)
		local percentage = use(parrySpring) / MAX_PARRY
		-- Parry expands from center, so edge is at 0.5 + half the width
		local halfWidth = percentage * 0.47
		return UDim2.fromScale(0.5 + halfWidth, 0.5)
	end)

	-- Hover states for text labels
	local isHoveringHealth = scope:Value(false)
	local isHoveringStamina = scope:Value(false)

	-- Text transparency springs (1 = hidden, 0 = visible)
	local healthTextTransparency = scope:Spring(
		scope:Computed(function(use)
			return use(isHoveringHealth) and 0 or 1
		end),
		25, 1
	)
	local staminaTextTransparency = scope:Spring(
		scope:Computed(function(use)
			return use(isHoveringStamina) and 0 or 1
		end),
		25, 1
	)

	-- Particle Emitters
	local healthChipEmitter = Emitter2D.new()
	healthChipEmitter.Color = Color3.fromRGB(255, 80, 80)
	healthChipEmitter.Size = 8
	healthChipEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	healthChipEmitter.EmissionDirection = "Bottom"
	healthChipEmitter.Enabled = false
	healthChipEmitter.Lifetime = NumberRange.new(0.4, 0.8)
	healthChipEmitter.Rate = 30
	healthChipEmitter.Speed = 80
	healthChipEmitter.SpreadAngle = 45
	healthChipEmitter.Acceleration = Vector2.new(0, 200) -- gravity
	healthChipEmitter.Rotation = 0
	healthChipEmitter.RotSpeed = 180
	healthChipEmitter.Transparency = 0

	-- Speed line emitters for regeneration
	local healthRegenEmitter = Emitter2D.new()
	healthRegenEmitter.Color = Color3.fromRGB(255, 150, 150)
	healthRegenEmitter.Size = 4
	healthRegenEmitter.AspectRatio = 8 -- elongated for speed lines
	healthRegenEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	healthRegenEmitter.EmissionDirection = "Right" -- going right as bar fills
	healthRegenEmitter.Enabled = false
	healthRegenEmitter.Lifetime = NumberRange.new(0.15, 0.25)
	healthRegenEmitter.Rate = 40
	healthRegenEmitter.Speed = 150
	healthRegenEmitter.SpreadAngle = 10
	healthRegenEmitter.Transparency = 0.3

	local staminaRegenEmitter = Emitter2D.new()
	staminaRegenEmitter.Color = Color3.fromRGB(85, 255, 139)
	staminaRegenEmitter.Size = 3
	staminaRegenEmitter.AspectRatio = 8
	staminaRegenEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	staminaRegenEmitter.EmissionDirection = "Right" -- going right as bar fills
	staminaRegenEmitter.Enabled = false
	staminaRegenEmitter.Lifetime = NumberRange.new(0.15, 0.25)
	staminaRegenEmitter.Rate = 40
	staminaRegenEmitter.Speed = 120
	staminaRegenEmitter.SpreadAngle = 10
	staminaRegenEmitter.Transparency = 0.3

	local parryRegenEmitter = Emitter2D.new()
	parryRegenEmitter.Color = Color3.fromRGB(255, 200, 50)
	parryRegenEmitter.Size = 3
	parryRegenEmitter.AspectRatio = 6
	parryRegenEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	parryRegenEmitter.EmissionDirection = "Left" -- shrinking inward
	parryRegenEmitter.Enabled = false
	parryRegenEmitter.Lifetime = NumberRange.new(0.15, 0.25)
	parryRegenEmitter.Rate = 35
	parryRegenEmitter.Speed = 100
	parryRegenEmitter.SpreadAngle = 15
	parryRegenEmitter.Transparency = 0.3

	-- Track previous health for damage detection
	local prevHealth = MAX_HEALTH

	-- Function to emit health chip particles from the edge
	local function emitHealthChips(damageAmount)
		local edgeFrame = Fusion.peek(healthEdgeRef)
		if edgeFrame then
			healthChipEmitter.Parent = edgeFrame
			local particleCount = math.clamp(math.floor(damageAmount / 5), 3, 15)
			healthChipEmitter:Emit(particleCount)
		end
	end

	-- Computed sizes for bars (right-to-left for health/stamina using gradient offset)
	local healthGradientOffset = scope:Computed(function(use)
		local percentage = use(healthSpring) / MAX_HEALTH
		-- Negative offset for right-to-left depletion (right side disappears first)
		return Vector2.new(percentage - 1, 0)
	end)

	local staminaGradientOffset = scope:Computed(function(use)
		local percentage = use(staminaSpring) / MAX_STAMINA
		-- Negative offset for right-to-left depletion
		return Vector2.new(percentage - 1, 0)
	end)

	-- Parry bar expands from center outward using gradient transparency
	local parryTransparency = scope:Computed(function(use)
		local percentage = use(parrySpring) / MAX_PARRY
		-- Calculate the visible region (expands from center)
		local halfWidth = percentage * 0.47 -- Max 0.47 to leave soft edges
		local leftEdge = math.max(0.03, 0.5 - halfWidth)
		local rightEdge = math.min(0.97, 0.5 + halfWidth)

		-- Create transparency sequence: transparent on edges, visible in center region
		if percentage < 0.02 then
			-- Nearly empty - tiny sliver
			return NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.48, 1),
				NumberSequenceKeypoint.new(0.49, 0),
				NumberSequenceKeypoint.new(0.51, 0),
				NumberSequenceKeypoint.new(0.52, 1),
				NumberSequenceKeypoint.new(1, 1),
			})
		else
			return NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(math.max(0.01, leftEdge - 0.02), 1),
				NumberSequenceKeypoint.new(leftEdge, 0),
				NumberSequenceKeypoint.new(rightEdge, 0),
				NumberSequenceKeypoint.new(math.min(0.99, rightEdge + 0.02), 1),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end)

	-- RunService connection for gradual effects
	local connection = RunService.Heartbeat:Connect(function(dt)
		-- Shake effect
		if Fusion.peek(isShaking) then
			local currentTime = Fusion.peek(shakeTime) + dt
			shakeTime:set(currentTime)

			if currentTime < shakeDuration then
				local decay = 1 - (currentTime / shakeDuration)
				local intensity = Fusion.peek(currentShakeIntensity) * decay
				shakeOffsetX:set((math.random() - 0.5) * 2 * intensity)
				shakeOffsetY:set((math.random() - 0.5) * 2 * intensity)
			else
				isShaking:set(false)
				shakeOffsetX:set(0)
				shakeOffsetY:set(0)
			end
		end

		-- Low health blink effect
		local currentHealth = Fusion.peek(health)
		if currentHealth <= LOW_HEALTH_THRESHOLD and currentHealth > 0 then
			local newBlinkTime = Fusion.peek(blinkTime) + dt
			blinkTime:set(newBlinkTime)
			-- Sine wave for smooth pulsing (0 to 1)
			local blinkValue = (math.sin(newBlinkTime * BLINK_SPEED * math.pi * 2) + 1) / 2
			lowHealthBlink:set(blinkValue)
		else
			lowHealthBlink:set(0)
			blinkTime:set(0)
		end

		-- Detect health changes for damage effects
		if currentHealth < prevHealth then
			local damage = prevHealth - currentHealth
			triggerShake(damage)
			triggerFlash()
			emitHealthChips(damage)
		end
		prevHealth = currentHealth

		-- Update particle emitters
		healthChipEmitter:Update(dt)
		healthRegenEmitter:Update(dt)
		staminaRegenEmitter:Update(dt)
		parryRegenEmitter:Update(dt)

		-- Bind emitter parents to edge frames
		local hpEdge = Fusion.peek(healthEdgeRef)
		local stamEdge = Fusion.peek(staminaEdgeRef)
		local parEdge = Fusion.peek(parryEdgeRef)

		if hpEdge then
			healthChipEmitter.Parent = hpEdge
			healthRegenEmitter.Parent = hpEdge
		end
		if stamEdge then
			staminaRegenEmitter.Parent = stamEdge
		end
		if parEdge then
			parryRegenEmitter.Parent = parEdge
		end

		-- Health regen with speed lines
		if Fusion.peek(isRegenHealth) then
			local current = Fusion.peek(health)
			local newValue = math.min(MAX_HEALTH, current + GRADUAL_DRAIN_RATE * dt)
			health:set(newValue)
			healthRegenEmitter.Enabled = true
			if newValue >= MAX_HEALTH then
				isRegenHealth:set(false)
				healthRegenEmitter.Enabled = false
			end
		else
			healthRegenEmitter.Enabled = false
		end

		-- Stamina regen with speed lines
		if Fusion.peek(isRegenStamina) then
			local current = Fusion.peek(stamina)
			local newValue = math.min(MAX_STAMINA, current + GRADUAL_DRAIN_RATE * dt)
			stamina:set(newValue)
			staminaRegenEmitter.Enabled = true
			if newValue >= MAX_STAMINA then
				isRegenStamina:set(false)
				staminaRegenEmitter.Enabled = false
			end
		else
			staminaRegenEmitter.Enabled = false
		end

		-- Gradual stamina drain
		if Fusion.peek(isDrainingStamina) then
			local current = Fusion.peek(stamina)
			local newValue = math.max(0, current - GRADUAL_DRAIN_RATE * dt)
			stamina:set(newValue)
			if newValue <= 0 then
				isDrainingStamina:set(false)
			end
		end

		-- Gradual health drain
		if Fusion.peek(isDrainingHealth) then
			local current = Fusion.peek(health)
			local newValue = math.max(0, current - GRADUAL_DRAIN_RATE * dt)
			health:set(newValue)
			if newValue <= 0 then
				isDrainingHealth:set(false)
			end
		end

		-- Parry regeneration (decreases parry meter back to 0/center) with speed lines
		if Fusion.peek(isRegenParry) then
			local current = Fusion.peek(parry)
			local newValue = math.max(0, current - PARRY_REGEN_RATE * dt)
			parry:set(newValue)
			parryRegenEmitter.Enabled = true
			if newValue <= 0 then
				isRegenParry:set(false)
				parryRegenEmitter.Enabled = false
			end
		else
			parryRegenEmitter.Enabled = false
		end
	end)

	-- Main UI
	local ui = scope:New "Frame" {
		Parent = target,
		Name = "PlayerBars",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0.5, -1.5),
		[Children] = {
			-- The actual player bars
			scope:New "Frame" {
				Name = "Frame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Position = framePosition,
				Size = UDim2.fromOffset(572, 127),
				[Children] = {
					-- Frame overlay image
					scope:New "ImageLabel" {
						Name = "ImageLabel",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						ClipsDescendants = true,
						Image = "rbxassetid://105685114510712",
						Position = UDim2.fromScale(-0.0035, 0.126),
						Size = UDim2.fromOffset(572, 95),
					},

					-- Health Bar (right-to-left using UIGradient offset)
					scope:New "ImageLabel" {
						Name = "HP",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://139839835048778",
						ImageColor3 = scope:Computed(function(use)
							local flash = use(healthFlashSpring)
							local blink = use(lowHealthBlink)
							-- Combine flash (damage) and blink (low health) effects
							local combinedEffect = math.max(flash, blink * 0.6) -- blink is subtler
							return Color3.fromRGB(255, 0 + (255 * combinedEffect), 0 + (255 * combinedEffect))
						end),
						ImageTransparency = 0.4,
						Position = UDim2.fromScale(0.0122, 0.305),
						ScaleType = Enum.ScaleType.Crop,
						Size = UDim2.fromOffset(555, 48),
						ZIndex = -1,
						[Ref] = healthBarRef,
						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Offset = healthGradientOffset,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 1),
									NumberSequenceKeypoint.new(0.0299, 0),
									NumberSequenceKeypoint.new(0.961, 0),
									NumberSequenceKeypoint.new(1, 1),
								}),
							},
							-- Health text label (fades in on hover)
							scope:New "TextLabel" {
								Name = "HealthText",
								AnchorPoint = Vector2.new(0, 0.5),
								Position = UDim2.fromScale(0.03, 0.5),
								Size = UDim2.fromScale(0.94, 1),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use)
									return string.format("%.0f / %.0f", use(healthSpring), use(maxHealth))
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextTransparency = healthTextTransparency,
								TextSize = 11,
								FontFace = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
								TextXAlignment = Enum.TextXAlignment.Left,
								TextStrokeTransparency = scope:Computed(function(use)
									return 0.5 + (use(healthTextTransparency) * 0.5)
								end),
								ZIndex = 5,
							},
							-- Edge frame for particle emission
							scope:New "Frame" {
								Name = "HealthEdge",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = healthEdgePosition,
								Size = UDim2.fromOffset(10, 48),
								[Ref] = healthEdgeRef,
							},
							-- Hover detection overlay
							scope:New "TextButton" {
								Name = "HoverDetect",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "",
								ZIndex = 10,
								[OnEvent "MouseEnter"] = function()
									isHoveringHealth:set(true)
								end,
								[OnEvent "MouseLeave"] = function()
									isHoveringHealth:set(false)
								end,
							},
						},
					},

					-- Health Bar Background
					scope:New "ImageLabel" {
						Name = "HPBG",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://73041928160337",
						Position = UDim2.fromScale(0.0122, 0.305),
						Size = UDim2.fromOffset(555, 48),
						ZIndex = -3,
					},

					-- Parry Bar (center-outward using UIGradient transparency)
					scope:New "ImageLabel" {
						Name = "Parry",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://139839835048778",
						ImageColor3 = Color3.fromRGB(255, 200, 50),
						Position = UDim2.fromScale(0.166, 0.173),
						ScaleType = Enum.ScaleType.Crop,
						Size = UDim2.fromOffset(375, 16),
						ZIndex = -1,
						[Ref] = parryBarRef,
						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Transparency = parryTransparency,
							},
							-- Edge frame for particle emission
							scope:New "Frame" {
								Name = "ParryEdge",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = parryEdgePosition,
								Size = UDim2.fromOffset(10, 16),
								[Ref] = parryEdgeRef,
							},
						},
					},

					-- Parry Bar Background
					scope:New "ImageLabel" {
						Name = "ParryBG",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://99303213937982",
						Position = UDim2.fromScale(0.166, 0.173),
						Size = UDim2.fromOffset(375, 16),
						ZIndex = -2,
					},

					-- Stamina Bar (right-to-left using UIGradient offset)
					scope:New "ImageLabel" {
						Name = "Stamina",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://139839835048778",
						ImageColor3 = Color3.fromRGB(85, 255, 139),
						Position = UDim2.fromScale(0.0997, 0.683),
						ScaleType = Enum.ScaleType.Crop,
						Size = UDim2.fromOffset(456, 24),
						ZIndex = -1,
						[Ref] = staminaBarRef,
						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Offset = staminaGradientOffset,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 1),
									NumberSequenceKeypoint.new(0.0299, 0),
									NumberSequenceKeypoint.new(0.961, 0),
									NumberSequenceKeypoint.new(1, 1),
								}),
							},
							-- Stamina text label (fades in on hover)
							scope:New "TextLabel" {
								Name = "StaminaText",
								AnchorPoint = Vector2.new(0, 0.5),
								Position = UDim2.fromScale(0.03, 0.5),
								Size = UDim2.fromScale(0.94, 1),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use)
									return string.format("%.0f / %.0f", use(staminaSpring), use(maxStamina))
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextTransparency = staminaTextTransparency,
								TextSize = 10,
								FontFace = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
								TextXAlignment = Enum.TextXAlignment.Left,
								TextStrokeTransparency = scope:Computed(function(use)
									return 0.5 + (use(staminaTextTransparency) * 0.5)
								end),
								ZIndex = 5,
							},
							-- Edge frame for particle emission
							scope:New "Frame" {
								Name = "StaminaEdge",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = staminaEdgePosition,
								Size = UDim2.fromOffset(10, 24),
								[Ref] = staminaEdgeRef,
							},
							-- Hover detection overlay
							scope:New "TextButton" {
								Name = "HoverDetect",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "",
								ZIndex = 10,
								[OnEvent "MouseEnter"] = function()
									isHoveringStamina:set(true)
								end,
								[OnEvent "MouseLeave"] = function()
									isHoveringStamina:set(false)
								end,
							},
						},
					},

					-- Stamina Bar Background
					scope:New "ImageLabel" {
						Name = "StaminaBG",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://80095944992641",
						Position = UDim2.fromScale(0.0997, 0.683),
						Size = UDim2.fromOffset(456, 18),
						ZIndex = -2,
					},
				},
			},
		}
	}

	-- Cleanup function
	local function cleanup()
		connection:Disconnect()
		healthChipEmitter:Destroy()
		healthRegenEmitter:Destroy()
		staminaRegenEmitter:Destroy()
		parryRegenEmitter:Destroy()
	end

	-- Add cleanup to scope
	table.insert(scope, cleanup)

	-- Return API for external updates
	return {
		frame = ui,
		healthValue = health,
		maxHealthValue = maxHealth,
		staminaValue = stamina,
		maxStaminaValue = maxStamina,
		parryValue = parry,
		maxParryValue = maxParry,
		moneyValue = money,
		scope = scope,

		-- Flags for external control
		isDrainingStamina = isDrainingStamina,
		isDrainingHealth = isDrainingHealth,
		isRegenParry = isRegenParry,
		isRegenHealth = isRegenHealth,
		isRegenStamina = isRegenStamina,

		-- Reset function for respawn
		reset = function()
			health:set(MAX_HEALTH)
			maxHealth:set(MAX_HEALTH)
			stamina:set(MAX_STAMINA)
			maxStamina:set(MAX_STAMINA)
			parry:set(0)
			maxParry:set(MAX_PARRY)
			money:set(0)
			prevHealth = MAX_HEALTH
			isDrainingStamina:set(false)
			isDrainingHealth:set(false)
			isRegenParry:set(false)
			isRegenHealth:set(false)
			isRegenStamina:set(false)
			blinkTime:set(0)
			lowHealthBlink:set(0)
			healthRegenEmitter.Enabled = false
			staminaRegenEmitter.Enabled = false
			parryRegenEmitter.Enabled = false
		end,
	}
end
