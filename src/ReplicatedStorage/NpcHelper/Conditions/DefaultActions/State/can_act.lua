--[[
    Check if NPC can perform actions (not stunned, not in certain states)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage.Modules.Library)

return function(actor: Actor, mainConfig: table)
    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        return false
    end

    -- Check if NPC is stunned
    local stuns = npc:FindFirstChild("Stuns")
    if stuns and Library.StateCount(stuns) then
        -- print("NPC", npc.Name, "is stunned, cannot act")
        return false
    end

    -- Check if NPC is in certain action states that prevent other actions
    local actions = npc:FindFirstChild("Actions")
    if actions then
        -- Check for states that prevent actions
        if Library.StateCheck(actions, "Attacking") then
            -- print("NPC", npc.Name, "is already attacking")
            return false
        end
        
        if Library.StateCheck(actions, "BlockBreak") then
            -- print("NPC", npc.Name, "is block broken")
            return false
        end
    end

    return true
end

