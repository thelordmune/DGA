local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Server
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local Voxbreaker = require(Replicated.Modules.Voxel)
local SFX = Replicated.Assets.SFX
local WeaponStats = require(ServerStorage.Stats._Weapons)
local Moves = require(ServerStorage.Stats._Moves)
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Jail escape system
local JailEscape = require(Replicated.Modules.QuestsFolder.JailEscape)

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
	local Animation = Replicated.Assets.Animations.Misc.Deconstruct

	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)
	local Weapon: string = Entity.Weapon
	local Stats: {} = WeaponStats[Weapon]
	local Move: string = script.Name
	local Moves: {} = Moves[Move]

	local root = Character:FindFirstChild("HumanoidRootPart")

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	-- REMOVED Data.Air check - alchemy moves should work in air
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, "Deconstruct") then
		cleanUp()
		Server.Library.SetCooldown(Character,"Deconstruct",2.5)
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		Alchemy.Looped = false
		Alchemy:AdjustSpeed(1.5) -- Add mulitplier later
		Alchemy:Play()
		Server.Library.TimedState(Character.Actions, "Deconstruct", Alchemy.Length)
		Server.Library.TimedState(Character.Stuns, "NoRotate", Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "Jump-50", Alchemy.Length) -- Prevent jumping during move

		local soundeffects = {}
		local kfConn
		kfConn = Alchemy.KeyframeReached:Connect(function(key)
			if key == "Start" then
				-- CHECK FOR JAIL ESCAPE: If player is jailed, trigger escape sequence
				if not isNPC and Character:GetAttribute("Jailed") then
					-- Trigger jail escape!
					JailEscape.TriggerEscape(Player)
				end

				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "Deconstruct",
					Arguments = { Character },
				})
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Misc",
					Function = "DeconBolt",
					Arguments = { Character },
				})
				local startup = SFX.FMAB.Deconstruct:Clone()
				startup.Parent = root
				startup.Volume = 3
				startup:Play()
				Debris:AddItem(startup, startup.TimeLength)
				local targets = {}
				local partsDeconstructed = {}

				-- ENHANCED: Use spatial query to find ALL parts in the hitbox area
				local overlapParams = OverlapParams.new()
				overlapParams.FilterType = Enum.RaycastFilterType.Exclude
				overlapParams.FilterDescendantsInstances = { Character, workspace.World.Live }

				-- Create a box in front of the player to detect parts
				local boxCenter = root.Position + (root.CFrame.LookVector * 8)
				local boxSize = Vector3.new(12, 8, 16) -- Width, Height, Depth
				local boxCFrame = CFrame.new(boxCenter) * CFrame.Angles(0, math.rad(root.Orientation.Y), 0)

				local partsInBox = workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)
				local playerForward = root.CFrame.LookVector
				playerForward = Vector3.new(playerForward.X, playerForward.Y, playerForward.Z).Unit

				local hitSoundPlayed = false

				for _, hitPart in partsInBox do
					-- Check if it's a valid part to deconstruct (not terrain, not too large)
					if hitPart:IsA("BasePart") and not hitPart:IsA("Terrain") then
						local partSize = hitPart.Size
						local maxDimension = math.max(partSize.X, partSize.Y, partSize.Z)

						-- Only deconstruct parts smaller than 50 studs in any dimension
						if maxDimension <= 50 and not partsDeconstructed[hitPart] then
							partsDeconstructed[hitPart] = true

							-- Play hit sound only once
							if not hitSoundPlayed then
								hitSoundPlayed = true
								local wallhit = SFX.Hits.RAHit:Clone()
								wallhit.Parent = root
								wallhit.Volume = 1
								wallhit.TimePosition = 0.35
								wallhit:Play()
								Debris:AddItem(wallhit, wallhit.TimeLength)

								-- Screen shake
								if not isNPC then
									Server.Visuals.FireClient(Player, {
										Module = "Base",
										Function = "Shake",
										Arguments = {
											"Once",
											{ 6, 11, 0, 0.7, Vector3.new(1.1, 2, 1.1), Vector3.new(0.34, 0.25, 0.34) },
										},
									})
								end
							end

							-- Voxelize the part with limited debris count
							local voxelParts = Voxbreaker:VoxelizePart(hitPart, 20, 15)
							local MAX_DEBRIS_PER_PART = 15 -- Limit debris to prevent frame drops
							local debrisCount = 0

							for _, v in pairs(voxelParts) do
								-- Limit debris count
								if debrisCount >= MAX_DEBRIS_PER_PART then
									if v:IsA("BasePart") then
										v:Destroy()
									end
									continue
								end
								debrisCount = debrisCount + 1
								if v:IsA("BasePart") then
									-- Add trail to debris
									local attachment0 = Instance.new("Attachment")
									attachment0.Name = "TrailAttachment0"
									attachment0.Position = Vector3.new(0, v.Size.Y/2, 0)
									attachment0.Parent = v

									local attachment1 = Instance.new("Attachment")
									attachment1.Name = "TrailAttachment1"
									attachment1.Position = Vector3.new(0, -v.Size.Y/2, 0)
									attachment1.Parent = v

									local trail = Instance.new("Trail")
									trail.Attachment0 = attachment0
									trail.Attachment1 = attachment1
									trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
									trail.Transparency = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0.7),
										NumberSequenceKeypoint.new(0.5, 0.85),
										NumberSequenceKeypoint.new(1, 1)
									})
									trail.Lifetime = 0.3
									trail.MinLength = 0
									trail.WidthScale = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0.4),
										NumberSequenceKeypoint.new(0.5, 0.25),
										NumberSequenceKeypoint.new(1, 0.05)
									})
									trail.FaceCamera = true
									trail.LightEmission = 0.1
									trail.LightInfluence = 0.8
									trail.Parent = v

									v.CollisionGroup = "Rock"
									v.Anchored = false
									v.CanCollide = true

									local randomSpread = Vector3.new(
										(math.random() - 0.5) * 0.5,
										math.random() * 0.5,
										(math.random() - 0.5) * 0.5
									)
									local combinedDirection = (playerForward + randomSpread).Unit
									local velocityVector = combinedDirection * 120

									v.AssemblyLinearVelocity = velocityVector

									local debrisVelocity = Instance.new("BodyVelocity")
									debrisVelocity.Velocity = velocityVector
									debrisVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
									debrisVelocity.Parent = v

									Debris:AddItem(debrisVelocity, 0.5)
									Debris:AddItem(v, 8 + math.random() * 4)
								end
							end
						end
					end
				end

				-- ORIGINAL: Spatial query for models/entities
				for i = 1, 5 do
					if #targets >= 1 then
						break
					end

					local TargetsFound, _ = Hitbox.SpatialQuery(
						Character,
						Stats["Hitboxes"][1]["HitboxSize"],
						Entity:GetCFrame() * Stats["Hitboxes"][1]["HitboxOffset"],
						false
					)

					for _, target in TargetsFound do
						if target ~= Character and not table.find(targets, target) and target:IsA("Model") then
							table.insert(targets, target)
							-- Create damage table with Junction properties for guaranteed arm removal
							local damageTable = {}
							for k, v in pairs(Stats["Critical"]["DamageTable"]) do
								damageTable[k] = v
							end
							-- Add Junction properties for Deconstruct (10% chance arm removal)
							damageTable.Junction = "RandomArm"
							damageTable.JunctionChance = 0.10
							Server.Modules.Damage.Tag(Character, target, damageTable)
						end
						if target:GetAttribute("Id") then
							if not soundeffects[target] then
								soundeffects[target] = {
									wallhit = SFX.Hits.RAHit:Clone(),
								}
								soundeffects[target].wallhit.Parent = root
								soundeffects[target].wallhit.Volume = 1
								soundeffects[target].wallhit.TimePosition = 0.35
								soundeffects[target].wallhit:Play()
								Debris:AddItem(soundeffects[target].wallhit, soundeffects[target].wallhit.TimeLength)
							end

							Server.Visuals.FireClient(Player, {
								Module = "Base",
								Function = "Shake",
								Arguments = {
									"Once",
									{ 6, 11, 0, 0.7, Vector3.new(1.1, 2, 1.1), Vector3.new(0.34, 0.25, 0.34) },
								},
							})
							local parts = Voxbreaker:VoxelizePart(target, 20, 15)
							local entityForward = root.CFrame.LookVector
							entityForward = Vector3.new(entityForward.X, entityForward.Y, entityForward.Z).Unit
							-- Limit debris count to prevent frame drops
							local MAX_ENTITY_DEBRIS = 15
							local entityDebrisCount = 0
							for _, v in pairs(parts) do
								-- Limit debris count
								if entityDebrisCount >= MAX_ENTITY_DEBRIS then
									if v:IsA("BasePart") then
										v:Destroy()
									end
									continue
								end
								entityDebrisCount = entityDebrisCount + 1
								if v:IsA("BasePart") then
									-- Add trail to the debris part
									local attachment0 = Instance.new("Attachment")
									attachment0.Name = "TrailAttachment0"
									attachment0.Position = Vector3.new(0, v.Size.Y/2, 0)
									attachment0.Parent = v

									local attachment1 = Instance.new("Attachment")
									attachment1.Name = "TrailAttachment1"
									attachment1.Position = Vector3.new(0, -v.Size.Y/2, 0)
									attachment1.Parent = v

									local trail = Instance.new("Trail")
									trail.Attachment0 = attachment0
									trail.Attachment1 = attachment1

									-- White trail color
									trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
									trail.Transparency = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0.7),
										NumberSequenceKeypoint.new(0.5, 0.85),
										NumberSequenceKeypoint.new(1, 1)
									})
									trail.Lifetime = 0.3
									trail.MinLength = 0

									-- Smaller, more subtle trail
									trail.WidthScale = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0.4),
										NumberSequenceKeypoint.new(0.5, 0.25),
										NumberSequenceKeypoint.new(1, 0.05)
									})

									trail.FaceCamera = true
									trail.LightEmission = 0.1
									trail.LightInfluence = 0.8
									trail.Parent = v

									-- Create a connection to update the hitbox as the part moves
									local hitConnection
									hitConnection = RunService.PostSimulation:Connect(function()
										local TargetsFound = Hitbox.SpatialQuery(
											Character, -- The entity performing the action
											v.Size, -- Use the part's actual size
											v.CFrame, -- Current CFrame of the part
											false -- Don't visualize these (would be too many)
										)

										for _, target in TargetsFound do
											if
												target ~= Character
												and not table.find(targets, target)
												and target:IsA("Model")
											then
												table.insert(targets, target)
												Server.Modules.Damage.Tag(
													Character,
													target,
													Moves["DamageTable"]
												)
											end
										end
									end)

									-- Initial check
									local initialTargets = Hitbox.SpatialQuery(Character, v.Size, v.CFrame, false)

									for _, target in initialTargets do
										if
											target ~= Character
											and not table.find(targets, target)
											and target:IsA("Model")
										then
											table.insert(targets, target)
											Server.Modules.Damage.Tag(
												Character,
												target,
												Moves["DamageTable"]
											)
										end
									end
									v.CollisionGroup = "Rock"
									v.Anchored = false
									v.CanCollide = true

									local direction = (v.Position - root.Position).Unit

									local randomSpread = Vector3.new(
										(math.random() - 0.5) * 0.5,
										math.random() * 0.5,
										(math.random() - 0.5) * 0.5
									)

									local combinedDirection = (entityForward + randomSpread).Unit
									local velocityVector = combinedDirection * 120

									v.AssemblyLinearVelocity = velocityVector

									local debrisVelocity = Instance.new("BodyVelocity")
									debrisVelocity.Velocity = velocityVector
									debrisVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
									debrisVelocity.Parent = v

									-- Also add some angular velocity for rotation
									-- local angularVelocity = Instance.new("BodyAngularVelocity")
									-- angularVelocity.AngularVelocity = Vector3.new(
									--     (math.random() - 0.5) * 20,
									--     (math.random() - 0.5) * 20,
									--     (math.random() - 0.5) * 20
									-- )
									-- angularVelocity.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
									-- angularVelocity.Parent = v

									v.Destroying:Connect(function()
										hitConnection:Disconnect()
									end)

									game:GetService("Debris"):AddItem(debrisVelocity, 0.5)
									-- game:GetService("Debris"):AddItem(angularVelocity, 0.5)
									game:GetService("Debris"):AddItem(v, 8 + math.random() * 4)
								end
							end
						end
					end
					task.wait(0.001)
				end
			end
		end)
		table.insert(activeConnections, kfConn)
	end
end

return NetworkModule
