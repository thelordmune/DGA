--[[
	Initialize Dialogues Module

	This module runs on the client and builds all dialogue trees from modules.
]]

local InitDialogues = {}
local CSystem = require(script.Parent)

local ReplicatedStorage = CSystem.Service.ReplicatedStorage

-- Initialize
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	local DialogueBuilder = ReplicatedStorage.Modules.Utils:WaitForChild("DialogueBuilder", 10)
	if not DialogueBuilder then
		warn("[InitDialogues] DialogueBuilder not found!")
		return
	end

	local success, builder = pcall(require, DialogueBuilder)
	if not success then
		warn("[InitDialogues] Failed to load DialogueBuilder:", builder)
		return
	end

	local buildSuccess, buildError = pcall(function()
		builder.BuildAll()
	end)

	if not buildSuccess then
		warn("[InitDialogues] Failed to build dialogues:", buildError)
		return
	end
end)

return InitDialogues
