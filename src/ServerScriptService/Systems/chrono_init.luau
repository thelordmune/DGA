--[[
	Chrono Initialization System (Server)

	Initializes the Chrono replication system on the server.
	This MUST run before any NPC spawning systems to ensure Chrono is ready.

	Chrono handles custom physics replication with:
	- Binary buffer serialization (70-97% bandwidth savings)
	- Hermite interpolation for smooth movement
	- Per-NPC-type tick rates (wanderers at 10Hz, combat at 30Hz)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		print("[Chrono] Server initialized successfully")
	else
		warn("[Chrono] Failed to initialize:", err)
	end

	return Chrono
end

-- Initialize immediately when this module loads
initializeChrono()

-- Export for other systems to access
return {
	-- No run function needed - just initialization
	run = function()
		-- Ensure Chrono is initialized (idempotent)
		if not initialized then
			initializeChrono()
		end
	end,

	-- Get the Chrono module (for other systems)
	getChrono = function()
		return Chrono
	end,

	-- Check if ready
	isReady = function()
		return initialized
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true,
		-- Run early - before mobs system
		priority = 1000,
	}
}
