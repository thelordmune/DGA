--[[
	Dialogue Condition: HasPocketwatch
	
	Checks if the player has the pocketwatch in their inventory.
	
	Usage in Dialogue Trees:
	- Create a Condition node in your dialogue tree
	- Add this module as a child of the Condition node
	- Set the Condition node's Priority attribute to match the dialogue path priority
	
	Returns:
	- true if player has pocketwatch in inventory
	- false if player does not have pocketwatch
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

local HasPocketwatch = {}

function HasPocketwatch.Run()
	local player = Players.LocalPlayer
	if not player then
		warn("[HasPocketwatch] No local player found")
		return false
	end
	
	-- Get player entity
	local playerEntity = ref.get("local_player")
	if not playerEntity then
		warn("[HasPocketwatch] No player entity found")
		return false
	end
	
	-- Check if player has inventory
	if not world:has(playerEntity, comps.Inventory) then
		warn("[HasPocketwatch] Player has no inventory")
		return false
	end
	
	-- Get inventory
	local inventory = world:get(playerEntity, comps.Inventory)
	if not inventory or not inventory.items then
		warn("[HasPocketwatch] Inventory is empty or invalid")
		return false
	end
	
	-- Check if pocketwatch is in inventory
	for slot, item in pairs(inventory.items) do
		if item.name == "Pocketwatch" then
			-- print("[HasPocketwatch] Player has pocketwatch in slot", slot)
			return true
		end
	end
	
	-- print("[HasPocketwatch] Player does not have pocketwatch")
	return false
end

return HasPocketwatch

