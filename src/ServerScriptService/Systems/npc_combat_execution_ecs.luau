--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local Server = require(ServerScriptService.ServerConfig.Server)
local Library = Server.Library
local Combat = Server.Modules.Combat
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)


-- OPTIMIZED: Cache query for better performance
local combatNPCQuery = world:query(comps.Character, comps.CombatNPC, comps.NPCTarget, comps.NPCCombatState, comps.NPCSkillScoring, comps.Combat):cached()

-- NETWORK OPTIMIZATION: Throttle to 20 Hz instead of 60 Hz
-- Combat execution doesn't need frame-perfect precision
local EXECUTION_HZ = 20
local EXECUTION_TICK = 1 / EXECUTION_HZ
local executionAcc = 0

local GLOBAL_ACTION_COOLDOWN = 0.3


local function canAct(character: Model): boolean
	-- Check StateStuns component (used by damage system)
	if StateManager.StateCount(character, "Stuns") then
		return false
	end

	-- Check if in any action state
	if StateManager.StateCount(character, "Actions") then
		return false
	end

	-- Check knocked attribute
	if character:GetAttribute("Knocked") and character:GetAttribute("Knocked") > 0 then
		return false
	end

	-- Check ragdoll
	if character:FindFirstChild("Ragdoll") then
		return false
	end

	-- Check health
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return false
	end

	return true
end


local function executeM1(character: Model, combatState: any): boolean
	if StateManager.StateCount(character, "Actions") then
		return false
	end

	local now = os.clock()
	if now - combatState.lastM1Time < 0.5 then
		return false
	end

	-- Use Server.Modules.Combat (not the ECS Combat component)
	Combat.Light(character)
	combatState.lastM1Time = now
	return true
end


local function executeCritical(character: Model): boolean
	-- Use Server.Modules.Combat (not the ECS Combat component)
	Combat.Critical(character)
	return true
end


local function executeBlock(character: Model): boolean
	-- Use Server.Modules.Combat (not the ECS Combat component)
	Combat.HandleBlockInput(character, true)
	return true
end


local function executeSkill(character: Model, skillName: string): boolean

	local actor = character:FindFirstAncestorOfClass("Actor")
	if not actor then return false end
	
	local mainConfig = require(actor:FindFirstChild("MainConfig"))
	if not mainConfig or not mainConfig.performAction then
		return false
	end
	

	return mainConfig.performAction(skillName)
end


-- ARCHETYPE OPTIMIZATION: Batch process for better performance
local function updateCombatExecution()
	local now = os.clock()

	-- Get archetypes for batch processing
	local archetypes = combatNPCQuery:archetypes()

	for _, archetype in archetypes do
		local columns = archetype.columns_map
		local entities = archetype.entities

		-- Direct column access
		local characters = columns[comps.Character]
		local targets = columns[comps.NPCTarget]
		local combatStates = columns[comps.NPCCombatState]
		local skillScorings = columns[comps.NPCSkillScoring]

		-- Process all entities in this archetype
		for row, entity in entities do
			local character = characters[row]
			local target = targets[row]
			local combatState = combatStates[row]
			local skillScoring = skillScorings[row]

			if not target or not target:IsDescendantOf(workspace) then
				continue
			end

			if not canAct(character) then
				continue
			end

			if now - combatState.lastActionTime < GLOBAL_ACTION_COOLDOWN then
				continue
			end

			if not skillScoring.bestSkill or skillScoring.bestScore <= 0 then
				continue
			end

			local success = false
			local skillName = skillScoring.bestSkill

			-- Debug: Log for guards (only once)
			if character.Name:match("Guard") then
				print(`[npc_combat_execution_ecs] {character.Name} executing {skillName}`)
			end

			if skillName == "M1" then
				success = executeM1(character, combatState)
			elseif skillName == "Critical" or skillName == "M2" then
				success = executeCritical(character)
			elseif skillName == "Block" then
				success = executeBlock(character)
			else
				success = executeSkill(character, skillName)
			end

			if success then
				combatState.lastActionTime = now
				combatState.lastAttackTime = now
				combatState.lastSkillUsed = skillName
				world:set(entity, comps.NPCCombatState, combatState)
			end
		end
	end
end

return {
	run = function(_world: Jecs.World, dt: number)
		-- NETWORK OPTIMIZATION: Throttle to 20 Hz
		executionAcc += dt
		if executionAcc >= EXECUTION_TICK then
			executionAcc = 0
			updateCombatExecution()
		end
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}
