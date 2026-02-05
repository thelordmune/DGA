
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local world = require(script.Parent.jecs_world)

local JecsBatch = {}

function JecsBatch.setMany(entity: number, componentPairs: {{any}})
	local ids = {}
	local values = {}
	
	for i, pair in (componentPairs) do
		ids[i] = pair[1]
		values[i] = pair[2]
	end
	
	jecs.bulk_insert(world, entity, ids, values)
end
function JecsBatch.builder(entity: number)
	local componentPairs = {}
	
	local builder = {}
	
	function builder:set(component, value)
		table.insert(componentPairs, {component, value})
		return self
	end
	
	function builder:apply()
		if #componentPairs > 0 then
			JecsBatch.setMany(entity, componentPairs)
		end
		return entity
	end
	
	return builder
end

return JecsBatch

