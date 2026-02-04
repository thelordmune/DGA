--!strict
--[[
    Posture System - Deepwoken-Inspired Posture/Poise Mechanic

    A secondary defense resource that builds up when blocking attacks.
    When posture is full (100), the character's guard is broken and they
    receive a long stun (2.5s PostureBreakStun).

    Mechanics:
    - Posture starts at 0 and increases when blocking attacks
    - Each blocked attack adds posture damage (based on attack damage)
    - When posture reaches max (100), guard is broken
    - Posture regenerates back to 0 over time when not taking hits
    - Regeneration only starts after a delay (2s by default)

    This system handles:
    1. Posture regeneration over time
    2. Posture break detection and stun application
    3. Posture bar reset after break

    Posture DAMAGE is applied in Damage.lua HandleBlock() function.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local tags = require(ReplicatedStorage.Modules.ECS.jecs_tags)
local EntityCleanup = require(ReplicatedStorage.Modules.ECS.entity_cleanup)
local Packets = require(ReplicatedStorage.Modules.Packets)

-- Default posture values
local DEFAULT_POSTURE_MAX = 100
local DEFAULT_REGEN_RATE = 10      -- Posture recovered per second
local DEFAULT_REGEN_DELAY = 2      -- Seconds before regen starts after damage

-- Accumulators for fractional posture regen
local postureAccumulators: { [number]: number } = {}

-- Query for entities with PostureBar component
local postureQuery = world:query(comps.PostureBar, comps.Character):with(comps.ComponentsReady):without(comps.Dead):cached()

-- Cleanup when entity is removed
local function cleanup(entity: number)
	postureAccumulators[entity] = nil
end

-- Register cleanup callback
EntityCleanup.register("posture_system", cleanup)

--[[
    Initialize posture bar for an entity
    Called when entity is created or needs posture reset
]]
local function initializePosture(entity: number)
	local existing = world:get(entity, comps.PostureBar)
	if existing then
		return existing
	end

	local postureBar = {
		current = 0,
		max = DEFAULT_POSTURE_MAX,
		regenRate = DEFAULT_REGEN_RATE,
		regenDelay = DEFAULT_REGEN_DELAY,
		lastDamageTime = 0,
	}
	world:set(entity, comps.PostureBar, postureBar)
	return postureBar
end

--[[
    Apply posture damage to an entity
    Called from Damage.lua when blocking an attack

    @param entity - The ECS entity ID
    @param damage - Amount of posture damage to apply
    @return boolean - True if posture broke
]]
local function applyPostureDamage(entity: number, damage: number): boolean
	local postureBar = world:get(entity, comps.PostureBar)
	if not postureBar then
		postureBar = initializePosture(entity)
	end

	-- Apply damage
	postureBar.current = math.min(postureBar.current + damage, postureBar.max)
	postureBar.lastDamageTime = os.clock()
	world:set(entity, comps.PostureBar, postureBar)

	-- Check for posture break
	if postureBar.current >= postureBar.max then
		-- Add PostureBroken tag
		world:add(entity, tags.PostureBroken)
		return true
	end

	return false
end

--[[
    Reset posture to 0 (called after posture break stun ends)

    @param entity - The ECS entity ID
]]
local function resetPosture(entity: number, character: Model?)
	local postureBar = world:get(entity, comps.PostureBar)
	if postureBar then
		postureBar.current = 0
		postureBar.lastDamageTime = os.clock() -- Reset timer so regen doesn't start immediately
		world:set(entity, comps.PostureBar, postureBar)

		-- Send posture reset to client for UI (only for players)
		if character then
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				Packets.PostureSync.sendTo({
					Current = 0,
					Max = math.floor(postureBar.max),
				}, player)
			end
		end
	end

	-- Remove PostureBroken tag if present
	if world:has(entity, tags.PostureBroken) then
		world:remove(entity, tags.PostureBroken)
	end
end

--[[
    Get current posture percentage (0-1)

    @param entity - The ECS entity ID
    @return number - Posture percentage (0 = fresh, 1 = about to break)
]]
local function getPosturePercent(entity: number): number
	local postureBar = world:get(entity, comps.PostureBar)
	if not postureBar then
		return 0
	end
	return postureBar.current / postureBar.max
end

--[[
    Main posture system update
    Handles regeneration and posture break detection
]]
local function posture_system(_world, dt: number)
	-- Only run on server
	if RunService:IsClient() then
		return
	end

	local now = os.clock()

	for entity, postureBar, character in postureQuery do
		-- Skip if no posture damage
		if postureBar.current <= 0 then
			continue
		end

		-- Check if posture is broken (should apply stun)
		if world:has(entity, tags.PostureBroken) then
			-- Posture break is handled by Damage.lua which applies the stun
			-- This system just tracks the state
			continue
		end

		-- Check if regen delay has passed
		local timeSinceDamage = now - postureBar.lastDamageTime
		if timeSinceDamage < postureBar.regenDelay then
			-- Still in cooldown, don't regen
			continue
		end

		-- Regenerate posture (decrease current back toward 0)
		local regenAmount = postureBar.regenRate * dt

		-- Initialize accumulator if needed
		if not postureAccumulators[entity] then
			postureAccumulators[entity] = 0
		end

		-- Add to accumulator
		postureAccumulators[entity] = postureAccumulators[entity] + regenAmount

		-- Only apply when we have at least 1 point to remove
		if postureAccumulators[entity] >= 1 then
			local wholePosture = math.floor(postureAccumulators[entity])
			postureAccumulators[entity] = postureAccumulators[entity] - wholePosture

			-- Decrease posture (clamped to 0)
			postureBar.current = math.max(0, postureBar.current - wholePosture)
			world:set(entity, comps.PostureBar, postureBar)

			-- Send posture update to client for UI (only for players)
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				Packets.PostureSync.sendTo({
					Current = math.floor(postureBar.current),
					Max = math.floor(postureBar.max),
				}, player)
			end
		end
	end
end

-- Export functions for use by other modules (Damage.lua, Library.lua)
return {
	run = posture_system,
	settings = {
		server_only = true,
		phase = "Heartbeat",
	},

	-- Public API
	initializePosture = initializePosture,
	applyPostureDamage = applyPostureDamage,
	resetPosture = resetPosture,
	getPosturePercent = getPosturePercent,

	-- Constants for external use
	DEFAULT_POSTURE_MAX = DEFAULT_POSTURE_MAX,
	DEFAULT_REGEN_RATE = DEFAULT_REGEN_RATE,
	DEFAULT_REGEN_DELAY = DEFAULT_REGEN_DELAY,
}
