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
    triangle.TextStrokeTransparency = 1 -- Start invisible
    triangle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    triangle.TextTransparency = 1 -- Start invisible
    triangle.Font = Enum.Font.SourceSansBold
    triangle.Rotation = rotation
    triangle.Visible = false -- Start hidden
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
    active = Color3.fromRGB(0, 255, 0),
    modifier = Color3.fromRGB(255, 0, 0), -- Red for modifier mode
    modifierHover = Color3.fromRGB(255, 100, 100) -- Light red for modifier hover
}

-- Current active triangle
local currentTriangle = nil
local lastTriangle = nil

-- Casting system variables
local isCasting = false
local isModifying = false
local directionSequence = {}
local modifierSequence = {}
local savedBaseSequence = {}
local castingStartTime = 0

-- Tween info for smooth transitions
local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Function to start casting
local function startCasting()
    isCasting = true
    isModifying = false
    directionSequence = {}
    modifierSequence = {}
    savedBaseSequence = {}
    castingStartTime = tick()

    -- Make container more visible during casting
    local castingTween = TweenService:Create(container, tweenInfo, {
        BackgroundTransparency = 0.8,
        BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    })
    castingTween:Play()

    -- Fade in all triangles
    for _, triangle in pairs(triangles) do
        triangle.TextTransparency = 1
        triangle.TextStrokeTransparency = 1
        triangle.Visible = true

        local fadeInTween = TweenService:Create(triangle, tweenInfo, {
            TextTransparency = 0,
            TextStrokeTransparency = 0
        })
        fadeInTween:Play()
    end

    print("🎯 CASTING STARTED - Move mouse to triangles, press K again to finish")
    print("🔧 Press X to enter modifier mode")
end

-- Function to start modifier mode
local function startModifying()
    if not isCasting then return end -- Can only modify during casting

    -- Save the current base sequence
    savedBaseSequence = {}
    for i, direction in ipairs(directionSequence) do
        savedBaseSequence[i] = direction
    end

    -- Start modifier mode with fresh sequence
    isModifying = true
    modifierSequence = {} -- Fresh array for modifier combinations

    -- Change all triangles to red
    for _, triangle in pairs(triangles) do
        local modifierTween = TweenService:Create(triangle, tweenInfo, {
            TextColor3 = colors.modifier
        })
        modifierTween:Play()
    end

    print("🔧 MODIFIER MODE ACTIVATED - Triangles are now red")
    print("� Base sequence saved: " .. (table.concat(savedBaseSequence, " -> ")))
    print("🆕 Starting fresh modifier sequence...")
end

