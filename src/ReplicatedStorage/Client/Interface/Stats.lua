local Controller = {}; local Client = require(script.Parent.Parent);
Controller.__index = Controller;
local self = setmetatable({}, Controller);
local Replicated = game:GetService("ReplicatedStorage")
local plr = game:GetService("Players").LocalPlayer
local Character = plr.Character or plr.CharacterAdded

local UI = Client.UI or plr.PlayerGui.ScreenGui;

Controller.Check = function()
	if not UI or not UI:FindFirstChild("Stats") then
       local ui = Replicated.Assets.GUI.ScreenGui:Clone()
	   ui.Parent = plr.PlayerGui
	   UI = ui -- Update the UI reference
        return
    end
end

Controller.Health = function(Value, MaxValue)
	if not UI or not UI:FindFirstChild("Stats") then
        UI = plr.PlayerGui.ScreenGui
        return
    end
    local scale = math.clamp(Value / MaxValue, 0, 1)
    Client.Service.TweenService:Create(UI.Stats.Container.Health.Bar, TweenInfo.new(.1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), {
        Size = UDim2.fromScale(scale, 0.635)
    }):Play()
    Client.Service.TweenService:Create(UI.Stats.Container.Health:WaitForChild("Shadow"), TweenInfo.new(.1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), {
        Size = UDim2.fromScale(scale, 0.635)
    }):Play()
end

