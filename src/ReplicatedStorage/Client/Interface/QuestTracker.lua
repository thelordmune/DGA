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
	self.scope = scoped(Fusion, {})
	
	-- State
	self.isOpen = self.scope:Value(false)
	self.activeQuestData = self.scope:Value(nil)
	self.questsList = self.scope:Value({})
	self.questsVisible = self.scope:Value(false)
	
	-- UI References
	self.questTrackerGui = nil
	self.questUIFrame = nil

	instance = self
	return self
end

function QuestTrackerManager:Initialize()
	-- ---- print("[QuestTracker] Initializing...")

	-- Show existing UI if it exists (for respawns), otherwise create new
	if self.questTrackerGui and self.questTrackerGui.Parent then
		self.questTrackerGui.Enabled = true
		---- print("[QuestTracker] Showing existing UI")
	else
		-- Create the quest tracker UI only if it doesn't exist
		self:CreateUI()
	end

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

	-- ---- print("[QuestTracker] Initialized successfully")
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
		Enabled = self.scope:Computed(function(use)
			return use(self.isOpen)
		end),
	}

	-- Create a container frame
	local containerFrame = self.scope:New "Frame" {
		Name = "QuestContainer",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.02, 0.05), -- Top left corner
		Size = UDim2.fromOffset(380, 500),
		Parent = self.questTrackerGui,
	}

	-- Add corner to container
	self.scope:New "UICorner" {
		CornerRadius = UDim.new(0, 10),
		Parent = containerFrame,
	}

	-- Create the new quest UI using the component
	local NewQuestComponent = require(ReplicatedStorage.Client.Components.Newquest)
	self.questUIFrame = NewQuestComponent(self.scope, {
		Parent = containerFrame,
		questsList = self.questsList, -- Pass the questsList so the component can observe it
		isVisible = self.questsVisible, -- Pass visibility state for fade animations
	})

	-- ---- print("[QuestTracker] UI created")
end

function QuestTrackerManager:SetupQuestUpdates()
	-- Update quest data initially (with delay to ensure player entity exists)
	task.delay(2, function()
		self:UpdateQuestData()
	end)

	-- Store update loop thread for cleanup
	self.updateThread = task.spawn(function()
		while true do
			task.wait(2) -- Update every 2 seconds (reduced from 0.5s to save performance)
			self:UpdateQuestData()
		end
	end)
end

function QuestTrackerManager:UpdateQuestData()
	local playerEntity = ref.get("local_player")
	if not playerEntity or not world:contains(playerEntity) then
		-- ---- print("[QuestTracker] No player entity found")
		return
	end

	-- Update active quest
	if world:has(playerEntity, comps.ActiveQuest) then
		local activeQuest = world:get(playerEntity, comps.ActiveQuest)
		local questInfo = QuestData[activeQuest.npcName] and QuestData[activeQuest.npcName][activeQuest.questName]

		if questInfo then
			local questData = {
				npcName = activeQuest.npcName,
				questName = activeQuest.questName,
				description = questInfo.Description or "No description available",
				startTime = activeQuest.startTime,
			}
			self.activeQuestData:set(questData)

			-- Update questsList - the Newquest component will observe this and update automatically
			local currentQuests = peek(self.questsList)
			local alreadyExists = false
			for _, quest in ipairs(currentQuests) do
				if quest.name == activeQuest.questName then
					alreadyExists = true
					break
				end
			end

			-- Only add if it doesn't exist
			if not alreadyExists then
				local updatedList = {}
				for _, q in ipairs(currentQuests) do
					table.insert(updatedList, q)
				end
				table.insert(updatedList, {
					name = activeQuest.questName,
					desc = questInfo.Description or "No description available",
					icon = "rbxassetid://99100008402900", -- Default icon
					npcName = activeQuest.npcName,
				})
				self.questsList:set(updatedList)
			end
		end
	else
		self.activeQuestData:set(nil)
		-- Clear all quests from UI when no active quest
		self.questsList:set({})
	end
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

	if not newState then
		-- Trigger fade-out animation before closing
		self.questsVisible:set(false)
		-- Wait for fade-out to complete before hiding UI
		task.delay(0.35, function()
			self.isOpen:set(false)
		end)
	else
		-- Open immediately and trigger fade-in
		self.isOpen:set(true)
		self:UpdateQuestData()
		-- Trigger fade-in animation
		task.delay(0.05, function()
			self.questsVisible:set(true)
		end)
	end

	-- ---- print("[QuestTracker] Toggled:", newState and "Open" or "Closed")
end

function QuestTrackerManager:Show()
	self.isOpen:set(true)
	self:UpdateQuestData()
	task.delay(0.05, function()
		self.questsVisible:set(true)
	end)
end

function QuestTrackerManager:Hide()
	self.questsVisible:set(false)
	task.delay(0.35, function()
		self.isOpen:set(false)
	end)
end

function QuestTrackerManager:Destroy()
	-- Hide the UI instead of destroying it
	if self.questTrackerGui then
		self.questTrackerGui.Enabled = false
	end

	-- DON'T cancel update thread or cleanup scope - keep it running
	-- DON'T destroy the GUI - just hide it for reuse on respawn
end

-- Full cleanup for when player leaves (not used on death)
function QuestTrackerManager:FullDestroy()
	-- Cancel update loop thread to prevent memory leak
	if self.updateThread then
		task.cancel(self.updateThread)
		self.updateThread = nil
	end

	if self.scope then
		self.scope:doCleanup()
	end
	if self.questTrackerGui then
		self.questTrackerGui:Destroy()
	end
	instance = nil
end

return QuestTrackerManager

