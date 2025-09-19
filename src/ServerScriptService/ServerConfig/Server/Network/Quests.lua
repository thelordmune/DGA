local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

local Replicated = game:GetService("ReplicatedStorage")
local bridges = require(game:GetService("ReplicatedStorage").Modules.Bridges)

NetworkModule.EndPoint = function(Player, Data)
    print("Quest packet received:", Data.Module, Data.Function)
    if Data.Function == "Start" then
        print("Starting quest: " .. Data.Module)
        bridges.Quests:Fire(Player, { Module = Data.Module })
        -- -- Call the quest module directly
        -- local success, err = pcall(function()
        --     local QuestModule = require(script.Parent.Parent.Quests[Data.Module])
        --     if QuestModule.Start then
        --         QuestModule.Start(Player)
        --     else
        --         warn("Quest module " .. Data.Module .. " has no Start function")
        --     end
        -- end)
        
        -- if not success then
        --     warn("Failed to start quest " .. Data.Module .. ": " .. err)
        -- end
        
        -- Also fire the bridge for other systems

        
    end
    if Data.Function == "End" then
        print("Ending quest: " .. Data.Module)
        
        local success, err = pcall(function()
            local QuestModule = require(script.Parent.Parent.Quests[Data.Module])
            if QuestModule.End then
                QuestModule.End(Player)
            end
        end)
        
        if not success then
            warn("Failed to end quest " .. Data.Module .. ": " .. err)
        end
    end
end

return NetworkModule
