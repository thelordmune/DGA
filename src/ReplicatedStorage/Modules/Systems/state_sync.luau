--[[
	State Sync System (CLIENT)

	Syncs ECS state components back to StringValues on the client.
	This is the CLIENT version that runs in ReplicatedStorage/Modules/Systems.

	When client adds states via Library.AddState() (like running), this system syncs them to StringValues.
	For server-added states (like M1 attacks), the server's state_sync handles it and replicates via StringValues.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

-- Cache to avoid unnecessary updates
local lastSyncedStates = {}

-- Debug flag (set to true to see sync activity)
local DEBUG = false

-- Track first run
local firstRun = true

local function syncStateToStringValue(character: Model, componentName: string, stringValueName: string, states: {string})
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

	-- Create a cache key
	local cacheKey = `{character}_{stringValueName}`

	-- Convert states array to JSON
	local jsonStates = HttpService:JSONEncode(states or {})

	-- Only update if changed (avoid triggering unnecessary .Changed events)
	if lastSyncedStates[cacheKey] ~= jsonStates then
		stringValue.Value = jsonStates
		lastSyncedStates[cacheKey] = jsonStates

		if DEBUG and #states > 0 then
			print(`[StateSync/Client] ✅ Updated {character.Name}.{stringValueName}: {jsonStates}`)
		end
	end
end

local frameCount = 0
local hasLoggedQuery = false

local function state_sync()
	if firstRun then
		-- print(`[StateSync] ✅ State sync system started on Client`)
		firstRun = false
	end

	frameCount = frameCount + 1

	-- Log every 60 frames (1 second) to confirm system is running
	if DEBUG and frameCount % 60 == 0 then
		-- print(`[StateSync/Client] System is running (frame {frameCount})`)
	end

	-- Iterate through all entities with Character component
	local entityCount = 0
	for entity in world:query(comps.Character):iter() do
		entityCount = entityCount + 1
		local character = world:get(entity, comps.Character)

		if not character or not character.Parent then
			-- Character destroyed, clean up cache
			for key in pairs(lastSyncedStates) do
				if string.match(key, tostring(character)) then
					lastSyncedStates[key] = nil
				end
			end
			continue
		end

		-- Sync each state category
		for componentName, stringValueName in pairs(STATE_SYNC_MAP) do
			local component = comps[componentName]
			if component and world:has(entity, component) then
				local states = world:get(entity, component)
				syncStateToStringValue(character, componentName, stringValueName, states)
			end
		end
	end

	-- Log entity count once
	if not hasLoggedQuery and entityCount > 0 then
		-- print(`[StateSync/Client] Found {entityCount} character entities`)
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

