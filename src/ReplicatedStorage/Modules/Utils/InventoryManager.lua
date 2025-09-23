local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local Runservice = game:GetService("RunService")
local isServer = Runservice:IsServer()

local InventoryManager = {}

local function markInventoryChanged(entity)
    if isServer then
        world:set(entity, comps.InventoryChanged, os.clock())
    end
end

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

-- Add item to inventory
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
                return true, i
            end
        end
    end
    
    -- Find empty slot
    local emptySlot = nil
    for i = 1, inventory.maxSlots do
        if not inventory.items[i] then
            emptySlot = i
            break
        end
    end
    
    if not emptySlot then
        warn("Inventory full, cannot add item:", itemName)
        return false, nil
    end
    
    -- Add new item
    inventory.items[emptySlot] = {
        name = itemName,
        typ = itemType,
        quantity = quantity,
        singleuse = singleuse,
        description = description,
        icon = icon,
        stackable = stackable,
        slot = emptySlot
    }
    
    world:set(entity, comps.Inventory, inventory)
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

return InventoryManager