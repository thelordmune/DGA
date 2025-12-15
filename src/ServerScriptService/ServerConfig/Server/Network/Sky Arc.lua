local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Server
local Library = require(Replicated.Modules.Library)
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

local activeConnections = {}
local activeTweens = {}

local function cleanUp()
	for _, conn in pairs(activeConnections) do
		conn:Disconnect()
	end
	activeConnections = {}

	for _, t in pairs(activeTweens) do
		t:Cancel()
	end
	activeTweens = {}
end



-- Get the material and color of what the player is standing on
local function getGroundMaterial(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return Enum.Material.Plastic, Color3.fromRGB(100, 100, 100)
	end

	local rayOrigin = root.Position
	local rayDirection = Vector3.new(0, -10, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character, workspace.World.Visuals }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if raycastResult and raycastResult.Instance then
		return raycastResult.Instance.Material, raycastResult.Instance.Color
	end

	-- Default to stone-like material
	return Enum.Material.Slate, Color3.fromRGB(100, 100, 100)
end

-- Find surface at mouse position
local function findSurfaceAtPosition(character, mousePosition)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	-- Raycast parameters
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {character, workspace.World.Visuals}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Raycast down from high above the mouse position to find ground
	local rayStart = Vector3.new(mousePosition.X, mousePosition.Y + 100, mousePosition.Z)
	local rayDirection = Vector3.new(0, -200, 0)

	local rayResult = workspace:Raycast(rayStart, rayDirection, rayParams)

	if rayResult then
		return rayResult.Position
	end

	-- If no surface found, use the mouse position itself
	return mousePosition
end

-- Calculate arc points for bridge
local function calculateArcPoints(startPos, endPos, numSegments)
	local points = {}
	local horizontalDistance = (Vector3.new(endPos.X, startPos.Y, endPos.Z) - startPos).Magnitude
	local heightDifference = endPos.Y - startPos.Y
	
	-- Arc height is based on distance (higher arc for longer bridges)
	local arcHeight = math.max(heightDifference * 0.5, horizontalDistance * 0.3)
	
	for i = 0, numSegments do
		local t = i / numSegments
		
		-- Linear interpolation for horizontal position
		local horizontalPos = startPos:Lerp(endPos, t)
		
		-- Parabolic arc for vertical position
		local arcOffset = 4 * arcHeight * t * (1 - t) -- Parabola formula
		local finalPos = Vector3.new(horizontalPos.X, horizontalPos.Y + arcOffset, horizontalPos.Z)
		
		table.insert(points, finalPos)
	end
	
	return points
end

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character

	if not Character then
		return
	end

	-- Check if this is an NPC (no Player instance) or a real player
	local isNPC = typeof(Player) ~= "Instance" or not Player:IsA("Player")

	-- For players, check equipped status
	if not isNPC and not Character:GetAttribute("Equipped") then
		return
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Misc.Alchemy

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, "Sky Arc") then
		-- Get endpoint from mouse position (or in front of NPC)
		local endpoint

		if isNPC then
			-- For NPCs, create bridge in front of them
			local root = Character.HumanoidRootPart
			local lookVector = root.CFrame.LookVector
			lookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
			endpoint = root.Position + (lookVector * 30) + Vector3.new(0, 10, 0)
		else
			-- For players, use mouse position
			endpoint = findSurfaceAtPosition(Character, Data.MousePosition)
		end

		if not endpoint then
			return
		end

		cleanUp()
		Server.Library.SetCooldown(Character, "Sky Arc", 8)
		-- Apply 1 second soft cooldown on cast
		Server.Library.SetCooldown(Character, "SkillCast", 1)
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		if not Alchemy then
			---- print("Failed to load Sky Arc animation")
			return
		end

		Alchemy.Looped = false

		-- Set character states
		Server.Library.TimedState(Character.Actions, "Sky Arc", Alchemy.Length)
		Server.Library.TimedState(Character.Stuns, "NoRotate", Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "Jump-50", Alchemy.Length) -- Prevent jumping during move

		-- Track connections for cleanup
		local connections = {}

		local kfConn
		kfConn = Alchemy.KeyframeReached:Connect(function(key)
			if key == "Clap" then
				-- Play clap sound
				local s = Replicated.Assets.SFX.FMAB.Clap:Clone()
				s.Parent = Character.HumanoidRootPart
				s:Play()
				Debris:AddItem(s, s.TimeLength)

				-- Visual effects
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "Clap",
					Arguments = { Character },
				})
			end

			if key == "Touch" then
				-- Play transmutation sound
				local s = Replicated.Assets.SFX.FMAB.Transmute:Clone()
				s.Volume = 2
				s.Parent = Character.HumanoidRootPart
				s:Play()
				Debris:AddItem(s, s.TimeLength)

				-- Get ground material and color
				local groundMaterial, groundColor = getGroundMaterial(Character)

				-- Create the bridge
				local root = Character.HumanoidRootPart
				local startPos = root.Position + Vector3.new(0, -2, 0) -- Start at feet

				-- Calculate arc points
				local distance = (endpoint - startPos).Magnitude
				local numArcPoints = math.floor(distance / 2) -- Arc points every 2 studs
				numArcPoints = math.clamp(numArcPoints, 10, 40)

				local arcPoints = calculateArcPoints(startPos, endpoint, numArcPoints)

				-- Track previous plank position for spawning effect
				local previousPlankPos = startPos

				-- Create makeshift bridge with lengthwise planks
				local plankCount = 0
				for i = 1, #arcPoints - 1 do
					local currentPoint = arcPoints[i]
					local nextPoint = arcPoints[i + 1]

					-- Calculate direction along the arc
					local direction = (nextPoint - currentPoint).Unit

					-- Create 2-4 planks per arc segment for makeshift look
					local planksPerSegment = math.random(2, 4)

					for p = 1, planksPerSegment do
						plankCount = plankCount + 1

						-- Capture the previous position for this plank
						local spawnFromPos = previousPlankPos

						task.delay((plankCount - 1) * 0.04, function()
							-- Create plank
							local plank = Instance.new("Part")
							plank.Name = "SkyArc_" .. HttpService:GenerateGUID(false)
							plank.Anchored = true
							plank.CanCollide = true
							plank.Material = groundMaterial
							plank.Color = groundColor
							plank.Transparency = 1 -- Start fully transparent

							-- Plank dimensions - bigger and wider
							local plankLength = math.random(8, 14) -- Longer planks (was 6-10)
							local plankWidth = math.random(3, 5) -- Wider planks (was 2-3)
							local plankThickness = 0.8 -- Thicker planks (was 0.5)
							plank.Size = Vector3.new(plankWidth, plankThickness, plankLength)

							-- Position plank along the arc with some randomness
							local t = (p - 1) / planksPerSegment
							local plankPos = currentPoint:Lerp(nextPoint, t)

							-- Add slight random offset for makeshift look
							local randomOffset = Vector3.new(
								(math.random() - 0.5) * 1.5, -- Side to side variation
								(math.random() - 0.5) * 0.3, -- Slight height variation
								(math.random() - 0.5) * 0.5  -- Forward/back variation
							)
							plankPos = plankPos + randomOffset

							-- Orient plank lengthwise along the bridge direction
							local lookAt = CFrame.lookAt(plankPos, plankPos + direction)

							-- Add slight random rotation for makeshift look
							local randomRotation = CFrame.Angles(
								math.rad((math.random() - 0.5) * 5), -- Slight pitch
								math.rad((math.random() - 0.5) * 10), -- Slight yaw
								math.rad((math.random() - 0.5) * 3)  -- Slight roll
							)

							local finalCFrame = lookAt * randomRotation

							-- Start at the previous plank's position (spawn from behind)
							plank.CFrame = CFrame.new(spawnFromPos) * lookAt.Rotation * randomRotation
							plank.Parent = workspace.Transmutables

							-- Tween from previous position to final position AND fade in transparency
							local tweenDuration = 0.2 + (math.random() * 0.1)
							local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
							local tween = TweenService:Create(plank, tweenInfo, {
								CFrame = finalCFrame,
								Transparency = 0 -- Fade from 1 (invisible) to 0 (solid)
							})
							tween:Play()

							-- Visual effects (only occasionally)
							if plankCount % 5 == 1 then
								Server.Visuals.Ranged(plank.Position, 300, {
									Module = "Base",
									Function = "WallErupt",
									Arguments = { plank, Character }
								})
							end

							-- Destroy after 15 seconds
							Debris:AddItem(plank, 15)
						end)

						-- Update previous position for next plank
						local t = (p - 1) / planksPerSegment
						previousPlankPos = currentPoint:Lerp(nextPoint, t)
					end
				end
			end
		end)
		table.insert(connections, kfConn)

		-- Cleanup when animation ends
		local animEndConn
		animEndConn = Alchemy.Stopped:Connect(function()
			if kfConn then
				kfConn:Disconnect()
				kfConn = nil
			end
			if animEndConn then
				animEndConn:Disconnect()
				animEndConn = nil
			end
		end)
		table.insert(connections, animEndConn)
	end
end

return NetworkModule

