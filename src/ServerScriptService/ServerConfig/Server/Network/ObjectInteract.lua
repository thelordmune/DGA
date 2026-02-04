local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

local Replicated = game:GetService("ReplicatedStorage")

-- ECS imports
local world = require(Replicated.Modules.ECS.jecs_world)
local comps = require(Replicated.Modules.ECS.jecs_components)

-- OPTIMIZATION: Cache query for better performance
local interactableQuery = world:query(comps.Interactable):cached()

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character
	if not Character then
		return
	end

	local objectId = Data.ObjectId
	if not objectId then
		warn("[ObjectInteract] No ObjectId provided")
		return
	end

	-- Find the entity with matching ObjectId using ECS
	local targetEntity = nil
	local targetObject = nil
	local handlerName = nil

	for entity in interactableQuery do
		local interactableData = world:get(entity, comps.Interactable)
		if interactableData and interactableData.objectId == objectId then
			targetEntity = entity
			targetObject = interactableData.model
			handlerName = interactableData.handlerName
			break
		end
	end

	if not targetObject then
		warn("[ObjectInteract] Object not found:", objectId)
		return
	end

	if not handlerName then
		warn("[ObjectInteract] No handler name in Interactable component:", objectId)
		return
	end

	-- Call the interaction handler
	local success, err = pcall(function()
		local handler = require(script.Parent.InteractionHandlers[handlerName])
		if handler and handler.OnInteract then
			handler.OnInteract(Player, targetObject)
		else
			warn("[ObjectInteract] Handler missing OnInteract function:", handlerName)
		end
	end)

	if not success then
		warn("[ObjectInteract] Error calling interaction handler:", err)
	end
end

return NetworkModule
