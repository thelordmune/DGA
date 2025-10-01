local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)

local self = setmetatable({}, NetworkModule)

NetworkModule.EndPoint = function(Player, Data)
    local Weapon = Player:GetAttribute("Weapon")

    print("=== USE ITEM ENDPOINT ===")
    print("Player:", Player.Name)
    print("Item:", Data.itemName)
    print("Hotbar Slot:", Data.hotbarSlot)

    local pent = ref.get("player", Player)  -- Fixed: Use "player" on server, not "local_player"
    if not pent then
        warn("[UseItem] Player entity not found for:", Player.Name)
        return
    end

    print("[UseItem] Player entity:", pent)

    -- Debug: Print hotbar state
    if world:has(pent, comps.Hotbar) then
        local hotbar = world:get(pent, comps.Hotbar)
        print("Hotbar slots:", hotbar.slots)
        print("Looking for item in hotbar slot:", Data.hotbarSlot)
        print("Inventory slot mapped to hotbar slot:", hotbar.slots[Data.hotbarSlot])
    else
        warn("Player has no Hotbar component!")
    end

    -- Debug: Print inventory state
    if world:has(pent, comps.Inventory) then
        local inventory = world:get(pent, comps.Inventory)
        print("Inventory items count:", #inventory.items)
        for slot, item in pairs(inventory.items) do
            print("  Slot", slot, ":", item.name, "(type:", item.typ, ")")
        end
    else
        warn("Player has no Inventory component!")
    end

    -- Verify item is still in hotbar slot
    local item = InventoryManager.getHotbarItem(pent, Data.hotbarSlot)
    if not item then
        warn("No item found in hotbar slot", Data.hotbarSlot)
        return
    end

    if item.name ~= Data.itemName then
        warn("Item mismatch! Expected:", Data.itemName, "Found:", item.name)
        return
    end
    
    -- Use the item
    local success, usedItem = InventoryManager.useItem(pent, Data.itemName)
    if success then
        print("Successfully used item:", Data.itemName)
        
        -- Handle different item types
        if usedItem.typ == "consumable" then
            -- Handle consumable logic (healing, buffs, etc.)
            print("Used consumable:", usedItem.name)
        elseif usedItem.typ == "weapon" then
            -- Switch weapon
            Player:SetAttribute("Weapon", usedItem.name)
            print("Switched to weapon:", usedItem.name)
        elseif usedItem.typ == "skill" then
            -- Activate skill
            print("Activated skill:", usedItem.name, "for weapon:", Weapon)
            local skillPath = script.Parent.Parent.WeaponSkills[Weapon]
            if skillPath and skillPath:FindFirstChild(usedItem.name) then
                local skill = require(skillPath[usedItem.name])
                skill(Player, Data, Server)
            else
                warn("Skill not found:", usedItem.name, "for weapon:", Weapon)
            end
        end
    else
        warn("Failed to use item:", Data.itemName)
    end
end

return NetworkModule