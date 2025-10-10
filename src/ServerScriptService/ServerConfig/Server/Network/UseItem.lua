local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)

local self = setmetatable({}, NetworkModule)

-- Track held weapon skills per player
-- Format: {[Player] = {skillName, skillInstance, character}}
local heldWeaponSkills = {}

NetworkModule.EndPoint = function(Player, Data)
    local Weapon = Player:GetAttribute("Weapon")

    print("=== USE ITEM ENDPOINT ===")
    print("Player:", Player.Name)
    print("Item:", Data.itemName)
    print("Hotbar Slot:", Data.hotbarSlot)
    print("InputType:", Data.inputType or "nil")

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
            print("Activated skill:", usedItem.name, "for weapon:", Weapon, "InputType:", Data.inputType or "began")
            local skillPath = script.Parent.Parent.WeaponSkills[Weapon]
            if skillPath and skillPath:FindFirstChild(usedItem.name) then
                local skillModule = skillPath[usedItem.name]
                local skill = require(skillModule)

                print("[UseItem] Skill type:", type(skill))

                -- Check if skill is a WeaponSkillHold instance (has OnInputBegan method)
                if type(skill) == "table" and type(skill.OnInputBegan) == "function" then
                    print("[UseItem] Has OnInputBegan: true")
                    print("[UseItem] Skill metatable:", getmetatable(skill))
                    -- NEW HOLD SYSTEM
                    print("[UseItem] Using NEW HOLD SYSTEM for:", usedItem.name)
                    if Data.inputType == "began" then
                        -- Store skill for InputEnded
                        heldWeaponSkills[Player] = {
                            skillName = usedItem.name,
                            skillInstance = skill,
                            character = Player.Character
                        }

                        -- Call OnInputBegan
                        print("[UseItem] Calling OnInputBegan for:", usedItem.name)
                        skill:OnInputBegan(Player, Player.Character)
                    elseif Data.inputType == "ended" then
                        -- Call OnInputEnded
                        print("[UseItem] Calling OnInputEnded for:", usedItem.name)
                        local heldData = heldWeaponSkills[Player]
                        if heldData and heldData.skillName == usedItem.name then
                            skill:OnInputEnded(Player)
                            heldWeaponSkills[Player] = nil
                        else
                            print("[UseItem] No held skill data found for:", usedItem.name)
                        end
                    end
                else
                    -- OLD SYSTEM (function-based skills)
                    print("[UseItem] Using OLD SYSTEM (function-based) for:", usedItem.name)
                    skill(Player, Data, Server)
                end
            else
                warn("Skill not found:", usedItem.name, "for weapon:", Weapon)
            end
        end
    else
        warn("Failed to use item:", Data.itemName)
    end
end

-- Cleanup when player leaves
game:GetService("Players").PlayerRemoving:Connect(function(player)
    heldWeaponSkills[player] = nil
end)

return NetworkModule