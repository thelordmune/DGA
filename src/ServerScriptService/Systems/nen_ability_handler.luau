--!strict
-- Server-side Nen Ability Handler
-- Validates and applies Nen ability effects to players

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local NenAbilities = require(ReplicatedStorage.Modules.NenAbilities)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

-- Forward declarations
local activateAbility
local deactivateAbility

-- Activate a Nen ability
activateAbility = function(player, entity, abilityName, abilityData, nenAbility, nenEffects)
	print(`[NenAbilityHandler] Activating {abilityName}`)

	-- Set as active
	nenAbility.active = abilityName
	table.insert(nenAbility.activeAbilities, abilityName)

	-- Apply effects
	local effects = abilityData.effects

	if effects.damageBonus then
		nenEffects.damageBonus = effects.damageBonus
	end

	if effects.damageReduction then
		nenEffects.damageReduction = effects.damageReduction
	end

	if effects.speedModifier then
		nenEffects.speedModifier = effects.speedModifier
	end

	if effects.invisibility then
		nenEffects.invisibility = effects.invisibility
	end

	if effects.detectionRadius then
		nenEffects.detectionRadius = effects.detectionRadius
	end

	-- Sync stamina drain rate to client (stamina is managed client-side)
	local drainRate = abilityData.staminaDrain or 0
	Bridges.NenStaminaDrain:Fire(player, {
		drainRate = drainRate,
		abilityName = abilityName,
	})
	print(`[NenAbilityHandler] Synced stamina drain rate {drainRate}% per second to client`)

	-- Handle special abilities
	if abilityName == "Zetsu" then
		-- Disable other Nen abilities
		-- TODO: Implement full Zetsu restrictions
	elseif abilityName == "Gyo" then
		-- TODO: Implement Gyo vision/detection
	elseif abilityName == "En" then
		-- TODO: Implement En detection sphere
	elseif abilityName == "Ko" then
		-- Ko is a one-time ability with charge time
		if abilityData.chargeTime then
			task.delay(abilityData.chargeTime, function()
				-- Apply Ko effect for a brief moment
				deactivateAbility(player, entity, abilityName, abilityData, nenAbility, nenEffects)
			end)
		end
	end
end

-- Deactivate a Nen ability
deactivateAbility = function(player, entity, abilityName, abilityData, nenAbility, nenEffects)
	print(`[NenAbilityHandler] Deactivating {abilityName}`)

	-- Remove from active
	if nenAbility.active == abilityName then
		nenAbility.active = nil
	end

	-- Remove from active abilities list
	for i, name in ipairs(nenAbility.activeAbilities) do
		if name == abilityName then
			table.remove(nenAbility.activeAbilities, i)
			break
		end
	end

	-- Reset effects to default
	nenEffects.damageBonus = 1.0
	nenEffects.damageReduction = 0.0
	nenEffects.speedModifier = 1.0
	nenEffects.invisibility = 0.0
	nenEffects.detectionRadius = 0
	nenEffects.focusedLimb = nil

	-- Stop stamina drain on client
	Bridges.NenStaminaDrain:Fire(player, {
		drainRate = 0,
		abilityName = abilityName,
	})

	-- Set cooldown
	if abilityData.cooldown > 0 then
		nenAbility.cooldowns[abilityName] = os.clock() + abilityData.cooldown
	end

	-- Add recovery endlag after Nen ability deactivation (prevents instant action)
	local character = player.Character
	if character then
		StateManager.TimedState(character, "Actions", "NenRecovery", 0.2)
	end
end

-- Listen for Nen ability activation requests from clients
Bridges.NenAbility:Connect(function(player: Player, data: {action: string, abilityName: string})
		print(`[NenAbilityHandler] Received request from {player.Name}:`, data.abilityName)

		local entity = ref.get("player", player)
		if not entity then
			warn(`[NenAbilityHandler] No entity found for player {player.Name}`)
			return
		end

		local abilityName = data.abilityName
		local action = data.action or "activate"

		-- Validate ability exists
		local abilityData = NenAbilities[abilityName]
		if not abilityData then
			warn(`[NenAbilityHandler] Invalid ability: {abilityName}`)
			return
		end

		print(`[NenAbilityHandler] Processing {abilityName} for {player.Name}`)

		-- Get or create Nen components
		local nenAbility = world:get(entity, comps.NenAbility)
		if not nenAbility then
			nenAbility = {
				active = nil,
				activeAbilities = {},
				cooldowns = {},
				level = 1,
			}
			world:set(entity, comps.NenAbility, nenAbility)
		end

		-- Get or create Nen effects
		local nenEffects = world:get(entity, comps.NenEffects)
		if not nenEffects then
			nenEffects = {
				damageBonus = 1.0,
				damageReduction = 0.0,
				speedModifier = 1.0,
				invisibility = 0.0,
				detectionRadius = 0,
				focusedLimb = nil,
			}
			world:set(entity, comps.NenEffects, nenEffects)
		end

		-- Check cooldown
		local currentTime = os.clock()
		if nenAbility.cooldowns[abilityName] and currentTime < nenAbility.cooldowns[abilityName] then
			-- Ability on cooldown
			local timeLeft = math.ceil(nenAbility.cooldowns[abilityName] - currentTime)
			Bridges.NenNotification:Fire(player, {
				abilityName = abilityName,
				success = false,
				message = `{abilityName} on cooldown ({timeLeft}s)`
			})
			return
		end

		-- Check level requirement
		if abilityData.minimumLevel then
			local levelComp = world:get(entity, comps.Level)
			if levelComp and levelComp.current < abilityData.minimumLevel then
				Bridges.NenNotification:Fire(player, {
					abilityName = abilityName,
					success = false,
					message = `{abilityName} requires level {abilityData.minimumLevel}`
				})
				return
			end
		end

		-- Note: Stamina checking is done client-side for responsiveness
		-- Server just validates ability exists and cooldowns

		-- Handle toggle abilities
		if abilityData.isToggle then
			if nenAbility.active == abilityName then
				-- Deactivate current ability
				deactivateAbility(player, entity, abilityName, abilityData, nenAbility, nenEffects)
				Bridges.NenNotification:Fire(player, {
					abilityName = abilityName,
					success = true,
					message = `{abilityName} deactivated`
				})
			else
				-- Deactivate any conflicting ability first
				if nenAbility.active then
					local currentAbilityData = NenAbilities[nenAbility.active]
					if currentAbilityData then
						deactivateAbility(player, entity, nenAbility.active, currentAbilityData, nenAbility, nenEffects)
					end
				end

				-- Activate new ability
				activateAbility(player, entity, abilityName, abilityData, nenAbility, nenEffects)
				Bridges.NenNotification:Fire(player, {
					abilityName = abilityName,
					success = true,
					message = `{abilityName} activated`
				})
			end
		else
			-- One-time use ability (like Ko)
			activateAbility(player, entity, abilityName, abilityData, nenAbility, nenEffects)
			Bridges.NenNotification:Fire(player, {
				abilityName = abilityName,
				success = true,
				message = `{abilityName} activated`
			})
		end

		-- Update components
		world:set(entity, comps.NenAbility, nenAbility)
		world:set(entity, comps.NenEffects, nenEffects)
	end)

-- No return needed - this is an event-driven system
