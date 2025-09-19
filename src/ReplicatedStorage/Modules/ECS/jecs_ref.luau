local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local world = require(script.Parent.jecs_world)

local running_on: "server" | "client" = (if RunService:IsServer() then "server" else "client")
local local_player_entity = world:entity()
local local_character_entity: jecs.Entity? = nil
local player_refs: { [string]: jecs.Entity } = {}
local network_id_refs: { [number]: jecs.Entity } = {}
local singleton_refs: { [string]: jecs.Entity } = {}
local current_run: jecs.Entity? = nil
local game_global: jecs.Entity? = nil
local memory_refs = world:entity()
local memory_reference = world:component() :: jecs.Entity<{}>

world:add(memory_reference, jecs.pair(jecs.OnDeleteTarget, jecs.Remove))

export type EntityMemoryRef = { jecs.Entity }

export type DefineFunction =
	((type: "local_character", entity: jecs.Entity) -> ())
	& ((type: "network_id", id: number, entity: jecs.Entity) -> ())
	& ((type: "player", roblox_player: Player, entity: jecs.Entity) -> ())
	& ((type: "current_run", entity: jecs.Entity) -> ())
	& ((type: "game", entity: jecs.Entity) -> ())

export type GetFunction =
	((type: "local_player") -> jecs.Entity)
	& ((type: "local_character") -> jecs.Entity?)
	& ((type: "network_id", id: number) -> jecs.Entity?)
	& ((type: "player", roblox_player: Player) -> jecs.Entity?)
	& ((type: "current_run") -> jecs.Entity?)
	& ((type: "game") -> jecs.Entity?)

export type DeleteFunction =
	((type: "local_character") -> ())
	& ((type: "network_id", id: number) -> ())
	& ((type: "player", roblox_player: Player) -> ())
	& ((type: "current_run") -> ())

export type SingletonFunction =
    ((type: "string", name: string) -> jecs.Entity)
    & ((type: "memory", entity: jecs.Entity) -> { jecs.Entity })

local ref = {}

ref.get = (
	function(type, data: any): any?
		if type == "local_player" then
			return local_player_entity
		elseif type == "local_character" then
			assert(running_on == "client", "Cannot get local_character on server")

			return local_character_entity :: any
		elseif type == "network_id" then
			return network_id_refs[data]
		elseif type == "player" then
			return player_refs[`{data.UserId}`]
		elseif type == "current_run" then
			return current_run :: jecs.Entity
		elseif type == "game" then
			return game_global :: jecs.Entity
		end

		return error("unreachable")
	end
) :: GetFunction

ref.define = (
	function(type: string, data: any, entity: jecs.Entity)
		if type == "local_character" then
			assert(running_on == "client", "Cannot define local_character on server")

			local_character_entity = data
		elseif type == "network_id" then
			network_id_refs[data] = entity
		elseif type == "player" then
			player_refs[`{data.UserId}`] = entity
		elseif type == "current_run" then
			current_run = data
		elseif type == "game" then
			game_global = data
		end
	end :: any
) :: DefineFunction

--[=[
	deletes the entity and deletes the reference
]=]
ref.delete = (
	function(type: string, data: any)
		if type == "local_character" then
			assert(running_on == "client", "Cannot delete local_character on server")

			if local_character_entity then
				world:delete(local_character_entity :: any)
				local_character_entity = nil
			end
		elseif type == "network_id" and network_id_refs[data] then
			world:delete(network_id_refs[data])
			network_id_refs[data] = nil
		elseif type == "player" and player_refs[`{data.UserId}`] then
			world:delete(player_refs[`{data.UserId}`])
			player_refs[`{data.UserId}`] = nil
		elseif type == "current_run" then
			if current_run then
				world:delete(current_run :: jecs.Entity)
				current_run = nil
			end
		end
	end :: any
) :: DeleteFunction

ref.untrack = (
	function(type: string, data: any)
		if type == "local_character" then
			assert(running_on == "client", "Cannot delete local_character on server")

			if local_character_entity then local_character_entity = nil end
		elseif type == "network_id" and network_id_refs[data] then
			network_id_refs[data] = nil
		elseif type == "player" and player_refs[`{data.UserId}`] then
			player_refs[`{data.UserId}`] = nil
		elseif type == "current_run" then
			if current_run then current_run = nil end
		end
	end :: any
) :: DeleteFunction

ref.singleton = (
	function(type: "literal" | "memory", data: any): any
		if type == "literal" then
			local ent = singleton_refs[data]
			if not ent then
				ent = world:entity()
				singleton_refs[data] = ent
			end
			return ent
		elseif type == "memory" then
			if not world:contains(data) then return nil end
			local reference_pair = jecs.pair(memory_reference, data)
			-- Luau ???????
			local reference_found = (world :: any):get(memory_refs, reference_pair)
			if not reference_found then
				reference_found = { data };
				(world :: any):set(memory_refs, reference_pair, reference_found)
			end
			return reference_found
		else
			return error(`Invalid type for ref.singleton: "{type}"`)
		end
	end
) :: SingletonFunction

ref.__memoryRefs = memory_refs
ref.__memoryRef = memory_reference

return ref
