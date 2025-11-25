--[[
    Server-side Bvel module for NPCs and non-player characters
    Mirrors the client-side Bvel functions
--]]

local ServerBvel = {}

-- BF Knockback (for Pincer Impact Black Flash variant)
ServerBvel.BFKnockback = function(Character, direction, horizontalPower, upwardPower)
    local rootPart = Character.PrimaryPart
    if not rootPart then
        warn("[ServerBvel] No PrimaryPart found for BFKnockback")
        return
    end

    -- Clean up ALL existing BodyMovers and LinearVelocities that might interfere with knockback
    for _, child in ipairs(rootPart:GetChildren()) do
        if child:IsA("BodyPosition") or child:IsA("BodyGyro") or child:IsA("BodyVelocity") or child:IsA("LinearVelocity") then
            child:Destroy()
            -- print(`[ServerBvel] Removed interfering {child.ClassName} from {Character.Name}`)
        end
    end

    -- Create attachment
    local attachment = rootPart:FindFirstChild("BFKnockbackAttachment")
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "BFKnockbackAttachment"
        attachment.Parent = rootPart
    end

    -- Calculate velocity vector (horizontal + upward arc)
    local horizontalDir = Vector3.new(direction.X, 0, direction.Z).Unit
    local velocity = Vector3.new(
        horizontalDir.X * horizontalPower,
        upwardPower,
        horizontalDir.Z * horizontalPower
    )

    -- Create LinearVelocity
    local lv = Instance.new("LinearVelocity")
    lv.Name = "BFKnockbackVelocity"
    lv.MaxForce = 200000  -- Reduced from math.huge to prevent excessive force
    lv.VectorVelocity = velocity
    lv.Attachment0 = attachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = rootPart

    -- print(`[ServerBvel] Applied BFKnockback to {Character.Name}: H={horizontalPower}, U={upwardPower}`)

    -- Clean up after duration (only destroy LinearVelocity, not attachment)
    task.delay(0.65, function()
        if lv and lv.Parent then
            lv:Destroy()
        end
    end)
end

-- Parry Knockback (snappier, eased knockback for parry reactions)
ServerBvel.ParryKnockback = function(Character, direction, horizontalPower)
    print(`[PARRY KNOCKBACK DEBUG] Called for {Character.Name} with power {horizontalPower}`)
    local TweenService = game:GetService("TweenService")
    local rootPart = Character.PrimaryPart
    if not rootPart then
        warn("[ServerBvel] No PrimaryPart found for ParryKnockback")
        return
    end
    print(`[PARRY KNOCKBACK DEBUG] {Character.Name} - PrimaryPart found, applying knockback`)

    -- Clean up ALL existing BodyMovers and LinearVelocities that might interfere with knockback
    for _, child in ipairs(rootPart:GetChildren()) do
        if child:IsA("BodyPosition") or child:IsA("BodyGyro") or child:IsA("BodyVelocity") or child:IsA("LinearVelocity") then
            child:Destroy()
        end
    end

    -- Create attachment
    local attachment = rootPart:FindFirstChild("ParryKnockbackAttachment")
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "ParryKnockbackAttachment"
        attachment.Parent = rootPart
    end

    -- Calculate velocity vector (horizontal only, no upward)
    local horizontalDir = Vector3.new(direction.X, 0, direction.Z).Unit
    local velocity = Vector3.new(
        horizontalDir.X * horizontalPower,
        0,
        horizontalDir.Z * horizontalPower
    )

    -- Create LinearVelocity
    local lv = Instance.new("LinearVelocity")
    lv.Name = "ParryKnockbackVelocity"
    lv.MaxForce = 200000
    lv.VectorVelocity = velocity
    lv.Attachment0 = attachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = rootPart

    -- Tween the velocity to 0 with snappy easing (Quint Out for snappy deceleration)
    local tweenInfo = TweenInfo.new(
        0.4, -- Duration matches knockback duration
        Enum.EasingStyle.Quint, -- Quint for snappier feel
        Enum.EasingDirection.Out -- Ease out for deceleration
    )

    local tween = TweenService:Create(lv, tweenInfo, {
        VectorVelocity = Vector3.new(0, 0, 0)
    })
    tween:Play()

    -- Clean up after duration
    task.delay(0.4, function()
        if lv and lv.Parent then
            lv:Destroy()
        end
    end)
end

return ServerBvel

