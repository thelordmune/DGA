--!strict
--[[
    NPC Skill Scoring System (ECS)
    
    Translates intelligent_attack.lua logic to pure ECS.
    Scores all available skills based on:
    - Distance to target vs skill's optimal range
    - Player state (blocking, hyper armor, attacking, ragdolled)
    - Aggressive mode bonuses
    - Health-based preferences (defensive when low HP)
    - Combo context (prefer enders after starters)
    - Cooldowns
    
    Runs at ~15 Hz for performance
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local Server = require(ServerScriptService.ServerConfig.Server)
local Library = Server.Library
local CombatProperties = require(ReplicatedStorage.Modules.CombatProperties)
local PlayerStateDetector = require(ReplicatedStorage.Modules.ECS.PlayerStateDetector)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)

-- NETWORK OPTIMIZATION: Throttle to 15 Hz instead of 60 Hz
-- Skill scoring doesn't need frame-perfect precision
local SCORING_HZ = 15
local SCORING_TICK = 1 / SCORING_HZ
local scoringAcc = 0

-- Cache queries (OPTIMIZED: added :cached())
local combatNPCQuery = world:query(comps.Character, comps.CombatNPC, comps.NPCTarget, comps.NPCCombatState, comps.NPCSkillScoring, comps.Health, comps.Hitbox, comps.Combat):cached()

-- Cache for player states (avoid redundant PlayerStateDetector calls)
local playerStateCache = {} -- [Model] = {blocking, ragdolled, hyperArmor, timestamp}
local PLAYER_STATE_CACHE_TIME = 0.033 -- Cache for 33ms (2 frames at 60fps)

-- Get cached player state (OPTIMIZED: reduces redundant state checks)
local function getPlayerState(target: Model, now: number)
	local cached = playerStateCache[target]
	if cached and (now - cached.timestamp) < PLAYER_STATE_CACHE_TIME then
		return cached.blocking, cached.ragdolled, cached.hyperArmor
	end

	-- Calculate fresh state
	local blocking = PlayerStateDetector.IsBlocking(target)
	local ragdolled = PlayerStateDetector.IsRagdolled(target)
	local hyperArmor = PlayerStateDetector.HasHyperArmor(target)

	-- Cache it
	playerStateCache[target] = {
		blocking = blocking,
		ragdolled = ragdolled,
		hyperArmor = hyperArmor,
		timestamp = now
	}

	return blocking, ragdolled, hyperArmor
end

-- Get distance to target (OPTIMIZED: inline for performance)
local function getDistanceToTarget(npcRoot: Part, target: Model): number
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return 999 end
	return (targetRoot.Position - npcRoot.Position).Magnitude
end

-- Get available skills for NPC
local function getAvailableSkills(npc: Model): {string}
	local skills = {"M1", "Critical"} -- REMOVED: Block - NPCs no longer block
	
	-- Get weapon skills from Data folder
	local actor = npc:FindFirstAncestorOfClass("Actor")
	if actor then
		local data = actor:FindFirstChild("Data")
		if data then
			local skillsFolder = data:FindFirstChild("Skills")
			if skillsFolder then
				for _, skillValue in skillsFolder:GetChildren() do
					if skillValue:IsA("StringValue") then
						table.insert(skills, skillValue.Value)
					end
				end
			end
		end
	end
	
	return skills
end

-- Score a skill based on combat properties and context (OPTIMIZED: added now param for caching)
local function scoreSkill(
	skillName: string,
	distance: number,
	npc: Model,
	target: Model,
	combatState: any,
	health: any,
	now: number
): number
	-- Get combat properties for this skill
	local properties = CombatProperties[skillName]
	if not properties then
		-- Default properties for M1/Block
		if skillName == "M1" then
			properties = {
				SkillType = "Offensive",
				RangeType = "Close",
				TargetingProperties = { MinRange = 0, MaxRange = 10, OptimalRange = 5 },
				SkillPriority = 5,
			}
		elseif skillName == "Block" then
			properties = {
				SkillType = "Defensive",
				RangeType = "Close",
				TargetingProperties = { MinRange = 0, MaxRange = 15, OptimalRange = 8 },
				SkillPriority = 1, -- REDUCED from 3 to 1 to prevent excessive blocking
			}
		else
			return 0
		end
	end
	
	-- Check cooldown
	if Library.CheckCooldown(npc, skillName) then
		return 0
	end
	
	-- Base score from priority
	local score = properties.SkillPriority or 1
	
	-- Distance scoring
	local targetProps = properties.TargetingProperties
	if targetProps then
		local minRange = targetProps.MinRange or 0
		local maxRange = targetProps.MaxRange or 100
		local optimalRange = targetProps.OptimalRange or ((minRange + maxRange) / 2)
		
		-- Out of range = 0 score
		if distance < minRange or distance > maxRange then
			return 0
		end
		
		-- Distance from optimal range penalty
		local distanceFromOptimal = math.abs(distance - optimalRange)
		local rangeTolerance = (maxRange - minRange) / 2
		local distancePenalty = distanceFromOptimal / rangeTolerance
		score = score * (1 - distancePenalty * 0.5)
	end
	
	-- Aggressive mode bonus
	if combatState.isAggressive then
		score = score * 1.3
	end
	
	-- Low health = prefer defensive skills (but not too much)
	local healthPercent = health.current / (health.max or 100)
	if healthPercent < 0.3 then
		if properties.SkillType == "Defensive" then
			-- REDUCED from 2.0 to 1.3 to prevent constant blocking at low HP
			score = score * 1.3
		elseif properties.SkillType == "Offensive" then
			score = score * 0.7
		end
	end

	-- ADDED: Block should only be used when player is attacking
	if skillName == "Block" then
		local playerAttacking = PlayerStateDetector.IsAttacking(target)
		if not playerAttacking then
			-- Heavily penalize blocking when player isn't attacking
			score = score * 0.1
		end
	end

	-- Player state reactions (OPTIMIZED: use cached state)
	local playerBlocking, playerRagdolled, playerHasHyperArmor = getPlayerState(target, now)

	-- If player is blocking, heavily prioritize guard breaks
	if playerBlocking and properties.IsGuardBreak then
		score = score * 3.0 -- Massive bonus for guard breaks when player is blocking
	elseif playerBlocking and not properties.IsGuardBreak then
		score = score * 0.3 -- Heavily penalize non-guard-break attacks when player is blocking
	end

	-- If player is ragdolled, prioritize combo extenders
	if playerRagdolled and properties.IsComboExtender then
		score = score * 2.5 -- Big bonus for combo extenders on ragdolled targets
	end

	-- If player has hyper armor, avoid weak attacks
	if playerHasHyperArmor then
		if properties.SkillPriority and properties.SkillPriority < 8 then
			score = score * 0.4 -- Penalize weak attacks against hyper armor
		end
	end

	-- Combo context
	if combatState.lastSkillUsed then
		local lastProps = CombatProperties[combatState.lastSkillUsed]
		if lastProps and lastProps.ComboProperties then
			-- If last skill was a combo starter, prefer combo enders
			if lastProps.ComboProperties.IsComboStarter and properties.ComboProperties and properties.ComboProperties.IsComboEnder then
				score = score * 1.8
			end
		end
	end

	return score
end

-- Main system function
local hasLoggedScoring = false

local function updateSkillScoring()
	local now = os.clock()

	local archetypes = combatNPCQuery:archetypes()

	for _, archetype in archetypes do
		local columns = archetype.columns_map
		local entities = archetype.entities

		local characters = columns[comps.Character]
		local targets = columns[comps.NPCTarget]
		local combatStates = columns[comps.NPCCombatState]
		local skillScorings = columns[comps.NPCSkillScoring]
		local healths = columns[comps.Health]
		local hitboxes = columns[comps.Hitbox]

		for row, entity in entities do
			local character = characters[row]
			local target = targets[row]
			local combatState = combatStates[row]
			local skillScoring = skillScorings[row]
			local health = healths[row]
			local hitbox = hitboxes[row]

			if not target or not target:IsDescendantOf(workspace) then
				continue
			end

			-- NETWORK OPTIMIZATION: Removed per-entity throttle since we're throttling the whole system now

			local distance = getDistanceToTarget(hitbox, target)

			local availableSkills = getAvailableSkills(character)

			local bestSkill = nil
			local bestScore = 0

			for _, skillName in availableSkills do
				local score = scoreSkill(skillName, distance, character, target, combatState, health, now)
				if score > bestScore then
					bestScore = score
					bestSkill = skillName
				end
			end

			-- NETWORK OPTIMIZATION: Only update component if skill actually changed
			-- This prevents redundant network replication
			if skillScoring.bestSkill ~= bestSkill or skillScoring.bestScore ~= bestScore then
				skillScoring.bestSkill = bestSkill
				skillScoring.bestScore = bestScore

				if character.Name:match("Guard") and bestSkill and not hasLoggedScoring then
					hasLoggedScoring = true
				end

				world:set(entity, comps.NPCSkillScoring, skillScoring)
			end
		end
	end
end

return {
	run = function(_world: Jecs.World, dt: number)
		-- NETWORK OPTIMIZATION: Throttle to 15 Hz
		scoringAcc += dt
		if scoringAcc >= SCORING_TICK then
			scoringAcc = 0
			updateSkillScoring()
		end
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}
