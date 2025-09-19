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
    
    local pent = ref.get("local_player", Player)
    if not pent then
        warn("Player entity not found")
        return
    end
    
    -- Verify item is still in hotbar slot
    local item = InventoryManager.getHotbarItem(pent, Data.hotbarSlot)
    if not item or item.name ~= Data.itemName then
        warn("Item mismatch or not found in hotbar slot")
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
            print("Activated skill:", usedItem.name)
            local skill = require(script.Parent.Parent.WeaponSkills[Weapon][usedItem.name])
            skill(Player, Data, Server)
        end
    else
        warn("Failed to use item:", Data.itemName)
    end
end

return NetworkModule