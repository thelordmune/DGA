local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local PassivesData = require(ReplicatedStorage.Modules.PassivesData)

-- Import 2D Particle Emitter
local Emitter2D = require(ReplicatedStorage.Modules.Utils["2dEmitter"])

local Children, scoped, peek, Out, Ref, OnEvent, Value, Computed, Tween, Spring =
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.Ref, Fusion.OnEvent, Fusion.Value, Fusion.Computed, Fusion.Tween, Fusion.Spring

local TInfoFast = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0)

-- Button image (same as confirm button)
local BUTTON_IMAGE = "rbxassetid://118973584856362"

-- Circle color (orange-pink gradient inspired)
local CIRCLE_COLOR = Color3.fromRGB(200, 120, 100)

-- Base size for the circle (will use aspect ratio to keep it perfect)
local CIRCLE_BASE_SIZE = 460

-- Alchemy circle configuration - elaborate FMA style
local CIRCLE_CONFIG = {
	-- Ring slots for passives
	rings = {
		{ radius = 0, slots = 1 },           -- Center node (keystone)
		{ radius = 0.12, slots = 4 },        -- Inner ring around center
		{ radius = 0.22, slots = 6 },        -- Middle ring
		{ radius = 0.34, slots = 8 },        -- Outer middle ring
		{ radius = 0.44, slots = 12 },       -- Outer ring
	},
	-- Node size based on ring (inner = larger)
	nodeSizes = { 65, 50, 45, 40, 36 },
	-- Total placeholder slots per ring
	totalSlots = { 1, 4, 6, 8, 12 },
}

-- Helper function to format requirements text
local function formatRequirements(requirements)
	if not requirements or next(requirements) == nil then return "No requirements" end

	local parts = {}

	if requirements.prerequisitePassives and #requirements.prerequisitePassives > 0 then
		table.insert(parts, "Requires: " .. table.concat(requirements.prerequisitePassives, ", "))
	end

	if requirements.weapon then
		table.insert(parts, "Weapon: " .. requirements.weapon)
	end

	if requirements.alchemy then
		table.insert(parts, "Alchemy: " .. requirements.alchemy)
	end

	if requirements.stats then
		local statParts = {}
		for stat, value in pairs(requirements.stats) do
			table.insert(statParts, stat .. " " .. value)
		end
		if #statParts > 0 then
			table.insert(parts, "Stats: " .. table.concat(statParts, ", "))
		end
	end

	if requirements.level then
		table.insert(parts, "Level: " .. requirements.level)
	end

	if #parts == 0 then
		return "No requirements"
	end

	return table.concat(parts, "\n")
end

-- Helper function to format effects text
local function formatEffects(effects)
	if not effects then return "" end

	local parts = {}
	for effectName, value in pairs(effects) do
		if type(value) == "number" then
			if value > 0 and value < 1 then
				table.insert(parts, "+" .. math.floor(value * 100) .. "% " .. effectName)
			elseif value < 0 then
				table.insert(parts, math.floor(value * 100) .. "% " .. effectName)
			else
				table.insert(parts, "+" .. value .. " " .. effectName)
			end
		elseif type(value) == "boolean" and value then
			table.insert(parts, effectName)
		end
	end

	return table.concat(parts, ", ")
end

-- Generate positions for alchemy circle layout with all slots filled
local function generateAlchemyCirclePositions()
	local positions = {}
	local posIndex = 1

	for ringIndex, ring in ipairs(CIRCLE_CONFIG.rings) do
		local totalSlots = CIRCLE_CONFIG.totalSlots[ringIndex]
		-- Offset so nodes don't align perfectly across rings
		local angleOffset = -math.pi / 2  -- Start from top
		if ringIndex == 2 then angleOffset = angleOffset + math.pi / 4 end
		if ringIndex == 4 then angleOffset = angleOffset + math.pi / 8 end

		for slot = 1, totalSlots do
			local angle = ((slot - 1) / totalSlots) * math.pi * 2 + angleOffset
			local x = 0.5 + math.cos(angle) * ring.radius
			local y = 0.5 + math.sin(angle) * ring.radius

			positions[posIndex] = {
				position = UDim2.fromScale(x, y),
				ring = ringIndex,
				angle = angle,
				slot = slot,
			}
			posIndex = posIndex + 1
		end
	end

	return positions
end

