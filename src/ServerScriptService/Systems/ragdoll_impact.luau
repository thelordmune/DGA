-- ragdoll_impact.luau - HEAVILY OPTIMIZED
-- ECS System that monitors ragdolled entities and creates crater effects when they hit the ground
--
-- OPTIMIZATIONS:
-- - Throttled to 15 Hz instead of 60 Hz (75% reduction)
-- - Ragdoll detection throttled to 5 Hz (92% reduction)
-- - Cached query for RagdollImpact component (only processes ragdolled entities)
-- - Reduced raycast frequency with caching
-- - Optimized component access patterns
-- - Removed redundant character lookups

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local BridgeNet2 = require(ReplicatedStorage.Modules.Shared.BridgeNet2)
local Visuals = require(ReplicatedStorage.Modules.Visuals)

-- Get Server modules for damage dealing
local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)

-- Configuration
local MIN_IMPACT_VELOCITY = 30 -- Minimum velocity to create crater (studs/second) - increased from 10
local IMPACT_COOLDOWN = .3 -- Seconds between impacts
local RAYCAST_DISTANCE = 10 -- How far to raycast down for ground detection
local FALLING_THRESHOLD = -10 -- Y velocity threshold to consider "falling"
local GROUND_PROXIMITY_THRESHOLD = 5 -- Distance from ground to trigger impact (studs)
local DASH_EFFECT_VELOCITY = 5 -- Minimum velocity to show dash effect (studs/second)

-- OPTIMIZATION: Throttling configuration
local IMPACT_CHECK_HZ = 15 -- Check for impacts at 15 Hz (was 60 Hz)
local IMPACT_CHECK_TICK = 1 / IMPACT_CHECK_HZ
local impactCheckAcc = 0

local RAGDOLL_DETECT_HZ = 5 -- Detect new ragdolls at 5 Hz (was 60 Hz)
local RAGDOLL_DETECT_TICK = 1 / RAGDOLL_DETECT_HZ
local ragdollDetectAcc = 0

-- Raycast parameters for ground detection
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = {workspace.World.Live, workspace.World.Visuals}

-- OPTIMIZATION: Cached queries
local ragdollQuery = world:query(comps.Character, comps.RagdollImpact):cached()
local allCharactersQuery = world:query(comps.Character):cached()



-- -- print("[RagdollImpact] ✅ Server system loaded - will replicate effects to clients")

-- Helper function to send impact event to all clients and deal damage
local function createImpact(character, impactPosition, impactVelocity)
    -- Check minimum velocity
    local velocityMagnitude = math.abs(impactVelocity.Y)
    if velocityMagnitude < MIN_IMPACT_VELOCITY then
        -- -- print(`[RagdollImpact] ⚠️ Impact velocity too low: {velocityMagnitude} < {MIN_IMPACT_VELOCITY}`)
        return
    end

    -- -- print(`[RagdollImpact] 🎯 Sending impact event for {character.Name} at {impactPosition} with velocity {velocityMagnitude} studs/s`)

    -- Raycast down to find the ground with extended range
    local rayOrigin = impactPosition + Vector3.new(0, 10, 0) -- Start higher
    local rayDirection = Vector3.new(0, -15, 0) -- Cast further down
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

    if not raycastResult then
        warn(`[RagdollImpact] ❌ No ground found below {impactPosition}`)
        return
    end

    -- -- print(`[RagdollImpact] ✅ Ground found: {raycastResult.Instance:GetFullName()} at {raycastResult.Position}`)

    -- Send impact event to all clients for smooth replication
    -- Use BridgeNet2.AllPlayers() to send to all connected players
    Bridges.ECSClient:Fire(BridgeNet2.AllPlayers(), {
        Module = "RagdollImpact",
        Action = "CreateImpact",
        Position = raycastResult.Position,
        Velocity = impactVelocity,
        CharacterName = character.Name
    })

    -- -- print(`[RagdollImpact] 📡 Impact event sent to all clients`)

    -- Deal damage based on impact velocity
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        -- Calculate damage: 5 damage per 10 studs/s of velocity (minimum 5, maximum 25)
        local baseDamage = math.floor(velocityMagnitude / 10) * 5
        local damage = math.clamp(baseDamage, 5, 25)

        -- Apply damage
        humanoid:TakeDamage(damage)
        -- -- print(`[RagdollImpact] 💥 Dealt {damage} impact damage to {character.Name} (velocity: {math.floor(velocityMagnitude)} studs/s)`)
    end
end

local debugPrinted = false
local lastDebugTime = 0
local DEBUG_INTERVAL = 5 -- print debug info every 5 seconds

