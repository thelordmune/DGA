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
local PlayerStateDetector = require(ReplicatedStorage.Modules.ECS.PlayerStateDetector_ECS)

-- Cache queries
local combatNPCQuery = world:query(comps.Character, comps.CombatNPC, comps.NPCTarget, comps.NPCCombatState, comps.NPCSkillScoring, comps.Health, comps.Hitbox, comps.Combat)

-- Get distance to target
local function getDistanceToTarget(npcRoot: Part, target: Model): number
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return 999 end
	return (targetRoot.Position - npcRoot.Position).Magnitude
end

-- Get available skills for NPC
local function getAvailableSkills(npc: Model): {string}
	local skills = {"M1", "Critical", "Block"}
	
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

-- Score a skill based on combat properties and context
local function scoreSkill(
	skillName: string,
	distance: number,
	npc: Model,
	target: Model,
	combatState: any,
	health: any
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
				SkillPriority = 3,
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
	
	-- Low health = prefer defensive skills
	local healthPercent = health.current / (health.max or 100)
	if healthPercent < 0.3 then
		if properties.SkillType == "Defensive" then
			score = score * 2.0
		elseif properties.SkillType == "Offensive" then
			score = score * 0.5
		end
	end

	-- Player state reactions
	local playerBlocking = PlayerStateDetector.IsBlocking(target)
	local playerRagdolled = PlayerStateDetector.IsRagdolled(target)
	local playerHasHyperArmor = PlayerStateDetector.HasHyperArmor(target)

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
return function(dt: number)
	for entity, character, _, target, combatState, skillScoring, health, hitbox, combat in combatNPCQuery do
		-- Skip if no target
		if not target or not target:IsDescendantOf(workspace) then
			continue
		end
		
		-- Throttle scoring to ~15 Hz
		local now = os.clock()
		if now - skillScoring.lastScoringTime < 0.067 then
			continue
		end
		skillScoring.lastScoringTime = now
		
		-- Get distance
		local distance = getDistanceToTarget(hitbox, target)
		
		-- Get available skills
		local availableSkills = getAvailableSkills(character)
		
		-- Score all skills
		local bestSkill = nil
		local bestScore = 0
		
		for _, skillName in availableSkills do
			local score = scoreSkill(skillName, distance, character, target, combatState, health)
			if score > bestScore then
				bestScore = score
				bestSkill = skillName
			end
		end
		
		-- Update skill scoring component
		skillScoring.bestSkill = bestSkill
		skillScoring.bestScore = bestScore

		-- Update combat state with last skill used (will be set by execution system)
		world:set(entity, comps.NPCSkillScoring, skillScoring)
	end
end

