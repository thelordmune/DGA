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

    -- NEW: Tactical properties for NPC decision-making
    IsGuardBreak = false, -- Can break through blocks
    IsComboExtender = false, -- Works well on ragdolled/knocked targets
    HasHyperArmor = false, -- Has hyper armor during execution
}
]]

-- BASIC COMBAT
CombatProperties["M1"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,  -- Allow close combat
        MaxRange = 12, -- Extended range
        OptimalRange = 5, -- Sweet spot for melee
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = false,
        FollowupWindow = 0.5,
    },
    DashProperty = nil,
    SkillPriority = 10, -- High priority - bread and butter
    IsGuardBreak = false,
    IsComboExtender = true, -- M1s work great on ragdolled targets
    HasHyperArmor = false,
}

CombatProperties["M2"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,  -- Allow close combat
        MaxRange = 12, -- Extended range
        OptimalRange = 6, -- Sweet spot for critical
    },
    ComboProperties = {
        IsComboStarter = false,
        IsComboEnder = true,
        FollowupWindow = 0,
    },
    DashProperty = nil,
    SkillPriority = 7, -- Medium-high priority
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
}

CombatProperties["Critical"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,  -- Allow close combat
        MaxRange = 15, -- Extended range for dash attack
        OptimalRange = 8, -- Sweet spot for critical
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 0.3,
    },
    DashProperty = "Forward",
    SkillPriority = 12, -- High priority special attack
    IsGuardBreak = true, -- Critical breaks blocks
    IsComboExtender = true, -- Works great on ragdolled targets
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = true, -- Has hyper armor during dash
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = true, -- Has hyper armor during spin
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = true, -- Great for juggling ragdolled targets
    HasHyperArmor = false,
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
    IsGuardBreak = true, -- Axe Kick breaks blocks
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = true, -- Excellent for ragdolled targets
    HasHyperArmor = true, -- Has hyper armor during execution
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
    IsGuardBreak = false,
    IsComboExtender = true, -- Good for comboing ragdolled targets
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = true, -- Has hyper armor during dash
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = true, -- Has hyper armor during roll
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
    IsGuardBreak = false,
    IsComboExtender = true, -- Good for juggling
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
}

CombatProperties["Sky Arc"] = {
    SkillType = "Utility",
    RangeType = "Medium",
    TargetingProperties = {
        MinRange = 10,
        MaxRange = 40,
        OptimalRange = 25,
    },
    ComboProperties = {
        IsComboStarter = false,
        IsComboEnder = false,
        FollowupWindow = 0.5,
    },
    DashProperty = nil,
    SkillPriority = 8, -- Medium priority - mobility/utility
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
}

CombatProperties["Branch"] = {
    SkillType = "Offensive",
    RangeType = "Medium",
    TargetingProperties = {
        MinRange = 10,
        MaxRange = 50,
        OptimalRange = 25,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 0.8,
    },
    DashProperty = nil,
    SkillPriority = 12, -- High priority - converging rock paths
    IsGuardBreak = true, -- FIXED: Branch should break blocks
    IsComboExtender = false,
    HasHyperArmor = false,
}

CombatProperties["Ground Decay"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 20,
        OptimalRange = 10,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = true,
        FollowupWindow = 1.0,
    },
    DashProperty = nil,
    SkillPriority = 11, -- High priority - AOE expanding craters
    IsGuardBreak = true, -- FIXED: Ground Decay should break blocks
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
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
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
}

return CombatProperties

