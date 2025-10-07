local ReplicatedStorage = game:GetService("ReplicatedStorage")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local Bridges = require(ReplicatedStorage.Modules.Bridges)

local function deserializeInventory(inventoryData)
    local inventory = {
        items = {},
        maxSlots = inventoryData.maxSlots
    }
    
    for slot, item in pairs(inventoryData.items) do
        inventory.items[slot] = {
            name = item.name,
            typ = item.typ,
            quantity = item.quantity,
            singleuse = item.singleuse,
            description = item.description,
            icon = item.icon,
            stackable = item.stackable,
            slot = slot
        }
    end
    
    return inventory
end

-- Handle inventory updates from server
Bridges.Inventory:Connect(function(syncData)
    print("[InventoryHandler] Client: Received inventory update from server")
    print("[InventoryHandler] Client: SyncData:", syncData)

    -- Wait a bit to ensure ECS is fully initialized
    local maxAttempts = 10
    local attempt = 0
    local pent = nil

    while attempt < maxAttempts do
        pent = ref.get("local_player")  -- No second parameter needed for local_player
        if pent then
            print("[InventoryHandler] Client: Local player entity found:", pent, "(attempt", attempt + 1, ")")
            break
        end
        attempt = attempt + 1
        warn("[InventoryHandler] Client: No local player entity found, retrying... (attempt", attempt, "/", maxAttempts, ")")
        task.wait(0.1)
    end

    if not pent then
        warn("[InventoryHandler] Client: FAILED to get local player entity after", maxAttempts, "attempts!")
        warn("[InventoryHandler] Client: Inventory sync FAILED - player entity does not exist")
        return
    end

    print("[InventoryHandler] Client: Local player entity confirmed:", pent)

    -- Update inventory component
    local inventory = deserializeInventory(syncData.inventory)
    world:set(pent, comps.Inventory, inventory)
    print("[InventoryHandler] Client: Set Inventory component")

    -- Update hotbar component
    world:set(pent, comps.Hotbar, syncData.hotbar)
    print("[InventoryHandler] Client: Set Hotbar component")

    -- Count items
    local itemCount = 0
    for _ in pairs(syncData.inventory.items) do
        itemCount = itemCount + 1
    end

    print("[InventoryHandler] Client: Updated inventory with", itemCount, "items")
    print("[InventoryHandler] Client: Inventory items:")
    for slot, item in pairs(syncData.inventory.items) do
        print("  Slot", slot, ":", item.name, "(type:", item.typ, ")")
    end

    print("[InventoryHandler] Client: Updated hotbar slots:")
    for slot, invSlot in pairs(syncData.hotbar.slots) do
        print("  Hotbar", slot, "-> Inventory slot", invSlot)
    end

    -- Update UI with retry logic (UI might not be loaded yet)
    task.spawn(function()
        local Client = require(ReplicatedStorage.Client)
        local maxUIAttempts = 20 -- Wait up to 2 seconds for UI to load
        local uiAttempt = 0

        while uiAttempt < maxUIAttempts do
            -- Check if Interface module is loaded
            if Client.Modules and Client.Modules["Interface"] then
                local Interface = Client.Modules["Interface"]

                -- Check if Stats module exists
                if Interface.Modules and Interface.Modules["Stats"] then
                    local Stats = Interface.Modules["Stats"]

                    -- Check if LoadWeaponSkills function exists
                    if Stats.LoadWeaponSkills and typeof(Stats.LoadWeaponSkills) == "function" then
                        print("[InventoryHandler] Client: Updating hotbar UI (attempt", uiAttempt + 1, ")")
                        Stats.LoadWeaponSkills()
                        print("[InventoryHandler] Client: ✅ Successfully updated hotbar UI")
                        return -- Success!
                    end
                end
            end

            uiAttempt = uiAttempt + 1
            if uiAttempt < maxUIAttempts then
                task.wait(0.1)
            end
        end

        warn("[InventoryHandler] Client: ⚠️ Could not find Stats interface after", maxUIAttempts, "attempts")
        warn("[InventoryHandler] Client: Hotbar UI may not be updated - try manually updating")
    end)
end)

return {}