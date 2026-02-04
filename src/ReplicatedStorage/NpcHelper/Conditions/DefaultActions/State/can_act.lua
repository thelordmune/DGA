--[[
    Check if NPC can perform actions (not stunned, not in certain states)
    This is the central function for NPC action validation - all stun checks should go here
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)

return function(actor: Actor, mainConfig: table)
    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        return false
    end

    -- OPTIMIZATION: Use RefManager for O(1) entity lookup instead of O(n) query iteration
    local entity = RefManager.getEntityFromModel(npc)
    if entity then
        -- Check ECS Dead tag
        if world:has(entity, comps.Dead) then
            return false
        end

        -- Check ECS Stun component
        local stun = world:get(entity, comps.Stun)
        if stun and stun.value then
            return false
        end

        -- Check ECS Knocked component
        local knocked = world:get(entity, comps.Knocked)
        if knocked and knocked.value then
            return false
        end

        -- Check ECS Ragdoll component
        local ragdoll = world:get(entity, comps.Ragdoll)
        if ragdoll and ragdoll.value then
            return false
        end

        -- Check ECS CantMove component
        local cantMove = world:get(entity, comps.CantMove)
        if cantMove and cantMove.value then
            return false
        end

        -- Check if NPC is dashing (Dashing is now a tag)
        if world:has(entity, comps.Dashing) then
            return false
        end
    end

    -- Check if NPC is stunned or knocked back using ECS StateManager
    if StateManager.StateCount(npc, "Stuns") then
        return false
    end

    -- Specifically check for parry knockback
    if StateManager.StateCheck(npc, "Stuns", "ParryKnockback") then
        return false
    end

    -- Check M1Stun (true hitstun)
    if StateManager.StateCheck(npc, "Stuns", "M1Stun") then
        return false
    end

    -- Check BlockBreakStun
    if StateManager.StateCheck(npc, "Stuns", "BlockBreakStun") then
        return false
    end

    -- Check Knockback states
    if StateManager.StateCheck(npc, "Stuns", "Knockback") then
        return false
    end

    if StateManager.StateCheck(npc, "Stuns", "KnockbackRoll") then
        return false
    end

    -- Check if NPC is in certain action states that prevent other actions
    -- Check for states that prevent actions
    if StateManager.StateCheck(npc, "Actions", "Attacking") then
        return false
    end

    if StateManager.StateCheck(npc, "Actions", "BlockBreak") then
        return false
    end

    -- Check for M1 combo states (M1, M2, M3, M4, etc.)
    for i = 1, 10 do
        if StateManager.StateCheck(npc, "Actions", "M1" .. i) then
            return false
        end
    end

    -- Check for M2 (critical) action
    if StateManager.StateCheck(npc, "Actions", "M2") then
        return false
    end

    -- Check for running attack
    if StateManager.StateCheck(npc, "Actions", "RunningAttack") then
        return false
    end

    return true
end
