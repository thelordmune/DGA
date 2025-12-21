local Controller = {}; local Client = require(script.Parent.Parent);
Controller.__index = Controller;
local self = setmetatable({}, Controller);
local Replicated = game:GetService("ReplicatedStorage")
local plr = game:GetService("Players").LocalPlayer
local Character = plr.Character or plr.CharacterAdded

local UI = Client.UI or plr.PlayerGui.ScreenGui;

-- Fusion-based Health Component
local HealthComponent = require(Replicated.Client.Components.Health)
local healthComponentData = nil

-- Track Fusion scopes for cleanup on death
local activeScopes = {}

-- Expose healthComponentData for DirectionalCasting to access
Controller.healthComponentData = healthComponentData

-- Cleanup function to destroy all UI scopes
Controller.CleanupUI = function()
	print("[Stats] 🧹 Cleaning up UI components...")

	-- Clean up health component
	if healthComponentData and healthComponentData.scope then
		healthComponentData.scope:doCleanup()
		print("[Stats] ✅ Health component scope cleaned up")
	end
	healthComponentData = nil
	Controller.healthComponentData = nil

	-- Clean up all tracked scopes
	for i, scopeData in ipairs(activeScopes) do
		if scopeData.scope then
			scopeData.scope:doCleanup()
			print(`[Stats] ✅ Cleaned up scope: {scopeData.name}`)
		end
	end
	table.clear(activeScopes)

	print("[Stats] ✅ All UI components cleaned up")
end

Controller.Check = function()
	if not UI or not UI:FindFirstChild("Stats") then
       local ui = Replicated.Assets.GUI.ScreenGui:Clone()
	   ui.Parent = plr.PlayerGui
	   UI = ui -- Update the UI reference
	   -- Reset health component data when UI is recreated
	   healthComponentData = nil
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

        -- Initialize the new Fusion-based Health component (or reinitialize after respawn)
        if not healthComponentData or not healthComponentData.frame.Parent then
            -- CLEANUP OLD HEALTH COMPONENT FIRST to prevent memory leak
            if healthComponentData and healthComponentData.scope then
                healthComponentData.scope:doCleanup()
               -- print("[Stats] 🧹 Cleaned up old Health component before creating new one")
            end

            healthComponentData = HealthComponent(statsFrame)
            Controller.healthComponentData = healthComponentData -- Update the exposed reference
           -- print("[Stats] ✅ New Health component initialized")
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

    -- Update the health value for the Fusion component
    if healthComponentData and healthComponentData.healthValue then
        local healthPercent = math.clamp((Value / MaxValue) * 100, 0, 100)
        healthComponentData.healthValue:set(healthPercent)
       -- print(`[Stats] Health updated: {healthPercent}%`)
    else
        warn("[Stats] Health component not initialized yet")
    end
end

Controller.Energy = function(Value, MaxValue)
    local scale = math.clamp(Value / MaxValue, 0, 1)
    Client.Service.TweenService:Create(UI.Stats.Container.Energy.Bar, TweenInfo.new(.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(scale, 0.635)
    }):Play()
end

Controller.LoadAlchemyMoves = function()
    local currentAlchemy = Client.Alchemy
    local Skills = require(game.ReplicatedStorage.Modules.Shared.Skills)

    if not Skills[currentAlchemy] then
        warn("Alchemy type not found:", currentAlchemy)
        return
    end

    -- Update hotbar to show directional casting info
    local alchemyInfo = Skills[currentAlchemy]

    -- Update hotbar slots to show casting controls
    Controller.UpdateHotbarSlot(8, "Cast (Z)")      -- Z key starts/stops casting
    Controller.UpdateHotbarSlot(9, "Modifier (X)")  -- X key enters modifier mode
    Controller.UpdateHotbarSlot(10, alchemyInfo.Type .. " Alchemy") -- Show alchemy type

    -- ---- print("📋 Loaded", alchemyInfo.Type, "alchemy - Use Z to cast, X for modifiers")
end

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

    local pent = ref.get("local_player")  -- No second parameter needed for local_player

    if not pent then
        warn("[LoadWeaponSkills] Player entity not found")
        return
    end

    ---- print("[LoadWeaponSkills] Loading weapon skills for player entity:", pent)

    -- Check if player has Hotbar and Inventory components
    -- Throw errors instead of returning so retry logic knows it failed
    if not world:has(pent, comps.Hotbar) then
        error("[LoadWeaponSkills] Player entity has no Hotbar component yet")
    end

    if not world:has(pent, comps.Inventory) then
        error("[LoadWeaponSkills] Player entity has no Inventory component yet")
    end

    local hotbar = world:get(pent, comps.Hotbar)
    local inventory = world:get(pent, comps.Inventory)

    ---- print("[LoadWeaponSkills] 📋 Hotbar slots:", hotbar.slots)
    ---- print("[LoadWeaponSkills] 📦 Inventory items count:", inventory.items and #inventory.items or 0)

    -- Get weapon skills from hotbar slots 1-7
    local skillsLoaded = 0
    for slotNumber = 1, 7 do
        local success3, item = pcall(InventoryManager.getHotbarItem, pent, slotNumber)
        if success3 and item then
            ---- print("[LoadWeaponSkills] Slot", slotNumber, "- Item:", item.name, "Type:", item.typ)
            if item.typ == "skill" then
                Controller.UpdateHotbarSlot(slotNumber, item.name)
                skillsLoaded = skillsLoaded + 1
            end
        else
            ---- print("[LoadWeaponSkills] Slot", slotNumber, "- Empty or error:", success3 and "empty" or item)
            Controller.UpdateHotbarSlot(slotNumber, "") -- Clear slot if no skill
        end
    end

    ---- print("[LoadWeaponSkills] ✅ Loaded", skillsLoaded, "weapon skills")
end

Controller.UpdateHotbarSlot = function(slotNumber, itemName)
    -- Check if UI and Hotbar exist before trying to access them
    if not UI or not UI:FindFirstChild("Hotbar") then
        return -- UI not ready yet, skip update
    end

    local hotbarName = slotNumber == 1 and "Hotbar" or "Hotbar" .. slotNumber
    local hotbar = UI.Hotbar:FindFirstChild(hotbarName)

    if hotbar then
        local textLabel = hotbar:FindFirstChild("Text")
        if textLabel then
            textLabel.Text = itemName or ""
        end
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
				print("[Stats] 🧹 Cleaned up old Hotbar scope before creating new one")
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


    local scope = scoped(Fusion, {
		Party = require(Replicated.Client.Components.Party)
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

-- Set up BridgeNet2 listener for adrenaline updates
Bridges.UpdateAdrenaline:Connect(function(data)
    -- Don't update during loading screen or if UI isn't ready
    if _G.LoadingScreenActive then
        return
    end

    -- Update adrenaline value for the Fusion component
    if healthComponentData and healthComponentData.adrenalineValue then
        healthComponentData.adrenalineValue:set(data.adrenaline)
    end
end)

-- Money update function
Controller.Money = function(Value)
    if healthComponentData and healthComponentData.moneyValue then
        healthComponentData.moneyValue:set(Value or 0)
    end
end

-- Set up BridgeNet2 listener for money updates
Bridges.UpdateMoney:Connect(function(data)
    -- Don't update during loading screen or if UI isn't ready
    if _G.LoadingScreenActive then
        return
    end

    -- Update money value for the Fusion component
    if healthComponentData and healthComponentData.moneyValue then
        healthComponentData.moneyValue:set(data.money or 0)
    end
end)

return Controller;