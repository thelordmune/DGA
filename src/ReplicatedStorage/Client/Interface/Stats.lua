local Controller = {}; local Client = require(script.Parent.Parent);
Controller.__index = Controller;
local self = setmetatable({}, Controller);
local Replicated = game:GetService("ReplicatedStorage")
local plr = game:GetService("Players").LocalPlayer
local Character = plr.Character or plr.CharacterAdded

local UI = Client.UI or plr.PlayerGui.ScreenGui;

-- Fusion-based PlayerBars Component (replaces old Health component)
local PlayerBarsComponent = require(Replicated.Client.Components.PlayerBars)
local playerBarsData = nil

-- Nen Indicator Component (replaces NenWheel)
local NenIndicatorComponent = require(Replicated.Client.Components.NenIndicator)
local nenIndicatorData = nil

-- Track Fusion scopes for cleanup on death
local activeScopes = {}

-- UI Reuse: Store persistent UI components that survive respawns
local persistentHotbarScope = nil -- Stores the reusable Hotbar scope

-- Expose playerBarsData for external systems to access
Controller.playerBarsData = playerBarsData
Controller.nenIndicatorData = nenIndicatorData

-- Cleanup function called on death - HIDES UI instead of destroying
-- CRITICAL: Don't destroy UI - just hide it to avoid recreation overhead
Controller.CleanupUI = function()
	-- Hide the main UI instead of destroying it
	if UI then
		UI.Enabled = false
	end

	-- Reset state values but keep the UI intact
	if playerBarsData then
		-- Reset state values to defaults
		if playerBarsData.healthValue then
			playerBarsData.healthValue:set(100)
		end
		if playerBarsData.staminaValue then
			playerBarsData.staminaValue:set(100)
		end
		if playerBarsData.moneyValue then
			playerBarsData.moneyValue:set(0)
		end
		-- Call reset function if available
		if playerBarsData.reset then
			playerBarsData.reset()
		end
		-- DON'T destroy - we reuse it
	end

	-- DON'T clean up hotbar scope - just hide it
	-- The hotbar will be shown again on respawn

	-- DON'T clean up tracked scopes - they'll be reused
	-- Just reset their state if needed
end

-- Full cleanup function for when player leaves or UI needs complete reset
Controller.FullCleanupUI = function()
	-- Clean up player bars component completely
	if playerBarsData and playerBarsData.scope then
		playerBarsData.scope:doCleanup()
	end
	playerBarsData = nil
	Controller.playerBarsData = nil

	-- Clean up persistent hotbar scope
	if persistentHotbarScope then
		persistentHotbarScope:doCleanup()
	end
	persistentHotbarScope = nil

	-- Clean up all tracked scopes
	for i, scopeData in ipairs(activeScopes) do
		if scopeData.scope then
			scopeData.scope:doCleanup()
		end
	end
	table.clear(activeScopes)
end

