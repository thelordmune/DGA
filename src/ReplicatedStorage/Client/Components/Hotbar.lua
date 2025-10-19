local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)
local HotbarButton = require(ReplicatedStorage.Client.Components.HotbarButton)

return function(scope, props: {
	character: Model?,
	Parent: Instance,
	entity: number?,
})
	local character = props.character
	local parent = props.Parent
	local entity = props.entity

	-- -- print("[Hotbar] ===== HOTBAR COMPONENT STARTING =====")
	-- -- print(`[Hotbar] Character: {character}`)
	-- -- print(`[Hotbar] Parent: {parent}`)
	-- -- print(`[Hotbar] Parent type: {typeof(parent)}`)
	-- -- print(`[Hotbar] Entity: {entity}`)

	-- Reactive values for hotbar items
	local hotbarItems = scope:Value({})

	-- Update hotbar items when inventory changes
	local function updateHotbarDisplay()
		-- -- print("[Hotbar] updateHotbarDisplay called")
		if not entity then
			-- -- print("[Hotbar] No entity, skipping update")
			return
		end

		local items = {}
		for slot = 1, 7 do
			local item = InventoryManager.getHotbarItem(entity, slot)
			-- -- -- print(`[Hotbar] Slot {slot}: {item}`)
			if item then
				-- -- -- print(`[Hotbar]   - Item name: {item.name}`)
				-- -- -- print(`[Hotbar]   - Item icon: {item.icon}`)
			end
			items[slot] = item
		end

		hotbarItems:set(items)
		-- -- print("[Hotbar] Hotbar items updated")
	end

	-- Initial update
	updateHotbarDisplay()

	-- Continuous update every frame to catch inventory changes
	local updateConnection = RunService.RenderStepped:Connect(function()
		updateHotbarDisplay()
	end)

	-- -- print("[Hotbar] Using existing parent frame as hotbar container...")
	-- -- print(`[Hotbar] Parent: {parent}`)

	-- Ensure UIListLayout exists in the parent
	local uiListLayout = parent:FindFirstChild("UIListLayout")
	if not uiListLayout then
		-- -- print("[Hotbar] Creating UIListLayout in parent...")
		uiListLayout = scope:New "UIListLayout" {
			Name = "UIListLayout",
			Parent = parent,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.005, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}
	else
		-- -- print("[Hotbar] UIListLayout already exists in parent")
	end

	-- Create hotbar buttons with staggered animation
	-- -- print("[Hotbar] Creating 7 hotbar buttons...")
	for slot = 1, 7 do
		-- -- print(`[Hotbar] Creating button for slot {slot}`)
		local button = HotbarButton(scope, {
			slotNumber = slot,
			itemName = scope:Computed(function(use)
				local items = use(hotbarItems)
				local item = items[slot]
				return item and item.name or ""
			end),
			itemIcon = scope:Computed(function(use)
				local items = use(hotbarItems)
				local item = items[slot]
				return item and item.icon or "rbxassetid://71291612556381"
			end),
			character = character,
			Parent = parent,
		})

		-- -- print(`[Hotbar] Button created for slot {slot}: {button}`)

		-- Add loading animation (one by one)
		task.delay(0.05 * (slot - 1), function()
			-- -- print(`[Hotbar] Animating button {slot}`)
			if button then
				-- Set initial state (transparent and offset)
				button.BackgroundTransparency = 1
				button.Position = button.Position + UDim2.fromOffset(0, -15)

				-- Tween to visible
				TweenService:Create(
					button,
					TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{Position = button.Position - UDim2.fromOffset(0, -15)}
				):Play()

				TweenService:Create(
					button,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{BackgroundTransparency = 1}
				):Play()
			else
				-- -- print(`[Hotbar] ⚠️ Button {slot} is nil!`)
			end
		end)
	end

	-- Cleanup update connection
	-- scope:Cleanup(function()
	-- 	updateConnection:Disconnect()
	-- end)

	-- -- print("[Hotbar] ===== HOTBAR COMPONENT COMPLETE =====")
	return parent
end

