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

-- Cache queries
local combatNPCQuery = world:query(comps.Character, comps.CombatNPC, comps.NPCTarget, comps.NPCCombatState, comps.Hitbox, comps.Combat)

-- Defense cooldown
local DEFENSE_COOLDOWN = 0.5

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
	
	-- Release block after 0.5s
	task.delay(0.5, function()
		if character and character.Parent and mainConfig.InitiateBlock then
			-- Don't release if guard broken or stunned
			if not StateManager.StateCheck(character, "Stuns", "BlockBreakStun")
				and not StateManager.StateCheck(character, "Stuns", "GuardbreakStun") then
				mainConfig.InitiateBlock(false)
			end
		end
	end)
	
	return true
end

-- Execute dodge (LinearVelocity)
local function executeDodge(character: Model, hitbox: Part): boolean
	-- Get random dodge direction
	local dodgeDirections = {
		hitbox.CFrame.RightVector,
		-hitbox.CFrame.RightVector,
		-hitbox.CFrame.LookVector,
	}

	local dodgeVector = dodgeDirections[math.random(1, #dodgeDirections)]

	-- Add dodge IFrame
	StateManager.AddState(character, "IFrames", "Dodge")
	task.delay(0.5, function()
		StateManager.RemoveState(character, "IFrames", "Dodge")
	end)

	-- Clean up existing dodge velocities
	for _, bodyMover in hitbox:GetChildren() do
		if bodyMover.Name == "NPCDodge" then
			bodyMover:Destroy()
		end
	end

	-- Create LinearVelocity for dodge
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "NPCDodge"
	velocity.MaxAxesForce = Vector3.new(100000, 0, 100000)
	velocity.ForceLimitsEnabled = true
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.Attachment0 = hitbox:FindFirstChild("RootAttachment")
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = dodgeVector * 135 -- Match player dodge speed
	velocity.Parent = hitbox

	-- Destroy after 0.5s
	task.delay(0.5, function()
		if velocity and velocity.Parent then
			velocity:Destroy()
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
return function(dt: number)
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

		-- Execute defense
		local success = false
		if defenseType == "Parry" then
			success = executeParry(character, combatState, combat)
		elseif defenseType == "Block" then
			success = executeBlock(character, combat)
		elseif defenseType == "Dodge" then
			success = executeDodge(character, hitbox)
		end

		-- Update combat state if successful
		if success then
			combatState.lastDefenseTime = now
			combatState.lastActionTime = now
			world:set(entity, comps.NPCCombatState, combatState)
		end
	end
end

