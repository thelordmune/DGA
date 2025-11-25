--[[
    Player State Detector
    
    Helper module for NPCs to detect what state the player is in.
    Used to make intelligent combat decisions based on player actions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage.Modules.Library)

local PlayerStateDetector = {}

-- Check if player is blocking
function PlayerStateDetector.IsBlocking(target)
    if not target then return false end
    
    local frames = target:FindFirstChild("Frames")
    if frames and Library.StateCheck(frames, "Blocking") then
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
    
    -- Check for HyperArmor state in Status folder
    local status = target:FindFirstChild("States")
    if status then
        status = status:FindFirstChild("Status")
        if status and status:FindFirstChild("HyperArmor") then
            return true
        end
    end
    
    return false
end

-- Check if player is attacking
function PlayerStateDetector.IsAttacking(target)
    if not target then return false end
    
    local actions = target:FindFirstChild("Actions")
    if not actions or not actions:IsA("StringValue") then
        return false
    end
    
    -- Decode the actions JSON
    local success, decodedActions = pcall(function()
        return game:GetService("HttpService"):JSONDecode(actions.Value)
    end)
    
    if not success or type(decodedActions) ~= "table" then
        return false
    end
    
    -- Check if any action is present (means player is doing something)
    return #decodedActions > 0
end

-- Get the current action the player is performing
function PlayerStateDetector.GetCurrentAction(target)
    if not target then return nil end
    
    local actions = target:FindFirstChild("Actions")
    if not actions or not actions:IsA("StringValue") then
        return nil
    end
    
    -- Decode the actions JSON
    local success, decodedActions = pcall(function()
        return game:GetService("HttpService"):JSONDecode(actions.Value)
    end)
    
    if not success or type(decodedActions) ~= "table" then
        return nil
    end
    
    -- Return the first action found (most recent)
    return decodedActions[1]
end

-- Check if player is stunned
function PlayerStateDetector.IsStunned(target)
    if not target then return false end
    
    local stuns = target:FindFirstChild("Stuns")
    if stuns and Library.StateCount(stuns) then
        return true
    end
    
    return false
end

-- Check if player is in iframes
function PlayerStateDetector.HasIFrames(target)
    if not target then return false end
    
    local iframes = target:FindFirstChild("IFrames")
    if iframes and Library.StateCount(iframes) then
        return true
    end
    
    return false
end

return PlayerStateDetector