-- Create a perfect circle ring (uses UIAspectRatioConstraint)
local function createPerfectCircle(scope, radiusScale, thickness, showTrigger, isDashed)
	local size = radiusScale * 2

	return scope:New "Frame" {
		Name = "Circle_" .. tostring(radiusScale),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(size, size),

		[Children] = {
			scope:New "UIAspectRatioConstraint" {
				AspectRatio = 1,
				AspectType = Enum.AspectType.ScaleWithParentSize,
				DominantAxis = Enum.DominantAxis.Width,
			},
			scope:New "UICorner" {
				CornerRadius = UDim.new(0.5, 0),
			},
			scope:New "UIStroke" {
				Color = CIRCLE_COLOR,
				Thickness = thickness,
				Transparency = scope:Tween(
					scope:Computed(function(use)
						return if use(showTrigger) then 0.2 else 1
					end),
					TInfoFast
				),
				LineJoinMode = Enum.LineJoinMode.Round,
			},
		}
	}
end

-- Create a line between two points (for triangles and connections)
local function createLine(scope, x1, y1, x2, y2, thickness, showTrigger, color)
	color = color or CIRCLE_COLOR
	local dx = x2 - x1
	local dy = y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	local angle = math.deg(math.atan2(dy, dx))
	local midX = (x1 + x2) / 2
	local midY = (y1 + y2) / 2

	return scope:New "Frame" {
		Name = "Line",
		BackgroundColor3 = color,
		BackgroundTransparency = scope:Tween(
			scope:Computed(function(use)
				return if use(showTrigger) then 0.2 else 1
			end),
			TInfoFast
		),
		Position = UDim2.fromScale(midX, midY),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(length, 0, 0, thickness),
		Rotation = angle,
		ZIndex = 0,
	}
end

-- Create a triangle inscribed in a circle
local function createTriangle(scope, radiusScale, rotationOffset, thickness, showTrigger)
	local lines = {}
	local points = {}

	for i = 0, 2 do
		local angle = math.rad(rotationOffset + i * 120)
		table.insert(points, {
			x = 0.5 + math.cos(angle) * radiusScale,
			y = 0.5 + math.sin(angle) * radiusScale
		})
	end

	for i = 1, 3 do
		local nextI = (i % 3) + 1
		table.insert(lines, createLine(
			scope,
			points[i].x, points[i].y,
			points[nextI].x, points[nextI].y,
			thickness,
			showTrigger
		))
	end

	return lines
end

