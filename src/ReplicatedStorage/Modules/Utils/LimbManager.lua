--[[
    LimbManager Module

    Handles limb loss and restoration mechanics:
    - Severing limbs from characters
    - Restoring limbs via healing
    - Calculating junction chances
    - Debuff values for missing limbs
]]

local LimbManager = {}

-- Limb to Motor6D joint mapping (R6 character)
LimbManager.LimbJoints = {
    LeftArm = "Left Shoulder",
    RightArm = "Right Shoulder",
    LeftLeg = "Left Hip",
    RightLeg = "Right Hip",
}

-- Limb to Part name mapping
LimbManager.LimbParts = {
    LeftArm = "Left Arm",
    RightArm = "Right Arm",
    LeftLeg = "Left Leg",
    RightLeg = "Right Leg",
}

-- Debuff values for missing limbs
LimbManager.Debuffs = {
    arm = {
        damageMultiplier = 0.75,      -- 25% less damage per missing arm
        attackSpeedMultiplier = 0.85, -- 15% slower attacks per missing arm
    },
    leg = {
        walkSpeedMultiplier = 0.7,    -- 30% slower per missing leg
    },
    bleeding = {
        damagePerSecond = 1.5,        -- HP drain per missing limb per second
        tickRate = 1,                 -- How often bleeding ticks (seconds)
    },
}

-- Junction chance calculation
-- Base chance increases when victim is low HP
function LimbManager.calculateJunctionChance(baseChance: number, victimHealthPercent: number): number
    -- Below 30% HP: up to 3x chance
    -- Below 50% HP: up to 2x chance
    local multiplier = 1
    if victimHealthPercent <= 0.3 then
        multiplier = 3
    elseif victimHealthPercent <= 0.5 then
        multiplier = 2
    end
    return math.min(baseChance * multiplier, 0.5) -- Cap at 50%
end

-- Sever a limb from character (server-side)
function LimbManager.SeverLimb(character: Model, limbName: string): boolean
    local torso = character:FindFirstChild("Torso")
    local limb = character:FindFirstChild(LimbManager.LimbParts[limbName])
    if not torso or not limb then return false end

    local jointName = LimbManager.LimbJoints[limbName]
    local joint = torso:FindFirstChild(jointName)
    if not joint then return false end

    -- Store original joint data for restoration
    local C0Pos = joint.C0.Position
    local C0X, C0Y, C0Z = joint.C0:ToEulerAnglesXYZ()
    local C1Pos = joint.C1.Position
    local C1X, C1Y, C1Z = joint.C1:ToEulerAnglesXYZ()

    character:SetAttribute("Severed_" .. limbName .. "_C0Pos", C0Pos)
    character:SetAttribute("Severed_" .. limbName .. "_C0Rot", Vector3.new(C0X, C0Y, C0Z))
    character:SetAttribute("Severed_" .. limbName .. "_C1Pos", C1Pos)
    character:SetAttribute("Severed_" .. limbName .. "_C1Rot", Vector3.new(C1X, C1Y, C1Z))
    character:SetAttribute("Severed_" .. limbName, true)

    -- Disconnect the joint by removing Part0
    joint.Part0 = nil

    -- Hide the limb (make it invisible and non-collidable)
    limb.Transparency = 1
    limb.CanCollide = false
    limb.CanQuery = false
    limb.CanTouch = false

    return true
end

