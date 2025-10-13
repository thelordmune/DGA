--[[
    Anti-Fling System
    
    Prevents excessive velocities from flinging the character.
    Monitors AssemblyLinearVelocity and clamps it to safe values.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Configuration
local MAX_HORIZONTAL_VELOCITY = 200  -- Maximum horizontal speed (studs/second)
local MAX_VERTICAL_VELOCITY = 150    -- Maximum vertical speed (studs/second)
local VELOCITY_CHECK_INTERVAL = 0    -- Check every frame (0 = every frame)

-- Track last check time
local lastCheckTime = 0

-- Function to clamp velocity
local function clampVelocity(velocity: Vector3): Vector3
    local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
    local vertical = Vector3.new(0, velocity.Y, 0)
    
    -- Clamp horizontal velocity
    if horizontal.Magnitude > MAX_HORIZONTAL_VELOCITY then
        horizontal = horizontal.Unit * MAX_HORIZONTAL_VELOCITY
    end
    
    -- Clamp vertical velocity
    if math.abs(vertical.Y) > MAX_VERTICAL_VELOCITY then
        vertical = Vector3.new(0, math.sign(velocity.Y) * MAX_VERTICAL_VELOCITY, 0)
    end
    
    return horizontal + vertical
end

-- Monitor velocity every frame
local connection
connection = RunService.Heartbeat:Connect(function(deltaTime)
    if not Character or not Character.Parent then
        connection:Disconnect()
        return
    end
    
    local rootPart = Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        connection:Disconnect()
        return
    end
    
    -- Check at interval
    lastCheckTime = lastCheckTime + deltaTime
    if lastCheckTime < VELOCITY_CHECK_INTERVAL then
        return
    end
    lastCheckTime = 0
    
    -- Get current velocity
    local currentVelocity = rootPart.AssemblyLinearVelocity
    
    -- Check if velocity is excessive
    local horizontalSpeed = Vector3.new(currentVelocity.X, 0, currentVelocity.Z).Magnitude
    local verticalSpeed = math.abs(currentVelocity.Y)
    
    if horizontalSpeed > MAX_HORIZONTAL_VELOCITY or verticalSpeed > MAX_VERTICAL_VELOCITY then
        -- Clamp the velocity
        local clampedVelocity = clampVelocity(currentVelocity)
        rootPart.AssemblyLinearVelocity = clampedVelocity
        
        -- Debug output (optional)
        -- warn(`[Anti-Fling] Clamped velocity from {currentVelocity} to {clampedVelocity}`)
    end
end)

-- Reconnect when character respawns
Player.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    
    -- Disconnect old connection
    if connection then
        connection:Disconnect()
    end
    
    -- Restart monitoring
    connection = RunService.Heartbeat:Connect(function(deltaTime)
        if not Character or not Character.Parent then
            connection:Disconnect()
            return
        end
        
        local rootPart = Character:FindFirstChild("HumanoidRootPart")
        if not rootPart then
            connection:Disconnect()
            return
        end
        
        -- Check at interval
        lastCheckTime = lastCheckTime + deltaTime
        if lastCheckTime < VELOCITY_CHECK_INTERVAL then
            return
        end
        lastCheckTime = 0
        
        -- Get current velocity
        local currentVelocity = rootPart.AssemblyLinearVelocity
        
        -- Check if velocity is excessive
        local horizontalSpeed = Vector3.new(currentVelocity.X, 0, currentVelocity.Z).Magnitude
        local verticalSpeed = math.abs(currentVelocity.Y)
        
        if horizontalSpeed > MAX_HORIZONTAL_VELOCITY or verticalSpeed > MAX_VERTICAL_VELOCITY then
            -- Clamp the velocity
            local clampedVelocity = clampVelocity(currentVelocity)
            rootPart.AssemblyLinearVelocity = clampedVelocity
            
            -- Debug output (optional)
            -- warn(`[Anti-Fling] Clamped velocity from {currentVelocity} to {clampedVelocity}`)
        end
    end)
end)

