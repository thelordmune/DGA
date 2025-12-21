return function(actor: Actor, mainConfig: table)
    local npc = mainConfig.getNpc()
    if not npc then return false end

    -- Skip if this is a combat NPC (ECS AI handles movement)
    local ECSBridge = require(game.ReplicatedStorage.NpcHelper.ECSBridge)
    if ECSBridge.isCombatNPC(npc) then
        return false
    end

    -- Skip if this is a wanderer NPC (ECS AI handles movement)
    if ECSBridge.isWandererNPC(npc) then
        return false
    end

    local root = npc:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    -- Get spawn position
    local spawnPosition = mainConfig.Spawning.SpawnedAt
    if not spawnPosition then return false end

    -- Check if NPC is far from spawn
    local currentPosition = root.Position
    local distanceFromSpawn = (currentPosition - spawnPosition).Magnitude

    -- If too far from spawn, move back
    local humanoid = npc:FindFirstChild("Humanoid")
    if humanoid then
        if distanceFromSpawn > 10 then
            local direction = (spawnPosition - currentPosition).Unit
            humanoid:Move(direction)
        else
            -- Stop movement when at spawn
            humanoid:Move(Vector3.new(0, 0, 0))
        end
    end
    
    -- Simple idle animation/behavior
    -- local humanoid = npc:FindFirstChild("Humanoid")
    -- if humanoid and humanoid.MoveDirection.Magnitude < 0.1 then
    --     -- NPC is standing still, add subtle idle movement
    --     local time = tick()
    --     local sway = math.sin(time * 0.5) * 0.5
    --     root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(sway), 0)
    -- end
    
    return true
end