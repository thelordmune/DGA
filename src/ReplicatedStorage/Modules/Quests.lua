return {
    ["Magnus"] = {
        ["Missing Pocketwatch"] = {
            ["Description"] = "Find Magnus' pocketwatch at one of the stands in central city, be careful not to make any trouble",
            ["Rewards"] = {
                ["Items"] = {
                    ["Library Pass"] = 1
                },
                ["Experience"] = math.random(70, 120),
                ["Alignment"] = 1
            }
        }
    },
    ["Sam"] = {
        ["Nen Awakening"] = {
            ["Description"] = "Sam has given you a sacred cup. Head to the meditation point and drink from it to awaken your Nen.",
            ["Rewards"] = {
                ["Items"] = {},
                ["Experience"] = math.random(100, 150),
                ["Alignment"] = 2
            }
        }
    },
    ["Librarian"] = {
        ["Explore"] = {
            ["Description"] = "Find out what knowledge the library has to give you.",
            ["Rewards"] = {
                ["Items"] = {},
                ["Experience"] = math.random(50, 100),
                ["Alignment"] = 1
            }
        }
    },

    -- System-generated quest for jail escape
    ["System"] = {
        ["Escape"] = {
            ["Description"] = "A prisoner has escaped! Find a way out of Central Command HQ.",
            ["Rewards"] = {
                ["Items"] = {},
                ["Experience"] = 0,
                ["Alignment"] = -5 -- Negative alignment for escaping
            },
            ["SystemQuest"] = true, -- Flag to indicate this is auto-assigned
            ["HideFromNPC"] = true, -- Don't show in NPC dialogue
        }
    }

}