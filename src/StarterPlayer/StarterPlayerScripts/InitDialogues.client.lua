--[[
	Initialize Dialogues
	
	This script runs on the client and builds all dialogue trees from modules.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for game to load
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- print("[InitDialogues] 🔧 Initializing dialogue system...")

-- Wait for DialogueBuilder to exist
local DialogueBuilder = ReplicatedStorage.Modules.Utils:WaitForChild("DialogueBuilder", 10)
if not DialogueBuilder then
	warn("[InitDialogues] ❌ DialogueBuilder not found!")
	return
end

-- Load the dialogue builder
local success, builder = pcall(require, DialogueBuilder)
if not success then
	warn("[InitDialogues] ❌ Failed to load DialogueBuilder:", builder)
	return
end

-- Build all dialogues
-- print("[InitDialogues] 📚 Building all dialogue trees...")
local buildSuccess, buildError = pcall(function()
	builder.BuildAll()
end)

if not buildSuccess then
	warn("[InitDialogues] ❌ Failed to build dialogues:", buildError)
	return
end

-- print("[InitDialogues] ✅ Dialogue system initialized successfully!")

-- Debug: List all built dialogues
local dialoguesFolder = ReplicatedStorage:FindFirstChild("Dialogues")
if dialoguesFolder then
	-- print("[InitDialogues] 📋 Built dialogues:")
	for _, dialogue in ipairs(dialoguesFolder:GetChildren()) do
		-- print("  - " .. dialogue.Name)
	end
else
	warn("[InitDialogues] ⚠️ Dialogues folder not found after building!")
end

