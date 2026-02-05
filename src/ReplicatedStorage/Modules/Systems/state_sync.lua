--[[
	State Sync System (CLIENT) - ECS Packet-Based Replication

	Receives ECS state updates from server via ByteNet packets and applies
	them to the client's local ECS world.

	This replaces the old StringValue-based replication with pure ECS.
	Server sends StateSync packets when states change, client applies them
	to the local ECS world so StateManager reads work correctly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Early exit for server
if RunService:IsServer() then
	return {
		run = function() end,
		settings = {
			phase = "Heartbeat",
			client_only = true,
		}
	}
end

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local Packets = require(ReplicatedStorage.Modules.Packets)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local Players = game:GetService("Players")

-- Category ID to component mapping
local ID_TO_COMPONENT = {
	[0] = comps.StateActions,
	[1] = comps.StateStuns,
	[2] = comps.StateIFrames,
	[3] = comps.StateSpeeds,
	[4] = comps.StateFrames,
	[5] = comps.StateStatus,
}

-- Category ID to name (for debugging)
local ID_TO_NAME = {
	[0] = "Actions",
	[1] = "Stuns",
	[2] = "IFrames",
	[3] = "Speeds",
	[4] = "Frames",
	[5] = "Status",
}

-- Debug flag
local DEBUG = false

-- Track initialization
local initialized = false

-- Get entity for a character on the client
local function getEntityForCharacter(character: Model): number?
	if not character then return nil end

	-- Check if it's the local player's character
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		if player == Players.LocalPlayer then
			-- Try local_player ref first, then player ref
			local entity = ref.get("local_player")
			if not entity then
				entity = ref.get("player", player)
			end
			return entity
		else
			-- Other player's character
			return ref.get("player", player)
		end
	end

	-- NPC - find by character model
	return RefManager.entity.find(character)
end

-- Apply state from server to client ECS
local function applyStateToECS(character: Model, categoryId: number, states: {string})
	local component = ID_TO_COMPONENT[categoryId]
	if not component then
		warn(`[StateSync/Client] Unknown category ID: {categoryId}`)
		return
	end

	local entity = getEntityForCharacter(character)
	if not entity then
		-- Entity might not exist yet on client, that's OK
		if DEBUG then
			warn(`[StateSync/Client] No entity found for character: {character.Name}`)
		end
		return
	end

	-- Apply state to client's ECS world
	world:set(entity, component, states)

	if DEBUG then
		local categoryName = ID_TO_NAME[categoryId] or "Unknown"
		if #states > 0 then
			print(`[StateSync/Client] Applied {categoryName} to {character.Name}: {table.concat(states, ", ")}`)
		else
			print(`[StateSync/Client] Cleared {categoryName} for {character.Name}`)
		end
	end
end

-- Set up packet listener
local function initializePacketListener()
	if initialized then return end
	initialized = true

	Packets.StateSync.listen(function(data)
		local character = data.Character
		local categoryId = data.Category
		local states = data.States

		if character and character:IsA("Model") then
			applyStateToECS(character, categoryId, states)
		end
	end)

	print(`[StateSync/Client] ✅ ECS packet-based state sync initialized`)
end

-- The run function is called every frame but we only need to initialize once
local function state_sync()
	if not initialized then
		initializePacketListener()
	end
	-- No per-frame work needed - packets are handled by listeners
end

return {
	run = function()
		state_sync()
	end,
	settings = {
		phase = "Heartbeat",
		depends_on = {},
		client_only = true,
	}
}
