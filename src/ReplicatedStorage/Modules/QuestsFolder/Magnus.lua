local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local isServer = RunService:IsServer()

if isServer then
    -- Server-side quest module
    local ref = require(Replicated.Modules.ECS.jecs_ref)
    local world = require(Replicated.Modules.ECS.jecs_world)
    local comps = require(Replicated.Modules.ECS.jecs_components)
    local InventoryManager = require(Replicated.Modules.Utils.InventoryManager)

    return {
        -- Called when quest is accepted
        Start = function()
            print("[Magnus Quest] Starting quest - spawning pocketwatch")
            local item = Replicated.Assets.Quest_Items.Pocketwatch:Clone()
            local randomspots = workspace.World.Quests.Magnus:GetChildren()
            local randomspot = randomspots[math.random(1, #randomspots)]
            item:SetPrimaryPartCFrame(randomspot.CFrame)
            item.Parent = randomspot

            local clickdetector = item.ClickDetector
            clickdetector.MouseClick:Connect(function(player)
                print("[Magnus Quest] Pocketwatch clicked by:", player.Name)
                item:Destroy()

                -- Get player entity
                local playerEntity = ref.get("player", player)
                if playerEntity then
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
                        print("[Magnus Quest] Pocketwatch added to", player.Name, "'s inventory")
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