local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
-- local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)
local HotbarButton = require(ReplicatedStorage.Client.Components.HotbarButton)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

return function(scope, props: {
    character: Model?,
    Parent: Instance,
    entity: number?,
})
    local character = props.character
    local parent = props.Parent
    -- Store the initial entity, but we'll always fetch fresh when needed
    local initialEntity = props.entity

    print("[Hotbar] ===== HOTBAR COMPONENT STARTING =====")
    print(`[Hotbar] Character: {character}`)
    print(`[Hotbar] Parent: {parent}`)
    print(`[Hotbar] Initial Entity: {initialEntity}`)

    -- Reactive values for hotbar items
    local hotbarItems = scope:Value({})

    -- Helper function to get the current player entity (always fresh)
    local function getCurrentEntity()
        -- Always get fresh entity from ref to handle entity sync race conditions
        local entity = ref.get("player", Players.LocalPlayer)
        if not entity then
            entity = ref.get("local_player")
        end
        return entity
    end

    -- Update hotbar items when inventory changes
    local function updateHotbarDisplay()
        -- Always get fresh entity - don't use stale reference
        local entity = getCurrentEntity()
        print("[Hotbar] updateHotbarDisplay called, entity:", entity)

        if not entity then
            print("[Hotbar] No entity, skipping update")
            return
        end

        -- Debug: Check if entity has Inventory and Hotbar components
        local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
        local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
        local hasInventory = world:has(entity, comps.Inventory)
        local hasHotbar = world:has(entity, comps.Hotbar)
        print(`[Hotbar] Entity {entity} has Inventory: {hasInventory}, Hotbar: {hasHotbar}`)

        if hasHotbar then
            local hotbarData = world:get(entity, comps.Hotbar)
            print(`[Hotbar] Hotbar data: slots =`, hotbarData and hotbarData.slots or "nil")
        end

        local items = {}
        local itemCount = 0
        for slot = 1, 7 do
            local item = InventoryManager.getHotbarItem(entity, slot)
            if item then
                print(`[Hotbar] Slot {slot}: {item.name}, icon: {item.icon or "no icon"}`)
                itemCount = itemCount + 1
            end
            items[slot] = item
        end

        hotbarItems:set(items)
        print(`[Hotbar] Hotbar items updated - found {itemCount} items`)
    end

    -- Initial update
    updateHotbarDisplay()

    -- ⚡ PERFORMANCE OPTIMIZATION: Event-driven updates instead of RenderStepped
    -- Listen to BridgeNet2 inventory sync events instead of polling every frame
    -- This reduces CPU usage by ~95% (60Hz → event-driven)
    local Bridges = require(ReplicatedStorage.Modules.Bridges)
    local inventoryConnection = Bridges.Inventory:Connect(function()
        -- Wait for InventoryHandler to finish setting the data on the entity
        -- InventoryHandler also listens to this event and sets the Inventory/Hotbar components
        -- Use task.wait to ensure we're in a new frame and InventoryHandler has completed
        task.spawn(function()
            task.wait() -- Wait one frame for InventoryHandler to complete
            print("[Hotbar] Bridges.Inventory received - updating display (after frame wait)")
            updateHotbarDisplay()
        end)
    end)

    -- Also listen to UpdateHotbar bridge for immediate updates
    local hotbarUpdateConnection = Bridges.UpdateHotbar:Connect(function()
        -- Wait one frame to ensure inventory components are set
        task.spawn(function()
            task.wait() -- Wait one frame
            print("[Hotbar] Bridges.UpdateHotbar received - updating display (after frame wait)")
            updateHotbarDisplay()
        end)
    end)

    -- ---- print("[Hotbar] Using existing parent frame as hotbar container...")
    -- ---- print(`[Hotbar] Parent: {parent}`)

    -- Ensure UIListLayout exists in the parent
    local uiListLayout = parent:FindFirstChild("UIListLayout")
    if not uiListLayout then
        -- ---- print("[Hotbar] Creating UIListLayout in parent...")
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
        -- ---- print("[Hotbar] UIListLayout already exists in parent")
    end

    -- Create hotbar buttons with staggered animation
    -- ---- print("[Hotbar] Creating 7 hotbar buttons...")
    for slot = 1, 7 do
        -- ---- print(`[Hotbar] Creating button for slot {slot}`)
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

        -- ---- print(`[Hotbar] Button created for slot {slot}: {button}`)

        -- Add loading animation (one by one)
        task.delay(0.05 * (slot - 1), function()
            -- ---- print(`[Hotbar] Animating button {slot}`)
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
                -- ---- print(`[Hotbar] ⚠️ Button {slot} is nil!`)
            end
        end)
    end

    -- ⚡ Cleanup connections when scope is destroyed
    table.insert(scope, function()
        if inventoryConnection then
            inventoryConnection:Disconnect()
            inventoryConnection = nil
        end
        if hotbarUpdateConnection then
            hotbarUpdateConnection:Disconnect()
            hotbarUpdateConnection = nil
        end
    end)

    -- ---- print("[Hotbar] ===== HOTBAR COMPONENT COMPLETE =====")
    return parent
end