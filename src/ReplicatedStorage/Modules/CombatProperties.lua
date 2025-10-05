--[[
    Combat Properties System

    Defines tactical properties for all skills in the game.
    Used by NPCs to make intelligent combat decisions.

    NOTE: This does NOT use Skill_Data. NPCs use the same Combat system as players
    (Combat.Light, Combat.Critical, etc.) These properties are ONLY for AI decision-making.
]]

local CombatProperties = {}

-- Combat property template
--[[
CombatProperties = {
    SkillType = "Offensive", -- "Offensive" | "Defensive" | "Movement" | "Retreating"
    RangeType = "Close", -- "Close" | "Medium" | "Long"
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 10,
        OptimalRange = 5,
    },
    ComboProperties = {
        IsComboStarter = false,
        IsComboEnder = false,
        FollowupWindow = 0.5,
    },
    DashProperty = nil, -- nil | "Forward" | "Back" | "Side"
    SkillPriority = 0, -- Higher = more likely to use (for AI decision-making)
}
]]

-- BASIC COMBAT
CombatProperties["M1"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 3,  -- Increased from 0 to maintain spacing
        MaxRange = 10, -- Increased from 8
        OptimalRange = 6, -- Increased from 5
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = false,
        FollowupWindow = 0.5,
    },
    DashProperty = nil,
    SkillPriority = 10, -- High priority - bread and butter
}

CombatProperties["M2"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 3,  -- Increased from 0 to maintain spacing
        MaxRange = 10, -- Increased from 8
        OptimalRange = 6, -- Increased from 5
    },
    ComboProperties = {
        IsComboStarter = false,
        IsComboEnder = true,
        FollowupWindow = 0,
    },
    DashProperty = nil,
    SkillPriority = 7, -- Medium-high priority
}

CombatProperties["Block"] = {
    SkillType = "Defensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 15,
        OptimalRange = 5,
    },
    ComboProperties = {
        IsComboStarter = false,
        IsComboEnder = false,
        FollowupWindow = 0,
    },
    DashProperty = nil,
    SkillPriority = 15, -- Very high when enemy is attacking
}

CombatProperties["Critical"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 4,  -- Increased from 0 to maintain spacing
        MaxRange = 14, -- Increased from 12
        OptimalRange = 9, -- Increased from 8
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 0.3,
    },
    DashProperty = "Forward",
    SkillPriority = 12, -- High priority special attack
}

-- MOVEMENT
CombatProperties["Dash"] = {
    SkillType = "Movement",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 20,
        OptimalRange = 10,
    },
    ComboProperties = {
        IsComboStarter = false,
        IsComboEnder = false,
        FollowupWindow = 0.3,
    },
    DashProperty = "Forward",
    SkillPriority = 8, -- Medium priority for repositioning
}

-- SPEAR SKILLS
CombatProperties["Needle Thrust"] = {
    SkillType = "Offensive",
    RangeType = "Medium",
    TargetingProperties = {
        MinRange = 5,
        MaxRange = 15,
        OptimalRange = 10,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = false,
        FollowupWindow = 0.6,
    },
    DashProperty = "Forward",
    SkillPriority = 11, -- High priority gap closer
}

CombatProperties["Grand Cleave"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 10,
        OptimalRange = 6,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 0.8,
    },
    DashProperty = nil,
    SkillPriority = 13, -- Very high priority - powerful combo
}

-- GUN SKILLS
CombatProperties["Shell Piercer"] = {
    SkillType = "Offensive",
    RangeType = "Long",
    TargetingProperties = {
        MinRange = 10,
        MaxRange = 40,
        OptimalRange = 25,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 0.5,
    },
    DashProperty = nil,
    SkillPriority = 14, -- Very high priority ranged attack
}

CombatProperties["Strategist Combination"] = {
    SkillType = "Offensive",
    RangeType = "Medium",
    TargetingProperties = {
        MinRange = 5,
        MaxRange = 20,
        OptimalRange = 12,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 1.0,
    },
    DashProperty = nil,
    SkillPriority = 15, -- Very high priority - complex combo
}

-- FIST SKILLS
CombatProperties["Downslam Kick"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 8,
        OptimalRange = 5,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = false,
        FollowupWindow = 0.7,
    },
    DashProperty = nil,
    SkillPriority = 12, -- High priority close combat
}