Controller.Check = function()
	-- Create UI only if it doesn't exist at all
	if not UI or not UI:FindFirstChild("Stats") then
       local ui = Replicated.Assets.GUI.ScreenGui:Clone()
	   ui.Parent = plr.PlayerGui
	   UI = ui -- Update the UI reference
	   -- Reset player bars data when UI is recreated
	   playerBarsData = nil
    end

	-- Show the UI (it may have been hidden on death)
	if UI then
		UI.Enabled = true
	end

    -- Hide the old health bar container
    if UI and UI:FindFirstChild("Stats") then
        local statsFrame = UI.Stats
        if statsFrame:FindFirstChild("Container") then
            local container = statsFrame.Container
            if container:FindFirstChild("Health") then
                container.Health.Visible = false
            end
        end

        -- REUSE PlayerBars component to avoid recreation overhead
        -- Only create new if it doesn't exist or frame was destroyed
        if playerBarsData and playerBarsData.frame and playerBarsData.frame.Parent then
            -- REUSE: Reset state values instead of recreating
            if playerBarsData.healthValue then
                playerBarsData.healthValue:set(100)
            end
            if playerBarsData.staminaValue then
                playerBarsData.staminaValue:set(100)
            end
            if playerBarsData.moneyValue then
                playerBarsData.moneyValue:set(0)
            end
            -- Call reset function if available
            if playerBarsData.reset then
                playerBarsData.reset()
            end
            -- Don't recreate - reuse existing component
        else
            -- Only create new if doesn't exist or frame was destroyed
            if playerBarsData and playerBarsData.scope then
                playerBarsData.scope:doCleanup()
            end
            playerBarsData = PlayerBarsComponent(statsFrame)
            Controller.playerBarsData = playerBarsData -- Update the exposed reference
        end

        -- Initialize NenIndicator if not already created
        if not nenIndicatorData or not nenIndicatorData.billboardGui then
            if nenIndicatorData and nenIndicatorData.cleanup then
                nenIndicatorData.cleanup()
            end
            nenIndicatorData = NenIndicatorComponent()
            Controller.nenIndicatorData = nenIndicatorData
        end
    end
end

Controller.Health = function(Value, MaxValue)
	if not UI or not UI:FindFirstChild("Stats") then
        UI = plr.PlayerGui:FindFirstChild("ScreenGui")
        if not UI then
            warn("[Stats] Health update failed - UI not found")
            return
        end
    end

    -- Update the health value for the PlayerBars component
    if playerBarsData and playerBarsData.healthValue then
        local healthPercent = math.clamp((Value / MaxValue) * 100, 0, 100)
        playerBarsData.healthValue:set(healthPercent)
        if playerBarsData.maxHealthValue then
            playerBarsData.maxHealthValue:set(MaxValue)
        end
    else
        warn("[Stats] PlayerBars component not initialized yet")
    end
end

Controller.Energy = function(Value, MaxValue)
    local scale = math.clamp(Value / MaxValue, 0, 1)
    Client.Service.TweenService:Create(UI.Stats.Container.Energy.Bar, TweenInfo.new(.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(scale, 0.635)
    }):Play()
end

-- Alchemy system removed - Hunter x Hunter Nen system will replace this

