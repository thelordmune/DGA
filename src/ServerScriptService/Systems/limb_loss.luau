--!strict
--[[
    Limb Loss System

    Handles:
    1. Damage/speed debuffs based on missing limbs
    2. Bleeding damage tick
    3. Animation speed modifiers

    Missing Arms:
    - 25% less damage per missing arm (multiplicative)
    - 15% slower attack animations per missing arm

    Missing Legs:
    - 30% slower movement per missing leg (multiplicative)

    Bleeding:
    - 1.5 HP/sec per missing limb (stacks)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local EntityCleanup = require(ReplicatedStorage.Modules.ECS.entity_cleanup)
local LimbManager = require(ReplicatedStorage.Modules.Utils.LimbManager)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local Global = require(ReplicatedStorage.Modules.Shared.Global)
local Visuals = require(ReplicatedStorage.Modules.Visuals)

-- Configuration
local BLEED_TICK_RATE = 1 -- seconds between bleed ticks

-- Track last bleed tick per entity
local lastBleedTick: {[number]: number} = {}

-- PERFORMANCE: Cache query for reuse
local limbLossQuery = world:query(comps.LimbState, comps.Character):cached()

local function limbLoss(_world, dt: number)
    -- Only run on server
    if RunService:IsClient() then
        return
    end

    local currentTime = os.clock()

    -- Query all entities with LimbState and Character components (using cached query)
    for entity, limbState, character in limbLossQuery do
        local model = character
        if not model or not model.Parent then continue end

        local humanoid = model:FindFirstChild("Humanoid")
        if not humanoid then continue end

        -- Count missing limbs
        local missingArms, missingLegs = LimbManager.CountMissingLimbs(limbState)

        -- Apply walk speed debuff for missing legs using ECS StateManager
        if missingLegs > 0 then
            local speedMultiplier = LimbManager.Debuffs.leg.walkSpeedMultiplier ^ missingLegs
            -- Use StateManager.TimedState to manage the speed modifier
            -- Set a long duration since this is permanent until healed
            if not StateManager.StateCheck(model, "Speeds", "LimbSpeedDebuff") then
                StateManager.TimedState(model, "Speeds", "LimbSpeedDebuff", 999999)
            end
            -- Store the multiplier as an attribute for the speed system to read
            model:SetAttribute("LimbSpeedMultiplier", speedMultiplier)
        else
            -- Remove speed debuff if legs are restored
            StateManager.RemoveState(model, "Speeds", "LimbSpeedDebuff")
            model:SetAttribute("LimbSpeedMultiplier", nil)
        end

        -- Store damage multiplier as attribute (used by Damage.lua)
        if missingArms > 0 then
            local damageMultiplier = LimbManager.Debuffs.arm.damageMultiplier ^ missingArms
            model:SetAttribute("LimbDamageMultiplier", damageMultiplier)

            -- Animation speed modifier stored as attribute
            local animSpeedMultiplier = LimbManager.Debuffs.arm.attackSpeedMultiplier ^ missingArms
            model:SetAttribute("LimbAnimSpeedMultiplier", animSpeedMultiplier)
        else
            model:SetAttribute("LimbDamageMultiplier", nil)
            model:SetAttribute("LimbAnimSpeedMultiplier", nil)
        end

        -- Bleeding damage tick
        if limbState.bleedingStacks > 0 then
            local lastTick = lastBleedTick[entity] or 0

            if currentTime - lastTick >= BLEED_TICK_RATE then
                lastBleedTick[entity] = currentTime

                -- Deal bleeding damage
                local bleedDamage = LimbManager.Debuffs.bleeding.damagePerSecond * limbState.bleedingStacks
                humanoid.Health = humanoid.Health - bleedDamage

                -- Update ECS Health component if it exists (in-place mutation)
                local health = world:get(entity, comps.Health)
                if health then
                    health.current = humanoid.Health
                    -- PERFORMANCE: Component is mutated in-place, world:set() is unnecessary
                end
            end
        else
            -- Clear bleed tick tracking if no bleeding
            lastBleedTick[entity] = nil
        end
    end
end

-- Helper function to restore all limbs (called by Doctor NPC or healing)
local function restoreAllLimbs(entity: number): boolean
    local character = world:get(entity, comps.Character)
    local limbState = world:get(entity, comps.LimbState)
    local player = world:get(entity, comps.Player)

    if not character or not limbState then
        return false
    end

    -- Check if any limbs need restoring
    local hadMissingLimbs = LimbManager.HasMissingLimbs(limbState)
    if not hadMissingLimbs then
        return false -- No limbs to restore
    end

    -- Restore each missing limb
    local limbsRestored = 0
    for limbName, isAttached in pairs(limbState) do
        if limbName ~= "bleedingStacks" and not isAttached then
            local success = LimbManager.RestoreLimb(character, limbName)
            if success then
                limbsRestored = limbsRestored + 1
                print(`[LimbLoss] Restored {limbName} for {character.Name}`)
            end
        end
    end

    -- Reset limb state to default
    local newLimbState = LimbManager.GetDefaultLimbState()
    world:set(entity, comps.LimbState, newLimbState)

    -- Clear bleed tracking
    lastBleedTick[entity] = nil

    -- Clear debuff attributes
    character:SetAttribute("LimbDamageMultiplier", nil)
    character:SetAttribute("LimbAnimSpeedMultiplier", nil)
    character:SetAttribute("LimbSpeedMultiplier", nil)

    -- Remove speed debuff state
    StateManager.RemoveState(character, "Speeds", "LimbSpeedDebuff")

    -- Remove bleeding visual effect
    Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
        Module = "Misc",
        Function = "DisableStatus",
        Arguments = { character, "Bleeding" },
    })

    -- Save to player data (persistence)
    if player then
        Global.SetData(player, function(data)
            data.LimbState = newLimbState
            return data
        end)
        print(`[LimbLoss] Saved restored limb state for {player.Name}`)
    end

    return limbsRestored > 0
