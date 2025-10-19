--[[
	Quest System - Modernized with Observers

	NOTE: Quest acceptance is now handled by observers in jecs_observers.luau
	This system only handles active quest progression logic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

local function questsystem()
	-- Check active quests for progression
	for entity in world:query(comps.ActiveQuest, comps.QuestData):iter() do
		local activeQuest = world:get(entity, comps.ActiveQuest)

		-- Auto-complete quest after 10 seconds for testing (sets QuestItemCollected, not CompletedQuest)
		if os.clock() - activeQuest.startTime > 10 then
			-- Only set if not already collected
			if not world:has(entity, comps.QuestItemCollected) then
				world:set(entity, comps.QuestItemCollected, {
					npcName = activeQuest.npcName,
					questName = activeQuest.questName,
					itemName = "Pocketwatch",
					collectedTime = os.clock(),
				})
				-- print("[QuestSystem] Quest item collected for entity", entity, activeQuest.npcName, activeQuest.questName)
			end
		end
	end
end

return {
	run = function()
		questsystem()
	end,
	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}