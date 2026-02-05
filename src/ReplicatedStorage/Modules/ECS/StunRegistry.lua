--!strict
--[[
	Stun Registry - Priority-Based Stun System

	A centralized system for registering and applying stuns with priority levels.
	Higher priority stuns can interrupt lower priority states, but not vice versa.

	Priority Levels (0-10):
	- 0: Idle/Default (no stun)
	- 1: Light hitstun (M1 hit reactions)
	- 2: Medium hitstun (skill damage)
	- 3: Heavy hitstun (critical hits)
	- 4: Knockback (movement-impairing)
	- 5: Stagger (action-interrupting)
	- 6: Guard break (defensive penalty)
	- 7: Ragdoll (full incapacitation)
	- 8: Grab (controlled by another entity)
	- 9: Ultimate effects (cinematic)
	- 10: Death/KO (highest priority)

	Usage:
		local StunRegistry = require(path.to.StunRegistry)

		-- Register a custom stun type
		StunRegistry.Register("MyCustomStun", {
			priority = 4,
			duration = 1.5,
			speedModifier = -8,
			canAct = false,
			canMove = false,
			canBlock = false,
			canDodge = false,
		})

		-- Apply a stun to a character
		StunRegistry.Apply(character, "DamageStun", { duration = 0.5 })

		-- Check if a stun can be applied (priority check)
		if StunRegistry.CanApply(character, "M1Stun") then
			StunRegistry.Apply(character, "M1Stun")
		end

		-- Get current stun priority
		local priority = StunRegistry.GetCurrentPriority(character)
]]

local StateManager = require(script.Parent.StateManager)

local StunRegistry = {}

-- Type definitions
export type StunConfig = {
	priority: number,           -- Priority level (0-10)
	duration: number?,          -- Default duration (can be overridden on apply)
	speedModifier: number?,     -- Speed penalty (negative value, e.g., -8 for walkspeed 8)
	canAct: boolean?,           -- Can perform actions (attacks, skills)
	canMove: boolean?,          -- Can move/walk
	canBlock: boolean?,         -- Can block
	canDodge: boolean?,         -- Can dodge
	canParry: boolean?,         -- Can parry
	animation: string?,         -- Animation to play
	lockRotation: boolean?,     -- Lock character rotation
	iframes: boolean?,          -- Grant invincibility frames
	breakOnHit: boolean?,       -- Does taking damage break this stun
	onApply: ((character: Model, config: StunConfig) -> ())?,    -- Callback when applied
	onRemove: ((character: Model, config: StunConfig) -> ())?,   -- Callback when removed
	-- Stun scaling options
	scalingGroup: string?,      -- Which scaling group this stun belongs to (default: "standard")
	noScaling: boolean?,        -- Disable stun scaling for this stun type
}

export type ApplyOptions = {
	duration: number?,          -- Override default duration
	invoker: Model?,            -- Who applied the stun
	force: boolean?,            -- Force apply even if lower priority
	noAnimation: boolean?,      -- Skip animation
}

-- Registry of all stun types
local StunTypes: { [string]: StunConfig } = {}

-- Active stuns per character (tracks current stun and priority)
local ActiveStuns: { [Model]: { stunName: string, priority: number, endTime: number } } = {}

-- ============================================
-- STUN SCALING (DIMINISHING RETURNS)
-- Repeated stuns become shorter to prevent stunlock abuse
-- ============================================
local SCALING_DECAY_RATE = 0.1    -- How fast scaling recovers per second (10% per second)
local SCALING_MIN = 0.4           -- Minimum stun duration multiplier (40%)
local SCALING_WINDOW = 5.0        -- Time window to count stuns (seconds)
local SCALING_REDUCTION = 0.15    -- Each stun reduces duration by 15%

local StunHistory: { [Model]: {
	recentStuns: { { name: string, time: number } },
	scalingFactor: number,
	lastStunTime: number,
} } = {}

-- ============================================
-- STUN SCALING FUNCTIONS
-- ============================================

