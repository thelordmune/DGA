--!strict
-- Server-side Nen Ability Handler
-- Validates and applies Nen ability effects to players

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local NenAbilities = require(ReplicatedStorage.Modules.NenAbilities)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

-- Forward declarations
local activateAbility
local deactivateAbility

-- ============================================
-- EN SPHERE MODEL MANAGEMENT
-- Server creates and manages the En model in workspace
-- so all clients can see it via Roblox replication.
-- ============================================

-- Active En data per player: { model, growConnection, currentScale }
local activeEnSpheres: {[Player]: {model: Model, growConnection: RBXScriptConnection?, currentScale: number}} = {}

local EN_MIN_RADIUS = 5
local EN_GROWTH_RATE = 10 -- studs per second radius growth (match client)
local EN_MAX_RADIUS = 50 -- max radius (match client)

local function startEnSphere(player: Player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Clean up existing En sphere if any
	if activeEnSpheres[player] then
		if activeEnSpheres[player].growConnection then
			activeEnSpheres[player].growConnection:Disconnect()
		end
		if activeEnSpheres[player].model and activeEnSpheres[player].model.Parent then
			activeEnSpheres[player].model:Destroy()
		end
		activeEnSpheres[player] = nil
	end

	-- Clone En model from assets
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then return end
	local vfxFolder = assetsFolder:FindFirstChild("VFX")
	if not vfxFolder then return end
	local aurasFolder = vfxFolder:FindFirstChild("Auras")
	if not aurasFolder then return end
	local enFolder = aurasFolder:FindFirstChild("En")
	if not enFolder then return end
	local enTemplate = enFolder:FindFirstChild("En")
	if not enTemplate then return end

	local clone = enTemplate:Clone()
	clone.Name = "EnSphere_" .. player.Name
	clone.Parent = workspace

	-- Enable all descendant ParticleEmitters
	for _, desc in clone:GetDescendants() do
		if desc:IsA("ParticleEmitter") then
			desc.Enabled = true
		end
	end

	-- Position slightly above feet
	local leftLeg = character:FindFirstChild("Left Leg")
	local legHeight = leftLeg and leftLeg.Size.Y or 2
	local feetOffset = -(hrp.Size.Y / 2 + legHeight) + 2.5

	-- Start at tiny scale so it grows in
	if clone:IsA("Model") then
		clone:ScaleTo(0.01)
		clone:PivotTo(hrp.CFrame * CFrame.new(0, feetOffset, 0))
	elseif clone:IsA("BasePart") then
		clone.Size = Vector3.new(0.1, 0.1, 0.1)
		clone.CFrame = hrp.CFrame * CFrame.new(0, feetOffset, 0)
	end

	local enData = {
		model = clone,
		growConnection = nil,
		currentScale = 0.01,
		startTime = os.clock(),
	}

	-- Server Heartbeat: grow the model with easing and keep it at feet
	-- Server computes EnRadius itself (client attributes don't replicate to server)
	enData.growConnection = RunService.Heartbeat:Connect(function()
		if not character or not character.Parent then
			return
		end
		if not hrp or not hrp.Parent then
			return
		end

		-- Server-side radius growth (matches client logic)
		local holdTime = os.clock() - enData.startTime
		local currentRadius = math.min(EN_MIN_RADIUS + EN_GROWTH_RATE * holdTime, EN_MAX_RADIUS)
		character:SetAttribute("EnRadius", currentRadius)

		local targetScale = math.min(currentRadius / EN_MIN_RADIUS, 1.5)

		-- Smooth grow-in with ease-out (fast start, slow end)
		local diff = targetScale - enData.currentScale
		local speed = 0.08 + math.abs(diff) * 0.05
		enData.currentScale = enData.currentScale + diff * speed

		-- Snap if close enough
		if math.abs(diff) < 0.001 then
			enData.currentScale = targetScale
		end

		-- Position slightly above feet
		if clone:IsA("Model") then
			clone:ScaleTo(enData.currentScale)
			clone:PivotTo(hrp.CFrame * CFrame.new(0, feetOffset, 0))
		elseif clone:IsA("BasePart") then
			local diameter = EN_MIN_RADIUS * enData.currentScale * 2
			clone.Size = Vector3.new(diameter, diameter, diameter)
			clone.CFrame = hrp.CFrame * CFrame.new(0, feetOffset, 0)
		end
	end)

	activeEnSpheres[player] = enData

	-- Set attributes for detection system
	character:SetAttribute("EnActive", true)

	-- Stamina drain disabled for now
	-- Bridges.NenStaminaDrain:Fire(player, {
	-- 	drainRate = NenAbilities.En.staminaDrain,
	-- 	abilityName = "En",
	-- })

	print(`[NenAbilityHandler] En sphere started for {player.Name}`)
end

local function stopEnSphere(player: Player)
	local enData = activeEnSpheres[player]
	if not enData then return end

	-- Disconnect grow loop
	if enData.growConnection then
		enData.growConnection:Disconnect()
		enData.growConnection = nil
	end

	-- Disable particles
	if enData.model and enData.model.Parent then
		for _, desc in enData.model:GetDescendants() do
			if desc:IsA("ParticleEmitter") then
				desc.Enabled = false
			end
		end

		-- Shrink with ease-in (slow start, accelerates) then destroy
		local model = enData.model
		local shrinkStart = os.clock()
		local shrinkDuration = 0.6
		local startScale = enData.currentScale

		local shrinkConn
		shrinkConn = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - shrinkStart
			local t = math.clamp(elapsed / shrinkDuration, 0, 1)

			if t >= 1 then
				shrinkConn:Disconnect()
				if model and model.Parent then
					model:Destroy()
				end
				return
			end

			-- Ease-in quad: t^2 (slow start, fast end)
			local eased = t * t
			local scale = startScale * (1 - eased)
			if scale > 0.005 and model and model.Parent then
				if model:IsA("Model") then
					model:ScaleTo(scale)
				elseif model:IsA("BasePart") then
					local d = EN_MIN_RADIUS * scale * 2
					model.Size = Vector3.new(d, d, d)
				end
			end
		end)
	end

	activeEnSpheres[player] = nil

	-- Clear attributes
	local character = player.Character
	if character then
		character:SetAttribute("EnActive", nil)
		character:SetAttribute("EnRadius", nil)
	end

	-- Stamina drain disabled for now
	-- local entity = ref.get("player", player)
	-- if entity then
	-- 	local nenAbility = world:get(entity, comps.NenAbility)
	-- 	if nenAbility and nenAbility.active then
	-- 		local baseAbility = NenAbilities[nenAbility.active]
	-- 		if baseAbility then
	-- 			Bridges.NenStaminaDrain:Fire(player, {
	-- 				drainRate = baseAbility.staminaDrain,
	-- 				abilityName = nenAbility.active,
	-- 			})
	-- 		end
	-- 	else
	-- 		Bridges.NenStaminaDrain:Fire(player, {
	-- 			drainRate = 0,
	-- 			abilityName = "En",
	-- 		})
	-- 	end
	-- end

	print(`[NenAbilityHandler] En sphere stopped for {player.Name}`)
end

-- Clean up En spheres when player leaves
Players.PlayerRemoving:Connect(function(player)
	stopEnSphere(player)
end)

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

	-- Stamina drain disabled for now
	-- local drainRate = abilityData.staminaDrain or 0
	-- Bridges.NenStaminaDrain:Fire(player, {
	-- 	drainRate = drainRate,
	-- 	abilityName = abilityName,
	-- })
	-- print(`[NenAbilityHandler] Synced stamina drain rate {drainRate}% per second to client`)

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

	-- Stamina drain disabled for now
	-- Bridges.NenStaminaDrain:Fire(player, {
	-- 	drainRate = 0,
	-- 	abilityName = abilityName,
	-- })

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
		print(`[NenAbilityHandler] Received request from {player.Name}:`, data.action, data.abilityName)

		-- Handle En sphere start/stop (separate from standard ability toggle)
		if data.action == "en_start" then
			startEnSphere(player)
			return
		elseif data.action == "en_stop" then
			stopEnSphere(player)
			return
		end

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
