--[[
	Quest Tracker Manager
	
	Handles the quest tracker UI that shows active quests and quest index.
	Toggles with Tab key.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Modules.Fusion)

-- ECS imports
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local QuestData = require(ReplicatedStorage.Modules.Quests)

local Children, scoped, peek, Value = 
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Value

local QuestTrackerManager = {}
QuestTrackerManager.__index = QuestTrackerManager

-- Singleton instance
local instance = nil

function QuestTrackerManager.new()
	if instance then
		return instance
	end
	
	local self = setmetatable({}, QuestTrackerManager)
	
	-- Fusion scope for managing UI lifecycle
	self.scope = scoped(Fusion, {
		QuestTrackerComponent = require(ReplicatedStorage.Client.Components.QuestTrackers)
	})
	
	-- State
	self.isOpen = self.scope:Value(false)
	self.currentView = self.scope:Value("ActiveQuest") -- "ActiveQuest" or "QuestIndex"
	self.activeQuestData = self.scope:Value(nil)
	self.questsList = self.scope:Value({})
	
	-- UI References
	self.questTrackerGui = nil
	
	instance = self
	return self
end

function QuestTrackerManager:Initialize()
	print("[QuestTracker] Initializing...")

	-- Clean up old UI if it exists (for respawns)
	if self.questTrackerGui and self.questTrackerGui.Parent then
		self.questTrackerGui:Destroy()
		self.questTrackerGui = nil
	end

	-- Create the quest tracker UI
	self:CreateUI()

	-- Set up keybind (only once)
	if not self.keybindSetup then
		self:SetupKeybind()
		self.keybindSetup = true
	end

	-- Set up quest data updates (only once)
	if not self.questUpdatesSetup then
		self:SetupQuestUpdates()
		self.questUpdatesSetup = true
	end

	print("[QuestTracker] Initialized successfully")
end

function QuestTrackerManager:CreateUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create ScreenGui for quest tracker
	self.questTrackerGui = self.scope:New "ScreenGui" {
		Name = "QuestTrackerGui",
		Parent = playerGui,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
	}
	
	-- Create the quest tracker using the component
	local questTrackerFrame = self.scope:QuestTrackerComponent({
		isOpen = self.isOpen,
		currentView = self.currentView,
		activeQuestData = self.activeQuestData,
		questsList = self.questsList,
		Parent = self.questTrackerGui,
	})
	
	print("[QuestTracker] UI created")
end

function QuestTrackerManager:SetupQuestUpdates()
	-- Update quest data initially (with delay to ensure player entity exists)
	task.delay(2, function()
		self:UpdateQuestData()
	end)

	-- Update periodically to catch quest changes
	task.spawn(function()
		while true do
			task.wait(0.5) -- Update every half second for responsiveness
			self:UpdateQuestData()
		end
	end)
end

function QuestTrackerManager:UpdateQuestData()
	local playerEntity = ref.get("local_player")
	if not playerEntity or not world:contains(playerEntity) then
		print("[QuestTracker] No player entity found")
		return
	end

	-- Update active quest
	if world:has(playerEntity, comps.ActiveQuest) then
		local activeQuest = world:get(playerEntity, comps.ActiveQuest)
		-- print("[QuestTracker] Active quest found:", activeQuest.npcName, activeQuest.questName)

		local questInfo = QuestData[activeQuest.npcName] and QuestData[activeQuest.npcName][activeQuest.questName]

		if questInfo then
			print("[QuestTracker] Quest info found, updating UI")
			self.activeQuestData:set({
				npcName = activeQuest.npcName,
				questName = activeQuest.questName,
				description = questInfo.Description or "No description available",
				startTime = activeQuest.startTime,
			})
		else
			print("[QuestTracker] Quest info not found in QuestData for:", activeQuest.npcName, activeQuest.questName)
		end
	else
		print("[QuestTracker] No active quest")
		self.activeQuestData:set(nil)
	end

	-- Update quests list (for Quest Index)
	local quests = {}
	if world:has(playerEntity, comps.ActiveQuest) then
		local activeQuest = world:get(playerEntity, comps.ActiveQuest)
		table.insert(quests, {
			npcName = activeQuest.npcName,
			questName = activeQuest.questName,
			isActive = true,
		})
	end
	self.questsList:set(quests)
	-- print("[QuestTracker] Updated quests list, count:", #quests)
end

function QuestTrackerManager:SetupKeybind()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.Tab then
			self:Toggle()
		end
	end)
end

function QuestTrackerManager:Toggle()
	local newState = not peek(self.isOpen)
	self.isOpen:set(newState)
	
	-- Update quest data when opening
	if newState then
		self:UpdateQuestData()
	end
	
	print("[QuestTracker] Toggled:", newState and "Open" or "Closed")
end

function QuestTrackerManager:Show()
	self.isOpen:set(true)
	self:UpdateQuestData()
end

function QuestTrackerManager:Hide()
	self.isOpen:set(false)
end

function QuestTrackerManager:SwitchView(viewName)
	if viewName == "ActiveQuest" or viewName == "QuestIndex" then
		self.currentView:set(viewName)
	end
end

function QuestTrackerManager:Destroy()
	if self.scope then
		self.scope:doCleanup()
	end
	if self.questTrackerGui then
		self.questTrackerGui:Destroy()
	end
	instance = nil
end

return QuestTrackerManager

