local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)

-- InputType enum for optimized packet serialization (string -> uint8)
local InputTypeEnum = {
    began = 0,
    ended = 1,
}

-- Hotbar slot 3
local HOTBAR_SLOT = 3

-- Track if skill is held
local isHeld = false

InputModule.InputBegan = function(input, Client)
    -- Block if in ANY action (not just dodging)
    if Client.Dodging or Client.IsInAction() then
        return
    end

    -- Block if stunned
    if Client.Library.StateCount(Client.Character, "Stuns") then
        return
    end

    -- BUGFIX: Get entity fresh each time (entity changes on respawn)
    local pent = ref.get("local_player")
    if not pent then return end

    local item = InventoryManager.getHotbarItem(pent, HOTBAR_SLOT)
    if not item then
        return
    end

    -- Mark as held
    isHeld = true

    -- Send to server to use item (server looks up item from hotbar slot)
    Client.Packets.UseItem.send({
        hotbarSlot = HOTBAR_SLOT,
        inputType = InputTypeEnum.began
    })
end

InputModule.InputEnded = function(input, Client)
    if not isHeld then return end

    -- Send to server (InputEnded)
    Client.Packets.UseItem.send({
        hotbarSlot = HOTBAR_SLOT,
        inputType = InputTypeEnum.ended
    })

    -- Clear held state
    isHeld = false
end

InputModule.InputChanged = function()
    -- Handle any input changes if needed
end

return InputModule