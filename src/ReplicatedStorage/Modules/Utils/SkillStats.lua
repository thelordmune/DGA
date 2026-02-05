-- Client-side skill stats data extracted from ServerStorage._Skills
-- Contains Damage, Cooldown, Augments, and Junction data for each skill
-- Junction chances are intentionally very low (0.5-1%) - limb loss is a rare event

local SkillStats = {
	-- Spear Skills
	["Needle Thrust"] = {
		Damage = 3.5,
		Cooldown = 0,
		Augments = 0,
		Junction = "Random",
		JunctionChance = 0.005, -- 0.5%
	},
	["Grand Cleave"] = {
		Damage = 6,
		Cooldown = 0,
		Augments = 0,
		Junction = "Random",
		JunctionChance = 0.01, -- 1% final hit
	},
	["WhirlWind"] = {
		Damage = 4,
		Cooldown = 0,
		Augments = 0,
		Junction = "Random",
		JunctionChance = 0.005, -- 0.5%
	},
	["Rapid Thrust"] = {
		Damage = 10,
		Cooldown = 0,
		Augments = 0,
		Junction = "Random",
		JunctionChance = 0.01, -- 1% slam final hit
	},
	["Charged Thrust"] = {
		Damage = 4,
		Cooldown = 0,
		Augments = 0,
		Junction = "Random",
		JunctionChance = 0.01, -- 1%
	},
	-- Guns Skills
	["Shell Piercer"] = {
		Damage = 3.5,
		Cooldown = 0,
		Augments = 0,
		Junction = "Random",
		JunctionChance = 0.005, -- 0.5%
	},
	["Strategist Combination"] = {
		Damage = 3.5,
		Cooldown = 0,
		Augments = 0,
		Junction = "Random",
		JunctionChance = 0.005, -- 0.5%
	},
	["Inverse Slide"] = {
		Damage = 1.5,
		Cooldown = 0,
		Augments = 0,
		Junction = "RandomLeg",
		JunctionChance = 0.005, -- 0.5%
	},
	["Tapdance"] = {
		Damage = 8,
		Cooldown = 0,
		Augments = 0,
		Junction = "RandomLeg",
		JunctionChance = 0.01, -- 1% final hit
	},
	["Hellraiser"] = {
		Damage = 8,
		Cooldown = 0,
		Augments = 0,
		Junction = "Random",
		JunctionChance = 0.01, -- 1% final hit
	},
	-- Fist Skills
	["Downslam Kick"] = {
		Damage = 9,
		Cooldown = 0,
		Augments = 0,
		Junction = "Random",
		JunctionChance = 0.01, -- 1%
	},
	["Axe Kick"] = {
		Damage = 7,
		Cooldown = 0,
		Augments = 0,
		Junction = "RandomLeg",
		JunctionChance = 0.01, -- 1%
	},
	["Pincer Impact"] = {
		Damage = 9,
		Cooldown = 0,
		Augments = 0,
		Junction = "RandomArm",
		JunctionChance = 0.01, -- 1%
	},
	["Triple Kick"] = {
		Damage = 3.5,
		Cooldown = 0,
		Augments = 0,
		Junction = "RandomLeg",
		JunctionChance = 0.005, -- 0.5%
	},
}

-- Get stats for a skill
local function GetStats(skillName: string)
	if SkillStats[skillName] then
		return SkillStats[skillName]
	end
	return {Damage = 0, Cooldown = 0, Augments = 0}
end

return {
	GetStats = GetStats,
	Data = SkillStats,
}
