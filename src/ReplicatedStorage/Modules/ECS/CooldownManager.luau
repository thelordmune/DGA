--!strict
--[[
	ECS Cooldown Manager
	
	Replaces the old Library cooldown system (table-based) with pure ECS components.
	Provides backwards-compatible API while using ECS under the hood.
	
	Cooldowns are stored as components with the format:
	{
		[skillName: string]: number (expiry time)
	}
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(script.Parent.jecs_world)
local comps = require(script.Parent.jecs_components)
local RefManager = require(script.Parent.jecs_ref_manager)

local CooldownManager = {}

-- Get entity from character model
local function getEntity(character: Model): number?
	-- Validate input
	if not character or typeof(character) ~= "Instance" or not character:IsA("Model") then
		warn(`[CooldownManager] Invalid character passed: {typeof(character)} - {tostring(character)}`)
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

-- Get or create cooldowns component for entity
local function getCooldowns(entity: number): {[string]: number}
	if world:has(entity, comps.Cooldowns) then
		return world:get(entity, comps.Cooldowns)
	else
		local newCooldowns = {}
		world:set(entity, comps.Cooldowns, newCooldowns)
		return newCooldowns
	end
end

--[[
	Set a cooldown for a character
	@param character Model - The character model
	@param identifier string - Cooldown identifier (skill name, etc.)
	@param duration number - Cooldown duration in seconds
]]
function CooldownManager.SetCooldown(character: Model, identifier: string, duration: number)
	local entity = getEntity(character)
	if not entity then
		warn(`[CooldownManager] No entity found for character: {character.Name}`)
		return
	end
	
	local cooldowns = getCooldowns(entity)
	cooldowns[identifier] = os.clock() + duration
	
	-- Update component
	world:set(entity, comps.Cooldowns, cooldowns)
end

--[[
	Check if a cooldown is active
	@param character Model - The character model
	@param identifier string - Cooldown identifier
	@return boolean - True if on cooldown
]]
function CooldownManager.CheckCooldown(character: Model, identifier: string): boolean
	local entity = getEntity(character)
	if not entity then
		return false
	end
	
	local cooldowns = getCooldowns(entity)
	local expiryTime = cooldowns[identifier]
	
	if not expiryTime then
		return false
	end
	
	if expiryTime > os.clock() then
		return true -- Still on cooldown
	else
		-- Cooldown expired, remove it
		cooldowns[identifier] = nil
		world:set(entity, comps.Cooldowns, cooldowns)
		return false
	end
end

--[[
	Reset a cooldown (set to 0)
	@param character Model - The character model
	@param identifier string - Cooldown identifier
]]
function CooldownManager.ResetCooldown(character: Model, identifier: string)
	local entity = getEntity(character)
	if not entity then
		return
	end
	
	local cooldowns = getCooldowns(entity)
	if cooldowns[identifier] ~= nil then
		cooldowns[identifier] = 0
		world:set(entity, comps.Cooldowns, cooldowns)
	end
end

--[[
	Get all cooldowns for a character
	@param character Model - The character model
	@return {[string]: number} - Dictionary of identifier -> expiry time
]]
function CooldownManager.GetCooldowns(character: Model): {[string]: number}
	local entity = getEntity(character)
	if not entity then
		return {}
	end
	
	return getCooldowns(entity)
end

--[[
	Get remaining cooldown time for a specific skill
	@param character Model - The character model
	@param identifier string - Cooldown identifier
	@return number - Remaining time in seconds (0 if not on cooldown)
]]
function CooldownManager.GetCooldownTime(character: Model, identifier: string): number
	local entity = getEntity(character)
	if not entity then
		return 0
	end
	
	local cooldowns = getCooldowns(entity)
	local expiryTime = cooldowns[identifier]
	
	if not expiryTime then
		return 0
	end
	
	local remaining = expiryTime - os.clock()
	return math.max(0, remaining)
end

--[[
	Clear all cooldowns for a character
	@param character Model - The character model
]]
function CooldownManager.ClearAllCooldowns(character: Model)
	local entity = getEntity(character)
	if not entity then
		return
	end
	
	world:set(entity, comps.Cooldowns, {})
end

--[[
	Remove a specific cooldown
	@param character Model - The character model
	@param identifier string - Cooldown identifier
]]
function CooldownManager.RemoveCooldown(character: Model, identifier: string)
	local entity = getEntity(character)
	if not entity then
		return
	end
	
	local cooldowns = getCooldowns(entity)
	cooldowns[identifier] = nil
	world:set(entity, comps.Cooldowns, cooldowns)
end

return CooldownManager

