local bridges = require(game:GetService("ReplicatedStorage").Modules.Bridges)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestEvents = {}

QuestEvents.Connect = function()
    bridges.Quests:Connect(function(Data)
        ---- print("Quest event received:", Data.Module)

        -- Quest modules are client-side representations, not the actual quest logic
        -- This should handle UI updates or client-side quest tracking
        local success, err = pcall(function()
            local QuestModule = require(game:GetService("ReplicatedStorage").Modules.QuestsFolder[Data.Module])
            if typeof(QuestModule) == "function" then
                QuestModule()
            elseif typeof(QuestModule) == "table" and QuestModule.Start then
                QuestModule.Start(Players.LocalPlayer)
            end
        end)

        if not success then
            warn("Failed to handle quest event for " .. Data.Module .. ": " .. err)
        end
    end)

    -- Handle TruthReturn - stop Truth room sounds when leaving
    bridges.TruthReturn:Connect(function()
        local Base = require(ReplicatedStorage.Effects.Base)
        if Base.StopTruthRoomSounds then
            Base.StopTruthRoomSounds()
        end
    end)
end

return QuestEvents