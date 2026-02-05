--[[
    OccupationData.lua

    Defines all wandering NPC occupations, names, personalities, and favors.
    Based on the Fullmetal Alchemist world with military and civilian roles.
]]

local OccupationData = {}

-- Military Occupations (30% spawn chance)
OccupationData.Military = {
    ["State Alchemist"] = {
        description = "A certified alchemist serving the Amestrian military.",
        favors = {
            Stranger = {},
            Acquaintance = {"alchemy_tip"},
            Friend = {"alchemy_supplies"},
            ["Close Friend"] = {"research_notes", "alchemy_supplies"},
            Trusted = {"rare_transmutation_circle", "special_quest"},
        },
        dialoguePool = "StateAlchemist",
    },
    ["Soldier"] = {
        description = "A member of the Amestrian military forces.",
        favors = {
            Stranger = {},
            Acquaintance = {"directions"},
            Friend = {"ammo", "basic_intel"},
            ["Close Friend"] = {"combat_training", "military_intel"},
            Trusted = {"restricted_access", "special_quest"},
        },
        dialoguePool = "Soldier",
    },
    ["Military Police"] = {
        description = "Enforces law and order in Amestris.",
        favors = {
            Stranger = {},
            Acquaintance = {"directions"},
            Friend = {"wanted_info"},
            ["Close Friend"] = {"minor_pardon", "detailed_intel"},
            Trusted = {"legal_pardon", "special_quest"},
        },
        dialoguePool = "MilitaryPolice",
    },
    ["Intelligence Agent"] = {
        description = "Gathers information for the military command.",
        favors = {
            Stranger = {},
            Acquaintance = {},
            Friend = {"rumors"},
            ["Close Friend"] = {"enemy_locations"},
            Trusted = {"classified_secrets", "special_quest"},
        },
        dialoguePool = "IntelAgent",
    },
}

-- Civilian Occupations (70% spawn chance)
OccupationData.Civilian = {
    ["Automail Engineer"] = {
        description = "Specializes in prosthetic automail limbs.",
        favors = {
            Stranger = {},
            Acquaintance = {"basic_repair"},
            Friend = {"automail_parts", "repairs"},
            ["Close Friend"] = {"automail_upgrade", "custom_parts"},
            Trusted = {"masterwork_automail", "special_quest"},
        },
        dialoguePool = "AutomailEngineer",
    },
    ["Merchant"] = {
        description = "Trades goods across Amestris.",
        favors = {
            Stranger = {},
            Acquaintance = {"small_discount"},
            Friend = {"discount", "rare_items_hint"},
            ["Close Friend"] = {"big_discount", "rare_items"},
            Trusted = {"best_prices", "special_quest"},
        },
        dialoguePool = "Merchant",
    },
    ["Blacksmith"] = {
        description = "Forges weapons and tools.",
        favors = {
            Stranger = {},
            Acquaintance = {"basic_sharpening"},
            Friend = {"weapon_repairs", "materials"},
            ["Close Friend"] = {"weapon_upgrade"},
            Trusted = {"masterwork_weapon", "special_quest"},
        },
        dialoguePool = "Blacksmith",
    },
    ["Doctor"] = {
        description = "Heals the sick and wounded.",
        favors = {
            Stranger = {"basic_healing"},
            Acquaintance = {"healing", "bandages"},
            Friend = {"medicine", "treatment"},
            ["Close Friend"] = {"surgery", "rare_medicine"},
            Trusted = {"full_recovery", "special_quest"},
        },
        dialoguePool = "Doctor",
    },
    ["Librarian"] = {
        description = "Keeper of knowledge and ancient texts.",
        favors = {
            Stranger = {},
            Acquaintance = {"book_recommendation"},
            Friend = {"alchemy_research", "lore"},
            ["Close Friend"] = {"rare_books", "hidden_knowledge"},
            Trusted = {"forbidden_texts", "special_quest"},
        },
        dialoguePool = "Librarian",
    },
    ["Farmer"] = {
        description = "Works the land and raises livestock.",
        favors = {
            Stranger = {},
            Acquaintance = {"basic_food"},
            Friend = {"food", "ingredients"},
            ["Close Friend"] = {"rare_ingredients"},
            Trusted = {"best_produce", "special_quest"},
        },
        dialoguePool = "Farmer",
    },
}

-- Name pools for random generation (Amestrian/Germanic style)
OccupationData.Names = {
    -- Male names
    "Heinrich", "Wilhelm", "Fritz", "Klaus", "Otto",
    "Hans", "Erich", "Ludwig", "Karl", "Ernst",
    "Rolf", "Werner", "Dieter", "Helmut", "Gunther",
    -- Female names
    "Maria", "Rosa", "Anna", "Greta", "Elsa",
    "Helga", "Ingrid", "Liesel", "Marta", "Frieda",
    "Ursula", "Gerda", "Hilda", "Brigitte", "Renate",
}

