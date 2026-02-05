local Library = {};
Library.__index = Library;
local self = setmetatable({}, Library);

local Utilities = require(script.Parent.Utilities);
local Debris    = Utilities.Debris;

local Players 	  = game:GetService("Players");
local RunService  = game:GetService("RunService");
local HttpService = game:GetService("HttpService");
local Replicated  = game:GetService("ReplicatedStorage");

-- Import ECS state and cooldown managers
local StateManager = require(Replicated.Modules.ECS.StateManager)
local CooldownManager = require(Replicated.Modules.ECS.CooldownManager)

-- Import specialized services (Library delegates to these for better organization)
local AnimationService = require(Replicated.Modules.Services.AnimationService)
local SoundService = require(Replicated.Modules.Services.SoundService)
local BodyMoverService = require(Replicated.Modules.Services.BodyMoverService)

-- Lazy load ActionPriority to avoid circular dependencies (declared early for CleanupCharacter)
local ActionPriority = nil
local function getActionPriority()
	if not ActionPriority then
		local success, module = pcall(function()
			return require(Replicated.Modules.ECS.ActionPriority)
		end)
		if success then
			ActionPriority = module
		else
			warn("[Library] Failed to load ActionPriority:", module)
		end
	end
	return ActionPriority
end

-- Lazy load UnifiedStateController for coordinated state management
local UnifiedStateController = nil
local function getUnifiedStateController()
	if not UnifiedStateController then
		local success, module = pcall(function()
			return require(Replicated.Modules.ECS.UnifiedStateController)
		end)
		if success then
			UnifiedStateController = module
		else
			warn("[Library] Failed to load UnifiedStateController:", module)
		end
	end
	return UnifiedStateController
end

-- Cooldowns are now managed by ECS CooldownManager
-- Animations are now managed by AnimationService (but we keep local cache for backwards compat)
local Animations = {};

-- ============================================
-- ANIMATION FUNCTIONS (delegate to AnimationService)
-- ============================================

Library.PlayAnimation = function(Char: Model, Name, Transition: number)
	return AnimationService.PlayAnimation(Char, Name, Transition)
end

Library.StopAnimation = function(Char: Model, Name, FadeTime)
	AnimationService.StopAnimation(Char, Name, FadeTime)
end

Library.StopAllAnims = function(Char: Model)
	AnimationService.StopAllAnims(Char)
end

-- Comprehensive cleanup function for character respawn
Library.CleanupCharacter = function(Char: Model)
	if not Char then return end

	-- Clear animation cache via AnimationService
	AnimationService.ClearAnimationCache(Char)

	-- Clear cooldowns for this character (ECS-based)
	CooldownManager.ClearAllCooldowns(Char)

	-- Clear all states for this character (ECS-based)
	for _, category in ipairs({"Actions", "Stuns", "IFrames", "Speeds", "Frames", "Status"}) do
		StateManager.ClearCategory(Char, category)
	end

	-- Clear action priority tracking for this character
	local priority = getActionPriority()
	if priority then
		priority.ClearAll(Char)
	end

	-- Stop all playing animation tracks via AnimationService
	AnimationService.StopAndDestroyAllTracks(Char)

	-- Clean up all body movers via BodyMoverService
	BodyMoverService.RemoveAllBodyMovers(Char)
end

Library.StopMovementAnimations = function(Char: Model)
	AnimationService.StopMovementAnimations(Char)
end

-- Remove all body movers from a character to prevent flinging (delegate to BodyMoverService)
Library.RemoveAllBodyMovers = function(Char: Model)
	return BodyMoverService.RemoveAllBodyMovers(Char)
end

