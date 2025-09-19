local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

local function questcleanup(world)
    for entity in world:query(comps.CompletedQuest):iter() do
        local completedQuest = world:get(entity, comps.CompletedQuest)
        if os.clock() - completedQuest.completedTime > 10 then
            world:remove(entity, comps.CompletedQuest)
        end
    end
end

return {
    run = function(world)
        questcleanup(world)
    end,
    settings = {
        phase = "Heartbeat",
        paused = false
    }
}