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
        stackable = true,
        rarity = "common"
    },
    ["Stone Sword"] = {
        typ = "weapon",
        description = "A basic stone sword",
        icon = "rbxassetid://987654321",
        singleuse = false,
        stackable = false,
        rarity = "common"
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
    },
    -- Fullmetal Alchemist themed items
    ["Philosopher's Stone"] = {
        typ = "consumable",
        description = "A legendary stone containing immense alchemical power. Can transmute anything.",
        icon = "rbxassetid://125715866811318",
        singleuse = false,
        stackable = false,
        rarity = "priceless" -- Rainbow animated
    },
    ["Red Stone"] = {
        typ = "consumable",
        description = "An incomplete Philosopher's Stone. Amplifies alchemical abilities temporarily.",
        icon = "rbxassetid://125715866811318",
        singleuse = true,
        stackable = true,
        rarity = "rare" -- Blue
    },
    ["Automail Arm"] = {
        typ = "equipment",
        description = "Advanced prosthetic limb made of steel. Increases physical strength.",
        icon = "rbxassetid://125715866811318",
        singleuse = false,
        stackable = false,
        rarity = "unique" -- Purple
    },
    ["Transmutation Circle"] = {
        typ = "consumable",
        description = "A pre-drawn circle for quick alchemy. Single use.",
        icon = "rbxassetid://125715866811318",
        singleuse = true,
        stackable = true,
        rarity = "common" -- Grey
    },
    ["State Alchemist Pocket Watch"] = {
        typ = "equipment",
        description = "Silver pocket watch bearing the State Alchemist symbol. 'Don't forget 3.Oct.11'",
        icon = "rbxassetid://125715866811318",
        singleuse = false,
        stackable = false,
        rarity = "legendary" -- Gold
    },
    ["Alkahestry Scroll"] = {
        typ = "consumable",
        description = "Ancient Xingese medical alchemy scroll. Heals wounds and purifies.",
        icon = "rbxassetid://125715866811318",
        singleuse = true,
        stackable = true,
        rarity = "rare" -- Blue
    },
    ["Homunculus Core"] = {
        typ = "material",
        description = "The core essence of a Homunculus. Radiates dark energy.",
        icon = "rbxassetid://125715866811318",
        singleuse = false,
        stackable = true,
        rarity = "forbidden" -- Red
    },
    ["Flame Alchemy Gloves"] = {
        typ = "equipment",
        description = "Ignition cloth gloves with transmutation circles. Creates flames with a snap.",
        icon = "rbxassetid://125715866811318",
        singleuse = false,
        stackable = false,
        rarity = "unique" -- Purple
    },
    ["Xerxes Tablet"] = {
        typ = "material",
        description = "Ancient stone tablet from the ruins of Xerxes. Contains forbidden knowledge.",
        icon = "rbxassetid://125715866811318",
        singleuse = false,
        stackable = false,
        rarity = "forbidden" -- Red
    },
    ["Amestrian Military Uniform"] = {
        typ = "equipment",
        description = "Standard issue blue military uniform of Amestris.",
        icon = "rbxassetid://125715866811318",
        singleuse = false,
        stackable = false,
        rarity = "common" -- Grey
    },
    ["Chimera Serum"] = {
        typ = "consumable",
        description = "Dangerous alchemical serum used in chimera creation. Handle with care.",
        icon = "rbxassetid://125715866811318",
        singleuse = true,
        stackable = true,
        rarity = "forbidden" -- Red
    },
    ["Truth's Door Key"] = {
        typ = "material",
        description = "A mysterious key fragment from beyond the Gate of Truth.",
        icon = "rbxassetid://125715866811318",
        singleuse = false,
        stackable = true,
        rarity = "legendary" -- Gold
    }
}

