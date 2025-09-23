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
    print("Client: Received inventory update from server")
    
    local pent = ref.get("player", player)
    print("INVENTORY HANDLER DEBUG: Entity ID for", player.Name, ":", pent)

    if not pent then
        warn("INVENTORY: Player entity not found, retrying...")
        -- Retry a few times
        local attempts = 0
        while attempts < 10 and not pent do
            task.wait(0.2)
            pent = ref.get("player", player)
            attempts = attempts + 1
        end

        if not pent then
            warn("INVENTORY: Failed to get player entity after retries")
            return
        end
        print("INVENTORY: Found entity after retry:", pent)
    end

    if pent then
        -- Update inventory component
        local inventory = deserializeInventory(syncData.inventory)
        world:set(pent, comps.Inventory, inventory)
        
        -- Update hotbar component
        world:set(pent, comps.Hotbar, syncData.hotbar)
        
        print("Client: Updated inventory with", table.getn(syncData.inventory.items), "items")
        print("Client: Updated hotbar slots:")
        for slot, invSlot in pairs(syncData.hotbar.slots) do
            print("  Hotbar", slot, "-> Inventory slot", invSlot)
        end
        
        -- Update UI if needed
        local Client = require(ReplicatedStorage.Client)
        if Client.Interface and Client.Interface.UpdateHotbar then
            Client.Interface.UpdateHotbar()
        end
    else
        print("Client: No local player entity found!")
    end
end)

return {}