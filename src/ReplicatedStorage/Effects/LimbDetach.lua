-- LimbDetach Effects Module
-- Handles visual effects for limb loss (client-side)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Replicated = game:GetService("ReplicatedStorage")
local TextPlus = require(Replicated.Modules.Utils.Text)

local LimbDetach = {}

-- Check if a model is inside any NpcRegistryCamera
local function isInNpcRegistryCamera(inst)
	local parent = inst.Parent
	while parent do
		if parent.Name == "NpcRegistryCamera" then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- Resolve Chrono NPC server model references to client clones
local function resolveChronoModel(model: Model?): Model?
	if not model then return nil end

	if Players:GetPlayerFromCharacter(model) then
		return model
	end

	if not isInNpcRegistryCamera(model) then
		return model
	end

	local clientCamera = nil
	for _, child in workspace:GetChildren() do
		if child.Name == "NpcRegistryCamera" and child:IsA("Camera") and child:GetAttribute("ClientOwned") then
			clientCamera = child
			break
		end
	end

	local chronoId = model:GetAttribute("ChronoId")
	if chronoId and clientCamera then
		local clientClone = clientCamera:FindFirstChild(tostring(chronoId), true)
		if clientClone and clientClone:IsA("Model") then
			return clientClone
		end
	end

	if clientCamera and model.Name then
		local byName = clientCamera:FindFirstChild(model.Name, true)
		if byName and byName:IsA("Model") then
			return byName
		end
	end

	return model
end

-- Warning messages that cycle through (with placeholder for limb name)
local WARNING_MESSAGES = {
	"SEEK A DOCTOR",
	"YOU'RE BLEEDING OUT",
	"%s SEVERED",  -- %s will be replaced with limb name
	"FIND MEDICAL AID",
	"CRITICAL INJURY",
}

-- Limb display names for warning messages
local LimbDisplayNames = {
	LeftArm = "LEFT ARM",
	RightArm = "RIGHT ARM",
	LeftLeg = "LEFT LEG",
	RightLeg = "RIGHT LEG",
}

-- Limb part names (R6)
local LimbParts = {
    LeftArm = "Left Arm",
    RightArm = "Right Arm",
    LeftLeg = "Left Leg",
    RightLeg = "Right Leg",
}

