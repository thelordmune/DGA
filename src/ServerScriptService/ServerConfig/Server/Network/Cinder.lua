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

	if not Character or not Character:GetAttribute("Equipped") then
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

	if PlayerObject and PlayerObject.Keys and not Server.Library.CheckCooldown(Character, "Cinder") then
		Server.Packets.Bvel.sendTo({Character = Character, Name = "RemoveBvel"},Player)
		print("removing bvel bro bro")
		cleanUp()
		Server.Library.SetCooldown(Character, "Cinder", 3)
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		Alchemy.Looped = false
		-- Alchemy:Play()

		Server.Library.TimedState(Character.Actions, "Cinder", Alchemy.Length)
		Server.Library.TimedState(Character.Stuns, "NoRotate", Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)

		Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
			Module = "Base",
			Function = "Cinder",
			Arguments = { Character, "Start" },
		})

		local startTime = os.clock()
		local hitInterval = 0.025 -- Hit every 0.2 seconds
		local lastHitTime = 0
		local hitTargets = {} -- Track who we've hit recently to prevent spam

		local connection
		task.delay(.6, function()
			connection = RunService.Heartbeat:Connect(function()
				local elapsed = os.clock() - startTime

				-- Stop when animation ends
				if elapsed >= Alchemy.Length then
					connection:Disconnect()
					return
				end

				-- Check if it's time for next hit
				if elapsed - lastHitTime >= hitInterval then
					lastHitTime = elapsed

					-- Clear hit tracking every few hits to allow re-hitting
					if elapsed % 1 < .2 then
						hitTargets = {}
					end

					-- Get targets in range
					local HitTargets = Hitbox.SpatialQuery(
						Character,
						Moves.Flame.Cinder["Hitboxes"][1]["HitboxSize"],
						Entity:GetCFrame() * Moves.Flame.Cinder["Hitboxes"][1]["HitboxOffset"],
						false
					)

					for _, Target in pairs(HitTargets) do
						if not hitTargets[Target] then
							hitTargets[Target] = true
							Server.Modules.Damage.Tag(Character, Target, Moves.Flame.Cinder["DamageTable"])
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
