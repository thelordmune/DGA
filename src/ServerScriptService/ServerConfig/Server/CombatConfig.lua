--[[
	CombatConfig - Centralized Combat Balance Constants
	Server-only. All gameplay-critical timing, damage, and physics values.

	Consumed by: Combat.lua, Damage.lua, posture_system.luau
]]

local CombatConfig = {

	-- ============================================
	-- COMBAT STATE
	-- ============================================
	InCombatDuration = 40, -- frames before InCombat expires
	HeavyDamageThreshold = 0.1, -- % of max HP that counts as "heavy" damage

	-- ============================================
	-- COMBO SYSTEM
	-- ============================================
	ComboResetTimeout = 2, -- seconds since last hit before combo resets
	ComboRecoveryDuration = 0.6, -- endlag after full combo chain

	-- ============================================
	-- M2 / CRITICAL
	-- ============================================
	MAX_CHARGE = 1.0, -- max M2 charge duration in seconds
	ChargeStages = {
		{ threshold = 0.66, multiplier = 1.5 },  -- Stage 3 (full charge)
		{ threshold = 0.33, multiplier = 1.25 }, -- Stage 2
		{ threshold = 0,    multiplier = 1.0 },  -- Stage 1 (quick release)
	},
	CriticalCooldown = 5, -- seconds

	-- ============================================
	-- KNOCKBACK
	-- ============================================
	Knockback = {
		HorizontalPower = 40,
		UpwardPower = 30,
		StunDuration = 1.267,
		RecoveryDuration = 0.4, -- endlag where target can only dodge
		NPCVelocity = 60, -- velocity magnitude for NPC->Player knockback
	},

	-- BFKnockback (Critical hit on ragdolled target)
	BFKnockback = {
		HorizontalPower = 60,
		UpwardPower = 50,
		RagdollDuration = 3,
	},

	-- KnockbackFollowUp
	FollowUp = {
		SpeedDivisor = 40, -- distance / this = travel time
		MinTravelTime = 0.3,
		MaxTravelTime = 1.2,
		StunDuration = 1.2,
		HorizontalPower = 30,
		MaxAnimSpeed = 1.5,
	},

	-- ============================================
	-- PARRY
	-- ============================================
	Parry = {
		Window = 0.23, -- parry window duration
		Cooldown = 1.5,
		FrameDuration = 0.5, -- active parry frames
		RecoveryDuration = 0.15, -- endlag after parry attempt
		StunDuration = 0.6, -- ParryStun on attacker
		KnockbackInvokerDuration = 0.4,
		KnockbackTargetDuration = 0.15,
		KnockbackPower = 30,
	},

	-- ============================================
	-- BLOCK
	-- ============================================
	Block = {
		RecoveryDuration = 0.1, -- endlag after releasing block
		PostureReduction = 0.5, -- blocking reduces posture damage by this factor
		BlockBarDivisor = 6, -- damage / this = block bar increase
		BBRegenDelay = 2, -- seconds before block bar starts regenerating
	},

	-- ============================================
	-- BLOCK BREAK
	-- ============================================
	BlockBreak = {
		StunDuration = 2,
		ActionDuration = 2,
		CooldownDuration = 2,
		ResetDelay = 3, -- BlockBroken tag reset delay
	},

	-- ============================================
	-- POSTURE
	-- ============================================
	Posture = {
		MaxPostureBar = 100,
		PostureBreakStun = 2.5,
		RegenRate = 10, -- posture recovered per second
		RegenDelay = 2, -- seconds before regen starts
	},

	-- ============================================
	-- HYPERARMOR
	-- ============================================
	HyperarmorBreakThreshold = 50,

	-- ============================================
	-- COUNTER HIT
	-- ============================================
	CounterHit = {
		PostureBonus = 15,
		CounterArmorDuration = 0.3,
	},

	-- ============================================
	-- WALLBANG
	-- ============================================
	Wallbang = {
		TriggerDistance = 5,
		DamageMultiplier = 1.2,
		StunDuration = 1.5,
		WallBreakRagdollDuration = 2,
	},

	-- ============================================
	-- WALL SLIDE
	-- ============================================
	WallSlide = {
		Duration = 1.0,
		MaxDistance = 35,
	},

	-- ============================================
	-- AERIAL ATTACK
	-- ============================================
	Aerial = {
		MaxAirTime = 2.0,
		GroundCheckTimeout = 1.5,
		BvelArcWait = 0.45,
	},

	-- ============================================
	-- LIGHT KNOCKBACK
	-- ============================================
	LightKnockback = {
		Velocity = 50,
		Duration = 0.15,
	},

	-- ============================================
	-- DESTRUCTIBLES
	-- ============================================
	Destructibles = {
		RespawnDelay = 30,
		MaxDebrisPerPart = 15,
		MinDebrisPerPart = 4,
		DebrisFadeDelayMin = 3,
		DebrisFadeDelayMax = 5,
		DebrisFadeDuration = 4,
		DebrisVelocityBase = 15,
		DebrisVelocityRandom = 10,
		DebrisMaxForce = 2000,
		DebrisAngularVelocity = 8,
		DebrisMaxTorque = 800,
	},

	-- ============================================
	-- DEFAULT SPEEDS
	-- ============================================
	DefaultWalkSpeed = 16,
}

return table.freeze(CombatConfig)
