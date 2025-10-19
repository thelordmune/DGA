-- Client-side skill stats data extracted from ServerStorage._Skills
-- Only contains Damage, Cooldown, and Augments for each skill

local SkillStats = {
	["Needle Thrust"] = {
		Damage = 3.5,
		Cooldown = 0,
		Augments = 0,
	},
	["Grand Cleave"] = {
		Damage = 6,
		Cooldown = 0,
		Augments = 0,
	},
	["Shell Piercer"] = {
		Damage = 3.5,
		Cooldown = 0,
		Augments = 0,
	},
	["Strategist Combination"] = {
		Damage = 3.5,
		Cooldown = 0,
		Augments = 0,
	},
	["Downslam Kick"] = {
		Damage = 9,
		Cooldown = 0,
		Augments = 0,
	},
	["Axe Kick"] = {
		Damage = 7,
		Cooldown = 0,
		Augments = 0,
	},
	["Pincer Impact"] = {
		Damage = 9,
		Cooldown = 0,
		Augments = 0,
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

