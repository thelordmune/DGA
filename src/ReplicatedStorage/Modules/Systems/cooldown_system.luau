--[[
    Cooldown System (ECS-Driven)

    Manages ability cooldowns via ECS components instead of StringValue objects.

    Benefits:
    - No Instance creation/destruction overhead
    - O(1) cooldown checks instead of GetChildren() polling
    - Works on both client and server
    - Automatic cleanup with entity deletion
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

local CooldownSystem = {}

-- Start a cooldown for an ability
function CooldownSystem.startCooldown(entity: number, abilityName: string, duration: number)
    local cooldowns = world:get(entity, comps.Cooldowns)
    if not cooldowns then
        cooldowns = {}
    end

    cooldowns[abilityName] = os.clock() + duration
    world:set(entity, comps.Cooldowns, cooldowns)
end

-- Check if an ability is on cooldown
function CooldownSystem.isOnCooldown(entity: number, abilityName: string): boolean
    local cooldowns = world:get(entity, comps.Cooldowns)
    if not cooldowns or not cooldowns[abilityName] then
        return false
    end

    return os.clock() < cooldowns[abilityName]
end

-- Get remaining cooldown time (returns 0 if not on cooldown)
function CooldownSystem.getRemainingCooldown(entity: number, abilityName: string): number
    local cooldowns = world:get(entity, comps.Cooldowns)
    if not cooldowns or not cooldowns[abilityName] then
        return 0
    end

    local remaining = cooldowns[abilityName] - os.clock()
    return math.max(0, remaining)
end

-- Clear a specific cooldown
function CooldownSystem.clearCooldown(entity: number, abilityName: string)
    local cooldowns = world:get(entity, comps.Cooldowns)
    if not cooldowns then return end

    cooldowns[abilityName] = nil
    world:set(entity, comps.Cooldowns, cooldowns)
end

-- Clear all cooldowns for an entity
function CooldownSystem.clearAllCooldowns(entity: number)
    if world:has(entity, comps.Cooldowns) then
        world:set(entity, comps.Cooldowns, {})
    end
end

-- Reduce cooldown by a percentage (for cooldown reduction effects)
function CooldownSystem.reduceCooldown(entity: number, abilityName: string, reductionPercent: number)
    local cooldowns = world:get(entity, comps.Cooldowns)
    if not cooldowns or not cooldowns[abilityName] then return end

    local endTime = cooldowns[abilityName]
    local remaining = endTime - os.clock()
    if remaining <= 0 then return end

    local reduction = remaining * (reductionPercent / 100)
    cooldowns[abilityName] = endTime - reduction
    world:set(entity, comps.Cooldowns, cooldowns)
end

-- Get all cooldowns for an entity (for UI display)
function CooldownSystem.getAllCooldowns(entity: number): {[string]: number}
    local cooldowns = world:get(entity, comps.Cooldowns)
    if not cooldowns then return {} end

    local result = {}
    local now = os.clock()

    for abilityName, endTime in pairs(cooldowns) do
        local remaining = endTime - now
        if remaining > 0 then
            result[abilityName] = remaining
        end
    end

    return result
end

-- Cleanup expired cooldowns (optional, call periodically to save memory)
function CooldownSystem.cleanupExpired(entity: number)
    local cooldowns = world:get(entity, comps.Cooldowns)
    if not cooldowns then return end

    local now = os.clock()
    local hasChanges = false

    for abilityName, endTime in pairs(cooldowns) do
        if now >= endTime then
            cooldowns[abilityName] = nil
            hasChanges = true
        end
    end

    if hasChanges then
        world:set(entity, comps.Cooldowns, cooldowns)
    end
end

return CooldownSystem
