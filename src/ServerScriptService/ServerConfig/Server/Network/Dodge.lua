local NetworkModule = {}; local Server = require(script.Parent.Parent);
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

local Replicated = game:GetService("ReplicatedStorage");
local Utilities  = require(Replicated.Modules.Utilities);
local Library    = require(Replicated.Modules.Library);
local Packets    = require(Replicated.Modules.Packets);
local Visuals    = require(Replicated.Modules.Visuals);
local world      = require(Replicated.Modules.ECS.jecs_world);
local comps      = require(Replicated.Modules.ECS.jecs_components);
local ref        = require(Replicated.Modules.ECS.jecs_ref);

NetworkModule.EndPoint = function(Player, Data)
    local Character = Player.Character
    if not Character then return end

    -- Initialize charges if needed
    local charges = Character:GetAttribute("DodgeCharges")
    if charges == nil then
        charges = 2
        Character:SetAttribute("DodgeCharges", charges)
    end

    -- Check if we can dodge
    if charges <= 0 then
        if Library.CheckCooldown(Character, "Dodge") then 
            return 
        else
            -- Reset charges when cooldown expires
            charges = 2
            Character:SetAttribute("DodgeCharges", charges)
        end
    end

    -- Use a charge
    charges = math.max(0, charges - 1)  -- Prevent negative charges
    Character:SetAttribute("DodgeCharges", charges)

    -- Set cooldown when out of charges
    if charges <= 0 then
        Library.SetCooldown(Character, "Dodge", 2)
    end

    -- Set Dashing component to true
    local playerEntity = ref.get("player", Player)
    if playerEntity then
        world:set(playerEntity, comps.Dashing, true)

        -- Clear dashing state after dash duration (0.5s)
        task.delay(0.5, function()
            if playerEntity and world:contains(playerEntity) then
                world:set(playerEntity, comps.Dashing, false)
            end
        end)
    end

    -- Always process VFX if we got here
    local Entity = Server.Modules["Entities"].Get(Character);
    if Entity and Entity.Character then
        if Entity.Character:FindFirstChild("IFrames") then
            Library.TimedState(Entity.Character.IFrames, "Dodge", .3);
        end
        Visuals.Ranged(Character.HumanoidRootPart.Position,300, {Module = "Base", Function = "DashFX", Arguments = {Character,Data.Direction}})
    end
end

return NetworkModule;