--[[
	Get the current stun scaling factor for a character
	Scaling decreases with repeated stuns but recovers over time
	@param character Model - The character to check
	@return number - Scaling factor (1.0 = full duration, lower = shorter stuns)
]]
function StunRegistry.GetScalingFactor(character: Model): number
	local history = StunHistory[character]
	if not history then
		return 1.0
	end

	-- Decay scaling factor back toward 1.0 based on time since last stun
	local timeSinceLastStun = os.clock() - (history.lastStunTime or 0)
	local decayedFactor = history.scalingFactor + (timeSinceLastStun * SCALING_DECAY_RATE)
	return math.min(1.0, decayedFactor)
end

--[[
	Record a stun application for scaling purposes
	@param character Model - The character being stunned
	@param stunName string - The stun type being applied
]]
function StunRegistry.RecordStun(character: Model, stunName: string)
	local config = StunTypes[stunName]

	-- Skip recording if this stun type doesn't use scaling
	if config and config.noScaling then
		return
	end

	if not StunHistory[character] then
		StunHistory[character] = {
			recentStuns = {},
			scalingFactor = 1.0,
			lastStunTime = 0,
		}
	end

	local history = StunHistory[character]
	local now = os.clock()

	-- Clean old stuns outside the scaling window
	local cleanedStuns = {}
	for _, stunRecord in ipairs(history.recentStuns) do
		if now - stunRecord.time <= SCALING_WINDOW then
			table.insert(cleanedStuns, stunRecord)
		end
	end
	history.recentStuns = cleanedStuns

	-- Add new stun
	table.insert(history.recentStuns, { name = stunName, time = now })

	-- Calculate new scaling: each stun in window reduces by SCALING_REDUCTION
	local stunCount = #history.recentStuns
	history.scalingFactor = math.max(SCALING_MIN, 1.0 - (stunCount - 1) * SCALING_REDUCTION)
	history.lastStunTime = now
end

--[[
	Clear stun history for a character (used on respawn)
	@param character Model - The character to clear history for
]]
function StunRegistry.ClearStunHistory(character: Model)
	StunHistory[character] = nil
end

-- ============================================
-- STUN REGISTRATION
-- ============================================

--[[
	Register a new stun type
	@param name string - Unique identifier for the stun
	@param config StunConfig - Configuration for the stun behavior
]]
function StunRegistry.Register(name: string, config: StunConfig)
	if StunTypes[name] then
		warn(`[StunRegistry] Overwriting existing stun type: {name}`)
	end

	-- Validate priority
	if config.priority < 0 or config.priority > 10 then
		warn(`[StunRegistry] Priority must be 0-10, got {config.priority} for {name}`)
		config.priority = math.clamp(config.priority, 0, 10)
	end

	StunTypes[name] = config
end

--[[
	Get a registered stun configuration
	@param name string - Stun type name
	@return StunConfig? - The configuration or nil if not found
]]
function StunRegistry.Get(name: string): StunConfig?
	return StunTypes[name]
end

--[[
	Get all registered stun types
	@return { [string]: StunConfig }
]]
function StunRegistry.GetAll(): { [string]: StunConfig }
	return StunTypes
end

--[[
	Get the current stun priority for a character
	@param character Model - The character to check
	@return number - Current priority (0 if no stun)
]]
function StunRegistry.GetCurrentPriority(character: Model): number
	local activeStun = ActiveStuns[character]
	if activeStun and os.clock() < activeStun.endTime then
		return activeStun.priority
	end
	return 0
end

--[[
	Get the current active stun name for a character
	@param character Model - The character to check
	@return string? - Current stun name or nil
]]
function StunRegistry.GetCurrentStun(character: Model): string?
	local activeStun = ActiveStuns[character]
	if activeStun and os.clock() < activeStun.endTime then
		return activeStun.stunName
	end
	return nil
end

--[[
	Check if a stun can be applied based on priority
	@param character Model - The character to check
	@param stunName string - The stun type to check
	@return boolean - True if the stun can be applied
]]
function StunRegistry.CanApply(character: Model, stunName: string): boolean
	local config = StunTypes[stunName]
	if not config then
		warn(`[StunRegistry] Unknown stun type: {stunName}`)
		return false
	end

	local currentPriority = StunRegistry.GetCurrentPriority(character)
	return config.priority >= currentPriority
