--[[
	Test Dialogue Builder
	
	Run this script in the command bar to test the dialogue builder:
	require(game.ReplicatedStorage.TestDialogueBuilder)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- print("=== Testing Dialogue Builder ===")

-- Load the dialogue builder
local DialogueBuilder = require(ReplicatedStorage.Modules.Utils.DialogueBuilder)

---- print("DialogueBuilder loaded successfully")

-- Build all dialogues
---- print("Building all dialogues...")
local success, err = pcall(function()
	DialogueBuilder.BuildAll()
end)

if not success then
	warn("Failed to build dialogues:", err)
	return
end

---- print("✅ Dialogues built successfully!")

-- Check what was created
local dialoguesFolder = ReplicatedStorage:FindFirstChild("Dialogues")
if dialoguesFolder then
	---- print("\n📋 Built dialogues:")
	for _, dialogue in ipairs(dialoguesFolder:GetChildren()) do
		---- print("  - " .. dialogue.Name)
		
		-- List nodes
		for _, node in ipairs(dialogue:GetChildren()) do
			local nodeType = node:GetAttribute("Type") or "Unknown"
			local priority = node:GetAttribute("Priority") or 0
			---- print("    • " .. node.Name .. " (" .. nodeType .. ", Priority: " .. priority .. ")")
		end
	end
else
	warn("⚠️ Dialogues folder not found!")
end

---- print("\n=== Test Complete ===")

return true

