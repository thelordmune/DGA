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

	if not Character or not Character:GetAttribute("Equipped") then
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

	if PlayerObject and PlayerObject.Keys and not Data.Air and not Server.Library.CheckCooldown(Character, "Deconstruct") then
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

		local soundeffects = {}
		local kfConn
		kfConn = Alchemy.KeyframeReached:Connect(function(key)
			if key == "Start" then
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "Deconstruct",
					Arguments = { Character },
				})
				local startup = SFX.FMAB.Deconstruct:Clone()
				startup.Parent = root
				startup.Volume = 3
				startup:Play()
				Debris:AddItem(startup, startup.TimeLength)
				local targets = {}
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
							Server.Modules.Damage.Tag(Character, target, Stats["Critical"]["DamageTable"])
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
							local playerForward = root.CFrame.LookVector
							playerForward = Vector3.new(playerForward.X, playerForward.Y, playerForward.Z).Unit
							-- Replace the debris velocity section with this:
							for _, v in pairs(parts) do
								if v:IsA("BasePart") then
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

									-- Get direction from player to debris piece
									local direction = (v.Position - root.Position).Unit

									-- Add some randomness to the direction
									local randomSpread = Vector3.new(
										(math.random() - 0.5) * 0.5, -- X spread (-0.25 to 0.25)
										math.random() * 0.5, -- Y spread (0 to 0.5)
										(math.random() - 0.5) * 0.5 -- Z spread (-0.25 to 0.25)
									)

									-- Combine forward force with random spread
									local combinedDirection = (playerForward + randomSpread).Unit

									-- Calculate velocity - stronger forward force
									local debrisVelocity = Instance.new("BodyVelocity")
									debrisVelocity.Velocity = combinedDirection * 120 -- Increased base speed

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