-- Function to stop everything (modifier + casting)
local function stopEverything()
    isModifying = false
    isCasting = false

    -- Hide container background
    local endTween = TweenService:Create(container, tweenInfo, {
        BackgroundTransparency = 1
    })
    endTween:Play()

    -- Fade out all triangles and reset their properties
    for _, triangle in pairs(triangles) do
        local fadeOutTween = TweenService:Create(triangle, tweenInfo, {
            TextTransparency = 1,
            TextStrokeTransparency = 1,
            TextColor3 = colors.inactive,
            TextSize = 30
        })
        fadeOutTween:Play()

        fadeOutTween.Completed:Connect(function()
            triangle.Visible = false
        end)
    end

    -- Log both sequences
    print("🛑 STOPPED! Final Results:")

    if #savedBaseSequence > 0 then
        local baseString = table.concat(savedBaseSequence, " -> ")
        print("� Base sequence: " .. baseString .. " (Total: " .. #savedBaseSequence .. ")")
    else
        print("📋 Base sequence: None")
    end

    if #modifierSequence > 0 then
        local modifierString = table.concat(modifierSequence, " -> ")
        print("� Modifier sequence: " .. modifierString .. " (Total: " .. #modifierSequence .. ")")
    else
        print("🔧 Modifier sequence: None")
    end

    -- If still in base casting mode (never entered modifier)
    if not isModifying and #directionSequence > 0 then
        local currentString = table.concat(directionSequence, " -> ")
        print("� Current sequence: " .. currentString .. " (Total: " .. #directionSequence .. ")")
    end

    -- Reset current triangle highlight and all sequences
    currentTriangle = nil
    directionSequence = {}
    modifierSequence = {}
    savedBaseSequence = {}
end

-- Function to end casting
local function endCasting()
    isCasting = false
    isModifying = false

    -- Hide container background
    local endTween = TweenService:Create(container, tweenInfo, {
        BackgroundTransparency = 1
    })
    endTween:Play()

    -- Fade out all triangles and reset their properties
    for _, triangle in pairs(triangles) do
        local fadeOutTween = TweenService:Create(triangle, tweenInfo, {
            TextTransparency = 1,
            TextStrokeTransparency = 1,
            TextColor3 = colors.inactive,
            TextSize = 30
        })
        fadeOutTween:Play()

        fadeOutTween.Completed:Connect(function()
            triangle.Visible = false
        end)
    end

    -- Log the sequence
    if #directionSequence > 0 then
        local sequenceString = table.concat(directionSequence, " -> ")
        print("✨ CAST COMPLETE! Sequence: " .. sequenceString)
        print("📊 Total directions: " .. #directionSequence)

        -- Here you would handle the actual spell/action based on the sequence
        -- Example: handleSpellCast(directionSequence)
    else
        print("❌ No directions recorded")
    end

    -- Reset current triangle highlight and all sequences
    currentTriangle = nil
    directionSequence = {}
    modifierSequence = {}
    savedBaseSequence = {}
end

-- Function to add direction to sequence
local function addDirectionToSequence(direction)
    if not isCasting then return end

    if isModifying then
        -- Add to modifier sequence
        if #modifierSequence == 0 or modifierSequence[#modifierSequence] ~= direction then
            table.insert(modifierSequence, direction)
            print("🔧 Added modifier direction: " .. direction .. " (Modifier Total: " .. #modifierSequence .. ")")
        end
    else
        -- Add to base sequence
        if #directionSequence == 0 or directionSequence[#directionSequence] ~= direction then
            table.insert(directionSequence, direction)
            print("📍 Added direction: " .. direction .. " (Base Total: " .. #directionSequence .. ")")
        end
    end
end

-- Function to highlight a triangle
local function highlightTriangle(triangle)
    if triangle == currentTriangle then return end

    -- Only show visual feedback if casting or always show (your choice)
    local showFeedback = isCasting or true -- Change to 'isCasting' to only show during casting

    -- Reset previous triangle
    if currentTriangle then
        local resetColor
        if showFeedback then
            resetColor = isModifying and colors.modifier or colors.inactive
        else
            resetColor = Color3.fromRGB(50, 50, 50)
        end
        local resetSize = showFeedback and 30 or 25
        local resetTween = TweenService:Create(currentTriangle, tweenInfo, {
            TextColor3 = resetColor,
            TextSize = resetSize
        })
        resetTween:Play()
    end

    -- Highlight new triangle and add to sequence if casting
    if triangle then
        local highlightColor
        if showFeedback then
            highlightColor = isModifying and colors.modifierHover or colors.hover
        else
            highlightColor = Color3.fromRGB(150, 150, 150)
        end
        local highlightSize = showFeedback and 35 or 30
        local highlightTween = TweenService:Create(triangle, tweenInfo, {
            TextColor3 = highlightColor,
            TextSize = highlightSize
        })
        highlightTween:Play()

        -- Add direction to sequence if casting (works in both normal and modifier mode)
        if isCasting then
            local direction = triangle.Name:gsub("Triangle", ""):upper()
            addDirectionToSequence(direction)
        end
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

    -- Minimum distance from center to activate (dead zone for neutral position)
    local deadZone = 70 -- Increased for better neutral zone and doubles
    local distance = math.sqrt(relativeX^2 + relativeY^2)

    if distance < deadZone then
        return nil -- Neutral zone - allows for repeating directions
    end

    -- Method 1: Angle-based detection with adjusted sensitivity
    local angle = math.atan2(relativeY, relativeX)
    local degrees = math.deg(angle)

    -- Normalize to 0-360
    if degrees < 0 then
        degrees = degrees + 360
    end

    -- Determine direction based on angle with better sensitivity balance
    if degrees >= 315 or degrees < 45 then
        return triangles.right
    elseif degrees >= 75 and degrees < 105 then -- Made down much less sensitive (was 60-120, now 75-105)
        return triangles.down
    elseif degrees >= 135 and degrees < 225 then
        return triangles.left
    elseif degrees >= 240 and degrees < 300 then -- Made up easier to reach (was 225-315, now 240-300)
        return triangles.up
    end

    -- If we're in the gap areas, return nil for neutral
    return nil
end

-- Main update loop
local connection
connection = RunService.Heartbeat:Connect(function()
    -- Only track mouse during casting or always (your choice)
    if isCasting or true then -- Change to 'if isCasting then' to only track during casting
        local targetTriangle = getTriangleFromMousePosition()
        highlightTriangle(targetTriangle)
    end
end)

-- Handle keyboard input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- K key to toggle casting
    if input.KeyCode == Enum.KeyCode.K then
        if isCasting then
            endCasting()
        else
            startCasting()
        end
    end

    -- X key to toggle modifier mode or stop everything
    if input.KeyCode == Enum.KeyCode.X then
        if isCasting and not isModifying then
            -- Start modifier mode
            startModifying()
        elseif isCasting and isModifying then
            -- Stop everything (modifier + casting)
            stopEverything()
        end
    end

    -- Optional: WASD keys for direct direction input during casting
    -- if isCasting then
    --     if input.KeyCode == Enum.KeyCode.W then
    --         addDirectionToSequence("UP")
    --     elseif input.KeyCode == Enum.KeyCode.S then
    --         addDirectionToSequence("DOWN")
    --     elseif input.KeyCode == Enum.KeyCode.A then
    --         addDirectionToSequence("LEFT")
    --     elseif input.KeyCode == Enum.KeyCode.D then
    --         addDirectionToSequence("RIGHT")
    --     end
    -- end
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == player then
        connection:Disconnect()
        screenGui:Destroy()
    end
end)

print("🎯 Directional Casting UI Demo loaded!")
print("📋 Instructions:")
print("   • Press K to start casting (triangles fade in)")
print("   • Move mouse to triangles to record directions")
print("   • Press K again to finish and see your sequence")
print("   • Press X during casting to enter modifier mode (red triangles)")
print("   • Press X again during modifier mode to stop everything")
print("   • Optional: Use WASD keys during casting for direct input")
