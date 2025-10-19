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
    -- print("========================================")
    -- print("[GiveWeaponSkills] CALLED - Weapon:", WeaponName, "Entity:", entity, "Player:", player and player.Name or "nil")
    -- print("========================================")

    local WeaponDirectory = require(ServerStorage.Stats._Skills)
    local WeaponSkills = WeaponDirectory[WeaponName]

    if not WeaponSkills then
        warn("[GiveWeaponSkills] No skills found for weapon:", WeaponName)
        return
    end

    -- print("[GiveWeaponSkills] Found", #WeaponSkills, "skills for weapon:", WeaponName)

    -- Get player from entity if on server
    if RunService:IsServer() then
        local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
        local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

        -- Verify entity exists in world
        if not world:contains(entity) then
            warn("[GiveWeaponSkills] Entity does not exist in world! Cannot give skills.")
            return
        end

        if world:has(entity, comps.Player) then
            player = world:get(entity, comps.Player)
        end

        -- Verify entity has Inventory and Hotbar components
        if not world:has(entity, comps.Inventory) then
            warn("[GiveWeaponSkills] Entity missing Inventory component! Initializing...")
            InventoryManager.initializeInventory(entity, 50)
            -- Wait a frame for initialization to complete
            task.wait()
        end
        if not world:has(entity, comps.Hotbar) then
            warn("[GiveWeaponSkills] Entity missing Hotbar component! Initializing...")
            InventoryManager.initializeInventory(entity, 50)
            -- Wait a frame for initialization to complete
            task.wait()
        end

        -- Double-check components exist after initialization
        if not world:has(entity, comps.Inventory) or not world:has(entity, comps.Hotbar) then
            warn("[GiveWeaponSkills] Failed to initialize components! Aborting.")
            return
        end

        -- Clear existing inventory and hotbar before giving new skills
        -- print("[GiveWeaponSkills] Clearing inventory and hotbar for weapon change")
        InventoryManager.clearInventory(entity)
        InventoryManager.clearHotbar(entity)
    end

    -- Track skills added
    local skillsAdded = 0

    for skillName, skillData in WeaponSkills do
        -- addItem now automatically handles slot allocation and hotbar assignment
        -- Skills go to slots 1-7 (hotbar), with automatic hotbar assignment
        local success, inventorySlot = InventoryManager.addItem(
            entity,
            skillName,
            "skill",
            1,
            false,
            skillData.Description,
            "rbxassetid://123456789"
        )

        if success and inventorySlot then
            -- print("[GiveWeaponSkills] ✅ Added skill:", skillName, "to slot:", inventorySlot)
            skillsAdded = skillsAdded + 1
        else
            warn("[GiveWeaponSkills] ❌ Failed to add skill:", skillName)
        end
    end

    -- print("[GiveWeaponSkills] Successfully added", skillsAdded, "skills for weapon:", WeaponName)

    -- Verify the inventory was actually updated
    if RunService:IsServer() then
        local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
        local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

        if world:has(entity, comps.Inventory) and world:has(entity, comps.Hotbar) then
            local inventory = world:get(entity, comps.Inventory)
            local hotbar = world:get(entity, comps.Hotbar)

            -- print("[GiveWeaponSkills] VERIFICATION - Inventory items:")
            for slot, item in pairs(inventory.items) do
                -- print("  Slot", slot, ":", item.name, "(type:", item.typ, ")")
            end

            -- print("[GiveWeaponSkills] VERIFICATION - Hotbar slots:")
            for slot, invSlot in pairs(hotbar.slots) do
                -- print("  Hotbar", slot, "-> Inventory slot", invSlot)
            end
        else
            warn("[GiveWeaponSkills] VERIFICATION FAILED - Missing components!")
        end
    end

    -- Update client hotbar display if this is for a player
    if player and RunService:IsServer() then
        Bridges.UpdateHotbar:Fire(player, {})
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
        
        -- print("Server: Firing inventory sync to", player.Name)
        Bridges.Inventory:Fire(player, syncData)
    end
end

return InventorySetup