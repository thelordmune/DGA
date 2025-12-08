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

    -- PREVENT OVERLAPPING ACTIONS: Cannot dash while performing any action
    if Character:FindFirstChild("Actions") and Library.StateCount(Character.Actions) then
        print(`[DODGE BLOCKED] {Character.Name} - Cannot dash while performing action`)
        return
    end

    -- Prevent dashing during M1 stun (true stun system)
    if Character:FindFirstChild("Stuns") and Library.StateCheck(Character.Stuns, "M1Stun") then
        print(`[DODGE BLOCKED] {Character.Name} - Cannot dash during M1Stun`)
        return
    end

    -- Prevent dashing while guardbroken
    if Character:FindFirstChild("Stuns") and Library.StateCheck(Character.Stuns, "GuardbreakStun") then
        print(`[DODGE BLOCKED] {Character.Name} - Cannot dash while guardbroken`)
        return
    end

    -- Prevent dashing during any stun
    if Character:FindFirstChild("Stuns") and Library.StateCount(Character.Stuns) then
        print(`[DODGE BLOCKED] {Character.Name} - Cannot dash while stunned`)
        return
    end

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

    -- Set Dashing component to true AND add Dashing state to Stuns to prevent all actions
    local playerEntity = ref.get("player", Player)
    if playerEntity then
        world:set(playerEntity, comps.Dashing, true)

        -- Clear dashing state after dash duration (0.35s)
        task.delay(0.35, function()
            if playerEntity and world:contains(playerEntity) then
                world:set(playerEntity, comps.Dashing, false)
            end
        end)
    end

    -- Add Dashing state to Stuns to prevent all actions during dash
    Library.TimedState(Character.Stuns, "Dashing", 0.35)

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