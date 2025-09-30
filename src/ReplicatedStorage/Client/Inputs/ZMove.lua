--[[
	Z Input - Alchemy Casting System

	Z key now starts/stops directional casting for alchemy moves.
	Uses the modular DirectionalCasting system with Library StateManager integration.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DirectionalCasting = require(ReplicatedStorage.Modules.Utils.DirectionalCasting)
local Combinations = require(ReplicatedStorage.Modules.Shared.Combinations)
local Library = require(ReplicatedStorage.Modules.Library)

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

-- Global casting instance (one per client) - exposed for XMove access
local castingInstance = nil
InputModule.castingInstance = castingInstance

-- Handle completed casting sequences
local function handleCastingComplete(Client, baseSequence, modifierSequence, isModifier)
	print("🔮 Processing alchemy cast...")
	print("Base:", baseSequence, "Modifier:", modifierSequence, "IsModifier:", isModifier)

	-- Check for matching combinations
	local matchedMove = nil
	local isAdvanced = false

	if isModifier and modifierSequence ~= "" then
		-- Check for advanced combinations (base + modifier)
		for moveName, combination in pairs(Combinations) do
			if type(combination) == "table" and combination.base and combination.modifier then
				if combination.base == baseSequence and combination.modifier == modifierSequence then
					matchedMove = moveName
					isAdvanced = true
					break
				end
			end
		end
	end

	-- If no advanced match, check base sequence
	if not matchedMove then
		matchedMove = castingInstance:CheckCombination(baseSequence)
	end

	if matchedMove then
		print("✨ Matched Alchemy Move:", matchedMove, isAdvanced and "(Advanced)" or "(Basic)")

		-- Send the alchemy move to server
		if Client.Packets[matchedMove] then
			Client.Packets[matchedMove].send({
				Held = false,
				Air = Client.InAir,
				Duration = 0
				-- Sequence = baseSequence,
				-- Modifier = modifierSequence,
				-- Advanced = isAdvanced
			})
		else
			warn("⚠️ No packet handler found for move:", matchedMove)
		end
	else
		print("❌ No matching alchemy move found for sequence:", baseSequence)
		if modifierSequence ~= "" then
			print("   Modifier sequence:", modifierSequence)
		end
	end
end

-- Initialize casting system
local function initializeCasting(Client)
	if not castingInstance then
		castingInstance = DirectionalCasting.new(Client.Character)
		InputModule.castingInstance = castingInstance -- Update exposed reference

		-- Connect to sequence completion
		castingInstance.OnSequenceComplete:Connect(function(baseSequence, modifierSequence, isModifier)
			handleCastingComplete(Client, baseSequence, modifierSequence, isModifier)
		end)

		print("🎯 Directional Casting System Initialized")
	end
	return castingInstance
end

InputModule.InputBegan = function(_, Client)
	local caster = initializeCasting(Client)

	-- Check if already casting
	if caster.isCasting then
		-- Stop casting and process results
		caster:StopCasting()
	else
		-- Start new casting session
		caster:StartCasting()
	end
end

InputModule.InputEnded = function(_, Client)
	-- Z key uses press-to-toggle, so InputEnded doesn't do anything
end

InputModule.InputChanged = function()
	-- No input changes to handle
end

return InputModule
