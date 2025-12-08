--!strict
--[[
    NPC Smart Defense System (ECS)
    
    Analyzes what the player is doing and reacts appropriately:
    - Parry: Quick attacks (M1 combos, fast skills) - 40% parry, 45% block, 15% no defense
    - Block: Heavy attacks (M2, Critical, heavy skills) - 60% block, 25% parry, 15% no defense
    - Dodge: AOE attacks, unblockable attacks - 70% dodge
    
    Runs at ~30 Hz for responsive defense
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

-- NETWORK OPTIMIZATION: Throttle to 20 Hz instead of 60 Hz
-- Defense reactions don't need frame-perfect precision
local DEFENSE_HZ = 20
local DEFENSE_TICK = 1 / DEFENSE_HZ
local defenseAcc = 0

-- Cache queries (OPTIMIZED: added :cached())
local combatNPCQuery = world:query(comps.Character, comps.CombatNPC, comps.NPCTarget, comps.NPCCombatState, comps.Hitbox, comps.Combat):cached()

-- Defense cooldown (INCREASED from 0.5 to 1.0 to reduce defensive spam)
local DEFENSE_COOLDOWN = 1.0

-- Dodge skills (AOE attacks)
local DODGE_SKILLS = {
	"Firestorm", "Cascade", "Grand Cleave", "Strategist Combination",
	"Ground Decay", "Branch", "Dempsey Roll",
}

-- Block skills (heavy single-target attacks)
local BLOCK_SKILLS = {
	"Needle Thrust", "Shell Piercer", "Downslam Kick", "Axe Kick",
	"Pincer Impact", "Gazelle Punch", "Stone Lance", "Rock Skewer", "Cinder",
}

-- Parry skills (fast attacks)
local PARRY_SKILLS = {
	"Jab Rush", "Rising Wind", "Deconstruct", "AlchemicAssault",
}

-- Determine best defense based on player action
local function getBestDefense(playerAction: string?, distance: number): string?
	if not playerAction then return nil end
	
	-- M1 attacks - prefer parrying
	if string.match(playerAction, "^M1") then
		if distance < 12 then
			local roll = math.random()
			if roll < 0.40 then return "Parry"
			elseif roll < 0.85 then return "Block"
			else return nil end
		end
		return nil
	end
	
	-- M2 attacks - prefer blocking
	if playerAction == "M2" then
		if distance < 14 then
			local roll = math.random()
			if roll < 0.60 then return "Block"
			elseif roll < 0.85 then return "Parry"
			else return nil end
		end
		return nil
	end
	
	-- Running attacks - prefer parrying
	if playerAction == "RunningAttack" then
		if distance < 12 then
			local roll = math.random()
			if roll < 0.50 then return "Parry"
			elseif roll < 0.85 then return "Block"
			else return nil end
		end
		return nil
	end
	
	-- Dodge AOE skills
	for _, skill in DODGE_SKILLS do
		if playerAction == skill then
			if distance < 18 and math.random() < 0.7 then
				return "Dodge"
			end
			return nil
		end
	end
	
	-- Block heavy skills
	for _, skill in BLOCK_SKILLS do
		if playerAction == skill then
			if distance < 14 then
				local roll = math.random()
				if roll < 0.60 then return "Block"
				elseif roll < 0.80 then return "Parry"
				else return nil end
			end
			return nil
		end
	end
	
	-- Parry fast skills
	for _, skill in PARRY_SKILLS do
		if playerAction == skill then
			if distance < 12 then
				local roll = math.random()
				if roll < 0.50 then return "Parry"
				elseif roll < 0.80 then return "Block"
				else return nil end
			end
			return nil
		end
	end
	
	return nil
end

-- Execute parry
local function executeParry(character: Model, combatState: any, combat: any): boolean
	if not combat or not combat.AttemptParry then return false end
	
	combat.AttemptParry(character)
	combatState.justParried = true
	combatState.parryTime = os.clock()
	
	return true
end

-- Execute block (hold for 0.5s)
local function executeBlock(character: Model, combat: any): boolean
	-- Get Actor and MainConfig
	local actor = character:FindFirstAncestorOfClass("Actor")
	if not actor then return false end

	local mainConfig = require(actor:FindFirstChild("MainConfig"))
	if not mainConfig or not mainConfig.InitiateBlock then
		return false
	end

	mainConfig.InitiateBlock(true)

	-- Release block after 0.2s (REDUCED from 0.5s for more aggressive play)
	task.delay(0.2, function()
		if character and character.Parent and mainConfig.InitiateBlock then
			-- Don't release if guard broken or stunned
			if not StateManager.StateCheck(character, "Stuns", "BlockBreakStun")
				and not StateManager.StateCheck(character, "Stuns", "GuardbreakStun") then
				mainConfig.InitiateBlock(false)
			end
		end
	end)

	-- FIXED: Failsafe - force release after 0.8s to prevent getting stuck (REDUCED from 1.5s)
	task.delay(0.8, function()
		if character and character.Parent and mainConfig.InitiateBlock then
			mainConfig.InitiateBlock(false)
		end
	end)

	return true
end

-- Execute dodge/dash (IMPROVED: Uses locomotion for proper dash mechanic)
local function executeDodge(entity: number, character: Model, hitbox: Part, loco: any): boolean
	-- Get random dodge direction
	local dodgeDirections = {
		hitbox.CFrame.RightVector,
		-hitbox.CFrame.RightVector,
		-hitbox.CFrame.LookVector,
	}

	local dodgeVector = dodgeDirections[math.random(1, #dodgeDirections)]

	-- Add dodge IFrame
	StateManager.AddState(character, "IFrames", "Dodge")
	task.delay(0.4, function()
		StateManager.RemoveState(character, "IFrames", "Dodge")
	end)

	-- IMPROVED: Set dash component to trigger animation
	world:set(entity, comps.Dashing, true)

	-- IMPROVED: Use locomotion system for dash (brief speed boost)
	local dashSpeed = 60 -- Fast dash speed
	world:set(entity, comps.Locomotion, {
		dir = dodgeVector.Unit,
		speed = dashSpeed
	})

	-- Play dash animation using Library (same as behavior tree dash.lua)
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		local dashAnimations = ReplicatedStorage.Assets.Animations.Dashes
		if dashAnimations then
			-- Determine direction based on dodgeVector
			local animationName = "Forward" -- Default
			local lookVector = hitbox.CFrame.LookVector
			local rightVector = hitbox.CFrame.RightVector

			-- Check if going backward
			if dodgeVector:Dot(lookVector) < -0.5 then
				animationName = "Back"
			-- Check if going left
			elseif dodgeVector:Dot(rightVector) < -0.5 then
				animationName = "Left"
			-- Check if going right
			elseif dodgeVector:Dot(rightVector) > 0.5 then
				animationName = "Right"
			end

			local dashAnim = dashAnimations:FindFirstChild(animationName)
			if dashAnim then
				Library.StopMovementAnimations(character)
				local dashTrack = Library.PlayAnimation(character, dashAnim, 0.05)
				if dashTrack then
					dashTrack.Priority = Enum.AnimationPriority.Action
				end
			end
		end
	end

	-- Reset dash after 0.4s
	task.delay(0.4, function()
		if character and character.Parent then
			world:set(entity, comps.Dashing, false)
		end
	end)

	return true
end

-- Check if NPC can defend
local function canDefend(character: Model): boolean
	-- Can't defend if stunned
	if StateManager.StateCount(character, "Stuns") then
		return false
	end

	-- Can't defend if knocked
	if character:GetAttribute("Knocked") and character:GetAttribute("Knocked") > 0 then
		return false
	end

	-- Can't defend if ragdolled
	if character:FindFirstChild("Ragdoll") then
		return false
	end

	return true
end

-- Main system function
local function updateDefense()
	for entity, character, _, target, combatState, hitbox, combat in combatNPCQuery do
		-- Skip if no target
		if not target or not target:IsDescendantOf(workspace) then
			continue
		end

		-- Skip if can't defend
		if not canDefend(character) then
			continue
		end

		-- Check defense cooldown
		local now = os.clock()
		if now - combatState.lastDefenseTime < DEFENSE_COOLDOWN then
			continue
		end

		-- Get distance to target
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if not targetRoot then continue end
		local distance = (targetRoot.Position - hitbox.Position).Magnitude

		-- Get player action
		local playerAction = PlayerStateDetector.GetCurrentAction(target)
		if not playerAction then continue end

		-- Determine best defense
		local defenseType = getBestDefense(playerAction, distance)
		if not defenseType then continue end

		-- Get locomotion component for dash
		local loco = world:get(entity, comps.Locomotion)

		-- Execute defense
		local success = false
		if defenseType == "Parry" then
			success = executeParry(character, combatState, combat)
		elseif defenseType == "Block" then
			success = executeBlock(character, combat)
		elseif defenseType == "Dodge" then
			success = executeDodge(entity, character, hitbox, loco)
		end

		-- Update combat state if successful
		if success then
			combatState.lastDefenseTime = now
			combatState.lastActionTime = now
			world:set(entity, comps.NPCCombatState, combatState)
		end
	end
end

return {
	run = function(_world: Jecs.World, dt: number)
		-- NETWORK OPTIMIZATION: Throttle to 20 Hz
		defenseAcc += dt
		if defenseAcc >= DEFENSE_TICK then
			defenseAcc = 0
			updateDefense()
		end
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}


