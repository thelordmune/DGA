--!strict
--[[
	ECS State Accessors

	Provides unified accessor functions for reading and writing state from ECS.
	Replaces direct boolean flags (Client.InAir, Client.Dodging, etc.) with ECS-backed operations.

	This module enables backwards-compatible migration from the old state system to pure ECS.
	All state reads/writes go through ECS components.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local world = require(script.Parent.jecs_world)
local comps = require(script.Parent.jecs_components)
local tags = require(script.Parent.jecs_tags)
local ref = require(script.Parent.jecs_ref)
local RefManager = require(script.Parent.jecs_ref_manager)
local StateManager = require(script.Parent.StateManager)

local StateAccessors = {}

-- Cache for performance
local entityCache: {[Model]: number} = {}
local cacheExpiry: {[Model]: number} = {}
local CACHE_TTL = 0.5 -- Cache entity lookups for 0.5 seconds

-- Client-side optimization: Cache local player character for parallel safety
local localPlayerCharacter: Model? = nil
local localPlayerEntity: number? = nil

-- Initialize local player cache on client
if RunService:IsClient() then
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		-- Update cache when character changes
		localPlayer.CharacterAdded:Connect(function(char)
			localPlayerCharacter = char
			localPlayerEntity = nil -- Will be re-fetched lazily
		end)

		if localPlayer.Character then
			localPlayerCharacter = localPlayer.Character
		end
	end
end

--[[
	Get ECS entity from character model with caching
	PARALLEL-SAFE: Avoids Players:GetPlayerFromCharacter() by using cached local player
	@param character Model - The character model
	@return number? - Entity ID or nil
]]
local function getEntity(character: Model): number?
	if not character or typeof(character) ~= "Instance" or not character:IsA("Model") then
		return nil
	end

	-- Check cache first (parallel-safe)
	local now = os.clock()
	if entityCache[character] and cacheExpiry[character] and cacheExpiry[character] > now then
		return entityCache[character]
	end

	local entity: number? = nil

	-- PARALLEL-SAFE: Check if this is the local player's character without calling GetPlayerFromCharacter
	if RunService:IsClient() and character == localPlayerCharacter then
		-- Fast path for local player (parallel-safe)
		if localPlayerEntity and cacheExpiry[character] and cacheExpiry[character] > now then
			return localPlayerEntity
		end

		entity = ref.get("player", Players.LocalPlayer)
		if not entity then
			entity = ref.get("local_player")
		end

		if entity then
			localPlayerEntity = entity
			entityCache[character] = entity
			cacheExpiry[character] = now + CACHE_TTL
		end

		return entity
	end

	-- For server or non-local-player characters, we need to synchronize
	-- This is safe because these paths are typically not called from parallel contexts
	local player = nil

	-- Try to detect if we're in a parallel context by attempting the call
	local success, result = pcall(function()
		return Players:GetPlayerFromCharacter(character)
	end)

	if not success then
		-- We're in a parallel context and need to synchronize
		task.synchronize()
		player = Players:GetPlayerFromCharacter(character)
	else
		player = result
	end

	if player then
		entity = ref.get("player", player)
		if not entity and RunService:IsClient() and player == Players.LocalPlayer then
			entity = ref.get("local_player")
		end
	else
		entity = RefManager.entity.find(character)
	end

	-- Cache result
	if entity then
		entityCache[character] = entity
		cacheExpiry[character] = now + CACHE_TTL
	end

	return entity
end

-- Clear cache when character is removed
local function clearCache(character: Model)
	entityCache[character] = nil
	cacheExpiry[character] = nil
end

-- ============================================
-- MOVEMENT STATE ACCESSORS
-- ============================================

--[[
	Check if character is in the air
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsInAir(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end
	return world:has(entity, tags.InAir) or world:has(entity, comps.InAir)
end

--[[
	Set in-air state
	@param character Model - The character model
	@param value boolean - Whether character is in air
]]
function StateAccessors.SetInAir(character: Model, value: boolean)
	local entity = getEntity(character)
	if not entity then return end

	if value then
		world:add(entity, tags.InAir)
	else
		if world:has(entity, tags.InAir) then
			world:remove(entity, tags.InAir)
		end
	end
end

--[[
	Check if character is dodging/dashing
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsDodging(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end
	return world:has(entity, tags.Dashing) or world:has(entity, comps.Dashing)
end

--[[
	Set dodging state
	@param character Model - The character model
	@param value boolean - Whether character is dodging
]]
function StateAccessors.SetDodging(character: Model, value: boolean)
	local entity = getEntity(character)
	if not entity then return end

	if value then
		world:add(entity, tags.Dashing)
		StateManager.AddState(character, "Actions", "Dashing")
	else
		if world:has(entity, tags.Dashing) then
			world:remove(entity, tags.Dashing)
		end
		StateManager.RemoveState(character, "Actions", "Dashing")
	end
end

--[[
	Check if character is running
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsRunning(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end

	-- Check ECS Sprinting component or Running tag
	if world:has(entity, tags.Running) then return true end
	if world:has(entity, comps.Sprinting) then
		local sprinting = world:get(entity, comps.Sprinting)
		return sprinting and sprinting.value == true
	end

	-- Also check StateActions for "Running"
	return StateManager.StateCheck(character, "Actions", "Running")
end

--[[
	Set running state
	@param character Model - The character model
	@param value boolean - Whether character is running
]]
function StateAccessors.SetRunning(character: Model, value: boolean)
	local entity = getEntity(character)
	if not entity then return end

	if value then
		world:set(entity, comps.Sprinting, { value = true })
		StateManager.AddState(character, "Actions", "Running")
	else
		world:set(entity, comps.Sprinting, { value = false })
		StateManager.RemoveState(character, "Actions", "Running")
	end
end

--[[
	Check if character is wall running
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsWallRunning(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end
	return world:has(entity, tags.WallRunning) or world:has(entity, comps.WallRunning)
end

--[[
	Set wall running state
	@param character Model - The character model
	@param value boolean - Whether character is wall running
]]
function StateAccessors.SetWallRunning(character: Model, value: boolean)
	local entity = getEntity(character)
	if not entity then return end

	if value then
		world:add(entity, tags.WallRunning)
		StateManager.AddState(character, "Actions", "WallRunning")
	else
		if world:has(entity, tags.WallRunning) then
			world:remove(entity, tags.WallRunning)
		end
		StateManager.RemoveState(character, "Actions", "WallRunning")
	end
end

--[[
	Check if character is ledge climbing
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsLedgeClimbing(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end

	if world:has(entity, tags.Climbing) then return true end
	return StateManager.StateCheck(character, "Actions", "LedgeClimbing")
end

--[[
	Set ledge climbing state
	@param character Model - The character model
	@param value boolean - Whether character is ledge climbing
]]
function StateAccessors.SetLedgeClimbing(character: Model, value: boolean)
	local entity = getEntity(character)
	if not entity then return end

	if value then
		world:add(entity, tags.Climbing)
		StateManager.AddState(character, "Actions", "LedgeClimbing")
	else
		if world:has(entity, tags.Climbing) then
			world:remove(entity, tags.Climbing)
		end
		StateManager.RemoveState(character, "Actions", "LedgeClimbing")
	end
end

--[[
	Check if character is leaping
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsLeaping(character: Model): boolean
	return StateManager.StateCheck(character, "Actions", "Leaping")
end

--[[
	Set leaping state
	@param character Model - The character model
	@param value boolean - Whether character is leaping
]]
function StateAccessors.SetLeaping(character: Model, value: boolean)
	if value then
		StateManager.AddState(character, "Actions", "Leaping")
	else
		StateManager.RemoveState(character, "Actions", "Leaping")
	end
end

--[[
	Check if character is in leap landing
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsLeapLanding(character: Model): boolean
	return StateManager.StateCheck(character, "Actions", "LeapLanding")
end

--[[
	Set leap landing state
	@param character Model - The character model
	@param value boolean - Whether character is in leap landing
]]
function StateAccessors.SetLeapLanding(character: Model, value: boolean)
	if value then
		StateManager.AddState(character, "Actions", "LeapLanding")
	else
		StateManager.RemoveState(character, "Actions", "LeapLanding")
	end
end

-- ============================================
-- COMBAT STATE ACCESSORS
-- ============================================

--[[
	Check if character is attacking
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsAttacking(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end

	-- Check ECS Attacking component
	if world:has(entity, comps.Attacking) then
		local attacking = world:get(entity, comps.Attacking)
		return attacking and attacking.value == true
	end

	-- Check tags
	if world:has(entity, tags.Attacking) then return true end

	-- Check StateActions for M1 attacks
	local actions = StateManager.GetAllStates(character, "Actions")
	for _, action in ipairs(actions) do
		if string.match(action, "^M1") then
			return true
		end
	end

	return false
end

--[[
	Check if character is blocking
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsBlocking(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end

	if world:has(entity, comps.Blocking) then
		local blocking = world:get(entity, comps.Blocking)
		return blocking and blocking.value == true
	end

	return StateManager.StateCheck(character, "Actions", "Blocking")
end

--[[
	Check if character is stunned
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsStunned(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end

	-- Check tag
	if world:has(entity, tags.Stunned) then return true end

	-- Check Stun component
	if world:has(entity, comps.Stun) then
		local stun = world:get(entity, comps.Stun)
		return stun and stun.value == true
	end

	-- Check StateStuns
	return StateManager.StateCount(character, "Stuns")
end

--[[
	Check if character has iframes
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.HasIFrames(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end

	if world:has(entity, comps.IFrame) then
		local iframe = world:get(entity, comps.IFrame)
		return iframe and iframe.value == true
	end

	return StateManager.StateCount(character, "IFrames")
end

--[[
	Check if character is ragdolled
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsRagdolled(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end

	if world:has(entity, comps.Ragdoll) then
		local ragdoll = world:get(entity, comps.Ragdoll)
		return ragdoll and ragdoll.value == true
	end

	return false
end

--[[
	Check if character is dead
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsDead(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end
	return world:has(entity, tags.Dead) or world:has(entity, comps.Dead)
end

-- ============================================
-- COMBAT STATE DATA ACCESSORS
-- ============================================

--[[
	Get combat combo count
	@param character Model - The character model
	@return number
]]
function StateAccessors.GetCombo(character: Model): number
	local entity = getEntity(character)
	if not entity then return 0 end

	if world:has(entity, comps.CombatState) then
		local combatState = world:get(entity, comps.CombatState)
		return combatState and combatState.combo or 0
	end

	return 0
end

--[[
	Set combat combo count
	@param character Model - The character model
	@param combo number - The combo count
]]
function StateAccessors.SetCombo(character: Model, combo: number)
	local entity = getEntity(character)
	if not entity then return end

	local combatState = world:get(entity, comps.CombatState) or {
		combo = 0,
		lastHitTime = 0,
		swingConnection = nil,
	}
	combatState.combo = combo
	world:set(entity, comps.CombatState, combatState)
end

--[[
	Get last hit timestamp
	@param character Model - The character model
	@return number
]]
function StateAccessors.GetLastHitTime(character: Model): number
	local entity = getEntity(character)
	if not entity then return 0 end

	if world:has(entity, comps.CombatState) then
		local combatState = world:get(entity, comps.CombatState)
		return combatState and combatState.lastHitTime or 0
	end

	return 0
end

--[[
	Set last hit timestamp
	@param character Model - The character model
	@param timestamp number - The timestamp
]]
function StateAccessors.SetLastHitTime(character: Model, timestamp: number)
	local entity = getEntity(character)
	if not entity then return end

	local combatState = world:get(entity, comps.CombatState) or {
		combo = 0,
		lastHitTime = 0,
		swingConnection = nil,
	}
	combatState.lastHitTime = timestamp
	world:set(entity, comps.CombatState, combatState)
end

--[[
	Get full combat state
	@param character Model - The character model
	@return {combo: number, lastHitTime: number, swingConnection: RBXScriptSignal?}?
]]
function StateAccessors.GetCombatState(character: Model): {combo: number, lastHitTime: number, swingConnection: RBXScriptConnection?}?
	local entity = getEntity(character)
	if not entity then return nil end

	if world:has(entity, comps.CombatState) then
		return world:get(entity, comps.CombatState)
	end

	return nil
end

--[[
	Set full combat state
	@param character Model - The character model
	@param state {combo: number, lastHitTime: number, swingConnection: RBXScriptSignal?}
]]
function StateAccessors.SetCombatState(character: Model, state: {combo: number, lastHitTime: number, swingConnection: RBXScriptConnection?})
	local entity = getEntity(character)
	if not entity then return end

	world:set(entity, comps.CombatState, state)
end

-- ============================================
-- ACTION STATE ACCESSORS
-- ============================================

--[[
	Check if character is in any action
	@param character Model - The character model
	@return boolean
]]
function StateAccessors.IsInAction(character: Model): boolean
	local entity = getEntity(character)
	if not entity then return false end

	-- Check CurrentAction component
	if world:has(entity, comps.CurrentAction) then
		local currentAction = world:get(entity, comps.CurrentAction)
		return currentAction and currentAction.name ~= nil
	end

	-- Check StateActions
	return StateManager.StateCount(character, "Actions")
end

--[[
	Get current action name
	@param character Model - The character model
	@return string?
]]
function StateAccessors.GetCurrentAction(character: Model): string?
	local entity = getEntity(character)
	if not entity then return nil end

	if world:has(entity, comps.CurrentAction) then
		local currentAction = world:get(entity, comps.CurrentAction)
		return currentAction and currentAction.name
	end

	return nil
end

-- ============================================
-- ANIMATION STATE ACCESSORS
-- ============================================

--[[
	Get animation state
	@param character Model - The character model
	@return {current: string, pose: string, freeFallTime: number, jumpAnimTime: number}?
]]
function StateAccessors.GetAnimationState(character: Model): {current: string, pose: string, freeFallTime: number, jumpAnimTime: number}?
	local entity = getEntity(character)
	if not entity then return nil end

	if world:has(entity, comps.AnimationState) then
		return world:get(entity, comps.AnimationState)
	end

	return nil
end

--[[
	Set animation state
	@param character Model - The character model
	@param state {current: string?, pose: string?, freeFallTime: number?, jumpAnimTime: number?}
]]
function StateAccessors.SetAnimationState(character: Model, state: {current: string?, pose: string?, freeFallTime: number?, jumpAnimTime: number?})
	local entity = getEntity(character)
	if not entity then return end

	local currentState = world:get(entity, comps.AnimationState) or {
		current = "",
		pose = "Standing",
		freeFallTime = 0,
		jumpAnimTime = 0,
	}

	-- Merge provided state with current
	if state.current ~= nil then currentState.current = state.current end
	if state.pose ~= nil then currentState.pose = state.pose end
	if state.freeFallTime ~= nil then currentState.freeFallTime = state.freeFallTime end
	if state.jumpAnimTime ~= nil then currentState.jumpAnimTime = state.jumpAnimTime end

	world:set(entity, comps.AnimationState, currentState)
end

-- ============================================
-- INPUT STATE ACCESSORS
-- ============================================

--[[
	Get input state
	@param character Model - The character model
	@return {attack: boolean, dash: boolean, block: boolean, critical: boolean, construct: boolean}?
]]
function StateAccessors.GetInputState(character: Model): {attack: boolean, dash: boolean, block: boolean, critical: boolean, construct: boolean}?
	local entity = getEntity(character)
	if not entity then return nil end

	if world:has(entity, comps.InputState) then
		return world:get(entity, comps.InputState)
	end

	return nil
end

--[[
	Set input state
	@param character Model - The character model
	@param state {attack: boolean?, dash: boolean?, block: boolean?, critical: boolean?, construct: boolean?}
]]
function StateAccessors.SetInputState(character: Model, state: {attack: boolean?, dash: boolean?, block: boolean?, critical: boolean?, construct: boolean?})
	local entity = getEntity(character)
	if not entity then return end

	local currentState = world:get(entity, comps.InputState) or {
		attack = false,
		dash = false,
		block = false,
		critical = false,
		construct = false,
	}

	-- Merge provided state with current
	if state.attack ~= nil then currentState.attack = state.attack end
	if state.dash ~= nil then currentState.dash = state.dash end
	if state.block ~= nil then currentState.block = state.block end
	if state.critical ~= nil then currentState.critical = state.critical end
	if state.construct ~= nil then currentState.construct = state.construct end

	world:set(entity, comps.InputState, currentState)
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

--[[
	Clear all movement states for a character
	@param character Model - The character model
]]
function StateAccessors.ClearMovementStates(character: Model)
	StateAccessors.SetInAir(character, false)
	StateAccessors.SetDodging(character, false)
	StateAccessors.SetRunning(character, false)
	StateAccessors.SetWallRunning(character, false)
	StateAccessors.SetLedgeClimbing(character, false)
	StateAccessors.SetLeaping(character, false)
	StateAccessors.SetLeapLanding(character, false)
end

--[[
	Clear entity cache for a character (call on character removal)
	@param character Model - The character model
]]
function StateAccessors.ClearCache(character: Model)
	clearCache(character)
end

--[[
	Get entity ID for a character (for advanced ECS operations)
	@param character Model - The character model
	@return number?
]]
function StateAccessors.GetEntity(character: Model): number?
	return getEntity(character)
end

return StateAccessors
