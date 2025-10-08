--[[
	Dialogue Condition: HasActiveQuest
	
	Checks if the player has an active quest from a specific NPC.
	
	Usage in Dialogue Trees:
	- Create a Condition node in your dialogue tree
	- Add this module as a child of the Condition node
	- Set the Condition node's Priority attribute to match the dialogue path priority
	
	Returns:
	- true if player has an active quest from the NPC
	- false if player does not have an active quest
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

local HasActiveQuest = {}

function HasActiveQuest.Run(npcName)
	local player = Players.LocalPlayer
	if not player then
		warn("[HasActiveQuest] No local player found")
		return false
	end
	
	-- Get player entity
	local playerEntity = ref.get("local_player")
	if not playerEntity then
		warn("[HasActiveQuest] No player entity found")
		return false
	end
	
	-- Check if player has ActiveQuest component
	if not world:has(playerEntity, comps.ActiveQuest) then
		return false
	end
	
	-- Get active quest data
	local activeQuest = world:get(playerEntity, comps.ActiveQuest)
	if not activeQuest then
		return false
	end
	
	-- Check if the active quest is from this NPC
	if activeQuest.npcName == npcName then
		print("[HasActiveQuest] Player has active quest from", npcName, ":", activeQuest.questName)
		return true
	end
	
	return false
end

return HasActiveQuest

