--!strict
--[[
    Player State Detector (ECS Version)
    
    Helper module for NPCs to detect what state the player is in using ECS components.
    Used to make intelligent combat decisions based on player actions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

local PlayerStateDetector = {}

-- Check if player is blocking
function PlayerStateDetector.IsBlocking(target: Model): boolean
	if not target then return false end
	return StateManager.StateCheck(target, "Frames", "Blocking")
end

-- Check if player is ragdolled/knocked
function PlayerStateDetector.IsRagdolled(target: Model): boolean
	if not target then return false end
	
	-- Check for Ragdoll BoolValue (legacy)
	if target:FindFirstChild("Ragdoll") then
		return true
	end
	
	-- Check for Knocked attribute
	if target:GetAttribute("Knocked") and target:GetAttribute("Knocked") > 0 then
		return true
	end
	
	-- Check for Unconscious attribute
	if target:GetAttribute("Unconscious") and target:GetAttribute("Unconscious") > 0 then
		return true
	end
	
	return false
end

-- Check if player is using a move with hyper armor
function PlayerStateDetector.HasHyperArmor(target: Model): boolean
	if not target then return false end
	
	-- Check for HyperarmorMove attribute
	local hyperarmorMove = target:GetAttribute("HyperarmorMove")
	if hyperarmorMove then
		return true
	end
	
	-- Check for HyperArmor state in Status
	return StateManager.StateCheck(target, "Status", "HyperArmor")
end

-- Check if player is attacking
function PlayerStateDetector.IsAttacking(target: Model): boolean
	if not target then return false end
	return StateManager.StateCount(target, "Actions")
end

-- Get the current action the player is performing
function PlayerStateDetector.GetCurrentAction(target: Model): string?
	if not target then return nil end
	
	local actions = StateManager.GetAllStates(target, "Actions")
	if #actions > 0 then
		return actions[1] -- Return first action
	end
	
	return nil
end

-- Check if player is stunned
function PlayerStateDetector.IsStunned(target: Model): boolean
	if not target then return false end
	return StateManager.StateCount(target, "Stuns")
end

-- Check if player is in iframes
function PlayerStateDetector.HasIFrames(target: Model): boolean
	if not target then return false end
	return StateManager.StateCount(target, "IFrames")
end

-- Check if player is dashing
function PlayerStateDetector.IsDashing(target: Model): boolean
	if not target then return false end
	
	local entity = RefManager.ref(target)
	if not entity then return false end

	-- Dashing is now a tag - just check if entity has it
	return world:has(entity, comps.Dashing)
end

-- Check if player is sprinting
function PlayerStateDetector.IsSprinting(target: Model): boolean
	if not target then return false end
	
	local entity = RefManager.ref(target)
	if not entity then return false end
	
	if world:has(entity, comps.Sprinting) then
		local sprintData = world:get(entity, comps.Sprinting)
		return sprintData and sprintData.value == true
	end
	
	return false
end

-- Get player's current health percentage
function PlayerStateDetector.GetHealthPercent(target: Model): number
	if not target then return 1.0 end
	
	local entity = RefManager.ref(target)
	if not entity then return 1.0 end
	
	if world:has(entity, comps.Health) then
		local health = world:get(entity, comps.Health)
		local max = health.max or 100
		return health.current / max
	end
	
	return 1.0
end

return PlayerStateDetector