end

-- Helper function to restore a specific limb
local function restoreLimb(entity: number, limbName: string): boolean
    local character = world:get(entity, comps.Character)
    local limbState = world:get(entity, comps.LimbState)
    local player = world:get(entity, comps.Player)

    if not character or not limbState then
        return false
    end

    -- Check if limb is actually missing
    if LimbManager.IsLimbAttached(limbState, limbName) then
        return false -- Already attached
    end

    -- Restore the limb
    local success = LimbManager.RestoreLimb(character, limbName)
    if not success then
        return false
    end

    -- Update limb state
    if limbName == "LeftArm" then limbState.leftArm = true
    elseif limbName == "RightArm" then limbState.rightArm = true
    elseif limbName == "LeftLeg" then limbState.leftLeg = true
    elseif limbName == "RightLeg" then limbState.rightLeg = true
    end

    -- Reduce bleeding stacks
    limbState.bleedingStacks = math.max(0, limbState.bleedingStacks - 1)
    world:set(entity, comps.LimbState, limbState)

    -- If no more bleeding stacks, remove bleeding visual
    if limbState.bleedingStacks == 0 then
        Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
            Module = "Misc",
            Function = "DisableStatus",
            Arguments = { character, "Bleeding" },
        })
    end

    -- Save to player data (persistence)
    if player then
        Global.SetData(player, function(data)
            data.LimbState = limbState
            return data
        end)
        print(`[LimbLoss] Saved limb state after restoring {limbName} for {player.Name}`)
    end

    print(`[LimbLoss] Restored {limbName} for {character.Name}`)
    return true
end

-- Cleanup when entity is removed
local function cleanup(entity: number)
    lastBleedTick[entity] = nil
end

-- Register cleanup callback for centralized entity cleanup
EntityCleanup.register("limb_loss", cleanup)

-- Export module with helper functions
local LimbLossModule = {
    run = limbLoss,
    settings = {
        server_only = true,
        phase = "Heartbeat",
        priority = 50,
    },
    -- Public API for healing systems
    restoreAllLimbs = restoreAllLimbs,
    restoreLimb = restoreLimb,
    cleanup = cleanup,
}

return LimbLossModule
