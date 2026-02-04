--!strict
--[[
    NPC Wanderer Flee System

    Handles hit detection and flee behavior for wandering citizen NPCs.
    When hit by a player:
    - Reduces relationship with that player
    - Tracks hit count
    - After enough hits, NPC flees from the attacker

    Runs at 10 Hz for performance
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local EntityCleanup = require(ReplicatedStorage.Modules.ECS.entity_cleanup)
local OccupationData = require(ReplicatedStorage.Modules.OccupationData)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)

-- Query wandering NPCs with flee component
local query = world:query(
    comps.Character,
    comps.Transform,
    comps.NPCFlee,
    comps.NPCRelationship,
    comps.NPCProximity,
    comps.Locomotion
):with(comps.WandererNPC):cached()

-- Throttle to 10 Hz
local lastUpdate = 0
local UPDATE_INTERVAL = 0.1

-- Track last known health per NPC to detect damage
local lastHealthValues: {[number]: number} = {}

-- Get player from character model
local function getPlayerFromCharacter(character: Model): Player?
    return Players:GetPlayerFromCharacter(character)
end

-- OPTIMIZED: Check DamageHistory ECS component first, then fallback
local function checkForDamage(char: Model, entity: number): (boolean, Model?)
    -- Check ECS DamageHistory component first (preferred)
    local damageHistory = world:get(entity, comps.DamageHistory)
    if damageHistory and damageHistory.lastDamageTime > 0 then
        local now = os.clock()
        -- Check if damage was recent (within 2 seconds for flee trigger)
        if now - damageHistory.lastDamageTime < 2 then
            return true, damageHistory.lastAttacker
        end
    end

    -- Fallback: Check for legacy Damage_Log folder
    local damageLog = char:FindFirstChild("Damage_Log")
    if damageLog then
        local children = damageLog:GetChildren()
        if #children > 0 then
            local recentEntry = children[#children]
            if recentEntry:IsA("ObjectValue") and recentEntry.Value then
                return true, recentEntry.Value
            end
        end
    end

    -- Also check health component for damage
    local health = world:get(entity, comps.Health)
    if health then
        local lastHealth = lastHealthValues[entity] or health.max
        if health.current < lastHealth then
            lastHealthValues[entity] = health.current
            return true, nil -- Damaged but unknown attacker
        end
        lastHealthValues[entity] = health.current
    end

    return false, nil
end

-- Main system function
local function updateFlee(dt: number)
    local now = os.clock()
    if now - lastUpdate < UPDATE_INTERVAL then
        return
    end
    lastUpdate = now

    for entity, char, transform, flee, relationship, proximity, loco in query do
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            continue
        end

        -- Check if currently fleeing
        if flee.isFleeing then
            -- Check if flee duration is over
            if now >= flee.fleeEndTime then
                -- Stop fleeing (in-place mutation)
                flee.isFleeing = false
                flee.fleeTarget = nil
                flee.fleeEndTime = 0

                -- Resume normal state (in-place mutation)
                proximity.isWanderPaused = false

                -- Components are mutated in-place, no world:set needed

                -- Stop movement briefly (in-place mutation with change detection)
                if loco.speed ~= 0 or loco.dir.Magnitude > 0.001 then
                    loco.dir = Vector3.zero
                    loco.speed = 0
                end
            else
                -- Continue fleeing
                if flee.fleeTarget then
                    local targetHRP = flee.fleeTarget:FindFirstChild("HumanoidRootPart")
                    if targetHRP then
                        local npcPos = transform.new.Position
                        local targetPos = targetHRP.Position

                        -- Calculate flee direction (away from target)
                        local fleeDir = (npcPos - targetPos) * Vector3.new(1, 0, 1)
                        if fleeDir.Magnitude > 0.01 then
                            fleeDir = fleeDir.Unit
                        else
                            -- Random direction if directly on top
                            fleeDir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
                        end

                        -- Get run speed from config
                        local config = world:get(entity, comps.NPCConfig)
                        local runSpeed = config and config.runSpeed or 18

                        -- Update locomotion with change detection (in-place mutation)
                        local dirChanged = (loco.dir - fleeDir).Magnitude > 0.001
                        local speedChanged = math.abs(loco.speed - runSpeed) > 0.1
                        if dirChanged or speedChanged then
                            loco.dir = fleeDir
                            loco.speed = runSpeed
                        end

                        -- Update transform to face away (in-place mutation)
                        local newCFrame = CFrame.lookAt(npcPos, npcPos + fleeDir)
                        transform.old = transform.new
                        transform.new = newCFrame
                    end
                end
            end
            continue -- Skip damage check while fleeing
        end

        -- Check for damage
        local wasDamaged, attacker = checkForDamage(char, entity)
        if wasDamaged then
            -- Find attacker player ID
            local attackerId: number? = nil
            if attacker then
                local player = getPlayerFromCharacter(attacker)
                if player then
                    attackerId = player.UserId
                end
            end

            if attackerId then
                -- Update hit count
                local hitCounts = relationship.hitCounts or {}
                hitCounts[attackerId] = (hitCounts[attackerId] or 0) + 1
                relationship.hitCounts = hitCounts

                -- Reduce relationship
                local relationships = relationship.relationships or {}
                local currentRel = relationships[attackerId] or 0
                relationships[attackerId] = math.max(0, currentRel - OccupationData.RELATIONSHIP_LOSS_PER_HIT)
                relationship.relationships = relationships

                -- relationship is mutated in-place, no world:set needed

                -- Check if should flee
                if hitCounts[attackerId] >= OccupationData.HITS_TO_FLEE then
                    -- Start fleeing (in-place mutation)
                    flee.isFleeing = true
                    flee.fleeTarget = attacker
                    flee.fleeEndTime = now + OccupationData.FLEE_DURATION

                    -- Pause wandering (in-place mutation)
                    proximity.isWanderPaused = true
                    proximity.nearbyPlayer = nil

                    -- Components are mutated in-place, no world:set needed

                    -- Clear head tracking
                    char:SetAttribute("TrackPlayer", false)

                    -- Reset hit count after fleeing starts (in-place mutation)
                    hitCounts[attackerId] = 0
                    relationship.hitCounts = hitCounts
                    -- relationship is mutated in-place, no world:set needed
                end
            end
        end
    end
end

-- Cleanup when entity is removed (prevents memory leak from lastHealthValues table)
local function cleanup(entity: number)
    lastHealthValues[entity] = nil
end

-- Register cleanup callback for centralized entity cleanup
EntityCleanup.register("npc_wanderer_flee", cleanup)

return {
    run = function(world: Jecs.World, dt: number)
        updateFlee(dt)
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = { "npc_wanderer_proximity" },
        server_only = true
    }
}