-- Create small circles at specific positions (like the node circles in the reference)
local function createSmallCircle(scope, x, y, radiusPixels, showTrigger, filled)
	return scope:New "Frame" {
		Name = "SmallCircle",
		BackgroundColor3 = if filled then CIRCLE_COLOR else Color3.fromRGB(20, 20, 30),
		BackgroundTransparency = scope:Tween(
			scope:Computed(function(use)
				if filled then
					return if use(showTrigger) then 0.3 else 1
				else
					return if use(showTrigger) then 0.8 else 1
				end
			end),
			TInfoFast
		),
		Position = UDim2.fromScale(x, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(radiusPixels * 2, radiusPixels * 2),
		ZIndex = 1,

		[Children] = {
			scope:New "UICorner" {
				CornerRadius = UDim.new(0.5, 0),
			},
			scope:New "UIStroke" {
				Color = CIRCLE_COLOR,
				Thickness = 2,
				Transparency = scope:Tween(
					scope:Computed(function(use)
						return if use(showTrigger) then 0.2 else 1
					end),
					TInfoFast
				),
			},
		}
	}
end

-- Create the elaborate transmutation circle decorations
local function createTransmutationCircle(scope, showTrigger)
	local elements = {}

	-- Multiple concentric rings (from outer to inner)
	-- Outermost double ring
	table.insert(elements, createPerfectCircle(scope, 0.48, 3, showTrigger))
	table.insert(elements, createPerfectCircle(scope, 0.46, 2, showTrigger))

	-- Main outer ring
	table.insert(elements, createPerfectCircle(scope, 0.42, 2.5, showTrigger))

	-- Middle rings
	table.insert(elements, createPerfectCircle(scope, 0.34, 2, showTrigger))
	table.insert(elements, createPerfectCircle(scope, 0.28, 1.5, showTrigger))

	-- Inner rings
	table.insert(elements, createPerfectCircle(scope, 0.22, 2, showTrigger))
	table.insert(elements, createPerfectCircle(scope, 0.16, 1.5, showTrigger))

	-- Center rings
	table.insert(elements, createPerfectCircle(scope, 0.10, 2, showTrigger))
	table.insert(elements, createPerfectCircle(scope, 0.05, 1.5, showTrigger))

	-- Outer triangle (pointing up)
	local outerTriUp = createTriangle(scope, 0.40, -90, 2, showTrigger)
	for _, line in ipairs(outerTriUp) do
		table.insert(elements, line)
	end

	-- Outer triangle (pointing down)
	local outerTriDown = createTriangle(scope, 0.40, 90, 2, showTrigger)
	for _, line in ipairs(outerTriDown) do
		table.insert(elements, line)
	end

	-- Inner triangle (pointing up)
	local innerTriUp = createTriangle(scope, 0.26, -90, 1.5, showTrigger)
	for _, line in ipairs(innerTriUp) do
		table.insert(elements, line)
	end

	-- Inner triangle (pointing down)
	local innerTriDown = createTriangle(scope, 0.26, 90, 1.5, showTrigger)
	for _, line in ipairs(innerTriDown) do
		table.insert(elements, line)
	end

	-- Cross lines through center (horizontal and vertical)
	table.insert(elements, createLine(scope, 0.5 - 0.34, 0.5, 0.5 + 0.34, 0.5, 1.5, showTrigger))
	table.insert(elements, createLine(scope, 0.5, 0.5 - 0.34, 0.5, 0.5 + 0.34, 1.5, showTrigger))

	-- Diagonal lines
	local diag = 0.24
	table.insert(elements, createLine(scope, 0.5 - diag, 0.5 - diag, 0.5 + diag, 0.5 + diag, 1, showTrigger))
	table.insert(elements, createLine(scope, 0.5 + diag, 0.5 - diag, 0.5 - diag, 0.5 + diag, 1, showTrigger))

	-- Small decorative circles on the cardinal points (like in the reference)
	local cardinalRadius = 0.28
	local smallCircleSize = 18
	-- Top
	table.insert(elements, createSmallCircle(scope, 0.5, 0.5 - cardinalRadius, smallCircleSize, showTrigger, false))
	-- Bottom
	table.insert(elements, createSmallCircle(scope, 0.5, 0.5 + cardinalRadius, smallCircleSize, showTrigger, false))
	-- Left
	table.insert(elements, createSmallCircle(scope, 0.5 - cardinalRadius, 0.5, smallCircleSize, showTrigger, false))
	-- Right
	table.insert(elements, createSmallCircle(scope, 0.5 + cardinalRadius, 0.5, smallCircleSize, showTrigger, false))

	-- Small circles at triangle vertices (inner)
	for i = 0, 5 do
		local angle = math.rad(-90 + i * 60)
		local x = 0.5 + math.cos(angle) * 0.16
		local y = 0.5 + math.sin(angle) * 0.16
		table.insert(elements, createSmallCircle(scope, x, y, 10, showTrigger, true))
	end

	-- Arc-like curves (simulated with short lines) between certain points
	-- These create the curved sections visible in the reference image
	local function createArc(cx, cy, radius, startAngle, endAngle, segments)
		local arcLines = {}
		local angleStep = (endAngle - startAngle) / segments
		for i = 0, segments - 1 do
			local a1 = math.rad(startAngle + i * angleStep)
			local a2 = math.rad(startAngle + (i + 1) * angleStep)
			local x1 = cx + math.cos(a1) * radius
			local y1 = cy + math.sin(a1) * radius
			local x2 = cx + math.cos(a2) * radius
			local y2 = cy + math.sin(a2) * radius
			table.insert(arcLines, createLine(scope, x1, y1, x2, y2, 1.5, showTrigger))
		end
		return arcLines
	end

	-- Partial arcs in the quadrants (like the curved sections in the reference)
	local arcRadius = 0.18
	local arcSegments = 8
	-- Top-left arc
	local arc1 = createArc(0.5, 0.5, arcRadius, 200, 250, arcSegments)
	for _, line in ipairs(arc1) do table.insert(elements, line) end
	-- Top-right arc
	local arc2 = createArc(0.5, 0.5, arcRadius, 290, 340, arcSegments)
	for _, line in ipairs(arc2) do table.insert(elements, line) end
	-- Bottom-right arc
	local arc3 = createArc(0.5, 0.5, arcRadius, 20, 70, arcSegments)
	for _, line in ipairs(arc3) do table.insert(elements, line) end
	-- Bottom-left arc
	local arc4 = createArc(0.5, 0.5, arcRadius, 110, 160, arcSegments)
	for _, line in ipairs(arc4) do table.insert(elements, line) end

	return elements
end

-- Create a connection line between two passives (only for prerequisites)
local function createPrerequisiteLine(scope, fromPos, toPos, showTrigger, isUnlocked)
	local fromX = fromPos.position.X.Scale
	local fromY = fromPos.position.Y.Scale
	local toX = toPos.position.X.Scale
	local toY = toPos.position.Y.Scale

	local dx = toX - fromX
	local dy = toY - fromY
	local length = math.sqrt(dx * dx + dy * dy)
	local angle = math.deg(math.atan2(dy, dx))

	local midX = (fromX + toX) / 2
	local midY = (fromY + toY) / 2

	return scope:New "Frame" {
		Name = "PrerequisiteLine",
		BackgroundColor3 = scope:Spring(
			scope:Computed(function(use)
				return if use(isUnlocked) then Color3.fromRGB(80, 220, 80) else Color3.fromRGB(150, 100, 80)
			end),
			15,
			1
		),
		BackgroundTransparency = scope:Tween(
			scope:Computed(function(use)
				return if use(showTrigger) then 0.2 else 1
			end),
			TInfoFast
		),
		Position = UDim2.fromScale(midX, midY),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(length, 0, 0, 3),
		Rotation = angle,
		ZIndex = 4,

		[Children] = {
			scope:New "UICorner" {
				CornerRadius = UDim.new(0, 2),
			},
		}
	}
end

-- Create placeholder passive node (empty slot)
local function createPlaceholderNode(scope, positionData, index, showTrigger, entranceDelay)
	local hasEntered = scope:Value(false)
	local nodeSize = CIRCLE_CONFIG.nodeSizes[positionData.ring] or 36
	local position = positionData.position

	task.spawn(function()
		task.wait(entranceDelay)
		hasEntered:set(true)
	end)

	return scope:New "Frame" {
		Name = "Placeholder_" .. index,
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = scope:Spring(
			scope:Computed(function(use)
				if not use(hasEntered) then return 1 end
				return if use(showTrigger) then 0.4 else 1
			end),
			20,
			1
		),
		Position = scope:Spring(
			scope:Computed(function(use)
				local entered = use(hasEntered)
				if use(showTrigger) and entered then
					return position
				elseif not entered then
					return UDim2.fromScale(0.5, 0.5)
				else
					return UDim2.new(
						position.X.Scale,
						position.X.Offset,
						position.Y.Scale + 0.03,
						position.Y.Offset
					)
				end
			end),
			20,
			0.8
		),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = scope:Spring(
			scope:Computed(function(use)
				if not use(hasEntered) then return UDim2.fromOffset(nodeSize * 0.3, nodeSize * 0.3) end
				return UDim2.fromOffset(nodeSize * 0.7, nodeSize * 0.7)
			end),
			25,
			0.7
		),
		ZIndex = 5,

		[Children] = {
			scope:New "UICorner" {
				CornerRadius = UDim.new(0.5, 0),
			},
			scope:New "UIStroke" {
				Color = Color3.fromRGB(80, 70, 90),
				Thickness = 2,
				Transparency = scope:Spring(
					scope:Computed(function(use)
						if not use(hasEntered) then return 1 end
						return if use(showTrigger) then 0.3 else 1
					end),
					20,
					1
				),
			},
			scope:New "TextLabel" {
				Name = "LockedIcon",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromScale(0.6, 0.6),
				Text = "?",
				TextColor3 = Color3.fromRGB(100, 90, 110),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextTransparency = scope:Spring(
					scope:Computed(function(use)
						if not use(hasEntered) then return 1 end
						return if use(showTrigger) then 0.3 else 1
					end),
					20,
					1
				),
			},
		}
	}
end

-- Helper function to create passive button
local function createPassiveButton(scope, passiveData, positionData, index, showTrigger, availableSkillPoints, unlockedPassives, entranceDelay)
	local isHovered = scope:Value(false)
	local isHolding = scope:Value(false)
	local holdProgress = scope:Value(0)
	local isUnlocked = scope:Value(unlockedPassives[passiveData.id] or false)

	local hasEntered = scope:Value(false)
	entranceDelay = entranceDelay or 0

	local particleEmitter = nil
	local passiveButtonRef = scope:Value(nil)

	local nodeSize = CIRCLE_CONFIG.nodeSizes[positionData.ring] or 40

	local hoverScale = scope:Spring(
		scope:Computed(function(use)
			if not use(hasEntered) then return 0.3 end
			return if use(isHovered) then 1.2 else 1
		end),
		25,
		0.7
	)

	task.spawn(function()
		task.wait(entranceDelay)
		hasEntered:set(true)
	end)

	local shakeOffset = scope:Value(Vector2.new(0, 0))
	local lockShakeOffset = scope:Value(Vector2.new(0, 0))

	local holdStartTime = nil
	local holdThread = nil

	local tierColor = passiveData.color or Color3.fromRGB(180, 180, 180)
	local unlockedColor = Color3.fromRGB(80, 220, 80)

	local position = positionData.position

	return scope:New "ImageButton" {
		Name = "Passive_" .. passiveData.id,
		BackgroundTransparency = 1,
		Image = "rbxassetid://136627441102605",
		ImageColor3 = scope:Spring(
			scope:Computed(function(use)
				return if use(isUnlocked) then unlockedColor else Color3.fromRGB(100, 100, 100)
			end),
			15,
			1
		),
		Position = scope:Spring(
			scope:Computed(function(use)
				local shake = use(shakeOffset)
				local entered = use(hasEntered)
				if use(showTrigger) and entered then
					return UDim2.new(
						position.X.Scale,
						position.X.Offset + shake.X,
						position.Y.Scale,
						position.Y.Offset + shake.Y
					)
				elseif not entered then
					return UDim2.fromScale(0.5, 0.5)
				else
					return UDim2.new(
						position.X.Scale,
						position.X.Offset,
						position.Y.Scale + 0.03,
						position.Y.Offset
					)
				end
			end),
			20,
			0.8
		),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = scope:Computed(function(use)
			local scale = use(hoverScale)
			return UDim2.fromOffset(nodeSize * scale, nodeSize * scale)
		end),
		ImageTransparency = scope:Spring(
			scope:Computed(function(use)
				if not use(hasEntered) then return 1 end
				return if use(showTrigger) then 0 else 1
			end),
			20,
			1
		),
		ZIndex = scope:Computed(function(use)
			return if use(isHovered) then 15 else 6
		end),

		[Ref] = passiveButtonRef,

		[OnEvent "MouseEnter"] = function()
			isHovered:set(true)
		end,

		[OnEvent "MouseLeave"] = function()
			isHovered:set(false)
		end,

		[OnEvent "MouseButton1Down"] = function()
			if peek(isUnlocked) then return end

			isHolding:set(true)
			holdStartTime = tick()

			holdThread = task.spawn(function()
				while peek(isHolding) do
					local elapsed = tick() - holdStartTime
					local progress = math.min(elapsed / 2, 1)
					holdProgress:set(progress)

					local lockIntensity = 3
					lockShakeOffset:set(Vector2.new(
						(math.random() - 0.5) * lockIntensity * 2,
						(math.random() - 0.5) * lockIntensity * 2
					))

					if progress >= 1 then
						lockShakeOffset:set(Vector2.new(0, 0))

						local passiveButton = peek(passiveButtonRef)
						local particleFrame = passiveButton and passiveButton:FindFirstChild("ParticleFrame")

						if particleFrame then
							particleEmitter = Emitter2D.new()
							particleEmitter.Parent = particleFrame
							particleEmitter.Color = tierColor
							particleEmitter.Size = 12
							particleEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
							particleEmitter.Transparency = 0
							particleEmitter.ZOffset = 10
							particleEmitter.EmissionDirection = "Top"
							particleEmitter.Enabled = false
							particleEmitter.Lifetime = NumberRange.new(0.4, 0.8)
							particleEmitter.Rate = 50
							particleEmitter.Speed = 150
							particleEmitter.SpreadAngle = 360
							particleEmitter.Acceleration = Vector2.new(0, 300)
							particleEmitter:BindToRenderStepped()
							particleEmitter:Emit(30)

							task.delay(2, function()
								if particleEmitter then
									particleEmitter:Destroy()
									particleEmitter = nil
								end
							end)
						end

						task.spawn(function()
							for i = 1, 10 do
								local intensity = 8 - (i * 0.6)
								shakeOffset:set(Vector2.new(
									(math.random() - 0.5) * intensity,
									(math.random() - 0.5) * intensity
								))
								task.wait(0.03)
							end
							shakeOffset:set(Vector2.new(0, 0))
						end)

						unlockedPassives[passiveData.id] = true
						isUnlocked:set(true)
						isHolding:set(false)
						break
					end

					task.wait(0.016)
				end

				if not peek(isUnlocked) then
					holdProgress:set(0)
					lockShakeOffset:set(Vector2.new(0, 0))
				end
			end)
		end,

		[OnEvent "MouseButton1Up"] = function()
			isHolding:set(false)
			if holdThread then
				task.cancel(holdThread)
			end
			if not peek(isUnlocked) then
				lockShakeOffset:set(Vector2.new(0, 0))
			end
		end,

		[Children] = {
			scope:New "Frame" {
				Name = "ParticleFrame",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 15,
			},

			scope:New "ImageLabel" {
				Name = "Glow",
				BackgroundTransparency = 1,
				Image = "rbxassetid://136627441102605",
				ImageColor3 = scope:Computed(function(use)
					return if use(isUnlocked) then unlockedColor else tierColor
				end),
				Size = UDim2.fromScale(1.3, 1.3),
				Position = UDim2.fromScale(-0.15, -0.15),
				ImageTransparency = scope:Computed(function(use)
					if use(isUnlocked) then return 0.4 end
					return if use(isHovered) then 0.3 else 0.8
				end),
				ZIndex = 0,
			},

			scope:New "ImageLabel" {
				Name = "Lock",
				BackgroundTransparency = 1,
				Image = "rbxassetid://134854985595248",
				Position = scope:Computed(function(use)
					local lockShake = use(lockShakeOffset)
					return UDim2.new(0.1, lockShake.X, 0.1, lockShake.Y)
				end),
				Size = UDim2.fromScale(0.8, 0.8),
				ImageColor3 = scope:Computed(function(use)
					local progress = use(holdProgress)
					local r = 255 - ((255 - tierColor.R * 255) * progress)
					local g = 255 - ((255 - tierColor.G * 255) * progress)
					local b = 255 - ((255 - tierColor.B * 255) * progress)
					return Color3.fromRGB(r, g, b)
				end),
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						if use(isUnlocked) then
							return 1
						elseif use(showTrigger) then
							return 0
						else
							return 1
						end
					end),
					TInfoFast
				),
			},

			scope:New "TextLabel" {
				Name = "Checkmark",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.15, 0.15),
				Size = UDim2.fromScale(0.7, 0.7),
				Text = "✓",
				TextColor3 = unlockedColor,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextTransparency = scope:Spring(
					scope:Computed(function(use)
						return if use(isUnlocked) then 0 else 1
					end),
					20,
					1
				),
				ZIndex = 3,
			},

			scope:New "Frame" {
				Name = "HoverInfo",
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				BackgroundTransparency = scope:Computed(function(use)
					return if use(isHovered) then 0.1 else 1
				end),
				BorderColor3 = scope:Computed(function(use)
					return if use(isUnlocked) then unlockedColor else tierColor
				end),
				BorderSizePixel = 2,
				Position = UDim2.fromScale(1.2, -0.3),
				AnchorPoint = Vector2.new(0, 0),
				Size = UDim2.fromOffset(260, 200),
				ZIndex = 20,
				Visible = scope:Computed(function(use)
					return use(isHovered) and use(showTrigger)
				end),

				[Children] = {
					scope:New "UICorner" {
						CornerRadius = UDim.new(0, 8),
					},

					scope:New "UIStroke" {
						Color = scope:Computed(function(use)
							return if use(isUnlocked) then unlockedColor else tierColor
						end),
						Thickness = 2,
						Transparency = 0.3,
					},

					scope:New "TextLabel" {
						Name = "PassiveTitle",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.05, 0.02),
						Size = UDim2.fromScale(0.9, 0.12),
						Text = passiveData.name,
						TextColor3 = scope:Computed(function(use)
							return if use(isUnlocked) then unlockedColor else Color3.fromRGB(255, 255, 255)
						end),
						TextSize = 15,
						Font = Enum.Font.SourceSansBold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					},

					scope:New "TextLabel" {
						Name = "Header",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.05, 0.14),
						Size = UDim2.fromScale(0.9, 0.10),
						Text = "[" .. passiveData.tier .. "] " .. passiveData.category,
						TextColor3 = tierColor,
						TextSize = 12,
						Font = Enum.Font.SourceSansBold,
						TextXAlignment = Enum.TextXAlignment.Left,
					},

					scope:New "TextLabel" {
						Name = "Description",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.05, 0.26),
						Size = UDim2.fromScale(0.9, 0.30),
						Text = passiveData.description,
						TextColor3 = Color3.fromRGB(220, 220, 220),
						TextSize = 13,
						Font = Enum.Font.SourceSans,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					},

					scope:New "TextLabel" {
						Name = "Effects",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.05, 0.58),
						Size = UDim2.fromScale(0.9, 0.18),
						Text = formatEffects(passiveData.effects),
						TextColor3 = Color3.fromRGB(100, 255, 100),
						TextSize = 12,
						Font = Enum.Font.SourceSans,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					},

					scope:New "TextLabel" {
						Name = "Requirements",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.05, 0.77),
						Size = UDim2.fromScale(0.9, 0.21),
						Text = formatRequirements(passiveData.requirements),
						TextColor3 = Color3.fromRGB(255, 150, 150),
						TextSize = 11,
						Font = Enum.Font.SourceSans,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					},
				}
			},
		}
	}
