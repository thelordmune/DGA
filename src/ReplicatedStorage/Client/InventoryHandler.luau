local ReplicatedStorage = game:GetService("ReplicatedStorage")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local NotificationManager = require(ReplicatedStorage.Client.NotificationManager)
local Players = game:GetService("Players")

-- Deserialize inventory data
-- Server sends items as an array (not sparse table) to avoid BridgeNet2 issues
local function deserializeInventory(inventoryData)
    local inventory = {
        items = {},
        maxSlots = inventoryData.maxSlots
    }

    -- Convert array format back to slot-indexed table
    for _, item in ipairs(inventoryData.items) do
        local slot = item.slot
        inventory.items[slot] = {
            name = item.name,
            typ = item.typ,
            quantity = item.quantity,
            singleuse = item.singleuse,
            description = item.description,
            icon = item.icon,
            stackable = item.stackable,
            slot = slot,
            rarity = item.rarity or "common" -- Preserve rarity
        }
    end

    return inventory
end

-- Track previous inventory state to detect new items
local previousInventory = {}
local isFirstSync = true

-- Cleanup function to reset state on death/respawn (called from PlayerHandler)
local function resetInventoryState()
	previousInventory = {}
	isFirstSync = true
	-- print("[InventoryHandler] 🧹 Reset inventory state for new character")
end

