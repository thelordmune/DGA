local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local TweenService = game:GetService("TweenService")
local SlotMachineText = require(ReplicatedStorage.Modules.Utils.TextStyles.SlotMachine) -- Your new module

local Children, scoped, peek, out, OnEvent, Value, Tween = 
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.Value, Fusion.Tween

local TInfo = TweenInfo.new(.1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0, false)

return function(scope, props: {
	Parent: Instance,
	Started: any,
	Stats: {Damage: number, Cooldown: number, Augments: number},
	SourceButton: Instance?,
})
    local parent = props.Parent
    local started = props.Started
    local sourceButton = props.SourceButton
    local textinit = scope:Value(false)
    local statsData = props.Stats or {Damage = 0, Cooldown = 0, Augments = 0}

    local damageLabel = nil
	local cooldownLabel = nil
	local augmentsLabel = nil

	local startOb = scope:Observer(started)
    local tsk
	local disconnect = startOb:onChange(function()
		if peek(started) == true then
			task.wait(1)
			textinit:set(true)

			-- Animate each label one by one
			tsk =task.spawn(function()
				task.wait(.2)
				if damageLabel then
					SlotMachineText(damageLabel, string.format("Damage: %d", statsData.Damage), {
						duration = .15,
						charDelay = 0.015,
						fadeInTime = 0.05,
					})
				end

				task.wait(.05) -- Wait for damage to finish

				if cooldownLabel then
					SlotMachineText(cooldownLabel, string.format("Cooldown: %d", statsData.Cooldown), {
						duration = .15,
						charDelay = 0.015,
						fadeInTime = 0.05,
					})
				end

				task.wait(.05) -- Wait for cooldown to finish

				if augmentsLabel then
					SlotMachineText(augmentsLabel, string.format("Augments: %d", statsData.Augments), {
						duration = .15,
						charDelay = 0.015,
						fadeInTime = 0.05,
					})
				end
			end)
        else
            textinit:set(false)
            task.cancel(tsk)
		end
	end)

	--task.delay(3, function()
	--	started:set(true)
	--end)

	-- Create individual TextLabels
	damageLabel = scope:New "TextLabel" {
		Name = "DamageLabel",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.097, 0.35),
		Size = UDim2.fromOffset(115, 15),
		Text = "",
		Font = Font.new("rbxassetid://12187607287", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextTransparency = scope:Tween(
			scope:Computed(function(use)
				return if use(textinit) then 0 else 1
			end),
			TInfo
		),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 10000001,
	}

	cooldownLabel = scope:New "TextLabel" {
		Name = "CooldownLabel",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.097, 0.50),
		Size = UDim2.fromOffset(115, 15),
		Text = "",
		Font = Font.new("rbxassetid://12187607287", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextTransparency = scope:Tween(
			scope:Computed(function(use)
				return if use(textinit) then 0 else 1
			end),
			TInfo
		),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 10000001,
	}

	augmentsLabel = scope:New "TextLabel" {
		Name = "AugmentsLabel",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.097, 0.65),
		Size = UDim2.fromOffset(115, 15),
		Text = "",
		Font = Font.new("rbxassetid://12187607287", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextTransparency = scope:Tween(
			scope:Computed(function(use)
				return if use(textinit) then 0 else 1
			end),
			TInfo
		),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 10000001,
	}

	scope:New "Frame" {
		Parent = parent,
		Name = "Frame",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = scope:Spring(
			scope:Computed(function(use)
				if sourceButton then
					-- Position above the source button
					local buttonPos = sourceButton.AbsolutePosition
					local buttonSize = sourceButton.AbsoluteSize
					local parentSize = parent.AbsoluteSize

					-- Calculate position above button with 10px offset
					local x = (buttonPos.X + buttonSize.X / 2) / parentSize.X
					local y = (buttonPos.Y + 30) / parentSize.Y

					return if use(started) then UDim2.fromScale(x, y) else UDim2.fromScale(x, y)
				else
					return if use(started) then UDim2.fromScale(0.5, 0.8) else UDim2.fromScale(0.5, 0.8)
				end
			end),
			30,
			9
		),
		Size = scope:Spring(
			scope:Computed(function(use)
				return if use(started) then UDim2.fromOffset(143, 74) else UDim2.fromOffset(0, 74)
			end),
			30,
			.6
		),
		ZIndex = 1000000,

		[Children] = {
			scope:New "TextLabel" {
				Name = "Stats",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxassetid://12187607287",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.212, 0.0624),
				Size = UDim2.fromOffset(81, 19),
				Text = "STATS",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				TextTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(textinit) then 0 else 1
					end),
					TInfo
				),
                ZIndex = 1000001,
			},

			-- Add the three text labels
			damageLabel,
			cooldownLabel,
			augmentsLabel,

			scope:New "ImageLabel" {
				Name = "Background",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://85774200010476",
				Position = UDim2.fromScale(0, 0.00695),
				Size = UDim2.fromScale(0.993, 0.993),
				ZIndex = 1000000,

				[Children] = {
					scope:New "ImageLabel" {
						Name = "Border",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Image = "rbxassetid://106093959266071",
						Position = UDim2.fromScale(0, 0.00694),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromScale(0.993, 0.993),
						SliceCenter = Rect.new(316, 202, 745, 340),
						SliceScale = 0.5,
                        ZIndex = 1000000,

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(141, 130, 91)),
									ColorSequenceKeypoint.new(0.25, Color3.fromRGB(0, 0, 0)),
									ColorSequenceKeypoint.new(0.75, Color3.fromRGB(0, 0, 0)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(141, 130, 91)),
								}),
                                ZIndex = 1000000,
							},
						}
					},
				}
			},
		}
	}
end