-- Give starter items to a player
function InventorySetup.giveStarterItems(entity)
    InventoryManager.initializeInventory(entity, 50)

    -- Add some starter items
    InventoryManager.addItem(entity, "Health Potion", "consumable", 5, true, "Restores 50 HP")
    InventoryManager.addItem(entity, "Stone Sword", "weapon", 1, false, "A basic stone sword")

    -- Add Fullmetal Alchemist themed items to inventory (slots 8+)
    InventorySetup.addItemFromDatabase(entity, "Philosopher's Stone", 1)
    InventorySetup.addItemFromDatabase(entity, "Red Stone", 3)
    InventorySetup.addItemFromDatabase(entity, "Automail Arm", 1)
    InventorySetup.addItemFromDatabase(entity, "Transmutation Circle", 5)
    InventorySetup.addItemFromDatabase(entity, "State Alchemist Pocket Watch", 1)
    InventorySetup.addItemFromDatabase(entity, "Alkahestry Scroll", 2)
    InventorySetup.addItemFromDatabase(entity, "Homunculus Core", 3)
    InventorySetup.addItemFromDatabase(entity, "Flame Alchemy Gloves", 1)
    InventorySetup.addItemFromDatabase(entity, "Xerxes Tablet", 1)
    InventorySetup.addItemFromDatabase(entity, "Amestrian Military Uniform", 1)
    InventorySetup.addItemFromDatabase(entity, "Chimera Serum", 2)
    InventorySetup.addItemFromDatabase(entity, "Truth's Door Key", 4)

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
        itemData.icon,
        itemData.rarity
    )
end

function InventorySetup.GiveWeaponSkills(entity, WeaponName: string, player)
    ---- print("========================================")
    ---- print("[GiveWeaponSkills] CALLED - Weapon:", WeaponName, "Entity:", entity, "Player:", player and player.Name or "nil")
    ---- print("========================================")

    local WeaponDirectory = require(ServerStorage.Stats._Skills)
    local WeaponSkills = WeaponDirectory[WeaponName]

    if not WeaponSkills then
        warn("[GiveWeaponSkills] No skills found for weapon:", WeaponName)
        return
    end

    ---- print("[GiveWeaponSkills] Found", #WeaponSkills, "skills for weapon:", WeaponName)

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

        -- Clear existing SKILLS (slots 1-7) before giving new skills
        -- DO NOT clear inventory items (slots 8-50)
        ---- print("[GiveWeaponSkills] Clearing skill slots (1-7) for weapon change")
        local inventory = world:get(entity, comps.Inventory)
        local newItems = {}

        -- Keep all items in slots 8-50 (inventory items)
        for slot, item in pairs(inventory.items) do
            if slot >= 8 then
                newItems[slot] = item
            end
        end

        inventory.items = newItems
        world:set(entity, comps.Inventory, inventory)

        -- Clear hotbar
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
            ---- print("[GiveWeaponSkills] ✅ Added skill:", skillName, "to slot:", inventorySlot)
            skillsAdded = skillsAdded + 1
        else
            warn("[GiveWeaponSkills] ❌ Failed to add skill:", skillName)
        end
    end

    ---- print("[GiveWeaponSkills] Successfully added", skillsAdded, "skills for weapon:", WeaponName)

    -- Verify the inventory was actually updated
    if RunService:IsServer() then
        local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
        local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

        if world:has(entity, comps.Inventory) and world:has(entity, comps.Hotbar) then
            local inventory = world:get(entity, comps.Inventory)
            local hotbar = world:get(entity, comps.Hotbar)

            ---- print("[GiveWeaponSkills] VERIFICATION - Inventory items:")
            for slot, item in pairs(inventory.items) do
                ---- print("  Slot", slot, ":", item.name, "(type:", item.typ, ")")
            end

            ---- print("[GiveWeaponSkills] VERIFICATION - Hotbar slots:")
            for slot, invSlot in pairs(hotbar.slots) do
                ---- print("  Hotbar", slot, "-> Inventory slot", invSlot)
            end
        else
            warn("[GiveWeaponSkills] VERIFICATION FAILED - Missing components!")
        end
    end

    -- Update client hotbar display if this is for a player
    if player and RunService:IsServer() then
        Bridges.UpdateHotbar:Fire(player, {})
    end

    -- NOTE: No need to manually sync inventory here!
    -- InventoryManager.addItem already calls markInventoryChanged which syncs to client
    -- Duplicate syncs can cause race conditions and overwrite inventory data
end

return InventorySetup