--!strict
--[[
    Nen Awakening Effects Module

    Handles the visual sequence when a player uses the Sacred Cup to discover their Nen type.
    Based on the Water Divination test from Hunter x Hunter.

    Nen Types and their probabilities:
    - Emission (27%) - Green
    - Enhancement (31%) - Yellow
    - Manipulation (20%) - Blue
    - Conjuration (22%) - Purple
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- EmitModule tags for bezier effects
local BEZIER_TAG = "BezierParticle"
local CONSTANT_VFX_TAG = "ConstantVFX"

local NenAwakeningEffects = {}

-- Nen type definitions with colors and probabilities
-- The Nen hexagon order (clockwise from top): Enhancement, Transmutation, Conjuration, Specialization, Manipulation, Emission
local NEN_TYPES = {
    {
        name = "Enhancement",
        probability = 0.31,
        color = Color3.fromRGB(255, 255, 0), -- Yellow
        description = "You are an Enhancer. Your aura strengthens and reinforces.",
        -- Adjacent: Emission (80%), Transmutation (80%)
        affinities = { Enhancement = 100, Emission = 80, Transmutation = 0, Manipulation = 80, Conjuration = 0, Specialization = 0 },
    },
    {
        name = "Emission",
        probability = 0.27,
        color = Color3.fromRGB(0, 255, 100), -- Green
        description = "You are an Emitter. Your aura can be projected and detached.",
        -- Adjacent: Enhancement (80%), Manipulation (80%)
        affinities = { Emission = 100, Enhancement = 80, Conjuration = 80, Manipulation = 0, Transmutation = 0, Specialization = 0 },
    },
    {
        name = "Conjuration",
        probability = 0.22,
        color = Color3.fromRGB(200, 100, 255), -- Purple
        description = "You are a Conjurer. Your aura can materialize objects.",
        -- Adjacent: Transmutation (80%), Specialization (80%)
        affinities = { Conjuration = 100, Emission = 80, Manipulation = 80, Enhancement = 0, Transmutation = 0, Specialization = 0 },
    },
    {
        name = "Manipulation",
        probability = 0.20,
        color = Color3.fromRGB(50, 150, 255), -- Blue
        description = "You are a Manipulator. Your aura can control objects and beings.",
        -- Adjacent: Emission (80%), Specialization (80%)
        affinities = { Manipulation = 100, Enhancement = 80, Conjuration = 80, Emission = 0, Transmutation = 0, Specialization = 0 },
    },
}

-- All 6 Nen types for the hexagon display (includes non-rollable types)
local NEN_HEXAGON_ORDER = { "Enhancement", "Transmutation", "Conjuration", "Specialization", "Manipulation", "Emission" }

-- Colors for each Nen type (for radar chart display)
local NEN_TYPE_COLORS = {
    Enhancement = Color3.fromRGB(255, 255, 0), -- Yellow
    Transmutation = Color3.fromRGB(255, 100, 100), -- Red/Pink
    Conjuration = Color3.fromRGB(200, 100, 255), -- Purple
    Specialization = Color3.fromRGB(128, 128, 128), -- Gray (cannot be rolled)
    Manipulation = Color3.fromRGB(50, 150, 255), -- Blue
    Emission = Color3.fromRGB(0, 255, 100), -- Green
}

-- Messages to display during the awakening sequence (extended for 20 second sequence)
local AWAKENING_MESSAGES = {
    { delay = 0, text = "Focus your aura into the cup..." },
    { delay = 3, text = "Feel the energy flowing from within..." },
    { delay = 6, text = "Your aura is reacting to the water..." },
    { delay = 9, text = "The water begins to change..." },
    { delay = 12, text = "Your true nature is emerging..." },
    { delay = 15, text = "Your Nen type is being revealed..." },
}

-- State tracking
local awakeningActive = false
local cleanupFunctions = {}

-- Store original lighting values for restoration
local originalLightingValues = {
    ccBrightness = nil,
    ccSaturation = nil,
    ccContrast = nil,
    ccTintColor = nil,
    bloomThreshold = nil,
    bloomIntensity = nil,
    bloomSize = nil,
}

-- Roll for Nen type based on weighted probabilities
local function rollNenType(): { name: string, color: Color3, description: string, affinities: { [string]: number } }
    local roll = math.random()
    local cumulative = 0

    for _, nenType in ipairs(NEN_TYPES) do
        cumulative = cumulative + nenType.probability
        if roll <= cumulative then
            return nenType
        end
    end

    -- Fallback to Enhancement
    return NEN_TYPES[1]
end

-- Store references to hidden UI elements for restoration
local hiddenUIElements = {}

-- GUIs that should stay visible during the awakening sequence
local AWAKENING_GUI_WHITELIST = {
    ["NenAwakeningGui"] = true,
    ["NenRadarChartGui"] = true,
}

-- Disable game UI during the awakening sequence
local function disableGameUI()
    local player = Players.LocalPlayer
    if not player then return end

    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end

    -- Hide all ScreenGuis except the awakening-related ones
    for _, gui in playerGui:GetChildren() do
        if gui:IsA("ScreenGui") and not AWAKENING_GUI_WHITELIST[gui.Name] then
            if gui.Enabled then
                table.insert(hiddenUIElements, { gui = gui, wasEnabled = true })
                gui.Enabled = false
            end
        end
    end

    -- Also hide Roblox core GUI elements
    local StarterGui = game:GetService("StarterGui")
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    end)
end

-- Re-enable game UI after the awakening sequence
local function enableGameUI()
    for _, data in ipairs(hiddenUIElements) do
        if data.gui and data.gui.Parent and data.wasEnabled then
            data.gui.Enabled = true
        end
    end
    table.clear(hiddenUIElements)

    -- Restore Roblox core GUI elements
    local StarterGui = game:GetService("StarterGui")
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
    end)
