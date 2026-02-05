--!strict
--[[
    Entity Cleanup System

    Centralized cleanup registry for per-entity state.
    Systems register cleanup callbacks, which are called when entities are deleted.

    Usage:
        local EntityCleanup = require(ReplicatedStorage.Modules.ECS.entity_cleanup)

        -- Register a cleanup callback
        EntityCleanup.register("my_system", function(entity)
            myTable[entity] = nil
        end)

        -- Call cleanup when deleting an entity (done in mobs.luau/playerloader.luau)
        EntityCleanup.cleanup(entity)
]]

local cleanupCallbacks: {[string]: (entity: number) -> ()} = {}

local EntityCleanup = {}

-- Register a cleanup callback for a system
function EntityCleanup.register(systemName: string, callback: (entity: number) -> ())
    cleanupCallbacks[systemName] = callback
end

-- Unregister a cleanup callback
function EntityCleanup.unregister(systemName: string)
    cleanupCallbacks[systemName] = nil
end

-- Call all registered cleanup callbacks for an entity
function EntityCleanup.cleanup(entity: number)
    for systemName, callback in pairs(cleanupCallbacks) do
        local success, err = pcall(callback, entity)
        if not success then
            warn(`[EntityCleanup] Error in {systemName}: {err}`)
        end
    end
end

-- Get count of registered callbacks (for debugging)
function EntityCleanup.getRegisteredCount(): number
    local count = 0
    for _ in pairs(cleanupCallbacks) do
        count += 1
    end
    return count
end

return EntityCleanup