Controller.LoadWeaponSkills = function()
    -- Check if we're still in loading screen
    if _G.LoadingScreenActive then
        warn("[LoadWeaponSkills] Skipped - Loading screen is active")
        return -- Don't load weapon skills during loading screen
    end

    -- Check if UI is ready
    if not UI or not UI:FindFirstChild("Hotbar") then
        warn("[LoadWeaponSkills] Skipped - UI or Hotbar not ready")
        return -- UI not ready yet, skip loading
    end

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    -- Safely require modules with error handling
    local success, ref = pcall(require, ReplicatedStorage.Modules.ECS.jecs_ref)
    if not success then
        warn("[LoadWeaponSkills] Failed to load jecs_ref:", ref)
        return
    end

    local success2, InventoryManager = pcall(require, ReplicatedStorage.Modules.Utils.InventoryManager)
    if not success2 then
        warn("[LoadWeaponSkills] Failed to load InventoryManager:", InventoryManager)
        return
    end

    -- Load world and comps
    local success3, world = pcall(require, ReplicatedStorage.Modules.ECS.jecs_world)
    if not success3 then
        warn("[LoadWeaponSkills] Failed to load jecs_world:", world)
        return
    end

    local success4, comps = pcall(require, ReplicatedStorage.Modules.ECS.jecs_components)
    if not success4 then
        warn("[LoadWeaponSkills] Failed to load jecs_components:", comps)
        return
    end

    -- Use the same method as InventoryHandler to get the entity
    -- This ensures we're looking at the same entity that has the inventory data
    local localPlayer = Players.LocalPlayer
    local pent = ref.get("player", localPlayer)

    if not pent then
        -- Fallback to local_player
        pent = ref.get("local_player")
    end

    if not pent then
        warn("[LoadWeaponSkills] Player entity not found")
        return
    end

    print("[LoadWeaponSkills] Loading weapon skills for player entity:", pent)

    -- Check if player has Hotbar and Inventory components
    if not world:has(pent, comps.Hotbar) then
        warn("[LoadWeaponSkills] Player entity has no Hotbar component yet")
        return
    end

    if not world:has(pent, comps.Inventory) then
        warn("[LoadWeaponSkills] Player entity has no Inventory component yet")
        return
    end

    local hotbar = world:get(pent, comps.Hotbar)
    local inventory = world:get(pent, comps.Inventory)

    print("[LoadWeaponSkills] 📋 Hotbar slots:", hotbar.slots)
    print("[LoadWeaponSkills] 📦 Inventory items:")
    local itemCount = 0
    for slot, item in pairs(inventory.items) do
        itemCount = itemCount + 1
        print("  Slot", slot, ":", item.name, "(type:", item.typ, ")")
    end
    print("[LoadWeaponSkills] Total items:", itemCount)

    -- Get weapon skills from hotbar slots 1-7
    local skillsLoaded = 0
    for slotNumber = 1, 7 do
        local success3, item = pcall(InventoryManager.getHotbarItem, pent, slotNumber)
        print("[LoadWeaponSkills] Checking slot", slotNumber, "- success:", success3, "item:", item and item.name or "nil")
        if success3 and item then
            print("[LoadWeaponSkills] Slot", slotNumber, "- Item:", item.name, "Type:", item.typ)
            if item.typ == "skill" then
                Controller.UpdateHotbarSlot(slotNumber, item.name)
                skillsLoaded = skillsLoaded + 1
            end
        else
            print("[LoadWeaponSkills] Slot", slotNumber, "- Empty or error:", success3 and "empty" or tostring(item))
            Controller.UpdateHotbarSlot(slotNumber, "") -- Clear slot if no skill
        end
    end

    print("[LoadWeaponSkills] ✅ Loaded", skillsLoaded, "weapon skills")
end

Controller.UpdateHotbarSlot = function(slotNumber, itemName)
    print("[UpdateHotbarSlot] Updating slot", slotNumber, "with:", itemName)

    -- Check if UI and Hotbar exist before trying to access them
    if not UI or not UI:FindFirstChild("Hotbar") then
        warn("[UpdateHotbarSlot] UI or Hotbar not found!")
        return -- UI not ready yet, skip update
    end

    local hotbarName = slotNumber == 1 and "Hotbar" or "Hotbar" .. slotNumber
    local hotbar = UI.Hotbar:FindFirstChild(hotbarName)

    if hotbar then
        local textLabel = hotbar:FindFirstChild("Text")
        if textLabel then
            textLabel.Text = itemName or ""
            print("[UpdateHotbarSlot] ✅ Set slot", slotNumber, "text to:", itemName)
        else
            warn("[UpdateHotbarSlot] No Text child in", hotbarName)
        end
    else
        warn("[UpdateHotbarSlot] Hotbar element not found:", hotbarName)
    end
end