end

-- Create the Nen type radar chart (hexagon) showing affinities
local function createNenRadarChart(nenType: { affinities: { [string]: number } }): ScreenGui?
    local player = Players.LocalPlayer
    if not player then return nil end
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NenRadarChartGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui

    -- Main container - use a fixed pixel size frame for the hexagon
    local container = Instance.new("Frame")
    container.Name = "RadarContainer"
    container.Size = UDim2.fromOffset(350, 350)
    container.Position = UDim2.fromScale(0.5, 0.5)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.BackgroundTransparency = 1
    container.Parent = gui

    -- Hexagon parameters - all in scale (0-1) relative to the container
    local centerScale = 0.5
    local hexRadiusScale = 0.3 -- 30% of container size

    -- Calculate hexagon vertex positions in scale coordinates
    -- Order: Enhancement (top), Transmutation (top-right), Conjuration (bottom-right),
    --        Specialization (bottom), Manipulation (bottom-left), Emission (top-left)
    local hexPoints = {}
    for i = 1, 6 do
        local angle = math.rad(-90 + (i - 1) * 60) -- Start from top, go clockwise
        hexPoints[i] = {
            x = centerScale + math.cos(angle) * hexRadiusScale,
            y = centerScale + math.sin(angle) * hexRadiusScale,
            angle = angle
        }
    end

    -- Helper function to create a line between two scale-based points
    local function createLine(x1: number, y1: number, x2: number, y2: number, color: Color3, thicknessPx: number, name: string): Frame
        local line = Instance.new("Frame")
        line.Name = name
        line.BackgroundColor3 = color
        line.BorderSizePixel = 0
        line.BackgroundTransparency = 1
        line.Parent = container

        -- Calculate the midpoint
        local midX = (x1 + x2) / 2
        local midY = (y1 + y2) / 2

        -- Calculate the distance in scale units
        local dx = x2 - x1
        local dy = y2 - y1
        local dist = math.sqrt(dx * dx + dy * dy)

        -- Calculate angle
        local angle = math.deg(math.atan2(dy, dx))

        -- Position at midpoint, use scale for length
        line.Size = UDim2.new(dist, 0, 0, thicknessPx)
        line.Position = UDim2.fromScale(midX, midY)
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Rotation = angle

        return line
    end

    -- Draw outer hexagon outline (gray)
    for i = 1, 6 do
        local nextI = i % 6 + 1
        local p1, p2 = hexPoints[i], hexPoints[nextI]

        local line = createLine(p1.x, p1.y, p2.x, p2.y, Color3.fromRGB(150, 150, 150), 2, "HexOutline" .. i)

        -- Fade in animation
        task.delay(10 + i * 0.1, function()
            if gui.Parent then
                local tween = TweenService:Create(line, TweenInfo.new(0.5), { BackgroundTransparency = 0.2 })
                tween:Play()
            end
        end)
    end

    -- Draw lines from center to each vertex (spokes)
    for i = 1, 6 do
        local p = hexPoints[i]
        local line = createLine(centerScale, centerScale, p.x, p.y, Color3.fromRGB(100, 100, 100), 1, "Spoke" .. i)

        task.delay(10.5 + i * 0.1, function()
            if gui.Parent then
                local tween = TweenService:Create(line, TweenInfo.new(0.5), { BackgroundTransparency = 0.4 })
                tween:Play()
            end
        end)
    end

    -- Draw inner hexagon ring (at 50% radius) for reference
    local innerRadiusScale = hexRadiusScale * 0.5
    local innerPoints = {}
    for i = 1, 6 do
        local angle = hexPoints[i].angle
        innerPoints[i] = {
            x = centerScale + math.cos(angle) * innerRadiusScale,
            y = centerScale + math.sin(angle) * innerRadiusScale
        }
    end

    for i = 1, 6 do
        local nextI = i % 6 + 1
        local p1, p2 = innerPoints[i], innerPoints[nextI]

        local line = createLine(p1.x, p1.y, p2.x, p2.y, Color3.fromRGB(80, 80, 80), 1, "InnerHex" .. i)

        task.delay(11 + i * 0.1, function()
            if gui.Parent then
                local tween = TweenService:Create(line, TweenInfo.new(0.5), { BackgroundTransparency = 0.5 })
                tween:Play()
            end
        end)
    end

    -- Calculate affinity points (scaled by affinity percentage)
    local affinityPoints = {}
    for i, typeName in ipairs(NEN_HEXAGON_ORDER) do
        local affinity = (nenType.affinities[typeName] or 0) / 100
        local angle = hexPoints[i].angle
        local affinityRadiusScale = hexRadiusScale * affinity

        affinityPoints[i] = {
            x = centerScale + math.cos(angle) * affinityRadiusScale,
            y = centerScale + math.sin(angle) * affinityRadiusScale
        }
    end

    -- Draw affinity polygon (colored lines connecting affinity points)
    for i = 1, 6 do
        local nextI = i % 6 + 1
        local p1, p2 = affinityPoints[i], affinityPoints[nextI]
        local typeName = NEN_HEXAGON_ORDER[i]
        local typeColor = NEN_TYPE_COLORS[typeName] or Color3.new(1, 1, 1)

        local line = createLine(p1.x, p1.y, p2.x, p2.y, typeColor, 3, "AffinityEdge" .. i)

        -- Animate the affinity polygon appearing
        task.delay(13 + i * 0.15, function()
            if gui.Parent then
                local tween = TweenService:Create(line, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundTransparency = 0
                })
                tween:Play()
            end
        end)
    end

    -- Draw colored dots at affinity vertices
    for i, typeName in ipairs(NEN_HEXAGON_ORDER) do
        local point = affinityPoints[i]
        local typeColor = NEN_TYPE_COLORS[typeName] or Color3.new(1, 1, 1)

        local dot = Instance.new("Frame")
        dot.Name = "AffinityDot" .. i
        dot.Size = UDim2.fromOffset(10, 10)
        dot.Position = UDim2.fromScale(point.x, point.y)
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.BackgroundColor3 = typeColor
        dot.BorderSizePixel = 0
        dot.BackgroundTransparency = 1
        dot.Parent = container

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = dot

        task.delay(13.5 + i * 0.15, function()
            if gui.Parent then
                local tween = TweenService:Create(dot, TweenInfo.new(0.4), { BackgroundTransparency = 0 })
                tween:Play()
            end
        end)
    end

    -- Create labels for each Nen type with their affinity percentage
    for i, typeName in ipairs(NEN_HEXAGON_ORDER) do
        local angle = hexPoints[i].angle
        local labelRadiusScale = hexRadiusScale + 0.18 -- Labels outside the hexagon

        local labelX = centerScale + math.cos(angle) * labelRadiusScale
        local labelY = centerScale + math.sin(angle) * labelRadiusScale

        local affinity = nenType.affinities[typeName] or 0
        local typeColor = NEN_TYPE_COLORS[typeName] or Color3.new(1, 1, 1)

        local label = Instance.new("TextLabel")
        label.Name = typeName .. "Label"
        label.Size = UDim2.fromOffset(100, 36)
        label.Position = UDim2.fromScale(labelX, labelY)
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextColor3 = typeColor
        label.Text = typeName .. "\n" .. affinity .. "%"
        label.TextTransparency = 1 -- Start invisible
        label.Parent = container

        -- Add stroke for visibility
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.new(0, 0, 0)
        stroke.Thickness = 1.5
        stroke.Transparency = 1
        stroke.Parent = label

        -- Fade in animation
        task.delay(12 + i * 0.3, function()
            if gui.Parent then
                local tween = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 0 })
                tween:Play()
                local strokeTween = TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 0 })
                strokeTween:Play()
            end
        end)
    end

    -- Add center dot
    local centerDot = Instance.new("Frame")
    centerDot.Name = "CenterDot"
    centerDot.Size = UDim2.fromOffset(8, 8)
    centerDot.Position = UDim2.fromScale(centerScale, centerScale)
    centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
    centerDot.BackgroundColor3 = Color3.new(1, 1, 1)
    centerDot.BorderSizePixel = 0
    centerDot.BackgroundTransparency = 1
    centerDot.Parent = container

    local centerCorner = Instance.new("UICorner")
    centerCorner.CornerRadius = UDim.new(1, 0)
    centerCorner.Parent = centerDot

    task.delay(10, function()
        if gui.Parent then
            local tween = TweenService:Create(centerDot, TweenInfo.new(0.5), { BackgroundTransparency = 0.3 })
            tween:Play()
        end
    end)

    return gui
