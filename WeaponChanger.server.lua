-- Weapon Changer Script
-- Place this script directly inside a part in workspace
-- The part's name will be the weapon name that players get when they touch it

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Get the part this script is inside
local part = script.Parent
if not part:IsA("BasePart") then
    error("WeaponChanger script must be placed inside a BasePart!")
end

-- Get the Server module and Global functions
local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
local Global = require(game:GetService("ReplicatedStorage").Modules.Shared.Global)

-- Configuration
local CHANGE_COOLDOWN = 2 -- Seconds between weapon changes per player
local WEAPON_NAME = part.Name -- Use the part's name as the weapon name

-- Track cooldowns per player
local playerCooldowns = {}

-- Function to change player's weapon
local function changePlayerWeapon(player, weaponName)
    local character = player.Character
    if not character then return end

    -- Check if player already has this weapon
    local currentWeapon = player:GetAttribute("Weapon")
    if currentWeapon == weaponName then
        ---- print("Player", player.Name, "already has weapon:", weaponName)
        return
    end

    -- Use the safe cleanup function from the equip system
    Server.Modules.Network.Equip.CleanupCharacterEquipState(character)

    -- Update player data using Global.SetData (persistent storage)
    Global.SetData(player, function(data)
        data.Weapon = weaponName
        return data
    end)

    -- Update player attribute for immediate access
    player:SetAttribute("Weapon", weaponName)

    -- Update entity weapon if available
    local playerClass = Server.Modules["Players"].Get(player)
    if playerClass and playerClass.Entity then
        playerClass.Entity.Weapon = weaponName
    end

    -- Update ECS component if available
    local world = require(game.ReplicatedStorage.Modules.ECS.jecs_world)
    local comps = require(game.ReplicatedStorage.Modules.ECS.jecs_components)
    local ref = require(game.ReplicatedStorage.Modules.ECS.jecs_ref)
    local InventorySetup = require(game.ReplicatedStorage.Modules.Utils.InventorySetup)

    local entity = ref.get("player", player)
    if entity and world:has(entity, comps.Combat) then
        local combat = world:get(entity, comps.Combat)
        combat.weapon = weaponName
        combat.equipped = false -- Reset equipped state
        world:set(entity, comps.Combat, combat)

        -- Update weapon component
        if world:has(entity, comps.Weapon) then
            world:set(entity, comps.Weapon, {name = weaponName, type = weaponName})
        end

        -- Give weapon skills to update hotbar
        task.delay(0.1, function()
            InventorySetup.GiveWeaponSkills(entity, weaponName, player)
        end)
    end

    -- Update client weapon (send packet to update UI)
    if Server.Packets and Server.Packets.WeaponUpdate then
        Server.Packets.WeaponUpdate.sendTo({
            Weapon = weaponName
        }, player)
    end

    -- Optional: Add visual feedback
    local highlight = Instance.new("Highlight")
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.FillColor = Color3.fromRGB(0, 255, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0.3
    highlight.Parent = character

    game:GetService("Debris"):AddItem(highlight, 1)

    ---- print("Changed", player.Name, "weapon to:", weaponName)
end

-- Function to handle when a player touches the part
local function onPartTouched(hit)
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
    
    -- Change the player's weapon
    changePlayerWeapon(player, WEAPON_NAME)
    
    -- Optional: Add part visual feedback
    local originalColor = part.Color
    part.Color = Color3.fromRGB(0, 255, 0)
    task.wait(0.2)
    part.Color = originalColor
end

-- Connect the touch event
local connection = part.Touched:Connect(onPartTouched)

-- Clean up cooldowns when players leave
local playerLeavingConnection = Players.PlayerRemoving:Connect(function(player)
    playerCooldowns[player.UserId] = nil
end)

-- Clean up connections when part is removed
part.AncestryChanged:Connect(function()
    if not part.Parent then
        connection:Disconnect()
        playerLeavingConnection:Disconnect()
        ---- print("Weapon changer cleaned up for:", WEAPON_NAME)
    end
end)

---- print("Weapon changer active for:", WEAPON_NAME)
