--[[
	Signals Module

	Central registry for typed game signals using LuauSignal.
	LuauSignal provides ~15x faster disconnection and ~2x faster connection than BindableEvents.

	Usage:
		local Signals = require(ReplicatedStorage.Modules.Signals)

		-- Connect to quest completion
		local disconnect = Signals.Quest.OnComplete:connect(function(questName, npcName)
			print("Completed:", questName)
		end)

		-- Fire signal
		Signals.Quest.OnComplete:fire("Sam_Delivery", "Sam")

		-- Disconnect when done
		disconnect()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- LuauSignal is already in Packages folder
local signal = require(ReplicatedStorage.Packages.luausignal)

-- Import sub-modules
local QuestSignals = require(script.QuestSignals)
local DeathSignals = require(script.DeathSignals)

-- Central signal registry
local Signals = {
	-- Quest events
	Quest = QuestSignals,

	-- Death events
	Death = DeathSignals,

	-- Expose signal constructor for custom signals
	new = signal,
}

return Signals
