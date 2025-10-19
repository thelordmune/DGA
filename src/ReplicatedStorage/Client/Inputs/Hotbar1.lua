local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)

local player = Players.LocalPlayer
local pent = ref.get("local_player", player)

-- Map keys to hotbar slots
local keyToSlot = {
    [Enum.KeyCode.One] = 1,
    [Enum.KeyCode.Two] = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four] = 4,
    [Enum.KeyCode.Five] = 5,
    [Enum.KeyCode.Six] = 6,
    [Enum.KeyCode.Seven] = 7,
}

-- Track currently held skill per hotbar slot
local heldSkills = {}

InputModule.InputBegan = function(input, Client)
    local hotbarSlot = keyToSlot[input.KeyCode]
    if not hotbarSlot then return end

    -- Check if player is dashing
    if Client.Dodging then
        -- print("[Hotbar1] Cannot use skill while dashing")
        return
    end

    -- print("Hotbar slot pressed:", hotbarSlot)

    local item = InventoryManager.getHotbarItem(pent, hotbarSlot)
    if not item then
        -- print("No item in hotbar slot:", hotbarSlot)
        return
    end

    -- print("Using item:", item.name, "from hotbar slot:", hotbarSlot)

    -- Store the item for InputEnded
    heldSkills[hotbarSlot] = item

    -- Send to server to use item (InputBegan)
    local packet = {
        itemName = item.name,
        hotbarSlot = hotbarSlot,
        inputType = "began" -- Track input type
    }
    -- print("[Hotbar1] Sending InputBegan packet:", packet.inputType)
    Client.Packets.UseItem.send(packet)
end

InputModule.InputEnded = function(input, Client)
    local hotbarSlot = keyToSlot[input.KeyCode]
    if not hotbarSlot then return end

    local item = heldSkills[hotbarSlot]
    if not item then return end

    -- print("Hotbar slot released:", hotbarSlot, "Item:", item.name)

    -- Send to server (InputEnded)
    local packet = {
        itemName = item.name,
        hotbarSlot = hotbarSlot,
        inputType = "ended" -- Track input type
    }
    -- print("[Hotbar1] Sending InputEnded packet:", packet.inputType)
    Client.Packets.UseItem.send(packet)

    -- Clear held skill
    heldSkills[hotbarSlot] = nil
end

InputModule.InputChanged = function()
    -- Handle any input changes if needed
end

return InputModule