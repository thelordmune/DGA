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
local world = require(script.Parent.jecs_world)
local comps = require(script.Parent.jecs_components)
local RefManager = require(script.Parent.jecs_ref_manager)

local StateManager = {}

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
		warn(`[StateManager] Invalid character passed: {typeof(character)} - {tostring(character)}`)
		return nil
	end

	-- Try player entity first
	local Players = game:GetService("Players")
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		return RefManager.player.get("player", player)
	end

	-- Try NPC entity
	return RefManager.entity.find(character)
end

-- Get or create state component for entity
local function getStateComponent(entity: number, category: string): {string}
	local componentName = STATE_CATEGORIES[category]
	if not componentName then
		warn(`[StateManager] Invalid state category: {category}`)
		return {}
	end

	local component = comps[componentName]
	if not component then
		warn(`[StateManager] Component not found: {componentName}`)
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
		warn(`[StateManager] No entity found for character: {character.Name}`)
		return
	end

	local states = getStateComponent(entity, category)

	-- Don't add duplicate states
	if table.find(states, stateName) then
		return
	end

	table.insert(states, stateName)

	-- Update component
	local componentName = STATE_CATEGORIES[category]
	world:set(entity, comps[componentName], states)
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
		warn(`[StateManager] No entity found for character: {character.Name}`)
		return
	end
	
	local states = getStateComponent(entity, category)
	local index = table.find(states, stateName)
	
	if index then
		table.remove(states, index)
		
		-- Update component
		local componentName = STATE_CATEGORIES[category]
		world:set(entity, comps[componentName], states)
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
	@param character Model - The character model
	@param category string - State category
	@param stateName string - Name of the state
	@param duration number - Duration in seconds
]]
function StateManager.TimedState(character: Model, category: string, stateName: string, duration: number)
	StateManager.AddState(character, category, stateName)
	
	task.delay(duration, function()
		StateManager.RemoveState(character, category, stateName)
	end)
end

--[[
	Get all states for a character in a category
	@param character Model - The character model
	@param category string - State category
	@return {string} - Array of state names
]]
function StateManager.GetAllStates(character: Model, category: string): {string}
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
function StateManager.GetAllStatesFromCharacter(character: Model): {[string]: {string}}
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
function StateManager.MultiStateCheck(character: Model, category: string, stateNames: {string}): boolean
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

return StateManager

