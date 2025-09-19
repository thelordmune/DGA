local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Bridges = require(ReplicatedStorage.Modules.Bridges)

local InventorySetup = {}

-- Example items database
local ItemDatabase = {
    ["Health Potion"] = {
        typ = "consumable",
        description = "Restores 50 HP",
        icon = "rbxassetid://123456789",
        singleuse = true,
        stackable = true
    },
    ["Stone Sword"] = {
        typ = "weapon",
        description = "A basic stone sword",
        icon = "rbxassetid://987654321",
        singleuse = false,
        stackable = false
    },
    ["Fireball"] = {
        typ = "skill",
        description = "Casts a fireball",
        icon = "rbxassetid://555666777",
        singleuse = false,
        stackable = false,
        requirements = {
            {type = "weapon", value = "Staff", description = "Requires a staff"}
        }
    }
}

-- Give starter items to a player
function InventorySetup.giveStarterItems(entity)
    InventoryManager.initializeInventory(entity, 50)
    
    -- Add some starter items
    InventoryManager.addItem(entity, "Health Potion", "consumable", 5, true, "Restores 50 HP")
    InventoryManager.addItem(entity, "Stone Sword", "weapon", 1, false, "A basic stone sword")
    
    -- Set up hotbar
    InventoryManager.setHotbarSlot(entity, 1, 1) -- Health potion in slot 1
    InventoryManager.setHotbarSlot(entity, 2, 2) -- Stone sword in slot 2
end

-- Get item data from database
function InventorySetup.getItemData(itemName)
    return ItemDatabase[itemName]
end

-- Add item with database lookup
function InventorySetup.addItemFromDatabase(entity, itemName, quantity)
    local itemData = ItemDatabase[itemName]
    if not itemData then
        warn("Item not found in database:", itemName)
        return false
    end
    
    return InventoryManager.addItem(
        entity,
        itemName,
        itemData.typ,
        quantity,
        itemData.singleuse,
        itemData.description,
        itemData.icon
    )
end

function InventorySetup.GiveWeaponSkills(entity, WeaponName: string, player)
    local WeaponDirectory = require(ServerStorage.Stats._Skills)
    local WeaponSkills = WeaponDirectory[WeaponName]

    if not WeaponSkills then
        warn("No skills found weapon:", WeaponName)
        return
    end

    -- Get player from entity if on server
    if RunService:IsServer() then
        local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
        local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
        if world:has(entity, comps.Player) then
            player = world:get(entity, comps.Player)
        end
    end

    for skillName, skillData in WeaponSkills do
        local success, slot = InventoryManager.addItem(
            entity,
            skillName,
            "skill",
            1,
            false,
            skillData.Description,
            "rbxassetid://123456789"
        )

        if success then
            print("added skill:", skillName, "to slot:", slot)

            local hotbarSlot = 1
            for existingSkill, _ in WeaponSkills do
                if existingSkill == skillName then
                    break
                end
                hotbarSlot += 1
            end

            if hotbarSlot <= 7 then
                InventoryManager.setHotbarSlot(entity, hotbarSlot, slot)
                print("set hotbar slot:", hotbarSlot, "to slot:", slot)
            end
        end
    end
    
    -- Fire inventory update to client if on server
    if RunService:IsServer() then
        local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
        local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
        
        local inventory = world:get(entity, comps.Inventory)
        local hotbar = world:get(entity, comps.Hotbar)
        
        -- Serialize inventory data
        local inventoryData = {
            items = {},
            maxSlots = inventory.maxSlots
        }
        
        for slot, item in pairs(inventory.items) do
            inventoryData.items[slot] = {
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
        
        local syncData = {
            inventory = inventoryData,
            hotbar = {
                slots = hotbar.slots,
                activeSlot = hotbar.activeSlot or 1
            }
        }
        
        print("Server: Firing inventory sync to", player.Name)
        Bridges.Inventory:Fire(player, syncData)
    end
end

return InventorySetup