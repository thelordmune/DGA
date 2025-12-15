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
            ---- print("[Magnus Quest] Starting quest for player:", player and player.Name or "UNKNOWN")

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

                ---- print("[Magnus Quest] Pocketwatch touched by:", touchingPlayer.Name)

                -- Only allow the quest owner to pick it up
                if touchingPlayer ~= player then
                    ---- print("[Magnus Quest] Wrong player tried to pick up pocketwatch!")
                    return
                end

                -- Disconnect to prevent multiple pickups
                touchConnection:Disconnect()
                item:Destroy()
                spawnedPocketwatches[player] = nil

                -- Get player entity
                local playerEntity = ref.get("player", touchingPlayer)
                if not playerEntity then
                    warn("[Magnus Quest] Failed to get player entity for:", touchingPlayer.Name)
                    return
                end

                ---- print("[Magnus Quest] Player entity found:", playerEntity)
                ---- print("[Magnus Quest] Entity exists in world:", world:contains(playerEntity))

                -- Check if entity has Character component (means it's initialized)
                if not world:has(playerEntity, comps.Character) then
                    warn("[Magnus Quest] Entity has no Character component - not initialized yet!")
                    return
                end

                local character = world:get(playerEntity, comps.Character)
                ---- print("[Magnus Quest] Character:", character and character.Name or "nil")

                -- Check for required components
                ---- print("[Magnus Quest] Has ActiveQuest:", world:has(playerEntity, comps.ActiveQuest))
                ---- print("[Magnus Quest] Has Inventory:", world:has(playerEntity, comps.Inventory))
                ---- print("[Magnus Quest] Has Player:", world:has(playerEntity, comps.Player))

                -- Check if player still has the active quest
                if not world:has(playerEntity, comps.ActiveQuest) then
                    warn("[Magnus Quest] Player no longer has active quest!")
                    warn("[Magnus Quest] This means ActiveQuest was removed before pocketwatch pickup!")
                    return
                end

                local activeQuest = world:get(playerEntity, comps.ActiveQuest)
                ---- print("[Magnus Quest] Active quest:", activeQuest.npcName, activeQuest.questName)

                if activeQuest.npcName ~= "Magnus" or activeQuest.questName ~= "Missing Pocketwatch" then
                    warn("[Magnus Quest] Player has different active quest:", activeQuest.npcName, activeQuest.questName)
                    return
                end

                -- Set QuestItemCollected component
                ---- print("[Magnus Quest] Setting QuestItemCollected component...")
                world:set(playerEntity, comps.QuestItemCollected, {
                    npcName = "Magnus",
                    questName = "Missing Pocketwatch",
                    itemName = "Pocketwatch",
                    collectedTime = os.clock(),
                })
                ---- print("[Magnus Quest] QuestItemCollected component set!")

                -- Add pocketwatch to inventory (server-side)
                ---- print("[Magnus Quest] Attempting to add pocketwatch to inventory...")
                ---- print("[Magnus Quest] Player entity:", playerEntity)
                ---- print("[Magnus Quest] Has Inventory component:", world:has(playerEntity, comps.Inventory))

                if world:has(playerEntity, comps.Inventory) then
                    local inv = world:get(playerEntity, comps.Inventory)
                    ---- print("[Magnus Quest] Current inventory items count:", inv and inv.items and #inv.items or "nil")
                    ---- print("[Magnus Quest] Max slots:", inv and inv.maxSlots or "nil")
                end

                local addSuccess, slot = InventoryManager.addItem(
                    playerEntity,
                    "Pocketwatch",
                    "item",
                    1,
                    false,
                    "A pocketwatch, seems to be used for something important."
                )

                ---- print("[Magnus Quest] addItem returned - success:", addSuccess, "slot:", slot)

                if addSuccess then
                    ---- print("[Magnus Quest] ✅ Pocketwatch added to", touchingPlayer.Name, "'s inventory in slot", slot)

                    -- Verify it was actually added
                    if world:has(playerEntity, comps.Inventory) then
                        local verifyInv = world:get(playerEntity, comps.Inventory)
                        if verifyInv.items[slot] then
                            ---- print("[Magnus Quest] ✅ VERIFIED: Pocketwatch is in slot", slot)
                        else
                            warn("[Magnus Quest] ❌ VERIFICATION FAILED: Pocketwatch NOT in slot", slot)
                        end
                    end
                else
                    warn("[Magnus Quest] ❌ Failed to add pocketwatch - inventory might be full")
                end
            end)
        end,

        -- Called when quest is completed
        Complete = function(player, questName, choice)
            ---- print("[Magnus Quest] Complete called for:", player.Name, "Choice:", choice)

            local playerEntity = ref.get("player", player)
            if not playerEntity then
                warn("[Magnus Quest] Player entity not found!")
                return
            end

            -- Make Magnus untalkable by removing him from Dialogue folder
            local dialogueFolder = workspace.World:FindFirstChild("Dialogue")
            if dialogueFolder then
                local magnusNPC = dialogueFolder:FindFirstChild("Magnus")
                if magnusNPC then
                    ---- print("[Magnus Quest] Removing Magnus from Dialogue folder - no longer talkable")
                    magnusNPC.Parent = workspace.World.Live
                end
            end

            if choice == "CompleteGood" then
                -- Player returned the pocketwatch - remove it from inventory
                ---- print("[Magnus Quest] Player returned pocketwatch - removing from inventory")
                local success = InventoryManager.removeItem(playerEntity, "Pocketwatch", 1)

                if success then
                    ---- print("[Magnus Quest] ✅ Pocketwatch removed from inventory")
                    -- Inventory sync happens automatically via markInventoryChanged
                else
                    warn("[Magnus Quest] ❌ Failed to remove pocketwatch from inventory!")
                end

            elseif choice == "CompleteEvil" then
                -- Player kept the pocketwatch - spawn an aggressive guard!
                ---- print("[Magnus Quest] 🚨 Player chose evil option - spawning aggressive guard!")

                local character = player.Character
                if not character or not character:FindFirstChild("HumanoidRootPart") then
                    warn("[Magnus Quest] Player has no character!")
                    return
                end

                -- Get the spawn position near the player
                local playerPos = character.HumanoidRootPart.Position
                local spawnOffset = Vector3.new(10, 0, 10)
                local guardSpawnPos = playerPos + spawnOffset

                -- Load the QuestGuard NPC data
                local QuestGuardData = require(game.ReplicatedStorage.Regions.Forest.Npcs.QuestGuard)

                -- Update spawn location
                QuestGuardData.DataToSendOverAndUdpate.Spawning.Locations = { guardSpawnPos }
                QuestGuardData.Quantity = 1
                QuestGuardData.AlwaysSpawn = true

                -- Use the serializer to create NPC data
                local seralizer = require(Replicated.Seralizer)

                -- Prepare NPC file (same way LeftGuard/RightGuard are spawned)
                local regionName = "Forest"
                local regionContainer = workspace.World.Live:FindFirstChild(regionName)
                if not regionContainer then
                    regionContainer = Instance.new("Folder")
                    regionContainer.Name = regionName
                    regionContainer.Parent = workspace.World.Live
                end

                local npcsContainer = regionContainer:FindFirstChild("NPCs")
                if not npcsContainer then
                    npcsContainer = Instance.new("Folder")
                    npcsContainer.Name = "NPCs"
                    npcsContainer.Parent = regionContainer
                end

                -- Create NPC file
                local npcFile = game.ReplicatedStorage.NpcFile:Clone()
                npcFile.Name = "QuestGuard"
                npcFile:SetAttribute("SetName", "QuestGuard")
                npcFile:SetAttribute("DefaultName", "QuestGuard")

                -- Create data folder
                local dataFolder = Instance.new("Folder")
                dataFolder.Name = "Data"
                seralizer.LoadTableThroughInstance(dataFolder, QuestGuardData.DataToSendOverAndUdpate)
                dataFolder.Parent = npcFile

                npcFile.Parent = npcsContainer

                ---- print("[Magnus Quest] Quest guard NPC file created!")

                -- Wait for the guard to spawn and be fully loaded
                task.spawn(function()
                    local spawnedGuard
                    local maxWaitTime = 10
                    local startTime = os.clock()

                    -- Poll for the guard model to spawn
                    while not spawnedGuard and (os.clock() - startTime) < maxWaitTime do
                        for _, model in workspace.World.Live:GetDescendants() do
                            if model:IsA("Model") and model:FindFirstChild("Humanoid") and
                               (model.Name:find("QuestGuard") or (model:GetAttribute("SetName") and model:GetAttribute("SetName") == "QuestGuard")) then
                                spawnedGuard = model
                                
                                break
                            end
                        end

                        if not spawnedGuard then
                            task.wait(0.5)
                        end
                    end

                    if spawnedGuard then
                        ---- print("[Magnus Quest] Found spawned guard:", spawnedGuard.Name)

                        local damageLog = spawnedGuard:WaitForChild("Damage_Log", 5)
                        if damageLog then
                            task.wait(0.5)

                            local attackRecord = Instance.new("ObjectValue")
                            attackRecord.Name = "Attack_" .. os.clock()
                            attackRecord.Value = character
                            attackRecord.Parent = damageLog
                            ---- print("[Magnus Quest] Guard set to target:", player.Name)
                        else
                            warn("[Magnus Quest] Damage_Log not found on guard!")
                        end
                    else
                        warn("[Magnus Quest] Could not find spawned guard model after", maxWaitTime, "seconds!")
                    end
                end)
            end
        end
    }
else
    return function()
    end
end