local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule

local Replicated = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Stats = require(ServerStorage.Stats._Weapons)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local world = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_world)
local comps = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_components)
local ref = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_ref)
local Bridges = require(Replicated.Modules.Bridges)

local self = setmetatable({}, NetworkModule)

type Dia = {
    npc: Model,
    name: string,
    inrange: boolean,
    state: string,
    currentnode: Configuration,
}

local pent
NetworkModule.EndPoint = function(Player, Data)
    print("=== EQUIP ENDPOINT CALLED ===")
    print("Player:", Player.Name)

    local Character: Model = Player.Character
    print("Character exists:", Character ~= nil)

    if pent == nil then
        pent = ref.get("local_player", Player)
        print("Created pent for player")
    end

    local PlayerEntity = Server.Modules["Players"].Get(Player)
    print("PlayerEntity exists:", PlayerEntity ~= nil)

    if not PlayerEntity or not Character then
        print("Early return: Missing PlayerEntity or Character")
        return
    end

    NetworkModule.EquipWeapon(Character, Player:GetAttribute("Weapon"))
end

-- New function that works with both players and NPCs
NetworkModule.EquipWeapon = function(Character: Model, WeaponName: string?, skipAnimation: boolean?)
    if not Character then
        print("Early return: No character provided")
        return
    end

    -- Get weapon name from character attribute if not provided
    WeaponName = WeaponName or Character:GetAttribute("Weapon")
    if not WeaponName then
        print("Early return: No weapon specified")
        return
    end

    print("=== EQUIPPING WEAPON ===")
    print("Character:", Character.Name, "Weapon:", WeaponName)

    local AnimationSet = Replicated.Assets.Animations.Weapons[WeaponName]
    local WeaponFolder: Folder? = ServerStorage.Assets.Models.Weapons[WeaponName]

    -- Clean up any stuck states first (fix for respawn issues)
    if Character:FindFirstChild("Actions") then
        -- Remove any stuck Equip states
        if Library.StateCheck(Character.Actions, "Equip") then
            Library.RemoveState(Character.Actions, "Equip")
            print("Cleaned up stuck Equip state")
        end

        -- Check if character has other active states (but allow if only Equip was stuck)
        if Library.StateCount(Character.Actions) then
            print("Early return: Character has active states")
            return
        end
    end

    local isEquipped = Character:GetAttribute("Equipped")
    print("Currently equipped:", isEquipped)

    if not isEquipped then
        Character:SetAttribute("Equipped", true)

        -- Play animation only if not skipping and AnimationSet exists
        local EquipAnimation
        if not skipAnimation and AnimationSet then
            EquipAnimation = Library.PlayAnimation(Character, AnimationSet.Equip)
            -- EquipAnimation:Play()
            EquipAnimation.Priority = Enum.AnimationPriority.Action
            for _, v in Character:GetDescendants() do
                if v:GetAttribute("WeaponTrail") then
                    v.Enabled = true
                end
            end
            print("Equip animation started")

            -- Play sound if character has a player
            local Player = game.Players:GetPlayerFromCharacter(Character)
            if Player then
                local Sound = Server.Library.PlaySound(
                    Character,
                    Server.Service.ReplicatedStorage.Assets.SFX.Weapons[WeaponName].Unsheathe
                )
                print("Equip sound played")
            end

            -- Add state only for players
            if Character:FindFirstChild("Actions") then
                Library.AddState(Character.Actions, "Equip")
                print("Added Equip state")
            end
        end

        local blacklist = {
            "Flame",
            "Fist",
        }

        if WeaponFolder and not table.find(blacklist, WeaponName) then
            print("=== SPAWNING WEAPON PARTS ===")

            if not Character:FindFirstChild(WeaponName) then
                print("Weapon not found in character, creating new parts")
                local weaponParts = ServerStorage.Assets.Models.Weapons[WeaponName]:GetChildren()

                for _, WepPart in pairs(weaponParts) do
                    print("Processing weapon part:", WepPart.Name)
                    local PotentialPart = WepPart:Clone()

                    if PotentialPart:FindFirstChild("Equip") then
                        if PotentialPart.Equip:GetAttribute("Part0") then
                            PotentialPart.Equip.Part0 = Character[PotentialPart.Equip:GetAttribute("Part0")]
                        else
                            PotentialPart.Equip.Part1 = Character[PotentialPart.Equip:GetAttribute("Part1")]
                        end
                    elseif PotentialPart:FindFirstChild("TorsoWeld") then
                        if PotentialPart.TorsoWeld:GetAttribute("Part0") then
                            PotentialPart.TorsoWeld.Part0 = Character[PotentialPart.TorsoWeld:GetAttribute("Part0")]
                        else
                            PotentialPart.TorsoWeld.Part1 = Character[PotentialPart.TorsoWeld:GetAttribute("Part1")]
                        end
                    end

                    PotentialPart.Parent = Character
                    print("Added", PotentialPart.Name, "to character")
                end
            else
                print("Weapon already exists in character, reconnecting welds")
                for _, PotentialPart in pairs(Character:GetChildren()) do
                    if PotentialPart:GetAttribute("Weapon") and PotentialPart:FindFirstChild("Equip") then
                        if PotentialPart.Equip:GetAttribute("Part0") then
                            PotentialPart.Equip.Part0 = Character[PotentialPart.Equip:GetAttribute("Part0")]
                        else
                            PotentialPart.Equip.Part1 = Character[PotentialPart.Equip:GetAttribute("Part1")]
                        end

                        if PotentialPart:FindFirstChild("Unequip") then
                            if PotentialPart.Unequip:GetAttribute("Part0") then
                                PotentialPart.Unequip.Part0 = nil
                            else
                                PotentialPart.Unequip.Part1 = nil
                            end
                        end
                    end
                end
            end
        end

        -- Handle animation completion
        if EquipAnimation then
            EquipAnimation.Stopped:Once(function()
                if Character:FindFirstChild("Actions") then
                    Library.RemoveState(Character.Actions, "Equip")
                    print("Removed Equip state")
                end
                for _, v in Character:GetDescendants() do
                    if v:GetAttribute("WeaponTrail") then
                        v.Enabled = false
                    end
                end
            end)
        else
            -- If no animation, immediately remove the Equip state
            if Character:FindFirstChild("Actions") then
                Library.RemoveState(Character.Actions, "Equip")
                print("Removed Equip state (no animation)")
            end
        end
    else
        NetworkModule.UnequipWeapon(Character, WeaponName, skipAnimation)
    end
    print("=== EQUIP FINISHED ===")
