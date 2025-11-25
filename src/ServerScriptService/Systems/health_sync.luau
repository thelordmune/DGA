--!strict
--[[
    Health Sync System
    
    Keeps the ECS Health component in sync with the Humanoid.Health value.
    This ensures that when damage is dealt directly to the Humanoid,
    the Health component is updated accordingly.
    
    This is critical for systems like health_regen to work properly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

-- Track health connections per entity
local healthConnections = {}

-- Debug logging
local DEBUG = false
local lastDebugTime = 0
local DEBUG_INTERVAL = 5 -- Print debug info every 5 seconds

local function health_sync(_world, _dt: number)
    -- Only run on server
    if RunService:IsClient() then
        return
    end

    -- Debug logging
    if DEBUG then
        local currentTime = os.clock()
        if currentTime - lastDebugTime >= DEBUG_INTERVAL then
            local syncedEntities = 0
            for _ in pairs(healthConnections) do
                syncedEntities = syncedEntities + 1
            end
            print(`[HealthSync] Active health sync connections: {syncedEntities}`)
            lastDebugTime = currentTime
        end
    end

    -- Query all entities with Health component that are fully initialized
    for entity, health in world:query(comps.Health):with(comps.ComponentsReady) do
        -- Get the character
        local character = world:get(entity, comps.Character)
        if not character or not character.Parent then
            -- Clean up connection if character is gone
            if healthConnections[entity] then
                healthConnections[entity]:Disconnect()
                healthConnections[entity] = nil
            end
            continue
        end

        -- Get humanoid
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then
            continue
        end

        -- Set up health changed listener if not already set up
        if not healthConnections[entity] then
            local healthChangedConnection = humanoid.HealthChanged:Connect(function(newHealth)
                -- Get current health component
                local currentHealth = world:get(entity, comps.Health)
                if not currentHealth then return end

                -- Only update if there's a difference (avoid infinite loops)
                if math.abs(currentHealth.current - newHealth) > 0.1 then
                    -- Update health component to match humanoid
                    currentHealth.current = math.max(0, math.min(newHealth, currentHealth.max))
                    world:set(entity, comps.Health, currentHealth)

                    if DEBUG then
                        print(`[HealthSync] Synced entity {entity} health: {currentHealth.current}/{currentHealth.max}`)
                    end
                end
            end)

            -- Also sync max health
            local maxHealthConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
                local currentHealth = world:get(entity, comps.Health)
                if not currentHealth then return end

                currentHealth.max = humanoid.MaxHealth
                world:set(entity, comps.Health, currentHealth)

                if DEBUG then
                    print(`[HealthSync] Synced entity {entity} max health: {currentHealth.max}`)
                end
            end)

            -- Store both connections
            healthConnections[entity] = {
                healthChanged = healthChangedConnection,
                maxHealthChanged = maxHealthConnection
            }
        end

        -- Also do a periodic sync check (every frame) to catch any missed updates
        if math.abs(health.current - humanoid.Health) > 0.1 then
            health.current = math.max(0, math.min(humanoid.Health, health.max))
            world:set(entity, comps.Health, health)
        end
    end
end

-- Clean up connections when entities are removed
local function cleanup()
    for entity, connections in pairs(healthConnections) do
        if not world:contains(entity) then
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

