local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local QuestData = require(ReplicatedStorage.Modules.Quests)

local function questsystem(world)
	for entity in world:query(comps.QuestAccepted):iter() do
		local questAccepted = world:get(entity, comps.QuestAccepted)
		print("Quest accepted:", questAccepted.npcName, questAccepted.questName)

		if not world:has(entity, comps.QuestHolder) then
			world:add(entity, comps.QuestHolder)
		end

		world:set(entity, comps.ActiveQuest, {
			npcName = questAccepted.npcName,
			questName = questAccepted.questName,
			startTime = os.clock(),
			progress = {},
		})

		local questData = QuestData[questAccepted.npcName] and QuestData[questAccepted.npcName][questAccepted.questName]
		if questData then
			world:set(entity, comps.QuestData, questData)
		end

		world:remove(entity, comps.QuestAccepted)

		print("Quest started for entity", entity, questAccepted.npcName, questAccepted.questName)
	end

	for entity in world:query(comps.ActiveQuest, comps.QuestData):iter() do
		local activeQuest = world:get(entity, comps.ActiveQuest)

		print("Active quest:", activeQuest.npcName, activeQuest.questName)

		if os.clock() - activeQuest.startTime > 10 then
			world:set(entity, comps.CompletedQuest, {
				npcName = activeQuest.npcName,
				questName = activeQuest.questName,
				completedTime = os.clock(),
			})
			world:remove(entity, comps.ActiveQuest)
			world:remove(entity, comps.QuestData)
			print("Quest completed for entity", entity, activeQuest.npcName, activeQuest.questName)
		end
	end
end

return {
    run = function()
        questsystem(world)
    end,
    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}