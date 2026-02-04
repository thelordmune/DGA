local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Library = require(ReplicatedStorage.Modules.Library)
local Tooltip = require(ReplicatedStorage.Client.Components.Tooltip)
local SkillStats = require(ReplicatedStorage.Modules.Utils.SkillStats)
local InventoryState = require(ReplicatedStorage.Client.InventoryState)

local Children, scoped, peek, Computed, Spring, Value, OnEvent =
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Computed, Fusion.Spring, Fusion.Value, Fusion.OnEvent

return function(scope, props: {
	slotNumber: number,
	itemName: string | Fusion.Computed<string>?,
	itemIcon: string | Fusion.Computed<string>?,
	character: Model?,
	Parent: Instance,
})
	local slotNumber = props.slotNumber
	local itemName = props.itemName or ""
	local itemIcon = props.itemIcon or "rbxassetid://71291612556381"
	local character = props.character
	local parent = props.Parent

	---- print(`[HotbarButton] Creating button for slot {slotNumber}`)
	---- print(`[HotbarButton] Parent: {parent}`)
	---- print(`[HotbarButton] Character: {character}`)
	---- print(`[HotbarButton] ItemName type: {typeof(itemName)}`)
	if typeof(itemName) == "table" and itemName.get then
		---- print(`[HotbarButton] ItemName Computed value: {peek(itemName)}`)
	else
		---- print(`[HotbarButton] ItemName string value: {itemName}`)
	end

	-- Reactive values for cooldown
	local cooldownTimer = scope:Value(0)
	local maxCooldownTime = scope:Value(1) -- Set once when cooldown starts
	local cooldownActive = scope:Value(false)
	local unlocking = scope:Value(false)
	local flash = scope:Value(false)

	-- OPTIMIZED: Throttle cooldown updates to 10 Hz instead of every frame
	local COOLDOWN_UPDATE_INTERVAL = 0.1 -- 10 Hz
	local cooldownUpdateAcc = 0

	-- Update cooldown at throttled rate using Library (old cooldown system)
	local cooldownConnection = RunService.RenderStepped:Connect(function(dt)
		if not character then return end

		-- OPTIMIZED: Throttle updates to 10 Hz
		cooldownUpdateAcc = cooldownUpdateAcc + dt
		if cooldownUpdateAcc < COOLDOWN_UPDATE_INTERVAL then
			return
		end
		cooldownUpdateAcc = 0

		-- Get the current item name (handle both Computed and string values)
		local currentItemName = itemName
		if typeof(itemName) == "table" and itemName.get then
			currentItemName = peek(itemName) or ""
		end

		local remaining = Library.GetCooldownTime(character, currentItemName)

		if remaining > 0 then
			-- First time cooldown is active, set the max time
			if not peek(cooldownActive) then
				maxCooldownTime:set(remaining)
				-- Start unlock transition when cooldown completes
				task.delay(remaining, function()
					unlocking:set(true)
					task.wait(0.3)
					unlocking:set(false)
					-- Flash effect after unlock animation completes
					flash:set(true)
					task.wait(0.1)
					flash:set(false)
				end)
			end
			cooldownActive:set(true)
			cooldownTimer:set(remaining)
		else
			cooldownActive:set(false)
			cooldownTimer:set(0)
		end
	end)

	-- Cleanup cooldown connection when scope is destroyed (tooltip cleanup added after tooltip vars are defined)
	table.insert(scope, function()
		if cooldownConnection then
			cooldownConnection:Disconnect()
			cooldownConnection = nil
			---- print(`[HotbarButton] 🧹 Disconnected cooldown connection for slot {slotNumber}`)
		end
	end)

	-- Calculate gradient progress (0 to 1)
	local gradientProgress = scope:Computed(function(use)
		local currentTime = use(cooldownTimer)
		local maxTime = use(maxCooldownTime)
		return 1 - (currentTime / maxTime) -- Inverted so it goes from 0 to 1 as timer decreases
	end)

	-- Determine key label
	local keyLabel = if slotNumber <= 7 then tostring(slotNumber)
		elseif slotNumber == 8 then "Z"
		elseif slotNumber == 9 then "X"
		elseif slotNumber == 10 then "C"
		else tostring(slotNumber)

	---- print(`[HotbarButton] Creating ImageButton for slot {slotNumber} with key label: {keyLabel}`)

	-- Tooltip system setup
	local tooltipFrame = nil
	local tooltipScope = nil
	local tooltipStarted = scope:Value(false)

	-- Cleanup tooltip scope when parent scope is destroyed (prevents memory leak if player dies while hovering)
	table.insert(scope, function()
		if tooltipScope then
			tooltipScope:doCleanup()
			tooltipScope = nil
			tooltipFrame = nil
			---- print(`[HotbarButton] 🧹 Cleaned up tooltip scope for slot {slotNumber}`)
		end
	end)

	local button

	button = scope:New "ImageButton" {
		Name = "HotbarButton",
		Active = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Image = "rbxassetid://97365531047745",
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		ScaleType = Enum.ScaleType.Crop,
		Selectable = false,
		Size = UDim2.fromOffset(60, 60),
		ZIndex = 100,
		Parent = parent,

		[OnEvent "MouseEnter"] = function()
			local currentItemName = itemName
		if typeof(itemName) == "table" and itemName.get then
			currentItemName = peek(itemName) or ""
		end

		if not currentItemName or currentItemName == "" then return end

		-- Get skill stats
		local stats = SkillStats.GetStats(currentItemName)

		-- Create tooltip scope
		tooltipScope = Fusion.scoped(Fusion, {})

		-- Create tooltip frame positioned above the button
		tooltipFrame = Tooltip(tooltipScope, {
			Parent = button.Parent.Parent, -- Parent to ScreenGui
			Started = tooltipStarted,
			Stats = stats,
			SourceButton = button,
		})

		-- Trigger animation
		tooltipStarted:set(true)
		end,
		[OnEvent "MouseLeave"] = function()
			tooltipStarted:set(false)
		task.wait(0.5) -- Wait for animation to finish

		if tooltipScope then
			tooltipScope:doCleanup()
		end
		tooltipFrame = nil
		tooltipScope = nil
		end,
		[OnEvent "MouseButton1Click"] = function()
			-- Check if an inventory item is selected for hotbar assignment
			local selectedSlot = InventoryState.getSelectedSlot()
			if selectedSlot then
				-- An inventory item is selected - handle the hotbar click
				InventoryState.handleHotbarClick(slotNumber)
			end
		end,

		[Children] = {
			-- Skill/Item icon display
			scope:New "ImageLabel" {
				Name = "SkillIcon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.7, 0.7),
				ZIndex = 99,
				Image = scope:Computed(function(use)
					if typeof(itemIcon) == "table" and itemIcon.get then
						return use(itemIcon) or "rbxassetid://71291612556381"
					else
						return itemIcon or "rbxassetid://71291612556381"
					end
				end),
				ImageTransparency = scope:Computed(function(use)
					-- Hide icon when there's no item
					local currentIcon
					if typeof(itemIcon) == "table" and itemIcon.get then
						currentIcon = use(itemIcon)
					else
						currentIcon = itemIcon
					end
					-- Hide if it's the default/empty icon
					if not currentIcon or currentIcon == "" or currentIcon == "rbxassetid://71291612556381" then
						return 1
					end
					return 0
				end),
			},

			-- Key indicator
			scope:New "ImageLabel" {
				Name = "KeyIndicator",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://71291612556381",
				ImageColor3 = Color3.fromRGB(168, 168, 168),
				Position = UDim2.fromScale(0.5, 0.9),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(0.3, 0.3),
				SliceCenter = Rect.new(5, 5, 19, 23),
				ZIndex = 101,

				[Children] = {
					scope:New "Frame" {
						Name = "Frame",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(29, 29, 29),
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.8, 0.84),
						ZIndex = 100,
						Visible = false
					},

					scope:New "TextLabel" {
						Name = "TextLabel",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json"),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
						Text = keyLabel,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 15,
						TextStrokeTransparency = 0.3,
						ZIndex = 100000,
					},
				}
			},

			-- Item name label with color transition
			scope:New "TextLabel" {
				Name = "ItemLabel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/Sarpanch.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.623, 0.696),
				Text = scope:Computed(function(use)
					-- Create a new Computed value owned by this scope
					if typeof(itemName) == "table" and itemName.get then
						local name = use(itemName)
						return name
					else
						return itemName or ""
					end
				end),
				TextColor3 = scope:Spring(
					scope:Computed(function(use)
						-- Red when on cooldown, white when ready
						if use(cooldownActive) then
							return Color3.fromRGB(255, 0, 0)
						else
							return Color3.fromRGB(255, 255, 255)
						end
					end),
					25,
					0.8
				),
				TextTransparency = scope:Spring(
					scope:Computed(function(use)
						-- Red when on cooldown, white when ready
						if use(cooldownActive) then
							return .5
						else
							return 0
						end
					end),
					25,
					0.8
				),
				TextScaled = true,
				TextSize = 14,
				TextWrapped = true,
				ZIndex = 10000,
			},

			-- Cooldown overlay with lock icon
			scope:New "ImageLabel" {
				Name = "CooldownOverlay",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://97431821945241",
				Position = UDim2.fromScale(0.1, 0.1),
				Size = UDim2.fromScale(0.806, 0.796),
				ZIndex = 5,
				ScaleType = Enum.ScaleType.Crop,
				

				[Children] = {
					scope:New "ImageLabel" {
						Name = "Lock",
						BackgroundTransparency = 1,
						Image = "rbxassetid://8445472085",
						ImageRectOffset = scope:Spring(
							scope:Computed(function(use)
								local currentTimer = use(cooldownTimer)
								local isUnlocking = use(unlocking)
								-- Show unlocked during unlocking transition or after cooldown
								if isUnlocking or currentTimer <= 0 then
									return Vector2.new(104, 604)
								else
									return Vector2.new(4, 604)
								end
							end),
							25,
							0.8
						),
						ImageRectSize = Vector2.new(96, 96),
						Position = UDim2.fromScale(0.1, 0.1),
						Size = UDim2.fromScale(0.8, 0.8),
						ImageTransparency = scope:Spring(
							scope:Computed(function(use)
								local currentTimer = use(cooldownTimer)
								local isUnlocking = use(unlocking)

								-- Fade away after unlocking and flashing
								if currentTimer <= 0 and not isUnlocking and not use(flash) then
									return 1
								end

								-- Dim during transition to make it smooth
								if isUnlocking then
									return 0.9
								end

								return 0
							end),
							35,
							1
						),
						ZIndex = 10002,

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Rotation = 90,
								Color = scope:Spring(
									scope:Computed(function(use)
										if use(flash) then
											return ColorSequence.new({
												ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
												ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 0)),
												ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
											})
										else
											return ColorSequence.new({
												ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
												ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
											})
										end
									end),
									50,
									1
								),
								Transparency = scope:Computed(function(use)
									if not use(cooldownActive) then
										return NumberSequence.new(1) -- Completely invisible when not on cooldown
									end
									local progress = use(gradientProgress)
									local cutoff = math.clamp(progress, 0, 1)
									return NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0),
										NumberSequenceKeypoint.new(math.max(0, cutoff - 0.001), 0),
										NumberSequenceKeypoint.new(math.min(1, cutoff + 0.001), 1),
										NumberSequenceKeypoint.new(1, 1),
									})
								end),
							},
						}
					},
				}
			},
		}
	}

	-- Tooltip functions (defined after button creation so button is available)

	local function showTooltip()
		if tooltipFrame then return end -- Already showing

		-- Get current item name
		
	end

	-- Hide tooltip when not hovering
	local function hideTooltip()
		-- if not tooltipFrame then return end

		tooltipStarted:set(false)
		task.wait(0.5) -- Wait for animation to finish

		if tooltipScope then
			tooltipScope:doCleanup()
		end
		tooltipFrame = nil
		tooltipScope = nil
	end

	-- Connect hover events
	-- button.MouseEnter:Connect(function()
	-- 	showTooltip()
	-- end)

	-- button.MouseLeave:Connect(function()
	-- 	hideTooltip()
	-- end)

	---- print(`[HotbarButton] ✅ Button created for slot {slotNumber}: {button}`)
	return button
end

