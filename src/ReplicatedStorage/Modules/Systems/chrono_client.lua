--[[
	Chrono Client System

	Initializes the Chrono replication system on the client.
	Handles receiving NPC position updates and interpolating movement.

	This system:
	- Starts Chrono client-side
	- Receives NPC registrations from server via NpcRegistry
	- Interpolates NPC positions using Hermite curves
	- Handles NpcAdded/NpcRemoved events for cleanup
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Only run on client
if RunService:IsServer() then
	return {
		run = function() end,
		settings = {
			phase = "PreRender",
			depends_on = {},
			server_only = false,
		}
	}
end

-- Track initialization state
local initialized = false
local Chrono = nil

-- Initialize Chrono once
local function initializeChrono()
	if initialized then
		return Chrono
	end

	local success, err = pcall(function()
		Chrono = require(ReplicatedStorage.Modules.Chrono)
		Chrono.Start()
	end)

	if success then
		initialized = true
		print("[Chrono Client] Initialized successfully")

		-- Initialize NPC Animator for client-side walk/idle animations
		-- Chrono bypasses Roblox replication, so animations don't replicate - we must play them locally
		local animSuccess, animErr = pcall(function()
			require(ReplicatedStorage.Client.NpcAnimator)
		end)
		if not animSuccess then
			warn("[Chrono Client] Failed to initialize NpcAnimator:", animErr)
		end
	else
		warn("[Chrono Client] Failed to initialize:", err)
	end

	return Chrono
end

-- Initialize when this module loads
initializeChrono()

return {
	run = function()
		-- Chrono handles its own PreRender loop internally
		-- This system just ensures initialization
		if not initialized then
			initializeChrono()
		end
	end,

	-- Get the Chrono module
	getChrono = function()
		return Chrono
	end,

	-- Check if ready
	isReady = function()
		return initialized
	end,

	settings = {
		phase = "PreRender",
		depends_on = {},
		server_only = false,
	}
}
