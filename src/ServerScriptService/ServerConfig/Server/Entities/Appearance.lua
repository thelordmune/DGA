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
                            mesh.TextureId = "rbxassetid://113724683736061"
                            mesh.VertexColor = Vector3.new(hairColor.R, hairColor.G, hairColor.B)
                            handle.Material = Enum.Material.Asphalt
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

-- Track which characters have had appearance loaded to prevent duplicate calls
local loadedCharacters = {}

Appearance.Load = function(Player : Player)
    print("[Appearance] 🎨 Load called for player:", Player.Name)

    local PlayerClass = Server.Modules["Players"].Get(Player);
    if not PlayerClass or not PlayerClass.Character or not PlayerClass.Data then
        warn("[Appearance] ⚠️ Missing PlayerClass, Character, or Data for:", Player.Name)
        return
    end

    local character = PlayerClass.Character

    -- Prevent duplicate calls for the same character instance
    if loadedCharacters[character] then
        warn("[Appearance] ⚠️ Appearance already loaded for this character, skipping duplicate call")
        return
    end

    local humanoid = character:WaitForChild("Humanoid")
    local playerData = PlayerClass.Data

    print("[Appearance] Character found:", character.Name)
    print("[Appearance] FirstJoin:", playerData.FirstJoin)

    -- Mark this character as loaded BEFORE doing any work
    loadedCharacters[character] = true

    -- Clear the flag when character is removed
    character.AncestryChanged:Once(function()
        if not character.Parent then
            loadedCharacters[character] = nil
            print("[Appearance] Character removed, cleared loaded flag for:", Player.Name)
        end
    end)

    -- Ensure Shirt and Pants exist - DESTROY old ones to prevent conflicts
    local oldShirt = character:FindFirstChild("Shirt")
    if oldShirt then
        print("[Appearance] ⚠️ Found existing Shirt with template:", oldShirt.ShirtTemplate)
        oldShirt:Destroy()
    end
    local oldPants = character:FindFirstChild("Pants")
    if oldPants then
        print("[Appearance] ⚠️ Found existing Pants with template:", oldPants.PantsTemplate)
        oldPants:Destroy()
    end

    -- Create fresh Shirt and Pants
    local shirt = Instance.new("Shirt", character)
    local pants = Instance.new("Pants", character)
    print("[Appearance] ✅ Created fresh Shirt and Pants instances")

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

        -- Apply clothing (use the shirt/pants we created earlier)
        shirt.ShirtTemplate = customizationData.Clothes[initialOutfit].shirt
        pants.PantsTemplate = customizationData.Clothes[initialOutfit].pants

        print("[Appearance] ✅ Applied clothing for first join:")
        print("  Shirt:", shirt.ShirtTemplate)
        print("  Pants:", pants.PantsTemplate)

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
        head.Transparency = 0 -- Keep head visible, not transparent
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

        -- Apply clothing (use the shirt/pants we created earlier)
        local outfit = PlayerClass.Data.Customization.Outfit
        print("[Appearance] Applying saved outfit:", outfit)

        if outfit and customizationData.Clothes[outfit] then
            shirt.ShirtTemplate = customizationData.Clothes[outfit].shirt
            pants.PantsTemplate = customizationData.Clothes[outfit].pants

            print("[Appearance] ✅ Applied saved clothing:")
            print("  Shirt:", shirt.ShirtTemplate)
            print("  Pants:", pants.PantsTemplate)
        else
            warn("[Appearance] ⚠️ Invalid outfit value or missing clothes data. Outfit:", outfit)
        end

        -- game.ReplicatedStorage.Status[Player.Name]:SetAttribute("Loaded", true)
    end

    print("[Appearance] ✅ Appearance.Load completed for:", Player.Name)
end

return Appearance