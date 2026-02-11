--!strict
--[[
	Focus System - Server ECS System

	Handles:
	- Passive focus decay
	- Mini mode enter/exit (50%+)
	- Absolute focus trigger (100%)
	- Focus bonuses (Nen drain reduction, HP regen boost)
	- Client sync (throttled to ~10Hz)
	- Training XP from natural decay
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local Packets = require(ReplicatedStorage.Modules.Packets)
local EntityCleanup = require(ReplicatedStorage.Modules.ECS.entity_cleanup)
local FocusConfig = require(game.ServerScriptService.ServerConfig.Server.FocusConfig)

-- Lazy-load FocusHandler to avoid circular dependency
local FocusHandler = nil
local function getFocusHandler()
	if not FocusHandler then
		-- FocusHandler is inside ServerConfig, load via require path
		local success, result = pcall(function()
			return require(game.ServerScriptService.ServerConfig.Server.FocusHandler)
		end)
		if success then
			FocusHandler = result
		end
	end
	return FocusHandler
end

-- Sync throttle
local syncAccumulators: {[number]: number} = {}

-- Focus bonus health regen accumulators
local focusHealthAccumulators: {[number]: number} = {}

-- Training save throttle
local trainingSaveAccumulators: {[number]: number} = {}

-- Query for entities with Focus + Character + Player (only players have focus)
local focusQuery = world:query(comps.Focus, comps.Character, comps.Player):with(comps.ComponentsReady):without(comps.Dead):cached()

-- Cleanup when entity is removed
local function cleanup(entity: number)
	syncAccumulators[entity] = nil
	focusHealthAccumulators[entity] = nil
	trainingSaveAccumulators[entity] = nil
end

EntityCleanup.register("focus_system", cleanup)

local function focus_system(_world, dt: number)
	if RunService:IsClient() then
		return
	end

	local handler = getFocusHandler()

	for entity, focus, character, player in focusQuery do
		-- Initialize accumulators
		if not syncAccumulators[entity] then
			syncAccumulators[entity] = 0
		end
		if not focusHealthAccumulators[entity] then
			focusHealthAccumulators[entity] = 0
		end
		if not trainingSaveAccumulators[entity] then
			trainingSaveAccumulators[entity] = 0
		end

		--------------------------------------------------------------------
		-- Passive Decay
		--------------------------------------------------------------------
		if focus.current > 0 then
			local decayAmount = focus.decayRate * dt
			local floor = math.max(focus.permanentFloor, focus.tempFloor)
			local oldCurrent = focus.current

			focus.current = math.max(focus.current - decayAmount, floor)

			-- Grant training XP for natural decay while having focus
			if oldCurrent > floor and focus.current > 0 then
				focus.trainingXP = focus.trainingXP + (FocusConfig.DecayTrainingXPPerSecond * dt)
			end
		end

		-- Additional decay for running/blocking in combat
		local inCombat = world:get(entity, comps.InCombat)
		local isInCombat = inCombat and inCombat.value or false

		if isInCombat and focus.current > 0 then
			local extraDecay = 0

			-- Running in combat
			if StateManager.StateCheck(character, "Actions", "Running") or
			   StateManager.StateCheck(character, "Speeds", "RunSpeedSet30") then
				extraDecay = extraDecay + FocusConfig.Amounts.RUNNING_IN_COMBAT * dt
			end

			-- Blocking in combat
			if StateManager.StateCheck(character, "Actions", "Blocking") or
			   StateManager.StateCheck(character, "Frames", "Blocking") then
				extraDecay = extraDecay + FocusConfig.Amounts.BLOCKING_IN_COMBAT * dt
			end

			if extraDecay > 0 then
				local floor = math.max(focus.permanentFloor, focus.tempFloor)
				focus.current = math.max(focus.current - extraDecay, floor)
			end
		end

		--------------------------------------------------------------------
		-- Mini Mode Transitions
		--------------------------------------------------------------------
		local focusPercent = focus.max > 0 and (focus.current / focus.max) or 0

		if focusPercent >= FocusConfig.MiniModeThreshold then
			if not focus.inMiniMode and handler then
				handler.EnterMiniMode(character)
			end
		else
			if focus.inMiniMode and handler then
				handler.ExitMiniMode(character)
			end
		end

		--------------------------------------------------------------------
		-- Absolute Focus Trigger
		--------------------------------------------------------------------
		if focus.current >= focus.max and not focus.inAbsoluteMode and handler then
			handler.TriggerAbsoluteFocus(character)
		end

		--------------------------------------------------------------------
		-- Focus Bonuses: HP Regen
		--------------------------------------------------------------------
		if focusPercent >= FocusConfig.MiniModeThreshold then
			local bonusRegen = 0
			if focusPercent >= 1.0 then
				bonusRegen = FocusConfig.HPRegen.At100Percent
			elseif focusPercent >= 0.75 then
				bonusRegen = FocusConfig.HPRegen.At75Percent
			else
				bonusRegen = FocusConfig.HPRegen.At50Percent
			end

			local health = world:get(entity, comps.Health)
			if health and health.current < health.max then
				focusHealthAccumulators[entity] = focusHealthAccumulators[entity] + (bonusRegen * dt)

				if focusHealthAccumulators[entity] >= 1 then
					local wholeHP = math.floor(focusHealthAccumulators[entity])
					focusHealthAccumulators[entity] = focusHealthAccumulators[entity] - wholeHP

					health.current = math.min(health.current + wholeHP, health.max)

					if character and character:FindFirstChild("Humanoid") then
						(character.Humanoid :: Humanoid).Health = health.current
					end
				end
			end
		end

		--------------------------------------------------------------------
		-- Focus Bonuses: Nen Drain Reduction
		-- Applied by modifying the stamina drainRate
		--------------------------------------------------------------------
		if focusPercent >= FocusConfig.MiniModeThreshold then
			local stamina = world:get(entity, comps.Stamina)
			if stamina and stamina.drainRate > 0 then
				local reduction = 0
				if focusPercent >= 1.0 then
					reduction = FocusConfig.NenDrainReduction.At100Percent
				elseif focusPercent >= 0.75 then
					reduction = FocusConfig.NenDrainReduction.At75Percent
				else
					reduction = FocusConfig.NenDrainReduction.At50Percent
				end

				-- Store the focus reduction on the character as an attribute
				-- The stamina_system can read this to apply the reduction
				character:SetAttribute("FocusNenReduction", reduction)
			end
		else
			-- Clear reduction attribute
			if character:GetAttribute("FocusNenReduction") then
				character:SetAttribute("FocusNenReduction", nil)
			end
		end

		--------------------------------------------------------------------
		-- Sync to Client (throttled)
		--------------------------------------------------------------------
		syncAccumulators[entity] = syncAccumulators[entity] + dt
		if syncAccumulators[entity] >= FocusConfig.SyncInterval then
			syncAccumulators[entity] = 0

			-- Find the Player instance
			local playerInstance = Players:GetPlayerFromCharacter(character)
			if playerInstance then
				Packets.FocusSync.sendTo({
					Current = math.clamp(math.floor(focus.current + 0.5), 0, 255),
					Max = math.clamp(math.floor(focus.max + 0.5), 0, 255),
				}, playerInstance)
			end
		end

		--------------------------------------------------------------------
		-- Periodic Training Save (throttled to every 60s)
		--------------------------------------------------------------------
		if focus.trainingXP > 0 then
			trainingSaveAccumulators[entity] = trainingSaveAccumulators[entity] + dt
			if trainingSaveAccumulators[entity] >= FocusConfig.TrainingSaveInterval then
				trainingSaveAccumulators[entity] = 0

				local playerInstance2 = Players:GetPlayerFromCharacter(character)
				if playerInstance2 and handler then
					handler.SaveTrainingData(playerInstance2, focus)
				end
			end
		end
	end
end

return {
	run = focus_system,
	settings = {
		server_only = true,
		phase = "Heartbeat",
	},
}
