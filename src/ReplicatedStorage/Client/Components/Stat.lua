local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

-- ECS imports for player data
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

-- Import the new components
local Components = ReplicatedStorage.Client.Components
-- Skills component removed - Hunter x Hunter Nen system will replace this
local SkillPointsHolder = require(Components.SkillPointsHolder)
local SkillPointsDisplay = require(Components.SkillPointsDisplay)

local Children, scoped, peek, out, OnEvent, Value, Computed, Tween, Spring =
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.Value, Fusion.Computed, Fusion.Tween, Fusion.Spring

local TInfo = TweenInfo.new(0.7, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)
local TInfoFast = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0)

-- Helper function to get player's ECS entity
local function getPlayerEntity()
	return ref.get("local_player")
end

-- Helper function to safely get component data
local function getComponentData(entity, component)
	if entity and world:has(entity, component) then
		return world:get(entity, component)
	end
	return nil
end

return function(scope, props: {})
	local parent = props.Parent
	local framein = props.fade
	local animateElements = props.animateElements

	-- Stats data (will be updated from ECS)
	local level = scope:Value(1)
	local xp = scope:Value(0)
	local maxXP = scope:Value(500)
	local health = scope:Value(100)
	local physicalResistance = scope:Value(0) -- Physical Resistance (percentage)
	local alchemicalResistance = scope:Value(0) -- Alchemical Resistance (percentage)
	local alignment = scope:Value(0)
	local kills = scope:Value(0)
	local passives = scope:Value(0)
	local contribution = scope:Value(0)
	local speedBonus = scope:Value(0)
	local valor = scope:Value(0)

	-- Attribute points (confirmed values from player's Build)
	local knowledge = scope:Value(0)
	local potency = scope:Value(0)
	local dexterity = scope:Value(0)
	local strange = scope:Value(0)
	local vibrance = scope:Value(0)

	-- Temporary attribute points (pending confirmation)
	local tempKnowledge = scope:Value(0)
	local tempPotency = scope:Value(0)
	local tempDexterity = scope:Value(0)
	local tempStrange = scope:Value(0)
	local tempVibrance = scope:Value(0)

	-- Available attribute points to spend
	local totalAttributePoints = scope:Value(10) -- Total points available
	local availableAttributePoints = scope:Computed(function(use)
		local spent = use(knowledge) + use(potency) + use(dexterity) + use(strange) + use(vibrance)
		return use(totalAttributePoints) - spent
	end)

	-- Remaining points after temp allocation
	local remainingPoints = scope:Computed(function(use)
		local currentAvailable = use(availableAttributePoints)
		local tempSpent = use(tempKnowledge) + use(tempPotency) + use(tempDexterity) + use(tempStrange) + use(tempVibrance)
		return currentAvailable - tempSpent
	end)

	-- Skill points
	local skillPoints = scope:Value(10)

	-- Function to update stats from ECS
	local function updateStatsFromECS()
		local entity = getPlayerEntity()
		if not entity then return end

		-- Get Level component
		local levelData = getComponentData(entity, comps.Level)
		if levelData then
			level:set(levelData.current or 1)
		end

		-- Get Experience component
		local expData = getComponentData(entity, comps.Experience)
		if expData then
			xp:set(expData.current or 0)
			maxXP:set(expData.required or 500)
		end

		-- Get Health component
		local healthData = getComponentData(entity, comps.Health)
		if healthData then
			health:set(math.floor(healthData.current or 100))
		end

		-- Get Alignment component
		local alignmentData = getComponentData(entity, comps.Alignment)
		if alignmentData then
			alignment:set(alignmentData.value or 0)
		end

		-- Get Physical Resistance from Stats component or data
		local statsData = getComponentData(entity, comps.Stats)
		if statsData then
			physicalResistance:set(statsData.PhysicalResistance or 0)
			alchemicalResistance:set(statsData.AlchemicalResistance or 0)
		end

		-- Try to get from leaderstats or other sources
		local leaderstats = plr:FindFirstChild("leaderstats")
		if leaderstats then
			local killsStat = leaderstats:FindFirstChild("Kills")
			if killsStat then
				kills:set(killsStat.Value or 0)
			end
		end
	end

	-- Initial update
	updateStatsFromECS()

	-- Set up periodic updates while menu is open
	local updateThread = task.spawn(function()
		while true do
			task.wait(0.5) -- Update every 0.5 seconds
			updateStatsFromECS()
		end
	end)

	-- Register cleanup to stop update thread
	table.insert(scope, function()
		if updateThread then
			task.cancel(updateThread)
		end
	end)

	-- Animation triggers for each section
	local showLevelSection = scope:Value(false)
	local showStatsSection = scope:Value(false)
	local showAttributesSection = scope:Value(false)
	local showIGN = scope:Value(false)
	local showSkillsSection = scope:Value(false)
	local showSkillPointsHolder = scope:Value(false)

	-- Clone and setup radar chart
	local radarChart = nil
	local radarBones = {}

	task.spawn(function()
		-- Wait for holder frame to be created
		task.wait(0.5)

		-- Get the radar chart from ReplicatedStorage
		local radarTemplate = ReplicatedStorage:FindFirstChild("RadarChart")
		if radarTemplate then
			radarChart = radarTemplate:Clone()

			-- Find all the bones
			local hexaModel = radarChart:FindFirstChild("Hexa")
			if hexaModel then
				local hexaMesh = hexaModel:FindFirstChild("Hexa")
				if hexaMesh then
					radarBones.Knowledge = hexaMesh:FindFirstChild("Bone.004")
					radarBones.Potency = hexaMesh:FindFirstChild("Bone.003")
					radarBones.Dexterity = hexaMesh:FindFirstChild("Bone.002")
					radarBones.Strange = hexaMesh:FindFirstChild("Bone.001")
					radarBones.Vibrance = hexaMesh:FindFirstChild("Bone_000")
				end
			end

			-- Setup camera
			local camera = radarChart:FindFirstChild("Camera")
			if camera then
				radarChart.CurrentCamera = camera
			end

			-- Position and parent the radar chart
			radarChart.AnchorPoint = Vector2.new(0.5, 0.5)
			radarChart.Position = UDim2.fromScale(0.491, 0.64)
			radarChart.Size = UDim2.fromScale(0.45, 0.32)
			radarChart.ZIndex = 2
			radarChart.BackgroundTransparency = 1

			-- Initially hide it
			radarChart.ImageTransparency = 1
			local bgImage = radarChart:FindFirstChild("ImageLabel")
			if bgImage then
				bgImage.ImageTransparency = 1
			end
		end
	end)

	-- Function to update bone positions based on stat values
	local function updateRadarChart()
		if not radarChart or not radarBones.Knowledge then return end

		-- Store initial world positions if not already stored
		if not radarBones.InitialWorldCFrames then
			radarBones.InitialWorldCFrames = {
				Knowledge = radarBones.Knowledge.WorldCFrame,
				Potency = radarBones.Potency.WorldCFrame,
				Dexterity = radarBones.Dexterity.WorldCFrame,
				Strange = radarBones.Strange.WorldCFrame,
				Vibrance = radarBones.Vibrance.WorldCFrame,
			}
		end

		-- Update each bone based on stat value
		local stats = {
			Knowledge = peek(knowledge),
			Potency = peek(potency),
			Dexterity = peek(dexterity),
			Strange = peek(strange),
			Vibrance = peek(vibrance),
		}

		for statName, bone in pairs(radarBones) do
			if statName ~= "InitialWorldCFrames" and bone then
				local initialWorldCF = radarBones.InitialWorldCFrames[statName]
				local value = stats[statName]

				-- Scale from 0.5 (at 0 points) to 1.0 (at 10 points)
				local scale = 0.5 + (value / 10) * 0.5

				-- Get the world position and NEGATE it to flip direction
				local worldPos = initialWorldCF.Position
				local flippedPos = -worldPos
				local scaledWorldPos = flippedPos * scale

				-- Set WorldCFrame with scaled position
				bone.WorldCFrame = CFrame.new(scaledWorldPos) * (initialWorldCF - initialWorldCF.Position)
			end
		end
	end

	-- Connect stat changes to update radar
	scope:Observer(knowledge):onChange(updateRadarChart)
	scope:Observer(potency):onChange(updateRadarChart)
	scope:Observer(dexterity):onChange(updateRadarChart)
	scope:Observer(strange):onChange(updateRadarChart)
	scope:Observer(vibrance):onChange(updateRadarChart)

	-- Trigger animations with delays - wait for animateElements to be true first
	task.spawn(function()
		while not peek(animateElements) do
			task.wait()
		end
		task.wait(0.3)
		showIGN:set(true)
	end)

	task.spawn(function()
		while not peek(animateElements) do
			task.wait()
		end
		task.wait(0.5)
		showLevelSection:set(true)
	end)

	task.spawn(function()
		while not peek(animateElements) do
			task.wait()
		end
		task.wait(0.9)
		showStatsSection:set(true)
	end)

	task.spawn(function()
		while not peek(animateElements) do
			task.wait()
		end
		task.wait(1.8)
		showAttributesSection:set(true)

		-- Parent and show radar chart
		if radarChart then
			-- Find the Attributes folder within the Holder
			local holder = parent
			if holder then
				local attributesFolder = holder:FindFirstChild("Holder")
				if attributesFolder then
					attributesFolder = attributesFolder:FindFirstChild("Attributes")
				end

				if attributesFolder then
					radarChart.Parent = attributesFolder
				else
					radarChart.Parent = holder
				end
			end

			-- Fade in the radar chart
			local tweenService = game:GetService("TweenService")
			local fadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			tweenService:Create(radarChart, fadeInfo, {ImageTransparency = 0}):Play()

			local bgImage = radarChart:FindFirstChild("ImageLabel")
			if bgImage then
				tweenService:Create(bgImage, fadeInfo, {ImageTransparency = 1}):Play()
			end

			-- Initial update
			updateRadarChart()
		end
	end)

	task.spawn(function()
		while not peek(animateElements) do
			task.wait()
		end
		task.wait(2.2)
		showSkillsSection:set(true)
	end)

	task.spawn(function()
		while not peek(animateElements) do
			task.wait()
		end
		task.wait(2.5)
		showSkillPointsHolder:set(true)
	end)

	local mainHolder = scope:New "Frame" {
		Name = "Holder",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.699, 0.0669),
		SelectionOrder = -1,
		Size = UDim2.fromOffset(446, 645),
		ZIndex = 10,
		Parent = parent,

		[Children] = {
			scope:New "ImageLabel" {
				Name = "ImageLabel",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://133186265401352",
				Size = UDim2.fromScale(1, 1),
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0 else 1
					end),
					TInfo
				),
			},

			-- IGN (Player Name)
			scope:New "TextLabel" {
				Name = "IGN",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/Sarpanch.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Italic
				),
				Position = scope:Spring(
					scope:Computed(function(use)
						return if use(showIGN) then UDim2.fromScale(0.291, 0.0264) else UDim2.fromScale(0.291, -0.02)
					end),
					25,
					0.9
				),
				Size = UDim2.fromOffset(186, 29),
				Text = plr.Name,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextSize = 14,
				TextWrapped = true,
				TextTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(showIGN) then 0 else 1
					end),
					TInfoFast
				),

				[Children] = {
					scope:New "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
							ColorSequenceKeypoint.new(0.393, Color3.fromRGB(143, 143, 143)),
							ColorSequenceKeypoint.new(0.678, Color3.fromRGB(255, 255, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
						}),
						Rotation = 90,
					},

					scope:New "UIStroke" {
						Name = "UIStroke",
						Thickness = 0.5,
						Transparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showIGN) then 0 else 1
							end),
							TInfoFast
						),
					},
				}
			},

			-- Level Section
			scope:New "Folder" {
				Name = "Level",

				[Children] = {
					-- "LEVEL" text
					scope:New "TextLabel" {
						Name = "LevelText",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showLevelSection) then UDim2.fromScale(0.117, 0.0806) else UDim2.fromScale(0.117, 0.03)
							end),
							25,
							0.9
						),
						Size = UDim2.fromOffset(70, 50),
						Text = "LEVEL",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 14,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showLevelSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(0, 0, 0)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showLevelSection) then 0 else 1
									end),
									TInfoFast
								),
							},
						}
					},

					-- Level Number
					scope:New "TextLabel" {
						Name = "LevelNumber",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showLevelSection) then UDim2.fromScale(0.117, 0.115) else UDim2.fromScale(0.117, 0.07)
							end),
							25,
							0.9
						),
						Size = UDim2.fromOffset(70, 50),
						Text = scope:Computed(function(use)
							return tostring(use(level))
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 30,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showLevelSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(125, 125, 125)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showLevelSection) then 0 else 1
									end),
									TInfoFast
								),
							},
						}
					},

					-- XP text
					scope:New "TextLabel" {
						Name = "XP",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showLevelSection) then UDim2.fromScale(0.404, 0.0992) else UDim2.fromScale(0.5, 0.0992)
							end),
							25,
							0.9
						),
						Size = UDim2.fromOffset(187, 17),
						Text = scope:Computed(function(use)
							return "XP " .. use(xp) .. "/" .. use(maxXP)
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 14,
						TextWrapped = true,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showLevelSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(143, 143, 143)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(255, 255, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showLevelSection) then 0 else 1
									end),
									TInfoFast
								),
							},
						}
					},

					-- Tip text
					scope:New "TextLabel" {
						Name = "Tip",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showLevelSection) then UDim2.fromScale(0.404, 0.158) else UDim2.fromScale(0.5, 0.158)
							end),
							25,
							0.9
						),
						Size = UDim2.fromOffset(187, 23),
						Text = "Complete your militia tasks to progress your levels",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 14,
						TextWrapped = true,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showLevelSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(143, 143, 143)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(255, 255, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showLevelSection) then 0 else 1
									end),
									TInfoFast
								),
							},
						}
					},

					-- XP Bar Frame
					scope:New "Frame" {
						Name = "Frame",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.354, 0.132),
						Size = UDim2.fromOffset(235, 21),
						ClipsDescendants = true,

						[Children] = {
							-- XP Bar Background (full width)
							scope:New "ImageLabel" {
								Name = "XPBarBG",
								BackgroundColor3 = Color3.fromRGB(50, 50, 50),
								BackgroundTransparency = 0.5,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								Position = UDim2.fromScale(0.289, 0.186),
								Size = UDim2.fromOffset(100, 13),
								Image = "",
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showLevelSection) then 0 else 1
									end),
									TInfoFast
								),

								[Children] = {
									scope:New "UICorner" {
										CornerRadius = UDim.new(0, 4),
									},
								}
							},

							-- XP Bar Fill (sized by XP percentage)
							scope:New "ImageLabel" {
								Name = "XPBarFill",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								Image = "rbxassetid://139839835048778",
								Position = UDim2.fromScale(0.289, 0.186),
								Size = scope:Spring(
									scope:Computed(function(use)
										local currentXP = use(xp)
										local requiredXP = use(maxXP)
										local percentage = if requiredXP > 0 then math.clamp(currentXP / requiredXP, 0, 1) else 0
										return UDim2.fromOffset(100 * percentage, 13)
									end),
									15,
									0.8
								),
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showLevelSection) then 0 else 1
									end),
									TInfoFast
								),

								[Children] = {
									scope:New "UICorner" {
										CornerRadius = UDim.new(0, 4),
									},
								}
							},
						}
					},
				}
			},

			-- Stats Section
			scope:New "Folder" {
				Name = "Stats",

				[Children] = {
					scope:New "TextLabel" {
						Name = "StatsHeader",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showStatsSection) then UDim2.fromScale(0.117, 0.229) else UDim2.fromScale(0.05, 0.229)
							end),
							25,
							0.9
						),
						Size = UDim2.fromOffset(77, 29),
						Text = "STATS",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 14,
						TextWrapped = true,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showStatsSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showStatsSection) then 0 else 1
									end),
									TInfoFast
								),
							},
						}
					},

					scope:New "Frame" {
						Name = "StatsHolder",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.164, 0.29),
						Size = UDim2.fromOffset(312, 88),

						[Children] = {
							scope:New "UIListLayout" {
								Name = "UIListLayout",
								HorizontalFlex = Enum.UIFlexAlignment.SpaceAround,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Wraps = true,
							},

							scope:New "TextLabel" {
								Name = "Health",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								FontFace = Font.new(
									"rbxasset://fonts/families/Sarpanch.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Italic
								),
								Size = UDim2.fromOffset(77, 29),
								Text = scope:Computed(function(use)
									return "Health: " .. use(health)
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 14,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTransparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showStatsSection) then 0 else 1
									end),
									TInfoFast
								),

								[Children] = {
									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
										Transparency = scope:Tween(
											scope:Computed(function(use)
												return if use(showStatsSection) then 0 else 1
											end),
											TInfoFast
										),
									},
								}
							},

							scope:New "TextLabel" {
								Name = "PhysicalResistance",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								FontFace = Font.new(
									"rbxasset://fonts/families/Sarpanch.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Italic
								),
								Size = UDim2.fromOffset(110, 29),
								Text = scope:Computed(function(use)
									return "Phys Res: " .. use(physicalResistance) .. "%"
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 14,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTransparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showStatsSection) then 0 else 1
									end),
									TInfoFast
								),

								[Children] = {
									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
										Transparency = scope:Tween(
											scope:Computed(function(use)
												return if use(showStatsSection) then 0 else 1
											end),
											TInfoFast
										),
									},
								}
							},

							scope:New "TextLabel" {
								Name = "AlchemicalResistance",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								FontFace = Font.new(
									"rbxasset://fonts/families/Sarpanch.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Italic
								),
								Size = UDim2.fromOffset(110, 29),
								Text = scope:Computed(function(use)
									return "Alch Res: " .. use(alchemicalResistance) .. "%"
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 14,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTransparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showStatsSection) then 0 else 1
									end),
									TInfoFast
								),

								[Children] = {
									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
										Transparency = scope:Tween(
											scope:Computed(function(use)
												return if use(showStatsSection) then 0 else 1
											end),
											TInfoFast
										),
									},
								}
							},

							scope:New "TextLabel" {
								Name = "Alignment",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								FontFace = Font.new(
									"rbxasset://fonts/families/Sarpanch.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Italic
								),
								Size = UDim2.fromOffset(77, 29),
								Text = scope:Computed(function(use)
									return "Alignment: " .. use(alignment)
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 14,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTransparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showStatsSection) then 0 else 1
									end),
									TInfoFast
								),

								[Children] = {
									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
										Transparency = scope:Tween(
											scope:Computed(function(use)
												return if use(showStatsSection) then 0 else 1
											end),
											TInfoFast
										),
									},
								}
							},

							scope:New "TextLabel" {
								Name = "Kills",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								FontFace = Font.new(
									"rbxasset://fonts/families/Sarpanch.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Italic
								),
								Size = UDim2.fromOffset(77, 29),
								Text = scope:Computed(function(use)
									return "Kills: " .. use(kills)
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 14,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTransparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showStatsSection) then 0 else 1
									end),
									TInfoFast
								),

								[Children] = {
									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
										Transparency = scope:Tween(
											scope:Computed(function(use)
												return if use(showStatsSection) then 0 else 1
											end),
											TInfoFast
										),
									},
								}
							},

							scope:New "TextLabel" {
								Name = "Passives",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								FontFace = Font.new(
									"rbxasset://fonts/families/Sarpanch.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Italic
								),
								Size = UDim2.fromOffset(77, 29),
								Text = scope:Computed(function(use)
									return "Passives: " .. use(passives)
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 14,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTransparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showStatsSection) then 0 else 1
									end),
									TInfoFast
								),

								[Children] = {
									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
										Transparency = scope:Tween(
											scope:Computed(function(use)
												return if use(showStatsSection) then 0 else 1
											end),
											TInfoFast
										),
									},
								}
							},

							scope:New "TextLabel" {
								Name = "Contribution",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								FontFace = Font.new(
									"rbxasset://fonts/families/Sarpanch.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Italic
								),
								Size = UDim2.fromOffset(77, 29),
								Text = scope:Computed(function(use)
									return "Contribution: " .. use(contribution)
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 14,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTransparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showStatsSection) then 0 else 1
									end),
									TInfoFast
								),

								[Children] = {
									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
										Transparency = scope:Tween(
											scope:Computed(function(use)
												return if use(showStatsSection) then 0 else 1
											end),
											TInfoFast
										),
									},
								}
							},

							scope:New "TextLabel" {
								Name = "SpeedBonus",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								FontFace = Font.new(
									"rbxasset://fonts/families/Sarpanch.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Italic
								),
								Size = UDim2.fromOffset(77, 29),
								Text = scope:Computed(function(use)
									return "Speed Bonus: " .. use(speedBonus)
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 14,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTransparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showStatsSection) then 0 else 1
									end),
									TInfoFast
								),

								[Children] = {
									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
										Transparency = scope:Tween(
											scope:Computed(function(use)
												return if use(showStatsSection) then 0 else 1
											end),
											TInfoFast
										),
									},
								}
							},

							scope:New "TextLabel" {
								Name = "Valor",
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								FontFace = Font.new(
									"rbxasset://fonts/families/Sarpanch.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Italic
								),
								Size = UDim2.fromOffset(77, 29),
								Text = scope:Computed(function(use)
									return "Valor: " .. use(valor)
								end),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 14,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTransparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showStatsSection) then 0 else 1
									end),
									TInfoFast
								),

								[Children] = {
									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
										Transparency = scope:Tween(
											scope:Computed(function(use)
												return if use(showStatsSection) then 0 else 1
											end),
											TInfoFast
										),
									},
								}
							},
						}
					},
				}
			},

			-- Attributes Section
			scope:New "Folder" {
				Name = "Attributes",

				[Children] = {
					scope:New "TextLabel" {
						Name = "AttributesHeader",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showAttributesSection) then UDim2.fromScale(0.117, 0.428) else UDim2.fromScale(0.05, 0.428)
							end),
							25,
							0.9
						),
						Size = UDim2.fromOffset(77, 29),
						Text = "ATTRIBUTES",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 14,
						TextWrapped = true,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showAttributesSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showAttributesSection) then 0 else 1
									end),
									TInfoFast
								),
							},
						}
					},

					-- Knowledge Button
					scope:New "TextButton" {
						Name = "Knowledge",
						Active = true,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showAttributesSection) then UDim2.fromScale(0.119, 0.577) else UDim2.fromScale(0.05, 0.577)
							end),
							25,
							0.9
						),
						Selectable = true,
						Size = UDim2.fromOffset(77, 29),
						Text = scope:Computed(function(use)
							local confirmed = use(knowledge)
							local temp = use(tempKnowledge)
							return "Knowledge: " .. (confirmed + temp)
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 14,
						TextWrapped = true,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showAttributesSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showAttributesSection) then 0 else 1
									end),
									TInfoFast
								),
							},

							scope:New "ImageButton" {
								Name = "Remove",
								Active = true,
								BackgroundTransparency = 1,
								Image = "rbxassetid://8445471499",
								ImageRectOffset = Vector2.new(104, 904),
								ImageRectSize = Vector2.new(96, 96),
								Position = UDim2.fromScale(-0.403, 0.069),
								Selectable = true,
								Size = UDim2.fromOffset(24, 24),
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										local visible = use(showAttributesSection) and use(tempKnowledge) > 0
										return if visible then 0 else 1
									end),
									TInfoFast
								),
								Visible = scope:Computed(function(use)
									return use(tempKnowledge) > 0
								end),

								[OnEvent "Activated"] = function()
									local val = peek(tempKnowledge)
									if val > 0 then
										tempKnowledge:set(val - 1)
									end
								end,

								[Children] = {
									scope:New "UIAspectRatioConstraint" {
										Name = "UIAspectRatioConstraint",
										DominantAxis = Enum.DominantAxis.Height,
									},

									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
									},
								}
							},

							scope:New "ImageButton" {
								Name = "Add",
								Active = true,
								BackgroundTransparency = 1,
								Image = "rbxassetid://8445470984",
								ImageRectOffset = Vector2.new(804, 704),
								ImageRectSize = Vector2.new(96, 96),
								Position = UDim2.fromScale(1.05, 0.069),
								Selectable = true,
								Size = UDim2.fromOffset(24, 24),
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										local visible = use(showAttributesSection) and use(remainingPoints) > 0
										return if visible then 0 else 1
									end),
									TInfoFast
								),
								Visible = scope:Computed(function(use)
									return use(remainingPoints) > 0
								end),

								[OnEvent "Activated"] = function()
									if peek(remainingPoints) > 0 then
										local val = peek(tempKnowledge)
										tempKnowledge:set(val + 1)
									end
								end,

								[Children] = {
									scope:New "UIAspectRatioConstraint" {
										Name = "UIAspectRatioConstraint",
										DominantAxis = Enum.DominantAxis.Height,
									},

									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
									},
								}
							},
						}
					},

					-- Potency Button
					scope:New "TextButton" {
						Name = "Potency",
						Active = true,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showAttributesSection) then UDim2.fromScale(0.404, 0.478) else UDim2.fromScale(0.404, 0.43)
							end),
							25,
							0.9
						),
						Selectable = true,
						Size = UDim2.fromOffset(77, 29),
						Text = scope:Computed(function(use)
							local confirmed = use(potency)
							local temp = use(tempPotency)
							return "Potency: " .. (confirmed + temp)
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 14,
						TextWrapped = true,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showAttributesSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showAttributesSection) then 0 else 1
									end),
									TInfoFast
								),
							},

							scope:New "ImageButton" {
								Name = "Remove",
								Active = true,
								BackgroundTransparency = 1,
								Image = "rbxassetid://8445471499",
								ImageRectOffset = Vector2.new(104, 904),
								ImageRectSize = Vector2.new(96, 96),
								Position = UDim2.fromScale(-0.403, 0.069),
								Selectable = true,
								Size = UDim2.fromOffset(24, 24),
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										local visible = use(showAttributesSection) and use(tempPotency) > 0
										return if visible then 0 else 1
									end),
									TInfoFast
								),
								Visible = scope:Computed(function(use)
									return use(tempPotency) > 0
								end),

								[OnEvent "Activated"] = function()
									local val = peek(tempPotency)
									if val > 0 then
										tempPotency:set(val - 1)
									end
								end,

								[Children] = {
									scope:New "UIAspectRatioConstraint" {
										Name = "UIAspectRatioConstraint",
										DominantAxis = Enum.DominantAxis.Height,
									},

									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
									},
								}
							},

							scope:New "ImageButton" {
								Name = "Add",
								Active = true,
								BackgroundTransparency = 1,
								Image = "rbxassetid://8445470984",
								ImageRectOffset = Vector2.new(804, 704),
								ImageRectSize = Vector2.new(96, 96),
								Position = UDim2.fromScale(1.05, 0.069),
								Selectable = true,
								Size = UDim2.fromOffset(24, 24),
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										local visible = use(showAttributesSection) and use(remainingPoints) > 0
										return if visible then 0 else 1
									end),
									TInfoFast
								),
								Visible = scope:Computed(function(use)
									return use(remainingPoints) > 0
								end),

								[OnEvent "Activated"] = function()
									if peek(remainingPoints) > 0 then
										local val = peek(tempPotency)
										tempPotency:set(val + 1)
									end
								end,

								[Children] = {
									scope:New "UIAspectRatioConstraint" {
										Name = "UIAspectRatioConstraint",
										DominantAxis = Enum.DominantAxis.Height,
									},

									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
									},
								}
							},
						}
					},

					-- Dexterity Button
					scope:New "TextButton" {
						Name = "Dexterity",
						Active = true,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showAttributesSection) then UDim2.fromScale(0.709, 0.577) else UDim2.fromScale(0.78, 0.577)
							end),
							25,
							0.9
						),
						Selectable = true,
						Size = UDim2.fromOffset(77, 29),
						Text = scope:Computed(function(use)
							local confirmed = use(dexterity)
							local temp = use(tempDexterity)
							return "Dexterity: " .. (confirmed + temp)
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 14,
						TextWrapped = true,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showAttributesSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showAttributesSection) then 0 else 1
									end),
									TInfoFast
								),
							},

							scope:New "ImageButton" {
								Name = "Remove",
								Active = true,
								BackgroundTransparency = 1,
								Image = "rbxassetid://8445471499",
								ImageRectOffset = Vector2.new(104, 904),
								ImageRectSize = Vector2.new(96, 96),
								Position = UDim2.fromScale(-0.403, 0.069),
								Selectable = true,
								Size = UDim2.fromOffset(24, 24),
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										local visible = use(showAttributesSection) and use(tempDexterity) > 0
										return if visible then 0 else 1
									end),
									TInfoFast
								),
								Visible = scope:Computed(function(use)
									return use(tempDexterity) > 0
								end),

								[OnEvent "Activated"] = function()
									local val = peek(tempDexterity)
									if val > 0 then
										tempDexterity:set(val - 1)
									end
								end,

								[Children] = {
									scope:New "UIAspectRatioConstraint" {
										Name = "UIAspectRatioConstraint",
										DominantAxis = Enum.DominantAxis.Height,
									},

									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
									},
								}
							},

							scope:New "ImageButton" {
								Name = "Add",
								Active = true,
								BackgroundTransparency = 1,
								Image = "rbxassetid://8445470984",
								ImageRectOffset = Vector2.new(804, 704),
								ImageRectSize = Vector2.new(96, 96),
								Position = UDim2.fromScale(1.05, 0.069),
								Selectable = true,
								Size = UDim2.fromOffset(24, 24),
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										local visible = use(showAttributesSection) and use(remainingPoints) > 0
										return if visible then 0 else 1
									end),
									TInfoFast
								),
								Visible = scope:Computed(function(use)
									return use(remainingPoints) > 0
								end),

								[OnEvent "Activated"] = function()
									if peek(remainingPoints) > 0 then
										local val = peek(tempDexterity)
										tempDexterity:set(val + 1)
									end
								end,

								[Children] = {
									scope:New "UIAspectRatioConstraint" {
										Name = "UIAspectRatioConstraint",
										DominantAxis = Enum.DominantAxis.Height,
									},

									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
									},
								}
							},
						}
					},

					-- Strange Button
					scope:New "TextButton" {
						Name = "Strange",
						Active = true,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showAttributesSection) then UDim2.fromScale(0.249, 0.736) else UDim2.fromScale(0.249, 0.78)
							end),
							25,
							0.9
						),
						Selectable = true,
						Size = UDim2.fromOffset(77, 29),
						Text = scope:Computed(function(use)
							local confirmed = use(strange)
							local temp = use(tempStrange)
							return "Strange: " .. (confirmed + temp)
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 14,
						TextWrapped = true,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showAttributesSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showAttributesSection) then 0 else 1
									end),
									TInfoFast
								),
							},

							scope:New "ImageButton" {
								Name = "Remove",
								Active = true,
								BackgroundTransparency = 1,
								Image = "rbxassetid://8445471499",
								ImageRectOffset = Vector2.new(104, 904),
								ImageRectSize = Vector2.new(96, 96),
								Position = UDim2.fromScale(-0.403, 0.069),
								Selectable = true,
								Size = UDim2.fromOffset(24, 24),
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										local visible = use(showAttributesSection) and use(tempStrange) > 0
										return if visible then 0 else 1
									end),
									TInfoFast
								),
								Visible = scope:Computed(function(use)
									return use(tempStrange) > 0
								end),

								[OnEvent "Activated"] = function()
									local val = peek(tempStrange)
									if val > 0 then
										tempStrange:set(val - 1)
									end
								end,

								[Children] = {
									scope:New "UIAspectRatioConstraint" {
										Name = "UIAspectRatioConstraint",
										DominantAxis = Enum.DominantAxis.Height,
									},

									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
									},
								}
							},

							scope:New "ImageButton" {
								Name = "Add",
								Active = true,
								BackgroundTransparency = 1,
								Image = "rbxassetid://8445470984",
								ImageRectOffset = Vector2.new(804, 704),
								ImageRectSize = Vector2.new(96, 96),
								Position = UDim2.fromScale(1.05, 0.069),
								Selectable = true,
								Size = UDim2.fromOffset(24, 24),
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										local visible = use(showAttributesSection) and use(remainingPoints) > 0
										return if visible then 0 else 1
									end),
									TInfoFast
								),
								Visible = scope:Computed(function(use)
									return use(remainingPoints) > 0
								end),

								[OnEvent "Activated"] = function()
									if peek(remainingPoints) > 0 then
										local val = peek(tempStrange)
										tempStrange:set(val + 1)
									end
								end,

								[Children] = {
									scope:New "UIAspectRatioConstraint" {
										Name = "UIAspectRatioConstraint",
										DominantAxis = Enum.DominantAxis.Height,
									},

									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
									},
								}
							},
						}
					},

					-- Vibrance Button
					scope:New "TextButton" {
						Name = "Vibrance",
						Active = true,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showAttributesSection) then UDim2.fromScale(0.576, 0.736) else UDim2.fromScale(0.576, 0.78)
							end),
							25,
							0.9
						),
						Selectable = true,
						Size = UDim2.fromOffset(77, 29),
						Text = scope:Computed(function(use)
							local confirmed = use(vibrance)
							local temp = use(tempVibrance)
							return "Vibrance: " .. (confirmed + temp)
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 14,
						TextWrapped = true,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showAttributesSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showAttributesSection) then 0 else 1
									end),
									TInfoFast
								),
							},

							scope:New "ImageButton" {
								Name = "Remove",
								Active = true,
								BackgroundTransparency = 1,
								Image = "rbxassetid://8445471499",
								ImageRectOffset = Vector2.new(104, 904),
								ImageRectSize = Vector2.new(96, 96),
								Position = UDim2.fromScale(-0.403, 0.069),
								Selectable = true,
								Size = UDim2.fromOffset(24, 24),
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										local visible = use(showAttributesSection) and use(tempVibrance) > 0
										return if visible then 0 else 1
									end),
									TInfoFast
								),
								Visible = scope:Computed(function(use)
									return use(tempVibrance) > 0
								end),

								[OnEvent "Activated"] = function()
									local val = peek(tempVibrance)
									if val > 0 then
										tempVibrance:set(val - 1)
									end
								end,

								[Children] = {
									scope:New "UIAspectRatioConstraint" {
										Name = "UIAspectRatioConstraint",
										DominantAxis = Enum.DominantAxis.Height,
									},

									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
									},
								}
							},

							scope:New "ImageButton" {
								Name = "Add",
								Active = true,
								BackgroundTransparency = 1,
								Image = "rbxassetid://8445470984",
								ImageRectOffset = Vector2.new(804, 704),
								ImageRectSize = Vector2.new(96, 96),
								Position = UDim2.fromScale(1.05, 0.069),
								Selectable = true,
								Size = UDim2.fromOffset(24, 24),
								ImageTransparency = scope:Tween(
									scope:Computed(function(use)
										local visible = use(showAttributesSection) and use(remainingPoints) > 0
										return if visible then 0 else 1
									end),
									TInfoFast
								),
								Visible = scope:Computed(function(use)
									return use(remainingPoints) > 0
								end),

								[OnEvent "Activated"] = function()
									if peek(remainingPoints) > 0 then
										local val = peek(tempVibrance)
										tempVibrance:set(val + 1)
									end
								end,

								[Children] = {
									scope:New "UIAspectRatioConstraint" {
										Name = "UIAspectRatioConstraint",
										DominantAxis = Enum.DominantAxis.Height,
									},

									scope:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
											ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
											ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
										}),
										Rotation = 90,
									},

									scope:New "UIStroke" {
										Name = "UIStroke",
										Thickness = 0.5,
									},
								}
							},
						}
					},

					-- Innate Skill Header
					scope:New "TextLabel" {
						Name = "InnateHeader",
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Sarpanch.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = scope:Spring(
							scope:Computed(function(use)
								return if use(showAttributesSection) then UDim2.fromScale(0.161, 0.805) else UDim2.fromScale(0.161, 0.76)
							end),
							25,
							0.9
						),
						Size = UDim2.fromOffset(77, 29),
						Text = "INNATE SKILL",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 14,
						TextWrapped = true,
						TextTransparency = scope:Tween(
							scope:Computed(function(use)
								return if use(showAttributesSection) then 0 else 1
							end),
							TInfoFast
						),

						[Children] = {
							scope:New "UIGradient" {
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 75)),
									ColorSequenceKeypoint.new(0.393, Color3.fromRGB(102, 102, 102)),
									ColorSequenceKeypoint.new(0.678, Color3.fromRGB(208, 208, 208)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
								}),
								Rotation = 90,
							},

							scope:New "UIStroke" {
								Name = "UIStroke",
								Thickness = 0.5,
								Transparency = scope:Tween(
									scope:Computed(function(use)
										return if use(showAttributesSection) then 0 else 1
									end),
									TInfoFast
								),
							},
						}
					},
				}
			},

			-- Skills Component removed - Hunter x Hunter Nen system will replace this

			-- Skill Points Display (shows points available for skills)
			SkillPointsDisplay(scope, {
				showDisplay = showSkillsSection,
				skillPoints = skillPoints,
			}),

			-- SkillPointsHolder Component (for attribute points)
			SkillPointsHolder(scope, {
				showSkillPointsHolder = showSkillPointsHolder,
				availablePoints = remainingPoints,
				onConfirm = function()
					-- Apply temporary values to actual values
					knowledge:set(peek(knowledge) + peek(tempKnowledge))
					potency:set(peek(potency) + peek(tempPotency))
					dexterity:set(peek(dexterity) + peek(tempDexterity))
					strange:set(peek(strange) + peek(tempStrange))
					vibrance:set(peek(vibrance) + peek(tempVibrance))

					-- Reset temp values
					tempKnowledge:set(0)
					tempPotency:set(0)
					tempDexterity:set(0)
					tempStrange:set(0)
					tempVibrance:set(0)
				end,
			}),
		}
	}

	return mainHolder
end