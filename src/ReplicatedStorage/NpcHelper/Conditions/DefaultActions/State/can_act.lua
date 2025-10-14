--[[
    Check if NPC can perform actions (not stunned, not in certain states)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage.Modules.Library)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

return function(actor: Actor, mainConfig: table)
    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        return false
    end

    -- Check if NPC is dashing by querying the world for the entity with this NPC's Character component
    for entity in world:query(comps.Character) do
        local character = world:get(entity, comps.Character)
        if character == npc then
            -- Found the entity for this NPC
            if world:has(entity, comps.Dashing) then
                local isDashing = world:get(entity, comps.Dashing)
                if isDashing then
                    -- print("NPC", npc.Name, "is dashing, cannot act")
                    return false
                end
            end
            break
        end
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

