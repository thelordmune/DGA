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
            ---- print(`[ServerBvel] Removed interfering {child.ClassName} from {Character.Name}`)
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

    ---- print(`[ServerBvel] Applied BFKnockback to {Character.Name}: H={horizontalPower}, U={upwardPower}`)

    -- Clean up after duration (only destroy LinearVelocity, not attachment)
    task.delay(0.65, function()
        if lv and lv.Parent then
            lv:Destroy()
        end
    end)
end

-- Parry Knockback (snappier, eased knockback for parry reactions)
ServerBvel.ParryKnockback = function(Character, direction, horizontalPower)
   -- print(`[PARRY KNOCKBACK DEBUG] Called for {Character.Name} with power {horizontalPower}`)
    local TweenService = game:GetService("TweenService")
    local rootPart = Character.PrimaryPart
    if not rootPart then
        warn("[ServerBvel] No PrimaryPart found for ParryKnockback")
        return
    end
   -- print(`[PARRY KNOCKBACK DEBUG] {Character.Name} - PrimaryPart found, applying knockback`)

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

-- Upward Knockback (for Axe Kick and similar moves)
ServerBvel.UpwardKnockback = function(Character, upwardPower)
    local rootPart = Character.PrimaryPart
    if not rootPart then
        warn("[ServerBvel] No PrimaryPart found for UpwardKnockback")
        return
    end

    -- Clean up ALL existing BodyMovers and LinearVelocities that might interfere with knockback
    for _, child in ipairs(rootPart:GetChildren()) do
        if child:IsA("BodyPosition") or child:IsA("BodyGyro") or child:IsA("BodyVelocity") or child:IsA("LinearVelocity") then
            child:Destroy()
        end
    end

    -- Create attachment
    local attachment = rootPart:FindFirstChild("UpwardKnockbackAttachment")
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "UpwardKnockbackAttachment"
        attachment.Parent = rootPart
    end

    -- Create upward velocity
    local velocity = Vector3.new(0, upwardPower, 0)

    -- Create LinearVelocity
    local lv = Instance.new("LinearVelocity")
    lv.Name = "UpwardKnockbackVelocity"
    lv.MaxForce = 200000
    lv.VectorVelocity = velocity
    lv.Attachment0 = attachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = rootPart

    -- Clean up after duration
    task.delay(0.5, function()
        if lv and lv.Parent then
            lv:Destroy()
        end
    end)
end

-- Pull Velocity (for Charged Thrust and similar grab moves)
ServerBvel.PullVelocity = function(Character, direction, pullPower, duration)
    local rootPart = Character.PrimaryPart
    if not rootPart then
        warn("[ServerBvel] No PrimaryPart found for PullVelocity")
        return
    end

    -- Clean up ALL existing BodyMovers and LinearVelocities that might interfere
    for _, child in ipairs(rootPart:GetChildren()) do
        if child:IsA("BodyPosition") or child:IsA("BodyGyro") or child:IsA("BodyVelocity") or child:IsA("LinearVelocity") then
            child:Destroy()
        end
    end

    -- Create attachment
    local attachment = rootPart:FindFirstChild("PullVelocityAttachment")
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "PullVelocityAttachment"
        attachment.Parent = rootPart
    end

    -- Calculate velocity vector (pull towards attacker)
    local velocity = direction * pullPower

    -- Create LinearVelocity
    local lv = Instance.new("LinearVelocity")
    lv.Name = "PullVelocity"
    lv.MaxForce = 200000
    lv.VectorVelocity = velocity
    lv.Attachment0 = attachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = rootPart

    -- Clean up after duration
    task.delay(duration or 0.3, function()
        if lv and lv.Parent then
            lv:Destroy()
        end
    end)
end

