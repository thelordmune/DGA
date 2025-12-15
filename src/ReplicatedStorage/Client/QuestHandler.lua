--[[
	Client-Side Quest Handler
	
	Monitors the player's active quest and calls client-side quest module functions
	to handle stage-specific logic like waypoint markers, UI updates, etc.
	
	Quest modules can define:
	- OnStageStart(stage, questData) - Called when a quest stage begins
	- OnStageUpdate(stage, questData) - Called every frame while on a stage
	- OnStageEnd(stage, questData) - Called when leaving a stage
	- OnQuestComplete(questData) - Called when quest is completed
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

local player = Players.LocalPlayer

local QuestHandler = {}

-- Track current quest state
local currentQuest = {
	npcName = nil,
	questName = nil,
	stage = nil,
	module = nil,
}

-- Store active quest markers for cleanup
local activeMarkers = {}

-- Helper function to clean up all quest markers
local function cleanupMarkers()
	local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)
	
	for _, markerKey in activeMarkers do
		QuestMarkers.RemoveWaypoint(markerKey)
	end
	
	table.clear(activeMarkers)
end

-- Helper function to register a marker for cleanup
function QuestHandler.RegisterMarker(markerKey: string)
	table.insert(activeMarkers, markerKey)
end

-- Helper function to create a waypoint (convenience wrapper)
function QuestHandler.CreateWaypoint(part: Model | BasePart, label: string?, config: any?): string?
	local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)
	local markerKey = QuestMarkers.CreateWaypoint(part, label, config)
	
	if markerKey then
		QuestHandler.RegisterMarker(markerKey)
	end
	
	return markerKey
end

-- Load a quest module (client-side version)
local function loadQuestModule(npcName: string)
	local questModulesFolder = ReplicatedStorage.Modules:FindFirstChild("QuestsFolder")
	if not questModulesFolder then
		return nil
	end
	
	local questModule = questModulesFolder:FindFirstChild(npcName)
	if not questModule then
		return nil
	end
	
	local success, result = pcall(function()
		return require(questModule)
	end)
	
	if success and typeof(result) == "table" then
		return result
	end
	
	return nil
end

