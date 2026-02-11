--[[
	ClientConfig - Client-Side System Constants
	Shared across client modules. Gameplay/system values only (not UI layout).

	Consumed by: DeathScreen, AntiFling, Health, Sounds, NotificationManager,
	             PlayerHandler, Animate, daynightcycle
]]

local ClientConfig = {

	-- ============================================
	-- DEATH SCREEN
	-- ============================================
	DeathScreen = {
		RAGDOLL_DURATION = 4,
		FADE_TO_BLACK_TIME = 0.5,
		HOLD_BLACK_TIME = 4,
		CONTENT_FADE_OUT_TIME = 0.6,
		FADE_TO_WHITE_TIME = 0.3,
		HOLD_WHITE_TIME = 0.5,
		FADE_FROM_WHITE_TIME = 0.5,
		IMAGE_ROTATION_SPEED = 15, -- degrees per second
		DEATH_IMAGE_ID = "rbxassetid://128446959644937",
	},

	-- ============================================
	-- ANTI-FLING
	-- ============================================
	AntiFling = {
		MAX_HORIZONTAL_VELOCITY = 150,
		MAX_VERTICAL_VELOCITY = 120,
		VELOCITY_CHECK_INTERVAL = 0,
		BODY_MOVER_CHECK_INTERVAL = 0.3,
		MAX_BODY_MOVER_LIFETIME = 2,
	},

	-- ============================================
	-- HEALTH BAR
	-- ============================================
	Health = {
		COLUMNS = 84,
		LERP_SPEED = 12,
		ADRENALINE_THRESHOLDS = { 33, 66 },
	},

	-- ============================================
	-- DAY/NIGHT CYCLE
	-- ============================================
	DayNight = {
		DAY_LENGTH = 3 * 60, -- 180 seconds for full cycle
		START_TIME = 6, -- 6 AM
	},

	-- ============================================
	-- SOUNDS
	-- ============================================
	Sounds = {
		FOOTSTEP_VOLUME = 0.35,
		ROLLOFF_MAX = 75,
		ROLLOFF_MIN = 10,
	},

	-- ============================================
	-- NOTIFICATIONS
	-- ============================================
	Notifications = {
		MAX_NOTIFICATIONS = 5,
		NOTIFICATION_HEIGHT = 30,
		SPAWN_DELAY = 0.2,
	},

	-- ============================================
	-- INVENTORY
	-- ============================================
	Inventory = {
		MAX_SLOTS = 50,
		HOTBAR_SLOTS = 10,
	},

	-- ============================================
	-- ANIMATION
	-- ============================================
	Animation = {
		JUMP_ANIM_DURATION = 0.316,
		FALL_TRANSITION_TIME = 0.1,
	},
}

return table.freeze(ClientConfig)
