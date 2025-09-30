--[[
    Alchemy Skills Configuration

    Now uses directional casting system instead of fixed Z/X/C keys.
    All alchemy moves are cast through directional sequences.

    This file maintains the alchemy types for compatibility but
    moves are now determined by casting combinations.
--]]

return {
    Stone = {
        -- Stone alchemy has access to all stone-based combinations
        -- Plus basic alchemy moves like Construct
        Type = "Stone",
        Description = "Earth and stone manipulation alchemy"
    },
    Basic = {
        -- Basic alchemy has access to fundamental combinations
        -- Like Construct, Deconstruct, AlchemicAssault, etc.
        Type = "Basic",
        Description = "Fundamental alchemy principles"
    },
    Flame = {
        -- Flame alchemy has access to all fire-based combinations
        -- Plus basic alchemy moves like Construct
        Type = "Flame",
        Description = "Fire and heat manipulation alchemy"
    }
}