CombatProperties["Axe Kick"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 8,
        OptimalRange = 5,
    },
    ComboProperties = {
        IsComboStarter = false,
        IsComboEnder = true,
        FollowupWindow = 0.5,
    },
    DashProperty = nil,
    SkillPriority = 11, -- High priority - guard break
}

CombatProperties["Pincer Impact"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 8,
        OptimalRange = 5,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 0.8,
    },
    DashProperty = nil,
    SkillPriority = 13, -- High priority - powerful combo skill
}

-- BOXING SKILLS
CombatProperties["Jab Rush"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 7,
        OptimalRange = 4,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = false,
        FollowupWindow = 0.6,
    },
    DashProperty = nil,
    SkillPriority = 10, -- Medium-high priority
}

CombatProperties["Gazelle Punch"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 3,
        MaxRange = 10,
        OptimalRange = 6,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = false,
        FollowupWindow = 0.5,
    },
    DashProperty = "Forward",
    SkillPriority = 11, -- High priority gap closer
}

CombatProperties["Dempsey Roll"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 8,
        OptimalRange = 5,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 1.0,
    },
    DashProperty = nil,
    SkillPriority = 14, -- Very high priority - ultimate move
}

-- BRAWLER SKILLS
CombatProperties["Rising Wind"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 10,
        OptimalRange = 6,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 0.6,
    },
    DashProperty = nil,
    SkillPriority = 12, -- High priority
}

-- ALCHEMY SKILLS - BASIC
CombatProperties["Construct"] = {
    SkillType = "Defensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 15,
        OptimalRange = 8,
    },
    ComboProperties = {
        IsComboStarter = false,
        IsComboEnder = false,
        FollowupWindow = 0.5,
    },
    DashProperty = nil,
    SkillPriority = 9, -- Medium priority - defensive wall
}

CombatProperties["Deconstruct"] = {
    SkillType = "Offensive",
    RangeType = "Medium",
    TargetingProperties = {
        MinRange = 5,
        MaxRange = 20,
        OptimalRange = 12,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = false,
        FollowupWindow = 0.6,
    },
    DashProperty = nil,
    SkillPriority = 10, -- Medium-high priority
}

CombatProperties["AlchemicAssault"] = {
    SkillType = "Offensive",
    RangeType = "Medium",
    TargetingProperties = {
        MinRange = 5,
        MaxRange = 25,
        OptimalRange = 15,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 0.8,
    },
    DashProperty = nil,
    SkillPriority = 13, -- High priority - complex attack
}

-- STONE ALCHEMY
CombatProperties["Cascade"] = {
    SkillType = "Offensive",
    RangeType = "Medium",
    TargetingProperties = {
        MinRange = 5,
        MaxRange = 20,
        OptimalRange = 12,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 0.7,
    },
    DashProperty = nil,
    SkillPriority = 12, -- High priority area attack
}

CombatProperties["Rock Skewer"] = {
    SkillType = "Offensive",
    RangeType = "Medium",
    TargetingProperties = {
        MinRange = 3,
        MaxRange = 18,
        OptimalRange = 10,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = false,
        FollowupWindow = 0.6,
    },
    DashProperty = nil,
    SkillPriority = 11, -- High priority ground attack
}

CombatProperties["Stone Lance"] = {
    SkillType = "Offensive",
    RangeType = "Medium",
    TargetingProperties = {
        MinRange = 5,
        MaxRange = 30,
        OptimalRange = 15,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 0.8,
    },
    DashProperty = nil,
    SkillPriority = 13, -- High priority - targets nearest enemy with stone spike
}

-- FLAME ALCHEMY
CombatProperties["Cinder"] = {
    SkillType = "Offensive",
    RangeType = "Long",
    TargetingProperties = {
        MinRange = 8,
        MaxRange = 30,
        OptimalRange = 18,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = false,
        FollowupWindow = 0.7,
    },
    DashProperty = nil,
    SkillPriority = 13, -- High priority ranged
}

CombatProperties["Firestorm"] = {
    SkillType = "Offensive",
    RangeType = "Medium",
    TargetingProperties = {
        MinRange = 5,
        MaxRange = 22,
        OptimalRange = 14,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 0.9,
    },
    DashProperty = nil,
    SkillPriority = 14, -- Very high priority - powerful AOE
}

return CombatProperties

