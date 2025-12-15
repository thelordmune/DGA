--!strict
--[[
    Adrenaline System - OPTIMIZED

    Manages adrenaline levels based on combat performance:
    - Landing hits increases adrenaline (more hits in a row = higher adrenaline)
    - Getting hit resets adrenaline to low
    - Adrenaline decays slowly over time when not landing hits

    Adrenaline Levels:
    - Low: 0-33
    - Medium: 34-66
    - High: 67-100

    OPTIMIZATIONS:
    - Removed all debug logging
    - Cached query results
    - Optimized sync logic to only update when needed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local Visuals = require(ReplicatedStorage.Modules.Visuals)

-- Adrenaline configuration
local ADRENALINE_PER_HIT = 5
local COMBO_MULTIPLIER = 1
local DECAY_RATE = 2
local MIN_ADRENALINE = 0
local MAX_ADRENALINE = 100
local COMBO_TIMEOUT = 3

-- Track last hit time for combo timeout
local lastHitTimes = {}

-- Helper function to sync adrenaline to client
local function syncAdrenalineToClient(entity: number, adrenalineValue: number)
    local player = world:get(entity, comps.Player)
    if player and player:IsA("Player") then
        Bridges.UpdateAdrenaline:Fire(player, {
            adrenaline = math.floor(adrenalineValue)
        })
    end
end

local function adrenaline(_world, dt: number)
    -- Only run on server
    if RunService:IsClient() then
        return
    end

    local currentTime = os.clock()

    -- Query all entities with Adrenaline component that are fully initialized
    for entity, adrenalineData in world:query(comps.Adrenaline):with(comps.ComponentsReady) do
        local needsSync = false
        local needsUpdate = false

        -- Check if combo has timed out
        local lastHitTime = lastHitTimes[entity] or 0
        if currentTime - lastHitTime > COMBO_TIMEOUT and adrenalineData.comboHits > 0 then
            adrenalineData.comboHits = 0
            needsUpdate = true
        end

        -- Decay adrenaline over time (only if not at minimum)
        if adrenalineData.value > MIN_ADRENALINE then
            local oldValue = adrenalineData.value
            local newValue = math.max(MIN_ADRENALINE, adrenalineData.value - (DECAY_RATE * dt))
            adrenalineData.value = newValue
            needsUpdate = true

            -- Sync to client every time value changes by at least 1
            if math.floor(oldValue) ~= math.floor(newValue) then
                needsSync = true
            end
        end

        -- Update component if needed
        if needsUpdate then
            world:set(entity, comps.Adrenaline, adrenalineData)
        end

        -- Sync to client if needed
        if needsSync then
            syncAdrenalineToClient(entity, adrenalineData.value)
        end
    end
end

-- Helper function to get adrenaline level name
local function getAdrenalineLevel(value: number): string
    if value <= 33 then
        return "Low"
    elseif value <= 66 then
        return "Medium"
    else
        return "High"
    end
end

-- Helper function to increase adrenaline when landing a hit
-- This should be called from the damage system
local function increaseAdrenaline(entity: number)
    local adrenalineData = world:get(entity, comps.Adrenaline)
    if not adrenalineData then
        -- Initialize if doesn't exist
        adrenalineData = { value = 0, comboHits = 0 }
    end

    -- Store old level before increasing
    local oldLevel = getAdrenalineLevel(adrenalineData.value)

    -- Increase combo counter
    adrenalineData.comboHits = adrenalineData.comboHits + 1

    -- Calculate adrenaline gain (more for combos)
    local comboBonus = math.min(adrenalineData.comboHits - 1, 5) * COMBO_MULTIPLIER
    local adrenalineGain = ADRENALINE_PER_HIT + comboBonus

    -- Add adrenaline (clamped to max)
    adrenalineData.value = math.min(MAX_ADRENALINE, adrenalineData.value + adrenalineGain)

    -- Check if level increased
    local newLevel = getAdrenalineLevel(adrenalineData.value)
    if newLevel ~= oldLevel then
        local sfx = game:GetService("ReplicatedStorage").Assets.SFX.Extra.Adrenaline:Clone()
        sfx.Parent = world:get(entity, comps.Character).HumanoidRootPart
        sfx:Play()
        task.delay(2, function()
            sfx:Stop()
            sfx:Destroy()
        end)

        -- Play adrenaline VFX when level increases
        local character = world:get(entity, comps.Character)
        if character and character:FindFirstChild("HumanoidRootPart") then
            Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
                Module = "Misc",
                Function = "AdrenalineFX",
                Arguments = { character }
            })
        end

        -- Health regeneration when reaching high adrenaline
        if newLevel == "High" and oldLevel ~= "High" then
            local health = world:get(entity, comps.Health)
            if health and health.current < health.max then
                -- Restore 7% of max health
                local healAmount = math.floor(health.max * 0.07)
                health.current = math.min(health.current + healAmount, health.max)
                world:set(entity, comps.Health, health)

                -- Update character's Humanoid
                local char = world:get(entity, comps.Character)
                if char and char:FindFirstChild("Humanoid") then
                    char.Humanoid.Health = health.current
                end
            end
        end
    end

    -- Update last hit time
    lastHitTimes[entity] = os.clock()

    -- Update component
    world:set(entity, comps.Adrenaline, adrenalineData)

    -- Sync to client
    syncAdrenalineToClient(entity, adrenalineData.value)
end

-- Helper function to reset adrenaline when getting hit
-- This should be called from the damage system
local function resetAdrenaline(entity: number)
    local adrenalineData = world:get(entity, comps.Adrenaline)
    if not adrenalineData then
        return
    end

    -- Reset to low adrenaline
    adrenalineData.value = MIN_ADRENALINE
    adrenalineData.comboHits = 0

    -- Clear last hit time
    lastHitTimes[entity] = nil

    -- Update component
    world:set(entity, comps.Adrenaline, adrenalineData)

    -- Sync to client
    syncAdrenalineToClient(entity, adrenalineData.value)
end

-- Export module with helper functions
local AdrenalineModule = {
    run = adrenaline,
    settings = {
        server_only = true,
        phase = "Heartbeat",
    },
    -- Public API for other systems to use
    increaseAdrenaline = increaseAdrenaline,
    resetAdrenaline = resetAdrenaline,
}

return AdrenalineModule



