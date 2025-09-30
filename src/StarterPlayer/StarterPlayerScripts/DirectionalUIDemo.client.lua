-- Directional Triangle UI Demo
-- Place this in StarterPlayer/StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create the main UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DirectionalUI"
screenGui.Parent = playerGui

-- Main container frame (center of screen)
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.fromOffset(200, 200)
container.Position = UDim2.fromScale(0.5, 0.5)
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.BackgroundTransparency = 1
container.Parent = screenGui

-- Center indicator (optional - shows the center point)
local center = Instance.new("Frame")
center.Name = "Center"
center.Size = UDim2.fromOffset(10, 10)
center.Position = UDim2.fromScale(0.5, 0.5)
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
center.Parent = container

local centerCorner = Instance.new("UICorner")
centerCorner.CornerRadius = UDim.new(1, 0)
centerCorner.Parent = center

-- Triangle creation function
local function createTriangle(direction, position, rotation)
    local triangle = Instance.new("TextLabel")
    triangle.Name = direction .. "Triangle"
    triangle.Size = UDim2.fromOffset(40, 40)
    triangle.Position = position
    triangle.AnchorPoint = Vector2.new(0.5, 0.5)
    triangle.BackgroundTransparency = 1
    triangle.Text = "▲"
    triangle.TextColor3 = Color3.fromRGB(100, 100, 100)
    triangle.TextSize = 30
    triangle.TextStrokeTransparency = 0
    triangle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    triangle.Font = Enum.Font.SourceSansBold
    triangle.Rotation = rotation
    triangle.Parent = container
    
    return triangle
end

-- Create the 4 triangles
local triangles = {
    up = createTriangle("Up", UDim2.fromScale(0.5, 0.2), 0),
    down = createTriangle("Down", UDim2.fromScale(0.5, 0.8), 180),
    left = createTriangle("Left", UDim2.fromScale(0.2, 0.5), -90),
    right = createTriangle("Right", UDim2.fromScale(0.8, 0.5), 90)
}

-- Colors for different states
local colors = {
    inactive = Color3.fromRGB(100, 100, 100),
    hover = Color3.fromRGB(255, 255, 0),
    active = Color3.fromRGB(0, 255, 0)
}

-- Current active triangle
local currentTriangle = nil
local lastTriangle = nil

-- Tween info for smooth transitions
local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Function to highlight a triangle
local function highlightTriangle(triangle)
    if triangle == currentTriangle then return end
    
    -- Reset previous triangle
    if currentTriangle then
        local resetTween = TweenService:Create(currentTriangle, tweenInfo, {
            TextColor3 = colors.inactive,
            TextSize = 30
        })
        resetTween:Play()
    end
    
    -- Highlight new triangle
    if triangle then
        local highlightTween = TweenService:Create(triangle, tweenInfo, {
            TextColor3 = colors.hover,
            TextSize = 35
        })
        highlightTween:Play()
    end
    
    currentTriangle = triangle
end

-- Function to trigger a triangle (when clicked or activated)
local function triggerTriangle(triangle)
    if not triangle then return end
    
    -- Visual feedback
    local triggerTween = TweenService:Create(triangle, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
        TextColor3 = colors.active,
        TextSize = 40
    })
    triggerTween:Play()
    
    -- Reset after a short delay
    triggerTween.Completed:Connect(function()
        task.wait(0.1)
        local resetTween = TweenService:Create(triangle, tweenInfo, {
            TextColor3 = colors.hover,
            TextSize = 35
        })
        resetTween:Play()
    end)
    
    -- Print which direction was triggered (replace with your logic)
    print("Triggered:", triangle.Name)
end

-- Function to determine which triangle should be active based on mouse position
local function getTriangleFromMousePosition()
    local mouse = UserInputService:GetMouseLocation()
    local containerPos = container.AbsolutePosition
    local containerSize = container.AbsoluteSize
    
    -- Calculate center of container
    local centerX = containerPos.X + containerSize.X / 2
    local centerY = containerPos.Y + containerSize.Y / 2
    
    -- Calculate relative position from center
    local relativeX = mouse.X - centerX
    local relativeY = mouse.Y - centerY
    
    -- Minimum distance from center to activate (dead zone)
    local deadZone = 30
    local distance = math.sqrt(relativeX^2 + relativeY^2)
    
    if distance < deadZone then
        return nil -- Too close to center
    end
    
    -- Method 1: Angle-based detection
    local angle = math.atan2(relativeY, relativeX)
    local degrees = math.deg(angle)
    
    -- Normalize to 0-360
    if degrees < 0 then
        degrees = degrees + 360
    end
    
    -- Determine direction based on angle
    if degrees >= 315 or degrees < 45 then
        return triangles.right
    elseif degrees >= 45 and degrees < 135 then
        return triangles.down
    elseif degrees >= 135 and degrees < 225 then
        return triangles.left
    elseif degrees >= 225 and degrees < 315 then
        return triangles.up
    end
    
    -- Method 2: Quadrant-based detection (alternative approach)
    --[[
    local absX = math.abs(relativeX)
    local absY = math.abs(relativeY)
    
    if absX > absY then
        -- More horizontal movement
        if relativeX > 0 then
            return triangles.right
        else
            return triangles.left
        end
    else
        -- More vertical movement
        if relativeY > 0 then
            return triangles.down
        else
            return triangles.up
        end
    end
    --]]
end

-- Main update loop
local connection
connection = RunService.Heartbeat:Connect(function()
    local targetTriangle = getTriangleFromMousePosition()
    highlightTriangle(targetTriangle)
end)

-- Handle mouse clicks to trigger triangles
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if currentTriangle then
            triggerTriangle(currentTriangle)
        end
    end
end)

-- Handle keyboard input for testing (WASD keys)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.W then
        triggerTriangle(triangles.up)
    elseif input.KeyCode == Enum.KeyCode.S then
        triggerTriangle(triangles.down)
    elseif input.KeyCode == Enum.KeyCode.A then
        triggerTriangle(triangles.left)
    elseif input.KeyCode == Enum.KeyCode.D then
        triggerTriangle(triangles.right)
    end
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == player then
        connection:Disconnect()
        screenGui:Destroy()
    end
end)

print("Directional UI Demo loaded!")
print("Move your mouse around the center to highlight triangles")
print("Click to trigger the highlighted triangle")
print("Use WASD keys to trigger triangles directly")