end

--[[
	Apply a stun to a character
	@param character Model - The character to stun
	@param stunName string - The stun type to apply
	@param options ApplyOptions? - Optional overrides
	@return boolean - True if stun was applied
]]
function StunRegistry.Apply(character: Model, stunName: string, options: ApplyOptions?): boolean
	local config = StunTypes[stunName]
	if not config then
		warn(`[StunRegistry] Unknown stun type: {stunName}`)
		return false
	end

	options = options or {}

	-- Priority check (unless forced)
	if not options.force then
		local currentPriority = StunRegistry.GetCurrentPriority(character)
		if config.priority < currentPriority then
			-- Lower priority stun blocked
			return false
		end
	end

	-- Calculate base duration
	local baseDuration = options.duration or config.duration or 0.5

	-- Apply stun scaling (diminishing returns) unless disabled
	local scalingFactor = 1.0
	if not config.noScaling then
		scalingFactor = StunRegistry.GetScalingFactor(character)
		StunRegistry.RecordStun(character, stunName)
	end
	local duration = baseDuration * scalingFactor

	local endTime = os.clock() + duration

	-- Store active stun
	ActiveStuns[character] = {
		stunName = stunName,
		priority = config.priority,
		endTime = endTime,
	}

	-- Apply stun state to StateManager
	StateManager.TimedState(character, "Stuns", stunName, duration)

	-- Apply speed modifier if specified
	if config.speedModifier then
		local speedStateName = `{stunName}Speed{math.abs(config.speedModifier)}`
		StateManager.TimedState(character, "Speeds", speedStateName, duration)
	end

	-- Apply iframes if specified
	if config.iframes then
		StateManager.TimedState(character, "IFrames", `{stunName}IFrame`, duration)
	end

	-- Lock rotation if specified
	if config.lockRotation then
		StateManager.TimedState(character, "Stuns", "NoRotate", duration)
	end

	-- Call onApply callback
	if config.onApply then
		config.onApply(character, config)
	end

	-- Schedule removal callback
	task.delay(duration, function()
		if character and character.Parent then
			-- Call onRemove callback
			if config.onRemove then
				config.onRemove(character, config)
			end
		end
	end)

	-- Schedule cleanup of active stun tracking
	task.delay(duration, function()
		local activeStun = ActiveStuns[character]
		if activeStun and activeStun.stunName == stunName and activeStun.endTime == endTime then
			ActiveStuns[character] = nil
		end
	end)

	return true
end

--[[
	Remove a stun from a character early
	@param character Model - The character to unstun
	@param stunName string? - Specific stun to remove (nil = remove any)
	@return boolean - True if a stun was removed
]]
function StunRegistry.Remove(character: Model, stunName: string?): boolean
	local activeStun = ActiveStuns[character]
	if not activeStun then
		return false
	end

	-- If specific stun name provided, check it matches
	if stunName and activeStun.stunName ~= stunName then
		return false
	end

	local config = StunTypes[activeStun.stunName]

	-- Remove from StateManager
	StateManager.RemoveState(character, "Stuns", activeStun.stunName)

	-- Remove speed modifier
	if config and config.speedModifier then
		local speedStateName = `{activeStun.stunName}Speed{math.abs(config.speedModifier)}`
		StateManager.RemoveState(character, "Speeds", speedStateName)
	end

	-- Remove iframes
	if config and config.iframes then
		StateManager.RemoveState(character, "IFrames", `{activeStun.stunName}IFrame`)
	end

	-- Remove rotation lock
	if config and config.lockRotation then
		StateManager.RemoveState(character, "Stuns", "NoRotate")
	end

	-- Call onRemove callback
	if config and config.onRemove then
		config.onRemove(character, config)
	end

	ActiveStuns[character] = nil
	return true
end

