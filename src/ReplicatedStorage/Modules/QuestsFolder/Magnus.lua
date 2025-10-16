local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local isServer = RunService:IsServer()

if isServer then
    -- Server-side quest module
    local ref = require(Replicated.Modules.ECS.jecs_ref)
    local world = require(Replicated.Modules.ECS.jecs_world)
    local comps = require(Replicated.Modules.ECS.jecs_components)
    local InventoryManager = require(Replicated.Modules.Utils.InventoryManager)

    -- Track spawned pocketwatches per player
    local spawnedPocketwatches = {} -- {[player] = pocketwatchModel}

    return {
        -- Called when quest is accepted
        Start = function(player)
            print("[Magnus Quest] Starting quest for player:", player and player.Name or "UNKNOWN")

            -- Validate player parameter
            if not player or not player:IsA("Player") then
                warn("[Magnus Quest] Start called without valid player!")
                return
            end

            -- Clean up any existing pocketwatch for this player
            if spawnedPocketwatches[player] then
                if spawnedPocketwatches[player].Parent then
                    spawnedPocketwatches[player]:Destroy()
                end
                spawnedPocketwatches[player] = nil
            end

            local item = Replicated.Assets.Quest_Items.Pocketwatch:Clone()
            local randomspots = workspace.World.Quests.Magnus:GetChildren()
            local randomspot = randomspots[math.random(1, #randomspots)]
            item:SetPrimaryPartCFrame(randomspot.CFrame)
            item.Parent = randomspot

            -- Store reference to this player's pocketwatch
            spawnedPocketwatches[player] = item

            -- Use Touched event instead of ClickDetector for more reliable pickup
            local primaryPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
            if not primaryPart then
                warn("[Magnus Quest] Pocketwatch has no PrimaryPart or BasePart!")
                return
            end

            local touchConnection
            touchConnection = primaryPart.Touched:Connect(function(hit)
                local touchingCharacter = hit.Parent
                if not touchingCharacter or not touchingCharacter:FindFirstChild("Humanoid") then
                    return
                end

                local touchingPlayer = game.Players:GetPlayerFromCharacter(touchingCharacter)
                if not touchingPlayer then
                    return
                end

                print("[Magnus Quest] Pocketwatch touched by:", touchingPlayer.Name)

                -- Only allow the quest owner to pick it up
                if touchingPlayer ~= player then
                    print("[Magnus Quest] Wrong player tried to pick up pocketwatch!")
                    return
                end

                -- Disconnect to prevent multiple pickups
                touchConnection:Disconnect()
                item:Destroy()
                spawnedPocketwatches[player] = nil

                -- Get player entity
                local playerEntity = ref.get("player", touchingPlayer)
                if playerEntity then
                    -- Check if player still has the active quest
                    if not world:has(playerEntity, comps.ActiveQuest) then
                        warn("[Magnus Quest] Player no longer has active quest!")
                        return
                    end

                    local activeQuest = world:get(playerEntity, comps.ActiveQuest)
                    if activeQuest.npcName ~= "Magnus" or activeQuest.questName ~= "Missing Pocketwatch" then
                        warn("[Magnus Quest] Player has different active quest!")
                        return
                    end

                    -- Set QuestItemCollected component
                    world:set(playerEntity, comps.QuestItemCollected, {
                        npcName = "Magnus",
                        questName = "Missing Pocketwatch",
                        itemName = "Pocketwatch",
                        collectedTime = os.clock(),
                    })

                    -- Add pocketwatch to inventory (server-side)
                    local success = InventoryManager.addItem(
                        playerEntity,
                        "Pocketwatch",
                        "item",
                        1,
                        false,
                        "A pocketwatch, seems to be used for something important."
                    )

                    if success then
                        print("[Magnus Quest] Pocketwatch added to", touchingPlayer.Name, "'s inventory")
                        -- Inventory sync happens automatically via markInventoryChanged
                    else
                        warn("[Magnus Quest] Failed to add pocketwatch to inventory!")
                    end
                end
            end)
        end,

        -- Called when quest is completed
        Complete = function(player, questName, choice)
            print("[Magnus Quest] Complete called for:", player.Name, "Choice:", choice)

            local playerEntity = ref.get("player", player)
            if not playerEntity then
                warn("[Magnus Quest] Player entity not found!")
                return
            end

            if choice == "CompleteGood" then
                -- Player returned the pocketwatch - remove it from inventory
                print("[Magnus Quest] Player returned pocketwatch - removing from inventory")
                local success = InventoryManager.removeItem(playerEntity, "Pocketwatch", 1)

                if success then
                    print("[Magnus Quest] Pocketwatch removed from inventory")
                    -- Inventory sync happens automatically via markInventoryChanged
                else
                    warn("[Magnus Quest] Failed to remove pocketwatch from inventory!")
                end

            elseif choice == "CompleteEvil" then
                -- Player kept the pocketwatch - leave it in inventory
                print("[Magnus Quest] Player kept pocketwatch - leaving in inventory")
            end
        end
    }
else
    -- Client-side - return empty module
    return function()
        -- Quest spawning happens on server
    end
end