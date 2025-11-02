local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)

local player = Players.LocalPlayer
local pent = ref.get("local_player", player)

-- Hotbar slot 6
local HOTBAR_SLOT = 6

-- Track currently held skill
local heldSkill = nil

InputModule.InputBegan = function(input, Client)
    -- Check if player is dashing
    if Client.Dodging then
        return
    end

    local item = InventoryManager.getHotbarItem(pent, HOTBAR_SLOT)
    if not item then
        return
    end

    -- Store the item for InputEnded
    heldSkill = item

    -- Send to server to use item (InputBegan)
    Client.Packets.UseItem.send({
        itemName = item.name,
        hotbarSlot = HOTBAR_SLOT,
        inputType = "began"
    })
end

InputModule.InputEnded = function(input, Client)
    if not heldSkill then return end

    -- Send to server (InputEnded)
    Client.Packets.UseItem.send({
        itemName = heldSkill.name,
        hotbarSlot = HOTBAR_SLOT,
        inputType = "ended"
    })

    -- Clear held skill
    heldSkill = nil
end

InputModule.InputChanged = function()
    -- Handle any input changes if needed
end

return InputModule

