local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Client = require(script.Parent.Parent)

-- ECS imports for efficient NPC queries
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

local NPCBodyTracking = {}

local DETECTION_RANGE = 15
local UPDATE_INTERVAL = 0.1
local ROTATION_SPEED = 0.25
local BODY_ROTATION_SPEED = 0.08 -- Slower, smoother body rotation
local VERTICAL_RESTRICTION = 0.75
local HORIZONTAL_RESTRICTION = 0.75

local trackedNPCs = {}
local lastUpdateTime = 0
local active = false

-- ⚡ PERFORMANCE OPTIMIZATION: Store connection for cleanup
local updateConnection = nil

-- ⚡ PERFORMANCE: Cache folder references instead of FindFirstChild every frame
local cachedDialogueFolder = nil
local foldersInitialized = false

-- ⚡ PERFORMANCE: Cached ECS query for wanderer NPCs (avoids GetChildren on Live folder)
local wandererQuery = world:query(comps.Character, comps.WandererNPC, comps.NPCIdentity):cached()

local function initFolderCache()
    if foldersInitialized then return end

    local worldFolder = workspace:FindFirstChild("World")
    if worldFolder then
        cachedDialogueFolder = worldFolder:FindFirstChild("Dialogue")
        foldersInitialized = true
    end
end

local function getTrackableNPCs()
    local npcs = {}

    -- Initialize cache if needed
    if not foldersInitialized then
        initFolderCache()
    end

    -- Get dialogue NPCs (using cached folder)
    if cachedDialogueFolder then
        for _, npc in cachedDialogueFolder:GetChildren() do
            if npc:IsA("Model") and npc:FindFirstChild("Humanoid") and npc:FindFirstChild("HumanoidRootPart") then
                table.insert(npcs, npc)
            end
        end
    end

    -- ⚡ PERFORMANCE: Use ECS query for wanderer NPCs instead of GetChildren iteration
    -- This is O(1) archetype lookup vs O(n) folder iteration
    for _, character in wandererQuery do
        if character and character.Parent then
            -- Only track if player is nearby (TrackPlayer attribute set by proximity system)
            local shouldTrack = character:GetAttribute("TrackPlayer")
            if shouldTrack then
                table.insert(npcs, character)
            end
        end
    end

    return npcs
end

local function isPlayerInRange(npcModel)
    if not Client.Character or not Client.Character.PrimaryPart then
        return false
    end

    local npcRoot = npcModel:FindFirstChild("HumanoidRootPart")
    if not npcRoot then
        return false
    end

    local distance = (Client.Character.PrimaryPart.Position - npcRoot.Position).Magnitude
    return distance <= DETECTION_RANGE
end

local function initializeNPC(npcModel)
    if trackedNPCs[npcModel] then
        return
    end

    local head = npcModel:FindFirstChild("Head")
    local neck = head and head:FindFirstChild("Neck")
    local torso = npcModel:FindFirstChild("Torso")

    if not head or not neck or not torso then
        return
    end

    local surfaceGuiPart = torso:FindFirstChild("Part")

    local hrp = npcModel:FindFirstChild("HumanoidRootPart")
    local humanoid = npcModel:FindFirstChild("Humanoid")
    local isWanderer = hrp and (hrp:GetAttribute("IsWandererNPC") or npcModel.Name:lower():find("wanderer"))

    trackedNPCs[npcModel] = {
        head = head,
        neck = neck,
        hrp = hrp,
        humanoid = humanoid,
        surfaceGuiPart = surfaceGuiPart,
        originalNeckC0 = neck.C0,
        originalSurfaceGuiCFrame = surfaceGuiPart and surfaceGuiPart.CFrame or nil,
        currentNeckTween = nil,
        currentSurfaceGuiTween = nil,
        isTracking = false,
        isWanderer = isWanderer,
        targetBodyRotation = nil,
        currentBodyRotation = hrp and hrp.CFrame or nil,
    }
end

local function updateWandererBodyRotation(npcModel, shouldTrack)
    local npcData = trackedNPCs[npcModel]
    if not npcData or not npcData.isWanderer then
        return
    end

    local hrp = npcData.hrp
    local humanoid = npcData.humanoid
    if not hrp or not humanoid then
        return
    end

    -- Don't rotate if NPC is walking/moving
    if humanoid.MoveDirection.Magnitude > 0.1 then
        npcData.currentBodyRotation = hrp.CFrame
        return
    end

    local playerRoot = Client.Character and Client.Character:FindFirstChild("HumanoidRootPart")
    if not playerRoot then
        return
    end

    if shouldTrack then
        -- Calculate target rotation to face player (only Y axis)
        local npcPos = hrp.Position
        local playerPos = playerRoot.Position
        local direction = (playerPos - npcPos) * Vector3.new(1, 0, 1)

        if direction.Magnitude > 0.1 then
            local targetCFrame = CFrame.lookAt(npcPos, npcPos + direction)
            npcData.targetBodyRotation = targetCFrame
        end
    else
        npcData.targetBodyRotation = nil
    end

    -- Smoothly interpolate to target rotation
    if npcData.targetBodyRotation and npcData.currentBodyRotation then
        npcData.currentBodyRotation = npcData.currentBodyRotation:Lerp(
            npcData.targetBodyRotation,
            BODY_ROTATION_SPEED
        )

        -- Apply rotation (preserve Y position)
        local currentPos = hrp.Position
        hrp.CFrame = npcData.currentBodyRotation + Vector3.new(0, currentPos.Y - npcData.currentBodyRotation.Position.Y, 0)
    end
