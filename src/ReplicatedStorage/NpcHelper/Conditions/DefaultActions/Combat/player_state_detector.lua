--[[
    Player State Detector
    
    Helper module for NPCs to detect what state the player is in.
    Used to make intelligent combat decisions based on player actions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

local PlayerStateDetector = {}

-- Check if player is blocking
function PlayerStateDetector.IsBlocking(target)
    if not target then return false end

    if StateManager.StateCheck(target, "Frames", "Blocking") then
        return true
    end

    return false
end

-- Check if player is ragdolled/knocked
function PlayerStateDetector.IsRagdolled(target)
    if not target then return false end
    
    -- Check for Ragdoll BoolValue
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
function PlayerStateDetector.HasHyperArmor(target)
    if not target then return false end

    -- Check for HyperarmorMove attribute (set when player uses hyper armor skill)
    local hyperarmorMove = target:GetAttribute("HyperarmorMove")
    if hyperarmorMove then
        return true
    end

    -- Check for HyperArmor state using ECS StateManager
    if StateManager.StateCheck(target, "Status", "HyperArmor") then
        return true
    end

    return false
end

-- Check if player is attacking
function PlayerStateDetector.IsAttacking(target)
    if not target then return false end

    -- Use ECS StateManager to check if any actions are present
    local allActions = StateManager.GetAllStates(target, "Actions")
    return #allActions > 0
end

-- Get the current action the player is performing
function PlayerStateDetector.GetCurrentAction(target)
    if not target then return nil end

    -- Use ECS StateManager to get all actions
    local allActions = StateManager.GetAllStates(target, "Actions")
    -- Return the first action found (most recent)
    return allActions[1]
end

-- Check if player is stunned
function PlayerStateDetector.IsStunned(target)
    if not target then return false end

    if StateManager.StateCount(target, "Stuns") then
        return true
    end

    return false
end

-- Check if player is in iframes
function PlayerStateDetector.HasIFrames(target)
    if not target then return false end

    if StateManager.StateCount(target, "IFrames") then
        return true
    end

    return false
end

return PlayerStateDetector

