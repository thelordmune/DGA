--!strict
--[[
	Action Priority - Animation Cancellation System

	Defines action priorities so higher-priority actions can cancel lower-priority ones.
	Walking/Sprinting are the easiest to cancel, hyper armor skills are the hardest.

	Priority Levels (0-6):
	- 0: Idle/Default (no action)
	- 1: Walking/Sprinting (movement animations)
	- 2: Dashing/Dodging (evasive actions)
	- 3: Attacking (M1 combos, criticals/M2)
	- 4: Skills (weapon abilities)
	- 5: Hyper Armor Skills (cannot be interrupted by lower actions)
	- 6: Ultimate/Cinematic (cannot be interrupted)

	Usage:
		local ActionPriority = require(path.to.ActionPriority)

		-- Check if an action can be started (will cancel current action if lower priority)
		if ActionPriority.CanStartAction(character, "M1Attack") then
			ActionPriority.StartAction(character, "M1Attack", 0.5) -- 0.5s duration
			-- Play animation...
		end

		-- Manually cancel current action
		ActionPriority.CancelAction(character, "Dodge") -- Only cancel if Dodge or higher wants to

		-- Get current action info
		local action, priority = ActionPriority.GetCurrentAction(character)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ECS imports for entity-based action checks
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local tags = require(ReplicatedStorage.Modules.ECS.jecs_tags)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

local ActionPriority = {}

-- Type definitions
export type ActionConfig = {
	priority: number,           -- Priority level (0-6)
	canBeCancelledBy: {string}?, -- List of actions that can cancel this (in addition to higher priority)
	cannotCancel: {string}?,    -- List of actions this cannot cancel (even if higher priority)
	duration: number?,          -- Default duration (optional, can be overridden)
	cancelOnStun: boolean?,     -- Should this action be cancelled when stunned (default: true)
	cancelOnDamage: boolean?,   -- Should this action be cancelled when damaged (default: false)
}

export type StartOptions = {
	duration: number?,          -- Override default duration
	force: boolean?,            -- Force start even if same priority
	noCancel: boolean?,         -- Don't cancel current action (just track)
}

-- Registry of action types
local ActionTypes: { [string]: ActionConfig } = {}

-- Active actions per character
local ActiveActions: { [Model]: {
	actionName: string,
	priority: number,
	endTime: number,
	animation: AnimationTrack?,
} } = {}

-- Callbacks for when actions are cancelled
local CancelCallbacks: { [Model]: { [string]: () -> () } } = {}

-- Cleanup connections for when characters are destroyed
local CleanupConnections: { [Model]: RBXScriptConnection } = {}

--[[
	Setup cleanup for a character (ensures ActiveActions is cleaned on death)
	@param character Model - The character to track
]]
local function setupCharacterCleanup(character: Model)
	if CleanupConnections[character] then
		return -- Already setup
	end

	CleanupConnections[character] = character.Destroying:Connect(function()
		-- Immediately clear active actions to prevent task.delay callbacks from firing
		ActiveActions[character] = nil
		CancelCallbacks[character] = nil
		CleanupConnections[character] = nil
	end)
end

--[[
	Register a new action type
	@param name string - Unique identifier for the action
	@param config ActionConfig - Configuration for the action
]]
function ActionPriority.Register(name: string, config: ActionConfig)
	if ActionTypes[name] then
		warn(`[ActionPriority] Overwriting existing action type: {name}`)
	end

	-- Validate priority
	if config.priority < 0 or config.priority > 6 then
		warn(`[ActionPriority] Priority must be 0-6, got {config.priority} for {name}`)
		config.priority = math.clamp(config.priority, 0, 6)
	end

	ActionTypes[name] = config
end

--[[
	Get a registered action configuration
	@param name string - Action type name
	@return ActionConfig? - The configuration or nil
]]
function ActionPriority.Get(name: string): ActionConfig?
	return ActionTypes[name]
end

--[[
	Get the current action priority for a character
	@param character Model - The character to check
	@return number - Current priority (0 if no action)
]]
function ActionPriority.GetCurrentPriority(character: Model): number
	local activeAction = ActiveActions[character]
	if activeAction and os.clock() < activeAction.endTime then
		return activeAction.priority
	end
	return 0
end

--[[
	Get the current action name and priority
	@param character Model - The character to check
	@return string?, number - Current action name and priority (nil, 0 if none)
]]
function ActionPriority.GetCurrentAction(character: Model): (string?, number)
	local activeAction = ActiveActions[character]
	if activeAction and os.clock() < activeAction.endTime then
		return activeAction.actionName, activeAction.priority
	end
	return nil, 0
end

--[[
	Check if an action can cancel the current action
	@param character Model - The character to check
	@param newActionName string - The action that wants to start
	@return boolean - True if the new action can start
]]
function ActionPriority.CanStartAction(character: Model, newActionName: string): boolean
	local newConfig = ActionTypes[newActionName]
	if not newConfig then
		-- Unknown action types default to priority 3 (attack level)
		warn(`[ActionPriority] Unknown action type: {newActionName}, defaulting to priority 3`)
		return ActionPriority.GetCurrentPriority(character) <= 3
	end

	local currentAction, currentPriority = ActionPriority.GetCurrentAction(character)

	-- No current action, always allow
	if not currentAction then
		return true
	end

	local currentConfig = ActionTypes[currentAction]

	-- Check if current action explicitly cannot be cancelled by new action
	if currentConfig and currentConfig.cannotCancel then
		for _, blockedAction in ipairs(currentConfig.cannotCancel) do
			if blockedAction == newActionName then
				return false
			end
		end
	end

	-- Check if new action is in the explicit cancel list
	if currentConfig and currentConfig.canBeCancelledBy then
		for _, allowedAction in ipairs(currentConfig.canBeCancelledBy) do
			if allowedAction == newActionName then
				return true
			end
		end
	end

	-- Standard priority comparison: higher priority wins
	return newConfig.priority > currentPriority
end

--[[
	Start an action, cancelling any lower-priority action
	@param character Model - The character performing the action
	@param actionName string - The action type
	@param options StartOptions? - Optional overrides
	@return boolean - True if action was started
]]
function ActionPriority.StartAction(character: Model, actionName: string, options: StartOptions?): boolean
	options = options or {}

	local config = ActionTypes[actionName]
	local priority = config and config.priority or 3

	-- Ensure cleanup is setup for this character
	setupCharacterCleanup(character)

	-- Check if we can start (unless forced)
	if not options.force and not ActionPriority.CanStartAction(character, actionName) then
		return false
	end

	-- Cancel current action if needed
	if not options.noCancel then
		ActionPriority.CancelCurrentAction(character)
	end

	-- Calculate duration
	local duration = options.duration or (config and config.duration) or 1.0
	local endTime = os.clock() + duration

	-- Store active action in ActionPriority tracking
	ActiveActions[character] = {
		actionName = actionName,
		priority = priority,
		endTime = endTime,
	}

	-- Also sync to StateManager for backwards compatibility
	-- This ensures systems reading StateActions still work
	StateManager.TimedState(character, "Actions", actionName, duration)

	-- Schedule cleanup
	task.delay(duration, function()
		-- Check if character still exists (prevents cleanup on dead characters)
		if not character or not character.Parent then
			return
		end

		local activeAction = ActiveActions[character]
		if activeAction and activeAction.actionName == actionName and activeAction.endTime == endTime then
			ActiveActions[character] = nil
			-- Clear cancel callback
			if CancelCallbacks[character] then
				CancelCallbacks[character][actionName] = nil
			end
		end
	end)

	return true
end

--[[
	Register a callback for when an action is cancelled
	@param character Model - The character
	@param actionName string - The action to watch
	@param callback function - Called when action is cancelled
]]
function ActionPriority.OnCancel(character: Model, actionName: string, callback: () -> ())
	if not CancelCallbacks[character] then
		CancelCallbacks[character] = {}
	end
	CancelCallbacks[character][actionName] = callback
end

--[[
	Cancel the current action for a character
	@param character Model - The character
	@return boolean - True if an action was cancelled
]]
function ActionPriority.CancelCurrentAction(character: Model): boolean
	local activeAction = ActiveActions[character]
	if not activeAction then
		return false
	end

	-- Call cancel callback if registered
	if CancelCallbacks[character] and CancelCallbacks[character][activeAction.actionName] then
		CancelCallbacks[character][activeAction.actionName]()
		CancelCallbacks[character][activeAction.actionName] = nil
	end

	-- Also remove from StateManager for consistency
	StateManager.RemoveState(character, "Actions", activeAction.actionName)

	ActiveActions[character] = nil
	return true
end

--[[
	End an action normally (not cancelled)
	@param character Model - The character
	@param actionName string? - Specific action to end (nil = any)
	@return boolean - True if action was ended
]]
function ActionPriority.EndAction(character: Model, actionName: string?): boolean
	local activeAction = ActiveActions[character]
	if not activeAction then
		return false
	end

	-- If specific action name provided, check it matches
	if actionName and activeAction.actionName ~= actionName then
		return false
	end

	ActiveActions[character] = nil

	-- Clear cancel callback (not called since action ended normally)
	if CancelCallbacks[character] and CancelCallbacks[character][activeAction.actionName] then
		CancelCallbacks[character][activeAction.actionName] = nil
	end

	return true
end

--[[
	Clear all actions from a character (used on respawn)
	@param character Model - The character to clear
]]
function ActionPriority.ClearAll(character: Model)
	ActiveActions[character] = nil
	CancelCallbacks[character] = nil

	-- Disconnect cleanup connection
	if CleanupConnections[character] then
		CleanupConnections[character]:Disconnect()
		CleanupConnections[character] = nil
	end
end

--[[
	Check if character is in an action
	@param character Model - The character to check
	@return boolean - True if in an action
]]
function ActionPriority.IsInAction(character: Model): boolean
	local activeAction = ActiveActions[character]
	return activeAction ~= nil and os.clock() < activeAction.endTime
end

--[[
	Check if character is in a specific action type
	@param character Model - The character to check
	@param actionName string - The action to check for
	@return boolean - True if in that specific action
]]
function ActionPriority.IsInActionType(character: Model, actionName: string): boolean
	local currentAction = ActionPriority.GetCurrentAction(character)
	return currentAction == actionName
end

--[[
	Get remaining time for current action
	@param character Model - The character to check
	@return number - Remaining time in seconds (0 if no action)
]]
function ActionPriority.GetRemainingTime(character: Model): number
	local activeAction = ActiveActions[character]
	if activeAction then
		return math.max(0, activeAction.endTime - os.clock())
	end
	return 0
end

-- ============================================
-- DEFAULT ACTION REGISTRATIONS
-- ============================================

-- Priority 1: Movement (easiest to cancel)
ActionPriority.Register("Walking", {
	priority = 1,
	cancelOnStun = true,
	cancelOnDamage = false,
})

ActionPriority.Register("Sprinting", {
	priority = 1,
	cancelOnStun = true,
	cancelOnDamage = false,
})

ActionPriority.Register("RunningAttack", {
	priority = 1, -- Same as sprint so M1 can cancel it
	cancelOnStun = true,
	cancelOnDamage = true,
})

-- Priority 2: Dashing/Dodging
ActionPriority.Register("Dodge", {
	priority = 2,
	duration = 0.35,
	cancelOnStun = true,
	cancelOnDamage = false,
	canBeCancelledBy = {"M1Attack", "M2Attack", "Skill", "HyperArmorSkill"}, -- Attacks can cancel dodge
})

ActionPriority.Register("Dashing", {
	priority = 2,
	duration = 0.5,
	cancelOnStun = true,
	cancelOnDamage = false,
})

-- Priority 3: Attacks (M1, M2/Critical)
ActionPriority.Register("M1Attack", {
	priority = 3,
	cancelOnStun = true,
	cancelOnDamage = true,
	canBeCancelledBy = {"Dodge", "Skill", "HyperArmorSkill"}, -- Can cancel into dodge or skills
})

ActionPriority.Register("M2Attack", {
	priority = 3,
	cancelOnStun = true,
	cancelOnDamage = true,
	canBeCancelledBy = {"Skill", "HyperArmorSkill"}, -- Can cancel into skills
})

ActionPriority.Register("Critical", {
	priority = 3,
	cancelOnStun = true,
	cancelOnDamage = true,
})

ActionPriority.Register("KnockbackFollowUp", {
	priority = 4, -- Higher than M1/M2 so it can cancel M1 endlag
	cancelOnStun = true,
	cancelOnDamage = true,
})

-- Priority 4: Skills
ActionPriority.Register("Skill", {
	priority = 4,
	cancelOnStun = true,
	cancelOnDamage = false,
	canBeCancelledBy = {"HyperArmorSkill"}, -- Only hyper armor skills can cancel
})

ActionPriority.Register("Block", {
	priority = 4, -- Block is like a skill, can cancel attacks
	cancelOnStun = true,
	cancelOnDamage = false,
})

ActionPriority.Register("Parry", {
	priority = 4,
	duration = 0.5,
	cancelOnStun = true,
	cancelOnDamage = false,
})

-- Priority 5: Hyper Armor Skills (hard to cancel)
ActionPriority.Register("HyperArmorSkill", {
	priority = 5,
	cancelOnStun = false, -- Hyper armor resists stuns
	cancelOnDamage = false,
	cannotCancel = {}, -- Nothing lower can cancel this
})

ActionPriority.Register("PincerImpact", {
	priority = 5,
	cancelOnStun = false,
	cancelOnDamage = false,
})

-- Priority 6: Ultimate/Cinematic (cannot be interrupted)
ActionPriority.Register("Ultimate", {
	priority = 6,
	cancelOnStun = false,
	cancelOnDamage = false,
})

ActionPriority.Register("Cinematic", {
	priority = 6,
	cancelOnStun = false,
	cancelOnDamage = false,
})

-- ============================================
-- ECS ENTITY-BASED FUNCTIONS
-- ============================================
-- These functions work with ECS entities instead of Model instances
-- Use CurrentAction component for tracking

--[[
	Check if an ECS entity can perform any action
	@param entity number - The ECS entity to check
	@return boolean - True if entity can act
]]
function ActionPriority.CanActECS(entity: number): boolean
	-- Dead entities can't act
	if world:has(entity, tags.Dead) then return false end

	-- Stunned entities can't act
	if world:has(entity, tags.Stunned) then return false end

	-- Check for Stun component (duration-based)
	local stun = world:get(entity, comps.Stun)
	if stun and stun.value and stun.duration > 0 then return false end

	-- Check for CantMove component
	local cantMove = world:get(entity, comps.CantMove)
	if cantMove and cantMove.value then return false end

	return true
end

--[[
	Start an action via ECS component
	@param entity number - The ECS entity
	@param actionName string - The action type name
	@param priority number - Priority level (0-6)
	@param duration number? - Optional duration
	@param interruptible boolean? - Can be interrupted by same priority
	@return boolean - True if action was started
]]
function ActionPriority.StartActionECS(entity: number, actionName: string, priority: number, duration: number?, interruptible: boolean?): boolean
	if not ActionPriority.CanActECS(entity) then
		return false
	end

	local currentAction = world:get(entity, comps.CurrentAction)
	if currentAction then
		-- Can't start if current action has higher priority
		if currentAction.priority > priority then
			return false
		end
		-- Same priority requires interruptible
		if currentAction.priority == priority and not currentAction.interruptible then
			return false
		end
	end

	world:set(entity, comps.CurrentAction, {
		name = actionName,
		priority = priority,
		startTime = os.clock(),
		duration = duration,
		interruptible = interruptible or false
	})

	return true
end

--[[
	End an action via ECS component
	@param entity number - The ECS entity
	@param actionName string? - Specific action to end (nil = any)
]]
function ActionPriority.EndActionECS(entity: number, actionName: string?)
	local currentAction = world:get(entity, comps.CurrentAction)
	if not currentAction then return end

	if actionName and currentAction.name ~= actionName then
		return
	end

	world:remove(entity, comps.CurrentAction)
end

--[[
	Check if entity is in an action via ECS
	@param entity number - The ECS entity
	@return boolean - True if in action
]]
function ActionPriority.IsInActionECS(entity: number): boolean
	local currentAction = world:get(entity, comps.CurrentAction)
	if not currentAction then return false end

	-- Check if action has expired
	if currentAction.duration then
		local elapsed = os.clock() - currentAction.startTime
		if elapsed >= currentAction.duration then
			world:remove(entity, comps.CurrentAction)
			return false
		end
	end

	return true
end

--[[
	Get current action from ECS component
	@param entity number - The ECS entity
	@return table? - Current action data or nil
]]
function ActionPriority.GetCurrentActionECS(entity: number)
	return world:get(entity, comps.CurrentAction)
end

return ActionPriority
