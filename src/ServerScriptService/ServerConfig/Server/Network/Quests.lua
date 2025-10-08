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

    elseif Data.Function == "Complete" then
        print("Completing quest: " .. Data.Module, "Choice:", Data.Arguments and Data.Arguments.choice or "none")

        -- Load required modules
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
        local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
        local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
        local LevelingManager = require(ReplicatedStorage.Modules.Utils.LevelingManager)
        local QuestData = require(ReplicatedStorage.Modules.Quests)

        -- Get player entity
        local playerEntity = ref.get("player", Player)
        if not playerEntity then
            warn("[Quest Complete] No player entity found for", Player.Name)
            return
        end

        -- Get quest data
        local questName = Data.Arguments and Data.Arguments.questName or "Missing Pocketwatch"
        local choice = Data.Arguments and Data.Arguments.choice or "CompleteGood"
        local npcName = Data.Module

        local questInfo = QuestData[npcName] and QuestData[npcName][questName]
        if not questInfo then
            warn("[Quest Complete] No quest data found for:", npcName, questName)
            return
        end

        -- Calculate rewards based on choice
        local experienceGained = questInfo.Rewards.Experience or 0
        local alignmentGained = 0
        local leveledUp = false
        local newLevel = LevelingManager.getLevel(playerEntity) or 1

        if choice == "CompleteGood" then
            -- Good choice: +alignment, free level
            alignmentGained = questInfo.Rewards.Alignment or 1
            LevelingManager.addAlignment(playerEntity, alignmentGained)
            LevelingManager.addExperience(playerEntity, experienceGained)

            -- Give free level
            newLevel = newLevel + 1
            LevelingManager.setLevel(playerEntity, newLevel)
            leveledUp = true

            print("[Quest Complete] Good choice - Alignment:", alignmentGained, "Free level:", newLevel)
        elseif choice == "CompleteEvil" then
            -- Evil choice: -alignment, no free level, just XP
            alignmentGained = -(questInfo.Rewards.Alignment or 1)
            LevelingManager.addAlignment(playerEntity, alignmentGained)

            local success, levelsGained = LevelingManager.addExperience(playerEntity, experienceGained)
            if success and levelsGained > 0 then
                leveledUp = true
                newLevel = LevelingManager.getLevel(playerEntity)
            end

            print("[Quest Complete] Evil choice - Alignment:", alignmentGained, "XP:", experienceGained)
        end

        -- Mark quest as completed and clean up quest components
        if world:has(playerEntity, comps.ActiveQuest) then
            world:remove(playerEntity, comps.ActiveQuest)
        end

        if world:has(playerEntity, comps.QuestItemCollected) then
            world:remove(playerEntity, comps.QuestItemCollected)
        end

        if world:has(playerEntity, comps.QuestData) then
            world:remove(playerEntity, comps.QuestData)
        end

        world:set(playerEntity, comps.CompletedQuest, {
            npcName = npcName,
            questName = questName,
            completedTime = os.clock(),
        })

        -- Send completion notification to client
        bridges.QuestCompleted:Fire(Player, {
            questName = questName,
            experienceGained = experienceGained,
            alignmentGained = alignmentGained,
            leveledUp = leveledUp,
            newLevel = newLevel,
        })

        print("[Quest Complete] Sent completion notification to client")

    elseif Data.Function == "End" then
        print("Ending quest: " .. Data.Module)

        -- Check if the old Quests folder exists (legacy support)
        local questsFolder = script.Parent.Parent:FindFirstChild("Quests")
        if questsFolder then
            local success, err = pcall(function()
                local QuestModule = require(questsFolder[Data.Module])
                if QuestModule.End then
                    QuestModule.End(Player)
                end
            end)

            if not success then
                warn("Failed to end quest " .. Data.Module .. ": " .. err)
            end
        else
            print("No Quests folder found - using new quest system")
        end
    end
end

return NetworkModule
