-- Weapon/Alchemy Changer Script
-- Place this script in ServerScriptService
-- Make sure the part in workspace has the weapon/alchemy name as its Name property

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Get the Server module for weapon changing
local Server = require(script.Parent.ServerConfig.Server)

-- Configuration
local PART_NAME = "WeaponChangerPart" -- Change this to your part's name in workspace
local CHANGE_COOLDOWN = 2 -- Seconds between weapon changes per player

-- Track cooldowns per player
local playerCooldowns = {}

-- Function to change player's weapon/alchemy
local function changePlayerWeapon(player, weaponName)
    local character = player.Character
    if not character then return end
    
    -- Get the player's entity from the server system
    local entity = Server.Modules.Entities.Get(character)
    if not entity then
        warn("Could not find entity for player:", player.Name)
        return
    end
    
    -- Change the weapon
    entity.Weapon = weaponName
    
    -- Set the equipped attribute
    character:SetAttribute("Equipped", true)
    
    -- Update any visual indicators or UI
    -- print("Changed", player.Name, "weapon to:", weaponName)
    
    -- Optional: Send a message to the player
    -- You can uncomment this if you have a messaging system
    -- Server.Packets.Message.sendTo({Text = "Weapon changed to: " .. weaponName}, player)
end

-- Function to handle when a player touches the part
local function onPartTouched(hit, part)
    local humanoid = hit.Parent:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local player = Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end
    
    -- Check cooldown
    local currentTime = tick()
    if playerCooldowns[player.UserId] and currentTime - playerCooldowns[player.UserId] < CHANGE_COOLDOWN then
        return
    end
    
    -- Update cooldown
    playerCooldowns[player.UserId] = currentTime
    
    -- Get the weapon name from the part's name
    local weaponName = part.Name
    
    -- Change the player's weapon
    changePlayerWeapon(player, weaponName)
end

-- Function to setup a weapon changer part
local function setupWeaponChanger(part)
    if not part:IsA("BasePart") then return end
    
    -- print("Setting up weapon changer for part:", part.Name)
    
    -- Connect the touch event
    local connection
    connection = part.Touched:Connect(function(hit)
        onPartTouched(hit, part)
    end)
    
    -- Clean up connection when part is removed
    part.AncestryChanged:Connect(function()
        if not part.Parent then
            connection:Disconnect()
            -- print("Cleaned up weapon changer for:", part.Name)
        end
    end)
end

-- Auto-setup for parts with specific names or tags
local function autoSetupWeaponChangers()
    -- Method 1: Setup by part name (if you know the exact name)
    local specificPart = workspace:FindFirstChild(PART_NAME)
    if specificPart then
        setupWeaponChanger(specificPart)
    end
    
    -- Method 2: Setup all parts with a specific tag
    -- Uncomment this if you want to use CollectionService tags
    --[[
    local CollectionService = game:GetService("CollectionService")
    local taggedParts = CollectionService:GetTagged("WeaponChanger")
    for _, part in pairs(taggedParts) do
        setupWeaponChanger(part)
    end
    
    -- Listen for new tagged parts
    CollectionService:GetInstanceAddedSignal("WeaponChanger"):Connect(setupWeaponChanger)
    --]]
    
    -- Method 3: Setup all parts in a specific folder
    -- Uncomment this if you have a folder containing weapon changer parts
    --[[
    local weaponChangerFolder = workspace:FindFirstChild("WeaponChangers")
    if weaponChangerFolder then
        for _, part in pairs(weaponChangerFolder:GetChildren()) do
            if part:IsA("BasePart") then
                setupWeaponChanger(part)
            end
        end
        
        -- Listen for new parts added to the folder
        weaponChangerFolder.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then
                setupWeaponChanger(child)
            end
        end)
    end
    --]]
end

-- Clean up cooldowns when players leave
Players.PlayerRemoving:Connect(function(player)
    playerCooldowns[player.UserId] = nil
end)

-- Wait a bit for the game to load, then setup weapon changers
task.wait(3)
autoSetupWeaponChangers()

-- print("Weapon Changer script loaded!")