-- Light Knockback (mirrors client BaseBvel - small backward push on hit)
ServerBvel.LightKnockback = function(Character, Attacker)
    local rootPart = Character.PrimaryPart
    if not rootPart then
        warn("[ServerBvel] No PrimaryPart found for LightKnockback")
        return
    end

    -- Clean up existing body movers
    for _, child in ipairs(rootPart:GetChildren()) do
        if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") then
            child:Destroy()
        end
    end

    -- Knockback direction: attacker's facing direction (or fall back to target's backward)
    local kbDirection
    local attackerRoot = Attacker and Attacker:FindFirstChild("HumanoidRootPart")
    if attackerRoot then
        local attackerLook = attackerRoot.CFrame.LookVector
        kbDirection = Vector3.new(attackerLook.X, 0, attackerLook.Z).Unit

        -- Rotate target to face the attacker
        local tPos = rootPart.Position
        local aPos = attackerRoot.Position
        rootPart.CFrame = CFrame.new(tPos) * CFrame.lookAt(tPos, Vector3.new(aPos.X, tPos.Y, aPos.Z)).Rotation
    else
        local backwardDirection = -rootPart.CFrame.LookVector
        kbDirection = Vector3.new(backwardDirection.X, 0, backwardDirection.Z).Unit
    end

    local attachment = rootPart:FindFirstChild("LightKBAttachment")
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "LightKBAttachment"
        attachment.Parent = rootPart
    end

    local lv = Instance.new("LinearVelocity")
    lv.Name = "LightKnockbackVelocity"
    lv.MaxForce = 50000
    lv.VectorVelocity = kbDirection * 50
    lv.Attachment0 = attachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = rootPart

    -- Quick tween out (matches client BaseBvel duration of 0.15s)
    local TweenService = game:GetService("TweenService")
    TweenService:Create(lv, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        VectorVelocity = Vector3.new(0, 0, 0)
    }):Play()

    task.delay(0.15, function()
        if lv and lv.Parent then
            lv:Destroy()
        end
    end)
end

-- Full Knockback (mirrors client KnockbackBvel - strong push away from attacker)
ServerBvel.Knockback = function(Character, Attacker)
    local rootPart = Character.PrimaryPart
    if not rootPart then
        warn("[ServerBvel] Missing PrimaryPart for Knockback")
        return
    end

    local attackerRoot = Attacker and Attacker:FindFirstChild("HumanoidRootPart")

    -- Clean up existing body movers
    for _, child in ipairs(rootPart:GetChildren()) do
        if child:IsA("BodyPosition") or child:IsA("BodyGyro") or child:IsA("BodyVelocity") or child:IsA("LinearVelocity") then
            child:Destroy()
        end
    end

    -- Disable AutoRotate during knockback (match player behavior)
    local humanoid = Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.AutoRotate = false
    end

    -- Knockback direction: attacker's facing direction (fallback to target backward)
    local direction
    if attackerRoot then
        local attackerLook = attackerRoot.CFrame.LookVector
        direction = Vector3.new(attackerLook.X, 0, attackerLook.Z).Unit

        -- Rotate target to face the attacker
        local tPos = rootPart.Position
        local aPos = attackerRoot.Position
        rootPart.CFrame = CFrame.new(tPos) * CFrame.lookAt(tPos, Vector3.new(aPos.X, tPos.Y, aPos.Z)).Rotation
    else
        local backDir = -rootPart.CFrame.LookVector
        direction = Vector3.new(backDir.X, 0, backDir.Z).Unit
    end

    local attachment = rootPart:FindFirstChild("KnockbackAttachment")
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "KnockbackAttachment"
        attachment.Parent = rootPart
    end

    local maxPower = 60
    local duration = 1.267 -- Match KnockbackStun animation length
    local rampUpTime = 0.05 -- Quick ramp-up for snappier feel
    local fullSpeedTime = 0.5 -- Hold at max until this point, then decelerate

    -- Reset existing velocity
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero

    local lv = Instance.new("LinearVelocity")
    lv.Name = "KnockbackVelocity"
    lv.MaxForce = 50000
    lv.VectorVelocity = direction * maxPower * 0.5 -- Start with initial burst
    lv.Attachment0 = attachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = rootPart

    -- Two-phase velocity: quick ramp to full speed → cubic ease-out deceleration
    local startTime = os.clock()
    local conn
    conn = game:GetService("RunService").Heartbeat:Connect(function()
        local elapsed = os.clock() - startTime
        if elapsed >= duration then
            conn:Disconnect()
            return
        end

        local currentPower
        if elapsed < rampUpTime then
            -- Phase 1: Quick ramp from 50% to maxPower (linear)
            local t = elapsed / rampUpTime
            currentPower = maxPower * (0.5 + 0.5 * t)
        elseif elapsed < fullSpeedTime then
            currentPower = maxPower
        else
            local slowdownProgress = (elapsed - fullSpeedTime) / (duration - fullSpeedTime)
            local easedProgress = 1 - (1 - slowdownProgress) ^ 3
            currentPower = maxPower * (1 - easedProgress)
        end

        if lv and lv.Parent then
            lv.VectorVelocity = direction * currentPower
        else
            conn:Disconnect()
        end
    end)

    task.delay(duration, function()
        if conn then
            conn:Disconnect()
        end
        if lv and lv.Parent then
            lv:Destroy()
        end
        -- Restore AutoRotate after knockback ends
        if humanoid and humanoid.Parent then
            local StateManager = require(game:GetService("ReplicatedStorage").Modules.ECS.StateManager)
            if not StateManager.StateCount(Character, "Stuns") then
                humanoid.AutoRotate = true
            end
        end
    end)