Controller.Posture = function(Value, MaxValue)
    local scale = math.clamp(Value / MaxValue, 0, 1)
    UI.Stats.Container.Posture.Bar.Size = UDim2.new(scale, 0, 0.3, 0)
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

    -- print("📋 Loaded", alchemyInfo.Type, "alchemy - Use Z to cast, X for modifiers")
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

    print("[LoadWeaponSkills] Loading weapon skills for player entity:", pent)

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

    print("[LoadWeaponSkills] 📋 Hotbar slots:", hotbar.slots)
    print("[LoadWeaponSkills] 📦 Inventory items count:", inventory.items and #inventory.items or 0)

    -- Get weapon skills from hotbar slots 1-7
    local skillsLoaded = 0
    for slotNumber = 1, 7 do
        local success3, item = pcall(InventoryManager.getHotbarItem, pent, slotNumber)
        if success3 and item then
            print("[LoadWeaponSkills] Slot", slotNumber, "- Item:", item.name, "Type:", item.typ)
            if item.typ == "skill" then
                Controller.UpdateHotbarSlot(slotNumber, item.name)
                skillsLoaded = skillsLoaded + 1
            end
        else
            print("[LoadWeaponSkills] Slot", slotNumber, "- Empty or error:", success3 and "empty" or item)
            Controller.UpdateHotbarSlot(slotNumber, "") -- Clear slot if no skill
        end
    end

    print("[LoadWeaponSkills] ✅ Loaded", skillsLoaded, "weapon skills")
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

Controller.Hotbar = function(Order: string)
    repeat task.wait() until Character
    if Order == "Initiate" then
        -- Get the existing hotbar container
        local hotbarContainer = UI.Hotbar.Hotbar
        
        -- Store original transparency values for all visual elements
        local originalProperties = {}
        
        -- Function to recursively store original transparency values
        local function storeOriginalProperties(object, propertiesTable)
            propertiesTable = propertiesTable or originalProperties
            if object:IsA("GuiObject") then
                propertiesTable[object] = {
                    BackgroundTransparency = object.BackgroundTransparency
                }
                
                -- Only store text transparency if it's a text-based object
                if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                    propertiesTable[object].TextTransparency = object.TextTransparency
                end
                
                -- Only store image transparency if it's an image-based object
                if object:IsA("ImageLabel") or object:IsA("ImageButton") then
                    propertiesTable[object].ImageTransparency = object.ImageTransparency
                end
                
            end
            
            -- Recursively process children
            for _, child in ipairs(object:GetChildren()) do
                storeOriginalProperties(child, propertiesTable)
            end
        end
        
        -- Function to set all transparencies to 1 (fully transparent)
        local function setTransparent(object)
            if object:IsA("GuiObject") then
                object.BackgroundTransparency = 1
                
                if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                    object.TextTransparency = 1
                end
                
                if object:IsA("ImageLabel") or object:IsA("ImageButton") then
                    object.ImageTransparency = 1
                end
            end
            
            -- Recursively process children
            for _, child in ipairs(object:GetChildren()) do
                setTransparent(child)
            end
        end
        
        -- Function to tween back to original transparency with proper type checking
        local function tweenToOriginal(object, propertiesTable)
            propertiesTable = propertiesTable or originalProperties
            if propertiesTable[object] then
                local props = propertiesTable[object]
                
                -- Tween background transparency (always exists for GuiObjects)
                Client.Service.TweenService:Create(object, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundTransparency = props.BackgroundTransparency
                }):Play()
                
                -- Tween text transparency only if it exists and the object supports it
                if props.TextTransparency ~= nil and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
                    Client.Service.TweenService:Create(object, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        TextTransparency = props.TextTransparency
                    }):Play()
                end
                
                -- Tween image transparency only if it exists and the object supports it
                if props.ImageTransparency ~= nil and (object:IsA("ImageLabel") or object:IsA("ImageButton")) then
                    Client.Service.TweenService:Create(object, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        ImageTransparency = props.ImageTransparency
                    }):Play()
                end
            end
            
            -- Recursively process children
            for _, child in ipairs(object:GetChildren()) do
                if child:IsA("GuiObject") then
                    tweenToOriginal(child, propertiesTable)
                end
            end
        end
        
        -- Store original properties of the template hotbar
        storeOriginalProperties(hotbarContainer)
        
        -- First, set the key labels for the template hotbar
        local imageLabel = hotbarContainer:FindFirstChild("ImageLabel")
        if imageLabel then
            local keyLabel = imageLabel:FindFirstChild("TextLabel")
            if keyLabel then
                keyLabel.Text = "1"
            end
        end
        
        -- Set the template to transparent initially
        setTransparent(hotbarContainer)
        
        -- Tween the template hotbar back to visible
        tweenToOriginal(hotbarContainer)
        
        -- Create 9 additional hotbars with delay
        task.delay(2, function()
        for i = 2, 10 do
            task.wait(0.05) -- Small delay between creating each hotbar

            local newHotbar = hotbarContainer:Clone()
            newHotbar.Name = "Hotbar" .. i
            newHotbar.Parent = UI.Hotbar

            -- Set the key label for this hotbar
            local newImageLabel = newHotbar:FindFirstChild("ImageLabel")
            if newImageLabel then
                local newKeyLabel = newImageLabel:FindFirstChild("TextLabel")
                if newKeyLabel then
                    if i <= 7 then
                        newKeyLabel.Text = tostring(i)
                    elseif i == 8 then
                        newKeyLabel.Text = "Z"
                    elseif i == 9 then
                        newKeyLabel.Text = "X"
                    elseif i == 10 then
                        newKeyLabel.Text = "C"
                    end
                end
            end

            -- Position the new hotbar next to the previous on
            -- Store the original properties for this specific hotbar
            local hotbarProperties = {}
            storeOriginalProperties(newHotbar, hotbarProperties)

            -- Set the new hotbar to transparent initially
            setTransparent(newHotbar)

            -- Tween it to visible after a short delay
            task.delay(2, function()
                task.wait(0.1 * (i-1)) -- Staggered delay based on index
                tweenToOriginal(newHotbar, hotbarProperties)
            end)
        end
         for i = 1, 10 do
            local hotbarName = i == 1 and "Hotbar" or "Hotbar" .. i
            local hotbar = UI.Hotbar:FindFirstChild(hotbarName)
            if hotbar then
                hotbar.Visible = true
            end
        end

        -- Load alchemy moves first
        task.wait(0.1)
        Controller.LoadAlchemyMoves()

        -- Load weapon skills LAST with retry mechanism to ensure everything is ready
        task.wait(0.5) -- Extra delay to ensure all systems are initialized
        local weaponSkillsLoaded = false
        local maxAttempts = 5
        local attempt = 0

        while not weaponSkillsLoaded and attempt < maxAttempts do
            attempt = attempt + 1
            local success, err = pcall(function()
                Controller.LoadWeaponSkills()
            end)

            if success then
                weaponSkillsLoaded = true
                print("✅ Weapon skills loaded successfully on attempt", attempt)
            else
                warn("⚠️ Failed to load weapon skills (attempt " .. attempt .. "/" .. maxAttempts .. "):", err)
                if attempt < maxAttempts then
                    task.wait(0.5) -- Wait before retry
                end
            end
        end

        if not weaponSkillsLoaded then
            warn("❌ Failed to load weapon skills after", maxAttempts, "attempts")
        end
        end)
        
        
        -- Make all hotbars visible
       
    elseif Order == "Update" then
        Controller.LoadAlchemyMoves()
        Controller.LoadWeaponSkills()
    end
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
					print("activated party button")
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

return Controller;