end

NetworkModule.UnequipWeapon = function(Character: Model, WeaponName: string?, skipAnimation: boolean?)
    if not Character then
        return
    end

    WeaponName = WeaponName or Character:GetAttribute("Weapon")
    if not WeaponName then
        return
    end

    print("=== UNEQUIPPING WEAPON ===")
    Character:SetAttribute("Equipped", nil)

    local AnimationSet = Replicated.Assets.Animations.Weapons[WeaponName]
    local EquipAnimation

    if not skipAnimation and AnimationSet then
        EquipAnimation = Library.PlayAnimation(Character, AnimationSet.Unequip)
        -- EquipAnimation:Play()
        EquipAnimation.Priority = Enum.AnimationPriority.Action
        for _, v in Character:GetDescendants() do
            if v:GetAttribute("WeaponTrail") then
                v.Enabled = true
            end
        end

        if Character:FindFirstChild("Actions") then
            Library.AddState(Character.Actions, "Equip")
        end

        local Player = game.Players:GetPlayerFromCharacter(Character)
        if Player then
            local Sound = Server.Library.PlaySound(Character, Server.Service.ReplicatedStorage.Assets.SFX.Weapons[WeaponName].Sheathe)
        end
    end

    local function disconnectWelds()
        for _, PotentialPart in pairs(Character:GetChildren()) do
            if PotentialPart:GetAttribute("Weapon") and PotentialPart:FindFirstChild("Equip") then
                if PotentialPart.Equip:GetAttribute("Part0") then
                    PotentialPart.Equip.Part0 = nil
                else
                    PotentialPart.Equip.Part1 = nil
                end

                if PotentialPart:FindFirstChild("Unequip") then
                    if PotentialPart.Unequip:GetAttribute("Part0") then
                        PotentialPart.Unequip.Part0 = Character[PotentialPart.Unequip:GetAttribute("Part0")]
                    else
                        PotentialPart.Unequip.Part1 = Character[PotentialPart.Unequip:GetAttribute("Part1")]
                    end
                end
            end
        end
    end

    -- Remove weapon parts completely instead of just disconnecting welds
    local function removeWeaponParts()
        local blacklist = {"Flame", "Fist"}
        if not table.find(blacklist, WeaponName) then
            for _, PotentialPart in pairs(Character:GetChildren()) do
                if PotentialPart:GetAttribute("Weapon") then
                    print("Removing weapon part:", PotentialPart.Name)
                    PotentialPart:Destroy()
                end
            end
        end
    end

    if EquipAnimation then
        EquipAnimation.Stopped:Once(function()
            for _, v in Character:GetDescendants() do
                if v:GetAttribute("WeaponTrail") then
                    v.Enabled = false
                end
            end
            if Character:FindFirstChild("Actions") then
                Library.RemoveState(Character.Actions, "Equip")
            end
            removeWeaponParts()
        end)
    else
        removeWeaponParts()
    end
end

NetworkModule.RemoveWeapon = function(PlayerOrCharacter)
    local Character
    if PlayerOrCharacter.Character then
        -- It's a Player
        Character = PlayerOrCharacter.Character
        print("=== REMOVING WEAPON ===")
        print("Player:", PlayerOrCharacter.Name)
    else
        -- It's a Character
        Character = PlayerOrCharacter
        print("=== REMOVING WEAPON ===")
        print("Character:", Character.Name)
    end

    if not Character then
        print("Early return: No character")
        return
    end

    local removedCount = 0
    for i, v in pairs(Character:GetChildren()) do
        if v:GetAttribute("Weapon") then
            print("Removing weapon part:", v.Name)
            v:Destroy()
            removedCount = removedCount + 1
        end
    end
    print("Removed", removedCount, "weapon parts")
end

-- Cleanup function to call when character is being removed/respawning
NetworkModule.CleanupCharacterEquipState = function(Character: Model)
    if not Character then return end

    print("=== CLEANING UP EQUIP STATE ===")
    print("Character:", Character.Name)

    -- Remove any stuck equip states
    if Character:FindFirstChild("Actions") then
        if Library.StateCheck(Character.Actions, "Equip") then
            Library.RemoveState(Character.Actions, "Equip")
            print("Cleaned up stuck Equip state on character removal")
        end
    end

    -- Reset equipped attribute
    Character:SetAttribute("Equipped", false)

    -- Remove all weapon parts
    NetworkModule.RemoveWeapon(Character)

    print("=== EQUIP STATE CLEANUP COMPLETE ===")
end

return NetworkModule