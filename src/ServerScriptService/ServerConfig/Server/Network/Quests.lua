local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

local Replicated = game:GetService("ReplicatedStorage")
local bridges = require(game:GetService("ReplicatedStorage").Modules.Bridges)

NetworkModule.EndPoint = function(Player, Data)
    ---- print("Quest packet received:", Data.Module, Data.Function)
    if Data.Function == "Start" then
        ---- print("Starting quest: " .. Data.Module)

        -- Set QuestAccepted component on server so observer can convert it to ActiveQuest
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
        local ref = RefManager.player
        local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
        local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

        local playerEntity = ref.get("player", Player)
        if playerEntity then
            ---- print("[Quest Start] Setting QuestAccepted component on server for:", Player.Name)
            world:set(playerEntity, comps.QuestAccepted, {
                npcName = Data.Module,
                questName = Data.Arguments[1] or "Missing Pocketwatch", -- Default for legacy support
                acceptedAt = os.clock(),
            })
        else
            warn("[Quest Start] ❌ No player entity found for:", Player.Name)
        end

        -- Call server-side quest module Start function if it exists
        local questModulesFolder = ReplicatedStorage.Modules:FindFirstChild("QuestsFolder")
        if questModulesFolder then
            local questModule = questModulesFolder:FindFirstChild(Data.Module)
            if questModule then
                local success, err = pcall(function()
                    local QuestScript = require(questModule)
                    if typeof(QuestScript) == "table" and QuestScript.Start then
                        ---- print("[Quest Start] 🎯 Calling quest module Start function for player:", Player.Name)
                        QuestScript.Start(Player) -- Pass player parameter
                    end
                end)

                if not success then
                    warn("[Quest Start] ❌ Failed to call quest module Start:", err)
                end
            end
        end

        -- Also fire to client for client-side quest handling
        bridges.Quests:Fire(Player, { Module = Data.Module })

    elseif Data.Function == "Complete" then
        ---- print("🎯 [Quest Complete] Received completion request")
        ---- print("  Full Data:", Data)
        ---- print("  NPC:", Data.Module)
        ---- print("  Arguments:", Data.Arguments)

        if not Data.Arguments or #Data.Arguments < 2 then
            warn("[Quest Complete] ❌ Invalid Arguments! Expected array with [questName, choice]")
            warn("[Quest Complete] Received:", Data.Arguments)
            return
        end

        -- Arguments is an array: [questName, choice]
        local questName = Data.Arguments[1]
        local choice = Data.Arguments[2]

        ---- print("  Quest Name:", questName)
        ---- print("  Choice:", choice)

        -- Load required modules
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
        local ref = RefManager.player -- Use player-specific ref system
        local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
        local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
        local LevelingManager = require(ReplicatedStorage.Modules.Utils.LevelingManager)
        local QuestData = require(ReplicatedStorage.Modules.Quests)

        -- Get player entity (server-side uses "player" key)
        ---- print("[Quest Complete] 🔍 Attempting to get player entity for:", Player.Name, "UserId:", Player.UserId)

        local playerEntity = ref.get("player", Player)
        ---- print("[Quest Complete] 🔍 ref.get returned:", playerEntity)

        if not playerEntity then
            warn("[Quest Complete] ❌ No player entity found for", Player.Name, "UserId:", Player.UserId)
            warn("[Quest Complete] 🔍 Checking all player entities in world...")

            -- Debug: Check what entities exist with Player component
            local playerEntitiesFound = 0
            for entity in world:query(comps.Player):iter() do
                local playerComp = world:get(entity, comps.Player)
                playerEntitiesFound = playerEntitiesFound + 1
                ---- print(`[Quest Complete] Found Player entity {entity} for {playerComp.Name} (UserId: {playerComp.UserId})`)

                if playerComp == Player then
                    playerEntity = entity
                    ---- print("[Quest Complete] ✅ Found matching player entity by Player component:", entity)
                    break
                end
            end

            if playerEntitiesFound == 0 then
                warn("[Quest Complete] ⚠️ No entities with Player component found in world!")
            end

            -- Try to find the entity by searching for the player's character
            if not playerEntity then
                local character = Player.Character
                if character then
                    ---- print("[Quest Complete] 🔍 Searching by character:", character.Name)
                    for entity in world:query(comps.Character):iter() do
                        local char = world:get(entity, comps.Character)
                        if char == character then
                            playerEntity = entity
                            ---- print("[Quest Complete] ✅ Found player entity by character:", entity)
                            break
                        end
                    end
                else
                    warn("[Quest Complete] ⚠️ Player has no character!")
                end
            end

            if not playerEntity then
                warn("[Quest Complete] ❌ Could not find player entity at all!")
                warn("[Quest Complete] 💡 This suggests the player entity was never created or was deleted")
                return
            end
        else
            ---- print("[Quest Complete] ✅ Found player entity via ref.get:", playerEntity)
        end

        -- NPC name from Module field
        local npcName = Data.Module

        local questInfo = QuestData[npcName] and QuestData[npcName][questName]
        if not questInfo then
            warn("[Quest Complete] No quest data found for:", npcName, questName)
            return
        end

        -- Calculate rewards based on choice
        local baseExperience = questInfo.Rewards.Experience or 0
        local baseAlignment = questInfo.Rewards.Alignment or 1
        local experienceGained = 0
        local alignmentGained = 0
        local leveledUp = false
        local newLevel = LevelingManager.getLevel(playerEntity) or 1

        if choice == "CompleteGood" then
            -- Good choice: full XP, +alignment, free level
            experienceGained = baseExperience
            alignmentGained = baseAlignment

            LevelingManager.addAlignment(playerEntity, alignmentGained)
            LevelingManager.addExperience(playerEntity, experienceGained)

            -- Give free level as bonus reward
            newLevel = newLevel + 1
            LevelingManager.setLevel(playerEntity, newLevel)
            leveledUp = true

            ---- print("[Quest Complete] ✅ Good choice - XP:", experienceGained, "Alignment: +" .. alignmentGained, "Free level:", newLevel)
        elseif choice == "CompleteEvil" then
            -- Evil choice: half XP, -alignment, no free level
            experienceGained = math.floor(baseExperience / 2)
            alignmentGained = -baseAlignment

            LevelingManager.addAlignment(playerEntity, alignmentGained)

            local success, levelsGained = LevelingManager.addExperience(playerEntity, experienceGained)
            if success and levelsGained > 0 then
                leveledUp = true
                newLevel = LevelingManager.getLevel(playerEntity)
            end

            ---- print("[Quest Complete] ❌ Evil choice - XP:", experienceGained, "(half)", "Alignment:", alignmentGained, "No free level")
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

        -- Call quest module's Complete function if it exists
        local questModulesFolder = ReplicatedStorage.Modules:FindFirstChild("QuestsFolder")
        if questModulesFolder then
            local questModule = questModulesFolder:FindFirstChild(npcName)
            if questModule then
                local success, err = pcall(function()
                    local QuestScript = require(questModule)
                    if typeof(QuestScript) == "table" and QuestScript.Complete then
                        ---- print("[Quest Complete] 🎯 Calling quest module Complete function")
                        QuestScript.Complete(Player, questName, choice)
                    end
                end)

                if not success then
                    warn("[Quest Complete] ❌ Failed to call quest module Complete:", err)
                end
            end
        end

        -- Send completion notification to client
        ---- print("🔔 [Quest Complete] Sending completion notification to client:")
        ---- print("  Quest Name:", questName)
        ---- print("  Experience:", experienceGained)
        ---- print("  Alignment:", alignmentGained)
        ---- print("  Leveled Up:", leveledUp)
        ---- print("  New Level:", newLevel)

        bridges.QuestCompleted:Fire(Player, {
            questName = questName,
            experienceGained = experienceGained,
            alignmentGained = alignmentGained,
            leveledUp = leveledUp,
            newLevel = newLevel,
        })

        ---- print("✅ [Quest Complete] Notification sent!")

    elseif Data.Function == "End" then
        ---- print("Ending quest: " .. Data.Module)

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
            ---- print("No Quests folder found - using new quest system")
        end
    else
        -- Handle custom quest actions (e.g., "Teleport")
        ---- print("🎯 [Quest Custom Action] Received:", Data.Function)
        ---- print("  NPC:", Data.Module)
        ---- print("  Arguments:", Data.Arguments)

        local questModulesFolder = Replicated.Modules:FindFirstChild("QuestsFolder")
        if questModulesFolder then
            local questModule = questModulesFolder:FindFirstChild(Data.Module)
            if questModule then
                local success, err = pcall(function()
                    local QuestScript = require(questModule)
                    -- Call the function with the same name as Data.Function (e.g., "Teleport")
                    if typeof(QuestScript) == "table" and QuestScript[Data.Function] then
                        ---- print("[Quest Custom Action] 🎯 Calling quest module function:", Data.Function)
                        QuestScript[Data.Function](Player, unpack(Data.Arguments or {}))
                    else
                        warn("[Quest Custom Action] ⚠️ Function not found in quest module:", Data.Function)
                    end
                end)

                if not success then
                    warn("[Quest Custom Action] ❌ Failed to call quest module function:", err)
                end
            else
                warn("[Quest Custom Action] ❌ Quest module not found:", Data.Module)
            end
        else
            warn("[Quest Custom Action] ❌ QuestsFolder not found")
        end
    end
end

return NetworkModule
