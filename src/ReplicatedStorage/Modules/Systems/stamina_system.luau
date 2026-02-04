--!strict
-- Client-Side Stamina System
-- Handles stamina regeneration and drain for Nen abilities locally
-- Server only validates ability activation, not stamina values

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local Bridges = require(ReplicatedStorage.Modules.Bridges)

-- Get the player bars data from Stats controller for UI updates
local function getPlayerBarsData()
	local success, Client = pcall(require, ReplicatedStorage.Client)
	if not success or not Client then
		return nil
	end

	local success2, Stats = pcall(require, ReplicatedStorage.Client.Interface.Stats)
	if not success2 or not Stats then
		return nil
	end

	return Stats.playerBarsData
end

-- System to update stamina for local player
local function staminaSystem(_world, deltaTime)
	-- Only run on client
	if RunService:IsServer() then return end

	local player = Players.LocalPlayer
	if not player then return end

	-- Get local player entity
	local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
	local entity = ref.get("local_player")
	if not entity then return end

	-- Get stamina component
	local stamina = world:get(entity, comps.Stamina)
	if not stamina then
		-- Initialize stamina for local player
		stamina = {
			current = 100,
			max = 100,
			regenRate = 2, -- 2% per second by default
			drainRate = 0, -- No drain by default
		}
		world:set(entity, comps.Stamina, stamina)

		-- Update UI immediately
		local playerBarsData = getPlayerBarsData()
		if playerBarsData and playerBarsData.staminaValue then
			playerBarsData.staminaValue:set(100)
		end
		return
	end

	-- Validate and clamp stamina values to prevent corruption
	stamina.current = math.clamp(stamina.current or 100, 0, stamina.max or 100)
	stamina.drainRate = math.max(0, stamina.drainRate or 0)
	stamina.regenRate = math.max(0, stamina.regenRate or 2)

	local changed = false

	-- Track drain rate changes for debugging rapid switching
	if not stamina._lastDrainRate then
		stamina._lastDrainRate = 0
	end
	if stamina.drainRate ~= stamina._lastDrainRate then
		print(`[StaminaSystem] Drain rate changed: {stamina._lastDrainRate}% -> {stamina.drainRate}%`)
		stamina._lastDrainRate = stamina.drainRate
	end

	-- Apply stamina drain (from active Nen abilities)
	if stamina.drainRate > 0 then
		local wasAboveZero = stamina.current > 0
		local drainAmount = stamina.drainRate * deltaTime
		stamina.current = math.max(0, stamina.current - drainAmount)
		changed = true

		-- Debug: Show drain rate occasionally
		if math.random() < 0.01 then -- 1% chance per frame
			local staminaRounded = math.floor(stamina.current * 10) / 10
			print(`[StaminaSystem] Draining: {staminaRounded}/{stamina.max} at {stamina.drainRate}%/s`)
		end

		-- If stamina just reached 0 (crossing threshold), deactivate active Nen ability
		if wasAboveZero and stamina.current <= 0 then
			print("[StaminaSystem] Stamina hit zero! Triggering exhaustion...")

			-- Get NenBasics module once to avoid redefinition
			local NenBasics = require(ReplicatedStorage.Client.Inputs.NenBasics)

			-- Try to get active ability from NenBasics input state (more reliable than ECS)
			local exhaustedAbility = nil
			if NenBasics.GetCurrentAbility then
				exhaustedAbility = NenBasics.GetCurrentAbility()
				print(`[StaminaSystem] Got ability from NenBasics: {exhaustedAbility}`)
			end

			-- Fallback to ECS component if NenBasics doesn't have it
			if not exhaustedAbility then
				local nenAbility = world:get(entity, comps.NenAbility)
				if nenAbility then
					exhaustedAbility = nenAbility.active
					print(`[StaminaSystem] Got ability from ECS: {exhaustedAbility}`)
				end
			end

			if exhaustedAbility then
				print(`[StaminaSystem] Processing exhaustion for: {exhaustedAbility}`)

				-- Deactivate due to stamina exhaustion
				stamina.drainRate = 0

				-- Update ECS components
				local nenAbility = world:get(entity, comps.NenAbility)
				if nenAbility then
					nenAbility.active = nil
					world:set(entity, comps.NenAbility, nenAbility)
				end

				-- Reset Nen effects
				local nenEffects = world:get(entity, comps.NenEffects)
				if nenEffects then
					nenEffects.damageBonus = 1.0
					nenEffects.damageReduction = 0.0
					nenEffects.speedModifier = 1.0
					nenEffects.invisibility = 0.0
					nenEffects.detectionRadius = 0
					world:set(entity, comps.NenEffects, nenEffects)
				end

				-- Show exhaustion UI
				-- Call the Stats controller's nenIndicatorData.showExhausted if available
				task.spawn(function()
					local success, Stats = pcall(require, ReplicatedStorage.Client.Interface.Stats)
					if success and Stats and Stats.nenIndicatorData then
						if Stats.nenIndicatorData.showExhausted then
							Stats.nenIndicatorData.showExhausted()
							print("[StaminaSystem] Triggered NEN EXHAUSTED UI")
						else
							warn("[StaminaSystem] showExhausted function not found in nenIndicatorData")
						end
					else
						warn("[StaminaSystem] Could not access Stats.nenIndicatorData")
					end
				end)

				-- Reset NenBasics input state (reusing already required module)
				if NenBasics.ResetState then
					NenBasics.ResetState()
				end

				-- Notify server to deactivate the ability
				Bridges.NenAbility:Fire({
					action = "deactivate",
					abilityName = exhaustedAbility,
				})

				warn(`[StaminaSystem] Nen ability '{exhaustedAbility}' deactivated due to stamina exhaustion`)
			else
				warn("[StaminaSystem] Could not determine which ability was active when stamina hit zero")
			end
		end
	end

	-- Apply stamina regeneration (only if not at max and not draining)
	if stamina.current < stamina.max and stamina.drainRate == 0 then
		local regenAmount = stamina.regenRate * deltaTime
		stamina.current = math.min(stamina.max, stamina.current + regenAmount)
		changed = true
	end

	-- Update component and UI if changed
	if changed then
		world:set(entity, comps.Stamina, stamina)

		-- Update UI directly - no network calls needed!
		local playerBarsData = getPlayerBarsData()
		if playerBarsData and playerBarsData.staminaValue then
			local staminaPercent = math.clamp((stamina.current / stamina.max) * 100, 0, 100)
			playerBarsData.staminaValue:set(staminaPercent)
		end
	end
end

-- Export for scheduler
return {
	run = staminaSystem,
	settings = {
		client_only = true,
		phase = "PreRender", -- Run on PreRender for immediate visual updates
	},
}