-- Personality types affect dialogue tone and relationship gain rate
OccupationData.Personalities = {
    Friendly = {
        prefix = "Oh, hello there! ",
        farewell = "Take care, buddy!",
        modifier = 1.2, -- +20% relationship gain
    },
    Grumpy = {
        prefix = "What do you want? ",
        farewell = "Finally, some peace...",
        modifier = 0.8, -- -20% relationship gain
    },
    Nervous = {
        prefix = "O-oh! You startled me... ",
        farewell = "S-stay safe out there...",
        modifier = 1.0,
    },
    Professional = {
        prefix = "Good day. ",
        farewell = "Until next time.",
        modifier = 1.0,
    },
    Curious = {
        prefix = "Hmm, interesting... ",
        farewell = "I hope to hear more from you!",
        modifier = 1.1, -- +10% relationship gain
    },
}

-- Relationship tier thresholds
OccupationData.RelationshipTiers = {
    { name = "Stranger", min = 0, max = 19, color = Color3.fromRGB(150, 150, 150) },
    { name = "Acquaintance", min = 20, max = 39, color = Color3.fromRGB(255, 255, 255) },
    { name = "Friend", min = 40, max = 59, color = Color3.fromRGB(100, 200, 255) },
    { name = "Close Friend", min = 60, max = 79, color = Color3.fromRGB(255, 200, 50) },
    { name = "Trusted", min = 80, max = 100, color = Color3.fromRGB(200, 100, 255) },
}

-- Daily interaction limit per NPC
OccupationData.DAILY_INTERACTION_LIMIT = 5

-- Quest chance at Trusted tier
OccupationData.QUEST_CHANCE = 0.25

-- Relationship change values
OccupationData.RELATIONSHIP_GAIN_PER_INTERACTION = 5
OccupationData.RELATIONSHIP_LOSS_PER_HIT = 8
OccupationData.HITS_TO_FLEE = 4
OccupationData.FLEE_DURATION = 8 -- seconds

-- Generate a random NPC identity
function OccupationData.generateRandomIdentity(): {name: string, occupation: string, occupationType: string, personality: string}
    -- 30% military, 70% civilian
    local isMilitary = math.random() < 0.3
    local pool = isMilitary and OccupationData.Military or OccupationData.Civilian

    -- Get all occupation names from the pool
    local occupationNames = {}
    for name in pairs(pool) do
        table.insert(occupationNames, name)
    end

    -- Pick random occupation
    local occupation = occupationNames[math.random(#occupationNames)]

    -- Pick random personality
    local personalityNames = {}
    for name in pairs(OccupationData.Personalities) do
        table.insert(personalityNames, name)
    end
    local personality = personalityNames[math.random(#personalityNames)]

    -- Pick random name
    local name = OccupationData.Names[math.random(#OccupationData.Names)]

    return {
        name = name,
        occupation = occupation,
        occupationType = isMilitary and "Military" or "Civilian",
        personality = personality,
    }
end

-- Get relationship tier from numeric value
function OccupationData.getTier(value: number): string
    if value >= 80 then
        return "Trusted"
    elseif value >= 60 then
        return "Close Friend"
    elseif value >= 40 then
        return "Friend"
    elseif value >= 20 then
        return "Acquaintance"
    else
        return "Stranger"
    end
end

-- Get tier color for UI display
function OccupationData.getTierColor(tier: string): Color3
    for _, tierData in ipairs(OccupationData.RelationshipTiers) do
        if tierData.name == tier then
            return tierData.color
        end
    end
    return Color3.fromRGB(150, 150, 150) -- Default gray
end

-- Get available favors for an NPC at a given relationship tier
function OccupationData.getAvailableFavors(occupation: string, occupationType: string, tier: string): {string}
    local pool = occupationType == "Military" and OccupationData.Military or OccupationData.Civilian
    local occupationData = pool[occupation]

    if not occupationData or not occupationData.favors then
        return {}
    end

    return occupationData.favors[tier] or {}
end

-- Get occupation description
function OccupationData.getDescription(occupation: string, occupationType: string): string
    local pool = occupationType == "Military" and OccupationData.Military or OccupationData.Civilian
    local occupationData = pool[occupation]

    if occupationData then
        return occupationData.description
    end
    return "A citizen of Amestris."
end

-- Get personality data
function OccupationData.getPersonality(personality: string): {prefix: string, farewell: string, modifier: number}
    return OccupationData.Personalities[personality] or OccupationData.Personalities.Professional
end

return OccupationData
