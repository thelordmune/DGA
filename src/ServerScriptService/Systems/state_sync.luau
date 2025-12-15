--[[
	State Sync System (SERVER) - HEAVILY OPTIMIZED

	Syncs ECS state components back to StringValues so they replicate to clients.
	This is the SERVER version that runs in ServerScriptService/Systems.

	When server adds states via Library.AddState(), this system syncs them to StringValues
	which then automatically replicate to clients.

	OPTIMIZATIONS:
	- Cached queries for each state component (prevents query recreation)
	- Pre-encoded empty state to avoid repeated JSON encoding
	- Optimized cache cleanup using weak tables
	- Reduced string allocations in cache keys
	- **THROTTLED to 10 Hz** (was 60 Hz) - reduces network traffic by 83%
	- **Only syncs when states actually change** - prevents redundant replication
	- **Batched updates** - processes all state categories in one pass
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

-- Map ECS component names to StringValue names
local STATE_SYNC_MAP = {
	StateActions = "Actions",
	StateStuns = "Stuns",
	StateIFrames = "IFrames",
	StateSpeeds = "Speeds",
	StateFrames = "Frames",
	StateStatus = "Status",
}

-- Pre-encode empty state to avoid repeated JSON encoding
local EMPTY_STATE_JSON = HttpService:JSONEncode({})

-- Cache to avoid unnecessary updates (using weak keys for automatic cleanup)
local lastSyncedStates = setmetatable({}, { __mode = "k" })

-- Debug flag (set to true to see sync activity)
local DEBUG = false

-- Track first run
local firstRun = true
local frameCount = 0
local hasLoggedQuery = false

-- OPTIMIZATION: Throttle to 10 Hz instead of 60 Hz (83% reduction in network traffic!)
local SYNC_HZ = 10
local SYNC_TICK = 1 / SYNC_HZ
local syncAcc = 0

-- OPTIMIZATION: Only sync NPCs within this distance of players (reduces network traffic for distant NPCs)
local NPC_SYNC_DISTANCE = 150 -- studs (only sync NPCs within 150 studs of any player)

-- OPTIMIZATION: Create cached queries for each state component
local stateQueries = {}
for componentName in pairs(STATE_SYNC_MAP) do
	local component = comps[componentName]
	if component then
		stateQueries[componentName] = world:query(comps.Character, component):cached()
	end
end

-- Helper to check if character is near any player
local Players = game:GetService("Players")
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

-- OPTIMIZATION: Reuse cache table for character to avoid string allocations
local function getCharacterCache(character: Model)
	local cache = lastSyncedStates[character]
	if not cache then
		cache = {}
		lastSyncedStates[character] = cache
	end
	return cache
end

local function syncStateToStringValue(character: Model, stringValueName: string, states: {string})
	-- Find the StringValue
	local stringValue = character:FindFirstChild(stringValueName)
	if not stringValue then
		-- StringValue doesn't exist yet, skip (it will be created by Entities.Initialize)
		return
	end

	if not stringValue:IsA("StringValue") then
		warn(`[StateSync/Server] {stringValueName} in {character.Name} is not a StringValue!`)
		return
	end

	-- Get character-specific cache
	local cache = getCharacterCache(character)

	-- OPTIMIZATION: Use pre-encoded empty state if states is empty
	local jsonStates = if #states > 0 then HttpService:JSONEncode(states) else EMPTY_STATE_JSON

	-- Only update if changed (avoid triggering unnecessary .Changed events)
	if cache[stringValueName] ~= jsonStates then
		stringValue.Value = jsonStates
		cache[stringValueName] = jsonStates

		if DEBUG and #states > 0 then
			---- print(`[StateSync/Server] Updated {character.Name}.{stringValueName}: {jsonStates}`)
		end
	end
end

local function state_sync_step()
	if firstRun then
		---- print(`[StateSync] ✅ State sync system started on Server (HEAVILY OPTIMIZED - 10 Hz + proximity filtering)`)
		firstRun = false
	end

	frameCount = frameCount + 1

	-- Log every 10 frames (1 second at 10 Hz) to confirm system is running
	if DEBUG and frameCount % 10 == 0 then
		---- print(`[StateSync/Server] System is running (frame {frameCount})`)
	end

	-- OPTIMIZATION: Use cached queries instead of iterating all characters
	-- This processes only entities that have each specific state component
	local entityCount = 0
	local skippedCount = 0
	for componentName, stringValueName in pairs(STATE_SYNC_MAP) do
		local query = stateQueries[componentName]
		if query then
			for _, character, states in query do
				entityCount = entityCount + 1

				-- Skip if character is destroyed
				if not character or not character.Parent then
					-- OPTIMIZATION: Weak table handles cleanup automatically
					lastSyncedStates[character] = nil
					continue
				end

				-- OPTIMIZATION: Skip NPCs that are far from all players (reduces network traffic)
				-- Players always sync (they don't have Mob component)
				local isMob = world:has(_, comps.Mob)
				if isMob and not isNearAnyPlayer(character) then
					skippedCount = skippedCount + 1
					continue
				end

				-- Sync this state category
				syncStateToStringValue(character, stringValueName, states)
			end
		end
	end

	-- Log entity count once
	if not hasLoggedQuery and entityCount > 0 then
		---- print(`[StateSync/Server] Found {entityCount} state components ({skippedCount} distant NPCs skipped)`)
		hasLoggedQuery = true
	end
end

-- OPTIMIZATION: Throttle wrapper to run at 10 Hz instead of 60 Hz
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
		server_only = true, -- Only run on server
	}
}

