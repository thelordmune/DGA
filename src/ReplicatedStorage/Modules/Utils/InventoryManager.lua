local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local Runservice = game:GetService("RunService")
local isServer = Runservice:IsServer()

local InventoryManager = {}

-- Sync inventory to client
local function syncInventoryToClient(entity)
    if not isServer then return end

    -- Get player from entity
    if not world:has(entity, comps.Player) then
        return
    end

    local player = world:get(entity, comps.Player)
    if not player or not player.Parent then
        return
    end

    -- Get inventory and hotbar (fresh read from world)
    if not world:has(entity, comps.Inventory) or not world:has(entity, comps.Hotbar) then
        return
    end

    -- Force a fresh read from the world to ensure we have the latest data
    local inventory = world:get(entity, comps.Inventory)
    local hotbar = world:get(entity, comps.Hotbar)

    -- Serialize inventory data
    -- IMPORTANT: Convert sparse table to array format for BridgeNet2
    -- BridgeNet2 doesn't handle sparse tables well (drops non-consecutive keys)
    local inventoryData = {
        items = {},
        maxSlots = inventory.maxSlots
    }

    -- Count items properly (can't use # with sparse tables)
    local itemCount = 0
    for _ in pairs(inventory.items) do
        itemCount = itemCount + 1
    end

    print("[InventoryManager] Syncing inventory - Total items:", itemCount)

    -- Convert to array format with slot numbers embedded in each item
    local itemArray = {}
    for slot, item in pairs(inventory.items) do
        print("[InventoryManager]   Slot", slot, ":", item.name, "(type:", item.typ .. ")")
        table.insert(itemArray, {
            name = item.name,
            typ = item.typ,
            quantity = item.quantity,
            singleuse = item.singleuse,
            description = item.description,
            icon = item.icon,
            stackable = item.stackable,
            slot = slot  -- Include slot number in the item data
        })
    end

    inventoryData.items = itemArray

    print("[InventoryManager] Serialized items array length:", #itemArray)
    for i, item in ipairs(itemArray) do
        print("[InventoryManager]   Array[" .. i .. "] slot", item.slot, ":", item.name)
    end

    local syncData = {
        inventory = inventoryData,
        hotbar = {
            slots = hotbar.slots,
            activeSlot = hotbar.activeSlot or 1
        }
    }

    -- Fire to client
    local Bridges = require(ReplicatedStorage.Modules.Bridges)
    print("[InventoryManager] Syncing inventory to", player.Name)
    Bridges.Inventory:Fire(player, syncData)
end

local function markInventoryChanged(entity)
    if isServer then
        world:set(entity, comps.InventoryChanged, os.clock())
        -- Immediately sync to client
        syncInventoryToClient(entity)
    end
end

-- Constants for slot ranges
local HOTBAR_SLOTS = {min = 1, max = 7}  -- Slots 1-7 are hotbar (for skills)
local INVENTORY_SLOTS = {min = 8, max = 50}  -- Slots 8-50 are inventory (for items)

function InventoryManager.initializeInventory(entity, maxSlots)
    maxSlots = maxSlots or 50

    if not world:has(entity, comps.Inventory) then
        world:set(entity, comps.Inventory, {
            items = {},
            maxSlots = maxSlots
        })
    end

    if not world:has(entity, comps.Hotbar) then
        world:set(entity, comps.Hotbar, {
            slots = {},
            activeSlot = 1
        })
    end
end

-- Find first available slot in a specific range
local function findEmptySlotInRange(inventory, minSlot, maxSlot)
    for i = minSlot, maxSlot do
        if not inventory.items[i] then
            return i
        end
    end
    return nil
end

-- Auto-assign hotbar slot for skills
local function autoAssignHotbarSlot(entity, inventorySlot)
    if not world:has(entity, comps.Hotbar) then
        return
    end

    local hotbar = world:get(entity, comps.Hotbar)

    -- Find first available hotbar slot (1-7)
    for hotbarSlot = 1, 7 do
        if not hotbar.slots[hotbarSlot] then
            hotbar.slots[hotbarSlot] = inventorySlot
            world:set(entity, comps.Hotbar, hotbar)
            print("[InventoryManager] Auto-assigned inventory slot", inventorySlot, "to hotbar slot", hotbarSlot)
            return hotbarSlot
        end
    end

    print("[InventoryManager] All hotbar slots full, skill added to inventory only")
    return nil
end

-- Add item to inventory with smart slot allocation
-- Skills go to slots 1-7 (hotbar), items go to slots 8-50 (inventory)
function InventoryManager.addItem(entity, itemName, itemType, quantity, singleuse, description, icon)
    if not world:has(entity, comps.Inventory) then
        InventoryManager.initializeInventory(entity)
    end

    local inventory = world:get(entity, comps.Inventory)
    quantity = quantity or 1
    singleuse = singleuse or false

    -- Check if item is stackable and already exists
    local stackable = not singleuse
    if stackable then
        for i, item in pairs(inventory.items) do
            if item.name == itemName and item.typ == itemType then
                item.quantity = item.quantity + quantity
                world:set(entity, comps.Inventory, inventory)
                markInventoryChanged(entity)
                return true, i
            end
        end
    end

    -- Determine slot range based on item type
    local emptySlot = nil
    if itemType == "skill" then
        -- Skills go to hotbar slots (1-7)
        emptySlot = findEmptySlotInRange(inventory, HOTBAR_SLOTS.min, HOTBAR_SLOTS.max)

        if not emptySlot then
            -- Hotbar full, try inventory slots as fallback
            print("[InventoryManager] Hotbar full, placing skill in inventory slots")
            emptySlot = findEmptySlotInRange(inventory, INVENTORY_SLOTS.min, INVENTORY_SLOTS.max)
        end
    else
        -- Items (consumables, weapons, etc.) go to inventory slots (8-50)
        emptySlot = findEmptySlotInRange(inventory, INVENTORY_SLOTS.min, INVENTORY_SLOTS.max)

        if not emptySlot then
            -- Inventory full, try hotbar slots as fallback
            print("[InventoryManager] Inventory full, placing item in hotbar slots")
            emptySlot = findEmptySlotInRange(inventory, HOTBAR_SLOTS.min, HOTBAR_SLOTS.max)
        end
    end

    if not emptySlot then
        warn("[InventoryManager] Inventory completely full, cannot add item:", itemName)
        return false, nil
    end

    -- Add new item (create completely new inventory table to ensure jecs detects the change)
    local newItems = {}
    for slot, item in pairs(inventory.items) do
        newItems[slot] = item
    end

    newItems[emptySlot] = {
        name = itemName,
        typ = itemType,
        quantity = quantity,
        singleuse = singleuse,
        description = description,
        icon = icon,
        stackable = stackable,
        slot = emptySlot
    }

    -- Create a completely new inventory table
    local newInventory = {
        items = newItems,
        maxSlots = inventory.maxSlots
    }

    world:set(entity, comps.Inventory, newInventory)

    -- Auto-assign to hotbar if it's a skill in hotbar range
    if itemType == "skill" and emptySlot >= HOTBAR_SLOTS.min and emptySlot <= HOTBAR_SLOTS.max then
        autoAssignHotbarSlot(entity, emptySlot)
    end

    print("[InventoryManager] Added", itemName, "to slot", emptySlot, "(type:", itemType .. ")")

    -- Debug: Verify item was actually added
    local verifyInventory = world:get(entity, comps.Inventory)
    if verifyInventory.items[emptySlot] then
        print("[InventoryManager] ✅ Verified item in slot", emptySlot, ":", verifyInventory.items[emptySlot].name)
    else
        warn("[InventoryManager] ❌ Item NOT found in slot", emptySlot, "after adding!")
    end

    markInventoryChanged(entity)
    return true, emptySlot
end

-- Remove item from inventory
function InventoryManager.removeItem(entity, itemName, quantity)
    if not world:has(entity, comps.Inventory) then
        return false
    end
    
    local inventory = world:get(entity, comps.Inventory)
    quantity = quantity or 1
    
    for i, item in pairs(inventory.items) do
        if item.name == itemName then
            if item.quantity <= quantity then
                inventory.items[i] = nil
                world:set(entity, comps.Inventory, inventory)
                markInventoryChanged(entity)
                return true, item.quantity
            else
                item.quantity = item.quantity - quantity
                world:set(entity, comps.Inventory, inventory)
                markInventoryChanged(entity)
                return true, quantity
            end
        end
    end
    
    return false, 0
end

-- Check if entity has item
function InventoryManager.hasItem(entity, itemName, quantity)
    if not world:has(entity, comps.Inventory) then
        return false
    end
    
    local inventory = world:get(entity, comps.Inventory)
    quantity = quantity or 1
    
    for _, item in pairs(inventory.items) do
        if item.name == itemName and item.quantity >= quantity then
            return true
        end
    end
    
    return false
end

-- Get item count
function InventoryManager.getItemCount(entity, itemName)
    if not world:has(entity, comps.Inventory) then
        return 0
    end
    
    local inventory = world:get(entity, comps.Inventory)
    local totalCount = 0
    
    for _, item in pairs(inventory.items) do
        if item.name == itemName then
            totalCount = totalCount + item.quantity
        end
    end
    
    return totalCount
end

-- Move item to different slot
function InventoryManager.moveItem(entity, fromSlot, toSlot)
    if not world:has(entity, comps.Inventory) then
        return false
    end
    
    local inventory = world:get(entity, comps.Inventory)
    
    if not inventory.items[fromSlot] then
        return false
    end
    
    -- Swap items
    local temp = inventory.items[toSlot]
    inventory.items[toSlot] = inventory.items[fromSlot]
    inventory.items[fromSlot] = temp
    
    -- Update slot references
    if inventory.items[toSlot] then
        inventory.items[toSlot].slot = toSlot
    end
    if inventory.items[fromSlot] then
        inventory.items[fromSlot].slot = fromSlot
    end
    
    world:set(entity, comps.Inventory, inventory)
    return true
end

-- Check requirements
function InventoryManager.checkRequirements(entity, requirements)
    if not requirements then
        return true
    end
    
    for _, requirement in pairs(requirements) do
        if requirement.type == "item" then
            if not InventoryManager.hasItem(entity, requirement.value.name, requirement.value.quantity) then
                return false, "Missing required item: " .. requirement.value.name
            end
        elseif requirement.type == "weapon" then
            -- Check if player has weapon equipped
            local character = world:get(entity, comps.Character)
            if character and character:GetAttribute("Weapon") ~= requirement.value then
                return false, "Requires weapon: " .. requirement.value
            end
        elseif requirement.type == "quest" then
            if not world:has(entity, comps.CompletedQuest) then
                return false, "Quest not completed: " .. requirement.value
            end
        end
    end
    
    return true
end

-- Use item (consume if singleuse)
function InventoryManager.useItem(entity, itemName)
    if not world:has(entity, comps.Inventory) then
        return false
    end
    
    local inventory = world:get(entity, comps.Inventory)
    
    for i, item in pairs(inventory.items) do
        if item.name == itemName then
            if item.singleuse then
                if item.quantity <= 1 then
                    inventory.items[i] = nil
                else
                    item.quantity = item.quantity - 1
                end
                world:set(entity, comps.Inventory, inventory)
            end
            return true, item
        end
    end
    
    return false
end

-- Hotbar functions
function InventoryManager.setHotbarSlot(entity, hotbarSlot, inventorySlot)
    if not world:has(entity, comps.Hotbar) then
        InventoryManager.initializeInventory(entity)
    end
    
    local hotbar = world:get(entity, comps.Hotbar)
    hotbar.slots[hotbarSlot] = inventorySlot
    world:set(entity, comps.Hotbar, hotbar)
    markInventoryChanged(entity)
end

function InventoryManager.getHotbarItem(entity, hotbarSlot)
    if not world:has(entity, comps.Hotbar) or not world:has(entity, comps.Inventory) then
        return nil
    end
    
    local hotbar = world:get(entity, comps.Hotbar)
    local inventory = world:get(entity, comps.Inventory)
    
    local inventorySlot = hotbar.slots[hotbarSlot]
    if inventorySlot and inventory.items[inventorySlot] then
        return inventory.items[inventorySlot]
    end
    
    return nil
end

function InventoryManager.useHotbarSlot(entity, hotbarSlot)
    local item = InventoryManager.getHotbarItem(entity, hotbarSlot)
    if item then
        return InventoryManager.useItem(entity, item.name)
    end
    return false
end

-- Clear all hotbar slots (for character reset)
function InventoryManager.clearHotbar(entity)
    if not world:has(entity, comps.Hotbar) then
        return
    end

    local hotbar = world:get(entity, comps.Hotbar)
    hotbar.slots = {}
    hotbar.activeSlot = 1
    world:set(entity, comps.Hotbar, hotbar)
    markInventoryChanged(entity)
    print("Cleared hotbar for entity")
end

-- Clear entire inventory (for character reset)
function InventoryManager.clearInventory(entity)
    if not world:has(entity, comps.Inventory) then
        return
    end

    local inventory = world:get(entity, comps.Inventory)
    inventory.items = {}
    world:set(entity, comps.Inventory, inventory)
    markInventoryChanged(entity)
    print("Cleared inventory for entity")
end

-- Comprehensive cleanup for character reset
function InventoryManager.resetPlayerInventory(entity)
    InventoryManager.clearInventory(entity)
    InventoryManager.clearHotbar(entity)
    print("Reset player inventory and hotbar")
end

-- Get available slot counts
function InventoryManager.getAvailableSlots(entity)
    if not world:has(entity, comps.Inventory) then
        return {
            hotbarSlots = 0,
            inventorySlots = 0,
            totalSlots = 0
        }
    end

    local inventory = world:get(entity, comps.Inventory)

    local hotbarAvailable = 0
    local inventoryAvailable = 0

    -- Count available hotbar slots (1-7)
    for i = HOTBAR_SLOTS.min, HOTBAR_SLOTS.max do
        if not inventory.items[i] then
            hotbarAvailable = hotbarAvailable + 1
        end
    end

    -- Count available inventory slots (8-50)
    for i = INVENTORY_SLOTS.min, INVENTORY_SLOTS.max do
        if not inventory.items[i] then
            inventoryAvailable = inventoryAvailable + 1
        end
    end

    return {
        hotbarSlots = hotbarAvailable,
        inventorySlots = inventoryAvailable,
        totalSlots = hotbarAvailable + inventoryAvailable
    }
end

-- Check if there's space for a specific item type
function InventoryManager.hasSpaceFor(entity, itemType)
    local available = InventoryManager.getAvailableSlots(entity)

    if itemType == "skill" then
        -- Skills prefer hotbar, but can use inventory as fallback
        return available.hotbarSlots > 0 or available.inventorySlots > 0
    else
        -- Items prefer inventory, but can use hotbar as fallback
        return available.inventorySlots > 0 or available.hotbarSlots > 0
    end
end

return InventoryManager