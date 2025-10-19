--[[
	Dialogue Condition: HasCompletedQuest
	
	Checks if the player has completed a specific quest from an NPC.
	
	Usage in Dialogue Trees:
	- Create a Condition node in your dialogue tree
	- Add this module as a child of the Condition node
	- Set the Condition node's Priority attribute to match the dialogue path priority
	
	Returns:
	- true if player has completed the quest
	- false if player has not completed the quest
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

local HasCompletedQuest = {}

function HasCompletedQuest.Run(npcName, questName)
	local player = Players.LocalPlayer
	if not player then
		warn("[HasCompletedQuest] No local player found")
		return false
	end
	
	-- Get player entity
	local playerEntity = ref.get("local_player")
	if not playerEntity then
		warn("[HasCompletedQuest] No player entity found")
		return false
	end
	
	-- Check if player has CompletedQuest component
	if not world:has(playerEntity, comps.CompletedQuest) then
		return false
	end
	
	-- Get completed quest data
	local completedQuest = world:get(playerEntity, comps.CompletedQuest)
	if not completedQuest then
		return false
	end
	
	-- Check if the completed quest matches
	if completedQuest.npcName == npcName and completedQuest.questName == questName then
		-- print("[HasCompletedQuest] Player has completed quest:", npcName, questName)
		return true
	end
	
	return false
end

return HasCompletedQuest

