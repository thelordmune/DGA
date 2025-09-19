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

InputModule.InputBegan = function(input, Client)
    local hotbarSlot = keyToSlot[input.KeyCode]
    if not hotbarSlot then return end
    
    print("Hotbar slot pressed:", hotbarSlot)
    
    local item = InventoryManager.getHotbarItem(pent, hotbarSlot)
    if not item then
        print("No item in hotbar slot:", hotbarSlot)
        return
    end
    
    print("Using item:", item.name, "from hotbar slot:", hotbarSlot)
    
    -- Send to server to use item
    Client.Packets.UseItem.send({
        itemName = item.name,
        hotbarSlot = hotbarSlot
    })
end

InputModule.InputEnded = function(input, Client)
    -- Handle any release logic if needed
end

InputModule.InputChanged = function()
    -- Handle any input changes if needed
end

return InputModule