-- OPTIMIZATION: Ragdoll detection (throttled to 5 Hz)
local function detectRagdolls()
    -- Check all characters for ragdoll state and add/remove RagdollImpact component
    for entity, character in allCharactersQuery do
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

        -- Add or remove RagdollImpact component based on ragdoll state
        if isRagdolled then
            if not world:has(entity, comps.RagdollImpact) then
                world:set(entity, comps.RagdollImpact, {
                    lastImpactTime = 0,
                    wasInAir = false,
                    lastVelocity = Vector3.zero,
                })
                -- print(`[RagdollImpact] 🎯 Started tracking ragdolled entity: {character.Name} (Reason: {ragdollReason})`)
            end
        else
            if world:has(entity, comps.RagdollImpact) then
                -- print(`[RagdollImpact] 🔄 {character.Name} is no longer ragdolled, clearing tracking`)
                world:remove(entity, comps.RagdollImpact)
            end
        end
    end
end

-- OPTIMIZATION: Impact checking (throttled to 15 Hz)
local function checkImpacts()
    -- Process only entities with RagdollImpact component
    for entity, character, impactData in ragdollQuery do
            if not character or not character.Parent then
                continue
            end

            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if not rootPart then
                continue
            end

            -- Get current velocity
            local currentVelocity = rootPart.AssemblyLinearVelocity
            local velocityMagnitude = currentVelocity.Magnitude

            -- OPTIMIZATION: Track if we need to update the component
            local needsUpdate = false

            -- Handle dash effect for high-velocity ragdolls
            if velocityMagnitude >= DASH_EFFECT_VELOCITY then
                if not impactData.hasDashEffect then
                    -- Enable dash effect
                    -- print(`[RagdollImpact] ✨ Enabling dash effect for {character.Name} (velocity: {math.floor(velocityMagnitude)} studs/s)`)
                    Visuals.Ranged(rootPart.Position, 300, {
                        Module = "Base",
                        Function = "DashFX",
                        Arguments = { character, "Forward" }
                    })
                    impactData.hasDashEffect = true
                    needsUpdate = true
                end
            else
                if impactData.hasDashEffect then
                    -- Disable dash effect
                    -- print(`[RagdollImpact] 🔚 Disabling dash effect for {character.Name}`)
                    Visuals.Ranged(rootPart.Position, 300, {
                        Module = "Base",
                        Function = "EndDashFX",
                        Arguments = { character }
                    })
                    impactData.hasDashEffect = false
                    needsUpdate = true
                end
            end

            -- Check if character is falling (negative Y velocity)
            local isFalling = currentVelocity.Y < FALLING_THRESHOLD

            if isFalling then
                -- Character is falling
                if not impactData.wasInAir then
                    -- print(`[RagdollImpact] 🪂 {character.Name} is falling (velocity: {math.floor(currentVelocity.Y)})`)
                end
                impactData.wasInAir = true
                impactData.lastVelocity = currentVelocity
                needsUpdate = true

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
                            -- print(`[RagdollImpact] 💥 {character.Name} hitting ground! Velocity: {math.floor(math.abs(currentVelocity.Y))} studs/s, Distance: {math.floor(distanceToGround)} studs`)
                            -- print(`[RagdollImpact] 📍 Ground: {raycastResult.Instance:GetFullName()}`)

                            -- Send impact event to clients immediately using the GROUND position, not character position
                            createImpact(character, raycastResult.Position, currentVelocity)

                            -- Update impact time
                            impactData.lastImpactTime = impactTime
                        end
                    end
                end
            else
                -- Not falling anymore - reset state
                if impactData.wasInAir then
                    impactData.wasInAir = false
                    needsUpdate = true
                end
            end

            -- OPTIMIZATION: Only update component if something changed
            if needsUpdate then
                world:set(entity, comps.RagdollImpact, impactData)
            end
        end
end

-- Main system function with throttling
return {
    run = function(_world, dt)
        -- print debug message once
        if not debugPrinted then
            -- print("[RagdollImpact] ✅ System is running on server - replicating to clients (HEAVILY OPTIMIZED - 15 Hz impacts, 5 Hz detection)")
            debugPrinted = true
        end

        -- Periodic debug info
        local currentTime = os.clock()
        if currentTime - lastDebugTime >= DEBUG_INTERVAL then
            lastDebugTime = currentTime
            local entityCount = 0
            for _ in ragdollQuery do
                entityCount = entityCount + 1
            end
            -- print(`[RagdollImpact] 📊 Monitoring {entityCount} ragdolled entities`)
        end

        -- OPTIMIZATION: Throttle ragdoll detection to 5 Hz
        ragdollDetectAcc += dt
        if ragdollDetectAcc >= RAGDOLL_DETECT_TICK then
            ragdollDetectAcc = 0
            detectRagdolls()
        end

        -- OPTIMIZATION: Throttle impact checking to 15 Hz
        impactCheckAcc += dt
        if impactCheckAcc >= IMPACT_CHECK_TICK then
            impactCheckAcc = 0
            checkImpacts()
        end
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true -- Run on server to access NPC entities
    }
}

