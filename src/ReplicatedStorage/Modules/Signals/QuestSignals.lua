--[[
	Quest Signals

	Typed signals for quest system events.
	Replaces manual callback checks with proper event-driven pattern.

	Usage:
		local QuestSignals = require(path.to.QuestSignals)

		-- Listen for quest stage changes
		QuestSignals.OnStageStart:connect(function(npcName, questName, stage, data)
			print("Starting stage", stage, "of", questName)
		end)

		-- Fire when stage starts
		QuestSignals.OnStageStart:fire("Sam", "Delivery", 1, {})
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local signal = require(ReplicatedStorage.Packages.luausignal)

export type QuestData = {
	npcName: string,
	questName: string,
	stage: number | string,
	progress: any?,
}

local QuestSignals = {
	-- Fired when a quest stage starts
	-- Args: npcName: string, questName: string, stage: number | string, data: table
	OnStageStart = signal() :: signal.Identity<string, string, number | string, table>,

	-- Fired when a quest stage ends
	-- Args: npcName: string, questName: string, stage: number | string, data: table
	OnStageEnd = signal() :: signal.Identity<string, string, number | string, table>,

	-- Fired when a quest is accepted
	-- Args: npcName: string, questName: string
	OnAccepted = signal() :: signal.Identity<string, string>,

	-- Fired when a quest is completed
	-- Args: npcName: string, questName: string, rewards: table
	OnComplete = signal() :: signal.Identity<string, string, table>,

	-- Fired when a quest is abandoned
	-- Args: npcName: string, questName: string
	OnAbandoned = signal() :: signal.Identity<string, string>,

	-- Fired when quest progress updates
	-- Args: npcName: string, questName: string, progress: table
	OnProgressUpdate = signal() :: signal.Identity<string, string, table>,

	-- Fired when an item is collected for a quest
	-- Args: npcName: string, questName: string, itemName: string
	OnItemCollected = signal() :: signal.Identity<string, string, string>,
}

return QuestSignals
