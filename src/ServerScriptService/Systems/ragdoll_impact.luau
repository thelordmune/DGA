-- ragdoll_impact.luau
-- ECS System that monitors ragdolled entities and creates crater effects when they hit the ground

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local BridgeNet2 = require(ReplicatedStorage.Modules.Shared.BridgeNet2)
local Visuals = require(ReplicatedStorage.Modules.Visuals)

-- Configuration
local MIN_IMPACT_VELOCITY = 10 -- Minimum velocity to create crater (studs/second)
local IMPACT_COOLDOWN = .3 -- Seconds between impacts
local RAYCAST_DISTANCE = 10 -- How far to raycast down for ground detection
local FALLING_THRESHOLD = -10 -- Y velocity threshold to consider "falling"
local GROUND_PROXIMITY_THRESHOLD = 5 -- Distance from ground to trigger impact (studs)
local DASH_EFFECT_VELOCITY = 5 -- Minimum velocity to show dash effect (studs/second)

-- Raycast parameters for ground detection
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = {workspace.World.Live, workspace.World.Visuals}



print("[RagdollImpact] ✅ Server system loaded - will replicate effects to clients")

-- Helper function to send impact event to all clients
local function createImpact(characterName, impactPosition, impactVelocity)
    -- Check minimum velocity
    local velocityMagnitude = math.abs(impactVelocity.Y)
    if velocityMagnitude < MIN_IMPACT_VELOCITY then
        print(`[RagdollImpact] ⚠️ Impact velocity too low: {velocityMagnitude} < {MIN_IMPACT_VELOCITY}`)
        return
    end

    print(`[RagdollImpact] 🎯 Sending impact event for {characterName} at {impactPosition} with velocity {velocityMagnitude} studs/s`)

    -- Raycast down to find the ground with extended range
    local rayOrigin = impactPosition + Vector3.new(0, 10, 0) -- Start higher
    local rayDirection = Vector3.new(0, -15, 0) -- Cast further down
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

    if not raycastResult then
        warn(`[RagdollImpact] ❌ No ground found below {impactPosition}`)
        return
    end

    print(`[RagdollImpact] ✅ Ground found: {raycastResult.Instance:GetFullName()} at {raycastResult.Position}`)

    -- Send impact event to all clients for smooth replication
    -- Use BridgeNet2.AllPlayers() to send to all connected players
    Bridges.ECSClient:Fire(BridgeNet2.AllPlayers(), {
        Module = "RagdollImpact",
        Action = "CreateImpact",
        Position = raycastResult.Position,
        Velocity = impactVelocity,
        CharacterName = characterName
    })

    print(`[RagdollImpact] 📡 Impact event sent to all clients`)
end

local debugPrinted = false
local lastDebugTime = 0
local DEBUG_INTERVAL = 5 -- Print debug info every 5 seconds