end

-- Get existing ColorCorrection from Lighting and store original values
local function getColorCorrection(): ColorCorrectionEffect?
    local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if cc then
        -- Store original values for restoration
        originalLightingValues.ccBrightness = cc.Brightness
        originalLightingValues.ccSaturation = cc.Saturation
        originalLightingValues.ccContrast = cc.Contrast
        originalLightingValues.ccTintColor = cc.TintColor
        return cc
    end
    return nil
end

-- Get existing Bloom from Lighting and store original values
local function getBloom(): BloomEffect?
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if bloom then
        -- Store original values for restoration
        originalLightingValues.bloomThreshold = bloom.Threshold
        originalLightingValues.bloomIntensity = bloom.Intensity
        originalLightingValues.bloomSize = bloom.Size
        return bloom
    end
    return nil
end

-- Create character highlight
local function createCharacterHighlight(character: Model): Highlight
    -- Remove existing highlight first
    local existing = character:FindFirstChild("NenAwakeningHighlight")
    if existing then
        existing:Destroy()
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "NenAwakeningHighlight"
    highlight.Adornee = character
    highlight.FillColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 1 -- Start fully transparent
    highlight.OutlineTransparency = 1
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = character

    return highlight
end

-- Cup highlight reference for external access
local cupHighlight: Highlight? = nil

