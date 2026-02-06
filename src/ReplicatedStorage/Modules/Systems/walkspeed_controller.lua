--[[
	Walkspeed Controller System

	Directly modifies Humanoid.WalkSpeed based on Speeds StringValue.
	Runs on PreRender (client-only) to ensure immediate response.

	This system reads the Speeds StringValue directly (same as the old listener)
	and immediately applies walkspeed changes every frame.

	This is how Running works - it adds "RunSpeedSet24" to the StringValue,
	and this system reads it and applies the walkspeed change.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
-- Note: StateManager.GetAllStates returns arrays directly, no JSON parsing needed

local DEBUG = true -- Enable debug logging

-- Convert state name to number (e.g., "M1Speed12" -> 12, "RunSpeedSet24" -> 24)
local function ConvertToNumber(String)
	local Number = string.match(String, "%d+$") -- Match digits at end of string
	local IsNegative = string.match(String, "[-]%d+$") ~= nil

	if IsNegative and Number then
		Number = "-" .. Number
	end

	return Number and tonumber(Number) or 0
end

-- Speed priority mapping (higher = takes precedence)
-- When multiple speed states are active, only the highest priority one applies
local SPEED_PRIORITY = {
	-- Stun slowdowns (highest priority - always apply these debuffs)
	DamageStunSpeed = 100,
	BlockBreakSpeed = 100,
	ParryStunSpeed = 100,
	KnockbackSpeed = 100,

	-- Skill locks (zero movement during skill execution)
	AlcSpeed = 80,

	-- Combat speeds (attack slowdown during swings)
	M1Speed = 50,
	M2Speed = 50, -- Critical/heavy attack speed (M2SpeedSet8, M2SpeedSet6)
	RunningAttack = 50,

	-- Defensive speeds
	BlockSpeed = 40,

	-- Movement speeds (lowest priority - can be overridden by combat)
	RunSpeedSet = 30,
	FlashSpeedSet = 30,
}

-- Get the priority for a speed state
local function GetSpeedPriority(stateName: string): number
	for prefix, priority in pairs(SPEED_PRIORITY) do
		if string.match(stateName, "^" .. prefix) then
			return priority
		end
	end
	return 0 -- Unknown states have lowest priority
end

local lastWalkSpeed = nil
local lastJumpPower = nil
local lastAutoRotate = nil -- Track AutoRotate state

local hasLoggedStartup = false

local function walkspeed_controller()
	-- Only run on client
	if RunService:IsServer() then return end

	local player = Players.LocalPlayer
	if not player then
		if DEBUG and not hasLoggedStartup then
			warn("[WalkspeedController] No LocalPlayer found!")
			hasLoggedStartup = true
		end
		return
	end

	if not player.Character then
		if DEBUG and not hasLoggedStartup then
			warn("[WalkspeedController] No character found!")
			hasLoggedStartup = true
		end
		return
	end

	if not hasLoggedStartup then
		-- ---- print("[WalkspeedController] ✅ System started successfully!")
		hasLoggedStartup = true
	end

	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[WalkspeedController] No humanoid found!")
		return
	end

	-- Check for stuns that completely lock movement (walkspeed = 0)
	-- These stuns override all speed states
	local movementLockingStuns = {
		"BlockBreakStun",      -- Guard broken - can't move
		"PostureBreakStun",    -- Posture broken - can't move
		"KnockbackStun",       -- Being knocked back - can't move
		"KnockbackRecovery",   -- Post-knockback recovery - restricted movement
		"WallbangStun",        -- Stuck to wall - can't move
		"Ragdolled",           -- Ragdolled - can't move
		"GrabVictim",          -- Being grabbed - can't move
		"Grabbed",             -- Being grabbed - can't move
		"ParryStun",           -- Got parried - can't move
		"ParryKnockback",      -- Parry knockback - can't move
	}

	local stunStates = StateManager.GetAllStates(character, "Stuns") or {}

	-- Handle NoRotate state - lock/unlock AutoRotate based on stun state
	local hasNoRotate = false
	for _, stun in ipairs(stunStates) do
		if stun == "NoRotate" then
			hasNoRotate = true
			break
		end
	end

	-- Apply AutoRotate based on NoRotate state
	if hasNoRotate then
		if humanoid.AutoRotate ~= false then
			humanoid.AutoRotate = false
			if DEBUG then
				---- print("[WalkspeedController] AutoRotate disabled (NoRotate stun)")
			end
		end
		lastAutoRotate = false
	else
		-- Only restore AutoRotate if we were the ones who disabled it
		if lastAutoRotate == false and humanoid.AutoRotate == false then
			humanoid.AutoRotate = true
			if DEBUG then
				---- print("[WalkspeedController] AutoRotate restored")
			end
		end
		lastAutoRotate = true
	end

	for _, stun in ipairs(stunStates) do
		for _, lockingStun in ipairs(movementLockingStuns) do
			if stun == lockingStun then
				-- Movement is heavily restricted but not completely locked
				humanoid.WalkSpeed = 3
				humanoid.JumpPower = 0
				return
			end
		end
	end

	-- Get speed states from ECS StateManager (no longer uses StringValue)
	local speedStates = StateManager.GetAllStates(character, "Speeds") or {}

	-- Debug: print parsed states
	if DEBUG and #speedStates > 0 then
		---- print(`[WalkspeedController] Speed states count: {#speedStates}`)
	end

	local DeltaSpeed = 16 -- Default speed
	local DeltaJump = 50 -- Default jump

	-- Process speed states with priority-based selection
	-- Only the highest priority speed modifier is applied (prevents stacking)
	local highestPriority = -1
	local bestSpeedModifier = nil

	for _, state in ipairs(speedStates) do
		if string.match(state, "Jump") then
			-- Jump modifiers still stack additively
			local Number = ConvertToNumber(state)
			DeltaJump += Number
		elseif string.match(state, "Speed") then
			local Number = ConvertToNumber(state)
			local priority = GetSpeedPriority(state)

			-- Use highest priority modifier (or first if same priority)
			if priority > highestPriority then
				highestPriority = priority
				bestSpeedModifier = Number
			end
		end
	end

	-- Apply the highest priority speed modifier
	if bestSpeedModifier ~= nil then
		DeltaSpeed = bestSpeedModifier
	end

	-- Final speed assignment
	local finalWalkSpeed = math.max(0, DeltaSpeed) -- Ensure never negative
	local finalJumpPower = math.max(0, DeltaJump) -- Ensure never negative

	-- Apply limb loss speed multiplier if present (leg loss slows movement)
	local limbSpeedMultiplier = character:GetAttribute("LimbSpeedMultiplier")
	if limbSpeedMultiplier and limbSpeedMultiplier < 1 then
		finalWalkSpeed = finalWalkSpeed * limbSpeedMultiplier
		if DEBUG then
			---- print(`[WalkspeedController] Applied limb speed multiplier: {limbSpeedMultiplier}, final: {finalWalkSpeed}`)
		end
	end

	-- ALWAYS update walkspeed (remove the "only if changed" check for debugging)
	humanoid.WalkSpeed = finalWalkSpeed

	if finalWalkSpeed ~= lastWalkSpeed then
		lastWalkSpeed = finalWalkSpeed
		if DEBUG then
			---- print(`[WalkspeedController] ⚡ WalkSpeed set to {finalWalkSpeed} (states: {table.concat(speedStates, ", ")})`)
		end
	end

	humanoid.JumpPower = finalJumpPower

	if finalJumpPower ~= lastJumpPower then
		lastJumpPower = finalJumpPower
		if DEBUG and #speedStates > 0 then
			-- ---- print(`[WalkspeedController] JumpPower set to {finalJumpPower}`)
		end
	end
end

return {
	run = walkspeed_controller,
	settings = {
		phase = "Heartbeat",
		client_only = true,
		priority = 200, -- Run AFTER state_sync (which has default priority)
		depends_on = {"state_sync"} -- Ensure state_sync runs first
	}
}

