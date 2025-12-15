-- Wanderer behavior tree - peaceful NPCs that just wander around
local Conditions = require(game.ReplicatedStorage.NpcHelper.Conditions)
local Trees = require(game.ReplicatedStorage.NpcHelper.Trees)

return function(TREE)
    local FALLBACK = TREE.fallback
    local SEQUENCE = TREE.sequence
    local INVERT = TREE.invert

    -- Helper function to create conditions
    local function Condition(conditionName, ...)
        local extraArguments = { ... }
        return function(actor, mainConfig)
            local result = Conditions[conditionName](actor, mainConfig, table.unpack(extraArguments))
            return result
        end
    end

    return SEQUENCE({
        -- Use the default brain sequence for spawning
        Trees.default_brain_sequence(TREE),

        -- Debug: Add some logging
        function(actor, mainConfig)
            -- ---- print("Wanderer behavior tree running for:", actor.Name)
            return true
        end,

        -- Main wanderer behavior
        FALLBACK({
            -- If low health, run away
            SEQUENCE({
                Condition("is_low_health"),
                Condition("run_away"),
            }),

            -- If should wander, wander around
            SEQUENCE({
                Condition("should_wander"),
                Condition("wander"),
            }),

            -- Otherwise idle at spawn
            Condition("idle_at_spawn"),
        })
    })
end
