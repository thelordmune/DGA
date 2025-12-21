--[[
	Pickpocket Network Handler

	Handles client requests for pickpocketing wanderer NPCs.
	- Validates the pickpocket attempt
	- Calculates success/failure
	- Grants loot on success
	- Updates reputation and alignment
	- Triggers guard spawns on high crime
]]

local NetworkModule = {}
NetworkModule.__index = NetworkModule

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InfluenceManager = require(ReplicatedStorage.Modules.Utils.InfluenceManager)
local Global = require(ReplicatedStorage.Modules.Shared.Global)
local Packets = require(ReplicatedStorage.Modules.Packets)

-- Cooldown tracking per player
local pickpocketCooldowns = {}

NetworkModule.EndPoint = function(Player, Data)
	if not Data or not Data.NPCId then
		warn("[Pickpocket] Invalid data received")
		return
	end

	local npcId = Data.NPCId
	local occupation = Data.Occupation or "Civilian"

	-- Check cooldown
	local now = os.clock()
	local lastAttempt = pickpocketCooldowns[Player.UserId] or 0
	if now - lastAttempt < InfluenceManager.PICKPOCKET_COOLDOWN then
		Packets.PickpocketResult.send({
			Success = false,
			Message = "Wait before pickpocketing again!",
			Money = nil,
			Item = nil,
			GuardsSpawning = false,
		}, Player)
		return
	end

	-- Update cooldown
	pickpocketCooldowns[Player.UserId] = now

	-- Attempt pickpocket
	local success, message, loot, guardsSpawning = InfluenceManager.attemptPickpocket(Player, npcId, occupation)

	-- Set NPC as hostile toward player
	InfluenceManager.setNPCHostile(Player, npcId)

	-- Send result to client
	Packets.PickpocketResult.send({
		Success = success,
		Message = message,
		Money = loot and loot.money or nil,
		Item = loot and loot.item or nil,
		GuardsSpawning = guardsSpawning or false,
	}, Player)

	-- Sync updated influence and money to client
	InfluenceManager.syncToClient(Player)

	-- Log the attempt
	if success then
		print(string.format("[Pickpocket] %s successfully pickpocketed %s (%s) - Got %d money%s",
			Player.Name, npcId, occupation,
			loot and loot.money or 0,
			loot and loot.item and (" + " .. loot.item) or ""))
	else
		print(string.format("[Pickpocket] %s FAILED to pickpocket %s (%s) - Caught!",
			Player.Name, npcId, occupation))
	end

	-- Spawn guards if threshold reached
	if guardsSpawning then
		print(string.format("[Pickpocket] %s has triggered guard spawn!", Player.Name))
		-- Guard spawning is handled by the GuardSpawner system
		-- We just need to mark the player as wanted
		local playerData = Global.GetData(Player)
		if playerData then
			Global.SetData(Player, function(data)
				data.Influence.GuardsSpawnedOn = (data.Influence.GuardsSpawnedOn or 0) + 1
				return data
			end)
		end
	end
end

return NetworkModule
