--!strict
--[[
    NPC Combat Execution System (ECS)
    
    Executes skills chosen by the skill scoring system.
    Handles:
    - M1 attacks (with spam prevention)
    - M2/Critical attacks
    - Weapon skills
    - Alchemy skills
    - Block activation
    - Global action cooldown (300ms between actions)
    
    Runs at ~30 Hz for responsive combat
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local Server = require(ServerScriptService.ServerConfig.Server)
local Library = Server.Library
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

-- Cache queries
local combatNPCQuery = world:query(comps.Character, comps.CombatNPC, comps.NPCTarget, comps.NPCCombatState, comps.NPCSkillScoring, comps.Combat)

-- Global action cooldown (300ms between actions)
local GLOBAL_ACTION_COOLDOWN = 0.3

-- Check if NPC can act (not stunned, knocked, etc.)
local function canAct(character: Model): boolean
	-- Check Stuns
	if StateManager.StateCount(character, "Stuns") then
		return false
	end
	
	-- Check if knocked
	if character:GetAttribute("Knocked") and character:GetAttribute("Knocked") > 0 then
		return false
	end
	
	-- Check if ragdolled
	if character:FindFirstChild("Ragdoll") then
		return false
	end
	
	-- Check if dead
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return false
	end
	
	return true
end

-- Execute M1 attack
local function executeM1(character: Model, combatState: any, combat: any): boolean
	-- Check if NPC is already in an M1 animation (prevent spam)
	if StateManager.StateCount(character, "Actions") then
		return false
	end
	
	-- Check M1 cooldown (prevent rapid M1 spam)
	local now = os.clock()
	if now - combatState.lastM1Time < 0.5 then
		return false
	end
	
	-- Execute M1
	if combat and combat.Light then
		combat.Light(character)
		combatState.lastM1Time = now
		return true
	end
	
	return false
end

-- Execute Critical/M2 attack
local function executeCritical(character: Model, combat: any): boolean
	if combat and combat.Critical then
		combat.Critical(character)
		return true
	end
	return false
end

-- Execute Block
local function executeBlock(character: Model, combat: any): boolean
	if combat and combat.HandleBlockInput then
		combat.HandleBlockInput(character, true)
		return true
	end
	return false
end

-- Execute weapon/alchemy skill
local function executeSkill(character: Model, skillName: string): boolean
	-- Get Actor and MainConfig
	local actor = character:FindFirstAncestorOfClass("Actor")
	if not actor then return false end
	
	local mainConfig = require(actor:FindFirstChild("MainConfig"))
	if not mainConfig or not mainConfig.performAction then
		return false
	end
	
	-- Execute skill
	return mainConfig.performAction(skillName)
end

-- Main system function
return function(dt: number)
	for entity, character, _, target, combatState, skillScoring, combat in combatNPCQuery do
		-- Skip if no target
		if not target or not target:IsDescendantOf(workspace) then
			continue
		end
		
		-- Skip if can't act
		if not canAct(character) then
			continue
		end
		
		-- Check global action cooldown
		local now = os.clock()
		if now - combatState.lastActionTime < GLOBAL_ACTION_COOLDOWN then
			continue
		end
		
		-- Skip if no skill chosen
		if not skillScoring.bestSkill or skillScoring.bestScore <= 0 then
			continue
		end
		
		-- Execute the best skill
		local success = false
		local skillName = skillScoring.bestSkill
		
		if skillName == "M1" then
			success = executeM1(character, combatState, combat)
		elseif skillName == "Critical" or skillName == "M2" then
			success = executeCritical(character, combat)
		elseif skillName == "Block" then
			success = executeBlock(character, combat)
		else
			success = executeSkill(character, skillName)
		end
		
		-- Update combat state if successful
		if success then
			combatState.lastActionTime = now
			combatState.lastAttackTime = now
			combatState.lastSkillUsed = skillName
			world:set(entity, comps.NPCCombatState, combatState)
		end
	end
end

