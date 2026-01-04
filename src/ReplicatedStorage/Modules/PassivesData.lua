--[[
	PassivesData - FMA-themed Passive Skill Tree System

	Inspired by Path of Exile's passive system, this creates a complex
	skill tree for a Fullmetal Alchemist-inspired roguelike RPG.

	Requirements can include:
	- prerequisitePassives: List of passives that must be unlocked first
	- weapon: Specific weapon type required (Fist, Sword, Spear, Guns, etc.)
	- stats: Minimum attribute values required (Knowledge, Potency, Dexerity, Strange, Vibrance)
	- level: Minimum player level
	- alchemy: Specific alchemy type required (Flame, Ice, Lightning, Stone, etc.)
]]

local PassivesData = {}

-- Page categories for organization
PassivesData.Pages = {
	"Combat",      -- General combat passives
	"Fist",        -- Fist/unarmed weapon passives
	"Spear",       -- Spear/polearm weapon passives
	"Guns",        -- Firearm weapon passives
	"Flame",       -- Flame alchemy passives
	"Stone",       -- Stone/Earth alchemy passives
	"Defense",     -- Defensive passives
	"Utility",     -- Utility and support passives
}

-- Rarity/tier system
PassivesData.Tiers = {
	MINOR = { color = Color3.fromRGB(180, 180, 180), cost = 1 },
	NOTABLE = { color = Color3.fromRGB(100, 200, 255), cost = 2 },
	KEYSTONE = { color = Color3.fromRGB(255, 180, 50), cost = 4 },
	LEGENDARY = { color = Color3.fromRGB(200, 50, 255), cost = 6 },
}