end

return function(scope, props: {})
	local showSkillsSection = props.showSkillsSection
	local availableSkillPoints = props.availableSkillPoints

	local unlockedPassives = {}

	local currentPageIndex = scope:Value(1)
	local totalPages = #PassivesData.Pages

	local currentPageName = scope:Computed(function(use)
		return PassivesData.Pages[use(currentPageIndex)] or "Combat"
	end)

	local passiveUnlockStates = {}
	local passivePositionsByName = {}

	local passiveButtonsContainer = scope:Value({})
	local connectionLinesContainer = scope:Value({})
	local decorativeElements = scope:Value({})

	local function rebuildAlchemyCircle()
		local pageName = peek(currentPageName)
		local passivesForPage = PassivesData.getPassivesByPage(pageName)

		-- Generate all positions for the full circle
		local allPositions = generateAlchemyCirclePositions()
		local totalPositions = #allPositions

		local newButtons = {}
		local newConnections = {}
		local newDecorations = {}

		-- Reset position tracking
		passivePositionsByName = {}

		-- Create the elaborate transmutation circle
		local circleElements = createTransmutationCircle(scope, showSkillsSection)
		for _, element in ipairs(circleElements) do
			table.insert(newDecorations, element)
		end

		-- Map passives to positions, fill remaining with placeholders
		local passivePositionMap = {}
		for i, passiveInfo in ipairs(passivesForPage) do
			if i <= totalPositions then
				passivePositionMap[i] = passiveInfo
				passivePositionsByName[passiveInfo.name] = allPositions[i]
			end
		end

		-- Create nodes for each position
		for i = 1, totalPositions do
			local posData = allPositions[i]
			local ring = posData.ring
			local slot = posData.slot
			local entranceDelay = (ring - 1) * 0.1 + (slot - 1) * 0.03

			local passiveInfo = passivePositionMap[i]

			if passiveInfo then
				-- Create actual passive button
				local passiveData = {
					name = passiveInfo.name,
					id = passiveInfo.data.id,
					cost = PassivesData.getPassiveCost(passiveInfo.name),
					description = passiveInfo.data.description,
					tier = passiveInfo.data.tier,
					category = passiveInfo.data.category,
					requirements = passiveInfo.data.requirements,
					effects = passiveInfo.data.effects,
					color = PassivesData.getPassiveColor(passiveInfo.name),
				}

				local unlockState = scope:Value(unlockedPassives[passiveData.id] or false)
				passiveUnlockStates[passiveData.id] = unlockState

				table.insert(newButtons, createPassiveButton(
					scope,
					passiveData,
					posData,
					i,
					showSkillsSection,
					availableSkillPoints,
					unlockedPassives,
					entranceDelay
				))
			else
				-- Create placeholder node
				table.insert(newButtons, createPlaceholderNode(
					scope,
					posData,
					i,
					showSkillsSection,
					entranceDelay
				))
			end
		end

		-- Create connection lines ONLY for actual prerequisite relationships
		for i, passiveInfo in ipairs(passivesForPage) do
			if passiveInfo.data.requirements and passiveInfo.data.requirements.prerequisitePassives then
				local currentPos = passivePositionsByName[passiveInfo.name]
				if currentPos then
					for _, prereqName in ipairs(passiveInfo.data.requirements.prerequisitePassives) do
						local prereqPos = passivePositionsByName[prereqName]
						if prereqPos then
							-- Find the prerequisite's unlock state
							local prereqPassive = nil
							for _, p in ipairs(passivesForPage) do
								if p.name == prereqName then
									prereqPassive = p
									break
								end
							end
							local prereqUnlockState = prereqPassive and passiveUnlockStates[prereqPassive.data.id] or scope:Value(false)

							table.insert(newConnections, createPrerequisiteLine(
								scope,
								prereqPos,
								currentPos,
								showSkillsSection,
								prereqUnlockState
							))
						end
					end
				end
			end
		end

		decorativeElements:set(newDecorations)
		connectionLinesContainer:set(newConnections)
		passiveButtonsContainer:set(newButtons)
	end

	rebuildAlchemyCircle()

	local function goToNextPage()
		local current = peek(currentPageIndex)
		if current < totalPages then
			currentPageIndex:set(current + 1)
			passiveUnlockStates = {}
			rebuildAlchemyCircle()
		end
	end

	local function goToPrevPage()
		local current = peek(currentPageIndex)
		if current > 1 then
			currentPageIndex:set(current - 1)
			passiveUnlockStates = {}
			rebuildAlchemyCircle()
		end
	end

	return scope:New "Frame" {
		Name = "Passives",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(-1.8, 0.189),
		Size = UDim2.fromOffset(629, 501),

		[Children] = {
			-- Page Title
			scope:New "TextLabel" {
				Name = "PageTitle",
				BackgroundTransparency = 1,
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(showSkillsSection) then UDim2.fromScale(0.25, 0.01) else UDim2.fromScale(0.25, -0.05)
					end),
					25,
					0.9
				),
				Size = UDim2.fromScale(0.5, 0.07),
				Text = scope:Computed(function(use)
					return use(currentPageName) .. " Passives"
				end),
				TextColor3 = Color3.fromRGB(220, 200, 180),
				TextScaled = true,
				Font = Enum.Font.SourceSansBold,
				TextTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(showSkillsSection) then 0 else 1
					end),
					TInfoFast
				),

				[Children] = {
					scope:New "UIStroke" {
						Color = Color3.fromRGB(100, 70, 60),
						Thickness = 2,
						Transparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showSkillsSection) then 0.3 else 1
							end),
							TInfoFast
						),
					},
				}
			},

			-- Page indicator
			scope:New "TextLabel" {
				Name = "PageIndicator",
				BackgroundTransparency = 1,
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(showSkillsSection) then UDim2.fromScale(0.4, 0.94) else UDim2.fromScale(0.4, 0.99)
					end),
					25,
					0.9
				),
				Size = UDim2.fromScale(0.2, 0.04),
				Text = scope:Computed(function(use)
					return use(currentPageIndex) .. " / " .. totalPages
				end),
				TextColor3 = Color3.fromRGB(180, 150, 140),
				TextScaled = true,
				Font = Enum.Font.SourceSans,
				TextTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(showSkillsSection) then 0 else 1
					end),
					TInfoFast
				),
			},

			-- Previous Page Button
			scope:New "ImageButton" {
				Name = "PrevPage",
				BackgroundTransparency = 1,
				Image = BUTTON_IMAGE,
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(showSkillsSection) then UDim2.fromScale(0.05, 0.93) else UDim2.fromScale(0.05, 0.98)
					end),
					25,
					0.9
				),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromOffset(90, 30),
				SliceCenter = Rect.new(171, 20, 187, 42),
				Rotation = 180,
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						if not use(showSkillsSection) then return 1 end
						return if use(currentPageIndex) > 1 then 0 else 0.5
					end),
					TInfoFast
				),

				[OnEvent "Activated"] = function()
					goToPrevPage()
				end,

				[Children] = {
					scope:New "TextLabel" {
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Size = UDim2.fromScale(1, 1),
						Rotation = 180,
						Text = "< PREV",
						TextColor3 = Color3.fromRGB(220, 200, 180),
						TextSize = 13,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showSkillsSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIStroke" {
								Color = Color3.fromRGB(100, 70, 60),
								Thickness = 1.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showSkillsSection) then 0.3 else 1
									end),
									TInfoFast
								),
							},
						}
					},
				}
			},

			-- Next Page Button
			scope:New "ImageButton" {
				Name = "NextPage",
				BackgroundTransparency = 1,
				Image = BUTTON_IMAGE,
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(showSkillsSection) then UDim2.fromScale(0.75, 0.93) else UDim2.fromScale(0.75, 0.98)
					end),
					25,
					0.9
				),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromOffset(90, 30),
				SliceCenter = Rect.new(171, 20, 187, 42),
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						if not use(showSkillsSection) then return 1 end
						return if use(currentPageIndex) < totalPages then 0 else 0.5
					end),
					TInfoFast
				),

				[OnEvent "Activated"] = function()
					goToNextPage()
				end,

				[Children] = {
					scope:New "TextLabel" {
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Size = UDim2.fromScale(1, 1),
						Text = "NEXT >",
						TextColor3 = Color3.fromRGB(220, 200, 180),
						TextSize = 13,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showSkillsSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIStroke" {
								Color = Color3.fromRGB(100, 70, 60),
								Thickness = 1.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showSkillsSection) then 0.3 else 1
									end),
									TInfoFast
								),
							},
						}
					},
				}
			},

			-- Circle container (maintains aspect ratio for perfect circles)
			scope:New "Frame" {
				Name = "CircleContainer",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.48),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(CIRCLE_BASE_SIZE, CIRCLE_BASE_SIZE),

				[Children] = {
					-- Force perfect square
					scope:New "UIAspectRatioConstraint" {
						AspectRatio = 1,
						AspectType = Enum.AspectType.ScaleWithParentSize,
						DominantAxis = Enum.DominantAxis.Height,
					},

					-- Decorative elements container
					scope:New "Frame" {
						Name = "DecorativeElements",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 0,

						[Children] = scope:Computed(function(use)
							return use(decorativeElements)
						end),
					},

					-- Connection lines container
					scope:New "Frame" {
						Name = "ConnectionLines",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 3,

						[Children] = scope:Computed(function(use)
							return use(connectionLinesContainer)
						end),
					},

					-- Passive buttons container
					scope:New "Frame" {
						Name = "PassiveButtonsContainer",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 5,

						[Children] = scope:Computed(function(use)
							return use(passiveButtonsContainer)
						end),
					},
				}
			},
		}
	}
end
