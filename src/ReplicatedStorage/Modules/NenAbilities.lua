--!strict
-- Nen Abilities System
-- Defines all 10 Nen techniques with their properties and effects

local NenAbilities = {
	["Ten"] = {
		name = "Ten",
		displayName = "Ten (Basic Defense)",
		description = "Reduces all incoming damage by 15-25%",
		staminaDrain = 2, -- % per second
		cooldown = 0, -- Can be activated anytime
		duration = 0, -- Toggle ability (stays on until deactivated)
		isToggle = true,
		effects = {
			damageReduction = 0.20, -- 20% average
			visualEffect = "FaintAuraShimmer",
		},
		icon = "rbxassetid://0", -- TODO: Add icon asset
		category = "Basic",
		order = 1,
	},

	["Ren"] = {
		name = "Ren",
		displayName = "Ren (Power Amplification)",
		description = "+30-50% damage output, 2x incoming damage",
		staminaDrain = 4, -- % per second
		cooldown = 0,
		duration = 0,
		isToggle = true,
		effects = {
			damageBonus = 1.40, -- +40% average
			damageReduction = -1.0, -- Takes 2x damage (100% more)
			visualEffect = "IntensePulsingAura",
		},
		icon = "rbxassetid://0",
		category = "Basic",
		order = 2,
	},

	["Zetsu"] = {
		name = "Zetsu",
		displayName = "Zetsu (Concealment)",
		description = "Become invisible to detection, 3x damage if hit",
		staminaDrain = 0, -- No drain when hiding
		cooldown = 3, -- 3 second cooldown when deactivated
		duration = 0,
		isToggle = true,
		effects = {
			aggroReduction = 0.70, -- 70% reduced aggro range
			damageReduction = -2.0, -- Takes 3x damage
			disableNenAbilities = true,
			invisibility = 0.7, -- 70% transparency
			visualEffect = "Translucent",
		},
		icon = "rbxassetid://0",
		category = "Basic",
		order = 3,
	},

	["Gyo"] = {
		name = "Gyo",
		displayName = "Gyo (Focused Perception)",
		description = "Reveals hidden enemies, +25% focused damage",
		staminaDrain = 3, -- % per second
		cooldown = 0,
		duration = 0,
		isToggle = true,
		effects = {
			revealHidden = true,
			focusedDamageBonus = 1.25, -- +25% to focused target
			speedReduction = 0.50, -- Move 50% slower
			visualEffect = "GlowingEyes",
		},
		icon = "rbxassetid://0",
		category = "Advanced",
		order = 4,
	},

	["In"] = {
		name = "In",
		displayName = "In (Advanced Concealment)",
		description = "Hide your aura while using abilities",
		staminaDrain = 5, -- % per second
		cooldown = 0,
		duration = 0,
		isToggle = true,
		effects = {
			hideAbilityEffects = true,
			visualEffect = "InvisibleAura",
		},
		icon = "rbxassetid://0",
		category = "Advanced",
		order = 5,
	},

	["En"] = {
		name = "En",
		displayName = "En (Territory Control)",
		description = "5-50m detection sphere, must remain stationary",
		staminaDrain = 10, -- % per second
		cooldown = 5,
		duration = 0,
		isToggle = true,
		effects = {
			detectionRadius = 25, -- meters (scales with mastery)
			autoDetect = true,
			mustBeStationary = true,
			visualEffect = "TransparentDome",
		},
		icon = "rbxassetid://0",
		category = "Advanced",
		order = 6,
	},

	["Shu"] = {
		name = "Shu",
		displayName = "Shu (Weapon Enhancement)",
		description = "+40-60% weapon damage, increased reach",
		staminaDrain = 2.5, -- % per second
		cooldown = 0,
		duration = 0,
		isToggle = true,
		effects = {
			weaponDamageBonus = 1.50, -- +50% weapon damage
			weaponReachBonus = 0.15, -- +15% reach
			weaponIndestructible = true,
			visualEffect = "GlowingWeapon",
		},
		icon = "rbxassetid://0",
		category = "Advanced",
		order = 7,
	},

	["Ko"] = {
		name = "Ko",
		displayName = "Ko (Ultimate Focus)",
		description = "3-5x damage on single strike, 4x damage elsewhere",
		staminaDrain = 0, -- One-time use
		cooldown = 20, -- 20 second cooldown
		duration = 2, -- 2 second charge time
		isToggle = false,
		chargeTime = 1.5,
		effects = {
			damageMultiplier = 4.0, -- 4x damage on focused strike
			damageReduction = -3.0, -- Takes 4x damage to other body parts
			telegraphed = true,
			visualEffect = "MassiveAuraConcentration",
		},
		icon = "rbxassetid://0",
		category = "Master",
		order = 8,
	},

	["Ken"] = {
		name = "Ken",
		displayName = "Ken (Sustained Defense)",
		description = "+20% damage, 40% damage reduction",
		staminaDrain = 3.5, -- % per second
		cooldown = 0,
		duration = 0,
		isToggle = true,
		minimumLevel = 40, -- Requires level 40+
		effects = {
			damageBonus = 1.20, -- +20% damage
			damageReduction = 0.40, -- 40% damage reduction
			visualEffect = "StableAuraCoating",
		},
		icon = "rbxassetid://0",
		category = "Master",
		order = 9,
	},

	["Ryu"] = {
		name = "Ryu",
		displayName = "Ryu (Flow Control)",
		description = "Shift aura to body parts for defense/offense",
		staminaDrain = 0, -- Costs stamina per shift
		cooldown = 0,
		duration = 0,
		isToggle = true,
		minimumLevel = 50, -- Requires level 50+
		effects = {
			shiftCost = 5, -- 5% stamina per shift
			focusedDamageReduction = 0.70, -- 70% reduction on focused limb
			focusedDamageBonus = 1.50, -- +50% damage from focused limb
			shiftWindow = 1.0, -- 1 second window
			visualEffect = "FlowingAura",
		},
		icon = "rbxassetid://0",
		category = "Master",
		order = 10,
	},
}

return NenAbilities
