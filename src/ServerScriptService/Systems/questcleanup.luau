--[[
	Quest Cleanup System - DEPRECATED

	This system is now handled by observers in jecs_observers.luau
	The observer automatically schedules cleanup 10 seconds after quest completion.

	This file is kept for backwards compatibility but does nothing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return {
	run = function(world)
		-- No-op: Quest cleanup is now handled by observers
	end,
	settings = {
		phase = "Heartbeat",
		paused = true, -- Paused since observers handle this now
		server_only = true
	}
}