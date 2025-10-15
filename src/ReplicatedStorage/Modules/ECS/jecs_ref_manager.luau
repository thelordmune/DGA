--!strict
--[[
	Unified Ref Manager
	Combines the old player-specific ref system with the new jecs-utils generic ref system
	
	Usage:
		- For players: RefManager.player.get("player", robloxPlayer)
		- For NPCs/Models: RefManager.entity(npcModel, initFunction)
		- For singletons: RefManager.singleton("literal", "MySystem")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local world = require(script.Parent.jecs_world)
local oldRef = require(script.Parent.jecs_ref)
local newRef = require(script.Parent.ref)

-- Initialize new ref system with world
newRef.world(world)

export type RefManager = {
	-- Player-specific refs (old system)
	player: typeof(oldRef),
	
	-- Generic entity refs (new system)
	entity: typeof(newRef),
	
	-- Singleton refs (new system)
	singleton: typeof(newRef.singleton),
	
	-- Utility functions
	getEntityFromModel: (model: Model) -> number?,
	getModelFromEntity: (entity: number) -> Model?,
	cleanup: (key: any) -> (),
}

local RefManager: RefManager = {
	-- Old player ref system
	player = oldRef,
	
	-- New generic ref system (call directly)
	entity = newRef,
	
	-- Singleton system
	singleton = newRef.singleton,
	
	-- Utility: Get entity from model
	getEntityFromModel = function(model: Model): number?
		return newRef.find(model)
	end,
	
	-- Utility: Get model from entity (reverse lookup)
	getModelFromEntity = function(entity: number): Model?
		local comps = require(script.Parent.jecs_components)
		if world:has(entity, comps.Character) then
			return world:get(entity, comps.Character)
		end
		return nil
	end,
	
	-- Cleanup both systems
	cleanup = function(key: any)
		-- Try to clean up from new ref system
		newRef.delete(key)
		
		-- If it's a player, also clean up from old system
		if typeof(key) == "Instance" and key:IsA("Player") then
			oldRef.delete("player", key)
		end
	end,
}

return RefManager

