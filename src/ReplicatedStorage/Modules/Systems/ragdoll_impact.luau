-- ragdoll_impact.luau
-- ECS System that monitors ragdolled entities and creates crater effects when they hit the ground

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

-- Configuration
local MIN_IMPACT_VELOCITY = 40 -- Minimum velocity to create crater (studs/second)
local IMPACT_COOLDOWN = 2 -- Seconds between impacts
local RAYCAST_DISTANCE = 10 -- How far to raycast down for ground detection
local FALLING_THRESHOLD = -10 -- Y velocity threshold to consider "falling"

-- Raycast parameters for ground detection
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = {workspace.World.Live, workspace.World.Visuals, workspace.Interactables}

-- Get RockMod (only on client)
local RockMod = nil
local isClient = Players.LocalPlayer ~= nil

if isClient then
    local success, result = pcall(function()
        return require(script.Parent.Parent.Utils.RockMod)
    end)
    if success then
        RockMod = result
        print("[RagdollImpact] ✅ RockMod loaded successfully")
    else
        warn("[RagdollImpact] ❌ Failed to load RockMod:", result)
    end
else
    print("[RagdollImpact] Running on server - RockMod not loaded")
end

-- Helper function to create crater impact effect
local function createImpact(character, impactPosition, impactVelocity)
    if not RockMod then
        return
    end
    
    -- Check minimum velocity
    if math.abs(impactVelocity.Y) < MIN_IMPACT_VELOCITY then
        return
    end
    
    print(`[RagdollImpact] Creating impact effect at {impactPosition} with velocity {impactVelocity.Y}`)
    
    -- Raycast down to find the ground
    local rayOrigin = impactPosition + Vector3.new(0, 2, 0)
    local rayDirection = Vector3.new(0, -RAYCAST_DISTANCE, 0)
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if not raycastResult then
        return
    end
    
    -- Calculate crater size based on impact velocity
    local velocityMagnitude = math.abs(impactVelocity.Y)
    local sizeMultiplier = math.clamp(velocityMagnitude / 100, 0.2, 0.5) -- Scale between 0.2 and 0.5
    local debrisCount = math.clamp(math.floor(velocityMagnitude / 10), 5, 15) -- More debris for harder impacts
    
    -- Create crater effect
    RockMod.New("Crater", CFrame.new(raycastResult.Position.X, raycastResult.Position.Y, raycastResult.Position.Z), {
        Distance = { 5.5, 15 },
        SizeMultiplier = sizeMultiplier,
        PartCount = 12,
        Layers = { 3, 3 },
        ExitIterationDelay = { 0.5, 1 },
    })
    :Debris("Normal", {
        Size = { 0.75, 2.5 },
        UpForce = { 0.55, 0.95 },
        RotationalForce = {15, 35},
        Spread = { 8, 8 },
        PartCount = debrisCount,
        Radius = 8,
        LifeTime = 5,
        LifeCycle = {
            Entrance = {
                Type = "SizeUp",
                Speed = 0.25,
                Division = 3,
                EasingStyle = Enum.EasingStyle.Quad,
                EasingDirection = Enum.EasingDirection.Out,
            },
            Exit = {
                Type = "SizeDown",
                Speed = 0.3,
                Division = 2,
                EasingStyle = Enum.EasingStyle.Sine,
                EasingDirection = Enum.EasingDirection.In,
            },
        },
    })
end

local debugPrinted = false
local lastDebugTime = 0
local DEBUG_INTERVAL = 5 -- Print debug info every 5 seconds

return {
    run = function(world, _dt)
        -- Only run on client
        if not RockMod then
            return
        end

        -- Print debug message once
        if not debugPrinted then
            print("[RagdollImpact] ✅ System is running on client")
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
            
            -- Check if character is falling (negative Y velocity)
            local isFalling = currentVelocity.Y < FALLING_THRESHOLD
            
            if isFalling then
                -- Character is falling
                if not impactData.wasInAir then
                    print(`[RagdollImpact] 🪂 {character.Name} is falling (velocity: {math.floor(currentVelocity.Y)})`)
                end
                impactData.wasInAir = true
                impactData.lastVelocity = currentVelocity
                world:set(entity, comps.RagdollImpact, impactData)
            elseif impactData.wasInAir then
                -- Character was falling and now stopped - check if they hit the ground
                local impactTime = os.clock()

                -- Check cooldown
                if impactTime - impactData.lastImpactTime >= IMPACT_COOLDOWN then
                    -- Raycast down to check for ground
                    local rayOrigin = rootPart.Position
                    local rayDirection = Vector3.new(0, -5, 0)
                    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

                    if raycastResult then
                        -- Character hit the ground!
                        print(`[RagdollImpact] 💥 {character.Name} hit the ground! Velocity: {math.floor(math.abs(impactData.lastVelocity.Y))} studs/s`)
                        createImpact(character, rootPart.Position, impactData.lastVelocity)

                        -- Update impact time
                        impactData.lastImpactTime = impactTime
                        impactData.wasInAir = false
                        world:set(entity, comps.RagdollImpact, impactData)
                    else
                        print(`[RagdollImpact] ⚠️ {character.Name} stopped falling but no ground detected`)
                        impactData.wasInAir = false
                        world:set(entity, comps.RagdollImpact, impactData)
                    end
                else
                    -- Still in cooldown, just reset wasInAir
                    impactData.wasInAir = false
                    world:set(entity, comps.RagdollImpact, impactData)
                end
            end
        end
    end,
    
    settings = {
        phase = "Heartbeat",
        depends_on = {},
        client_only = true -- Run on client only for visual effects
    }
}

