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
local StateManager = require(Replicated.Modules.ECS.StateManager);
local FocusHandler = require(script.Parent.Parent.FocusHandler);

-- Direction enum decoder: uint8 -> string
local EnumToDirection = {
    [0] = "Forward",
    [1] = "Back",
    [2] = "Left",
    [3] = "Right",
}

NetworkModule.EndPoint = function(Player, Data)
    -- Data is now a uint8 (direction enum), decode it to string
    local Direction = EnumToDirection[Data] or "Forward"

    local Character = Player.Character
    if not Character then return end

    -- PREVENT OVERLAPPING ACTIONS: Cannot dash while performing certain actions
    -- Allow dashing during recovery states
    local allStates = StateManager.GetAllStates(Character, "Actions")
    local allowedForDash = {
        "DodgeRecovery", "ComboRecovery", "BlockRecovery", "ParryRecovery",
        "Running", "Equipped",
    }
    for _, state in ipairs(allStates) do
        local isAllowed = false
        for _, allowed in ipairs(allowedForDash) do
            if state == allowed or string.find(state, allowed) then
                isAllowed = true
                break
            end
        end
        if not isAllowed then
            -- print(`[DODGE BLOCKED] {Character.Name} - Cannot dash while performing action: {state}`)
            return
        end
    end

    -- Prevent dashing during M1 stun (true stun system)
    if StateManager.StateCheck(Character, "Stuns", "M1Stun") then
       -- print(`[DODGE BLOCKED] {Character.Name} - Cannot dash during M1Stun`)
        return
    end

    -- Prevent dashing while guardbroken
    if StateManager.StateCheck(Character, "Stuns", "GuardbreakStun") then
       -- print(`[DODGE BLOCKED] {Character.Name} - Cannot dash while guardbroken`)
        return
    end

    -- Prevent dashing during any stun
    if StateManager.StateCount(Character, "Stuns") then
       -- print(`[DODGE BLOCKED] {Character.Name} - Cannot dash while stunned`)
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

    -- Add Dashing ECS component for systems that check it
    local playerEntity = ref.get("player", Player)
    if playerEntity then
        world:add(playerEntity, comps.Dashing)

        -- Clear dashing state after active movement phase
        task.delay(0.35, function()
            if playerEntity and world:contains(playerEntity) then
                world:remove(playerEntity, comps.Dashing)
            end
        end)
    end

    -- Add Dashing state to Actions — only covers active movement, not falloff
    StateManager.TimedState(Character, "Actions", "Dashing", 0.35)

    -- Always process VFX if we got here
    local Entity = Server.Modules["Entities"].Get(Character);
    if Entity and Entity.Character then
        -- Mini mode grants extra dodge iframes (+0.1s)
        local iframeDuration = 0.45
        if Character:GetAttribute("FocusMiniMode") == true then
            iframeDuration = 0.55
        end
        StateManager.TimedState(Entity.Character, "IFrames", "Dodge", iframeDuration)

        -- Add PerfectDodgeWindow - allows counter hit if player attacks during this window
        -- This gives 0.5s after dodge to land a counter attack on an enemy in recovery
        StateManager.TimedState(Entity.Character, "Frames", "PerfectDodgeWindow", 0.5)

        -- Focus: reward successful dodge
        FocusHandler.AddFocus(Character, FocusHandler.Amounts.DODGE_SUCCESS, "dodge_success")

        Visuals.Ranged(Character.HumanoidRootPart.Position,300, {Module = "Base", Function = "DashFX", Arguments = {Character, Direction}})
    end
end

return NetworkModule;