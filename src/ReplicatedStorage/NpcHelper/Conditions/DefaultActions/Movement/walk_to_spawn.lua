--!strict
local pathfinding = require(script.Parent.Parent.Combat.Following.follow_enemy.Pathfinding)

local raycastParams: RaycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = {workspace.World.Visuals, workspace.World.Live}
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

return function(actor: Actor, mainConfig: any)
    local npc: Model? = actor:FindFirstChildOfClass("Model")
    if not npc then
        return false
    end

    -- Skip if this is a combat NPC (ECS AI handles movement)
    local ECSBridge = require(game.ReplicatedStorage.NpcHelper.ECSBridge)
    if ECSBridge.isCombatNPC(npc) then
        return false
    end

    local humanoid, humanoidRootPart = npc:FindFirstChild("Humanoid") :: Humanoid, npc:FindFirstChild("HumanoidRootPart") :: BasePart
    if not humanoid or not humanoidRootPart then
        return false
    end

    local spawnPosition: any = mainConfig.Spawning.SpawnedAt;
    local rootPosition: any = humanoidRootPart.Position;
    local distanceToSpawn: number = vector.magnitude(spawnPosition - rootPosition)

    -- If close to spawn, use Humanoid:Move() for smooth animation
    if distanceToSpawn <= 7 then
        local direction = (spawnPosition - rootPosition).Unit

        -- Initialize movement smoothing if not present
        if not mainConfig.Movement then
            mainConfig.Movement = {}
        end
        if not mainConfig.Movement.CurrentDirection then
            mainConfig.Movement.CurrentDirection = Vector3.zero
        end
        if not mainConfig.Movement.SmoothingAlpha then
            mainConfig.Movement.SmoothingAlpha = 0.3
        end

        -- Smooth interpolation for movement direction
        local alpha = mainConfig.Movement.SmoothingAlpha
        local smoothedDirection = mainConfig.Movement.CurrentDirection:Lerp(direction, alpha)
        mainConfig.Movement.CurrentDirection = smoothedDirection

        -- Use Humanoid:Move() to trigger walk animation
        humanoid:Move(smoothedDirection)
        return true
    end

    local lastCheck: number = mainConfig.States.LastWalkToSpawnCheck or 0
    if os.clock() - lastCheck < 0.5 then
        local aiFolder: any = mainConfig.getMimic()
        if aiFolder.PathState.Value == 2 then
            pathfinding(npc, mainConfig, spawnPosition, aiFolder)
        else
            -- Use Humanoid:Move() instead of MoveTo for walk animation
            local direction = (spawnPosition - rootPosition).Unit

            -- Initialize movement smoothing if not present
            if not mainConfig.Movement then
                mainConfig.Movement = {}
            end
            if not mainConfig.Movement.CurrentDirection then
                mainConfig.Movement.CurrentDirection = Vector3.zero
            end
            if not mainConfig.Movement.SmoothingAlpha then
                mainConfig.Movement.SmoothingAlpha = 0.3
            end

            -- Smooth interpolation for movement direction
            local alpha = mainConfig.Movement.SmoothingAlpha
            local smoothedDirection = mainConfig.Movement.CurrentDirection:Lerp(direction, alpha)
            mainConfig.Movement.CurrentDirection = smoothedDirection

            humanoid:Move(smoothedDirection)
        end
        return true
    end

    mainConfig.States.LastWalkToSpawnCheck = os.clock()

    local direction: vector = spawnPosition - rootPosition
    local unitVector: vector = vector.normalize(direction)
    local magnitudeIndex: number = distanceToSpawn + 1

    local pass: number = 1

    local raycastResults: RaycastResult = workspace:Raycast(rootPosition, unitVector * magnitudeIndex, raycastParams)
    if raycastResults and raycastResults.Position then
        local difference: number = vector.magnitude(raycastResults.Position - (rootPosition + (unitVector * magnitudeIndex)))
        if difference > 5 then
            pass = 2
        end
    end

    local aiFolder: any = mainConfig.getMimic()

    if humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.FloorMaterial ~= nil and pass ~= aiFolder.PathState.Value then
        aiFolder.StateId.Value = math.random(1, 9999)
        aiFolder.PathState.Value = pass;
    end

    if aiFolder.PathState.Value == 2 then
        pathfinding(npc, mainConfig, spawnPosition, aiFolder)
    else
        -- Use Humanoid:Move() instead of MoveTo for walk animation
        local direction = (spawnPosition - rootPosition).Unit

        -- Initialize movement smoothing if not present
        if not mainConfig.Movement then
            mainConfig.Movement = {}
        end
        if not mainConfig.Movement.CurrentDirection then
            mainConfig.Movement.CurrentDirection = Vector3.zero
        end
        if not mainConfig.Movement.SmoothingAlpha then
            mainConfig.Movement.SmoothingAlpha = 0.3
        end

        -- Smooth interpolation for movement direction
        local alpha = mainConfig.Movement.SmoothingAlpha
        local smoothedDirection = mainConfig.Movement.CurrentDirection:Lerp(direction, alpha)
        mainConfig.Movement.CurrentDirection = smoothedDirection

        humanoid:Move(smoothedDirection)
    end

    return true
end