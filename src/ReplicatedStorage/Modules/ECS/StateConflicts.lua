--!strict
--[[
	State Conflict Groups

	Defines which states are mutually exclusive within their category.
	When adding a state, all conflicting states in the same group are automatically removed.

	This prevents state stacking issues like:
	- Multiple speed states active (M1Speed13 + RunSpeedSet30)
	- Multiple M1 combo states (M11 + M12)
	- Conflicting recovery states
]]

local StateConflicts = {}

-- Speed conflict groups - only ONE state from each group can be active
StateConflicts.Speeds = {
	-- Combat speed modifiers (M1/M2 attacks slow player down)
	CombatSpeed = {
		"M1Speed13", "M1Speed8", "M1Speed12", "M1Speed16",
		"AlcSpeed-0", "AlcSpeed-6", "AlcSpeed4",
	},

	-- Movement speed modifiers (running, blocking)
	MovementSpeed = {
		"RunSpeedSet30", "RunSpeedSet24",
		"BlockSpeed8",
		"FlashSpeedSet50",
		"FocusMiniSpeed20",
	},

	-- Jump modifiers
	JumpModifier = {
		"Jump-50", -- Prevents jumping during skills
	},
}

-- Action conflict groups - mutually exclusive actions
StateConflicts.Actions = {
	-- M1 combo states (only one M1 state active at a time)
	M1Combo = {
		"M11", "M12", "M13", "M14", "M15",
	},

	-- Recovery states (block attacker from acting)
	Recovery = {
		"DodgeRecovery", "BlockRecovery", "ParryRecovery",
		"PincerRecovery", "NenRecovery", "ComboRecovery",
	},

	-- Blocking states
	Block = {
		"Blocking", "BlockBreak",
	},

	-- Movement actions (Dashing is an action, not a stun)
	MovementActions = {
		"Dashing", "Running",
	},
}

-- Stun conflict groups - stuns that shouldn't coexist
StateConflicts.Stuns = {
	-- Movement restriction stuns (mutual exclusion)
	-- NOTE: "Dashing" removed - it's now in Actions.MovementActions
	MovementRestriction = {
		"KnockbackStun", "KnockbackRecovery", "WallbangStun", "ParryKnockback",
	},
}

--[[
	Get all states in the same conflict group as the given state
	@param category string - "Speeds", "Actions", "Stuns", etc.
	@param stateName string - The state to find conflicts for
	@return {string}? - Array of conflicting state names, or nil if no conflicts
]]
function StateConflicts.GetConflicts(category: string, stateName: string): {string}?
	local categoryGroups = StateConflicts[category]
	if not categoryGroups then
		return nil
	end

	for _, states in pairs(categoryGroups) do
		if table.find(states, stateName) then
			-- Return all OTHER states in this group (not the state itself)
			local conflicts = {}
			for _, s in ipairs(states) do
				if s ~= stateName then
					table.insert(conflicts, s)
				end
			end
			return conflicts
		end
	end

	return nil
end

--[[
	Check if two states conflict
	@param category string - State category
	@param state1 string - First state
	@param state2 string - Second state
	@return boolean - True if they conflict
]]
function StateConflicts.DoConflict(category: string, state1: string, state2: string): boolean
	local conflicts = StateConflicts.GetConflicts(category, state1)
	if conflicts then
		return table.find(conflicts, state2) ~= nil
	end
	return false
end

--[[
	Register a new conflict group dynamically
	@param category string - State category ("Speeds", "Actions", etc.)
	@param groupName string - Name for this conflict group
	@param states {string} - Array of mutually exclusive states
]]
function StateConflicts.RegisterGroup(category: string, groupName: string, states: {string})
	if not StateConflicts[category] then
		StateConflicts[category] = {}
	end
	StateConflicts[category][groupName] = states
end

return StateConflicts
