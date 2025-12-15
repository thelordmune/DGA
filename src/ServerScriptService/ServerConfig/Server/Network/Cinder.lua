local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
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
	local Animation = Replicated.Assets.Animations.Abilities.Flame[script.Name]
	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)

	local root = Character:FindFirstChild("HumanoidRootPart")

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, "Cinder") then
		Server.Packets.Bvel.sendTo({Character = Character, Name = "RemoveBvel"},Player)
		---- print("removing bvel bro bro")
		cleanUp()
		Server.Library.SetCooldown(Character, "Cinder", 8) -- Increased from 3 to 8 seconds
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		Alchemy.Looped = false
		-- Alchemy:Play()

		Server.Library.TimedState(Character.Actions, "Cinder", Alchemy.Length)
		Server.Library.TimedState(Character.Stuns, "NoRotate", Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "Jump-50", Alchemy.Length) -- Prevent jumping during move

		-- Fix VFX positioning - get fresh position to avoid dash desync
		local currentPosition = Character.HumanoidRootPart.Position
		Server.Visuals.Ranged(currentPosition, 300, {
			Module = "Base",
			Function = "Cinder",
			Arguments = { Character, "Start" },
		})

		local startTime = os.clock()
		-- DPS Calculation: 3.5 damage every 0.5 seconds = 7 DPS per target
		-- This provides consistent, predictable damage instead of chunky bursts
		local hitInterval = 0.15 -- Hit every 0.5 seconds for consistent DPS
		local lastGlobalHitTime = 0
		local targetLastHitTimes = {} -- Track individual hit times per target

		local connection
		task.delay(.6, function()
			connection = RunService.Heartbeat:Connect(function()
				local currentTime = os.clock()
				local elapsed = currentTime - startTime

				-- Stop when animation ends
				if elapsed >= Alchemy.Length then
					connection:Disconnect()
					return
				end

				-- Check if it's time for next global hit check
				if currentTime - lastGlobalHitTime >= hitInterval then
					lastGlobalHitTime = currentTime

					-- Get targets in range - use fresh CFrame to avoid dash desync
					local currentCFrame = Character.HumanoidRootPart.CFrame
					local HitTargets = Hitbox.SpatialQuery(
						Character,
						Moves.Flame.Cinder["Hitboxes"][1]["HitboxSize"],
						currentCFrame * Moves.Flame.Cinder["Hitboxes"][1]["HitboxOffset"],
						false
					)

					for _, Target in pairs(HitTargets) do
						-- Check if enough time has passed since we last hit this specific target
						local lastHitTime = targetLastHitTimes[Target] or 0
						if currentTime - lastHitTime >= hitInterval then
							targetLastHitTimes[Target] = currentTime
							Server.Modules.Damage.Tag(Character, Target, Moves.Flame.Cinder["DamageTable"])

							-- Visual effect for each consistent hit
							Server.Visuals.Ranged(Target.HumanoidRootPart.Position, 300, {
								Module = "Base",
								Function = "CinderHit",
								Arguments = { Target }
							})

							-- Debug print for consistent DPS tracking
							---- print("Cinder consistent hit:", Target.Name, "damage: 1.5, interval:", hitInterval)
						end
					end

					-- Clean up old target tracking (remove targets not hit in last 2 seconds)
					for target, lastTime in pairs(targetLastHitTimes) do
						if currentTime - lastTime > 2 then
							targetLastHitTimes[target] = nil
						end
					end
				end
			end) -- End of heartbeat connection function
			table.insert(activeConnections, connection)
		end)
		-- Add connection to list of active connections to clean up later
	end
end

return NetworkModule
