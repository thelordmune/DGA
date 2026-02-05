--[[
    Combat Properties System - STRIPPED DOWN VERSION
    
    Only basic combat and fist skills remain.
    Weapon skills (Spear, Guns) removed - keeping only Fist combat
    Alchemy skills removed - Hunter x Hunter Nen system will replace this
]]

local CombatProperties = {}

-- BASIC COMBAT
CombatProperties["M1"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 12,
        OptimalRange = 5,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = false,
        FollowupWindow = 0.5,
    },
    DashProperty = nil,
    SkillPriority = 10,
    IsGuardBreak = false,
    IsComboExtender = true,
    HasHyperArmor = false,
}

CombatProperties["M2"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 12,
        OptimalRange = 6,
    },
    ComboProperties = {
        IsComboStarter = false,
        IsComboEnder = true,
        FollowupWindow = 0,
    },
    DashProperty = nil,
    SkillPriority = 7,
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
    SkillPriority = 15,
    IsGuardBreak = false,
    IsComboExtender = false,
    HasHyperArmor = false,
}

CombatProperties["Critical"] = {
    SkillType = "Offensive",
    RangeType = "Close",
    TargetingProperties = {
        MinRange = 0,
        MaxRange = 12,
        OptimalRange = 6,
    },
    ComboProperties = {
        IsComboStarter = false,
        IsComboEnder = true,
        FollowupWindow = 0,
    },
    DashProperty = nil,
    SkillPriority = 7,
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
    SkillPriority = 12,
    IsGuardBreak = false,
    IsComboExtender = true,
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
    SkillPriority = 11,
    IsGuardBreak = true,
    IsComboExtender = false,
    HasHyperArmor = false,
}

CombatProperties["Triple Kick"] = {
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
        FollowupWindow = 0.6,
    },
    DashProperty = nil,
    SkillPriority = 11,
    IsGuardBreak = false,
    IsComboExtender = true,
    HasHyperArmor = false,
}

return CombatProperties

