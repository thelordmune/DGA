--[[
    Server-Side Anti-Fling System
    
    Prevents excessive velocities from flinging characters.
    Monitors all characters and clamps velocities to safe values.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Configuration
local MAX_HORIZONTAL_VELOCITY = 200  -- Maximum horizontal speed (studs/second)
local MAX_VERTICAL_VELOCITY = 150    -- Maximum vertical speed (studs/second)
local VELOCITY_CHECK_INTERVAL = 0.1  -- Check every 0.1 seconds (10 times per second)

-- Track characters
local characterConnections = {}

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

-- Monitor a character's velocity
local function monitorCharacter(character: Model)
    local rootPart = character:WaitForChild("HumanoidRootPart", 5)
    if not rootPart then return end
    
    local lastCheckTime = 0
    
    -- Create connection
    local connection = RunService.Heartbeat:Connect(function(deltaTime)
        if not character or not character.Parent then
            if characterConnections[character] then
                characterConnections[character]:Disconnect()
                characterConnections[character] = nil
            end
            return
        end
        
        local currentRootPart = character:FindFirstChild("HumanoidRootPart")
        if not currentRootPart then
            if characterConnections[character] then
                characterConnections[character]:Disconnect()
                characterConnections[character] = nil
            end
            return
        end
        
        -- Check at interval
        lastCheckTime = lastCheckTime + deltaTime
        if lastCheckTime < VELOCITY_CHECK_INTERVAL then
            return
        end
        lastCheckTime = 0
        
        -- Get current velocity
        local currentVelocity = currentRootPart.AssemblyLinearVelocity
        
        -- Check if velocity is excessive
        local horizontalSpeed = Vector3.new(currentVelocity.X, 0, currentVelocity.Z).Magnitude
        local verticalSpeed = math.abs(currentVelocity.Y)
        
        if horizontalSpeed > MAX_HORIZONTAL_VELOCITY or verticalSpeed > MAX_VERTICAL_VELOCITY then
            -- Clamp the velocity
            local clampedVelocity = clampVelocity(currentVelocity)
            currentRootPart.AssemblyLinearVelocity = clampedVelocity
            
            -- Debug output (optional)
            -- warn(`[Server Anti-Fling] Clamped {character.Name}'s velocity from {currentVelocity} to {clampedVelocity}`)
        end
    end)
    
    -- Store connection
    characterConnections[character] = connection
end

-- Monitor player when they join
local function onPlayerAdded(player: Player)
    player.CharacterAdded:Connect(function(character)
        -- Wait a moment for character to fully load
        task.wait(0.5)
        monitorCharacter(character)
    end)
    
    -- Monitor current character if it exists
    if player.Character then
        task.wait(0.5)
        monitorCharacter(player.Character)
    end
end

-- Monitor NPCs
local function monitorNPCs()
    -- Monitor existing NPCs
    for _, descendant in pairs(workspace:GetDescendants()) do
        if descendant:IsA("Model") and descendant:GetAttribute("IsNPC") then
            task.spawn(function()
                monitorCharacter(descendant)
            end)
        end
    end
    
    -- Monitor new NPCs
    workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Model") and descendant:GetAttribute("IsNPC") then
            task.wait(0.5)
            monitorCharacter(descendant)
        end
    end)
end

-- Clean up when player leaves
local function onPlayerRemoving(player: Player)
    if player.Character and characterConnections[player.Character] then
        characterConnections[player.Character]:Disconnect()
        characterConnections[player.Character] = nil
    end
end

-- Initialize
for _, player in pairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Monitor NPCs
monitorNPCs()

-- print("[Anti-Fling] Server-side anti-fling system initialized")

