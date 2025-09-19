local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.FilterDescendantsInstances = { workspace.World.Map.Zones }
raycastParams.IgnoreWater = true

repeat task.wait() until game:IsLoaded()

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local INTERVAL = 0.75
local lastCheck = 0

player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
end)

local function findZone(character): Model?
    if not character then return nil end
    
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not root or not humanoid or humanoid.Health <= 0 then
        return nil
    end

    local raycastResult = workspace:Raycast(root.Position, root.Position + Vector3.new(0, 90000, 0), raycastParams)
    return (raycastResult and raycastResult.Instance)
end

local function applyZone(character)
    local zonePart = findZone(character)

    if not zonePart then
        -- Clear zone if we're not in any zone
        if workspace:GetAttribute("CurrentZone") ~= nil then
            workspace:SetAttribute("CurrentZone", nil)
        end
        return
    end
    
    local ZoneNameHolder = zonePart:FindFirstAncestorWhichIsA("Model")
    if not ZoneNameHolder then return end

    local ZoneName = ZoneNameHolder.Name
    if ZoneName == workspace:GetAttribute("CurrentZone") then return end
    
    lastCheck = os.clock()
    workspace:SetAttribute("CurrentZone", ZoneName)
end

function MapZones()
    if os.clock() - lastCheck < INTERVAL then return end
    
    if character then
        applyZone(character)
    end
end

return {
    run = function()
        MapZones()
    end,
    settings = {
        phase = "Heartbeat",
        depends_on = {"PlayerAdded"},
        client_only = true
    }
}