-- Update quest state and call appropriate handlers
local function updateQuestState()
	local playerEntity = ref.get("local_player")
	if not playerEntity then
		--print("[QuestHandler] ⚠️ No local player entity found")
		return
	end

	-- Check if player has an active quest
	if world:has(playerEntity, comps.ActiveQuest) then
		local activeQuest = world:get(playerEntity, comps.ActiveQuest)
		---- --print(`[QuestHandler] 🔍 ActiveQuest detected: {activeQuest.npcName} - {activeQuest.questName}`)
		---- --print(`[QuestHandler] 🔍 ActiveQuest progress: {activeQuest.progress}`)
		local stage = activeQuest.progress and activeQuest.progress.stage or 1
		---- --print(`[QuestHandler] 🔍 Stage: {stage}`)
		
		-- Check if this is a new quest or stage change
		local isNewQuest = currentQuest.npcName ~= activeQuest.npcName or currentQuest.questName ~= activeQuest.questName
		local isNewStage = currentQuest.stage ~= stage
		
		if isNewQuest then
			-- Clean up old quest
			if currentQuest.module then
				-- Call OnStageEnd for old stage
				if currentQuest.module.OnStageEnd and currentQuest.stage then
					pcall(currentQuest.module.OnStageEnd, currentQuest.stage, {
						npcName = currentQuest.npcName,
						questName = currentQuest.questName,
						stage = currentQuest.stage,
					})
				end
			end

			cleanupMarkers()

			-- Load new quest module
			--print(`[QuestHandler] 📦 Loading quest module for: {activeQuest.npcName}`)
			local questModule = loadQuestModule(activeQuest.npcName)

			if questModule then
				--print(`[QuestHandler] ✅ Quest module loaded successfully`)
			else
				warn(`[QuestHandler] ❌ Failed to load quest module for: {activeQuest.npcName}`)
			end

			currentQuest.npcName = activeQuest.npcName
			currentQuest.questName = activeQuest.questName
			currentQuest.stage = stage
			currentQuest.module = questModule

			-- Call OnStageStart for new quest
			if questModule and questModule.OnStageStart then
				--print(`[QuestHandler] 🎬 Calling OnStageStart for stage {stage}`)
				pcall(questModule.OnStageStart, stage, {
					npcName = activeQuest.npcName,
					questName = activeQuest.questName,
					stage = stage,
					progress = activeQuest.progress,
				})
			else
				warn(`[QuestHandler] ⚠️ Quest module has no OnStageStart function`)
			end

			--print(`[QuestHandler] 🎯 New quest started: {activeQuest.npcName} - {activeQuest.questName} (Stage {stage})`)
			
		elseif isNewStage then
			-- Stage changed
			if currentQuest.module then
				-- Call OnStageEnd for old stage
				if currentQuest.module.OnStageEnd then
					pcall(currentQuest.module.OnStageEnd, currentQuest.stage, {
						npcName = currentQuest.npcName,
						questName = currentQuest.questName,
						stage = currentQuest.stage,
					})
				end
				
				cleanupMarkers()
				
				-- Call OnStageStart for new stage
				if currentQuest.module.OnStageStart then
					pcall(currentQuest.module.OnStageStart, stage, {
						npcName = activeQuest.npcName,
						questName = activeQuest.questName,
						stage = stage,
						progress = activeQuest.progress,
					})
				end
			end
			
			currentQuest.stage = stage
			--print(`[QuestHandler] 📋 Quest stage changed: {activeQuest.npcName} - {activeQuest.questName} (Stage {stage})`)
		end
		
		-- Call OnStageUpdate every frame
		if currentQuest.module and currentQuest.module.OnStageUpdate then
			pcall(currentQuest.module.OnStageUpdate, stage, {
				npcName = activeQuest.npcName,
				questName = activeQuest.questName,
				stage = stage,
				progress = activeQuest.progress,
			})
		end
		
	else
		-- No active quest, clean up if we had one
		if currentQuest.npcName then
			if currentQuest.module and currentQuest.module.OnStageEnd and currentQuest.stage then
				pcall(currentQuest.module.OnStageEnd, currentQuest.stage, {
					npcName = currentQuest.npcName,
					questName = currentQuest.questName,
					stage = currentQuest.stage,
				})
			end
			
			cleanupMarkers()
			
			currentQuest.npcName = nil
			currentQuest.questName = nil
			currentQuest.stage = nil
			currentQuest.module = nil
			
			--print("[QuestHandler] ✅ Quest completed or abandoned")
		end
	end
	
	-- Check for quest completion
	if world:has(playerEntity, comps.CompletedQuest) then
		local completedQuest = world:get(playerEntity, comps.CompletedQuest)
		
		-- Only call OnQuestComplete once per completion
		if currentQuest.module and currentQuest.module.OnQuestComplete then
			if currentQuest.npcName == completedQuest.npcName and currentQuest.questName == completedQuest.questName then
				pcall(currentQuest.module.OnQuestComplete, {
					npcName = completedQuest.npcName,
					questName = completedQuest.questName,
					completedTime = completedQuest.completedTime,
				})
			end
		end
	end
end

-- Initialize the quest handler
function QuestHandler.Init()
	-- Wait for character to load
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(1) -- Wait for ECS to initialize
	
	--print("[QuestHandler] 🎮 Initializing client-side quest handler...")
	
	-- Update quest state every frame
	RunService.RenderStepped:Connect(updateQuestState)
	
	-- Initial update
	updateQuestState()
	
	--print("[QuestHandler] ✅ Quest handler initialized")
end

-- Cleanup on death
function QuestHandler.Cleanup()
	cleanupMarkers()
	
	if currentQuest.module and currentQuest.module.OnStageEnd and currentQuest.stage then
		pcall(currentQuest.module.OnStageEnd, currentQuest.stage, {
			npcName = currentQuest.npcName,
			questName = currentQuest.questName,
			stage = currentQuest.stage,
		})
	end
	
	currentQuest.npcName = nil
	currentQuest.questName = nil
	currentQuest.stage = nil
	currentQuest.module = nil
end

return QuestHandler

