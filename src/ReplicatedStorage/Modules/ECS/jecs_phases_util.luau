-- Shared utility for phase creation
local jecs = require(game:GetService("ReplicatedStorage").Modules.Imports.jecs)
local world = require(script.Parent.jecs_world)
local comps = require(script.Parent.jecs_components)

return {
    create = function(event, after)
        local phase = world:entity()
        world:set(phase, comps.Name, "Phase")
        world:set(phase, comps.Event, event)
        world:set(phase, comps.After, after)
        return phase
    end
}