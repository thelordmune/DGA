--[[
	Example Dialogue Condition for Magnus NPC
	
	This is a ready-to-use example that checks if the player has an active quest from Magnus.
	
	HOW TO USE:
	1. In your Magnus dialogue tree, create a Condition node
	2. Set the Condition node's Type attribute to "Condition"
	3. Set the Condition node's Priority attribute to 1
	4. Add this ModuleScript as a child of the Condition node
	5. Connect the Condition node as an input to your "quest active" dialogue path
	
	WHAT IT DOES:
	- Returns true if player has an active quest from Magnus
	- Returns false if player does not have an active quest
	- When true, the dialogue will show "Did you find my pocketwatch yet?"
	- When false, the dialogue will show the default greeting
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local ref = RefManager.player -- Use player-specific ref system
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

local MagnusActiveQuest = {}

function MagnusActiveQuest.Run()
	local player = Players.LocalPlayer
	if not player then
		return false
	end
	
	-- Get player entity
	local playerEntity = ref.get("local_player")
	if not playerEntity then
		return false
	end
	
	-- Check if player has an active quest
	if not world:has(playerEntity, comps.ActiveQuest) then
		-- print("[Magnus Dialogue] Player has no active quests")
		return false
	end
	
	-- Get the active quest
	local activeQuest = world:get(playerEntity, comps.ActiveQuest)
	if not activeQuest then
		return false
	end
	
	-- Check if it's Magnus's quest
	if activeQuest.npcName == "Magnus" then
		-- print("[Magnus Dialogue] Player has active quest from Magnus:", activeQuest.questName)
		return true
	else
		-- print("[Magnus Dialogue] Player has quest from different NPC:", activeQuest.npcName)
		return false
	end
end

return MagnusActiveQuest

