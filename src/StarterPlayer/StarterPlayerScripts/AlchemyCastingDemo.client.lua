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

print("✅ DirectionalCasting instance created successfully!")

-- Connect to casting events
caster.OnSequenceComplete:Connect(function(baseSequence, modifierSequence, isModifier)
	print("🔮 ALCHEMY CAST COMPLETED!")
	print("📋 Base Sequence:", baseSequence)
	
	if isModifier and modifierSequence ~= "" then
		print("🔧 Modifier Sequence:", modifierSequence)
		
		-- Check for advanced combinations
		for moveName, combination in pairs(Combinations) do
			if type(combination) == "table" and combination.base and combination.modifier then
				if combination.base == baseSequence and combination.modifier == modifierSequence then
					print("✨ ADVANCED ALCHEMY MOVE:", moveName)
					return
				end
			end
		end
		print("❓ Unknown advanced combination")
	else
		-- Check basic combinations
		local matchedMove = caster:CheckCombination(baseSequence)
		if matchedMove then
			print("✨ BASIC ALCHEMY MOVE:", matchedMove)
		else
			print("❓ Unknown combination - try a different sequence")
		end
	end
end)

caster.OnCastingStateChanged:Connect(function(isCasting, isModifying)
	if isCasting then
		if isModifying then
			print("🔧 Modifier mode active - triangles are red")
		else
			print("🎯 Casting mode active - move mouse to select directions")
		end
	else
		print("⭕ Casting stopped")
	end
end)

-- Instructions
print("🧙‍♂️ ALCHEMY CASTING SYSTEM LOADED")
print("📖 Instructions:")
print("   Z = Start/Stop casting")
print("   X = Modifier mode (when casting)")
print("   Mouse = Select directions")
print("")
print("🔮 Try these combinations:")
print("   DU = Construct")
print("   DLR = Cascade") 
print("   LRU = Cinder")
print("   DULR = AlchemicAssault")
print("")
print("🎯 Press Z to start casting!")