end

-- Bezier chase velocity (for knockback follow-up - server-side for NPCs)
ServerBvel.BezierChase = function(Character, Target, travelTime)
    local rootPart = Character.PrimaryPart
    local targetRoot = Target and Target:FindFirstChild("HumanoidRootPart")
    if not rootPart or not targetRoot then
        warn("[ServerBvel] Missing parts for BezierChase")
        return
    end

    -- Clean up existing body movers
    for _, child in ipairs(rootPart:GetChildren()) do
        if child:IsA("BodyPosition") or child:IsA("BodyGyro") or child:IsA("BodyVelocity") or child:IsA("LinearVelocity") then
            child:Destroy()
        end
    end

    local attachment = rootPart:FindFirstChild("BezierChaseAttachment")
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "BezierChaseAttachment"
        attachment.Parent = rootPart
    end

    local startPos = rootPart.Position
    local endPos = targetRoot.Position
    local distance = (endPos - startPos).Magnitude
    local midpoint = (startPos + endPos) / 2 + Vector3.new(0, math.clamp(distance * 0.3, 3, 12), 0)

    local lv = Instance.new("LinearVelocity")
    lv.Name = "BezierChaseVelocity"
    lv.MaxForce = math.huge
    lv.Attachment0 = attachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = Vector3.zero
    lv.Parent = rootPart

    local startTime = os.clock()
    local conn
    conn = game:GetService("RunService").Heartbeat:Connect(function()
        local elapsed = os.clock() - startTime
        local tLinear = math.clamp(elapsed / travelTime, 0, 1)

        if tLinear >= 1 then
            conn:Disconnect()
            if lv and lv.Parent then lv:Destroy() end
            return
        end

        -- Ease-out: fast at start, slows down approaching target
        local t = 1 - (1 - tLinear) ^ 2.5

        -- Quadratic bezier derivative: B'(t) = 2(1-t)(P1-P0) + 2t(P2-P1)
        local p0 = startPos
        local p1 = midpoint
        local p2 = targetRoot.Position -- Track target position live

        -- dt/dtLinear for the ease-out curve (chain rule for velocity correction)
        local dtdtLinear = 2.5 * (1 - tLinear) ^ 1.5

        local velocity = 2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)
        velocity = velocity * dtdtLinear / travelTime

        if lv and lv.Parent then
            lv.VectorVelocity = velocity
        else
            conn:Disconnect()
        end
    end)

    task.delay(travelTime, function()
        if conn then conn:Disconnect() end
        if lv and lv.Parent then lv:Destroy() end
    end)
end

-- Aerial Attack launch: smooth forward dive for NPC aerial attacks
ServerBvel.AerialAttackLaunch = function(Character)
    local rootPart = Character.PrimaryPart
    if not rootPart then return end

    local attachment = rootPart:FindFirstChild("AerialAttachment")
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "AerialAttachment"
        attachment.Parent = rootPart
    end

    local forward = rootPart.CFrame.LookVector

    local lv = Instance.new("LinearVelocity")
    lv.Name = "AerialAttackVelocity"
    lv.MaxForce = 50000
    lv.VectorVelocity = forward * 35 + Vector3.new(0, 40, 0)
    lv.Attachment0 = attachment
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = rootPart

    -- Smooth diving arc matching client Bvel
    local startTime = os.clock()
    local duration = 0.45
    local conn
    conn = game:GetService("RunService").Heartbeat:Connect(function()
        local elapsed = os.clock() - startTime
        if elapsed >= duration then
            if conn then conn:Disconnect() end
            if lv and lv.Parent then lv:Destroy() end
            return
        end

        local t = elapsed / duration
        local fwdPower = 40 * (1 - t * t)
        local vertPower = 60 * math.cos(t * math.pi * 1.1) - 22 * t
        lv.VectorVelocity = forward * fwdPower + Vector3.new(0, vertPower, 0)
    end)
end

return ServerBvel

