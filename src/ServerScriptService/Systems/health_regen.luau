--!strict
--[[
    Health & BlockBar Regeneration System - OPTIMIZED & COMBINED

    Provides passive regeneration for both Health and BlockBar components.

    Health Regeneration:
    - Out of Combat: 2 HP per second
    - In Combat: 0.5 HP per second

    BlockBar Regeneration:
    - BlockBar starts at 0 and increases when hit while blocking
    - When BlockBar reaches 100, the block is broken
    - BBRegen component is set to {value = true, duration = 2} when hit while blocking
    - After 2 seconds of not being hit, BlockBar starts regenerating back to 0
    - Regeneration rate: 20 per second (takes 5 seconds to fully regenerate from 100 to 0)

    OPTIMIZATIONS:
    - Combined two systems into one to reduce overhead
    - Single query loop processes both health and blockbar
    - Shared accumulator pattern for fractional values
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local EntityCleanup = require(ReplicatedStorage.Modules.ECS.entity_cleanup)

-- Health regeneration rates (HP per second)
local HEALTH_REGEN_OUT_OF_COMBAT = 2
local HEALTH_REGEN_IN_COMBAT = 0.5

-- BlockBar regeneration rate (points per second)
local BLOCKBAR_REGEN_RATE = 20

-- Accumulators for fractional values
local healthAccumulators = {}
local blockBarAccumulators = {}

-- OPTIMIZED: Query with Health component directly to avoid world:get() calls
-- :without(comps.Dead) excludes dead entities at archetype level (no regen for dead)
local healthRegenQuery = world:query(comps.Health, comps.Character):with(comps.ComponentsReady):without(comps.Dead):cached()

-- Cleanup when entity is removed (prevents memory leak from accumulator tables)
local function cleanup(entity: number)
	healthAccumulators[entity] = nil
	blockBarAccumulators[entity] = nil
end

-- Register cleanup callback for centralized entity cleanup
EntityCleanup.register("health_regen", cleanup)

local function regen_system(_world, dt: number)
	-- Only run on server
	if RunService:IsClient() then
		return
	end

	-- NOTE: Cleanup is now handled by EntityCleanup.cleanup() called from mobs.luau/playerloader.luau
	-- This removes the unreliable world:exists() check that had JECS entity ID reuse issues

	-- OPTIMIZED: Query includes Health and Character directly (avoids world:get calls)
	for entity, health, character in healthRegenQuery do

		if health.current < health.max then
			-- Check if entity is in combat
			local inCombat = world:get(entity, comps.InCombat)
			local isInCombat = inCombat and inCombat.value or false

			-- Determine regeneration rate
			local regenRate = isInCombat and HEALTH_REGEN_IN_COMBAT or HEALTH_REGEN_OUT_OF_COMBAT

			-- Calculate health to add this frame
			local healthToAdd = regenRate * dt

			-- Initialize accumulator if needed
			if not healthAccumulators[entity] then
				healthAccumulators[entity] = 0
			end

			-- Add to accumulator
			healthAccumulators[entity] = healthAccumulators[entity] + healthToAdd

			-- Only apply when we have at least 1 HP to add
			if healthAccumulators[entity] >= 1 then
				local wholeHealth = math.floor(healthAccumulators[entity])
				healthAccumulators[entity] = healthAccumulators[entity] - wholeHealth

				-- Add health (clamped to max) - in-place mutation
				local newHealth = math.min(health.current + wholeHealth, health.max)
				health.current = newHealth

				-- Update character's Humanoid if it exists
				if character and character:FindFirstChild("Humanoid") then
					local humanoid = character.Humanoid :: Humanoid
					humanoid.Health = newHealth
				end
			end
		end

		-- Process BlockBar regeneration
		local blockBar = world:get(entity, comps.BlockBar)
		if blockBar and blockBar.Value > 0 then
			-- Check if BBRegen is active
			local bbRegen = world:get(entity, comps.BBRegen)
			if bbRegen and bbRegen.value and bbRegen.duration <= 0 then
				-- Calculate BlockBar to remove this frame
				local blockBarToRemove = BLOCKBAR_REGEN_RATE * dt

				-- Initialize accumulator if needed
				if not blockBarAccumulators[entity] then
					blockBarAccumulators[entity] = 0
				end

				-- Add to accumulator
				blockBarAccumulators[entity] = blockBarAccumulators[entity] + blockBarToRemove

				-- Only apply when we have at least 1 point to remove
				if blockBarAccumulators[entity] >= 1 then
					local wholeBlockBar = math.floor(blockBarAccumulators[entity])
					blockBarAccumulators[entity] = blockBarAccumulators[entity] - wholeBlockBar

					-- Remove BlockBar (clamped to 0) - in-place mutation
					local newValue = math.max(0, blockBar.Value - wholeBlockBar)
					blockBar.Value = newValue

					-- If fully regenerated, disable BBRegen
					if newValue <= 0 then
						world:set(entity, comps.BBRegen, { value = false, duration = 0 })
					end
				end
			end
		end
	end
end



return {
	run = regen_system,
	settings = {
		server_only = true,
		phase = "Heartbeat",
	},
}
