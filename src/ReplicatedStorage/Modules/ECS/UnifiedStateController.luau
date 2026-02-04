--!strict
--[[
	UnifiedStateController - Priority-Based State Management System

	Coordinates ActionPriority and StunRegistry into a unified priority system.
	Higher priority states can cancel lower priority states with centralized cleanup.

	Priority Levels:
	- 1: Movement (Walking, Running, Sprinting, Dashing, Jumping)
	- 2: Parkour (Sliding, WallRunning, LedgeClimbing, Vaulting)
	- 3: Stuns (DamageStun, M1Stun, ParryStun, etc.)
	- 4: Combat (M1Attack, M2Attack, Block, Parry)
	- 5: Skills (Weapon abilities, HyperArmorSkill)
	- 6: Ragdoll/Knockback (Ragdolled, KnockbackStun, Grab)
	- 10: Death (Cannot be cancelled)

	Special Rules:
	- Stuns cancel combat via cancelOnStun flag (bypasses priority)
	- HyperArmor resists stuns up to damage threshold
	- Dodge can cancel M1 during first 50% of animation (feint window)
	- Block/Parry can cancel M1 attacks (defensive priority)

	Works for both Players and NPCs with identical behavior.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateManager = require(script.Parent.StateManager)
local StunRegistry = require(script.Parent.StunRegistry)

local UnifiedStateController = {}

-- Debug mode toggle (also checks character:GetAttribute("DebugState"))
UnifiedStateController.DEBUG_ENABLED = false

-- Priority constants
UnifiedStateController.Priority = {
	IDLE = 0,
	MOVEMENT = 1,
	PARKOUR = 2,
	STUN = 3,
	COMBAT = 4,
	SKILL = 5,
	RAGDOLL = 6,
	CINEMATIC = 7,
	DEATH = 10,
}

-- Type definitions
export type StateConfig = {
	priority: number,
	category: "Movement" | "Parkour" | "Action" | "Stun",
	cancelOnStun: boolean?,
	cancelOnHigherAction: boolean?,
	hyperArmor: boolean?,
	hyperArmorThreshold: number?,
	dodgeCancelWindow: number?,        -- % of animation where dodge can cancel
	canBeCancelledBy: {string}?,       -- Explicit allow list
	canCancelSamePriority: boolean?,   -- Can cancel other actions at same priority
	duration: number?,
	onCancel: {
		stopAnimations: boolean?,
		animationFadeTime: number?,
		destroyVelocities: boolean?,
		cleanupVFX: boolean?,
		customCallback: (() -> ())?,
	}?,
	-- Stun-specific config
	stunConfig: {
		duration: number?,
		canAct: boolean?,
		canMove: boolean?,
		canBlock: boolean?,
		canDodge: boolean?,
		canParry: boolean?,
		speedModifier: number?,
		iframes: boolean?,
		lockRotation: boolean?,
		noScaling: boolean?,
	}?,
}

export type StartOptions = {
	duration: number?,
	force: boolean?,
	noCancel: boolean?,
}

export type ApplyStunOptions = {
	duration: number?,
	invoker: Model?,
	force: boolean?,
}

-- Registry of all state types
local StateRegistry: { [string]: StateConfig } = {}

-- Active states per character (tracks current state, start time, duration)
local ActiveStates: { [Model]: {
	stateName: string,
	priority: number,
	category: string,
	startTime: number,
	duration: number,
	endTime: number,
} } = {}

-- Cleanup callbacks when character is destroyed
local CleanupConnections: { [Model]: RBXScriptConnection } = {}

-- ============================================
-- DEBUG LOGGING
-- ============================================

local function debugLog(character: Model, message: string)
	if UnifiedStateController.DEBUG_ENABLED or (character and character:GetAttribute("DebugState")) then
		print(`[StateController] {character and character.Name or "???"}: {message}`)
	end
end

-- ============================================
-- STATE REGISTRATION
-- ============================================

--[[
	Register a state type
	@param name string - Unique identifier for the state
	@param config StateConfig - Configuration for the state
]]
function UnifiedStateController.Register(name: string, config: StateConfig)
	if StateRegistry[name] then
		warn(`[UnifiedStateController] Overwriting existing state type: {name}`)
	end

	-- Validate priority
	if config.priority < 0 or config.priority > 10 then
		warn(`[UnifiedStateController] Priority must be 0-10, got {config.priority} for {name}`)
		config.priority = math.clamp(config.priority, 0, 10)
	end

	-- Set defaults
	if config.cancelOnStun == nil then
		config.cancelOnStun = true
	end
	if config.cancelOnHigherAction == nil then
		config.cancelOnHigherAction = true
	end

	StateRegistry[name] = config
end

--[[
	Get a registered state configuration
	@param name string - State type name
	@return StateConfig? - The configuration or nil
]]
function UnifiedStateController.Get(name: string): StateConfig?
	return StateRegistry[name]
end

-- ============================================
-- ACTIVE STATE MANAGEMENT
-- ============================================

--[[
	Get the current active state for a character
	@param character Model - The character to check
	@return string?, number, string - State name, priority, category (nil, 0, "None" if no state)
]]
function UnifiedStateController.GetCurrentState(character: Model): (string?, number, string)
	local activeState = ActiveStates[character]
	if activeState and os.clock() < activeState.endTime then
		return activeState.stateName, activeState.priority, activeState.category
	end
	return nil, 0, "None"
end

--[[
	Get the elapsed ratio of current action (0.0 to 1.0)
	Used for dodge cancel window calculation
	@param character Model - The character to check
	@return number - Elapsed ratio (0 if no action or action finished)
]]
function UnifiedStateController.GetActionElapsedRatio(character: Model): number
	local activeState = ActiveStates[character]
	if not activeState or activeState.duration <= 0 then
		return 0
	end

	local elapsed = os.clock() - activeState.startTime
	return math.clamp(elapsed / activeState.duration, 0, 1)
end

--[[
	Setup cleanup for a character (call on character added)
	Ensures ActiveStates is cleaned up when character is destroyed
	@param character Model - The character to track
]]
function UnifiedStateController.SetupCharacterCleanup(character: Model)
	if CleanupConnections[character] then
		return -- Already setup
	end

	CleanupConnections[character] = character.Destroying:Connect(function()
		UnifiedStateController.ForceCancel(character)
		ActiveStates[character] = nil
		CleanupConnections[character] = nil
	end)
end

-- ============================================
-- STATE CANCELLATION (via ActionCancellation module)
-- ============================================

-- Forward declaration - will be set when ActionCancellation loads
local ActionCancellation = nil

local function performCancellation(character: Model, options: any?)
	if ActionCancellation then
		ActionCancellation.Cancel(character, options)
	else
		-- Fallback: basic cancellation without ActionCancellation module
		-- This allows the system to work even before ActionCancellation is created
		debugLog(character, "ActionCancellation not loaded, using fallback cleanup")

		-- Stop all animations
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in animator:GetPlayingAnimationTracks() do
					track:Stop(options and options.animationFadeTime or 0.1)
				end
			end
		end

		-- Destroy body movers
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			for _, child in rootPart:GetChildren() do
				if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or
					child:IsA("BodyPosition") or child:IsA("BodyGyro") or
					child:IsA("AlignPosition") or child:IsA("AlignOrientation") then
					child:Destroy()
				end
			end
		end
	end
end

--[[
	Set the ActionCancellation module reference
	Called by ActionCancellation.luau on load
]]
function UnifiedStateController.SetActionCancellation(module: any)
	ActionCancellation = module
end

-- ============================================
-- CAN START ACTION CHECK
-- ============================================

--[[
	Check if a new state can be started (will cancel current if allowed)
	@param character Model - The character to check
	@param stateName string - The state that wants to start
	@return boolean - True if the state can start
]]
function UnifiedStateController.CanStart(character: Model, stateName: string): boolean
	local newConfig = StateRegistry[stateName]
	if not newConfig then
		-- Unknown state types default to COMBAT priority
		warn(`[UnifiedStateController] Unknown state type: {stateName}, defaulting to COMBAT priority`)
		return UnifiedStateController.GetCurrentState(character) == nil or
			select(2, UnifiedStateController.GetCurrentState(character)) < UnifiedStateController.Priority.COMBAT
	end

	local currentName, currentPriority, currentCategory = UnifiedStateController.GetCurrentState(character)

	-- No current state? Always allow
	if not currentName then
		debugLog(character, `CanStart({stateName}): YES - no current state`)
		return true
	end

	local currentConfig = StateRegistry[currentName]
	if not currentConfig then
		-- Current state not registered, allow override
		debugLog(character, `CanStart({stateName}): YES - current state {currentName} not registered`)
		return true
	end

	-- Check explicit canBeCancelledBy list
	if currentConfig.canBeCancelledBy then
		for _, allowedAction in ipairs(currentConfig.canBeCancelledBy) do
			if allowedAction == stateName then
				debugLog(character, `CanStart({stateName}): YES - in canBeCancelledBy list`)
				return true
			end
		end
	end

	-- Check window-based dodge cancel for M1
	if stateName == "Dashing" and currentConfig.dodgeCancelWindow then
		local elapsedRatio = UnifiedStateController.GetActionElapsedRatio(character)
		if elapsedRatio <= currentConfig.dodgeCancelWindow then
			debugLog(character, `CanStart({stateName}): YES - within dodge cancel window ({string.format("%.2f", elapsedRatio)} <= {currentConfig.dodgeCancelWindow})`)
			return true
		else
			debugLog(character, `CanStart({stateName}): NO - past dodge cancel window ({string.format("%.2f", elapsedRatio)} > {currentConfig.dodgeCancelWindow})`)
			return false
		end
	end

	-- Check if new action can cancel same priority (Block/Parry)
	if newConfig.canCancelSamePriority and newConfig.priority == currentPriority then
		debugLog(character, `CanStart({stateName}): YES - canCancelSamePriority at priority {currentPriority}`)
		return true
	end

	-- Standard priority check
	if newConfig.priority > currentPriority then
		debugLog(character, `CanStart({stateName}): YES - higher priority ({newConfig.priority} > {currentPriority})`)
		return true
	end

	debugLog(character, `CanStart({stateName}): NO - lower/equal priority ({newConfig.priority} <= {currentPriority})`)
	return false
end

-- ============================================
-- START STATE
-- ============================================

--[[
	Start a state, cancelling any lower-priority state
	@param character Model - The character performing the state
	@param stateName string - The state type
	@param options StartOptions? - Optional overrides
	@return boolean - True if state was started
]]
function UnifiedStateController.Start(character: Model, stateName: string, options: StartOptions?): boolean
	options = options or {}

	local config = StateRegistry[stateName]
	local priority = config and config.priority or UnifiedStateController.Priority.COMBAT
	local category = config and config.category or "Action"

	-- Ensure cleanup is setup
	UnifiedStateController.SetupCharacterCleanup(character)

	-- Check if we can start (unless forced)
	if not options.force and not UnifiedStateController.CanStart(character, stateName) then
		debugLog(character, `Start({stateName}): BLOCKED - cannot start`)
		return false
	end

	-- Get current state for cancellation
	local currentName = UnifiedStateController.GetCurrentState(character)
	local currentConfig = currentName and StateRegistry[currentName]

	-- Cancel current state if needed
	if not options.noCancel and currentName then
		debugLog(character, `Start({stateName}): Cancelling current state {currentName}`)
		performCancellation(character, currentConfig and currentConfig.onCancel)

		-- Remove from StateManager
		if currentConfig then
			if currentConfig.category == "Stun" then
				StateManager.RemoveState(character, "Stuns", currentName)
			else
				StateManager.RemoveState(character, "Actions", currentName)
			end
		end
	end

	-- Calculate duration
	local duration = options.duration or (config and config.duration) or 1.0
	local now = os.clock()
	local endTime = now + duration

	-- Store active state
	ActiveStates[character] = {
		stateName = stateName,
		priority = priority,
		category = category,
		startTime = now,
		duration = duration,
		endTime = endTime,
	}

	-- Store start time and duration as attributes for dodge cancel window
	character:SetAttribute("ActionStartTime", now)
	character:SetAttribute("ActionDuration", duration)

	-- Sync to StateManager for backwards compatibility
	if category == "Stun" then
		StateManager.TimedState(character, "Stuns", stateName, duration)
	else
		StateManager.TimedState(character, "Actions", stateName, duration)
	end

	debugLog(character, `Start({stateName}): SUCCESS - priority {priority}, duration {duration}s`)

	-- Schedule cleanup
	task.delay(duration, function()
		local activeState = ActiveStates[character]
		if activeState and activeState.stateName == stateName and activeState.endTime == endTime then
			ActiveStates[character] = nil
			debugLog(character, `State {stateName} ended naturally`)
		end
	end)

	return true
end

-- ============================================
-- APPLY STUN (Special handling)
-- ============================================

--[[
	Apply a stun to a character
	Stuns can cancel actions with cancelOnStun = true, regardless of priority
	@param character Model - The character to stun
	@param stunName string - The stun type to apply
	@param options ApplyStunOptions? - Optional overrides
	@return boolean - True if stun was applied
]]
function UnifiedStateController.ApplyStun(character: Model, stunName: string, options: ApplyStunOptions?): boolean
	options = options or {}

	local stunConfig = StateRegistry[stunName]

	-- Also check StunRegistry for stun-specific config
	local registryConfig = StunRegistry.Get(stunName)

	if not stunConfig and not registryConfig then
		warn(`[UnifiedStateController] Unknown stun type: {stunName}`)
		return false
	end

	-- Ensure cleanup is setup
	UnifiedStateController.SetupCharacterCleanup(character)

	-- Get current state
	local currentName, currentPriority, currentCategory = UnifiedStateController.GetCurrentState(character)
	local currentConfig = currentName and StateRegistry[currentName]

	-- Check if current action can be cancelled by stun
	if currentName and currentCategory == "Action" then
		if currentConfig then
			if currentConfig.cancelOnStun then
				-- Stun cancels action regardless of priority
				debugLog(character, `ApplyStun({stunName}): Cancelling action {currentName} (cancelOnStun=true)`)
				performCancellation(character, currentConfig.onCancel)
				StateManager.RemoveState(character, "Actions", currentName)
				ActiveStates[character] = nil
			elseif currentConfig.hyperArmor then
				-- Check hyper armor threshold
				local accumulated = character:GetAttribute("HyperarmorDamage") or 0
				local threshold = currentConfig.hyperArmorThreshold or 50
				if accumulated >= threshold then
					debugLog(character, `ApplyStun({stunName}): Hyper armor broken ({accumulated} >= {threshold})`)
					performCancellation(character, currentConfig.onCancel)
					StateManager.RemoveState(character, "Actions", currentName)
					ActiveStates[character] = nil
				else
					debugLog(character, `ApplyStun({stunName}): BLOCKED by hyper armor ({accumulated} < {threshold})`)
					return false
				end
			else
				-- cancelOnStun = false and no hyper armor = immune to stuns
				debugLog(character, `ApplyStun({stunName}): BLOCKED - action immune to stuns`)
				return false
			end
		end
	end

	-- Check priority against current stun (if any)
	if currentCategory == "Stun" then
		local stunPriority = stunConfig and stunConfig.priority or
			(registryConfig and registryConfig.priority) or UnifiedStateController.Priority.STUN

		if not options.force and stunPriority < currentPriority then
			debugLog(character, `ApplyStun({stunName}): BLOCKED - lower priority stun ({stunPriority} < {currentPriority})`)
			return false
		end
	end

	-- Apply stun via StunRegistry (handles scaling, duration, etc.)
	local success = StunRegistry.Apply(character, stunName, {
		duration = options.duration,
		invoker = options.invoker,
		force = options.force,
	})

	if success then
		-- Update ActiveStates
		local duration = options.duration or (registryConfig and registryConfig.duration) or 0.5
		local priority = stunConfig and stunConfig.priority or
			(registryConfig and registryConfig.priority) or UnifiedStateController.Priority.STUN

		local now = os.clock()
		ActiveStates[character] = {
			stateName = stunName,
			priority = priority,
			category = "Stun",
			startTime = now,
			duration = duration,
			endTime = now + duration,
		}

		debugLog(character, `ApplyStun({stunName}): SUCCESS - priority {priority}, duration {duration}s`)
	end

	return success
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

--[[
	Force cancel current state (used on death, respawn)
	@param character Model - The character
]]
function UnifiedStateController.ForceCancel(character: Model)
	local currentName = UnifiedStateController.GetCurrentState(character)
	if currentName then
		local currentConfig = StateRegistry[currentName]
		debugLog(character, `ForceCancel: Cancelling {currentName}`)
		performCancellation(character, currentConfig and currentConfig.onCancel)
		ActiveStates[character] = nil
	end

	-- Clear attributes
	character:SetAttribute("ActionStartTime", nil)
	character:SetAttribute("ActionDuration", nil)
end

--[[
	End a state normally (not cancelled)
	@param character Model - The character
	@param stateName string? - Specific state to end (nil = any)
	@return boolean - True if state was ended
]]
function UnifiedStateController.EndState(character: Model, stateName: string?): boolean
	local activeState = ActiveStates[character]
	if not activeState then
		return false
	end

	if stateName and activeState.stateName ~= stateName then
		return false
	end

	debugLog(character, `EndState: {activeState.stateName} ended normally`)
	ActiveStates[character] = nil
	return true
end

--[[
	Check if character is in an action
	@param character Model - The character to check
	@return boolean - True if in an action
]]
function UnifiedStateController.IsInAction(character: Model): boolean
	local activeState = ActiveStates[character]
	return activeState ~= nil and os.clock() < activeState.endTime
end

--[[
	Check if character is in a specific action type
	@param character Model - The character to check
	@param stateName string - The state to check for
	@return boolean - True if in that specific state
]]
function UnifiedStateController.IsInState(character: Model, stateName: string): boolean
	local currentName = UnifiedStateController.GetCurrentState(character)
	return currentName == stateName
end

--[[
	Check if character can act (not stunned, not dead)
	@param character Model - The character to check
	@return boolean - True if character can act
]]
function UnifiedStateController.CanAct(character: Model): boolean
	-- Check StateManager for stuns
	if StateManager.StateCount(character, "Stuns") then
		return false
	end

	-- Check StunRegistry
	if not StunRegistry.CanAct(character) then
		return false
	end

	return true
end

--[[
	Check if character can move
	@param character Model - The character to check
	@return boolean - True if character can move
]]
function UnifiedStateController.CanMove(character: Model): boolean
	return StunRegistry.CanMove(character)
end

--[[
	Check if character can block
	@param character Model - The character to check
	@return boolean - True if character can block
]]
function UnifiedStateController.CanBlock(character: Model): boolean
	return StunRegistry.CanBlock(character)
end

--[[
	Check if character can dodge
	@param character Model - The character to check
	@return boolean - True if character can dodge
]]
function UnifiedStateController.CanDodge(character: Model): boolean
	return StunRegistry.CanDodge(character)
end

--[[
	Clear all state tracking for a character (used on respawn)
	@param character Model - The character to clear
]]
function UnifiedStateController.ClearAll(character: Model)
	debugLog(character, "ClearAll: Clearing all states")

	-- Cancel current state
	UnifiedStateController.ForceCancel(character)

	-- Clear stun tracking
	StunRegistry.ClearAll(character)

	-- Clear all state categories
	StateManager.ClearCategory(character, "Actions")
	StateManager.ClearCategory(character, "Stuns")
	StateManager.ClearCategory(character, "Speeds")
	StateManager.ClearCategory(character, "IFrames")
	StateManager.ClearCategory(character, "Frames")

	-- Disconnect cleanup
	if CleanupConnections[character] then
		CleanupConnections[character]:Disconnect()
		CleanupConnections[character] = nil
	end
end

-- ============================================
-- DEFAULT STATE REGISTRATIONS
-- ============================================

-- Priority 1: Movement
UnifiedStateController.Register("Walking", {
	priority = UnifiedStateController.Priority.MOVEMENT,
	category = "Movement",
	cancelOnStun = true,
})

UnifiedStateController.Register("Running", {
	priority = UnifiedStateController.Priority.MOVEMENT,
	category = "Movement",
	cancelOnStun = true,
})

UnifiedStateController.Register("Sprinting", {
	priority = UnifiedStateController.Priority.MOVEMENT,
	category = "Movement",
	cancelOnStun = true,
})

UnifiedStateController.Register("Dashing", {
	priority = UnifiedStateController.Priority.MOVEMENT,
	category = "Action",
	cancelOnStun = true,
	duration = 0.35,
	onCancel = {
		stopAnimations = true,
		destroyVelocities = true,
	},
})

UnifiedStateController.Register("Jumping", {
	priority = UnifiedStateController.Priority.MOVEMENT,
	category = "Movement",
	cancelOnStun = true,
})

-- Priority 2: Parkour
UnifiedStateController.Register("Sliding", {
	priority = UnifiedStateController.Priority.PARKOUR,
	category = "Action",
	cancelOnStun = true,
	onCancel = {
		stopAnimations = true,
		destroyVelocities = true,
	},
})

UnifiedStateController.Register("WallRunning", {
	priority = UnifiedStateController.Priority.PARKOUR,
	category = "Action",
	cancelOnStun = true,
	onCancel = {
		stopAnimations = true,
		destroyVelocities = true,
	},
})

UnifiedStateController.Register("LedgeClimbing", {
	priority = UnifiedStateController.Priority.PARKOUR,
	category = "Action",
	cancelOnStun = true,
	onCancel = {
		stopAnimations = true,
		destroyVelocities = true,
	},
})

UnifiedStateController.Register("Vaulting", {
	priority = UnifiedStateController.Priority.PARKOUR,
	category = "Action",
	cancelOnStun = true,
})

-- Priority 3: Stuns (registered in StunRegistry, we just add priority mapping)
UnifiedStateController.Register("DamageStun", {
	priority = UnifiedStateController.Priority.STUN,
	category = "Stun",
})

UnifiedStateController.Register("M1Stun", {
	priority = UnifiedStateController.Priority.STUN,
	category = "Stun",
})

UnifiedStateController.Register("ParryStun", {
	priority = UnifiedStateController.Priority.STUN,
	category = "Stun",
})

UnifiedStateController.Register("BlockBreakStun", {
	priority = UnifiedStateController.Priority.STUN,
	category = "Stun",
})

UnifiedStateController.Register("WallbangStun", {
	priority = UnifiedStateController.Priority.STUN,
	category = "Stun",
})

UnifiedStateController.Register("Stagger", {
	priority = UnifiedStateController.Priority.STUN,
	category = "Stun",
})

UnifiedStateController.Register("PostureBreakStun", {
	priority = UnifiedStateController.Priority.STUN,
	category = "Stun",
})

UnifiedStateController.Register("CounterHitStun", {
	priority = UnifiedStateController.Priority.STUN,
	category = "Stun",
})

-- Priority 4: Combat
UnifiedStateController.Register("M1Attack", {
	priority = UnifiedStateController.Priority.COMBAT,
	category = "Action",
	cancelOnStun = true,
	dodgeCancelWindow = 0.5, -- Can dodge cancel during first 50% of animation
	canBeCancelledBy = { "Block", "Parry" }, -- Block/Parry can cancel M1
	onCancel = {
		stopAnimations = true,
		animationFadeTime = 0.2,
		destroyVelocities = true,
		cleanupVFX = true,
	},
})

UnifiedStateController.Register("M2Attack", {
	priority = UnifiedStateController.Priority.COMBAT,
	category = "Action",
	cancelOnStun = true,
	onCancel = {
		stopAnimations = true,
		destroyVelocities = true,
		cleanupVFX = true,
	},
})

UnifiedStateController.Register("Critical", {
	priority = UnifiedStateController.Priority.COMBAT,
	category = "Action",
	cancelOnStun = true,
})

UnifiedStateController.Register("Block", {
	priority = UnifiedStateController.Priority.COMBAT,
	category = "Action",
	cancelOnStun = true,
	canCancelSamePriority = true, -- Can cancel other priority 4 actions
})

UnifiedStateController.Register("Parry", {
	priority = UnifiedStateController.Priority.COMBAT,
	category = "Action",
	cancelOnStun = true,
	canCancelSamePriority = true,
	duration = 0.5,
})

UnifiedStateController.Register("RunningAttack", {
	priority = UnifiedStateController.Priority.COMBAT,
	category = "Action",
	cancelOnStun = true,
})

-- Priority 5: Skills
UnifiedStateController.Register("Skill", {
	priority = UnifiedStateController.Priority.SKILL,
	category = "Action",
	cancelOnStun = true,
	onCancel = {
		stopAnimations = true,
		destroyVelocities = true,
		cleanupVFX = true,
	},
})

UnifiedStateController.Register("HyperArmorSkill", {
	priority = UnifiedStateController.Priority.SKILL,
	category = "Action",
	cancelOnStun = false, -- Resists stuns
	hyperArmor = true,
	hyperArmorThreshold = 50,
	onCancel = {
		stopAnimations = true,
		destroyVelocities = true,
		cleanupVFX = true,
	},
})

UnifiedStateController.Register("PincerImpact", {
	priority = UnifiedStateController.Priority.SKILL,
	category = "Action",
	cancelOnStun = false,
	hyperArmor = true,
	hyperArmorThreshold = 50,
})

UnifiedStateController.Register("Ultimate", {
	priority = UnifiedStateController.Priority.SKILL,
	category = "Action",
	cancelOnStun = false,
})

-- Priority 6: Ragdoll/Knockback
UnifiedStateController.Register("Ragdolled", {
	priority = UnifiedStateController.Priority.RAGDOLL,
	category = "Stun",
})

UnifiedStateController.Register("KnockbackStun", {
	priority = UnifiedStateController.Priority.RAGDOLL,
	category = "Stun",
})

UnifiedStateController.Register("ParryKnockback", {
	priority = UnifiedStateController.Priority.RAGDOLL,
	category = "Stun",
})

UnifiedStateController.Register("GrabVictim", {
	priority = UnifiedStateController.Priority.RAGDOLL,
	category = "Stun",
})

UnifiedStateController.Register("Grabbed", {
	priority = UnifiedStateController.Priority.RAGDOLL,
	category = "Stun",
})

-- Priority 10: Death
UnifiedStateController.Register("Death", {
	priority = UnifiedStateController.Priority.DEATH,
	category = "Stun",
	cancelOnStun = false,
})

return UnifiedStateController
