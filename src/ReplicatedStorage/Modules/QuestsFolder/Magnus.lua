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
                if not playerEntity then
                    warn("[Magnus Quest] Failed to get player entity for:", touchingPlayer.Name)
                    return
                end

                print("[Magnus Quest] Player entity found:", playerEntity)
                print("[Magnus Quest] Entity exists in world:", world:contains(playerEntity))

                -- Check if entity has Character component (means it's initialized)
                if not world:has(playerEntity, comps.Character) then
                    warn("[Magnus Quest] Entity has no Character component - not initialized yet!")
                    return
                end

                local character = world:get(playerEntity, comps.Character)
                print("[Magnus Quest] Character:", character and character.Name or "nil")

                -- Check for required components
                print("[Magnus Quest] Has ActiveQuest:", world:has(playerEntity, comps.ActiveQuest))
                print("[Magnus Quest] Has Inventory:", world:has(playerEntity, comps.Inventory))
                print("[Magnus Quest] Has Player:", world:has(playerEntity, comps.Player))

                -- Check if player still has the active quest
                if not world:has(playerEntity, comps.ActiveQuest) then
                    warn("[Magnus Quest] Player no longer has active quest!")
                    warn("[Magnus Quest] This means ActiveQuest was removed before pocketwatch pickup!")
                    return
                end

                local activeQuest = world:get(playerEntity, comps.ActiveQuest)
                print("[Magnus Quest] Active quest:", activeQuest.npcName, activeQuest.questName)

                if activeQuest.npcName ~= "Magnus" or activeQuest.questName ~= "Missing Pocketwatch" then
                    warn("[Magnus Quest] Player has different active quest:", activeQuest.npcName, activeQuest.questName)
                    return
                end

                -- Set QuestItemCollected component
                print("[Magnus Quest] Setting QuestItemCollected component...")
                world:set(playerEntity, comps.QuestItemCollected, {
                    npcName = "Magnus",
                    questName = "Missing Pocketwatch",
                    itemName = "Pocketwatch",
                    collectedTime = os.clock(),
                })
                print("[Magnus Quest] QuestItemCollected component set!")

                -- Add pocketwatch to inventory (server-side)
                print("[Magnus Quest] Attempting to add pocketwatch to inventory...")
                print("[Magnus Quest] Player entity:", playerEntity)
                print("[Magnus Quest] Has Inventory component:", world:has(playerEntity, comps.Inventory))

                if world:has(playerEntity, comps.Inventory) then
                    local inv = world:get(playerEntity, comps.Inventory)
                    print("[Magnus Quest] Current inventory items count:", inv and inv.items and #inv.items or "nil")
                    print("[Magnus Quest] Max slots:", inv and inv.maxSlots or "nil")
                end

                local addSuccess, slot = InventoryManager.addItem(
                    playerEntity,
                    "Pocketwatch",
                    "item",
                    1,
                    false,
                    "A pocketwatch, seems to be used for something important."
                )

                print("[Magnus Quest] addItem returned - success:", addSuccess, "slot:", slot)

                if addSuccess then
                    print("[Magnus Quest] ✅ Pocketwatch added to", touchingPlayer.Name, "'s inventory in slot", slot)

                    -- Verify it was actually added
                    if world:has(playerEntity, comps.Inventory) then
                        local verifyInv = world:get(playerEntity, comps.Inventory)
                        if verifyInv.items[slot] then
                            print("[Magnus Quest] ✅ VERIFIED: Pocketwatch is in slot", slot)
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
                    print("[Magnus Quest] ✅ Pocketwatch removed from inventory")
                    -- Inventory sync happens automatically via markInventoryChanged
                else
                    warn("[Magnus Quest] ❌ Failed to remove pocketwatch from inventory!")
                end

            elseif choice == "CompleteEvil" then
                -- Player kept the pocketwatch - spawn an aggressive guard!
                print("[Magnus Quest] 🚨 Player chose evil option - spawning aggressive guard!")

                local character = player.Character
                if not character or not character:FindFirstChild("HumanoidRootPart") then
                    warn("[Magnus Quest] Player has no character!")
                    return
                end

                -- Spawn guard near the player
                local playerPos = character.HumanoidRootPart.Position
                local spawnOffset = Vector3.new(10, 0, 10) -- Spawn 10 studs away
                local guardSpawnPos = playerPos + spawnOffset

                -- Clone the Bandit model to create a guard
                local guardModel = game.ReplicatedStorage.Assets.NPC.Bandit:Clone()
                guardModel.Name = "QuestGuard"
                guardModel:SetAttribute("Weapon", "Fist")
                guardModel:SetAttribute("Equipped", false)
                guardModel:SetAttribute("IsNPC", true)

                -- Position the guard
                guardModel:PivotTo(CFrame.new(guardSpawnPos))

                -- Add to workspace
                guardModel.Parent = workspace.World.Live

                print("[Magnus Quest] ✅ Guard spawned at:", guardSpawnPos)

                -- Wait for guard to be initialized by the NPC system
                task.wait(0.5)

                -- Make the guard aggressive towards the player
                local damageLog = guardModel:FindFirstChild("Damage_Log")
                if not damageLog then
                    damageLog = Instance.new("Folder")
                    damageLog.Name = "Damage_Log"
                    damageLog.Parent = guardModel
                end

                -- Add player to damage log to make guard aggro
                local attackRecord = Instance.new("ObjectValue")
                attackRecord.Name = "Attack_" .. os.clock()
                attackRecord.Value = character
                attackRecord.Parent = damageLog

                print("[Magnus Quest] ✅ Guard set to aggressive mode targeting:", player.Name)
            end
        end
    }
else
    -- Client-side - return empty module
    return function()
        -- Quest spawning happens on server
    end
end