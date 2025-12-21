local ReplicatedStorage = game:GetService("ReplicatedStorage")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local BridgeNet2 = require(ReplicatedStorage.Modules.Shared.BridgeNet2)
local Visuals = require(ReplicatedStorage.Modules.Visuals)

local MIN_IMPACT_VELOCITY = 30
local IMPACT_COOLDOWN = .3
local FALLING_THRESHOLD = -10
local GROUND_PROXIMITY_THRESHOLD = 5
local DASH_EFFECT_VELOCITY = 5

local IMPACT_CHECK_HZ = 15
local IMPACT_CHECK_TICK = 1 / IMPACT_CHECK_HZ
local impactCheckAcc = 0

local RAGDOLL_DETECT_HZ = 5
local RAGDOLL_DETECT_TICK = 1 / RAGDOLL_DETECT_HZ
local ragdollDetectAcc = 0

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = {workspace.World.Live, workspace.World.Visuals}

local ragdollQuery = world:query(comps.Character, comps.RagdollImpact):cached()
local allCharactersQuery = world:query(comps.Character):cached()

local function createImpact(character, impactPosition, impactVelocity)
    local velocityMagnitude = math.abs(impactVelocity.Y)
    if velocityMagnitude < MIN_IMPACT_VELOCITY then
        return
    end

    local rayOrigin = impactPosition + Vector3.new(0, 10, 0)
    local rayDirection = Vector3.new(0, -15, 0)
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

    if not raycastResult then
        warn(`[RagdollImpact] ❌ No ground found below {impactPosition}`)
        return
    end

    Bridges.ECSClient:Fire(BridgeNet2.AllPlayers(), {
        Module = "RagdollImpact",
        Action = "CreateImpact",
        Position = raycastResult.Position,
        Velocity = impactVelocity,
        CharacterName = character.Name
    })

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        local baseDamage = math.floor(velocityMagnitude / 10) * 5
        local damage = math.clamp(baseDamage, 5, 25)
        humanoid:TakeDamage(damage)
    end
end

local debugPrinted = false
local lastDebugTime = 0
local DEBUG_INTERVAL = 5

local function detectRagdolls()
    for entity, character in allCharactersQuery do
        if not character or not character.Parent then
            continue
        end

        local isRagdolled = false
        local ragdollReason = ""

        if character:FindFirstChild("Ragdoll") then
            isRagdolled = true
            ragdollReason = "Ragdoll BoolValue"
        end

        if character:GetAttribute("Knocked") and character:GetAttribute("Knocked") > 0 then
            isRagdolled = true
            ragdollReason = ragdollReason ~= "" and ragdollReason .. " + Knocked" or "Knocked"
        end

        if character:GetAttribute("Unconscious") and character:GetAttribute("Unconscious") > 0 then
            isRagdolled = true
            ragdollReason = ragdollReason ~= "" and ragdollReason .. " + Unconscious" or "Unconscious"
        end

        if isRagdolled then
            if not world:has(entity, comps.RagdollImpact) then
                world:set(entity, comps.RagdollImpact, {
                    lastImpactTime = 0,
                    wasInAir = false,
                    lastVelocity = Vector3.zero,
                })
            end
        else
            if world:has(entity, comps.RagdollImpact) then
                world:remove(entity, comps.RagdollImpact)
            end
        end
    end
end

local function checkImpacts()
    for entity, character, impactData in ragdollQuery do
        if not character or not character.Parent then
            continue
        end

        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then
            continue
        end

        local currentVelocity = rootPart.AssemblyLinearVelocity
        local velocityMagnitude = currentVelocity.Magnitude

        local needsUpdate = false

        if velocityMagnitude >= DASH_EFFECT_VELOCITY then
            if not impactData.hasDashEffect then
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
                Visuals.Ranged(rootPart.Position, 300, {
                    Module = "Base",
                    Function = "EndDashFX",
                    Arguments = { character }
                })
                impactData.hasDashEffect = false
                needsUpdate = true
            end
        end

        local isFalling = currentVelocity.Y < FALLING_THRESHOLD

        if isFalling then
            impactData.wasInAir = true
            impactData.lastVelocity = currentVelocity
            needsUpdate = true

            local rayOrigin = rootPart.Position + Vector3.new(0, 2, 0)
            local rayDirection = Vector3.new(0, -10, 0)
            local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

            if raycastResult then
                local distanceToGround = (raycastResult.Position - rootPart.Position).Magnitude

                if distanceToGround <= GROUND_PROXIMITY_THRESHOLD then
                    local impactTime = os.clock()

                    if impactTime - impactData.lastImpactTime >= IMPACT_COOLDOWN then
                        createImpact(character, raycastResult.Position, currentVelocity)
                        impactData.lastImpactTime = impactTime
                    end
                end
            end
        else
            if impactData.wasInAir then
                impactData.wasInAir = false
                needsUpdate = true
            end
        end

        if needsUpdate then
            world:set(entity, comps.RagdollImpact, impactData)
        end
    end
end

return {
    run = function(_, dt)
        if not debugPrinted then
            debugPrinted = true
        end

        local currentTime = os.clock()
        if currentTime - lastDebugTime >= DEBUG_INTERVAL then
            lastDebugTime = currentTime
            local entityCount = 0
            for _ in ragdollQuery do
                entityCount = entityCount + 1
            end
        end

        ragdollDetectAcc += dt
        if ragdollDetectAcc >= RAGDOLL_DETECT_TICK then
            ragdollDetectAcc = 0
            detectRagdolls()
        end

        impactCheckAcc += dt
        if impactCheckAcc >= IMPACT_CHECK_TICK then
            impactCheckAcc = 0
            checkImpacts()
        end
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}