-- All passives in the tree, organized by page/category
PassivesData.Passives = {
	-- ============================================
	-- COMBAT PAGE - General combat passives
	-- ============================================

	["Warrior's Resolve"] = {
		id = "warrior_resolve",
		tier = "MINOR",
		category = "Combat",
		description = "Steel your mind for battle. +5% Physical damage.",
		effects = {
			physicalDamage = 0.05,
		},
		requirements = {},
	},

	["Kinetic Redirection"] = {
		id = "kinetic_redirection",
		tier = "NOTABLE",
		category = "Combat",
		description = "Redirect incoming force into your strikes. Blocked attacks grant +10% damage for 3s.",
		effects = {
			onBlockDamageBoost = 0.10,
			onBlockDuration = 3,
		},
		requirements = {
			prerequisitePassives = {"Warrior's Resolve"},
		},
	},

	["Battle Hardened"] = {
		id = "battle_hardened",
		tier = "MINOR",
		category = "Combat",
		description = "Experience breeds strength. +3% damage per 10 kills (max 15%).",
		effects = {
			killStackDamage = 0.03,
			maxKillStacks = 5,
		},
		requirements = {},
	},

	["Momentum"] = {
		id = "momentum",
		tier = "NOTABLE",
		category = "Combat",
		description = "Keep moving, keep fighting. +8% damage while sprinting.",
		effects = {
			sprintDamageBonus = 0.08,
		},
		requirements = {
			prerequisitePassives = {"Battle Hardened"},
		},
	},

	["Berserker's Fury"] = {
		id = "berserker_fury",
		tier = "KEYSTONE",
		category = "Combat",
		description = "Pain fuels your rage. Deal +2% more damage for each 10% missing health.",
		effects = {
			lowHealthDamageBonus = 0.02,
		},
		requirements = {
			prerequisitePassives = {"Kinetic Redirection", "Momentum"},
			stats = { Potency = 8 },
			level = 10,
		},
	},

	["Critical Eye"] = {
		id = "critical_eye",
		tier = "MINOR",
		category = "Combat",
		description = "Spot weaknesses in your enemies. +5% critical hit chance.",
		effects = {
			critChance = 0.05,
		},
		requirements = {},
	},

	["Devastating Blows"] = {
		id = "devastating_blows",
		tier = "NOTABLE",
		category = "Combat",
		description = "Your criticals hit harder. +25% critical damage.",
		effects = {
			critDamage = 0.25,
		},
		requirements = {
			prerequisitePassives = {"Critical Eye"},
		},
	},

	["Executioner"] = {
		id = "executioner",
		tier = "KEYSTONE",
		category = "Combat",
		description = "Finish what you start. +30% damage to enemies below 30% health.",
		effects = {
			executeThreshold = 0.30,
			executeDamage = 0.30,
		},
		requirements = {
			prerequisitePassives = {"Devastating Blows"},
			stats = { Potency = 6, Dexerity = 4 },
			level = 12,
		},
	},

	["Combo Master"] = {
		id = "combo_master",
		tier = "NOTABLE",
		category = "Combat",
		description = "Chain attacks together flawlessly. +3% damage per consecutive hit (max 5 stacks).",
		effects = {
			comboBonus = 0.03,
			comboMaxStacks = 5,
		},
		requirements = {
			prerequisitePassives = {"Warrior's Resolve"},
		},
	},

	["Relentless Assault"] = {
		id = "relentless_assault",
		tier = "KEYSTONE",
		category = "Combat",
		description = "Never stop attacking. +15% attack speed, -10% damage.",
		effects = {
			attackSpeed = 0.15,
			physicalDamage = -0.10,
		},
		requirements = {
			prerequisitePassives = {"Combo Master"},
			stats = { Dexerity = 8 },
			level = 15,
		},
	},

	-- ============================================
	-- FIST PAGE - Unarmed combat passives
	-- ============================================

	["Bare Knuckle Brawler"] = {
		id = "bare_knuckle_brawler",
		tier = "MINOR",
		category = "Fist",
		description = "Your fists are your weapons. +8% unarmed damage.",
		effects = {
			unarmedDamage = 0.08,
		},
		requirements = {
			weapon = "Fist",
		},
	},

	["Triple Kick Mastery"] = {
		id = "triple_kick_mastery",
		tier = "NOTABLE",
		category = "Fist",
		description = "Perfect the Triple Kick technique. Triple Kick deals +15% damage and has reduced recovery.",
		effects = {
			tripleKickDamage = 0.15,
			tripleKickRecovery = -0.20,
		},
		requirements = {
			prerequisitePassives = {"Bare Knuckle Brawler"},
			weapon = "Fist",
		},
	},

	["Axe Kick Devastation"] = {
		id = "axe_kick_devastation",
		tier = "NOTABLE",
		category = "Fist",
		description = "Bring down the hammer. Axe Kick deals +20% damage and has increased stun duration.",
		effects = {
			axeKickDamage = 0.20,
			axeKickStun = 0.25,
		},
		requirements = {
			prerequisitePassives = {"Bare Knuckle Brawler"},
			weapon = "Fist",
		},
	},

	["Downslam Authority"] = {
		id = "downslam_authority",
		tier = "NOTABLE",
		category = "Fist",
		description = "Ground your enemies. Downslam Kick creates a small shockwave on impact.",
		effects = {
			downslamShockwave = true,
			downslamDamage = 0.15,
		},
		requirements = {
			prerequisitePassives = {"Axe Kick Devastation"},
			weapon = "Fist",
		},
	},

	["Pincer Impact Perfection"] = {
		id = "pincer_impact_perfection",
		tier = "KEYSTONE",
		category = "Fist",
		description = "Like the Hawk's Eye. Pincer Impact has 20% chance to instantly break posture.",
		effects = {
			pincerPostureBreak = 0.20,
			pincerDamage = 0.25,
		},
		requirements = {
			prerequisitePassives = {"Downslam Authority", "Triple Kick Mastery"},
			weapon = "Fist",
			stats = { Potency = 6, Dexerity = 6 },
			level = 12,
		},
	},

	["Automail Reinforcement"] = {
		id = "automail_reinforcement",
		tier = "KEYSTONE",
		category = "Fist",
		description = "Your limbs have been replaced with superior mechanical parts. +25% attack speed, but -15% alchemical damage.",
		effects = {
			attackSpeed = 0.25,
			alchemicalDamage = -0.15,
		},
		requirements = {
			prerequisitePassives = {"Pincer Impact Perfection"},
			weapon = "Fist",
			stats = { Dexerity = 8 },
			level = 15,
		},
	},

	["Iron Fist"] = {
		id = "iron_fist",
		tier = "MINOR",
		category = "Fist",
		description = "Harden your strikes. +10% posture damage with unarmed attacks.",
		effects = {
			unarmedPostureDamage = 0.10,
		},
		requirements = {
			weapon = "Fist",
		},
	},

	["Counter Striker"] = {
		id = "counter_striker",
		tier = "NOTABLE",
		category = "Fist",
		description = "Turn defense into offense. After a perfect block, next attack deals +40% damage.",
		effects = {
			perfectBlockBonus = 0.40,
		},
		requirements = {
			prerequisitePassives = {"Iron Fist"},
			weapon = "Fist",
		},
	},

	["Flurry of Blows"] = {
		id = "flurry_of_blows",
		tier = "NOTABLE",
		category = "Fist",
		description = "Strike like lightning. +20% attack speed with unarmed attacks.",
		effects = {
			unarmedAttackSpeed = 0.20,
		},
		requirements = {
			prerequisitePassives = {"Bare Knuckle Brawler"},
			weapon = "Fist",
			stats = { Dexerity = 4 },
		},
	},

	["Martial Artist"] = {
		id = "martial_artist",
		tier = "LEGENDARY",
		category = "Fist",
		description = "True mastery of the body. All Fist moves deal +30% damage and cost 20% less energy.",
		effects = {
			fistMoveDamage = 0.30,
			fistEnergyCost = -0.20,
		},
		requirements = {
			prerequisitePassives = {"Automail Reinforcement", "Counter Striker"},
			weapon = "Fist",
			stats = { Potency = 8, Dexerity = 8 },
			level = 20,
		},
	},

	-- ============================================
	-- SPEAR PAGE - Polearm weapon passives
	-- ============================================

	["Spear Initiate"] = {
		id = "spear_initiate",
		tier = "MINOR",
		category = "Spear",
		description = "The way of the polearm. +8% spear damage.",
		effects = {
			spearDamage = 0.08,
		},
		requirements = {
			weapon = "Spear",
		},
	},

	["Needle Thrust Precision"] = {
		id = "needle_thrust_precision",
		tier = "NOTABLE",
		category = "Spear",
		description = "Strike true. Needle Thrust has +15% critical chance and ignores 10% armor.",
		effects = {
			needleThrustCrit = 0.15,
			needleThrustArmorPen = 0.10,
		},
		requirements = {
			prerequisitePassives = {"Spear Initiate"},
			weapon = "Spear",
		},
	},

	["Rapid Thrust Fury"] = {
		id = "rapid_thrust_fury",
		tier = "NOTABLE",
		category = "Spear",
		description = "Overwhelm with speed. Rapid Thrust attacks +25% faster and builds combo stacks.",
		effects = {
			rapidThrustSpeed = 0.25,
			rapidThrustCombo = true,
		},
		requirements = {
			prerequisitePassives = {"Spear Initiate"},
			weapon = "Spear",
		},
	},

	["Grand Cleave Power"] = {
		id = "grand_cleave_power",
		tier = "NOTABLE",
		category = "Spear",
		description = "Sweep through all. Grand Cleave hits in a wider arc and deals +20% damage.",
		effects = {
			grandCleaveDamage = 0.20,
			grandCleaveArc = 0.30,
		},
		requirements = {
			prerequisitePassives = {"Needle Thrust Precision"},
			weapon = "Spear",
		},
	},

	["Whirlwind Devastation"] = {
		id = "whirlwind_devastation",
		tier = "KEYSTONE",
		category = "Spear",
		description = "Become the storm. Whirlwind pulls enemies in and deals +25% damage.",
		effects = {
			whirlwindPull = true,
			whirlwindDamage = 0.25,
		},
		requirements = {
			prerequisitePassives = {"Grand Cleave Power", "Rapid Thrust Fury"},
			weapon = "Spear",
			stats = { Potency = 6 },
			level = 12,
		},
	},

	["Charged Thrust Mastery"] = {
		id = "charged_thrust_mastery",
		tier = "NOTABLE",
		category = "Spear",
		description = "Power builds with patience. Charged Thrust deals +35% damage and has longer range.",
		effects = {
			chargedThrustDamage = 0.35,
			chargedThrustRange = 0.20,
		},
		requirements = {
			prerequisitePassives = {"Needle Thrust Precision"},
			weapon = "Spear",
			stats = { Potency = 4 },
		},
	},

	["Reach Advantage"] = {
		id = "reach_advantage",
		tier = "MINOR",
		category = "Spear",
		description = "Keep enemies at bay. +15% attack range with spears.",
		effects = {
			spearRange = 0.15,
		},
		requirements = {
			weapon = "Spear",
		},
	},

	["Impaling Strike"] = {
		id = "impaling_strike",
		tier = "NOTABLE",
		category = "Spear",
		description = "Pin them down. Spear attacks have 15% chance to apply Impaled (slow + bleed).",
		effects = {
			impaleChance = 0.15,
		},
		requirements = {
			prerequisitePassives = {"Reach Advantage"},
			weapon = "Spear",
		},
	},

	["Polearm Mastery"] = {
		id = "polearm_mastery",
		tier = "LEGENDARY",
		category = "Spear",
		description = "The spear becomes an extension of your soul. All Spear moves deal +35% damage.",
		effects = {
			allSpearDamage = 0.35,
			spearPostureDamage = 0.20,
		},
		requirements = {
			prerequisitePassives = {"Whirlwind Devastation", "Charged Thrust Mastery"},
			weapon = "Spear",
			stats = { Potency = 8, Dexerity = 6 },
			level = 20,
		},
	},

	-- ============================================
	-- GUNS PAGE - Firearm weapon passives
	-- ============================================

	["Marksman"] = {
		id = "marksman",
		tier = "MINOR",
		category = "Guns",
		description = "Steady aim, deadly shot. +8% gun damage.",
		effects = {
			gunDamage = 0.08,
		},
		requirements = {
			weapon = "Guns",
		},
	},

	["Inverse Slide Expertise"] = {
		id = "inverse_slide_expertise",
		tier = "NOTABLE",
		category = "Guns",
		description = "Move and shoot. Inverse Slide grants +20% damage and immunity during slide.",
		effects = {
			inverseSlideDamage = 0.20,
			inverseSlideImmunity = true,
		},
		requirements = {
			prerequisitePassives = {"Marksman"},
			weapon = "Guns",
		},
	},

	["Tapdance Rhythm"] = {
		id = "tapdance_rhythm",
		tier = "NOTABLE",
		category = "Guns",
		description = "Dance with death. Tapdance builds stacks that increase damage by 5% per stack (max 6).",
		effects = {
			tapdanceStacks = 6,
			tapdanceStackDamage = 0.05,
		},
		requirements = {
			prerequisitePassives = {"Marksman"},
			weapon = "Guns",
		},
	},

	["Strategist Combination"] = {
		id = "strategist_combination_passive",
		tier = "KEYSTONE",
		category = "Guns",
		description = "Like Hawkeye herself. Strategist Combination chains perfectly, +40% damage on full combo.",
		effects = {
			strategistComboDamage = 0.40,
			strategistComboReset = true,
		},
		requirements = {
			prerequisitePassives = {"Inverse Slide Expertise", "Tapdance Rhythm"},
			weapon = "Guns",
			stats = { Dexerity = 6, Knowledge = 4 },
			level = 12,
		},
	},

	["Shell Piercer Mastery"] = {
		id = "shell_piercer_mastery",
		tier = "NOTABLE",
		category = "Guns",
		description = "Break through any armor. Shell Piercer ignores 30% armor and deals +15% damage.",
		effects = {
			shellPiercerArmorPen = 0.30,
			shellPiercerDamage = 0.15,
		},
		requirements = {
			prerequisitePassives = {"Marksman"},
			weapon = "Guns",
			stats = { Knowledge = 3 },
		},
	},

	["Hellraiser Unleashed"] = {
		id = "hellraiser_unleashed",
		tier = "KEYSTONE",
		category = "Guns",
		description = "Rain fire upon your enemies. Hellraiser has 25% more projectiles and +20% damage.",
		effects = {
			hellraiserProjectiles = 0.25,
			hellraiserDamage = 0.20,
		},
		requirements = {
			prerequisitePassives = {"Shell Piercer Mastery"},
			weapon = "Guns",
			stats = { Potency = 6 },
			level = 14,
		},
	},

	["Quick Draw"] = {
		id = "quick_draw",
		tier = "MINOR",
		category = "Guns",
		description = "First shot advantage. +20% damage on first shot after equipping.",
		effects = {
			firstShotDamage = 0.20,
		},
		requirements = {
			weapon = "Guns",
		},
	},

	["Steady Hands"] = {
		id = "steady_hands",
		tier = "NOTABLE",
		category = "Guns",
		description = "No shaking, no missing. +10% accuracy and -15% recoil.",
		effects = {
			accuracy = 0.10,
			recoil = -0.15,
		},
		requirements = {
			prerequisitePassives = {"Quick Draw"},
			weapon = "Guns",
		},
	},

	["Hawkeye's Disciple"] = {
		id = "hawkeyes_disciple",
		tier = "LEGENDARY",
		category = "Guns",
		description = "Trained by the best. All Gun moves deal +30% damage, +15% fire rate.",
		effects = {
			allGunDamage = 0.30,
			fireRate = 0.15,
		},
		requirements = {
			prerequisitePassives = {"Strategist Combination", "Hellraiser Unleashed"},
			weapon = "Guns",
			stats = { Dexerity = 8, Knowledge = 6 },
			level = 20,
		},
	},

	-- ============================================
	-- FLAME PAGE - Flame alchemy passives
	-- ============================================

	["Alchemist's Foundation"] = {
		id = "alchemist_foundation",
		tier = "MINOR",
		category = "Flame",
		description = "The first step on the path of alchemy. +5% Alchemical damage.",
		effects = {
			alchemicalDamage = 0.05,
		},
		requirements = {},
	},

	["Flame Adept"] = {
		id = "flame_adept",
		tier = "NOTABLE",
		category = "Flame",
		description = "Master the destructive power of fire. +20% Flame alchemy damage.",
		effects = {
			flameDamage = 0.20,
		},
		requirements = {
			prerequisitePassives = {"Alchemist's Foundation"},
			alchemy = "Flame",
		},
	},

	["Snap Ignition"] = {
		id = "snap_ignition",
		tier = "NOTABLE",
		category = "Flame",
		description = "Like Mustang himself. Flame attacks have 15% chance to cause Burning (DoT).",
		effects = {
			burnChance = 0.15,
		},
		requirements = {
			prerequisitePassives = {"Flame Adept"},
			alchemy = "Flame",
			stats = { Knowledge = 3 },
		},
	},

	["Firestorm Intensity"] = {
		id = "firestorm_intensity",
		tier = "KEYSTONE",
		category = "Flame",
		description = "Unleash the inferno. Firestorm deals +30% damage and hits spread fire.",
		effects = {
			firestormDamage = 0.30,
			firestormSpread = true,
		},
		requirements = {
			prerequisitePassives = {"Snap Ignition"},
			alchemy = "Flame",
			stats = { Knowledge = 6, Potency = 4 },
			level = 12,
		},
	},

	["Cinder Control"] = {
		id = "cinder_control",
		tier = "NOTABLE",
		category = "Flame",
		description = "Master the embers. Cinder lingers 50% longer and deals +15% damage.",
		effects = {
			cinderDuration = 0.50,
			cinderDamage = 0.15,
		},
		requirements = {
			prerequisitePassives = {"Flame Adept"},
			alchemy = "Flame",
		},
	},

	["Combustion Expert"] = {
		id = "combustion_expert",
		tier = "MINOR",
		category = "Flame",
		description = "Understand the chemistry of fire. +10% explosion radius.",
		effects = {
			explosionRadius = 0.10,
		},
		requirements = {
			alchemy = "Flame",
		},
	},

	["Inferno Master"] = {
		id = "inferno_master",
		tier = "NOTABLE",
		category = "Flame",
		description = "The flames obey your will. Burning enemies take +20% more damage from you.",
		effects = {
			burningTargetDamage = 0.20,
		},
		requirements = {
			prerequisitePassives = {"Combustion Expert", "Snap Ignition"},
			alchemy = "Flame",
		},
	},

	["Flame Alchemist"] = {
		id = "flame_alchemist",
		tier = "LEGENDARY",
		category = "Flame",
		description = "The title earned by Roy Mustang. All Flame alchemy deals +40% damage, burns always apply.",
		effects = {
			allFlameDamage = 0.40,
			guaranteedBurn = true,
		},
		requirements = {
			prerequisitePassives = {"Firestorm Intensity", "Inferno Master"},
			alchemy = "Flame",
			stats = { Knowledge = 10, Potency = 6 },
			level = 22,
		},
	},

	["Heat Resistance"] = {
		id = "heat_resistance",
		tier = "MINOR",
		category = "Flame",
		description = "Handle the heat. +15% resistance to fire damage.",
		effects = {
			fireResistance = 0.15,
		},
		requirements = {
			alchemy = "Flame",
		},
	},

	-- ============================================
	-- STONE PAGE - Stone/Earth alchemy passives
	-- ============================================

	["Earth Shaper"] = {
		id = "earth_shaper",
		tier = "MINOR",
		category = "Stone",
		description = "Reshape the ground beneath your feet. +8% Stone alchemy damage.",
		effects = {
			stoneDamage = 0.08,
		},
		requirements = {
			alchemy = "Stone",
		},
	},

	["Stone Lance Mastery"] = {
		id = "stone_lance_mastery",
		tier = "NOTABLE",
		category = "Stone",
		description = "Impale from the earth. Stone Lance deals +25% damage and launches higher.",
		effects = {
			stoneLanceDamage = 0.25,
			stoneLanceLaunch = 0.30,
		},
		requirements = {
			prerequisitePassives = {"Earth Shaper"},
			alchemy = "Stone",
		},
	},

	["Cascade Fury"] = {
		id = "cascade_fury",
		tier = "NOTABLE",
		category = "Stone",
		description = "The earth rises in waves. Cascade creates additional rows and deals +15% damage.",
		effects = {
			cascadeRows = 2,
			cascadeDamage = 0.15,
		},
		requirements = {
			prerequisitePassives = {"Earth Shaper"},
			alchemy = "Stone",
		},
	},

	["Tectonic Mastery"] = {
		id = "tectonic_mastery",
		tier = "KEYSTONE",
		category = "Stone",
		description = "Command the very earth. Stone attacks cause tremors that stagger nearby enemies.",
		effects = {
			tremorEffect = true,
			tremorRadius = 10,
		},
		requirements = {
			prerequisitePassives = {"Stone Lance Mastery", "Cascade Fury"},
			alchemy = "Stone",
			stats = { Strange = 6, Potency = 4 },
			level = 12,
		},
	},

	["Barrier Transmuter"] = {
		id = "barrier_transmuter",
		tier = "NOTABLE",
		category = "Stone",
		description = "Create walls from nothing. Can create stone barriers that block projectiles.",
		effects = {
			canCreateBarriers = true,
			barrierDuration = 5,
		},
		requirements = {
			prerequisitePassives = {"Earth Shaper"},
			alchemy = "Stone",
			stats = { Strange = 3 },
		},
	},

	["Weapon Transmuter"] = {
		id = "weapon_transmuter",
		tier = "NOTABLE",
		category = "Stone",
		description = "Like Edward Elric. Can transmute arm into blade. +15% melee damage when unarmed.",
		effects = {
			unarmedMeleeDamage = 0.15,
			canTransmuteArmBlade = true,
		},
		requirements = {
			prerequisitePassives = {"Barrier Transmuter"},
			alchemy = "Stone",
			stats = { Strange = 5 },
		},
	},

	["Deconstruction Expert"] = {
		id = "deconstruction_expert",
		tier = "KEYSTONE",
		category = "Stone",
		description = "Like Scar. Break down matter with a touch. +30% damage to armored enemies.",
		effects = {
			armorPenetration = 0.30,
		},
		requirements = {
			prerequisitePassives = {"Weapon Transmuter"},
			alchemy = "Stone",
			stats = { Strange = 8, Potency = 5 },
			level = 14,
		},
	},

	["Stone Alchemist"] = {
		id = "stone_alchemist",
		tier = "LEGENDARY",
		category = "Stone",
		description = "Master of earth transmutation. All Stone alchemy deals +35% damage, creates jagged terrain.",
		effects = {
			allStoneDamage = 0.35,
			jaggedTerrain = true,
		},
		requirements = {
			prerequisitePassives = {"Tectonic Mastery", "Deconstruction Expert"},
			alchemy = "Stone",
			stats = { Strange = 10, Knowledge = 6 },
			level = 22,
		},
	},

	["Earthen Armor"] = {
		id = "earthen_armor",
		tier = "MINOR",
		category = "Stone",
		description = "Coat yourself in stone. +10% Physical Resistance.",
		effects = {
			physicalResistance = 0.10,
		},
		requirements = {
			alchemy = "Stone",
		},
	},

	-- ============================================
	-- DEFENSE PAGE - Defensive passives
	-- ============================================

	["Iron Constitution"] = {
		id = "iron_constitution",
		tier = "MINOR",
		category = "Defense",
		description = "Harden your body against harm. +10 Max Health.",
		effects = {
			maxHealth = 10,
		},
		requirements = {},
	},

	["Stone Skin"] = {
		id = "stone_skin",
		tier = "NOTABLE",
		category = "Defense",
		description = "Transmute your skin to be harder. +10% Physical Resistance.",
		effects = {
			physicalResistance = 0.10,
		},
		requirements = {
			prerequisitePassives = {"Iron Constitution"},
		},
	},

	["Alchemical Shield"] = {
		id = "alchemical_shield",
		tier = "NOTABLE",
		category = "Defense",
		description = "A barrier of pure energy. +10% Alchemical Resistance.",
		effects = {
			alchemicalResistance = 0.10,
		},
		requirements = {
			prerequisitePassives = {"Iron Constitution"},
		},
	},

	["Equivalent Exchange"] = {
		id = "equivalent_exchange",
		tier = "KEYSTONE",
		category = "Defense",
		description = "The fundamental law of alchemy. When you take damage, heal for 5% of damage dealt in the next 3s.",
		effects = {
			damageToHealConversion = 0.05,
			conversionWindow = 3,
		},
		requirements = {
			prerequisitePassives = {"Stone Skin", "Alchemical Shield"},
			stats = { Vibrance = 8 },
			level = 10,
		},
	},

	["Regenerative Tissue"] = {
		id = "regenerative_tissue",
		tier = "NOTABLE",
		category = "Defense",
		description = "Your body heals rapidly. +2 Health regeneration per second.",
		effects = {
			healthRegen = 2,
		},
		requirements = {
			prerequisitePassives = {"Iron Constitution"},
			stats = { Vibrance = 3 },
		},
	},

	["Fortified Body"] = {
		id = "fortified_body",
		tier = "MINOR",
		category = "Defense",
		description = "Build your endurance. +15 Max Health.",
		effects = {
			maxHealth = 15,
		},
		requirements = {},
	},

	["Unyielding"] = {
		id = "unyielding",
		tier = "NOTABLE",
		category = "Defense",
		description = "Refuse to fall. When below 20% health, gain +25% damage reduction.",
		effects = {
			lowHealthDamageReduction = 0.25,
			lowHealthThreshold = 0.20,
		},
		requirements = {
			prerequisitePassives = {"Fortified Body"},
			stats = { Vibrance = 4 },
		},
	},

	["Posture Master"] = {
		id = "posture_master",
		tier = "NOTABLE",
		category = "Defense",
		description = "Stand firm. +20% Posture recovery speed, +10 Max Posture.",
		effects = {
			postureRecovery = 0.20,
			maxPosture = 10,
		},
		requirements = {
			prerequisitePassives = {"Stone Skin"},
		},
	},

	["Immortal Body"] = {
		id = "immortal_body",
		tier = "LEGENDARY",
		category = "Defense",
		description = "Like the Homunculi. +50 Max Health, regenerate 3 HP/s, +15% all resistances.",
		effects = {
			maxHealth = 50,
			healthRegen = 3,
			allResistance = 0.15,
		},
		requirements = {
			prerequisitePassives = {"Equivalent Exchange", "Unyielding"},
			stats = { Vibrance = 10 },
			level = 22,
		},
	},

	["Perfect Block"] = {
		id = "perfect_block",
		tier = "MINOR",
		category = "Defense",
		description = "Timing is everything. Perfect blocks restore 5 posture.",
		effects = {
			perfectBlockPosture = 5,
		},
		requirements = {},
	},

	-- ============================================
	-- UTILITY PAGE - Utility and support passives
	-- ============================================

	["Swift Transmutation"] = {
		id = "swift_transmutation",
		tier = "MINOR",
		category = "Utility",
		description = "Faster transmutation circles. -10% cast time for alchemy.",
		effects = {
			castTimeReduction = 0.10,
		},
		requirements = {},
	},

	["Circle-less Alchemy"] = {
		id = "circleless_alchemy",
		tier = "KEYSTONE",
		category = "Utility",
		description = "Like the Elric brothers, perform alchemy without circles. -30% cast time, +10% energy cost.",
		effects = {
			castTimeReduction = 0.30,
			energyCostIncrease = 0.10,
		},
		requirements = {
			prerequisitePassives = {"Swift Transmutation"},
			stats = { Knowledge = 10, Strange = 5 },
			level = 15,
		},
	},

	["Alchemist's Eye"] = {
		id = "alchemist_eye",
		tier = "NOTABLE",
		category = "Utility",
		description = "See the composition of matter. Can identify item quality and enemy weak points.",
		effects = {
			canAnalyzeItems = true,
			canSeeWeakPoints = true,
		},
		requirements = {
			prerequisitePassives = {"Swift Transmutation"},
			stats = { Knowledge = 5 },
		},
	},

	["Energy Efficiency"] = {
		id = "energy_efficiency",
		tier = "MINOR",
		category = "Utility",
		description = "Conserve your strength. -8% energy cost for all abilities.",
		effects = {
			energyCostReduction = 0.08,
		},
		requirements = {},
	},

	["Rapid Recovery"] = {
		id = "rapid_recovery",
		tier = "NOTABLE",
		category = "Utility",
		description = "Bounce back quickly. +25% energy regeneration rate.",
		effects = {
			energyRegen = 0.25,
		},
		requirements = {
			prerequisitePassives = {"Energy Efficiency"},
		},
	},

	["Fleet Footed"] = {
		id = "fleet_footed",
		tier = "MINOR",
		category = "Utility",
		description = "Move with purpose. +8% movement speed.",
		effects = {
			movementSpeed = 0.08,
		},
		requirements = {},
	},

	["Evasive Maneuvers"] = {
		id = "evasive_maneuvers",
		tier = "NOTABLE",
		category = "Utility",
		description = "Dodge with grace. +15% dodge distance, -10% dodge cooldown.",
		effects = {
			dodgeDistance = 0.15,
			dodgeCooldown = -0.10,
		},
		requirements = {
			prerequisitePassives = {"Fleet Footed"},
			stats = { Dexerity = 3 },
		},
	},

	["Philosopher's Insight"] = {
		id = "philosophers_insight",
		tier = "KEYSTONE",
		category = "Utility",
		description = "Glimpse the truth beyond the Gate. All alchemical abilities cost 20% less energy.",
		effects = {
			alchemyCostReduction = 0.20,
		},
		requirements = {
			prerequisitePassives = {"Circle-less Alchemy", "Rapid Recovery"},
			stats = { Knowledge = 10 },
			level = 18,
		},
	},

	["State Alchemist Certification"] = {
		id = "state_alchemist",
		tier = "LEGENDARY",
		category = "Utility",
		description = "Recognized by the military. +20% all stats, access to military equipment and missions.",
		effects = {
			allStats = 0.20,
			militaryAccess = true,
		},
		requirements = {
			prerequisitePassives = {"Philosopher's Insight", "Alchemist's Eye"},
			stats = { Knowledge = 10, Potency = 5, Strange = 5 },
			level = 25,
		},
	},

	["Chimera Fusion"] = {
		id = "chimera_fusion",
		tier = "KEYSTONE",
		category = "Utility",
		description = "Fuse with beasts to gain their traits. Gain animal-like senses: +20% enemy detection range.",
		effects = {
			detectionRange = 0.20,
			canSenseEnemies = true,
		},
		requirements = {
			stats = { Strange = 8 },
			level = 10,
		},
	},

	["Homunculus Core"] = {
		id = "homunculus_core",
		tier = "LEGENDARY",
		category = "Utility",
		description = "A fragment of a Philosopher's Stone pulses within you. Revive once per life with 30% health.",
		effects = {
			canRevive = true,
			reviveHealth = 0.30,
			revivesPerLife = 1,
		},
		requirements = {
			prerequisitePassives = {"Chimera Fusion"},
			stats = { Strange = 10, Vibrance = 5, Knowledge = 5 },
			level = 25,
		},
	},
}

