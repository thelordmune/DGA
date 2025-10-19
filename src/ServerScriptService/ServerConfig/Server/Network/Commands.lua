local NetworkModule = {}
local Server = require(script.Parent.Parent)
local Global = require(game.ReplicatedStorage.Modules.Shared.Global)

-- Available weapons and alchemy types
local VALID_WEAPONS = {"Fist", "Spear", "Augment", "Flame", "Stone", "Guns"}
local VALID_ALCHEMY = {"Stone", "Basic", "Flame"}

-- Helper function to check if value exists in table
local function tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if string.lower(v) == string.lower(value) then
            return v -- Return the properly cased version
        end
    end
    return false
end

-- Helper function to update client UI
local function updateClientUI(player, updateType)
    -- Send UI update signal to client
    if updateType == "weapon" then
        Server.Packets.WeaponUpdate.sendTo({
            Weapon = player:GetAttribute("Weapon")
        }, player)
    elseif updateType == "alchemy" then
        Server.Packets.AlchemyUpdate.sendTo({
            Alchemy = player:GetAttribute("Alchemy")
        }, player)
    end
end

-- Set weapon command
NetworkModule.SetWeapon = function(player, weaponName)
    -- print("SetWeapon called for player:", player.Name, "weapon:", weaponName)
    
    if not player or not player.Character then
        -- print("Player or character not found")
        return false, "Player or character not found"
    end
    
    -- Validate weapon name
    local validWeapon = tableContains(VALID_WEAPONS, weaponName)
    -- print("Valid weapon check:", validWeapon)
    if not validWeapon then
        return false, "Invalid weapon. Valid weapons: " .. table.concat(VALID_WEAPONS, ", ")
    end
    
    -- Get current player data using Global
    local currentData = Global.GetData(player)
    if not currentData then
        -- print("Could not get player data")
        return false, "Player data not found"
    end
    
    -- print("Current weapon:", currentData.Weapon, "New weapon:", validWeapon)
    
    -- Unequip current weapon if equipped
    local character = player.Character
    if character:GetAttribute("Equipped") then
        -- print("Unequipping current weapon before changing to:", validWeapon)
        Server.Modules.Network.Equip.UnequipWeapon(character, nil, true) -- Skip animation
    end
    
    -- Update player data using Global.SetData
    Global.SetData(player, function(data)
        data.Weapon = validWeapon
        return data
    end)
    
    -- Update player attribute for immediate access
    player:SetAttribute("Weapon", validWeapon)
    
    -- Update entity weapon if available
    local playerClass = Server.Modules["Players"].Get(player)
    if playerClass and playerClass.Entity then
        playerClass.Entity.Weapon = validWeapon
    end
    
    -- Update ECS component if available
    local world = require(game.ReplicatedStorage.Modules.ECS.jecs_world)
    local comps = require(game.ReplicatedStorage.Modules.ECS.jecs_components)
    local ref = require(game.ReplicatedStorage.Modules.ECS.jecs_ref)
    
    local entity = ref.get("player", player)
    if entity and world:has(entity, comps.Combat) then
        local combat = world:get(entity, comps.Combat)
        combat.weapon = validWeapon
        combat.equipped = false -- Reset equipped state
        world:set(entity, comps.Combat, combat)
        
        -- Update weapon component
        if world:has(entity, comps.Weapon) then
            world:set(entity, comps.Weapon, {name = validWeapon, type = validWeapon})
        end
    end
    
    -- Give weapon skills
    if entity then
        local InventorySetup = require(game.ReplicatedStorage.Modules.Utils.InventorySetup)
        task.delay(0.5, function()
            InventorySetup.GiveWeaponSkills(entity, validWeapon, player)
        end)
    end
    
    -- Update client UI
    updateClientUI(player, "weapon")
    
    -- print("Weapon successfully set to:", validWeapon)
    return true, "Weapon set to: " .. validWeapon
end

-- Set alchemy command
NetworkModule.SetAlchemy = function(player, alchemyName)
    -- print("SetAlchemy called for player:", player.Name, "alchemy:", alchemyName)
    
    if not player or not player.Character then
        -- print("Player or character not found")
        return false, "Player or character not found"
    end
    
    -- Validate alchemy name
    local validAlchemy = tableContains(VALID_ALCHEMY, alchemyName)
    -- print("Valid alchemy check:", validAlchemy)
    if not validAlchemy then
        return false, "Invalid alchemy. Valid alchemy types: " .. table.concat(VALID_ALCHEMY, ", ")
    end
    
    -- Get current player data using Global
    local currentData = Global.GetData(player)
    if not currentData then
        -- print("Could not get player data")
        return false, "Player data not found"
    end
    
    -- print("Current alchemy:", currentData.Alchemy, "New alchemy:", validAlchemy)
    
    -- Update player data using Global.SetData
    Global.SetData(player, function(data)
        data.Alchemy = validAlchemy
        return data
    end)
    
    -- Update player attribute for immediate access
    player:SetAttribute("Alchemy", validAlchemy)
    
    -- Update client UI
    updateClientUI(player, "alchemy")
    
    -- print("Alchemy successfully set to:", validAlchemy)
    return true, "Alchemy set to: " .. validAlchemy
end

-- Chat command handler
NetworkModule.HandleChatCommand = function(player, message)
    -- print("HandleChatCommand called with:", message)
    
    -- Check for set commands (without /e prefix)
    local parts = {}
    for part in string.gmatch(message, "%S+") do
        table.insert(parts, part)
    end
    
    -- print("Command parts:", table.concat(parts, ", "))
    
    if #parts < 3 then
        return false, "Usage: set Weapon <weaponname> or set Alchemy <alchemyname>"
    end
    
    -- Check if first word is "set"
    if string.lower(parts[1]) ~= "set" then
        return false, "Command must start with 'set'"
    end
    
    local setType = string.lower(parts[2])
    local setValue = parts[3]
    
    -- print("Set type:", setType, "Set value:", setValue)
    
    if setType == "weapon" then
        -- print("Calling SetWeapon with:", setValue)
        return NetworkModule.SetWeapon(player, setValue)
    elseif setType == "alchemy" then
        -- print("Calling SetAlchemy with:", setValue)
        return NetworkModule.SetAlchemy(player, setValue)
    else
        return false, "Invalid set type. Use 'Weapon' or 'Alchemy'"
    end
end

return NetworkModule
