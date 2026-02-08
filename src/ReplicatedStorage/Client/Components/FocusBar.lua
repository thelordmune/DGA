--[[
	FocusBar Component

	A vertical focus bar that floats next to the character in 3D space via BillboardGui.
	- Fades in when focus > 0, fades out when focus == 0
	- White fill bar with gradient swipe effect
	- Percentage label
	- Shake on threshold crossings (50%, 100%)

	Usage:
		local focusBarData = FocusBar()
		focusBarData.focusValue:set(0.5) -- 50% focus
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Modules.Fusion)

local Children = Fusion.Children
local Ref = Fusion.Ref

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(0, 0, 0)

local JURA_BOLD = Font.new(
	"rbxasset://fonts/families/Jura.json",
	Enum.FontWeight.Bold,
	Enum.FontStyle.Normal
)

-- Bar geometry
local BAR_WIDTH = 6
local BAR_HEIGHT = 60
local BAR_BG_WIDTH = 5

-- Fill tween
local FILL_TWEEN_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Shake
local IMPULSE_AMPLITUDE = 2
local IMPULSE_DECAY = 8

-- Gradient swipe
local WIPE_DURATION = 0.5
local WIPE_BASE_INTERVAL = 1.2
local WIPE_MIN_INTERVAL = 0.3

-- Fade
local FADE_SPRING_SPEED = 12
local FADE_SPRING_DAMPING = 1

--------------------------------------------------------------------------------
-- Component
--------------------------------------------------------------------------------

return function()
	local scope = Fusion:scoped()

	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 5)

	if not root then
		warn("[FocusBar] Could not find HumanoidRootPart")
		return nil
	end

	-- Focus value (0 to 1)
	local focusValue = scope:Value(0)

	-- Tweened fill (NumberValue driven by TweenService for smooth bar movement)
	local fillNumberValue = Instance.new("NumberValue")
	fillNumberValue.Value = 0
	local currentTween = nil

	-- Visibility: bar is visible when focus > 0
	local isVisible = scope:Value(false)
	local visibilitySpring = scope:Spring(
		scope:Computed(function(use)
			return use(isVisible) and 1 or 0
		end),
		FADE_SPRING_SPEED,
		FADE_SPRING_DAMPING
	)

	-- Refs
	local fillBarRef = scope:Value(nil)
	local percentLabelRef = scope:Value(nil)
	local barAssemblyRef = scope:Value(nil)
	local gradientRef = scope:Value(nil)

	-- Shake state
	local shakeTime = 0
	local impulseTimer = 0
	local prevFillForThreshold = 0

	-- Gradient wipe state
	local wipeTimer = 0
	local wipeActive = false
	local wipeProgress = 0

	----------------------------------------------------------------------------
	-- Tween fill to target
	----------------------------------------------------------------------------

	local function tweenFillTo(target_val)
		if currentTween then
			currentTween:Cancel()
		end
		currentTween = TweenService:Create(fillNumberValue, FILL_TWEEN_INFO, {
			Value = target_val,
		})
		currentTween:Play()
	end

	----------------------------------------------------------------------------
	-- Observer: react to focusValue changes
	----------------------------------------------------------------------------

	scope:Observer(focusValue):onChange(function()
		local newVal = Fusion.peek(focusValue)
		tweenFillTo(math.clamp(newVal, 0, 1))

		if newVal > 0 then
			isVisible:set(true)
		else
			isVisible:set(false)
		end
	end)

	----------------------------------------------------------------------------
	-- Default gradient transparency
	----------------------------------------------------------------------------

	local swipeTransDefault = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.1, 0.5),
		NumberSequenceKeypoint.new(0.25, 0),
		NumberSequenceKeypoint.new(1, 0),
	})

	----------------------------------------------------------------------------
	-- Heartbeat
	----------------------------------------------------------------------------

	local connection = RunService.Heartbeat:Connect(function(dt)
		local fillT = fillNumberValue.Value
		local visT = Fusion.peek(visibilitySpring)

		----------------------------------------------------------------
		-- Threshold crossing detection -> impulse shake
		----------------------------------------------------------------
		local crossedUp50 = prevFillForThreshold < 0.5 and fillT >= 0.5
		local crossedUp100 = prevFillForThreshold < 1.0 and fillT >= 1.0

		if crossedUp50 or crossedUp100 then
			impulseTimer = 1.0
		end

		prevFillForThreshold = fillT

		----------------------------------------------------------------
		-- Shake
		----------------------------------------------------------------
		shakeTime += dt
		local assembly = Fusion.peek(barAssemblyRef)
		if assembly then
			local sx, sy = 0, 0

			if impulseTimer > 0 then
				impulseTimer = math.max(0, impulseTimer - dt * IMPULSE_DECAY)
				local amp = IMPULSE_AMPLITUDE * impulseTimer
				sx += math.sin(shakeTime * 45) * amp
				sy += math.cos(shakeTime * 38) * amp * 0.7
			end

			assembly.Position = UDim2.new(0.5, sx, 0.5, sy)
		end

		----------------------------------------------------------------
		-- Transparency driven by visibility spring
		----------------------------------------------------------------
		local containerAlpha = 1 - visT

		local pLabel = Fusion.peek(percentLabelRef)
		if pLabel then
			local dv = math.floor(fillT * 100 + 0.5)
			pLabel.Text = dv .. "%"
			pLabel.TextTransparency = containerAlpha
		end

		----------------------------------------------------------------
		-- Fill bar size
		----------------------------------------------------------------
		local fillBar = Fusion.peek(fillBarRef)
		if fillBar then
			local clampedFill = math.clamp(fillT, 0, 1)
			local h = math.round(BAR_HEIGHT * clampedFill)
			fillBar.Size = UDim2.fromOffset(BAR_WIDTH, h)
			fillBar.Position = UDim2.new(0, 0, 1, -h)
			fillBar.ImageTransparency = containerAlpha
		end

		----------------------------------------------------------------
		-- Gradient swipe
		----------------------------------------------------------------
		wipeTimer += dt
		local grad = Fusion.peek(gradientRef)
		if grad then
			local t = math.clamp(fillT, 0, 1)
			local interval = WIPE_BASE_INTERVAL - (WIPE_BASE_INTERVAL - WIPE_MIN_INTERVAL) * t

			if not wipeActive and wipeTimer >= interval and fillT > 0.05 then
				wipeActive = true
				wipeProgress = 0
				wipeTimer = 0
			end

			if wipeActive then
				wipeProgress += dt / WIPE_DURATION
				if wipeProgress >= 1 then
					wipeActive = false
					wipeProgress = 0
					grad.Transparency = swipeTransDefault
				else
					local center = wipeProgress
					local halfW = 0.08
					local bandStart = math.max(0.001, center - halfW)
					local bandEnd = math.min(0.999, center + halfW)

					local keypoints = {}
					if bandStart > 0.02 then
						table.insert(keypoints, NumberSequenceKeypoint.new(0, 0.8))
						if bandStart > 0.12 then
							table.insert(keypoints, NumberSequenceKeypoint.new(0.1, 0.5))
						end
						if bandStart > 0.26 then
							table.insert(keypoints, NumberSequenceKeypoint.new(0.25, 0))
						end
						table.insert(keypoints, NumberSequenceKeypoint.new(bandStart, 0))
					else
						table.insert(keypoints, NumberSequenceKeypoint.new(0, 0.8))
					end
					table.insert(keypoints, NumberSequenceKeypoint.new(math.max(bandStart + 0.001, center), 0.35))
					if bandEnd < 0.998 then
						table.insert(keypoints, NumberSequenceKeypoint.new(bandEnd, 0))
						table.insert(keypoints, NumberSequenceKeypoint.new(1, 0))
					else
						table.insert(keypoints, NumberSequenceKeypoint.new(1, 0.35))
					end

					grad.Transparency = NumberSequence.new(keypoints)
				end
			end
		end
	end)

	----------------------------------------------------------------------------
	-- UI
	----------------------------------------------------------------------------

	-- Bar assembly (the actual bar content)
	local barAssembly = scope:New "Frame" {
		Name = "BarAssembly",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(BAR_WIDTH + 10, BAR_HEIGHT + 18),
		BackgroundTransparency = 1,
		[Ref] = barAssemblyRef,

		[Children] = {
			-- Percentage label above bar
			scope:New "TextLabel" {
				Name = "PercentLabel",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -2),
				Size = UDim2.fromOffset(30, 12),
				BackgroundTransparency = 1,
				Text = "0%",
				TextColor3 = WHITE,
				TextSize = 8,
				FontFace = JURA_BOLD,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTransparency = 1,
				ZIndex = 5,
				TextStrokeTransparency = 0.5,
				TextStrokeColor3 = BLACK,
				[Ref] = percentLabelRef,
			},

			-- Bar container (clips the fill)
			scope:New "Frame" {
				Name = "BarContainer",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 0),
				Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
				BackgroundTransparency = 1,
				ClipsDescendants = true,

				[Children] = {
					-- Background
					scope:New "Frame" {
						Name = "BG",
						Position = UDim2.new(0.5, 0, 0, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundColor3 = BLACK,
						BackgroundTransparency = scope:Computed(function(use)
							return 1 - (use(visibilitySpring) * 0.6)
						end),
						BorderSizePixel = 0,
						ZIndex = 0,

						[Children] = {
							scope:New "UICorner" {
								CornerRadius = UDim.new(0, 3),
							},
						},
					},

					-- Fill bar (white, grows from bottom)
					scope:New "ImageLabel" {
						Name = "Fill",
						BackgroundColor3 = WHITE,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = "rbxassetid://130402074412508",
						ImageColor3 = WHITE,
						ImageTransparency = 1,
						Position = UDim2.new(0, 0, 1, 0),
						Size = UDim2.fromOffset(BAR_WIDTH, 0),
						ZIndex = 1,
						ClipsDescendants = true,
						[Ref] = fillBarRef,

						[Children] = {
							scope:New "UICorner" {
								CornerRadius = UDim.new(0, 3),
							},
							scope:New "UIGradient" {
								Name = "SwipeGradient",
								Transparency = swipeTransDefault,
								Rotation = 0,
								[Ref] = gradientRef,
							},
						},
					},

					-- Outline stroke
					scope:New "Frame" {
						Name = "Outline",
						Position = UDim2.new(0.5, 0, 0, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						ZIndex = 3,

						[Children] = {
							scope:New "UICorner" {
								CornerRadius = UDim.new(0, 3),
							},
							scope:New "UIStroke" {
								Color = WHITE,
								Thickness = 1,
								Transparency = scope:Computed(function(use)
									return 1 - (use(visibilitySpring) * 0.4)
								end),
							},
						},
					},
				},
			},
		},
	}

	-- BillboardGui
	local billboardGui = scope:New "BillboardGui" {
		Name = "FocusBar",
		Adornee = root,
		Size = UDim2.fromOffset(BAR_WIDTH + 10, BAR_HEIGHT + 18),
		StudsOffset = Vector3.new(1.8, 0.5, 0),
		AlwaysOnTop = false,
		MaxDistance = 50,
		Active = false,

		[Children] = {
			barAssembly,
		},
	}

	billboardGui.Parent = player.PlayerGui

	-- Update adornee on respawn
	player.CharacterAdded:Connect(function(newCharacter)
		local newRoot = newCharacter:WaitForChild("HumanoidRootPart", 5)
		if newRoot and billboardGui then
			billboardGui.Adornee = newRoot
		end
	end)

	-- Cleanup
	local function cleanup()
		connection:Disconnect()
		if currentTween then currentTween:Cancel() end
		fillNumberValue:Destroy()
	end

	table.insert(scope, cleanup)

	return {
		focusValue = focusValue,
		billboardGui = billboardGui,
		scope = scope,

		cleanup = function()
			scope:doCleanup()
		end,

		reset = function()
			focusValue:set(0)
			isVisible:set(false)
			fillNumberValue.Value = 0
			impulseTimer = 0
			prevFillForThreshold = 0
			wipeActive = false
			wipeTimer = 0
		end,
	}
end
