--[[
	Quest Completion Controller
	
	Handles displaying quest completion popups with rewards
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Bridges = require(ReplicatedStorage.Modules.Bridges)

local scoped = Fusion.scoped
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local QuestCompletionController = {}

local currentPopupUI = nil
local currentScope = nil

function QuestCompletionController.ShowCompletion(data)
	print("[QuestCompletionController] Showing quest completion:", data.questName)
	
	-- Clean up existing popup
	if currentPopupUI then
		currentPopupUI:Destroy()
		currentPopupUI = nil
	end
	
	if currentScope then
		currentScope:doCleanup()
	end
	
	-- Create new scope
	currentScope = scoped(Fusion, {
		QuestCompletionPopup = require(ReplicatedStorage.Client.Components.QuestCompletionPopup)
	})
	
	local framein = currentScope:Value(false)
	
	-- Create UI
	local popupTarget = currentScope:New("ScreenGui")({
		Name = "QuestCompletionPopup",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = PlayerGui,
	})
	
	currentScope:QuestCompletionPopup({
		questName = data.questName or "Quest",
		experienceGained = data.experienceGained or 0,
		alignmentGained = data.alignmentGained or 0,
		leveledUp = data.leveledUp or false,
		newLevel = data.newLevel or 1,
		framein = framein,
		Parent = popupTarget
	})
	
	currentPopupUI = popupTarget
	
	-- Animate in
	task.wait(0.3)
	framein:set(true)
	
	-- Auto-hide after 5 seconds
	task.spawn(function()
		task.wait(5)
		if framein then
			framein:set(false)
			task.wait(1.5)
			if currentPopupUI then
				currentPopupUI:Destroy()
				currentPopupUI = nil
			end
			if currentScope then
				currentScope:doCleanup()
				currentScope = nil
			end
		end
	end)
end

-- Listen for quest completion events from server
function QuestCompletionController.Initialize()
	print("[QuestCompletionController] Initializing...")

	-- Listen for quest completion bridge
	Bridges.QuestCompleted:Connect(function(data)
		print("[QuestCompletionController] 🎉 Received quest completion data:")
		print("  Quest Name:", data.questName)
		print("  Experience Gained:", data.experienceGained)
		print("  Alignment Gained:", data.alignmentGained)
		print("  Leveled Up:", data.leveledUp)
		print("  New Level:", data.newLevel)

		QuestCompletionController.ShowCompletion(data)
	end)

	print("[QuestCompletionController] ✅ Initialized and listening for QuestCompleted bridge!")
end

return QuestCompletionController

