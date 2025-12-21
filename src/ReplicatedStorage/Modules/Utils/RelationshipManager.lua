--[[
	RelationshipManager

	Handles NPC relationship persistence and progression.
	- Tracks relationship values (0-100) per NPC per player
	- Saves/loads from player DataStore
	- Locks NPC appearance once Friend tier (40+) is reached
	- Provides tier calculations and relationship bonuses

	Tiers:
	- Stranger: 0-19
	- Acquaintance: 20-39
	- Friend: 40-59 (appearance locks here)
	- Close Friend: 60-79
	- Trusted: 80-100
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OccupationData = require(ReplicatedStorage.Modules.OccupationData)

local RelationshipManager = {}

-- Constants
RelationshipManager.FRIEND_THRESHOLD = 40 -- Tier at which appearance locks
RelationshipManager.INTERACTION_GAIN = 5 -- Base relationship gain per interaction
RelationshipManager.HIT_PENALTY = 8 -- Relationship loss per hit
RelationshipManager.MAX_DAILY_INTERACTIONS = 5 -- Max interactions per NPC per day

-- Tier thresholds
RelationshipManager.TIERS = {
	{ name = "Stranger", min = 0, max = 19 },
	{ name = "Acquaintance", min = 20, max = 39 },
	{ name = "Friend", min = 40, max = 59 },
	{ name = "Close Friend", min = 60, max = 79 },
	{ name = "Trusted", min = 80, max = 100 },
}

-- Get tier name from relationship value
function RelationshipManager.getTier(value: number): string
	value = math.clamp(value or 0, 0, 100)

	for _, tier in ipairs(RelationshipManager.TIERS) do
		if value >= tier.min and value <= tier.max then
			return tier.name
		end
	end

	return "Stranger"
end

-- Check if relationship has reached Friend tier (appearance should be locked)
function RelationshipManager.isBefriended(value: number): boolean
	return (value or 0) >= RelationshipManager.FRIEND_THRESHOLD
end

-- Generate a unique ID for an NPC based on their identity
-- This creates a consistent ID that can be used across sessions
function RelationshipManager.generateNPCId(name: string, occupation: string): string
	-- Use name + occupation as unique identifier
	-- This means the same named NPC with same occupation is the same "person"
	return string.format("%s_%s", name or "Unknown", occupation or "Citizen")
end

-- Get relationship data for a specific NPC from player data
-- Returns: { value, name, occupation, personality, appearance } or nil
function RelationshipManager.getRelationship(playerData, npcId: string)
	if not playerData or not playerData.NPCRelationships then
		return nil
	end

	return playerData.NPCRelationships[npcId]
end

-- Get all NPC relationships for a player
function RelationshipManager.getAllRelationships(playerData)
	if not playerData or not playerData.NPCRelationships then
		return {}
	end

	return playerData.NPCRelationships
end

-- Add relationship progress (server-side only)
-- Returns: newValue, tier, isBefriended, wasNewlyBefriended
function RelationshipManager.addProgress(player, npcId: string, npcName: string, occupation: string, personality: string, appearance)
	if not RunService:IsServer() then
		warn("[RelationshipManager] addProgress can only be called on server")
		return 0, "Stranger", false, false
	end

	local Global = require(ReplicatedStorage.Modules.Shared.Global)

	-- Get personality modifier
	local personalityData = OccupationData.Personalities[personality]
	local modifier = personalityData and personalityData.modifier or 1.0

	-- Calculate gain with modifier
	local gain = math.floor(RelationshipManager.INTERACTION_GAIN * modifier)

	local newValue = 0
	local wasBefriended = false
	local isNowBefriended = false

	Global.SetData(player, function(data)
		-- Ensure NPCRelationships exists
		if not data.NPCRelationships then
			data.NPCRelationships = {}
		end

		-- Get or create relationship entry
		local relationship = data.NPCRelationships[npcId]
		if not relationship then
			relationship = {
				value = 0,
				name = npcName,
				occupation = occupation,
				personality = personality,
				appearance = nil, -- Will be set when befriended
			}
		end

		wasBefriended = RelationshipManager.isBefriended(relationship.value)

		-- Add progress
		relationship.value = math.clamp(relationship.value + gain, 0, 100)
		newValue = relationship.value

		isNowBefriended = RelationshipManager.isBefriended(newValue)

		-- Lock appearance when reaching Friend tier for the first time
		if isNowBefriended and not wasBefriended and appearance then
			relationship.appearance = appearance
		end

		-- Update identity info in case it changed (for strangers only)
		if not wasBefriended then
			relationship.name = npcName
			relationship.occupation = occupation
			relationship.personality = personality
		end

		data.NPCRelationships[npcId] = relationship
		return data
	end)

	local tier = RelationshipManager.getTier(newValue)
	local wasNewlyBefriended = isNowBefriended and not wasBefriended

	return newValue, tier, isNowBefriended, wasNewlyBefriended
end

-- Reduce relationship (e.g., when player hits NPC)
-- Returns: newValue, tier
function RelationshipManager.reduceProgress(player, npcId: string, amount: number?)
	if not RunService:IsServer() then
		warn("[RelationshipManager] reduceProgress can only be called on server")
		return 0, "Stranger"
	end

	local Global = require(ReplicatedStorage.Modules.Shared.Global)
	amount = amount or RelationshipManager.HIT_PENALTY

	local newValue = 0

	Global.SetData(player, function(data)
		if not data.NPCRelationships or not data.NPCRelationships[npcId] then
			return data
		end

		local relationship = data.NPCRelationships[npcId]
		relationship.value = math.clamp(relationship.value - amount, 0, 100)
		newValue = relationship.value

		data.NPCRelationships[npcId] = relationship
		return data
	end)

	return newValue, RelationshipManager.getTier(newValue)
end

-- Get locked appearance for a befriended NPC
-- Returns appearance table or nil if not befriended
function RelationshipManager.getLockedAppearance(playerData, npcId: string)
	local relationship = RelationshipManager.getRelationship(playerData, npcId)

	if relationship and RelationshipManager.isBefriended(relationship.value) then
		return relationship.appearance
	end

	return nil
end

-- Check if an NPC should use locked appearance for this player
function RelationshipManager.shouldUseSavedAppearance(playerData, npcId: string): boolean
	local relationship = RelationshipManager.getRelationship(playerData, npcId)
	return relationship ~= nil and RelationshipManager.isBefriended(relationship.value) and relationship.appearance ~= nil
end

-- Get the saved identity for a befriended NPC
-- Returns: name, occupation, personality or nil if not befriended
function RelationshipManager.getSavedIdentity(playerData, npcId: string)
	local relationship = RelationshipManager.getRelationship(playerData, npcId)

	if relationship and RelationshipManager.isBefriended(relationship.value) then
		return relationship.name, relationship.occupation, relationship.personality
	end

	return nil, nil, nil
end

-- Sync relationship data to client
function RelationshipManager.syncToClient(player, npcId: string, value: number, tier: string, isBefriended: boolean)
	if not RunService:IsServer() then
		return
	end

	local Packets = require(ReplicatedStorage.Modules.Packets)

	Packets.NPCRelationshipSync.send({
		NPCId = npcId,
		Value = value,
		Tier = tier,
		IsBefriended = isBefriended,
	}, player)
end

return RelationshipManager
