--[[
	Leveling Manager
	
	Handles player leveling, experience, and alignment systems.
	- Level range: 1-50
	- Exponential XP curve
	- Alignment system (-100 to +100)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

local LevelingManager = {}

-- Constants
LevelingManager.MAX_LEVEL = 50
LevelingManager.MIN_LEVEL = 1
LevelingManager.MIN_ALIGNMENT = -100
LevelingManager.MAX_ALIGNMENT = 100

-- Experience formula: Exponential curve
-- Formula: XP = baseXP * (level ^ exponent) + (level * multiplier)
-- This creates a smooth exponential curve from level 1 to 50
local BASE_XP = 100
local EXPONENT = 1.5
local MULTIPLIER = 50

function LevelingManager.calculateRequiredXP(level)
	if level >= LevelingManager.MAX_LEVEL then
		return 0 -- Max level, no more XP needed
	end
	
	-- Exponential formula for smooth progression
	local requiredXP = math.floor(BASE_XP * (level ^ EXPONENT) + (level * MULTIPLIER))
	return requiredXP
end

-- Initialize leveling components for a player entity
-- If playerData is provided, loads from saved data; otherwise uses defaults
function LevelingManager.initialize(entity, playerData)
	if not entity or not world:contains(entity) then
		warn("[LevelingManager] Invalid entity")
		return false
	end

	-- Load from saved data or use defaults
	local savedLevel = (playerData and playerData.Level) or 1
	local savedExperience = (playerData and playerData.Experience) or 0
	local savedTotalExperience = (playerData and playerData.TotalExperience) or 0
	local savedAlignment = (playerData and playerData.Alignment) or 0

	-- Initialize Level component
	if not world:has(entity, comps.Level) then
		world:set(entity, comps.Level, {
			current = savedLevel,
			max = LevelingManager.MAX_LEVEL
		})
	end

	-- Initialize Experience component
	if not world:has(entity, comps.Experience) then
		world:set(entity, comps.Experience, {
			current = savedExperience,
			required = LevelingManager.calculateRequiredXP(savedLevel),
			total = savedTotalExperience
		})
	end

	-- Initialize Alignment component
	if not world:has(entity, comps.Alignment) then
		world:set(entity, comps.Alignment, {
			value = savedAlignment,
			min = LevelingManager.MIN_ALIGNMENT,
			max = LevelingManager.MAX_ALIGNMENT
		})
	end

	return true
end

-- Add experience to a player
function LevelingManager.addExperience(entity, amount)
	if not entity or not world:contains(entity) then
		warn("[LevelingManager] Invalid entity")
		return false
	end

	if not world:has(entity, comps.Experience) or not world:has(entity, comps.Level) then
		warn("[LevelingManager] Entity missing Experience or Level component")
		return false
	end

	local exp = world:get(entity, comps.Experience)
	local level = world:get(entity, comps.Level)

	-- Add experience
	exp.current = exp.current + amount
	exp.total = exp.total + amount

	-- Check for level up
	local levelsGained = 0
	while exp.current >= exp.required and level.current < level.max do
		exp.current = exp.current - exp.required
		level.current = level.current + 1
		levelsGained = levelsGained + 1
		exp.required = LevelingManager.calculateRequiredXP(level.current)
	end

	-- Update components
	world:set(entity, comps.Experience, exp)
	world:set(entity, comps.Level, level)

	-- Auto-save to DataStore if on server
	if game:GetService("RunService"):IsServer() then
		-- Get the Player instance from the entity
		local player = world:has(entity, comps.Player) and world:get(entity, comps.Player) or nil
		if player then
			LevelingManager.saveToDataStore(player, entity)
		end
	end

	return true, levelsGained
end

-- Set player level directly (for rewards like free level)
function LevelingManager.setLevel(entity, newLevel)
	if not entity or not world:contains(entity) then
		warn("[LevelingManager] Invalid entity")
		return false
	end

	if not world:has(entity, comps.Level) or not world:has(entity, comps.Experience) then
		warn("[LevelingManager] Entity missing Level or Experience component")
		return false
	end

	newLevel = math.clamp(newLevel, LevelingManager.MIN_LEVEL, LevelingManager.MAX_LEVEL)

	local level = world:get(entity, comps.Level)
	local exp = world:get(entity, comps.Experience)

	level.current = newLevel
	exp.current = 0
	exp.required = LevelingManager.calculateRequiredXP(newLevel)

	world:set(entity, comps.Level, level)
	world:set(entity, comps.Experience, exp)

	-- Auto-save to DataStore if on server
	if game:GetService("RunService"):IsServer() then
		-- Get the Player instance from the entity
		local player = world:has(entity, comps.Player) and world:get(entity, comps.Player) or nil
		if player then
			LevelingManager.saveToDataStore(player, entity)
		end
	end

	return true
end

-- Add alignment to a player
function LevelingManager.addAlignment(entity, amount)
	if not entity or not world:contains(entity) then
		warn("[LevelingManager] Invalid entity")
		return false
	end

	if not world:has(entity, comps.Alignment) then
		warn("[LevelingManager] Entity missing Alignment component")
		return false
	end

	local alignment = world:get(entity, comps.Alignment)
	alignment.value = math.clamp(alignment.value + amount, alignment.min, alignment.max)
	world:set(entity, comps.Alignment, alignment)

	-- Auto-save to DataStore if on server
	if game:GetService("RunService"):IsServer() then
		-- Get the Player instance from the entity
		local player = world:has(entity, comps.Player) and world:get(entity, comps.Player) or nil
		if player then
			LevelingManager.saveToDataStore(player, entity)
		end
	end

	return true, alignment.value
end

-- Get player level
function LevelingManager.getLevel(entity)
	if not entity or not world:contains(entity) then
		return nil
	end
	
	if not world:has(entity, comps.Level) then
		return nil
	end
	
	local level = world:get(entity, comps.Level)
	return level.current
end

-- Get player experience
function LevelingManager.getExperience(entity)
	if not entity or not world:contains(entity) then
		return nil
	end
	
	if not world:has(entity, comps.Experience) then
		return nil
	end
	
	local exp = world:get(entity, comps.Experience)
	return exp.current, exp.required, exp.total
end

-- Get player alignment
function LevelingManager.getAlignment(entity)
	if not entity or not world:contains(entity) then
		return nil
	end
	
	if not world:has(entity, comps.Alignment) then
		return nil
	end
	
	local alignment = world:get(entity, comps.Alignment)
	return alignment.value
end

-- Get alignment tier name
function LevelingManager.getAlignmentTier(alignmentValue)
	if alignmentValue >= 75 then
		return "Saint"
	elseif alignmentValue >= 50 then
		return "Hero"
	elseif alignmentValue >= 25 then
		return "Good"
	elseif alignmentValue >= -25 then
		return "Neutral"
	elseif alignmentValue >= -50 then
		return "Evil"
	elseif alignmentValue >= -75 then
		return "Villain"
	else
		return "Demon"
	end
end

-- Get progress percentage to next level
function LevelingManager.getProgressPercent(entity)
	if not entity or not world:contains(entity) then
		return 0
	end

	if not world:has(entity, comps.Experience) then
		return 0
	end

	local exp = world:get(entity, comps.Experience)
	if exp.required == 0 then
		return 100 -- Max level
	end

	return (exp.current / exp.required) * 100
end

-- Save leveling data to player's DataStore profile
-- This should be called whenever Level, Experience, or Alignment changes
function LevelingManager.saveToDataStore(player, entity)
	if not game:GetService("RunService"):IsServer() then
		warn("[LevelingManager] saveToDataStore can only be called on the server")
		return false
	end

	if not player or not player:IsA("Player") then
		warn("[LevelingManager] Invalid player")
		return false
	end

	if not entity or not world:contains(entity) then
		warn("[LevelingManager] Invalid entity")
		return false
	end

	-- Get the Global module for data access
	local success, Global = pcall(function()
		return require(ReplicatedStorage.Modules.Shared.Global)
	end)

	if not success or not Global then
		warn("[LevelingManager] Could not load Global module")
		return false
	end

	-- Get current component values
	local level = world:has(entity, comps.Level) and world:get(entity, comps.Level) or nil
	local exp = world:has(entity, comps.Experience) and world:get(entity, comps.Experience) or nil
	local alignment = world:has(entity, comps.Alignment) and world:get(entity, comps.Alignment) or nil

	if not level or not exp or not alignment then
		warn("[LevelingManager] Entity missing leveling components")
		return false
	end

	-- Update the player's data
	Global.SetData(player, function(data)
		data.Level = level.current
		data.Experience = exp.current
		data.TotalExperience = exp.total
		data.Alignment = alignment.value
		return data
	end)

	return true
end

return LevelingManager

