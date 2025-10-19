--[[
	Dialogue Condition: MagnusQuestCompleted
	
	Checks if the player has completed Magnus's quest by checking:
	1. Player has QuestHolder component (has done quests before)
	2. Player does NOT have ActiveQuest from Magnus
	3. Player does NOT have the pocketwatch in inventory
	
	This means they either:
	- Returned the pocketwatch (good ending)
	- Kept the pocketwatch and got attacked by guards (evil ending)
	
	Returns:
	- true if player has completed the quest
	- false if player has not completed the quest or never started it
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

local MagnusQuestCompleted = {}

function MagnusQuestCompleted.Run()
	local player = Players.LocalPlayer
	if not player then
		warn("[MagnusQuestCompleted] No local player found")
		return false
	end
	
	-- Get player entity
	local playerEntity = ref.get("local_player")
	if not playerEntity then
		warn("[MagnusQuestCompleted] No player entity found")
		return false
	end
	
	-- Check if player has ever done a quest (has QuestHolder component)
	if not world:has(playerEntity, comps.QuestHolder) then
		-- Player has never done any quest
		return false
	end
	
	-- Check if player currently has an active quest from Magnus
	if world:has(playerEntity, comps.ActiveQuest) then
		local activeQuest = world:get(playerEntity, comps.ActiveQuest)
		if activeQuest and activeQuest.npcName == "Magnus" then
			-- Player has active quest from Magnus - not completed yet
			return false
		end
	end
	
	-- Check if player has the pocketwatch in inventory
	if world:has(playerEntity, comps.Inventory) then
		local inventory = world:get(playerEntity, comps.Inventory)
		if inventory and inventory.items then
			for _, item in pairs(inventory.items) do
				if item and item.name == "Pocketwatch" then
					-- Player still has the pocketwatch - quest not completed
					return false
				end
			end
		end
	end
	
	-- Player has QuestHolder, no active Magnus quest, and no pocketwatch
	-- This means they completed the quest!
	-- print("[MagnusQuestCompleted] Player has completed Magnus quest!")
	return true
end

return MagnusQuestCompleted