--[[
	Check if a character can perform an action based on current stun
	@param character Model - The character to check
	@return boolean - True if character can act
]]
function StunRegistry.CanAct(character: Model): boolean
	local stunName = StunRegistry.GetCurrentStun(character)
	if not stunName then
		return true
	end

	local config = StunTypes[stunName]
	if not config then
		return true
	end

	return config.canAct ~= false
end

--[[
	Check if a character can move based on current stun
	@param character Model - The character to check
	@return boolean - True if character can move
]]
function StunRegistry.CanMove(character: Model): boolean
	local stunName = StunRegistry.GetCurrentStun(character)
	if not stunName then
		return true
	end

	local config = StunTypes[stunName]
	if not config then
		return true
	end

	return config.canMove ~= false
end

--[[
	Check if a character can block based on current stun
	@param character Model - The character to check
	@return boolean - True if character can block
]]
function StunRegistry.CanBlock(character: Model): boolean
	local stunName = StunRegistry.GetCurrentStun(character)
	if not stunName then
		return true
	end

	local config = StunTypes[stunName]
	if not config then
		return true
	end

	return config.canBlock ~= false
end

--[[
	Check if a character can dodge based on current stun
	@param character Model - The character to check
	@return boolean - True if character can dodge
]]
function StunRegistry.CanDodge(character: Model): boolean
	local stunName = StunRegistry.GetCurrentStun(character)
	if not stunName then
		return true
	end

	local config = StunTypes[stunName]
	if not config then
		return true
	end

	return config.canDodge ~= false
end

--[[
	Check if a character can parry based on current stun
	@param character Model - The character to check
	@return boolean - True if character can parry
]]
function StunRegistry.CanParry(character: Model): boolean
	local stunName = StunRegistry.GetCurrentStun(character)
	if not stunName then
		return true
	end

	local config = StunTypes[stunName]
	if not config then
		return true
	end

	return config.canParry ~= false
end

--[[
	Clear all stuns from a character (used on respawn)
	@param character Model - The character to clear
]]
function StunRegistry.ClearAll(character: Model)
	local activeStun = ActiveStuns[character]
	if activeStun then
		local config = StunTypes[activeStun.stunName]
		if config and config.onRemove then
			config.onRemove(character, config)
		end
	end

	ActiveStuns[character] = nil
	StateManager.ClearCategory(character, "Stuns")

	-- Also clear stun history on respawn
	StunRegistry.ClearStunHistory(character)
end

-- ============================================
-- DEFAULT STUN REGISTRATIONS
-- ============================================

-- Light hitstun (M1 hit reactions)
StunRegistry.Register("DamageStun", {
	priority = 1,
	duration = 0.4,
	speedModifier = -12, -- Walkspeed reduced to 4
	canAct = false,
	canMove = true,
	canBlock = false,
	canDodge = false,
	canParry = false,
})

-- M1 True Stun (prevents parrying except on 3rd hit)
StunRegistry.Register("M1Stun", {
	priority = 1,
	duration = 0.4,
	speedModifier = -12,
	canAct = false,
	canMove = true,
	canBlock = false,
	canDodge = false,
	canParry = false,
})

-- Parry stun (when you get parried)
StunRegistry.Register("ParryStun", {
	priority = 5,
	duration = 1.5,
	speedModifier = -12,
	canAct = false,
	canMove = false,
	canBlock = false,
	canDodge = false,
	canParry = false,
	noScaling = true, -- Parry stun should not scale down
})

-- Parry knockback
StunRegistry.Register("ParryKnockback", {
	priority = 4,
	duration = 0.4,
	canAct = false,
	canMove = false,
	canBlock = false,
	canDodge = false,
	canParry = false,
	iframes = true,
})

-- Guard break stun
StunRegistry.Register("BlockBreakStun", {
	priority = 6,
	duration = 3.0,
	speedModifier = -13, -- Very slow
	canAct = false,
	canMove = true,
	canBlock = false,
	canDodge = false,
	canParry = false,
	noScaling = true, -- Guard break should not scale down
})

-- Knockback stun (during knockback animation)
StunRegistry.Register("KnockbackStun", {
	priority = 4,
	duration = 0.65,
	canAct = false,
	canMove = false,
	canBlock = false,
	canDodge = false,
	canParry = false,
	lockRotation = true,
})

