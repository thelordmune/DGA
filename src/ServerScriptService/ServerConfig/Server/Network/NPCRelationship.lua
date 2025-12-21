--[[
	NPCRelationship Network Handler

	Handles client requests for NPC relationship interactions.
	- Tracks relationship progress when player interacts with wanderer NPCs
	- Saves relationship data to player profile
	- Locks NPC appearance once Friend tier is reached
]]

local NetworkModule = {}
NetworkModule.__index = NetworkModule

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RelationshipManager = require(ReplicatedStorage.Modules.Utils.RelationshipManager)
local Global = require(ReplicatedStorage.Modules.Shared.Global)
local Packets = require(ReplicatedStorage.Modules.Packets)

NetworkModule.EndPoint = function(Player, Data)
	if not Data or not Data.Action then
		warn("[NPCRelationship] Invalid data received")
		return
	end

	local action = Data.Action
	local npcId = Data.NPCId

	if not npcId then
		warn("[NPCRelationship] No NPC ID provided")
		return
	end

	if action == "Interact" then
		-- Player completed a dialogue interaction with an NPC
		local npcName = Data.NPCName or "Citizen"
		local occupation = Data.Occupation or "Civilian"
		local personality = Data.Personality or "Professional"
		local appearance = Data.Appearance -- Table with outfit, race, gender, hair, skinColor

		-- Add relationship progress
		local newValue, tier, isBefriended, wasNewlyBefriended = RelationshipManager.addProgress(
			Player,
			npcId,
			npcName,
			occupation,
			personality,
			appearance
		)

		-- Sync the new relationship state to the client
		RelationshipManager.syncToClient(Player, npcId, newValue, tier, isBefriended)

		-- Log if player just became friends with this NPC
		if wasNewlyBefriended then
			print(string.format("[NPCRelationship] %s became friends with %s (%s)! Appearance locked.",
				Player.Name, npcName, occupation))
		end

	elseif action == "GetRelationship" then
		-- Client requesting current relationship status for an NPC
		local playerData = Global.GetData(Player)
		local relationship = RelationshipManager.getRelationship(playerData, npcId)

		local value = relationship and relationship.value or 0
		local tier = RelationshipManager.getTier(value)
		local isBefriended = RelationshipManager.isBefriended(value)

		RelationshipManager.syncToClient(Player, npcId, value, tier, isBefriended)

	elseif action == "Hit" then
		-- Player hit an NPC - reduce relationship
		local newValue, tier = RelationshipManager.reduceProgress(Player, npcId)
		local isBefriended = RelationshipManager.isBefriended(newValue)

		RelationshipManager.syncToClient(Player, npcId, newValue, tier, isBefriended)
	end
end

return NetworkModule
