local Controller = {}; local Client = require(script.Parent.Parent);
Controller.__index = Controller;
local self = setmetatable({}, Controller);
local Replicaetd = game:GetService("ReplicatedStorage")
local plr = game:GetService("Players").LocalPlayer
local Character = plr.Character or plr.CharacterAdded

local UI = Client.UI or plr.PlayerGui.ScreenGui;

Controller.Check = function()
	if not UI or not UI:FindFirstChild("Stats") then
       local ui = Replicaetd.Assets.GUI.ScreenGui:Clone()
	   ui.Parent = plr.PlayerGui
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
    
    local alchemyMoves = Skills[currentAlchemy]
    
    -- Map moves to hotbar slots (Z=8, X=9, C=10)
    local moveSlots = {
        [8] = alchemyMoves.ZMove,  -- Z key
        [9] = alchemyMoves.XMove,  -- X key  
        [10] = alchemyMoves.CMove  -- C key
    }
    
    -- Update hotbar text for alchemy moves
    for slotNumber, moveName in pairs(moveSlots) do
        Controller.UpdateHotbarSlot(slotNumber, moveName)
    end
end

Controller.UpdateHotbarSlot = function(slotNumber, itemName)
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
        task.wait(0.1)
        Controller.LoadAlchemyMoves()
        end)
        
        
        -- Make all hotbars visible
       
    elseif Order == "Update" then
        Controller.LoadAlchemyMoves()
    end
end

return Controller;