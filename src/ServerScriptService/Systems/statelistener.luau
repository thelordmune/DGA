local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local Player = comps.Player
local Character = comps.Character


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
                    world:set(entity, comps[component], Sift.Dictionary.mergeDeep(
                        componentInstance,
                        {
                            value = false,
                            duration = 0
                        }
                    ))
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