--[[
    Status Effects System (ECS-Driven)

    Processes status effects like Burning, Bleeding, Poisoned via ECS queries
    instead of individual RunService loops per effect.

    Benefits:
    - Single system handles all status effects
    - Automatic cleanup when component is removed
    - Dead entities excluded via query filter
    - Efficient batched processing
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local tags = require(ReplicatedStorage.Modules.ECS.jecs_tags)
local jecsRef = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local Visuals = require(ReplicatedStorage.Modules.Visuals)

-- Cached queries for status effects (exclude dead entities)
local burningQuery = world:query(comps.Burning, comps.Character):without(tags.Dead):cached()
local bleedingQuery = world:query(comps.Bleeding, comps.Character):without(tags.Dead):cached()
local poisonedQuery = world:query(comps.Poisoned, comps.Character):without(tags.Dead):cached()

-- Helper to apply damage and check for death
local function applyStatusDamage(entity, character, damage, statusName)
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end

    local health = world:get(entity, comps.Health)
    if not health then return end

    local newHealth = health.current - damage

    if newHealth <= 1 then
        -- Skip if already dead
        if character:GetAttribute("IsDead") then return end

        -- Set health to death threshold
        humanoid.Health = 1
        health.current = 1

        -- Mark as dead
        character:SetAttribute("IsDead", true)
        character:SetAttribute("DeathTime", os.clock())

        -- Add Dead tag via ECS
        if not world:has(entity, tags.Dead) then
            world:add(entity, tags.Dead)
            world:set(entity, comps.DeathInfo, {
                killer = nil,
                damageType = statusName,
                timestamp = os.clock()
            })
        end
    else
        health.current = newHealth
        humanoid.Health = newHealth
    end
end

-- Process burning entities
local function processBurning(dt)
    for entity, burning, character in burningQuery:iter() do
        if not character or not character.Parent then continue end

        -- Update remaining time
        burning.remainingTime = burning.remainingTime - dt

        -- Check if effect expired
        if burning.remainingTime <= 0 then
            -- Remove component
            world:remove(entity, comps.Burning)

            -- Disable visual effect
            pcall(function()
                Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
                    Module = "Misc",
                    Function = "DisableStatus",
                    Arguments = { character, "Burning" },
                })
            end)
            continue
        end

        -- Check if it's time to tick damage
        local timeSinceLastTick = os.clock() - burning.lastTick
        if timeSinceLastTick >= burning.tickInterval then
            burning.lastTick = os.clock()
            applyStatusDamage(entity, character, burning.damagePerTick, "Burning")
        end
    end
end

-- Process bleeding entities
local function processBleeding(dt)
    for entity, bleeding, character in bleedingQuery:iter() do
        if not character or not character.Parent then continue end

        -- Update remaining time
        bleeding.remainingTime = bleeding.remainingTime - dt

        -- Check if effect expired
        if bleeding.remainingTime <= 0 then
            world:remove(entity, comps.Bleeding)

            pcall(function()
                Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
                    Module = "Misc",
                    Function = "DisableStatus",
                    Arguments = { character, "Bleeding" },
                })
            end)
            continue
        end

        -- Check if it's time to tick damage (stacks increase damage)
        local timeSinceLastTick = os.clock() - bleeding.lastTick
        if timeSinceLastTick >= bleeding.tickInterval then
            bleeding.lastTick = os.clock()
            local stackedDamage = bleeding.damagePerTick * bleeding.stacks
            applyStatusDamage(entity, character, stackedDamage, "Bleeding")
        end
    end
end

-- Process poisoned entities
local function processPoisoned(dt)
    for entity, poisoned, character in poisonedQuery:iter() do
        if not character or not character.Parent then continue end

        -- Update remaining time
        poisoned.remainingTime = poisoned.remainingTime - dt

        -- Check if effect expired
        if poisoned.remainingTime <= 0 then
            world:remove(entity, comps.Poisoned)

            pcall(function()
                Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
                    Module = "Misc",
                    Function = "DisableStatus",
                    Arguments = { character, "Poisoned" },
                })
            end)
            continue
        end

        -- Check if it's time to tick damage
        local timeSinceLastTick = os.clock() - poisoned.lastTick
        if timeSinceLastTick >= poisoned.tickInterval then
            poisoned.lastTick = os.clock()
            applyStatusDamage(entity, character, poisoned.damagePerTick, "Poisoned")
        end
    end
end

-- Public API for applying status effects
local StatusEffects = {}

function StatusEffects.applyBurning(entity, damagePerTick, tickInterval, duration, source)
    local existing = world:get(entity, comps.Burning)
    if existing then
        -- Refresh duration if already burning
        existing.remainingTime = math.max(existing.remainingTime, duration)
        return
    end

    world:set(entity, comps.Burning, {
        damagePerTick = damagePerTick,
        tickInterval = tickInterval,
        remainingTime = duration,
        lastTick = os.clock(),
        source = source
    })

    -- Enable visual effect
    local character = world:get(entity, comps.Character)
    if character and character:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
                Module = "Misc",
                Function = "EnableStatus",
                Arguments = { character, "Burning", duration },
            })
        end)
    end
end

function StatusEffects.applyBleeding(entity, damagePerTick, tickInterval, duration, stacks)
    local existing = world:get(entity, comps.Bleeding)
    if existing then
        -- Stack bleeding effects
        existing.stacks = math.min(existing.stacks + (stacks or 1), 5) -- Max 5 stacks
        existing.remainingTime = math.max(existing.remainingTime, duration)
        return
    end

    world:set(entity, comps.Bleeding, {
        damagePerTick = damagePerTick,
        tickInterval = tickInterval,
        remainingTime = duration,
        lastTick = os.clock(),
        stacks = stacks or 1
    })

    local character = world:get(entity, comps.Character)
    if character and character:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
                Module = "Misc",
                Function = "EnableStatus",
                Arguments = { character, "Bleeding", duration },
            })
        end)
    end
end

function StatusEffects.applyPoisoned(entity, damagePerTick, tickInterval, duration, source)
    local existing = world:get(entity, comps.Poisoned)
    if existing then
        existing.remainingTime = math.max(existing.remainingTime, duration)
        return
    end

    world:set(entity, comps.Poisoned, {
        damagePerTick = damagePerTick,
        tickInterval = tickInterval,
        remainingTime = duration,
        lastTick = os.clock(),
        source = source
    })

    local character = world:get(entity, comps.Character)
    if character and character:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
                Module = "Misc",
                Function = "EnableStatus",
                Arguments = { character, "Poisoned", duration },
            })
        end)
    end
end

function StatusEffects.clearAll(entity)
    if world:has(entity, comps.Burning) then
        world:remove(entity, comps.Burning)
    end
    if world:has(entity, comps.Bleeding) then
        world:remove(entity, comps.Bleeding)
    end
    if world:has(entity, comps.Poisoned) then
        world:remove(entity, comps.Poisoned)
    end
end

-- Main system run function
local function run(_world, dt)
    if RunService:IsClient() then return end

    processBurning(dt)
    processBleeding(dt)
    processPoisoned(dt)
end

return {
    run = run,
    settings = {
        server_only = true,
        phase = "Heartbeat",
    },
    -- Public API
    applyBurning = StatusEffects.applyBurning,
    applyBleeding = StatusEffects.applyBleeding,
    applyPoisoned = StatusEffects.applyPoisoned,
    clearAll = StatusEffects.clearAll,
}