-- Create cup highlight (same style as character highlight)
local function createCupHighlight(cupModel: Model | BasePart): Highlight?
    if not cupModel then return nil end

    -- Remove existing cup highlight first
    local existing = cupModel:FindFirstChild("NenCupHighlight")
    if existing then
        existing:Destroy()
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "NenCupHighlight"
    highlight.Adornee = cupModel
    highlight.FillColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 1 -- Start fully transparent
    highlight.OutlineTransparency = 1
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = cupModel

    cupHighlight = highlight
    return highlight
end

-- Clone Nen VFX to body parts
local function cloneNenVFXToCharacter(character: Model): { [string]: { any } }
    local vfxFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not vfxFolder then return {} end

    vfxFolder = vfxFolder:FindFirstChild("VFX")
    if not vfxFolder then return {} end

    local nenFolder = vfxFolder:FindFirstChild("Nen")
    if not nenFolder then
        warn("[NenAwakening] Nen VFX folder not found at ReplicatedStorage.Assets.VFX.Nen")
        return {}
    end

    local clonedEffects: { [string]: { any } } = {}

    -- Map folder names to R6 body part names
    local partMapping = {
        ["RightArm"] = "Right Arm",
        ["LeftArm"] = "Left Arm",
        ["RightLeg"] = "Right Leg",
        ["LeftLeg"] = "Left Leg",
        ["Torso"] = "Torso",
        ["Head"] = "Head",
    }

    for folderName, partName in pairs(partMapping) do
        local vfxPartFolder = nenFolder:FindFirstChild(folderName)
        local bodyPart = character:FindFirstChild(partName)

        if vfxPartFolder and bodyPart then
            clonedEffects[partName] = {}

            for _, vfx in vfxPartFolder:GetChildren() do
                local cloned = vfx:Clone()
                cloned.Parent = bodyPart
                table.insert(clonedEffects[partName], cloned)
            end
        end
    end

    return clonedEffects
end

