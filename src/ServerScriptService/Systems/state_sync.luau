--[[
	State Sync System (SERVER) - ECS Packet-Based Replication

	Syncs ECS state components to clients via ByteNet packets.
	This replaces the old StringValue-based replication with pure ECS.

	When server adds states via StateManager.AddState(), this system sends
	packets to clients so they can update their local ECS world.

	OPTIMIZATIONS:
	- Cached queries for each state component (prevents query recreation)
	- Only syncs when states actually change (delta sync)
	- Throttled to 30 Hz for responsive combat
	- Proximity filtering for NPCs (reduces bandwidth)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local Packets = require(ReplicatedStorage.Modules.Packets)

-- Category name to uint8 mapping for packet
local CATEGORY_TO_ID = {
	Actions = 0,
	Stuns = 1,
	IFrames = 2,
	Speeds = 3,
	Frames = 4,
	Status = 5,
}

-- Map ECS component names to category names
local STATE_SYNC_MAP = {
	StateActions = "Actions",
	StateStuns = "Stuns",
	StateIFrames = "IFrames",
	StateSpeeds = "Speeds",
	StateFrames = "Frames",
	StateStatus = "Status",
}

-- Cache to track last synced states (for delta sync)
local lastSyncedStates = setmetatable({}, { __mode = "k" })

-- Debug flag
local DEBUG = false

-- Track first run
local firstRun = true
local frameCount = 0

-- Throttle to 30 Hz for responsive stun sync
local SYNC_HZ = 30
local SYNC_TICK = 1 / SYNC_HZ
local syncAcc = 0

-- Only sync NPCs within this distance of players
local NPC_SYNC_DISTANCE = 150

-- Create cached queries for each state component
local stateQueries = {}
for componentName in pairs(STATE_SYNC_MAP) do
	local component = comps[componentName]
	if component then
		stateQueries[componentName] = world:query(comps.Character, component):cached()
	end
end

-- Helper to check if character is near any player
local function isNearAnyPlayer(character: Model): boolean
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local npcPos = hrp.Position

	for _, player in Players:GetPlayers() do
		local playerChar = player.Character
		if playerChar then
			local playerHRP = playerChar:FindFirstChild("HumanoidRootPart")
			if playerHRP then
				local distance = (npcPos - playerHRP.Position).Magnitude
				if distance <= NPC_SYNC_DISTANCE then
					return true
				end
			end
		end
	end

	return false
end

-- Get or create cache for a character
local function getCharacterCache(character: Model)
	local cache = lastSyncedStates[character]
	if not cache then
		cache = {}
		lastSyncedStates[character] = cache
	end
	return cache
end

-- Compare two state arrays for equality
local function statesEqual(a: {string}, b: {string}?): boolean
	if not b then return false end
	if #a ~= #b then return false end
	for i, v in ipairs(a) do
		if b[i] ~= v then return false end
	end
	return true
end

-- Copy state array
local function copyStates(states: {string}): {string}
	local copy = {}
	for i, v in ipairs(states) do
		copy[i] = v
	end
	return copy
end

-- Sync state to clients via packet
local function syncStateViaPacket(character: Model, categoryName: string, states: {string})
	local cache = getCharacterCache(character)

	-- Only sync if changed (delta sync)
	if statesEqual(states, cache[categoryName]) then
		return
	end

	-- Update cache
	cache[categoryName] = copyStates(states)

	local categoryId = CATEGORY_TO_ID[categoryName]
	if categoryId == nil then
		warn(`[StateSync/Server] Unknown category: {categoryName}`)
		return
	end

	-- Send packet to all players
	-- TODO: Could optimize to only send to nearby players for NPCs
	Packets.StateSync.sendToAll({
		Character = character,
		Category = categoryId,
		States = states,
	})

	if DEBUG and #states > 0 then
		print(`[StateSync/Server] Sent {categoryName} for {character.Name}: {table.concat(states, ", ")}`)
	end
end

local function state_sync_step()
	if firstRun then
		print(`[StateSync/Server] ✅ ECS packet-based state sync started (30 Hz)`)
		firstRun = false
	end

	frameCount = frameCount + 1

	-- Process all state components
	for componentName, categoryName in pairs(STATE_SYNC_MAP) do
		local query = stateQueries[componentName]
		if query then
			for entityId, character, states in query do
				-- Skip if character is destroyed
				if not character or not character.Parent then
					lastSyncedStates[character] = nil
					continue
				end

				-- Skip NPCs that are far from all players
				local isMob = world:has(entityId, comps.Mob)
				if isMob and not isNearAnyPlayer(character) then
					continue
				end

				-- Sync this state category via packet
				syncStateViaPacket(character, categoryName, states or {})
			end
		end
	end
end

-- Throttle wrapper
local function state_sync_wrapper(dt: number)
	syncAcc += dt
	if syncAcc < SYNC_TICK then return end

	syncAcc = 0
	state_sync_step()
end

return {
	run = function(_world, dt)
		state_sync_wrapper(dt)
	end,
	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true,
	}
}
