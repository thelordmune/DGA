--[[
    Alchemy Combinations System

    Each alchemy move has a unique key sequence.
    Format: Z, X, C keys

    Basic moves use simple 1-3 key sequences.
    Advanced moves use longer, more complex sequences.
    Modifier sequences can enhance or change the base move.
]]

return {
    -- BASIC ALCHEMY (All Types)
    ["Z"] = "Construct",              -- Z (foundation/building)
    ["ZX"] = "Stone Lance",           -- Z -> X
    ["ZZZ"] = "Stone Lance Path",     -- Z -> Z -> Z (multiple lances in path)
    ["XZ"] = "Sky Arc",               -- X -> Z (arcing bridge)

    -- STONE ALCHEMY
    ["ZXC"] = "Cascade",              -- Z -> X -> C (falling rocks)
    ["XZXZ"] = "Rock Skewer",         -- X -> Z -> X -> Z (spikes from ground)
    ["XXZC"] = "Branch",              -- X -> X -> Z -> C (converging rock paths)
    ["CXZ"] = "Ground Decay",         -- C -> X -> Z (expanding craters)

    -- FLAME ALCHEMY
    ["CXZC"] = "Firestorm",           -- C -> X -> Z -> C (chaotic flames)

    ["X"] = "Deconstruct",            -- X (opposite of construct)
    ["ZXCX"] = "AlchemicAssault",     -- Z -> X -> C -> X (complex attack)

    -- Misc
    ["CCXZ"] = "Motor",

    -- TRUTH (Gate of Truth - FMA Brotherhood)
    ["XXXXX"] = "Truth",              -- X -> X -> X -> X -> X (forbidden alchemy)
}