Library.PlaySound = function(Origin, S,Overlap: boolean,Speed: number)
	local Sound = S
	if not Sound then return end;

	if Sound:IsA("Folder") then
		Sound = Sound:GetChildren()[math.random(1,#Sound:GetChildren())]
	end

	if typeof(Origin) == "CFrame" then
		local Part = script.SoundPart:Clone()
		Part.CFrame = Origin
		Part.Parent = workspace

		local SoundClone = Sound:Clone()
		SoundClone.Name = "SoundClone"
		SoundClone.PlaybackSpeed *= (1+(0.1)*(math.random()*2-1))

		local Time = 5 + (SoundClone.TimeLength / SoundClone.PlaybackSpeed)
		SoundClone.Parent = Part
		Debris:AddItem(Part,Time)


		coroutine.wrap(function()
			RunService.Stepped:Wait()
			SoundClone:Play()
		end)()

		return SoundClone
	else
		if Sound and Origin:FindFirstChild("Torso") then
			local SoundClone = Sound:Clone()

			if Overlap then
				SoundClone.Name = "Overlap"
			else
				SoundClone.Name = "SoundClone"
			end

			SoundClone.PlaybackSpeed *= (1+(Speed or 0.1)*(math.random()*2-1))

			local Time = 5+(SoundClone.TimeLength / SoundClone.PlaybackSpeed)
			SoundClone.Parent = Origin.Torso
			Debris:AddItem(SoundClone,SoundClone.TimeLength)

			coroutine.wrap(function()
				RunService.Stepped:Wait()
				SoundClone:Play()
			end)()

			return SoundClone
		elseif Sound and Origin:IsA("Part") then
			local SoundClone = Sound:Clone()

			if Overlap then
				SoundClone.Name = "Overlap"
			else
				SoundClone.Name = "SoundClone"
			end

			SoundClone.PlaybackSpeed *= (1+(Speed or 0.1)*(math.random()*2-1))

			local Time = 5+(SoundClone.TimeLength / SoundClone.PlaybackSpeed)
			SoundClone.Parent = Origin
			Debris:AddItem(SoundClone,SoundClone.TimeLength)

			coroutine.wrap(function()
				RunService.Stepped:Wait()
				SoundClone:Play()
			end)()

			return SoundClone
		end
	end
end

-- ECS-based cooldown functions
Library.SetCooldown = function(Char: Model, Identifier: string, Time: number)
	CooldownManager.SetCooldown(Char, Identifier, Time)
end

Library.CheckCooldown = function(Char: Model, Identifier: string)
	return CooldownManager.CheckCooldown(Char, Identifier)
end

Library.ResetCooldown = function(Char: Model, Identifier: string)
	CooldownManager.ResetCooldown(Char, Identifier)
end

Library.GetCooldowns = function(Char: Model)
	return CooldownManager.GetCooldowns(Char)
end

Library.GetCooldownTime = function(Char: Model, Identifier: string)
	return CooldownManager.GetCooldownTime(Char, Identifier)
end

function ReturnDecodedTable(Table)
	return HttpService:JSONDecode(Table.Value)
end

function ReturnEncodedTable(Table)
	return HttpService:JSONEncode(Table)
end

-- Helper to extract category from StringValue name
local function getCategoryFromStringValue(stringValue)
	local name = stringValue.Name
	-- Map old StringValue names to new categories
	local categoryMap = {
		Actions = "Actions",
		Stuns = "Stuns",
		IFrames = "IFrames",
		Speeds = "Speeds",
		Frames = "Frames",
		Status = "Status",
	}
	return categoryMap[name] or "Actions"
end

-- Helper to get character from StringValue
local function getCharacterFromStringValue(stringValue)
	-- Validate input
	if not stringValue or typeof(stringValue) ~= "Instance" then
		-- Silent fail for nil - this is expected when character is respawning
		return nil
	end

	if not stringValue:IsA("StringValue") then
		warn(`[Library] Expected StringValue, got {stringValue.ClassName} named "{stringValue.Name}"`)
		return nil
	end

	local parent = stringValue.Parent
	if not parent then
		-- Silent fail for no parent - StringValue might be destroyed
		return nil
	end

	if not parent:IsA("Model") then
		warn(`[Library] StringValue "{stringValue.Name}" parent is not a Model: {parent.ClassName} named "{parent.Name}"`)
		return nil
	end

	return parent
end

-- ECS-based state functions
Library.StateCheck = function(Table, FrameName)
	local character = getCharacterFromStringValue(Table)
	if not character then return false end

	local category = getCategoryFromStringValue(Table)
	return StateManager.StateCheck(character, category, FrameName)
end

-- StateCount: Supports both old API (StringValue) and new API (character, category)
-- Old: Library.StateCount(Character.Stuns)
-- New: Library.StateCount(Character, "Stuns")
Library.StateCount = function(TableOrCharacter, category: string?)
	-- New API: (character, category)
	if typeof(TableOrCharacter) == "Instance" and TableOrCharacter:IsA("Model") and category then
		return StateManager.StateCount(TableOrCharacter, category)
	end

	-- Old API: (StringValue)
	local character = getCharacterFromStringValue(TableOrCharacter)
	if not character then return false end

	local categoryFromSV = getCategoryFromStringValue(TableOrCharacter)
	return StateManager.StateCount(character, categoryFromSV)
end

Library.MultiStateCheck = function(Table, Query)
	local character = getCharacterFromStringValue(Table)
	if not character then return true end

	local category = getCategoryFromStringValue(Table)
	return StateManager.MultiStateCheck(character, category, Query)
end

Library.AddState = function(Table, Name)
	local character = getCharacterFromStringValue(Table)
	if not character then return end

	local category = getCategoryFromStringValue(Table)
	StateManager.AddState(character, category, Name)
end

Library.RemoveState = function(Table, Name)
	local character = getCharacterFromStringValue(Table)
	if not character then return end

	local category = getCategoryFromStringValue(Table)
	StateManager.RemoveState(character, category, Name)
end

Library.TimedState = function(Table, Name, Time)
	local character = getCharacterFromStringValue(Table)
	if not character then return end

	local category = getCategoryFromStringValue(Table)
	StateManager.TimedState(character, category, Name, Time)
end

Library.RemoveAllStates = function(Table, Name)
	local character = getCharacterFromStringValue(Table)
	if not character then return end

	local category = getCategoryFromStringValue(Table)
	StateManager.RemoveAllStates(character, category, Name)
end

Library.Remove = function(Char) --> For Clean Up
	if Animations[Char.Name] then Animations[Char.Name] = nil end;
	-- Cooldowns are now managed by ECS
	CooldownManager.ClearAllCooldowns(Char)
end

-- GetAllStates: Supports both old API (StringValue) and new API (character, category)
-- Old: Library.GetAllStates(Character.Stuns)
-- New: Library.GetAllStates(Character, "Stuns")
Library.GetAllStates = function(TableOrCharacter, category: string?)
	-- New API: (character, category)
	if typeof(TableOrCharacter) == "Instance" and TableOrCharacter:IsA("Model") and category then
		return StateManager.GetAllStates(TableOrCharacter, category)
	end

	-- Old API: (StringValue)
	local character = getCharacterFromStringValue(TableOrCharacter)
	if not character then return {} end

	local categoryFromSV = getCategoryFromStringValue(TableOrCharacter)
	return StateManager.GetAllStates(character, categoryFromSV)
end

Library.GetAllStatesFromCharacter = function(Char: Model)
	return StateManager.GetAllStatesFromCharacter(Char)
end

Library.GetSpecificState = function(Char: Model, DesiredState: string)
	if not Char then return nil end

	-- Check all state categories for the desired state
	local allStates = StateManager.GetAllStatesFromCharacter(Char)

	for category, states in pairs(allStates) do
		for _, state in ipairs(states) do
			if string.match(state, DesiredState) then
				-- Return a mock StringValue for backwards compatibility
				local mockStringValue = Instance.new("StringValue")
				mockStringValue.Name = category
				mockStringValue.Parent = Char
				return mockStringValue
			end
		end
	end

	return nil
end

-- ============================================
-- STUN REGISTRY INTEGRATION
-- Priority-based stun system for easy stun registration
-- ============================================

-- Lazy load StunRegistry to avoid circular dependencies
local StunRegistry = nil
local function getStunRegistry()
	if not StunRegistry then
		local success, module = pcall(function()
			return require(Replicated.Modules.ECS.StunRegistry)
		end)
		if success then
			StunRegistry = module
		else
			warn("[Library] Failed to load StunRegistry")
		end
	end
	return StunRegistry
end

--[[
	Apply a registered stun to a character
	Uses the priority-based StunRegistry system
	@param Char Model - Character to stun
	@param StunName string - Name of registered stun type
	@param Duration number? - Optional duration override
	@param Invoker Model? - Who applied the stun
	@return boolean - True if stun was applied
]]
Library.ApplyStun = function(Char: Model, StunName: string, Duration: number?, Invoker: Model?): boolean
	local registry = getStunRegistry()
	if not registry then
		-- Fallback to ECS StateManager
		StateManager.TimedState(Char, "Stuns", StunName, Duration or 0.5)
		return true
	end

	return registry.Apply(Char, StunName, {
		duration = Duration,
		invoker = Invoker,
	})
end

--[[
	Check if a stun can be applied (priority check)
	@param Char Model - Character to check
	@param StunName string - Stun type to check
	@return boolean - True if stun can be applied
]]
Library.CanApplyStun = function(Char: Model, StunName: string): boolean
	local registry = getStunRegistry()
	if not registry then
		return true -- Fallback: always allow
	end

	return registry.CanApply(Char, StunName)
end

--[[
	Get the current stun priority for a character
	@param Char Model - Character to check
	@return number - Priority level (0-10, 0 = no stun)
]]
Library.GetStunPriority = function(Char: Model): number
	local registry = getStunRegistry()
	if not registry then
		return 0
	end

	return registry.GetCurrentPriority(Char)
end

--[[
	Remove a stun from a character early
	@param Char Model - Character to unstun
	@param StunName string? - Specific stun to remove (nil = any)
	@return boolean - True if stun was removed
]]
Library.RemoveStun = function(Char: Model, StunName: string?): boolean
	local registry = getStunRegistry()
	if not registry then
		if StunName then
			StateManager.RemoveState(Char, "Stuns", StunName)
		end
		return true
	end

	return registry.Remove(Char, StunName)
end

--[[
	Check if character can perform actions
	@param Char Model - Character to check
	@return boolean - True if can act
]]
Library.CanAct = function(Char: Model): boolean
	local registry = getStunRegistry()
	if not registry then
		return not StateManager.StateCount(Char, "Stuns")
	end

	return registry.CanAct(Char)
end

--[[
	Check if character can block
	@param Char Model - Character to check
	@return boolean - True if can block
]]
Library.CanBlock = function(Char: Model): boolean
	local registry = getStunRegistry()
	if not registry then
		return not StateManager.StateCount(Char, "Stuns")
	end

	return registry.CanBlock(Char)
end

--[[
	Check if character can dodge
	@param Char Model - Character to check
	@return boolean - True if can dodge
]]
Library.CanDodge = function(Char: Model): boolean
	local registry = getStunRegistry()
	if not registry then
		return not StateManager.StateCount(Char, "Stuns")
	end

	return registry.CanDodge(Char)
end

--[[
	Check if character can parry
	@param Char Model - Character to check
	@return boolean - True if can parry
]]
Library.CanParry = function(Char: Model): boolean
	local registry = getStunRegistry()
	if not registry then
		return not StateManager.StateCheck(Char, "Stuns", "M1Stun")
	end

	return registry.CanParry(Char)
end

--[[
	Register a custom stun type
	@param Name string - Unique stun name
	@param Config table - Stun configuration
		priority: number (0-10)
		duration: number? (default duration)
		speedModifier: number? (negative value)
		canAct: boolean?
		canMove: boolean?
		canBlock: boolean?
		canDodge: boolean?
		canParry: boolean?
		lockRotation: boolean?
		iframes: boolean?
]]
Library.RegisterStun = function(Name: string, Config: {})
	local registry = getStunRegistry()
	if not registry then
		warn("[Library] Cannot register stun - StunRegistry not loaded")
		return
	end

	registry.Register(Name, Config)
end

--[[
	Clear all stuns from a character (used on respawn)
	@param Char Model - Character to clear
]]
Library.ClearAllStuns = function(Char: Model)
	local registry = getStunRegistry()
	if registry then
		registry.ClearAll(Char)
	else
		StateManager.ClearCategory(Char, "Stuns")
	end
end

-- ============================================
-- STUN SCALING SYSTEM
-- Diminishing returns on repeated stuns
-- ============================================

--[[
	Get the current stun scaling factor for a character
	@param Char Model - Character to check
	@return number - Scaling factor (1.0 = full duration, lower = shorter stuns)
]]
Library.GetStunScaling = function(Char: Model): number
	local registry = getStunRegistry()
	if not registry then
		return 1.0
	end

	return registry.GetScalingFactor(Char)
end

--[[
	Clear stun history for a character (resets scaling)
	@param Char Model - Character to clear history for
]]
Library.ClearStunHistory = function(Char: Model)
	local registry = getStunRegistry()
	if not registry then
		return
	end

	registry.ClearStunHistory(Char)
end

-- ============================================
-- ACTION PRIORITY INTEGRATION
-- Priority-based action cancellation system
-- (getActionPriority is defined at the top of the file)
-- ============================================

--[[
	Check if an action can be started (will cancel current if lower priority)
	@param Char Model - Character to check
	@param ActionName string - The action that wants to start
	@return boolean - True if action can start
]]
Library.CanStartAction = function(Char: Model, ActionName: string): boolean
	local priority = getActionPriority()
	if not priority then
		return true -- Fallback: always allow
	end

	return priority.CanStartAction(Char, ActionName)
end

--[[
	Start an action, cancelling any lower-priority action
	@param Char Model - Character performing the action
	@param ActionName string - The action type
	@param Duration number? - Optional duration override
	@param Options table? - Additional options (force, noCancel)
	@return boolean - True if action was started
]]
Library.StartAction = function(Char: Model, ActionName: string, Duration: number?, Options: {}?): boolean
	local priority = getActionPriority()
	if not priority then
		return true -- Fallback: always allow
	end

	local opts = Options or {}
	opts.duration = Duration or opts.duration

	return priority.StartAction(Char, ActionName, opts)
end

--[[
	Register a callback for when an action is cancelled
	@param Char Model - The character
	@param ActionName string - The action to watch
	@param Callback function - Called when action is cancelled
]]
Library.OnActionCancel = function(Char: Model, ActionName: string, Callback: () -> ())
	local priority = getActionPriority()
	if not priority then
		return
	end

	priority.OnCancel(Char, ActionName, Callback)
end

--[[
	End an action normally (not cancelled)
	@param Char Model - The character
	@param ActionName string? - Specific action to end (nil = any)
	@return boolean - True if action was ended
]]
Library.EndAction = function(Char: Model, ActionName: string?): boolean
	local priority = getActionPriority()
	if not priority then
		return true
	end

	return priority.EndAction(Char, ActionName)
end

--[[
	Cancel the current action for a character
	@param Char Model - The character
	@return boolean - True if an action was cancelled
]]
Library.CancelCurrentAction = function(Char: Model): boolean
	local priority = getActionPriority()
	if not priority then
		return false
	end

	return priority.CancelCurrentAction(Char)
end

--[[
	Get the current action priority for a character
	@param Char Model - The character to check
	@return number - Priority level (0-6, 0 = no action)
]]
Library.GetActionPriority = function(Char: Model): number
	local priority = getActionPriority()
	if not priority then
		return 0
	end

	return priority.GetCurrentPriority(Char)
end

--[[
	Get the current action name and priority
	@param Char Model - The character to check
	@return string?, number - Current action name and priority (nil, 0 if none)
]]
Library.GetCurrentAction = function(Char: Model): (string?, number)
	local priority = getActionPriority()
	if not priority then
		return nil, 0
	end

	return priority.GetCurrentAction(Char)
end

--[[
	Check if character is in an action
	@param Char Model - The character to check
	@return boolean - True if in an action
]]
Library.IsInAction = function(Char: Model): boolean
	local priority = getActionPriority()
	if not priority then
		return false
	end

	return priority.IsInAction(Char)
end

--[[
	Check if character is in a specific action type
	@param Char Model - The character to check
	@param ActionName string - The action to check for
	@return boolean - True if in that specific action
]]
Library.IsInActionType = function(Char: Model, ActionName: string): boolean
	local priority = getActionPriority()
	if not priority then
		return false
	end

	return priority.IsInActionType(Char, ActionName)
end

--[[
	Register a custom action type
	@param Name string - Unique action name
	@param Config table - Action configuration
		priority: number (0-6)
		canBeCancelledBy: {string}? (list of actions that can cancel this)
		cannotCancel: {string}? (list of actions this cannot cancel)
		duration: number? (default duration)
		cancelOnStun: boolean? (default: true)
		cancelOnDamage: boolean? (default: false)
]]
Library.RegisterAction = function(Name: string, Config: {})
	local priority = getActionPriority()
	if not priority then
		warn("[Library] Cannot register action - ActionPriority not loaded")
		return
	end

	priority.Register(Name, Config)
end

--[[
	Clear all actions from a character (used on respawn)
	@param Char Model - Character to clear
]]
Library.ClearAllActions = function(Char: Model)
	local priority = getActionPriority()
	if priority then
		priority.ClearAll(Char)
	end
end

-- ============================================
-- UNIFIED STATE CONTROLLER INTEGRATION
-- Coordinated priority-based state management
-- ============================================

--[[
	Check if a state can be started using unified priority system
	Routes through UnifiedStateController for coordinated action/stun handling
	@param Char Model - The character
	@param StateName string - The state to check
	@return boolean - True if state can start
]]
Library.CanStartState = function(Char: Model, StateName: string): boolean
	local controller = getUnifiedStateController()
	if controller then
		return controller.CanStart(Char, StateName)
	end
	-- Fallback to ActionPriority
	return Library.CanStartAction(Char, StateName)
end

--[[
	Start a state using unified priority system
	Handles cancellation of lower-priority states with proper cleanup
	@param Char Model - The character
	@param StateName string - The state to start
	@param Duration number? - Optional duration
	@return boolean - True if state was started
]]
Library.StartState = function(Char: Model, StateName: string, Duration: number?): boolean
	local controller = getUnifiedStateController()
	if controller then
		return controller.Start(Char, StateName, { duration = Duration })
	end
	-- Fallback to ActionPriority
	return Library.StartAction(Char, StateName, Duration)
end

--[[
	Apply a stun using unified priority system
	Handles stun vs action priority, hyper armor, and cleanup
	@param Char Model - The character
	@param StunName string - The stun type
	@param Duration number? - Optional duration override
	@param Invoker Model? - Who applied the stun
	@return boolean - True if stun was applied
]]
Library.ApplyUnifiedStun = function(Char: Model, StunName: string, Duration: number?, Invoker: Model?): boolean
	local controller = getUnifiedStateController()
	if controller then
		return controller.ApplyStun(Char, StunName, {
			duration = Duration,
			invoker = Invoker,
		})
	end
	-- Fallback to StunRegistry
	return Library.ApplyStun(Char, StunName, Duration, Invoker)
end

--[[
	Get the current unified state for a character
	@param Char Model - The character
	@return string?, number, string - State name, priority, category
]]
Library.GetUnifiedState = function(Char: Model): (string?, number, string)
	local controller = getUnifiedStateController()
	if controller then
		return controller.GetCurrentState(Char)
	end
	-- Fallback
	local actionName, actionPriority = Library.GetCurrentAction(Char)
	return actionName, actionPriority, "Action"
end

--[[
	Force cancel all states for a character
	Used for death, respawn, or forced interrupts
	@param Char Model - The character
]]
Library.ForceCancelState = function(Char: Model)
	local controller = getUnifiedStateController()
	if controller then
		controller.ForceCancel(Char)
	else
		-- Fallback: cancel action and clear stuns
		Library.CancelCurrentAction(Char)
		Library.ClearAllStuns(Char)
	end
end

--[[
	Setup character cleanup tracking for unified state system
	Should be called when character is added
	@param Char Model - The character
]]
Library.SetupUnifiedStateCleanup = function(Char: Model)
	local controller = getUnifiedStateController()
	if controller then
		controller.SetupCharacterCleanup(Char)
	end
end

--[[
	Register a unified state type (action + stun combined config)
	@param Name string - Unique state name
	@param Config table - State configuration (see UnifiedStateController)
]]
Library.RegisterUnifiedState = function(Name: string, Config: {})
	local controller = getUnifiedStateController()
	if controller then
		controller.Register(Name, Config)
	else
		warn("[Library] Cannot register unified state - UnifiedStateController not loaded")
	end
end

--[[
	Get priority constants from UnifiedStateController
	@return table - Priority level constants
]]
Library.GetPriorityLevels = function(): {}
	local controller = getUnifiedStateController()
	if controller then
		return controller.Priority
	end
	-- Fallback priorities
	return {
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
end

return Library
