--!strict
--[[
	ECS State Manager
	
	Replaces the old Library state system (StringValue JSON arrays) with pure ECS components.
	Provides backwards-compatible API while using ECS under the hood.
	
	State Categories:
	- Actions: Combat actions, skills, movement
	- Stuns: Stun states, knockback, ragdoll
	- IFrames: Immunity frames, invincibility
	- Speeds: Speed modifiers
	- Frames: General purpose states
	- Status: Status effects
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local world = require(script.Parent.jecs_world)
local comps = require(script.Parent.jecs_components)
local RefManager = require(script.Parent.jecs_ref_manager)
local StateConflicts = require(script.Parent.StateConflicts)

-- Signal library for state change notifications
local Signal = require(ReplicatedStorage.Packages.luausignal)

local StateManager = {}

-- ============================================
-- CHRONO NPC STATE REPLICATION
-- Syncs NPC states to NPC_MODEL_CACHE for client replication
-- ============================================
local NPC_MODEL_CACHE = nil
local IS_SERVER = RunService:IsServer()

-- Sync all states for an NPC to the cache model (server only)
local function syncNPCStatesToCache(character: Model)
	if not IS_SERVER then return end

	local chronoId = character:GetAttribute("ChronoId")
	if not chronoId then return end -- Not a Chrono NPC

	-- Skip players
	if Players:GetPlayerFromCharacter(character) then return end

	-- Get or find cache
	if not NPC_MODEL_CACHE then
		NPC_MODEL_CACHE = ReplicatedStorage:FindFirstChild("NPC_MODEL_CACHE")
	end
	if not NPC_MODEL_CACHE then return end

	local cacheModel = NPC_MODEL_CACHE:FindFirstChild(tostring(chronoId))
	if not cacheModel then return end

	-- Get entity to read states
	local entity = RefManager.entity.find(character)
	if not entity then return end

	-- Sync key state categories that affect client-side behavior
	-- Format: comma-separated state names for each category
	local STATE_CATEGORIES_TO_SYNC = {"Actions", "Stuns", "Speeds", "Frames"}

	for _, category in ipairs(STATE_CATEGORIES_TO_SYNC) do
		local componentName = "State" .. category
		local component = comps[componentName]
		if component and world:has(entity, component) then
			local states = world:get(entity, component) or {}
			local stateStr = table.concat(states, ",")
			cacheModel:SetAttribute("NPC" .. category, stateStr)
		else
			cacheModel:SetAttribute("NPC" .. category, "")
		end
	end
end

-- Version tracking for TimedState to prevent race conditions
-- When the same state is added twice with different durations, this ensures
-- only the most recent task.delay removes the state
local StateVersions: {[number]: {[string]: {[string]: number}}} = {} -- entity -> category -> stateName -> version

-- ============================================
-- STATE CHANGE SIGNALS
-- Replaces StringValue.Changed event listeners
-- ============================================

-- Per-character, per-category signals for state changes
-- Structure: characterSignals[character][category] = { added: Signal, removed: Signal }
type CategorySignals = { added: any, removed: any }
local characterSignals: {[Model]: {[string]: CategorySignals}} = {}

-- Get or create signals for a character+category combination
local function getOrCreateSignals(character: Model, category: string): CategorySignals
	if not characterSignals[character] then
		characterSignals[character] = {}
	end

	if not characterSignals[character][category] then
		characterSignals[character][category] = {
			added = Signal(),
			removed = Signal(),
		}
	end

	return characterSignals[character][category]
end

-- Fire state added signal
local function fireStateAdded(character: Model, category: string, stateName: string)
	if characterSignals[character] and characterSignals[character][category] then
		characterSignals[character][category].added:fire(stateName)
	end

	-- Sync NPC states to cache for Chrono replication
	syncNPCStatesToCache(character)
end

-- Fire state removed signal
local function fireStateRemoved(character: Model, category: string, stateName: string)
	if characterSignals[character] and characterSignals[character][category] then
		characterSignals[character][category].removed:fire(stateName)
	end

	-- Sync NPC states to cache for Chrono replication
	syncNPCStatesToCache(character)
end

-- State category to component mapping
local STATE_CATEGORIES = {
	Actions = "StateActions",
	Stuns = "StateStuns",
	IFrames = "StateIFrames",
	Speeds = "StateSpeeds",
	Frames = "StateFrames",
	Status = "StateStatus",
}

-- Get entity from character model
local function getEntity(character: Model): number?
	-- Validate input
	if not character or typeof(character) ~= "Instance" or not character:IsA("Model") then
		-- warn(`[StateManager] Invalid character passed: {typeof(character)} - {tostring(character)}`)
		return nil
	end

	-- Try player entity first
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		-- Use "player" ref first (same as Initialize does), fall back to "local_player"
		-- This ensures consistency with how Character component is set
		local ref = require(script.Parent.jecs_ref)
		local entity = ref.get("player", player)
		if not entity and RunService:IsClient() and player == Players.LocalPlayer then
			entity = ref.get("local_player")
		end

		if not entity then
			-- warn(`[StateManager] No entity found for player {player.Name}`)
		else
			local context = RunService:IsClient() and "Client" or "Server"
			-- print(`[StateManager/{context}] Got entity {entity} for player {player.Name}`)
		end
		return entity
	end

	-- Try NPC entity
	return RefManager.entity.find(character)
end

-- Get or create state component for entity (ECS-based)
local function getStateComponent(entity: number, category: string): { string }
	local componentName = STATE_CATEGORIES[category]
	if not componentName then
		-- warn(`[StateManager] Invalid state category: {category}`)
		return {}
	end

	local component = comps[componentName]
	if not component then
		-- warn(`[StateManager] Component not found: {componentName}`)
		return {}
	end

	-- Get existing state or create empty array
	if world:has(entity, component) then
		local states = world:get(entity, component)
		return states or {}
	else
		local newState = {}
		world:set(entity, component, newState)
		local result = world:get(entity, component)
		return result or {}
	end
end


--[[
	Add a state to a character
	@param character Model - The character model
	@param category string - State category (Actions, Stuns, IFrames, Speeds, Frames, Status)
	@param stateName string - Name of the state to add
]]
function StateManager.AddState(character: Model, category: string, stateName: string)
	local entity = getEntity(character)
	if not entity then
		-- Silently fail if no entity - this can happen during character transitions
		return
	end

	local states = getStateComponent(entity, category)

	-- Don't add duplicate states
	if table.find(states, stateName) then
		return
	end

	-- Remove conflicting states BEFORE adding the new one
	-- This prevents state stacking (e.g., M1Speed13 + RunSpeedSet30 both active)
	local conflicts = StateConflicts.GetConflicts(category, stateName)
	if conflicts then
		for _, conflictState in ipairs(conflicts) do
			local index = table.find(states, conflictState)
			if index then
				table.remove(states, index)
			end
		end
	end

	table.insert(states, stateName)

	-- Update component
	local componentName = STATE_CATEGORIES[category]
	world:set(entity, comps[componentName], states)

	-- Fire state added signal
	fireStateAdded(character, category, stateName)
end

--[[
	Remove a state from a character
	@param character Model - The character model
	@param category string - State category
	@param stateName string - Name of the state to remove
]]
function StateManager.RemoveState(character: Model, category: string, stateName: string)
	local entity = getEntity(character)
	if not entity then
		-- warn(`[StateManager] No entity found for character: {character.Name}`)
		return
	end

	local states = getStateComponent(entity, category)
	local index = table.find(states, stateName)

	if index then
		table.remove(states, index)

		-- Update component
		local componentName = STATE_CATEGORIES[category]
		world:set(entity, comps[componentName], states)

		-- Fire state removed signal
		fireStateRemoved(character, category, stateName)
	end
end

--[[
	Check if a character has a specific state
	@param character Model - The character model
	@param category string - State category
	@param stateName string - Name of the state to check
	@return boolean - True if state exists
]]
function StateManager.StateCheck(character: Model, category: string, stateName: string): boolean
	local entity = getEntity(character)
	if not entity then
		return false
	end
	local states = getStateComponent(entity, category)
	return table.find(states, stateName) ~= nil
end

--[[
	Check if a character has any states in a category
	@param character Model - The character model
	@param category string - State category
	@return boolean - True if any states exist
]]
function StateManager.StateCount(character: Model, category: string): boolean
	local entity = getEntity(character)
	if not entity then
		return false
	end
	local states = getStateComponent(entity, category)
	return #states > 0
end

--[[
	Add a timed state that automatically removes after duration
	Uses version tracking to prevent race conditions when the same state
	is added multiple times with different durations
	@param character Model - The character model
	@param category string - State category
	@param stateName string - Name of the state
	@param duration number - Duration in seconds
]]
function StateManager.TimedState(character: Model, category: string, stateName: string, duration: number)
	local entity = getEntity(character)
	if not entity then return end

	-- Initialize version tracking tables
	if not StateVersions[entity] then
		StateVersions[entity] = {}
	end
	if not StateVersions[entity][category] then
		StateVersions[entity][category] = {}
	end

	-- Increment version (invalidates any previous task.delay for this state)
	local currentVersion = (StateVersions[entity][category][stateName] or 0) + 1
	StateVersions[entity][category][stateName] = currentVersion

	-- Add the state (handles conflict removal)
	StateManager.AddState(character, category, stateName)

	-- Schedule removal with version check
	task.delay(duration, function()
		-- Only remove if this version is still current
		-- If a newer TimedState was called, our version won't match and we skip removal
		if StateVersions[entity]
			and StateVersions[entity][category]
			and StateVersions[entity][category][stateName] == currentVersion then
			StateManager.RemoveState(character, category, stateName)
		end
	end)
end

--[[
	Get all states for a character in a category
	@param character Model - The character model
	@param category string - State category
	@return {string} - Array of state names
]]
function StateManager.GetAllStates(character: Model, category: string): { string }
	local entity = getEntity(character)
	if not entity then
		return {}
	end
	return getStateComponent(entity, category)
end

--[[
	Get all states from all categories for a character
	@param character Model - The character model
	@return {[string]: {string}} - Dictionary of category -> states
]]
function StateManager.GetAllStatesFromCharacter(character: Model): { [string]: { string } }
	local entity = getEntity(character)
	if not entity then
		return {}
	end

	local allStates = {}
	for category, _ in pairs(STATE_CATEGORIES) do
		allStates[category] = getStateComponent(entity, category)
	end

	return allStates
end

--[[
	Remove all instances of a state from a category
	@param character Model - The character model
	@param category string - State category
	@param stateName string - Name of the state to remove
]]
function StateManager.RemoveAllStates(character: Model, category: string, stateName: string)
	local entity = getEntity(character)
	if not entity then
		return
	end

	local states = getStateComponent(entity, category)
	local newStates = {}

	-- Filter out all instances of the state
	for _, state in ipairs(states) do
		if state ~= stateName then
			table.insert(newStates, state)
		end
	end

	-- Update component
	local componentName = STATE_CATEGORIES[category]
	world:set(entity, comps[componentName], newStates)
end

--[[
	Check if character has any of the specified states
	@param character Model - The character model
	@param category string - State category
	@param stateNames {string} - Array of state names to check
	@return boolean - True if character has NONE of the states (passes check)
]]
function StateManager.MultiStateCheck(character: Model, category: string, stateNames: { string }): boolean
	local entity = getEntity(character)
	if not entity then
		return true -- Pass if no entity
	end

	local states = getStateComponent(entity, category)
	for _, stateName in ipairs(stateNames) do
		if table.find(states, stateName) then
			return false -- Fail if any state is found
		end
	end

	return true -- Pass if none found
end

--[[
	Clear all states from a category
	@param character Model - The character model
	@param category string - State category
]]
function StateManager.ClearCategory(character: Model, category: string)
	local entity = getEntity(character)
	if not entity then
		return
	end

	local componentName = STATE_CATEGORIES[category]
	world:set(entity, comps[componentName], {})
end

-- ============================================
-- STATE CHANGE OBSERVER API
-- Replaces Character.Stuns.Changed, Character.Actions.Changed, etc.
-- ============================================

--[[
	Subscribe to state added events for a character and category
	@param character Model - The character model
	@param category string - State category (Actions, Stuns, IFrames, Speeds, Frames, Status)
	@param callback function(stateName: string) - Called when a state is added
	@return function - Disconnect function
]]
function StateManager.OnStateAdded(character: Model, category: string, callback: (string) -> ()): () -> ()
	local signals = getOrCreateSignals(character, category)
	return signals.added:connect(callback)
end

--[[
	Subscribe to state added events ONCE (auto-disconnects after first fire)
	@param character Model - The character model
	@param category string - State category
	@param callback function(stateName: string) - Called when a state is added
]]
function StateManager.OnStateAddedOnce(character: Model, category: string, callback: (string) -> ())
	local signals = getOrCreateSignals(character, category)
	signals.added:once(callback)
end

--[[
	Subscribe to state removed events for a character and category
	@param character Model - The character model
	@param category string - State category
	@param callback function(stateName: string) - Called when a state is removed
	@return function - Disconnect function
]]
function StateManager.OnStateRemoved(character: Model, category: string, callback: (string) -> ()): () -> ()
	local signals = getOrCreateSignals(character, category)
	return signals.removed:connect(callback)
end

--[[
	Subscribe to state removed events ONCE
	@param character Model - The character model
	@param category string - State category
	@param callback function(stateName: string) - Called when a state is removed
]]
function StateManager.OnStateRemovedOnce(character: Model, category: string, callback: (string) -> ())
	local signals = getOrCreateSignals(character, category)
	signals.removed:once(callback)
end

--[[
	Convenience wrapper: Subscribe to stun added events
	Replaces: Character.Stuns.Changed:Once(function() ... end)
	@param character Model - The character model
	@param callback function(stunName: string) - Called when a stun is added
	@return function - Disconnect function
]]
function StateManager.OnStunAdded(character: Model, callback: (string) -> ()): () -> ()
	return StateManager.OnStateAdded(character, "Stuns", callback)
end

--[[
	Convenience wrapper: Subscribe to stun added events ONCE
	@param character Model - The character model
	@param callback function(stunName: string) - Called when a stun is added
]]
function StateManager.OnStunAddedOnce(character: Model, callback: (string) -> ())
	StateManager.OnStateAddedOnce(character, "Stuns", callback)
end

--[[
	Cleanup signals for a character (call when character is removed)
	@param character Model - The character model
]]
function StateManager.CleanupSignals(character: Model)
	if characterSignals[character] then
		-- Disconnect and delete all signals for this character
		for _, categorySignals in pairs(characterSignals[character]) do
			if categorySignals.added then
				categorySignals.added:delete()
			end
			if categorySignals.removed then
				categorySignals.removed:delete()
			end
		end
		characterSignals[character] = nil
	end
end

return StateManager
