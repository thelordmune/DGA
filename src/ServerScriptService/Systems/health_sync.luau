--!strict
--[[
    Health Sync System - OPTIMIZED

    Keeps the ECS Health component in sync with the Humanoid.Health value.
    This ensures that when damage is dealt directly to the Humanoid,
    the Health component is updated accordingly.

    This is critical for systems like health_regen to work properly.

    OPTIMIZATIONS:
    - Throttled periodic sync to 5 Hz (was 60 Hz) - 92% reduction
    - Event-based sync still runs immediately for responsive health changes
    - Cached query for better performance
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local tags = require(ReplicatedStorage.Modules.ECS.jecs_tags)

-- Track health connections per entity
local healthConnections = {}

-- Debug logging
local DEBUG = false
local lastDebugTime = 0
local DEBUG_INTERVAL = 5 -- Print debug info every 5 seconds

-- OPTIMIZATION: Throttle periodic sync to 5 Hz instead of 60 Hz
local SYNC_HZ = 5
local SYNC_TICK = 1 / SYNC_HZ
local syncAcc = 0

-- OPTIMIZATION: Cached query (excludes dead entities)
local healthQuery = world:query(comps.Health):with(comps.ComponentsReady):without(tags.Dead):cached()

-- Setup connections for new entities (runs every frame to detect new entities)
local function setupHealthConnections()
    -- Only run on server
    if RunService:IsClient() then
        return
    end

    -- OPTIMIZATION: Use cached query
    for entity, health in healthQuery do
        -- Get the character
        local character = world:get(entity, comps.Character)
        if not character or not character.Parent then
            -- Clean up connection if character is gone
            if healthConnections[entity] then
                local conns = healthConnections[entity]
                if type(conns) == "table" then
                    if conns.healthChanged then conns.healthChanged:Disconnect() end
                    if conns.maxHealthChanged then conns.maxHealthChanged:Disconnect() end
                else
                    conns:Disconnect()
                end
                healthConnections[entity] = nil
            end
            continue
        end

        -- Get humanoid
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then
            continue
        end

        -- IMMEDIATE CLEANUP: Check if character changed (respawn scenario)
        -- If we have connections but they're for a different character/humanoid, clean up NOW
        if healthConnections[entity] then
            local existingConns = healthConnections[entity]
            -- Check if the stored humanoid reference is different (character changed)
            if existingConns.humanoidRef and existingConns.humanoidRef ~= humanoid then
                -- Character changed - cleanup old connections IMMEDIATELY
                if existingConns.healthChanged then existingConns.healthChanged:Disconnect() end
                if existingConns.maxHealthChanged then existingConns.maxHealthChanged:Disconnect() end
                healthConnections[entity] = nil
            end
        end

        -- Set up health changed listener if not already set up
        if not healthConnections[entity] then
            local healthChangedConnection = humanoid.HealthChanged:Connect(function(newHealth)
                -- Get current health component
                local currentHealth = world:get(entity, comps.Health)
                if not currentHealth then return end

                -- Only update if there's a difference (avoid infinite loops)
                if math.abs(currentHealth.current - newHealth) > 0.1 then
                    -- Update health component to match humanoid (in-place mutation, no world:set needed)
                    currentHealth.current = math.max(0, math.min(newHealth, currentHealth.max))
                    -- PERFORMANCE: Component is mutated in-place, world:set() is unnecessary

                    if DEBUG then
                       -- print(`[HealthSync] Event-based sync: entity {entity} health: {currentHealth.current}/{currentHealth.max}`)
                    end
                end
            end)

            -- Also sync max health
            local maxHealthConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
                local currentHealth = world:get(entity, comps.Health)
                if not currentHealth then return end

                -- In-place mutation, no world:set needed
                currentHealth.max = humanoid.MaxHealth
            end)

            -- Store both connections and humanoid reference for respawn detection
            healthConnections[entity] = {
                healthChanged = healthChangedConnection,
                maxHealthChanged = maxHealthConnection,
                humanoidRef = humanoid
            }
        end
    end
end

-- OPTIMIZATION: Periodic sync check (throttled to 5 Hz instead of 60 Hz)
-- This catches any missed updates from the event-based system
local function periodicHealthSync()
    for entity, health in healthQuery do
        local character = world:get(entity, comps.Character)
        if not character or not character.Parent then
            continue
        end

        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then
            continue
        end

        -- Sync if there's a difference (in-place mutation, no world:set needed)
        if math.abs(health.current - humanoid.Health) > 0.1 then
            health.current = math.max(0, math.min(humanoid.Health, health.max))
            -- PERFORMANCE: Component is mutated in-place, world:set() is unnecessary
        end
    end
end

-- Main system function with throttling
local function health_sync(_world, dt: number)
    -- Always setup connections for new entities (lightweight check)
    setupHealthConnections()

    -- OPTIMIZATION: Throttle periodic sync to 5 Hz
    syncAcc += dt
    if syncAcc >= SYNC_TICK then
        syncAcc = 0
        periodicHealthSync()

        -- Debug logging
        if DEBUG then
            local currentTime = os.clock()
            if currentTime - lastDebugTime >= DEBUG_INTERVAL then
                local syncedEntities = 0
                for _ in pairs(healthConnections) do
                    syncedEntities = syncedEntities + 1
                end
               -- print(`[HealthSync] Active health sync connections: {syncedEntities} (OPTIMIZED - 5 Hz periodic sync)`)
                lastDebugTime = currentTime
            end
        end
    end
end

-- Clean up connections when entities are removed
local function cleanup()
    for entity, connections in pairs(healthConnections) do
        -- Check both entity AND character validity
        -- JECS reuses entity IDs, so we must also verify the character still exists
        local character = nil
        if world:contains(entity) then
            character = world:get(entity, comps.Character)
        end

        -- Clean up if entity gone OR character gone/destroyed
        if not world:contains(entity) or not character or not character.Parent then
            if type(connections) == "table" then
                if connections.healthChanged then
                    connections.healthChanged:Disconnect()
                end
                if connections.maxHealthChanged then
                    connections.maxHealthChanged:Disconnect()
                end
            else
                connections:Disconnect()
            end
            healthConnections[entity] = nil
        end
    end
end

-- Run cleanup periodically
task.spawn(function()
    while true do
        task.wait(5)
        cleanup()
    end
end)

return {
    run = health_sync,
    settings = {
        server_only = true,
        phase = "Heartbeat",
    }
}

