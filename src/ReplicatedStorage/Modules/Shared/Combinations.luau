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
    ["Construct"] = "DU",              -- Down -> Up (foundation \building)

    -- STONE ALCHEMY
    ["Cascade"] = "DLR",               -- Down -> Left -> Right (falling rocks)
    ["Rock Skewer"] = "UDUD",          -- Up -> Down -> Up -> Down (spikes from ground)


    -- FLAME ALCHEMY
    ["Cinder"] = "LRU",                -- Left -> Right -> Up (spreading embers)
    ["Firestorm"] = "RLUD",            -- Right -> Left -> Up -> Down (chaotic flames)

    ["Deconstruct"] = "UD",            -- Up -> Down (opposite of construct)
    ["AlchemicAssault"] = "DULR",      -- Down -> Up -> Left -> Right (complex attack)

}