-- Restore a limb (via healing)
function LimbManager.RestoreLimb(character: Model, limbName: string): boolean
    local torso = character:FindFirstChild("Torso")
    local limbPartName = LimbManager.LimbParts[limbName]
    local limb = character:FindFirstChild(limbPartName)

    -- If limb was destroyed, we need to recreate it
    if not limb then
        -- Clone from a template or recreate the limb
        -- For now, we'll create a basic part
        limb = Instance.new("Part")
        limb.Name = limbPartName
        limb.Size = Vector3.new(1, 2, 1)
        limb.BrickColor = torso.BrickColor
        limb.Material = torso.Material
        limb.Parent = character
    end

    if not torso then return false end

    local jointName = LimbManager.LimbJoints[limbName]
    local joint = torso:FindFirstChild(jointName)

    -- If joint was destroyed, recreate it
    if not joint then
        joint = Instance.new("Motor6D")
        joint.Name = jointName
        joint.Parent = torso
    end

    -- Restore joint data if stored
    local C0Pos = character:GetAttribute("Severed_" .. limbName .. "_C0Pos")
    local C0Rot = character:GetAttribute("Severed_" .. limbName .. "_C0Rot")
    local C1Pos = character:GetAttribute("Severed_" .. limbName .. "_C1Pos")
    local C1Rot = character:GetAttribute("Severed_" .. limbName .. "_C1Rot")

    if C0Pos and C0Rot and C1Pos and C1Rot then
        joint.C0 = CFrame.new(C0Pos) * CFrame.Angles(C0Rot.X, C0Rot.Y, C0Rot.Z)
        joint.C1 = CFrame.new(C1Pos) * CFrame.Angles(C1Rot.X, C1Rot.Y, C1Rot.Z)
    else
        -- Default joint positions based on limb type
        if limbName == "LeftArm" then
            joint.C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0)
            joint.C1 = CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0)
        elseif limbName == "RightArm" then
            joint.C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0)
            joint.C1 = CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0)
        elseif limbName == "LeftLeg" then
            joint.C0 = CFrame.new(-1, -1, 0) * CFrame.Angles(0, -math.pi / 2, 0)
            joint.C1 = CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -math.pi / 2, 0)
        elseif limbName == "RightLeg" then
            joint.C0 = CFrame.new(1, -1, 0) * CFrame.Angles(0, math.pi / 2, 0)
            joint.C1 = CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.pi / 2, 0)
        end
    end

    -- Reconnect the joint
    joint.Part0 = torso
    joint.Part1 = limb

    -- Restore limb visibility and physics
    limb.Transparency = 0
    limb.Anchored = false
    limb.CanCollide = false
    limb.CanQuery = true
    limb.CanTouch = true

    -- Clear stored data
    character:SetAttribute("Severed_" .. limbName .. "_C0Pos", nil)
    character:SetAttribute("Severed_" .. limbName .. "_C0Rot", nil)
    character:SetAttribute("Severed_" .. limbName .. "_C1Pos", nil)
    character:SetAttribute("Severed_" .. limbName .. "_C1Rot", nil)
    character:SetAttribute("Severed_" .. limbName, nil)

    return true
end

-- Get random limb based on Junction target
function LimbManager.GetRandomLimb(junctionTarget: string, limbState: table): string?
    -- Direct targeting
    if junctionTarget == "LeftArm" and limbState.leftArm then return "LeftArm" end
    if junctionTarget == "RightArm" and limbState.rightArm then return "RightArm" end
    if junctionTarget == "LeftLeg" and limbState.leftLeg then return "LeftLeg" end
    if junctionTarget == "RightLeg" and limbState.rightLeg then return "RightLeg" end

    -- Random arm targeting
    if junctionTarget == "RandomArm" then
        local available = {}
        if limbState.leftArm then table.insert(available, "LeftArm") end
        if limbState.rightArm then table.insert(available, "RightArm") end
        if #available > 0 then return available[math.random(#available)] end
    end

    -- Random leg targeting
    if junctionTarget == "RandomLeg" then
        local available = {}
        if limbState.leftLeg then table.insert(available, "LeftLeg") end
        if limbState.rightLeg then table.insert(available, "RightLeg") end
        if #available > 0 then return available[math.random(#available)] end
    end

    -- Random any limb targeting
    if junctionTarget == "Random" then
        local available = {}
        if limbState.leftArm then table.insert(available, "LeftArm") end
        if limbState.rightArm then table.insert(available, "RightArm") end
        if limbState.leftLeg then table.insert(available, "LeftLeg") end
        if limbState.rightLeg then table.insert(available, "RightLeg") end
        if #available > 0 then return available[math.random(#available)] end
    end

    return nil -- No valid limb to sever
end

-- Check if character has any missing limbs
function LimbManager.HasMissingLimbs(limbState: table): boolean
    return not limbState.leftArm or not limbState.rightArm or not limbState.leftLeg or not limbState.rightLeg
end

-- Count missing limbs
function LimbManager.CountMissingLimbs(limbState: table): (number, number)
    local missingArms = 0
    local missingLegs = 0

    if not limbState.leftArm then missingArms = missingArms + 1 end
    if not limbState.rightArm then missingArms = missingArms + 1 end
    if not limbState.leftLeg then missingLegs = missingLegs + 1 end
    if not limbState.rightLeg then missingLegs = missingLegs + 1 end

    return missingArms, missingLegs
end

-- Get default limb state (all limbs attached)
function LimbManager.GetDefaultLimbState(): table
    return {
        leftArm = true,
        rightArm = true,
        leftLeg = true,
        rightLeg = true,
        bleedingStacks = 0,
    }
end

-- Check if a specific limb is attached
function LimbManager.IsLimbAttached(limbState: table, limbName: string): boolean
    if limbName == "LeftArm" then return limbState.leftArm end
    if limbName == "RightArm" then return limbState.rightArm end
    if limbName == "LeftLeg" then return limbState.leftLeg end
    if limbName == "RightLeg" then return limbState.rightLeg end
    return false
end

return LimbManager
