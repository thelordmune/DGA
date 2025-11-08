--!strict
--[[
    Adrenaline System
    
    Manages adrenaline levels based on combat performance:
    - Landing hits increases adrenaline (more hits in a row = higher adrenaline)
    - Getting hit resets adrenaline to low
    - Adrenaline decays slowly over time when not landing hits
    
    Adrenaline Levels:
    - Low: 0-33
    - Medium: 34-66
    - High: 67-100
    
    Adrenaline affects the health bar UI visualization.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local Visuals = require(ReplicatedStorage.Modules.Visuals)

-- Adrenaline configuration
local ADRENALINE_PER_HIT = 3 -- Base adrenaline gain per hit (reduced from 5)
local COMBO_MULTIPLIER = 0.5 -- Multiplier for consecutive hits (reduced from 1.5)
local DECAY_RATE = 3 -- Adrenaline lost per second when not hitting (increased from 1)
local MIN_ADRENALINE = 0
local MAX_ADRENALINE = 100
local COMBO_TIMEOUT = 2 -- Seconds before combo resets (reduced from 3 for faster decay)

-- Track last hit time for combo timeout
local lastHitTimes = {}

-- Track last debug time to avoid spam
local lastDebugTime = 0
local DEBUG_INTERVAL = 5 -- Print debug every 5 seconds

local function adrenaline(dt: number)
    -- Only run on server
    if RunService:IsClient() then
        return
    end

    local currentTime = os.clock()

    -- Debug: Print system status periodically
    if currentTime - lastDebugTime > DEBUG_INTERVAL then
        local entityCount = 0
        local totalAdrenaline = 0
        for entity, adrenalineData in world:query(comps.Adrenaline):with(comps.ComponentsReady) do
            entityCount = entityCount + 1
            totalAdrenaline = totalAdrenaline + 1

            -- Get player name for debugging
            local player = world:get(entity, comps.Player)
            if player then
                print(`[Adrenaline Debug] Entity {entity} ({player.Name}): value={math.floor(adrenalineData.value)}, combo={adrenalineData.comboHits}`)
            end
        end
        print(`[Adrenaline System] Running - Processing {entityCount} entities with ComponentsReady`)

        -- Also check entities without ComponentsReady
        local withoutReady = 0
        for _ in world:query(comps.Adrenaline):without(comps.ComponentsReady) do
            withoutReady = withoutReady + 1
        end
        if withoutReady > 0 then
            print(`[Adrenaline System] WARNING: {withoutReady} entities have Adrenaline but NOT ComponentsReady`)
        end

        lastDebugTime = currentTime
    end

    -- Query all entities with Adrenaline component that are fully initialized
    for entity, adrenalineData in world:query(comps.Adrenaline):with(comps.ComponentsReady) do
        local needsSync = false

        -- Check if combo has timed out
        local lastHitTime = lastHitTimes[entity] or 0
        if currentTime - lastHitTime > COMBO_TIMEOUT and adrenalineData.comboHits > 0 then
            -- Reset combo
            adrenalineData.comboHits = 0
            world:set(entity, comps.Adrenaline, adrenalineData)
        end

        -- Decay adrenaline over time (only if not at minimum)
        if adrenalineData.value > MIN_ADRENALINE then
            local oldValue = adrenalineData.value
            local newValue = math.max(MIN_ADRENALINE, adrenalineData.value - (DECAY_RATE * dt))
            adrenalineData.value = newValue
            world:set(entity, comps.Adrenaline, adrenalineData)

            -- Sync to client every time value changes by at least 1
            if math.floor(oldValue) ~= math.floor(newValue) then
                needsSync = true
                print(`[Adrenaline] Entity {entity} decayed from {math.floor(oldValue)} to {math.floor(newValue)}`)
            end
        end

        -- Sync to client if needed
        if needsSync then
            syncAdrenalineToClient(entity, adrenalineData.value)
        end
    end
end

-- Helper function to sync adrenaline to client
local function syncAdrenalineToClient(entity: number, adrenalineValue: number)
    -- Get the player from the entity
    local player = world:get(entity, comps.Player)
    if player and player:IsA("Player") then
        -- Send adrenaline value to client
        local adrenalineInt = math.floor(adrenalineValue)
        Bridges.UpdateAdrenaline:Fire(player, {
            adrenaline = adrenalineInt
        })
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
        print("Adrenaline increased")
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
    end

    -- Update last hit time
    lastHitTimes[entity] = os.clock()

    -- Update component
    world:set(entity, comps.Adrenaline, adrenalineData)

    -- Sync to client
    syncAdrenalineToClient(entity, adrenalineData.value)

    -- Debug: Only print on significant adrenaline changes
    if adrenalineData.comboHits == 1 or adrenalineData.comboHits % 3 == 0 then
        print(`[Adrenaline] Combo #{adrenalineData.comboHits}, adrenaline: {math.floor(adrenalineData.value)}`)
    end
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

