-- NPC Attack System - uses the same combat system as players

-- Main NPC attack function
return function(actor: Actor, mainConfig: table)
    print("=== NPC_ATTACK CALLED ===")

    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        print("npc_attack: No NPC found")
        return false
    end

    local target = mainConfig.getTarget()
    if not target then
        print("npc_attack:", npc.Name, "- No target found")
        return false
    end

    print("npc_attack:", npc.Name, "has target:", target.Name)

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
    local attackCooldown = 1.5 -- Base cooldown in seconds

    -- Reduce cooldown when aggressive for more frequent attacks
    if mainConfig.States and mainConfig.States.AggressiveMode then
        attackCooldown = attackCooldown * 0.6 -- 40% faster attacks when aggressive
        print("NPC", npc.Name, "is aggressive - reduced attack cooldown to", attackCooldown)
    end

    if os.clock() - lastAttack < attackCooldown then
        return false
    end

    print("NPC", npc.Name, "attacking target", target.Name, "at range", math.floor(distance))

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
        warn("Server modules not loaded! Entities:", Server.Modules.Entities, "Combat:", Server.Modules.Combat)
        print("Available Server.Modules:")
        for k, v in pairs(Server.Modules) do
            print("  " .. k .. ":", v)
        end
        return false
    end

    -- Ensure NPC has an entity in the system
    local Entity = Server.Modules.Entities.Get(npc)
    if not Entity then
        print("Warning: NPC", npc.Name, "does not have an entity - creating one")
        -- Try to create entity for NPC
        Server.Modules.Entities.Init(npc)
        Entity = Server.Modules.Entities.Get(npc)
        if not Entity then
            print("Error: Could not create entity for NPC", npc.Name)
            return false
        end
    end

    -- Clear any blocking states that might prevent attacking
    local actions = npc:FindFirstChild("Actions")
    if actions then
        -- Clear any previous attacking states to prevent blocking
        Server.Library.RemoveState(actions, "Attacking")
    end

    -- Use Combat.Light just like players do
    print("NPC", npc.Name, "calling Combat.Light with entity:", Entity and "found" or "not found")
    Server.Modules.Combat.Light(npc)
    print("NPC", npc.Name, "Combat.Light call completed")

    return true
end