-- Handle inventory updates from server
Bridges.Inventory:Connect(function(syncData)
    print("[InventoryHandler] 📦 RECEIVED inventory sync from server!")
    print("[InventoryHandler] Items count:", syncData and syncData.inventory and #syncData.inventory.items or "nil")

    -- Wait for the entity to be properly synced from server (not a client-created fallback)
    -- This ensures we set inventory on the correct entity
    local maxAttempts = 50  -- Increased to 5 seconds max wait
    local attempt = 0
    local pent = nil
    local localPlayer = Players.LocalPlayer

    while attempt < maxAttempts do
        -- Check if we have a server-synced entity (via network_id or player ref)
        -- Don't use ref.get("local_player") as it creates a fallback entity
        -- First try to get from player refs (set by SetPlayerEntity sync)
        pent = ref.get("player", localPlayer)

        if pent and world:contains(pent) then
            print("[InventoryHandler] Client: Server-synced entity found:", pent, "(attempt", attempt + 1, ")")
            break
        end

        attempt = attempt + 1
        if attempt % 10 == 0 then
            warn("[InventoryHandler] Client: Waiting for server-synced entity... (attempt", attempt, "/", maxAttempts, ")")
        end
        task.wait(0.1)
    end

    if not pent then
        warn("[InventoryHandler] Client: FAILED to get server-synced entity after", maxAttempts, "attempts!")
        warn("[InventoryHandler] Client: Inventory sync FAILED - player entity does not exist")
        return
    end

    ---- print("[InventoryHandler] Client: Local player entity confirmed:", pent)

    -- Detect new items by comparing with previous inventory
    local newItems = {}

    -- Skip notifications on first sync (initial inventory load)
    if not isFirstSync then
        -- Items come as array, need to use ipairs and get slot from item.slot
        for _, item in ipairs(syncData.inventory.items) do
            local slot = item.slot  -- Get actual slot number from item data
            local previousItem = previousInventory[slot]

            -- Check if this is a new item or increased quantity
            if not previousItem then
                -- Brand new item in this slot
                ---- print("[InventoryHandler] New item in slot", slot, ":", item.name)
                table.insert(newItems, {
                    name = item.name,
                    typ = item.typ,
                    quantity = item.quantity
                })
            elseif previousItem.name ~= item.name then
                -- Different item in same slot (item replaced)
                ---- print("[InventoryHandler] Item replaced in slot", slot, ":", previousItem.name, "->", item.name)
                table.insert(newItems, {
                    name = item.name,
                    typ = item.typ,
                    quantity = item.quantity
                })
            elseif previousItem.name == item.name and item.quantity > previousItem.quantity then
                -- Same item, increased quantity
                ---- print("[InventoryHandler] Item quantity increased in slot", slot, ":", item.name, previousItem.quantity, "->", item.quantity)
                table.insert(newItems, {
                    name = item.name,
                    typ = item.typ,
                    quantity = item.quantity - previousItem.quantity
                })
            end
        end
    else
        -- BUGFIX: First sync - skip notifications but ALSO populate previousInventory
        -- This prevents the second sync (backup sync) from triggering notifications
        ---- print("[InventoryHandler] First sync - skipping notifications for initial inventory")
        isFirstSync = false

        -- Populate previousInventory so second sync doesn't treat items as new
        for _, item in ipairs(syncData.inventory.items) do
            local slot = item.slot
            previousInventory[slot] = {
                name = item.name,
                typ = item.typ,
                quantity = item.quantity
            }
        end
    end

    -- Update inventory component
    local inventory = deserializeInventory(syncData.inventory)
    print("[InventoryHandler] Setting inventory on entity:", pent)
    print("[InventoryHandler] Inventory items count:", #syncData.inventory.items)
    for _, item in ipairs(syncData.inventory.items) do
        print("  Slot", item.slot, ":", item.name, "(type:", item.typ, ")")
    end

    -- CRITICAL: Check if entity exists in client world before setting components
    -- Server entity IDs don't automatically exist in client's jecs world
    local entityExists = world:contains(pent)
    print("[InventoryHandler] Entity", pent, "exists in client world:", entityExists)

    if not entityExists then
        -- Entity doesn't exist - we need to create it or use a different approach
        warn("[InventoryHandler] ⚠️ Entity", pent, "does not exist in client world! Creating it...")
        -- The entity ID from server needs to exist in client world
        -- This might happen if jecs_world isn't properly syncing entity IDs
    end

    world:set(pent, comps.Inventory, inventory)
    print("[InventoryHandler] ✅ Set Inventory component on entity:", pent)

    -- Verify it was actually set
    local hasInv = world:has(pent, comps.Inventory)
    print("[InventoryHandler] Verification - entity has Inventory:", hasInv)

    -- Update hotbar component
    print("[InventoryHandler] Setting hotbar on entity:", pent)
    print("[InventoryHandler] Hotbar slots:", syncData.hotbar.slots)
    world:set(pent, comps.Hotbar, syncData.hotbar)
    print("[InventoryHandler] ✅ Set Hotbar component on entity:", pent)

    -- Verify it was actually set
    local hasHotbar = world:has(pent, comps.Hotbar)
    print("[InventoryHandler] Verification - entity has Hotbar:", hasHotbar)

    -- Show notifications for new items
    ---- print("[InventoryHandler] Total new items to notify:", #newItems)
    for _, item in ipairs(newItems) do
        ---- print("[InventoryHandler] Showing notification for:", item.name, "Type:", item.typ)

        if item.typ == "skill" then
            NotificationManager.ShowSkill(item.name)
        else
            NotificationManager.ShowItem(item.name)
        end
    end

    -- Update previous inventory state
    previousInventory = {}
    for _, item in ipairs(syncData.inventory.items) do
        local slot = item.slot  -- Get actual slot number from item data
        previousInventory[slot] = {
            name = item.name,
            typ = item.typ,
            quantity = item.quantity
        }
    end

    -- Count items
    local itemCount = 0
    for _ in pairs(syncData.inventory.items) do
        itemCount = itemCount + 1
    end

    ---- print("[InventoryHandler] Client: Updated inventory with", itemCount, "items")
    ---- print("[InventoryHandler] Client: Inventory items:")
    for slot, item in pairs(syncData.inventory.items) do
        ---- print("  Slot", slot, ":", item.name, "(type:", item.typ, ")")
    end

    ---- print("[InventoryHandler] Client: Updated hotbar slots:")
    for slot, invSlot in pairs(syncData.hotbar.slots) do
        ---- print("  Hotbar", slot, "-> Inventory slot", invSlot)
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
                        ---- print("[InventoryHandler] Client: Updating hotbar UI (attempt", uiAttempt + 1, ")")
                        Stats.LoadWeaponSkills()
                        ---- print("[InventoryHandler] Client: ✅ Successfully updated hotbar UI")
                        return -- Success!
                    end
                end
            end

            uiAttempt = uiAttempt + 1
            if uiAttempt < maxUIAttempts then
                task.wait(0.1)
            end
        end

    end)
end)

return {
	resetInventoryState = resetInventoryState,
}