--[[
    Alchemy Combinations System

    Each alchemy move has a unique directional sequence.
    Format: D=Down, U=Up, L=Left, R=Right

    Basic moves use simple 2-3 direction sequences.
    Advanced moves use longer, more complex sequences.
    Modifier sequences can enhance or change the base move.
]]

return {
    -- BASIC ALCHEMY (All Types)
    ["Construct"] = "DU",              -- Down -> Up (foundation building)

    -- STONE ALCHEMY
    ["Cascade"] = "DLR",               -- Down -> Left -> Right (falling rocks)
    ["Rock Skewer"] = "UDUD",          -- Up -> Down -> Up -> Down (spikes from ground)
    -- ["Stone Wall"] = "DLRU",           -- Down -> Left -> Right -> Up (wall construction)
    -- ["Boulder Throw"] = "ULR",         -- Up -> Left -> Right (overhead throw)
    -- ["Earth Spike"] = "DUR",           -- Down -> Up -> Right (single spike)
    -- ["Stone Prison"] = "DLRUD",        -- Down -> Left -> Right -> Up -> Down (encasing)

    -- FLAME ALCHEMY
    ["Cinder"] = "LRU",                -- Left -> Right -> Up (spreading embers)
    ["Firestorm"] = "RLUD",            -- Right -> Left -> Up -> Down (chaotic flames)
    -- ["Flame Wall"] = "LRUD",           -- Left -> Right -> Up -> Down (fire barrier)
    -- ["Fireball"] = "UDR",              -- Up -> Down -> Right (projectile)
    -- ["Flame Burst"] = "UDLR",          -- Up -> Down -> Left -> Right (explosion)
    -- ["Ignite"] = "UR",                 -- Up -> Right (simple ignition)
    -- ["Inferno"] = "RLRLUD",            -- Right -> Left -> Right -> Left -> Up -> Down (massive fire)

    -- BASIC ALCHEMY SPECIFIC
    ["Deconstruct"] = "UD",            -- Up -> Down (opposite of construct)
    ["AlchemicAssault"] = "DULR",      -- Down -> Up -> Left -> Right (complex attack)
    -- ["Transmute"] = "LRUD",            -- Left -> Right -> Up -> Down (transformation)
    -- ["Purify"] = "UDRL",               -- Up -> Down -> Right -> Left (cleansing)
    -- ["Barrier"] = "RLDU",              -- Right -> Left -> Down -> Up (protection)

    -- ADVANCED COMBINATIONS (Modifier Enhanced)
    -- ["Greater Construct"] = {
    --     base = "DU",                   -- Base construct
    --     modifier = "RL"                -- Right -> Left modifier for enhanced version
    -- },
    -- ["Meteor"] = {
    --     base = "ULR",                  -- Boulder throw base
    --     modifier = "DUD"               -- Down -> Up -> Down for meteor enhancement
    -- },
    -- ["Phoenix Flame"] = {
    --     base = "RLUD",                 -- Firestorm base
    --     modifier = "URD"               -- Up -> Right -> Down for phoenix enhancement
    -- },
    -- ["Earthquake"] = {
    --     base = "UDUD",                 -- Rock skewer base
    --     modifier = "LRL"               -- Left -> Right -> Left for area effect
    -- },

    -- UTILITY COMBINATIONS
    -- ["Repair"] = "UDUD",              -- Up -> Down -> Up -> Down (restoration)
    -- ["Enhance"] = "RLRL",             -- Right -> Left -> Right -> Left (improvement)
    -- ["Dispel"] = "LRDU",              -- Left -> Right -> Down -> Up (magic removal)
    -- ["Shield"] = "UDLR",              -- Up -> Down -> Left -> Right (protection)
}