-- Setup NenBezier effect centered on player using EmitModule
local function setupNenBezier(character: Model): (Part?, Attachment?)
    local vfxFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not vfxFolder then return nil, nil end

    vfxFolder = vfxFolder:FindFirstChild("VFX")
    if not vfxFolder then return nil, nil end

    local nenBezier = vfxFolder:FindFirstChild("NenBezier")
    if not nenBezier then
        warn("[NenAwakening] NenBezier not found at ReplicatedStorage.Assets.VFX.NenBezier")
        return nil, nil
    end

    local inwardsBezier = nenBezier:FindFirstChild("InwardsBezier")
    if not inwardsBezier then
        warn("[NenAwakening] InwardsBezier not found under NenBezier")
        return nil, nil
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end

    -- Clone the InwardsBezier
    local clonedBezier = inwardsBezier:Clone()
    clonedBezier.Name = "NenAwakeningBezier"

    -- Disable collision on all parts
    for _, descendant in clonedBezier:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.CanCollide = false
            descendant.Anchored = false
        end
    end

    -- Also disable collision on the main part if it's a BasePart
    if clonedBezier:IsA("BasePart") then
        clonedBezier.CanCollide = false
        clonedBezier.Anchored = false
    end

    -- Create weld to center on player
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hrp
    weld.Part1 = clonedBezier:IsA("BasePart") and clonedBezier or clonedBezier:FindFirstChildWhichIsA("BasePart")
    weld.Parent = clonedBezier

    -- Position at HRP
    if clonedBezier:IsA("BasePart") then
        clonedBezier.CFrame = hrp.CFrame
    elseif clonedBezier:IsA("Model") and clonedBezier.PrimaryPart then
        clonedBezier:SetPrimaryPartCFrame(hrp.CFrame)
    end

    -- Parent to workspace (required for EmitModule to detect it)
    clonedBezier.Parent = workspace

    -- Find the bezier attachment - look for any attachment with Points child (bezier structure)
    local bezierAttachment = nil
    for _, descendant in clonedBezier:GetDescendants() do
        if descendant:IsA("Attachment") and descendant:FindFirstChild("Points") then
            bezierAttachment = descendant
            break
        end
    end

    -- Fallback to finding by name
    if not bezierAttachment then
        bezierAttachment = clonedBezier:FindFirstChild("bezier", true)
    end

    -- Add EmitModule tags for continuous emission
    -- BezierParticle tag identifies it as a bezier effect
    -- ConstantVFX tag enables the RenderStepped loop for continuous emission
    if bezierAttachment then
        CollectionService:AddTag(bezierAttachment, BEZIER_TAG)
        CollectionService:AddTag(bezierAttachment, CONSTANT_VFX_TAG)

        -- Set Duration for how long each particle travels along the bezier path
        -- NumberRange controls min/max duration for each particle
        bezierAttachment:SetAttribute("Duration", NumberRange.new(5,7))

        -- Set initial Rate low and Enabled to true for EmitModule to pick up
        bezierAttachment:SetAttribute("Rate", 3) -- Start with slow rate
        bezierAttachment:SetAttribute("Enabled", true)
    end

    return clonedBezier, bezierAttachment
end

-- Animate bezier rate from slow to fast using EmitModule's Rate attribute
-- The bezier stays enabled throughout the entire sequence until cleanup
local function animateBezierRate(attachment: Attachment?, targetRate: number, duration: number)
    if not attachment then return end

    local startRate = attachment:GetAttribute("Rate") or 3
    local startTime = tick()

    -- Ensure Enabled is true for EmitModule to process - stays enabled until cleanup
    attachment:SetAttribute("Enabled", true)

    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not attachment or not attachment.Parent then
            if connection then connection:Disconnect() end
            return
        end

        local elapsed = tick() - startTime
        local progress = math.clamp(elapsed / duration, 0, 1)

        -- Ease in cubic - start slow, accelerate towards end
        local easedProgress = progress * progress * progress
        local currentRate = startRate + (targetRate - startRate) * easedProgress

        -- Set Rate attribute which EmitModule reads to control emission frequency
        attachment:SetAttribute("Rate", currentRate)

        -- Keep running even after reaching target rate - bezier stays active
        -- The rate animation completes but emission continues at target rate
        if progress >= 1 then
            connection:Disconnect()
            -- Keep at target rate - don't disable, emission continues
            attachment:SetAttribute("Rate", targetRate)
        end
    end)

    -- Only disable bezier on cleanup (when StopAwakening is called)
    table.insert(cleanupFunctions, function()
        if connection then connection:Disconnect() end
        -- Disable the bezier emission on cleanup
        if attachment and attachment.Parent then
            attachment:SetAttribute("Enabled", false)
        end
    end)
end

-- Remove EmitModule tags on cleanup
local function cleanupBezierTags(attachment: Attachment?)
    if not attachment then return end

    -- Remove tags so EmitModule stops processing
    CollectionService:RemoveTag(attachment, CONSTANT_VFX_TAG)
    CollectionService:RemoveTag(attachment, BEZIER_TAG)
