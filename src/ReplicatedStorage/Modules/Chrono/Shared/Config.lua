export type NPC_CONFIG = {
	BUFFER: number,
	TICK_RATE: number,
}

return {
	MIN_BUFFER = 0.09,
	MAX_BUFFER = 0.5,
	TICK_RATE = 1 / 20,

	PROXIMITY = 100,

	ENABLE_CUSTOM_CHARACTERS = false, -- this will disable default roblox replication as well.
	DISABLE_DEFAULT_REPLICATION = false, -- this is if you want to disable the default roblox replication, but still use their controller

	SEND_FULL_ROTATION = false,

	NPC_MODELS = {},

	NPC_TYPES = {
		DEFAULT = {
			TICK_RATE = 1 / 30,
			BUFFER = 0.1,
		},
		-- Wanderer NPCs: Non-combat citizens, slower tick rate to save bandwidth
		-- They just walk around casually, don't need precise replication
		WANDERER = {
			TICK_RATE = 1 / 10, -- 10 Hz (100ms) - much slower than combat NPCs
			BUFFER = 0.15, -- Slightly larger buffer for smoother interpolation
		},
	},

	PLAYER_MODELS = {},

	--note that warnings are mostly non fatal
	--this will be set to false to optimize output by default, only enable if you're experiencing bugs with the system
	SHOW_WARNINGS = false,
	MAX_SNAPSHOT_COUNT = 30,

	-- Network packet sizing
	MAX_UNRELIABLE_BYTES = 900,
	HEADER_SIZE = 2,

	-- ID reuse timing (prevents stale ID collisions)
	ID_REUSE_DELAY_MIN = 2,
	ID_REUSE_DELAY_MAX = 4,

	-- Far player tick rate multipliers
	FAR_PLAYER_MULTIPLIER = 4,
	FAR_PLAYER_MULTIPLIER_DEFAULT = 50,

	-- Position/rotation change thresholds
	POSITION_THRESHOLD = 0.05,
	ROTATION_EPSILON = 0.0001,

	-- Client awaiting timeout
	MAX_AWAITING_TIME = 2,
} :: {
	MIN_BUFFER: number,
	MAX_BUFFER: number,
	TICK_RATE: number,

	PROXIMITY: number,

	ENABLE_CUSTOM_CHARACTERS: boolean,
	DISABLE_DEFAULT_REPLICATION: boolean,

	SEND_FULL_ROTATION: boolean,

	NPC_MODELS: { [string]: Model },
	NPC_TYPES: {
		[string]: NPC_CONFIG,
		DEFAULT: NPC_CONFIG,
	},

	PLAYER_MODELS: { [string]: Model },

	SHOW_WARNINGS: boolean,
	MAX_SNAPSHOT_COUNT: number,

	MAX_UNRELIABLE_BYTES: number,
	HEADER_SIZE: number,
	ID_REUSE_DELAY_MIN: number,
	ID_REUSE_DELAY_MAX: number,
	FAR_PLAYER_MULTIPLIER: number,
	FAR_PLAYER_MULTIPLIER_DEFAULT: number,
	POSITION_THRESHOLD: number,
	ROTATION_EPSILON: number,
	MAX_AWAITING_TIME: number,
}