-- Helper function to get passives by category/page
function PassivesData.getPassivesByPage(pageName)
	local passives = {}
	for passiveName, passiveData in pairs(PassivesData.Passives) do
		if passiveData.category == pageName then
			table.insert(passives, {
				name = passiveName,
				data = passiveData,
			})
		end
	end
	-- Sort alphabetically for consistent display
	table.sort(passives, function(a, b)
		return a.name < b.name
	end)
	return passives
end

-- Helper function to check if a player meets requirements for a passive
function PassivesData.meetsRequirements(playerData, passiveId)
	local passive = nil
	for name, data in pairs(PassivesData.Passives) do
		if data.id == passiveId then
			passive = data
			break
		end
	end
	if not passive then return false, "Passive not found" end

	local reqs = passive.requirements
	if not reqs or next(reqs) == nil then return true end -- No requirements

	-- Check prerequisite passives
	if reqs.prerequisitePassives then
		for _, prereqName in ipairs(reqs.prerequisitePassives) do
			local prereqData = PassivesData.Passives[prereqName]
			if prereqData and not playerData.unlockedPassives[prereqData.id] then
				return false, "Missing prerequisite: " .. prereqName
			end
		end
	end

	-- Check weapon requirement
	if reqs.weapon then
		if playerData.weapon ~= reqs.weapon then
			return false, "Requires weapon: " .. reqs.weapon
		end
	end

	-- Check alchemy requirement
	if reqs.alchemy then
		if playerData.alchemy ~= reqs.alchemy then
			return false, "Requires alchemy: " .. reqs.alchemy
		end
	end

	-- Check stat requirements
	if reqs.stats then
		for statName, minValue in pairs(reqs.stats) do
			local playerStat = playerData.build and playerData.build[statName] or 0
			if playerStat < minValue then
				return false, "Requires " .. statName .. ": " .. minValue
			end
		end
	end

	-- Check level requirement
	if reqs.level then
		if (playerData.level or 1) < reqs.level then
			return false, "Requires level: " .. reqs.level
		end
	end

	return true
end

-- Get the cost for a passive based on its tier
function PassivesData.getPassiveCost(passiveName)
	local passive = PassivesData.Passives[passiveName]
	if not passive then return 0 end

	local tierData = PassivesData.Tiers[passive.tier]
	return tierData and tierData.cost or 1
end

-- Get color for a passive based on its tier
function PassivesData.getPassiveColor(passiveName)
	local passive = PassivesData.Passives[passiveName]
	if not passive then return Color3.fromRGB(128, 128, 128) end

	local tierData = PassivesData.Tiers[passive.tier]
	return tierData and tierData.color or Color3.fromRGB(128, 128, 128)
end

return PassivesData