end

-- Change color of all Nen VFX (particles, beams, trails)
local function changeNenVFXColor(clonedEffects: { [string]: { any } }, bezierPart: Part?, targetColor: Color3, duration: number)
    local startTime = tick()

    local function updateColors(progress: number)
        -- Update cloned body part effects
        for _, effectList in pairs(clonedEffects) do
            for _, effect in ipairs(effectList) do
                for _, descendant in effect:GetDescendants() do
                    if descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") then
                        -- Lerp color
                        local currentColor = descendant.Color
                        if typeof(currentColor) == "ColorSequence" then
                            local keypoints = currentColor.Keypoints
                            local newKeypoints = {}
                            for _, kp in ipairs(keypoints) do
                                local lerpedColor = kp.Value:Lerp(targetColor, progress)
                                table.insert(newKeypoints, ColorSequenceKeypoint.new(kp.Time, lerpedColor))
                            end
                            descendant.Color = ColorSequence.new(newKeypoints)
                        end
                    elseif descendant:IsA("Trail") then
                        local currentColor = descendant.Color
                        if typeof(currentColor) == "ColorSequence" then
                            local keypoints = currentColor.Keypoints
                            local newKeypoints = {}
                            for _, kp in ipairs(keypoints) do
                                local lerpedColor = kp.Value:Lerp(targetColor, progress)
                                table.insert(newKeypoints, ColorSequenceKeypoint.new(kp.Time, lerpedColor))
                            end
                            descendant.Color = ColorSequence.new(newKeypoints)
                        end
                    end
                end
            end
        end

        -- Update bezier trail and particles
        if bezierPart then
            for _, descendant in bezierPart:GetDescendants() do
                if descendant:IsA("Trail") then
                    local newColorSeq = ColorSequence.new(targetColor)
                    descendant.Color = newColorSeq
                elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") then
                    local currentColor = descendant.Color
                    if typeof(currentColor) == "ColorSequence" then
                        local newColorSeq = ColorSequence.new(targetColor)
                        descendant.Color = newColorSeq
                    end
                end
            end
        end
    end

    local connection
    connection = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        local progress = math.clamp(elapsed / duration, 0, 1)

        updateColors(progress)

        if progress >= 1 then
            connection:Disconnect()
        end
    end)

    table.insert(cleanupFunctions, function()
        if connection then connection:Disconnect() end
    end)
end

-- Show awakening message on screen
local function showAwakeningMessage(text: string, duration: number?)
    local player = Players.LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end

    -- Create or get screen GUI
    local screenGui = playerGui:FindFirstChild("NenAwakeningGui")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "NenAwakeningGui"
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screenGui.Parent = playerGui
    end

    -- Remove existing message
    local existingLabel = screenGui:FindFirstChild("AwakeningMessage")
    if existingLabel then
        existingLabel:Destroy()
    end

    -- Create message label
    local label = Instance.new("TextLabel")
    label.Name = "AwakeningMessage"
    label.Size = UDim2.new(0.8, 0, 0.15, 0)
    label.Position = UDim2.new(0.1, 0, 0.4, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 28
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Text = text
    label.TextWrapped = true
    label.TextTransparency = 1
    label.Parent = screenGui

    -- Fade in
    local fadeIn = TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency = 0
    })
    fadeIn:Play()

    -- Schedule fade out if duration provided
    if duration and duration > 0 then
        task.delay(duration, function()
            if label.Parent then
                local fadeOut = TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    TextTransparency = 1
                })
                fadeOut:Play()
                fadeOut.Completed:Wait()
                if label.Parent then
                    label:Destroy()
                end
            end
        end)
    end

    return label
end

