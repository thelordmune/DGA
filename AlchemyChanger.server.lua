-- Alchemy Changer Script
-- Place this script directly inside a part in workspace
-- The part's name will be the alchemy name that players get when they touch it

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Get the part this script is inside
local part = script.Parent
if not part:IsA("BasePart") then
    error("AlchemyChanger script must be placed inside a BasePart!")
end

-- Get the Server module and Global functions
local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
local Global = require(game:GetService("ReplicatedStorage").Modules.Shared.Global)

-- Configuration
local CHANGE_COOLDOWN = 2 -- Seconds between alchemy changes per player
local ALCHEMY_NAME = part.Name -- Use the part's name as the alchemy name

-- Track cooldowns per player
local playerCooldowns = {}

-- Function to change player's alchemy
local function changePlayerAlchemy(player, alchemyName)
    local character = player.Character
    if not character then return end

    -- Check if player already has this alchemy
    local currentAlchemy = player:GetAttribute("Alchemy")
    if currentAlchemy == alchemyName then
        print("Player", player.Name, "already has alchemy:", alchemyName)
        return
    end

    -- Update player data using Global.SetData (persistent storage)
    Global.SetData(player, function(data)
        data.Alchemy = alchemyName
        return data
    end)

    -- Update player attribute for immediate access
    player:SetAttribute("Alchemy", alchemyName)

    -- Update client alchemy (this is crucial for the client to know the change)
    if Server.Packets and Server.Packets.AlchemyUpdate then
        Server.Packets.AlchemyUpdate.sendTo({
            Alchemy = alchemyName
        }, player)
    end

    -- Update client alchemy variable directly using RemoteEvent
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local updateAlchemyRemote = ReplicatedStorage:FindFirstChild("UpdateAlchemy")
    if not updateAlchemyRemote then
        updateAlchemyRemote = Instance.new("RemoteEvent")
        updateAlchemyRemote.Name = "UpdateAlchemy"
        updateAlchemyRemote.Parent = ReplicatedStorage
    end

    -- Send alchemy update to client
    updateAlchemyRemote:FireClient(player, alchemyName)

    -- Optional: Add visual feedback with alchemy-themed colors
    local highlight = Instance.new("Highlight")
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded

    -- Different colors for different alchemies
    if alchemyName == "Fire" or alchemyName == "Flame" then
        highlight.FillColor = Color3.fromRGB(255, 100, 0)
    elseif alchemyName == "Water" or alchemyName == "Ice" then
        highlight.FillColor = Color3.fromRGB(0, 150, 255)
    elseif alchemyName == "Earth" or alchemyName == "Stone" then
        highlight.FillColor = Color3.fromRGB(139, 69, 19)
    elseif alchemyName == "Air" or alchemyName == "Wind" then
        highlight.FillColor = Color3.fromRGB(200, 200, 200)
    elseif alchemyName == "Lightning" or alchemyName == "Electric" then
        highlight.FillColor = Color3.fromRGB(255, 255, 0)
    else
        highlight.FillColor = Color3.fromRGB(128, 0, 128) -- Purple for unknown
    end

    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0.3
    highlight.Parent = character

    game:GetService("Debris"):AddItem(highlight, 1)

    print("Changed", player.Name, "alchemy to:", alchemyName)
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
    
    -- Change the player's alchemy
    changePlayerAlchemy(player, ALCHEMY_NAME)
    
    -- Optional: Add part visual feedback with alchemy-themed colors
    local originalColor = part.Color
    
    -- Different flash colors for different alchemies
    if ALCHEMY_NAME == "Fire" or ALCHEMY_NAME == "Flame" then
        part.Color = Color3.fromRGB(255, 100, 0)
    elseif ALCHEMY_NAME == "Water" or ALCHEMY_NAME == "Ice" then
        part.Color = Color3.fromRGB(0, 150, 255)
    elseif ALCHEMY_NAME == "Earth" or ALCHEMY_NAME == "Stone" then
        part.Color = Color3.fromRGB(139, 69, 19)
    elseif ALCHEMY_NAME == "Air" or ALCHEMY_NAME == "Wind" then
        part.Color = Color3.fromRGB(200, 200, 200)
    elseif ALCHEMY_NAME == "Lightning" or ALCHEMY_NAME == "Electric" then
        part.Color = Color3.fromRGB(255, 255, 0)
    else
        part.Color = Color3.fromRGB(128, 0, 128) -- Purple for unknown
    end
    
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
        print("Alchemy changer cleaned up for:", ALCHEMY_NAME)
    end
end)

print("Alchemy changer active for:", ALCHEMY_NAME)
