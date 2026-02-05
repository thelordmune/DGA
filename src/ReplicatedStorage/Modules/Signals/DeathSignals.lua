--[[
	Death Signals

	Typed signals for death system events.
	Replaces BindableEvent "CustomDeath" pattern with centralized signal.

	Usage:
		local DeathSignals = require(path.to.DeathSignals)

		-- Listen for any character death
		DeathSignals.OnDeath:connect(function(character)
			print(character.Name, "died")
		end)

		-- Fire when character dies (called from Damage.lua)
		DeathSignals.OnDeath:fire(character)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local signal = require(ReplicatedStorage.Packages.luausignal)

local DeathSignals = {
	-- Fired when a character dies (player or NPC)
	-- Args: character: Model
	OnDeath = signal() :: signal.Identity<Model>,

	-- Fired when a character is about to be cleaned up (corpse removal)
	-- Args: character: Model
	OnCorpseCleanup = signal() :: signal.Identity<Model>,
}

return DeathSignals
