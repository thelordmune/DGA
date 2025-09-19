local Appearance = {}; 
local Server = require(script.Parent.Parent);
Appearance.__index = Appearance;
local self = setmetatable({}, Appearance);

local replicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local customizationData = require(replicatedStorage.Modules.CustomizationData)

local function getSpinResult()
    local roll = math.random(1, 1000)
    if roll <= 10 then return "Common"
    elseif roll <= 100 then return "Common"
    else return "Common" end
end

local function positionHairManually(accessory, head)
    local handle = accessory:FindFirstChild("Handle")
    local headAttachment = head:FindFirstChild("HairAttachment")
    local hairAttachment = handle and handle:FindFirstChild("HairAttachment")

    if handle and hairAttachment and headAttachment then
        handle.CFrame = headAttachment.WorldCFrame * hairAttachment.CFrame:Inverse()
    end
end

local function applyPlayerHairToDummy(character, humanoid, player, hairColor)
    local humanoidDescription = Players:GetHumanoidDescriptionFromUserId(player.UserId)
    local hairAccessoryIDs = humanoidDescription.HairAccessory
    
    if hairAccessoryIDs and hairAccessoryIDs ~= "" then
        local hairIDList = string.split(hairAccessoryIDs, ",")

        for _, hairID in ipairs(hairIDList) do
            local success, accessoryModel = pcall(function()
                return InsertService:LoadAsset(tonumber(hairID))
            end)

            if success and accessoryModel then
                local accessory = accessoryModel:FindFirstChildWhichIsA("Accessory")
                if accessory then
                    local handle = accessory:FindFirstChild("Handle")
                    humanoid:AddAccessory(accessory)
                    
                    local head = character:FindFirstChild("Head")
                    if head then
                        positionHairManually(accessory, head)
                        
                        if handle and handle:FindFirstChildOfClass("SpecialMesh") then
                            local mesh = handle:FindFirstChildOfClass("SpecialMesh")
                            mesh.TextureId = "rbxassetid://120868826325554"
                            mesh.VertexColor = Vector3.new(hairColor.R, hairColor.G, hairColor.B)
                            handle.Material = Enum.Material.CorrodedMetal
                            handle.Color = hairColor
                        end
                    end
                end
            end
        end
    end
end

local function racespin()
    local roll = math.random(1, 3)
    if roll == 1 then return "Amestrian"
    elseif roll == 2 then return "Ishvalan"
    elseif roll == 3 then return "Xing" end
end

local function varspin()
    local roll = math.random(1, 3)
    if roll == 1 then return "variant1"
    elseif roll == 2 then return "variant2"
    elseif roll == 3 then return "variant3" end
end

