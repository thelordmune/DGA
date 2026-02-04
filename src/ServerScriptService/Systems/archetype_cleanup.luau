--[[
    Archetype Cleanup System

    Periodically calls world:cleanup() to remove empty archetypes.
    This prevents memory leaks from archetype fragmentation when entities
    are deleted (e.g., when players die/respawn or NPCs despawn).

    Without this, empty archetypes accumulate in:
    - world.archetype_index
    - world.component_index

    This system runs every 10 seconds to clean up empty archetypes.
    A more aggressive cleanup runs every 60 seconds that also compacts component_index.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

local CLEANUP_INTERVAL = 10 -- seconds between cleanups
local DEEP_CLEANUP_INTERVAL = 60 -- seconds between deep cleanups
local lastCleanup = 0
local lastDeepCleanup = 0

-- Helper to count table entries
local function countTable(t)
    local count = 0
    for _ in pairs(t) do
        count += 1
    end
    return count
end

-- Perform cleanup and return stats
local function performCleanup()
    local archetypesBefore = countTable(world.archetypes)
    local componentIndexBefore = countTable(world.component_index)

    -- Run cleanup to remove empty archetypes
    world:cleanup()

    local archetypesAfter = countTable(world.archetypes)
    local componentIndexAfter = countTable(world.component_index)

    return {
        archetypesRemoved = archetypesBefore - archetypesAfter,
        archetypesBefore = archetypesBefore,
        archetypesAfter = archetypesAfter,
        componentIndexBefore = componentIndexBefore,
        componentIndexAfter = componentIndexAfter,
    }
end

return {
    run = function(_world, deltaTime)
        local currentTime = os.clock()

        -- Regular cleanup every 10 seconds
        if currentTime - lastCleanup >= CLEANUP_INTERVAL then
            lastCleanup = currentTime

            local stats = performCleanup()

            if stats.archetypesRemoved > 0 then
                print(`[ArchetypeCleanup] Removed {stats.archetypesRemoved} empty archetypes ({stats.archetypesBefore} -> {stats.archetypesAfter})`)
            end
        end

        -- Deep cleanup with stats every 60 seconds
        if currentTime - lastDeepCleanup >= DEEP_CLEANUP_INTERVAL then
            lastDeepCleanup = currentTime

            local stats = performCleanup()

            -- Always print stats during deep cleanup for monitoring
            print(`[ArchetypeCleanup] Deep cleanup - Archetypes: {stats.archetypesAfter}, ComponentIndex entries: {stats.componentIndexAfter}`)

            -- Warn if archetype count is getting high
            if stats.archetypesAfter > 500 then
                warn(`[ArchetypeCleanup] High archetype count: {stats.archetypesAfter} - potential fragmentation issue`)
            end
        end
    end,

    settings = {
        phase = "Heartbeat",
        paused = false,
        server_only = true, -- Server handles authoritative cleanup
    }
}
