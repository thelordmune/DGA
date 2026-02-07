--[[
    Input Buffer System

    Buffers inputs (M1, Block, Sprint) when the player is stunned or in a blocking state.
    Once the blocking state ends, the buffered input is executed.

    Usage:
    - Call Buffer(inputType, Client) when an input is blocked due to stuns/actions
    - The system will automatically execute the input when the player is free to act
    - Call Clear(inputType) or ClearAll() when input is released
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

local InputBuffer = {}
InputBuffer.__index = InputBuffer

-- Buffer configuration
local BUFFER_WINDOW = 0.5 -- Maximum time to hold a buffered input (seconds)
local CHECK_INTERVAL = 1/60 -- Check every frame

-- Buffered inputs: { [inputType] = { timestamp, held, connection, Client } }
local bufferedInputs = {}

-- Input types
InputBuffer.InputType = {
    Attack = "Attack",
    Block = "Block",
    Sprint = "Sprint",
}

-- Stuns that prevent blocking specifically
local BLOCKING_STUNS = {
    "BlockBreakStun",
    "BlockBreakCooldown",
    "ParryKnockback",
    "ParryStun",
    "Ragdolled",
    "KnockbackStun",
    "PostureBreakStun",
}

-- Check if character can perform attack
local function canAttack(Client)
    if not Client.Character then return false end

    -- Check stuns
    if Client.Library.StateCount(Client.Character, "Stuns") then
        return false
    end

    -- Check for blocking actions (exclude Running/Sprinting as those shouldn't block attacks)
    local actionStates = Client.Library.GetAllStates(Client.Character, "Actions") or {}
    for _, action in ipairs(actionStates) do
        if action ~= "Running" and action ~= "Sprinting" and action ~= "Dodge" and action ~= "Dashing" and action ~= "Dodging" and action ~= "DodgeRecovery" then
            return false
        end
    end

    return true
end

-- Check if character can block
local function canBlock(Client)
    if not Client.Character then return false end

    -- Check specific blocking stuns
    for _, stunName in ipairs(BLOCKING_STUNS) do
        if StateManager.StateCheck(Client.Character, "Stuns", stunName) then
            return false
        end
    end

    return true
end

-- Check if character can sprint
local function canSprint(Client)
    if not Client.Character then return false end

    -- Check sprint lock
    if Client.SprintLocked then
        return false
    end

    -- Check stuns
    if Client.Library.StateCount(Client.Character, "Stuns") then
        return false
    end

    -- Check for blocking actions
    local actionStates = Client.Library.GetAllStates(Client.Character, "Actions") or {}
    for _, action in ipairs(actionStates) do
        if action ~= "Running" and action ~= "Sprinting" and action ~= "Dodge" and action ~= "Dashing" and action ~= "Dodging" and action ~= "DodgeRecovery" then
            return false
        end
    end

    -- Check client flags
    if Client.Dodging or Client.Sliding or Client.WallRunning or Client.LedgeClimbing then
        return false
    end

    return true
end

-- Execute buffered attack
local function executeAttack(Client)
    -- Attack Type enum for optimized packet serialization
    local AttackTypeEnum = {
        Normal = 0,
        Running = 1,
        None = 2,
    }

    -- Check if blocking
    if table.find(Client.CurrentInput, "Block") then
        Client.Packets.Parry.send()
        return
    end

    -- Check for running attack
    if Client.RunAtk and not Client.Library.CheckCooldown(Client.Character, "RunningAttack") then
        Client.Packets.Attack.send({Type = AttackTypeEnum.Running, Held = true, Air = Client.InAir})
    else
        -- Stop running if currently running
        if Client._Running then
            Client.Modules['Movement'].Run(false)
        end
        Client.Packets.Attack.send({Type = AttackTypeEnum.Normal, Held = true, Air = Client.InAir})
    end
end

-- Execute buffered block
local function executeBlock(Client)
    local Library = require(ReplicatedStorage.Modules.Library)

    -- Play block animation
    if Client.Character and Client.Character:GetAttribute("Equipped") then
        local Weapon = Client.Character:GetAttribute("Weapon") or "Fist"
        local BlockAnim = ReplicatedStorage.Assets.Animations.Weapons[Weapon]:FindFirstChild("Block")

        if BlockAnim then
            local BlockAnimation = Library.PlayAnimation(Client.Character, BlockAnim)
            if BlockAnimation then
                BlockAnimation.Priority = Enum.AnimationPriority.Action2
            end
            -- Store reference for cleanup (accessed via InputBuffer)
            InputBuffer._currentBlockAnimation = BlockAnimation
        end
    end

    -- Send to server
    Client.Packets.Block.send({Held = true})
end

-- Execute buffered sprint
local function executeSprint(Client)
    Client.Modules["Movement"].Run(true)
end

-- Buffer an input for execution when free
function InputBuffer.Buffer(inputType, Client)
    -- Clear any existing buffer of this type
    InputBuffer.Clear(inputType)

    local startTime = os.clock()

    bufferedInputs[inputType] = {
        timestamp = startTime,
        held = true,
        Client = Client,
        connection = nil,
    }

    local buffer = bufferedInputs[inputType]

    -- Create heartbeat connection to check when action can be performed
    buffer.connection = RunService.Heartbeat:Connect(function()
        -- Check if buffer expired or input was released
        local elapsed = os.clock() - buffer.timestamp
        if elapsed > BUFFER_WINDOW or not buffer.held then
            InputBuffer.Clear(inputType)
            return
        end

        -- Check if we can now perform the action
        local canPerform = false

        if inputType == InputBuffer.InputType.Attack then
            canPerform = canAttack(Client)
        elseif inputType == InputBuffer.InputType.Block then
            canPerform = canBlock(Client)
        elseif inputType == InputBuffer.InputType.Sprint then
            canPerform = canSprint(Client)
        end

        if canPerform then
            -- Execute the buffered action
            if inputType == InputBuffer.InputType.Attack then
                executeAttack(Client)
            elseif inputType == InputBuffer.InputType.Block then
                executeBlock(Client)
            elseif inputType == InputBuffer.InputType.Sprint then
                executeSprint(Client)
            end

            -- Clear this buffer (but keep held state for continuous inputs)
            if buffer.connection then
                buffer.connection:Disconnect()
                buffer.connection = nil
            end
            bufferedInputs[inputType] = nil
        end
    end)
end

-- Check if an input is currently buffered
function InputBuffer.IsBuffered(inputType)
    return bufferedInputs[inputType] ~= nil and bufferedInputs[inputType].held
end

-- Clear a specific buffered input
function InputBuffer.Clear(inputType)
    local buffer = bufferedInputs[inputType]
    if buffer then
        if buffer.connection then
            buffer.connection:Disconnect()
        end
        bufferedInputs[inputType] = nil
    end
end

-- Clear all buffered inputs
function InputBuffer.ClearAll()
    for inputType, _ in pairs(bufferedInputs) do
        InputBuffer.Clear(inputType)
    end
end

-- Mark input as no longer held (will clear on next check)
function InputBuffer.Release(inputType)
    local buffer = bufferedInputs[inputType]
    if buffer then
        buffer.held = false
    end
end

return InputBuffer