return {
    run = function(world, _dt)
        -- Print debug message once
        if not debugPrinted then
            print("[RagdollImpact] ✅ System is running on server - replicating to clients")
            debugPrinted = true
        end

        -- Periodic debug info
        local currentTime = os.clock()
        if currentTime - lastDebugTime >= DEBUG_INTERVAL then
            lastDebugTime = currentTime
            local entityCount = 0
            for _ in world:query(comps.Character) do
                entityCount = entityCount + 1
            end
            print(`[RagdollImpact] 📊 Monitoring {entityCount} entities with Character component`)
        end

        -- Query all entities with Character component
        for entity in world:query(comps.Character) do
            -- Get character model
            local character = world:get(entity, comps.Character)
            if not character or not character.Parent then
                continue
            end

            -- Check if character is ragdolled by looking for Ragdoll BoolValue or Knocked attribute
            local isRagdolled = false
            local ragdollReason = ""

            -- Check for Ragdoll BoolValue (created by Ragdoller:Enable)
            if character:FindFirstChild("Ragdoll") then
                isRagdolled = true
                ragdollReason = "Ragdoll BoolValue"
            end

            -- Check for Knocked attribute
            if character:GetAttribute("Knocked") and character:GetAttribute("Knocked") > 0 then
                isRagdolled = true
                ragdollReason = ragdollReason ~= "" and ragdollReason .. " + Knocked" or "Knocked"
            end

            -- Check for Unconscious attribute
            if character:GetAttribute("Unconscious") and character:GetAttribute("Unconscious") > 0 then
                isRagdolled = true
                ragdollReason = ragdollReason ~= "" and ragdollReason .. " + Unconscious" or "Unconscious"
            end

            -- Skip if not ragdolled
            if not isRagdolled then
                -- Clear impact tracking if exists
                if world:has(entity, comps.RagdollImpact) then
                    print(`[RagdollImpact] 🔄 {character.Name} is no longer ragdolled, clearing tracking`)
                    world:remove(entity, comps.RagdollImpact)
                end
                continue
            end
            
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if not rootPart then
                continue
            end
            
            -- Get or create impact tracking component
            local impactData = world:get(entity, comps.RagdollImpact)
            if not impactData then
                impactData = {
                    lastImpactTime = 0,
                    wasInAir = false,
                    lastVelocity = Vector3.zero,
                }
                world:set(entity, comps.RagdollImpact, impactData)
                print(`[RagdollImpact] 🎯 Started tracking ragdolled entity: {character.Name} (Reason: {ragdollReason})`)
            end
            
            -- Get current velocity
            local currentVelocity = rootPart.AssemblyLinearVelocity
            local velocityMagnitude = currentVelocity.Magnitude

            -- Handle dash effect for high-velocity ragdolls
            if velocityMagnitude >= DASH_EFFECT_VELOCITY then
                if not impactData.hasDashEffect then
                    -- Enable dash effect
                    print(`[RagdollImpact] ✨ Enabling dash effect for {character.Name} (velocity: {math.floor(velocityMagnitude)} studs/s)`)
                    Visuals.Ranged(rootPart.Position, 300, {
                        Module = "Base",
                        Function = "DashFX",
                        Arguments = { character, "Forward" }
                    })
                    impactData.hasDashEffect = true
                    world:set(entity, comps.RagdollImpact, impactData)
                end
            else
                if impactData.hasDashEffect then
                    -- Disable dash effect
                    print(`[RagdollImpact] 🔚 Disabling dash effect for {character.Name}`)
                    Visuals.Ranged(rootPart.Position, 300, {
                        Module = "Base",
                        Function = "EndDashFX",
                        Arguments = { character }
                    })
                    impactData.hasDashEffect = false
                    world:set(entity, comps.RagdollImpact, impactData)
                end
            end

            -- Check if character is falling (negative Y velocity)
            local isFalling = currentVelocity.Y < FALLING_THRESHOLD

            if isFalling then
                -- Character is falling
                if not impactData.wasInAir then
                    print(`[RagdollImpact] 🪂 {character.Name} is falling (velocity: {math.floor(currentVelocity.Y)})`)
                end
                impactData.wasInAir = true
                impactData.lastVelocity = currentVelocity

                -- Check proximity to ground while falling (early impact detection)
                local rayOrigin = rootPart.Position + Vector3.new(0, 2, 0)
                local rayDirection = Vector3.new(0, -10, 0)
                local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

                if raycastResult then
                    local distanceToGround = (raycastResult.Position - rootPart.Position).Magnitude

                    -- Trigger impact when close to ground (early detection for better timing)
                    if distanceToGround <= GROUND_PROXIMITY_THRESHOLD then
                        local impactTime = os.clock()

                        -- Check cooldown
                        if impactTime - impactData.lastImpactTime >= IMPACT_COOLDOWN then
                            -- Character is about to hit the ground!
                            print(`[RagdollImpact] 💥 {character.Name} hitting ground! Velocity: {math.floor(math.abs(currentVelocity.Y))} studs/s, Distance: {math.floor(distanceToGround)} studs`)
                            print(`[RagdollImpact] 📍 Ground: {raycastResult.Instance:GetFullName()}`)

                            -- Send impact event to clients immediately
                            createImpact(character.Name, rootPart.Position, currentVelocity)

                            -- Update impact time
                            impactData.lastImpactTime = impactTime
                        end
                    end
                end

                world:set(entity, comps.RagdollImpact, impactData)
            else
                -- Not falling anymore - reset state
                if impactData.wasInAir then
                    impactData.wasInAir = false
                    world:set(entity, comps.RagdollImpact, impactData)
                end
            end
        end
    end,
    
    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true -- Run on server to access NPC entities
    }
}

