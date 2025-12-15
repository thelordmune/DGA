--[[
	Movement Lock System
	
	Prevents player movement when Actions or Stuns states are active.
	This system runs on the client and disables the ControlModule when needed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Track control module state
local controlModuleDisabled = false
local controlModule = nil

-- Get the player's control module
local function getControlModule()
	if controlModule then
		return controlModule
	end
	
	local player = Players.LocalPlayer
	if not player then return nil end
	
	local playerScripts = player:WaitForChild("PlayerScripts", 5)
	if not playerScripts then return nil end
	
	local playerModule = playerScripts:FindFirstChild("PlayerModule")
	if not playerModule then return nil end
	
	local success, module = pcall(function()
		return require(playerModule)
	end)
	
	if success then
		controlModule = module
		return controlModule
	end
	
	return nil
end

-- Check if player should be locked
-- Uses ECS components directly to avoid timing issues with StringValue sync
local function shouldLockMovement(character)
	local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

	-- Check Actions states (directly from ECS)
	local allowedStates = {
		"Running", -- Allow running
		"Equipped", -- Allow having weapon equipped
	}

	-- Get all current action states from ECS
	local allStates = StateManager.GetAllStates(character, "Actions")

	-- Safety check: ensure allStates is a table
	if not allStates or type(allStates) ~= "table" then
		allStates = {}
	end

	-- Check if there are any blocking states
	for _, state in ipairs(allStates) do
		local isAllowed = false
		for _, allowed in ipairs(allowedStates) do
			if string.find(state, allowed) then
				isAllowed = true
				break
			end
		end
		if not isAllowed then
			-- Found a blocking state
			---- print(`[MovementLock] Blocking state found: {state}`)
			return true
		end
	end

	-- Check Stuns states (directly from ECS)
	if StateManager.StateCount(character, "Stuns") then
		---- print("[MovementLock] Stun state found")
		return true
	end

	return false
end

local function movement_lock()
	-- Only run on client
	if RunService:IsServer() then
		return
	end

	local player = Players.LocalPlayer
	if not player or not player.Character then
		return
	end

	-- Check if movement should be locked
	local shouldLock = shouldLockMovement(player.Character)

	-- Get control module
	local controls = getControlModule()
	if not controls then
		return
	end

	-- Update control module state
	if shouldLock and not controlModuleDisabled then
		-- Disable controls
		controls:Enable(false)
		controlModuleDisabled = true
		---- print("[MovementLock] Movement disabled")
	elseif not shouldLock and controlModuleDisabled then
		-- Re-enable controls
		controls:Enable(true)
		controlModuleDisabled = false
		---- print("[MovementLock] Movement enabled")
	end
end

return {
	run = function()
		movement_lock()
	end,
	settings = {
		phase = "Heartbeat", -- Run before rendering on client
		depends_on = {},
		client_only = true, -- Only run on client
	}
}