-- Show final Nen type reveal message
local function showNenTypeReveal(nenType: { name: string, color: Color3, description: string })
    local player = Players.LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local screenGui = playerGui:FindFirstChild("NenAwakeningGui")
    if not screenGui then return end

    -- Clear existing messages
    for _, child in screenGui:GetChildren() do
        child:Destroy()
    end

    -- Create container
    local container = Instance.new("Frame")
    container.Name = "NenTypeReveal"
    container.Size = UDim2.new(0.6, 0, 0.4, 0)
    container.Position = UDim2.new(0.2, 0, 0.3, 0)
    container.BackgroundTransparency = 1
    container.Parent = screenGui

    -- Nen type name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NenTypeName"
    nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
    nameLabel.Position = UDim2.new(0, 0, 0.1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextSize = 48
    nameLabel.TextColor3 = nenType.color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Text = nenType.name
    nameLabel.TextTransparency = 1
    nameLabel.TextScaled = true
    nameLabel.Parent = container

    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "NenTypeDesc"
    descLabel.Size = UDim2.new(1, 0, 0.3, 0)
    descLabel.Position = UDim2.new(0, 0, 0.55, 0)
    descLabel.BackgroundTransparency = 1
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 24
    descLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    descLabel.TextStrokeTransparency = 0.3
    descLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    descLabel.Text = nenType.description
    descLabel.TextWrapped = true
    descLabel.TextTransparency = 1
    descLabel.Parent = container

    -- Animate reveal
    local nameTween = TweenService:Create(nameLabel, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextTransparency = 0
    })
    nameTween:Play()

    task.delay(0.5, function()
        local descTween = TweenService:Create(descLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TextTransparency = 0
        })
        descTween:Play()
    end)
end

-- Cleanup all effects and restore original lighting values
local function cleanup()
    for _, cleanupFunc in ipairs(cleanupFunctions) do
        pcall(cleanupFunc)
    end
    table.clear(cleanupFunctions)

    -- Remove awakening GUI
    local player = Players.LocalPlayer
    if player then
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            local gui = playerGui:FindFirstChild("NenAwakeningGui")
            if gui then
                gui:Destroy()
            end

            -- Fade out and remove radar chart GUI
            local radarGui = playerGui:FindFirstChild("NenRadarChartGui")
            if radarGui then
                local container = radarGui:FindFirstChild("RadarContainer")
                if container then
                    -- Collect all elements that need to fade out
                    local fadeOutTweens = {}

                    for _, child in container:GetChildren() do
                        if child:IsA("Frame") then
                            local tween = TweenService:Create(child, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                BackgroundTransparency = 1
                            })
                            tween:Play()
                            table.insert(fadeOutTweens, tween)
                        elseif child:IsA("TextLabel") then
                            local tween = TweenService:Create(child, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                TextTransparency = 1
                            })
                            tween:Play()
                            table.insert(fadeOutTweens, tween)

                            -- Also fade out UIStroke if present
                            local stroke = child:FindFirstChildOfClass("UIStroke")
                            if stroke then
                                local strokeTween = TweenService:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                    Transparency = 1
                                })
                                strokeTween:Play()
                            end
                        end
                    end

                    -- Destroy after fade completes
                    task.delay(0.5, function()
                        if radarGui and radarGui.Parent then
                            radarGui:Destroy()
                        end
                    end)
                else
                    radarGui:Destroy()
                end
            end
        end
    end

    -- Re-enable game UI
    enableGameUI()

    -- Restore original ColorCorrection values
    local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if cc and originalLightingValues.ccBrightness ~= nil then
        local resetTween = TweenService:Create(cc, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Brightness = originalLightingValues.ccBrightness,
            Saturation = originalLightingValues.ccSaturation,
            Contrast = originalLightingValues.ccContrast,
        })
        resetTween:Play()
    end

    -- Restore original Bloom values
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if bloom and originalLightingValues.bloomThreshold ~= nil then
        local resetBloomTween = TweenService:Create(bloom, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Threshold = originalLightingValues.bloomThreshold,
            Intensity = originalLightingValues.bloomIntensity,
        })
        resetBloomTween:Play()
    end

    -- Clear stored values
    originalLightingValues.ccBrightness = nil
    originalLightingValues.ccSaturation = nil
    originalLightingValues.ccContrast = nil
    originalLightingValues.ccTintColor = nil
    originalLightingValues.bloomThreshold = nil
    originalLightingValues.bloomIntensity = nil
    originalLightingValues.bloomSize = nil

    awakeningActive = false
end

