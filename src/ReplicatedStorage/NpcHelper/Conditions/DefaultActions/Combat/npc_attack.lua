-- NPC Attack System - uses the same combat system as players

-- Main NPC attack function
return function(actor: Actor, mainConfig: table)
    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        return false
    end

    local target = mainConfig.getTarget()
    if not target then
        return false
    end

    -- Check if target is still valid and in range
    local targetHumanoid = target:FindFirstChild("Humanoid")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    local npcRoot = npc:FindFirstChild("HumanoidRootPart")

    if not targetHumanoid or not targetRoot or not npcRoot or targetHumanoid.Health <= 0 then
        return false
    end

    local distance = (targetRoot.Position - npcRoot.Position).Magnitude
    local attackRange = 15 -- Base attack range

    if distance > attackRange then
        return false
    end

    -- Check attack cooldown
    local lastAttack = mainConfig.States.LastAttack or 0
    local attackCooldown = 2.0 -- Balanced base cooldown

    -- Reduce cooldown when aggressive for more frequent attacks
    if mainConfig.States and mainConfig.States.AggressiveMode then
        attackCooldown = attackCooldown * 0.75 -- 25% faster attacks when aggressive
    end

    if os.clock() - lastAttack < attackCooldown then
        return false
    end

    -- Update last attack time
    mainConfig.States.LastAttack = os.clock()

    -- Face the target
    local lookDirection = (targetRoot.Position - npcRoot.Position).Unit
    local lookCFrame = CFrame.lookAt(npcRoot.Position, npcRoot.Position + Vector3.new(lookDirection.X, 0, lookDirection.Z))
    npcRoot.CFrame = npcRoot.CFrame:Lerp(lookCFrame, 0.5)

    -- Use the same combat system as players
    local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)

    -- Check if modules are loaded
    if not Server.Modules.Entities or not Server.Modules.Combat then
        return false
    end

    -- Ensure NPC has an entity in the system
    local Entity = Server.Modules.Entities.Get(npc)
    if not Entity then
        -- Try to create entity for NPC
        Server.Modules.Entities.Init(npc)
        Entity = Server.Modules.Entities.Get(npc)
        if not Entity then
            return false
        end
    end

    -- Check if NPC is already in an M1 animation (prevent spam)
    local actions = npc:FindFirstChild("Actions")
    if actions and Server.Library.StateCount(actions) then
        -- NPC is already performing an action, don't spam M1
        return false
    end

    -- Use Combat.Light just like players do
    Server.Modules.Combat.Light(npc)

    return true
end
