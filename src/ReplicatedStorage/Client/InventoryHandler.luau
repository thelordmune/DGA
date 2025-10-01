local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local Bridges = require(ReplicatedStorage.Modules.Bridges)

local player = Players.LocalPlayer

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

    local pent = ref.get("local_player", player)
    if not pent then
        warn("[InventoryHandler] Client: No local player entity found!")
        return
    end

    print("[InventoryHandler] Client: Local player entity found:", pent)

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

    -- Update UI
    local Client = require(ReplicatedStorage.Client)
    if Client.Interface and Client.Interface.Stats then
        print("[InventoryHandler] Client: Updating hotbar UI")
        Client.Interface.Stats.LoadWeaponSkills()
    else
        warn("[InventoryHandler] Client: Could not find Stats interface to update hotbar")
    end
end)

return {}