function LimbDetach.SeverLimb(character: Model, limbName: string, attacker: Model)
    character = resolveChronoModel(character) :: Model
    attacker = resolveChronoModel(attacker) :: Model
    local limbPartName = LimbParts[limbName]
    if not limbPartName or not character then return end

    local limb = character:FindFirstChild(limbPartName)
    if not limb then return end

    -- Calculate direction (away from attacker)
    local attackerRoot = attacker and attacker:FindFirstChild("HumanoidRootPart")
    local targetRoot = character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local direction: Vector3
    if attackerRoot then
        direction = (targetRoot.Position - attackerRoot.Position).Unit
    else
        direction = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
    end

    local upward = Vector3.new(0, 1, 0)

    -- Apply physics velocity to the limb
    local velocity = (direction * 30) + (upward * 20) + Vector3.new(
        (math.random() - 0.5) * 10,
        math.random() * 10,
        (math.random() - 0.5) * 10
    )

    -- Create BodyVelocity for initial impulse
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = velocity
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Parent = limb
    Debris:AddItem(bodyVelocity, 0.3)

    -- Add angular velocity for tumbling
    local angularVelocity = Instance.new("BodyAngularVelocity")
    angularVelocity.AngularVelocity = Vector3.new(
        (math.random() - 0.5) * 20,
        (math.random() - 0.5) * 20,
        (math.random() - 0.5) * 20
    )
    angularVelocity.MaxTorque = Vector3.new(1000, 1000, 1000)
    angularVelocity.Parent = limb
    Debris:AddItem(angularVelocity, 1)

    -- Blood splatter VFX at severance point
    local bloodVFX = Replicated.Assets.VFX.Blood:FindFirstChild("Splatter")
    if bloodVFX then
        local splatter = bloodVFX:Clone()
        splatter.Parent = limb
        if splatter:IsA("ParticleEmitter") then
            splatter:Emit(20)
        elseif splatter:IsA("Attachment") then
            for _, emitter in splatter:GetDescendants() do
                if emitter:IsA("ParticleEmitter") then
                    emitter:Emit(20)
                end
            end
        end
        Debris:AddItem(splatter, 5)
    end

    -- Blood trail on the limb
    local bloodTrail = Replicated.Assets.VFX.Blood:FindFirstChild("Trail")
    if bloodTrail then
        local trail = bloodTrail:Clone()
        trail.Parent = limb
        if trail:IsA("Trail") then
            trail.Enabled = true
        end
        Debris:AddItem(trail, 10)
    end

    -- Play severing sound
    local severSound = Replicated.Assets.SFX.Hits.Blood:GetChildren()
    if #severSound > 0 then
        local sound = severSound[math.random(1, #severSound)]:Clone()
        sound.Parent = limb
        sound:Play()
        Debris:AddItem(sound, sound.TimeLength + 0.1)
    end

    -- Fade and destroy limb after 8 seconds
    task.delay(8, function()
        if limb and limb.Parent then
            local fadeInfo = TweenInfo.new(2, Enum.EasingStyle.Quad)
            local fadeTween = TweenService:Create(limb, fadeInfo, {
                Transparency = 1
            })
            fadeTween:Play()
            fadeTween.Completed:Connect(function()
                if limb and limb.Parent then
                    limb:Destroy()
                end
            end)
        end
    end)

    -- Screen effect for victim (blood splatter on screen edges)
    local player = Players.LocalPlayer
    local victimPlayer = Players:GetPlayerFromCharacter(character)

    if player and victimPlayer == player then
        LimbDetach.LimbLossScreen(limbName)
    end
end

-- Screen blood effect when local player loses a limb
function LimbDetach.LimbLossScreen(limbName: string)
    local player = Players.LocalPlayer
    if not player then return end

    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end

    -- Remove any existing limb loss effect
    local existing = playerGui:FindFirstChild("LimbLossEffect")
    if existing then existing:Destroy() end

    -- Create blood vignette effect
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LimbLossEffect"
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 100
    screenGui.Parent = playerGui

    -- Full screen red tint flash
    local redTint = Instance.new("Frame")
    redTint.Name = "RedTint"
    redTint.Size = UDim2.fromScale(1, 1)
    redTint.Position = UDim2.fromScale(0, 0)
    redTint.BackgroundColor3 = Color3.fromRGB(139, 0, 0) -- Dark red
    redTint.BackgroundTransparency = 1
    redTint.BorderSizePixel = 0
    redTint.ZIndex = 1
    redTint.Parent = screenGui

    -- Blood vignette frame
    local vignette = Instance.new("ImageLabel")
    vignette.Name = "BloodVignette"
    vignette.Size = UDim2.fromScale(1, 1)
    vignette.Position = UDim2.fromScale(0.5, 0.5)
    vignette.AnchorPoint = Vector2.new(0.5, 0.5)
    vignette.BackgroundTransparency = 1
    vignette.Image = "rbxassetid://1171967896" -- Vignette image
    vignette.ImageColor3 = Color3.fromRGB(139, 0, 0) -- Dark red
    vignette.ImageTransparency = 0.3
    vignette.ZIndex = 2
    vignette.Parent = screenGui

    -- Warning text container (center of screen)
    local textContainer = Instance.new("Frame")
    textContainer.Name = "WarningTextContainer"
    textContainer.Size = UDim2.fromScale(0.8, 0.15)
    textContainer.Position = UDim2.fromScale(0.5, 0.5)
    textContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    textContainer.BackgroundTransparency = 1
    textContainer.ZIndex = 10
    textContainer.Parent = screenGui

    -- Flash the red tint
    local tintFlashIn = TweenService:Create(redTint, TweenInfo.new(0.05), {
        BackgroundTransparency = 0.5
    })
    local tintFlashOut = TweenService:Create(redTint, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 0.85
    })

    tintFlashIn:Play()
    tintFlashIn.Completed:Connect(function()
        tintFlashOut:Play()
    end)

    -- Flash vignette
    local flashIn = TweenService:Create(vignette, TweenInfo.new(0.1), {
        ImageTransparency = 0
    })
    flashIn:Play()

    -- Camera shake
    local CamShake = require(Replicated.Modules.Utils.CamShake)
    if CamShake then
        CamShake({
            Location = workspace.CurrentCamera.CFrame.Position,
            Magnitude = 8,
            Damp = 0.00005,
            Frequency = 25,
            Influence = Vector3.new(1, 1, 1),
            Falloff = 1000,
        })
    end

    -- Cycle through warning messages with TextPlus
    local messageIndex = 1
    local warningActive = true
    local lastTextFrame = nil

    local function showNextMessage()
        if not warningActive or not screenGui.Parent then return end

        -- Clear previous text
        if lastTextFrame then
            -- Fade out animation
            for _, child in lastTextFrame:GetChildren() do
                if child:IsA("TextLabel") or child:IsA("ImageLabel") then
                    local fadeOut = TweenService:Create(child, TweenInfo.new(0.1), {
                        [child:IsA("TextLabel") and "TextTransparency" or "ImageTransparency"] = 1
                    })
                    fadeOut:Play()
                end
            end
            task.delay(0.1, function()
                if lastTextFrame and lastTextFrame.Parent then
                    lastTextFrame:Destroy()
                end
            end)
        end

        -- Create new text frame
        local textFrame = Instance.new("Frame")
        textFrame.Name = "WarningText"
        textFrame.Size = UDim2.fromScale(1, 1)
        textFrame.Position = UDim2.fromScale(0, 0)
        textFrame.BackgroundTransparency = 1
        textFrame.Parent = textContainer
        lastTextFrame = textFrame

        -- Create the warning text with TextPlus
        local message = WARNING_MESSAGES[messageIndex]
        -- Replace %s with limb name if present
        if message:find("%%s") then
            local limbDisplayName = LimbDisplayNames[limbName] or "LIMB"
            message = message:format(limbDisplayName)
        end
        TextPlus.Create(textFrame, message, {
            Font = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Bold),
            Size = 48,
            Color = Color3.fromRGB(255, 50, 50), -- Bright red
            StrokeSize = 3,
            StrokeColor = Color3.fromRGB(0, 0, 0),
            StrokeTransparency = 0.3,
            XAlignment = "Center",
            YAlignment = "Center",
            Dynamic = false,
        })

        -- Animate text appearing with shake effect
        for _, child in textFrame:GetChildren() do
            if child:IsA("TextLabel") or child:IsA("ImageLabel") then
                local originalPos = child.Position
                local isText = child:IsA("TextLabel")

                -- Start invisible and offset
                if isText then
                    child.TextTransparency = 1
                else
                    child.ImageTransparency = 1
                end
                child.Position = originalPos + UDim2.fromOffset(math.random(-5, 5), math.random(-3, 3))

                -- Animate in
                local fadeIn = TweenService:Create(child, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Position = originalPos,
                    [isText and "TextTransparency" or "ImageTransparency"] = 0
                })
                fadeIn:Play()
            end
        end

        messageIndex = (messageIndex % #WARNING_MESSAGES) + 1
    end

    -- Show first message immediately
    showNextMessage()

    -- Cycle messages every 0.8 seconds for 4 seconds
    local cycleCount = 0
    local maxCycles = 5
    task.spawn(function()
        while warningActive and cycleCount < maxCycles and screenGui.Parent do
            task.wait(0.8)
            cycleCount = cycleCount + 1
            if warningActive and screenGui.Parent then
                showNextMessage()
            end
        end
    end)

    -- Fade out everything after 4 seconds
    task.delay(4, function()
        warningActive = false
        if not screenGui.Parent then return end

        -- Fade out all elements
        local fadeOutInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad)

        local fadeRedTint = TweenService:Create(redTint, fadeOutInfo, {
            BackgroundTransparency = 1
        })
        local fadeVignette = TweenService:Create(vignette, fadeOutInfo, {
            ImageTransparency = 1
        })

        fadeRedTint:Play()
        fadeVignette:Play()

        -- Fade out text
        if lastTextFrame and lastTextFrame.Parent then
            for _, child in lastTextFrame:GetChildren() do
                if child:IsA("TextLabel") or child:IsA("ImageLabel") then
                    local fadeOut = TweenService:Create(child, fadeOutInfo, {
                        [child:IsA("TextLabel") and "TextTransparency" or "ImageTransparency"] = 1
                    })
                    fadeOut:Play()
                end
            end
        end

        fadeVignette.Completed:Connect(function()
            if screenGui.Parent then
                screenGui:Destroy()
            end
        end)
    end)
end

return LimbDetach