end

local function updateNPCHead(npcModel, shouldTrack)
    local npcData = trackedNPCs[npcModel]
    if not npcData then
        return
    end

    local head = npcData.head
    local neck = npcData.neck
    local surfaceGuiPart = npcData.surfaceGuiPart

    if not head or not neck then
        return
    end

    if shouldTrack then
        if not npcData.isTracking then
            npcData.isTracking = true
        end

        local playerRoot = Client.Character and Client.Character:FindFirstChild("HumanoidRootPart")
        if not playerRoot then
            return
        end

        local npcRoot = npcModel:FindFirstChild("HumanoidRootPart")
        if not npcRoot then
            return
        end

        -- Calculate look direction
        local npcPos = npcRoot.Position
        local playerPos = playerRoot.Position
        local direction = (playerPos - npcPos).Unit

        -- Convert to neck space
        local neckCFrame = neck.Part0.CFrame * npcData.originalNeckC0
        local localDirection = neckCFrame:VectorToObjectSpace(direction)

        -- Calculate angles with restrictions
        local yaw = math.atan2(localDirection.X, localDirection.Z)
        local pitch = math.asin(-localDirection.Y)

        yaw = math.clamp(yaw, -HORIZONTAL_RESTRICTION, HORIZONTAL_RESTRICTION)
        pitch = math.clamp(pitch, -VERTICAL_RESTRICTION, VERTICAL_RESTRICTION)

        -- Apply rotation
        local targetC0 = npcData.originalNeckC0 * CFrame.Angles(pitch, yaw, 0)

        -- Cancel existing tween
        if npcData.currentNeckTween then
            npcData.currentNeckTween:Cancel()
        end

        -- Create smooth tween
        npcData.currentNeckTween = TweenService:Create(
            neck,
            TweenInfo.new(ROTATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {C0 = targetC0}
        )
        npcData.currentNeckTween:Play()

        -- Update SurfaceGui part rotation if it exists
        if surfaceGuiPart and npcData.originalSurfaceGuiCFrame then
            local targetSurfaceGuiCFrame = npcData.originalSurfaceGuiCFrame * CFrame.Angles(pitch, yaw, 0)

            if npcData.currentSurfaceGuiTween then
                npcData.currentSurfaceGuiTween:Cancel()
            end

            npcData.currentSurfaceGuiTween = TweenService:Create(
                surfaceGuiPart,
                TweenInfo.new(ROTATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {CFrame = targetSurfaceGuiCFrame}
            )
            npcData.currentSurfaceGuiTween:Play()
        end
    else
        if npcData.isTracking then
            npcData.isTracking = false

            -- Reset to original position
            if npcData.currentNeckTween then
                npcData.currentNeckTween:Cancel()
            end

            npcData.currentNeckTween = TweenService:Create(
                neck,
                TweenInfo.new(ROTATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {C0 = npcData.originalNeckC0}
            )
            npcData.currentNeckTween:Play()

            -- Reset SurfaceGui part
            if surfaceGuiPart and npcData.originalSurfaceGuiCFrame then
                if npcData.currentSurfaceGuiTween then
                    npcData.currentSurfaceGuiTween:Cancel()
                end

                npcData.currentSurfaceGuiTween = TweenService:Create(
                    surfaceGuiPart,
                    TweenInfo.new(ROTATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {CFrame = npcData.originalSurfaceGuiCFrame}
                )
                npcData.currentSurfaceGuiTween:Play()
            end
        end
    end
end

local function updateBodyTracking()
    if not active then
        return
    end

    local currentTime = os.clock()
    if currentTime - lastUpdateTime < UPDATE_INTERVAL then
        return
    end
    lastUpdateTime = currentTime

    local npcs = getTrackableNPCs()

    for npcModel, _ in pairs(trackedNPCs) do
        if not npcModel.Parent then
            trackedNPCs[npcModel] = nil
        end
    end

    for _, npcModel in npcs do
        initializeNPC(npcModel)

        local inRange = isPlayerInRange(npcModel)

        updateNPCHead(npcModel, inRange)
        updateWandererBodyRotation(npcModel, inRange)
    end
end

-- ⚡ PERFORMANCE OPTIMIZATION: Cleanup function to prevent memory leaks
NPCBodyTracking.Stop = function()
    if not active then
        return
    end

    active = false

    -- Disconnect the RenderStepped connection
    if updateConnection then
        updateConnection:Disconnect()
        updateConnection = nil
    end

    -- Clean up tracked NPCs
    for npcModel, npcData in pairs(trackedNPCs) do
        if npcData.currentNeckTween then
            npcData.currentNeckTween:Cancel()
        end
        if npcData.currentSurfaceGuiTween then
            npcData.currentSurfaceGuiTween:Cancel()
        end
    end
    table.clear(trackedNPCs)

    -- Reset folder cache so it re-initializes on next start
    foldersInitialized = false
    cachedDialogueFolder = nil
end

NPCBodyTracking.Start = function()
    if active then
        return
    end

    active = true

    -- ⚡ Store connection for cleanup
    updateConnection = RunService.RenderStepped:Connect(updateBodyTracking)
end

return NPCBodyTracking