--[[
	State Sync System (CLIENT) - OPTIMIZED

	Syncs ECS state components back to StringValues on the client.
	This is the CLIENT version that runs in ReplicatedStorage/Modules/Systems.

	When client adds states via Library.AddState() (like running), this system syncs them to StringValues.
	For server-added states (like M1 attacks), the server's state_sync handles it and replicates via StringValues.

	OPTIMIZATIONS:
	- Cached queries for each state component (prevents query recreation)
	- Pre-encoded empty state to avoid repeated JSON encoding
	- Optimized cache cleanup using weak tables
	- Reduced string allocations in cache keys
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
local DEBUG = true

-- Track first run
local firstRun = true

-- OPTIMIZATION: Create cached queries for each state component
local stateQueries = {}
for componentName in pairs(STATE_SYNC_MAP) do
	local component = comps[componentName]
	if component then
		stateQueries[componentName] = world:query(comps.Character, component):cached()
	end
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
		warn(`[StateSync/Client] {stringValueName} in {character.Name} is not a StringValue!`)
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
			---- print(`[StateSync/Client] ✅ Updated {character.Name}.{stringValueName}: {jsonStates}`)
		end
	end
end

local frameCount = 0
local hasLoggedQuery = false

local function state_sync()
	if firstRun then
		---- print(`[StateSync] ✅ State sync system started on Client (OPTIMIZED)`)
		firstRun = false
	end

	frameCount = frameCount + 1

	-- Log every 60 frames (1 second) to confirm system is running
	if DEBUG and frameCount % 60 == 0 then
		---- print(`[StateSync/Client] System is running (frame {frameCount})`)
	end

	-- OPTIMIZATION: Use cached queries instead of iterating all characters
	-- This processes only entities that have each specific state component
	local entityCount = 0
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

				-- Sync this state category
				syncStateToStringValue(character, stringValueName, states)
			end
		end
	end

	-- Log entity count once
	if not hasLoggedQuery and entityCount > 0 then
		---- print(`[StateSync/Client] Found {entityCount} state components across all entities`)
		hasLoggedQuery = true
	end
end

return {
	run = function()
		state_sync()
	end,
	settings = {
		phase = "Heartbeat",
		depends_on = {},
		client_only = true, -- Only run on client (server has its own version)
	}
}

