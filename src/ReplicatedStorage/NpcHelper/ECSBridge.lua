--[[
    ECS Bridge for Behavior Trees
    
    This module allows behavior trees to interact with the ECS system.
    It provides functions to:
    - Set movement intent via Locomotion component
    - Override ECS AI when behavior tree is in control
    - Query ECS state
    
    Usage in behavior tree conditions:
        local ECSBridge = require(game.ReplicatedStorage.NpcHelper.ECSBridge)
        
        -- Set movement direction
        ECSBridge.setMovement(npcModel, direction, speed)
        
        -- Enable behavior tree override (disables ECS AI)
        ECSBridge.enableOverride(npcModel)
        
        -- Disable behavior tree override (re-enables ECS AI)
        ECSBridge.disableOverride(npcModel)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)

local ECSBridge = {}

--[[
    Set movement intent for an NPC
    
    @param npcModel: Model - The NPC character model
    @param direction: Vector3 - Movement direction (will be normalized)
    @param speed: number - Movement speed
]]
function ECSBridge.setMovement(npcModel: Model, direction: Vector3, speed: number)
    local entity = RefManager.entity.find(npcModel)
    if not entity then
        return
    end
    
    -- Only set locomotion if NPC has the component (combat NPCs)
    if not world:has(entity, comps.Locomotion) then
        return
    end
    
    -- Normalize direction
    local dir = direction
    if dir.Magnitude > 0.001 then
        dir = dir.Unit
    else
        dir = Vector3.zero
        speed = 0
    end
    
    world:set(entity, comps.Locomotion, {
        dir = dir,
        speed = speed
    })
end

--[[
    Enable behavior tree override
    This tells the ECS AI to skip this NPC
    
    @param npcModel: Model - The NPC character model
]]
function ECSBridge.enableOverride(npcModel: Model)
    local entity = RefManager.entity.find(npcModel)
    if not entity then
        return
    end
    
    world:add(entity, comps.BehaviorTreeOverride)
end

--[[
    Disable behavior tree override
    This allows the ECS AI to control this NPC again
    
    @param npcModel: Model - The NPC character model
]]
function ECSBridge.disableOverride(npcModel: Model)
    local entity = RefManager.entity.find(npcModel)
    if not entity then
        return
    end
    
    if world:has(entity, comps.BehaviorTreeOverride) then
        world:remove(entity, comps.BehaviorTreeOverride)
    end
end

--[[
    Check if NPC is a combat NPC (has ECS AI)

    @param npcModel: Model - The NPC character model
    @return boolean - True if combat NPC
]]
function ECSBridge.isCombatNPC(npcModel: Model): boolean
    local entity = RefManager.entity.find(npcModel)
    if not entity then
        return false
    end

    return world:has(entity, comps.CombatNPC)
end

--[[
    Check if NPC is a wanderer NPC (non-combat citizen)

    @param npcModel: Model - The NPC character model
    @return boolean - True if wanderer NPC
]]
function ECSBridge.isWandererNPC(npcModel: Model): boolean
    local entity = RefManager.entity.find(npcModel)
    if not entity then
        -- Fallback: check HRP attribute or name
        local hrp = npcModel:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:GetAttribute("IsWandererNPC") then
            return true
        end
        return npcModel.Name:lower():find("wanderer") ~= nil
    end

    return world:has(entity, comps.WandererNPC)
end

--[[
    Get current AI state
    
    @param npcModel: Model - The NPC character model
    @return string? - Current AI state ("wander", "chase", "flee", "circle", "idle")
]]
function ECSBridge.getAIState(npcModel: Model): string?
    local entity = RefManager.entity.find(npcModel)
    if not entity then
        return nil
    end
    
    if not world:has(entity, comps.AIState) then
        return nil
    end
    
    local aiState = world:get(entity, comps.AIState)
    return aiState.state
end

--[[
    Set AI state directly (for behavior tree control)
    
    @param npcModel: Model - The NPC character model
    @param state: string - New state ("wander", "chase", "flee", "circle", "idle")
]]
function ECSBridge.setAIState(npcModel: Model, state: string)
    local entity = RefManager.entity.find(npcModel)
    if not entity then
        return
    end
    
    if not world:has(entity, comps.AIState) then
        return
    end
    
    local aiState = world:get(entity, comps.AIState)
    aiState.state = state
    aiState.t = 0
    world:set(entity, comps.AIState, aiState)
end

return ECSBridge