Controller.InitializeHotbar = function(character, entity)
	---- print("[Stats] ===== INITIALIZING HOTBAR =====")
	---- print(`[Stats] Character: {character}`)
	---- print(`[Stats] Entity: {entity}`)
	---- print(`[Stats] UI: {UI}`)

	if not UI then
		---- print("[Stats] ❌ UI not found, skipping hotbar initialization")
		return
	end

	---- print(`[Stats] UI type: {typeof(UI)}`)
	---- print(`[Stats] UI name: {UI.Name}`)
	---- print(`[Stats] UI children: {#UI:GetChildren()}`)

	-- Find existing Hotbar frame
	local hotbarFrame = UI:FindFirstChild("Hotbar")
	if not hotbarFrame then
		---- print("[Stats] ❌ Hotbar frame not found in UI!")
		return
	end

	---- print(`[Stats] ✅ Found existing Hotbar frame: {hotbarFrame}`)

	-- CLEANUP OLD HOTBAR SCOPE FIRST to prevent memory leak
	for i = #activeScopes, 1, -1 do
		if activeScopes[i].name == "Hotbar" then
			if activeScopes[i].scope then
				activeScopes[i].scope:doCleanup()
			end
			table.remove(activeScopes, i)
		end
	end

	---- print("[Stats] Loading Hotbar component...")
	local Fusion = require(Replicated.Modules.Fusion)
	local Hotbar = require(Replicated.Client.Components.Hotbar)
	---- print("[Stats] Hotbar component loaded, creating scope...")
	local scope = Fusion.scoped(Fusion, {})
	---- print(`[Stats] Scope created: {scope}`)

	-- Track this scope for cleanup
	table.insert(activeScopes, {
		name = "Hotbar",
		scope = scope
	})

	-- Create the hotbar component
	---- print("[Stats] Calling Hotbar function...")
	Hotbar(scope, {
		character = character,
		entity = entity,
		Parent = hotbarFrame,
	})

	---- print("[Stats] ✅ Hotbar initialized with Fusion component")
	---- print("[Stats] ===== HOTBAR INITIALIZATION COMPLETE =====")
end

Controller.Hotbar = function(Order: string)
    -- Old hotbar initialization - now handled by Fusion Hotbar component
    -- This function is kept for backwards compatibility but does nothing
    ---- print("[Stats] Hotbar function called with Order:", Order, "- using new Fusion hotbar system")
end

Controller.Party = function()
local Fusion = require(Replicated.Modules.Fusion)

local Children, scoped, peek, out, OnEvent, Value, Tween =
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.Value, Fusion.Tween

	-- CLEANUP OLD PARTY SCOPE FIRST to prevent memory leak
	for i = #activeScopes, 1, -1 do
		if activeScopes[i].name == "Party" then
			if activeScopes[i].scope then
				activeScopes[i].scope:doCleanup()
			end
			table.remove(activeScopes, i)
		end
	end

    local scope = scoped(Fusion, {
		Party = require(Replicated.Client.Components.Party)
	})

	-- Track this scope for cleanup
	table.insert(activeScopes, {
		name = "Party",
		scope = scope
	})
	
	local start = scope:Value(false)
	local squ = scope:Value(false)
	local temper = scope:Value(false)
	local invitd = scope:Value(false)
	local use = scope:Value("")
	local par = UI
	local move = scope:Value(false)
	
	--task.delay(3, function()
	--	scope:Party{
	--		squadselected = squ,
	--		temp = temper,
	--		started = start,
	--		invited = invitd,
	--		user = use,
	--		parent = par
	--	}
	--	move:set(true)
	--	start:set(true)
	--end)
	
	--task.delay(5, function()
		
	--end)
	
	scope:New "Frame" {
		Parent = UI,
		Name = "PartyButton",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(move) then UDim2.fromScale(-1.5, 0.5) else UDim2.fromScale(0, 0.5)
			end),
			18,
			.23
			),
		Size = UDim2.fromOffset(100, 100),
        ZIndex = -5,

		[Children] = {
			scope:New "ImageButton" {
				Name = "Add",
				Active = true,
				BackgroundTransparency = 1,
				Image = "rbxassetid://8445470984",
				--ImageContent = Content.new(Content),
				ImageRectOffset = Vector2.new(804, 704),
				ImageRectSize = Vector2.new(96, 96),
				Position = UDim2.fromScale(0.5, 0.5),
				Selectable = false,
				Size = UDim2.fromOffset(24, 24),

				[Children] = {
					scope:New "UIAspectRatioConstraint" {
						Name = "UIAspectRatioConstraint",
						DominantAxis = Enum.DominantAxis.Height,
					},
				},
				[OnEvent "Activated"] = function(_,numclicks)
					---- print("activated party button")
					scope:Party{
						squadselected = squ,
						tempselected = temper,
						started = start,
						invited = invitd,
						user = use,
                        parent = par
					}
					move:set(true)
					start:set(true)
				end,
			},
		}
	}
