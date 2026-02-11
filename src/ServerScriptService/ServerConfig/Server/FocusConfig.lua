--[[
	FocusConfig - Focus System Tuning Constants
	Server-only. All focus gain/loss amounts, training, modes, and bonuses.

	Consumed by: FocusHandler.lua, focus_system.luau
]]

local FocusConfig = {

	-- ============================================
	-- FOCUS AMOUNTS
	-- ============================================
	Amounts = {
		-- Good actions (gain focus)
		M1_HIT = 6,
		COMBO_BONUS = 8, -- extra at combo 3+
		SKILL_HIT = 12,
		PARRY_SUCCESS = 15,
		DODGE_SUCCESS = 8,

		-- Bad actions (lose focus)
		WHIFF_ATTACK = 3,
		WHIFF_PARRY = 2,
		GOT_PARRIED = 4,
		LIGHT_DAMAGE = 2,
		HEAVY_DAMAGE = 5, -- triggered when hit > 10% max HP

		-- Per-second decay rates (applied in focus_system.luau)
		PASSIVE_DECAY = 0.3,
		RUNNING_IN_COMBAT = 0.5,
		BLOCKING_IN_COMBAT = 0.5,
	},

	-- ============================================
	-- TRAINING LEVELS
	-- ============================================
	TrainingLevels = {
		[0] = { xp = 0,     max = 50,  floor = 0  },
		[1] = { xp = 1000,  max = 55,  floor = 5  },
		[2] = { xp = 3000,  max = 60,  floor = 10 },
		[3] = { xp = 6000,  max = 65,  floor = 15 },
		[4] = { xp = 10000, max = 70,  floor = 20 },
		[5] = { xp = 16000, max = 75,  floor = 25 },
		[6] = { xp = 25000, max = 80,  floor = 30 },
		[7] = { xp = 36000, max = 90,  floor = 35 },
		[8] = { xp = 50000, max = 100, floor = 40 },
	},
	MaxTrainingLevel = 8,

	-- XP multiplier for training from good actions
	TrainingXPMultiplier = 0.5,

	-- XP from natural decay while having focus (per second)
	DecayTrainingXPPerSecond = 0.1,

	-- ============================================
	-- ABSOLUTE FOCUS
	-- ============================================
	AbsoluteFocusIFrameDuration = 0.5,
	AbsoluteFocusModeDuration = 0.5,

	-- ============================================
	-- MINI MODE
	-- ============================================
	MiniModeThreshold = 0.5, -- 50% of max focus

	-- ============================================
	-- FOCUS BONUSES
	-- ============================================
	HPRegen = {
		At50Percent = 0.3,
		At75Percent = 0.5,
		At100Percent = 1.0,
	},
	NenDrainReduction = {
		At50Percent = 0.20,
		At75Percent = 0.35,
		At100Percent = 0.50,
	},

	-- ============================================
	-- SYNC / SAVE RATES
	-- ============================================
	SyncInterval = 0.1, -- 10Hz client sync
	TrainingSaveInterval = 60, -- save training every 60s

	-- ============================================
	-- VOICELINES (Absolute Focus)
	-- ============================================
	Voicelines = {
		"Don't hesitate to kill.",
		"Very well...",
		"I'll give you all I got.",
		"Nah, I'd win.",
	},
}

return table.freeze(FocusConfig)
