local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local Player = comps.Player
local Character = comps.Character
local Visuals = require(ReplicatedStorage.Modules.Visuals)

local Sift = require(ReplicatedStorage.Modules.Imports.Sift)

local lastTime = os.clock()

local function statelistener()
    local currentTime = os.clock()
    local deltaTime = currentTime - (lastTime or currentTime)
    lastTime = currentTime

    for entity, _ in world:query(comps.Character) do
        for component, data in pairs(comps) do
            local componentInstance = world:get(entity, comps[component])

            if type(componentInstance) == "table"
               and componentInstance.duration ~= nil
               and componentInstance.value ~= nil then

                local newDuration = componentInstance.duration - deltaTime

                if newDuration <= 0 then
                    -- Check if this is InCombat component and notify client when combat ends
                    local wasInCombat = component == "InCombat" and componentInstance.value == true

                    world:set(entity, comps[component], Sift.Dictionary.mergeDeep(
                        componentInstance,
                        {
                            value = false,
                            duration = 0
                        }
                    ))

                    -- Notify client that combat has ended
                    if wasInCombat then
                        local playerEntity = world:get(entity, comps.Player)
                        if playerEntity then
                            Visuals.FireClient(playerEntity, {
                                Module = "Base",
                                Function = "InCombat",
                                Arguments = { playerEntity, false },
                            })
                        end
                    end
                else
                    world:set(entity, comps[component], Sift.Dictionary.mergeDeep(
                        componentInstance,
                        {
                            duration = newDuration
                        }
                    ))
                    -- print(component.." updated to", newDuration, "for entity", entity)
                end
            end
        end
    end
end

return {
    run = function()
        statelistener()
    end,
    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}