end

-- Set up BridgeNet2 listener for hotbar updates
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bridges = require(ReplicatedStorage.Modules.Bridges)
Bridges.UpdateHotbar:Connect(function()
    -- Don't update during loading screen or if UI isn't ready
    if _G.LoadingScreenActive then
        return
    end

    if not UI or not UI:FindFirstChild("Hotbar") then
        return
    end

    -- Update weapon skills display when server tells us to
    Controller.LoadWeaponSkills()
end)

-- Note: Stamina updates are now handled client-side by the stamina_system
-- No need for network updates - the client ECS system updates the UI directly

-- Set up BridgeNet2 listener for Nen notifications
Bridges.NenNotification:Connect(function(data)
    -- Don't show during loading screen
    if _G.LoadingScreenActive then
        return
    end

    -- Show notification
    local NotificationManager = require(Replicated.Client.NotificationManager)
    NotificationManager.ShowNen(data.abilityName, data.message)
end)

-- Set up BridgeNet2 listener for Nen exhaustion (stamina depleted)
Bridges.NenExhausted:Connect(function(data)
    -- Don't show during loading screen
    if _G.LoadingScreenActive then
        return
    end

    -- Show exhaustion message with shake effect
    if Controller.nenIndicatorData and Controller.nenIndicatorData.showExhausted then
        Controller.nenIndicatorData.showExhausted()
    end

    -- Reset NenBasics state
    local NenBasics = require(Replicated.Client.Inputs.NenBasics)
    if NenBasics.ResetState then
        NenBasics.ResetState()
    end
end)

-- Set up BridgeNet2 listener for stamina drain rate updates from server
Bridges.NenStaminaDrain:Connect(function(data)
    -- Don't update during loading screen
    if _G.LoadingScreenActive then
        return
    end

    -- Update local stamina drain rate in ECS
    local ref = require(Replicated.Modules.ECS.jecs_ref)
    local world = require(Replicated.Modules.ECS.jecs_world)
    local comps = require(Replicated.Modules.ECS.jecs_components)

    local entity = ref.get("local_player")
    if not entity then
        warn("[Stats] Could not find local player entity for stamina drain update")
        return
    end

    local stamina = world:get(entity, comps.Stamina)
    if not stamina then
        -- Initialize if not exists
        stamina = {
            current = 100,
            max = 100,
            regenRate = 2,
            drainRate = 0,
        }
    end

    stamina.drainRate = data.drainRate or 0
    world:set(entity, comps.Stamina, stamina)

    print(`[Stats] Updated stamina drain rate to {stamina.drainRate}% per second for ability {data.abilityName}`)
end)

-- Money update function
Controller.Money = function(Value)
    if playerBarsData and playerBarsData.moneyValue then
        playerBarsData.moneyValue:set(Value or 0)
    end
end

-- Set up BridgeNet2 listener for money updates
Bridges.UpdateMoney:Connect(function(data)
    -- Don't update during loading screen or if UI isn't ready
    if _G.LoadingScreenActive then
        return
    end

    -- Update money value for the PlayerBars component
    if playerBarsData and playerBarsData.moneyValue then
        playerBarsData.moneyValue:set(data.money or 0)
    end
end)

-- Set up ByteNet listener for posture sync from server
-- This updates the Parry bar in PlayerBars to show current posture
Client.Packets.PostureSync.listen(function(data)
    -- Don't update during loading screen or if UI isn't ready
    if _G.LoadingScreenActive then
        return
    end

    -- Update the parry (posture) bar in PlayerBars
    if playerBarsData and playerBarsData.parryValue then
        -- data.Current is 0-100 posture value, data.Max is max posture
        local posturePercent = math.clamp((data.Current / data.Max) * 100, 0, 100)
        playerBarsData.parryValue:set(posturePercent)
    end
end)

return Controller;