local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

local self = setmetatable({}, NetworkModule)

-- InputType enum decoder: uint8 -> string
local EnumToInputType = {
    [0] = "began",
    [1] = "ended",
}

-- Track held weapon skills per player
-- Format: {[Player] = {skillName, skillInstance, character}}
local heldWeaponSkills = {}

NetworkModule.EndPoint = function(Player, Data)
    local Weapon = Player:GetAttribute("Weapon")

    -- Decode uint8 inputType to string
    local inputType = EnumToInputType[Data.inputType] or "began"

   -- print("=== USE ITEM ENDPOINT ===")
   -- print("Player:", Player.Name)
   -- print("Hotbar Slot:", Data.hotbarSlot)
   -- print("InputType:", inputType)
   -- print("Weapon:", Weapon)

    local pent = ref.get("player", Player)  -- Fixed: Use "player" on server, not "local_player"
    if not pent then
        warn("[UseItem] Player entity not found for:", Player.Name)
        return
    end

    ---- print("[UseItem] Player entity:", pent)

    -- Debug: Print hotbar state
    if world:has(pent, comps.Hotbar) then
        local hotbar = world:get(pent, comps.Hotbar)
        ---- print("Hotbar slots:", hotbar.slots)
        ---- print("Looking for item in hotbar slot:", Data.hotbarSlot)
        ---- print("Inventory slot mapped to hotbar slot:", hotbar.slots[Data.hotbarSlot])
    else
        warn("Player has no Hotbar component!")
    end

    -- Debug: Print inventory state
    if world:has(pent, comps.Inventory) then
        local inventory = world:get(pent, comps.Inventory)
        ---- print("Inventory items count:", #inventory.items)
        for slot, item in pairs(inventory.items) do
            ---- print("  Slot", slot, ":", item.name, "(type:", item.typ, ")")
        end
    else
        warn("Player has no Inventory component!")
    end

    -- Look up item from hotbar slot (server authoritative - no need for client to send item name)
    local item = InventoryManager.getHotbarItem(pent, Data.hotbarSlot)
    if not item then
        warn("No item found in hotbar slot", Data.hotbarSlot)
        return
    end

    local itemName = item.name

    -- Use the item
    local success, usedItem = InventoryManager.useItem(pent, itemName)
    if success then
        ---- print("Successfully used item:", Data.itemName)
        
        -- Handle different item types
        if usedItem.typ == "consumable" then
            -- Handle consumable logic (healing, buffs, etc.)
            ---- print("Used consumable:", usedItem.name)
        elseif usedItem.typ == "weapon" then
            -- Switch weapon
            Player:SetAttribute("Weapon", usedItem.name)
            ---- print("Switched to weapon:", usedItem.name)
        elseif usedItem.typ == "skill" then
            -- Check if player is dashing (Dashing is now a tag)
            local playerEntity = ref.get("player", Player)
            if playerEntity and world:has(playerEntity, comps.Dashing) then
                ---- print("[UseItem] Cannot use skill while dashing")
                return
            end

            -- Activate skill
            ---- print("Activated skill:", usedItem.name, "for weapon:", Weapon, "InputType:", inputType or "began")
            local skillPath = script.Parent.Parent.WeaponSkills[Weapon]
            if skillPath and skillPath:FindFirstChild(usedItem.name) then
                local skillModule = skillPath[usedItem.name]
                local skill = require(skillModule)

                ---- print("[UseItem] Skill type:", type(skill))

                -- Check if skill is a WeaponSkillHold instance (has OnInputBegan method)
                if type(skill) == "table" and type(skill.OnInputBegan) == "function" then
                    ---- print("[UseItem] Has OnInputBegan: true")
                    ---- print("[UseItem] Skill metatable:", getmetatable(skill))
                    -- NEW HOLD SYSTEM
                    ---- print("[UseItem] Using NEW HOLD SYSTEM for:", usedItem.name)
                    if inputType == "began" then
                        -- Additional server-side check: prevent spam if skill is on cooldown or executing
                        local Character = Player.Character
                        if Character then
                            -- Check if skill is on cooldown
                            if skill:IsOnCooldown(Player) then
                                ---- print("[UseItem] Skill is on cooldown, ignoring input")
                                return
                            end

                            -- Check if skill is already executing (Actions state)
                            if StateManager.StateCheck(Character, "Actions", usedItem.name) then
                                ---- print("[UseItem] Skill is already executing, ignoring input")
                                return
                            end

                            -- Check if player is already holding a skill
                            if heldWeaponSkills[Player] then
                                ---- print("[UseItem] Player is already holding a skill, ignoring input")
                                return
                            end
                        end

                        -- CANCEL SPRINT when using a skill
                        Server.Packets.CancelSprint.sendTo({}, Player)

                        -- Store skill for InputEnded
                        heldWeaponSkills[Player] = {
                            skillName = usedItem.name,
                            skillInstance = skill,
                            character = Player.Character
                        }

                        -- Call OnInputBegan
                        ---- print("[UseItem] Calling OnInputBegan for:", usedItem.name)
                        skill:OnInputBegan(Player, Player.Character)
                    elseif inputType == "ended" then
                        -- Call OnInputEnded
                        ---- print("[UseItem] Calling OnInputEnded for:", usedItem.name)
                        local heldData = heldWeaponSkills[Player]
                        if heldData and heldData.skillName == usedItem.name then
                            skill:OnInputEnded(Player)
                            heldWeaponSkills[Player] = nil

                            -- Apply 1 second soft cooldown on cast
                            local Character = Player.Character
                            if Character then
                                Server.Library.SetCooldown(Character, "SkillCast", 1)
                            end
                        else
                            ---- print("[UseItem] No held skill data found for:", usedItem.name)
                        end
                    end
                else
                    -- OLD SYSTEM (function-based skills)
                   -- print("[UseItem] Using OLD SYSTEM (function-based) for:", usedItem.name)
                    -- Only execute on 'ended' input to prevent double-triggering
                    if inputType == "ended" then
                       -- print("[UseItem] Executing skill on 'ended' input")

                        -- CANCEL SPRINT when using a skill
                        Server.Packets.CancelSprint.sendTo({}, Player)

                        skill(Player, Data, Server)

                        -- Apply 1 second soft cooldown on cast
                        local Character = Player.Character
                        if Character then
                            Server.Library.SetCooldown(Character, "SkillCast", 1)
                        end
                    else
                       -- print("[UseItem] Ignoring 'began' input for old system skill")
                    end
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