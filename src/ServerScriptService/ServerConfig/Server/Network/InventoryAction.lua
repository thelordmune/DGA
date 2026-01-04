--[[
	InventoryAction Network Handler

	Handles inventory-related actions from clients:
	- MoveToHotbar: Move item from inventory to hotbar slot
	- SwapWithHotbar: Swap inventory item with hotbar item
	- MoveToInventory: Move item from hotbar to inventory
]]

local NetworkModule = {}
NetworkModule.__index = NetworkModule

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

local self = setmetatable({}, NetworkModule)

-- Constants for slot ranges
local HOTBAR_SLOTS = {min = 1, max = 7}
local INVENTORY_SLOTS = {min = 8, max = 50}

NetworkModule.EndPoint = function(Player, Data)
	if not Data or not Data.action then
		warn("[InventoryAction] Invalid data received from", Player.Name)
		return
	end

	local entity = ref.get("player", Player)
	if not entity then
		warn("[InventoryAction] No entity found for player:", Player.Name)
		return
	end

	local action = Data.action

	if action == "MoveToHotbar" then
		-- Move an inventory item to a hotbar slot
		local inventorySlot = Data.inventorySlot
		local hotbarSlot = Data.hotbarSlot

		if not inventorySlot or not hotbarSlot then
			warn("[InventoryAction] MoveToHotbar: Missing slots")
			return
		end

		-- Validate hotbar slot (1-7)
		if hotbarSlot < HOTBAR_SLOTS.min or hotbarSlot > HOTBAR_SLOTS.max then
			warn("[InventoryAction] MoveToHotbar: Invalid hotbar slot:", hotbarSlot)
			return
		end

		-- Get inventory and hotbar
		if not world:has(entity, comps.Inventory) or not world:has(entity, comps.Hotbar) then
			warn("[InventoryAction] MoveToHotbar: Missing components")
			return
		end

		local inventory = world:get(entity, comps.Inventory)
		local hotbar = world:get(entity, comps.Hotbar)

		-- Check if inventory slot has an item
		if not inventory.items[inventorySlot] then
			warn("[InventoryAction] MoveToHotbar: No item in inventory slot:", inventorySlot)
			return
		end

		-- Check if hotbar slot is empty
		local currentHotbarInventorySlot = hotbar.slots[hotbarSlot]

		if currentHotbarInventorySlot and inventory.items[currentHotbarInventorySlot] then
			-- Hotbar slot has an item - swap them
			-- The old hotbar item goes to the inventory slot, new item takes hotbar
			local oldHotbarItem = inventory.items[currentHotbarInventorySlot]
			local newItem = inventory.items[inventorySlot]

			-- Swap the items in inventory
			inventory.items[inventorySlot] = oldHotbarItem
			inventory.items[inventorySlot].slot = inventorySlot

			inventory.items[currentHotbarInventorySlot] = newItem
			inventory.items[currentHotbarInventorySlot].slot = currentHotbarInventorySlot

			-- Hotbar still points to the same inventory slot (currentHotbarInventorySlot)
			-- which now contains the new item

			world:set(entity, comps.Inventory, inventory)
			world:set(entity, comps.Hotbar, hotbar)

			-- Sync to client
			InventoryManager.setHotbarSlot(entity, hotbarSlot, currentHotbarInventorySlot)

			print("[InventoryAction] Swapped inventory slot", inventorySlot, "with hotbar slot", hotbarSlot)
		else
			-- Hotbar slot is empty - just assign the inventory item to the hotbar
			-- Simply point the hotbar slot to the inventory slot (no moving needed)
			InventoryManager.setHotbarSlot(entity, hotbarSlot, inventorySlot)
			print("[InventoryAction] Assigned inventory slot", inventorySlot, "to hotbar slot", hotbarSlot)
		end

	elseif action == "SwapWithHotbar" then
		-- Swap inventory item with hotbar item
		local inventorySlot = Data.inventorySlot
		local hotbarSlot = Data.hotbarSlot

		if not inventorySlot or not hotbarSlot then
			warn("[InventoryAction] SwapWithHotbar: Missing slots")
			return
		end

		if not world:has(entity, comps.Inventory) or not world:has(entity, comps.Hotbar) then
			return
		end

		local inventory = world:get(entity, comps.Inventory)
		local hotbar = world:get(entity, comps.Hotbar)

		local hotbarInventorySlot = hotbar.slots[hotbarSlot]
		if not hotbarInventorySlot then
			warn("[InventoryAction] SwapWithHotbar: Hotbar slot empty")
			return
		end

		-- Swap items
		local invItem = inventory.items[inventorySlot]
		local hotbarItem = inventory.items[hotbarInventorySlot]

		inventory.items[inventorySlot] = hotbarItem
		inventory.items[hotbarInventorySlot] = invItem

		-- Update slot references
		if inventory.items[inventorySlot] then
			inventory.items[inventorySlot].slot = inventorySlot
		end
		if inventory.items[hotbarInventorySlot] then
			inventory.items[hotbarInventorySlot].slot = hotbarInventorySlot
		end

		world:set(entity, comps.Inventory, inventory)

		print("[InventoryAction] Swapped inventory slot", inventorySlot, "with hotbar inventory slot", hotbarInventorySlot)

	elseif action == "MoveToInventory" or action == "UnequipFromHotbar" then
		-- Remove item from hotbar slot (unequip)
		local hotbarSlot = Data.hotbarSlot

		if not hotbarSlot then
			warn("[InventoryAction] MoveToInventory: Missing hotbar slot")
			return
		end

		if not world:has(entity, comps.Hotbar) then
			return
		end

		local hotbar = world:get(entity, comps.Hotbar)
		hotbar.slots[hotbarSlot] = nil
		world:set(entity, comps.Hotbar, hotbar)

		-- Sync to client
		local Bridges = require(ReplicatedStorage.Modules.Bridges)
		local inventory = world:get(entity, comps.Inventory)
		local syncData = {
			inventory = {
				items = {},
				maxSlots = inventory.maxSlots
			},
			hotbar = {
				slots = hotbar.slots,
				activeSlot = hotbar.activeSlot or 1
			}
		}
		-- Convert inventory items to array format
		for slot, item in pairs(inventory.items) do
			table.insert(syncData.inventory.items, {
				name = item.name,
				typ = item.typ,
				quantity = item.quantity,
				singleuse = item.singleuse,
				description = item.description,
				icon = item.icon,
				stackable = item.stackable,
				slot = slot,
				rarity = item.rarity or "common"
			})
		end
		Bridges.Inventory:Fire(Player, syncData)

		print("[InventoryAction] Unequipped hotbar slot", hotbarSlot)

	elseif action == "AssignToHotbar" then
		-- Simply assign an inventory slot to a hotbar slot without moving
		local inventorySlot = Data.inventorySlot
		local hotbarSlot = Data.hotbarSlot

		if not inventorySlot or not hotbarSlot then
			warn("[InventoryAction] AssignToHotbar: Missing slots")
			return
		end

		InventoryManager.setHotbarSlot(entity, hotbarSlot, inventorySlot)
		print("[InventoryAction] Assigned inventory slot", inventorySlot, "to hotbar slot", hotbarSlot)

	else
		warn("[InventoryAction] Unknown action:", action)
	end
end

return NetworkModule
