--[[
	InventoryState

	Shared state module for inventory/hotbar communication.
	Tracks the currently selected inventory item slot for hotbar assignment.

	NOTE: Uses simple Lua values instead of Fusion to avoid memory leaks.
	This module persists across character respawns.
]]

local InventoryState = {}

-- Currently selected inventory slot (nil if nothing selected)
local selectedSlot: number? = nil

-- Currently selected item data (for display purposes)
local selectedItemData: any? = nil

-- Callback when a hotbar slot is clicked while an item is selected
InventoryState.onHotbarSlotClick = nil

-- Set the selected inventory item
function InventoryState.setSelectedItem(slot: number?, itemData: any?)
	selectedSlot = slot
	selectedItemData = itemData
end

-- Clear the selection
function InventoryState.clearSelection()
	selectedSlot = nil
	selectedItemData = nil
end

-- Get the current selection
function InventoryState.getSelectedSlot(): number?
	return selectedSlot
end

function InventoryState.getSelectedItemData(): any?
	return selectedItemData
end

-- Register callback for hotbar slot clicks
function InventoryState.registerHotbarClickHandler(callback: (hotbarSlot: number) -> ())
	InventoryState.onHotbarSlotClick = callback
end

-- Called by hotbar when a slot is clicked
function InventoryState.handleHotbarClick(hotbarSlot: number)
	if InventoryState.onHotbarSlotClick then
		InventoryState.onHotbarSlotClick(hotbarSlot)
	end
end

-- Reset state (call on character death/respawn)
function InventoryState.reset()
	selectedSlot = nil
	selectedItemData = nil
	-- Don't clear the callback - it will be re-registered by the new Inventory component
end

return InventoryState
