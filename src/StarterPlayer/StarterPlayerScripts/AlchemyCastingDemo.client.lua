--[[
	Alchemy Casting System Demo
	
	This script demonstrates the new directional casting system for alchemy.
	
	Controls:
	- Z: Start/Stop casting
	- X: Enter modifier mode (when casting) or stop everything
	- Mouse: Move to select directions (Up, Down, Left, Right)
	
	Example Combinations:
	- DU = Construct (basic building)
	- DLR = Cascade (stone falling rocks)
	- LRU = Cinder (flame spreading embers)
	- DULR = AlchemicAssault (complex attack)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DirectionalCasting = require(ReplicatedStorage.Modules.Utils.DirectionalCasting)
local Combinations = require(ReplicatedStorage.Modules.Shared.Combinations)

local player = Players.LocalPlayer

-- Wait for character
local character = player.Character or player.CharacterAdded:Wait()

-- Create casting instance
local caster = DirectionalCasting.new(character)



-- Connect to casting events
caster.OnSequenceComplete:Connect(function(baseSequence, modifierSequence, isModifier)
	
	
	if isModifier and modifierSequence ~= "" then
		
		
		-- Check for advanced combinations
		for moveName, combination in pairs(Combinations) do
			if type(combination) == "table" and combination.base and combination.modifier then
				if combination.base == baseSequence and combination.modifier == modifierSequence then
					
					return
				end
			end
		end
		
	else
		-- Check basic combinations
		local matchedMove = caster:CheckCombination(baseSequence)
		if matchedMove then
			
		else
			
		end
	end
end)

caster.OnCastingStateChanged:Connect(function(isCasting, isModifying)
	if isCasting then
		if isModifying then
			
		else
			
		end
	else
		
	end
end)

-- Instructions