-- Wallbang stun (stuck to wall)
StunRegistry.Register("WallbangStun", {
	priority = 5,
	duration = 1.5,
	canAct = false,
	canMove = false,
	canBlock = false,
	canDodge = false,
	canParry = false,
	lockRotation = true,
	iframes = true,
})

-- Ragdoll
StunRegistry.Register("Ragdolled", {
	priority = 7,
	duration = 2.0,
	canAct = false,
	canMove = false,
	canBlock = false,
	canDodge = false,
	canParry = false,
	noScaling = true, -- Ragdoll should not scale down
})

-- Grab victim
StunRegistry.Register("GrabVictim", {
	priority = 8,
	duration = 3.0,
	canAct = false,
	canMove = false,
	canBlock = false,
	canDodge = false,
	canParry = false,
	noScaling = true, -- Grab should not scale down
})

-- Strategist combo victim (locked in combo)
StunRegistry.Register("StrategistComboHit", {
	priority = 8,
	duration = 5.0,
	canAct = false,
	canMove = false,
	canBlock = false,
	canDodge = false,
	canParry = false,
	noScaling = true, -- Combo stun should not scale down
})

-- Death/KO state
StunRegistry.Register("Death", {
	priority = 10,
	duration = math.huge,
	canAct = false,
	canMove = false,
	canBlock = false,
	canDodge = false,
	canParry = false,
})

-- ============================================
-- ADDITIONAL STUN REGISTRATIONS
-- ============================================

-- NOTE: "Dashing" is NOT a stun - it's an action state managed via Actions category
-- Do not register it here. See Dodge.lua for implementation.

-- NoRotate (character rotation locked during skills)
StunRegistry.Register("NoRotate", {
	priority = 3,
	duration = 1.0,
	canAct = true, -- Can still act (it's just rotation lock)
	canMove = true,
	canBlock = true,
	canDodge = true,
	canParry = true,
	lockRotation = true,
})

-- NoAttack (cannot attack but can move/block)
StunRegistry.Register("NoAttack", {
	priority = 2,
	duration = 1.0,
	canAct = false,
	canMove = true,
	canBlock = true,
	canDodge = true,
	canParry = false,
})

-- Grabbed (being held by enemy grab skill)
StunRegistry.Register("Grabbed", {
	priority = 8,
	duration = 3.0,
	canAct = false,
	canMove = false,
	canBlock = false,
	canDodge = false,
	canParry = false,
})

-- Stagger (brief interruption from light hits)
StunRegistry.Register("Stagger", {
	priority = 3,
	duration = 0.3,
	canAct = false,
	canMove = true,
	canBlock = false,
	canDodge = false,
	canParry = false,
})

-- DodgeRecovery (brief window after dodge where you can't dodge again)
StunRegistry.Register("DodgeRecovery", {
	priority = 1,
	duration = 0.5,
	canAct = true,
	canMove = true,
	canBlock = true,
	canDodge = false, -- Cannot dodge during recovery
	canParry = true,
})

-- ============================================
-- NEW STUN TYPES (Deepwoken-inspired)
-- ============================================

-- Posture break stun (Deepwoken-style) - triggered when posture bar maxes out
StunRegistry.Register("PostureBreakStun", {
	priority = 6,
	duration = 2.5, -- Long stun for posture break
	speedModifier = -14, -- Very slow movement
	canAct = false,
	canMove = true, -- Can slowly move away
	canBlock = false,
	canDodge = false,
	canParry = false,
	noScaling = true, -- Posture break should not scale down
})

-- Counter hit stun - applied when interrupting an enemy's attack
-- 50% longer than normal damage stun to reward counter hits
StunRegistry.Register("CounterHitStun", {
	priority = 3, -- Higher priority than normal damage stun
	duration = 0.6, -- 50% longer than DamageStun (0.4s)
	speedModifier = -12,
	canAct = false,
	canMove = true,
	canBlock = false,
	canDodge = false,
	canParry = false,
})

return StunRegistry
