local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

local player = Players.LocalPlayer

local QuestHandler = {}

local currentQuest = {
	npcName = nil,
	questName = nil,
	stage = nil,
	module = nil,
}

local activeMarkers = {}

local function cleanupMarkers()
	local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)

	for _, markerKey in activeMarkers do
		QuestMarkers.RemoveWaypoint(markerKey)
	end

	table.clear(activeMarkers)
end

function QuestHandler.RegisterMarker(markerKey: string)
	table.insert(activeMarkers, markerKey)
end

function QuestHandler.CreateWaypoint(part: Model | BasePart, label: string?, config: any?): string?
	local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)
	local markerKey = QuestMarkers.CreateWaypoint(part, label, config)

	if markerKey then
		QuestHandler.RegisterMarker(markerKey)
	end

	return markerKey
end

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

local function updateQuestState()
	local playerEntity = ref.get("local_player")
	if not playerEntity then
		return
	end

	if world:has(playerEntity, comps.ActiveQuest) then
		local activeQuest = world:get(playerEntity, comps.ActiveQuest)
		local stage = activeQuest.progress and activeQuest.progress.stage or 1

		local isNewQuest = currentQuest.npcName ~= activeQuest.npcName or currentQuest.questName ~= activeQuest.questName
		local isNewStage = currentQuest.stage ~= stage

		if isNewQuest then
			if currentQuest.module then
				if currentQuest.module.OnStageEnd and currentQuest.stage then
					pcall(currentQuest.module.OnStageEnd, currentQuest.stage, {
						npcName = currentQuest.npcName,
						questName = currentQuest.questName,
						stage = currentQuest.stage,
					})
				end
			end

			cleanupMarkers()

			local questModule = loadQuestModule(activeQuest.npcName)

			if not questModule then
				warn(`[QuestHandler] ❌ Failed to load quest module for: {activeQuest.npcName}`)
			end

			currentQuest.npcName = activeQuest.npcName
			currentQuest.questName = activeQuest.questName
			currentQuest.stage = stage
			currentQuest.module = questModule

			if questModule and questModule.OnStageStart then
				pcall(questModule.OnStageStart, stage, {
					npcName = activeQuest.npcName,
					questName = activeQuest.questName,
					stage = stage,
					progress = activeQuest.progress,
				})
			else
				warn(`[QuestHandler] ⚠️ Quest module has no OnStageStart function`)
			end

		elseif isNewStage then
			if currentQuest.module then
				if currentQuest.module.OnStageEnd then
					pcall(currentQuest.module.OnStageEnd, currentQuest.stage, {
						npcName = currentQuest.npcName,
						questName = currentQuest.questName,
						stage = currentQuest.stage,
					})
				end

				cleanupMarkers()

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
		end

		if currentQuest.module and currentQuest.module.OnStageUpdate then
			pcall(currentQuest.module.OnStageUpdate, stage, {
				npcName = activeQuest.npcName,
				questName = activeQuest.questName,
				stage = stage,
				progress = activeQuest.progress,
			})
		end

	else
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
		end
	end

	if world:has(playerEntity, comps.CompletedQuest) then
		local completedQuest = world:get(playerEntity, comps.CompletedQuest)

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

function QuestHandler.Init()
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(1)

	RunService.RenderStepped:Connect(updateQuestState)

	updateQuestState()
end

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