-- Main awakening sequence
function NenAwakeningEffects.StartAwakening(character: Model, cupModel: (Model | BasePart)?): string?
    if awakeningActive then
        warn("[NenAwakening] Awakening already in progress!")
        return nil
    end

    awakeningActive = true

    -- Disable game UI during the awakening sequence
    disableGameUI()

    -- Roll for Nen type first (but don't reveal yet)
    local nenType = rollNenType()
    print("[NenAwakening] Rolled Nen type:", nenType.name)

    -- Create the radar chart showing Nen type affinities (will animate in during the sequence)
    local radarChart = createNenRadarChart(nenType)
    if radarChart then
        table.insert(cleanupFunctions, function()
            if radarChart and radarChart.Parent then
                radarChart:Destroy()
            end
        end)
    end

    -- Step 1: Tween existing color correction to -1 brightness (very dark)
    local cc = getColorCorrection()
    if cc then
        local ccTween = TweenService:Create(cc, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Brightness = -1,
            Saturation = -0.3,
        })
        ccTween:Play()
    end

    -- Step 2: Add character highlight (start transparent, tween to 0.55)
    local highlight = createCharacterHighlight(character)
    task.delay(0.5, function()
        local highlightTween = TweenService:Create(highlight, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            FillTransparency = 0.55,
            OutlineTransparency = 0.3,
        })
        highlightTween:Play()
    end)

    table.insert(cleanupFunctions, function()
        if highlight.Parent then
            highlight:Destroy()
        end
    end)

    -- Step 2b: Add cup highlight if cup model provided (same style as character)
    if cupModel then
        local cupHL = createCupHighlight(cupModel)
        if cupHL then
            task.delay(0.5, function()
                if cupHL.Parent then
                    local cupHLTween = TweenService:Create(cupHL, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        FillTransparency = 0.55,
                        OutlineTransparency = 0.3,
                    })
                    cupHLTween:Play()
                end
            end)

            table.insert(cleanupFunctions, function()
                if cupHL and cupHL.Parent then
                    cupHL:Destroy()
                end
                cupHighlight = nil
            end)
        end
    end

    -- Step 3: Clone Nen VFX to body parts
    local clonedEffects = cloneNenVFXToCharacter(character)

    table.insert(cleanupFunctions, function()
        for _, effectList in pairs(clonedEffects) do
            for _, effect in ipairs(effectList) do
                if effect.Parent then
                    effect:Destroy()
                end
            end
        end
    end)

    -- Step 4: Decrease existing bloom threshold
    local bloom = getBloom()
    if bloom then
        local bloomTween = TweenService:Create(bloom, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Threshold = 0.8,
            Intensity = 1,
        })
        bloomTween:Play()
    end

    -- Step 5: Setup NenBezier (tags are added in setupNenBezier, EmitModule auto-detects via ConstantVFX tag)
    local bezierPart, bezierAttachment = setupNenBezier(character)

    table.insert(cleanupFunctions, function()
        -- Clean up bezier tags first so EmitModule stops processing
        cleanupBezierTags(bezierAttachment)
        if bezierPart and bezierPart.Parent then
            bezierPart:Destroy()
        end
    end)

    -- Step 6: Animate bezier rate - EmitModule handles emission via ConstantVFX tag
    if bezierAttachment then
        -- Start with slow rate, ramp up over 18 seconds (keeps emitting until cleanup)
        bezierAttachment:SetAttribute("Rate", 3)
        animateBezierRate(bezierAttachment, 50, 18)
    end

    -- Step 7: Show awakening messages
    for _, messageData in ipairs(AWAKENING_MESSAGES) do
        task.delay(messageData.delay, function()
            if awakeningActive then
                showAwakeningMessage(messageData.text, 2.5)
            end
        end)
    end

    -- Step 8: Gradually change VFX colors to match Nen type (starts at second 10 for 20 second sequence)
    task.delay(10, function()
        if awakeningActive then
            -- Color transition over 5 seconds
            changeNenVFXColor(clonedEffects, bezierPart, nenType.color, 5)

            -- Also tween highlight color
            if highlight.Parent then
                local highlightColorTween = TweenService:Create(highlight, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                    FillColor = nenType.color,
                    OutlineColor = nenType.color,
                })
                highlightColorTween:Play()
            end

            -- Also tween cup highlight color if it exists
            if cupHighlight and cupHighlight.Parent then
                local cupHLColorTween = TweenService:Create(cupHighlight, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                    FillColor = nenType.color,
                    OutlineColor = nenType.color,
                })
                cupHLColorTween:Play()
            end
        end
    end)

    -- Step 9: Reveal Nen type (at second 17 for 20 second sequence)
    task.delay(17, function()
        if awakeningActive then
            showNenTypeReveal(nenType)
        end
    end)

    -- Return the Nen type name for quest system to use
    return nenType.name
end

-- Stop awakening and cleanup
function NenAwakeningEffects.StopAwakening()
    cleanup()
end

-- Check if awakening is active
function NenAwakeningEffects.IsAwakeningActive(): boolean
    return awakeningActive
end

-- Get Nen type colors for external use
function NenAwakeningEffects.GetNenTypeColor(nenTypeName: string): Color3?
    for _, nenType in ipairs(NEN_TYPES) do
        if nenType.name == nenTypeName then
            return nenType.color
        end
    end
    return nil
end

return NenAwakeningEffects
