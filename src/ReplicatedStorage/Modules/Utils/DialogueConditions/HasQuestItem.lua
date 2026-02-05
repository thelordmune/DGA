--[[
	Dialogue Condition: HasQuestItem
	
	Checks if the player has collected a quest item (ready to turn in).
	
	Usage in Dialogue Trees:
	- Create a Condition node in your dialogue tree
	- Add this module as a child of the Condition node
	- Set the Condition node's Priority attribute to match the dialogue path priority
	
	Returns:
	- true if player has collected the quest item
	- false if player has not collected the quest item
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

local HasQuestItem = {}

function HasQuestItem.Run(npcName, questName)
	local player = Players.LocalPlayer
	if not player then
		warn("[HasQuestItem] No local player found")
		return false
	end
	
	-- Get player entity
	local playerEntity = ref.get("local_player")
	if not playerEntity then
		warn("[HasQuestItem] No player entity found")
		return false
	end
	
	-- Check if player has QuestItemCollected component
	if not world:has(playerEntity, comps.QuestItemCollected) then
		return false
	end
	
	-- Get quest item data
	local questItem = world:get(playerEntity, comps.QuestItemCollected)
	if not questItem then
		return false
	end
	
	-- Check if the quest item matches
	if questItem.npcName == npcName and questItem.questName == questName then
		---- print("[HasQuestItem] Player has quest item:", npcName, questName)
		return true
	end
	
	return false
end

return HasQuestItem

