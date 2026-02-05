--[[
    Archetype Cleanup System (Client)

    Periodically calls world:cleanup() to remove empty archetypes on the client.
    This prevents memory leaks from archetype fragmentation when entities
    are deleted (e.g., when players die/respawn or NPCs despawn).

    Without this, empty archetypes accumulate in:
    - world.archetype_index
    - world.component_index

    This system runs every 15 seconds to clean up empty archetypes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

local CLEANUP_INTERVAL = 15 -- seconds between cleanups
local lastCleanup = 0

-- Helper to count table entries
local function countTable(t)
    local count = 0
    for _ in pairs(t) do
        count += 1
    end
    return count
end

return {
    run = function()
        local currentTime = os.clock()

        if currentTime - lastCleanup >= CLEANUP_INTERVAL then
            lastCleanup = currentTime

            local archetypesBefore = countTable(world.archetypes)

            -- Run cleanup to remove empty archetypes
            world:cleanup()

            local archetypesAfter = countTable(world.archetypes)
            local removed = archetypesBefore - archetypesAfter

            if removed > 0 then
                print(`[ArchetypeCleanup:Client] Removed {removed} empty archetypes ({archetypesBefore} -> {archetypesAfter})`)
            end
        end
    end,

    settings = {
        phase = "Heartbeat",
        paused = false,
        client_only = true, -- Client-side cleanup
    }
}
