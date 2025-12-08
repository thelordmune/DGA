--!strict
--[[
    NPC Guard Attack Pattern System (ECS)
    
    Guards have specific attack patterns when aggro'd:
    1. DEFENSIVE: Block and wait
    2. COUNTER: Quick M1 counter
    3. PRESSURE: Aggressive follow-up (M2/Critical)
    4. SPECIAL: Use weapon skill
    5. RESET: Return to defensive stance
    
    State machine: DEFENSIVE → COUNTER → PRESSURE → SPECIAL → RESET → DEFENSIVE
    
    Runs at ~15 Hz
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local Server = require(ServerScriptService.ServerConfig.Server)
local Library = Server.Library
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local PlayerStateDetector = require(ReplicatedStorage.Modules.ECS.PlayerStateDetector_ECS)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)

-- NETWORK OPTIMIZATION: Throttle to 15 Hz instead of 60 Hz
-- Guard patterns don't need frame-perfect precision
local PATTERN_HZ = 15
local PATTERN_TICK = 1 / PATTERN_HZ
local patternAcc = 0

-- Cache queries (OPTIMIZED: added :cached())
local guardQuery = world:query(comps.Character, comps.CombatNPC, comps.NPCTarget, comps.NPCCombatState, comps.NPCGuardPattern, comps.Hitbox, comps.Combat):cached()

-- Guard pattern states
local GuardPatterns = {
	DEFENSIVE = "Defensive",
	COUNTER = "Counter",
	PRESSURE = "Pressure",
	SPECIAL = "Special",
	RESET = "Reset",
}

-- Get next pattern state
local function getNextPatternState(pattern: any, target: Model, distance: number): string
	local currentState = pattern.currentState
	local timeInState = os.clock() - pattern.stateStartTime
	local targetAttacking = PlayerStateDetector.IsAttacking(target)
	
	if currentState == GuardPatterns.DEFENSIVE then
		if targetAttacking and distance < 12 then
			return GuardPatterns.COUNTER
		end
		-- IMPROVED: Faster transition to counter (was 1.0s, now 0.5s)
		if timeInState > 0.5 and distance < 10 then
			return GuardPatterns.COUNTER
		end
		
	elseif currentState == GuardPatterns.COUNTER then
		if timeInState > 0.5 then
			return GuardPatterns.PRESSURE
		end
		
	elseif currentState == GuardPatterns.PRESSURE then
		if pattern.comboCount >= 3 then
			return GuardPatterns.SPECIAL
		end
		if timeInState > 1.2 then
			return GuardPatterns.RESET
		end
		
	elseif currentState == GuardPatterns.SPECIAL then
		if timeInState > 0.7 then
			return GuardPatterns.RESET
		end
		
	elseif currentState == GuardPatterns.RESET then
		if timeInState > 0.3 then
			return GuardPatterns.DEFENSIVE
		end
	end
	
	return currentState
end

-- Execute pattern action
local function executePatternAction(
	character: Model,
	target: Model,
	distance: number,
	currentState: string,
	pattern: any,
	combatState: any,
	combat: any
): boolean
	local weapon = character:GetAttribute("Weapon") or "Fist"
	local skillToUse = nil
	
	if currentState == GuardPatterns.DEFENSIVE then
		-- REMOVED: Guards no longer block in defensive state - they stay aggressive
		-- Just wait in defensive stance without blocking
		return false
		
	elseif currentState == GuardPatterns.COUNTER then
		local now = os.clock()
		if now - combatState.lastM1Time >= 0.8 and not Library.CheckCooldown(character, "M1") then
			skillToUse = "M1"
			pattern.comboCount = pattern.comboCount + 1
			combatState.lastM1Time = now
		end
		
	elseif currentState == GuardPatterns.PRESSURE then
		if not Library.CheckCooldown(character, "Critical") and distance < 12 then
			skillToUse = "Critical"
		else
			local now = os.clock()
			if now - combatState.lastM1Time >= 0.8 and not Library.CheckCooldown(character, "M1") then
				skillToUse = "M1"
				combatState.lastM1Time = now
			end
		end
		pattern.comboCount = pattern.comboCount + 1
		
	elseif currentState == GuardPatterns.SPECIAL then
		-- Weapon-specific skills
		if weapon == "Spear" then
			if not Library.CheckCooldown(character, "Grand Cleave") and distance < 10 then
				skillToUse = "Grand Cleave"
			elseif not Library.CheckCooldown(character, "Needle Thrust") and distance < 15 then
				skillToUse = "Needle Thrust"
			end
		elseif weapon == "Guns" then
			if not Library.CheckCooldown(character, "Shell Piercer") and distance > 10 then
				skillToUse = "Shell Piercer"
			elseif not Library.CheckCooldown(character, "Strategist Combination") and distance < 20 then
				skillToUse = "Strategist Combination"
			end
		elseif weapon == "Fist" then
			if not Library.CheckCooldown(character, "Axe Kick") and distance < 8 then
				skillToUse = "Axe Kick"
			elseif not Library.CheckCooldown(character, "Downslam Kick") and distance < 8 then
				skillToUse = "Downslam Kick"
			end
		end
		
		-- Fallback to M2
		if not skillToUse and not Library.CheckCooldown(character, "M2") then
			skillToUse = "M2"
		end
		
	elseif currentState == GuardPatterns.RESET then
		pattern.comboCount = 0
		return false
	end
	
	-- Execute skill
	if not skillToUse then return false end

	-- Face target
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if targetRoot then
		local lookDirection = (targetRoot.Position - character.PrimaryPart.Position).Unit
		local lookCFrame = CFrame.lookAt(character.PrimaryPart.Position, character.PrimaryPart.Position + Vector3.new(lookDirection.X, 0, lookDirection.Z))
		character.PrimaryPart.CFrame = character.PrimaryPart.CFrame:Lerp(lookCFrame, 0.5)
	end

	-- Execute
	if skillToUse == "M1" then
		if StateManager.StateCount(character, "Actions") then
			return false
		end
		if combat and combat.Light then
			combat.Light(character)
			return true
		end
	elseif skillToUse == "Critical" or skillToUse == "M2" then
		if combat and combat.Critical then
			combat.Critical(character)
			return true
		end
	elseif skillToUse == "Block" then
		if combat and combat.HandleBlockInput then
			combat.HandleBlockInput(character, true)
			return true
		end
	else
		-- Weapon skill
		local actor = character:FindFirstAncestorOfClass("Actor")
		if actor then
			local mainConfig = require(actor:FindFirstChild("MainConfig"))
			if mainConfig and mainConfig.performAction then
				return mainConfig.performAction(skillToUse)
			end
		end
	end

	return false
end

-- Main system function
local function updateGuardPattern()
	for entity, character, _, target, combatState, pattern, hitbox, combat in guardQuery do
		-- Skip if not enabled
		if not pattern.enabled then continue end

		-- Skip if not aggressive
		if not combatState.isAggressive then continue end

		-- Skip if no target
		if not target or not target:IsDescendantOf(workspace) then
			continue
		end

		-- Skip if only for guards and this isn't a guard
		if not string.find(character.Name, "Guard") then
			continue
		end

		-- Get distance
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if not targetRoot then continue end
		local distance = (targetRoot.Position - hitbox.Position).Magnitude

		-- Too far
		if distance > 25 then continue end

		-- Get next state
		local nextState = getNextPatternState(pattern, target, distance)

		-- Update state if changed
		if nextState ~= pattern.currentState then
			pattern.currentState = nextState
			pattern.stateStartTime = os.clock()
			world:set(entity, comps.NPCGuardPattern, pattern)
		end

		-- Execute action
		local success = executePatternAction(character, target, distance, pattern.currentState, pattern, combatState, combat)

		if success then
			combatState.lastActionTime = os.clock()
			world:set(entity, comps.NPCCombatState, combatState)
			world:set(entity, comps.NPCGuardPattern, pattern)
		end
	end
end

return {
	run = function(_world: Jecs.World, dt: number)
		-- NETWORK OPTIMIZATION: Throttle to 15 Hz
		patternAcc += dt
		if patternAcc >= PATTERN_TICK then
			patternAcc = 0
			updateGuardPattern()
		end
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}