Appearance.Load = function(Player : Player)
    local PlayerClass = Server.Modules["Players"].Get(Player);
    if not PlayerClass or not PlayerClass.Character or not PlayerClass.Data then return end;

    local character = PlayerClass.Character
    local humanoid = character:WaitForChild("Humanoid")
    local playerData = PlayerClass.Data

    -- Ensure Shirt and Pants exist
    if not character:FindFirstChild("Shirt") then
        Instance.new("Shirt", character)
    end
    if not character:FindFirstChild("Pants") then
        Instance.new("Pants", character)
    end

    if playerData.FirstJoin == true then
        local raceSpinner = racespin()
        local rarity = getSpinResult()
        local variant = varspin()
        local initialOutfit = math.random(1, 2)

        -- Set initial data
        PlayerClass.Data.Customization.Outfit = initialOutfit
        
        local Race = customizationData.Races[raceSpinner]
        local RaceTable = customizationData.Races[raceSpinner]

        if RaceTable then
            local SkinColor = RaceTable[variant]
            PlayerClass.Data.Customization.SkinColor = SkinColor
        else
            warn("Invalid race: " .. tostring(raceSpinner))
        end
        
        PlayerClass.Data.FL_Name.First = customizationData.FirstNames[math.random(1, #customizationData.FirstNames)]
        PlayerClass.Data.FL_Name.Last = customizationData.LastNames[math.random(1, #customizationData.LastNames)]
        PlayerClass.Data.Customization.Gender = "Male"
        
        local hairColorTable = customizationData.HairColor[Race.Name]
        local h, s, v
        
        if typeof(Race.Name) ~= "string" then
            warn("Race is not a valid string. Actual value:", Race)
            Race = "Amestrian"
        end

        if hairColorTable and hairColorTable[1] then
            local hairColor = hairColorTable[1]
            h, s, v = hairColor:ToHSV()
            PlayerClass.Data.Customization.HairColor = {H = h, S = s, V = v}
        else
            warn("Invalid Race or missing hair color data for Race: " .. tostring(Race))
            local defaultColor = Color3.new(0, 0, 0)
            h, s, v = defaultColor:ToHSV()
            PlayerClass.Data.Customization.HairColor = {H = h, S = s, V = v}
        end
        
        PlayerClass.Data.Customization.EyeColor = {
            R = math.random(0, 100) / 100,
            G = math.random(0, 100) / 100,
            B = math.random(0, 100) / 100
        }
        
        PlayerClass.Data.Customization.Race = Race.Name
        
        -- Apply skin color
        local skinColor = PlayerClass.Data.Customization.SkinColor
        character["Body Colors"].HeadColor = BrickColor.new(skinColor)
        character["Body Colors"].LeftArmColor = BrickColor.new(skinColor)
        character["Body Colors"].RightArmColor = BrickColor.new(skinColor)
        character["Body Colors"].LeftLegColor = BrickColor.new(skinColor)
        character["Body Colors"].RightLegColor = BrickColor.new(skinColor)
        character["Body Colors"].TorsoColor = BrickColor.new(skinColor)

        -- Apply face assets
        local gender = PlayerClass.Data.Customization.Gender
        local faceassets = customizationData.Face[gender][math.random(1, #customizationData.Face[gender])].assets:Clone()
        local head = character.Head:Clone()
        head.Name = "fakehead"
        head.CanCollide = false
        head.Transparency = 0
        head.Color = BrickColor.new(skinColor).Color -- Apply skin color to fakehead
        local weld = Instance.new("Weld")
        weld.Part0 = character.Head
        weld.Part1 = head
        weld.Parent = head
        head.Parent = character
        
        faceassets.Pupils.Color3 = Color3.new(
            PlayerClass.Data.Customization.EyeColor.R,
            PlayerClass.Data.Customization.EyeColor.G,
            PlayerClass.Data.Customization.EyeColor.B
        )
        
        faceassets.Eyebrows.Color3 = Color3.fromHSV(
            PlayerClass.Data.Customization.HairColor.H,
            PlayerClass.Data.Customization.HairColor.S,
            PlayerClass.Data.Customization.HairColor.V
        )
        
        for i, v in pairs(faceassets:GetChildren()) do
            if v then
                v.Parent = character:WaitForChild("fakehead")
            end
        end
        
        -- Set display name
        humanoid.DisplayName = "- Civilian -\n" .. PlayerClass.Data.FL_Name.First .. " " .. PlayerClass.Data.FL_Name.Last

        -- Apply hair
        local customHairColor = Color3.fromHSV(
            PlayerClass.Data.Customization.HairColor.H,
            PlayerClass.Data.Customization.HairColor.S,
            PlayerClass.Data.Customization.HairColor.V
        )
        applyPlayerHairToDummy(character, humanoid, Player, customHairColor)
            
        -- Apply clothing
        character:WaitForChild("Shirt").ShirtTemplate = customizationData.Clothes[initialOutfit].shirt
        character:WaitForChild("Pants").PantsTemplate = customizationData.Clothes[initialOutfit].pants
        
        PlayerClass.Data.FirstJoin = false
        -- game.ReplicatedStorage.Status[Player.Name]:SetAttribute("Loaded", true)
    else
        -- Apply saved customization
        local skinColor = PlayerClass.Data.Customization.SkinColor
        character["Body Colors"].HeadColor = BrickColor.new(skinColor)
        character["Body Colors"].LeftArmColor = BrickColor.new(skinColor)
        character["Body Colors"].RightArmColor = BrickColor.new(skinColor)
        character["Body Colors"].LeftLegColor = BrickColor.new(skinColor)
        character["Body Colors"].RightLegColor = BrickColor.new(skinColor)
        character["Body Colors"].TorsoColor = BrickColor.new(skinColor)
        
        -- Apply face assets
        local faceassets = game.ReplicatedStorage.Assets.Customization.Face[PlayerClass.Data.Customization.Gender]:Clone()
        faceassets.Pupils.Color3 = Color3.new(
            PlayerClass.Data.Customization.EyeColor.R,
            PlayerClass.Data.Customization.EyeColor.G,
            PlayerClass.Data.Customization.EyeColor.B
        )
        
        faceassets.Eyebrows.Color3 = Color3.fromHSV(
            PlayerClass.Data.Customization.HairColor.H,
            PlayerClass.Data.Customization.HairColor.S,
            PlayerClass.Data.Customization.HairColor.V
        )
        
        local head = character.Head:Clone()
        head.Name = "fakehead"
        head.CanCollide = false
        head.Transparency = 1
        local weld = Instance.new("Weld")
        weld.Part0 = character.Head
        weld.Part1 = head
        weld.Parent = head
        head.Parent = character
        
        for i, v in pairs(faceassets:GetChildren()) do
            if v then
                v:Clone()
                v.Parent = character:WaitForChild("fakehead")
            end
        end
        
        -- Set display name
        humanoid.DisplayName = "- Civilian -\n" .. PlayerClass.Data.FL_Name.First .. " " .. PlayerClass.Data.FL_Name.Last
        
        -- Apply hair
        local customHairColor = Color3.fromHSV(
            PlayerClass.Data.Customization.HairColor.H,
            PlayerClass.Data.Customization.HairColor.S,
            PlayerClass.Data.Customization.HairColor.V
        )
        
        applyPlayerHairToDummy(character, humanoid, Player, customHairColor)
        
        -- Apply clothing
        local outfit = PlayerClass.Data.Customization.Outfit
        if outfit and customizationData.Clothes[outfit] then
            character.Shirt.ShirtTemplate = customizationData.Clothes[outfit].shirt
            character.Pants.PantsTemplate = customizationData.Clothes[outfit].pants
        else
            warn("Invalid outfit value or missing clothes data")
        end
        
        -- game.ReplicatedStorage.Status[Player.Name]:SetAttribute("Loaded", true)
    end
end

return Appearance