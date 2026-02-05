--!strict
--[[
	Library Compatibility Layer
	
	Provides backwards-compatible API for the old Library state/cooldown system
	while using the new ECS StateManager and CooldownManager under the hood.
	
	This allows existing code to continue working without changes while
	benefiting from the ECS architecture.
	
	Usage:
		Replace: local Library = require(ReplicatedStorage.Modules.Library)
		With: local Library = require(ReplicatedStorage.Modules.ECS.LibraryCompat)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateManager = require(script.Parent.StateManager)
local CooldownManager = require(script.Parent.CooldownManager)

-- Import original Library for non-state/cooldown functions
local OriginalLibrary = require(ReplicatedStorage.Modules.Library)

local LibraryCompat = {}

-- Copy all non-state/cooldown functions from original Library
for key, value in pairs(OriginalLibrary) do
	if type(value) == "function" and not string.match(key, "State") and not string.match(key, "Cooldown") then
		LibraryCompat[key] = value
	end
end

--[[
	COOLDOWN FUNCTIONS (ECS-based)
]]

function LibraryCompat.SetCooldown(character: Model, identifier: string, duration: number)
	CooldownManager.SetCooldown(character, identifier, duration)
end

function LibraryCompat.CheckCooldown(character: Model, identifier: string): boolean
	return CooldownManager.CheckCooldown(character, identifier)
end

function LibraryCompat.ResetCooldown(character: Model, identifier: string)
	CooldownManager.ResetCooldown(character, identifier)
end

function LibraryCompat.GetCooldowns(character: Model): {[string]: number}
	return CooldownManager.GetCooldowns(character)
end

function LibraryCompat.GetCooldownTime(character: Model, identifier: string): number
	return CooldownManager.GetCooldownTime(character, identifier)
end

--[[
	STATE FUNCTIONS (ECS-based)
	
	Note: The old API used StringValue objects as the first parameter.
	We need to convert this to character + category.
]]

-- Helper to extract category from StringValue name
local function getCategoryFromStringValue(stringValue: StringValue): string
	local name = stringValue.Name
	-- Map old StringValue names to new categories
	local categoryMap = {
		Actions = "Actions",
		Stuns = "Stuns",
		IFrames = "IFrames",
		Speeds = "Speeds",
		Frames = "Frames",
		Status = "Status",
	}
	return categoryMap[name] or "Actions"
end

-- Helper to get character from StringValue
local function getCharacterFromStringValue(stringValue: StringValue): Model?
	return stringValue.Parent :: Model
end

function LibraryCompat.StateCheck(stringValue: StringValue, stateName: string): boolean
	local character = getCharacterFromStringValue(stringValue)
	if not character then return false end
	
	local category = getCategoryFromStringValue(stringValue)
	return StateManager.StateCheck(character, category, stateName)
end

function LibraryCompat.StateCount(stringValue: StringValue): boolean
	local character = getCharacterFromStringValue(stringValue)
	if not character then return false end
	
	local category = getCategoryFromStringValue(stringValue)
	return StateManager.StateCount(character, category)
end

function LibraryCompat.MultiStateCheck(stringValue: StringValue, stateNames: {string}): boolean
	local character = getCharacterFromStringValue(stringValue)
	if not character then return true end
	
	local category = getCategoryFromStringValue(stringValue)
	return StateManager.MultiStateCheck(character, category, stateNames)
end

function LibraryCompat.AddState(stringValue: StringValue, stateName: string)
	local character = getCharacterFromStringValue(stringValue)
	if not character then return end
	
	local category = getCategoryFromStringValue(stringValue)
	StateManager.AddState(character, category, stateName)
end

function LibraryCompat.RemoveState(stringValue: StringValue, stateName: string)
	local character = getCharacterFromStringValue(stringValue)
	if not character then return end
	
	local category = getCategoryFromStringValue(stringValue)
	StateManager.RemoveState(character, category, stateName)
end

function LibraryCompat.TimedState(stringValue: StringValue, stateName: string, duration: number)
	local character = getCharacterFromStringValue(stringValue)
	if not character then return end
	
	local category = getCategoryFromStringValue(stringValue)
	StateManager.TimedState(character, category, stateName, duration)
end

function LibraryCompat.RemoveAllStates(stringValue: StringValue, stateName: string)
	local character = getCharacterFromStringValue(stringValue)
	if not character then return end
	
	local category = getCategoryFromStringValue(stringValue)
	StateManager.RemoveAllStates(character, category, stateName)
end

function LibraryCompat.GetAllStates(stringValue: StringValue): {string}
	local character = getCharacterFromStringValue(stringValue)
	if not character then return {} end
	
	local category = getCategoryFromStringValue(stringValue)
	return StateManager.GetAllStates(character, category)
end

function LibraryCompat.GetAllStatesFromCharacter(character: Model): {[string]: {string}}
	return StateManager.GetAllStatesFromCharacter(character)
end

function LibraryCompat.GetSpecificState(character: Model, desiredState: string): StringValue?
	-- This function is tricky - it searches for a state across all categories
	-- We'll check all categories and return a mock StringValue if found
	local allStates = StateManager.GetAllStatesFromCharacter(character)
	
	for category, states in pairs(allStates) do
		for _, state in ipairs(states) do
			if string.match(state, desiredState) then
				-- Return a mock StringValue for backwards compatibility
				-- In practice, this function is rarely used
				local mockStringValue = Instance.new("StringValue")
				mockStringValue.Name = category
				mockStringValue.Parent = character
				return mockStringValue
			end
		end
	end
	
	return nil
end

--[[
	CLEANUP FUNCTION
]]

function LibraryCompat.Remove(character: Model)
	-- Clear all cooldowns
	CooldownManager.ClearAllCooldowns(character)
	
	-- Clear all states
	for _, category in ipairs({"Actions", "Stuns", "IFrames", "Speeds", "Frames", "Status"}) do
		StateManager.ClearCategory(character, category)
	end
end

-- Also call original cleanup for animations
function LibraryCompat.CleanupCharacter(character: Model)
	-- Call original cleanup for animations and other non-ECS stuff
	OriginalLibrary.CleanupCharacter(character)
	
	-- Clear ECS states and cooldowns
	LibraryCompat.Remove(character)
end

--[[
	DIRECT ECS ACCESS (for new code)
	
	New code can use these directly instead of the StringValue-based API
]]

LibraryCompat.ECS = {
	State = StateManager,
	Cooldown = CooldownManager,
}

return LibraryCompat

