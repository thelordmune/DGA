--[[
	Stun Signals

	Typed signals for stun system events.
	Used for VFX hooks, UI updates, and combat feedback.

	Usage:
		local StunSignals = require(path.to.StunSignals)

		-- Listen for stun events
		StunSignals.OnStunApplied:connect(function(character, stunName, duration)
			print(character.Name, "stunned with", stunName, "for", duration, "seconds")
		end)

		-- Listen for posture events
		StunSignals.OnPostureBroken:connect(function(character, attacker)
			-- Play posture break VFX
		end)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local signal = require(ReplicatedStorage.Packages.luausignal)

export type StunAppliedArgs = {
	character: Model,
	stunName: string,
	duration: number,
	invoker: Model?,
	scaledDuration: number?, -- Duration after scaling applied
}

export type PostureChangedArgs = {
	character: Model,
	current: number,
	max: number,
	delta: number, -- Amount changed (positive = damage, negative = regen)
}

local StunSignals = {
	-- Fired when a stun is applied to a character
	-- Args: character, stunName, duration, invoker?, scaledDuration?
	OnStunApplied = signal() :: signal.Identity<Model, string, number, Model?, number?>,

	-- Fired when a stun ends (naturally or removed early)
	-- Args: character, stunName
	OnStunEnded = signal() :: signal.Identity<Model, string>,

	-- Fired when posture changes (damage or regen)
	-- Args: character, current, max, delta
	OnPostureChanged = signal() :: signal.Identity<Model, number, number, number>,

	-- Fired when posture breaks (guard is broken)
	-- Args: character, attacker?
	OnPostureBroken = signal() :: signal.Identity<Model, Model?>,

	-- Fired when posture resets after break
	-- Args: character
	OnPostureReset = signal() :: signal.Identity<Model>,

	-- Fired when a counter hit occurs (interrupting enemy attack)
	-- Args: target (who got counter hit), attacker
	OnCounterHit = signal() :: signal.Identity<Model, Model>,

	-- Fired when stun immunity is granted
	-- Args: character, duration
	OnImmunityGranted = signal() :: signal.Identity<Model, number>,

	-- Fired when stun immunity ends
	-- Args: character
	OnImmunityEnded = signal() :: signal.Identity<Model>,
}

return StunSignals
